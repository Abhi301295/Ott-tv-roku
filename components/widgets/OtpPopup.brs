sub init()
    m.keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "delete"]
    m.pin = ["", "", "", "", "", ""]
    m.focusIdx = 0       ' keypad index 0..11, -1 Continue, -2 Close
    m.continue = m.top.findNode("continueBtn")
    m.continueLabel = m.top.findNode("continueLabel")
    m.closeBg = m.top.findNode("closeBg")
    m.closeLabel = m.top.findNode("closeLabel")
    m.card = m.top.findNode("card")

    m.top.observeField("keyEvent", "OnKey")
    OnCardBgChanged()
    UpdateAll()
end sub

' Card surface follows the BE theme (neutral-900), matching React's bg-neutral-900.
' Also re-themes the keypad/buttons: the screen injects tokens after init() runs,
' and cCardBg is the last field it sets, so all themed colors are ready here.
sub OnCardBgChanged()
    if m.card = invalid then m.card = m.top.findNode("card")
    if m.card <> invalid then m.card.blendColor = m.top.cCardBg
    if m.continue <> invalid then UpdateAll()
end sub

sub OnResetPin()
    if not m.top.resetPin then return
    m.pin = ["", "", "", "", "", ""]
    m.focusIdx = 0
    UpdateAll()
end sub

sub OnVerifyingChanged()
    UpdateAll()
end sub

function FirstEmpty() as integer
    for i = 0 to 5
        if m.pin[i] = "" then return i
    end for
    return -1
end function

function PinString() as string
    s = ""
    for i = 0 to 5
        s = s + m.pin[i]
    end for
    return s
end function

function IsComplete() as boolean
    return (FirstEmpty() = -1)
end function

sub InputDigit(num as string)
    idx = FirstEmpty()
    if idx <> -1 then m.pin[idx] = num
    UpdateAll()
end sub

sub DeleteDigit()
    last = -1
    for i = 0 to 5
        if m.pin[i] <> "" then last = i
    end for
    if last <> -1 then m.pin[last] = ""
    UpdateAll()
end sub

sub UpdateAll()
    UpdatePinBoxes()
    UpdateKeys()
    UpdateContinue()
    UpdateClose()
end sub

sub UpdatePinBoxes()
    emptyIdx = FirstEmpty()
    dotCh = Chr(8226)
    for i = 0 to 5
        pinBox = m.top.findNode("pin" + i.ToStr())
        dot = m.top.findNode("dot" + i.ToStr())
        if m.pin[i] <> "" then
            pinBox.blendColor = m.top.cPrimary500
            dot.text = dotCh
        else
            if i = emptyIdx then
                pinBox.blendColor = m.top.cPrimary500
            else
                pinBox.blendColor = m.top.cNeutral600
            end if
            dot.text = ""
        end if
    end for
end sub

sub UpdateKeys()
    for idx = 0 to 11
        if m.keys[idx] <> "" then
            key = m.top.findNode("key" + idx.ToStr())
            if key <> invalid then
                if idx = m.focusIdx then
                    key.blendColor = m.top.cPrimary500
                else
                    key.blendColor = m.top.cNeutral700
                end if
            end if
        end if
    end for
end sub

sub UpdateClose()
    if m.closeBg = invalid then return
    if m.focusIdx = -2 then
        m.closeBg.blendColor = m.top.cPrimary500
        m.closeLabel.color = "0xf8f1f7ff"
    else
        m.closeBg.blendColor = m.top.cNeutral700
        m.closeLabel.color = "0xf8f1f7ff"
    end if
end sub

sub UpdateContinue()
    complete = IsComplete()
    focused = (m.focusIdx = -1)
    if focused and complete then
        m.continue.blendColor = m.top.cPrimary600
        m.continueLabel.color = "0xf8f1f7ff"
    else if complete then
        m.continue.blendColor = m.top.cPrimary500
        m.continueLabel.color = "0xf8f1f7ff"
    else
        m.continue.blendColor = m.top.cNeutral700
        m.continueLabel.color = "0x9ea4b0ff"
    end if
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.top.verifying then return

    key = ev.key
    if m.focusIdx = -2 then
        HandleCloseKey(key)
        return
    end if

    if m.focusIdx = -1 then
        HandleContinueKey(key)
        return
    end if

    row = m.focusIdx \ 3
    col = m.focusIdx mod 3

    if key = "left" then
        if col > 0 and m.keys[m.focusIdx - 1] <> "" then m.focusIdx = m.focusIdx - 1
    else if key = "right" then
        if col < 2 and m.keys[m.focusIdx + 1] <> "" then m.focusIdx = m.focusIdx + 1
    else if key = "up" then
        if row > 0 then
            m.focusIdx = m.focusIdx - 3
        else
            m.focusIdx = -2
        end if
    else if key = "down" then
        if row < 3 then
            newIdx = m.focusIdx + 3
            if newIdx < 12 and m.keys[newIdx] <> "" then
                m.focusIdx = newIdx
            else if row = 2 then
                m.focusIdx = -1
            end if
        else if row = 3 then
            m.focusIdx = -1
        end if
    else if key = "OK" or key = "ok" then
        val = m.keys[m.focusIdx]
        if val = "delete" then
            DeleteDigit()
        else if val <> "" then
            InputDigit(val)
        end if
    end if

    UpdateAll()
end sub

sub HandleCloseKey(key as string)
    if key = "down" then
        m.focusIdx = 0
        UpdateAll()
    else if key = "OK" or key = "ok" then
        m.top.action = "close"
    end if
end sub

sub HandleContinueKey(key as string)
    if key = "up" then
        m.focusIdx = 7
        UpdateAll()
    else if key = "OK" or key = "ok" then
        if IsComplete() then m.top.submitted = PinString()
    end if
end sub
