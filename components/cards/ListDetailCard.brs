' ListDetailCard.brs — parity with features/list-detail/listDetailCard.tsx

function LD_ThumbW() as integer
    return 368
end function

function LD_ThumbH() as integer
    return 208
end function

function LD_CardPad() as integer
    return 5
end function

function LD_CardBorder() as integer
    return 3
end function

function LD_CardFocusRadius() as integer
    return 16
end function

function LD_CardW() as integer
    return LD_ThumbW()
end function

function LD_CardH() as integer
    return LD_ThumbH() + LD_TitleMarginTop() + LD_TitleLineH() + LD_TitleMarginBottom() + 5 + 22 + 10
end function

function LD_CardOuterW() as integer
    return LD_CardW() + 2 * LD_CardPad()
end function

function LD_CardOuterH() as integer
    return LD_CardH() + 2 * LD_CardPad()
end function

function LD_TitleFontSize() as integer
    ' React fs-28 @ FontScale LARGE (1.75 * 1.2 * 16 ≈ 34).
    return 34
end function

function LD_TitleLineH() as integer
    ' React lh-32 (2rem @ 16px).
    return 32
end function

function LD_TitleMaxW() as integer
    ' React max-w-[370px].
    return 370
end function

function LD_TitleMarginTop() as integer
    ' React m-t-24.
    return 24
end function

function LD_TitleMarginBottom() as integer
    ' React m-b-4.
    return 4
end function

function LD_TypeFontSize() as integer
    return 18
end function

function LD_LangFontSize() as integer
    return 14
end function

function LD_MetaDotSize() as integer
    return 10
end function

function LD_MetaDotUri() as string
    return "pkg:/images/ui/sk_detail_dot.png"
end function

function LD_TypeLabelWidth(typeText as string) as integer
    if typeText = invalid or typeText = "" then return 72
    w = Len(typeText) * Int(LD_TypeFontSize() * 0.62) + 8
    if w < 72 then w = 72
    if w > 140 then w = 140
    return w
end function

sub init()
    m.contentHost = m.top.findNode("contentHost")
    m.thumbBlock = m.top.findNode("thumbBlock")
    m.thumbSkel = m.top.findNode("thumbSkel")
    m.thumbFallback = m.top.findNode("thumbFallback")
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.thumb = m.top.findNode("thumb")
    m.grad = m.top.findNode("grad")
    m.titleSkelHost = m.top.findNode("titleSkelHost")
    m.titleSkel = m.top.findNode("titleSkel")
    m.titleLbl = m.top.findNode("titleLbl")
    m.metaSkelHost = m.top.findNode("metaSkelHost")
    m.typeSkel = m.top.findNode("typeSkel")
    m.dotSkel = m.top.findNode("dotSkel")
    m.langSkel = m.top.findNode("langSkel")
    m.metaHost = m.top.findNode("metaHost")
    m.typeLbl = m.top.findNode("typeLbl")
    m.metaDot = m.top.findNode("metaDot")
    m.langLbl = m.top.findNode("langLbl")
    m.focusBorder = invalid
    if m.thumb <> invalid then m.thumb.observeField("loadStatus", "OnThumbLoad")
    LayoutCard()
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyFocusVisual()
end sub

sub OnThemeChanged()
    LayoutCard()
    ApplyAll()
end sub

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, m.thumbSkel, m.thumbFallback, m.thumbFallbackLogo, m.top, LD_ThumbW(), LD_ThumbH())
    SyncThumbOverlay()
end sub

sub SyncThumbOverlay()
    showPoster = false
    if m.thumb <> invalid and m.thumb.visible = true and m.thumb.loadStatus = "ready" then showPoster = true
    if m.grad <> invalid then m.grad.visible = showPoster
end sub

