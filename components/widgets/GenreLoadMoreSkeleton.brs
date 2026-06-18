sub init()
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
    for each id in ["skR0C0", "skR0C1", "skR0C2", "skR0C3", "skR1C0", "skR1C1", "skR1C2", "skR1C3"]
        sk = m.top.findNode(id)
        if sk <> invalid then CardApplySkeleton(sk, base, hi)
    end for
end sub

sub SyncRunning()
    on = m.top.running
    for each id in ["skR0C0", "skR0C1", "skR0C2", "skR0C3", "skR1C0", "skR1C1", "skR1C2", "skR1C3"]
        sk = m.top.findNode(id)
        if sk <> invalid and sk.hasField("running") then sk.running = on
    end for
end sub
