' ColorShade.brs
' Faithful BrightScript port of the web app's color token system:
'   - src/utils/helper/colorShadeGenerator.ts (generateShades, generateBgTokens)
'   - src/hooks/useTheme.ts (token application order / priority)
'
' The web app applies, in order:
'   1. static darkTheme  (DarkThemeTokens)
'   2. colors.primary    -> generateShades -> --primary-50..900
'   3. colors.secondary  -> generateShades(50..600) -> --neutral-50..600
'   4. colors.tertiary   -> generateBgTokens -> --background + --neutral-700..1000
' (textColor is empty in theme.config.ts, so generateTextTokens is NOT applied.)
'
' BuildThemeTokens() reproduces that exact precedence and returns an assoc
' array of "#rrggbb" strings keyed like Tailwind tokens ("primary-600",
' "neutral-500", "background", ...). Use ThemeTokenColor() to read a token as
' a Roku "0xRRGGBBaa" color.

function NormalizeHex(hex as string) as string
    if hex = invalid or hex = "" then return ""
    if Left(hex, 1) <> "#" then return "#" + hex
    return hex
end function

' ---- Hex <-> RGB <-> HSL (mirrors colorShadeGenerator.ts) ----

function HexToRgb(hex as string) as object
    clean = hex
    if Left(clean, 1) = "#" then clean = Mid(clean, 2)
    if Len(clean) <> 6 then return invalid
    return {
        r: Val(Mid(clean, 1, 2), 16)
        g: Val(Mid(clean, 3, 2), 16)
        b: Val(Mid(clean, 5, 2), 16)
    }
end function

function RoundNum(x as float) as integer
    if x >= 0 then return Int(x + 0.5)
    return -Int(-x + 0.5)
end function

function ClampByte(c as float) as integer
    n = RoundNum(c)
    if n < 0 then return 0
    if n > 255 then return 255
    return n
end function

function ByteToHex(n as integer) as string
    digits = "0123456789abcdef"
    if n < 0 then n = 0
    if n > 255 then n = 255
    hi = Int(n / 16)
    lo = n - hi * 16
    return Mid(digits, hi + 1, 1) + Mid(digits, lo + 1, 1)
end function

function RgbToHexF(r as float, g as float, b as float) as string
    return "#" + ByteToHex(ClampByte(r)) + ByteToHex(ClampByte(g)) + ByteToHex(ClampByte(b))
end function

' Returns { h: 0..360, s: 0..100, l: 0..100 }
function RgbToHsl(r as float, g as float, b as float) as object
    r = r / 255.0
    g = g / 255.0
    b = b / 255.0

    mx = r
    if g > mx then mx = g
    if b > mx then mx = b
    mn = r
    if g < mn then mn = g
    if b < mn then mn = b

    l = (mx + mn) / 2.0
    h = 0.0
    s = 0.0

    if mx <> mn then
        d = mx - mn
        if l > 0.5 then
            s = d / (2.0 - mx - mn)
        else
            s = d / (mx + mn)
        end if

        if mx = r then
            add = 0.0
            if g < b then add = 6.0
            h = ((g - b) / d + add) / 6.0
        else if mx = g then
            h = ((b - r) / d + 2.0) / 6.0
        else
            h = ((r - g) / d + 4.0) / 6.0
        end if
    end if

    return { h: h * 360.0, s: s * 100.0, l: l * 100.0 }
end function

function Hue2Rgb(p as float, q as float, t as float) as float
    if t < 0.0 then t = t + 1.0
    if t > 1.0 then t = t - 1.0
    if t < (1.0 / 6.0) then return p + (q - p) * 6.0 * t
    if t < (1.0 / 2.0) then return q
    if t < (2.0 / 3.0) then return p + (q - p) * (2.0 / 3.0 - t) * 6.0
    return p
end function

