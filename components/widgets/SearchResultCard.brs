sub init()
    m.thumbBlock = m.top.findNode("thumbBlock")
    m.thumbWrap = m.top.findNode("thumbWrap")
    m.thumb = m.top.findNode("thumb")
    m.grad = m.top.findNode("grad")
    m.cornerTL = m.top.findNode("cornerTL")
    m.cornerTR = m.top.findNode("cornerTR")
    m.cornerBL = m.top.findNode("cornerBL")
    m.cornerBR = m.top.findNode("cornerBR")
    m.focusRing = m.top.findNode("focusRing")
    m.titleLbl = m.top.findNode("titleLbl")
    m.scaleAnim = m.top.findNode("scaleAnim")
    m.scaleInterp = m.top.findNode("scaleInterp")
    m.thumbScale = 1.0
    if m.scaleAnim <> invalid then m.scaleAnim.duration = SR_CardFocusAnimDuration()
    if m.thumb <> invalid then m.thumb.observeField("loadStatus", "OnThumbLoad")
    LayoutCard()
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyFocus()
end sub

sub OnThemeChanged()
    ApplyCornerColors()
    ApplyFocus()
end sub

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, invalid)
end sub

function PageBgColor() as string
    bg = m.top.cPageBg
    if bg = invalid or bg = "" then return SR_PinPageBg()
    return bg
end function

sub ApplyCornerColors()
    bg = PageBgColor()
    if m.cornerTL <> invalid then m.cornerTL.blendColor = bg
    if m.cornerTR <> invalid then m.cornerTR.blendColor = bg
    if m.cornerBL <> invalid then m.cornerBL.blendColor = bg
    if m.cornerBR <> invalid then m.cornerBR.blendColor = bg
end sub

sub LayoutCard()
    w = SR_CardW()
    h = SR_CardH()
    r = SR_CardCornerRadius()
    pad = SR_CardTitleMarginTop()

    if m.thumbBlock <> invalid then m.thumbBlock.translation = [0, pad]
    if m.thumbWrap <> invalid then m.thumbWrap.scaleRotateCenter = [w / 2, h / 2]

    if m.thumb <> invalid then
        m.thumb.width = w
        m.thumb.height = h
        m.thumb.loadDisplayMode = "scaleToZoom"
        m.thumb.loadWidth = 0
        m.thumb.loadHeight = 0
    end if
    if m.grad <> invalid then
        m.grad.width = w
        m.grad.height = h
    end if

    LayoutCorner(m.cornerTL, "tl", 0, 0, r)
    LayoutCorner(m.cornerTR, "tr", w - r, 0, r)
    LayoutCorner(m.cornerBL, "bl", 0, h - r, r)
    LayoutCorner(m.cornerBR, "br", w - r, h - r, r)
    ApplyCornerColors()

    if m.focusRing <> invalid then
        m.focusRing.uri = SR_CardFocusRingUri()
        m.focusRing.width = w
        m.focusRing.height = h
    end if

    if m.titleLbl <> invalid then
        m.titleLbl.translation = [0, pad + h + pad]
        m.titleLbl.width = SR_CardTitleMaxW()
        m.titleLbl.height = SR_CardTitleH()
        f = CreateObject("roSGNode", "Font")
        f.uri = "pkg:/fonts/Inter-Medium.ttf"
        f.size = SR_CardTitleFontSize()
        m.titleLbl.font = f
    end if
end sub

sub LayoutCorner(node as object, quadrant as string, x as integer, y as integer, r as integer)
    if node = invalid then return
    node.uri = SR_CardCornerUri(quadrant)
    node.width = r
    node.height = r
    node.translation = [x, y]
    node.visible = true
end sub

sub ApplyAll()
    LayoutCard()
    if m.titleLbl <> invalid and m.top.title <> invalid then m.titleLbl.text = m.top.title
    uri = m.top.thumbnailUri
    if m.thumb <> invalid then
        if uri <> invalid and uri <> "" then
            m.thumb.uri = uri
            m.thumb.visible = true
        else
            m.thumb.uri = ""
            m.thumb.visible = false
        end if
    end if
    ApplyFocus()
end sub

sub ApplyFocus()
    focused = m.top.focusedState = true
    target = 1.0
    if focused then target = SR_CardFocusScale()
    AnimateThumbScale(target)

    if m.focusRing <> invalid then
        m.focusRing.visible = focused
        if focused then
            color = m.top.cPrimary700
            if color = invalid or color = "" then color = SR_PinPrimary700()
            m.focusRing.blendColor = color
            m.thumbWrap.removeChild(m.focusRing)
            m.thumbWrap.appendChild(m.focusRing)
        end if
    end if

    if m.titleLbl <> invalid then
        if focused then
            m.titleLbl.color = m.top.cPrimary700
        else
            m.titleLbl.color = m.top.cNeutral50
        end if
    end if
end sub

sub AnimateThumbScale(target as float)
    if m.thumbWrap = invalid then return
    cur = m.thumbScale
    if cur = invalid then cur = 1.0
    if Abs(cur - target) < 0.01 then return
    m.thumbScale = target
    interp = m.scaleInterp
    anim = m.scaleAnim
    if interp = invalid or anim = invalid then
        m.thumbWrap.scale = [target, target]
        return
    end if
    interp.keyValue = [[cur, cur], [target, target]]
    anim.control = "start"
end sub
