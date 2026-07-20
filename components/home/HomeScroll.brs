' HomeScroll.brs — rows-host scroll animation and input-priority prefetch.


sub ResumeFocusedRowBuild()
    if m.rowWidgets = invalid or m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row <> invalid then row.callFunc("ResumeBuild", invalid)
end sub


' Materialize deferred row shells within a 1-row prefetch window around focus.
' Neighbors keep building during idle so lower rows finish while the user watches the hero.
sub MaterializeNearbyRows()
    if not m.rowsRevealed then return
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return
    lo = m.rowIndex - 1
    if lo < 0 then lo = 0
    hi = m.rowIndex + 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = lo to hi
        row = m.rowWidgets[i]
        if row <> invalid then
            if row.hasField("ottRowReveal") then row.ottRowReveal = true
            row.callFunc("Materialize", invalid)
            if i = m.rowIndex then row.callFunc("ResumeBuild", invalid)
        end if
    end for
end sub


' Keep the row backdrop transparent in both loading and loaded states. The row shimmer owns
' the loading affordance, and React/LG keeps the hero visible behind the content rows.
sub UpdateRowsScrim()
    if m.rowsScrim <> invalid then m.rowsScrim.opacity = 0.0
    if m.rowsScrimGrad <> invalid then m.rowsScrimGrad.opacity = 0.0
end sub

' Smooth row pinning (parity with netflixContent.tsx). User keys snap instantly so
' row translation paints before deferred card construction resumes.
sub AnimateRowsHost(targetY as integer)
    if m.rowsHost = invalid then return
    offX = 0
    if m.layoutOffsetX <> invalid then offX = m.layoutOffsetX
    fromY = m.rowsHost.translation[1]
    if m.interacting then
        if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"
        m.rowsHost.translation = [offX, targetY]
        return
    end if
    if m.rowsAnim = invalid or m.rowsInterp = invalid or fromY = targetY then
        m.rowsHost.translation = [offX, targetY]
        return
    end if
    m.rowsInterp.keyValue = [[offX, fromY], [offX, targetY]]
    m.rowsAnim.control = "start"
end sub


sub OnRowsAnimState()
    if m.rowsAnim = invalid then return
    if m.rowsAnim.state <> "stopped" then return
    RunRowPrefetchPass()
end sub


sub ScheduleRowPrefetch()
    if not m.rowsRevealed then return
    if m.focusZone <> "rows" then return
    if m.rowPrefetchTimer = invalid then return
    m.rowPrefetchTimer.control = "stop"
    m.rowPrefetchTimer.control = "start"
end sub


sub OnRowPrefetchTimer()
    RunRowPrefetchPass()
end sub

' Card construction resumes after key idle so focus and row translation paint first.
sub RunRowPrefetchPass()
    if not m.rowsRevealed then return
    if m.focusZone <> "rows" then return
    if m.interacting then return
    PrimeFocusedRow()
    MaterializeNearbyRows()
    if ThemeIsOttHome() then ResumeFocusedRowBuild()
    FlushPendingHeroUpdate()
end sub


sub FlushPendingHeroUpdate()
    if not m.pendingHeroUpdate then return
    m.pendingHeroUpdate = false
    ' Only OTT / card-focus home syncs hero from the focused card.
    if ThemeIsOttHome() then UpdateOttHeroFromFocus()
end sub


sub SyncHeroAutoAdvanceHold()
    if m.hero = invalid then return
    if m.interacting then
        if m.hero.hasField("autoAdvanceHold") then m.hero.autoAdvanceHold = true
        m.hero.callFunc("PauseAutoAdvance", invalid)
    else
        if m.hero.hasField("autoAdvanceHold") then m.hero.autoAdvanceHold = false
        ' Always re-arm — a paused timer is not cleared by the hold field alone.
        m.hero.callFunc("ResumeAutoAdvance", invalid)
    end if
end sub

' Materialize shell + sync-build visible cards so vertical nav never lands on a blank strip.
sub PrimeFocusedRow()
    if not m.rowsRevealed then return
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = true
    row.callFunc("Materialize", invalid)
    row.callFunc("ResumeBuild", invalid)
    row.callFunc("ForceReveal", invalid)
