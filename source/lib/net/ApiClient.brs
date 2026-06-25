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

' Called when a screen is replaced (not pushed) so queued boot fetches from the
' outgoing screen do not block the new screen's first requests.
function DrainHttpQueueForNavigation() as void
    client = GetHttpClient()
    if client <> invalid then client.callFunc("ClearQueue", invalid)
end function

' Returns the app-wide HTTP pool, creating it on first use if MainScene has not yet
' (so requests fired during early boot still resolve to a single shared pool).
function GetHttpClient() as object
    if m.global <> invalid and m.global.httpClient <> invalid then
        return m.global.httpClient
    end if
    return CreateObject("roSGNode", "HttpClient")
end function

function WarmHttpBearerPath() as string
    ' Small Bearer GET — never use home/CW/catalogue for keep-alive (full payloads).
    return Endpoints().PROFILE.GET_LOGIN_PROFILES
end function

' Warm every pool worker with one cheap Bearer GET (profile picker idle time).
sub WarmHttpPool()
    warmPath = WarmHttpBearerPath()
    if warmPath = "" then return
    client = GetHttpClient()
    if client = invalid then return
    client.callFunc("WarmAll", { path: warmPath, warmOnly: true })
end sub

' Warm a single worker before a lone POST/GET (e.g. select-profile).
sub WarmHttpConnection(path as string)
    if path = invalid or path = "" then return
    client = GetHttpClient()
    if client = invalid then return
    client.callFunc("WarmAll", { path: path, workerCount: 1, warmOnly: true })
end sub

' Legacy alias — routes to WarmHttpPool (never duplicate heavy catalogue GETs).
sub WarmHttpConnections(path = "" as string)
    WarmHttpPool()
end sub

function ApiGet(path as string) as object
    return CreateHttpTask("GET", path)
end function

' GET with query-string params (parity with axios params on getDataApi).
function ApiGetQuery(path as string, params as object) as object
    return ApiGet(path + BuildQueryString(params))
end function

function BuildQueryString(params as object) as string
    if params = invalid then return ""
    qs = ""
    for each key in params
        val = params[key]
        if val <> invalid then
            piece = key + "=" + EncodeQueryValue(val)
            if qs = "" then
                qs = piece
            else
                qs = qs + "&" + piece
            end if
        end if
    end for
    if qs = "" then return ""
    return "?" + qs
end function

function EncodeQueryValue(val as dynamic) as string
    if type(val) = "roInteger" or type(val) = "Integer" then return Str(val).Trim()
    if type(val) = "roFloat" or type(val) = "Float" then return Str(val).Trim()
    if type(val) = "roBoolean" or type(val) = "Boolean" then
        if val = true then return "true"
        return "false"
    end if
    return val.ToStr()
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