' h:0..360 s:0..100 l:0..100 -> { r, g, b } 0..255
function HslToRgb(h as float, s as float, l as float) as object
    h = h / 360.0
    s = s / 100.0
    l = l / 100.0

    if s = 0.0 then
        v = RoundNum(l * 255.0)
        return { r: v, g: v, b: v }
    end if

    if l < 0.5 then
        q = l * (1.0 + s)
    else
        q = l + s - l * s
    end if
    p = 2.0 * l - q

    return {
        r: RoundNum(Hue2Rgb(p, q, h + 1.0 / 3.0) * 255.0)
        g: RoundNum(Hue2Rgb(p, q, h) * 255.0)
        b: RoundNum(Hue2Rgb(p, q, h - 1.0 / 3.0) * 255.0)
    }
end function

' ---- Shade generation (mirrors generateShades) ----

function ShadeStops() as object
    ' [shade, targetLightness] in insertion order
    return [
        [50, 96.0], [100, 90.0], [200, 80.0], [300, 68.0], [400, 56.0],
        [500, 0.0], [600, 38.0], [700, 28.0], [800, 18.0], [900, 10.0]
    ]
end function

' Returns { "50": "#..", ..., "900": "#.." }
function GenerateShades(baseHex as string) as object
    hex = NormalizeHex(baseHex)
    rgb = HexToRgb(hex)
    if rgb = invalid then return {}

    hsl = RgbToHsl(rgb.r, rgb.g, rgb.b)
    h = hsl.h
    s = hsl.s

    shades = {}
    for each entry in ShadeStops()
        shadeNum = entry[0]
        targetL = entry[1]

        if shadeNum = 500 then
            shades["500"] = hex
        else
            if shadeNum < 500 then
                a = s * 0.55
                b = s - (500 - shadeNum) * 0.08
                if a > b then satAdjust = a else satAdjust = b
            else
                a = s * 1.05
                b = s + (shadeNum - 500) * 0.02
                if a < b then satAdjust = a else satAdjust = b
            end if

            c = HslToRgb(h, satAdjust, targetL)
            shades[StrI(shadeNum).Trim()] = RgbToHexF(c.r, c.g, c.b)
        end if
    end for
    return shades
end function

' ---- Background tokens (mirrors generateBgTokens) ----

function GenerateBgTokens(baseHex as string) as object
    hex = NormalizeHex(baseHex)
    rgb = HexToRgb(hex)
    if rgb = invalid then return {}

    hsl = RgbToHsl(rgb.r, rgb.g, rgb.b)
    h = hsl.h
    s = hsl.s
    l = hsl.l

    return {
        background: hex
        backgroundDark: ShadeLightness(h, s, l, -3.0)
        backgroundDarker: ShadeLightness(h, s, l, -6.0)
        neutral700: ShadeLightness(h, s, l, 10.0)
        neutral800: ShadeLightness(h, s, l, 5.0)
        neutral900: hex
        neutral950: ShadeLightness(h, s, l, -3.0)
        neutral1000: ShadeLightness(h, s, l, -6.0)
    }
end function

function ShadeLightness(h as float, s as float, l as float, delta as float) as string
    nl = l + delta
    if nl < 0.0 then nl = 0.0
    if nl > 100.0 then nl = 100.0
    c = HslToRgb(h, s, nl)
    return RgbToHexF(c.r, c.g, c.b)
end function

' ---- Static dark theme defaults (mirrors dark.theme.ts) ----

function DarkThemeTokens() as object
    return {
        "primary-50": "#e6f3ff"
        "primary-100": "#cce7ff"
        "primary-200": "#99ceff"
        "primary-300": "#66b6ff"
        "primary-400": "#339dff"
        "primary-500": "#0092ff"
        "primary-600": "#459adb"
        "primary-700": "#80bbe9"
        "primary-800": "#350e0e"
        "primary-900": "#011932"
        "neutral-50": "#ffffff"
        "neutral-100": "#f8f8f8"
        "neutral-200": "#e5e5e5"
        "neutral-300": "#d6d6d6"
        "neutral-400": "#c8c8c8"
        "neutral-500": "#555555"
        "neutral-600": "#3d3d3d"
        "neutral-700": "#181818"
        "neutral-800": "#121212"
        "neutral-900": "#0a0a0a"
        "neutral-950": "#050505"
        "neutral-1000": "#1f1f22"
        "background": "#1f1f22"
        "background-dark": "#1a1a1a"
        "background-darker": "#121212"
        "border-color": "#333333"
    }
