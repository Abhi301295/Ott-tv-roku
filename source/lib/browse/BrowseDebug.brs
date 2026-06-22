' BrowseDebug.brs — optional browse trace hooks (no-op in production).

function BrowseDbgStr(val as dynamic) as string
    if val = invalid then return "(invalid)"
    t = type(val)
    if t = "roBoolean" or t = "Boolean" then
        if val = true then return "true"
        return "false"
    end if
    if t = "roInteger" or t = "Integer" or t = "roInt" then return Str(val).Trim()
    if t = "roFloat" or t = "Float" then return Str(val).Trim()
    if t = "roString" or t = "String" then return val
    return Str(val).Trim()
end function

sub BrowseDbg(tag as string, detail as string)
end sub

sub BrowseDbgState(tag as string, state as object)
end sub

sub BrowseDbgApi(tag as string, api as object)
end sub
