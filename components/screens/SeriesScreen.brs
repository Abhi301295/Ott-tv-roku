' SeriesScreen.brs — parity with src/features/series/ (See All grid, 6 cards per row).

sub init()
    m.bg = m.top.findNode("bg")
    m.contentHost = m.top.findNode("contentHost")
    m.loaderHost = m.top.findNode("loaderHost")
    m.loaderPageBg = m.top.findNode("loaderPageBg")
    m.pageLoader = m.top.findNode("pageLoader")
    m.titleLabel = m.top.findNode("titleLabel")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.rowsHost = m.top.findNode("rowsHost")

    m.listType = ""
    m.categoryId = ""
    m.genreId = ""
    m.page = 0
    m.hasMore = true
    m.loading = false
    m.initialLoad = true
    m.contentRevealed = false
    m.thumbPaintWatch = invalid
    m.rows = []
    m.rowNodes = []
    m.rowIdx = 0
    m.colIdx = 0
    m.scrollY = 0
    m.rowScrollX = []

    m.rowBuildIdx = 0
    m.rowBuildTimer = CreateObject("roSGNode", "Timer")
    m.rowBuildTimer.duration = 0.02
    m.rowBuildTimer.repeat = true
    m.top.appendChild(m.rowBuildTimer)
    m.rowBuildTimer.observeField("fire", "OnSeriesRowBuildTick")

    m.vScrollAnim = m.top.findNode("vScrollAnim")
    m.vScrollInterp = m.top.findNode("vScrollInterp")
    m.hScrollAnim = m.top.findNode("hScrollAnim")
    m.hScrollInterp = m.top.findNode("hScrollInterp")

    m.vm = FindViewManager(m.top)
    LoadBrowseTokens()
    ApplyStaticColors()

    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
    state = m.top.navState
    BrowseDbgState("series_nav", state)
    if state = invalid then
        BrowseDbg("series_nav", "abort: navState invalid")
        return
    end if
    if state.type <> invalid then m.listType = state.type
    if state.categoryId <> invalid then m.categoryId = state.categoryId
    if state.genere_id <> invalid then m.genreId = state.genere_id
    if state.genere_title <> invalid and state.genere_title <> "" then
        m.titleLabel.text = state.genere_title
    else if state.selectedID <> invalid and state.selectedID <> "" then
        m.titleLabel.text = state.selectedID
    else if state.title <> invalid then
        m.titleLabel.text = state.title
    else if m.listType = "SERIES_AND_EPISODES" then
        m.titleLabel.text = "Series"
    else if m.listType = "SINGLE_VIDEO" then
        m.titleLabel.text = "Movies"
    end if
    BrowseDbg("series_nav", "listType=" + m.listType + " categoryId=" + m.categoryId + " genreId=" + m.genreId + " title=" + m.titleLabel.text)
    if m.listType = "" then
        BrowseDbg("series_nav", "abort: listType empty — no fetch")
        return
    end if
    ResetAndFetch()
end sub

sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    if m.rows.Count() = 0 or SeriesEmptyVisible() then return
    m.rowIdx = 0
    m.colIdx = 0
    ApplyFocus()
    BrowseDbg("series_focus", "shell_enter_content row=0 col=0")
end sub

sub OnDispose()
    if not m.top.dispose then return
    DetachSeriesPaintWatch()
    BrowseDisarmLoaderTimeout(m)
    StopSeriesGridBuild()
    KillListTask(m.listTask)
    m.listTask = invalid
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
end sub

sub KillListTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

sub OnBusinessResolved()
    LoadBrowseTokens()
    ApplyStaticColors()
    RefreshCardThemes()
    if BrowsePageLoaderRunning(m) then
        BrowseApplyPageLoaderColors(m)
        BrowseApplyLoaderVeil(m, true, m.pageBgRest)
    end if
end sub

sub LoadBrowseTokens()
    ThemeApplyBrowsePalette(m, m.top)
end sub

