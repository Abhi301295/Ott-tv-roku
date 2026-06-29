sub init()
    m.hero = m.top.findNode("hero")
    m.vm = FindViewManager(m.top)
    m.header = FindAppHeader(m.top)
    m.rowsHost = m.top.findNode("rowsHost")
    m.rowsAnim = m.top.findNode("rowsAnim")
    m.rowsInterp = m.top.findNode("rowsInterp")
    m.layoutAnim = m.top.findNode("layoutAnim")
    m.heroLayoutInterp = m.top.findNode("heroLayoutInterp")
    m.rowsLayoutInterp = m.top.findNode("rowsLayoutInterp")
    m.scrimGradLayoutInterp = m.top.findNode("scrimGradLayoutInterp")
    m.scrimLayoutInterp = m.top.findNode("scrimLayoutInterp")
    m.skeletonLayoutInterp = m.top.findNode("skeletonLayoutInterp")
    m.homeSkeleton = m.top.findNode("homeSkeleton")
    m.rowsScrim = m.top.findNode("rowsScrim")
    m.rowsScrimGrad = m.top.findNode("rowsScrimGrad")
    m.bg = m.top.findNode("bg")
    ' Once the Continue Watching row has painted, the dark content scrim is removed at the
    ' top row so the hero poster/video bleeds behind the cards (re-shown when scrolled down).
    m.rowsRevealed = false
    ' Which hero control is focused while focusZone = "hero": "prev" | "next" | "mute".
    m.heroFocus = "next"

    m.categories = []
    m.rowWidgets = []
    m.rowIndex = 0
    m.cardIndex = 0
    m.loadingMore = false

    ' Auto-land on first row only when there is no header/sidebar nav; otherwise stay on Home.
    ' Until rows are ready the header stays focused so nav remains usable during shimmer.
    m.focusZone = "header"
    m.pendingContentFocus = true
    m.menuItems = []
    m.menuIndex = 0
    m.headerReturnZone = "rows"
    m.headerReturnRowIndex = 0
    m.headerReturnCardIndex = 0
    m.headerReturnHeroFocus = "next"
    m.layoutOffsetX = 0
    m.pendingLayoutOffX = 0
    m.pendingLayoutViewportW = 1920

    m.contentRowCats = []
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowTops = []
    m.rowContentHeight = 0
    m.rowBuildTimer = CreateObject("roSGNode", "Timer")
    m.rowBuildTimer.duration = 0.03
    m.rowBuildTimer.repeat = true
    m.top.appendChild(m.rowBuildTimer)
    m.rowBuildTimer.observeField("fire", "OnRowBuildTick")

    m.page = HC_HomePageStart()
    m.hasMore = true
    m.homeLayout = HomeLayoutMode()
    m.showUpdate = false
    ApplyLayoutGeometry()

    m.initialLoading = true
    m.continueLoading = true
    m.categoriesPrefetched = false
    m.versionLoading = true
    m.heroBuilt = false
    m.rowsBuilt = false

    ' Continue-Watching (and the other rows) are expensive to build — creating their card
    ' nodes + decoding thumbnails saturates the single render thread and starves the hero
    ' trailer (the preview video would never paint until the rows finished). So we hold the
    ' row build until the hero trailer is actually live, or a safety gate elapses, giving the
    ' preview the thread first. The cheap shimmer keeps animating during the wait.
    m.rowsDataReady = false
    m.rowGateStarted = false
    m.rowGateElapsed = false
    m.rowBuildGate = CreateObject("roSGNode", "Timer")
    m.rowBuildGate.duration = HC_RowBuildGateSecForLayout(m.homeLayout)
    m.rowBuildGate.repeat = false
    m.top.appendChild(m.rowBuildGate)
    m.rowBuildGate.observeField("fire", "OnRowBuildGate")
    m.continueBootTimeout = CreateObject("roSGNode", "Timer")
    m.continueBootTimeout.duration = HC_ContinueBootMaxSec()
    m.continueBootTimeout.repeat = false
    m.top.appendChild(m.continueBootTimeout)
    m.continueBootTimeout.observeField("fire", "OnContinueBootTimeout")

    ' Select-profile runs on Home
    ' here instantly — no full-screen loader. The chosen profile id + avatar arrive via
    ' navState, which ViewManager assigns AFTER init() returns, so the boot sequence is
    ' deferred to OnNavStateReady (see TryStartHomeBoot).
    m.pendingSelectId = ""
    m.pendingSelectAvatar = ""
    m.bootStarted = false
    m.homeNavReady = false
    m.contentBootStarted = false
    m.selectInFlight = false
    m.selectAwaitingApiResult = false
    m.selectRetriesLeft = 0
    m.SELECT_MAX_RETRIES = 8
    m.selectRetryTimer = CreateObject("roSGNode", "Timer")
    m.selectRetryTimer.duration = 0.5
    m.selectRetryTimer.repeat = false
    m.top.appendChild(m.selectRetryTimer)
    m.selectRetryTimer.observeField("fire", "OnHomeSelectRetry")
    ' Hard ceiling so a hung select (one that never posts a response) can't strand the
    ' user on an endless shimmer — on fire we surface an error and return to profiles.
    m.selectWatchdog = CreateObject("roSGNode", "Timer")
    m.selectWatchdog.duration = HC_SelectWatchdogSec()
    m.selectWatchdog.repeat = false
    m.top.appendChild(m.selectWatchdog)
    m.selectWatchdog.observeField("fire", "OnSelectWatchdog")

    LoadThemeTokens()
    if m.global <> invalid then
        m.global.observeField("businessResolved", "OnBusinessResolved")
        if m.global.businessResolved <> invalid then OnBusinessResolved()
    end if

    m.top.observeField("keyEvent", "OnKey")
    ' When another screen is pushed on top (e.g. Detail), ViewManager sets this screen
    ' invisible; pause the hero so its trailer/swipe/video stop ticking in the background,
    ' and resume them when we're revealed again (back/pop).
    m.top.observeField("visible", "OnHomeVisibleChanged")

    ' Input-priority: any keypress pauses background row/card building so node creation never
    ' competes with the user's interaction on the single render thread; building resumes a
    ' short, repeatedly-reset idle window after the last key, so it never lags interaction.
    m.interacting = false
    m.interactIdle = CreateObject("roSGNode", "Timer")
    m.interactIdle.duration = 0.25
    m.interactIdle.repeat = false
    m.top.appendChild(m.interactIdle)
    m.interactIdle.observeField("fire", "OnInteractIdle")
    m.pendingHeroUpdate = false
    if m.rowsAnim <> invalid then m.rowsAnim.observeField("state", "OnRowsAnimState")
    m.rowPrefetchTimer = CreateObject("roSGNode", "Timer")
    m.rowPrefetchTimer.duration = 0.001
    m.rowPrefetchTimer.repeat = false
    m.top.appendChild(m.rowPrefetchTimer)
    m.rowPrefetchTimer.observeField("fire", "OnRowPrefetchTimer")

    ' Hero shimmer hides once the hero poster actually paints, with a safety timeout so
    ' a slow/blocked image can never strand it.
    if m.hero <> invalid then
        m.hero.observeField("posterReady", "OnHeroPosterReady")
        m.hero.observeField("trailerPlaying", "OnHeroTrailerPlayingChanged")
    end if
    m.skeletonTimeout = CreateObject("roSGNode", "Timer")
    m.skeletonTimeout.duration = HC_HomeSkeletonMaxSec()
    m.skeletonTimeout.repeat = false
    m.top.appendChild(m.skeletonTimeout)
    m.skeletonTimeout.observeField("fire", "OnSkeletonTimeout")
    m.rowsSkeletonTimeout = CreateObject("roSGNode", "Timer")
    m.rowsSkeletonTimeout.duration = HC_RowsSkeletonMaxSecForLayout(m.homeLayout)
    m.rowsSkeletonTimeout.repeat = false
    m.top.appendChild(m.rowsSkeletonTimeout)
    m.rowsSkeletonTimeout.observeField("fire", "OnRowsSkeletonTimeout")
    m.firstRowWatch = invalid
    m.rowsForceHideTimer = CreateObject("roSGNode", "Timer")
    m.rowsForceHideTimer.duration = 4.0
    m.rowsForceHideTimer.repeat = false
    m.top.appendChild(m.rowsForceHideTimer)
    m.rowsForceHideTimer.observeField("fire", "OnRowsForceHideTimer")
    m.transitionSafetyTimer = CreateObject("roSGNode", "Timer")
    m.transitionSafetyTimer.duration = 15.0
    m.transitionSafetyTimer.repeat = false
    m.top.appendChild(m.transitionSafetyTimer)
    m.transitionSafetyTimer.observeField("fire", "OnTransitionSafetyTimer")
    m.bootDeferPending = false
    m.cwShimmerSpan = invalid
    m.cwRowBuildSpan = invalid
    m.cwRevealAtMs = -1

    if m.layoutAnim <> invalid then m.layoutAnim.observeField("state", "OnLayoutAnimState")
end sub

' ViewManager assigns navState after SetupAppHeader — see OnNavStateReady.
sub OnNavStateReady()
    if m.homeNavReady = true then return
    m.homeNavReady = true
    SyncHeaderFromShell()
    ClaimHomeHeaderFocus()
    TryStartHomeBoot()
end sub

