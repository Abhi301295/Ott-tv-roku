sub init()
    m.rowTitle = m.top.findNode("rowTitle")
    m.cardsHost = m.top.findNode("cardsHost")
    m.cards = []
    m.cardWidths = []
    m.cardItemIds = []
    m.suppressCategoryRebuild = false
    m.seeAllOrientation = HC_CardTypeVertical()
    if m.rowTitle <> invalid then m.rowTitle.opacity = 0.0
    ApplyRowTitleFont()

    ' Cards are built progressively (a small chunk per tick) instead of all-at-once.
    ' Creating a full row's cards synchronously blocks the render thread for hundreds of
    ' ms to seconds (measured), which freezes the hero. Chunking lets the thread breathe.
    m.buildPlan = []
    m.buildIdx = 0
    m.buildX = 0
    m.pendingMediaLoads = 0
    m.buildComplete = false
    ' True only while a real card build is mid-flight (StartCardBuild ran but hasn't
    ' finished). Shells have a plan but are NOT active, so resume must skip them.
    m.buildActive = false
    m.shellCat = invalid
    m.cardTimer = CreateObject("roSGNode", "Timer")
    m.cardTimer.duration = 0.01
    m.cardTimer.repeat = true
    m.top.appendChild(m.cardTimer)
    m.cardTimer.observeField("fire", "OnCardBuildTick")

    ' Safety net: if a thumbnail never reports back, force the reveal so the
    ' shimmer can't sit on screen forever.
    m.revealTimer = CreateObject("roSGNode", "Timer")
    m.revealTimer.duration = 4
    m.revealTimer.repeat = false
    m.top.appendChild(m.revealTimer)
    m.revealTimer.observeField("fire", "OnRevealSafety")

    ' Defer paintedReady until the first on-screen card has a painted thumbnail.
    m.paintTimer = CreateObject("roSGNode", "Timer")
    m.paintTimer.duration = 0.05
    m.paintTimer.repeat = false
    m.top.appendChild(m.paintTimer)
    m.paintTimer.observeField("fire", "OnPaintPoll")
    m.cwPerfSpan = invalid
    m.paintPollCount = 0
    m.paintStableCount = 0
    m.bootThumbsReleased = false
    m.pendingSkelSlots = []
end sub

sub OnCategoryChanged()
    if m.suppressCategoryRebuild = true then
        m.suppressCategoryRebuild = false
        return
    end if
    BuildRowCards()
end sub

sub OnRowTitleFontChanged()
    ApplyRowTitleFont()
end sub

sub ApplyRowTitleFont()
    if m.rowTitle = invalid then return
    size = m.top.rowTitleFontSize
    if size = invalid or size < 12 then size = 41
    font = m.rowTitle.font
    if font = invalid then
        font = CreateObject("roSGNode", "Font")
        font.uri = "pkg:/fonts/Inter-Bold.ttf"
        m.rowTitle.font = font
    end if
    font.size = size
end sub

sub OnThemeChanged()
    ApplyRowTheme()
    OnCardFocusChanged()
end sub

sub OnCardFocusChanged()
    ApplyCardFocus()
    ScrollToFocusedCard()
end sub

sub OnRowVisualChanged()
    ' React row virtualization: focused=1, past=0.01, upcoming=0.4.
    if m.top.rowFocused = true then
        m.top.opacity = 1.0
        if m.top.ottRowReveal = true then
            if m.rowTitle <> invalid then m.rowTitle.opacity = 1.0
            if m.cards.Count() > 0 then RevealStripNow()
        end if
    else if m.top.rowSuppressed = true then
        m.top.opacity = 0.01
    else if m.top.rowPeekVisible = true then
        m.top.opacity = 1.0
    else if m.top.rowDimmed = true then
        m.top.opacity = 0.4
    else
        m.top.opacity = 1.0
    end if
end sub

' Plan the row synchronously (cheap), then build the card nodes progressively on a timer.
sub BuildRowCards()
    ClearCards()
    cat = m.top.categoryData
    if cat = invalid then return
    m.shellCat = invalid
    StartCardBuild(cat)
end sub

' Title + cardCount only — card nodes are deferred until Materialize() (off-screen rows).
function PrepareShell(cat as object) as boolean
    if cat = invalid then return false
    ClearCards()
    m.shellCat = cat
    plan = PlanRowCards(cat)
    if plan = invalid then return false
    m.buildPlan = plan
    m.top.cardCount = m.buildPlan.Count()
    m.top.built = false
    m.top.mediaReady = false
    m.top.paintedReady = false
    m.buildComplete = false
    m.buildActive = false
    if m.cardsHost <> invalid then m.cardsHost.opacity = 0.0
    return true
end function

' Build deferred card nodes for a shell row (focus prefetch or background warm-up).
function Materialize() as boolean
    if m.buildComplete then return false
    if m.shellCat = invalid then return false
    cat = m.shellCat
    m.shellCat = invalid
    StartCardBuild(cat)
    return true
end function

' Suspend this row's progressive card build so the render thread is free for user input
' (hero slide changes, navigation). Build state (buildIdx) is preserved for resume.
function PauseBuild(dummy = invalid as dynamic) as boolean
    if m.cardTimer <> invalid then m.cardTimer.control = "stop"
    return true
end function

' Resume a paused build only if there are still cards left to create.
function ResumeBuild(dummy = invalid as dynamic) as boolean
    ' Only revive a genuinely in-flight build — never auto-start a shell row (which would
    ' break lazy off-screen loading).
    if not m.buildActive then return false
    if m.buildComplete then return false
    if m.buildPlan = invalid then return false
    if m.buildIdx >= m.buildPlan.Count() then return false
    if m.cardTimer <> invalid then m.cardTimer.control = "start"
    return true
