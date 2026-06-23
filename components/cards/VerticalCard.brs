sub init()
    m.focusBorder = invalid
    m.thumbClip = m.top.findNode("thumbClip")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.veil = m.top.findNode("veil")
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
    ' Content vertical card is 220×300 (parity with verticalCard.tsx w-240 token = 220px);
    ' the list variant is 272×340.
    w = 220
    h = 300
    if m.top.listType = true then
        w = 272
        h = 340
    end if
    m.focusW = w + 6
    m.focusH = h + 6
    m.skeleton.boxWidth = w
    m.skeleton.boxHeight = h
    CardApplyPosterCover(m.thumb, m.thumbClip, w, h)
    if m.veil <> invalid then
        m.veil.width = w
        m.veil.height = h
    end if
    ' Corner covers are baked for each card size (radius-10).
    tl = m.top.findNode("cornerTL")
    tr = m.top.findNode("cornerTR")
    bl = m.top.findNode("cornerBL")
    br = m.top.findNode("cornerBR")
    if tl <> invalid then tl.translation = [0, 0]
    if tr <> invalid then tr.translation = [w - 10, 0]
    if bl <> invalid then bl.translation = [0, h - 10]
    if br <> invalid then br.translation = [w - 10, h - 10]

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
    CardApplySkeletonFromConfig(m.skeleton, CardSkeletonThemeTokens(m.top), true)
    ApplyFocusVisual()
end sub

sub ApplyFocusVisual()
    fw = 226
    fh = 306
    if m.focusW <> invalid then fw = m.focusW
    if m.focusH <> invalid then fh = m.focusH
    if m.top.focusedState = true then
        m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 0, 0, fw, fh, m.top.cPrimary500)
    else if m.focusBorder <> invalid then
        m.focusBorder.boxWidth = fw
        m.focusBorder.boxHeight = fh
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
