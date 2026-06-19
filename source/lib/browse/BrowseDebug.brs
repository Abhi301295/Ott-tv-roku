' BrowseDebug.brs — grep telnet / sim log for [BROWSE_DBG].

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
    print "[BROWSE_DBG] "; tag; " | "; detail
end sub

sub BrowseDbgState(tag as string, state as object)
    if state = invalid then
        BrowseDbg(tag, "navState=(invalid)")
        return
    end if
    parts = ""
    for each key in state
        piece = key + "=" + BrowseDbgStr(state[key])
        if parts = "" then
            parts = piece
        else
            parts = parts + " " + piece
        end if
    end for
    BrowseDbg(tag, parts)
end sub

sub BrowseDbgApi(tag as string, api as object)
    if api = invalid then
        BrowseDbg(tag, "api=(invalid)")
        return
    end if
    ok = "(missing)"
    if api.ok <> invalid then ok = BrowseDbgStr(api.ok)
    status = "(missing)"
    if api.statusCode <> invalid then status = BrowseDbgStr(api.statusCode)
    msg = ""
    if api.message <> invalid then msg = api.message
    total = "(missing)"
    if api.result <> invalid and api.result.total <> invalid then total = BrowseDbgStr(api.result.total)
    listingCount = 0
    if api.result <> invalid and api.result.listing <> invalid then listingCount = api.result.listing.Count()
    BrowseDbg(tag, "ok=" + ok + " statusCode=" + status + " message=" + msg + " total=" + total + " listingCount=" + Str(listingCount))
end sub
