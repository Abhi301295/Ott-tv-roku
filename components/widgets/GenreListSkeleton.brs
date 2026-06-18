sub init()
    m.heroPulse = m.top.findNode("heroPulse")
    m.rowsPulse = m.top.findNode("rowsPulse")
    ApplyColors()
    SyncRunning()
end sub

sub OnRunningChanged()
    SyncRunning()
end sub

sub OnColorsChanged()
    ApplyColors()
end sub

sub ApplyColors()
    base = m.top.baseColor
    hi = m.top.highlightColor
    if base = invalid or base = "" then base = "0x404040ff"
    if hi = invalid or hi = "" then hi = "0x262626ff"
    for each id in ["skHeroTitle", "skHeroRating", "skHeroGenre", "skHeroDesc", "skCard0", "skCard1", "skCard2", "skCard3"]
        sk = m.top.findNode(id)
        if sk <> invalid then CardApplySkeleton(sk, base, hi)
    end for
end sub

sub SyncRunning()
    heroOn = m.top.heroRunning
    rowsOn = m.top.rowsRunning
    if m.heroPulse <> invalid then m.heroPulse.visible = heroOn
    if m.rowsPulse <> invalid then m.rowsPulse.visible = rowsOn
    for each id in ["skHeroTitle", "skHeroRating", "skHeroGenre", "skHeroDesc"]
        sk = m.top.findNode(id)
        if sk <> invalid and sk.hasField("running") then sk.running = heroOn
    end for
    for each id in ["skCard0", "skCard1", "skCard2", "skCard3"]
        sk = m.top.findNode(id)
        if sk <> invalid and sk.hasField("running") then sk.running = rowsOn
    end for
end sub
