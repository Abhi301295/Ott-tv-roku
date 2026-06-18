' ProfileUiDebug.brs — grep telnet / simulator output for [PROFILE_UI].

sub ProfileUiLog(tag as string, detail as string)
    if not ProfileUiDebugEnabled() then return
    print "[PROFILE_UI] "; tag; " | "; detail
end sub

sub ProfileUiLogRow(index as integer, focused as boolean, progress as float, outerScale as float, innerScale as float, offsetX as float)
    if not ProfileUiDebugEnabled() then return
    s = ProfileUiSpec()
    pct = Int(progress * 100 + 0.5)
    oPct = Int(outerScale * 100 + 0.5)
    iPct = Int(innerScale * 100 + 0.5)
    soPct = Int(s.outerFocusScale * 100 + 0.5)
    siPct = Int(s.innerFocusScale * 100 + 0.5)
    detail = "idx=" + index.ToStr()
    detail = detail + " focused=" + focused.ToStr()
    detail = detail + " progress=" + pct.ToStr() + "%"
    detail = detail + " outerScale=" + oPct.ToStr() + "%"
    detail = detail + " innerScale=" + iPct.ToStr() + "%"
    detail = detail + " offsetX=" + Str(offsetX)
    detail = detail + " specOuter=" + soPct.ToStr() + "%"
    detail = detail + " specInner=" + siPct.ToStr() + "%"
    ProfileUiLog("square-row", detail)
end sub

sub ProfileUiLogColors(top as string, bottom as string, border as string, name as string)
    if not ProfileUiDebugEnabled() then return
    ProfileUiLog("square-colors", "top=" + top + " bottom=" + bottom + " border=" + border + " name=" + name)
end sub

sub ProfileUiLogScreen(titleX as integer, titleY as integer, listX as integer, listY as integer, pitch as integer)
    if not ProfileUiDebugEnabled() then return
    s = ProfileUiSpec()
    detail = "title=[" + titleX.ToStr() + "," + titleY.ToStr() + "]"
    detail = detail + " list=[" + listX.ToStr() + "," + listY.ToStr() + "]"
    detail = detail + " pitch=" + pitch.ToStr()
    detail = detail + " specTitle=[" + s.titleX.ToStr() + "," + s.titleY.ToStr() + "]"
    detail = detail + " specList=[" + s.profilesX.ToStr() + "," + s.profilesY.ToStr() + "]"
    detail = detail + " specPitch=" + s.rowPitch.ToStr()
    ProfileUiLog("screen-layout", detail)
end sub

sub ProfileUiLogDerived(index as integer, focused as boolean, outerScale as float, innerScale as float)
    if not ProfileUiDebugEnabled() then return
    cardScale = outerScale
    if focused then cardScale = outerScale * innerScale
    cs = Int(cardScale * 100 + 0.5)
    detail = "idx=" + index.ToStr()
    detail = detail + " cardVisualScaleVsLayout=" + Str(cardScale / 100.0)
    detail = detail + " specCardScale=1.56"
    ProfileUiLog("square-derived", detail)
end sub