sub ClaimHomeHeaderFocus()
    if not ThemeHasHomeNav() then return
    if not IsHomeForeground() then return
    if m.vm = invalid then m.vm = FindViewManager(m.top)
    if m.header = invalid then m.header = FindAppHeader(m.top)
    if m.header = invalid then return
    idx = HeaderSelectedIndex(m.menuItems, RouteHome())
    if idx < 0 then idx = 0
    if ThemeIsSidebarHeader() then
        EnterSidebarHomeDefault(false)
    else
        EnterHeader(false)
    end if
end sub

sub SyncHeaderFromShell()
    if m.vm = invalid then m.vm = FindViewManager(m.top)
    if m.header = invalid then m.header = FindAppHeader(m.top)
    if m.header = invalid then return
    if m.vm <> invalid and m.vm.menuItems <> invalid then m.menuItems = m.vm.menuItems
    if m.vm <> invalid and m.vm.shellFocus = "header" then
        m.focusZone = "header"
        if m.header.focusedIndex <> invalid then m.menuIndex = m.header.focusedIndex
    end if
    ApplyHeaderTheme()
    ApplyHeaderBranding()
    UpdateHeaderScrimForHero()
end sub

' ViewManager/AppShell sets shellEnterContent when the user leaves the header (DOWN on
' Netflix bar, DOWN on last sidebar item, RIGHT on sidebar). Home must land hero/rows here
' because HandleShellKey consumes the key before HomeScreen.OnKey runs.
sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    action = m.top.shellEnterAction
    if action = invalid then action = ""
    m.top.shellEnterAction = ""
    if action = "restore" then
        ExitHeaderToPrevious()
        return
    end if
    if m.focusZone = "header" then EnterHeroFromHeader()
end sub

sub ConsumeHomeNavState()
    ns = m.top.navState
    if ns = invalid then return
    if ns.selectProfileId <> invalid then m.pendingSelectId = ns.selectProfileId
    ' The chosen profile's avatar is handed off alongside the id; persist it on select
    ' success so the header shows the SELECTED profile (not the first one that
    ' SaveProfilesMeta defaulted SK_Avatar to). Without this the avatar never updates.
    if ns.selectAvatar <> invalid then m.pendingSelectAvatar = ns.selectAvatar
end sub

sub TryStartHomeBoot()
    if m.bootDeferPending then return
    if m.bootStarted then return
    ConsumeHomeNavState()
    if ProfileTransitionActive() then
        ArmTransitionSafetyTimer()
        if m.bootDeferTimer = invalid then
            m.bootDeferTimer = CreateObject("roSGNode", "Timer")
            m.bootDeferTimer.duration = 0.045
            m.bootDeferTimer.repeat = false
            m.top.appendChild(m.bootDeferTimer)
            m.bootDeferTimer.observeField("fire", "OnBootDeferTimer")
        end if
        m.bootDeferPending = true
        m.bootDeferTimer.control = "start"
        return
    end if
    BeginHomeBootWork()
end sub

sub OnBootDeferTimer()
    m.bootDeferPending = false
    if m.bootStarted then return
    BeginHomeBootWork()
end sub

sub BeginHomeBootWork()
    if m.bootStarted then return
    m.bootStarted = true

    ' A pending select (from the profile screen) sets the profile id itself once it
    ' succeeds, so don't bounce back to the picker just because it isn't persisted yet.
    if GetProfileId() = "" and m.pendingSelectId = "" then
        ProfileSelectLogNode("HOME_BOOT", "no profile id -> RedirectToProfiles", m.top)
        RedirectToProfiles()
        return
    end if

    ConsumeHomeBootCacheIfReady()

    ' Shimmer regions follow layout; Netflix shows hero metadata placeholders, OTT relies on
    ' the banner fallback and only needs the row strip (parity: React Spinner until rows).
    ApplySkeletonLayout()
    if ThemeIsNetflixHome() then
        ShowHeroSkeleton(true)
    else
        ShowHeroSkeleton(false)
    end if
    if m.categoriesPrefetched = true then
        ShowRowsSkeleton(false)
    else
        ShowRowsSkeleton(true)
        m.cwShimmerSpan = CreateObject("roTimespan")
        CwPerfMark(m.cwShimmerSpan, "shimmer ON (boot)")
    end if
    ' Rows timeout starts when BuildContentRows begins, not at boot (hero gate can take 3.5s+).
    ' Wall-clock from mount → hero poster painted = perceived first-content latency.
    m.bootSpan = CreateObject("roTimespan")
    HomeBootLog(m.bootSpan, "boot start", "layout=" + m.homeLayout + " ott=" + CwPerfBool(ThemeIsOttHome()) + " prefetch=" + CwPerfBool(m.categoriesPrefetched = true))
    StartBootSequence()
end sub

sub ArmTransitionSafetyTimer()
    if m.transitionSafetyTimer = invalid then return
    m.transitionSafetyTimer.control = "stop"
    m.transitionSafetyTimer.control = "start"
end sub

sub OnTransitionSafetyTimer()
    if not ProfileTransitionActive() then return
    print "[WELCOME_DBG] safety_timeout hide_overlay boot_started="; m.bootStarted; " content_boot="; m.contentBootStarted
    HideProfileWelcomeTransition()
    if not m.contentBootStarted then BootHomeContent()
end sub

sub HideProfileWelcomeTransition()
    if ProfileTransitionActive() then ProfileTransitionHide(m.vm)
    if m.transitionSafetyTimer <> invalid then m.transitionSafetyTimer.control = "stop"
end sub

sub ConsumeHomeBootCacheIfReady()
    m.categoriesPrefetched = false
    pid = GetProfileId()
    if pid = "" and m.pendingSelectId <> "" then pid = m.pendingSelectId
    if pid = "" then return
    if not HomeBootCacheHasData(pid) then return
    if not HomeBootCacheHasUsableData(pid) then
        HomeBootCacheClear()
        return
    end if
    data = HomeBootCacheConsume(pid)
    if data = invalid then return
    m.categoriesPrefetched = true
    m.categories = data.categories
    m.initialLoading = false
    m.continueLoading = false
    m.hasMore = false
end sub

' Stop every ContentRow timer on this screen (render-thread hygiene on dispose).
sub AbortAllRowBuilds()
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("AbortBuild", invalid)
    end for
end sub

' Stop everything that ticks before this screen is torn down, so a removed HomeScreen
' can't leave its hero carousel/trailer/build timers running in the background.
sub OnDispose()
    if not m.top.dispose then return
    print "[HOME] dispose -> stopping hero + timers + in-flight tasks"
    m.heroBuilt = true
    m.rowsBuilt = true
    m.rowsDataReady = false
    m.initialLoading = false
    m.continueLoading = false
    m.loadingMore = false
    CancelHomeSelect("dispose")
    AbortAllRowBuilds()
    ' Setting the hero invisible runs its OnVisibleChanged cleanup (swipe timer, trailer,
    ' video, pending detail fetch all stop).
    if m.hero <> invalid then
        m.hero.unobserveField("posterReady")
        m.hero.unobserveField("trailerPlaying")
        m.hero.visible = false
    end if

    ' Stop every timer that ticks on this screen.
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowBuildGate <> invalid then m.rowBuildGate.control = "stop"
    if m.continueBootTimeout <> invalid then m.continueBootTimeout.control = "stop"
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    DetachFirstRowWatch()
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"
    if m.interactIdle <> invalid then m.interactIdle.control = "stop"
    if m.rowPrefetchTimer <> invalid then m.rowPrefetchTimer.control = "stop"
    if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "stop"
    if m.transitionSafetyTimer <> invalid then m.transitionSafetyTimer.control = "stop"
    if m.bootDeferTimer <> invalid then m.bootDeferTimer.control = "stop"
    if m.rowBuildDeferTimer <> invalid then m.rowBuildDeferTimer.control = "stop"
    HideProfileWelcomeTransition()
    if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"

    ' Kill every in-flight HTTP listener. The shared pool may still finish the request,
    ' but unobserving guarantees no apiResult handler runs on this (removed) screen — so a
    ' late Continue-Watching / categories response can't kick off row-building in the
    ' background after the user has navigated to a different profile.
    KillTask(m.selectTask)
    KillTask(m.profilesTask)
    KillTask(m.continueTask)
    KillTask(m.categoryTask)
    KillTask(m.versionTask)
    KillTask(m.loadMoreTask)
    m.selectTask = invalid
    m.profilesTask = invalid
    m.continueTask = invalid
    m.categoryTask = invalid
    m.versionTask = invalid
    m.loadMoreTask = invalid
    m.selectInFlight = false
    m.loadingMore = false

    ' Detach the app-global observer (m.global outlives this screen, so its observer would
    ' otherwise pin the removed HomeScreen in memory).
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
    m.top.unobserveField("visible")
end sub

' Stop a finished/in-flight HTTP task and detach its result listener.
sub KillTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

' Pause/resume the hero when this screen is covered/revealed by the nav stack.
' The hero's own OnVisibleChanged stops the trailer, swipe timer, video and pending
' detail fetch when invisible, and reschedules them when visible — so we just mirror
' the screen's visibility onto the hero (only showing it again if it has banners).
sub OnHomeVisibleChanged()
    if m.top.dispose = true then return
    if m.top.visible = true then
        if m.hero <> invalid then
            items = m.hero.bannerItems
            m.hero.visible = (items <> invalid and items.Count() > 0)
        end if
        ' Resume any unfinished background row-building when revealed (the build cursor
        ' m.rowBuildIndex survives, so it picks up where it paused).
        if m.rowBuildTimer <> invalid and m.contentRowCats <> invalid and m.rowBuildIndex < m.contentRowCats.Count() then
            m.rowBuildTimer.control = "start"
        end if
    else
        ' Covered by another screen (e.g. Detail pushed on top): stop the hero AND pause
        ' background node-building so nothing competes with the foreground screen for the
        ' single render thread.
        if m.hero <> invalid then m.hero.visible = false
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        if m.interactIdle <> invalid then m.interactIdle.control = "stop"
        CancelHomeSelect("covered")
    end if
