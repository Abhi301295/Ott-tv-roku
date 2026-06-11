sub init()
    m.shadow = m.top.findNode("shadow")
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    m.top.focusable = true
    m.top.drawFocusFeedback = false
    OnSizeChanged()
    OnShapeChanged()
    OnFontChanged()
    ApplyStyle()
end sub

sub OnLabelChanged()
    m.text.text = m.top.label
end sub

sub OnShapeChanged()
    if m.top.shapeUri <> invalid and m.top.shapeUri <> "" then
        m.bg.uri = m.top.shapeUri
    end if
    if m.top.shadowUri <> invalid and m.top.shadowUri <> "" then
        m.shadow.uri = m.top.shadowUri
    end if
end sub

sub OnFontChanged()
    fontNode = m.text.font
    if fontNode <> invalid then
        if m.top.fontUri <> invalid and m.top.fontUri <> "" then fontNode.uri = m.top.fontUri
        if m.top.fontSize > 0 then fontNode.size = m.top.fontSize
    end if
end sub

sub OnSizeChanged()
    w = m.top.buttonWidth
    h = m.top.buttonHeight
    if w < 40 then w = 232
    if h < 20 then h = 56
    m.bg.width = w
    m.bg.height = h
    m.text.width = w
    m.text.height = h
    ' Each *_shadow.png is authored at exactly (button + 96px), i.e. 48px of soft
    ' drop-shadow padding on every side (tab_phone 168x56 → shadow 264x152, etc).
    ' Render at native size and center it with [-48,-48] so the pre-baked blur stays
    ' soft. (An earlier +32 clamp squished it into a hard blob; the "huge panel" look
    ' was the shadow showing when it shouldn't, now gated by showShadow below.)
    m.shadow.width = w + 96
    m.shadow.height = h + 96
    m.shadow.translation = [-48, -48]
end sub

sub ApplyStyle()
    bgc = m.top.bgColor
    txc = m.top.textColor
    if bgc = invalid or bgc = "" then bgc = "0x0760bbff"
    if txc = invalid or txc = "" then txc = "0xf8f1f7ff"
    m.bg.blendColor = bgc
    m.text.color = txc

    sc = m.top.shadowColor
    if sc = invalid or sc = "" then sc = "0x04478bff"
    m.shadow.blendColor = sc
    ' Soft drop shadow (shadow-lg shadow-primary-700) on the selected/focused state,
    ' driven by the owner via showShadow. Login tabs light this on the selected tab;
    ' the logout button leaves it off so its look is unchanged.
    m.shadow.visible = m.top.showShadow
end sub
