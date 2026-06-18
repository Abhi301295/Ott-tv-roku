sub init()
    m.heroPulse = m.top.findNode("heroPulse")
    m.rowsPulse = m.top.findNode("rowsPulse")
    m.rowsTitle = m.top.findNode("rowsTitle")
    m.heroAnim = m.top.findNode("heroAnim")
    m.rowsAnim = m.top.findNode("rowsAnim")
    ApplySkeletonLayout()
end sub

sub OnLayoutChanged()
    ApplySkeletonLayout()
end sub

' Reposition placeholder bars to match the active home layout (Netflix vs OTT anchor
' and card geometry). HomeScreen sets layoutMode + anchorY from ThemeConfig.
sub ApplySkeletonLayout()
    mode = m.top.layoutMode
    if mode = invalid or mode = "" then mode = "netflix"
    anchorY = m.top.anchorY
    if anchorY = invalid or anchorY < 1 then anchorY = HC_NetflixAnchorY()

    cardsY = anchorY + HC_RowCardsTop()
    cardW = 540
    cardH = 286
    startX = 32

    if mode = "ott" then
        ' OTT hero metadata (HeroBannerOtt metaHost at 48,200).
        PlaceBar("hTitle", 48, 200, 600, 60)
        PlaceBar("hGenre", 48, 352, 400, 22)
        PlaceBar("hDesc1", 48, 268, 520, 22)
        PlaceBar("hDesc2", 48, 380, 480, 18)
        ' OTT rows use horizontal cards while loading (content.tsx default).
        cardW = 556
        cardH = 312
    else
        ' Netflix cinematic hero metadata (HeroBannerCinematic metaHost at 64,300).
        PlaceBar("hTitle", 64, 300, 520, 54)
        PlaceBar("hGenre", 64, 444, 360, 22)
        PlaceBar("hDesc1", 64, 490, 630, 18)
        PlaceBar("hDesc2", 64, 518, 580, 18)
    end if

    gap = HC_CardGap()
    for i = 1 to 4
        x = startX + (i - 1) * (cardW + gap)
        PlaceBar("rowBox" + i.ToStr(), x, cardsY, cardW, cardH)
        PlaceBar("rowShine" + i.ToStr(), x, cardsY, cardW, cardH)
    end for
end sub

sub PlaceBar(id as string, x as integer, y as integer, w as integer, h as integer)
    bar = m.top.findNode(id)
    if bar = invalid then return
    bar.translation = [x, y]
    bar.width = w
    bar.height = h
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
            if Right(bar.id, 5) = "Shine" or Left(bar.id, 8) = "rowShine" then
                bar.color = "0x404040ff"
            else
                bar.color = color
            end if
        end if
    end for
end sub
