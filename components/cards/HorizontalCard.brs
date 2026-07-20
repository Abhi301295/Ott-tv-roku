sub init()
    m.focusBorder = invalid
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    m.titleLabel = m.top.findNode("titleLabel")
    m.titleSkeleton = m.top.findNode("titleSkeleton")
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
    status = ""
    if m.thumb <> invalid then status = m.thumb.loadStatus
    if status = "ready" then
        CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
    else if status = "failed" then
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
    end if
    ApplyTitleVisual()
end sub

sub ApplyAll()
    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        status = m.thumb.loadStatus
        if status = "ready" then
            CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 312)
        else
            if m.thumb <> invalid then m.thumb.visible = false
            if m.skeleton <> invalid then
                m.skeleton.visible = true
                m.skeleton.running = true
                skColors = CardHomeCardSkeletonColors()
                CardApplySkeleton(m.skeleton, skColors.base, skColors.highlight)
            end if
        end if
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

sub HideTitleSkeleton()
    if m.titleSkeleton = invalid then return
    m.titleSkeleton.running = false
    m.titleSkeleton.visible = false
end sub

' React: title text is ready with the card data; only the poster waits on load.
' Reveal title first, then poster paints when ready (or placeholder settles).
sub ApplyTitleVisual()
    if m.titleLabel = invalid then return
    HideTitleSkeleton()
    wantTitle = false
    if m.top.displayTitle then wantTitle = true
    show = false
    if wantTitle and m.top.cardTitle <> "" then show = true
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
