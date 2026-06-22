' ReelsDbg.brs — grep telnet for [REELS_DBG] during sim verification.

function ReelsDbgStr(val as dynamic) as string
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

sub ReelsDbg(tag as string, detail as string)
    print "[REELS_DBG] " + tag + " | " + detail
end sub

sub ReelsDbgApi(tag as string, api as object)
    if api = invalid then
        ReelsDbg(tag, "api=invalid")
        return
    end if
    ok = false
    if api.ok = true then ok = true
    sc = ""
    if api.statusCode <> invalid then sc = Str(api.statusCode).Trim()
    cnt = 0
    if api.result <> invalid and api.result.data <> invalid then cnt = api.result.data.Count()
    total = 0
    if api.result <> invalid and api.result.total <> invalid then total = api.result.total
    ReelsDbg(tag, "ok=" + ReelsDbgStr(ok) + " status=" + sc + " batch=" + Str(cnt) + " total=" + Str(total))
end sub
