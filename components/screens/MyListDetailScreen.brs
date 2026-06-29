' MyListDetailScreen.brs — parity with features/list-detail/

sub init()
    m.vm = FindViewManager(m.top)
    m.bg = m.top.findNode("bg")
    m.contentHost = m.top.findNode("contentHost")
    m.skeletonHost = m.top.findNode("skeletonHost")
    m.rowsHost = m.top.findNode("rowsHost")
    m.emptyHost = m.top.findNode("emptyHost")
    m.emptyLabel = m.top.findNode("emptyLabel")

    m.folderId = ""
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
    m.fetchGen = 0
    m.viewportW = 1808
    m.itemsPerRow = 6

    LoadMyListTokens()
    ApplyStaticColors()
    ApplyMyListShellLayout()

    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
    ResetAndFetch()
end sub

sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    m.rowIdx = 0
    m.colIdx = 0
    ApplyFocus()
end sub

' ViewManager sets stackResumed when popping back from Detail (or any overlay screen).
sub OnStackResumed()
    if m.top.stackResumed <> true then return
    m.top.stackResumed = false
    ResetAndFetch()
end sub

sub OnShellLayoutRev()
    ApplyMyListShellLayout()
    ApplyScroll()
end sub

sub OnBusinessResolved()
    LoadMyListTokens()
    ApplyStaticColors()
    RefreshCardThemes()
end sub

sub OnDispose()
    if not m.top.dispose then return
    KillTask(m.folderTask)
    KillTask(m.detailTask)
    m.folderTask = invalid
    m.detailTask = invalid
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
end sub

sub KillTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

sub LoadMyListTokens()
    ThemeApplyWatchlistPalette(m, m.top)
end sub

sub ApplyStaticColors()
    if m.bg <> invalid then m.bg.color = m.cPageBg
    ApplyEmptyLayout()
end sub

sub ApplyEmptyLayout()
    if m.emptyLabel <> invalid then
        m.emptyLabel.text = WL_EmptyCopy()
        ' React: max-w-355 text-center m-0 text-neutral-50 fw-900 fs-36 font-sans
        m.emptyLabel.width = WL_EmptyMaxW()
        m.emptyLabel.horizAlign = "center"
        m.emptyLabel.vertAlign = "center"
        m.emptyLabel.wrap = true
        f = m.emptyLabel.font
        if f = invalid then
            f = CreateObject("roSGNode", "Font")
            m.emptyLabel.font = f
        end if
        f.uri = "pkg:/fonts/Inter-Black.ttf"
        f.size = WL_EmptyFontSize()
        m.emptyLabel.color = m.cEmptyText
    end if
    header = FindAppHeader(m.top)
    viewportW = ShellContentViewportW(header)
    w = WL_EmptyMaxW()
    x = Int((viewportW - w) / 2)
    if x < 0 then x = 0
    if m.emptyHost <> invalid then m.emptyHost.translation = [x, WL_EmptyTopY()]
end sub

sub ApplyMyListShellLayout()
    header = FindAppHeader(m.top)
    offX = ShellContentOffsetX(header)
    m.viewportW = ShellContentViewportW(header)
    m.itemsPerRow = WL_ItemsPerRow(m.viewportW)
    if m.contentHost <> invalid then m.contentHost.translation = [offX, 0]
    ApplyEmptyLayout()
end sub

sub ResetAndFetch()
    m.fetchGen = m.fetchGen + 1
    KillTask(m.folderTask)
    KillTask(m.detailTask)
    m.folderTask = invalid
    m.detailTask = invalid
    m.loading = false
    m.initialLoad = true
    m.folderId = ""
    m.page = 0
    m.hasMore = true
    m.rows = []
    m.rowIdx = 0
    m.colIdx = 0
    m.scrollY = 0
    m.rowScrollX = []
    ClearRows()
    ShowEmpty(false)
    FetchFolders()
end sub

sub ShowSkeleton(show as boolean)
    if m.skeletonHost <> invalid then
        m.skeletonHost.removeChildrenIndex(m.skeletonHost.getChildCount(), 0)
        if show then BuildSkeletonRow()
        m.skeletonHost.visible = show
    end if
    if m.rowsHost <> invalid and show then m.rowsHost.visible = false
end sub