sub ApplyStaticColors()
    m.pageBgRest = SK_LoadingPageBg()
    if m.bg <> invalid then m.bg.color = m.pageBgRest
    if m.titleLabel <> invalid then m.titleLabel.color = m.cNeutral50
    if m.emptyLabel <> invalid then m.emptyLabel.color = m.cNeutral50
    ApplyPageLoaderColors()
end sub

sub ApplyPageLoaderColors()
    BrowseApplyPageLoaderColors(m)
end sub

sub ShowLoader(show as boolean)
    if show then
        BrowseShowPageLoader(m, m.pageBgRest)
    else
        BrowseDetachHostPaintWatch(m)
        BrowseHidePageLoader(m, m.pageBgRest)
    end if
end sub

sub OnBrowseLoaderTimeout()
    if m.contentRevealed then return
    BrowseDetachHostPaintWatch(m)
    RevealContent()
    if m.page = 1 then
        SeriesHandoffContentFocus()
    else
        ClampCol()
        ApplyFocus()
    end if
end sub

sub DetachSeriesPaintWatch()
    BrowseDetachHostPaintWatch(m)
end sub

sub AttachSeriesPaintWatch()
    if m.contentRevealed or m.page <> 1 then return
    if m.rowNodes.Count() = 0 then
        RevealContent()
        return
    end if
    entry = m.rowNodes[0]
    if entry = invalid or entry.cards = invalid or entry.cards.Count() = 0 then
        RevealContent()
        return
    end if
    card = entry.cards[0]
    if card = invalid then
        RevealContent()
        return
    end if
    thumb = card.findNode("thumb")
    if thumb = invalid then
        RevealContent()
        return
    end if
    if BrowseAttachThumbPaintWatch(m, thumb, "OnSeriesFirstPainted") then OnSeriesFirstPainted()
end sub

sub OnSeriesFirstPainted()
    if m.contentRevealed then return
    if not BrowsePageLoaderRunning(m) then return
    BrowseDetachHostPaintWatch(m)
    RevealContent()
    if m.page = 1 then
        SeriesHandoffContentFocus()
    else
        ClampCol()
        ApplyFocus()
    end if
end sub

sub RevealContent()
    if m.contentRevealed then return
    BrowseHidePageLoader(m, m.pageBgRest)
    m.contentRevealed = true
    BrowseDbg("series_reveal", "content visible title=" + m.titleLabel.text)
end sub

sub ResetAndFetch()
    StopSeriesGridBuild()
    m.page = 0
    m.hasMore = true
    m.initialLoad = true
    m.contentRevealed = false
    m.rows = []
    m.rowIdx = 0
    m.colIdx = 0
    m.scrollY = 0
    m.rowScrollX = []
    ClearRows()
    ShowEmpty(false)
    ShowLoader(true)
    FetchNextPage()
end sub

sub FetchNextPage()
    if m.loading then return
    if not m.hasMore then return
    m.page = m.page + 1
    m.loading = true
    if m.page = 1 then ShowLoader(true)
    path = Endpoints().SERIES.SERIES_LIST
    q = SL_BuildQuery(m.page, m.listType, m.categoryId, m.genreId)
    KillListTask(m.listTask)
    m.listTask = ApiGetQuery(path, q)
    m.listTask.observeField("apiResult", "OnListResponse")
    StartHttpTask(m.listTask)
end sub

