sub init()
    m.border = m.top.findNode("border")
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    m.top.focusable = true
    m.top.drawFocusFeedback = false
    m.placeholder = ""
    OnSizeChanged()
    ApplyStyle()
end sub

sub OnLabelChanged()
    m.placeholder = m.top.label
    UpdateDisplay()
end sub

sub OnValueChanged()
    UpdateDisplay()
end sub

sub OnSizeChanged()
    w = m.top.fieldWidth
    h = m.top.fieldHeight
    if w < 200 then w = 842
    if h < 30 then h = 56
    m.border.width = w
    m.border.height = h
    m.bg.width = w - 4
    m.bg.height = h - 4
    m.text.width = w - 48
    m.text.height = h
end sub

function MaskSecret(val as string) as string
    out = ""
    for i = 1 to Len(val)
        out = out + "*"
    end for
    return out
end function

sub UpdateDisplay()
    val = m.top.value
    hasVal = (val <> invalid and val <> "")
    if hasVal then
        if m.top.secure then
            m.text.text = MaskSecret(val)
        else
            m.text.text = val
        end if
        m.text.color = m.top.textColor
    else
        m.text.text = m.placeholder
        ' Unfocused: placeholder:text-neutral-950. Focused: no placeholder: class → preflight #9ca3af.
        if m.top.focusedState then
            m.text.color = m.top.placeholderColorFocused
        else
            m.text.color = m.top.placeholderColor
        end if
    end if
end sub

sub ApplyStyle()
    if m.top.focusedState then
        bgc = m.top.bgColorFocused      ' bg-neutral-900
        if bgc = invalid or bgc = "" then bgc = "0xffffffff"
        m.bg.blendColor = bgc
        m.border.blendColor = m.top.borderColor
        m.border.visible = true
    else
        bgc = m.top.bgColor             ' bg-neutral-700
        if bgc = invalid or bgc = "" then bgc = "0xffffffff"
        m.bg.blendColor = bgc
        m.border.visible = false
    end if

    UpdateDisplay()
end sub
