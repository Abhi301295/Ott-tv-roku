sub init()
    m.top.functionName = "RunBake"
end sub

sub RunBake()
    key = m.top.colorKey
    if key = invalid or key = "" then
        m.top.done = true
        return
    end if

    primary = ProfileArcParseRokuRgb(m.top.portalPrimary)
    secondary = ProfileArcParseRokuRgb(m.top.portalSecondary)
    tertiary = ProfileArcParseRokuRgb(m.top.portalTertiary)
    last = ProfileArcFrameCount() - 1

    for i = 0 to last
        ProfileArcBakeOneFrame(i, key, primary, secondary, tertiary)
    end for

    print "[PROFILE_ARC_DBG] bake_complete key=" + key + " frames=" + (last + 1).ToStr()
    m.top.done = true
end sub
