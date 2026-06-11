sub init()
    m.edgeTop = m.top.findNode("edgeTop")
    m.edgeBottom = m.top.findNode("edgeBottom")
    m.edgeLeft = m.top.findNode("edgeLeft")
    m.edgeRight = m.top.findNode("edgeRight")
    m.cTL = m.top.findNode("cTL")
    m.cTR = m.top.findNode("cTR")
    m.cBL = m.top.findNode("cBL")
    m.cBR = m.top.findNode("cBR")
    Rebuild()
    ApplyColor()
end sub

sub OnFrameChanged()
    Rebuild()
end sub

sub OnColorChanged()
    ApplyColor()
end sub

' Lay the 4 corner sprites at the corners and stretch the 4 edge rectangles between them.
sub Rebuild()
    w = m.top.boxWidth
    h = m.top.boxHeight
    t = m.top.thickness
    r = m.top.radius
    if w <= 0 or h <= 0 then return

    m.cTL.width = r
    m.cTL.height = r
    m.cTL.translation = [0, 0]
    m.cTR.width = r
    m.cTR.height = r
    m.cTR.translation = [w - r, 0]
    m.cBL.width = r
    m.cBL.height = r
    m.cBL.translation = [0, h - r]
    m.cBR.width = r
    m.cBR.height = r
    m.cBR.translation = [w - r, h - r]

    midW = w - 2 * r
    if midW < 0 then midW = 0
    midH = h - 2 * r
    if midH < 0 then midH = 0

    m.edgeTop.width = midW
    m.edgeTop.height = t
    m.edgeTop.translation = [r, 0]

    m.edgeBottom.width = midW
    m.edgeBottom.height = t
    m.edgeBottom.translation = [r, h - t]

    m.edgeLeft.width = t
    m.edgeLeft.height = midH
    m.edgeLeft.translation = [0, r]

    m.edgeRight.width = t
    m.edgeRight.height = midH
    m.edgeRight.translation = [w - t, r]
end sub

sub ApplyColor()
    c = m.top.color
    if c = invalid or c = "" then return
    ' Straight edges are Rectangles whose .color fill always renders. The rounded corner
    ' sprites are now WHITE alpha masks, so blendColor tints them to the active theme color
    ' (no more baked blue corners when the business theme changes to e.g. red).
    m.edgeTop.color = c
    m.edgeBottom.color = c
    m.edgeLeft.color = c
    m.edgeRight.color = c
    m.cTL.blendColor = c
    m.cTR.blendColor = c
    m.cBL.blendColor = c
    m.cBR.blendColor = c
end sub
