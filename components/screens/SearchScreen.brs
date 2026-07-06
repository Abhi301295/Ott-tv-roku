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
    m.searchLoaderBg = m.top.findNode("searchLoaderBg")
    m.searchLoaderCenter = m.top.findNode("searchLoaderCenter")
    m.searchLoaderSpin = m.top.findNode("searchLoaderSpin")
    m.searchLoaderRing = m.top.findNode("searchLoaderRing")
    m.searchLoaderArc = m.top.findNode("searchLoaderArc")
    m.searchLoaderText = m.top.findNode("searchLoaderText")
    m.searchLoaderAnim = m.top.findNode("searchLoaderAnim")
    m.emptyHost = m.top.findNode("emptyHost")
    m.emptyIcon = m.top.findNode("emptyIcon")
    m.emptyLbl = m.top.findNode("emptyLbl")

    m.focusZone = "input"
    m.searchText = ""
    m.lastFetchedKeyword = chr(1)
    m.inFlightKeyword = ""
    m.searchFetchGen = 0
    m.pendingSearchGen = 0
    m.searchDebounceDeadlineMs = 0
    m.results = []
    m.cardNodes = []
    m.gridIndex = 0
    m.gridScrollY = 0
    m.gridCols = 3
    m.keyRow = 0
    m.keyCol = 0
    m.loading = false
    m.thumbPaintWatch = invalid
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

    ' Grid build pauses on input; search API uses its own 400ms trailing debounce.
    m.interacting = false
    m.gridBuildDeferred = false
    m.gridBuildNeedsFresh = false
    m.gridBuildIdx = 0
    m.gridBuildTimer = CreateObject("roSGNode", "Timer")
    m.gridBuildTimer.duration = 0.02
    m.gridBuildTimer.repeat = true
    m.top.appendChild(m.gridBuildTimer)
    m.gridBuildTimer.observeField("fire", "OnGridBuildTick")
    m.searchDebounceClock = CreateObject("roTimespan")
    m.searchDebouncePoll = CreateObject("roSGNode", "Timer")
    m.searchDebouncePoll.duration = 0.05
    m.searchDebouncePoll.repeat = true
    m.top.appendChild(m.searchDebouncePoll)
    m.searchDebouncePoll.observeField("fire", "OnSearchDebouncePoll")
    m.interactIdle = CreateObject("roSGNode", "Timer")
    m.interactIdle.duration = 0.25
    m.interactIdle.repeat = false
    m.top.appendChild(m.interactIdle)
    m.interactIdle.observeField("fire", "OnGridInteractIdle")

    ApplyEmptyCopy()
end sub

sub OnNavStateReady()
    LoadSearchTokens()
    ApplySearchTokens()
    EnterInput()
    FetchSearch("")
end sub

sub OnDispose()
    if not m.top.dispose then return
    KillSearchTask(m.searchTask)
    m.searchTask = invalid
    if m.gridBuildTimer <> invalid then m.gridBuildTimer.control = "stop"
    if m.searchDebouncePoll <> invalid then m.searchDebouncePoll.control = "stop"
    if m.interactIdle <> invalid then m.interactIdle.control = "stop"
    DetachSearchPaintWatch()
    BrowseDisarmLoaderTimeout(m)
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
    if task.hasField("control") then task.control = "stop"
end sub

sub CancelInFlightSearch()
    KillSearchTask(m.searchTask)
    m.searchTask = invalid
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
    ApplySearchLoaderColors()
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
    ApplySearchLoaderLayout()
    RebuildGridPositions()
    ApplyGridScroll()
    ApplyEmptyLayout()
end sub

sub ApplyGridViewport()
    if m.gridViewport = invalid then return
    viewH = SR_GridViewHeight()
    m.gridViewport.clippingRect = [0, 0, m.rightW, viewH]
end sub

