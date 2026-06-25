' TelemetryWorker.brs
' Single long-lived worker: one POST at a time to the telemetry bridge (external host).
' Reuses roUrlTransfer; response code comes from roUrlEvent (not xfer.GetResponseCode).

sub init()
    m.top.functionName = "runWorker"
end sub

sub runWorker()
    m.port = CreateObject("roMessagePort")
    m.top.observeField("job", m.port)

    m.xfer = CreateObject("roUrlTransfer")
    m.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    m.xfer.InitClientCertificates()
    m.xfer.EnableEncodings(true)
    m.xfer.SetPort(m.port)

    m.curJob = invalid
    m.timer = invalid

    m.top.available = true
    m.top.completed = m.top.completed + 1

    while true
        msg = wait(1000, m.port)
        if msg = invalid then
            if m.curJob <> invalid and m.timer <> invalid and m.timer.TotalMilliseconds() > 15000 then
                m.xfer.AsyncCancel()
                FinishCurrent(0, "", "timeout")
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
                        reason = ""
                        if m.xfer.GetFailureReason() <> invalid then reason = m.xfer.GetFailureReason()
                        FinishCurrent(msg.GetResponseCode(), "", reason)
                    end if
                end if
            end if
        end if
    end while
end sub

sub BeginJob(job as object)
    if m.curJob <> invalid then return

    m.curJob = job
    m.timer = CreateObject("roTimespan")

    url = job.url
    payload = job.payload
    eventName = ""
    if payload <> invalid and payload.event_name <> invalid then eventName = payload.event_name

    if url = invalid or url = "" or payload = invalid then
        FinishCurrent(0, "", "missing url or payload")
        return
    end if

    m.xfer.SetUrl(url)
    m.xfer.AddHeader("Content-Type", "application/json")
    m.xfer.SetRequest("POST")

    body = FormatJson(payload)
    ok = m.xfer.AsyncPostFromString(body)
    if not ok then
        FinishCurrent(0, "", "failed to start POST")
        return
    end if

    print "[TELEMETRY_DBG] post_start event="; eventName
end sub

sub FinishCurrent(status as integer, responseText as string, errMsg as string)
    job = m.curJob
    eventName = ""
    if job <> invalid and job.payload <> invalid and job.payload.event_name <> invalid then
        eventName = job.payload.event_name
    end if

    elapsed = 0
    if m.timer <> invalid then elapsed = m.timer.TotalMilliseconds()

    body = ""
    if responseText <> invalid and responseText <> "" then body = responseText

    print "[TELEMETRY_DBG] post_done event="; eventName; " http="; status; " ms="; elapsed; " ok="; TelemetryHttpOk(status)
    if errMsg <> "" then
        print "[TELEMETRY_DBG] response event="; eventName; " http="; status; " error="; errMsg
    else if body <> "" then
        print "[TELEMETRY_DBG] response event="; eventName; " http="; status; " body="; body
    else
        print "[TELEMETRY_DBG] response event="; eventName; " http="; status; " body=(empty)"
    end if

    m.curJob = invalid
    m.timer = invalid

    m.top.available = true
    m.top.completed = m.top.completed + 1
end sub

function TelemetryHttpOk(status as integer) as string
    if status = 202 then return "true"
    if status >= 200 and status < 300 then return "true"
    return "false"
end function
