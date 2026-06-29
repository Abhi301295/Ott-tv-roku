' GenreListScreen.brs — Movies/Series genre catalogue (parity with features/genre-list/).

sub init()
    m.bg = m.top.findNode("bg")
    m.contentHost = m.top.findNode("contentHost")
    m.hero = m.top.findNode("hero")
    m.genreSkeleton = m.top.findNode("genreSkeleton")
    m.rowsHost = m.top.findNode("rowsHost")
    m.rowsAnim = m.top.findNode("rowsAnim")
    m.rowsInterp = m.top.findNode("rowsInterp")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.rowBuildTimer = m.top.findNode("rowBuildTimer")
    m.prefetchWarmupTimer = m.top.findNode("prefetchWarmupTimer")
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
    m.prefetchWarmupIdx = 1
    m.interacting = false

    m.interactIdle = CreateObject("roSGNode", "Timer")
    m.interactIdle.duration = 0.25
    m.interactIdle.repeat = false
    m.top.appendChild(m.interactIdle)
    m.interactIdle.observeField("fire", "OnGenreInteractIdle")

    m.vm = FindViewManager(m.top)
    LoadGenreTokens()
    ApplyStaticColors()
    if m.hero <> invalid then m.hero.visible = false

    if m.rowBuildTimer <> invalid then m.rowBuildTimer.observeField("fire", "OnRowBuildTick")
    if m.prefetchWarmupTimer <> invalid then m.prefetchWarmupTimer.observeField("fire", "OnPrefetchWarmupTick")
    if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.observeField("fire", "OnHeroSkeletonTimeout")
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.observeField("fire", "OnRowsSkeletonTimeout")
    if m.rowsAnim <> invalid then m.rowsAnim.observeField("state", "OnRowsAnimState")
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
    ApplyGenreShellLayout()
    ResetAndFetch()
end sub

sub ApplyGenreShellLayout()
    header = FindAppHeader(m.top)
    offX = ShellContentOffsetX(header)
    viewportW = ShellContentViewportW(header)
    if m.contentHost <> invalid then m.contentHost.translation = [offX, 0]
    if m.hero <> invalid then
        m.hero.contentWidth = viewportW
        ApplyHeroTheme()
    end if
end sub

sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    if not m.rowsRevealed then return
    if m.categories.Count() = 0 then return
    m.rowIndex = 0
    m.cardIndex = 0
    ApplyGenreFocus()
end sub

sub OnShellLayoutRev()
    ApplyGenreShellLayout()
end sub

sub ClearGenreRowCardFocus()
    for each row in m.rowWidgets
        if row <> invalid and row.hasField("cardFocusIndex") then row.cardFocusIndex = -1
    end for
end sub

sub OnDispose()
    if not m.top.dispose then return
    BrowseDbg("genre_dispose", "stopping timers + row builds + catalogue fetch")
    m.loading = false
    m.hasMore = false
    DetachFirstRowWatch()
    AbortAllGenreRowBuilds()
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.prefetchWarmupTimer <> invalid then m.prefetchWarmupTimer.control = "stop"
    if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"
    if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.control = "stop"
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    if m.interactIdle <> invalid then m.interactIdle.control = "stop"
    KillCatalogueTask(m.catalogueTask)
    m.catalogueTask = invalid
    if m.hero <> invalid then
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
    ApplyGenreShellLayout()
end sub

sub LoadGenreTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    ' Fallbacks mirror HomeScreen LoadThemeTokens / React dark.theme.ts.
    m.cPrimary500 = TokenColor(m.tokens, "primary-500", "#0092ff")
    m.cPrimary600 = TokenColor(m.tokens, "primary-600", "#459adb")
    m.cPrimary700 = TokenColor(m.tokens, "primary-700", "#80bbe9")
    m.cNeutral50 = TokenColor(m.tokens, "neutral-50", "#ffffff")
    m.cNeutral100 = TokenColor(m.tokens, "neutral-100", "#f8f8f8")
    m.cNeutral700 = TokenColor(m.tokens, "neutral-700", "#181818")
    m.cNeutral800 = TokenColor(m.tokens, "neutral-800", "#121212")
    m.cNeutral950 = TokenColor(m.tokens, "neutral-900", "#0a0a0a")
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

