sub init()
    m.focusBorder = m.top.findNode("focusBorder")
    m.fill = m.top.findNode("fill")
    m.label = m.top.findNode("label")
    m.cornerTR = m.top.findNode("cornerTR")
    m.cornerBL = m.top.findNode("cornerBL")
    m.cornerBR = m.top.findNode("cornerBR")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyAll()
end sub

sub OnThemeChanged()
    ApplyAll()
end sub

sub ApplyAll()
    w = 240
    h = 305
    if m.top.orientation = HC_CardTypeHorizontal() then
        w = 540
        h = 320
    end if

    m.focusBorder.boxWidth = w + 6
    m.focusBorder.boxHeight = h + 6
    m.fill.width = w
    m.fill.height = h
    m.fill.color = m.top.cNeutral800
    m.label.width = w
    m.label.translation = [0, Int((h - 40) / 2)]
    m.label.color = m.top.cNeutral50
    ' Reposition the baked corner covers to the active size (TL stays at origin).
    if m.cornerTR <> invalid then m.cornerTR.translation = [w - 10, 0]
    if m.cornerBL <> invalid then m.cornerBL.translation = [0, h - 10]
    if m.cornerBR <> invalid then m.cornerBR.translation = [w - 10, h - 10]
    if m.top.focusedState = true then
        m.label.color = m.top.cPrimary600
    end if
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
