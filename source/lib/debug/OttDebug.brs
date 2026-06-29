' OttDebug.brs — unified opt-in trace logging.
' Grep telnet for [OTT_DBG]. Set OttDbgEnabled() true while investigating.
' Separate channels: [HTTP] (HttpClient), [PERF] (HomePerf.brs).

function OttDbgEnabled() as boolean
    return false
end function

function OttDbgStr(val as dynamic) as string
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

sub OttDbg(tag as string, detail = "" as string)
    if not OttDbgEnabled() then return
    line = "[OTT_DBG] " + tag
    if detail <> "" then line = line + " " + detail
    print line
end sub

sub OttDbgState(tag as string, state as object)
    if not OttDbgEnabled() then return
    if state = invalid then
        OttDbg(tag, "state=invalid")
        return
    end if
    parts = ""
    for each k in state
        if parts <> "" then parts = parts + " "
        parts = parts + k + "=" + OttDbgStr(state[k])
    end for
    OttDbg(tag, parts)
end sub

sub OttDbgApi(tag as string, api as object)
    if not OttDbgEnabled() then return
    if api = invalid then
        OttDbg(tag, "api=invalid")
        return
    end if
    ok = "?"
    if api.ok <> invalid then
        if api.ok = true then ok = "true" else ok = "false"
    end if
    http = "?"
    if api.httpStatus <> invalid then http = Str(api.httpStatus)
    OttDbg(tag, "ok=" + ok + " http=" + http)
end sub
