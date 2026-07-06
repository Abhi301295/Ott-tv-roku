' HomeBoot.brs — home mount, select-profile, category fetch, page loader.


' ViewManager assigns navState after SetupAppHeader — see OnNavStateReady.
sub OnNavStateReady()
    if m.homeNavReady = true then return
    m.homeNavReady = true
    HomeLoaderLog("navState ready", "pendingSelectId=" + m.pendingSelectId)
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
    HomeLoaderLogBoot(m.bootSpan, "boot work start", HomeLoaderGateSnapshot())

    ' A pending select (from the profile screen) sets the profile id itself once it
    ' succeeds, so don't bounce back to the picker just because it isn't persisted yet.
    if GetProfileId() = "" and m.pendingSelectId = "" then
        ProfileSelectLogNode("HOME_BOOT", "no profile id -> RedirectToProfiles", m.top)
        RedirectToProfiles()
        return
    end if

    ConsumeHomeBootCacheIfReady()

    ' Page loader follows layout; React Spinner covers the home canvas until data lands.
    ApplyHomeLoaderColors()
    HomeLoaderLogBoot(m.bootSpan, "loader SHOW", "boot sequence | " + HomeLoaderGateSnapshot())
    ShowHomeLoader(true)
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "start"
    m.cwShimmerSpan = CreateObject("roTimespan")
    CwPerfMark(m.cwShimmerSpan, "loader ON (boot)")
    ' Rows timeout starts when BuildContentRows begins, not at boot (hero gate can take 3.5s+).
    ' Wall-clock from mount → hero poster painted = perceived first-content latency.
    m.bootSpan = CreateObject("roTimespan")
    HomeBootLog(m.bootSpan, "boot start", "layout=" + m.homeLayout + " ott=" + CwPerfBool(ThemeIsOttHome()) + " prefetch=" + CwPerfBool(m.categoriesPrefetched = true))
    if HomeLoadTurboEnabled() and m.hero <> invalid and m.hero.hasField("holdTrailerBoot") then
        m.hero.holdTrailerBoot = true
    end if
    StartBootSequence()
end sub


sub ArmTransitionSafetyTimer()
    if m.transitionSafetyTimer = invalid then return
    m.transitionSafetyTimer.control = "stop"
    m.transitionSafetyTimer.control = "start"
end sub


sub OnTransitionSafetyTimer()
    if m.transitionSafetyTimer <> invalid then m.transitionSafetyTimer.control = "stop"
    if not m.contentBootStarted then BootHomeContent()
    row0 = invalid
    if m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 then row0 = m.rowWidgets[0]
    if row0 <> invalid then
        row0.callFunc("ForceReveal", invalid)
        if not m.rowsRevealed then TryPrepareHomeReveal()
    end if
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

' Stop every ContentRow timer on this screen (render-thread hygiene on dispose).
sub AbortAllRowBuilds()
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("AbortBuild", invalid)
    end for
end sub

' Stop everything that ticks before this screen is torn down, so a removed HomeScreen
' can't leave its hero carousel/trailer/build timers running in the background.

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
    HomeLoaderLogBoot(m.bootSpan, "content boot start", HomeLoaderGateSnapshot())
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
    HomeLoaderLogBoot(m.bootSpan, "CW boot TIMEOUT", HomeLoaderGateSnapshot())
    HomeBootLog(m.bootSpan, "CW boot timeout", "proceed without continue-watching")
    m.continueLoading = false
    MaybeBuildRows()
end sub

' ── Select-profile (runs on Home so the profile screen can navigate here instantly) ──
' POST select-profile, retrying a few times on transient 401/404 (a freshly-issued token
' is briefly not yet active on the backend). On success: persist identity + boot content.
' On give-up: surface a toast and return to the picker — never log the user out for a
' transient failure (only a real session-expiry ends the session via HttpClient).

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
        HomeLoaderLogBoot(m.bootSpan, "select-profile OK", HomeLoaderGateSnapshot())
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
    HomeLoaderLogBoot(m.bootSpan, "fetch CW", path)
    m.continueTask = ApiGet(path)
    m.continueTask.observeField("apiResult", "OnContinueWatchingResponse")
    StartHttpTask(m.continueTask)
end sub


sub OnContinueWatchingResponse()
    if m.top.dispose = true then return
    if m.continueTask = invalid then return
    api = m.continueTask.apiResult
    if api = invalid then return
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
    HomeLoaderLogBoot(m.bootSpan, "CW response", "ok=" + CwPerfBool(api.ok) + " rows=" + Str(cwCount) + " | " + HomeLoaderGateSnapshot())
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
    HomeLoaderLogBoot(m.bootSpan, "fetch categories", path)
    m.categoryTask = ApiGet(path)
    m.categoryTask.observeField("apiResult", "OnHomeCategoriesResponse")
    StartHttpTask(m.categoryTask)
