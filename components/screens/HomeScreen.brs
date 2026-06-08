sub init()
    m.hero = m.top.findNode("hero")
    m.header = m.top.findNode("homeHeader")
    m.rowsHost = m.top.findNode("rowsHost")
    m.homeSkeleton = m.top.findNode("homeSkeleton")

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

    m.vm = FindViewManager(m.top)

    LoadThemeTokens()
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    m.top.observeField("keyEvent", "OnKey")

    SetupHeader()

    if GetProfileId() = "" then
        RedirectToProfiles()
        return
    end if

    ShowSkeleton(true)
    StartBootSequence()
end sub

' ── Theme ────────────────────────────────────────────────────────────────────

sub LoadThemeTokens()
    tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens

    m.cPrimary500 = TokenColor(tokens, "primary-500", "#0b75e0")
    m.cPrimary600 = TokenColor(tokens, "primary-600", "#0760bb")
    m.cPrimary700 = TokenColor(tokens, "primary-700", "#04478b")
    m.cNeutral50 = TokenColor(tokens, "neutral-50", "#f8f1f7")
    m.cNeutral200 = TokenColor(tokens, "neutral-200", "#d4d4d4")
    m.cNeutral700 = TokenColor(tokens, "neutral-700", "#404040")
    m.cNeutral800 = TokenColor(tokens, "neutral-800", "#262626")
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
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return
    if resolved.brandingLogo <> invalid then m.header.logoUri = resolved.brandingLogo
    if resolved.appName <> invalid then m.header.appName = resolved.appName
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
        ExitHeaderToRows()
    else if key = "OK" or key = "ok" then
        SelectHeaderItem()
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
        if listing.Count() > 0 then
            tagged = TagContinueWatchingRows(listing)
            m.categories = PrependCategories(m.categories, tagged)
        end if
    else if api.message <> invalid and api.message <> "" then
        ShowAlert(m.top, 2, api.message)
    end if

    m.continueLoading = false
    TryFinishBoot()
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
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
            m.hasMore = true
        else
            m.hasMore = false
        end if
    else
        m.hasMore = false
        if api.message <> invalid and api.message <> "" then
            ShowAlert(m.top, 2, api.message)
        end if
    end if

    m.initialLoading = false
    TryFinishBoot()
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
    TryFinishBoot()
end sub

' The update check runs in parallel and never gates first paint (parity with
' index.tsx, where checkVersion does not block isInitialLoading).
function AnyBootLoading() as boolean
    return m.initialLoading or m.continueLoading
end function

sub TryFinishBoot()
    if AnyBootLoading() then return
    UpdateHeroBanner()
    BuildContentRows()
end sub

sub ShowSkeleton(show as boolean)
    if m.homeSkeleton = invalid then return
    m.homeSkeleton.boxColor = m.cNeutral800
    m.homeSkeleton.visible = show
    m.homeSkeleton.running = show
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

    if m.contentRowCats.Count() > 0 then
        m.rowBuildTimer.control = "start"
    else
        ShowSkeleton(false)
    end if
end sub

sub OnRowBuildTick()
    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
        return
    end if

    cat = m.contentRowCats[m.rowBuildIndex]
    row = m.rowsHost.createChild("ContentRow")
    ApplyThemeToRow(row)
    row.categoryData = cat
    row.translation = [0, m.rowBuildY]
    m.rowWidgets.Push(row)

    m.rowBuildY = m.rowBuildY + HC_RowPitch()
    m.rowBuildIndex = m.rowBuildIndex + 1

    ' First real row is on screen — drop the loading scaffold.
    if m.rowBuildIndex = 1 then ShowSkeleton(false)

    if m.rowBuildIndex >= m.contentRowCats.Count() then
        m.rowBuildTimer.control = "stop"
    end if

    ApplyHomeFocus()
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
    m.rowsHost.translation = [0, anchorY]

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

    if m.focusZone = "header" then
        HandleHeaderKey(key)
        return
    end if

    if m.rowWidgets.Count() = 0 then
        if key = "up" then EnterHeader()
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
            EnterHeader()
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
        ' Card navigation lands in feature/home-nav.
    end if
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
