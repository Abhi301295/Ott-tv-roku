' HomeFocus.brs — header/hero/rows focus zones and key routing.


sub EnterHeader(animateLayout = true as boolean)
    if m.header = invalid then return
    if not IsHomeForeground() then return
    m.focusZone = "header"
    m.menuIndex = m.header.selectedIndex
    if m.vm <> invalid then
        ShellEnterHeader(m.vm, m.menuIndex)
    else
        m.header.focusedIndex = m.menuIndex
        m.header.headerActive = true
    end if
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(animateLayout)
    ClearAllRowCardFocus()
    ApplyAllRowFocusStates()
    RestoreSavedRowsHostY()
end sub


sub ClearAllRowCardFocus()
    if m.rowWidgets = invalid then return
    for each row in m.rowWidgets
        if row <> invalid and row.hasField("cardFocusIndex") then row.cardFocusIndex = -1
    end for
end sub


sub ExitHeaderToRows()
    if not IsHomeForeground() then return
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    m.savedRowsHostY = invalid
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(true)
    m.focusZone = "rows"
    ApplyHomeFocus()
end sub

' Sidebar header (cases 4/6): expanded menu on Home — focus in menu, not rows.

' Sidebar header (cases 4/6): expanded menu on Home — focus in menu, not rows.
sub EnterSidebarHomeDefault(animateLayout = true as boolean)
    if m.header = invalid then return
    idx = HeaderSelectedIndex(m.menuItems, RouteHome())
    if idx < 0 then idx = 0
    m.menuIndex = idx
    m.header.selectedIndex = idx
    m.header.focusedIndex = idx
    EnterHeader(animateLayout)
end sub

' Sidebar (case 4/6): remember where focus was before opening the expanded menu.

' Sidebar (case 4/6): remember where focus was before opening the expanded menu.
sub RememberHeaderReturnZone()
    if m.focusZone = "hero" then
        m.headerReturnZone = "hero"
        m.headerReturnHeroFocus = m.heroFocus
    else if m.focusZone = "rows" then
        m.headerReturnZone = "rows"
        m.headerReturnRowIndex = m.rowIndex
        m.headerReturnCardIndex = m.cardIndex
    end if
end sub

' Sidebar: LEFT from hero/rows opens the menu. Netflix top bar: UP opens header.
sub EnterHeaderFromContent()
    RememberHeaderReturnZone()
    ' Exact catalogue Y before sidebar width / focus chrome runs — source of truth.
    if m.rowsHost <> invalid then m.savedRowsHostY = m.rowsHost.translation[1]
    EnterHeader()
end sub

' RIGHT leaves sidebar — collapse to icons and restore hero or row focus.
sub ExitHeaderToPrevious()
    if not IsHomeForeground() then return
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    if ThemeIsSidebarHeader() then ApplyLayoutGeometry(true)

    zone = m.headerReturnZone
    if zone = "hero" and HeroAvailable() then
        target = m.headerReturnHeroFocus
        if target = invalid or target = "" then target = "next"
        m.savedRowsHostY = invalid
        EnterHero(target)
        return
    end if

    m.focusZone = "rows"
    if m.headerReturnRowIndex <> invalid then m.rowIndex = m.headerReturnRowIndex
    if m.headerReturnCardIndex <> invalid then m.cardIndex = m.headerReturnCardIndex
    ClampCardIndex()
    m.savedRowsHostY = invalid
    ApplyHomeFocus()
end sub

