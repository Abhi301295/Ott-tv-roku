sub init()
    m.rowTitle = m.top.findNode("rowTitle")
    m.cardsHost = m.top.findNode("cardsHost")
    m.cards = []
    m.cardWidths = []
    m.seeAllOrientation = HC_CardTypeVertical()
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
    if m.top.rowFocused = true then
        m.top.opacity = 1.0
    else if m.top.rowDimmed = true then
        m.top.opacity = 0.4
    else
        m.top.opacity = 0.0
    end if
end sub

sub BuildRowCards()
    ClearCards()
    cat = m.top.categoryData
    if cat = invalid then return

    rowType = ""
    if cat.type <> invalid then rowType = cat.type
    cardType = HC_CardTypeVertical()
    if cat.cardType <> invalid and cat.cardType <> "" then cardType = cat.cardType
    if cardType = HC_CardTypeHorizontal() then m.seeAllOrientation = HC_CardTypeHorizontal()

    title = ""
    if cat.name <> invalid then title = cat.name
    m.rowTitle.text = title
    m.rowTitle.color = m.top.cNeutral50

    items = cat.result
    if items = invalid or items.Count() = 0 then return

    compName = CardComponentForRow(rowType, cardType)
    if compName = "BannerCard" and rowType <> HC_PromotionalCard() then return

    maxItems = items.Count()
    if rowType <> HC_PromotionalCard() then
        limit = HC_SeeAllThreshold() + 1
        if maxItems > limit then maxItems = limit
    else
        maxItems = 1
    end if

    x = 0
    gap = HC_CardGap()
    for i = 0 to maxItems - 1
        item = items[i]
        if item = invalid then continue for
        card = m.cardsHost.createChild(compName)
        ConfigureCard(card, compName, item, cardType, i)
        card.translation = [x, 0]
        w = CardComponentWidth(compName)
        m.cards.Push(card)
        m.cardWidths.Push(w)
        x = x + w + gap
    end for

    if rowType <> HC_PromotionalCard() and items.Count() >= HC_SeeAllThreshold() + 1 then
        seeAll = m.cardsHost.createChild("SeeAllCard")
        seeAll.orientation = m.seeAllOrientation
        CardInjectTheme(seeAll, m.top.cPrimary500, m.top.cPrimary600, m.top.cPrimary700, m.top.cNeutral50, m.top.cNeutral800, m.top.cNeutral700)
        seeAll.translation = [x, 0]
        w = CardComponentWidth("SeeAllCard", m.seeAllOrientation)
        m.cards.Push(seeAll)
        m.cardWidths.Push(w)
    end if

    m.top.cardCount = m.cards.Count()
    OnCardFocusChanged()
end sub

sub ConfigureCard(card as object, compName as string, item as object, cardType as string, rank as integer)
    CardInjectTheme(card, m.top.cPrimary500, m.top.cPrimary600, m.top.cPrimary700, m.top.cNeutral50, m.top.cNeutral800, m.top.cNeutral700)

    if compName = "ContinueWatchCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
        card.progress = GetContinueProgressPercent(item)
        if card.hasField("cNeutral950") then card.cNeutral950 = m.top.cNeutral950
        if card.hasField("cNeutral700") then card.cNeutral700 = m.top.cNeutral700
    else if compName = "NumberedVerticalCard" then
        card.thumbnailUri = GetCardImgByType(HC_CardTypeVertical(), item.thumbnails)
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

' Keep the focused card in view (parity with contentRow onAssetFocus scroll).
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
    scrollX = x - 10
    if scrollX < 0 then scrollX = 0
    m.cardsHost.translation = [32 - scrollX, 55]
end sub

sub ClearCards()
    m.cards = []
    m.cardWidths = []
    if m.cardsHost = invalid then return
    count = m.cardsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.cardsHost.removeChildIndex(i)
    end for
    m.top.cardCount = 0
end sub
