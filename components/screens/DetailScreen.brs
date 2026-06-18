sub init()
    m.banner = m.top.findNode("banner")
    m.gradLeft = m.top.findNode("gradLeft")
    m.gradBottom = m.top.findNode("gradBottom")
    m.skeletonGroup = m.top.findNode("skeletonGroup")
    m.contentHost = m.top.findNode("contentHost")
    m.titleLabel = m.top.findNode("titleLabel")
    m.ratingHost = m.top.findNode("ratingHost")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.watchNowBtn = m.top.findNode("watchNowBtn")
    m.moreEpisodesBtn = m.top.findNode("moreEpisodesBtn")
    m.watchlistBtn = m.top.findNode("watchlistBtn")
    m.moreLikeBtn = m.top.findNode("moreLikeBtn")
    m.trailerBtn = m.top.findNode("trailerBtn")
    m.moreLikeOverlay = m.top.findNode("moreLikeOverlay")
    m.moreLikeScrim = m.top.findNode("moreLikeScrim")
    m.moreLikeDrawer = m.top.findNode("moreLikeDrawer")
    m.moreLikeCardsHost = m.top.findNode("moreLikeCardsHost")
    m.moreLikeSkeletonHost = m.top.findNode("moreLikeSkeletonHost")
    m.moreLikeCloseHost = m.top.findNode("moreLikeCloseHost")
    m.moreLikeClose = m.top.findNode("moreLikeClose")
    m.moreLikeScrimIn = m.top.findNode("moreLikeScrimIn")
    m.moreLikeDrawerIn = m.top.findNode("moreLikeDrawerIn")

    m.contentId = ""
    m.contentType = ""
    m.content = invalid
    m.isWatchlisted = false
    m.moreLikeVideos = []
    m.moreLikeCards = []
    m.moreLikeIndex = 0
    m.moreLikeOpen = false
    m.moreLikeFocusZone = "cards"
    m.moreLikeCloseFrame = invalid
    m.actionIndex = 0
    m.actionIds = []
    m.loading = true
    m.watchlistBusy = false

    m.vm = FindViewManager(m.top)
    LoadDetailTokens()
    SetupActionButtons()
    ApplyContentColors()
    ApplySkeletonColors()

    m.top.observeField("keyEvent", "OnKey")
    if m.vm <> invalid then m.vm.observeField("overlayDismiss", "OnOverlayDismiss")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    ShowLoading(true)
end sub

sub OnNavStateReady()
    state = m.top.navState
    if state = invalid then return
    if state.id <> invalid then m.contentId = state.id
    if state.type <> invalid then m.contentType = state.type
    if m.contentId = "" or m.contentType = "" then return
    FetchDetail()
end sub

sub OnDispose()
    if not m.top.dispose then return
    CloseMoreLike(false)
    KillDetailTask(m.detailTask)
    KillDetailTask(m.moreLikeTask)
    KillDetailTask(m.watchlistTask)
    KillDetailTask(m.watchlistMutTask)
    m.detailTask = invalid
    m.moreLikeTask = invalid
    m.watchlistTask = invalid
    m.watchlistMutTask = invalid
    if m.vm <> invalid then m.vm.unobserveField("overlayDismiss")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
    StopDetailSkeletons()
end sub

sub KillDetailTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

sub StopDetailSkeletons()
    if m.skeletonGroup = invalid then return
    for each sk in m.skeletonGroup.getChildren(-1, 0)
        if sk <> invalid and sk.hasField("running") then sk.running = false
    end for
    if m.moreLikeSkeletonHost = invalid then return
    for each sk in m.moreLikeSkeletonHost.getChildren(-1, 0)
        if sk <> invalid and sk.hasField("running") then sk.running = false
    end for
end sub

sub OnBusinessResolved()
    LoadDetailTokens()
    ApplyButtonThemes()
    ApplyContentColors()
    ApplySkeletonColors()
    ApplyMoreLikeSkeletonColors()
    ApplyActionFocus()
    ApplyMoreLikeCardFocus()
