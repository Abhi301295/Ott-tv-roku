' BrowseDebug.brs — compatibility shim; include OttDebug.brs before this file in component XML.

function BrowseDbgStr(val as dynamic) as string
    return OttDbgStr(val)
end function

sub BrowseDbg(tag as string, detail as string)
    OttDbg(tag, detail)
end sub

sub BrowseDbgState(tag as string, state as object)
    OttDbgState(tag, state)
end sub

sub BrowseDbgApi(tag as string, api as object)
    OttDbgApi(tag, api)
end sub