end sub

' True when this HomeScreen is the top, visible screen (not covered/disposed).
function IsHomeForeground() as boolean
    if m.top.dispose = true then return false
    if m.top.visible = false then return false
    if m.vm = invalid then return false
    host = m.vm.findNode("screenHost")
    if host = invalid then return false
    count = host.getChildCount()
    if count < 1 then return false
    active = host.getChild(count - 1)
    if active = invalid then return false
    return active.isSameNode(m.top)
end function

' Stop select-profile retries/watchdog when Home is covered, disposed, or giving up.
sub CancelHomeSelect(reason as string)
    wasInFlight = m.selectInFlight
    pending = m.pendingSelectId
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"
    KillTask(m.selectTask)
    m.selectTask = invalid
    m.selectInFlight = false
    m.selectAwaitingApiResult = false
    if wasInFlight or pending <> "" then
        ProfileSelectLogNode("HOME_SELECT_CANCEL", reason + " pendingId=" + pending, m.top)
    end if
end sub

' ── Theme ────────────────────────────────────────────────────────────────────

sub LoadThemeTokens()
    tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens

    ' Fallbacks mirror the static React dark theme (dark.theme.ts) so colors
    ' match LG even before BE-driven themeTokens resolve.
    m.cPrimary500 = TokenColor(tokens, "primary-500", "#0092ff")
    m.cPrimary600 = TokenColor(tokens, "primary-600", "#459adb")
    m.cPrimary700 = TokenColor(tokens, "primary-700", "#80bbe9")
    m.cNeutral50 = TokenColor(tokens, "neutral-50", "#ffffff")
    m.cNeutral100 = TokenColor(tokens, "neutral-100", "#f8f8f8")
    m.cNeutral200 = TokenColor(tokens, "neutral-200", "#e5e5e5")
    m.cNeutral400 = TokenColor(tokens, "neutral-400", "#c8c8c8")
    m.cNeutral700 = TokenColor(tokens, "neutral-700", "#181818")
    m.cNeutral800 = TokenColor(tokens, "neutral-800", "#121212")
    m.cNeutral950 = TokenColor(tokens, "neutral-900", "#0a0a0a")
    m.cPageBg = TokenColor(tokens, "background", "#0a0a0a")
    ApplyHomePageBackground()
end sub

' Netflix home is always cinematic dark (netflixContent.tsx bg-black). OTT uses neutral-100
' (content.tsx). API background/neutral tokens are light on some tenants — never use them here.
sub ApplyHomePageBackground()
    if m.bg = invalid then return
    layout = m.homeLayout
    if layout = invalid or layout = "" then layout = HomeLayoutMode()
    bg = m.cPageBg
    if ThemeIsNetflixHome() or layout = HC_HomeLayoutNetflix() then
        bg = HC_HomeCinematicBg()
    else if ThemeIsOttHome() or layout = HC_HomeLayoutOtt() then
        bg = HC_HomeOttPageBg()
    end if
    m.cHomeBg = bg
    m.bg.color = bg
end sub

function HomeRowPageBg() as string
    if m.cHomeBg <> invalid and m.cHomeBg <> "" then return m.cHomeBg
    if ThemeIsNetflixHome() then return HC_HomeCinematicBg()
    return m.cPageBg
end function

function TokenColor(tokens as object, name as string, fallbackHex as string) as string
    hex = fallbackHex
    if tokens <> invalid and tokens[name] <> invalid and tokens[name] <> "" then
        hex = tokens[name]
    end if
    if Left(hex, 1) = "#" then hex = Mid(hex, 2)
    if Len(hex) = 8 then return "0x" + hex
    if Len(hex) = 6 then return "0x" + hex + "ff"
    return "0x0b75e0ff"
end function

sub OnBusinessResolved()
    LoadThemeTokens()
    InjectRowTheme()
    ApplyThemeToHero()
    ApplyHomeSkeletonColors()
    if IsHomeForeground() then SetupHeader()
end sub

sub InjectRowTheme()
    for each row in m.rowWidgets
        if row = invalid then continue for
        ApplyThemeToRow(row)
    end for
end sub

sub ApplyThemeToRow(row as object)
    if row = invalid then return
    row.cPrimary500 = m.cPrimary500
    row.cPrimary600 = m.cPrimary600
    row.cPrimary700 = m.cPrimary700
    row.cNeutral50 = m.cNeutral50
    row.cNeutral800 = m.cNeutral800
    row.cNeutral950 = m.cNeutral950
    row.cNeutral700 = m.cNeutral700
    row.cPageBg = HomeRowPageBg()
end sub

sub ApplyActiveHeader()
    m.header = FindAppHeader(m.top)
end sub

sub ApplyLayoutGeometry(animate = false as boolean)
    m.layoutRowPitch = HC_RowPitchForLayout(m.homeLayout)
    m.layoutAnchorY = HC_AnchorYForLayout(m.homeLayout)

    if not ThemeIsSidebarHeader() then
        m.layoutOffsetX = 0
        ApplyContentLayout(0, 1920)
    else
        expanded = false
        if m.header <> invalid and m.header.headerActive = true then expanded = true
        offX = ThemeSidebarOffset(expanded)
        viewportW = 1920 - offX

        doAnimate = animate and ShouldAnimateSidebarLayout()
        if doAnimate and m.layoutAnim <> invalid then
            StartLayoutOffsetAnim(offX, viewportW)
        else
            m.layoutOffsetX = offX
            ApplyContentLayout(offX, viewportW)
        end if
    end if

    NormalizeOttRowsHostY()
    ApplySkeletonLayout()
end sub

' Drive HomeSkeleton placeholder positions from the active layout case.
sub ApplySkeletonLayout()
    if m.homeSkeleton = invalid then return
    mode = "netflix"
    if ThemeIsOttHome() then mode = "ott"
    m.homeSkeleton.layoutMode = mode
    m.homeSkeleton.anchorY = m.layoutAnchorY
end sub

' OTT rows default to y=702 in XML (Netflix anchor); snap to OTT anchor unless scrolled down.
sub NormalizeOttRowsHostY()
    if not ThemeIsOttHome() then return
    if m.rowsHost = invalid then return
    if m.focusZone = "rows" and m.rowIndex > 0 then return
    offX = 0
    if m.layoutOffsetX <> invalid then offX = m.layoutOffsetX
    m.rowsHost.translation = [offX, m.layoutAnchorY]
end sub

function ShouldAnimateSidebarLayout() as boolean
    if m.pendingContentFocus then return false
    if not m.rowsRevealed then return false
    return true
end function

sub ApplyContentLayout(offX as integer, viewportW as integer)
    if m.hero <> invalid then
        m.hero.translation = [offX, 0]
        if m.hero.hasField("contentWidth") then m.hero.contentWidth = viewportW
    end if
    if m.rowsScrimGrad <> invalid then
        y = m.rowsScrimGrad.translation[1]
        m.rowsScrimGrad.translation = [offX, y]
        m.rowsScrimGrad.width = viewportW
    end if
    if m.rowsScrim <> invalid then
        y = m.rowsScrim.translation[1]
        m.rowsScrim.translation = [offX, y]
        m.rowsScrim.width = viewportW
    end if
    if m.rowsHost <> invalid then
        curY = m.rowsHost.translation[1]
        m.rowsHost.translation = [offX, curY]
    end if
    if m.homeSkeleton <> invalid then m.homeSkeleton.translation = [offX, 0]
end sub

sub StartLayoutOffsetAnim(targetOffX as integer, targetViewportW as integer)
    fromOffX = 0
    if m.layoutOffsetX <> invalid then fromOffX = m.layoutOffsetX
    if fromOffX = targetOffX then
        m.layoutOffsetX = targetOffX
        ApplyContentLayout(targetOffX, targetViewportW)
        return
    end if

    m.pendingLayoutOffX = targetOffX
    m.pendingLayoutViewportW = targetViewportW

    if m.heroLayoutInterp <> invalid and m.hero <> invalid then
        fromT = m.hero.translation
        m.heroLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
    end if
    if m.rowsLayoutInterp <> invalid and m.rowsHost <> invalid then
        fromT = m.rowsHost.translation
        m.rowsLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
    end if
    if m.scrimGradLayoutInterp <> invalid and m.rowsScrimGrad <> invalid then
        fromT = m.rowsScrimGrad.translation
        m.scrimGradLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
    end if
    if m.scrimLayoutInterp <> invalid and m.rowsScrim <> invalid then
        fromT = m.rowsScrim.translation
        m.scrimLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
    end if
    if m.skeletonLayoutInterp <> invalid and m.homeSkeleton <> invalid then
        fromT = m.homeSkeleton.translation
        m.skeletonLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
    end if

    ' Width snaps at end of slide; hero clips continuously via contentWidth.
    if m.hero <> invalid and m.hero.hasField("contentWidth") then
        m.hero.contentWidth = targetViewportW
    end if
    if m.rowsScrimGrad <> invalid then m.rowsScrimGrad.width = targetViewportW
    if m.rowsScrim <> invalid then m.rowsScrim.width = targetViewportW

    m.layoutAnim.control = "start"
end sub

sub OnLayoutAnimState()
    if m.layoutAnim = invalid then return
    if m.layoutAnim.state <> "stopped" then return
    m.layoutOffsetX = m.pendingLayoutOffX
    ApplyContentLayout(m.pendingLayoutOffX, m.pendingLayoutViewportW)
