sub init()
    m.themeManager = m.top.findNode("themeManager")
    m.viewManager = m.top.findNode("viewManager")
    m.bootBg = m.top.findNode("bootBg")

    m.themeManager.observeField("ready", "OnThemeReady")
    m.themeManager.observeField("bootBackgroundColor", "OnBootColor")
end sub

sub OnBootColor()
    color = m.themeManager.bootBackgroundColor
    if color <> invalid and color <> "" then
        m.bootBg.color = HexToRgColor(color)
    end if
end sub

sub OnThemeReady()
    if not m.themeManager.ready then return

    m.bootBg.visible = false
    m.viewManager.visible = true

    initialRoute = GetInitialRoute()
    m.viewManager.callFunc("NavigateReplace", initialRoute, {})
    m.viewManager.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if key = "back" then
        return NavigationHandleBack(m.viewManager)
    end if

    return false
end function

' "#RRGGBB" or "#AARRGGBB" → "0xRRGGBBAA" for Rectangle.color
function HexToRgColor(hex as string) as string
    if hex = invalid or hex = "" then return "0x0b1120ff"
    h = hex
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) = 6 then
        return "0x" + h + "ff"
    else if Len(h) = 8 then
        return "0x" + h
    end if
    return "0x0b1120ff"
end function
