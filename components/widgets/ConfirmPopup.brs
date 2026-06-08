sub init()
    m.cancelShadow = m.top.findNode("cancelShadow")
    m.cancelBorder = m.top.findNode("cancelBorder")
    m.cancelFill = m.top.findNode("cancelFill")
    m.cancelLabel = m.top.findNode("cancelLabel")
    m.logoutShadow = m.top.findNode("logoutShadow")
    m.logoutBorder = m.top.findNode("logoutBorder")
    m.logoutFill = m.top.findNode("logoutFill")
    m.logoutLabel = m.top.findNode("logoutLabel")

    m.top.observeField("keyEvent", "OnKey")

    ' Default focus = Cancel (parity with cancelBtnFocusSelf()).
    m.focus = "cancel"
    ApplyTheme()
    UpdateButtons()
end sub

' Re-apply when the screen injects themed tokens after this component's init().
sub OnThemeChanged()
    if m.cancelFill = invalid then return   ' init() not finished yet
    ApplyTheme()
    UpdateButtons()
end sub

sub ApplyTheme()
    m.cardBorder = m.top.findNode("cardBorder")
    m.cardFill = m.top.findNode("cardFill")
    m.prompt = m.top.findNode("prompt")
    m.cardBorder.blendColor = m.top.cCardBorder
    m.cardFill.blendColor = m.top.cCardBg
    ' Prompt copy follows the themed neutral-300 (parity with text-neutral-300).
    if m.prompt <> invalid then m.prompt.color = m.top.cNeutral300
    ' Subtle dark drop shadow on the focused button (parity with shadow-lg),
    ' not a colored glow. Kept black; size/opacity set in XML.
    m.cancelShadow.blendColor = "0x000000ff"
    m.logoutShadow.blendColor = "0x000000ff"
end sub

sub OnLoggingOutChanged()
    if m.logoutLabel = invalid then return
    if m.top.isLoggingOut then
        m.logoutLabel.text = "Logging Out"
    else
        m.logoutLabel.text = "Log Out"
    end if
    UpdateButtons()
end sub

sub UpdateButtons()
    if m.cancelFill = invalid then return
    loggingOut = m.top.isLoggingOut

    cancelFocused = (m.focus = "cancel")
    logoutFocused = (m.focus = "logout")

    ' Cancel: focused → primary-600 fill; else neutral card bg with neutral border.
    if cancelFocused and not loggingOut then
        m.cancelBorder.blendColor = m.top.cPrimary500
        m.cancelFill.blendColor = m.top.cPrimary600
    else
        m.cancelBorder.blendColor = m.top.cNeutral500
        m.cancelFill.blendColor = m.top.cCardBg
    end if
    m.cancelShadow.visible = (cancelFocused and not loggingOut)

    ' Log Out: focused → primary-500 fill; else neutral.
    if logoutFocused and not loggingOut then
        m.logoutBorder.blendColor = m.top.cPrimary500
        m.logoutFill.blendColor = m.top.cPrimary500
    else
        m.logoutBorder.blendColor = m.top.cNeutral500
        m.logoutFill.blendColor = m.top.cCardBg
    end if
    m.logoutShadow.visible = (logoutFocused and not loggingOut)

    op = 1.0
    if loggingOut then op = 0.5
    m.cancelLabel.opacity = op
    m.logoutLabel.opacity = op
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.top.isLoggingOut then return

    key = ev.key
    if key = "left" then
        m.focus = "cancel"
        UpdateButtons()
    else if key = "right" then
        m.focus = "logout"
        UpdateButtons()
    else if key = "OK" or key = "ok" then
        m.top.action = m.focus
    end if
end sub
