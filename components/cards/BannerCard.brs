sub init()
    m.focusBorder = m.top.findNode("focusBorder")
    m.thumbFallback = m.top.findNode("fallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.titleLabel = m.top.findNode("titleLabel")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary700)
end sub

sub OnThemeChanged()
    ApplyAll()
end sub

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 1770, 400)
end sub

sub ApplyAll()
    m.titleLabel.text = m.top.title
    m.titleLabel.color = m.top.cNeutral50

    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        CardHideThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo)
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
        CardApplySkeletonFromConfig(m.skeleton, CardSkeletonThemeTokens(m.top), true)
        m.titleLabel.visible = true
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 1770, 400)
        m.titleLabel.visible = true
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary700)
end sub
