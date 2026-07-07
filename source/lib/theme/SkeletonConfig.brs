' SkeletonConfig.brs — app-wide skeleton shimmer palette (edit here).
'
' Default matches React SkeletonBox / profile: primary-700 base + primary-500 highlight.
' Page/skeleton backdrop during loading matches React PageContainer + browse loaders: bg-black.
' Login QR placeholder is excluded — LoginScreen.brs keeps its own white skeleton.

function SK_LoadingPageBg() as string
    return "0x000000ff"
end function

function SK_BaseToken() as string
    return "primary-700"
end function

function SK_HighlightToken() as string
    return "primary-500"
end function

function SK_BaseFallbackHex() as string
    return "#04478b"
end function

function SK_HighlightFallbackHex() as string
    return "#0b75e0"
end function

function SkeletonBoxGlowPad() as integer
    ' gen_skeleton_masks.py: GLOW_BLUR(5) + 14 — matches CSS blur-radius 10px halo
    return 19
end function

function SkeletonProfileNameGlowPadX() as integer
    ' gen_skeleton_masks.py: PILL_GLOW_BLUR(12) + 28 — full left/right halo on 190px pill
    return 40
end function

function SkeletonProfileNameGlowPadY() as integer
    return 28
end function

function SkeletonGlowLayoutPads(glowUri as string) as object
    padX = SkeletonBoxGlowPad()
    padY = padX
    if glowUri = SkeletonProfileNameGlowUri() then
        padX = SkeletonProfileNameGlowPadX()
        padY = SkeletonProfileNameGlowPadY()
    end if
    return { padX: padX, padY: padY }
end function

sub LayoutSkeletonGlowPoster(glow as object, sk as object, glowUri as string, glowW as integer, glowH as integer)
    if glow = invalid or sk = invalid then return
    pads = SkeletonGlowLayoutPads(glowUri)
    tr = sk.translation
    glow.uri = glowUri
    glow.translation = [tr[0] - pads.padX, tr[1] - pads.padY]
    glow.width = glowW
    glow.height = glowH
    ApplySkeletonGlowPoster(glow)
end sub

function SkeletonBoxGlowColor() as string
    ' onboardingSkeleton.tsx hardcoded rgba(0, 146, 255, *) — not a theme token
    return "0x0092ffff"
end function

function SkeletonBoxGlowOpacity() as float
    return 0.4
end function

sub ApplySkeletonGlowPoster(glow as object)
    if glow = invalid then return
    glow.blendColor = SkeletonBoxGlowColor()
    glow.opacity = SkeletonBoxGlowOpacity()
    glow.loadDisplayMode = "scaleToFill"
end sub

function SkeletonBoxGlowOffsetY() as integer
    return 4
end function

function SkeletonProfileAvatarGlowUri(squareAvatars as boolean) as string
    if squareAvatars then return "pkg:/images/ui/sk_glow_rounded_150_r12.png"
    return "pkg:/images/ui/sk_glow_avatar_150.png"
end function

function SkeletonProfileNameGlowUri() as string
    return "pkg:/images/ui/sk_glow_pill_190x22.png"
end function

function SkeletonProfileAvatarGlowSize() as object
    pad = SkeletonBoxGlowPad()
    offY = SkeletonBoxGlowOffsetY()
    av = 150
    return [av + pad * 2, av + pad * 2 + offY]
end function

function SkeletonProfileNameGlowSize() as object
    padX = SkeletonProfileNameGlowPadX()
    padY = SkeletonProfileNameGlowPadY()
    offY = SkeletonBoxGlowOffsetY()
    return [190 + padX * 2, 22 + padY * 2 + offY]
end function

function SK_DefaultPageBg() as string
    return SK_LoadingPageBg()
end function

function SK_HexToRoku(hex as string, alpha as string) as string
    if hex = invalid or hex = "" then return "0x000000" + alpha
    h = hex
    if Left(h, 2) = "0x" or Left(h, 2) = "0X" then return h
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) = 8 then return "0x" + h
    if Len(h) = 6 then return "0x" + h + alpha
    return "0x000000" + alpha
end function

function SK_TokenColor(tokens as object, name as string, fallbackHex as string) as string
    hex = fallbackHex
    if tokens <> invalid and tokens[name] <> invalid and tokens[name] <> "" then
        hex = tokens[name]
    end if
    return SK_HexToRoku(hex, "ff")
end function

' Resolve configured skeleton colors from theme token map (themeManager.themeTokens).
function SkeletonResolveColors(tokens as object) as object
    base = SK_TokenColor(tokens, SK_BaseToken(), SK_BaseFallbackHex())
    hi = SK_TokenColor(tokens, SK_HighlightToken(), SK_HighlightFallbackHex())
    return { base: base, highlight: hi }
end function

' Rounded skeleton mask for vertical catalogue cards (parity verticalCard.tsx radius-10).
function CardVerticalSkeletonShapeUri(w as integer, h as integer) as string
    if w = 272 and h = 340 then return "pkg:/images/ui/sk_vertical_card_272x340.png"
    if w = 240 and h = 300 then return "pkg:/images/ui/sk_vertical_card_240x300.png"
    return "pkg:/images/ui/sk_vertical_card_240x300.png"
end function

' profile.tsx SkeletonBox borderRadius={9999} — circle avatar + pill name bar.
function SkeletonProfileAvatarShapeUri(squareAvatars as boolean) as string
    if squareAvatars then return "pkg:/images/ui/sk_rounded_150_r12.png"
    return "pkg:/images/ui/sk_avatar_150.png"
end function

function SkeletonProfileNameShapeUri() as string
    return "pkg:/images/ui/sk_pill_190x22.png"
end function

' seriesEpisode.tsx loading pulse blocks — rounded masks (parity DetailScreen sk_detail_*).
function SeriesEpisodesSkShapeUri(id as string, w as integer, h as integer) as string
    if id = "seSkLogo" then return "pkg:/images/ui/sk_series_block_280x48.png"
    if id = "seSkTitle" then return "pkg:/images/ui/sk_series_block_450x50.png"
    if id = "seSkMeta" then return "pkg:/images/ui/sk_detail_line_300x24.png"
    if Left(id, 7) = "seSkTab" then return "pkg:/images/ui/sk_series_block_" + w.ToStr() + "x" + h.ToStr() + ".png"
    if id = "seSkHeading" then return "pkg:/images/ui/sk_detail_line_200x36.png"
    if id = "seSkSubtitle" then return "pkg:/images/ui/sk_detail_line_240x22.png"
    if Right(id, 5) = "Thumb" then return "pkg:/images/ui/sk_episode_thumb.png"
    if Right(id, 5) = "Title" then return "pkg:/images/ui/sk_detail_line_400x32.png"
    if Right(id, 5) = "Desc1" then return "pkg:/images/ui/sk_detail_line_560x22.png"
    if Right(id, 5) = "Desc2" then return "pkg:/images/ui/sk_detail_line_420x22.png"
    if Right(id, 4) = "Meta" then return "pkg:/images/ui/sk_detail_line_280x20.png"
    return ""
end function
