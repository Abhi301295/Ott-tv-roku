sub init()
    m.hero = m.top.findNode("hero")
    m.header = m.top.findNode("homeHeader")
    m.rowsHost = m.top.findNode("rowsHost")
    m.rowsAnim = m.top.findNode("rowsAnim")
    m.rowsInterp = m.top.findNode("rowsInterp")
    m.homeSkeleton = m.top.findNode("homeSkeleton")
    m.rowsScrim = m.top.findNode("rowsScrim")
    m.rowsScrimGrad = m.top.findNode("rowsScrimGrad")
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

    ' Start on the header so navigation is responsive while hero/CW rows are still loading.
    ' The user can move to another section immediately instead of waiting for CW cards.
    m.focusZone = "header"
    m.menuItems = []
    m.menuIndex = 0

    m.contentRowCats = []
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowBuildTimer = CreateObject("roSGNode", "Timer")
    m.rowBuildTimer.duration = 0.03
    m.rowBuildTimer.repeat = true
    m.top.appendChild(m.rowBuildTimer)
    m.rowBuildTimer.observeField("fire", "OnRowBuildTick")

    m.page = HC_HomePageStart()
    m.hasMore = true
    m.homeLayout = HomeLayoutMode()
    m.showUpdate = false

    m.initialLoading = true
    m.continueLoading = true
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
    m.rowBuildGate.duration = HC_RowBuildGateSec()
    m.rowBuildGate.repeat = false
    m.top.appendChild(m.rowBuildGate)
    m.rowBuildGate.observeField("fire", "OnRowBuildGate")

    m.vm = FindViewManager(m.top)

    ' Select-profile runs on Home (behind the shimmer) so the profile screen can navigate
    ' here instantly — no full-screen loader. The chosen profile id + avatar arrive via
    ' navState, which ViewManager assigns AFTER init() returns, so the boot sequence is
    ' deferred to OnNavStateReady (see TryStartHomeBoot).
    m.pendingSelectId = ""
    m.pendingSelectAvatar = ""
    m.bootStarted = false
    m.selectInFlight = false
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
    m.top.observeField("navState", "OnNavStateReady")

    LoadThemeTokens()
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    m.top.observeField("keyEvent", "OnKey")

    ' Input-priority: any keypress pauses background row/card building so node creation never
    ' competes with the user's interaction on the single render thread; building resumes a
    ' short, repeatedly-reset idle window after the last key, so it never lags interaction.
    m.interacting = false
    m.interactIdle = CreateObject("roSGNode", "Timer")
    m.interactIdle.duration = 0.25
    m.interactIdle.repeat = false
    m.top.appendChild(m.interactIdle)
    m.interactIdle.observeField("fire", "OnInteractIdle")

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

    SetupHeader()
    EnterHeader()
    ' Boot (redirect check, shimmer, API calls) waits for navState — see OnNavStateReady.
end sub

' ViewManager assigns navState after init(); consume it once and start the boot sequence.
sub OnNavStateReady()
    TryStartHomeBoot()
end sub

sub ConsumeHomeNavState()
    ns = m.top.navState
    if ns = invalid then return
    if ns.selectProfileId <> invalid then m.pendingSelectId = ns.selectProfileId
    if ns.selectAvatar <> invalid then m.pendingSelectAvatar = ns.selectAvatar
end sub

sub TryStartHomeBoot()
    if m.bootStarted then return
    ConsumeHomeNavState()
    m.bootStarted = true

    ' A pending select (from the profile screen) sets the profile id itself once it
    ' succeeds, so don't bounce back to the picker just because it isn't persisted yet.
    if GetProfileId() = "" and m.pendingSelectId = "" then
        RedirectToProfiles()
        return
    end if

    ' Paint the chosen avatar immediately so switching profiles never flashes the previous
    ' profile's image in the header while select-profile is still in flight.
    if m.pendingSelectId <> "" and m.pendingSelectAvatar <> "" and m.header <> invalid then
        m.header.avatarUri = m.pendingSelectAvatar
    end if

    ' Both regions shimmer immediately on mount; they reveal independently as their data
    ' lands (hero on poster paint, rows when CW + categories are ready).
    ShowHeroSkeleton(true)
    ShowRowsSkeleton(true)
    ' Wall-clock from mount → hero poster painted = perceived first-content latency.
    m.bootSpan = CreateObject("roTimespan")
    StartBootSequence()
