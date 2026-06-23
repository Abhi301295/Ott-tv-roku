sub init()
    m.focusBorder = m.top.findNode("focusBorder")
    m.fallback = m.top.findNode("fallback")
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
    CardOnPosterLoad(m.thumb, m.skeleton)
    if m.thumb.loadStatus = "failed" then
        m.fallback.visible = true
        m.titleLabel.visible = true
    end if
end sub

sub ApplyAll()
    m.titleLabel.text = m.top.title
    m.titleLabel.color = m.top.cNeutral50
    m.fallback.color = m.top.cNeutral800
    CardApplySkeletonFromConfig(m.skeleton, CardSkeletonThemeTokens(m.top), true)

    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
        m.fallback.visible = false
        m.titleLabel.visible = true
    else
        m.thumb.visible = false
        m.skeleton.visible = false
        m.fallback.visible = true
        m.titleLabel.visible = true
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary700)
end sub
