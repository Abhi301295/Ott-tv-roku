' HomeRowBuild.brs — incremental ContentRow creation and first-row reveal.


sub OnRowsSkeletonTimeout()
    print "[HOME] rows skeleton timeout -> force first row reveal"
    HomeBootLog(m.bootSpan, "rows skeleton timeout", "force reveal")
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then
        row0 = m.rowWidgets[0]
        if row0 <> invalid then row0.callFunc("ForceReveal", invalid)
    end if
    if ThemeIsOttHome() and m.homeSkeleton <> invalid and m.homeSkeleton.rowsRunning = true then
        PrepareFirstRowReveal()
        return
    end if
    if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "start"
end sub


sub DetachFirstRowWatch()
    if m.firstRowWatch = invalid then return
    if m.firstRowWatch.hasField("paintedReady") then m.firstRowWatch.unobserveField("paintedReady")
    if m.firstRowWatch.hasField("mediaReady") then m.firstRowWatch.unobserveField("mediaReady")
    m.firstRowWatch = invalid
end sub


sub OnRowsForceHideTimer()
    print "[HOME] rows force-hide safety -> drop shimmer"
    if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "stop"
    row0 = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row0 = m.rowWidgets[0]
    painted = false
    if row0 <> invalid and row0.hasField("paintedReady") then painted = row0.paintedReady
    if painted and m.homeSkeleton <> invalid and m.homeSkeleton.rowsRunning = true then
        CwPerfInstant("force-hide", "paintedReady=true -> reveal")
        PrepareFirstRowReveal()
    else
        CwPerfInstant("force-hide skipped", "paintedReady=" + CwPerfBool(painted) + " shimmer=" + CwPerfBool(m.homeSkeleton <> invalid and m.homeSkeleton.rowsRunning = true))
    end if
end sub

' Skeleton bars — same palette as Profile / SkeletonConfig.brs (login excluded).

' ── Content rows (parity with netflixContent.tsx row list) ───────────────────

' OTT may build rows before CW lands; prepend CW into the visible list when it arrives late.
sub MaybeInsertLateContinueWatchingRow()
    if not m.rowsBuilt then return
    cats = FilterContentRows(m.categories)
    if cats.Count() = 0 then return
    first = cats[0]
    if first = invalid or first.type <> HC_TypeContinueWatching() then return
    if m.contentRowCats <> invalid and m.contentRowCats.Count() > 0 then
        cur = m.contentRowCats[0]
        if cur <> invalid and cur.type = HC_TypeContinueWatching() then return
    end if
    HomeBootLog(m.bootSpan, "late CW merge", "rebuild row list")
    m.rowsBuilt = false
    m.rowsDataReady = true
    m.rowGateElapsed = true
    MaybeStartRowBuild()
end sub

' Building every card up-front blocks the render thread for several seconds, so the
' rows are created one per timer tick: the hero/header/background paint immediately
' and rows pop in top-to-bottom while the thread stays responsive.

' Building every card up-front blocks the render thread for several seconds, so the
' rows are created one per timer tick: the hero/header/background paint immediately
' and rows pop in top-to-bottom while the thread stays responsive.
sub BuildContentRows()
    if m.rowsHost = invalid then return
    ClearContentRows()

    m.contentRowCats = FilterContentRows(m.categories)
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowTops = []
    m.rowContentHeight = 0
    m.rowIndex = 0
    m.cardIndex = 0
    m.rowsHost.visible = (m.contentRowCats.Count() > 0)
    ' Row build timing (CwPerfMark/HomeBootLog are no-ops unless re-enabled in HomePerf.brs).
    m.rowBuildSpan = CreateObject("roTimespan")
    m.cwRowBuildSpan = CreateObject("roTimespan")
    m.rowBuildCostMs = 0
    CwPerfMark(m.cwRowBuildSpan, "BuildContentRows start", "rows=" + Str(m.contentRowCats.Count()))
    HomeBootLog(m.bootSpan, "BuildContentRows", "rows=" + Str(m.contentRowCats.Count()))

    if m.contentRowCats.Count() = 0 then
        HomeBootLog(m.bootSpan, "BuildContentRows", "no rows")
        if ProfileTransitionActive() then HideProfileWelcomeTransition()
        ShowRowsSkeleton(false)
        if m.categoriesPrefetched = true then
            m.categoriesPrefetched = false
            m.categories = []
            m.initialLoading = true
            m.continueLoading = true
            m.heroBuilt = false
            m.rowsBuilt = false
            m.rowsDataReady = false
            m.contentBootStarted = false
            BootHomeContent()
        end if
        return
    end if

    ' Skeleton visibility is owned by OnHeroPosterReady / OnSkeletonTimeout, so we don't
    ' toggle it here — rows build underneath and the shimmer drops once the hero paints.
    if m.contentRowCats.Count() > 0 then
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "start"
        if ProfileTransitionActive() then
            if m.rowBuildTimer <> invalid then m.rowBuildTimer.duration = 0.01
            ScheduleDeferredRowBuildStart()
        else
            if m.rowBuildTimer <> invalid then m.rowBuildTimer.duration = 0.03
            m.rowBuildTimer.control = "start"
        end if
    end if
