sub init()
    m.focusBorder = invalid
    m.cardBg = m.top.findNode("cardBg")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumbFallback = m.cardBg
    m.thumbFallbackLogo = m.top.findNode("thumbFallbackLogo")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    ' Build the gradient slices once (fixed node count); colored/sized in ApplyProgressFill.
    m.fillSegs = []
    m.FILL_SEG_COUNT = 12
    for i = 0 to m.FILL_SEG_COUNT - 1
        seg = m.progressFill.createChild("Rectangle")
        seg.height = 8
        seg.width = 0
        seg.translation = [0, 0]
        m.fillSegs.Push(seg)
    end for
    m.dataApplied = false
    m.reported = false
    m.pendingThumbUri = ""
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    ApplyAll()
end sub

sub OnDataChanged()
    m.dataApplied = true
    m.reported = false
    ApplyAll()
end sub

' Progress-only refresh (home CW resume) — repaint the bar without reloading the poster.
sub OnProgressChanged()
    ApplyProgressFill()
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
    CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 286)
    if status = "ready" or status = "failed" then ReportLoaded()
end sub

' Notify the parent row exactly once that this card's media is ready.
' Guarded so the alwaysNotify "loaded" field never fires more than once
' (which previously corrupted the row's pending-load counter).
sub ReportLoaded()
    if not m.dataApplied then return
    if m.reported then return
    if m.skeleton <> invalid and m.skeleton.visible = true then
        CwPerfInstant("card loaded BLOCKED", "skeleton still visible")
        return
    end if
    m.reported = true
    m.top.loaded = true
end sub

function ReleaseThumbLoad(dummy = invalid as dynamic) as boolean
    m.top.holdThumbLoad = false
    uri = m.pendingThumbUri
    if uri = "" then uri = m.top.thumbnailUri
    if uri = "" then
        ShowSkeletonOnly()
        return true
    end if
    m.pendingThumbUri = ""
    ' Re-apply so the poster fetch starts after the page loader is gone.
    if m.top.thumbnailUri = uri then
        StartThumbFetch(uri)
    else
        m.top.thumbnailUri = uri
    end if
    return true
end function

sub ApplyAll()
    uri = m.top.thumbnailUri
    if m.top.holdThumbLoad = true then
        if uri <> invalid and uri <> "" then m.pendingThumbUri = uri
        ShowSkeletonOnly()
        ApplyProgressFill()
        ApplyFocusVisual()
        return
    end if

    if uri <> invalid and uri <> "" then
        StartThumbFetch(uri)
    else
        CardApplyThumbPlaceholder(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 286)
        if m.dataApplied then ReportLoaded()
    end if
    bg = m.top.cPageBg
    if bg = invalid or bg = "" then bg = SkeletonDefaultPageBg()
    skColors = CardHomeCardSkeletonColors()
    if m.skeleton <> invalid and m.skeleton.visible = true then
        CardApplySkeleton(m.skeleton, skColors.base, skColors.highlight)
    end if
    if m.cardBg <> invalid then
        if m.thumbFallbackLogo <> invalid and m.thumbFallbackLogo.visible = true then
            m.cardBg.color = CardThumbFallbackFillColor(m.top)
        else
            m.cardBg.color = CardWhite10Color()
        end if
    end if
    m.progressTrack.color = CardCwProgressTrackColor()
    ApplyProgressFill()

    ApplyFocusVisual()
end sub

sub StartThumbFetch(uri as string)
    m.thumb.uri = uri
    status = m.thumb.loadStatus
    ready = (status = "ready" or status = "failed")
    if ready then
        CardOnPosterLoad(m.thumb, m.skeleton, m.thumbFallback, m.thumbFallbackLogo, m.top, 540, 286)
        ReportLoaded()
    else
        ' React continueWatchCard: shimmer + progress while img loads (img hidden until onLoad).
        if m.thumb <> invalid then m.thumb.visible = false
        if m.skeleton <> invalid then
            m.skeleton.visible = true
            m.skeleton.running = true
        end if
        if m.thumbFallback <> invalid then m.thumbFallback.visible = false
        if m.thumbFallbackLogo <> invalid then m.thumbFallbackLogo.visible = false
    end if
    skColors = CardHomeCardSkeletonColors()
    if m.skeleton <> invalid and m.skeleton.visible = true then
        CardApplySkeleton(m.skeleton, skColors.base, skColors.highlight)
    end if
    if m.cardBg <> invalid then m.cardBg.color = CardWhite10Color()
end sub

sub ShowSkeletonOnly()
    if m.thumb <> invalid then
        m.thumb.visible = false
        m.thumb.uri = ""
    end if
    if m.skeleton <> invalid then
        m.skeleton.visible = true
        m.skeleton.running = true
        skColors = CardHomeCardSkeletonColors()
        CardApplySkeleton(m.skeleton, skColors.base, skColors.highlight)
    end if
    if m.thumbFallback <> invalid then
        m.thumbFallback.visible = true
        m.thumbFallback.color = CardWhite10Color()
    end if
    if m.thumbFallbackLogo <> invalid then m.thumbFallbackLogo.visible = false
    if m.progressTrack <> invalid then m.progressTrack.color = CardCwProgressTrackColor()
end sub

sub ApplyFocusVisual()
    m.focusBorder = CardEnsureFocusFrame(m.top, m.focusBorder, 0, 0, 546, 292, m.top.cPrimary500)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub

' Smooth gradient fill: interpolate primary-500 -> primary-700 across N thin slices spanning
' the filled width (parity with React's from-primary-500 via-600 to-700, but continuous so
' the tone blends evenly instead of showing hard color steps). Fully theme-token driven.
sub ApplyProgressFill()
    pct = m.top.progress
    if pct < 0 then pct = 0
    if pct > 100 then pct = 100
    fillW = Int(540 * pct / 100)

    visible = (pct > 0)
    n = m.fillSegs.Count()
    if not visible or n = 0 then
        for each seg in m.fillSegs
            if seg <> invalid then seg.visible = false
        end for
        return
    end if

    c0 = CardHexToRgb(m.top.cPrimary500)
    c1 = CardHexToRgb(m.top.cPrimary700)

    prevEdge = 0
    for i = 0 to n - 1
        seg = m.fillSegs[i]
        if seg <> invalid then
            ' t at the slice midpoint gives a smooth ramp across the whole fill.
            t = 0.0
            if n > 1 then t = (i + 0.5) / n
            r = Int(c0[0] + (c1[0] - c0[0]) * t)
            g = Int(c0[1] + (c1[1] - c0[1]) * t)
            b = Int(c0[2] + (c1[2] - c0[2]) * t)
            ' Cumulative edges avoid sub-pixel gaps between slices.
            edge = Int((fillW * (i + 1)) / n)
            seg.translation = [prevEdge, 0]
            w = edge - prevEdge
            if w < 0 then w = 0
            seg.width = w
            seg.height = 8
            seg.color = CardRgbToHex(r, g, b)
            seg.visible = true
            prevEdge = edge
        end if
    end for
end sub