sub ApplyStaticColors()
    ' Full-screen chrome stays dark like HomeScreen.xml / HeroBannerOtt (poster covers the rest).
    if m.bg <> invalid then m.bg.color = "0x0a0a0aff"
    if m.emptyLabel <> invalid then
        m.emptyLabel.color = m.cNeutral50
        ApplyEmptyLabelFont()
    end if
    ApplyHeroTheme()
    ApplySkeletonColors()
end sub

sub ApplyEmptyLabelFont()
    if m.emptyLabel = invalid then return
    if m.emptyLabelFont = invalid then
        m.emptyLabelFont = CreateObject("roSGNode", "Font")
        m.emptyLabelFont.uri = "pkg:/fonts/Inter-Bold.ttf"
    end if
    m.emptyLabelFont.size = GL_EmptyTitleFontSize()
    m.emptyLabel.font = m.emptyLabelFont
end sub

sub ApplyHeroTheme()
    if m.hero = invalid then return
    m.hero.cNeutral50 = m.cNeutral50
    m.hero.cPrimary500 = m.cPrimary500
    m.hero.contentWidth = 1920
end sub

sub ApplySkeletonColors()
    if m.genreSkeleton = invalid then return
    colors = SkeletonResolveColors(m.tokens)
    m.genreSkeleton.baseColor = colors.base
    m.genreSkeleton.highlightColor = colors.highlight
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
    if m.hero <> invalid then m.hero.visible = false
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

' Unified loading veil — hero and row shimmers toggle together via ShowGenreSkeleton / HideGenreSkeleton.
sub ShowGenreSkeleton(hero as boolean, rows as boolean)
    if m.genreSkeleton = invalid then return
    m.genreSkeleton.heroRunning = hero
    m.genreSkeleton.rowsRunning = rows
    if hero or rows then
        m.genreSkeleton.visible = true
        if rows and m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "start"
    else
        if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    end if
    SyncGenreSkeletonVisible()
end sub

sub HideGenreSkeleton()
    if m.genreSkeleton = invalid then return
    m.genreSkeleton.heroRunning = false
    m.genreSkeleton.rowsRunning = false
    m.genreSkeleton.visible = false
    if m.heroSkeletonTimeout <> invalid then m.heroSkeletonTimeout.control = "stop"
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    BrowseDbg("genre_boot", "shimmer off (all)")
end sub

sub OnHeroSkeletonTimeout()
    if not m.rowsRevealed then PrepareGenreReveal()
end sub

sub FetchNextPage()
    if m.loading then return
    if not m.hasMore then return
    m.page = m.page + 1
    m.loading = true
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
    end if
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
    if m.interacting then return
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
            row.callFunc("BuildCardsNow", 6)
            PrepareGenreReveal()
        end if
    else
        row.callFunc("PrepareShell", cat)
    end if
    row.translation = [0, m.rowContentHeight]
    m.rowTops.Push(m.rowContentHeight)
    m.rowContentHeight = m.rowContentHeight + HC_ContentRowLayoutHeight(cat)
    m.rowWidgets.Push(row)
    ApplyRowFocusState(m.rowWidgets.Count() - 1)
    if m.rowsRevealed then MaterializePrefetchWindow()
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
    MaterializePrefetchWindow()
end sub

sub OnRowsSkeletonTimeout()
    BrowseDbg("genre_reveal", "skeleton timeout — force reveal")
    if m.rowsSkeletonTimeout <> invalid then m.rowsSkeletonTimeout.control = "stop"
    if m.rowWidgets.Count() > 0 then
        row0 = m.rowWidgets[0]
        if row0 <> invalid then
            row0.callFunc("BuildCardsNow", 6)
            row0.callFunc("ForceReveal", invalid)
        end if
    end if
    if not m.rowsRevealed then PrepareGenreReveal()
end sub

sub PrepareGenreReveal()
    if m.rowsRevealed then return
    if m.rowWidgets.Count() > 0 then
        row0 = m.rowWidgets[0]
        if row0 <> invalid then
            row0.callFunc("BuildCardsNow", 6)
            row0.opacity = 1.0
            if row0.hasField("rowPeekVisible") then row0.rowPeekVisible = true
        end if
    end if
    m.rowsRevealed = true
    HideGenreSkeleton()
    if m.hero <> invalid then m.hero.visible = true
    if m.rowsHost <> invalid then m.rowsHost.visible = true
    WarmGenrePrefetchWindow()
    m.prefetchWarmupIdx = 3
    if m.prefetchWarmupIdx < m.rowWidgets.Count() then ScheduleGenrePrefetchWarmup()
    ApplyGenreFocus()
    if m.vm <> invalid and m.categories.Count() > 0 and not GenreEmptyVisible() then
        wasHeader = false
        if m.vm.shellFocus = "header" then wasHeader = true
        ShellEnterContent(m.vm)
        print "[BROWSE_DBG] genre_focus handoff_to_rows categories="; m.categories.Count(); " fromHeader="; wasHeader
    end if
    BrowseDbg("genre_reveal", "rows visible focus applied")