end sub

sub LoadDetailTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens
    m.cPrimary500 = TC("primary-500", "#0b75e0")
    m.cPrimary600 = TC("primary-600", "#0760bb")
    m.cPrimary700 = TC("primary-700", "#04478b")
    m.cNeutral50 = TC("neutral-50", "#f5f5f5")
    m.cNeutral300 = TC("neutral-300", "#adadad")
    m.cNeutral700 = TC("neutral-700", "#404040")
    ' React hardcodes the focused action glow as shadow-[0_0_8px_#1e90ff] (not a theme token).
    m.cGlow = "0x1e90ffff"
end sub

function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

sub SetupActionButtons()
    m.btnMap = {
        watchNow: m.watchNowBtn
        moreEpisodes: m.moreEpisodesBtn
        watchlist: m.watchlistBtn
        moreLike: m.moreLikeBtn
        trailer: m.trailerBtn
    }
    ApplyButtonThemes()
end sub

sub ApplyButtonThemes()
    for each id in m.btnMap
        btn = m.btnMap[id]
        if btn <> invalid then
            btn.cPrimary500 = m.cPrimary500
            btn.cPrimary700 = m.cPrimary700
            btn.cNeutral700 = m.cNeutral700
            btn.cNeutral50 = m.cNeutral50
            btn.cGlow = m.cGlow
        end if
    end for
end sub

' Drive text colors from theme tokens (no hardcoded hex): neutral-50 for title/rating,
' neutral-300 for the meta + description, matching contentdetail/index.tsx.
sub ApplyContentColors()
    if m.titleLabel <> invalid then m.titleLabel.color = m.cNeutral50
    if m.ratingLabel <> invalid then m.ratingLabel.color = m.cNeutral50
    if m.metaLabel <> invalid then m.metaLabel.color = m.cNeutral300
    if m.descLabel <> invalid then m.descLabel.color = m.cNeutral300
end sub

' React's detail skeleton uses bg-neutral-700; in this brand that token resolves light,
' matching the (light) Watch Now button. Drive the placeholders from the same token so the
' shimmer is identical to React rather than a hardcoded grey.
sub ApplySkeletonColors()
    if m.skeletonGroup = invalid then return
    base = m.cNeutral700
    hi = CardLightenHex(base, 26)
    for each sk in m.skeletonGroup.getChildren(-1, 0)
        if sk <> invalid and sk.hasField("baseColor") then
            sk.baseColor = base
            sk.highlightColor = hi
        end if
    end for
end sub

function LightenHexColor(hex as string, amount as integer) as string
    return CardLightenHex(hex, amount)
end function

sub ShowLoading(show as boolean)
    m.loading = show
    m.skeletonGroup.visible = show
    m.contentHost.visible = not show
    m.banner.visible = not show
    m.gradLeft.visible = not show
    m.gradBottom.visible = not show
    if show then
        for each sk in m.skeletonGroup.getChildren(-1, 0)
            if sk <> invalid and sk.hasField("running") then sk.running = true
        end for
    else
        StopDetailSkeletons()
    end if
end sub

sub FetchDetail()
    ShowLoading(true)
    path = DetailContentPath(m.contentId, m.contentType)
    m.detailTask = ApiGet(path)
    m.detailTask.observeField("apiResult", "OnDetailResponse")
    StartHttpTask(m.detailTask)
end sub

sub OnDetailResponse()
    if m.top.dispose = true then return
    if m.detailTask = invalid then return
    m.detailTask.unobserveField("apiResult")
    api = m.detailTask.apiResult
    m.detailTask = invalid

    if api = invalid or api.statusCode = invalid or api.statusCode <> 200 then
        ShowAlert(m.top, 2, CopyDetailLoadFailed())
        ShowLoading(false)
        return
    end if

    raw = invalid
    if api.result <> invalid then raw = api.result
    if raw = invalid then
        ShowAlert(m.top, 2, CopyDetailLoadFailed())
        ShowLoading(false)
        return
    end if

    m.content = EnrichDetailContent(raw, m.contentType)
    ApplyDetailContent()
    ShowLoading(false)
    RebuildActionList()
    m.actionIndex = 0
    ApplyActionFocus()