sub OnListResponse()
    if m.top.dispose = true then return
    if m.listTask = invalid then return
    m.listTask.unobserveField("apiResult")
    api = m.listTask.apiResult
    m.listTask = invalid
    m.loading = false
    m.initialLoad = false

    BrowseDbgApi("series_response", api)
    if api = invalid or api.statusCode = invalid or api.statusCode <> 200 then
        msg = ""
        status = 0
        if api <> invalid then
            if api.message <> invalid then msg = api.message
            if api.statusCode <> invalid then status = api.statusCode
        end if
        BrowseDbg("series_response", "fail: bad status — show empty=" + BrowseDbgStr(m.rows.Count() = 0))
        m.hasMore = false
        ShowLoader(false)
        if m.rows.Count() = 0 then ShowEmpty(true)
        return
    end if

    listing = SL_ParseSeriesListing(api)

    if listing.Count() = 0 and m.rows.Count() = 0 then
        m.hasMore = false
        BrowseDbg("series_response", "empty listing — show empty state")
        ShowLoader(false)
        ShowEmpty(true)
        return
    end if

    ShowEmpty(false)
    m.rows = SL_AppendRows(m.rows, listing, BS_ItemsPerRow())
    m.hasMore = SL_PageHasMore(api, listing.Count(), SL_FlatItemCount(m.rows))
    BrowseDbg("series_response", "listingCount=" + Str(listing.Count()) + " hasMore=" + BrowseDbgStr(m.hasMore) + " loaded=" + Str(SL_FlatItemCount(m.rows)) + " page=" + Str(m.page))
    if m.page = 1 then
        StartSeriesGridBuild(true)
    else
        StartSeriesGridBuild(false)
    end if
end sub

sub ShowEmpty(show as boolean)
    BrowseDbg("series_empty", "visible=" + BrowseDbgStr(show))
    if show then ShowLoader(false)
    if m.emptyLabel <> invalid then m.emptyLabel.visible = show
    if m.rowsHost <> invalid then m.rowsHost.visible = not show
    if show then m.contentRevealed = false
end sub

sub ClearRows()
    if m.rowsHost = invalid then return
    m.rowsHost.removeChildrenIndex(m.rowsHost.getChildCount(), 0)
    m.rowNodes = []
end sub

sub StopSeriesGridBuild()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
end sub

function SeriesGridBuildIncomplete() as boolean
    if m.rows = invalid then return false
    return m.rowBuildIdx < m.rows.Count()
end function

' fresh=true clears nodes and rebuilds from row 0; false appends after the last built row.
sub StartSeriesGridBuild(fresh as boolean)
    StopSeriesGridBuild()
    if fresh then
        m.rowBuildIdx = 0
        ClearRows()
        m.rowScrollX = []
    else
        m.rowBuildIdx = m.rowNodes.Count()
    end if
    if m.rows = invalid or m.rows.Count() = 0 then return

    if fresh then
        syncMax = BS_SkeletonRows()
        if syncMax > m.rows.Count() then syncMax = m.rows.Count()
        for i = 0 to syncMax - 1
            row = m.rows[i]
            if row = invalid then continue for
            EnsureSeriesRow(i, row)
            m.rowBuildIdx = i + 1
        end for
        AttachSeriesPaintWatch()
        print "[SERIES_DBG] grid_sync rows="; syncMax; " total="; m.rows.Count()
    end if

    if m.rowBuildIdx >= m.rows.Count() then
        FinishSeriesGridBuild()
        return
    end if
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "start"
end sub

sub OnSeriesRowBuildTick()
    if m.top.dispose = true then
        StopSeriesGridBuild()
        return
    end if
    if m.rows = invalid or m.rows.Count() = 0 then
        StopSeriesGridBuild()
        return
    end if
    if m.rowBuildIdx >= m.rows.Count() then
        StopSeriesGridBuild()
        FinishSeriesGridBuild()
        return
    end if

    row = m.rows[m.rowBuildIdx]
    if row <> invalid then EnsureSeriesRow(m.rowBuildIdx, row)
    m.rowBuildIdx = m.rowBuildIdx + 1

    if m.rowBuildIdx >= m.rows.Count() then
        StopSeriesGridBuild()
        FinishSeriesGridBuild()
    end if
end sub

sub FinishSeriesGridBuild()
    ClampCol()
    ApplyFocus()
    if m.page > 1 and m.vm <> invalid and m.vm.shellFocus = "header" then
        ShellEnterContent(m.vm)
    end if
    print "[SERIES_DBG] grid_build_done rows="; m.rows.Count(); " nodes="; m.rowNodes.Count()
end sub