' Rows ready: Netflix home keeps header focus; OTT / card-focus lands first row card
' (parity Content.tsx setFocus(CONTENT) after categories load).
sub MaybeLandContentFocus()
    if not IsHomeForeground() then return
    if m.rowWidgets = invalid or m.rowWidgets.Count() = 0 then return

    if ThemeIsOttHome() then
        if not m.pendingContentFocus then return
        ' User already navigated (e.g. Down from header) — never steal focus back to row 0.
        if m.userMovedFocus = true then
            m.pendingContentFocus = false
            return
        end if
        ' Sidebar: only collapse into content when focus is still on the Home menu item.
        if not ShellSidebarFocusMatchesPage(m.vm, RouteHome(), "") then
            m.pendingContentFocus = false
            return
        end if
        m.pendingContentFocus = false
        m.rowIndex = 0
        m.cardIndex = 0
        ExitHeaderToRows()
        return
    end if

    if ThemeHasHomeNav() then
        m.pendingContentFocus = false
        ' Do not reset sidebar selection to Home if the user already moved away.
        if ThemeIsSidebarHeader() and not ShellSidebarFocusMatchesPage(m.vm, RouteHome(), "") then
            return
        end if
        if m.focusZone = "header" then
            if m.header <> invalid and m.header.headerActive <> true then
                if ThemeIsSidebarHeader() then
                    EnterSidebarHomeDefault(false)
                else
                    EnterHeader(false)
                end if
            end if
            return
        end if
        if ThemeIsSidebarHeader() then
            EnterSidebarHomeDefault(false)
        else
            EnterHeader(false)
        end if
        return
    end if

    if not m.pendingContentFocus then return
    m.pendingContentFocus = false
    if m.focusZone = "header" then ExitHeaderToRows()
end sub


sub HandleHeaderKey(key as string)
    if ThemeIsSidebarHeader() then
        if key = "up" then
            if m.menuIndex > 0 then
                m.menuIndex = m.menuIndex - 1
                m.header.focusedIndex = m.menuIndex
            end if
        else if key = "down" then
            if m.menuIndex < m.menuItems.Count() - 1 then
                m.menuIndex = m.menuIndex + 1
                m.header.focusedIndex = m.menuIndex
            end if
        else if key = "right" then
            ExitHeaderToPrevious()
        else if key = "OK" or key = "ok" then
            SelectHeaderItem()
        end if
        return
    end if

    if key = "left" then
        if m.menuIndex > 0 then
            m.menuIndex = m.menuIndex - 1
            m.header.focusedIndex = m.menuIndex
        end if
    else if key = "right" then
        if m.menuIndex < m.menuItems.Count() - 1 then
            m.menuIndex = m.menuIndex + 1
            m.header.focusedIndex = m.menuIndex
        end if
    else if key = "down" then
        EnterHeroFromHeader()
    else if key = "OK" or key = "ok" then
        SelectHeaderItem()
    end if
end sub

' ── Hero banner focus zone (parity with the portal arrows / mute button) ─────
' Vertical flow (Netflix carousel):  HEADER ↕ HERO (prev/next/mute) ↕ ROWS.
' OTT / card-focus (HeroBannerCardFocus): no hero focus zone — mute is visual-only.
' UP from row 0 goes straight to HEADER; banner keeps last focused card (React Content).

function HeroAvailable() as boolean
    if m.hero = invalid or m.hero.visible <> true then return false
    ' Card-focus home: never trap D-pad on mute/arrows (React has no CONTENT→mute path).
    if ThemeIsOttHome() then return false
    items = m.hero.bannerItems
    if items = invalid or items.Count() = 0 then return false
    ' Focusable only when there is something to act on: multiple slides (arrows) or a
    ' playing trailer (mute) — mirrors React showing arrows only when items.length > 1.
    return (items.Count() > 1) or (m.hero.trailerPlaying = true)
end function


function HeroMultiSlide() as boolean
    return HeroSlideCount() > 1
end function


function HeroSlideCount() as integer
    if m.hero = invalid then return 0
    items = m.hero.bannerItems
    if items = invalid then return 0
    return items.Count()
end function

' True when the merged category list includes a non-empty Continue Watching row.

' Pick a valid landing control given what is currently available.
function NormalizeHeroTarget(target as string) as string
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)
    if target = "mute" and not playing then target = "next"
    if (target = "prev" or target = "next") and not HeroMultiSlide() then
        if playing then return "mute"
        return "next"
    end if
    if target = "" then target = "next"
    return target
end function


sub EnterHeroOrHeader()
    if not HeroAvailable() then
        if NavUpOpensHeaderFromContent() then EnterHeader()
        return
    end if
    target = "next"
    if m.hero.trailerPlaying = true then target = "mute"
    EnterHero(target)
end sub


sub EnterHeroFromHeader()
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    if HeroAvailable() then
        EnterHero("next")
    else if m.rowWidgets.Count() > 0 then
        ' Single-slide hero (or no trailer): skip arrow chrome — land on rows (React parity).
        ExitHeaderToRows()
    else
        ' Keep header focus active while Home content is still loading.
        EnterHeader()
    end if