' searchgrid.tsx: bg-black loader centered in the right 60% column.
sub ApplySearchLoaderLayout()
    viewH = SR_GridViewHeight()
    if m.searchLoaderBg <> invalid then
        m.searchLoaderBg.width = m.rightW
        m.searchLoaderBg.height = viewH
    end if
    if m.searchLoaderCenter <> invalid then
        m.searchLoaderCenter.translation = [Int(m.rightW / 2), Int(viewH / 2)]
    end if
end sub

sub ApplySearchLoaderColors()
    if m.searchLoaderRing <> invalid then m.searchLoaderRing.blendColor = m.cText
    if m.searchLoaderArc <> invalid then m.searchLoaderArc.blendColor = m.cPrimary500
    if m.searchLoaderText <> invalid then m.searchLoaderText.color = m.cText
end sub

function SearchGridCols(panelW as integer) as integer
    ' React searchgrid.tsx: repeat(auto-fill, minmax(300px, 1fr)).
    return GridFlatColsForPanel(panelW, SR_GridMarginLeft(), SR_GridMinCol(), SR_GridGapX())
end function

sub ScheduleSearch()
    CancelInFlightSearch()
end sub

function CurrentSearchKeyword() as string
    kw = m.searchText.Trim()
    if kw = invalid then return ""
    return kw
end function

function SearchKeywordInFlight(keyword as string) as boolean
    if m.searchTask = invalid then return false
    if m.inFlightKeyword <> keyword then return false
    return true
end function

sub CommitPendingSearchIfNeeded()
    kw = CurrentSearchKeyword()
    if kw = m.lastFetchedKeyword then return
    if SearchKeywordInFlight(kw) then return
    print "[SEARCH_DBG] debounce commit kw="; kw
    CommitSearch(kw)
end sub

sub CommitSearch(keyword as string)
    if keyword = invalid then keyword = ""
    if keyword = m.lastFetchedKeyword then return
    FetchSearch(keyword)
end sub

sub FetchSearch(keyword as string)
    if keyword = invalid then keyword = ""
    CancelInFlightSearch()
    StopGridBuild()
    if m.interactIdle <> invalid then m.interactIdle.control = "stop"
    m.interacting = false
    m.gridBuildDeferred = false
    m.gridBuildNeedsFresh = false
    m.searchFetchGen = m.searchFetchGen + 1
    m.pendingSearchGen = m.searchFetchGen
    m.inFlightKeyword = keyword
    m.loading = true
    ' Show right-pane loader as soon as the debounced API fires (replaces any prior results).
    BeginSearchLoading()
    print "[SEARCH_DBG] fetch kw="; keyword; " gen="; m.pendingSearchGen; " cards_before="; m.cardNodes.Count()
    path = SearchBuildPath(keyword, 1, SR_ApiLimit())
    m.searchTask = ApiGet(path)
    m.searchTask.observeField("apiResult", "OnSearchResponse")
    StartHttpTask(m.searchTask)
end sub

sub BeginSearchLoading()
    m.gridScrollY = 0
    m.results = []
    ClearGrid()
    ShowEmpty(false)
    ShowLoading(true)
    ApplyGridScroll()
end sub

sub OnSearchResponse()
    if m.top.dispose = true then return
    if m.searchTask = invalid then return
    responseGen = m.pendingSearchGen
    m.searchTask.unobserveField("apiResult")
    api = m.searchTask.apiResult
    respondedKw = m.inFlightKeyword
    m.searchTask = invalid

    if responseGen <> m.searchFetchGen then
        print "[SEARCH_DBG] stale gen="; responseGen; " current="; m.searchFetchGen; " kw="; respondedKw
        return
    end if

    if respondedKw <> CurrentSearchKeyword() then
        print "[SEARCH_DBG] stale response kw="; respondedKw; " current="; CurrentSearchKeyword()
        return
    end if

    m.inFlightKeyword = ""
    m.lastFetchedKeyword = respondedKw
    m.loading = false

    m.results = SearchParseListing(api)
    count = m.results.Count()

    if count = 0 and Len(m.searchText) > 0 then
        ShowEmpty(true)
        ClearGrid()
        ShowLoading(false)
        return
    end if
    if count = 0 then
        ShowLoading(false)
        return
    end if
    ShowEmpty(false)
    ScheduleGridBuild()
