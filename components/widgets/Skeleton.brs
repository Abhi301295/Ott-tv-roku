sub init()
    m.base = m.top.findNode("base")
    m.shine = m.top.findNode("shine")
    m.anim = m.top.findNode("anim")
    m.interp = m.top.findNode("interp")
    ApplySize()
    ApplyColors()
end sub

sub OnSizeChanged()
    ApplySize()
end sub

sub OnShapeChanged()
    if m.base = invalid then return
    if m.top.shapeUri <> invalid and m.top.shapeUri <> "" then
        m.base.uri = m.top.shapeUri
        m.shine.uri = m.top.shapeUri
    end if
end sub

sub OnColorsChanged()
    ApplyColors()
end sub

sub ApplySize()
    if m.base = invalid then return
    w = m.top.boxWidth
    h = m.top.boxHeight
    m.base.width = w
    m.base.height = h
    m.shine.width = w
    m.shine.height = h
end sub

sub ApplyColors()
    if m.base = invalid then return
    m.base.blendColor = m.top.baseColor
    m.shine.blendColor = m.top.highlightColor
end sub

' Static placeholders (cards) keep the shimmer animation off: running ~20 of them
' while building rows starves the render thread. The shine overlay is parked so the
' base color reads as a plain neutral block. Screens that want the sweep set animate.
sub OnRunningChanged()
    if m.anim = invalid then return
    if m.top.running and m.top.animate then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
        if m.shine <> invalid then m.shine.opacity = 0.0
    end if
end sub
