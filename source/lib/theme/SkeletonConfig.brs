' SkeletonConfig.brs — app-wide skeleton shimmer palette (edit here).
'
' Default matches React SkeletonBox / profile: primary-700 base + primary-500 highlight.
' Used by Detail, Home, Watchlist, Reels, cards, etc.
' Login QR placeholder is excluded — LoginScreen.brs keeps its own white skeleton.

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

function SK_DefaultPageBg() as string
    return "0x0a0a0aff"
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
