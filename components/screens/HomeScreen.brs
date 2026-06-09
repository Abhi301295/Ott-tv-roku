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

    m.focusZone = "rows"
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

    m.vm = FindViewManager(m.top)

    LoadThemeTokens()
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    m.top.observeField("keyEvent", "OnKey")

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

    if GetProfileId() = "" then
        RedirectToProfiles()
        return
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
    else
        ExitHeaderToRows()
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
        ExitHeaderToRows()
        return
    end if

    if m.vm <> invalid then
        m.vm.callFunc("NavigateReplace", item.route, { type: item.type, selectedID: item.text })
    end if
end sub

' ── Boot sequence (parity with features/home/index.tsx) ──────────────────────

sub StartBootSequence()
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
    path = Endpoints().HOME.CATEGORY_LIST
    m.categoryTask = ApiGetQuery(path, HomeCategoryQuery(pageNum))
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
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
            m.hasMore = true
        else
            m.hasMore = false
        end if
    else
        print "[HOME] home categories response failed/empty"
        m.hasMore = false
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    m.initialLoading = false
    ' Categories (and thus the hero banner) are ready — render the hero NOW, independent
    ' of Continue Watching. Rows still wait for CW so its shimmer can keep showing.
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
    m.rowsBuilt = true
    print "[HOME] MaybeBuildRows -> build rows (shimmer stays until first row paints)"
    ' Rows build progressively; the rows shimmer is dropped in OnRowBuildTick once the
    ' first real row exists, so the shimmer hands straight off to content (no black gap).
    BuildContentRows()
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

' Safety net: never let the hero shimmer outlive the poster wait.
sub OnSkeletonTimeout()
    print "[HOME] hero skeleton timeout -> hide hero shimmer"
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
    row.categoryData = cat
    row.translation = [0, m.rowBuildY]
    m.rowWidgets.Push(row)
    rowMs = span.TotalMilliseconds()
    if m.rowBuildCostMs = invalid then m.rowBuildCostMs = 0
    m.rowBuildCostMs = m.rowBuildCostMs + rowMs
    print "[PERF] build row "; m.rowBuildIndex; " '"; catName; "' cards="; row.cardCount; " "; rowMs; "ms"

    ' Keep the rows shimmer up until the FIRST row (Continue Watching) is fully populated,
    ' then hand off to a row that appears all at once (no one-by-one card stacking).
    if m.rowBuildIndex = 0 then row.observeField("built", "OnFirstRowBuilt")

    m.rowBuildY = m.rowBuildY + HC_RowPitch()
    m.rowBuildIndex = m.rowBuildIndex + 1

    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
        wall = 0
        if m.rowBuildSpan <> invalid then wall = m.rowBuildSpan.TotalMilliseconds()
        print "[PERF] all rows built: "; m.rowBuildIndex; " rows, render-cost="; m.rowBuildCostMs; "ms, wall="; wall; "ms"
    end if

    ApplyHomeFocus()
end sub

' The Continue Watching row finished populating — drop the shimmer so the shimmer hands
' straight off to a fully-built row (cards reveal together, never one at a time).
sub OnFirstRowBuilt()
    print "[HOME] first row built -> hide rows shimmer + reveal hero behind cards"
    ShowRowsSkeleton(false)
    ' CW content has painted — drop the dark scrim so the hero bleeds behind the cards.
    m.rowsRevealed = true
    UpdateRowsScrim()
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

    anchorY = HC_NetflixAnchorY() - (m.rowIndex * HC_RowPitch())
    AnimateRowsHost(anchorY)

    for i = 0 to m.rowWidgets.Count() - 1
        row = m.rowWidgets[i]
        if row = invalid then continue for
        row.rowFocused = (i = m.rowIndex)
        row.rowDimmed = (i > m.rowIndex)
        if i = m.rowIndex then
            ClampCardIndex()
            row.cardFocusIndex = m.cardIndex
        end if
    end for

    UpdateRowsScrim()
end sub

' The dark content backdrop only blocks the hero while the rows are loading or the user
' has scrolled past the first row. Once Continue Watching has painted and we're back at
' the top row, it goes transparent so the hero poster/trailer bleeds behind the cards
' (parity with the React layout where the hero shows through under the first row).
sub UpdateRowsScrim()
    transparent = m.rowsRevealed and (m.rowIndex <= 0)
    op = 1.0
    if transparent then op = 0.0
    if m.rowsScrim <> invalid then m.rowsScrim.opacity = op
    if m.rowsScrimGrad <> invalid then m.rowsScrimGrad.opacity = op
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
    if AnyBootLoading() then return

    key = ev.key
    print "[KEYDBG] OnKey key='"; key; "' zone='"; m.focusZone; "' heroFocus='"; m.heroFocus; "'"

    if m.focusZone = "header" then
        HandleHeaderKey(key)
        return
    end if

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

    prevCount = m.rowWidgets.Count()
    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
            m.hasMore = true
            UpdateHeroBanner()
            BuildContentRows()
            if m.rowIndex < prevCount then
                m.rowIndex = prevCount
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