end sub

sub ApplyDetailContent()
    content = m.content
    if content = invalid then return

    uri = DetailBannerUri(content)
    if uri <> "" then m.banner.uri = uri

    title = ""
    if content.title <> invalid then title = content.title
    m.titleLabel.text = title

    desc = ""
    if content.description <> invalid then desc = content.description
    m.descLabel.text = desc

    m.metaLabel.text = DetailMetaLine(content)
    BuildRatingStars(content)
    m.isWatchlisted = content.isWatchlisted = true

    m.watchNowBtn.label = DetailWatchNowLabel(content)
    m.moreEpisodesBtn.visible = DetailShowMoreEpisodesButton(content)
    m.trailerBtn.visible = DetailShowTrailerButton(content)
    UpdateWatchlistLabel()
end sub

sub BuildRatingStars(content as object)
    for i = m.ratingHost.getChildCount() - 1 to 1 step -1
        m.ratingHost.removeChildIndex(i)
    end for

    imdb = invalid
    if content <> invalid and content.imdb <> invalid then imdb = content.imdb
    if imdb = invalid or FormatHeroRating(imdb) = "" then
        m.ratingHost.visible = false
        return
    end if

    ' Star math mirrors detail/index.tsx getContentData EXACTLY (no /2 normalization):
    ' full = floor(imdb), half = 1 when the fractional part is .5, blank fills up to 5.
    m.ratingLabel.text = FormatDetailRating(imdb)
    v = ImdbValue(imdb)
    full = Int(v)
    half = 0
    if Abs((v - full) - 0.5) < 0.001 then half = 1
    blank = 5 - (full + half)
    if blank < 0 then blank = 0

    ' Number is ~44px wide + 10px margin-right (m-r-10); stars follow with ~25px pitch (justify-evenly).
    blankColor = "0x31383Aff"
    x = 54
    pitch = 25
    for i = 1 to full
        AppendDetailStar("full", blankColor, x)
        x = x + pitch
    end for
    if half = 1 then
        AppendDetailStar("half", blankColor, x)
        x = x + pitch
    end if
    for i = 1 to blank
        AppendDetailStar("blank", blankColor, x)
        x = x + pitch
    end for
    m.ratingHost.visible = true
end sub

sub AppendDetailStar(kind as string, blankColor as string, x as integer)
    starUri = "pkg:/images/ui/star.png"
    sz = 20
    starY = 6
    if kind = "half" then
        g = m.ratingHost.createChild("Group")
        g.translation = [x, starY]
        base = g.createChild("Poster")
        base.uri = starUri
        base.width = sz
        base.height = sz
        base.blendColor = blankColor
        clip = g.createChild("Group")
        clip.clippingRect = [0, 0, sz / 2, sz]
        clip.clippingRectClipsChildren = true
        fill = clip.createChild("Poster")
        fill.uri = starUri
        fill.width = sz
        fill.height = sz
        fill.blendColor = m.cPrimary500
        return
    end if

    p = m.ratingHost.createChild("Poster")
    p.translation = [x, starY]
    p.uri = starUri
    p.width = sz
    p.height = sz
    if kind = "full" then
        p.blendColor = m.cPrimary500
    else
        p.blendColor = blankColor
    end if
end sub

sub RebuildActionList()
    ' Visual order: watchNow, moreEpisodes, watchlist, moreLike, trailer.
    m.actionIds = ["watchNow"]
    if DetailShowMoreEpisodesButton(m.content) then m.actionIds.Push("moreEpisodes")
    m.actionIds.Push("watchlist")
    m.actionIds.Push("moreLike")
    if DetailShowTrailerButton(m.content) then m.actionIds.Push("trailer")

    y = 0
    for each id in m.actionIds
        btn = m.btnMap[id]
        if btn <> invalid then
            btn.translation = [0, y]
            ' 76px button height + 16px gap (m-t-16) = 92px pitch.
            y = y + 92
        end if
    end for
