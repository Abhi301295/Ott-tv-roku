' HomeRowBuild.brs — incremental ContentRow creation and first-row reveal.

' Welcome dismisses only when row 0 is Continue Watching if the catalogue includes CW.
function WelcomeDismissReadyForRow0() as boolean
    if not HomeHasContinueWatchingRow() then return true
    if m.contentRowCats = invalid or m.contentRowCats.Count() = 0 then return false
    cat = m.contentRowCats[0]
    if cat = invalid then return false
    return cat.type = HC_TypeContinueWatching()
end function

' Hero catalogue data is ready once boot fetches finish and MaybeBuildHero has run
' (banner items extracted from categories). Poster paint continues after loader off.
function HomeHeroDataReady() as boolean
    if RowsBootLoading() then return false
    if not m.heroBuilt then return false
    return true
end function

' Hero poster paint — tracked for logs / trailer; does not gate the page loader.
function HomeHeroPaintComplete() as boolean
    if m.hero = invalid then return true
    if m.hero.visible <> true then return true
    if m.hero.hasField("posterReady") and m.hero.posterReady = true then return true
    return false
end function

' Page loader may drop once row widgets exist for the boot catalogue.
' Poster/card CDN paint continues after reveal (React Spinner parity).
function HomeBootPaintComplete() as boolean
    if not m.rowsBuilt then return false
    if m.contentRowCats = invalid or m.contentRowCats.Count() = 0 then return true
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return false
    return m.rowWidgets[0] <> invalid
end function

sub ConfigureHomeRowPaintGate(row as object, bootCardCount as integer)
    if row = invalid then return
    if row.hasField("requireFullRowPaint") then row.requireFullRowPaint = true
    if row.hasField("bootPaintCardCount") then row.bootPaintCardCount = bootCardCount
end sub

sub TryPrepareHomeReveal()
    if m.rowsRevealed then return
    if not HomeHeroDataReady() then
        HomeBootLog(m.bootSpan, "reveal waiting", "heroData=" + CwPerfBool(HomeHeroDataReady()) + " heroBuilt=" + CwPerfBool(m.heroBuilt) + " bootLoading=" + CwPerfBool(RowsBootLoading()))
        HomeLoaderLogBoot(m.bootSpan, "reveal waiting", "hero data gate | " + HomeLoaderGateSnapshot())
        return
    end if
    HomeLoaderLogBoot(m.bootSpan, "reveal GO", "hero data gate | " + HomeLoaderGateSnapshot())
    PrepareFirstRowReveal()
end sub

function HomeLoaderGateSnapshot() as string
    loaderRun = false
    if m.homeLoader <> invalid and m.homeLoader.running = true then loaderRun = true
    heroPoster = "n/a"
    heroVis = false
    if m.hero <> invalid then
        heroVis = (m.hero.visible = true)
        if m.hero.hasField("posterReady") then heroPoster = CwPerfBool(m.hero.posterReady = true)
    end if
    row0Paint = "n/a"
    row0Built = "n/a"
    row0Cards = "0"
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then
        r = m.rowWidgets[0]
        if r <> invalid then
            if r.hasField("paintedReady") then row0Paint = CwPerfBool(r.paintedReady = true)
            if r.hasField("built") then row0Built = CwPerfBool(r.built = true)
            if r.hasField("cardCount") then row0Cards = Str(r.cardCount)
        end if
    end if
    rowTimer = false
    if m.rowBuildTimer <> invalid and m.rowBuildTimer.control = "start" then rowTimer = true
    detail = "loaderRunning=" + CwPerfBool(loaderRun)
    detail = detail + " rowsRevealed=" + CwPerfBool(m.rowsRevealed)
    detail = detail + " selectInFlight=" + CwPerfBool(m.selectInFlight)
    detail = detail + " initialLoading=" + CwPerfBool(m.initialLoading)
    detail = detail + " continueLoading=" + CwPerfBool(m.continueLoading)
    detail = detail + " rowsBuilt=" + CwPerfBool(m.rowsBuilt)
    detail = detail + " rowsDataReady=" + CwPerfBool(m.rowsDataReady)
    detail = detail + " heroDataReady=" + CwPerfBool(HomeHeroDataReady())
    detail = detail + " heroBuilt=" + CwPerfBool(m.heroBuilt)
    detail = detail + " heroVisible=" + CwPerfBool(heroVis)
    detail = detail + " heroPosterReady=" + heroPoster
    detail = detail + " row0Painted=" + row0Paint
    detail = detail + " row0Built=" + row0Built
    detail = detail + " row0Cards=" + row0Cards
    detail = detail + " rowBuildTimer=" + CwPerfBool(rowTimer)
    detail = detail + " rowGateElapsed=" + CwPerfBool(m.rowGateElapsed)
    return detail