sub LayoutCard()
    pad = LD_CardPad()
    textX = pad + 5
    tw = LD_ThumbW()
    th = LD_ThumbH()

    if m.contentHost <> invalid then m.contentHost.translation = [0, 0]

    if m.thumbBlock <> invalid then m.thumbBlock.translation = [pad, pad]
    if m.thumbSkel <> invalid then
        m.thumbSkel.boxWidth = tw
        m.thumbSkel.boxHeight = th
    end if
    CardApplyPosterCover(m.thumb, invalid, tw, th)
    if m.grad <> invalid then
        m.grad.width = tw
        m.grad.height = th
    end if
    CardLayoutThumbFallbackNodes(m.thumbFallback, m.thumbFallbackLogo, tw, th)

    titleY = pad + th + LD_TitleMarginTop()
    if m.titleSkelHost <> invalid then m.titleSkelHost.translation = [textX, titleY]
    if m.titleSkel <> invalid then
        m.titleSkel.boxWidth = Int(LD_TitleMaxW() * 0.85)
        m.titleSkel.boxHeight = LD_TitleLineH() + 1
    end if
    ApplyTitleLabel(textX, titleY)

    metaY = titleY + LD_TitleLineH() + LD_TitleMarginBottom() + 5
    if m.metaSkelHost <> invalid then m.metaSkelHost.translation = [textX, metaY]
    if m.metaHost <> invalid then m.metaHost.translation = [textX, metaY]
    LayoutMetaRow()
end sub

sub ApplyTitleLabel(x as integer, y as integer)
    if m.titleLbl = invalid then return
    m.titleLbl.translation = [x, y]
    m.titleLbl.width = LD_TitleMaxW()
    m.titleLbl.height = LD_TitleLineH()
    m.titleLbl.wrap = false
    m.titleLbl.ellipsizeOnBoundary = true
    m.titleLbl.horizAlign = "left"
    m.titleLbl.vertAlign = "top"
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Inter-Bold.ttf"
    f.size = LD_TitleFontSize()
    m.titleLbl.font = f
    ' React text-neutral-50 fw-700 — apply color after font.
    c = m.top.cNeutral50
    if c = invalid or c = "" then c = "0xffffffff"
    m.titleLbl.color = c
end sub

sub LayoutMetaRow()
    dot = LD_MetaDotSize()
    typeText = ""
    if m.typeLbl <> invalid and m.typeLbl.text <> invalid then typeText = m.typeLbl.text
    typeW = LD_TypeLabelWidth(typeText)
    if m.typeLbl <> invalid then
        m.typeLbl.width = typeW
        m.typeLbl.height = 22
        f = CreateObject("roSGNode", "Font")
        f.uri = "pkg:/fonts/Inter-Bold.ttf"
        f.size = LD_TypeFontSize()
        m.typeLbl.font = f
    end if
    if m.metaDot <> invalid then
        m.metaDot.uri = LD_MetaDotUri()
        m.metaDot.loadDisplayMode = "scaleToFill"
        m.metaDot.translation = [typeW + 5, 5]
        m.metaDot.width = dot
        m.metaDot.height = dot
        if m.top.cPrimary500 <> invalid and m.top.cPrimary500 <> "" then
            m.metaDot.blendColor = m.top.cPrimary500
        end if
    end if
    if m.langLbl <> invalid then
        m.langLbl.translation = [typeW + 5 + dot + 5, 2]
        m.langLbl.width = 80
        m.langLbl.height = 18
        f = CreateObject("roSGNode", "Font")
        f.uri = "pkg:/fonts/Inter-Bold.ttf"
        f.size = LD_LangFontSize()
        m.langLbl.font = f
    end if
end sub

sub ApplyAll()
    LayoutCard()
    loading = false
    if m.top.isLoading = true then loading = true
    ApplySkeletonMode(loading)
    if not loading then ApplyContent()
    ApplyFocusVisual()
end sub

sub LD_ApplySkeleton(sk as object, running as boolean)
    if sk = invalid then return
    CardApplyHomeCardSkeleton(sk, running)
end sub

