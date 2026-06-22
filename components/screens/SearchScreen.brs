sub init()
    m.vm = FindViewManager(m.top)
    m.contentHost = m.top.findNode("contentHost")
    m.layoutCol = m.top.findNode("layoutCol")
    m.leftPanel = m.top.findNode("leftPanel")
    m.rightPanel = m.top.findNode("rightPanel")
    m.inputWrap = m.top.findNode("inputWrap")
    m.searchInput = m.top.findNode("searchInput")
    m.keyboard = m.top.findNode("keyboard")
    m.gridViewport = m.top.findNode("gridViewport")
    m.gridScrollHost = m.top.findNode("gridScrollHost")
    m.gridHost = m.top.findNode("gridHost")
    m.loadingHost = m.top.findNode("loadingHost")
    m.skeletonHost = m.top.findNode("skeletonHost")
    m.emptyHost = m.top.findNode("emptyHost")
    m.emptyIcon = m.top.findNode("emptyIcon")
    m.emptyLbl = m.top.findNode("emptyLbl")
    m.searchDebounceTimer = m.top.findNode("searchDebounceTimer")

    m.focusZone = "input"
    m.searchText = ""
    m.pendingKeyword = ""
    m.lastFetchedKeyword = chr(1)
    m.inFlightKeyword = ""
    m.results = []
    m.cardNodes = []
    m.gridIndex = 0
    m.gridScrollY = 0
    m.gridCols = 3
    m.keyRow = 0
    m.keyCol = 0
    m.loading = false
    m.viewportW = 1920
    m.leftW = 768
    m.rightW = 1152

    LoadSearchTokens()
    ApplySearchShellLayout()
    ApplySearchInputTheme()

    if m.keyboard <> invalid then
        m.keyboard.observeField("keyPress", "OnKeyboardKeyPress")
        m.keyboard.focusActive = false
        ApplyKeyboardTheme()
    end if
    ApplyInputFocus()
    m.top.observeField("keyEvent", "OnKey")
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid then tm.observeField("ready", "OnThemeReady")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
    if m.searchDebounceTimer <> invalid then
        m.searchDebounceTimer.duration = SR_SearchDebounceMs()
        m.searchDebounceTimer.observeField("fire", "OnSearchDebounceFire")
    end if
    ApplyEmptyCopy()
end sub

sub OnNavStateReady()
    LoadSearchTokens()
    ApplySearchTokens()
    EnterInput()
    m.pendingKeyword = ""
    FetchSearch("")
end sub

sub OnDispose()
    if not m.top.dispose then return
    KillSearchTask(m.searchTask)
    m.searchTask = invalid
    if m.searchDebounceTimer <> invalid then
        m.searchDebounceTimer.control = "stop"
        m.searchDebounceTimer.unobserveField("fire")
    end if
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid then tm.unobserveField("ready")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
    if m.keyboard <> invalid then m.keyboard.unobserveField("keyPress")
end sub

sub KillSearchTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

sub OnThemeReady()
    LoadSearchTokens()
    ApplySearchTokens()
end sub

sub OnBusinessResolved()
    LoadSearchTokens()
    ApplySearchTokens()
end sub

sub LoadSearchTokens()
    SearchApplyThemeColors(m)
end sub

sub ApplySearchTokens()
    ApplySearchInputTheme()
    ApplyKeyboardTheme()
    ApplyInputFocus()
    ApplyGridFocus()
end sub

sub ApplySearchInputTheme()
    if m.searchInput = invalid then return
    m.searchInput.bgColor = m.cInputBg
    m.searchInput.borderColor = m.cInputBorderFocus
    m.searchInput.textColor = m.cText
    m.searchInput.placeholderColor = SR_PlaceholderColor()
    m.searchInput.placeholder = SR_InputPlaceholder()
end sub

sub ApplyKeyboardTheme()
    if m.keyboard = invalid then return
    m.keyboard.cPrimary500 = m.cPrimary500
    m.keyboard.cNeutral700 = m.cKeyBorder
    m.keyboard.cNeutral50 = m.cText
    m.keyboard.callFunc("RefreshKeyColors", invalid)
end sub

sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    m.focusZone = "input"
    ApplyInputFocus()
end sub

sub OnShellLayoutRev()
    ApplySearchShellLayout()
end sub

