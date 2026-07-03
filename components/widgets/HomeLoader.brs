sub init()
    m.loaderHost = m.top.findNode("loaderHost")
    m.loaderSpin = m.top.findNode("loaderSpin")
    m.loaderRing = m.top.findNode("loaderRing")
    m.loaderArc = m.top.findNode("loaderArc")
    m.loaderText = m.top.findNode("loaderText")
    m.loaderAnim = m.top.findNode("loaderAnim")
    m.top.visible = false
    OnColorsChanged()
end sub

sub OnRunningChanged()
    show = m.top.running = true
    m.top.visible = show
    if m.loaderAnim = invalid then return
    m.loaderAnim.control = "stop"
    if m.loaderSpin <> invalid then m.loaderSpin.rotation = 0.0
    if show then m.loaderAnim.control = "start"
end sub

sub OnColorsChanged()
    ring = m.top.neutral50
    arc = m.top.primary600
    if ring = invalid or ring = "" then ring = "0xf5f5f5ff"
    if arc = invalid or arc = "" then arc = "0x0760bbff"
    if m.loaderRing <> invalid then m.loaderRing.blendColor = ring
    if m.loaderArc <> invalid then m.loaderArc.blendColor = arc
    if m.loaderText <> invalid then m.loaderText.color = ring
end sub