sub ApplySkeletonMode(loading as boolean)
    if loading then
        if m.thumbFallback <> invalid then m.thumbFallback.visible = false
        if m.thumbFallbackLogo <> invalid then m.thumbFallbackLogo.visible = false
        if m.thumbSkel <> invalid then
            m.thumbSkel.visible = true
            LD_ApplySkeleton(m.thumbSkel, true)
        end if
        if m.thumb <> invalid then m.thumb.visible = false
        if m.grad <> invalid then m.grad.visible = false
        if m.titleSkelHost <> invalid then m.titleSkelHost.visible = true
        if m.metaSkelHost <> invalid then m.metaSkelHost.visible = true
        if m.titleLbl <> invalid then m.titleLbl.visible = false
        if m.metaHost <> invalid then m.metaHost.visible = false
        LD_ApplySkeleton(m.titleSkel, true)
        LD_ApplySkeleton(m.typeSkel, true)
        LD_ApplySkeleton(m.dotSkel, true)
        LD_ApplySkeleton(m.langSkel, true)
    else
        if m.titleSkelHost <> invalid then m.titleSkelHost.visible = false
        if m.metaSkelHost <> invalid then m.metaSkelHost.visible = false
        if m.titleLbl <> invalid then m.titleLbl.visible = true
        if m.metaHost <> invalid then m.metaHost.visible = true
    end if
end sub

sub ApplyContent()
    if m.titleLbl <> invalid then
        t = m.top.title
        if t = invalid then t = ""
        m.titleLbl.text = t
        textX = LD_CardPad() + 5
        titleY = LD_CardPad() + LD_ThumbH() + LD_TitleMarginTop()
        ApplyTitleLabel(textX, titleY)
    end if

    typeText = FormatListContentType(m.top.contentType)
    lang = m.top.originalLang
    if lang = invalid then lang = ""

    if m.typeLbl <> invalid then
        m.typeLbl.text = typeText
        m.typeLbl.color = m.top.cPrimary500
    end if
    if m.metaDot <> invalid then
        m.metaDot.blendColor = m.top.cPrimary500
    end if
    if m.langLbl <> invalid then
        m.langLbl.text = lang
        m.langLbl.color = LangLabelColor(m.top.cNeutral50)
    end if
    LayoutMetaRow()
    ApplyThumbContent()
end sub

' Thumb: shimmer while the poster loads; neutral/logo placeholder only on missing URI or load failure.
sub ApplyThumbContent()
    uri = m.top.thumbnailUri
    tw = LD_ThumbW()
    th = LD_ThumbH()
    if m.thumb = invalid then return
    if uri = invalid or uri = "" then
        CardApplyThumbPlaceholder(m.thumb, m.thumbSkel, m.thumbFallback, m.thumbFallbackLogo, m.top, tw, th)
        SyncThumbOverlay()
        return
    end if
    CardHideThumbPlaceholder(m.thumb, m.thumbSkel, m.thumbFallback, m.thumbFallbackLogo)
    if m.thumbSkel <> invalid then
        m.thumbSkel.visible = true
        LD_ApplySkeleton(m.thumbSkel, true)
    end if
    m.thumb.visible = true
    m.thumb.uri = uri
    OnThumbLoad()
end sub

function FormatListContentType(contentType as string) as string
    if contentType = invalid or contentType = "" then return ""
    if contentType = "SERIES_AND_EPISODES" then return "Series"
    if contentType = "SINGLE_VIDEO" then return "Movies"
    return contentType
end function

function LangLabelColor(neutral50 as string) as string
    rgb = CardHexToRgb(neutral50)
    return "0x" + CardByteHex(rgb[0]) + CardByteHex(rgb[1]) + CardByteHex(rgb[2]) + "80"
end function

sub ApplyFocusVisual()
    border = LD_CardBorder()
    fw = LD_CardOuterW() + 2 * border
    fh = LD_CardOuterH() + 2 * border
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, -border, -border, fw, fh, m.top.cPrimary500)
    if m.focusBorder <> invalid then
        m.focusBorder.radius = LD_CardFocusRadius()
        m.focusBorder.thickness = border
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
    if m.top.focusedState = true and m.focusBorder <> invalid then
        m.top.removeChild(m.focusBorder)
        m.top.appendChild(m.focusBorder)
    end if
end sub
