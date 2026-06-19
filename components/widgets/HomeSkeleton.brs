sub init()
    m.heroPulse = m.top.findNode("heroPulse")
    m.rowsPulse = m.top.findNode("rowsPulse")
    m.rowsTitle = m.top.findNode("rowsTitle")
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.heroBackdropShine = m.top.findNode("heroBackdropShine")
    m.heroAnim = m.top.findNode("heroAnim")
    m.rowsAnim = m.top.findNode("rowsAnim")
    m.heroBarIds = ["hTitle", "hGenre", "hDesc1", "hDesc2"]
    m.rowBarIds = ["rowBox1", "rowBox2", "rowBox3", "rowBox4"]
    ApplySkeletonLayout()
end sub

sub OnLayoutChanged()
    ApplySkeletonLayout()
end sub

sub ApplySkeletonLayout()
    mode = m.top.layoutMode
    if mode = invalid or mode = "" then mode = "netflix"
    anchorY = m.top.anchorY
    if anchorY = invalid or anchorY < 1 then anchorY = HC_NetflixAnchorY()

    heroH = HC_HeroHeight()
    PlaceBar("heroBackdrop", 0, 0, 1920, heroH)
    PlaceBar("heroBackdropShine", 0, 0, 1920, heroH)

    cardsY = anchorY + HC_RowCardsTop()
    cardW = 540
    cardH = 286
    startX = 32

    if mode = "ott" then
        PlaceHeroBar("hTitle", 48, 200, 600, 60)
        PlaceHeroBar("hGenre", 48, 352, 400, 22)
        PlaceHeroBar("hDesc1", 48, 268, 520, 22)
        PlaceHeroBar("hDesc2", 48, 380, 480, 18)
        cardW = 556
        cardH = 312
    else
        PlaceHeroBar("hTitle", 64, 300, 520, 54)
        PlaceHeroBar("hGenre", 64, 444, 360, 22)
        PlaceHeroBar("hDesc1", 64, 490, 630, 18)
        PlaceHeroBar("hDesc2", 64, 518, 580, 18)
    end if

    gap = HC_CardGap()
    for i = 1 to 4
        x = startX + (i - 1) * (cardW + gap)
        PlaceRowBar(i, x, cardsY, cardW, cardH)
    end for
end sub

sub PlaceHeroBar(baseId as string, x as integer, y as integer, w as integer, h as integer)
    PlaceBar(baseId, x, y, w, h)
    PlaceBar(baseId + "Shine", x, y, w, h)
end sub

sub PlaceRowBar(index as integer, x as integer, y as integer, w as integer, h as integer)
    PlaceBar("rowBox" + index.ToStr(), x, y, w, h)
    PlaceBar("rowShine" + index.ToStr(), x, y, w, h)
end sub

sub PlaceBar(id as string, x as integer, y as integer, w as integer, h as integer)
    bar = m.top.findNode(id)
    if bar = invalid then return
    bar.translation = [x, y]
    bar.width = w
    bar.height = h
end sub

sub OnRunningChanged()
    if m.heroPulse <> invalid then m.heroPulse.visible = m.top.heroRunning
    if m.rowsPulse <> invalid then
        if m.top.rowsRunning then
            m.rowsPulse.opacity = 1.0
            m.rowsPulse.visible = true
        else if m.rowsPulse.visible then
            m.rowsPulse.visible = false
            m.rowsPulse.opacity = 1.0
        end if
    end if
    if m.rowsTitle <> invalid then m.rowsTitle.visible = false

    if m.heroAnim <> invalid then
        if m.top.heroRunning then
            ResetHeroShine()
            m.heroAnim.control = "start"
        else
            m.heroAnim.control = "stop"
            ResetHeroShine()
        end if
    end if

    if m.rowsAnim <> invalid then
        if m.top.rowsRunning then
            ResetRowShine()
            m.rowsAnim.control = "start"
        else
            m.rowsAnim.control = "stop"
            ResetRowShine()
        end if
    end if
end sub

' Bases stay fully opaque; only highlight overlays animate.
sub ResetHeroShine()
    if m.heroBackdrop <> invalid then m.heroBackdrop.opacity = 1.0
    if m.heroBackdropShine <> invalid then m.heroBackdropShine.opacity = 0.0
    for each id in m.heroBarIds
        bar = m.top.findNode(id)
        if bar <> invalid then bar.opacity = 1.0
        shine = m.top.findNode(id + "Shine")
        if shine <> invalid then shine.opacity = 0.0
    end for
end sub

sub ResetRowShine()
    for each id in m.rowBarIds
        bar = m.top.findNode(id)
        if bar <> invalid then bar.opacity = 1.0
        idx = Right(id, 1)
        shine = m.top.findNode("rowShine" + idx)
        if shine <> invalid then shine.opacity = 0.0
    end for
end sub

sub OnColorsChanged()
    base = m.top.boxColor
    shine = m.top.shineColor
    backdrop = m.top.backdropColor
    if base = invalid or base = "" then return
    if shine = invalid or shine = "" then shine = CardLightenHex(base, 56)
    if backdrop = invalid or backdrop = "" then backdrop = "0xe5e5e5ff"
    if m.heroBackdrop <> invalid then m.heroBackdrop.color = backdrop
    if m.heroBackdropShine <> invalid then m.heroBackdropShine.color = CardLightenHex(backdrop, 28)
    TintBarPair(m.heroBarIds, base, shine)
    TintRowBars(base, shine)
end sub

sub TintBarPair(ids as object, base as string, shine as string)
    for each id in ids
        bar = m.top.findNode(id)
        if bar <> invalid and bar.hasField("color") then bar.color = base
        hi = m.top.findNode(id + "Shine")
        if hi <> invalid and hi.hasField("color") then hi.color = shine
    end for
end sub

sub TintRowBars(base as string, shine as string)
    for i = 1 to 4
        bar = m.top.findNode("rowBox" + i.ToStr())
        if bar <> invalid and bar.hasField("color") then bar.color = base
        hi = m.top.findNode("rowShine" + i.ToStr())
        if hi <> invalid and hi.hasField("color") then hi.color = shine
    end for
end sub