end sub

' Stop everything that ticks before this screen is torn down, so a removed HomeScreen
' can't leave its hero carousel/trailer/build timers running in the background.
sub OnDispose()
    if not m.top.dispose then return
    print "[HOME] dispose -> stopping hero + timers"
    ' Setting the hero invisible runs its OnVisibleChanged cleanup (swipe timer, trailer,
    ' video, pending detail fetch all stop).
    if m.hero <> invalid then m.hero.visible = false
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"
    if m.interactIdle <> invalid then m.interactIdle.control = "stop"
    ' Drop the in-flight select task so a late apiResult can't fire a handler on this
    ' (now removed) screen — the handlers also guard on m.top.dispose defensively.
    m.selectInFlight = false
    m.selectTask = invalid
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
    m.cNeutral200 = TokenColor(tokens, "neutral-200", "#e5e5e5")
    m.cNeutral700 = TokenColor(tokens, "neutral-700", "#181818")
    m.cNeutral800 = TokenColor(tokens, "neutral-800", "#121212")
    m.cNeutral950 = TokenColor(tokens, "neutral-900", "#0a0a0a")
end sub

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
    SetupHeader()
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
end sub

sub ApplyThemeToHero()
    if m.hero = invalid then return
    m.hero.cNeutral50 = m.cNeutral50
    m.hero.cPrimary500 = m.cPrimary500
end sub

sub UpdateHeroBanner()
    if m.hero = invalid then return
    items = ExtractBannerItems(m.categories)
    print "[HOME] UpdateHeroBanner bannerItems="; items.Count()
    ApplyThemeToHero()
    m.hero.bannerItems = items
    m.hero.visible = (items.Count() > 0)
end sub

' ── Header (parity with ottHeader.tsx NetflixHeader) ─────────────────────────

sub SetupHeader()
    if m.header = invalid then return

    reels = false
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved <> invalid and resolved.features <> invalid then
        reels = (resolved.features.reelsEnabled = true)
    end if

    m.menuItems = HeaderMenuItems(reels)
    texts = []
    for each it in m.menuItems
        texts.Push(it.text)
    end for

    m.header.menuTexts = texts
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
end sub

sub ApplyHeaderBranding()
    if m.header = invalid then return

    ' Active profile avatar (parity with NetflixHeader): persisted by fetchProfiles.
    avatarUri = RegistryRead(SK_Avatar(), "app")
    print "[AVATARDBG] HomeHeader reading avatar='"; avatarUri; "'"
    if avatarUri <> invalid then m.header.avatarUri = avatarUri

    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return
    if resolved.brandingLogo <> invalid then m.header.logoUri = resolved.brandingLogo
    if resolved.appName <> invalid then m.header.appName = resolved.appName
end sub

sub OnHeroTrailerPlayingChanged()
    UpdateHeaderScrimForHero()
    ' Preview is live now — safe to spend the render thread on building the rows.
    if m.hero <> invalid and m.hero.trailerPlaying = true then MaybeStartRowBuild()
end sub

sub UpdateHeaderScrimForHero()
    if m.header = invalid then return
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)
    ' Home hero media must sit visually behind the header/nav like LG. Do not restore a
    ' black header band for the static poster either, otherwise the media appears to start
    ' below the header (the red-line issue).
    m.header.scrimOpacity = 0.0
    if playing then
        print "[HEROVID] trailer playing -> transparent header scrim"
    else
        print "[HEROVID] trailer idle -> transparent header scrim"
    end if
end sub

sub EnterHeader()
    if m.header = invalid then return
    m.focusZone = "header"
    m.menuIndex = m.header.selectedIndex
    m.header.focusedIndex = m.menuIndex
    m.header.headerActive = true
    row = CurrentRow()
    if row <> invalid then row.cardFocusIndex = -1
