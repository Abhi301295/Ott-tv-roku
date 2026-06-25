' HttpWorker.brs
' A long-lived task that owns ONE roUrlTransfer and processes jobs in a loop.
' Reusing the same transfer across requests is what keeps the TCP+TLS connection
' alive (HTTP keep-alive), so every request after the first to the same host skips
' the ~1.1s handshake. One job at a time; parallelism comes from the pool size.

sub init()
    m.top.functionName = "runWorker"
end sub

sub runWorker()
    m.port = CreateObject("roMessagePort")
    m.top.observeField("job", m.port)

    m.xfer = CreateObject("roUrlTransfer")
    m.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    m.xfer.InitClientCertificates()
    m.xfer.SetPort(m.port)

    m.curJob = invalid
    m.timer = invalid
    m.lastAuthScheme = invalid

    ' Job observer + transfer are live; announce readiness so the pool can dispatch.
    ' Bumping `completed` is the pool's pump trigger (see HttpClient.OnWorkerCompleted).
    m.top.available = true
    m.top.completed = m.top.completed + 1

    while true
        msg = wait(1000, m.port)
        if msg = invalid then
            ' Idle tick: abort a request that has run past the timeout budget.
            if m.curJob <> invalid and m.timer <> invalid and m.timer.TotalMilliseconds() > 20000 then
                m.xfer.AsyncCancel()
                FinishCurrent(0, "", "HttpWorker: timeout")
            end if
        else
            t = type(msg)
            if t = "roSGNodeEvent" then
                if msg.GetField() = "job" then
                    job = msg.GetData()
                    if job <> invalid then BeginJob(job)
                end if
            else if t = "roUrlEvent" then
                if m.curJob <> invalid then
                    if msg.GetInt() = 1 then
                        FinishCurrent(msg.GetResponseCode(), msg.GetString(), "")
                    else
                        FinishCurrent(msg.GetResponseCode(), "", "HttpWorker: " + Str(msg.GetResponseCode()))
                    end if
                end if
            end if
        end if
    end while
end sub

sub BeginJob(job as object)
    ' Should not happen (dispatcher gates on `available`), but never clobber a live job.
    if m.curJob <> invalid then return

    m.curJob = job
    m.timer = CreateObject("roTimespan")

    job.responseText = ""
    job.httpStatus = 0
    job.errorMessage = ""
    job.shouldLogout = false

    path = job.path
    if path = invalid or path = "" then
        FinishCurrent(0, "", "HttpWorker: path is required")
        return
    end if

    cfg = AppConfig()
    url = cfg.apiBaseUrl
    if Left(path, 1) = "/" then
        url = url + path
    else
        url = url + "/" + path
    end if
    m.curUrl = url

    headers = BuildDefaultHeaders()
    headers = ApplyAuthHeader(url, headers)
    authHdr = ""
    if headers["authorization"] <> invalid then authHdr = headers["authorization"]
    if authHdr = "" then headers.Delete("authorization")
    ' Login uses Basic auth; post-login APIs use Bearer. Reusing the same roUrlTransfer
    ' across that boundary leaves a keep-alive connection the server bound to the wrong
    ' credentials — recycle the transfer when the auth scheme changes.
    EnsureTransferForAuth(authHdr)

    m.xfer.SetUrl(url)
    ' SetHeaders replaces the full header set, so a reused transfer never carries
    ' a stale authorization header from a previous request.
    m.xfer.SetHeaders(headers)

    method = UCase(job.method)
    body = HttpWorkerBody(job.body)

    ok = false
    ' SetRequest is sticky on a reused keep-alive roUrlTransfer: a prior PATCH/PUT/DELETE
    ' otherwise leaks its verb onto the next GET/POST (e.g. PATCH accounts/signin poisoning
    ' the worker so the onboard POST /device goes out as PATCH -> "Cannot PATCH /device").
    ' Always set the verb explicitly so the request method matches this job regardless of
    ' what ran on this worker before.
    if method = "GET" then
        m.xfer.SetRequest("GET")
        ok = m.xfer.AsyncGetToString()
    else if method = "POST" then
        m.xfer.SetRequest("POST")
        ok = m.xfer.AsyncPostFromString(body)
    else if method = "PATCH" or method = "PUT" or method = "DELETE" then
        m.xfer.SetRequest(method)
        ok = m.xfer.AsyncPostFromString(body)
    else
        FinishCurrent(0, "", "HttpWorker: unsupported method " + method)
        return
    end if

    if not ok then
        FinishCurrent(0, "", "HttpWorker: failed to start request")
    end if
end sub

sub FinishCurrent(status as integer, responseText as string, errMsg as string)
    job = m.curJob

    elapsed = 0
    if m.timer <> invalid then elapsed = m.timer.TotalMilliseconds()
    p = ""
    warmOnly = false
    if job <> invalid then
        p = job.path
        if job.warmOnly = true then warmOnly = true
    end if
    tag = "[HTTP]"
    if warmOnly then tag = "[HTTP_WARM]"
    print tag + " " + m.top.id + " " + Str(elapsed).Trim() + "ms  " + Str(status).Trim() + "  " + p

    m.curJob = invalid
    m.timer = invalid

    if job <> invalid then
        job.responseText = responseText
        job.httpStatus = status

        url = m.curUrl
        if url = invalid then url = ""

        if errMsg <> "" and responseText = "" then
            ' Transport-level failure (no envelope to parse).
            job.errorMessage = errMsg
            job.apiResult = {
                ok: false
                httpStatus: status
                statusCode: status
                message: errMsg
                result: invalid
                shouldLogout: false
                suppressToast: false
            }
        else
            processed = ProcessApiResponse(url, status, responseText)
            job.shouldLogout = processed.shouldLogout
            if processed.shouldLogout then ClearStorage()
            if not processed.ok and not processed.suppressToast then
                if processed.message <> "" then
                    job.errorMessage = processed.message
                else
                    job.errorMessage = "Request failed"
                end if
            end if
            ' apiResult is set last: callers observe it as the "done" signal.
            job.apiResult = processed
        end if
    end if

    ' Hand the warm transfer back to the pool.
    m.top.available = true
    m.top.completed = m.top.completed + 1
end sub

function HttpWorkerBody(value as dynamic) as string
    if value = invalid then return ""
    return value
end function

function AuthScheme(authHdr as string) as string
    if authHdr = invalid or authHdr = "" then return "none"
    if Left(LCase(authHdr), 7) = "bearer " then return "bearer"
    return "basic"
end function

' Drop and recreate roUrlTransfer when Authorization scheme changes (Basic login
' warm-up vs Bearer select-profile). Without this, keep-alive reuses a connection the
' API gateway already associated with the previous credentials.
sub EnsureTransferForAuth(authHdr as string)
    scheme = AuthScheme(authHdr)
    if m.lastAuthScheme <> invalid and m.lastAuthScheme <> scheme then
        print "[HTTP] " + m.top.id + " auth scheme " + m.lastAuthScheme + " -> " + scheme + " (recycling transfer)"
        m.xfer = CreateObject("roUrlTransfer")
        m.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        m.xfer.InitClientCertificates()
        m.xfer.SetPort(m.port)
    end if
    m.lastAuthScheme = scheme
end sub
