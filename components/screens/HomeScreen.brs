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
    m.homeSkeleton = invalid
    m.homeLoaderHost = m.top.findNode("homeLoaderHost")
    m.loaderPageBg = m.top.findNode("loaderPageBg")
    m.loaderCenter = m.top.findNode("loaderCenter")
    m.homeLoader = m.top.findNode("homeLoader")
    m.pageLoader = m.homeLoader
    m.loaderHost = m.homeLoaderHost
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

    if m.hero <> invalid then
        m.hero.observeField("posterReady", "OnHeroPosterReady")
        m.hero.observeField("trailerPlaying", "OnHeroTrailerPlayingChanged")
    end if

    ' Safety net: never let the page loader outlive the boot wait.
    m.skeletonTimeout = CreateObject("roSGNode", "Timer")
    m.skeletonTimeout.duration = HC_HomeSkeletonMaxSec()
    m.skeletonTimeout.repeat = false
    m.top.appendChild(m.skeletonTimeout)
    m.skeletonTimeout.observeField("fire", "OnHomeLoaderTimeout")
    m.rowsSkeletonTimeout = CreateObject("roSGNode", "Timer")
    m.rowsSkeletonTimeout.duration = HC_RowsSkeletonMaxSecForLayout(m.homeLayout)
    m.rowsSkeletonTimeout.repeat = false
    m.top.appendChild(m.rowsSkeletonTimeout)
    m.rowsSkeletonTimeout.observeField("fire", "OnRowsLoaderTimeout")
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
    m.cwRefreshTask = invalid
    m.cwRefreshInFlight = false

    if m.layoutAnim <> invalid then m.layoutAnim.observeField("state", "OnLayoutAnimState")
end sub

' ViewManager assigns navState after SetupAppHeader — see OnNavStateReady.

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
    KillHomeCwRefreshTask()
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

' Stop a finished/in-flight HTTP task and detach its result listener.
sub KillTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

' Pause/resume the hero when this screen is covered/revealed by the nav stack.
' Push/pop keeps the same HomeScreen instance; hero.visible can stay true while covered
' (e.g. a late UpdateHeroBanner), so always call ResumeHeroPlayback on reveal — not only
' when the host visible observer fires.
sub OnHomeVisibleChanged()
    if m.top.dispose = true then return
    if m.top.visible = true then
        if m.hero <> invalid then
            items = m.hero.bannerItems
            showHero = ThemeIsOttHome()
            if items <> invalid and items.Count() > 0 then showHero = true
            if showHero then
                m.hero.visible = true
                m.hero.callFunc("ResumeHeroPlayback", invalid)
            else
                m.hero.visible = false
            end if
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
        if m.hero <> invalid then
            m.hero.callFunc("PauseHeroPlayback", invalid)
            m.hero.visible = false
        end if
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        if m.interactIdle <> invalid then m.interactIdle.control = "stop"
        CancelHomeSelect("covered")
    end if
end sub

' True when this HomeScreen is the top, visible screen (not covered/disposed).

' ── Theme ────────────────────────────────────────────────────────────────────

sub LoadThemeTokens()
    tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens
    m.tokens = tokens

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

' React home/content.tsx + netflixContent.tsx + PageContainer: bg-black.
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
    m.pageBgRest = bg
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
    ApplyHomeLoaderColors()
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

function HomeRowTheme() as object
    theme = CRC_ThemeFromHost(m)
    theme.cPageBg = HomeRowPageBg()
    return theme
end function


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
    if m.homeLoaderHost <> invalid then ApplyHomeLoaderLayout(offX, viewportW)
end sub


sub ApplyHomeLoaderLayout(offX as integer, viewportW as integer)
    if m.homeLoaderHost <> invalid then m.homeLoaderHost.translation = [offX, 0]
    if m.loaderPageBg <> invalid then m.loaderPageBg.width = viewportW
    if m.loaderCenter <> invalid then m.loaderCenter.translation = [Int(viewportW / 2), 518]
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
    if m.loaderLayoutInterp <> invalid and m.homeLoaderHost <> invalid then
        fromT = m.homeLoaderHost.translation
        m.loaderLayoutInterp.keyValue = [fromT, [targetOffX, fromT[1]]]
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
    if ThemeIsOttHome() then
        m.hero.activeItem = ExtractOttActiveItem(m.categories)
    end if
    ' Do not re-show the hero while Home is covered — that leaves hero.visible=true under
    ' a paused screen and blocks trailer resume when the user pops back.
    if IsHomeForeground() then
        m.hero.visible = (items.Count() > 0 or ThemeIsOttHome())
    end if
end sub

' ── Header (parity with ottHeader.tsx NetflixHeader) ─────────────────────────


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

    flags = HeaderMenuFeatureFlags(m.top)
    m.menuItems = HeaderMenuItems(flags.reels, flags.epg)
    if ThemeIsSidebarHeader() then
        m.header.menuItems = SidebarMenuItems(flags.reels, flags.epg)
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

