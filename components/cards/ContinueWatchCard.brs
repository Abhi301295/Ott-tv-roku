sub init()
    m.focusBorder = invalid
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFillA = m.top.findNode("progressFillA")
    m.progressFillB = m.top.findNode("progressFillB")
    m.progressFillC = m.top.findNode("progressFillC")
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
    ApplyFocusVisual()
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
    ApplyProgressFill()

    ApplyFocusVisual()
end sub

sub ApplyFocusVisual()
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 0, 0, 546, 292, m.top.cPrimary500)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub

' Lay out the 3 fill segments left→right across the filled width, colored primary
' 500/600/700 to approximate React's from-primary-500 via-600 to-700 progress gradient.
sub ApplyProgressFill()
    pct = m.top.progress
    if pct < 0 then pct = 0
    if pct > 100 then pct = 100
    fillW = Int(540 * pct / 100)

    m.progressFillA.color = m.top.cPrimary500
    m.progressFillB.color = m.top.cPrimary600
    m.progressFillC.color = m.top.cPrimary700

    visible = (pct > 0)
    m.progressFillA.visible = visible
    m.progressFillB.visible = visible
    m.progressFillC.visible = visible
    if not visible then return

    segA = Int(fillW / 3)
    segB = Int(fillW / 3)
    segC = fillW - segA - segB

    m.progressFillA.translation = [0, 278]
    m.progressFillA.width = segA
    m.progressFillB.translation = [segA, 278]
    m.progressFillB.width = segB
    m.progressFillC.translation = [segA + segB, 278]
    m.progressFillC.width = segC
end sub