end sub

sub UpdateOttHeroFromFocus()
    if not ThemeIsOttHome() then return
    if m.hero = invalid then return
    item = ItemAtRowCard(m.contentRowCats, m.rowIndex, m.cardIndex)
    if item = invalid then item = ExtractOttActiveItem(m.categories)
    if item <> invalid then m.hero.activeItem = item
end sub

sub ApplyThemeToHero()
    if m.hero = invalid then return
    m.hero.cNeutral50 = m.cNeutral50
    m.hero.cPrimary500 = m.cPrimary500
end sub

sub UpdateHeroBanner()
    if m.hero = invalid then return
    items = ExtractBannerItems(m.categories)
    print "[HOME] UpdateHeroBanner bannerItems="; items.Count(); " layout="; m.homeLayout
    ApplyThemeToHero()
    m.hero.bannerItems = items
    m.hero.visible = (items.Count() > 0 or ThemeIsOttHome())
    if ThemeIsOttHome() then
        m.hero.activeItem = ExtractOttActiveItem(m.categories)
    end if
end sub

' ── Header (parity with ottHeader.tsx NetflixHeader) ─────────────────────────

sub SetupHeader()
    if m.header = invalid then m.header = FindAppHeader(m.top)
    if m.header = invalid then return

    if m.vm = invalid then m.vm = FindViewManager(m.top)
    if m.vm <> invalid and m.vm.menuItems <> invalid and m.vm.menuItems.Count() > 0 then
        m.menuItems = m.vm.menuItems
        ApplyHeaderTheme()
        ApplyHeaderBranding()
        UpdateHeaderScrimForHero()
        return
    end if

    reels = false
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved <> invalid then reels = IsFeatureEnabled(resolved, "reelsEnabled")
    if not reels then
        tm = m.top.getScene().findNode("themeManager")
        if tm <> invalid and tm.reelsEnabled = true then reels = true
    end if

    m.menuItems = HeaderMenuItems(reels)
    if ThemeIsSidebarHeader() then
        m.header.menuItems = SidebarMenuItems(reels)
    else
        texts = []
        for each it in m.menuItems
            texts.Push(it.text)
        end for
        m.header.menuTexts = texts
    end if
    m.header.selectedIndex = HeaderSelectedIndex(m.menuItems, RouteHome())
    if m.focusZone <> "header" then m.menuIndex = m.header.selectedIndex

    ApplyHeaderTheme()
    ApplyHeaderBranding()
    UpdateHeaderScrimForHero()
end sub

sub ApplyHeaderTheme()
    if m.header = invalid then return
    m.header.cPrimary500 = m.cPrimary500
    m.header.cNeutral50 = m.cNeutral50
    m.header.cNeutral200 = m.cNeutral200
    m.header.cNeutral800 = m.cNeutral800
    m.header.cNeutral950 = m.cNeutral950
    if m.header.hasField("cPrimary700") then m.header.cPrimary700 = m.cPrimary700
    if m.header.hasField("cNeutral100") then m.header.cNeutral100 = m.cNeutral100
    if m.header.hasField("cNeutral700") then m.header.cNeutral700 = m.cNeutral700
end sub

sub ApplyHeaderBranding()
    if m.header = invalid then return

    ' Active profile avatar (parity with NetflixHeader): persisted by the select-profile
    ' handoff (PersistSelectedProfile), falling back to the first profile from fetch.
    avatarUri = RegistryRead(SK_Avatar(), "app")
    if avatarUri <> invalid then m.header.avatarUri = avatarUri

    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return
    if resolved.brandingLogo <> invalid then
        m.header.logoUri = resolved.brandingLogo
        if m.header.hasField("logoCroppedUri") then m.header.logoCroppedUri = resolved.brandingLogo
    end if
    if resolved.appName <> invalid then m.header.appName = resolved.appName
end sub

sub OnHeroTrailerPlayingChanged()
    UpdateHeaderScrimForHero()
    ' Preview is live now — safe to spend the render thread on building the rows.
    if m.hero <> invalid and m.hero.trailerPlaying = true then MaybeStartRowBuild()
end sub

sub UpdateHeaderScrimForHero()
    if m.header = invalid then return
    ' Home hero media must sit visually behind the header/nav like LG. Do not restore a
    ' black header band for the static poster either, otherwise the media appears to start
    ' below the header (the red-line issue).
    m.header.scrimOpacity = 0.0
end sub

sub EnterHeader(animateLayout = true as boolean)
    if m.header = invalid then return
    if not IsHomeForeground() then return
    m.focusZone = "header"
    m.menuIndex = m.header.selectedIndex
    if m.vm <> invalid then
        ShellEnterHeader(m.vm, m.menuIndex)
    else
        m.header.focusedIndex = m.menuIndex
        m.header.headerActive = true
    end if
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(animateLayout)
    ClearAllRowCardFocus()
    ApplyAllRowFocusStates()
end sub

sub ClearAllRowCardFocus()
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid and row.hasField("cardFocusIndex") then row.cardFocusIndex = -1
    end for
end sub

sub ExitHeaderToRows()
    if not IsHomeForeground() then return
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(true)
    m.focusZone = "rows"
    ApplyHomeFocus()
end sub

' Sidebar header (cases 4/6): expanded menu on Home — focus in menu, not rows.
sub EnterSidebarHomeDefault(animateLayout = true as boolean)
    if m.header = invalid then return
    idx = HeaderSelectedIndex(m.menuItems, RouteHome())
    if idx < 0 then idx = 0
    m.menuIndex = idx
    m.header.selectedIndex = idx
    m.header.focusedIndex = idx
    EnterHeader(animateLayout)
end sub

' Sidebar (case 4/6): remember where focus was before opening the expanded menu.
sub RememberHeaderReturnZone()
    if m.focusZone = "hero" then
        m.headerReturnZone = "hero"
        m.headerReturnHeroFocus = m.heroFocus
    else if m.focusZone = "rows" then
        m.headerReturnZone = "rows"
        m.headerReturnRowIndex = m.rowIndex
        m.headerReturnCardIndex = m.cardIndex
    end if
end sub

' Case 4 parity: LEFT from hero/rows opens sidebar (case 1 uses UP for top header).
sub EnterHeaderFromContent()
    RememberHeaderReturnZone()
    EnterHeader()
end sub

' RIGHT leaves sidebar — collapse to icons and restore hero or row focus.
sub ExitHeaderToPrevious()
    if not IsHomeForeground() then return
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(true)

    zone = m.headerReturnZone
    if zone = "hero" and HeroAvailable() then
        target = m.headerReturnHeroFocus
        if target = invalid or target = "" then target = "next"
        EnterHero(target)
        return
    end if

    m.focusZone = "rows"
    if m.headerReturnRowIndex <> invalid then m.rowIndex = m.headerReturnRowIndex
    if m.headerReturnCardIndex <> invalid then m.cardIndex = m.headerReturnCardIndex
    ClampCardIndex()
    ApplyHomeFocus()
end sub

' Rows ready / CW painted: stay on Home menu when header/sidebar exist; otherwise land row 0 once.
sub MaybeLandContentFocus()
    if not IsHomeForeground() then return
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return

    if ThemeHasHomeNav() then
        m.pendingContentFocus = false
        if m.focusZone = "header" then
            if m.header <> invalid and m.header.headerActive <> true then
                if ThemeIsSidebarHeader() then
                    EnterSidebarHomeDefault(false)
                else
                    EnterHeader(false)
                end if
            end if
            return
        end if
        if ThemeIsSidebarHeader() then
            EnterSidebarHomeDefault(false)
        else
            EnterHeader(false)
        end if
        return
    end if

    if not m.pendingContentFocus then return
    m.pendingContentFocus = false
    if m.focusZone = "header" then ExitHeaderToRows()
end sub

sub HandleHeaderKey(key as string)
    if ThemeIsSidebarHeader() then
        if key = "up" then
            if m.menuIndex > 0 then
                m.menuIndex = m.menuIndex - 1
                m.header.focusedIndex = m.menuIndex
            end if
        else if key = "down" then
            if m.menuIndex < m.menuItems.Count() - 1 then
                m.menuIndex = m.menuIndex + 1
                m.header.focusedIndex = m.menuIndex
            else
                EnterHeroFromHeader()
            end if
        else if key = "right" then
            ExitHeaderToPrevious()
        else if key = "OK" or key = "ok" then
            SelectHeaderItem()
        end if
        return
    end if

    if key = "left" then
        if m.menuIndex > 0 then
            m.menuIndex = m.menuIndex - 1
            m.header.focusedIndex = m.menuIndex
        end if
    else if key = "right" then
        if m.menuIndex < m.menuItems.Count() - 1 then
            m.menuIndex = m.menuIndex + 1
            m.header.focusedIndex = m.menuIndex
        end if
    else if key = "down" then
        EnterHeroFromHeader()
    else if key = "OK" or key = "ok" then
        SelectHeaderItem()
    end if
end sub

' ── Hero banner focus zone (parity with the portal arrows / mute button) ─────
' Vertical flow:  HEADER ↕ HERO (prev/next/mute) ↕ CONTINUE WATCHING.

function HeroAvailable() as boolean
    if ThemeIsOttHome() then return false
    if m.hero = invalid or m.hero.visible <> true then return false
    items = m.hero.bannerItems
    if items = invalid or items.Count() = 0 then return false
    ' Focusable only when there is something to act on: multiple slides (arrows) or a
    ' playing trailer (mute) — mirrors React showing arrows only when items.length > 1.
    return (items.Count() > 1) or (m.hero.trailerPlaying = true)