sub ApplySearchShellLayout()
    header = FindAppHeader(m.top)
    offX = ShellContentOffsetX(header)
    m.viewportW = ShellContentViewportW(header)
    m.leftW = Int(m.viewportW * SR_LeftBasisPct() / 100)
    m.rightW = m.viewportW - m.leftW - SR_ColGap()
    if m.contentHost <> invalid then m.contentHost.translation = [offX, 0]
    if m.layoutCol <> invalid then m.layoutCol.translation = [SR_ColPadX(), SR_ContentPadTop()]
    if m.rightPanel <> invalid then m.rightPanel.translation = [m.leftW + SR_ColGap(), 0]
    inputX = SR_InputWrapperMarginLeft()
    if m.inputWrap <> invalid then
        m.inputWrap.translation = [inputX, 0]
    end if
    inputW = m.leftW
    if m.searchInput <> invalid then
        m.searchInput.fieldWidth = inputW
    end if
    if m.keyboard <> invalid then
        kw = m.keyboard.panelWidth
        if kw = invalid or kw < 1 then kw = inputW
        kx = inputX + Int((inputW - kw) / 2)
        if kx < 0 then kx = 0
        m.keyboard.translation = [kx, SR_InputH() + SR_KeyboardMarginTop()]
    end if
    m.gridCols = SearchGridCols(m.rightW)
    ApplyGridViewport()
    RebuildGridPositions()
    ApplyGridScroll()
    ApplyEmptyLayout()
end sub

sub ApplyGridViewport()
    if m.gridViewport = invalid then return
    viewH = SR_GridViewHeight()
    m.gridViewport.clippingRect = [0, 0, m.rightW, viewH]
end sub

function SearchGridCols(panelW as integer) as integer
    ' React searchgrid.tsx: repeat(auto-fill, minmax(300px, 1fr)).
    usable = panelW - SR_GridMarginLeft()
    minColW = SR_GridMinCol()
    gap = SR_GridGapX()
    if usable < minColW then return 1
    cols = Int((usable + gap) / (minColW + gap))
    if cols < 1 then cols = 1
    return cols
end function

sub ScheduleSearch(keyword as string)
    if keyword = invalid then keyword = ""
    if keyword <> m.lastFetchedKeyword then BeginSearchLoading()
    m.pendingKeyword = keyword
    if m.searchDebounceTimer = invalid then
        CommitSearch(keyword)
        return
    end if
    m.searchDebounceTimer.duration = SR_SearchDebounceMs()
    m.searchDebounceTimer.control = "stop"
    m.searchDebounceTimer.control = "start"
end sub

sub OnSearchDebounceFire()
    kw = m.pendingKeyword
    if kw = invalid then kw = ""
    if kw = m.lastFetchedKeyword then return
    CommitSearch(kw)
end sub

sub CommitSearch(keyword as string)
    if keyword = invalid then keyword = ""
    if keyword = m.lastFetchedKeyword then return
    FetchSearch(keyword)
end sub

sub FetchSearch(keyword as string)
    if keyword = invalid then keyword = ""
    m.lastFetchedKeyword = keyword
    m.inFlightKeyword = keyword
    m.loading = true
    BeginSearchLoading()
    KillSearchTask(m.searchTask)
    path = SearchBuildPath(keyword, 1, SR_ApiLimit())
    m.searchTask = ApiGet(path)
    m.searchTask.observeField("apiResult", "OnSearchResponse")
    StartHttpTask(m.searchTask)
end sub

sub BeginSearchLoading()
    m.gridScrollY = 0
    ClearGrid()
    ShowEmpty(false)
    ShowLoading(true)
    ApplyGridScroll()
end sub

sub OnSearchResponse()
    if m.top.dispose = true then return
    if m.searchTask = invalid then return
    m.searchTask.unobserveField("apiResult")
    api = m.searchTask.apiResult
    respondedKw = m.inFlightKeyword
    m.searchTask = invalid

    if respondedKw <> m.pendingKeyword then return

    m.loading = false
    ShowLoading(false)

    m.results = SearchParseListing(api)
    count = m.results.Count()

    if count = 0 and Len(m.searchText) > 0 then
        ShowEmpty(true)
        ClearGrid()
        return
    end if
    ShowEmpty(false)
    BuildGrid()
end sub