end function

' Build the full token map with the exact web precedence.
function BuildThemeTokens(resolved as object) as object
    tokens = DarkThemeTokens()
    if resolved = invalid then return tokens

    primary = NormalizeHex(resolved.portalPrimaryColor)
    if primary <> "" then
        ps = GenerateShades(primary)
        for each k in ps
            tokens["primary-" + k] = ps[k]
        end for
    end if

    ' Faithful 1:1 port of useTheme.ts: colors.secondary -> generateNeutralLightTokens
    ' (neutral-50..600). No usability guard — match React exactly.
    secondary = NormalizeHex(resolved.portalSecondaryColor)
    if secondary <> "" then
        ss = GenerateShades(secondary)
        for each k in ss
            kn = Val(k)
            if kn >= 50 and kn <= 600 then tokens["neutral-" + k] = ss[k]
        end for
    end if

    ' Faithful 1:1 port of useTheme.ts: colors.tertiary -> generateBgTokens
    ' (--background + neutral-700..1000). No darkness guard — match React exactly.
    tertiary = NormalizeHex(resolved.portalTertiaryColor)
    if tertiary <> "" then
        bg = GenerateBgTokens(tertiary)
        tokens["background"] = bg.background
        tokens["background-dark"] = bg.backgroundDark
        tokens["background-darker"] = bg.backgroundDarker
        tokens["neutral-700"] = bg.neutral700
        tokens["neutral-800"] = bg.neutral800
        tokens["neutral-900"] = bg.neutral900
        tokens["neutral-950"] = bg.neutral950
        tokens["neutral-1000"] = bg.neutral1000
    end if

    return tokens
end function

' Read a token from a tokens map and return it as a Roku "0xRRGGBBaa" color.
function ThemeTokenColor(tokens as object, name as string, fallbackHex as string) as string
    hex = fallbackHex
    if tokens <> invalid and tokens[name] <> invalid and tokens[name] <> "" then
        hex = tokens[name]
    end if
    return HexToRokuColor(hex, "ff")
end function

' "#rrggbb" (or "rrggbb") + alpha hex "ff" -> "0xrrggbbff"
function HexToRokuColor(hex as string, alpha as string) as string
    if hex = invalid or hex = "" then return "0x000000" + alpha
    h = hex
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) = 8 then return "0x" + h
    if Len(h) = 6 then return "0x" + h + alpha
    return "0x000000" + alpha
end function

' ---- Apply resolved colors to a ThemeManager node ----

function ApplyResolvedTheme(theme as object, resolved as object) as void
    if theme = invalid or resolved = invalid then return

    theme.primaryColor = NormalizeHex(resolved.portalPrimaryColor)
    theme.secondaryColor = NormalizeHex(resolved.portalSecondaryColor)
    theme.tertiaryColor = NormalizeHex(resolved.portalTertiaryColor)

    tokens = BuildThemeTokens(resolved)
    theme.themeTokens = tokens

    if tokens["primary-500"] <> invalid then theme.primary500 = tokens["primary-500"]
    if tokens["primary-600"] <> invalid then theme.primary600 = tokens["primary-600"]
    if tokens["primary-700"] <> invalid then theme.primary700 = tokens["primary-700"]

    theme.brandingLogo = resolved.brandingLogo
    theme.loginBackgroundImage = resolved.loginBackgroundImage
    theme.fontFamily = resolved.fontFamily
    theme.appName = resolved.appName

    theme.reelsEnabled = IsFeatureEnabled(resolved, "reelsEnabled")
    theme.geoBlockingEnabled = IsFeatureEnabled(resolved, "geoBlockingEnabled")
    theme.subscriptionEnabled = IsFeatureEnabled(resolved, "subscriptionEnabled")

    ' Boot splash color (web shows tertiary/#0b1120 until config loads)
    if resolved.darkThemeBackground <> "" then
        theme.bootBackgroundColor = NormalizeHex(resolved.darkThemeBackground)
    else if theme.tertiaryColor <> "" then
        theme.bootBackgroundColor = theme.tertiaryColor
    else
        theme.bootBackgroundColor = "#0b1120"
    end if
end function