end function

function HeroMultiSlide() as boolean
    return HeroSlideCount() > 1
end function

function HeroSlideCount() as integer
    if m.hero = invalid then return 0
    items = m.hero.bannerItems
    if items = invalid then return 0
    return items.Count()
end function

' True when the merged category list includes a non-empty Continue Watching row.
function HomeHasContinueWatchingRow() as boolean
    cats = FilterContentRows(m.categories)
    for each cat in cats
        if cat = invalid then continue for
        if cat.type = HC_TypeContinueWatching() then return true
    end for
    return false
end function

' Pick a valid landing control given what is currently available.
function NormalizeHeroTarget(target as string) as string
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)
    if target = "mute" and not playing then target = "next"
    if (target = "prev" or target = "next") and not HeroMultiSlide() then
        if playing then return "mute"
        return "next"
    end if
    if target = "" then target = "next"
    return target
end function

sub EnterHeroOrHeader()
    if not HeroAvailable() then
        if ThemeIsSidebarHeader() then
            EnterHeaderFromContent()
        else
            EnterHeader()
        end if
        return
    end if
    target = "next"
    if m.hero.trailerPlaying = true then target = "mute"
    EnterHero(target)
end sub

sub EnterHeroFromHeader()
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    if HeroAvailable() then
        EnterHero("next")
    else if m.rowWidgets.Count() > 0 then
        ' Single-slide hero (or no trailer): skip arrow chrome — land on rows (React parity).
        ExitHeaderToRows()
    else
        ' Keep header focus active while Home content is still loading.
        EnterHeader()
    end if
end sub

sub EnterHero(target as string)
    if not HeroAvailable() then return
    m.focusZone = "hero"
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    ' Drop any card highlight while the hero is focused.
    for each row in m.rowWidgets
        if row <> invalid then row.cardFocusIndex = -1
    end for
    m.heroFocus = NormalizeHeroTarget(target)
    ApplyHeroFocus()
    ApplyAllRowFocusStates()
    UpdateRowsScrim()
end sub

sub ApplyHeroFocus()
    if m.hero <> invalid then m.hero.focusTarget = m.heroFocus
end sub

sub ClearHeroFocus()
    if m.hero <> invalid then m.hero.focusTarget = ""
end sub

sub EnterRowsFromHero()
    ClearHeroFocus()
    m.focusZone = "rows"
    m.rowIndex = 0
    m.cardIndex = 0
    ApplyHomeFocus()
    UpdateRowsScrim()
end sub

function HeroIsPageFlip() as boolean
    return ThemeHeroBannerStyle() = TC_HeroPageFlip()
end function

function HeroIsParallaxSlide() as boolean
    return ThemeHeroBannerStyle() = TC_HeroParallaxSlide()
end function

function HeroUsesFrostNav() as boolean
    return HeroIsPageFlip() or HeroIsParallaxSlide()
end function

sub HandleHeroKey(key as string)
    multi = HeroMultiSlide()
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)
    frostNav = HeroUsesFrostNav()

    if key = "up" then
        if ThemeIsSidebarHeader() then
            ' Vertical hero controls only — sidebar is opened with LEFT, not UP.
            if m.heroFocus = "mute" then
                m.heroFocus = "next"
                ApplyHeroFocus()
            end if
        else if m.heroFocus = "mute" then
            m.heroFocus = "next"
            ApplyHeroFocus()
        else
            ClearHeroFocus()
            EnterHeader()
        end if
    else if key = "down" then
        if m.heroFocus = "next" and playing and not frostNav then
            m.heroFocus = "mute"
            ApplyHeroFocus()
        else
            EnterRowsFromHero()
        end if
    else if key = "left" then
        if frostNav and multi then
            if m.hero <> invalid then m.hero.callFunc("HeroGoPrev", invalid)
        else if ThemeIsSidebarHeader() then
            if m.heroFocus = "next" and multi then
                m.heroFocus = "prev"
                ApplyHeroFocus()
            else if m.heroFocus = "mute" then
                EnterRowsFromHero()
            else
                EnterHeaderFromContent()
            end if
        else if m.heroFocus = "next" and multi then
            m.heroFocus = "prev"
            ApplyHeroFocus()
        else if m.heroFocus = "mute" then
            EnterRowsFromHero()
        end if
    else if key = "right" then
        if frostNav and multi then
            if m.hero <> invalid then m.hero.callFunc("HeroGoNext", invalid)
        else if m.heroFocus = "prev" and multi then
            m.heroFocus = "next"
            ApplyHeroFocus()
        end if
    else if key = "OK" or key = "ok" then
        if m.hero = invalid then return
        if frostNav or m.heroFocus = "next" then
            m.hero.callFunc("HeroGoNext", invalid)
        else if m.heroFocus = "prev" then
            m.hero.callFunc("HeroGoPrev", invalid)
        else if m.heroFocus = "mute" then
            m.hero.callFunc("HeroToggleMute", invalid)
        end if
    end if
end sub

sub SelectHeaderItem()
    if m.menuItems = invalid or m.menuIndex < 0 or m.menuIndex >= m.menuItems.Count() then return
    item = m.menuItems[m.menuIndex]
    m.header.selectedIndex = m.menuIndex
    SetValueByKey(SK_SelectedItem(), item.text, "app")

    if item.route = RouteHome() then
        if ThemeIsSidebarHeader() then
            EnterSidebarHomeDefault(true)
        else if m.rowWidgets.Count() > 0 then
            ExitHeaderToRows()
        else
            EnterHeader()
        end if
        return
    end if

    if m.vm <> invalid then
        state = { type: item.type, selectedID: item.text }
        m.vm.callFunc("NavigateReplace", item.route, state)
    end if
end sub

' ── Boot sequence (parity with features/home/index.tsx) ──────────────────────

sub StartBootSequence()
    if m.pendingSelectId <> "" then
        if m.pendingSelectId = GetProfileId() and GetRefreshToken() <> "" then
            HomeBootLog(m.bootSpan, "select skipped", "profile already active id=" + m.pendingSelectId)
            if m.header <> invalid and m.pendingSelectAvatar <> invalid and m.pendingSelectAvatar <> "" then
                m.header.avatarUri = m.pendingSelectAvatar
            end if
            m.pendingSelectId = ""
            m.pendingSelectAvatar = ""
            BootHomeContent()
            return
        end if
        HomeBootLog(m.bootSpan, "select-profile queued", "id=" + m.pendingSelectId)
        print "[HOME] pending select-profile -> running behind shimmer"
        ' Session tokens from login may already be valid — fetch home content in parallel
        ' so the rows shimmer is not held hostage to a slow select-profile round-trip.
        if GetAccessToken() <> "" or GetRefreshToken() <> "" then
            HomeBootLog(m.bootSpan, "parallel content boot", "while select runs")
            BootHomeContent()
        end if
        DoHomeSelect()
        return
    end if
    BootHomeContent()
end sub

sub BootHomeContent()
    if m.contentBootStarted then return
    ' Prefetch may finish after BeginHomeBootWork when select-profile ran in parallel.
    if not m.categoriesPrefetched then ConsumeHomeBootCacheIfReady()
    m.contentBootStarted = true
    if m.categoriesPrefetched = true then
        print "[HOME_BOOT_DBG] content_boot prefetch_hit skip_fetch=true"
        HomeBootLog(m.bootSpan, "content boot", "prefetch hit skip CW+categories")
        if m.continueBootTimeout <> invalid then m.continueBootTimeout.control = "stop"
        m.continueLoading = false
        EnsureHomeProfileDefaults()
        FetchLatestVersion()
        MaybeBuildHero()
        MaybeBuildRows()
        return
    end if
    print "[HOME_BOOT_DBG] content_boot prefetch_hit skip_fetch=false fetch_cw_and_home=true"
    HomeBootLog(m.bootSpan, "content boot", "fetch CW + categories parallel")
    ' The profile was just selected on the previous screen, so the active profile
    ' identity is already persisted — only re-fetch profiles if it is somehow missing
    ' (parity intent: avoid a redundant GET_LOGIN_PROFILES on every home mount).
    EnsureHomeProfileDefaults()
    if GetProfileId() = "" then FetchProfilesBootstrap()

    ' Continue-watching and categories fire together (instead of categories waiting on
    ' continue) so first paint waits on max(continue, categories) ~1.8s, not their sum.
    ' Both merge into m.categories on the render thread, and continue always lands first
    ' in the list via PrependCategories regardless of which response arrives first.
    FetchContinueWatching()
    FetchHomeCategories(m.page)
    FetchLatestVersion()
    if m.continueBootTimeout <> invalid then m.continueBootTimeout.control = "start"
end sub

sub OnContinueBootTimeout()
    if m.continueLoading <> true then return
    HomeBootLog(m.bootSpan, "CW boot timeout", "proceed without continue-watching")
    m.continueLoading = false
    MaybeBuildRows()
end sub

' ── Select-profile (runs on Home so the profile screen can navigate here instantly) ──
' POST select-profile, retrying a few times on transient 401/404 (a freshly-issued token
' is briefly not yet active on the backend). On success: persist identity + boot content.
' On give-up: surface a toast and return to the picker — never log the user out for a
' transient failure (only a real session-expiry ends the session via HttpClient).
sub DoHomeSelect()
    m.selectInFlight = true
    m.selectAwaitingApiResult = false
    m.selectRetriesLeft = m.SELECT_MAX_RETRIES
    ProfileSelectLogNode("HOME_SELECT_START", "profileId=" + m.pendingSelectId + " retries=" + ProfileSelectFmt(m.SELECT_MAX_RETRIES), m.top)
    if m.selectWatchdog <> invalid then
        m.selectWatchdog.control = "stop"
        m.selectWatchdog.control = "start"
    end if
    ' One keep-alive refresh before POST — not a full-pool warm (select is a single request).
    WarmHttpConnection(SelectProfilePath())
    FireHomeSelectRequest()
