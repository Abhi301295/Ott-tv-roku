' Shared focus ring + poster load handling for home card widgets.

' CW progress track + card placeholder — parity with continueWatchCard.tsx bg-neutral-950 /
' bg-neutral-700. React's Tailwind neutral-950 is NOT overridden by API tertiary (stays
' #0a0a0a). Roku must not use theme neutral-900/950 here: those are shades of
' portalTertiaryColor (red sidebar → red progress track / red card fill).
function CardProgressTrackColor() as string
    return "0x0a0a0aff"
end function

function CardThumbPlaceholderBg() as string
    ' React verticalCard.tsx animate-pulse bg-neutral-800 (#262626).
    return "0x262626ff"
end function

function CardBrandingLogoUrl(fromNode as object) as string
    if fromNode = invalid then return ""
    scene = fromNode.getScene()
    if scene = invalid then return ""
    tm = scene.findNode("themeManager")
    if tm = invalid then return ""
    if tm.brandingLogo <> invalid and tm.brandingLogo <> "" then return tm.brandingLogo
    return ""
end function

function CardThumbFallbackFillColor(card as object) as string
    if card <> invalid and card.hasField("cNeutral800") then
        c = card.cNeutral800
        if c <> invalid and c <> "" then return c
    end if
    return CardThumbPlaceholderBg()
end function

function CardResolveThumbSize(poster as object, posterW as integer, posterH as integer) as object
    w = posterW
    h = posterH
    if w <= 0 and poster <> invalid then w = poster.width
    if h <= 0 and poster <> invalid then h = poster.height
    if w <= 0 then w = 220
    if h <= 0 then h = 300
    return [w, h]
end function

sub CardLayoutThumbFallbackNodes(fallback as object, fallbackLogo as object, w as integer, h as integer)
    if fallback <> invalid then
        fallback.width = w
        fallback.height = h
        fallback.translation = [0, 0]
    end if
    if fallbackLogo = invalid then return
    logoW = Int(w * 0.42 + 0.5)
    logoH = Int(h * 0.42 + 0.5)
    if logoW < 40 then logoW = 40
    if logoH < 40 then logoH = 40
    fallbackLogo.width = logoW
    fallbackLogo.height = logoH
    fallbackLogo.translation = [Int((w - logoW) / 2), Int((h - logoH) / 2)]
    fallbackLogo.loadDisplayMode = "scaleToFit"
    fallbackLogo.opacity = 0.35
end sub

sub CardHideThumbPlaceholder(poster as object, skeleton as object, fallback as object, fallbackLogo as object)
    if skeleton <> invalid then
        skeleton.running = false
        skeleton.visible = false
    end if
    if fallback <> invalid then fallback.visible = false
    if fallbackLogo <> invalid then fallbackLogo.visible = false
end sub

' Terminal missing/broken poster — neutral-800 tile with optional portal logo watermark.
' ⚠ Parity Note: React verticalCard.tsx keeps animate-pulse shimmer on onError; Roku
' shows this branded placeholder instead of an infinite skeleton.
sub CardApplyThumbPlaceholder(poster as object, skeleton as object, fallback as object, fallbackLogo as object, cardNode as object, posterW as integer, posterH as integer)
    size = CardResolveThumbSize(poster, posterW, posterH)
    w = size[0]
    h = size[1]
    if poster <> invalid then poster.visible = false
    if skeleton <> invalid then
        skeleton.running = false
        skeleton.visible = false
    end if
    if fallback <> invalid then
        fallback.color = CardThumbFallbackFillColor(cardNode)
        CardLayoutThumbFallbackNodes(fallback, fallbackLogo, w, h)
        fallback.visible = true
    end if
    if fallbackLogo <> invalid then
        logoUrl = CardBrandingLogoUrl(cardNode)
        if logoUrl <> "" then
            fallbackLogo.uri = logoUrl
            fallbackLogo.visible = true
        else
            fallbackLogo.visible = false
        end if
    end if
end sub

function CardSkeletonBaseColor() as string
    return "0x404040ff"
end function

function CardSkeletonHighlightColor() as string
    return "0x525252ff"
end function

' Skeleton shimmer — colors from source/lib/theme/SkeletonConfig.brs (login excluded).

function SkeletonDefaultPageBg() as string
    return SK_DefaultPageBg()
end function

function SkeletonColorsForPage(pageBg as string, tokens as object) as object
    colors = SkeletonResolveColors(tokens)
    if pageBg = invalid or pageBg = "" then return colors
    safe = CardContrastSkeletonBase(pageBg, colors.base)
    if safe <> colors.base then
        colors.base = safe
        if CardAvgLum(colors.highlight) <= CardAvgLum(colors.base) then
            colors.highlight = CardLightenHex(colors.base, 56)
        end if
    end if
    return colors
end function

sub SkeletonApply(node as object, tokens as object, running as boolean, pageBg = "" as string)
    if node = invalid then return
    colors = SkeletonColorsForPage(pageBg, tokens)
    CardApplySkeleton(node, colors.base, colors.highlight)
    if node.hasField("running") then node.running = running
end sub

sub SkeletonApplyTree(node as object, tokens as object, running as boolean, pageBg = "" as string)
    colors = SkeletonColorsForPage(pageBg, tokens)
    CardApplySkeletonTree(node, colors.base, colors.highlight, running)
end sub

sub CardApplySkeletonFromConfig(skeleton as object, tokens as object, running = false as boolean)
    if skeleton = invalid then return
    colors = SkeletonResolveColors(tokens)
    CardApplySkeleton(skeleton, colors.base, colors.highlight)
    if running and skeleton.hasField("running") then skeleton.running = true
end sub

' Same theme token map as Profile / Detail — never per-card color overrides.
function CardSkeletonThemeTokens(fromNode as object) as object
    tm = invalid
    if fromNode <> invalid then
        scene = fromNode.getScene()
        if scene <> invalid then tm = scene.findNode("themeManager")
    end if
    if tm <> invalid and tm.themeTokens <> invalid then return tm.themeTokens
    return {}
end function

' Lazily create a card's focus frame only when it is first needed (i.e. the card becomes
' focused), instead of building all 9 frame nodes for every card up-front. During a row's
' build burst no card is focused, so this removes the single biggest per-card node cost from
' the hot path; the frame is created once on first focus and reused thereafter. Appearance is
' identical to the previous XML-declared frame.
function CardEnsureFocusFrame(card as object, existing as object, offX as float, offY as float, w as float, h as float, color as string) as object
    if card = invalid then return invalid
    frame = existing
    if frame = invalid then frame = card.createChild("FocusFrame")
    frame.translation = [offX, offY]
    frame.boxWidth = w
    frame.boxHeight = h
    if color <> invalid and color <> "" then frame.color = color
    return frame
end function

' Parse a "0xRRGGBBAA" (or "0xRRGGBB") color string into [r, g, b] (0-255).
function CardHexToRgb(hex as string) as object
    if hex = invalid or hex = "" then return [0, 0, 0]
    s = hex
    if Left(s, 2) = "0x" or Left(s, 2) = "0X" then s = Mid(s, 3)
    if Len(s) < 6 then return [0, 0, 0]
    r = CardHexByte(Mid(s, 1, 2))
    g = CardHexByte(Mid(s, 3, 2))
    b = CardHexByte(Mid(s, 5, 2))
    return [r, g, b]
end function

function CardHexByte(h as string) as integer
    v = 0
    for i = 1 to Len(h)
        v = v * 16 + CardHexDigit(Mid(h, i, 1))
    end for
    if v < 0 then v = 0
    if v > 255 then v = 255
    return v
end function

function CardHexDigit(c as string) as integer
    u = UCase(c)
    if u >= "0" and u <= "9" then return Asc(u) - Asc("0")
    if u >= "A" and u <= "F" then return 10 + Asc(u) - Asc("A")
    return 0
end function

' Build "0xRRGGBBff" from r,g,b (0-255), fully opaque.
function CardRgbToHex(r as integer, g as integer, b as integer) as string
    return "0x" + CardByteHex(r) + CardByteHex(g) + CardByteHex(b) + "ff"
end function

function CardByteHex(v as integer) as string
    if v < 0 then v = 0
    if v > 255 then v = 255
    digits = "0123456789abcdef"
    hi = (v \ 16)
    lo = (v MOD 16)
    return Mid(digits, hi + 1, 1) + Mid(digits, lo + 1, 1)
end function

sub CardApplyFocusBorder(border as object, focused as boolean, color as string)
    if border = invalid then return
    border.visible = focused
    if focused and color <> invalid and color <> "" then
        ' The focus frame is a tintable 9-patch Poster (rounded, even border) — tint it via
        ' blendColor. Fall back to .color for any legacy Rectangle border.
        if border.hasField("blendColor") then
            border.blendColor = color
        else if border.hasField("color") then
            border.color = color
        end if
    end if
end sub

sub CardOnPosterLoad(poster as object, skeleton as object, fallback = invalid as object, fallbackLogo = invalid as object, cardNode = invalid as object, posterW = 0 as integer, posterH = 0 as integer)
    if poster = invalid then return
    status = poster.loadStatus
    if status = "ready" then
        CardHideThumbPlaceholder(poster, skeleton, fallback, fallbackLogo)
        poster.visible = true
    else if status = "failed" then
        if fallback <> invalid then
            CardApplyThumbPlaceholder(poster, skeleton, fallback, fallbackLogo, cardNode, posterW, posterH)
        else
            if skeleton <> invalid then
                skeleton.running = false
                skeleton.visible = false
            end if
            poster.visible = false
        end if
    end if
end sub

' object-cover parity — decode at native aspect, zoom-crop into w×h (never set both load dims).
sub CardApplyPosterCover(poster as object, clip as object, w as integer, h as integer)
    if poster = invalid then return
    if clip <> invalid then
        clip.clippingRect = [0, 0, w, h]
        clip.clippingRectClipsChildren = true
    end if
    poster.width = w
    poster.height = h
    poster.loadDisplayMode = "scaleToZoom"
    poster.loadWidth = 0
    poster.loadHeight = 0
end sub

sub CardInjectTheme(card as object, primary500 as string, primary600 as string, primary700 as string, neutral50 as string, neutral800 as string, neutral700 = "" as string, pageBg = "" as string)
    if card = invalid then return
    if card.hasField("cPrimary500") then card.cPrimary500 = primary500
    if card.hasField("cPrimary600") then card.cPrimary600 = primary600
    if card.hasField("cPrimary700") then card.cPrimary700 = primary700
    if card.hasField("cNeutral50") then card.cNeutral50 = neutral50
    if card.hasField("cNeutral800") then card.cNeutral800 = neutral800
    if neutral700 <> "" and card.hasField("cNeutral700") then card.cNeutral700 = neutral700
    if pageBg <> "" and card.hasField("cPageBg") then card.cPageBg = pageBg
end sub

' Placeholder shimmer — parity with React bg-neutral-700 / neutral-800 pulse.
sub CardApplySkeleton(skeleton as object, neutral700 as string, neutral800 as string)
    if skeleton = invalid then return
    base = neutral700
    highlight = neutral800
    if base = invalid or base = "" then base = "0x404040ff"
    if highlight = invalid or highlight = "" then highlight = "0x262626ff"
    if CardAvgLum(highlight) <= CardAvgLum(base) then highlight = CardLightenHex(base, 56)
    skeleton.baseColor = base
    skeleton.highlightColor = highlight
    ' Shimmer the card placeholder while its thumbnail loads (it stops itself on load),
    ' so a loading row reads as an intentional shimmer, not flat grey boxes.
    if skeleton.hasField("animate") then skeleton.animate = true
end sub

function CardLightenHex(hex as string, amount as integer) as string
    rgb = CardHexToRgb(hex)
    r = rgb[0] + amount
    g = rgb[1] + amount
    b = rgb[2] + amount
    if r > 255 then r = 255
    if g > 255 then g = 255
    if b > 255 then b = 255
    return CardRgbToHex(r, g, b)
end function

function CardAvgLum(hex as string) as integer
    rgb = CardHexToRgb(hex)
    return Int((rgb[0] + rgb[1] + rgb[2]) / 3)
end function

' Pick a skeleton base that contrasts the screen fill when brand tokens resolve near-white.
function CardContrastSkeletonBase(bg as string, candidate as string) as string
    if bg = invalid or bg = "" then bg = "0x121212ff"
    if candidate = invalid or candidate = "" then candidate = "0x404040ff"
    bgL = CardAvgLum(bg)
    cL = CardAvgLum(candidate)
    if bgL > 160 then
        if cL > 120 then return "0x404040ff"
    else if cL > 160 then
        return "0x404040ff"
    end if
    return candidate
end function

sub CardApplySkeletonTree(node as object, base as string, hi as string, running as boolean)
    if node = invalid then return
    if node.hasField("running") and node.hasField("baseColor") then
        CardApplySkeleton(node, base, hi)
        node.running = running
        return
    end if
    for each child in node.getChildren(-1, 0)
        CardApplySkeletonTree(child, base, hi, running)
    end for
end sub

sub CardDetachMediaObservers(card as object)
    if card = invalid then return
    if card.hasField("loaded") then card.unobserveField("loaded")
    thumb = card.findNode("thumb")
    if thumb <> invalid then thumb.unobserveField("loadStatus")
end sub

' ── Sim-safe rounded thumbs (parity search cards) ─────────────────────────────
' Stack: full-rect Poster → overlays → 4× card_corner_{tl,tr,bl,br}.png with page bg
' baked in (gen_card_assets.py — blendColor is unreliable for corner nubs in sim).
' Focus: card_focus_ring_{w}x{h}.png inset 3px, tinted via blendColor — NOT FocusFrame.

function CardThumbCornerRadius() as integer
    return 10
end function

function CardFocusBorderW() as integer
    return 3
end function

function CardDefaultPageBg() as string
    return "0x0a0a0aff"
end function

function CardCornerUri(quadrant as string) as string
    return "pkg:/images/ui/card_corner_" + quadrant + ".png"
end function

function CardFocusRingUri(w as integer, h as integer) as string
    return "pkg:/images/ui/card_focus_ring_" + Stri(w).Trim() + "x" + Stri(h).Trim() + ".png"
end function

function CardPageBgColor(card as object) as string
    if card = invalid then return CardDefaultPageBg()
    if card.hasField("cPageBg") then
        bg = card.cPageBg
        if bg <> invalid and bg <> "" then return bg
    end if
    return CardDefaultPageBg()
end function

sub CardLayoutCornerPoster(node as object, quadrant as string, x as integer, y as integer, r as integer)
    if node = invalid then return
    node.uri = CardCornerUri(quadrant)
    node.width = r
    node.height = r
    node.translation = [x, y]
    node.loadDisplayMode = "scaleToFill"
    node.visible = true
end sub

sub CardTintCornerNodes(tl as object, tr as object, bl as object, br as object, pageBg as string)
    ' Corner PNGs ship with CardDefaultPageBg() baked in — no runtime tint.
end sub

sub CardLayoutThumbCorners(tl as object, tr as object, bl as object, br as object, w as integer, h as integer, pageBg as string)
    r = CardThumbCornerRadius()
    CardLayoutCornerPoster(tl, "tl", 0, 0, r)
    CardLayoutCornerPoster(tr, "tr", w - r, 0, r)
    CardLayoutCornerPoster(bl, "bl", 0, h - r, r)
    CardLayoutCornerPoster(br, "br", w - r, h - r, r)
    CardTintCornerNodes(tl, tr, bl, br, pageBg)
end sub

sub CardLayoutInsetFocusRing(ring as object, w as integer, h as integer)
    if ring = invalid then return
    ring.uri = CardFocusRingUri(w, h)
    ring.width = w
    ring.height = h
    ring.loadDisplayMode = "scaleToFill"
end sub

sub CardApplyInsetFocusRing(ring as object, host as object, focused as boolean, color as string)
    if ring = invalid then return
    ring.visible = focused
    if not focused then return
    if color <> invalid and color <> "" then ring.blendColor = color
    if host <> invalid then
        host.removeChild(ring)
        host.appendChild(ring)
    end if
end sub