end sub

sub WarmGenreRow(row as object)
    if row = invalid then return
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", 6)
end sub

' Pre-build the first shell rows at reveal so vertical navigation is instant.
sub WarmGenrePrefetchWindow()
    if m.rowWidgets = invalid then return
    hi = 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = 1 to hi
        WarmGenreRow(m.rowWidgets[i])
    end for
    BrowseDbg("genre_prefetch", "warmup window rows 1.." + Str(hi))
end sub

sub ScheduleGenrePrefetchWarmup()
    m.prefetchWarmupIdx = 1
    if m.prefetchWarmupTimer <> invalid then m.prefetchWarmupTimer.control = "start"
    BrowseDbg("genre_prefetch", "warmup start max=" + Str(GL_PrefetchWarmupMax()))
end sub

sub StopGenrePrefetchWarmup()
    if m.prefetchWarmupTimer <> invalid then m.prefetchWarmupTimer.control = "stop"
end sub

sub OnPrefetchWarmupTick()
    if m.top.dispose = true then
        StopGenrePrefetchWarmup()
        return
    end if
    if m.prefetchWarmupIdx >= GL_PrefetchWarmupMax() then
        StopGenrePrefetchWarmup()
        BrowseDbg("genre_prefetch", "warmup done idx=" + Str(m.prefetchWarmupIdx))
        return
    end if
    if m.prefetchWarmupIdx >= m.rowWidgets.Count() then
        StopGenrePrefetchWarmup()
        BrowseDbg("genre_prefetch", "warmup done widgets=" + Str(m.rowWidgets.Count()))
        return
    end if
    row = m.rowWidgets[m.prefetchWarmupIdx]
    if row <> invalid then WarmGenreRow(row)
    BrowseDbg("genre_prefetch", "warmup row=" + Str(m.prefetchWarmupIdx))
    m.prefetchWarmupIdx = m.prefetchWarmupIdx + 1
end sub

sub DetachFirstRowWatch()
    if m.firstRowWatch = invalid then return
    if m.firstRowWatch.hasField("paintedReady") then m.firstRowWatch.unobserveField("paintedReady")
    if m.firstRowWatch.hasField("built") then m.firstRowWatch.unobserveField("built")
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
    StopGenrePrefetchWarmup()
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
    if row.hasField("rowTitleFontSize") then row.rowTitleFontSize = GL_RowTitleFontSize()
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

sub ApplyGenreFocusWindow()
    if m.rowWidgets.Count() = 0 then return
    lo = m.rowIndex - 1
    if lo < 0 then lo = 0
    hi = m.rowIndex + 2
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    for i = lo to hi
        ApplyRowFocusState(i)
    end for
end sub

' Horizontal nav — sync-build focused card, update focus + banner without scroll work.
sub ApplyGenreCardFocus()
    if m.rowWidgets.Count() = 0 then return
    if not m.rowsRevealed then return
    if m.rowIndex < 0 then m.rowIndex = 0
    if m.rowIndex >= m.rowWidgets.Count() then m.rowIndex = m.rowWidgets.Count() - 1
    ClampCardIndex()
    PrimeFocusedRowCards()
    ApplyGenreFocusWindow()
    UpdateGenreHeroFromFocus()
end sub

sub PrimeFocusedRowCards()
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row = invalid then return
    need = m.cardIndex + 2
    if need < 6 then need = 6
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", need)
    row.callFunc("ResumeBuild", invalid)
    row.callFunc("ForceReveal", invalid)
end sub

