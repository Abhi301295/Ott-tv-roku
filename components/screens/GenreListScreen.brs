' GenreListScreen.brs — Movies/Series genre catalogue (parity with features/genre-list/).

sub init()
    m.bg = m.top.findNode("bg")
    m.hero = m.top.findNode("hero")
    m.genreSkeleton = m.top.findNode("genreSkeleton")
    m.rowsHost = m.top.findNode("rowsHost")
    m.rowsAnim = m.top.findNode("rowsAnim")
    m.rowsInterp = m.top.findNode("rowsInterp")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.rowBuildTimer = m.top.findNode("rowBuildTimer")
    m.heroSkeletonTimeout = m.top.findNode("heroSkeletonTimeout")
    m.rowsSkeletonTimeout = m.top.findNode("rowsSkeletonTimeout")

    m.listType = ""
    m.page = 0
    m.hasMore = true
    m.loading = false
    m.initialLoad = true
    m.rowsRevealed = false
    m.categories = []
    m.rowWidgets = []
    m.rowTops = []
    m.rowBuildIndex = 0
    m.rowContentHeight = 0
    m.rowIndex = 0
    m.cardIndex = 0
    m.layoutAnchorY = GL_RowAnchorY()
    m.firstRowWatch = invalid
    m.loadMoreSkeleton = invalid

    m.vm = FindViewManager(m.top)
    LoadGenreTokens()
    ApplyStaticColors()

    if m.rowBuildTimer <> invalid then m.rowBuildTimer.observeField("fire", "OnRowBuildTick")
    if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.observeField("fire", "OnHeroSkeletonTimeout")
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.observeField("fire", "OnRowsSkeletonTimeout")
    if m.rowsAnim <> invalid then m.rowsAnim.observeField("state", "OnRowsAnimState")
    if m.hero <> invalid then m.hero.observeField("posterReady", "OnHeroPosterReady")
    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
    state = m.top.navState
    BrowseDbgState("genre_nav_ready", state)
    if state = invalid then return
    if state.type <> invalid then m.listType = state.type
    BrowseDbg("genre_nav_ready", "listType=" + m.listType)
    if m.listType = "" then
        BrowseDbg("genre_nav_ready", "abort: listType empty")
        return
    end if
    ResetAndFetch()
end sub

sub OnDispose()
    if not m.top.dispose then return
    BrowseDbg("genre_dispose", "stopping timers + row builds + catalogue fetch")
    m.loading = false
    m.hasMore = false
    DetachFirstRowWatch()
    AbortAllGenreRowBuilds()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"
    if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.control = "stop"
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    KillCatalogueTask(m.catalogueTask)
    m.catalogueTask = invalid
    HideLoadMoreSkeleton()
    if m.hero <> invalid then
        m.hero.unobserveField("posterReady")
        m.hero.visible = false
    end if
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
end sub

sub AbortAllGenreRowBuilds()
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("AbortBuild", invalid)
    end for
end sub

sub KillCatalogueTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

sub OnBusinessResolved()
    LoadGenreTokens()
    ApplyStaticColors()
    ApplyHeroTheme()
    RefreshRowThemes()
end sub

sub LoadGenreTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens
    m.cPrimary500 = TCg("primary-500", "#0b75e0")
    m.cPrimary600 = TCg("primary-600", "#0760bb")
    m.cPrimary700 = TCg("primary-700", "#04478b")
    m.cNeutral50 = TCg("neutral-50", "#f5f5f5")
    m.cNeutral700 = TCg("neutral-700", "#404040")
    m.cNeutral800 = TCg("neutral-800", "#262626")
    m.cNeutral950 = TCg("neutral-950", "#0a0a0a")
end sub