end function

' Safety net for Home rows shimmer timeout — finish the card build first, then reveal.
function ForceReveal(dummy = invalid as dynamic) as boolean
    if not m.buildComplete then
        CwPerfInstant("row ForceReveal — accelerating card build")
        if m.cardTimer <> invalid then
            m.cardTimer.duration = 0.001
            m.cardTimer.control = "start"
        end if
        if m.revealTimer <> invalid then m.revealTimer.control = "start"
        return true
    end if
    OnRevealSafety()
    return true
end function

' Screen dispose — stop every timer and abandon any in-progress build.
function AbortBuild(dummy = invalid as dynamic) as boolean
    if m.cardTimer <> invalid then m.cardTimer.control = "stop"
    if m.revealTimer <> invalid then m.revealTimer.control = "stop"
    if m.paintTimer <> invalid then m.paintTimer.control = "stop"
    ClearPendingSkeletonSlots()
    m.buildActive = false
    return true
end function

' Cheap planning pass shared by immediate and deferred builds.
function PlanRowCards(cat as object) as object
    if cat = invalid then return invalid

    rowType = ""
    if cat.type <> invalid then rowType = cat.type
    cardType = HC_CardTypeVertical()
    if cat.cardType <> invalid and cat.cardType <> "" then cardType = cat.cardType
    if cardType = HC_CardTypeHorizontal() then m.seeAllOrientation = HC_CardTypeHorizontal()

    title = ""
    if cat.name <> invalid then title = cat.name
    m.rowTitle.text = title
    m.rowTitle.color = m.top.cNeutral50
    m.rowTitle.opacity = 0.0

    items = cat.result
    if items = invalid or items.Count() = 0 then return invalid

    compName = CardComponentForRow(rowType, cardType)
    if compName = "BannerCard" and rowType <> HC_PromotionalCard() then return invalid

    maxItems = items.Count()
    if rowType <> HC_PromotionalCard() then
        limit = HC_SeeAllThreshold() + 1
        if maxItems > limit then maxItems = limit
    else
        maxItems = 1
    end if

    plan = []
    for i = 0 to maxItems - 1
        item = items[i]
        if item <> invalid then
            plan.Push({ kind: "card", item: item, comp: compName, cardType: cardType, rank: i })
        end if
    end for
    if rowType <> HC_PromotionalCard() and items.Count() >= HC_SeeAllThreshold() + 1 then
        plan.Push({ kind: "seeAll" })
    end if
    return plan
end function

sub StartCardBuild(cat as object)
    plan = PlanRowCards(cat)
    if plan = invalid then return

    m.cwPerfSpan = CreateObject("roTimespan")
    m.paintPollCount = 0
    m.paintStableCount = 0
    m.bootThumbsReleased = false
    CwPerfMark(m.cwPerfSpan, "row StartCardBuild", "cards=" + Str(plan.Count()))
    if m.top.bootPaintCardCount > 0 then
        HomeLoaderLog("row StartCardBuild", "plan=" + Str(plan.Count()) + " bootWindow=" + Str(m.top.bootPaintCardCount) + " progressive=1card/tick")
    end if

    m.buildPlan = plan
    m.top.cardCount = m.buildPlan.Count()
    m.top.mediaReady = false
    m.top.paintedReady = false
    m.buildIdx = 0
    m.buildX = 0
    m.pendingMediaLoads = 0
    m.buildComplete = false
    m.buildActive = true
    if m.revealTimer <> invalid then m.revealTimer.control = "stop"

    ' Boot / peek rows show skeleton cards while thumbs load (React continueWatchCard).
    ' Other rows keep the strip hidden until media is ready.
    if RowShowsSkeletonFirst() then
        if m.cardsHost <> invalid then m.cardsHost.opacity = 1.0
        if m.rowTitle <> invalid then m.rowTitle.opacity = 1.0
    else if m.cardsHost <> invalid then
        m.cardsHost.opacity = 0.0
    end if
    m.top.built = false

    if m.buildPlan.Count() > 0 then
        ' Shimmer slots for every plan item not yet a real card (React mounts all CW cards at once).
        EnsurePendingSkeletonSlots()
        if m.top.bootPaintCardCount > 0 then
            ' Home calls BuildCardsNow next — keep the progressive timer off so it cannot
            ' race ahead and replace skeleton slots before the sync window runs.
            if m.cardTimer <> invalid then m.cardTimer.control = "stop"
        else if m.top.deferCardBuild = true then
            ' Catalogue first paint owns the start time so skeleton slots reach the
            ' compositor before real card nodes begin replacing them.
            if m.cardTimer <> invalid then m.cardTimer.control = "stop"
        else
            m.cardTimer.control = "start"
        end if
    else
        m.buildComplete = true
        m.buildActive = false
        RevealNow()
    end if
end sub

function RowShowsSkeletonFirst() as boolean
    if m.top.bootPaintCardCount > 0 then return true
    if m.top.ottRowReveal = true then return true
    return false
end function

' Only count cards that intersect the first-screen strip toward the reveal gate.
sub TrackCardMediaLoad(card as object, compName as string)
    if card = invalid then return
    if compName = "SeeAllCard" then return
    if m.buildX >= 1920 then return

    if compName = "ContinueWatchCard" and card.hasField("loaded") then
        m.pendingMediaLoads = m.pendingMediaLoads + 1
        if card.loaded = true then
            OnCardMediaLoaded()
        else
            card.observeField("loaded", "OnCardMediaLoaded")
        end if
        return
    end if

    thumb = card.findNode("thumb")
    if thumb = invalid then return
    m.pendingMediaLoads = m.pendingMediaLoads + 1
    st = thumb.loadStatus
    if st = "ready" or st = "failed" then
        OnCardMediaLoaded()
    else
        thumb.observeField("loadStatus", "OnThumbLoadStatusChanged")
    end if