end sub


sub EnterHero(target as string)
    if not HeroAvailable() then return
    m.focusZone = "hero"
    if m.vm <> invalid then
        ShellEnterContent(m.vm)
    else if m.header <> invalid then
        m.header.headerActive = false
    end if
    ' Drop any card highlight while the hero is focused.
    for each row in m.rowWidgets
        if row <> invalid then row.cardFocusIndex = -1
    end for
    m.heroFocus = NormalizeHeroTarget(target)
    ApplyHeroFocus()
    ApplyAllRowFocusStates()
    UpdateRowsScrim()
end sub


sub ApplyHeroFocus()
    if m.hero <> invalid then m.hero.focusTarget = m.heroFocus
end sub


sub ClearHeroFocus()
    if m.hero <> invalid then m.hero.focusTarget = ""
end sub


sub EnterRowsFromHero()
    ClearHeroFocus()
    m.focusZone = "rows"
    m.rowIndex = 0
    m.cardIndex = 0
    ApplyHomeFocus()
    UpdateRowsScrim()
end sub


function HeroIsPageFlip() as boolean
    return ThemeHeroBannerStyle() = TC_HeroPageFlip()
end function


function HeroIsParallaxSlide() as boolean
    return ThemeHeroBannerStyle() = TC_HeroParallaxSlide()
end function


function HeroUsesFrostNav() as boolean
    return HeroIsPageFlip() or HeroIsParallaxSlide()
end function


sub HandleHeroKey(key as string)
    multi = HeroMultiSlide()
    playing = (m.hero <> invalid and m.hero.trailerPlaying = true)
    frostNav = HeroUsesFrostNav()

    if key = "up" then
        if ThemeIsSidebarHeader() then
            ' Vertical hero controls only — sidebar is opened with LEFT, not UP.
            if m.heroFocus = "mute" then
                m.heroFocus = "next"
                ApplyHeroFocus()
            end if
        else if m.heroFocus = "mute" then
            m.heroFocus = "next"
            ApplyHeroFocus()
        else
            ClearHeroFocus()
            EnterHeader()
        end if
    else if key = "down" then
        if m.heroFocus = "next" and playing and not frostNav then
            m.heroFocus = "mute"
            ApplyHeroFocus()
        else
            EnterRowsFromHero()
        end if
    else if key = "left" then
        if frostNav and multi then
            if m.hero <> invalid then m.hero.callFunc("HeroGoPrev", invalid)
        else if ThemeIsSidebarHeader() then
            if m.heroFocus = "next" and multi then
                m.heroFocus = "prev"
                ApplyHeroFocus()
            else if m.heroFocus = "mute" then
                EnterRowsFromHero()
            else
                EnterHeaderFromContent()
            end if
        else if m.heroFocus = "next" and multi then
            m.heroFocus = "prev"
            ApplyHeroFocus()
        else if m.heroFocus = "mute" then
            EnterRowsFromHero()
        end if
    else if key = "right" then
        if frostNav and multi then
            if m.hero <> invalid then m.hero.callFunc("HeroGoNext", invalid)
        else if m.heroFocus = "prev" and multi then
            m.heroFocus = "next"
            ApplyHeroFocus()
        end if
    else if key = "OK" or key = "ok" then
        if m.hero = invalid then return
        if frostNav or m.heroFocus = "next" then
            m.hero.callFunc("HeroGoNext", invalid)
        else if m.heroFocus = "prev" then
            m.hero.callFunc("HeroGoPrev", invalid)
        else if m.heroFocus = "mute" then
            m.hero.callFunc("HeroToggleMute", invalid)
        end if
    end if
end sub


sub SelectHeaderItem()
    if m.menuItems = invalid or m.menuIndex < 0 or m.menuIndex >= m.menuItems.Count() then return
    item = m.menuItems[m.menuIndex]
    m.header.selectedIndex = m.menuIndex
    SetValueByKey(SK_SelectedItem(), item.text, "app")

    if item.route = RouteHome() then
        if ThemeIsSidebarHeader() then
            EnterSidebarHomeDefault(true)
        else if m.rowWidgets.Count() > 0 then
            ExitHeaderToRows()
        else
            EnterHeader()
        end if
        return
    end if

    if m.vm <> invalid then
        state = { type: item.type, selectedID: item.text }
        m.vm.callFunc("NavigateReplace", item.route, state)
    end if