end sub

sub FireHomeSelectRequest()
    path = SelectProfilePath()
    ProfileSelectLogNode("HOME_SELECT_REQUEST", "pendingId=" + m.pendingSelectId + " retriesLeft=" + ProfileSelectFmt(m.selectRetriesLeft), m.top)
    m.selectAwaitingApiResult = true
    m.selectTask = ApiPost(path, SelectProfilePayload(m.pendingSelectId))
    m.selectTask.observeField("apiResult", "OnHomeSelectResponse")
    StartHttpTask(m.selectTask)
    ' Per-attempt ceiling — reset whenever we fire (initial + retries + watchdog retries).
    if m.selectWatchdog <> invalid and m.selectInFlight then
        m.selectWatchdog.control = "stop"
        m.selectWatchdog.control = "start"
    end if
end sub

sub OnHomeSelectResponse(event as object)
    ' A late apiResult after the screen left the tree must not mutate auth/navigation.
    if m.top.dispose = true then return
    if not m.selectInFlight then return

    task = invalid
    if event <> invalid then task = event.getRoSGNode()
    if task = invalid then task = m.selectTask
    if task = invalid then return

    api = task.apiResult
    if api = invalid then return

    m.selectAwaitingApiResult = false
    if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"

    if not IsHomeForeground() then
        ProfileSelectLogNode("HOME_SELECT_RESPONSE", "ignored (not foreground)", m.top)
        CancelHomeSelect("response-not-foreground")
        return
    end if
    if api.shouldLogout = true then return

    if api.ok and ApplySelectProfileTokens(api.result) then
        PersistSelectedProfile(m.pendingSelectId, m.pendingSelectAvatar)
        if m.header <> invalid and m.pendingSelectAvatar <> invalid and m.pendingSelectAvatar <> "" then
            m.header.avatarUri = m.pendingSelectAvatar
        end if
        m.pendingSelectId = ""
        m.pendingSelectAvatar = ""
        m.selectInFlight = false
        ProfileSelectLogNode("HOME_SELECT_OK", "profileId persisted -> boot content", m.top)
        HomeBootLog(m.bootSpan, "select-profile ok", "boot content")
        print "[HOME] select-profile ok -> boot home content"
        BootHomeContent()
        return
    end if

    ' Duplicate select — session is already valid; do not retry a 21s 404 loop.
    if api.httpStatus = 404 and m.pendingSelectId <> "" and (GetRefreshToken() <> "" or GetAccessToken() <> "") then
        HomeBootLog(m.bootSpan, "select 404 ignored", "session valid -> boot content")
        PersistSelectedProfile(m.pendingSelectId, m.pendingSelectAvatar)
        if m.header <> invalid and m.pendingSelectAvatar <> invalid and m.pendingSelectAvatar <> "" then
            m.header.avatarUri = m.pendingSelectAvatar
        end if
        m.pendingSelectId = ""
        m.pendingSelectAvatar = ""
        m.selectInFlight = false
        BootHomeContent()
        return
    end if

    HomeBootLog(m.bootSpan, "select-profile fail", "http=" + ProfileSelectFmt(api.httpStatus))

    ' A superseded attempt failed after a newer one was already fired — ignore it.
    if m.selectTask <> invalid and not task.isSameNode(m.selectTask) then
        ProfileSelectLogNode("HOME_SELECT_RESPONSE", "ignored stale httpStatus=" + ProfileSelectFmt(api.httpStatus), m.top)
        return
    end if

    if SelectProfileRetriable(api.httpStatus) and m.selectRetriesLeft > 0 then
        m.selectRetriesLeft = m.selectRetriesLeft - 1
        print "[HOME] select-profile failed (httpStatus="; api.httpStatus; ") -> retry, left="; m.selectRetriesLeft
        if m.selectRetryTimer <> invalid then
            m.selectRetryTimer.control = "stop"
            m.selectRetryTimer.control = "start"
        else
            FireHomeSelectRequest()
        end if
        return
    end if

    print "[HOME] select-profile giving up (httpStatus="; api.httpStatus; ") -> back to profiles"
    SelectFailedToProfiles("api-fail httpStatus=" + ProfileSelectFmt(api.httpStatus))
end sub

sub OnHomeSelectRetry()
    if m.top.dispose = true then return
    if not IsHomeForeground() then
        ProfileSelectLogNode("HOME_SELECT_RETRY", "ignored (not foreground)", m.top)
        CancelHomeSelect("retry-not-foreground")
        return
    end if
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    print "[HOME] retrying select-profile (retriesLeft="; m.selectRetriesLeft; ")"
    FireHomeSelectRequest()
end sub

' Transient/exhausted select failure: keep the user logged in, tell them, and send them
' back to the profile picker so they can retry. (Auth is only cleared on a real 403.)
sub SelectFailedToProfiles(reason as string)
    ProfileSelectLogNode("HOME_SELECT_FAIL", reason + " pendingId=" + m.pendingSelectId, m.top)
    if not IsHomeForeground() then
        ProfileSelectLog("HOME_SELECT_FAIL", "suppressed (not foreground) reason=" + reason)
        CancelHomeSelect("fail-suppressed")
        return
    end if
    m.selectInFlight = false
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"
    ShowAlert(m.top, 2, MsgFailedSelectProfile())
    RedirectToProfiles()
end sub

' Safety net for a select that never resolves (hung socket, no apiResult ever posted).
sub OnSelectWatchdog()
    if m.top.dispose = true then return
    if not m.selectInFlight then return
    if not IsHomeForeground() then
        ProfileSelectLogNode("HOME_SELECT_WATCHDOG", "ignored (not foreground)", m.top)
        CancelHomeSelect("watchdog-not-foreground")
        return
    end if
    ' HTTP may have finished on the worker thread while apiResult is still queued on the
    ' render thread — never stack a parallel POST on top of an in-flight attempt.
    if m.selectAwaitingApiResult then
        ProfileSelectLogNode("HOME_SELECT_WATCHDOG", "awaiting apiResult -> extend", m.top)
        if m.selectWatchdog <> invalid then
            m.selectWatchdog.control = "stop"
            m.selectWatchdog.control = "start"
        end if
        return
    end if
    ' apiResult never arrived (hung socket / rendezvous timeout) — treat like a retriable
    ' transport failure and keep trying until the retry budget is exhausted.
    if m.selectRetriesLeft > 0 then
        m.selectRetriesLeft = m.selectRetriesLeft - 1
        ProfileSelectLogNode("HOME_SELECT_WATCHDOG", "no response -> retry left=" + ProfileSelectFmt(m.selectRetriesLeft), m.top)
        print "[HOME] select-profile watchdog -> retry, left="; m.selectRetriesLeft
        FireHomeSelectRequest()
        return
    end if
    print "[HOME] select-profile watchdog fired -> back to profiles"
    SelectFailedToProfiles("watchdog-exhausted")
end sub

' Subscription/badge flags the home tree reads are static placeholders (same values
' BootstrapActiveProfile wrote); set them once without another network round-trip.
sub EnsureHomeProfileDefaults()
    if GetValueByKey(SK_IsSubscribed()) = "" then SetValueByKey(SK_IsSubscribed(), "true", "app")
    if GetValueByKey(SK_IsDefaultPlan()) = "" then SetValueByKey(SK_IsDefaultPlan(), "false", "app")
    if GetValueByKey(SK_ShowPremiumBadge()) = "" then SetValueByKey(SK_ShowPremiumBadge(), "false", "app")
end sub

sub FetchProfilesBootstrap()
    path = Endpoints().PROFILE.GET_LOGIN_PROFILES
    m.profilesTask = ApiGet(path)
    m.profilesTask.observeField("apiResult", "OnProfilesBootstrapResponse")
    StartHttpTask(m.profilesTask)
end sub

sub OnProfilesBootstrapResponse()
    if m.top.dispose = true then return
    if m.profilesTask = invalid then return
    api = m.profilesTask.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    if not api.ok or api.result = invalid then
        ClearAuthAndGoLogin()
        return
    end if

    profiles = ExtractProfiles(api.result)
    if profiles.Count() = 0 then
        ClearAuthAndGoLogin()
        return
    end if

    if BootstrapActiveProfile(profiles) = invalid then
        ClearAuthAndGoLogin()
    end if
end sub

sub FetchContinueWatching()
    path = Endpoints().HOME.CONTINUE_WATCHING
    m.continueTask = ApiGet(path)
    m.continueTask.observeField("apiResult", "OnContinueWatchingResponse")
    StartHttpTask(m.continueTask)
end sub

sub OnContinueWatchingResponse()
    if m.top.dispose = true then return
    if m.continueTask = invalid then return
    api = m.continueTask.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    cwCount = 0
    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        cwCount = listing.Count()
        print "[HOME] continue-watching response ok, rows="; cwCount
        if listing.Count() > 0 then
            tagged = TagContinueWatchingRows(listing)
            m.categories = PrependCategories(m.categories, tagged)
            MaybeInsertLateContinueWatchingRow()
        end if
    else
        print "[HOME] continue-watching response failed/empty"
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    if m.continueBootTimeout <> invalid then m.continueBootTimeout.control = "stop"
    m.continueLoading = false
    HomeBootLog(m.bootSpan, "CW response", "ok=" + CwPerfBool(api.ok) + " rows=" + Str(cwCount) + " rowsBuilt=" + CwPerfBool(m.rowsBuilt))
    MaybeBuildRows()