end sub

sub OnThumbLoadStatusChanged(event as object)
    node = event.getRoSGNode()
    if node = invalid then return
    st = node.loadStatus
    if st <> "ready" and st <> "failed" then return
    node.unobserveField("loadStatus")
    OnCardMediaLoaded()
end sub

sub OnCardBuildTick()
    if m.buildIdx >= m.buildPlan.Count() then
        m.cardTimer.control = "stop"
        return
    end if

    ' Boot row: pause progressive build until the boot paint window is ready, then resume.
    if m.top.bootPaintCardCount > 0 and m.top.paintedReady <> true then
        target = m.top.bootPaintCardCount
        if m.buildPlan <> invalid and m.buildPlan.Count() < target then target = m.buildPlan.Count()
        if m.cards.Count() >= target then
            m.cardTimer.control = "stop"
            ' Sync BuildCardsNow can fill the window without going through Append+MaybeBootPaintProgress —
            ' arm the paint poll so paintedReady can fire and ResumeBootCardBuildIfNeeded continues.
            MaybeStartPaintGate()
            return
        end if
    end if

    AppendNextCardFromPlan()
    MaybeBootPaintProgress()
    FinishCardBuildIfDone()
end sub

sub MaybeBootPaintProgress()
    if m.top.bootPaintCardCount < 1 then return
    if m.cards.Count() = 0 then return
    if m.rowTitle <> invalid and m.rowTitle.opacity < 1.0 then m.rowTitle.opacity = 1.0
    if m.cardsHost <> invalid and m.cardsHost.opacity < 1.0 then m.cardsHost.opacity = 1.0
    HomeLoaderLog("row0 card built", "idx=" + Str(m.buildIdx) + "/" + Str(m.buildPlan.Count()) + " " + BootWindowPaintProgress())
    MaybeStartPaintGate()
end sub

sub ResumeBootCardBuildIfNeeded()
    if m.top.bootPaintCardCount < 1 then return
    if m.buildComplete then return
    if m.buildIdx >= m.buildPlan.Count() then return
    if m.cardTimer <> invalid then m.cardTimer.control = "start"
end sub

sub AppendNextCardFromPlan()
    if m.buildPlan = invalid then return
    if m.buildIdx >= m.buildPlan.Count() then return

    PopPendingSkeletonSlot()

    plan = m.buildPlan[m.buildIdx]
    gap = HC_CardGap()

    if plan.kind = "seeAll" then
        seeAll = m.cardsHost.createChild("SeeAllCard")
        seeAll.orientation = m.seeAllOrientation
        CardInjectTheme(seeAll, m.top.cPrimary500, m.top.cPrimary600, m.top.cPrimary700, m.top.cNeutral50, m.top.cNeutral800, m.top.cNeutral700)
        seeAll.translation = [m.buildX, 0]
        w = CardComponentWidth("SeeAllCard", m.seeAllOrientation)
        m.cards.Push(seeAll)
        m.cardWidths.Push(w)
        m.cardItemIds.Push("__see_all__")
        m.buildX = m.buildX + w + gap
    else
        card = m.cardsHost.createChild(plan.comp)
        ConfigureCard(card, plan.comp, plan.item, plan.cardType, plan.rank)
        card.translation = [m.buildX, 0]
        TrackCardMediaLoad(card, plan.comp)
        w = CardComponentWidth(plan.comp)
        m.cards.Push(card)
        m.cardWidths.Push(w)
        itemId = ""
        if plan.item <> invalid and plan.item._id <> invalid then itemId = plan.item._id
        m.cardItemIds.Push(itemId)
        m.buildX = m.buildX + w + gap
    end if

    m.buildIdx = m.buildIdx + 1

    newCard = m.cards[m.cards.Count() - 1]
    if newCard <> invalid and newCard.hasField("focusedState") then
        newCard.focusedState = ((m.cards.Count() - 1) = m.top.cardFocusIndex)
    end if
end sub

sub FinishCardBuildIfDone()
    if m.buildIdx < m.buildPlan.Count() then return
    m.cardTimer.control = "stop"
    if m.cardTimer <> invalid then m.cardTimer.duration = 0.01
    ClearPendingSkeletonSlots()
    OnCardFocusChanged()
    m.buildComplete = true
    m.buildActive = false
    m.top.built = true
    if m.pendingMediaLoads > 0 and m.revealTimer <> invalid then
        m.revealTimer.control = "start"
    end if
    MaybeReveal()
end sub

sub RevealStripNow()
    if m.rowTitle <> invalid then m.rowTitle.opacity = 1.0
    if m.cardsHost <> invalid then m.cardsHost.opacity = 1.0
end sub