end sub

sub ExitHeaderToRows()
    if m.header <> invalid then m.header.headerActive = false
    m.focusZone = "rows"
    ApplyHomeFocus()
end sub

sub HandleHeaderKey(key as string)
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
    if m.hero = invalid or m.hero.visible <> true then return false
    items = m.hero.bannerItems
    if items = invalid or items.Count() = 0 then return false
    ' Focusable only when there is something to act on: multiple slides (arrows) or a
    ' playing trailer (mute) — mirrors React showing arrows only when items.length > 1.
    return (items.Count() > 1) or (m.hero.trailerPlaying = true)
end function

function HeroMultiSlide() as boolean
    if m.hero = invalid then return false
    items = m.hero.bannerItems
    return (items <> invalid and items.Count() > 1)
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
        EnterHeader()
        return
    end if
    target = "next"
    if m.hero.trailerPlaying = true then target = "mute"
    EnterHero(target)
end sub

sub EnterHeroFromHeader()
    if m.header <> invalid then m.header.headerActive = false
    if HeroAvailable() then
        EnterHero("next")
    else if m.rowWidgets.Count() > 0 then
        ExitHeaderToRows()
    else
        ' Keep header focus active while Home content is still loading.
        EnterHeader()
    end if
end sub

sub EnterHero(target as string)
    if not HeroAvailable() then return
    m.focusZone = "hero"
    if m.header <> invalid then m.header.headerActive = false
    ' Drop any card highlight while the hero is focused.
    for each row in m.rowWidgets
        if row <> invalid then row.cardFocusIndex = -1
    end for
    m.heroFocus = NormalizeHeroTarget(target)
    ApplyHeroFocus()
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

sub HandleHeroKey(key as string)
    multi = HeroMultiSlide()
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)

    if key = "up" then
        if m.heroFocus = "mute" then
            m.heroFocus = "next"
            ApplyHeroFocus()
        else
            ClearHeroFocus()
            EnterHeader()
        end if
    else if key = "down" then
        if m.heroFocus = "next" and playing then
            m.heroFocus = "mute"
            ApplyHeroFocus()
        else
            EnterRowsFromHero()
        end if
    else if key = "left" then
        if m.heroFocus = "next" and multi then
            m.heroFocus = "prev"
            ApplyHeroFocus()
        else if m.heroFocus = "mute" then
            EnterRowsFromHero()
        end if
    else if key = "right" then
        if m.heroFocus = "prev" and multi then
            m.heroFocus = "next"
            ApplyHeroFocus()
        end if
    else if key = "OK" or key = "ok" then
        print "[KEYDBG] HandleHeroKey OK branch heroFocus='"; m.heroFocus; "' heroInvalid="; (m.hero = invalid)
        if m.hero = invalid then return
        if m.heroFocus = "prev" then
            print "[KEYDBG] calling HeroGoPrev"
            m.hero.callFunc("HeroGoPrev", invalid)
        else if m.heroFocus = "next" then
            print "[KEYDBG] calling HeroGoNext"
            m.hero.callFunc("HeroGoNext", invalid)
        else if m.heroFocus = "mute" then
            print "[KEYDBG] calling HeroToggleMute"
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
        if m.rowWidgets.Count() > 0 then
            ExitHeaderToRows()
        else
            EnterHeader()
        end if
        return
    end if

    if m.vm <> invalid then
        m.vm.callFunc("NavigateReplace", item.route, { type: item.type, selectedID: item.text })
    end if
end sub

' ── Boot sequence (parity with features/home/index.tsx) ──────────────────────

sub StartBootSequence()
    ' If the profile screen handed us a pending profile, establish the session first
    ' (select-profile, behind the shimmer). Content boot only fires once the token lands.
    if m.pendingSelectId <> "" then
        print "[HOME] pending select-profile -> running behind shimmer"
        DoHomeSelect()
        return
    end if
    BootHomeContent()
end sub

sub BootHomeContent()
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
end sub