end function

sub OnRowsLoaderTimeout()
    HomeLoaderLogBoot(m.bootSpan, "rows loader timeout", HomeLoaderGateSnapshot())
    print "[HOME] home loader timeout -> force reveal (hero data gate)"
    HomeBootLog(m.bootSpan, "loader timeout", "force reveal")
    row0 = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row0 = m.rowWidgets[0]
    if row0 <> invalid then row0.callFunc("ForceReveal", invalid)
    if HomeHeroDataReady() then
        TryPrepareHomeReveal()
        return
    end if
    if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "start"
end sub


sub DetachFirstRowWatch()
    if m.firstRowWatch = invalid then return
    if m.firstRowWatch.hasField("paintedReady") then m.firstRowWatch.unobserveField("paintedReady")
    if m.firstRowWatch.hasField("built") then m.firstRowWatch.unobserveField("built")
    m.firstRowWatch = invalid
end sub


sub OnRowsForceHideTimer()
    HomeLoaderLogBoot(m.bootSpan, "rows force-hide timer", HomeLoaderGateSnapshot())
    print "[HOME] loader force-hide safety -> drop loader"
    if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "stop"
    row0 = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row0 = m.rowWidgets[0]
    if row0 <> invalid then row0.callFunc("ForceReveal", invalid)
    if HomeHeroDataReady() and m.homeLoader <> invalid and m.homeLoader.running = true then
        CwPerfInstant("force-hide", "hero data gate -> reveal")
        TryPrepareHomeReveal()
    else
        CwPerfInstant("force-hide skipped", "heroData=" + CwPerfBool(HomeHeroDataReady()) + " loader=" + CwPerfBool(m.homeLoader <> invalid and m.homeLoader.running = true))
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
    if m.rowsRevealed then
        m.rowsRevealed = false
        ShowHomeLoader(true)
    end if
    m.rowsDataReady = true
    m.rowGateElapsed = true
    DetachFirstRowWatch()
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
    HomeLoaderLogBoot(m.bootSpan, "BuildContentRows", "cats=" + Str(FilterContentRows(m.categories).Count()) + " | " + HomeLoaderGateSnapshot())
    ClearContentRows()

    m.contentRowCats = FilterContentRows(m.categories)
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowTops = []
    m.rowContentHeight = 0
    m.rowIndex = 0
    m.cardIndex = 0
    m.rowsHost.visible = false
    m.rowBuildSpan = CreateObject("roTimespan")
    m.cwRowBuildSpan = CreateObject("roTimespan")
    m.rowBuildCostMs = 0
    CwPerfMark(m.cwRowBuildSpan, "BuildContentRows start", "rows=" + Str(m.contentRowCats.Count()))
    HomeBootLog(m.bootSpan, "BuildContentRows", "rows=" + Str(m.contentRowCats.Count()))
    if not m.rowsRevealed then BrowseEnsureLoaderRunning(m)

    if m.contentRowCats.Count() = 0 then
        HomeBootLog(m.bootSpan, "BuildContentRows", "no rows — keep loader until refetch/reveal")
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

    if HomeLoadTurboEnabled() then
        BuildContentRowsTurbo()
        return
    end if

    ' Loader visibility is owned by PrepareFirstRowReveal; rows build underneath.
    if m.contentRowCats.Count() > 0 then
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "start"
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.duration = 0.03
        m.rowBuildTimer.control = "start"
    end if
