sub init()
    m.focusBorder = invalid
    m.body = m.top.findNode("body")
    m.thumbClip = m.top.findNode("thumbClip")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.veil = m.top.findNode("veil")
    m.titleLabel = m.top.findNode("titleLabel")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    m.lastThumbnailUri = ""
    m.skeletonDwellStarted = false
    m.skeletonDwellComplete = false
    m.thumbRevealTimer = CreateObject("roSGNode", "Timer")
    ' ⚠ Parity Note: React's transition-opacity duration-300 gives the loading placeholder
    ' a render window; cached Roku Posters can become ready before SceneGraph paints once.
    m.thumbRevealTimer.duration = 0.3
    m.thumbRevealTimer.repeat = false
    m.top.appendChild(m.thumbRevealTimer)
    m.thumbRevealTimer.observeField("fire", "OnThumbRevealTimer")
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

function ThumbW() as integer
    if m.top.listType = true then return 272
    return 240
end function

function ThumbH() as integer
    if m.top.listType = true then return 340
    return 300
end function

sub OnThumbLoad()
    if m.thumb.loadStatus = "failed" then
        ShowThumbLoading()
        return
    end if
    if m.thumb.loadStatus = "ready" and m.skeletonDwellComplete then RevealThumb()
end sub

sub OnThumbRevealTimer()
    m.skeletonDwellComplete = true
    if m.thumb <> invalid and m.thumb.loadStatus = "ready" then RevealThumb()
end sub

sub RevealThumb()
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
    if uri <> m.lastThumbnailUri then
        m.lastThumbnailUri = uri
        m.skeletonDwellStarted = false
        m.skeletonDwellComplete = false
        if m.thumbRevealTimer <> invalid then m.thumbRevealTimer.control = "stop"
    end if
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        status = m.thumb.loadStatus
        ' React sets loaded only from onLoad; loading, failed, and missing posters retain
        ' the bg-white/10 animate-pulse card skeleton.
        if status = "ready" and m.skeletonDwellComplete then
            RevealThumb()
        else
            ShowThumbLoading()
        end if
    else
        ShowThumbLoading()
    end if
    ApplyFocusVisual()
    ApplyTitleVisual()
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
    if not m.skeletonDwellStarted then
        m.skeletonDwellStarted = true
        if m.thumbRevealTimer <> invalid then m.thumbRevealTimer.control = "start"
    end if
end sub

sub ApplyTitleVisual()
    if m.titleLabel = invalid then return
    show = (m.top.displayTitle = true and m.top.cardTitle <> "")
    m.titleLabel.visible = show
    if not show then return
    m.titleLabel.text = m.top.cardTitle
    w = ThumbW()
    m.titleLabel.width = w
    m.titleLabel.translation = [3, ThumbH() + 8]
    if m.top.focusedState = true then
        m.titleLabel.color = m.top.cPrimary500
    else
        m.titleLabel.color = m.top.cNeutral400
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