' ── Select-profile (runs on Home so the profile screen can navigate here instantly) ──
' POST select-profile, retrying a few times on transient 401/404 (a freshly-issued token
' is briefly not yet active on the backend). On success: persist identity + boot content.
' On give-up: surface a toast and return to the picker — never log the user out for a
' transient failure (only a real 403 session-expiry, handled by HandleSessionExpiry, does).
sub DoHomeSelect()
    m.selectInFlight = true
    m.selectRetriesLeft = m.SELECT_MAX_RETRIES
    if m.selectWatchdog <> invalid then
        m.selectWatchdog.control = "stop"
        m.selectWatchdog.control = "start"
    end if
    ' Re-open a keep-alive connection to the (Bearer-auth) select endpoint: the profile
    ' screen warmed the pool, but a long auto-select wait can let that socket idle out, so
    ' the POST would otherwise pay a fresh TLS handshake. SelectProfilePath() is post-login
    ' Bearer here, so this never poisons the pool with Basic-auth (see WarmHttpConnections).
    WarmHttpConnections(SelectProfilePath())
    FireHomeSelectRequest()
end sub

sub FireHomeSelectRequest()
    path = SelectProfilePath()
    m.selectTask = ApiPost(path, SelectProfilePayload(m.pendingSelectId))
    m.selectTask.observeField("apiResult", "OnHomeSelectResponse")
    StartHttpTask(m.selectTask)
end sub

sub OnHomeSelectRetry()
    if m.top.dispose = true then return
    if m.selectRetryTimer <> invalid then m.selectRetryTimer.control = "stop"
    print "[HOME] retrying select-profile (retriesLeft="; m.selectRetriesLeft; ")"
    FireHomeSelectRequest()
end sub

sub OnHomeSelectResponse()
    ' A late apiResult after the screen left the tree must not mutate auth/navigation.
    if m.top.dispose = true then return
    if m.selectTask = invalid then return
    api = m.selectTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

    if api.ok and ApplySelectProfileTokens(api.result) then
        PersistSelectedProfile(m.pendingSelectId, m.pendingSelectAvatar)
        m.pendingSelectId = ""
        m.selectInFlight = false
        if m.selectWatchdog <> invalid then m.selectWatchdog.control = "stop"
        print "[HOME] select-profile ok -> boot home content"
        BootHomeContent()
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
    SelectFailedToProfiles()
end sub

' Transient/exhausted select failure: keep the user logged in, tell them, and send them
' back to the profile picker so they can retry. (Auth is only cleared on a real 403.)
sub SelectFailedToProfiles()
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
    print "[HOME] select-profile watchdog fired -> back to profiles"
    SelectFailedToProfiles()
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
    if HandleSessionExpiry(m.top, api) then return

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
    if m.continueTask = invalid then return
    api = m.continueTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        print "[HOME] continue-watching response ok, rows="; listing.Count()
        if listing.Count() > 0 then
            tagged = TagContinueWatchingRows(listing)
            m.categories = PrependCategories(m.categories, tagged)
        end if
    else
        print "[HOME] continue-watching response failed/empty"
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    m.continueLoading = false
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
    if m.categoryTask = invalid then return
    api = m.categoryTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        print "[HOME] home categories response ok, categories="; listing.Count()
        LogCategoryMapping(listing)
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
        end if
    else
        print "[HOME] home categories response failed/empty"
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    ' PARITY: the active LG layout (NetflixContent) renders this single param-less response
    ' and never paginates (loadMore is only wired into the non-Netflix Content layout). So
    ' there is no "next page" — disable infinite scroll so we show exactly LG's row set.
    m.hasMore = false

    m.initialLoading = false
    ' Categories (and thus the hero banner) are ready — render the hero NOW, independent
    ' of Continue Watching. Rows still wait for CW so its shimmer can keep showing.
    MaybeBuildHero()
    MaybeBuildRows()
end sub