end sub


sub SetupHomeRowPaintWatch(row as object)
    if row = invalid then return
    row.rowPeekVisible = true
    if row.cardCount = 0 then
        if WelcomeDismissReadyForRow0() then OnFirstRowPainted()
        return
    end if
    DetachFirstRowWatch()
    m.firstRowWatch = row
    row.observeField("paintedReady", "OnFirstRowPainted")
    row.observeField("built", "OnFirstRowBuilt")
    if row.hasField("paintedReady") and row.paintedReady = true then OnFirstRowPainted()
end sub


' Full row build can finish after the boot paint window — retry reveal if we deferred on built.
sub OnFirstRowBuilt()
    if m.top.dispose = true then return
    if m.rowsRevealed then return
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row = invalid or row.hasField("built") = false or row.built <> true then return
    TryPrepareHomeReveal()
end sub

' Turbo path: mount row 0, drop page loader (React data gate), cards fill in after.
sub BuildContentRowsTurbo()
    theme = HomeRowTheme()
    m.rowBuildCostMs = 0

    if m.contentRowCats.Count() > 0 then
        cat = m.contentRowCats[0]
        rowSpan = CreateObject("roTimespan")
        catName = ""
        if cat <> invalid and cat.name <> invalid then catName = cat.name
        row = CRC_CreateDataRow(m.rowsHost, cat, 0, theme, 6)
        if row <> invalid then
            row.cardFocusIndex = -1
            row.ottRowReveal = true
            row.rowPeekVisible = true
            if ThemeIsOttHome() then
                m.rowBuildY = CRC_AppendRowRecord(m, row, 0, cat)
            else
                m.rowWidgets.Push(row)
                m.rowBuildY = m.layoutRowPitch
            end if
            ReleaseHeroTrailerBoot()
            HomeLoaderLogBoot(m.bootSpan, "row0 skeleton window", "plan=" + Str(row.cardCount) + " window=6")
            SetupHomeRowPaintWatch(row)
            ' Sync-mount a couple CW skeleton+progress cards (React placeholders). More than
            ' ~2 ContinueWatchCard nodes stalls the render thread for seconds on-device/sim.
            row.callFunc("BuildCardsNow", 2)
            RevealRowsBuiltAfterHeroData()
            rowMs = rowSpan.TotalMilliseconds()
            m.rowBuildCostMs = rowMs
            print "[PERF] turbo build row 0 '"; catName; "' cards="; row.cardCount; " "; rowMs; "ms"
        end if
    end if

    m.rowBuildIndex = 1
    wall = 0
    if m.rowBuildSpan <> invalid then wall = m.rowBuildSpan.TotalMilliseconds()
    print "[PERF] turbo row0 ready wall="; wall; "ms render="; m.rowBuildCostMs; "ms"
    HomeBootLog(m.bootSpan, "turbo row0 ready", "render=" + Str(m.rowBuildCostMs) + "ms wall=" + Str(wall) + "ms")
    ' Shells are cheap (title + plan only). Mount them before reveal so Down from CW
    ' has a real next row — progressive shell ticks left LastRowIndex at 0 after loader off.
    MountRemainingRowShells()
    ' React: Spinner off when catalogue data resolves — skeleton cards already mounted.
    TryPrepareHomeReveal()
    ApplyHomeFocus()
    MaybeLandContentFocus()
end sub