end sub


sub OnHomeCategoriesResponse()
    if m.top.dispose = true then return
    if m.categoryTask = invalid then return
    api = m.categoryTask.apiResult
    if api = invalid then return
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
    HomeLoaderLogBoot(m.bootSpan, "categories response", "listing=" + Str(catCount) + " totalCats=" + Str(m.categories.Count()) + " | " + HomeLoaderGateSnapshot())
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
    verdict = EvaluateVersionUpdate(api)
    m.showUpdate = verdict.showUpdate
    m.versionLoading = false
    ' Version check is non-blocking and gates nothing (parity: checkVersion runs in
    ' parallel and never blocks isInitialLoading).
end sub

' The update check runs in parallel and never gates first paint (parity with
' index.tsx, where checkVersion does not block isInitialLoading).

' The update check runs in parallel and never gates first paint (parity with
' index.tsx, where checkVersion does not block isInitialLoading).
function AnyBootLoading() as boolean
    return m.initialLoading or m.continueLoading
end function

' Row build gate — OTT may build before CW on revisit; profile handoff and Netflix wait
' for both APIs so row 0 is Continue Watching before the welcome overlay dismisses.
function RowsBootLoading() as boolean
    if ThemeIsOttHome() then return m.initialLoading
    return AnyBootLoading()
end function

' ── Hero (independent of Continue Watching) ──────────────────────────────────
' Built as soon as categories land. Hero shimmer stays until the poster actually
' paints (OnHeroPosterReady) or the safety timeout fires.

' ── Hero (independent of Continue Watching) ──────────────────────────────────
' Built as soon as categories land. Hero shimmer stays until the poster actually
' paints (OnHeroPosterReady) or the safety timeout fires.
sub MaybeBuildHero()
    if m.heroBuilt then return
    m.heroBuilt = true
    items = ExtractBannerItems(m.categories)
    HomeLoaderLogBoot(m.bootSpan, "build hero", "bannerItems=" + Str(items.Count()))
    print "[HOME] MaybeBuildHero bannerItems="; items.Count()
    if items.Count() = 0 then
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
' Page loader stays up until row 0 is revealed (parity with React Spinner until rows).
sub MaybeBuildRows()
    if m.rowsBuilt then return
    if RowsBootLoading() then
        HomeLoaderLogBoot(m.bootSpan, "MaybeBuildRows waiting", "initial=" + CwPerfBool(m.initialLoading) + " continue=" + CwPerfBool(m.continueLoading))
        HomeBootLog(m.bootSpan, "rows waiting", "initial=" + CwPerfBool(m.initialLoading) + " continue=" + CwPerfBool(m.continueLoading) + " ott=" + CwPerfBool(ThemeIsOttHome()))
        print "[HOME] MaybeBuildRows waiting (initialLoading="; m.initialLoading; " continueLoading="; m.continueLoading; ")"
        return
    end if
    m.rowsDataReady = true
    HomeLoaderLogBoot(m.bootSpan, "rows data ready", "cats=" + Str(FilterContentRows(m.categories).Count()) + " | " + HomeLoaderGateSnapshot())
    HomeBootLog(m.bootSpan, "rows data ready", "cats=" + Str(FilterContentRows(m.categories).Count()))
    print "[HOME] MaybeBuildRows -> data ready, waiting for hero trailer / gate"
    MaybeStartRowBuild()
end sub


sub MaybeStartRowBuild()
    if m.rowsBuilt then return
    if not m.rowsDataReady then return

    if HomeLoadTurboEnabled() then
        m.rowGateElapsed = true
        m.rowsBuilt = true
        HomeBootLog(m.bootSpan, "row gate open", "turbo immediate")
        print "[HOME] turbo row gate -> build rows immediately"
        BuildContentRows()
        return
    end if

    if ThemeIsOttHome() then m.rowGateElapsed = true
    ' No CW row for this profile — do not hold row build for a hero trailer preview gate.
    if not HomeHasContinueWatchingRow() then m.rowGateElapsed = true
    if not HeroMultiSlide() then m.rowGateElapsed = true

    heroLive = (m.hero <> invalid and m.hero.trailerPlaying = true)
    if heroLive or m.rowGateElapsed then
        m.rowsBuilt = true
        HomeLoaderLogBoot(m.bootSpan, "row gate OPEN", "trailer=" + CwPerfBool(heroLive) + " elapsed=" + CwPerfBool(m.rowGateElapsed) + " | " + HomeLoaderGateSnapshot())
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
        HomeLoaderLogBoot(m.bootSpan, "row gate ARMED", "sec=" + Str(HC_RowBuildGateSecForLayout(m.homeLayout)))
        HomeBootLog(m.bootSpan, "row gate armed", "sec=" + Str(HC_RowBuildGateSecForLayout(m.homeLayout)))
        print "[HOME] row build held for hero preview (gate armed)"
    end if