end sub

sub FetchHomeCategories(pageNum as integer)
    ' PARITY: the LG app calls getHomeCategory with a { page, limit } payload, but its
    ' getDataApi forwards only `params` to axios (never `data`), so page/limit are dropped
    ' and the real request is a bare GET /contents/home. The backend returns a different
    ' curated home payload when page/limit ARE present, which made our rows/items diverge
    ' from LG. Send the identical param-less request so the content mapping matches exactly.
    path = Endpoints().HOME.CATEGORY_LIST
    m.categoryTask = ApiGet(path)
    m.categoryTask.observeField("apiResult", "OnHomeCategoriesResponse")
    StartHttpTask(m.categoryTask)
end sub

sub OnHomeCategoriesResponse()
    if m.top.dispose = true then return
    if m.categoryTask = invalid then return
    api = m.categoryTask.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    catCount = 0
    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        catCount = listing.Count()
        print "[HOME] home categories response ok, categories="; catCount
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
        end if
    else
        print "[HOME] home categories response failed/empty"
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    m.hasMore = false
    m.initialLoading = false
    HomeBootLog(m.bootSpan, "categories response", "listing=" + Str(catCount) + " totalCats=" + Str(m.categories.Count()))
    MaybeBuildHero()
    MaybeBuildRows()
end sub

sub FetchLatestVersion()
    path = Endpoints().LOGIN.CHECK_UPDATE
    m.versionTask = ApiGet(path)
    m.versionTask.observeField("apiResult", "OnLatestVersionResponse")
    StartHttpTask(m.versionTask)
end sub

sub OnLatestVersionResponse()
    if m.top.dispose = true then return
    if m.versionTask = invalid then return
    api = m.versionTask.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    verdict = EvaluateVersionUpdate(api)
    m.showUpdate = verdict.showUpdate
    m.versionLoading = false
    ' Version check is non-blocking and gates nothing (parity: checkVersion runs in
    ' parallel and never blocks isInitialLoading).
end sub

' The update check runs in parallel and never gates first paint (parity with
' index.tsx, where checkVersion does not block isInitialLoading).
function AnyBootLoading() as boolean
    return m.initialLoading or m.continueLoading
end function

' Row build gate — OTT only needs categories (CW may arrive late); Netflix waits for both.
function RowsBootLoading() as boolean
    if ThemeIsOttHome() then return m.initialLoading
    return AnyBootLoading()
end function

' ── Hero (independent of Continue Watching) ──────────────────────────────────
' Built as soon as categories land. Hero shimmer stays until the poster actually
' paints (OnHeroPosterReady) or the safety timeout fires.
sub MaybeBuildHero()
    if m.heroBuilt then return
    m.heroBuilt = true
    items = ExtractBannerItems(m.categories)
    print "[HOME] MaybeBuildHero bannerItems="; items.Count()
    if items.Count() = 0 then
        ' Nothing to show in the hero — drop its shimmer immediately.
        ShowHeroSkeleton(false)
        UpdateHeroBanner()
        ' No hero means no trailer to wait for: let the rows build right away.
        m.rowGateElapsed = true
        MaybeStartRowBuild()
        return
    end if
    m.skeletonTimeout.control = "start"
    UpdateHeroBanner()
end sub

' ── Rows / Continue Watching (waits for BOTH categories and CW) ───────────────
' The rows shimmer (which reads as the Continue-Watching shimmer) stays up until CW
' has resolved AND categories are in, so the hero can be live above a still-loading row.
sub MaybeBuildRows()
    if m.rowsBuilt then return
    if RowsBootLoading() then
        HomeBootLog(m.bootSpan, "rows waiting", "initial=" + CwPerfBool(m.initialLoading) + " continue=" + CwPerfBool(m.continueLoading) + " ott=" + CwPerfBool(ThemeIsOttHome()))
        print "[HOME] MaybeBuildRows waiting (initialLoading="; m.initialLoading; " continueLoading="; m.continueLoading; ")"
        return
    end if
    m.rowsDataReady = true
    HomeBootLog(m.bootSpan, "rows data ready", "cats=" + Str(FilterContentRows(m.categories).Count()))
    print "[HOME] MaybeBuildRows -> data ready, waiting for hero trailer / gate"
    MaybeStartRowBuild()
end sub

sub MaybeStartRowBuild()
    if m.rowsBuilt then return
    if not m.rowsDataReady then return

    if ThemeIsOttHome() then m.rowGateElapsed = true
    ' Profile handoff: user already waited on welcome overlay — build rows immediately.
    if ProfileTransitionActive() then m.rowGateElapsed = true
    ' No CW row for this profile — do not hold row build for a hero trailer preview gate.
    if not HomeHasContinueWatchingRow() then m.rowGateElapsed = true
    if not HeroMultiSlide() then m.rowGateElapsed = true

    heroLive = (m.hero <> invalid and m.hero.trailerPlaying = true)
    if heroLive or m.rowGateElapsed then
        m.rowsBuilt = true
        if heroLive then
            HomeBootLog(m.bootSpan, "row gate open", "trailer live")
            print "[HOME] row gate open (trailer live) -> build rows"
        else
            HomeBootLog(m.bootSpan, "row gate open", "timeout/skip ott=" + CwPerfBool(ThemeIsOttHome()) + " cw=" + CwPerfBool(HomeHasContinueWatchingRow()) + " slides=" + Str(HeroSlideCount()))
            print "[HOME] row gate open (timeout) -> build rows"
        end if
        BuildContentRows()
        return
    end if

    if not m.rowGateStarted then
        m.rowGateStarted = true
        m.rowBuildGate.control = "start"
        HomeBootLog(m.bootSpan, "row gate armed", "sec=" + Str(HC_RowBuildGateSecForLayout(m.homeLayout)))
        print "[HOME] row build held for hero preview (gate armed)"
    end if
end sub

' Safety gate elapsed — build the rows even if no trailer ever went live.
sub OnRowBuildGate()
    m.rowGateElapsed = true
    MaybeStartRowBuild()
end sub

' Hero poster has painted — drop the hero shimmer (rows shimmer is untouched).
sub OnHeroPosterReady()
    if m.hero = invalid or m.hero.posterReady <> true then return
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    ShowHeroSkeleton(false)
end sub

' Safety net: never let the hero shimmer outlive the wait.
sub OnSkeletonTimeout()
    print "[HOME] hero skeleton timeout -> hide shimmer"
    ShowHeroSkeleton(false)
end sub

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
sub ApplyHomeSkeletonColors()
    if m.homeSkeleton = invalid then return
    colors = SkeletonResolveColors(CardSkeletonThemeTokens(m.top))
    m.homeSkeleton.boxColor = colors.base
    m.homeSkeleton.shineColor = colors.highlight
    bg = HomeRowPageBg()
    if bg = invalid or bg = "" then bg = SK_DefaultPageBg()
    m.homeSkeleton.backdropColor = bg
end sub

sub ShowHeroSkeleton(show as boolean)
    if m.homeSkeleton = invalid then return
    ApplyHomeSkeletonColors()
    m.homeSkeleton.heroRunning = show
end sub

sub ShowRowsSkeleton(show as boolean)
    if m.homeSkeleton = invalid then return
    if show then
        if m.cwShimmerSpan = invalid then m.cwShimmerSpan = CreateObject("roTimespan")
        CwPerfMark(m.cwShimmerSpan, "shimmer ON")
    else
        shimmerMs = CwPerfMs(m.cwShimmerSpan)
        bootMs = -1
        if m.bootSpan <> invalid then bootMs = m.bootSpan.TotalMilliseconds()
        gapMs = -1
        if m.cwRevealAtMs >= 0 and shimmerMs >= 0 then gapMs = shimmerMs - m.cwRevealAtMs
        detail = "shimmerVisible=" + Str(shimmerMs) + "ms"
        if bootMs >= 0 then detail = detail + " boot=" + Str(bootMs) + "ms"
        if gapMs >= 0 then detail = detail + " revealToShimmerOff=" + Str(gapMs) + "ms"
        CwPerfMark(m.cwShimmerSpan, "shimmer OFF", detail)
        m.cwShimmerSpan = invalid
    end if
    ApplyHomeSkeletonColors()
    m.homeSkeleton.rowsRunning = show
    if m.rowsSkeletonTimeout <> invalid then
        if not show then
            m.rowsSkeletonTimeout.control = "stop"
            if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "stop"
        end if
    end if
end sub

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
    row = m.rowsHost.createChild("ContentRow")
    ApplyThemeToRow(row)
    ' Default cardFocusIndex=0 would highlight card 0 while nodes build — clear before data.
    row.cardFocusIndex = -1
    ' Only row 0 builds immediately — row 1+ are shells until CW has painted, so their
    ' card nodes cannot steal the render thread from the first visible strip.
    if m.rowBuildIndex = 0 then
        ' Non-CW first row: skip Netflix paint-poll (profiles with no Continue Watching were
        ' stranding the rows shimmer for seconds even though no CW row exists).
        if cat <> invalid and cat.type <> HC_TypeContinueWatching() then
            row.ottRowReveal = true
        end if
        row.categoryData = cat
    else
        ' OTT catalogue rows reveal on card nodes, not thumbnail completion — avoids a multi-
        ' second blank strip when scrolling from row 0 into shell rows.
        row.ottRowReveal = true
        row.callFunc("PrepareShell", cat)
    end if
    row.translation = [0, m.rowBuildY]
    if ThemeIsOttHome() then
        m.rowTops.Push(m.rowBuildY)
        m.rowBuildY = m.rowBuildY + HC_ContentRowLayoutHeight(cat)
    else
        m.rowBuildY = m.rowBuildY + m.layoutRowPitch
    end if
    m.rowWidgets.Push(row)
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
    if m.rowsHost = invalid then return
    count = m.rowsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.rowsHost.removeChildIndex(i)
    end for