end sub

sub ApplyActionFocus()
    if m.actionIds.Count() = 0 then return
    for each id in m.actionIds
        btn = m.btnMap[id]
        if btn = invalid then continue for
        btn.focusedState = (id = m.actionIds[m.actionIndex])
    end for
end sub

sub ClearActionFocus()
    for each id in m.actionIds
        btn = m.btnMap[id]
        if btn <> invalid then btn.focusedState = false
    end for
end sub

sub UpdateWatchlistLabel()
    if m.watchlistBtn = invalid then return
    if m.watchlistBusy then
        if m.isWatchlisted then
            m.watchlistBtn.label = CopyRemovingWatchlist()
        else
            m.watchlistBtn.label = CopyAddingWatchlist()
        end if
        return
    end if
    if m.isWatchlisted then
        m.watchlistBtn.label = CopyRemoveWatchlist()
    else
        m.watchlistBtn.label = CopyAddWatchlist()
    end if
end sub

' ── Keys ─────────────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.loading then return

    if m.moreLikeOpen then
        HandleMoreLikeKey(ev.key)
        return
    end if

    HandleActionsKey(ev.key)
end sub

sub HandleActionsKey(key as string)
    if m.actionIds.Count() = 0 then return
    if key = "up" then
        if m.actionIndex > 0 then m.actionIndex = m.actionIndex - 1
        ApplyActionFocus()
    else if key = "down" then
        if m.actionIndex < m.actionIds.Count() - 1 then m.actionIndex = m.actionIndex + 1
        ApplyActionFocus()
    else if key = "OK" or key = "ok" then
        if m.watchlistBusy then return
        id = m.actionIds[m.actionIndex]
        if id = "watchNow" then
            OnWatchNow(false)
        else if id = "moreEpisodes" then
            OnMoreEpisodes()
        else if id = "watchlist" then
            OnWatchlistToggle()
        else if id = "moreLike" then
            OnMoreLikeToggle()
        else if id = "trailer" then
            OnPlayTrailer()
        end if
    end if
end sub

sub HandleMoreLikeKey(key as string)
    if m.moreLikeFocusZone = "close" then
        if key = "down" then
            m.moreLikeFocusZone = "cards"
            ApplyMoreLikeCloseFocus()
            ApplyMoreLikeCardFocus()
        else if key = "OK" or key = "ok" then
            CloseMoreLike(true)
        else if key = "back" then
            CloseMoreLike(true)
        end if
        return
    end if

    if key = "up" then
        m.moreLikeFocusZone = "close"
        ApplyMoreLikeCloseFocus()
        ApplyMoreLikeCardFocus()
    else if key = "left" then
        if m.moreLikeIndex > 0 then m.moreLikeIndex = m.moreLikeIndex - 1
        ApplyMoreLikeCardFocus()
        ScrollMoreLikeToFocused()
    else if key = "right" then
        if m.moreLikeIndex < m.moreLikeCards.Count() - 1 then m.moreLikeIndex = m.moreLikeIndex + 1
        ApplyMoreLikeCardFocus()
        ScrollMoreLikeToFocused()
    else if key = "OK" or key = "ok" then
        if m.moreLikeCards.Count() > m.moreLikeIndex then
            item = m.moreLikeVideos[m.moreLikeIndex]
            if item <> invalid and item._id <> invalid then
                id = item._id
                tp = HM_TypeSingleVideo()
                if item.type <> invalid and item.type <> "" then tp = item.type
                CloseMoreLike(false)
                if m.vm <> invalid then
                    m.vm.callFunc("NavigateReplace", RouteDetail(), { id: id, type: tp })
                end if
            end if
        end if
    else if key = "back" then
        CloseMoreLike(true)
    end if
end sub

sub OnOverlayDismiss()
    if m.moreLikeOpen then CloseMoreLike(true)