end sub

sub ShowLoading(show as boolean)
    if m.loadingHost <> invalid then m.loadingHost.visible = show
    if m.gridHost <> invalid and m.emptyHost <> invalid and m.emptyHost.visible <> true then
        m.gridHost.visible = not show
    end if
    if show then
        ApplySearchLoaderColors()
        BrowseArmLoaderTimeout(m)
        if m.searchLoaderAnim <> invalid then
            m.searchLoaderAnim.control = "stop"
            m.searchLoaderAnim.control = "start"
        end if
    else
        BrowseDisarmLoaderTimeout(m)
        BrowseDetachHostPaintWatch(m)
        if m.searchLoaderAnim <> invalid then m.searchLoaderAnim.control = "stop"
        if m.searchLoaderSpin <> invalid then m.searchLoaderSpin.rotation = 0.0
        if m.gridHost <> invalid and m.emptyHost <> invalid and m.emptyHost.visible <> true then
            m.gridHost.visible = true
        end if
    end if
end sub

sub DetachSearchPaintWatch()
    BrowseDetachHostPaintWatch(m)
end sub

sub AttachSearchPaintWatch()
    if m.cardNodes.Count() < 1 then return
    card = m.cardNodes[0]
    if card = invalid then return
    thumb = card.findNode("thumb")
    if BrowseAttachThumbPaintWatch(m, thumb, "OnSearchFirstPainted") then OnSearchFirstPainted()
end sub

sub OnSearchFirstPainted()
    TryCompleteSearchReveal()
end sub

function SearchPaintGateOpen() as boolean
    if m.cardNodes.Count() < 1 then return false
    card = m.cardNodes[0]
    if card = invalid then return true
    return BrowseThumbPaintComplete(card.findNode("thumb"))
end function

sub TryCompleteSearchReveal()
    if m.loadingHost = invalid or m.loadingHost.visible <> true then return
    if SearchPaintGateOpen() then CompleteSearchReveal()
end sub

sub CompleteSearchReveal()
    if m.loadingHost = invalid or m.loadingHost.visible <> true then return
    if not SearchPaintGateOpen() then return
    DetachSearchPaintWatch()
    if m.gridHost <> invalid and m.emptyHost <> invalid and m.emptyHost.visible <> true then
        m.gridHost.visible = true
    end if
    ShowLoading(false)
end sub

sub OnBrowseLoaderTimeout()
    if m.loadingHost = invalid or m.loadingHost.visible <> true then return
    CompleteSearchReveal()
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
    StopGridBuild()
    m.gridBuildIdx = 0
    if m.gridHost = invalid then return
    m.gridHost.removeChildrenIndex(m.gridHost.getChildCount(), 0)
    m.cardNodes = []
    m.gridIndex = 0
    m.gridScrollY = 0
end sub

sub ScheduleGridBuild()
    if m.interacting then
        m.gridBuildDeferred = true
        m.gridBuildNeedsFresh = true
        StopGridBuild()
        return
    end if
    m.gridBuildNeedsFresh = false
    StartGridBuild(true)
end sub

' fresh=true clears prior cards; false resumes from gridBuildIdx after input pause.
sub StartGridBuild(fresh as boolean)
    m.gridBuildDeferred = false
    if fresh then
        StopGridBuild()
        m.gridBuildIdx = 0
        m.gridScrollY = 0
        if m.gridHost <> invalid then
            m.gridHost.removeChildrenIndex(m.gridHost.getChildCount(), 0)
        end if
        m.cardNodes = []
        m.gridIndex = 0
        ShowEmpty(false)
    end if
    if m.gridHost = invalid or m.results = invalid then return
    if m.results.Count() = 0 then return
    if m.gridBuildIdx >= m.results.Count() then
        AttachSearchPaintWatch()
        TryCompleteSearchReveal()
        FinishGridBuild()
        return
    end if
    ' Cold load: fill the first viewport synchronously, then progressive rows below.
    if fresh then
        AppendGridRows(SR_SkeletonRows())
        AttachSearchPaintWatch()
        TryCompleteSearchReveal()
    end if
    if m.gridBuildIdx >= m.results.Count() then
        FinishGridBuild()
        return
    end if
    if m.gridBuildTimer <> invalid then m.gridBuildTimer.control = "start"
