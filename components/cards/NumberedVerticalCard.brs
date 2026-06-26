sub init()
    m.focusBorder = invalid
    m.rankLabel = m.top.findNode("rankLabel")
    m.rankGlow = m.top.findNode("rankGlow")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
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
    CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 368, 208)
end sub

sub ApplyAll()
    m.rankLabel.text = (m.top.rank + 1).ToStr()
    m.rankLabel.color = m.top.cNeutral50
    if m.rankGlow <> invalid then m.rankGlow.visible = true

    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        CardHideThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo)
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
        CardApplySkeletonFromConfig(m.skeleton, CardSkeletonThemeTokens(m.top), true)
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 368, 208)
    end if
    ApplyFocusVisual()
end sub

sub ApplyFocusVisual()
    if m.focusBorder = invalid then
        frame = m.top.createChild("FocusFrame")
        m.top.removeChild(frame)
        m.top.insertChild(frame, 1)
        frame.translation = [21, 0]
        frame.boxWidth = 374
        frame.boxHeight = 214
        if m.top.cPrimary500 <> invalid and m.top.cPrimary500 <> "" then frame.color = m.top.cPrimary500
        m.focusBorder = frame
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
