sub init()
    m.rowTitle = m.top.findNode("rowTitle")
    m.cardsHost = m.top.findNode("cardsHost")
    m.cards = []
    m.cardWidths = []
    m.seeAllOrientation = HC_CardTypeVertical()
    if m.rowTitle <> invalid then m.rowTitle.opacity = 0.0

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
end sub

sub OnCategoryChanged()
    BuildRowCards()
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
    ' netflixContent.tsx: focused=1, above focus=0, below focus=0.4 (OTT below stays 1.0).
    if m.top.rowFocused = true then
        m.top.opacity = 1.0
    else if m.top.rowSuppressed = true then
        m.top.opacity = 0.0
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
    CwPerfMark(m.cwPerfSpan, "row StartCardBuild", "cards=" + Str(plan.Count()))

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

    if m.cardsHost <> invalid then m.cardsHost.opacity = 0.0
    m.top.built = false

    if m.buildPlan.Count() > 0 then
        m.cardTimer.control = "start"
    else
        m.buildComplete = true
        m.buildActive = false
        RevealNow()
    end if
end sub

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

    ' One card per tick keeps each render-thread slice tiny so the hero animation and
    ' input stay responsive while the row fills in.
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
        m.buildX = m.buildX + w + gap
    else
        card = m.cardsHost.createChild(plan.comp)
        ConfigureCard(card, plan.comp, plan.item, plan.cardType, plan.rank)
        card.translation = [m.buildX, 0]
        TrackCardMediaLoad(card, plan.comp)
        w = CardComponentWidth(plan.comp)
        m.cards.Push(card)
        m.cardWidths.Push(w)
        m.buildX = m.buildX + w + gap
    end if

    m.buildIdx = m.buildIdx + 1

    ' Highlight only the card just built (if it's the focused one) instead of looping the
    ' whole strip on every 10ms tick. The full focus pass runs once at completion below.
    newCard = m.cards[m.cards.Count() - 1]
    if newCard <> invalid and newCard.hasField("focusedState") then
        newCard.focusedState = ((m.cards.Count() - 1) = m.top.cardFocusIndex)
    end if

    if m.buildIdx >= m.buildPlan.Count() then
        m.cardTimer.control = "stop"
        if m.cardTimer <> invalid then m.cardTimer.duration = 0.01
        OnCardFocusChanged()
        m.buildComplete = true
        m.buildActive = false
        m.top.built = true
        ' If we're still waiting on card thumbnails, arm the safety fallback.
        if m.pendingMediaLoads > 0 and m.revealTimer <> invalid then
            m.revealTimer.control = "start"
        end if
        MaybeReveal()
    end if
end sub

' Reveal only when every card node exists AND its media is loaded, so the
' shimmer stays up continuously and the real strip swaps in instantly.
sub MaybeReveal()
    if not m.buildComplete then return
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
    ' OTT home + genre catalogue: media loaded — skip paint-poll (sim often never passes it).
    if ThemeIsOttHome() or m.top.ottRowReveal = true then
        MarkPaintedReady(false)
        return
    end if
    m.paintPollCount = 0
    m.paintStableCount = 0
    StartPaintPoll()
end sub

sub StartPaintPoll()
    if m.paintTimer = invalid then return
    m.paintTimer.control = "start"
end sub

function FirstVisibleCardPainted() as boolean
    if m.top.opacity < 1.0 then return false
    if m.cardsHost = invalid or m.cardsHost.opacity < 1.0 then return false
    if m.cards.Count() = 0 then return true
    for each card in m.cards
        if card = invalid then continue for
        x = card.translation[0]
        if x >= 1920 then continue for
        thumb = card.findNode("thumb")
        skel = card.findNode("skeleton")
        if thumb = invalid then return false
        st = thumb.loadStatus
        if st <> "ready" and st <> "failed" then return false
        if thumb.visible <> true then return false
        if skel <> invalid and skel.visible = true then return false
        return true
    end for
    return false
end function

sub OnPaintPoll()
    m.paintPollCount = m.paintPollCount + 1
    painted = FirstVisibleCardPainted()
    if painted then
        m.paintStableCount = m.paintStableCount + 1
    else
        m.paintStableCount = 0
    end if
    if painted or m.paintPollCount = 1 or m.paintPollCount >= 120 then
        chop = 0.0
        if m.cardsHost <> invalid then chop = m.cardsHost.opacity
        CwPerfMark(m.cwPerfSpan, "row paint poll #" + Str(m.paintPollCount), "painted=" + CwPerfBool(painted) + " stable=" + Str(m.paintStableCount) + " rowOp=" + Str(m.top.opacity) + " hostOp=" + Str(chop))
    end if
    ' Two consecutive painted frames — avoids cutting shimmer before compositor shows cards.
    ' OTT home: one stable frame is enough (faster handoff off the rows shimmer).
    needStable = 2
    if ThemeIsOttHome() or m.top.ottRowReveal = true then needStable = 1
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
    CwPerfMark(m.cwPerfSpan, "row paintedReady TRUE", detail)
    if m.top.paintedReady <> true then m.top.paintedReady = true
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

    if compName = "ContinueWatchCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
        card.progress = GetContinueProgressPercent(item)
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
end sub

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
    if idx < 0 then idx = 0
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
    if m.cardsHost = invalid then return
    count = m.cardsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.cardsHost.removeChildIndex(i)
    end for
    m.top.cardCount = 0
    m.top.mediaReady = false
    m.top.paintedReady = false
end sub