end sub

sub StopGridBuild()
    if m.gridBuildTimer <> invalid then m.gridBuildTimer.control = "stop"
end sub

sub OnGridBuildTick()
    if m.top.dispose = true then
        StopGridBuild()
        return
    end if
    if m.interacting then
        m.gridBuildDeferred = true
        StopGridBuild()
        return
    end if
    if m.gridHost = invalid or m.results = invalid then
        StopGridBuild()
        return
    end if
    total = m.results.Count()
    if m.gridBuildIdx >= total then
        StopGridBuild()
        AttachSearchPaintWatch()
        TryCompleteSearchReveal()
        FinishGridBuild()
        return
    end if

    AppendGridRows(1)
    AttachSearchPaintWatch()
    TryCompleteSearchReveal()

    if m.gridBuildIdx >= total then
        StopGridBuild()
        FinishGridBuild()
    end if
end sub

' Materialize up to rowCount grid rows from m.gridBuildIdx (one row per call when rowCount=1).
sub AppendGridRows(rowCount as integer)
    if rowCount < 1 then return
    if m.gridHost = invalid or m.results = invalid then return
    total = m.results.Count()
    rowsBuilt = 0
    while rowsBuilt < rowCount and m.gridBuildIdx < total
        rowEnd = m.gridBuildIdx + m.gridCols
        if rowEnd > total then rowEnd = total
        for i = m.gridBuildIdx to rowEnd - 1
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
        m.gridBuildIdx = rowEnd
        rowsBuilt = rowsBuilt + 1
    end while
end sub

sub FinishGridBuild()
    if m.gridIndex >= m.cardNodes.Count() then m.gridIndex = 0
    m.gridIndex = GridClampFlatIndex(m.gridIndex, m.cardNodes.Count())
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
    BeginGridInteraction()
    key = m.keyboard.keyPress
    if key = invalid or key = "" then return
    m.keyboard.keyPress = ""

    if key = "CLEAR" then
        m.searchText = ""
        UpdateInputLabel()
        ResetSearchDebounce()
        CommitEmptySearchRestore()
        return
    end if

    if key = "Backspace" then
        if Len(m.searchText) > 0 then m.searchText = Left(m.searchText, Len(m.searchText) - 1)
    else
        m.searchText = m.searchText + key
    end if
    UpdateInputLabel()
    kw = CurrentSearchKeyword()
    ScheduleSearch()
    if key = "Backspace" and Len(kw) = 0 then
        ResetSearchDebounce()
        CommitEmptySearchRestore()
    else
        PushSearchDebounce()
    end if
end sub