' Verification logging for content/image parity with LG. Dumps the row order, each row's
' type/cardType/item-count, and (for TOP_CONTENTS) every item's title + thumbnail variants
' so we can confirm Roku and LG resolve the same content and the same image per card.
sub LogCategoryMapping(listing as object)
    if listing = invalid then
        print "[HOME][MAP] listing invalid"
        return
    end if
    print "[HOME][MAP] ===== category mapping (rows="; listing.Count(); ") ====="
    for i = 0 to listing.Count() - 1
        cat = listing[i]
        if cat <> invalid then
            nm = ""
            if cat.name <> invalid then nm = cat.name
            tp = ""
            if cat.type <> invalid then tp = cat.type
            ct = ""
            if cat.cardType <> invalid then ct = cat.cardType
            cid = ""
            if cat._id <> invalid then cid = cat._id
            cnt = 0
            if cat.result <> invalid then cnt = cat.result.Count()
            print "[HOME][MAP] row#"; i; " name='"; nm; "' type="; tp; " cardType="; ct; " id="; cid; " items="; cnt
            if tp = "TOP_CONTENTS" and cat.result <> invalid then
                for j = 0 to cat.result.Count() - 1
                    it = cat.result[j]
                    if it <> invalid then
                        itTitle = ""
                        if it.title <> invalid then itTitle = it.title
                        itId = ""
                        if it._id <> invalid then itId = it._id
                        print "[HOME][MAP]   item#"; j; " id="; itId; " title='"; itTitle; "'"
                        if it.thumbnails <> invalid then
                            for each th in it.thumbnails
                                if th <> invalid then
                                    thType = ""
                                    if th.type <> invalid then thType = th.type
                                    thPath = ""
                                    if th.path <> invalid then thPath = th.path
                                    print "[HOME][MAP]       thumb type="; thType; " path="; thPath
                                end if
                            end for
                        end if
                    end if
                end for
            end if
        end if
    end for
    print "[HOME][MAP] ===== end mapping ====="
end sub

sub FetchLatestVersion()
    path = Endpoints().LOGIN.CHECK_UPDATE
    m.versionTask = ApiGet(path)
    m.versionTask.observeField("apiResult", "OnLatestVersionResponse")
    StartHttpTask(m.versionTask)
end sub

sub OnLatestVersionResponse()
    if m.versionTask = invalid then return
    api = m.versionTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

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
    if AnyBootLoading() then
        print "[HOME] MaybeBuildRows waiting (initialLoading="; m.initialLoading; " continueLoading="; m.continueLoading; ")"
        return
    end if
    ' Data is in. Don't build yet — hand the render thread to the hero preview first and
    ' let the gate (trailer-live or timeout) kick off the build (see MaybeStartRowBuild).
    m.rowsDataReady = true
    print "[HOME] MaybeBuildRows -> data ready, waiting for hero trailer / gate"
    MaybeStartRowBuild()
end sub

' Build the rows once data is ready AND either the hero trailer is live or the safety gate
' elapsed. Holding the build off the render thread until the preview is up stops the rows
' from starving the trailer (the preview video would otherwise never paint until CW built).
sub MaybeStartRowBuild()
    if m.rowsBuilt then return
    if not m.rowsDataReady then return

    heroLive = (m.hero <> invalid and m.hero.trailerPlaying = true)
    if heroLive or m.rowGateElapsed then
        m.rowsBuilt = true
        if heroLive then
            print "[HOME] row gate open (trailer live) -> build rows"
        else
            print "[HOME] row gate open (timeout) -> build rows"
        end if
        ' Rows build progressively; the rows shimmer is dropped in OnRowBuildTick once the
        ' first real row exists, so the shimmer hands straight off to content (no black gap).
        BuildContentRows()
        return
    end if

    ' Arm the safety gate once so rows still appear even if this slide has no trailer.
    if not m.rowGateStarted then
        m.rowGateStarted = true
        m.rowBuildGate.control = "start"
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
    bootMs = 0
    if m.bootSpan <> invalid then bootMs = m.bootSpan.TotalMilliseconds()
    print "[PERF] hero poster painted: "; bootMs; "ms from mount (perceived first-content latency)"
    print "[HOME] hero poster ready -> hide hero shimmer"
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    ShowHeroSkeleton(false)
end sub