end sub

' ── Boot sequence (parity with features/home/index.tsx) ──────────────────────


' Vertical pin for a catalogue row — shared by rows focus and sidebar header (must not jump to top).
function RowsHostAnchorForIndex(rowIdx as integer) as integer
    pitch = m.layoutRowPitch
    if pitch = invalid or pitch <= 0 then pitch = HC_RowPitchForLayout(m.homeLayout)
    if rowIdx < 0 then rowIdx = 0

    if ThemeIsOttHome() and m.rowTops <> invalid and rowIdx < m.rowTops.Count() then
        rowTop = m.rowTops[rowIdx]
        idealAnchorY = m.layoutAnchorY - rowTop
        anchorY = idealAnchorY
        contentH = OttRowsContentHeight()
        if HC_IsDisplayTitleEnabled() then contentH = contentH + HC_CardTitleExtraH()
        viewH = 1080 - m.layoutAnchorY
        maxScroll = contentH - viewH
        if maxScroll < 0 then maxScroll = 0
        minAnchor = m.layoutAnchorY - maxScroll
        if anchorY < minAnchor then
            contentBottom = idealAnchorY + contentH
            if contentBottom < 1080 then
                anchorY = idealAnchorY
            else
                anchorY = minAnchor
            end if
        end if
    else
        idealAnchorY = m.layoutAnchorY - (rowIdx * pitch)
        anchorY = idealAnchorY
        contentH = 0
        if m.rowWidgets <> invalid then contentH = m.rowWidgets.Count() * pitch
        if HC_IsDisplayTitleEnabled() then contentH = contentH + HC_CardTitleExtraH()
        viewH = 1080 - m.layoutAnchorY
        maxScroll = contentH - viewH
        if maxScroll < 0 then maxScroll = 0
        minAnchor = m.layoutAnchorY - maxScroll
        if anchorY < minAnchor then
            contentBottom = idealAnchorY + contentH
            if contentBottom < 1080 then
                anchorY = idealAnchorY
            else
                anchorY = minAnchor
            end if
        end if
    end if
    if anchorY > m.layoutAnchorY then anchorY = m.layoutAnchorY
    return anchorY
end function

function HomePinnedRowIndex() as integer
    if m.focusZone = "header" then
        if m.headerReturnRowIndex <> invalid and m.headerReturnRowIndex >= 0 then
            return m.headerReturnRowIndex
        end if
    end if
    if m.rowIndex <> invalid and m.rowIndex >= 0 then return m.rowIndex
    return 0
end function

' Re-apply vertical pin after sidebar width change (instant — layoutAnim owns the X slide).
sub PinRowsHostToPinnedRow(instant as boolean)
    if m.rowsHost = invalid then return
    if m.savedRowsHostY <> invalid then
        RestoreSavedRowsHostY()
        return
    end if
    anchorY = RowsHostAnchorForIndex(HomePinnedRowIndex())
    if instant then
        was = m.interacting
        m.interacting = true
        AnimateRowsHost(anchorY)
        m.interacting = was
    else
        AnimateRowsHost(anchorY)
    end if
end sub

sub RestoreSavedRowsHostY()
    if m.rowsHost = invalid then return
    if m.savedRowsHostY = invalid then return
    offX = 0
    if m.layoutOffsetX <> invalid then offX = m.layoutOffsetX
    ' Prefer the in-flight sidebar target so we never snap back under an expanded menu.
    if m.pendingLayoutOffX <> invalid then offX = m.pendingLayoutOffX
    ' Stop both anims that write rowsHost.translation — they fight and can snap Y to top.
    if m.rowsAnim <> invalid then m.rowsAnim.control = "stop"
    m.rowsHost.translation = [offX, m.savedRowsHostY]
end sub