sub EnsureSeriesRow(rowIdx as integer, row as object)
    while m.rowNodes.Count() <= rowIdx
        rowGroup = m.rowsHost.createChild("Group")
        rowGroup.id = "seriesRow" + Str(m.rowNodes.Count())
        m.rowNodes.Push({ group: rowGroup, cards: [] })
        m.rowScrollX.Push(0)
    end while

    entry = m.rowNodes[rowIdx]
    if entry = invalid or entry.group = invalid then return
    if entry.cards = invalid then entry.cards = []

    for j = entry.cards.Count() to row.items.Count() - 1
        item = row.items[j]
        if item = invalid then continue for
        card = entry.group.createChild("VerticalCard")
        card.translation = [j * BS_ListCardPitch(), 0]
        CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
        card.listType = true
        uri = ""
        if item.thumbnails <> invalid then
            uri = GetCardImgByType(HC_CardTypeVertical(), item.thumbnails)
        end if
        card.thumbnailUri = uri
        card.focusedState = false
        entry.cards.Push(card)
    end for

    scrollX = 0
    if m.rowScrollX.Count() > rowIdx then scrollX = m.rowScrollX[rowIdx]
    rowY = rowIdx * BS_RowPitch()
    if rowIdx <> m.rowIdx then
        entry.group.translation = [-scrollX, rowY]
    end if
    m.rowNodes[rowIdx] = entry
end sub

sub RefreshCardThemes()
    for each entry in m.rowNodes
        if entry = invalid or entry.cards = invalid then continue for
        for each card in entry.cards
            if card = invalid then continue for
            CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
        end for
    end for
end sub

' Hand off shell key routing from the header to the grid once cards are ready.
sub SeriesHandoffContentFocus()
    if m.rows.Count() = 0 then return
    if SeriesEmptyVisible() then return
    m.rowIdx = 0
    m.colIdx = 0
    ApplyFocus()
    if m.vm <> invalid then
        wasHeader = false
        if m.vm.shellFocus = "header" then wasHeader = true
        ShellEnterContent(m.vm)
        BrowseDbg("series_focus", "handoff_to_grid rows=" + Str(m.rows.Count()) + " fromHeader=" + BrowseDbgStr(wasHeader))
    end if
end sub

sub ApplyFocus()
    paintGridFocus = true
    if m.vm <> invalid and m.vm.shellFocus = "header" then paintGridFocus = false

    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.cards = invalid then continue for
        for j = 0 to entry.cards.Count() - 1
            card = entry.cards[j]
            if card = invalid then continue for
            card.focusedState = (paintGridFocus and i = m.rowIdx and j = m.colIdx)
        end for
    end for
    ApplyScroll()
    MaybeLoadMore()
end sub

sub ApplyScroll()
    if m.rowsHost = invalid then return
    if m.rowNodes.Count() = 0 then return

    m.scrollY = GridClampScrollY(m.rowIdx, m.scrollY, BS_RowPitch(), BS_ListCardH(), BS_ViewHeight())

    viewW = 1808
    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.group = invalid then continue for
        scrollX = 0
        if m.rowScrollX.Count() > i then scrollX = m.rowScrollX[i]
        if i = m.rowIdx and entry.cards <> invalid and entry.cards.Count() > 0 then
            m.colIdx = GridClampColIndex(m.rowIdx, m.colIdx, m.rowNodes)
            scrollX = GridClampRowScrollX(m.colIdx, scrollX, BS_ListCardPitch(), BS_ListCardW(), viewW)
            m.rowScrollX[i] = scrollX
        end if
        rowY = i * BS_RowPitch()
        if i <> m.rowIdx then
            entry.group.translation = [-scrollX, rowY]
            m.rowNodes[i] = entry
        end if
    end for

    AnimateRowsHostVertical()
    AnimateFocusedRowHorizontal()
end sub

' Vertical list scroll — parity GenreListScreen AnimateRowsHost (inOutCubic).
sub AnimateRowsHostVertical()
    if m.rowsHost = invalid then return
    target = [BS_ListLeft(), BS_RowStartY() - m.scrollY]
    GridAnimateTranslation(m.rowsHost, m.rowsHost.translation, target, m.vScrollAnim, m.vScrollInterp, true, "")
