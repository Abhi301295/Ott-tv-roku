sub init()
    m.logoLabel = m.top.findNode("logoLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.dataLabel = m.top.findNode("dataLabel")
    m.bootSpinner = m.top.findNode("bootSpinner")
    m.bootOverlay = m.top.findNode("bootOverlay")

    m.categories = []
    m.page = HC_HomePageStart()
    m.hasMore = true
    m.homeLayout = HomeLayoutMode()
    m.showUpdate = false

    m.initialLoading = true
    m.continueLoading = true
    m.versionLoading = true

    m.vm = FindViewManager(m.top)

    ApplyColors()
    ApplyBranding()
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    m.top.observeField("keyEvent", "OnKey")

    if GetProfileId() = "" then
        RedirectToProfiles()
        return
    end if

    ShowBootSpinner(true)
    StartBootSequence()
end sub

' ── Theme ────────────────────────────────────────────────────────────────────

sub ApplyColors()
    tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens

    cPrimary500 = TokenColor(tokens, "primary-500", "#0b75e0")
    cNeutral50 = TokenColor(tokens, "neutral-50", "#f8f1f7")
    cNeutral400 = TokenColor(tokens, "neutral-400", "#9ea4b0")

    m.logoLabel.color = cPrimary500
    m.statusLabel.color = cNeutral400
    m.dataLabel.color = cNeutral50
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
    ApplyColors()
    ApplyBranding()
end sub

sub ApplyBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return
    if resolved.appName <> invalid and resolved.appName <> "" then
        m.logoLabel.text = resolved.appName
    end if
end sub

' ── Boot sequence (parity with features/home/index.tsx) ──────────────────────

sub StartBootSequence()
    FetchProfilesBootstrap()
    FetchContinueWatching()
    FetchLatestVersion()
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
    FetchHomeCategories(m.page)
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

function AnyBootLoading() as boolean
    return m.initialLoading or m.continueLoading or m.versionLoading
end function

sub TryFinishBoot()
    if AnyBootLoading() then return
    ShowBootSpinner(false)
    RenderBootData()
end sub

sub ShowBootSpinner(show as boolean)
    if m.bootOverlay <> invalid then m.bootOverlay.visible = show
    if m.bootSpinner <> invalid then m.bootSpinner.visible = show
end sub

sub RenderBootData()
    if m.dataLabel = invalid then return
    m.dataLabel.text = BuildCategoryDebugText(m.categories, m.homeLayout, m.showUpdate)
    m.dataLabel.visible = true
    if m.statusLabel <> invalid then
        m.statusLabel.text = "Home data loaded"
        m.statusLabel.visible = true
    end if
end sub

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
    if key = "OK" or key = "ok" then
        if m.hasMore and not AnyBootLoading() then LoadMoreCategories()
    end if
end sub

sub LoadMoreCategories()
    if not m.hasMore then return
    m.page = m.page + 1
    m.statusLabel.text = "Loading page " + Str(m.page) + "..."
    path = Endpoints().HOME.CATEGORY_LIST
    m.loadMoreTask = ApiGetQuery(path, HomeCategoryQuery(m.page))
    m.loadMoreTask.observeField("apiResult", "OnLoadMoreResponse")
    StartHttpTask(m.loadMoreTask)
end sub

sub OnLoadMoreResponse()
    if m.loadMoreTask = invalid then return
    api = m.loadMoreTask.apiResult
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
    end if
    RenderBootData()
end sub
