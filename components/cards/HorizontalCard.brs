sub init()
    m.focusBorder = invalid
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
    CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
end sub

sub ApplyAll()
    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        CardHideThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo)
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
        CardApplySkeletonFromConfig(m.skeleton, CardSkeletonThemeTokens(m.top), true)
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
    end if
    ApplyFocusVisual()
end sub

sub ApplyFocusVisual()
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 0, 0, 546, 318, m.top.cPrimary500)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
