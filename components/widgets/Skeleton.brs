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

sub OnRunningChanged()
    if m.anim = invalid then return
    if m.top.running then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
    end if
end sub