' Sync-build cards. Boot window mounts skeleton cards immediately (React CW placeholders).
function BuildCardsNow(maxCards as dynamic) as boolean
    limit = 6
    if maxCards <> invalid then
        if Type(maxCards) = "roInt" or Type(maxCards) = "Integer" then limit = maxCards
        if Type(maxCards) = "roFloat" or Type(maxCards) = "Float" then limit = Int(maxCards)
    end if
    if limit < 1 then limit = 1
    if m.buildPlan = invalid or m.buildPlan.Count() = 0 then return false
    if not m.buildActive and not m.buildComplete then return false

    if m.cardTimer <> invalid then m.cardTimer.control = "stop"

    ' First-screen boot cards: create nodes now so skeleton + progress show under the data gate.
    if m.top.bootPaintCardCount > 0 then
        target = m.top.bootPaintCardCount
        if m.buildPlan.Count() < target then target = m.buildPlan.Count()
        if limit < target then target = limit
        while m.cards.Count() < target and m.buildIdx < m.buildPlan.Count()
            AppendNextCardFromPlan()
        end while
        RevealStripNow()
        EnsurePendingSkeletonSlots()
        MaybeStartPaintGate()
        HomeLoaderLog("row0 skeleton window", "cards=" + Str(m.cards.Count()) + " idx=" + Str(m.buildIdx) + "/" + Str(m.buildPlan.Count()))
        if m.buildIdx >= m.buildPlan.Count() then
            FinishCardBuildIfDone()
        else if m.cardTimer <> invalid then
            m.cardTimer.duration = 0.01
            m.cardTimer.control = "start"
        end if
        return true
    end if

    n = 0
    while n < limit and m.buildIdx < m.buildPlan.Count()
        AppendNextCardFromPlan()
        n = n + 1
    end while

    if m.top.ottRowReveal = true and m.cards.Count() > 0 then
        RevealStripNow()
        EnsurePendingSkeletonSlots()
    end if
    if m.buildIdx >= m.buildPlan.Count() then
        FinishCardBuildIfDone()
    else
        if m.top.ottRowReveal = true and m.cards.Count() > 0 then MaybeStartPaintGate()
        if m.cardTimer <> invalid then m.cardTimer.control = "start"
    end if
    return true
end function

' Lightweight shimmer slots for plan items not yet built as real cards (CW progressive mount).
sub ClearPendingSkeletonSlots()
    if m.pendingSkelSlots = invalid then
        m.pendingSkelSlots = []
        return
    end if
    for each slot in m.pendingSkelSlots
        if slot = invalid then continue for
        parent = slot.getParent()
        if parent <> invalid then parent.removeChild(slot)
    end for
    m.pendingSkelSlots = []
end sub

sub PopPendingSkeletonSlot()
    if m.pendingSkelSlots = invalid or m.pendingSkelSlots.Count() = 0 then return
    slot = m.pendingSkelSlots[0]
    m.pendingSkelSlots.Delete(0)
    if slot = invalid then return
    parent = slot.getParent()
    if parent <> invalid then parent.removeChild(slot)
end sub

sub EnsurePendingSkeletonSlots()
    if not RowShowsSkeletonFirst() then return
    if m.buildPlan = invalid or m.cardsHost = invalid then return
    ClearPendingSkeletonSlots()
    if m.buildIdx >= m.buildPlan.Count() then return

    gap = HC_CardGap()
    x = m.buildX
    skColors = CardHomeCardSkeletonColors()
    for i = m.buildIdx to m.buildPlan.Count() - 1
        plan = m.buildPlan[i]
        if plan = invalid then continue for
        w = 256
        h = 286
        isCw = false
        showTitleSkel = false
        if plan.kind = "seeAll" then
            w = CardComponentWidth("SeeAllCard", m.seeAllOrientation)
            h = HC_CardPosterHeight("SeeAllCard")
        else if plan.comp <> invalid then
            w = CardComponentWidth(plan.comp)
            h = HC_CardPosterHeight(plan.comp)
            showTitleSkel = HC_CardUsesDisplayTitle(plan.comp)
            if plan.comp = "ContinueWatchCard" then isCw = true
        end if

        posterW = w - 6
        if posterW < 1 then posterW = w

        slot = m.cardsHost.createChild("Group")
        slot.translation = [x, 0]
        bg = slot.createChild("Rectangle")
        bg.translation = [3, 3]
        bg.width = posterW
        bg.height = h
        bg.color = CardWhite10Color()
        sk = slot.createChild("Skeleton")
        sk.translation = [3, 3]
        sk.boxWidth = posterW
        sk.boxHeight = h
        CardApplySkeleton(sk, skColors.base, skColors.highlight)
        if sk.hasField("running") then sk.running = true
        if isCw then
            track = slot.createChild("Rectangle")
            track.translation = [3, 3 + h - 8]
            track.width = posterW
            track.height = 8
            track.color = CardWhite10Color()
        end if
        if showTitleSkel then
            titleW = HC_CardTitleShimmerWidth(posterW)
            titleH = HC_CardTitleShimmerH()
            titleX = 3 + Int((posterW - titleW) / 2)
            titleY = 3 + h + HC_CardTitleShimmerGap()
            titleSk = slot.createChild("Skeleton")
            titleSk.translation = [titleX, titleY]
            titleSk.boxWidth = titleW
            titleSk.boxHeight = titleH
            if titleSk.hasField("shapeUri") then titleSk.shapeUri = SkeletonProfileNameShapeUri()
            CardApplySkeleton(titleSk, skColors.base, skColors.highlight)
            if titleSk.hasField("running") then titleSk.running = true
        end if
        m.pendingSkelSlots.Push(slot)
        x = x + w + gap
    end for
end sub

' Show the strip once card nodes exist. Boot/peek rows keep skeletons visible while
' thumbs load (React continueWatchCard). Other rows wait for media so painted cards swap in.
sub MaybeReveal()
    if not m.buildComplete then return
    if RowShowsSkeletonFirst() then
        RevealNow()
        return
    end if
    if m.pendingMediaLoads > 0 then return
    RevealNow()
end sub

sub RevealNow()
    if m.revealTimer <> invalid then m.revealTimer.control = "stop"
    if m.paintTimer <> invalid then m.paintTimer.control = "stop"
    if m.rowTitle <> invalid then m.rowTitle.opacity = 1.0
    if m.cardsHost <> invalid then m.cardsHost.opacity = 1.0
    m.top.built = true
    if m.top.mediaReady <> true then m.top.mediaReady = true
    CwPerfMark(m.cwPerfSpan, "row RevealNow", "pendingLoads=0 cards=" + Str(m.cards.Count()))
    m.paintPollCount = 0
    m.paintStableCount = 0
    if m.cards.Count() = 0 then
        MarkPaintedReady(false)
        return
    end if
    StartPaintPoll()
