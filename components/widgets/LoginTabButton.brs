sub init()
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    m.top.focusable = true
    ApplyColors()
end sub

sub OnLabelChanged()
    m.text.text = m.top.label
end sub

sub OnSizeChanged()
    w = m.top.buttonWidth
    if w < 120 then w = 280
    m.bg.width = w
    m.text.width = w - 48
end sub

sub OnSelectedChanged()
    ApplyColors()
end sub

sub ApplyColors()
    active = m.top.activeColor
    inactive = m.top.inactiveColor
    if active = invalid or active = "" then active = "0x4d57eaff"
    if inactive = invalid or inactive = "" then inactive = "0x1f1f22ff"
    if m.top.selected then
        m.bg.color = active
    else
        m.bg.color = inactive
    end if
end sub