end sub

' ── Actions ──────────────────────────────────────────────────────────────────

sub OnWatchNow(startOver as boolean)
    if m.content = invalid or m.vm = invalid then return
    state = DetailPlayEpisode(m.content, startOver)
    if state = invalid then return
    m.vm.callFunc("NavigatePush", RouteVideoPlayer(), state)
end sub

sub OnMoreEpisodes()
    if m.content = invalid or m.vm = invalid then return
    m.vm.callFunc("NavigatePush", RouteSeriesEpisodes(), {
        id: m.contentId
        type: m.contentType
        contentList: m.content.seasons
        detail: m.content
    })
end sub

sub OnPlayTrailer()
    if m.content = invalid or m.vm = invalid then return
    state = DetailTrailerPayload(m.content)
    if state = invalid then return
    m.vm.callFunc("NavigatePush", RouteVideoPlayer(), state)
end sub

sub OnWatchlistToggle()
    if m.watchlistBusy or m.contentId = "" then return
    m.watchlistBusy = true
    UpdateWatchlistLabel()
    path = Endpoints().DETAIL.WATCH_LIST
    m.watchlistTask = ApiGetQuery(path, { content: m.contentId })
    m.watchlistTask.observeField("apiResult", "OnWatchlistFoldersResponse")
    StartHttpTask(m.watchlistTask)
end sub

sub OnWatchlistFoldersResponse()
    if m.top.dispose = true then return
    if m.watchlistTask = invalid then return
    m.watchlistTask.unobserveField("apiResult")
    api = m.watchlistTask.apiResult
    m.watchlistTask = invalid

    if api = invalid or api.ok <> true then
        m.watchlistBusy = false
        UpdateWatchlistLabel()
        ShowAlert(m.top, 2, CopyDetailLoadFailed())
        return
    end if

    folders = []
    if api <> invalid and api.result <> invalid and api.result.data <> invalid then
        folders = api.result.data
    end if

    if folders.Count() = 0 then
        m.watchlistBusy = false
        UpdateWatchlistLabel()
        ShowAlert(m.top, 2, "No watchlist folder found")
        return
    end if

    folder = folders[0]
    for each f in folders
        if f <> invalid and f.isDefault = true then
            folder = f
            exit for
        end if
    end for

    if folder = invalid or folder._id = invalid then
        m.watchlistBusy = false
        UpdateWatchlistLabel()
        return
    end if

    if folder.isChecked = true or m.isWatchlisted = true then
        path = Endpoints().DETAIL.REMOVE_FROM_WATCH_LIST + folder._id + "/content"
        m.watchlistMutTask = ApiDelete(path, { content: m.contentId })
    else
        path = Endpoints().DETAIL.SAVE_WATCH_LIST
        m.watchlistMutTask = ApiPost(path, { folders: [folder._id], content: m.contentId })
    end if
    m.watchlistMutTask.observeField("apiResult", "OnWatchlistMutResponse")
    StartHttpTask(m.watchlistMutTask)
end sub

sub OnWatchlistMutResponse()
    if m.top.dispose = true then return
    if m.watchlistMutTask = invalid then return
    m.watchlistMutTask.unobserveField("apiResult")
    api = m.watchlistMutTask.apiResult
    m.watchlistMutTask = invalid
    m.watchlistBusy = false

    if api = invalid or api.ok <> true then
        UpdateWatchlistLabel()
        ShowAlert(m.top, 2, CopyDetailLoadFailed())
        return
    end if

    m.isWatchlisted = not m.isWatchlisted
    UpdateWatchlistLabel()
    if m.isWatchlisted then
        ShowAlert(m.top, 1, CopyAddedToWatchlist())
    else
        ShowAlert(m.top, 1, CopyRemovedFromWatchlist())
    end if
    ApplyActionFocus()
end sub

sub OnMoreLikeToggle()
    if m.moreLikeOpen then
        CloseMoreLike(true)
        return
    end if
    OpenMoreLike()