end sub

sub StartPaintPoll()
    if m.paintTimer = invalid then return
    m.paintTimer.control = "start"
end sub

' Start the compositor paint gate without waiting for the full row build to finish.
sub MaybeStartPaintGate()
    if m.top.paintedReady = true then return
    if m.cards.Count() = 0 then return
    if m.rowTitle <> invalid and m.rowTitle.opacity < 1.0 then m.rowTitle.opacity = 1.0
    if m.cardsHost <> invalid and m.cardsHost.opacity < 1.0 then m.cardsHost.opacity = 1.0
    m.paintPollCount = 0
    m.paintStableCount = 0
    StartPaintPoll()
end sub

function CardSlotPainted(card as object) as boolean
    if card = invalid then return true
    ' Branded missing/broken poster tile is a terminal paint state (not still loading).
    fallback = card.findNode("thumbFallback")
    if fallback <> invalid and fallback.visible = true then return true
    thumb = card.findNode("thumb")
    if thumb = invalid then return true
    st = thumb.loadStatus
    if st <> "ready" and st <> "failed" then return false
    if thumb.visible <> true then return false
    skel = card.findNode("skeleton")
    if skel <> invalid and skel.visible = true then return false
    return true
end function

function FirstVisibleCardPainted() as boolean
    if m.top.opacity < 1.0 then return false
    if m.cardsHost = invalid or m.cardsHost.opacity < 1.0 then return false
    if m.cards.Count() = 0 then return true
    for each card in m.cards
        if card = invalid then continue for
        x = card.translation[0]
        if x >= 1920 then continue for
        if CardSlotPainted(card) then return true
    end for
    return false
end function

function AllOnScreenCardsPainted() as boolean
    if m.top.opacity < 1.0 then return false
    if m.cardsHost = invalid or m.cardsHost.opacity < 1.0 then return false
    if m.cards.Count() = 0 then return true
    anyOnScreen = false
    for each card in m.cards
        if card = invalid then continue for
        x = card.translation[0]
        if x >= 1920 then continue for
        anyOnScreen = true
        if not CardSlotPainted(card) then return false
    end for
    return anyOnScreen
end function

function BootWindowCardsPainted() as boolean
    target = m.top.bootPaintCardCount
    if target < 1 then return AllOnScreenCardsPainted()
    if m.buildPlan <> invalid and m.buildPlan.Count() > 0 and m.buildPlan.Count() < target then
        target = m.buildPlan.Count()
    end if
    if m.cards.Count() < target then return false
    for i = 0 to target - 1
        if not CardSlotPainted(m.cards[i]) then return false
    end for
    return true
end function

function BootWindowPaintProgress() as string
    target = m.top.bootPaintCardCount
    if target < 1 then return ""
    if m.buildPlan <> invalid and m.buildPlan.Count() > 0 and m.buildPlan.Count() < target then
        target = m.buildPlan.Count()
    end if
    painted = 0
    for i = 0 to m.cards.Count() - 1
        if i >= target then exit for
        if CardSlotPainted(m.cards[i]) then painted = painted + 1
    end for
    return Str(painted) + "/" + Str(target) + " built=" + Str(m.cards.Count())
end function

function RowPaintPollSatisfied() as boolean
    if m.top.requireFullRowPaint = true then
        if m.top.bootPaintCardCount > 0 then return BootWindowCardsPainted()
        if not m.buildComplete then return false
        return AllOnScreenCardsPainted()
    end if
    return FirstVisibleCardPainted()
end function

sub OnPaintPoll()
    m.paintPollCount = m.paintPollCount + 1
    painted = RowPaintPollSatisfied()
    if painted then
        m.paintStableCount = m.paintStableCount + 1
    else
        m.paintStableCount = 0
    end if
    if painted or m.paintPollCount = 1 or m.paintPollCount >= 120 then
        chop = 0.0
        if m.cardsHost <> invalid then chop = m.cardsHost.opacity
        CwPerfMark(m.cwPerfSpan, "row paint poll #" + Str(m.paintPollCount), "painted=" + CwPerfBool(painted) + " stable=" + Str(m.paintStableCount) + " rowOp=" + Str(m.top.opacity) + " hostOp=" + Str(chop))
        if m.top.bootPaintCardCount > 0 then
            HomeLoaderLog("row0 paint poll", "#" + Str(m.paintPollCount) + " ok=" + CwPerfBool(painted) + " " + BootWindowPaintProgress())
        end if
    end if
    ' Two consecutive painted frames — page loader drops only after compositor shows cards.
    needStable = 2
    if m.paintStableCount >= needStable then
        MarkPaintedReady(false)
        return
    end if
    if m.paintPollCount >= 120 then
        CwPerfInstant("row paint poll TIMEOUT — forcing paintedReady")
        MarkPaintedReady(true)
        return
    end if
    StartPaintPoll()
end sub

sub MarkPaintedReady(forced as boolean)
    if m.paintTimer <> invalid then m.paintTimer.control = "stop"
    detail = "polls=" + Str(m.paintPollCount) + " forced=" + CwPerfBool(forced)
    if m.top.bootPaintCardCount > 0 then detail = detail + " " + BootWindowPaintProgress()
    CwPerfMark(m.cwPerfSpan, "row paintedReady TRUE", detail)
    if m.top.bootPaintCardCount > 0 then HomeLoaderLog("row0 paintedReady", detail)
    if m.top.paintedReady <> true then m.top.paintedReady = true
    ResumeBootCardBuildIfNeeded()
end sub

