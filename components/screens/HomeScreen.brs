sub init()
    m.logoLabel = m.top.findNode("logoLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.dataLabel = m.top.findNode("dataLabel")
    m.cardsContainer = m.top.findNode("cardsContainer")
    m.bootSpinner = m.top.findNode("bootSpinner")
    m.bootOverlay = m.top.findNode("bootOverlay")

    m.categories = []
    m.previewCards = []
    m.previewFocusIndex = 0
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

    m.cPrimary500 = TokenColor(tokens, "primary-500", "#0b75e0")
    m.cPrimary600 = TokenColor(tokens, "primary-600", "#0760bb")
    m.cPrimary700 = TokenColor(tokens, "primary-700", "#04478b")
    m.cNeutral50 = TokenColor(tokens, "neutral-50", "#f8f1f7")
    m.cNeutral400 = TokenColor(tokens, "neutral-400", "#9ea4b0")
    m.cNeutral700 = TokenColor(tokens, "neutral-700", "#404040")
    m.cNeutral800 = TokenColor(tokens, "neutral-800", "#262626")
    m.cNeutral950 = TokenColor(tokens, "neutral-900", "#0a0a0a")

    m.logoLabel.color = m.cPrimary500
    m.statusLabel.color = m.cNeutral400
    m.dataLabel.color = m.cNeutral50
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
    if m.dataLabel <> invalid then
        m.dataLabel.text = BuildCategoryDebugText(m.categories, m.homeLayout, m.showUpdate)
        m.dataLabel.visible = true
    end if
    if m.statusLabel <> invalid then
        m.statusLabel.text = "Home data loaded — use ← → to focus cards, OK for next page"
        m.statusLabel.visible = true
    end if
    BuildCardPreview()
end sub

' ── Card preview (home-cards phase — one sample per row type) ────────────────

sub BuildCardPreview()
    if m.cardsContainer = invalid then return
    ClearCardPreview()

    x = 0
    gap = HC_CardGap()
    seeAllOrientation = HC_CardTypeVertical()
    maxRows = 6
    built = 0

    for i = 0 to m.categories.Count() - 1
        if built >= maxRows then exit for
        cat = m.categories[i]
        if cat = invalid then continue for
        items = cat.result
        if items = invalid or items.Count() = 0 then continue for

        rowType = ""
        if cat.type <> invalid then rowType = cat.type
        cardType = HC_CardTypeVertical()
        if cat.cardType <> invalid and cat.cardType <> "" then cardType = cat.cardType

        compName = CardComponentForRow(rowType, cardType)
        if compName = "BannerCard" then continue for

        item = items[0]
        card = m.cardsContainer.createChild(compName)
        ConfigurePreviewCard(card, compName, item, cardType, 0)
        card.translation = [x, 0]
        m.previewCards.Push(card)
        x = x + PreviewCardWidth(compName) + gap
        built = built + 1

        if cardType = HC_CardTypeHorizontal() then seeAllOrientation = HC_CardTypeHorizontal()
    end for

    seeAll = m.cardsContainer.createChild("SeeAllCard")
    seeAll.orientation = seeAllOrientation
    CardInjectTheme(seeAll, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800)
    seeAll.translation = [x, 0]
    m.previewCards.Push(seeAll)
    x = x + PreviewCardWidth("SeeAllCard", seeAllOrientation) + gap

    m.previewFocusIndex = 0
    ApplyCardPreviewFocus()
    m.cardsContainer.visible = (m.previewCards.Count() > 0)
end sub

sub ClearCardPreview()
    m.previewCards = []
    if m.cardsContainer = invalid then return
    count = m.cardsContainer.getChildCount()
    for i = count - 1 to 0 step -1
        m.cardsContainer.removeChildIndex(i)
    end for
end sub

sub ConfigurePreviewCard(card as object, compName as string, item as object, cardType as string, rank as integer)
    CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800)
    card.focusedState = false

    if compName = "ContinueWatchCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
        card.progress = GetContinueProgressPercent(item)
        if card.hasField("cNeutral950") then card.cNeutral950 = m.cNeutral950
        if card.hasField("cNeutral700") then card.cNeutral700 = m.cNeutral700
    else if compName = "NumberedVerticalCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeVertical(), item.thumbnails)
        card.rank = rank
    else if compName = "HorizontalCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
    else if compName = "VerticalCard" then
        card.thumbnailUri = GetCardImgByType(cardType, item.thumbnails)
    end if
end sub

function PreviewCardWidth(compName as string, orientation = "" as string) as integer
    if compName = "HorizontalCard" then return 556
    if compName = "ContinueWatchCard" then return 556
    if compName = "NumberedVerticalCard" then return 422
    if compName = "VerticalCard" then return 256
    if compName = "SeeAllCard" then
        if orientation = HC_CardTypeHorizontal() then return 546
        return 246
    end if
    return 256
end function

sub ApplyCardPreviewFocus()
    for i = 0 to m.previewCards.Count() - 1
        card = m.previewCards[i]
        if card <> invalid and card.hasField("focusedState") then
            card.focusedState = (i = m.previewFocusIndex)
        end if
    end for
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
    if key = "left" then
        if m.previewFocusIndex > 0 then
            m.previewFocusIndex = m.previewFocusIndex - 1
            ApplyCardPreviewFocus()
        end if
    else if key = "right" then
        if m.previewFocusIndex < m.previewCards.Count() - 1 then
            m.previewFocusIndex = m.previewFocusIndex + 1
            ApplyCardPreviewFocus()
        end if
    else if key = "OK" or key = "ok" then
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