' Restore browse listing (keyword "") — deduped so repeated CLEAR cannot spam the API.
sub CommitEmptySearchRestore()
    kw = ""
    if kw = m.lastFetchedKeyword then return
    if SearchKeywordInFlight(kw) then return
    print "[SEARCH_DBG] restore commit kw="; kw
    FetchSearch(kw)
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
    return GridFlatRowCount(m.cardNodes.Count(), m.gridCols)
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
        m.gridIndex = GridClampFlatIndex(m.gridIndex, m.cardNodes.Count())
        row = GridFlatRowForIndex(m.gridIndex, m.gridCols)
        rowTop = row * SR_CardRowPitch()
        scrollBottom = SearchRowScrollBottom(row)
        pad = SR_GridScrollPad()
        viewH = SR_GridViewHeight()
        lastRow = SearchGridRowCount() - 1
        m.gridScrollY = GridClampFlatScrollY(m.gridScrollY, rowTop, scrollBottom, viewH, pad, row = lastRow)
    end if
    m.gridScrollY = GridClampScrollMax(m.gridScrollY, SearchGridMaxScroll())
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
    if m.focusZone <> "keyboard" then return
    m.keyboard.batchFocusRow = m.keyRow
    m.keyboard.batchFocusCol = m.keyCol
    m.keyboard.callFunc("SetFocusedKey", invalid)
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
    m.gridIndex = GridClampFlatIndex(m.gridIndex, m.cardNodes.Count())
    ApplyInputFocus()
    ApplyGridFocus()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.vm <> invalid and m.vm.shellFocus = "header" then return

    BeginGridInteraction()
    key = ev.key
    if m.focusZone = "input" then
        if key = "up" and NavUpOpensHeaderFromContent() then
            ShellEnterHeader(m.vm, invalid)
            return
        else if key = "left" and NavLeftOpensSidebarFromContent(true) then
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
            fromRow = m.keyRow
            m.keyRow = m.keyRow - 1
            MapKeyColVertical(fromRow, m.keyRow)
        else
            EnterInput()
            return
        end if
    else if key = "down" then
        maxRow = 3
        if m.keyRow < maxRow then
            fromRow = m.keyRow
            m.keyRow = m.keyRow + 1
            MapKeyColVertical(fromRow, m.keyRow)
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
        m.keyboard.batchFocusRow = m.keyRow
        m.keyboard.batchFocusCol = m.keyCol
        m.keyboard.callFunc("SetFocusedKey", invalid)
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

sub MapKeyColVertical(fromRow as integer, toRow as integer)
    if m.keyboard = invalid then
        ClampKeyCol()
        return
    end if
    m.keyboard.navFromRow = fromRow
    m.keyboard.navFromCol = m.keyCol
    m.keyboard.navToRow = toRow
    m.keyCol = m.keyboard.callFunc("MapColForVerticalNav", invalid)
    ClampKeyCol()
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

sub PushSearchDebounce()
    debounceMs = Int(SR_SearchDebounceMs() * 1000 + 0.5)
    if debounceMs < 1 then debounceMs = 1
    m.searchDebounceDeadlineMs = m.searchDebounceClock.TotalMilliseconds() + debounceMs
    if m.searchDebouncePoll <> invalid then m.searchDebouncePoll.control = "start"
end sub

sub StopSearchDebouncePoll()
    if m.searchDebouncePoll <> invalid then m.searchDebouncePoll.control = "stop"
end sub

sub ResetSearchDebounce()
    StopSearchDebouncePoll()
    m.searchDebounceDeadlineMs = 0
end sub

sub OnSearchDebouncePoll()
    if m.searchDebounceDeadlineMs < 1 then return
    now = m.searchDebounceClock.TotalMilliseconds()
    if now < m.searchDebounceDeadlineMs then return
    ResetSearchDebounce()
    CommitPendingSearchIfNeeded()
end sub

sub BeginGridInteraction()
    m.interacting = true
    StopGridBuild()
    if GridBuildIncomplete() then m.gridBuildDeferred = true
    if m.interactIdle <> invalid then
        m.interactIdle.control = "stop"
        m.interactIdle.control = "start"
    end if
end sub

function GridBuildIncomplete() as boolean
    if m.results = invalid then return false
    total = m.results.Count()
    if total = 0 then return false
    return m.gridBuildIdx < total
end function

sub OnGridInteractIdle()
    m.interacting = false
    if m.loading then
        m.gridBuildDeferred = false
        m.gridBuildNeedsFresh = false
        return
    end if
    if not GridBuildIncomplete() then
        m.gridBuildDeferred = false
        m.gridBuildNeedsFresh = false
        return
    end if
    fresh = m.gridBuildNeedsFresh
    m.gridBuildDeferred = false
    m.gridBuildNeedsFresh = false
    StartGridBuild(fresh)
end sub
