sub init()
    m.heroPulse = m.top.findNode("heroPulse")
    m.rowsPulse = m.top.findNode("rowsPulse")
    m.rowsTitle = m.top.findNode("rowsTitle")
    m.heroAnim = m.top.findNode("heroAnim")
    m.rowsAnim = m.top.findNode("rowsAnim")
end sub

' Either region running keeps the shared pulse animation alive; each region's own
' visibility is driven independently so the hero and rows can reveal separately.
sub OnRunningChanged()
    if m.heroPulse <> invalid then m.heroPulse.visible = m.top.heroRunning
    if m.rowsPulse <> invalid then
        if m.top.rowsRunning then
            m.rowsPulse.opacity = 1.0
            m.rowsPulse.visible = true
        else if m.rowsPulse.visible then
            ' Hard cut once real cards are painted — a dissolve exposes black underneath.
            m.rowsPulse.visible = false
            m.rowsPulse.opacity = 1.0
        end if
    end if
    ' Do NOT show a "Continue Watching" label during loading: a profile may have no CW
    ' row at all, and flashing the label before the data lands is wrong (parity: React
    ' shows a neutral spinner while loading, then the real row supplies its own title).
    if m.rowsTitle <> invalid then m.rowsTitle.visible = false

    ' Hero pulse animates the whole time the hero is loading.
    if m.heroAnim <> invalid then
        if m.top.heroRunning then
            m.heroAnim.control = "start"
        else
            m.heroAnim.control = "stop"
        end if
    end if

    if m.rowsAnim <> invalid then
        if m.top.rowsRunning then
            m.rowsAnim.control = "start"
        else
            m.rowsAnim.control = "stop"
        end if
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
        if bar <> invalid and bar.hasField("color") then
            ' Keep all HomeSkeleton placeholders on one visual system:
            ' base = neutral-800-ish, shine = neutral-700-ish.
            if Right(bar.id, 5) = "Shine" or Left(bar.id, 8) = "rowShine" then
                bar.color = "0x404040ff"
            else
                bar.color = color
            end if
        end if
    end for
end sub