' Create remaining catalogue rows as shells (no card nodes) so vertical nav targets exist
' as soon as row 0 is visible. Cards materialize via WarmWelcomeRowsWindow / PrimeFocusedRow.
sub MountRemainingRowShells()
    if m.contentRowCats = invalid then return
    if m.rowsHost = invalid then return
    if m.rowWidgets = invalid then m.rowWidgets = []
    startIdx = m.rowWidgets.Count()
    catCount = m.contentRowCats.Count()
    if startIdx < 1 then return
    if startIdx >= catCount then
        m.rowBuildIndex = catCount
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        return
    end if

    theme = HomeRowTheme()
    ' Prefer layout cursor; fall back to last row slot if Y was not advanced.
    y = m.rowBuildY
    if y = invalid then y = 0
    if ThemeIsOttHome() and m.rowTops <> invalid and m.rowTops.Count() > 0 then
        last = m.rowTops.Count() - 1
        if last >= 0 and last < m.contentRowCats.Count() then
            y = m.rowTops[last] + CRC_RowSlotHeight(m.contentRowCats[last])
        end if
    else if startIdx > 0 then
        y = startIdx * m.layoutRowPitch
    end if

    for i = startIdx to catCount - 1
        cat = m.contentRowCats[i]
        if cat = invalid then continue for
        row = CRC_CreateShellRow(m.rowsHost, cat, y, theme)
        if row = invalid then continue for
        row.cardFocusIndex = -1
        row.ottRowReveal = true
        if ThemeIsOttHome() then
            y = CRC_AppendRowRecord(m, row, y, cat)
        else
            m.rowWidgets.Push(row)
            y = y + m.layoutRowPitch
        end if
    end for

    m.rowBuildY = y
    m.rowContentHeight = y
    m.rowBuildIndex = catCount
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    HomeBootLog(m.bootSpan, "row shells mounted", "widgets=" + Str(m.rowWidgets.Count()) + " cats=" + Str(catCount))
end sub


sub ReleaseHeroTrailerBoot()
    if m.hero = invalid then return
    if m.hero.hasField("holdTrailerBoot") then m.hero.holdTrailerBoot = false
    m.hero.callFunc("ResumeHeroPlayback", invalid)
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
        row = CRC_CreateDataRow(m.rowsHost, cat, y, theme, 6)
        if row <> invalid then
            row.cardFocusIndex = -1
            row.ottRowReveal = true
            row.rowPeekVisible = true
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

    if m.rowBuildIndex = 0 then
        SetupHomeRowPaintWatch(row)
        if row <> invalid then row.callFunc("BuildCardsNow", 2)
        RevealRowsBuiltAfterHeroData()
        m.rowBuildIndex = 1
        MountRemainingRowShells()
        TryPrepareHomeReveal()
        return
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
        if HomeLoadTurboEnabled() then
            HomeBootLog(m.bootSpan, "turbo all rows built", "render=" + Str(m.rowBuildCostMs) + "ms wall=" + Str(wall) + "ms")
        end if
        ' Do not materialize row 1 or run focus scroll until CW has painted — that work
        ' was starving the render thread and caused the post-shimmer black gap.
        if m.rowsRevealed then
            ApplyHomeFocus()
            MaybeLandContentFocus()
        end if
    end if
end sub


sub RevealRowsBuiltAfterHeroData()
    if not m.rowsRevealed then return
    EnsureFirstRowVisibleUnderLoader()
    ArmCwThumbRelease()
    UpdateRowsScrim()
    ApplyHomeFocus()
    MaybeLandContentFocus()
end sub


sub WarmWelcomeRow(row as object)
    if row = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = true
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", 6)
end sub

' Pre-build rows 1–2 after the page loader drops so horizontal nav feels instant.
sub WarmWelcomeRowsWindow()
    if m.rowWidgets = invalid then return
    hi = 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = 1 to hi
        WarmWelcomeRow(m.rowWidgets[i])
    end for
end sub