sub ApplyHomeFocus()
    if m.rowsHost = invalid then return

    ' Hero focus: park rows at the top peek. Sidebar header: freeze saved scroll Y.
    if m.focusZone = "hero" then
        anchorY = m.layoutAnchorY
    else if m.focusZone = "header" and m.savedRowsHostY <> invalid then
        anchorY = m.savedRowsHostY
    else
        anchorY = RowsHostAnchorForIndex(HomePinnedRowIndex())
    end if

    if m.focusZone = "rows" then
        lo = m.rowIndex - 1
        if lo < 0 then lo = 0
        hi = m.rowIndex + 2
        if hi >= m.rowWidgets.Count() then hi = m.rowWidgets.Count() - 1
        for i = lo to hi
            ApplyRowFocusState(i)
        end for
    else
        for i = 0 to m.rowWidgets.Count() - 1
            ApplyRowFocusState(i)
        end for
    end if

    UpdateRowsScrim()
    ' Per-card hero sync is OTT-only (React Content / HeroBannerCardFocus).
    ' Netflix carousel keeps bannerItems from UpdateHeroBanner — do not defer/flush that path.
    if ThemeIsOttHome() then
        UpdateOttHeroFromFocus()
        m.pendingHeroUpdate = false
    else
        m.pendingHeroUpdate = false
    end if
    SyncHeroAutoAdvanceHold()
    if m.focusZone = "header" and m.savedRowsHostY <> invalid then
        RestoreSavedRowsHostY()
    else
        AnimateRowsHost(anchorY)
    end if
    ScheduleRowPrefetch()
end sub

' Set the focus/dim state for a single row. Pulled out of ApplyHomeFocus so the row-build
' loop can touch only the row it just created instead of re-applying focus to every row on
' every 30ms tick (which also needlessly re-triggers the rows-host scroll animation).
' Materialize deferred row shells within a 1-row prefetch window around focus.

sub ApplyRowFocusState(i as integer)
    if i < 0 or i >= m.rowWidgets.Count() then return
    row = m.rowWidgets[i]
    if row = invalid then return
    row.rowFocused = (m.focusZone = "rows" and i = m.rowIndex)
    row.rowDimmed = (m.focusZone = "rows" and i > m.rowIndex)
    peek = false
    if i = 0 and not m.rowsRevealed then
        peek = true
    else if m.rowsRevealed and i = 0 and m.focusZone = "hero" then
        ' Hero focus: peek the first catalogue row under the banner.
        peek = true
    else if m.rowsRevealed and i = 0 and m.focusZone = "header" and not ThemeIsSidebarHeader() then
        ' Netflix top bar: peek first row while the header is focused.
        peek = true
    end if
    suppressed = false
    if m.focusZone = "rows" then
        suppressed = (i < m.rowIndex)
    else if m.focusZone = "header" and ThemeIsSidebarHeader() then
        ' Keep the same virtualization as the row we left — hide rows above, do not reveal CW.
        pinIdx = HomePinnedRowIndex()
        suppressed = (i < pinIdx)
    else if not peek then
        suppressed = true
    end if
    if row.hasField("rowSuppressed") then row.rowSuppressed = suppressed
    if row.hasField("rowPeekVisible") then row.rowPeekVisible = peek
    if m.focusZone = "rows" and i = m.rowIndex then
        ClampCardIndex()
        row.cardFocusIndex = m.cardIndex
    else
        row.cardFocusIndex = -1
    end if
end sub


sub ApplyAllRowFocusStates()
    if m.rowWidgets = invalid then return
    for i = 0 to m.rowWidgets.Count() - 1
        ApplyRowFocusState(i)
    end for
end sub

' Keep the row backdrop transparent in both loading and loaded states. The row shimmer owns
' the loading affordance, and React/LG keeps the hero visible behind the content rows.

sub ClampCardIndex()
    row = CurrentRow()
    if row = invalid then
        m.cardIndex = 0
        return
    end if
    count = row.cardCount
    if count < 1 then
        m.cardIndex = 0
        return
    end if
    if m.cardIndex < 0 then m.cardIndex = 0
    if m.cardIndex >= count then m.cardIndex = count - 1
end sub


function CurrentRow() as object
    if m.rowIndex < 0 or m.rowIndex >= m.rowWidgets.Count() then return invalid
    return m.rowWidgets[m.rowIndex]
end function


function LastRowIndex() as integer
    return m.rowWidgets.Count() - 1
end function