' Safety net: never let the hero shimmer outlive the wait.
sub OnSkeletonTimeout()
    print "[HOME] hero skeleton timeout -> hide shimmer"
    ShowHeroSkeleton(false)
end sub

sub ShowHeroSkeleton(show as boolean)
    if m.homeSkeleton = invalid then return
    print "[HOME] ShowHeroSkeleton("; show; ")"
    m.homeSkeleton.boxColor = m.cNeutral800
    m.homeSkeleton.heroRunning = show
end sub

sub ShowRowsSkeleton(show as boolean)
    if m.homeSkeleton = invalid then return
    print "[HOME] ShowRowsSkeleton("; show; ")"
    m.homeSkeleton.boxColor = m.cNeutral800
    m.homeSkeleton.rowsRunning = show
end sub

' ── Content rows (parity with netflixContent.tsx row list) ───────────────────

' Building every card up-front blocks the render thread for several seconds, so the
' rows are created one per timer tick: the hero/header/background paint immediately
' and rows pop in top-to-bottom while the thread stays responsive.
sub BuildContentRows()
    if m.rowsHost = invalid then return
    ClearContentRows()

    m.contentRowCats = FilterContentRows(m.categories)
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowIndex = 0
    m.cardIndex = 0
    m.rowsHost.visible = (m.contentRowCats.Count() > 0)
    ' Render-build instrumentation: measure render-thread cost so optimization (e.g. lazy
    ' row building) is driven by data, not guesswork. [PERF] tags are greppable.
    m.rowBuildSpan = CreateObject("roTimespan")
    m.rowBuildCostMs = 0
    print "[HOME] BuildContentRows rows="; m.contentRowCats.Count()

    ' Skeleton visibility is owned by OnHeroPosterReady / OnSkeletonTimeout, so we don't
    ' toggle it here — rows build underneath and the shimmer drops once the hero paints.
    if m.contentRowCats.Count() > 0 then
        m.rowBuildTimer.control = "start"
    end if
end sub

sub OnRowBuildTick()
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
    ' Rows 0–1 (CW + next) materialize immediately; deeper rows are shell-only until the
    ' user scrolls near them or the first row finishes loading (background warm-up).
    if m.rowBuildIndex <= 1 then
        row.categoryData = cat
    else
        row.callFunc("PrepareShell", cat)
    end if
    row.translation = [0, m.rowBuildY]
    m.rowWidgets.Push(row)
    rowMs = span.TotalMilliseconds()
    if m.rowBuildCostMs = invalid then m.rowBuildCostMs = 0
    m.rowBuildCostMs = m.rowBuildCostMs + rowMs
    print "[PERF] build row "; m.rowBuildIndex; " '"; catName; "' cards="; row.cardCount; " "; rowMs; "ms"

    ' Keep the rows shimmer up until the FIRST row (Continue Watching) has actually loaded
    ' its thumbnails, then hand off to real cards (no static grey-card gap).
    if m.rowBuildIndex = 0 then row.observeField("mediaReady", "OnFirstRowBuilt")

    m.rowBuildY = m.rowBuildY + HC_RowPitch()
    m.rowBuildIndex = m.rowBuildIndex + 1

    ' Touch only the row we just built — the full ApplyHomeFocus (which also drives the
    ' rows-host scroll animation) runs once the build completes, not on every tick.
    ApplyRowFocusState(m.rowWidgets.Count() - 1)

    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
        wall = 0
        if m.rowBuildSpan <> invalid then wall = m.rowBuildSpan.TotalMilliseconds()
        print "[PERF] all rows built: "; m.rowBuildIndex; " rows, render-cost="; m.rowBuildCostMs; "ms, wall="; wall; "ms"
        ApplyHomeFocus()
    end if
end sub