' Row 0 thumbnails painted — drop the rows shimmer when CW row is ready (if applicable).
sub OnFirstRowPainted()
    if m.top.dispose = true then return
    if m.rowsRevealed then return
    HomeLoaderLogBoot(m.bootSpan, "OnFirstRowPainted", HomeLoaderGateSnapshot())
    if not WelcomeDismissReadyForRow0() then
        HomeBootLog(m.bootSpan, "row0 painted skip", "waiting for CW row")
        return
    end if
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row <> invalid and row.hasField("paintedReady") and row.paintedReady <> true then return
    DetachFirstRowWatch()
    m.cwRevealAtMs = CwPerfMs(m.cwShimmerSpan)
    HomeBootLog(m.bootSpan, "row0 paintedReady", "reveal loader")
    LogCwRowState("paintedReady -> pre-hide")
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.duration = 0.03
    TryPrepareHomeReveal()
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
    if m.homeLoader <> invalid and m.homeLoader.running <> invalid then
        pulseVis = m.homeLoader.running
    end if
    detail = "rowOp=" + Str(row.opacity) + " cardsHostOp=" + Str(chop)
    detail = detail + " peek=" + CwPerfBool(row.rowPeekVisible) + " focused=" + CwPerfBool(row.rowFocused)
    detail = detail + " loaderRunning=" + CwPerfBool(pulseVis) + " zone=" + m.focusZone
    CwPerfInstant(tag, detail)
end sub

function HomeFirstRowPaintComplete() as boolean
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return true
    row0 = m.rowWidgets[0]
    if row0 = invalid then return true
    if row0.hasField("paintedReady") and row0.paintedReady <> true then return false
    ' Boot row: paintedReady means the first-screen window is painted — do not wait for see-all / off-screen cards.
    bootWindow = false
    if row0.hasField("bootPaintCardCount") and row0.bootPaintCardCount > 0 then bootWindow = true
    if not bootWindow then
        if row0.hasField("built") and row0.built <> true and row0.cardCount > 0 then return false
    end if
    if row0.opacity < 1.0 then return false
    host = row0.findNode("cardsHost")
    if host <> invalid and host.opacity < 1.0 then return false
    return true
end function

' Drop the page loader once hero catalogue data is ready; rows/posters keep loading after.
sub PrepareFirstRowReveal()
    if m.rowsRevealed then return
    HomeLoaderLogBoot(m.bootSpan, "PrepareFirstRowReveal enter", HomeLoaderGateSnapshot())
    if not HomeHeroDataReady() then
        HomeBootLog(m.bootSpan, "reveal deferred", "heroData=" + CwPerfBool(HomeHeroDataReady()) + " heroBuilt=" + CwPerfBool(m.heroBuilt))
        return
    end if
    m.rowsRevealed = true
    HomeLoaderLogBoot(m.bootSpan, "home revealed — loader OFF", HomeLoaderGateSnapshot())
    HomeBootLog(m.bootSpan, "home revealed", "loader off (hero data gate)")
    LogCwRowState("hero data ready -> hide loader")
    ShowHomeLoader(false)
    EnsureFirstRowVisibleUnderLoader()
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then ArmCwThumbRelease()
    UpdateRowsScrim()
    LogCwRowState("loader hidden")
    ApplyHomeFocus()
    MaybeLandContentFocus()
    WarmWelcomeRowsWindow()
    LogCwRowState("post-focus zone=" + m.focusZone)
end sub

sub ArmCwThumbRelease()
    if m.cwThumbReleaseTimer = invalid then
        m.cwThumbReleaseTimer = CreateObject("roSGNode", "Timer")
        m.cwThumbReleaseTimer.duration = 0.4
        m.cwThumbReleaseTimer.repeat = false
        m.top.appendChild(m.cwThumbReleaseTimer)
        m.cwThumbReleaseTimer.observeField("fire", "OnCwThumbRelease")
    end if
    m.cwThumbReleaseTimer.control = "stop"
    m.cwThumbReleaseTimer.control = "start"
end sub

sub OnCwThumbRelease()
    if m.top.dispose = true then return
    ReleaseRow0BootThumbs()
end sub

sub ReleaseRow0BootThumbs()
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return
    row0 = m.rowWidgets[0]
    if row0 = invalid then return
    row0.callFunc("ReleaseBootThumbHolds", invalid)
end sub


sub EnsureFirstRowVisibleUnderLoader()
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

