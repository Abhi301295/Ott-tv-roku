sub init()
    m.top.functionName = "runHttp"
end sub

sub runHttp()
    method = UCase(m.top.method)
    path = m.top.path
    body = m.top.body

    m.top.responseText = ""
    m.top.apiResult = invalid
    m.top.httpStatus = 0
    m.top.errorMessage = ""
    m.top.shouldLogout = false

    if path = invalid or path = "" then
        m.top.errorMessage = "HttpTask: path is required"
        return
    end if

    cfg = AppConfig()
    url = cfg.apiBaseUrl
    if Left(path, 1) = "/" then
        url = url + path
    else
        url = url + "/" + path
    end if

    headers = BuildDefaultHeaders()
    headers = ApplyAuthHeader(url, headers)

    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.AddHeader("Content-Type", headers["Content-Type"])
    xfer.AddHeader("domain-name", headers["domain-name"])
    xfer.AddHeader("Accept-Language", headers["Accept-Language"])
    xfer.AddHeader("accept", headers["accept"])
    xfer.AddHeader("Platform", headers["Platform"])
    xfer.AddHeader("Timezone", headers["Timezone"])
    if headers["authorization"] <> invalid and headers["authorization"] <> "" then
        xfer.AddHeader("authorization", headers["authorization"])
    end if

    port = CreateObject("roMessagePort")
    xfer.SetPort(port)

    ok = false
    if method = "GET" then
        ok = xfer.AsyncGetToString()
    else if method = "POST" then
        ok = xfer.AsyncPostFromString(IfElse(body, ""))
    else if method = "PATCH" then
        xfer.SetRequest("PATCH")
        ok = xfer.AsyncPostFromString(IfElse(body, ""))
    else if method = "PUT" then
        xfer.SetRequest("PUT")
        ok = xfer.AsyncPostFromString(IfElse(body, ""))
    else if method = "DELETE" then
        xfer.SetRequest("DELETE")
        ok = xfer.AsyncPostFromString(IfElse(body, ""))
    else
        m.top.errorMessage = "HttpTask: unsupported method " + method
        return
    end if

    if not ok then
        m.top.errorMessage = "HttpTask: failed to start request"
        return
    end if

    responseText = ""
    while true
        msg = wait(20000, port)
        if msg = invalid then
            m.top.errorMessage = "HttpTask: timeout"
            exit while
        end if
        if type(msg) = "roUrlEvent" then
            if msg.GetInt() = 1 then
                responseText = msg.GetString()
                m.top.httpStatus = msg.GetResponseCode()
                exit while
            else
                m.top.errorMessage = "HttpTask: " + Str(msg.GetResponseCode())
                exit while
            end if
        end if
    end while

    m.top.responseText = responseText

    processed = ProcessApiResponse(url, m.top.httpStatus, responseText)
    m.top.apiResult = processed
    m.top.shouldLogout = processed.shouldLogout

    if processed.shouldLogout then
        ClearStorage()
    end if

    if not processed.ok and not processed.suppressToast then
        if processed.message <> "" then
            m.top.errorMessage = processed.message
        else
            m.top.errorMessage = "Request failed"
        end if
    end if
end sub

function IfElse(value as dynamic, fallback as string) as string
    if value = invalid then return fallback
    return value
end function