end sub

sub OpenMoreLike()
    if m.content = invalid then return
    m.moreLikeOpen = true
    if m.vm <> invalid then m.vm.overlayOpen = true
    m.moreLikeOverlay.visible = true
    m.moreLikeIndex = 0
    m.moreLikeFocusZone = "cards"
    ClearActionFocus()
    PlayMoreLikeOpenAnim()

    if m.moreLikeVideos.Count() > 0 then
        m.moreLikeSkeletonHost.visible = false
        m.moreLikeCardsHost.visible = true
        BuildMoreLikeCards()
        ApplyMoreLikeCloseFocus()
        ApplyMoreLikeCardFocus()
        ScrollMoreLikeToFocused()
        return
    end if

    m.moreLikeCardsHost.visible = false
    m.moreLikeSkeletonHost.visible = true
    ApplyMoreLikeSkeletonColors()
    title = ""
    if m.content.title <> invalid then title = m.content.title
    path = Endpoints().DETAIL.RECOMENDED_VIDEOS
    m.moreLikeTask = ApiGetQuery(path, DetailRecommendQuery(title, m.contentId, 10))
    m.moreLikeTask.observeField("apiResult", "OnMoreLikeResponse")
    StartHttpTask(m.moreLikeTask)
end sub

sub PlayMoreLikeOpenAnim()
    if m.moreLikeDrawer <> invalid then m.moreLikeDrawer.translation = [0, 1080]
    if m.moreLikeScrim <> invalid then m.moreLikeScrim.opacity = 0
    if m.moreLikeScrimIn <> invalid then
        m.moreLikeScrimIn.control = "stop"
        m.moreLikeScrimIn.control = "start"
    end if
    if m.moreLikeDrawerIn <> invalid then
        m.moreLikeDrawerIn.control = "stop"
        m.moreLikeDrawerIn.control = "start"
    end if
end sub

sub ApplyMoreLikeSkeletonColors()
    if m.moreLikeSkeletonHost = invalid then return
    base = m.cNeutral700
    hi = CardLightenHex(base, 26)
    CardApplySkeletonTree(m.moreLikeSkeletonHost, base, hi, true)
end sub

sub OnMoreLikeResponse()
    if m.top.dispose = true then return
    if m.moreLikeTask = invalid then return
    m.moreLikeTask.unobserveField("apiResult")
    api = m.moreLikeTask.apiResult
    m.moreLikeTask = invalid

    items = []
    if api <> invalid and api.result <> invalid and api.result.data <> invalid then
        items = api.result.data
    end if
    m.moreLikeVideos = items
    m.moreLikeSkeletonHost.visible = false
    m.moreLikeCardsHost.visible = true
    for each sk in m.moreLikeSkeletonHost.getChildren(-1, 0)
        if sk <> invalid and sk.hasField("running") then sk.running = false
    end for
    BuildMoreLikeCards()
    ApplyMoreLikeCloseFocus()
    ApplyMoreLikeCardFocus()
    ScrollMoreLikeToFocused()
end sub

sub BuildMoreLikeCards()
    ClearMoreLikeCards()
    x = 0
    gap = HC_CardGap()
    cardW = BS_ListCardW()
    pitch = BS_ListCardPitch()
    for i = 0 to m.moreLikeVideos.Count() - 1
        item = m.moreLikeVideos[i]
        if item = invalid then continue for
        card = m.moreLikeCardsHost.createChild("VerticalCard")
        card.translation = [x, 0]
        card.listType = true
        card.cPrimary500 = m.cPrimary500
        card.cPrimary700 = m.cPrimary700
        card.cNeutral700 = m.cNeutral700
        card.cNeutral800 = m.cNeutral800
        uri = ""
        if item.thumbnails <> invalid then
            ' Parity SeriesCard — horizontal art in 272×340 with object-cover (scaleToZoom).
            uri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
        end if
        card.thumbnailUri = uri
        m.moreLikeCards.Push(card)
        x = x + pitch
    end for