sub ShowLoading(show as boolean)
    if m.loadingHost <> invalid then m.loadingHost.visible = show
    if show then
        BuildSkeletonGrid()
    else
        ClearSkeletonGrid()
        if m.gridHost <> invalid and m.emptyHost <> invalid and m.emptyHost.visible <> true then
            m.gridHost.visible = true
        end if
    end if
end sub

sub BuildSkeletonGrid()
    if m.skeletonHost = invalid then return
    ClearSkeletonGrid()
    base = CardContrastSkeletonBase(m.cPageBg, m.cKeyBorder)
    hi = m.cKeyBorder
    if hi = invalid or hi = "" then hi = "0x404040ff"
    rows = SR_SkeletonRows()
    count = m.gridCols * rows
    for i = 0 to count - 1
        cardPos = SearchCardPos(i)
        tile = m.skeletonHost.createChild("Group")
        tile.translation = [cardPos[0], cardPos[1]]
        skThumb = tile.createChild("Skeleton")
        skThumb.translation = [0, SR_CardTitleMarginTop()]
        skThumb.boxWidth = SR_CardW()
        skThumb.boxHeight = SR_CardH()
        skThumb.shapeUri = SR_SkeletonThumbShapeUri()
        CardApplySkeleton(skThumb, base, hi)
        skThumb.running = true
        titleY = SR_CardTitleMarginTop() + SR_CardH() + SR_CardTitleMarginTop()
        skTitle = tile.createChild("Skeleton")
        skTitle.translation = [0, titleY]
        skTitle.boxWidth = SR_CardTitleMaxW()
        skTitle.boxHeight = SR_CardTitleH()
        skTitle.shapeUri = SR_SkeletonTitleShapeUri()
        CardApplySkeleton(skTitle, base, hi)
        skTitle.running = true
    end for
end sub

sub ClearSkeletonGrid()
    if m.skeletonHost = invalid then return
    m.skeletonHost.removeChildrenIndex(m.skeletonHost.getChildCount(), 0)
end sub

sub ShowEmpty(show as boolean)
    if m.emptyHost <> invalid then m.emptyHost.visible = show
    if m.gridHost <> invalid then m.gridHost.visible = not show
end sub

sub ApplyEmptyCopy()
    if m.emptyLbl <> invalid then m.emptyLbl.text = SR_EmptyCopy()
    if m.emptyIcon <> invalid then
        m.emptyIcon.uri = SR_EmptyIconUri()
        sz = SR_EmptyIconSize()
        m.emptyIcon.width = sz
        m.emptyIcon.height = sz
    end if
    ApplyEmptyLayout()
end sub

sub ApplyEmptyLayout()
    if m.emptyHost = invalid then return
    textW = SR_EmptyTextW()
    iconSz = SR_EmptyIconSize()
    blockW = textW
    if iconSz > blockW then blockW = iconSz
    x = Int((m.rightW - blockW) / 2)
    if x < 0 then x = 0
    y = 160
    m.emptyHost.translation = [x, y]
    if m.emptyIcon <> invalid then
        iconX = Int((blockW - iconSz) / 2)
        m.emptyIcon.translation = [iconX, 0]
    end if
    if m.emptyLbl <> invalid then
        gap = SR_EmptyIconGap()
        m.emptyLbl.translation = [0, iconSz + gap]
        m.emptyLbl.width = textW
    end if
end sub

sub ClearGrid()
    if m.gridHost = invalid then return
    m.gridHost.removeChildrenIndex(m.gridHost.getChildCount(), 0)
    m.cardNodes = []
    m.gridIndex = 0
    m.gridScrollY = 0
end sub

sub BuildGrid()
    ClearGrid()
    if m.gridHost = invalid then return
    for i = 0 to m.results.Count() - 1
        item = m.results[i]
        if item = invalid then continue for
        cardPos = SearchCardPos(i)
        card = m.gridHost.createChild("SearchResultCard")
        card.translation = [cardPos[0], cardPos[1]]
        card.title = item.title
        card.thumbnailUri = SearchHorizontalThumb(item)
        card.cPrimary700 = m.cPrimary700
        card.cNeutral50 = m.cText
        card.cNeutral700 = m.cKeyBorder
        card.cPageBg = m.cPageBg
        m.cardNodes.Push(card)
    end for
    if m.gridIndex >= m.cardNodes.Count() then m.gridIndex = 0
    m.gridScrollY = 0
    ApplyGridFocus()