end sub


sub ScheduleDeferredRowBuildStart()
    if m.rowBuildDeferTimer = invalid then
        m.rowBuildDeferTimer = CreateObject("roSGNode", "Timer")
        m.rowBuildDeferTimer.duration = 0.045
        m.rowBuildDeferTimer.repeat = false
        m.top.appendChild(m.rowBuildDeferTimer)
        m.rowBuildDeferTimer.observeField("fire", "OnRowBuildDefer")
    end if
    m.rowBuildDeferTimer.control = "stop"
    m.rowBuildDeferTimer.control = "start"
end sub


sub OnRowBuildDefer()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "start"
end sub


sub OnRowBuildTick()
    if m.top.dispose = true then
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        return
    end if
    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
        return
    end if

    cat = m.contentRowCats[m.rowBuildIndex]
    catName = ""
    if cat <> invalid and cat.name <> invalid then catName = cat.name

    ' Measure the render-thread cost of building this one row (node creation + card
    ' population is the real Roku bottleneck — this is the number that matters).
    span = CreateObject("roTimespan")
    theme = HomeRowTheme()
    y = m.rowBuildY
    if m.rowBuildIndex = 0 then
        row = CRC_CreateDataRow(m.rowsHost, cat, y, theme)
        if row <> invalid then
            row.cardFocusIndex = -1
            if cat <> invalid and cat.type <> HC_TypeContinueWatching() then
                row.ottRowReveal = true
            else
                row.ottRowReveal = false
            end if
        end if
    else
        row = CRC_CreateShellRow(m.rowsHost, cat, y, theme)
        if row <> invalid then
            row.cardFocusIndex = -1
            row.ottRowReveal = true
        end if
    end if
    if ThemeIsOttHome() then
        if row <> invalid then m.rowBuildY = CRC_AppendRowRecord(m, row, y, cat)
    else
        if row <> invalid then
            m.rowWidgets.Push(row)
            m.rowBuildY = y + m.layoutRowPitch
        end if
    end if
    rowMs = span.TotalMilliseconds()
    if m.rowBuildCostMs = invalid then m.rowBuildCostMs = 0
    m.rowBuildCostMs = m.rowBuildCostMs + rowMs
    print "[PERF] build row "; m.rowBuildIndex; " '"; catName; "' cards="; row.cardCount; " "; rowMs; "ms"

    addedIdx = m.rowWidgets.Count() - 1
    if ProfileTransitionActive() and addedIdx > 0 and addedIdx < 3 then
        WarmWelcomeRow(m.rowWidgets[addedIdx])
    end if

    ' Drop welcome overlay as soon as row 0 media resolves; paintedReady is a fallback.
    if m.rowBuildIndex = 0 then
        row.rowPeekVisible = true
        if row.cardCount = 0 then
            OnFirstRowPainted()
        else
            DetachFirstRowWatch()
            m.firstRowWatch = row
            row.observeField("mediaReady", "OnFirstRowMediaReady")
            row.observeField("paintedReady", "OnFirstRowPainted")
            if row.hasField("mediaReady") and row.mediaReady = true then OnFirstRowMediaReady()
        end if
    end if

    m.rowBuildIndex = m.rowBuildIndex + 1

    ' Touch only the row we just built — the full ApplyHomeFocus (which also drives the
    ' rows-host scroll animation) runs once the build completes, not on every tick.
    ApplyRowFocusState(m.rowWidgets.Count() - 1)

    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
        m.rowContentHeight = m.rowBuildY
        wall = 0
        if m.rowBuildSpan <> invalid then wall = m.rowBuildSpan.TotalMilliseconds()
        print "[PERF] all rows built: "; m.rowBuildIndex; " rows, render-cost="; m.rowBuildCostMs; "ms, wall="; wall; "ms"
        ' Do not materialize row 1 or run focus scroll until CW has painted — that work
        ' was starving the render thread and caused the post-shimmer black gap.
        if m.rowsRevealed then
            ApplyHomeFocus()
            MaybeLandContentFocus()
        else if ProfileTransitionActive() and m.rowBuildIndex >= m.contentRowCats.Count() then
            WarmWelcomeRowsWindow()
        end if
    end if
