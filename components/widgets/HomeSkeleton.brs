sub init()
    m.heroPulse = m.top.findNode("heroPulse")
    m.rowsPulse = m.top.findNode("rowsPulse")
    m.rowsTitle = m.top.findNode("rowsTitle")
    m.anim = m.top.findNode("anim")
end sub

' Either region running keeps the shared pulse animation alive; each region's own
' visibility is driven independently so the hero and rows can reveal separately.
sub OnRunningChanged()
    if m.heroPulse <> invalid then m.heroPulse.visible = m.top.heroRunning
    if m.rowsPulse <> invalid then m.rowsPulse.visible = m.top.rowsRunning
    ' Do NOT show a "Continue Watching" label during loading: a profile may have no CW
    ' row at all, and flashing the label before the data lands is wrong (parity: React
    ' shows a neutral spinner while loading, then the real row supplies its own title).
    if m.rowsTitle <> invalid then m.rowsTitle.visible = false

    if m.anim = invalid then return
    if m.top.heroRunning or m.top.rowsRunning then
        m.anim.control = "start"
    else
        m.anim.control = "stop"
    end if
end sub

sub OnColorsChanged()
    color = m.top.boxColor
    if color = invalid or color = "" then return
    TintGroup(m.heroPulse, color)
    TintGroup(m.rowsPulse, color)
end sub

sub TintGroup(grp as object, color as string)
    if grp = invalid then return
    count = grp.getChildCount()
    for i = 0 to count - 1
        bar = grp.getChild(i)
        ' Leave the large poster block on its darker base color; only tint the lines.
        if bar <> invalid and bar.hasField("color") and bar.id <> "hPoster" then
            bar.color = color
        end if
    end for
end sub