end sub

function OttRowsContentHeight() as integer
    if m.rowContentHeight <> invalid and m.rowContentHeight > 0 then return m.rowContentHeight
    if m.rowTops = invalid or m.rowTops.Count() = 0 then return 0
    if m.contentRowCats = invalid or m.contentRowCats.Count() = 0 then return 0
    lastIdx = m.rowTops.Count() - 1
    if lastIdx < 0 or lastIdx >= m.contentRowCats.Count() then return 0
    cat = m.contentRowCats[lastIdx]
    if cat = invalid then return 0
    return m.rowTops[lastIdx] + HC_ContentRowLayoutHeight(cat)
end function

sub ResumeFocusedRowBuild()
    if m.rowWidgets = invalid or m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row <> invalid then row.callFunc("ResumeBuild", invalid)
end sub

sub ApplyHomeFocus()
    if m.rowsHost = invalid then return

    pitch = m.layoutRowPitch
    if pitch = invalid or pitch <= 0 then pitch = HC_RowPitchForLayout(m.homeLayout)
    if m.focusZone = "rows" then
        if ThemeIsOttHome() and m.rowTops <> invalid and m.rowIndex >= 0 and m.rowIndex < m.rowTops.Count() then
            anchorY = m.layoutAnchorY - m.rowTops[m.rowIndex]
            contentH = OttRowsContentHeight()
            viewH = 1080 - m.layoutAnchorY + 80
            maxScroll = contentH - viewH
            if maxScroll > 0 then
                minAnchor = m.layoutAnchorY - maxScroll
                if anchorY < minAnchor then anchorY = minAnchor
            end if
        else
            anchorY = m.layoutAnchorY - (m.rowIndex * pitch)
        end if
    else
        anchorY = m.layoutAnchorY
    end if
    if anchorY > m.layoutAnchorY then anchorY = m.layoutAnchorY

    if m.focusZone = "rows" then
        lo = m.rowIndex - 1
        if lo < 0 then lo = 0
        hi = m.rowIndex + 2
        if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
        for i = lo to hi
            ApplyRowFocusState(i)
        end for
    else
        for i = 0 to m.rowWidgets.Count() - 1
            ApplyRowFocusState(i)
        end for
    end if

    UpdateRowsScrim()
    if m.interacting then
        m.pendingHeroUpdate = true
    else
        UpdateOttHeroFromFocus()
    end if
    SyncHeroAutoAdvanceHold()
    AnimateRowsHost(anchorY)
    ScheduleRowPrefetch()
end sub

' Set the focus/dim state for a single row. Pulled out of ApplyHomeFocus so the row-build
' loop can touch only the row it just created instead of re-applying focus to every row on
' every 30ms tick (which also needlessly re-triggers the rows-host scroll animation).
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

sub ApplyRowFocusState(i as integer)
    if i < 0 or i >= m.rowWidgets.Count() then return
    row = m.rowWidgets[i]
    if row = invalid then return
    row.rowFocused = (m.focusZone = "rows" and i = m.rowIndex)
    ' Netflix netflixContent.tsx dims rows below focus to 0.4; OTT content.tsx does not.
    if ThemeIsOttHome() then
        row.rowDimmed = false
    else
        row.rowDimmed = (m.focusZone = "rows" and i > m.rowIndex)
    end if
    peek = false
    if i = 0 and not m.rowsRevealed then
        peek = true
    else if m.rowsRevealed and i = 0 and (m.focusZone = "header" or m.focusZone = "hero") then
        peek = true
    end if
    suppressed = false
    if m.focusZone = "rows" then
        suppressed = (i < m.rowIndex)
    else if not peek then
        suppressed = true
    end if
    if row.hasField("rowSuppressed") then row.rowSuppressed = suppressed
    if row.hasField("rowPeekVisible") then row.rowPeekVisible = peek
    if m.focusZone = "rows" and i = m.rowIndex then
        ClampCardIndex()
        row.cardFocusIndex = m.cardIndex
    else
        row.cardFocusIndex = -1
    end if
end sub

sub ApplyAllRowFocusStates()
    if m.rowWidgets = invalid then return
    for i = 0 to m.rowWidgets.Count() - 1
        ApplyRowFocusState(i)
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

sub ClampCardIndex()
    row = CurrentRow()
    if row = invalid then
        m.cardIndex = 0
        return
    end if
    count = row.cardCount
    if count < 1 then
        m.cardIndex = 0
        return
    end if
    if m.cardIndex < 0 then m.cardIndex = 0
    if m.cardIndex >= count then m.cardIndex = count - 1
end sub

function CurrentRow() as object
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return invalid
    return m.rowWidgets[m.rowIndex]
end function

function LastRowIndex() as integer
    return m.rowWidgets.Count() - 1
end function

sub ClearAuthAndGoLogin()
    ProfileSelectLogNode("HOME_AUTH_CLEAR", "session expired -> login", m.top)
    ClearStorage()
    if m.vm <> invalid then m.vm.callFunc("NavigateClearAndReplace", RouteLogin(), {})
end sub

sub RedirectToProfiles()
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteLoginProfile(), {})
end sub

' ── Key handling ─────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return

    key = ev.key
    navRowIdx = -1
    if m.focusZone = "rows" and not AnyBootLoading() then
        if key = "down" and m.rowIndex < LastRowIndex() then
            navRowIdx = m.rowIndex + 1
        else if key = "up" and m.rowIndex > 0 then
            navRowIdx = m.rowIndex - 1
        end if
    end if
    ' Give the render thread to this interaction: suspend background builds except the row
    ' the user is scrolling into so that strip can materialize immediately.
    BeginInteraction(navRowIdx)

    if m.focusZone = "header" then
        HandleHeaderKey(key)
        return
    end if

    if AnyBootLoading() then return

    if m.focusZone = "hero" then
        HandleHeroKey(key)
        return
    end if

    if m.rowWidgets.Count() = 0 then
        if key = "up" then EnterHeroOrHeader()
        return
    end if

    if key = "left" then
        if ThemeIsSidebarHeader() and m.cardIndex = 0 then
            EnterHeaderFromContent()
        else if m.cardIndex > 0 then
            m.cardIndex = m.cardIndex - 1
            ApplyHomeFocus()
        end if
    else if key = "right" then
        row = CurrentRow()
        if row <> invalid and m.cardIndex < row.cardCount - 1 then
            m.cardIndex = m.cardIndex + 1
            ApplyHomeFocus()
        end if
    else if key = "up" then
        if m.rowIndex > 0 then
            m.rowIndex = m.rowIndex - 1
            ClampCardIndex()
            PrimeFocusedRow()
            ApplyHomeFocus()
        else
            EnterHeroOrHeader()
        end if
    else if key = "down" then
        if m.rowIndex < LastRowIndex() then
            m.rowIndex = m.rowIndex + 1
            ClampCardIndex()
            PrimeFocusedRow()
            ApplyHomeFocus()
        else if m.hasMore and not m.loadingMore then
            LoadMoreCategories()
        end if
    else if key = "OK" or key = "ok" then
        HandleCardSelection()
    end if
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

sub HandleCardSelection()
    if m.rowIndex < 0 or m.rowIndex >= m.contentRowCats.Count() then return
    row = CurrentRow()
    if row = invalid then return
    cat = m.contentRowCats[m.rowIndex]
    NavigateHomeCardSelection(m.vm, cat, m.cardIndex, row.cardCount)
end sub

sub LoadMoreCategories()
    if not m.hasMore or m.loadingMore then return
    m.loadingMore = true
    m.page = m.page + 1
    path = Endpoints().HOME.CATEGORY_LIST
    m.loadMoreTask = ApiGetQuery(path, HomeCategoryQuery(m.page))
    m.loadMoreTask.observeField("apiResult", "OnLoadMoreResponse")
    StartHttpTask(m.loadMoreTask)
end sub

sub OnLoadMoreResponse()
    if m.top.dispose = true then return
    m.loadingMore = false
    if m.loadMoreTask = invalid then return
    api = m.loadMoreTask.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    prevCatCount = m.contentRowCats.Count()
    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
            m.contentRowCats = FilterContentRows(m.categories)
            m.hasMore = true
            UpdateHeroBanner()
            ' Append-only: keep existing row nodes and build only the new categories.
            if m.contentRowCats.Count() > prevCatCount then
                m.rowBuildIndex = prevCatCount
                if ThemeIsOttHome() and m.rowContentHeight <> invalid and m.rowContentHeight > 0 then
                    m.rowBuildY = m.rowContentHeight
                else
                    m.rowBuildY = prevCatCount * m.layoutRowPitch
                end if
                m.rowsHost.visible = true
                m.rowBuildTimer.control = "start"
            end if
            if m.rowIndex < prevCatCount then
                m.rowIndex = prevCatCount
                m.cardIndex = 0
            end if
            ApplyHomeFocus()
        else
            m.hasMore = false
        end if
    else
        m.hasMore = false
    end if
end sub