' The Continue Watching row finished loading thumbnails — drop the shimmer so the shimmer
' hands straight off to real cards (not static grey card placeholders).
sub OnFirstRowBuilt()
    row = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row <> invalid and row.hasField("mediaReady") and row.mediaReady <> true then return
    print "[HOME] first row media ready -> hide rows shimmer + reveal hero behind cards"
    ShowRowsSkeleton(false)
    ' CW content has painted — drop the dark scrim so the hero bleeds behind the cards.
    m.rowsRevealed = true
    UpdateRowsScrim()
    ' Warm the next row in the background while the user is still on CW.
    if m.rowWidgets.Count() > 1 then
        row1 = m.rowWidgets[1]
        if row1 <> invalid then row1.callFunc("Materialize", invalid)
    end if
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

sub ApplyHomeFocus()
    if m.rowsHost = invalid then return

    if m.focusZone = "rows" then MaterializeNearbyRows()

    anchorY = HC_NetflixAnchorY() - (m.rowIndex * HC_RowPitch())
    AnimateRowsHost(anchorY)

    for i = 0 to m.rowWidgets.Count() - 1
        ApplyRowFocusState(i)
    end for

    UpdateRowsScrim()
end sub

' Set the focus/dim state for a single row. Pulled out of ApplyHomeFocus so the row-build
' loop can touch only the row it just created instead of re-applying focus to every row on
' every 30ms tick (which also needlessly re-triggers the rows-host scroll animation).
' Materialize deferred row shells within a 1-row prefetch window around focus.
sub MaterializeNearbyRows()
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return
    lo = m.rowIndex - 1
    if lo < 0 then lo = 0
    hi = m.rowIndex + 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = lo to hi
        row = m.rowWidgets[i]
        if row <> invalid then row.callFunc("Materialize", invalid)
    end for
end sub

sub ApplyRowFocusState(i as integer)
    if i < 0 or i >= m.rowWidgets.Count() then return
    row = m.rowWidgets[i]
    if row = invalid then return
    row.rowFocused = (m.focusZone = "rows" and i = m.rowIndex)
    row.rowDimmed = (m.focusZone = "rows" and i > m.rowIndex)
    if m.focusZone = "rows" and i = m.rowIndex then
        ClampCardIndex()
        row.cardFocusIndex = m.cardIndex
    else
        row.cardFocusIndex = -1
    end if
end sub

' Keep the row backdrop transparent in both loading and loaded states. The row shimmer owns
' the loading affordance, and React/LG keeps the hero visible behind the content rows.
sub UpdateRowsScrim()
    if m.rowsScrim <> invalid then m.rowsScrim.opacity = 0.0
    if m.rowsScrimGrad <> invalid then m.rowsScrimGrad.opacity = 0.0
end sub

' Smooth row pinning (parity with netflixContent.tsx 400ms translate).
sub AnimateRowsHost(targetY as integer)
    if m.rowsHost = invalid then return
    fromY = m.rowsHost.translation[1]
    if m.rowsAnim = invalid or m.rowsInterp = invalid or fromY = targetY then
        m.rowsHost.translation = [0, targetY]
        return
    end if
    m.rowsInterp.keyValue = [[0, fromY], [0, targetY]]
    m.rowsAnim.control = "start"
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
    ClearStorage()
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteLogin(), {})
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
    ' Give the render thread to this interaction: suspend any in-progress background build.
    BeginInteraction()
    print "[KEYDBG] OnKey key='"; key; "' zone='"; m.focusZone; "' heroFocus='"; m.heroFocus; "'"

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
        if m.cardIndex > 0 then
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
            ApplyHomeFocus()
        else
            EnterHeroOrHeader()
        end if
    else if key = "down" then
        if m.rowIndex < LastRowIndex() then
            m.rowIndex = m.rowIndex + 1
            ClampCardIndex()
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
sub BeginInteraction()
    m.interacting = true
    PauseRowBuilding()
    if m.interactIdle <> invalid then
        m.interactIdle.control = "stop"
        m.interactIdle.control = "start"
    end if
end sub

sub OnInteractIdle()
    m.interacting = false
    ResumeRowBuilding()
end sub

sub PauseRowBuilding()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("PauseBuild", invalid)
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
    m.loadingMore = false
    if m.loadMoreTask = invalid then return
    api = m.loadMoreTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

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
                m.rowBuildY = prevCatCount * HC_RowPitch()
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
