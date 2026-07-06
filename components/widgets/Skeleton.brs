sub init()
    m.baseRect = m.top.findNode("baseRect")
    m.shineRect = m.top.findNode("shineRect")
    m.basePoster = m.top.findNode("basePoster")
    m.shinePoster = m.top.findNode("shinePoster")
    m.anim = m.top.findNode("anim")
    ApplyShapeMode()
    ApplySize()
    ApplyColors()
end sub

sub OnSizeChanged()
    ApplySize()
end sub

sub OnShapeChanged()
    ApplyShapeMode()
    ApplySize()
    ApplyColors()
end sub

sub OnColorsChanged()
    ApplyColors()
end sub

sub ApplyShapeMode()
    usePoster = m.top.shapeUri <> invalid and m.top.shapeUri <> ""
    if m.baseRect <> invalid then m.baseRect.visible = not usePoster
    if m.shineRect <> invalid then m.shineRect.visible = not usePoster
    if m.basePoster <> invalid then
        m.basePoster.visible = usePoster
        if usePoster then m.basePoster.uri = m.top.shapeUri
    end if
    if m.shinePoster <> invalid then
        m.shinePoster.visible = usePoster
        if usePoster then m.shinePoster.uri = m.top.shapeUri
    end if
end sub

sub ApplySize()
    w = m.top.boxWidth
    h = m.top.boxHeight
    if m.baseRect <> invalid then
        m.baseRect.width = w
        m.baseRect.height = h
    end if
    if m.shineRect <> invalid then
        m.shineRect.width = w
        m.shineRect.height = h
    end if
    if m.basePoster <> invalid then
        m.basePoster.width = w
        m.basePoster.height = h
    end if
    if m.shinePoster <> invalid then
        m.shinePoster.width = w
        m.shinePoster.height = h
    end if
end sub

sub ApplyColors()
    if m.baseRect <> invalid then m.baseRect.color = m.top.baseColor
    if m.shineRect <> invalid then m.shineRect.color = m.top.highlightColor
    if m.basePoster <> invalid then m.basePoster.blendColor = m.top.baseColor
    if m.shinePoster <> invalid then m.shinePoster.blendColor = m.top.highlightColor
end sub

' Static placeholders (cards) keep the shimmer animation off: running ~20 of them
' while building rows starves the render thread. The shine overlay is parked so the
' base color reads as a plain neutral block. Screens that want the sweep set animate.
sub OnRunningChanged()
    if m.anim = invalid then return
    if m.baseRect <> invalid then m.baseRect.opacity = 1.0
    if m.basePoster <> invalid then m.basePoster.opacity = 1.0
    if m.top.running and m.top.animate then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
        if m.shineRect <> invalid then m.shineRect.opacity = 0.0
        if m.shinePoster <> invalid then m.shinePoster.opacity = 0.0
    end if
end sub