sub OnRevealSafety()
    if not m.buildComplete then return
    m.pendingMediaLoads = 0
    RevealNow()
end sub

sub OnCardMediaLoaded(event = invalid as object)
    if event <> invalid then
        node = event.getRoSGNode()
        if node <> invalid and node.hasField("loaded") then node.unobserveField("loaded")
    end if
    if m.pendingMediaLoads > 0 then m.pendingMediaLoads = m.pendingMediaLoads - 1
    CwPerfMark(m.cwPerfSpan, "row media loaded", "remaining=" + Str(m.pendingMediaLoads))
    MaybeReveal()
end sub

sub ConfigureCard(card as object, compName as string, item as object, cardType as string, rank as integer)
    CardInjectTheme(card, m.top.cPrimary500, m.top.cPrimary600, m.top.cPrimary700, m.top.cNeutral50, m.top.cNeutral800, m.top.cNeutral700)
    showTitle = FeatureDisplayTitle()
    ' React contentRow: description={contentItemData?.title} (fallback empty).
    cardTitle = ""
    if item <> invalid then
        if item.title <> invalid and item.title <> "" then
            cardTitle = item.title
        else if item.name <> invalid and item.name <> "" then
            cardTitle = item.name
        end if
    end if

    if compName = "ContinueWatchCard" then
        ' Hold poster fetch until Home drops the page loader so CW skeleton+progress is visible.
        ' Only cards created before the first ReleaseBootThumbHolds stay held; later cards load immediately.
        if m.top.bootPaintCardCount > 0 and m.bootThumbsReleased <> true then
            card.holdThumbLoad = true
        end if
        card.progress = GetContinueProgressPercent(item)
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
    else if compName = "NumberedVerticalCard" then
        ' PARITY: contentRow.tsx selects the TOP_CONTENTS thumbnail with the category's own
        ' cardType (getCardImgByType(cardType, thumbnails)) — NOT a hardcoded VERTICAL. Using
        ' VERTICAL here picked a different thumbnail variant than LG for the same item.
        card.thumbnailUri = GetCardImgByType(cardType, item.thumbnails)
        card.rank = rank
    else if compName = "BannerCard" then
        thumb = ResolveBannerImage(item, GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails))
        card.thumbnailUri = thumb
        nm = ""
        if item.title <> invalid then nm = item.title
        card.title = nm
    else if compName = "HorizontalCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
    else if compName = "VerticalCard" then
        card.thumbnailUri = GetCardImgByType(cardType, item.thumbnails)
    end if

    ' Set title text before displayTitle so OnDataChanged sees both when flag flips on.
    if card.hasField("cardTitle") then card.cardTitle = cardTitle
    if card.hasField("displayTitle") then card.displayTitle = showTitle
end sub

' After page loader hides — start CW poster fetches (skeleton was held during boot).
function ReleaseBootThumbHolds(dummy = invalid as dynamic) as boolean
    m.bootThumbsReleased = true
    n = 0
    for each card in m.cards
        if card = invalid then continue for
        if card.hasField("holdThumbLoad") <> true then continue for
        if card.holdThumbLoad <> true then continue for
        card.callFunc("ReleaseThumbLoad", invalid)
        n = n + 1
    end for
    HomeLoaderLog("row ReleaseBootThumbHolds", "released=" + Str(n) + " cards=" + Str(m.cards.Count()))
    return true
end function

sub ApplyRowTheme()
    m.rowTitle.color = m.top.cNeutral50
end sub

sub ApplyCardFocus()
    idx = m.top.cardFocusIndex
    for i = 0 to m.cards.Count() - 1
        card = m.cards[i]
        if card <> invalid and card.hasField("focusedState") then
            card.focusedState = (i = idx)
        end if
    end for
end sub

' Keep the focused card in view without over-scrolling. The previous logic aligned every
' focused card near the left edge, so navigating right made the whole strip slide left and
' left empty space on the right at the end of the row. Clamp to the real strip width so the
' last card lands flush-right, matching LG.
sub ScrollToFocusedCard()
    if m.cardsHost = invalid then return
    idx = m.top.cardFocusIndex
    if idx < 0 then return
    if m.cardWidths.Count() = 0 then return
    if idx >= m.cardWidths.Count() then idx = m.cardWidths.Count() - 1

    x = 0
    gap = HC_CardGap()
    for i = 0 to idx - 1
        x = x + m.cardWidths[i] + gap
    end for

    cardW = m.cardWidths[idx]
    cardLeft = x
    cardRight = cardLeft + cardW

    viewportW = 1920 - 64
    currentScroll = 32 - m.cardsHost.translation[0]
    if currentScroll < 0 then currentScroll = 0

    scrollX = currentScroll
    if cardLeft < scrollX then
        scrollX = cardLeft
    else if cardRight > scrollX + viewportW then
        scrollX = cardRight - viewportW
    end if

    totalW = 0
    for i = 0 to m.cardWidths.Count() - 1
        totalW = totalW + m.cardWidths[i]
        if i < m.cardWidths.Count() - 1 then totalW = totalW + gap
    end for
    maxScroll = totalW - viewportW
    if maxScroll < 0 then maxScroll = 0

    if scrollX < 0 then scrollX = 0
    if scrollX > maxScroll then scrollX = maxScroll
    m.cardsHost.translation = [32 - scrollX, 55]
end sub

