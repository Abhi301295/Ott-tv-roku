sub init()
    m.focusBorder = invalid
    m.body = m.top.findNode("body")
    m.thumbClip = m.top.findNode("thumbClip")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
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

function ThumbW() as integer
    if m.top.listType = true then return 272
    return 240
end function

function ThumbH() as integer
    if m.top.listType = true then return 340
    return 300
end function

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, ThumbW(), ThumbH())
end sub

sub ApplyAll()
    w = ThumbW()
    h = ThumbH()
    m.focusW = w + 6
    m.focusH = h + 6
    m.skeleton.boxWidth = w
    m.skeleton.boxHeight = h
    if m.skeleton.hasField("shapeUri") then
        m.skeleton.shapeUri = CardVerticalSkeletonShapeUri(w, h)
    end if
    CardApplyPosterCover(m.thumb, m.thumbClip, w, h)
    if m.veil <> invalid then
        m.veil.width = w
        m.veil.height = h
    end if
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
        status = m.thumb.loadStatus
        ' Parity verticalCard.tsx / seriesCard.tsx — pulse until onLoad; poster stays hidden.
        if status = "ready" or status = "failed" then
            CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, w, h)
        else
            ShowThumbLoading()
        end if
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, w, h)
    end if
    ApplyFocusVisual()
end sub

sub ShowThumbLoading()
    if m.thumb <> invalid then m.thumb.visible = false
    if m.thumbFallback <> invalid then m.thumbFallback.visible = false
    if m.thumbFallbackLogo <> invalid then m.thumbFallbackLogo.visible = false
    if m.skeleton <> invalid then
        m.skeleton.visible = true
        m.skeleton.running = true
        CardApplyHomeCardSkeleton(m.skeleton, true)
    end if
end sub

sub ApplyFocusVisual()
    border = 3
    pad = 2
    offX = 0
    offY = 0
    radius = 16
    w = ThumbW()
    h = ThumbH()
    if m.top.listType = true then
        offX = -border
        offY = -border
    end if
    if m.body <> invalid then m.body.translation = [pad, pad]
    fw = w + 2 * pad + 2 * border
    fh = h + 2 * pad + 2 * border
    if not m.top.listType then
        fw = w + 6
        fh = h + 6
    end if
    m.focusW = fw
    m.focusH = fh
    if m.top.focusedState = true then
        m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, offX, offY, fw, fh, m.top.cPrimary500)
        if m.focusBorder <> invalid and m.top.listType = true then
            m.focusBorder.radius = radius
            m.focusBorder.thickness = border
        end if
    else if m.focusBorder <> invalid then
        m.focusBorder.boxWidth = fw
        m.focusBorder.boxHeight = fh
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
    if m.top.focusedState = true and m.focusBorder <> invalid and m.top.listType = true then
        m.top.removeChild(m.focusBorder)
        m.top.appendChild(m.focusBorder)
    end if
end sub
