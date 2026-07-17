sub init()
    m.focusBorder = invalid
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    m.titleLabel = m.top.findNode("titleLabel")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyFocusVisual()
    ApplyTitleVisual()
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
        skColors = CardHomeCardSkeletonColors()
        CardApplySkeleton(m.skeleton, skColors.base, skColors.highlight)
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
    end if
    ApplyFocusVisual()
    ApplyTitleVisual()
end sub

sub ApplyFocusVisual()
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 0, 0, 546, 318, m.top.cPrimary500)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub

sub ApplyTitleVisual()
    if m.titleLabel = invalid then return
    ' Avoid `= true` — SceneGraph boolean fields can fail strict compare on some builds.
    show = false
    if m.top.displayTitle and m.top.cardTitle <> "" then show = true
    m.titleLabel.visible = show
    if not show then return
    m.titleLabel.text = m.top.cardTitle
    ' React: text-neutral-400 idle / text-primary-500 focused.
    if m.top.focusedState then
        m.titleLabel.color = m.top.cPrimary500
    else
        c = m.top.cNeutral400
        if c = invalid or c = "" then c = "0xa3a3a3ff"
        m.titleLabel.color = c
    end if
end sub
