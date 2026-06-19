' SearchDebug.brs — grep telnet for [SEARCH_DBG]; mirrors React searchDbg.ts

sub SearchDbg(tag as string, detail as string)
    print "[SEARCH_DBG] "; tag; " | "; detail
end sub

function SearchDbgStr(val as dynamic) as string
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

sub SearchDbgSpec()
    detail = "pageBg=#1f1f22 outerTop=" + Str(SR_OuterMarginTop())
    detail = detail + " colGap=" + Str(SR_ColGap()) + " padX=" + Str(SR_ColPadX())
    detail = detail + " padTop=" + Str(SR_ColPadTop()) + " marginTop=" + Str(SR_ColMarginTop())
    detail = detail + " leftPct=" + Str(SR_LeftBasisPct()) + " rightPct=" + Str(SR_RightBasisPct())
    detail = detail + " inputH=" + Str(SR_InputH()) + " inputFont=" + Str(SR_InputFontSize())
    detail = detail + " keyH=" + Str(SR_KeyH()) + " keyW=" + Str(SR_KeyW())
    detail = detail + " gridML=" + Str(SR_GridMarginLeft()) + " card=" + Str(SR_CardW()) + "x" + Str(SR_CardH())
    detail = detail + " resultCap=" + Str(SR_ResultCap())
    SearchDbg("token_spec", detail)
end sub

sub SearchDbgLayout(tag as string, offX as integer, viewportW as integer, leftW as integer, rightW as integer, topY as integer)
    SearchDbg(tag, "offX=" + Str(offX) + " viewportW=" + Str(viewportW) + " leftW=" + Str(leftW) + " rightW=" + Str(rightW) + " topY=" + Str(topY))
end sub

sub SearchDbgRect(tag as string, label as string, x as integer, y as integer, w as integer, h as integer)
    SearchDbg(tag, "rect " + label + " x=" + Str(x) + " y=" + Str(y) + " w=" + Str(w) + " h=" + Str(h))
end sub