sub ClearCards()
    if m.cardTimer <> invalid then m.cardTimer.control = "stop"
    if m.revealTimer <> invalid then m.revealTimer.control = "stop"
    if m.paintTimer <> invalid then m.paintTimer.control = "stop"
    for each card in m.cards
        CardDetachMediaObservers(card)
    end for
    ClearPendingSkeletonSlots()
    if m.cardsHost <> invalid then m.cardsHost.opacity = 0.0
    if m.rowTitle <> invalid then m.rowTitle.opacity = 0.0
    m.top.built = false
    m.buildPlan = []
    m.buildIdx = 0
    m.buildX = 0
    m.pendingMediaLoads = 0
    m.buildComplete = false
    m.buildActive = false
    m.shellCat = invalid
    m.cards = []
    m.cardWidths = []
    m.cardItemIds = []
    if m.cardsHost = invalid then return
    count = m.cardsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.cardsHost.removeChildIndex(i)
    end for
    m.top.cardCount = 0
    m.top.mediaReady = false
    m.top.paintedReady = false
end sub

' ── Continue Watching in-place refresh (home resume after playback) ───────────

function CwItemId(item as object) as string
    if item = invalid then return ""
    if item._id <> invalid then return item._id
    return ""
end function

function CwSlotIdForPlanEntry(p as object) as string
    if p = invalid then return ""
    if p.kind = "seeAll" then return "__see_all__"
    return CwItemId(p.item)
end function

function CwNormalizeSlotId(slotId as string) as string
    if slotId = "" then return "__see_all__"
    return slotId
end function

sub EnsureCardItemIdsFromPlan(plan as object)
    if plan = invalid then return
    if m.cardItemIds.Count() = m.cards.Count() and m.cardItemIds.Count() > 0 then return
    m.cardItemIds = []
    for i = 0 to plan.Count() - 1
        m.cardItemIds.Push(CwSlotIdForPlanEntry(plan[i]))
    end for
end sub

function CwIdsMatchPlan(plan as object) as boolean
    if plan = invalid then return false
    if plan.Count() <> m.cards.Count() then return false
    for i = 0 to plan.Count() - 1
        want = CwSlotIdForPlanEntry(plan[i])
        have = ""
        if m.cardItemIds.Count() > i then have = CwNormalizeSlotId(m.cardItemIds[i])
        if have <> want then return false
    end for
    return true
end function

function CwExistingPrefixMatchesPlan(plan as object) as boolean
    if plan = invalid then return false
    n = plan.Count()
    if m.cards.Count() <= n then return false
    for i = 0 to n - 1
        want = CwSlotIdForPlanEntry(plan[i])
        have = ""
        if m.cardItemIds.Count() > i then have = CwNormalizeSlotId(m.cardItemIds[i])
        if have <> want then return false
    end for
    return true
end function

function CwPrefixOfPlanMatchesCards(plan as object) as boolean
    if plan = invalid then return false
    n = m.cards.Count()
    if plan.Count() <= n then return false
    for i = 0 to n - 1
        want = CwSlotIdForPlanEntry(plan[i])
        have = ""
        if m.cardItemIds.Count() > i then have = CwNormalizeSlotId(m.cardItemIds[i])
        if have <> want then return false
    end for
    return true
end function

sub PatchCwPlanSlots(plan as object)
    if plan = invalid then return
    for i = 0 to plan.Count() - 1
        p = plan[i]
        if p = invalid or p.kind <> "card" then continue for
        if i >= m.cards.Count() then continue for
        PatchCwCardProgress(m.cards[i], p.item)
    end for
end sub

sub FinalizeCwRowAfterPatch()
    m.buildComplete = true
    m.buildActive = false
    m.top.cardCount = m.cards.Count()
    OnCardFocusChanged()
end sub

' Planning pass with no row-title / opacity side effects (safe during live paint).
function PlanRowCardsData(cat as object) as object
    if cat = invalid then return invalid

    rowType = ""
    if cat.type <> invalid then rowType = cat.type
    cardType = HC_CardTypeVertical()
    if cat.cardType <> invalid and cat.cardType <> "" then cardType = cat.cardType

    items = cat.result
    if items = invalid or items.Count() = 0 then return invalid

    compName = CardComponentForRow(rowType, cardType)
    if compName = "BannerCard" and rowType <> HC_PromotionalCard() then return invalid

    maxItems = items.Count()
    if rowType <> HC_PromotionalCard() then
        limit = HC_SeeAllThreshold() + 1
        if maxItems > limit then maxItems = limit
    else
        maxItems = 1
    end if

    plan = []
    for i = 0 to maxItems - 1
        item = items[i]
        if item <> invalid then
            plan.Push({ kind: "card", item: item, comp: compName, cardType: cardType, rank: i })
        end if
    end for
    if rowType <> HC_PromotionalCard() and items.Count() >= HC_SeeAllThreshold() + 1 then
        plan.Push({ kind: "seeAll" })
    end if
    return plan
end function

sub AppendCwPlanEntry(plan as object)
    if plan = invalid then return
    gap = HC_CardGap()

    if plan.kind = "seeAll" then
        seeAll = m.cardsHost.createChild("SeeAllCard")
        seeAll.orientation = m.seeAllOrientation
        CardInjectTheme(seeAll, m.top.cPrimary500, m.top.cPrimary600, m.top.cPrimary700, m.top.cNeutral50, m.top.cNeutral800, m.top.cNeutral700)
        seeAll.translation = [m.buildX, 0]
        w = CardComponentWidth("SeeAllCard", m.seeAllOrientation)
        m.cards.Push(seeAll)
        m.cardWidths.Push(w)
        m.cardItemIds.Push("__see_all__")
        m.buildX = m.buildX + w + gap
    else if plan.kind = "card" then
        card = m.cardsHost.createChild(plan.comp)
        ConfigureCard(card, plan.comp, plan.item, plan.cardType, plan.rank)
        card.translation = [m.buildX, 0]
        w = CardComponentWidth(plan.comp)
        m.cards.Push(card)
        m.cardWidths.Push(w)
        m.cardItemIds.Push(CwItemId(plan.item))
        m.buildX = m.buildX + w + gap
        idx = m.cards.Count() - 1
        if card.hasField("focusedState") then card.focusedState = (idx = m.top.cardFocusIndex)
    end if
    m.top.cardCount = m.cards.Count()