end sub

sub RebuildGridPositions()
    for i = 0 to m.cardNodes.Count() - 1
        card = m.cardNodes[i]
        if card = invalid then continue for
        cardPos = SearchCardPos(i)
        card.translation = [cardPos[0], cardPos[1]]
    end for
end sub

function SearchCardPos(index as integer) as object
    col = index MOD m.gridCols
    row = Int(index / m.gridCols)
    x = col * SR_CardColPitch()
    y = row * SR_CardRowPitch()
    return [x, y]
end function

sub OnKeyboardKeyPress()
    key = m.keyboard.keyPress
    if key = invalid or key = "" then return
    m.keyboard.keyPress = ""
    if key = "Backspace" then
        if Len(m.searchText) > 0 then m.searchText = Left(m.searchText, Len(m.searchText) - 1)
    else if key = "CLEAR" then
        m.searchText = ""
    else
        m.searchText = m.searchText + key
    end if
    UpdateInputLabel()
    kw = m.searchText.Trim()
    if kw = "" then kw = ""
    ScheduleSearch(kw)
end sub

sub UpdateInputLabel()
    if m.searchInput = invalid then return
    m.searchInput.value = m.searchText
end sub

sub ApplyInputFocus()
    if m.searchInput <> invalid then
        m.searchInput.focusedState = (m.focusZone = "input")
    end if
end sub

function SearchGridRowCount() as integer
    if m.cardNodes.Count() < 1 then return 0
    return Int((m.cardNodes.Count() - 1) / m.gridCols) + 1
end function

function SearchCardHeight() as integer
    return SR_CardTitleMarginTop() + SR_CardH() + SR_CardTitleMarginTop() + SR_CardTitleH()
end function

function SearchRowScrollBottom(row as integer) as integer
    rowTop = row * SR_CardRowPitch()
    tail = SearchCardHeight() + SR_CardTitleGlyphPad() + SR_GridScrollPad()
    return rowTop + tail
end function

function SearchGridContentHeight() as integer
    rows = SearchGridRowCount()
    if rows < 1 then return 0
    return SearchRowScrollBottom(rows - 1)
end function

function SearchGridMaxScroll() as integer
    contentH = SearchGridContentHeight()
    maxY = contentH - SR_GridViewHeight()
    if maxY < 0 then return 0
    return maxY
end function

sub ApplyGridScroll()
    if m.gridScrollHost = invalid then return
    if m.focusZone = "grid" and m.cardNodes.Count() > 0 then
        idx = m.gridIndex
        if idx < 0 then idx = 0
        if idx >= m.cardNodes.Count() then idx = m.cardNodes.Count() - 1
        row = Int(idx / m.gridCols)
        rowTop = row * SR_CardRowPitch()
        scrollBottom = SearchRowScrollBottom(row)
        pad = SR_GridScrollPad()
        viewH = SR_GridViewHeight()
        if rowTop < m.gridScrollY + pad then
            m.gridScrollY = rowTop - pad
        else if scrollBottom > m.gridScrollY + viewH then
            m.gridScrollY = scrollBottom - viewH
        end if
        lastRow = SearchGridRowCount() - 1
        if row = lastRow then
            needY = scrollBottom - viewH
            if needY > m.gridScrollY then m.gridScrollY = needY
        end if
    end if
    if m.gridScrollY < 0 then m.gridScrollY = 0
    maxScroll = SearchGridMaxScroll()
    if m.gridScrollY > maxScroll then m.gridScrollY = maxScroll
    m.gridScrollHost.translation = [SR_GridMarginLeft(), -m.gridScrollY]
end sub

sub ApplyGridFocus()
    for i = 0 to m.cardNodes.Count() - 1
        card = m.cardNodes[i]
        if card = invalid then continue for
        card.cPageBg = m.cPageBg
        card.focusedState = (m.focusZone = "grid" and i = m.gridIndex)
    end for
    ApplyGridScroll()
end sub

sub ApplyKeyboardFocus()
    if m.keyboard = invalid then return
    if m.focusZone = "keyboard" then
        m.keyboard.focusedRow = m.keyRow
        m.keyboard.focusedCol = m.keyCol
    end if
end sub

sub EnterInput()
    m.focusZone = "input"
    if m.keyboard <> invalid then
        m.keyboard.focusActive = false
    end if
    ApplyInputFocus()
    ApplyGridFocus()
