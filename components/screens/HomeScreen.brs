sub init()
    m.logoLabel = m.top.findNode("logoLabel")
    m.welcome = m.top.findNode("welcome")
    m.subtitle = m.top.findNode("subtitle")
    m.switchProfileBtn = m.top.findNode("switchProfileBtn")

    scene = m.top.getScene()
    m.vm = invalid
    if scene <> invalid then m.vm = scene.findNode("viewManager")

    ApplyColors()
    ApplyBranding()

    m.top.observeField("keyEvent", "OnKey")
    m.switchProfileBtn.setFocus(true)
end sub

' ── Theme ────────────────────────────────────────────────────────────────────

sub ApplyColors()
    tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens

    cPrimary500 = TokenColor(tokens, "primary-500", "#0b75e0")
    cPrimary600 = TokenColor(tokens, "primary-600", "#0760bb")
    cNeutral50 = TokenColor(tokens, "neutral-50", "#f8f1f7")
    cNeutral400 = TokenColor(tokens, "neutral-400", "#9ea4b0")

    m.logoLabel.color = cPrimary500
    m.welcome.color = cNeutral50
    m.subtitle.color = cNeutral400

    ' Button rendered in its focused/selected style (it's the only focusable item).
    m.switchProfileBtn.bgColor = cPrimary600
    m.switchProfileBtn.textColor = cNeutral50
    m.switchProfileBtn.shadowColor = cPrimary500
    m.switchProfileBtn.showShadow = true
end sub

' Read a "#rrggbb" theme token as a Roku "0xRRGGBBff" color (inline to avoid
' pulling the ColorShade/BusinessConfig dependency chain into this screen).
function TokenColor(tokens as object, name as string, fallbackHex as string) as string
    hex = fallbackHex
    if tokens <> invalid and tokens[name] <> invalid and tokens[name] <> "" then
        hex = tokens[name]
    end if
    if Left(hex, 1) = "#" then hex = Mid(hex, 2)
    if Len(hex) = 8 then return "0x" + hex
    if Len(hex) = 6 then return "0x" + hex + "ff"
    return "0x0b75e0ff"
end function

sub ApplyBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return

    if resolved.appName <> invalid and resolved.appName <> "" then
        m.logoLabel.text = resolved.appName
    end if
end sub

' ── Key handling ─────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return

    if ev.key = "OK" or ev.key = "ok" then GoToProfiles()
end sub

sub GoToProfiles()
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteLoginProfile(), {})
end sub
