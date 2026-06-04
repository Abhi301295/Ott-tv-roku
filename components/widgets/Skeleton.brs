sub init()
    m.clip = m.top.findNode("clip")
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
    m.shine.height = h
    bandWidth = w * 0.4
    if bandWidth < 24 then bandWidth = 24
    m.shine.width = bandWidth
    m.clip.clippingRect = [0, 0, w, h]
    m.interp.keyValue = [[-1 * bandWidth, 0], [w, 0]]
end sub

sub ApplyColors()
    if m.base = invalid then return
    m.base.color = m.top.baseColor
    m.shine.color = m.top.highlightColor
end sub

sub OnRunningChanged()
    if m.anim = invalid then return
    if m.top.running then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
    end if
end sub
