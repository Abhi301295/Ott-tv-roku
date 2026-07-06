' ThemeScreenColors.brs — shared theme palette loading for browse/grid screens.
' Screens assign returned fields to m; matches prior per-screen Load*Tokens() helpers.

function ThemeTokensFromNode(fromNode as object) as object
    tokens = {}
    if fromNode = invalid then return tokens
    scene = fromNode.getScene()
    if scene = invalid then return tokens
    tm = scene.findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens
    return tokens
end function

function ThemeBrowsePalette(fromNode as object) as object
    tokens = ThemeTokensFromNode(fromNode)
    return {
        tokens: tokens
        cPrimary500: ThemeTokenColor(tokens, "primary-500", "#0b75e0")
        cPrimary600: ThemeTokenColor(tokens, "primary-600", "#0760bb")
        cPrimary700: ThemeTokenColor(tokens, "primary-700", "#04478b")
        cNeutral50: ThemeTokenColor(tokens, "neutral-50", "#f5f5f5")
        cNeutral700: ThemeTokenColor(tokens, "neutral-700", "#181818")
        cNeutral800: ThemeTokenColor(tokens, "neutral-800", "#262626")
    }
end function

function ThemeWatchlistPalette(fromNode as object) as object
    tokens = ThemeTokensFromNode(fromNode)
    return {
        tokens: tokens
        cPrimary500: ThemeTokenColor(tokens, "primary-500", "#0092ff")
        cPrimary600: ThemeTokenColor(tokens, "primary-600", "#459adb")
        cPrimary700: ThemeTokenColor(tokens, "primary-700", "#80bbe9")
        cNeutral50: ThemeTokenColor(tokens, "neutral-50", "#ffffff")
        cNeutral700: ThemeTokenColor(tokens, "neutral-700", "#181818")
        cNeutral800: ThemeTokenColor(tokens, "neutral-800", "#262626")
        cPageBg: "0x000000ff"
    }
end function

sub ThemeApplyBrowsePalette(host as object, fromNode as object)
    if host = invalid then return
    p = ThemeBrowsePalette(fromNode)
    host.tokens = p.tokens
    host.cPrimary500 = p.cPrimary500
    host.cPrimary600 = p.cPrimary600
    host.cPrimary700 = p.cPrimary700
    host.cNeutral50 = p.cNeutral50
    host.cNeutral700 = p.cNeutral700
    host.cNeutral800 = p.cNeutral800
end sub

sub ThemeApplyWatchlistPalette(host as object, fromNode as object)
    if host = invalid then return
    p = ThemeWatchlistPalette(fromNode)
    host.tokens = p.tokens
    host.cPrimary500 = p.cPrimary500
    host.cPrimary600 = p.cPrimary600
    host.cPrimary700 = p.cPrimary700
    host.cNeutral50 = p.cNeutral50
    host.cNeutral700 = p.cNeutral700
    host.cNeutral800 = p.cNeutral800
    host.cPageBg = p.cPageBg
    host.cEmptyText = p.cNeutral50
end sub