end sub

' Horizontal row scroll — animate the focused row strip.
sub AnimateFocusedRowHorizontal()
    if m.rowIdx < 0 or m.rowIdx >= m.rowNodes.Count() then return
    entry = m.rowNodes[m.rowIdx]
    if entry = invalid or entry.group = invalid then return

    scrollX = 0
    if m.rowScrollX.Count() > m.rowIdx then scrollX = m.rowScrollX[m.rowIdx]
    target = [-scrollX, m.rowIdx * BS_RowPitch()]
    GridAnimateTranslation(entry.group, entry.group.translation, target, m.hScrollAnim, m.hScrollInterp, true, entry.group.id + ".translation")
end sub

sub MaybeLoadMore()
    if SeriesGridBuildIncomplete() then return
    if GridShouldLoadMore(m.hasMore, m.loading, m.rows.Count(), m.rowIdx) then FetchNextPage()
end sub

function SeriesEmptyVisible() as boolean
    if m.emptyLabel = invalid then return false
    return m.emptyLabel.visible = true
end function

sub EnterSeriesHeader()
    if m.vm = invalid then return
    menuItems = m.vm.menuItems
    if menuItems = invalid or menuItems.Count() = 0 then
        flags = HeaderMenuFeatureFlags(m.top)
        menuItems = HeaderMenuItems(flags.reels, flags.epg)
    end if
    navState = { type: m.listType }
    idx = HeaderSelectedIndexForNav(menuItems, RouteSeries(), navState)
    ShellEnterHeader(m.vm, idx)
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.loading and m.initialLoad then return
    if m.vm <> invalid and m.vm.shellFocus = "header" then return

    key = ev.key
    if SeriesEmptyVisible() then
        if key = "up" and NavUpOpensHeaderFromContent() then EnterSeriesHeader()
        if key = "left" and NavLeftOpensSidebarFromContent(true) then EnterSeriesHeader()
        return
    end if
    if m.rows.Count() = 0 then return

    if key = "up" then
        if m.rowIdx = 0 then
            if NavUpOpensHeaderFromContent() then EnterSeriesHeader()
            return
        end if
        if m.rowIdx > 0 then m.rowIdx = m.rowIdx - 1
        ClampCol()
        ApplyFocus()
    else if key = "down" then
        if m.rowIdx < m.rows.Count() - 1 then m.rowIdx = m.rowIdx + 1
        ClampCol()
        ApplyFocus()
    else if key = "left" then
        if NavLeftOpensSidebarFromContent(m.colIdx = 0) then
            EnterSeriesHeader()
            return
        end if
        if m.colIdx > 0 then m.colIdx = m.colIdx - 1
        ApplyFocus()
    else if key = "right" then
        entry = m.rowNodes[m.rowIdx]
        if entry <> invalid and entry.cards <> invalid and m.colIdx < entry.cards.Count() - 1 then
            m.colIdx = m.colIdx + 1
        end if
        ApplyFocus()
    else if key = "OK" or key = "ok" then
        OpenFocusedItem()
    end if
end sub

sub ClampCol()
    m.colIdx = GridClampColIndex(m.rowIdx, m.colIdx, m.rowNodes)
end sub

sub OpenFocusedItem()
    if m.rowIdx < 0 or m.rowIdx >= m.rows.Count() then return
    row = m.rows[m.rowIdx]
    if row = invalid or row.items = invalid then return
    if m.colIdx < 0 or m.colIdx >= row.items.Count() then return
    item = row.items[m.colIdx]
    if item = invalid or m.vm = invalid then return
    id = ""
    tp = ""
    if item._id <> invalid then id = item._id
    if item.type <> invalid then tp = item.type
    if id = "" or tp = "" then return
    m.vm.callFunc("NavigatePush", RouteDetail(), { id: id, type: tp })
end sub