sub ApplyGenreFocus()
    if m.rowWidgets.Count() = 0 then return
    if not m.rowsRevealed then return

    if m.rowIndex < 0 then m.rowIndex = 0
    if m.rowIndex >= m.rowWidgets.Count() then m.rowIndex = m.rowWidgets.Count() - 1
    ClampCardIndex()
    PrimeFocusedRow()
    GenreApplyVerticalScroll()
    ApplyGenreFocusWindow()
    UpdateGenreHeroFromFocus()
    MaybeLoadMore()
end sub

' Materialize shell + sync-build visible cards so row navigation never lands on a blank strip.
sub PrimeFocusedRow()
    if not m.rowsRevealed then return
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row = invalid then return
    row.callFunc("Materialize", invalid)
    row.callFunc("BuildCardsNow", 6)
    row.callFunc("ResumeBuild", invalid)
    row.callFunc("ForceReveal", invalid)
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

' Pin focused row at OTT anchor (parity Home). Tail rows use ideal pin when the list
' still fits on screen — avoids the old +80 viewH clamp that pushed the last row to Y=750.
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
    idealAnchorY = m.layoutAnchorY - rowTop
    anchorY = idealAnchorY
    contentH = GenreRowsContentHeight()
    viewH = GL_GenreViewHeight()
    maxScroll = contentH - viewH
    if maxScroll < 0 then maxScroll = 0
    minAnchor = m.layoutAnchorY - maxScroll
    tailPinned = false

    if anchorY < minAnchor then
        contentBottom = idealAnchorY + contentH
        if contentBottom < 1080 then
            anchorY = idealAnchorY
            tailPinned = true
        else
            anchorY = minAnchor
        end if
    end if
    if anchorY > m.layoutAnchorY then anchorY = m.layoutAnchorY

    screenRowY = anchorY + rowTop
    detail = "pin row=" + Str(m.rowIndex) + " rowTop=" + Str(rowTop) + " hostFrom=" + Str(hostY)
    detail = detail + " hostTo=" + Str(anchorY) + " screenRowY=" + Str(screenRowY)
    detail = detail + " contentH=" + Str(contentH) + " maxScroll=" + Str(maxScroll)
    detail = detail + " minAnchor=" + Str(minAnchor) + " tailPinned=" + BrowseDbgStr(tailPinned)
    BrowseDbg("genre_scroll", detail)

    AnimateRowsHost(anchorY)
end sub

' Smooth row scroll (parity Home). Keys snap instantly so scroll never blocks card materialize.
sub AnimateRowsHost(targetY as integer)
    if m.rowsHost = invalid then return
    fromY = m.rowsHost.translation[1]
    if m.interacting then
        if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"
        m.rowsHost.translation = [0, targetY]
        MaterializeNearbyRows()
        return
    end if
    if m.rowsAnim = invalid or m.rowsInterp = invalid or fromY = targetY then
        m.rowsHost.translation = [0, targetY]
        MaterializeNearbyRows()
        return
    end if
    m.rowsInterp.keyValue = [[0, fromY], [0, targetY]]
    m.rowsAnim.control = "start"
    BrowseDbg("genre_scroll", "anim from=" + Str(fromY) + " to=" + Str(targetY))
end sub

sub OnRowsAnimState()
    if m.rowsAnim = invalid then return
    if m.rowsAnim.state <> "stopped" then return
    RunGenrePrefetchPass()
end sub

function GenrePrefetchLo() as integer
    lo = m.rowIndex - 1
    if lo < 0 then lo = 0
    return lo
end function

function GenrePrefetchHi() as integer
    ahead = GL_PrefetchAhead()
    hi = m.rowIndex + ahead
    if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
    return hi
end function

' Materialize shell rows within the prefetch window around focus (parity Home OTT).
sub MaterializePrefetchWindow()
    if not m.rowsRevealed then return
    if m.rowWidgets.Count() = 0 then return
    lo = GenrePrefetchLo()
    hi = GenrePrefetchHi()
    for i = lo to hi
        row = m.rowWidgets[i]
        if row <> invalid then
            row.callFunc("Materialize", invalid)
            row.callFunc("BuildCardsNow", 6)
        end if
    end for
    BrowseDbg("genre_prefetch", "window lo=" + Str(lo) + " hi=" + Str(hi) + " focus=" + Str(m.rowIndex))
end sub

sub RunGenrePrefetchPass()
    if not m.rowsRevealed then return
    PrimeFocusedRow()
    if m.interacting then return
    MaterializePrefetchWindow()
end sub