end sub

sub EnterKeyboard()
    m.focusZone = "keyboard"
    if m.keyRow = invalid then m.keyRow = 0
    if m.keyCol = invalid then m.keyCol = 0
    if m.keyboard <> invalid then m.keyboard.focusActive = true
    ApplyInputFocus()
    ApplyKeyboardFocus()
end sub

sub EnterGrid()
    if m.cardNodes.Count() = 0 then return
    m.focusZone = "grid"
    if m.keyboard <> invalid then m.keyboard.focusActive = false
    if m.gridIndex < 0 then m.gridIndex = 0
    if m.gridIndex >= m.cardNodes.Count() then m.gridIndex = m.cardNodes.Count() - 1
    ApplyInputFocus()
    ApplyGridFocus()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.vm <> invalid and m.vm.shellFocus = "header" then return

    key = ev.key
    if m.focusZone = "input" then
        if key = "up" then
            ShellEnterHeader(m.vm, invalid)
            return
        else if key = "down" then
            m.keyRow = 0
            m.keyCol = 0
            EnterKeyboard()
            return
        else if key = "right" and m.cardNodes.Count() > 0 then
            EnterGrid()
            return
        else if key = "OK" or key = "ok" then
            m.keyRow = 0
            m.keyCol = 0
            EnterKeyboard()
            return
        end if
    else if m.focusZone = "keyboard" then
        HandleKeyboardNav(key)
    else if m.focusZone = "grid" then
        HandleGridNav(key)
    end if
end sub

sub HandleKeyboardNav(key as string)
    if key = "up" then
        if m.keyRow > 0 then
            m.keyRow = m.keyRow - 1
            ClampKeyCol()
        else
            EnterInput()
            return
        end if
    else if key = "down" then
        maxRow = 3
        if m.keyRow < maxRow then
            m.keyRow = m.keyRow + 1
            ClampKeyCol()
        end if
    else if key = "left" then
        if m.keyCol > 0 then m.keyCol = m.keyCol - 1
    else if key = "right" then
        maxC = KeyRowCount(m.keyRow) - 1
        if m.keyCol < maxC then
            m.keyCol = m.keyCol + 1
        else if m.cardNodes.Count() > 0 then
            EnterGrid()
            return
        end if
    else if key = "OK" or key = "ok" then
        m.keyboard.focusedRow = m.keyRow
        m.keyboard.focusedCol = m.keyCol
        m.keyboard.callFunc("PressFocusedKey", invalid)
        return
    end if
    ApplyKeyboardFocus()
end sub

function KeyRowCount(row as integer) as integer
    if m.keyboard = invalid then return 0
    if row = 0 then return 10
    if row = 1 then return 10
    if row = 2 then return 9
    if row = 3 then return 2
    return 1
end function

sub ClampKeyCol()
    maxC = KeyRowCount(m.keyRow) - 1
    if m.keyCol > maxC then m.keyCol = maxC
    if m.keyCol < 0 then m.keyCol = 0
end sub

sub HandleGridNav(key as string)
    if m.cardNodes.Count() = 0 then return
    cols = m.gridCols
    idx = m.gridIndex
    if key = "left" then
        if idx MOD cols = 0 then
            EnterInput()
            return
        end if
        m.gridIndex = idx - 1
    else if key = "right" then
        if idx >= m.cardNodes.Count() - 1 then
            EnterInput()
            return
        end if
        if idx MOD cols = cols - 1 then
            EnterInput()
            return
        end if
        m.gridIndex = idx + 1
    else if key = "up" then
        if idx < cols then
            EnterInput()
            return
        end if
        m.gridIndex = idx - cols
    else if key = "down" then
        if idx + cols < m.cardNodes.Count() then
            m.gridIndex = idx + cols
        end if
    else if key = "OK" or key = "ok" then
        OpenDetail(idx)
        return
    end if
    ApplyGridFocus()
end sub

sub OpenDetail(idx as integer)
    if idx < 0 or idx >= m.results.Count() then return
    item = m.results[idx]
    if item = invalid then return
    id = item._id
    tp = item.type
    if id = invalid or tp = invalid then return
    if m.vm <> invalid then
        m.vm.callFunc("NavigatePush", RouteDetail(), { id: id, type: tp })
    end if
end sub