sub BuildSkeletonRow()
    if m.skeletonHost = invalid then return
    x = 0
    n = m.itemsPerRow
    if n < 1 then n = WL_ItemsPerRow(m.viewportW)
    for i = 0 to n - 1
        card = m.skeletonHost.createChild("ListDetailCard")
        card.translation = [x, 0]
        card.isLoading = true
        CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
        card.cPageBg = m.cPageBg
        x = x + WL_CardPitch()
    end for
end sub

sub ShowEmpty(show as boolean)
    if m.emptyHost <> invalid then m.emptyHost.visible = show
    if m.rowsHost <> invalid then
        m.rowsHost.visible = (not show) and (m.rows.Count() > 0)
    end if
    if show then
        LoadMyListTokens()
        ShowSkeleton(false)
        ApplyEmptyLayout()
        if m.emptyHost <> invalid and m.contentHost <> invalid then
            m.contentHost.removeChild(m.emptyHost)
            m.contentHost.appendChild(m.emptyHost)
        end if
    end if
end sub

sub FetchFolders()
    if m.loading then return
    m.loading = true
    m.folderFetchGen = m.fetchGen
    ShowSkeleton(true)
    KillTask(m.folderTask)
    path = Endpoints().MY_LIST.MY_LIST_LISTING
    m.folderTask = ApiGet(path)
    m.folderTask.observeField("apiResult", "OnFoldersResponse")
    StartHttpTask(m.folderTask)
end sub

sub OnFoldersResponse()
    if m.top.dispose = true then return
    if m.folderTask = invalid then return
    if m.folderFetchGen <> m.fetchGen then
        return
    end if
    m.folderTask.unobserveField("apiResult")
    api = m.folderTask.apiResult
    m.folderTask = invalid

    folder = WL_ParseFirstFolder(api)
    if folder = invalid then
        m.loading = false
        m.initialLoad = false
        m.hasMore = false
        ShowSkeleton(false)
        ShowEmpty(true)
        return
    end if

    m.folderId = folder.id
    FetchDetailPage()
end sub

sub FetchDetailPage()
    if m.folderId = "" then return
    if m.loading and not m.initialLoad then return
    if not m.hasMore and m.page > 0 then return
    m.page = m.page + 1
    m.loading = true
    m.detailFetchGen = m.fetchGen
    path = WL_BuildDetailPath(m.folderId)
    q = { page: m.page, limit: WL_PageLimit() }
    KillTask(m.detailTask)
    m.detailTask = ApiGetQuery(path, q)
    m.detailTask.observeField("apiResult", "OnDetailResponse")
    StartHttpTask(m.detailTask)
end sub

sub OnDetailResponse()
    if m.top.dispose = true then return
    if m.detailTask = invalid then return
    if m.detailFetchGen <> m.fetchGen then
        return
    end if
    m.detailTask.unobserveField("apiResult")
    api = m.detailTask.apiResult
    m.detailTask = invalid
    m.loading = false
    m.initialLoad = false
    ShowSkeleton(false)

    items = WL_ParseDetailItems(api)
    count = items.Count()

    if count = 0 then
        m.hasMore = false
        if m.rows.Count() = 0 then ShowEmpty(true)
        return
    end if

    ShowEmpty(false)
    m.hasMore = WL_DetailHasMore(api, count)
    m.rows = SL_AppendRows(m.rows, items, m.itemsPerRow)
    AppendRowNodes(count)
    if m.rowsHost <> invalid then m.rowsHost.visible = true
    ApplyFocus()
end sub

sub ClearRows()
    if m.rowsHost = invalid then return
    m.rowsHost.removeChildrenIndex(m.rowsHost.getChildCount(), 0)
    m.rowNodes = []
end sub

sub AppendRowNodes(newItemCount as integer)
    if newItemCount <= 0 then return
    for i = 0 to m.rows.Count() - 1
        row = m.rows[i]
        if row = invalid then continue for
        if i < m.rowNodes.Count() then continue for

        rowGroup = m.rowsHost.createChild("Group")
        cards = []
        x = 0
        if row.items <> invalid then
            for j = 0 to row.items.Count() - 1
                item = row.items[j]
                card = rowGroup.createChild("ListDetailCard")
                card.translation = [x, 0]
                CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
                card.cPageBg = m.cPageBg
                uri = ""
                title = ""
                lang = ""
                tp = ""
                if item <> invalid then
                    uri = WL_ItemThumbnail(item)
                    if item.title <> invalid then title = item.title
                    tp = WL_ItemContentType(item)
                    if item.originalLang <> invalid then lang = item.originalLang
                end if
                card.thumbnailUri = uri
                card.title = title
                card.contentType = tp
                card.originalLang = lang
                card.focusedState = false
                cards.Push(card)
                x = x + WL_CardPitch()
            end for
        end if

        m.rowNodes.Push({ group: rowGroup, cards: cards })
        if m.rowScrollX.Count() <= i then m.rowScrollX.Push(0)
    end for
