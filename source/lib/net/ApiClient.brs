' ApiClient.brs
' Thin helpers to create and dispatch HTTP requests from the render thread.
' Requests run on the shared keep-alive HttpClient pool (see components/core/HttpClient).
' Observe task.apiResult or task.errorMessage when complete (unchanged for callers).

function CreateHttpTask(method as string, path as string, body = invalid as dynamic) as object
    req = CreateObject("roSGNode", "HttpRequest")
    req.method = UCase(method)
    req.path = path
    if body <> invalid then
        req.body = FormatJson(body)
    end if
    return req
end function

function StartHttpTask(task as object) as void
    client = GetHttpClient()
    if client <> invalid then client.callFunc("Submit", task)
end function

' Returns the app-wide HTTP pool, creating it on first use if MainScene has not yet
' (so requests fired during early boot still resolve to a single shared pool).
function GetHttpClient() as object
    if m.global <> invalid and m.global.httpClient <> invalid then
        return m.global.httpClient
    end if
    return CreateObject("roSGNode", "HttpClient")
end function

' Pre-open keep-alive connections on every pooled worker so the next screen's
' requests skip the TLS handshake. Safe to call from idle moments (e.g. profile screen).
function WarmHttpConnections() as void
    client = GetHttpClient()
    if client <> invalid then client.callFunc("WarmAll", Endpoints().LOGIN.CHECK_UPDATE)
end function

function ApiGet(path as string) as object
    return CreateHttpTask("GET", path)
end function

function ApiPost(path as string, body as object) as object
    return CreateHttpTask("POST", path, body)
end function

function ApiPatch(path as string, body as object) as object
    return CreateHttpTask("PATCH", path, body)
end function

function ApiPut(path as string, body as object) as object
    return CreateHttpTask("PUT", path, body)
end function

function ApiDelete(path as string, body = invalid as object) as object
    return CreateHttpTask("DELETE", path, body)
end function