end sub

sub PatchCwCardProgress(card as object, item as object)
    if card = invalid or item = invalid then return
    pct = GetContinueProgressPercent(item)
    if card.hasField("progress") then card.progress = pct
end sub

sub SyncCategoryDataSilent(cat as object)
    m.suppressCategoryRebuild = true
    m.top.categoryData = cat
end sub

sub TrimCwCardsFromIndex(fromIdx as integer)
    if fromIdx < 0 then fromIdx = 0
    while m.cards.Count() > fromIdx
        idx = m.cards.Count() - 1
        card = m.cards[idx]
        CardDetachMediaObservers(card)
        if m.cardsHost <> invalid then m.cardsHost.removeChild(card)
        m.cards.Pop()
        if m.cardItemIds.Count() > idx then m.cardItemIds.Pop()
        if m.cardWidths.Count() > idx then m.cardWidths.Pop()
    end while
    RecalcCwStripLayout()
    m.top.cardCount = m.cards.Count()
end sub

sub RecalcCwStripLayout()
    gap = HC_CardGap()
    x = 0
    for i = 0 to m.cards.Count() - 1
        card = m.cards[i]
        if card = invalid then continue for
        card.translation = [x, 0]
        w = 0
        if m.cardWidths.Count() > i then w = m.cardWidths[i]
        x = x + w + gap
    end for
    m.buildX = x
end sub

sub AppendCwCardFromPlan(plan as object)
    AppendCwPlanEntry(plan)
end sub

' Drop card nodes but keep the revealed strip visible (no skeleton re-arm).
sub ClearCwCardsPreserveReveal()
    if m.cardTimer <> invalid then m.cardTimer.control = "stop"
    if m.revealTimer <> invalid then m.revealTimer.control = "stop"
    if m.paintTimer <> invalid then m.paintTimer.control = "stop"
    for each card in m.cards
        CardDetachMediaObservers(card)
    end for
    m.buildPlan = []
    m.buildIdx = 0
    m.buildX = 0
    m.pendingMediaLoads = 0
    m.buildComplete = false
    m.buildActive = false
    m.shellCat = invalid
    m.cards = []
    m.cardWidths = []
    m.cardItemIds = []
    if m.cardsHost = invalid then return
    count = m.cardsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.cardsHost.removeChildIndex(i)
    end for
    m.top.cardCount = 0
end sub

sub RebuildCwRowPreserveReveal(cat as object)
    plan = PlanRowCardsData(cat)
    if plan = invalid then return
    hostOp = 1.0
    titleOp = 1.0
    if m.cardsHost <> invalid then hostOp = m.cardsHost.opacity
    if m.rowTitle <> invalid then titleOp = m.rowTitle.opacity
    ClearCwCardsPreserveReveal()
    m.buildPlan = plan
    m.buildIdx = 0
    m.buildX = 0
    m.buildComplete = false
    m.buildActive = true
    while m.buildIdx < m.buildPlan.Count()
        AppendNextCardFromPlan()
    end while
    FinishCardBuildIfDone()
    if m.cardsHost <> invalid then m.cardsHost.opacity = hostOp
    if m.rowTitle <> invalid then m.rowTitle.opacity = titleOp
    if m.top.paintedReady <> true then m.top.paintedReady = true
    if m.top.mediaReady <> true then m.top.mediaReady = true
    FinalizeCwRowAfterPatch()
end sub

' Returns true when the row was patched without a full strip teardown.
function PatchContinueWatching(cat as object) as boolean
    if cat = invalid then return false
    if m.buildComplete <> true then return false
    tp = ""
    if cat.type <> invalid then tp = cat.type
    if tp <> HC_TypeContinueWatching() then return false

    plan = PlanRowCardsData(cat)
    if plan = invalid then return false
    if plan.Count() = 0 then return false

    EnsureCardItemIdsFromPlan(plan)

    ' Same visible strip (content + See All) — update progress bars in place.
    if plan.Count() = m.cards.Count() and CwIdsMatchPlan(plan) then
        PatchCwPlanSlots(plan)
        SyncCategoryDataSilent(cat)
        FinalizeCwRowAfterPatch()
        print "[CONTENT_ROW_DBG] PatchContinueWatching progress_only slots="; plan.Count()
        return true
    end if

    ' Shorter row — tail cards removed (e.g. finished watching).
    if CwExistingPrefixMatchesPlan(plan) then
        TrimCwCardsFromIndex(plan.Count())
        PatchCwPlanSlots(plan)
        SyncCategoryDataSilent(cat)
        FinalizeCwRowAfterPatch()
        print "[CONTENT_ROW_DBG] PatchContinueWatching trimmed slots="; plan.Count()
        return true
    end if

    ' Longer row — append new slots at the end; prefix unchanged.
    if CwPrefixOfPlanMatchesCards(plan) then
        PatchCwPlanSlots(plan)
        for i = m.cards.Count() to plan.Count() - 1
            AppendCwPlanEntry(plan[i])
        end for
        SyncCategoryDataSilent(cat)
        FinalizeCwRowAfterPatch()
        print "[CONTENT_ROW_DBG] PatchContinueWatching appended slots="; plan.Count()
        return true
    end if

    ' Order or membership changed — rebuild nodes but keep the strip visible.
    print "[CONTENT_ROW_DBG] PatchContinueWatching resync slots="; plan.Count()
    RebuildCwRowPreserveReveal(cat)
    SyncCategoryDataSilent(cat)
    FinalizeCwRowAfterPatch()
    return true
end function
