' ProfileSelectTrace.brs — optional profile-select trace hooks (no-op in production).

function ProfileSelectFmt(val as dynamic) as string
    if val = invalid then return "?"
    t = type(val)
    if t = "roBoolean" or t = "Boolean" then return val.ToStr()
    if t = "roInteger" or t = "Integer" then return val.ToStr()
    if t = "roFloat" or t = "Float" then return val.ToStr()
    if t = "roString" or t = "String" then return val
    return "" + val
end function

function ProfileSelectCtx(fromNode as object) as string
    return ""
end function

sub ProfileSelectLog(tag as string, detail as string)
end sub

sub ProfileSelectLogNode(tag as string, detail as string, fromNode as object)
end sub