end sub


sub WarmWelcomeRow(row as object)
    if row = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = true
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", 6)
end sub

' While the welcome overlay is up, pre-build the first content rows so landing is instant.
sub WarmWelcomeRowsWindow()
    if m.rowWidgets = invalid then return
    hi = 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = 1 to hi
        WarmWelcomeRow(m.rowWidgets[i])
    end for
end sub

' Row 0 cards resolved (media loaded) — dismiss welcome overlay; paintedReady is fallback.

' Row 0 cards resolved (media loaded) — dismiss welcome overlay; paintedReady is fallback.
sub OnFirstRowMediaReady()
    if m.top.dispose = true then return
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row = invalid then return
    if row.hasField("mediaReady") and row.mediaReady <> true then return

    HomeBootLog(m.bootSpan, "row0 mediaReady", "hide welcome overlay")
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.duration = 0.03
    if ProfileTransitionActive() then HideProfileWelcomeTransition()
    if not m.rowsRevealed then PrepareFirstRowReveal()
end sub

' The Continue Watching row finished painting — drop the shimmer over real cards.

' The Continue Watching row finished painting — drop the shimmer over real cards.
sub OnFirstRowPainted()
    if m.rowsRevealed then return
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row <> invalid and row.hasField("paintedReady") and row.paintedReady <> true then return
    DetachFirstRowWatch()
    m.cwRevealAtMs = CwPerfMs(m.cwShimmerSpan)
    LogCwRowState("paintedReady -> pre-hide")
    PrepareFirstRowReveal()
end sub


sub LogCwRowState(tag as string)
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row = invalid then
        CwPerfInstant(tag, "row=missing")
        return
    end if
    chop = -1.0
    host = row.findNode("cardsHost")
    if host <> invalid then chop = host.opacity
    pulseVis = false
    if m.homeSkeleton <> invalid and m.homeSkeleton.rowsRunning <> invalid then
        pulseVis = m.homeSkeleton.rowsRunning
    end if
    detail = "rowOp=" + Str(row.opacity) + " cardsHostOp=" + Str(chop)
    detail = detail + " peek=" + CwPerfBool(row.rowPeekVisible) + " focused=" + CwPerfBool(row.rowFocused)
    detail = detail + " shimmerRunning=" + CwPerfBool(pulseVis) + " zone=" + m.focusZone
    CwPerfInstant(tag, detail)
end sub

' Cut the HomeSkeleton row strip before revealing real cards so the two shimmer
' systems (HomeSkeleton rectangles vs per-card Skeleton widgets) never overlap.

' Cut the HomeSkeleton row strip before revealing real cards so the two shimmer
' systems (HomeSkeleton rectangles vs per-card Skeleton widgets) never overlap.
sub PrepareFirstRowReveal()
    if m.rowsRevealed then
        if ProfileTransitionActive() then HideProfileWelcomeTransition()
        return
    end if
    m.rowsRevealed = true
    HomeBootLog(m.bootSpan, "rows revealed", "shimmer off")
    LogCwRowState("cards painted -> hide shimmer")
    if ProfileTransitionActive() then HideProfileWelcomeTransition()
    ShowRowsSkeleton(false)
    EnsureFirstRowVisibleUnderShimmer()
    UpdateRowsScrim()
    LogCwRowState("shimmer hidden")
    ApplyHomeFocus()
    MaybeLandContentFocus()
    LogCwRowState("post-focus zone=" + m.focusZone)
    WarmWelcomeRowsWindow()
end sub


sub EnsureFirstRowVisibleUnderShimmer()
    if m.rowsHost <> invalid then m.rowsHost.visible = true
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return
    row0 = m.rowWidgets[0]
    if row0 = invalid then return
    if row0.hasField("rowPeekVisible") then row0.rowPeekVisible = true
    row0.opacity = 1.0
    host = row0.findNode("cardsHost")
    if host <> invalid and host.opacity < 1.0 then host.opacity = 1.0
    title = row0.findNode("rowTitle")
    if title <> invalid and title.opacity < 1.0 then title.opacity = 1.0
end sub


sub ClearContentRows()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    m.rowWidgets = []
    CRC_ClearHost(m.rowsHost)
end sub


function OttRowsContentHeight() as integer
    if m.rowContentHeight <> invalid and m.rowContentHeight > 0 then return m.rowContentHeight
    return CRC_ContentHeight(m.rowTops, m.contentRowCats)
end function

