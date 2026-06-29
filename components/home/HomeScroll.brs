' HomeScroll.brs — rows-host scroll animation and input-priority prefetch.


sub ResumeFocusedRowBuild()
    if m.rowWidgets = invalid or m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row <> invalid then row.callFunc("ResumeBuild", invalid)
end sub


' Materialize deferred row shells within a 1-row prefetch window around focus.
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
            row.callFunc("BuildCardsNow", 6)
        end if
    end for
end sub


' Keep the row backdrop transparent in both loading and loaded states. The row shimmer owns
' the loading affordance, and React/LG keeps the hero visible behind the content rows.
sub UpdateRowsScrim()
    if m.rowsScrim <> invalid then m.rowsScrim.opacity = 0.0
    if m.rowsScrimGrad <> invalid then m.rowsScrimGrad.opacity = 0.0
end sub

' Smooth row pinning (parity with netflixContent.tsx 400ms translate). User keys snap
' instantly so the render thread never waits on animation + card materialize together.

' Smooth row pinning (parity with netflixContent.tsx 400ms translate). User keys snap
' instantly so the render thread never waits on animation + card materialize together.
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

' Focused row is primed even during key repeat; neighbor materialize waits for idle.

' Focused row is primed even during key repeat; neighbor materialize waits for idle.
sub RunRowPrefetchPass()
    if not m.rowsRevealed then return
    if m.focusZone <> "rows" then return
    PrimeFocusedRow()
    if m.interacting then return
    MaterializeNearbyRows()
    if ThemeIsOttHome() then ResumeFocusedRowBuild()
    FlushPendingHeroUpdate()
end sub


sub FlushPendingHeroUpdate()
    if not m.pendingHeroUpdate then return
    m.pendingHeroUpdate = false
    UpdateOttHeroFromFocus()
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

' Materialize shell + sync-build visible cards so vertical nav never lands on a blank strip.
sub PrimeFocusedRow()
    if not m.rowsRevealed then return
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = true
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", 6)
    row.callFunc("ResumeBuild", invalid)
    row.callFunc("ForceReveal", invalid)
end sub


' ── Input-priority build throttling ───────────────────────────────────────────
' Pause progressive row/card building the instant the user presses a key, so creating
' card nodes never steals render-thread time from a slide change or navigation. The idle
' timer is reset on every key, so building only resumes once the user pauses (0.25s).
sub BeginInteraction(primeRowIdx = -1 as integer)
    m.interacting = true
    PauseRowBuilding(primeRowIdx)
    SyncHeroAutoAdvanceHold()
    if m.interactIdle <> invalid then
        m.interactIdle.control = "stop"
        m.interactIdle.control = "start"
    end if
end sub


sub OnInteractIdle()
    m.interacting = false
    SyncHeroAutoAdvanceHold()
    RunRowPrefetchPass()
    ResumeRowBuilding()
end sub


sub PauseRowBuilding(exceptIdx = -1 as integer)
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowWidgets = invalid then return
    for i = 0 to m.rowWidgets.Count() - 1
        row = m.rowWidgets[i]
        if row <> invalid and i <> exceptIdx then row.callFunc("PauseBuild", invalid)
    end for
end sub


sub ResumeRowBuilding()
    ' Resume the row orchestration only if rows are still pending.
    if m.rowsBuilt and m.rowBuildTimer <> invalid and m.rowBuildIndex < m.contentRowCats.Count() then
        m.rowBuildTimer.control = "start"
    end if
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("ResumeBuild", invalid)
    end for
end sub

