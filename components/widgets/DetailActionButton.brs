sub init()
    m.shadow = m.top.findNode("shadow")
    m.bg = m.top.findNode("bg")
    m.icon = m.top.findNode("icon")
    m.text = m.top.findNode("text")
    OnLabelChanged()
    OnIconChanged()
    ApplyStyle()
end sub

sub OnLabelChanged()
    if m.text <> invalid then m.text.text = m.top.label
end sub

sub OnIconChanged()
    if m.icon = invalid then return
    if m.top.iconUri <> invalid and m.top.iconUri <> "" then
        m.icon.uri = m.top.iconUri
        m.icon.visible = true
    else
        m.icon.visible = false
    end if

    iw = m.top.iconW
    ih = m.top.iconH
    if iw <= 0 then iw = 18
    if ih <= 0 then ih = 21
    m.icon.width = iw
    m.icon.height = ih
    ' Center on the nominal 20px slot at padding-left 64 (slot center x=74) and the
    ' button's vertical center (76/2 = 38), matching React's items-center justify-center.
    m.icon.translation = [74 - iw / 2, 38 - ih / 2]
end sub

sub ApplyStyle()
    if m.bg = invalid then return
    m.text.color = m.top.cNeutral50

    if m.top.focusedState = true then
        ' Focused: primary gradient fill + blue halo (React: primary gradient bg + shadow #1e90ff).
        m.bg.uri = "pkg:/images/ui/btn_detail_grad.png"
        m.bg.blendColor = m.top.cPrimary500
        m.bg.opacity = 1.0
        m.shadow.blendColor = m.top.cGlow
        m.shadow.opacity = 0.55
        m.shadow.visible = true
    else if m.top.alwaysBg = true then
        ' Watch Now (unfocused): solid neutral-700 background.
        m.bg.uri = "pkg:/images/ui/btn_detail_flat.png"
        m.bg.blendColor = m.top.cNeutral700
        m.bg.opacity = 1.0
        m.shadow.visible = false
        m.shadow.opacity = 0.0
    else
        ' Other actions (unfocused): icon + text only, no background.
        m.bg.opacity = 0.0
        m.shadow.visible = false
        m.shadow.opacity = 0.0
    end if
end sub