end sub


' ── Idle catalogue warm-up ────────────────────────────────────────────────────
' Shells defer card nodes for render-thread safety. While idle (hero/trailer/header),
' finish remaining rows so a later Down does not re-enter skeleton shimmer.
' Fast Down before warm completes still shows shimmer.

function HomeRowNeedsWarm(row as object) as boolean
    if row = invalid then return false
    if row.hasField("built") and row.built = true then return false
    return true
end function

' Row 0 parks its card timer on the boot paint window — warm later shells instead.
function HomeRowBootPaintWaiting(row as object) as boolean
    if row = invalid then return false
    if not row.hasField("bootPaintCardCount") then return false
    if row.bootPaintCardCount < 1 then return false
    if row.hasField("paintedReady") and row.paintedReady = true then return false
    return true
end function

sub ScheduleHomePrefetchWarmup()
    if m.top.dispose = true then return
    if m.top.visible <> true then return
    if not m.rowsRevealed then return
    if m.interacting = true then return
    if m.homeWarmDone = true then return
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return
    if m.prefetchWarmupTimer = invalid then return
    m.prefetchWarmupTimer.control = "start"
end sub

sub StopHomePrefetchWarmup()
    if m.prefetchWarmupTimer <> invalid then m.prefetchWarmupTimer.control = "stop"
end sub

sub OnHomePrefetchWarmupTick()
    if m.top.dispose = true or m.top.visible <> true then
        StopHomePrefetchWarmup()
        return
    end if
    if not m.rowsRevealed or m.interacting = true then return
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then
        StopHomePrefetchWarmup()
        return
    end if

    count = m.rowWidgets.Count()
    warmed = false
    pending = 0
    for i = 0 to count - 1
        row = m.rowWidgets[i]
        if not HomeRowNeedsWarm(row) then continue for
        pending = pending + 1
        if row.hasField("ottRowReveal") then row.ottRowReveal = true
        row.callFunc("Materialize", invalid)
        row.callFunc("ResumeBuild", invalid)
        if HomeRowBootPaintWaiting(row) then continue for
        if warmed then continue for
        row.callFunc("BuildCardsNow", HC_HomeWarmCardsPerTick())
        warmed = true
    end for

    if pending = 0 then
        m.homeWarmDone = true
        StopHomePrefetchWarmup()
    end if
end sub


' ── Input-priority build throttling ───────────────────────────────────────────
' Pause progressive row/card building the instant the user presses a key, so creating
' card nodes never steals render-thread time from a slide change or navigation. The idle
' timer is reset on every key, so building only resumes once the user pauses (0.25s).
sub BeginInteraction()
    m.interacting = true
    ' Ignore late auto-land after the user starts navigating (keys or sidebar).
    if ThemeIsOttHome() then m.userMovedFocus = true
    if ThemeIsSidebarHeader() and m.focusZone = "header" then m.userMovedFocus = true
    PauseRowBuilding()
    SyncHeroAutoAdvanceHold()
    if m.interactIdle <> invalid then
        m.interactIdle.control = "stop"
        m.interactIdle.control = "start"
    end if
end sub


sub OnInteractIdle()
    m.interacting = false
    SyncHeroAutoAdvanceHold()
    ' Flush even when focus already left rows (e.g. raced UP to header) so the last
    ' focused card still drives the OTT/Netflix hero when deferral was used.
    FlushPendingHeroUpdate()
    RunRowPrefetchPass()
    ResumeRowBuilding()
    ScheduleHomePrefetchWarmup()
end sub


sub PauseRowBuilding()
    StopHomePrefetchWarmup()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("PauseBuild", invalid)
    end for
end sub


sub ResumeRowBuilding()
    ' Row shells may continue mounting via rowBuildTimer. Card nodes resume through
    ' PrimeFocusedRow (when in rows) and the idle catalogue warm-up timer.
    if m.rowsBuilt and m.rowBuildTimer <> invalid and m.rowBuildIndex < m.contentRowCats.Count() then
        m.rowBuildTimer.control = "start"
    end if
end sub