' ── Key handling ─────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return

    key = ev.key
    ' Ensure catalogue shells exist before computing the destination row (turbo used to
    ' reveal with only CW mounted, so Down computed last=0 and paused every build).
    if m.focusZone = "rows" and m.rowWidgets <> invalid and m.contentRowCats <> invalid then
        if m.rowWidgets.Count() < m.contentRowCats.Count() then MountRemainingRowShells()
    end if
    ' Give the render thread exclusively to focus and row translation for this key.
    BeginInteraction()

    if m.focusZone = "header" then
        HandleHeaderKey(key)
        return
    end if

    if AnyBootLoading() then return

    if m.focusZone = "hero" then
        HandleHeroKey(key)
        return
    end if

    if m.rowWidgets.Count() = 0 then
        if key = "up" and NavUpOpensHeaderFromContent() then EnterHeroOrHeader()
        return
    end if

    if key = "left" then
        if ThemeIsSidebarHeader() and m.cardIndex = 0 then
            EnterHeaderFromContent()
        else if m.cardIndex > 0 then
            m.cardIndex = m.cardIndex - 1
            ApplyHomeFocus()
        end if
    else if key = "right" then
        row = CurrentRow()
        if row <> invalid and m.cardIndex < row.cardCount - 1 then
            m.cardIndex = m.cardIndex + 1
            ApplyHomeFocus()
        end if
    else if key = "up" then
        if m.rowIndex > 0 then
            m.rowIndex = m.rowIndex - 1
            ClampCardIndex()
            ApplyHomeFocus()
        else if NavUpOpensHeaderFromContent() then
            EnterHeroOrHeader()
        else if HeroAvailable() then
            EnterHero("next")
        end if
    else if key = "down" then
        if m.rowIndex < LastRowIndex() then
            m.rowIndex = m.rowIndex + 1
            ClampCardIndex()
            ApplyHomeFocus()
        else if m.hasMore and not m.loadingMore then
            LoadMoreCategories()
        end if
    else if key = "OK" or key = "ok" then
        HandleCardSelection()
    end if
end sub

' ── Input-priority build throttling ───────────────────────────────────────────
' Pause progressive row/card building the instant the user presses a key, so creating
' card nodes never steals render-thread time from a slide change or navigation. The idle
' timer is reset on every key, so building only resumes once the user pauses (0.25s).

sub HandleCardSelection()
    if m.rowIndex < 0 or m.rowIndex >= m.contentRowCats.Count() then return
    row = CurrentRow()
    if row = invalid then return
    cat = m.contentRowCats[m.rowIndex]
    NavigateHomeCardSelection(m.vm, cat, m.cardIndex, row.cardCount)
end sub


sub LoadMoreCategories()
    if not m.hasMore or m.loadingMore then return
    m.loadingMore = true
    m.page = m.page + 1
    path = Endpoints().HOME.CATEGORY_LIST
    m.loadMoreTask = ApiGetQuery(path, HomeCategoryQuery(m.page))
    m.loadMoreTask.observeField("apiResult", "OnLoadMoreResponse")
    StartHttpTask(m.loadMoreTask)
end sub


sub OnLoadMoreResponse()
    if m.top.dispose = true then return
    m.loadingMore = false
    if m.loadMoreTask = invalid then return
    api = m.loadMoreTask.apiResult
    if api = invalid then return
    prevCatCount = m.contentRowCats.Count()
    if api.ok and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        if listing.Count() > 0 then
            m.categories = AppendCategories(m.categories, listing)
            m.contentRowCats = FilterContentRows(m.categories)
            m.hasMore = true
            UpdateHeroBanner()
            ' Append-only: keep existing row nodes and build only the new categories.
            if m.contentRowCats.Count() > prevCatCount then
                m.rowBuildIndex = prevCatCount
                if ThemeIsOttHome() and m.rowContentHeight <> invalid and m.rowContentHeight > 0 then
                    m.rowBuildY = m.rowContentHeight
                else
                    m.rowBuildY = prevCatCount * m.layoutRowPitch
                end if
                m.rowsHost.visible = true
                m.rowBuildTimer.control = "start"
            end if
            if m.rowIndex < prevCatCount then
                m.rowIndex = prevCatCount
                m.cardIndex = 0
            end if
            ApplyHomeFocus()
        else
            m.hasMore = false
        end if
    else
        m.hasMore = false
    end if
end sub