end sub

' Safety gate elapsed — build the rows even if no trailer ever went live.

' Safety gate elapsed — build the rows even if no trailer ever went live.
sub OnRowBuildGate()
    m.rowGateElapsed = true
    HomeLoaderLogBoot(m.bootSpan, "row gate TIMEOUT", HomeLoaderGateSnapshot())
    MaybeStartRowBuild()
end sub

' Hero poster has painted — retry dropping the loader when row 0 is also ready.
sub OnHeroPosterReady()
    if m.hero = invalid or m.hero.posterReady <> true then return
    HomeLoaderLogBoot(m.bootSpan, "hero posterReady", HomeLoaderGateSnapshot())
    if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    TryPrepareHomeReveal()
end sub

' Safety net: never drop the page loader while first paint is still in flight.
sub OnHomeLoaderTimeout()
    HomeLoaderLogBoot(m.bootSpan, "loader safety timeout", "bootActive=" + CwPerfBool(HomeLoaderBootActive()) + " | " + HomeLoaderGateSnapshot())
    if not m.rowsRevealed and m.rowsBuilt and WelcomeDismissReadyForRow0() then
        TryPrepareHomeReveal()
        if m.rowsRevealed then return
    end if
    if HomeLoaderBootActive() then
        HomeBootLog(m.bootSpan, "loader safety re-arm", "boot in flight")
        BrowseEnsureLoaderRunning(m)
        ArmHomeLoaderSafetyTimeout()
        return
    end if
    HomeBootLog(m.bootSpan, "loader safety hide", "stuck after reveal")
    ShowHomeLoader(false)
end sub

function HomeLoaderBootActive() as boolean
    if not m.bootStarted then return false
    if m.selectInFlight then return true
    if not m.rowsRevealed then return true
    if AnyBootLoading() then return true
    if not m.rowsBuilt then return true
    if m.rowBuildTimer <> invalid and m.rowBuildTimer.control = "start" then return true
    return false
end function

sub ArmHomeLoaderSafetyTimeout()
    if m.skeletonTimeout = invalid then return
    m.skeletonTimeout.control = "stop"
    m.skeletonTimeout.control = "start"
end sub

sub ApplyHomeLoaderColors()
    BrowseApplyPageLoaderColors(m)
    if BrowsePageLoaderRunning(m) then BrowseApplyLoaderVeil(m, true, m.pageBgRest)
end sub

sub ShowHomeLoader(show as boolean)
    if m.homeLoader = invalid then return
    if show then
        HomeLoaderLogBoot(m.bootSpan, "ShowHomeLoader ON", HomeLoaderGateSnapshot())
        if m.cwShimmerSpan = invalid then m.cwShimmerSpan = CreateObject("roTimespan")
        CwPerfMark(m.cwShimmerSpan, "loader ON")
        BrowseShowPageLoader(m, m.pageBgRest)
        ArmHomeLoaderSafetyTimeout()
    else
        loaderMs = CwPerfMs(m.cwShimmerSpan)
        bootMs = -1
        if m.bootSpan <> invalid then bootMs = m.bootSpan.TotalMilliseconds()
        detail = "loaderVisible=" + Str(loaderMs) + "ms"
        if bootMs >= 0 then detail = detail + " boot=" + Str(bootMs) + "ms"
        HomeLoaderLogBoot(m.bootSpan, "ShowHomeLoader OFF", detail + " | " + HomeLoaderGateSnapshot())
        CwPerfMark(m.cwShimmerSpan, "loader OFF", detail)
        m.cwShimmerSpan = invalid
        if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
        if m.rowsForceHideTimer <> invalid then m.rowsForceHideTimer.control = "stop"
        BrowseHidePageLoader(m, m.pageBgRest, false)
        ApplyHomePageBackground()
    end if
end sub

sub ClearAuthAndGoLogin()
    ProfileSelectLogNode("HOME_AUTH_CLEAR", "session expired -> login", m.top)
    ClearStorage()
    if m.vm <> invalid then m.vm.callFunc("NavigateClearAndReplace", RouteLogin(), {})
end sub


sub RedirectToProfiles()
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteLoginProfile(), {})
end sub

' ── Key handling ─────────────────────────────────────────────────────────────

