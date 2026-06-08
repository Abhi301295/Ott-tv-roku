sub init()
    m.pulse = m.top.findNode("pulse")
    m.anim = m.top.findNode("anim")
end sub

sub OnRunningChanged()
    if m.anim = invalid then return
    if m.top.running then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
    end if
end sub

sub OnColorsChanged()
    if m.pulse = invalid then return
    color = m.top.boxColor
    if color = invalid or color = "" then return
    count = m.pulse.getChildCount()
    for i = 0 to count - 1
        bar = m.pulse.getChild(i)
        if bar <> invalid and bar.hasField("color") then bar.color = color
    end for
end sub
