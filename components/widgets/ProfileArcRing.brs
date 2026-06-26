sub init()
    m.progressArc = m.top.findNode("progressArc")
    if m.global <> invalid then
        ProfileArcEnsureGlobalFields(m.global)
        m.global.observeField("profileArcBakeReady", "OnFrameChanged")
    end if
    OnLayoutChanged()
    OnFrameChanged()
end sub

sub OnLayoutChanged()
    if m.progressArc = invalid then return
    sz = m.top.ringSize
    if sz < 1 then sz = 166
    m.progressArc.width = sz
    m.progressArc.height = sz
end sub

sub OnPortalColorsChanged()
    OnFrameChanged()
end sub

sub OnFrameChanged()
    if m.progressArc = invalid then return
    uri = ProfileArcResolvedFrameUri(m.top.arcFrame, m.top.portalPrimary, m.top.portalSecondary, m.top.portalTertiary, m.global)
    if m.progressArc.uri <> uri then m.progressArc.uri = uri
end sub
