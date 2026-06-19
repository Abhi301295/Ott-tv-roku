' SeriesScreen.brs — parity with src/features/series/ (See All grid, 6 cards per row).

sub init()
    m.bg = m.top.findNode("bg")
    m.titleLabel = m.top.findNode("titleLabel")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.rowsHost = m.top.findNode("rowsHost")
    m.loadingHost = m.top.findNode("loadingHost")

    m.listType = ""
    m.categoryId = ""
    m.genreId = ""
    m.page = 0
    m.hasMore = true
    m.loading = false
    m.initialLoad = true
    m.rows = []
    m.rowNodes = []
    m.rowIdx = 0
    m.colIdx = 0
    m.scrollY = 0
    m.rowScrollX = []

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

sub OnDispose()
    if not m.top.dispose then return
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
end sub

sub LoadBrowseTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens
    m.cPrimary500 = TCb("primary-500", "#0b75e0")
    m.cPrimary600 = TCb("primary-600", "#0760bb")
    m.cPrimary700 = TCb("primary-700", "#04478b")
    m.cNeutral50 = TCb("neutral-50", "#f5f5f5")
    m.cNeutral700 = TCb("neutral-700", "#404040")
    m.cNeutral800 = TCb("neutral-800", "#262626")
end sub

function TCb(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

sub ApplyStaticColors()
    if m.bg <> invalid then m.bg.color = m.cNeutral800
    if m.titleLabel <> invalid then m.titleLabel.color = m.cNeutral50
    if m.emptyLabel <> invalid then m.emptyLabel.color = m.cNeutral50
end sub

sub ResetAndFetch()
    m.page = 0
    m.hasMore = true
    m.rows = []
    m.rowIdx = 0
    m.colIdx = 0
    m.scrollY = 0
    m.rowScrollX = []
    ClearRows()
    m.emptyLabel.visible = false
    FetchNextPage()
end sub

sub ShowLoading(show as boolean)
    m.loading = show
    if m.loadingHost <> invalid then m.loadingHost.visible = show
end sub

sub FetchNextPage()
    if m.loading then return
    if not m.hasMore then return
    m.page = m.page + 1
    ShowLoading(true)
    path = Endpoints().SERIES.SERIES_LIST
    q = SL_BuildQuery(m.page, m.listType, m.categoryId, m.genreId)
    BrowseDbg("series_fetch", "path=" + path + " page=" + Str(m.page) + " type=" + m.listType + " category=" + m.categoryId + " genre=" + m.genreId)
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
    m.initialLoad = false
    ShowLoading(false)

    BrowseDbgApi("series_response", api)
    if api = invalid or api.statusCode = invalid or api.statusCode <> 200 then
        BrowseDbg("series_response", "fail: bad status — show empty=" + BrowseDbgStr(m.rows.Count() = 0))
        m.hasMore = false
        if m.rows.Count() = 0 then ShowEmpty(true)
        return
    end if

    listing = []
    if api.result <> invalid and api.result.listing <> invalid then
        listing = api.result.listing
    end if

    m.hasMore = SL_PageHasMore(api, listing.Count())
    BrowseDbg("series_response", "listingCount=" + Str(listing.Count()) + " hasMore=" + BrowseDbgStr(m.hasMore) + " existingRows=" + Str(m.rows.Count()))
    if listing.Count() = 0 and m.rows.Count() = 0 then
        BrowseDbg("series_response", "empty listing — show empty state")
        ShowEmpty(true)
        return
    end if

    ShowEmpty(false)
    m.rows = SL_AppendRows(m.rows, listing, BS_ItemsPerRow())
    AppendRowNodes(listing.Count())
    ApplyFocus()
end sub

sub ShowEmpty(show as boolean)
    BrowseDbg("series_empty", "visible=" + BrowseDbgStr(show))
    if m.emptyLabel <> invalid then m.emptyLabel.visible = show
    if m.rowsHost <> invalid then m.rowsHost.visible = not show
end sub

sub ClearRows()
    if m.rowsHost = invalid then return
    for i = m.rowsHost.getChildCount() - 1 to 0 step -1
        m.rowsHost.removeChildIndex(i)
    end for
    m.rowNodes = []
end sub

sub AppendRowNodes(newItemCount as integer)
    if newItemCount <= 0 then return
    startFlat = 0
    for i = 0 to m.rows.Count() - 1
        row = m.rows[i]
        if row = invalid then continue for
        if i < m.rowNodes.Count() then continue for

        rowGroup = m.rowsHost.createChild("Group")
        rowY = i * BS_RowPitch()
        rowGroup.translation = [0, rowY]

        cards = []
        frames = []
        x = 0
        if row.items <> invalid then
            for j = 0 to row.items.Count() - 1
                item = row.items[j]
                card = rowGroup.createChild("VerticalCard")
                card.translation = [x, 0]
                CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
                card.listType = true
                uri = ""
                if item.thumbnails <> invalid then
                    uri = GetCardImgByType(HC_CardTypeVertical(), item.thumbnails)
                end if
                card.thumbnailUri = uri
                card.focusedState = false
                cards.Push(card)
                frames.Push(invalid)
                x = x + BS_ListCardPitch()
            end for
        end if

        m.rowNodes.Push({ group: rowGroup, cards: cards, frames: frames })
        if m.rowScrollX.Count() <= i then m.rowScrollX.Push(0)
    end for
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

sub ApplyFocus()
    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.cards = invalid then continue for
        for j = 0 to entry.cards.Count() - 1
            card = entry.cards[j]
            focused = (i = m.rowIdx and j = m.colIdx)
            card.focusedState = focused
            frame = entry.frames[j]
            frame = CardEnsureFocusFrame(card, frame, -3, -3, BS_ListCardW() + 6, BS_ListCardH() + 6, m.cPrimary600)
            entry.frames[j] = frame
            CardApplyFocusBorder(frame, focused, m.cPrimary600)
        end for
        m.rowNodes[i] = entry
    end for
    ApplyScroll()
    MaybeLoadMore()
end sub

sub ApplyScroll()
    if m.rowsHost = invalid then return
    if m.rowNodes.Count() = 0 then return

    rowTop = m.rowIdx * BS_RowPitch()
    rowBottom = rowTop + BS_ListCardH()
    if rowTop < m.scrollY then
        m.scrollY = rowTop
    else if rowBottom > m.scrollY + BS_ViewHeight() then
        m.scrollY = rowBottom - BS_ViewHeight()
    end if
    if m.scrollY < 0 then m.scrollY = 0
    m.rowsHost.translation = [BS_ListLeft(), BS_RowStartY() - m.scrollY]

    viewW = 1808
    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.group = invalid then continue for
        scrollX = 0
        if m.rowScrollX.Count() > i then scrollX = m.rowScrollX[i]
        if i = m.rowIdx and entry.cards <> invalid and entry.cards.Count() > 0 then
            if m.colIdx >= entry.cards.Count() then m.colIdx = entry.cards.Count() - 1
            if m.colIdx < 0 then m.colIdx = 0
            cardLeft = m.colIdx * BS_ListCardPitch()
            cardRight = cardLeft + BS_ListCardW()
            if cardLeft < scrollX then scrollX = cardLeft
            if cardRight > scrollX + viewW then scrollX = cardRight - viewW
            if scrollX < 0 then scrollX = 0
            m.rowScrollX[i] = scrollX
        end if
        entry.group.translation = [-scrollX, i * BS_RowPitch()]
        m.rowNodes[i] = entry
    end for
end sub

sub MaybeLoadMore()
    if not m.hasMore then return
    if m.loading then return
    if m.rows.Count() = 0 then return
    if m.rowIdx = m.rows.Count() - 1 then FetchNextPage()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.loading and m.initialLoad then return
    if m.rows.Count() = 0 then return

    key = ev.key
    if key = "up" then
        if m.rowIdx > 0 then m.rowIdx = m.rowIdx - 1
        ClampCol()
        ApplyFocus()
    else if key = "down" then
        if m.rowIdx < m.rows.Count() - 1 then m.rowIdx = m.rowIdx + 1
        ClampCol()
        ApplyFocus()
    else if key = "left" then
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
    if m.rowIdx < 0 or m.rowIdx >= m.rowNodes.Count() then return
    entry = m.rowNodes[m.rowIdx]
    if entry = invalid or entry.cards = invalid then return
    if m.colIdx >= entry.cards.Count() then m.colIdx = entry.cards.Count() - 1
    if m.colIdx < 0 then m.colIdx = 0
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
