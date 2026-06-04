' ColorShade.brs
' Theme color helpers for SceneGraph (simplified parity with colorShadeGenerator.ts).
' Stores key hex values on a node; full 10-shade HSL generation can be added later.

function NormalizeHex(hex as string) as string
    if hex = invalid or hex = "" then return ""
    if Left(hex, 1) <> "#" then return "#" + hex
    return hex
end function

' Apply resolved portal colors + boot background to a ThemeManager node.
function ApplyResolvedTheme(theme as object, resolved as object) as void
    if theme = invalid or resolved = invalid then return

    theme.primaryColor = NormalizeHex(resolved.portalPrimaryColor)
    theme.secondaryColor = NormalizeHex(resolved.portalSecondaryColor)
    theme.tertiaryColor = NormalizeHex(resolved.portalTertiaryColor)

    ' Focus / accent shades derived from primary (used by cards, buttons)
    shades = GeneratePrimaryShades(theme.primaryColor)
    if shades <> invalid then
        if shades["500"] <> invalid then theme.primary500 = shades["500"]
        if shades["600"] <> invalid then theme.primary600 = shades["600"]
        if shades["700"] <> invalid then theme.primary700 = shades["700"]
    end if

    theme.brandingLogo = resolved.brandingLogo
    theme.loginBackgroundImage = resolved.loginBackgroundImage
    theme.fontFamily = resolved.fontFamily
    theme.appName = resolved.appName

    theme.reelsEnabled = IsFeatureEnabled(resolved, "reelsEnabled")
    theme.geoBlockingEnabled = IsFeatureEnabled(resolved, "geoBlockingEnabled")
    theme.subscriptionEnabled = IsFeatureEnabled(resolved, "subscriptionEnabled")

    ' Boot splash color (parity with web #0b1120 blank screen until config loads)
    if resolved.darkThemeBackground <> "" then
        theme.bootBackgroundColor = NormalizeHex(resolved.darkThemeBackground)
    else if theme.tertiaryColor <> "" then
        theme.bootBackgroundColor = theme.tertiaryColor
    else
        theme.bootBackgroundColor = "#0b1120"
    end if
end function

' Returns { "500": hex, "600": hex, "700": hex } or invalid when base is empty.
function GeneratePrimaryShades(baseHex as string) as object
    hex = NormalizeHex(baseHex)
    if hex = "" then return invalid

    rgb = HexToRgb(hex)
    if rgb = invalid then return invalid

    return {
        "500": hex
        "600": RgbToHex(ScaleRgb(rgb, 0.85))
        "700": RgbToHex(ScaleRgb(rgb, 0.70))
    }
end function

function HexToRgb(hex as string) as object
    clean = hex.Replace("#", "")
    if Len(clean) <> 6 then return invalid

    return {
        r: Val("0x" + Mid(clean, 1, 2))
        g: Val("0x" + Mid(clean, 3, 2))
        b: Val("0x" + Mid(clean, 5, 2))
    }
end function

function RgbToHex(rgb as object) as string
    return "#" + ByteToHex(rgb.r) + ByteToHex(rgb.g) + ByteToHex(rgb.b)
end function

function ByteToHex(n as integer) as string
    hex = StrI(n, 16)
    if Len(hex) = 1 then return "0" + hex
    return hex
end function

function ScaleRgb(rgb as object, factor as float) as object
    return {
        r: Int(rgb.r * factor)
        g: Int(rgb.g * factor)
        b: Int(rgb.b * factor)
    }
end function
