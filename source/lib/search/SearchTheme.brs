' SearchTheme.brs — parity with useTheme.ts + searchcol/searchbar/customkeyboard tokens.

function SearchThemeTokens(fromNode as object) as object
    if fromNode = invalid then return DarkThemeTokens()
    scene = fromNode.getScene()
    if scene = invalid then return DarkThemeTokens()
    tm = scene.findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then return tm.themeTokens
    return DarkThemeTokens()
end function

function STC(tokens as object, name as string, fallbackHex as string) as string
    return ThemeTokenColor(tokens, name, fallbackHex)
end function

' Load search screen colors from the same API theme map React uses (generateBgTokens + primary).
sub SearchApplyThemeColors(m as object)
    if m = invalid then return
    tokens = SearchThemeTokens(m.top)

    m.cPageBg = "0x000000ff"
    m.cInputBg = "0x000000ff"
    m.cInputBorderFocus = STC(tokens, "neutral-400", "#c8c8c8")
    m.cText = STC(tokens, "neutral-50", "#ffffff")
    m.cPlaceholder = SR_PlaceholderColor()
    m.cPrimary500 = STC(tokens, "primary-500", "#0092ff")
    m.cPrimary700 = STC(tokens, "primary-700", "#80bbe9")
    m.cKeyBg = SR_KeyFillColor()
    m.cKeyBorder = STC(tokens, "neutral-700", "#404040")

    bg = m.top.findNode("bg")
    if bg <> invalid then bg.color = m.cPageBg
end sub
