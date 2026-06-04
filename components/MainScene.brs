sub init()
    m.themeManager = m.top.findNode("themeManager")
    m.viewManager = m.top.findNode("viewManager")
    m.bootBg = m.top.findNode("bootBg")
    m.toastBanner = m.top.findNode("toastBanner")
    m.toastLabel = m.top.findNode("toastLabel")
    m.toastCapL = m.top.findNode("toastCapL")
    m.toastMid = m.top.findNode("toastMid")
    m.toastCapR = m.top.findNode("toastCapR")
    m.toastCross = m.top.findNode("toastCross")
    m.alertTimer = m.top.findNode("alertTimer")

    m.themeManager.observeField("ready", "OnThemeReady")
    m.themeManager.observeField("bootBackgroundColor", "OnBootColor")
    m.top.observeField("alertMessage", "OnAlertMessageChange")
    m.alertTimer.observeField("fire", "OnAlertTimerFire")
end sub

' --- Global toast (parity with showAlert / react-toastify, 3s autoclose) ---
sub OnAlertMessageChange()
    msg = m.top.alertMessage
    if msg = invalid or msg = "" then
        HideGlobalToast()
        return
    end if
    ShowGlobalToast(msg)
end sub

sub ShowGlobalToast(message as string)
    if m.toastBanner = invalid or m.toastLabel = invalid then return

    capW = 20
    iconW = 20
    gap = 10        ' mr-[10px]
    padX = 30       ' px-[30px]
    h = 60          ' py-[15px] + 22px line

    ' Measure the text to hug the content (parity with the centered, auto-width toast).
    m.toastLabel.width = 0
    m.toastLabel.text = message
    m.toastBanner.visible = true
    rect = m.toastLabel.boundingRect()
    textW = 0
    if rect <> invalid then textW = rect.width
    if textW <= 0 then textW = Len(message) * 12  ' fallback if not yet measured

    bannerW = padX + iconW + gap + textW + padX
    x = Int((1920 - bannerW) / 2)
    m.toastBanner.translation = [x, 30]

    m.toastCapL.translation = [0, 0]
    m.toastMid.translation = [capW, 0]
    m.toastMid.width = bannerW - (2 * capW)
    m.toastCapR.translation = [bannerW - capW, 0]

    m.toastCross.translation = [padX, Int((h - iconW) / 2)]
    m.toastCross.blendColor = ToastIconColor()
    m.toastLabel.translation = [padX + iconW + gap, 0]
    m.toastLabel.height = h

    m.alertTimer.control = "stop"
    m.alertTimer.control = "start"
end sub

' Circle-X icon uses primary-500 (parity with CROSS_ICON fill var(--primary-500)).
function ToastIconColor() as string
    hex = "#0b75e0"
    if m.themeManager <> invalid and m.themeManager.themeTokens <> invalid then
        tokens = m.themeManager.themeTokens
        if tokens["primary-500"] <> invalid and tokens["primary-500"] <> "" then
            hex = tokens["primary-500"]
        end if
    end if
    return HexToRgColor(hex)
end function

sub HideGlobalToast()
    if m.alertTimer <> invalid then m.alertTimer.control = "stop"
    if m.toastBanner <> invalid then m.toastBanner.visible = false
end sub

sub OnAlertTimerFire()
    HideGlobalToast()
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

    ' Forward arrow/OK keys to the active screen (BRS simulator does not always
    ' bubble onKeyEvent to nested Groups inside ViewManager).
    screen = GetActiveScreen(m.viewManager)
    if screen <> invalid and screen.hasField("keyEvent") then
        screen.keyEvent = { key: key, press: press }
        return true
    end if

    return false
end function

function GetActiveScreen(viewManager as object) as object
    if viewManager = invalid then return invalid
    host = viewManager.findNode("screenHost")
    if host = invalid then return invalid
    count = host.getChildCount()
    if count < 1 then return invalid
    return host.getChild(count - 1)
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
