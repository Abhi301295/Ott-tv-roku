sub init()
    m.border = m.top.findNode("border")
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    OnSizeChanged()
    UpdateDisplay()
    ApplyStyle()
end sub

sub OnValueChanged()
    UpdateDisplay()
end sub

sub OnSizeChanged()
    w = m.top.fieldWidth
    h = m.top.fieldHeight
    if w < 200 then w = 700
    if h < 40 then h = SR_InputH()
    bw = SR_InputBorderW()
    m.border.width = w
    m.border.height = h
    m.bg.width = w - (2 * bw)
    m.bg.height = h - (2 * bw)
    m.bg.translation = [bw, bw]
    m.text.width = w - (2 * SR_InputPadX())
    m.text.height = h
    m.text.translation = [SR_InputPadX(), 0]
end sub

sub UpdateDisplay()
    val = m.top.value
    hasVal = (val <> invalid and val <> "")
    fontSize = SR_InputFontSize()
    if not hasVal then fontSize = SR_InputPlaceholderFontSize()
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Inter-Regular.ttf"
    f.size = fontSize
    m.text.font = f
    if hasVal then
        m.text.text = val
        m.text.color = m.top.textColor
    else
        ph = m.top.placeholder
        if ph = invalid then ph = SR_InputPlaceholder()
        m.text.text = ph
        m.text.color = m.top.placeholderColor
    end if
end sub

sub ApplyStyle()
    bgc = m.top.bgColor
    if bgc = invalid or bgc = "" then bgc = "0x181818ff"
    m.bg.blendColor = bgc
    if m.top.focusedState then
        m.border.blendColor = m.top.borderColor
        m.border.visible = true
    else
        m.border.visible = false
    end if
    UpdateDisplay()
end sub