sub ResumeFocusedRowBuild()
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return
    row = m.rowWidgets[m.rowIndex]
    if row <> invalid then row.callFunc("ResumeBuild", invalid)
end sub

sub PauseGenreRowBuilding(exceptIdx = -1 as integer)
    if m.rowBuildTimer <> invalid then m.rowBuildTimer.control = "stop"
    if m.rowWidgets = invalid then return
    for i = 0 to m.rowWidgets.Count() - 1
        row = m.rowWidgets[i]
        if row <> invalid and i <> exceptIdx then row.callFunc("PauseBuild", invalid)
    end for
end sub

sub ResumeGenreRowBuilding()
    if m.rowBuildTimer <> invalid and m.rowBuildIndex < m.categories.Count() then
        m.rowBuildTimer.control = "start"
    end if
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid then row.callFunc("ResumeBuild", invalid)
    end for
end sub

sub BeginGenreInteraction(primeRowIdx = -1 as integer)
    m.interacting = true
    PauseGenreRowBuilding(primeRowIdx)
    if m.interactIdle <> invalid then
        m.interactIdle.control = "stop"
        m.interactIdle.control = "start"
    end if
end sub

sub OnGenreInteractIdle()
    m.interacting = false
    ResumeGenreRowBuilding()
    RunGenrePrefetchPass()
end sub

sub MaterializeVisibleRows()
    MaterializePrefetchWindow()
end sub

sub MaterializeNearbyRows()
    MaterializePrefetchWindow()
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

function GenreEmptyVisible() as boolean
    if m.emptyLabel = invalid then return false
    return m.emptyLabel.visible = true
end function

sub EnterGenreHeader()
    if m.vm = invalid then return
    menuItems = m.vm.menuItems
    if menuItems = invalid or menuItems.Count() = 0 then
        reels = false
        tm = m.top.getScene().findNode("themeManager")
        if tm <> invalid and tm.reelsEnabled = true then reels = true
        menuItems = HeaderMenuItems(reels)
    end if
    navState = { type: m.listType }
    idx = HeaderSelectedIndexForNav(menuItems, RouteGenere(), navState)
    ShellEnterHeader(m.vm, idx)
end sub

sub TryLoadMoreFromDown()
    if not m.hasMore or m.loading then return
    if m.rowIndex = m.rowWidgets.Count() - 1 then FetchNextPage()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.vm <> invalid and m.vm.shellFocus = "header" then return

    key = ev.key
    navRowIdx = -1
    if m.rowsRevealed and not GenreEmptyVisible() then
        if key = "down" and m.rowIndex < m.rowWidgets.Count() - 1 then
            navRowIdx = m.rowIndex + 1
        else if key = "up" and m.rowIndex > 0 then
            navRowIdx = m.rowIndex - 1
        else if key = "left" or key = "right" then
            navRowIdx = m.rowIndex
        end if
    end if
    BeginGenreInteraction(navRowIdx)

    if GenreEmptyVisible() then
        if key = "up" then EnterGenreHeader()
        return
    end if

    if not m.rowsRevealed then return
    if m.categories.Count() = 0 then return
    if key = "up" then
        if m.rowIndex = 0 then
            ShellEnterHeader(m.vm, invalid)
            ClearGenreRowCardFocus()
            return
        end if
        if m.rowIndex > 0 then m.rowIndex = m.rowIndex - 1
        ClampCardIndex()
        PrimeFocusedRow()
        ApplyGenreFocus()
    else if key = "down" then
        if m.rowIndex < m.rowWidgets.Count() - 1 then
            m.rowIndex = m.rowIndex + 1
            ClampCardIndex()
            PrimeFocusedRow()
            ApplyGenreFocus()
        else
            TryLoadMoreFromDown()
        end if
    else if key = "left" then
        if ThemeIsSidebarHeader() and m.cardIndex = 0 then
            ShellEnterHeader(m.vm, invalid)
            ClearGenreRowCardFocus()
            return
        end if
        if m.cardIndex > 0 then m.cardIndex = m.cardIndex - 1
        ApplyGenreCardFocus()
    else if key = "right" then
        row = m.rowWidgets[m.rowIndex]
        if row <> invalid and m.cardIndex < row.cardCount - 1 then m.cardIndex = m.cardIndex + 1
        print "[BROWSE_DBG] genre_key right cardIndex="; m.cardIndex
        ApplyGenreCardFocus()
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