end sub

sub ClearMoreLikeCards()
    m.moreLikeCards = []
    if m.moreLikeCardsHost = invalid then return
    for i = m.moreLikeCardsHost.getChildCount() - 1 to 0 step -1
        m.moreLikeCardsHost.removeChildIndex(i)
    end for
end sub

sub ApplyMoreLikeCardFocus()
    for i = 0 to m.moreLikeCards.Count() - 1
        card = m.moreLikeCards[i]
        if card <> invalid then
            card.focusedState = (m.moreLikeFocusZone = "cards" and i = m.moreLikeIndex)
        end if
    end for
end sub

sub ApplyMoreLikeCloseFocus()
    if m.moreLikeClose = invalid then return
    focused = (m.moreLikeFocusZone = "close")
    if focused then
        m.moreLikeClose.color = m.cPrimary500
    else
        m.moreLikeClose.color = "0xffffff99"
    end if
    if m.moreLikeCloseHost <> invalid then
        m.moreLikeCloseFrame = CardEnsureFocusFrame(m.moreLikeCloseHost, m.moreLikeCloseFrame, -4, -4, 72, 72, m.cPrimary500)
        CardApplyFocusBorder(m.moreLikeCloseFrame, focused, m.cPrimary500)
    end if
end sub

' Keep the focused card in view without over-scrolling — same clamp as ContentRow.brs
' ScrollToFocusedCard so navigating right does not leave empty space on the right.
sub ScrollMoreLikeToFocused()
    if m.moreLikeCards.Count() = 0 then return
    if m.moreLikeCardsHost = invalid then return

    idx = m.moreLikeIndex
    if idx < 0 then idx = 0
    if idx >= m.moreLikeCards.Count() then idx = m.moreLikeCards.Count() - 1

    leftPad = 40
    cardW = BS_ListCardW()
    gap = HC_CardGap()
    pitch = cardW + gap
    viewportW = 1920 - leftPad - 64

    cardLeft = idx * pitch
    cardRight = cardLeft + cardW

    currentScroll = leftPad - m.moreLikeCardsHost.translation[0]
    if currentScroll < 0 then currentScroll = 0

    scrollX = currentScroll
    if cardLeft < scrollX then
        scrollX = cardLeft
    else if cardRight > scrollX + viewportW then
        scrollX = cardRight - viewportW
    end if

    n = m.moreLikeCards.Count()
    totalW = n * cardW + (n - 1) * gap
    maxScroll = totalW - viewportW
    if maxScroll < 0 then maxScroll = 0

    if scrollX < 0 then scrollX = 0
    if scrollX > maxScroll then scrollX = maxScroll

    m.moreLikeCardsHost.translation = [leftPad - scrollX, 612]
end sub

sub CloseMoreLike(refocus as boolean)
    if not m.moreLikeOpen then return
    KillDetailTask(m.moreLikeTask)
    m.moreLikeTask = invalid
    m.moreLikeOpen = false
    m.moreLikeFocusZone = "cards"
    if m.vm <> invalid then m.vm.overlayOpen = false
    m.moreLikeOverlay.visible = false
    m.moreLikeSkeletonHost.visible = false
    m.moreLikeCardsHost.visible = true
    if m.moreLikeDrawer <> invalid then m.moreLikeDrawer.translation = [0, 1080]
    if m.moreLikeScrim <> invalid then m.moreLikeScrim.opacity = 0
    if m.moreLikeScrimIn <> invalid then m.moreLikeScrimIn.control = "stop"
    if m.moreLikeDrawerIn <> invalid then m.moreLikeDrawerIn.control = "stop"
    for each sk in m.moreLikeSkeletonHost.getChildren(-1, 0)
        if sk <> invalid and sk.hasField("running") then sk.running = false
    end for
    if m.moreLikeCloseFrame <> invalid then
        CardApplyFocusBorder(m.moreLikeCloseFrame, false, m.cPrimary500)
    end if
    if refocus then ApplyActionFocus()
end sub