function TCg(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

sub ApplyStaticColors()
    if m.bg <> invalid then m.bg.color = "0x0a0a0aff"
    if m.emptyLabel <> invalid then m.emptyLabel.color = "0xf5f5f5ff"
    ApplyHeroTheme()
    ApplySkeletonColors()
end sub

sub ApplyHeroTheme()
    if m.hero = invalid then return
    m.hero.cNeutral50 = m.cNeutral50
    m.hero.cPrimary500 = m.cPrimary500
    m.hero.contentWidth = 1920
end sub

sub ApplySkeletonColors()
    if m.genreSkeleton = invalid then return
    base = CardContrastSkeletonBase("0x0a0a0aff", m.cNeutral700)
    hi = m.cNeutral800
    if hi = invalid or hi = "" then hi = "0x262626ff"
    m.genreSkeleton.baseColor = base
    m.genreSkeleton.highlightColor = hi
    ApplyLoadMoreSkeletonColors()
end sub

sub ApplyLoadMoreSkeletonColors()
    if m.loadMoreSkeleton = invalid then return
    base = CardContrastSkeletonBase("0x0a0a0aff", m.cNeutral700)
    hi = m.cNeutral800
    if hi = invalid or hi = "" then hi = "0x262626ff"
    m.loadMoreSkeleton.baseColor = base
    m.loadMoreSkeleton.highlightColor = hi
end sub

sub ShowLoadMoreSkeleton(show as boolean)
    if not show then
        HideLoadMoreSkeleton()
        return
    end if
    if m.loadMoreSkeleton <> invalid then
        m.loadMoreSkeleton.visible = true
        m.loadMoreSkeleton.running = true
        return
    end if
    sk = CreateObject("roSGNode", "GenreLoadMoreSkeleton")
    if sk = invalid then return
    ' Fixed tail affordance — always visible while the next page fetches (parity React pageLoader).
    sk.translation = [0, 820]
    sk.visible = true
    sk.running = true
    m.top.appendChild(sk)
    m.loadMoreSkeleton = sk
    ApplyLoadMoreSkeletonColors()
    BrowseDbg("genre_loadmore", "shimmer on")
end sub

sub HideLoadMoreSkeleton()
    if m.loadMoreSkeleton = invalid then return
    m.top.removeChild(m.loadMoreSkeleton)
    m.loadMoreSkeleton = invalid
    BrowseDbg("genre_loadmore", "shimmer off")
end sub

sub ResetAndFetch()
    m.page = 0
    m.hasMore = true
    m.categories = []
    m.rowIndex = 0
    m.cardIndex = 0
    m.rowContentHeight = 0
    m.rowsRevealed = false
    m.initialLoad = true
    DetachFirstRowWatch()
    ClearRows()
    ShowEmpty(false)
    if m.rowsHost <> invalid then m.rowsHost.visible = false
    ShowGenreSkeleton(true, true)
    BrowseDbg("genre_boot", "shimmer on — fetch catalogue")
    FetchNextPage()
end sub

sub SyncGenreSkeletonVisible()
    if m.genreSkeleton = invalid then return
    heroOn = m.genreSkeleton.heroRunning
    rowsOn = m.genreSkeleton.rowsRunning
    m.genreSkeleton.visible = heroOn or rowsOn
end sub

' Hero and rows shimmers are independent — hero drops when the poster paints; rows when
' the first strip is ready (parity with HomeScreen OnHeroPosterReady / PrepareFirstRowReveal).
sub ShowHeroSkeleton(show as boolean)
    if m.genreSkeleton = invalid then return
    m.genreSkeleton.heroRunning = show
    if show then
        m.genreSkeleton.visible = true
    else
        if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.control = "stop"
        BrowseDbg("genre_hero", "shimmer off")
    end if
    SyncGenreSkeletonVisible()
end sub

sub ShowRowsSkeleton(show as boolean)
    if m.genreSkeleton = invalid then return
    m.genreSkeleton.rowsRunning = show
    if show then
        m.genreSkeleton.visible = true
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "start"
    else
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
        BrowseDbg("genre_rows", "shimmer off")
    end if
    SyncGenreSkeletonVisible()
end sub

sub ShowGenreSkeleton(hero as boolean, rows as boolean)
    ShowHeroSkeleton(hero)
    ShowRowsSkeleton(rows)
end sub

sub HideGenreSkeleton()
    ShowHeroSkeleton(false)
    ShowRowsSkeleton(false)
    if m.genreSkeleton <> invalid then m.genreSkeleton.visible = false
    BrowseDbg("genre_boot", "shimmer off (all)")
end sub

sub OnHeroPosterReady()
    if m.hero = invalid or m.hero.posterReady <> true then return
    BrowseDbg("genre_hero", "poster ready — hide hero shimmer")
    ShowHeroSkeleton(false)
end sub

sub OnHeroSkeletonTimeout()
    BrowseDbg("genre_hero", "skeleton timeout — force hide hero shimmer")
    ShowHeroSkeleton(false)
end sub

sub FetchNextPage()
    if m.loading then return
    if not m.hasMore then return
    pagination = m.rowsRevealed and m.rowWidgets.Count() > 0
    m.page = m.page + 1
    m.loading = true
    if pagination then ShowLoadMoreSkeleton(true)
    path = Endpoints().SERIES.GENERE_LIST
    q = GL_BuildCatalogueQuery(m.page, m.listType)
    BrowseDbg("genre_fetch", "path=" + path + " page=" + Str(m.page) + " type=" + m.listType + " limit=" + Str(GL_CataloguePageLimit()))
    KillCatalogueTask(m.catalogueTask)
    m.catalogueTask = ApiGetQuery(path, q)
    m.catalogueTask.observeField("apiResult", "OnCatalogueResponse")
    StartHttpTask(m.catalogueTask)
end sub

sub OnCatalogueResponse()
    if m.top.dispose = true then return
    if m.catalogueTask = invalid then return
    m.catalogueTask.unobserveField("apiResult")
    api = m.catalogueTask.apiResult
    m.catalogueTask = invalid
    m.loading = false
    HideLoadMoreSkeleton()
    m.initialLoad = false

    BrowseDbgApi("genre_response", api)
    if api = invalid or api.ok <> true then
        BrowseDbg("genre_response", "fail: api not ok")
        m.hasMore = false
        HideGenreSkeleton()
        if m.categories.Count() = 0 then ShowEmpty(true)
        return
    end if

    listing = []
    if api.result <> invalid and api.result.listing <> invalid then
        listing = api.result.listing
    end if

    added = 0
    for i = 0 to listing.Count() - 1
        cat = GL_NormalizeCategory(listing[i])
        if cat = invalid then continue for
        m.categories.Push(cat)
        added = added + 1
    end for

    m.hasMore = GL_PageHasMore(api, added)
    BrowseDbg("genre_response", "batch=" + Str(listing.Count()) + " added=" + Str(added) + " totalCats=" + Str(m.categories.Count()) + " hasMore=" + BrowseDbgStr(m.hasMore))

    if m.categories.Count() = 0 then
        HideGenreSkeleton()
        BrowseDbg("genre_response", "empty catalogue — show empty state")
        ShowEmpty(true)
        return
    end if

    ShowEmpty(false)
    PrimeHeroFromCategories()
    if m.rowWidgets.Count() = 0 then
        StartRowBuild()
    else
        AppendRowsFrom(m.categories.Count() - added)
        ApplyGenreFocus()
    end if
end sub

sub PrimeHeroFromCategories()
    if m.hero = invalid then return
    item = GL_FocusedItem(m.categories, 0, 0, 0)
    if item = invalid then
        for each cat in m.categories
            if cat <> invalid and cat.result <> invalid and cat.result.Count() > 0 then
                item = cat.result[0]
                exit for
            end if
        end for
    end if
    if item <> invalid then
        m.hero.activeItem = item
        BrowseDbg("genre_hero", "primed title=" + BrowseDbgStr(item.title))
        if m.genreSkeleton <> invalid and m.genreSkeleton.heroRunning = true then
            if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.control = "start"
        end if
        if m.hero <> invalid and m.hero.posterReady = true then OnHeroPosterReady()
    end if
    m.hero.visible = true
end sub

sub StartRowBuild()
    m.rowBuildIndex = 0
    m.rowContentHeight = 0
    m.rowTops = []
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "start"
    BrowseDbg("genre_rows", "build start count=" + Str(m.categories.Count()))
end sub

sub OnRowBuildTick()
    if m.top.dispose = true then
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        return
    end if
    if m.rowBuildIndex >= m.categories.Count() then
        if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
        BrowseDbg("genre_rows", "build complete widgets=" + Str(m.rowWidgets.Count()) + " contentH=" + Str(m.rowContentHeight))
        GenreLogRowTops("build_done")
        if not m.rowsRevealed and m.rowWidgets.Count() > 0 then
            row0 = m.rowWidgets[0]
            if row0 <> invalid and row0.cardCount = 0 then
                PrepareGenreReveal()
            end if
        end if
        return
    end if

    cat = m.categories[m.rowBuildIndex]
    if cat = invalid then
        m.rowBuildIndex = m.rowBuildIndex + 1
        return
    end if

    row = m.rowsHost.createChild("ContentRow")
    ApplyThemeToRow(row)
    if m.rowBuildIndex = 0 then
        row.categoryData = cat
        row.rowPeekVisible = true
        if row.cardCount = 0 then
            PrepareGenreReveal()
        else
            DetachFirstRowWatch()
            m.firstRowWatch = row
            row.observeField("paintedReady", "OnFirstRowPainted")
        end if
    else
        row.callFunc("PrepareShell", cat)
    end if
    row.translation = [0, m.rowContentHeight]
    m.rowTops.Push(m.rowContentHeight)
    m.rowContentHeight = m.rowContentHeight + HC_ContentRowLayoutHeight(cat)
    m.rowWidgets.Push(row)
    ApplyRowFocusState(m.rowWidgets.Count() - 1)
    m.rowBuildIndex = m.rowBuildIndex + 1
end sub

sub AppendRowsFrom(startIdx as integer)
    if startIdx < 0 then startIdx = 0
    y = m.rowContentHeight
    for i = startIdx to m.categories.Count() - 1
        if i < m.rowWidgets.Count() then continue for
        cat = m.categories[i]
        if cat = invalid then continue for
        row = m.rowsHost.createChild("ContentRow")
        ApplyThemeToRow(row)
        row.callFunc("PrepareShell", cat)
        row.translation = [0, y]
        m.rowTops.Push(y)
        y = y + HC_ContentRowLayoutHeight(cat)
        m.rowWidgets.Push(row)
    end for
    m.rowContentHeight = y
end sub

sub OnFirstRowPainted()
    row = invalid
    if m.rowWidgets.Count() > 0 then row = m.rowWidgets[0]
    if row <> invalid and row.hasField("paintedReady") and row.paintedReady <> true then return
    DetachFirstRowWatch()
    BrowseDbg("genre_reveal", "first row painted")
    PrepareGenreReveal()
end sub

sub OnRowsSkeletonTimeout()
    BrowseDbg("genre_reveal", "skeleton timeout — force reveal")
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    if m.rowWidgets.Count() > 0 then
        row0 = m.rowWidgets[0]
        if row0 <> invalid then row0.callFunc("ForceReveal", invalid)
    end if
    if not m.rowsRevealed then PrepareGenreReveal()
end sub

sub PrepareGenreReveal()
    if m.rowsRevealed then return
    m.rowsRevealed = true
    if m.rowsHost <> invalid then m.rowsHost.visible = true
    if m.rowWidgets.Count() > 0 then
        row0 = m.rowWidgets[0]
        if row0 <> invalid then
            row0.opacity = 1.0
            if row0.hasField("rowPeekVisible") then row0.rowPeekVisible = true
        end if
    end if
    ShowRowsSkeleton(false)
    ApplyGenreFocus()
    BrowseDbg("genre_reveal", "rows visible focus applied")
end sub

sub DetachFirstRowWatch()
    if m.firstRowWatch = invalid then return
    if m.firstRowWatch.hasField("paintedReady") then m.firstRowWatch.unobserveField("paintedReady")
    m.firstRowWatch = invalid
end sub

sub ShowEmpty(show as boolean)
    BrowseDbg("genre_empty", "visible=" + BrowseDbgStr(show))
    if m.emptyLabel <> invalid then m.emptyLabel.visible = show
    if m.rowsHost <> invalid then m.rowsHost.visible = not show and m.rowsRevealed
    if m.hero <> invalid then m.hero.visible = not show
    if show then HideGenreSkeleton()
end sub

sub ClearRows()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    HideLoadMoreSkeleton()
    if m.rowsHost = invalid then return
    for i = m.rowsHost.getChildCount() - 1 to 0 step -1
        m.rowsHost.removeChildIndex(i)
    end for
    m.rowWidgets = []
    m.rowTops = []
    m.rowBuildIndex = 0
end sub

sub ApplyThemeToRow(row as object)
    if row = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = true
    row.cPrimary500 = m.cPrimary500
    row.cPrimary600 = m.cPrimary600
    row.cPrimary700 = m.cPrimary700
    row.cNeutral50 = m.cNeutral50
    row.cNeutral800 = m.cNeutral800
    row.cNeutral950 = m.cNeutral950
    row.cNeutral700 = m.cNeutral700
end sub

sub RefreshRowThemes()
    for each row in m.rowWidgets
        ApplyThemeToRow(row)
    end for
end sub

sub UpdateGenreHeroFromFocus()
    if m.hero = invalid then return
    row = invalid
    cardCount = 0
    if m.rowIndex >= 0 and m.rowIndex < m.rowWidgets.Count() then
        row = m.rowWidgets[m.rowIndex]
        if row <> invalid then cardCount = row.cardCount
    end if
    item = GL_FocusedItem(m.categories, m.rowIndex, m.cardIndex, cardCount)
    if item <> invalid then m.hero.activeItem = item
end sub

sub ApplyGenreFocus()
    if m.rowWidgets.Count() = 0 then return
    if not m.rowsRevealed then return

    if m.rowIndex < 0 then m.rowIndex = 0
    if m.rowIndex >= m.rowWidgets.Count() then m.rowIndex = m.rowWidgets.Count() - 1
    ClampCardIndex()
    MaterializeVisibleRows()
    GenreApplyVerticalScroll()

    for i = 0 to m.rowWidgets.Count() - 1
        ApplyRowFocusState(i)
    end for
    UpdateGenreHeroFromFocus()
    MaybeLoadMore()
end sub

function GenreRowsContentHeight() as integer
    if m.rowContentHeight <> invalid and m.rowContentHeight > 0 then return m.rowContentHeight
    if m.rowTops = invalid or m.rowTops.Count() = 0 then return 0
    if m.categories = invalid or m.categories.Count() = 0 then return 0
    lastIdx = m.rowTops.Count() - 1
    if lastIdx < 0 or lastIdx >= m.categories.Count() then return 0
    cat = m.categories[lastIdx]
    if cat = invalid then return 0
    return m.rowTops[lastIdx] + HC_ContentRowLayoutHeight(cat)
end function

sub GenreLogRowTops(tag as string)
    if m.rowTops = invalid then return
    parts = "count=" + Str(m.rowTops.Count())
    for i = 0 to m.rowTops.Count() - 1
        if i > 5 then
            parts = parts + " ..."
            exit for
        end if
        parts = parts + " [" + Str(i) + "]=" + Str(m.rowTops[i])
    end for
    BrowseDbg("genre_scroll", tag + " " + parts)
end sub

' Pin focused row at layout anchor (parity HomeScreen OTT ApplyHomeFocus).
sub GenreApplyVerticalScroll()
    hostY = m.layoutAnchorY
    if m.rowsHost <> invalid then hostY = m.rowsHost.translation[1]
    anchorY = m.layoutAnchorY

    if m.rowTops = invalid or m.rowIndex < 0 or m.rowIndex >= m.rowTops.Count() then
        BrowseDbg("genre_scroll", "skip rowIdx=" + Str(m.rowIndex) + " rowTops=" + Str(m.rowTops.Count()) + " hostY=" + Str(hostY))
        AnimateRowsHost(anchorY)
        return
    end if

    rowTop = m.rowTops[m.rowIndex]
    anchorY = m.layoutAnchorY - rowTop
    contentH = GenreRowsContentHeight()
    viewH = 1080 - m.layoutAnchorY + 80
    maxScroll = contentH - viewH
    if maxScroll > 0 then
        minAnchor = m.layoutAnchorY - maxScroll
        if anchorY < minAnchor then anchorY = minAnchor
    end if
    if anchorY > m.layoutAnchorY then anchorY = m.layoutAnchorY

    screenRowY = anchorY + rowTop
    row0ScreenY = anchorY
    if m.rowTops.Count() > 0 then row0ScreenY = anchorY + m.rowTops[0]
    detail = "pin row=" + Str(m.rowIndex) + " rowTop=" + Str(rowTop) + " hostFrom=" + Str(hostY)
    detail = detail + " hostTo=" + Str(anchorY) + " screenRowY=" + Str(screenRowY) + " row0ScreenY=" + Str(row0ScreenY)
    detail = detail + " anchor=" + Str(m.layoutAnchorY) + " contentH=" + Str(contentH) + " maxScroll=" + Str(maxScroll)
    BrowseDbg("genre_scroll", detail)

    AnimateRowsHost(anchorY)
end sub

' Smooth row pinning (parity HomeScreen AnimateRowsHost / netflixContent 400ms).
sub AnimateRowsHost(targetY as integer)
    if m.rowsHost = invalid then return
    fromY = m.rowsHost.translation[1]
    if Abs(fromY - targetY) < 3 then
        m.rowsHost.translation = [0, targetY]
        MaterializeNearbyRows()
        return
    end if
    if m.rowsAnim = invalid or m.rowsInterp = invalid then
        m.rowsHost.translation = [0, targetY]
        MaterializeNearbyRows()
        return
    end if
    if m.rowsAnim.state = "running" then m.rowsAnim.control = "stop"
    m.rowsInterp.keyValue = [[0, fromY], [0, targetY]]
    m.rowsAnim.control = "start"
    BrowseDbg("genre_scroll", "anim from=" + Str(fromY) + " to=" + Str(targetY))
end sub

sub OnRowsAnimState()
    if m.rowsAnim = invalid then return
    if m.rowsAnim.state <> "stopped" then return
    MaterializeNearbyRows()
end sub

sub MaterializeVisibleRows()
    if not m.rowsRevealed then return
    if m.rowWidgets.Count() = 0 then return
    lo = m.rowIndex
    hi = m.rowIndex + 1
    if m.rowIndex > 0 then lo = m.rowIndex - 1
    for i = lo to hi
        if i >= 0 and i < m.rowWidgets.Count() then
            row = m.rowWidgets[i]
            if row <> invalid then row.callFunc("Materialize", invalid)
        end if
    end for
end sub

sub MaterializeNearbyRows()
    if m.rowWidgets.Count() = 0 then return
    lo = m.rowIndex - 1
    if lo < 0 then lo = 0
    hi = m.rowIndex + 1
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = lo to hi
        row = m.rowWidgets[i]
        if row <> invalid then row.callFunc("Materialize", invalid)
    end for
end sub

sub ApplyRowFocusState(i as integer)
    if i < 0 or i >= m.rowWidgets.Count() then return
    row = m.rowWidgets[i]
    if row = invalid then return
    row.rowFocused = (i = m.rowIndex)
    row.rowDimmed = false
    peek = false
    if i = 0 and not m.rowsRevealed then
        peek = true
    else if m.rowsRevealed and i = 0 and m.rowIndex = 0 then
        peek = true
    end if
    suppressed = (i < m.rowIndex)
    if row.hasField("rowSuppressed") then row.rowSuppressed = suppressed
    if row.hasField("rowPeekVisible") then row.rowPeekVisible = peek
    if i = m.rowIndex then
        row.cardFocusIndex = m.cardIndex
    else
        row.cardFocusIndex = -1
    end if
end sub

sub ClampCardIndex()
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row = invalid then return
    count = row.cardCount
    if count <= 0 then
        m.cardIndex = 0
        return
    end if
    if m.cardIndex >= count then m.cardIndex = count - 1
    if m.cardIndex < 0 then m.cardIndex = 0
end sub

sub MaybeLoadMore()
    if not m.hasMore then return
    if m.loading then return
    if m.rowIndex = m.rowWidgets.Count() - 1 then FetchNextPage()
end sub

sub TryLoadMoreFromDown()
    if not m.hasMore or m.loading then return
    if m.rowIndex = m.rowWidgets.Count() - 1 then FetchNextPage()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if not m.rowsRevealed then return
    if m.categories.Count() = 0 then return

    key = ev.key
    if key = "up" then
        if m.rowIndex > 0 then m.rowIndex = m.rowIndex - 1
        ClampCardIndex()
        ApplyGenreFocus()
    else if key = "down" then
        if m.rowIndex < m.rowWidgets.Count() - 1 then
            m.rowIndex = m.rowIndex + 1
            ClampCardIndex()
            ApplyGenreFocus()
        else
            TryLoadMoreFromDown()
        end if
    else if key = "left" then
        if m.cardIndex > 0 then m.cardIndex = m.cardIndex - 1
        ApplyGenreFocus()
    else if key = "right" then
        row = m.rowWidgets[m.rowIndex]
        if row <> invalid and m.cardIndex < row.cardCount - 1 then m.cardIndex = m.cardIndex + 1
        ApplyGenreFocus()
    else if key = "OK" or key = "ok" then
        OpenFocusedCard()
    end if
end sub

sub OpenFocusedCard()
    if m.rowIndex < 0 or m.rowIndex >= m.categories.Count() then return
    cat = m.categories[m.rowIndex]
    if cat = invalid then return
    row = m.rowWidgets[m.rowIndex]
    cardCount = 0
    if row <> invalid then cardCount = row.cardCount
    NavigateGenreCardSelection(m.vm, cat, m.cardIndex, cardCount, m.listType)
end sub
