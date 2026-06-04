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