end sub

sub RefreshCardThemes()
    for each entry in m.rowNodes
        if entry = invalid or entry.cards = invalid then continue for
        for each card in entry.cards
            if card = invalid then continue for
            CardInjectTheme(card, m.cPrimary500, m.cPrimary600, m.cPrimary700, m.cNeutral50, m.cNeutral800, m.cNeutral700)
            card.cPageBg = m.cPageBg
        end for
    end for
end sub

sub ApplyFocus()
    paintGridFocus = true
    if m.vm <> invalid and m.vm.shellFocus = "header" then paintGridFocus = false

    focusedCard = invalid
    focusedRow = invalid
    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.cards = invalid then continue for
        for j = 0 to entry.cards.Count() - 1
            card = entry.cards[j]
            if card = invalid then continue for
            focused = (paintGridFocus and i = m.rowIdx and j = m.colIdx)
            card.focusedState = focused
            if focused then
                focusedCard = card
                focusedRow = entry.group
            end if
        end for
    end for
    if focusedCard <> invalid and focusedRow <> invalid then
        focusedRow.removeChild(focusedCard)
        focusedRow.appendChild(focusedCard)
    end if
    ApplyScroll()
    MaybeLoadMore()
end sub

sub ApplyScroll()
    if m.rowsHost = invalid then return
    if m.rowNodes.Count() = 0 then return

    m.scrollY = GridClampScrollY(m.rowIdx, m.scrollY, WL_RowPitch(), WL_CardOuterH(), WL_ViewHeight())

    viewW = m.viewportW
    if viewW < 1 then viewW = 1808
    cardScrollW = WL_CardOuterW() + WL_CardBorderBleed()
    for i = 0 to m.rowNodes.Count() - 1
        entry = m.rowNodes[i]
        if entry = invalid or entry.group = invalid then continue for
        scrollX = 0
        if m.rowScrollX.Count() > i then scrollX = m.rowScrollX[i]
        if i = m.rowIdx and entry.cards <> invalid and entry.cards.Count() > 0 then
            m.colIdx = GridClampColIndex(m.rowIdx, m.colIdx, m.rowNodes)
            scrollX = GridClampRowScrollX(m.colIdx, scrollX, WL_CardPitch(), cardScrollW, viewW)
            m.rowScrollX[i] = scrollX
        end if
        entry.group.translation = [-scrollX, i * WL_RowPitch() - m.scrollY]
        m.rowNodes[i] = entry
    end for
end sub

sub MaybeLoadMore()
    if GridShouldLoadMore(m.hasMore, m.loading, m.rows.Count(), m.rowIdx) then FetchDetailPage()
end sub

sub EnterMyListHeader()
    if m.vm = invalid then return
    reels = false
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.reelsEnabled = true then reels = true
    menuIdx = HeaderSelectedIndex(HeaderMenuItems(reels), RouteMyListDetail())
    ShellEnterHeader(m.vm, menuIdx)
end sub

function MyListEmptyVisible() as boolean
    if m.emptyHost = invalid then return false
    return m.emptyHost.visible = true
end function

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.loading and m.initialLoad then return

    key = ev.key
    if key = "up" then
        if MyListEmptyVisible() then
            EnterMyListHeader()
            return
        end if
        if m.rowIdx = 0 and m.rows.Count() > 0 then
            EnterMyListHeader()
            return
        end if
        if m.rowIdx > 0 then m.rowIdx = m.rowIdx - 1
        ClampCol()
        ApplyFocus()
    else if key = "down" then
        if m.rows.Count() = 0 then return
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
    if item._id <> invalid then id = item._id
    tp = WL_ItemContentType(item)
    if id = "" or tp = "" then return
    m.vm.callFunc("NavigatePush", RouteDetail(), { id: id, type: tp })
end sub
