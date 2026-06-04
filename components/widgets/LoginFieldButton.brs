sub init()
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    m.top.focusable = true
    m.placeholder = ""
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
    if w < 200 then w = 800
    m.bg.width = w
    m.text.width = w - 32
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
    if val <> invalid and val <> "" then
        if m.top.secure then
            m.text.text = MaskSecret(val)
        else
            m.text.text = val
        end if
    else
        m.text.text = m.placeholder
        m.text.color = "0x9ca3afff"
    end if
    if val <> invalid and val <> "" then
        m.text.color = "0xfafafaff"
    end if
end sub
