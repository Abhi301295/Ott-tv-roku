sub init()
    m.focusBorder = invalid
    m.rankLabel = m.top.findNode("rankLabel")
    m.rankGlow = m.top.findNode("rankGlow")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyFocusVisual()
end sub

sub OnThemeChanged()
    ApplyAll()
end sub

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, m.skeleton)
end sub

sub ApplyAll()
    m.rankLabel.text = (m.top.rank + 1).ToStr()
    m.rankLabel.color = m.top.cNeutral50
    if m.rankGlow <> invalid then m.rankGlow.visible = true

    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
    else
        m.thumb.visible = false
        m.skeleton.visible = true
        m.skeleton.running = true
    end if
    CardApplySkeleton(m.skeleton, m.top.cNeutral700, m.top.cNeutral800)
    ApplyFocusVisual()
end sub

sub ApplyFocusVisual()
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 21, 0, 374, 214, m.top.cPrimary500)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
