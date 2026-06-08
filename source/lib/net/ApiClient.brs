' ApiClient.brs
' Thin helpers to create and run HttpTask from the render thread.
' Observe task.apiResult or task.errorMessage when complete.

function CreateHttpTask(method as string, path as string, body = invalid as dynamic) as object
    task = CreateObject("roSGNode", "HttpTask")
    task.method = UCase(method)
    task.path = path
    if body <> invalid then
        task.body = FormatJson(body)
    end if
    return task
end function

function StartHttpTask(task as object) as void
    task.control = "RUN"
end function

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
