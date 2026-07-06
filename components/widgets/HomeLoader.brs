sub init()
    m.loaderHost = m.top.findNode("loaderHost")
    m.loaderSpin = m.top.findNode("loaderSpin")
    m.loaderRing = m.top.findNode("loaderRing")
    m.loaderArc = m.top.findNode("loaderArc")
    m.loaderText = m.top.findNode("loaderText")
  ' spinner.tsx animate-spin — 0.9s linear revolution; clock-driven so restarts never reset angle.
    m.SPIN_PERIOD_MS = 900
    m.spinClock = CreateObject("roTimespan")
    m.spinBaseMs = 0
    m.spinTimer = CreateObject("roSGNode", "Timer")
    m.spinTimer.duration = 0.032
    m.spinTimer.repeat = true
    m.top.appendChild(m.spinTimer)
    m.spinTimer.observeField("fire", "OnSpinTick")
    m.top.visible = false
    OnColorsChanged()
end sub

sub OnRunningChanged()
    show = m.top.running = true
    m.top.visible = show
    if m.spinTimer = invalid then return
    if show then
        StartSpin()
    else
        StopSpin()
    end if
end sub

sub StartSpin()
    if m.spinClock = invalid then m.spinClock = CreateObject("roTimespan")
    if m.spinBaseMs = 0 then
        m.spinClock.Mark()
        m.spinBaseMs = m.spinClock.TotalMilliseconds()
    end if
    if m.spinTimer <> invalid then
        m.spinTimer.control = "stop"
        m.spinTimer.control = "start"
    end if
    OnSpinTick()
end sub

sub StopSpin()
    if m.spinTimer <> invalid then m.spinTimer.control = "stop"
    m.spinBaseMs = 0
end sub

sub OnSpinTick()
    if m.top.running <> true then return
    if m.loaderSpin = invalid or m.spinClock = invalid then return
    elapsed = m.spinClock.TotalMilliseconds() - m.spinBaseMs
    if elapsed < 0 then elapsed = 0
    period = m.SPIN_PERIOD_MS
    if period <= 0 then period = 900
    m.loaderSpin.rotation = (elapsed mod period) / period * 6.2831853
end sub

' Restart the tick timer without toggling running (avoids OnRunningChanged hitch).
function NudgeSpin() as boolean
    if m.top.running <> true then return false
    StartSpin()
    return true
end function

sub OnColorsChanged()
    ring = m.top.neutral50
    arc = m.top.primary600
    if ring = invalid or ring = "" then ring = "0xf5f5f5ff"
    if arc = invalid or arc = "" then arc = "0x0760bbff"
    if m.loaderRing <> invalid then m.loaderRing.blendColor = ring
    if m.loaderArc <> invalid then m.loaderArc.blendColor = arc
    if m.loaderText <> invalid then m.loaderText.color = ring
end sub
