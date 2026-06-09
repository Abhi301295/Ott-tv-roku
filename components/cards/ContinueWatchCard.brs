sub init()
    m.focusBorder = m.top.findNode("focusBorder")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.dataApplied = false
    m.reported = false
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    ApplyAll()
end sub

sub OnDataChanged()
    m.dataApplied = true
    m.reported = false
    ApplyAll()
end sub

sub OnFocusChanged()
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub

sub OnThemeChanged()
    ApplyAll()
end sub

sub OnThumbLoad()
    status = ""
    if m.thumb <> invalid then status = m.thumb.loadStatus
    CardOnPosterLoad(m.thumb, m.skeleton)
    if status = "ready" or status = "failed" then ReportLoaded()
end sub

' Notify the parent row exactly once that this card's media is ready.
' Guarded so the alwaysNotify "loaded" field never fires more than once
' (which previously corrupted the row's pending-load counter).
sub ReportLoaded()
    if not m.dataApplied then return
    if m.reported then return
    m.reported = true
    m.top.loaded = true
end sub

sub ApplyAll()
    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
        status = m.thumb.loadStatus
        if status = "ready" or status = "failed" then ReportLoaded()
    else
        m.thumb.visible = false
        m.skeleton.visible = true
        m.skeleton.running = true
        if m.dataApplied then ReportLoaded()
    end if
    CardApplySkeleton(m.skeleton, m.top.cNeutral700, m.top.cNeutral800)
    m.progressTrack.color = m.top.cNeutral950
    m.progressFill.color = m.top.cPrimary600

    pct = m.top.progress
    if pct < 0 then pct = 0
    if pct > 100 then pct = 100
    fillW = Int(540 * pct / 100)
    m.progressFill.width = fillW
    m.progressFill.visible = (pct > 0)

    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
