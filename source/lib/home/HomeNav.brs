' HomeNav.brs — card selection routing (parity with contentRow.tsx onCardSelect /
' onContinueCardSelect / seeAllCardSelect).

function HomeCardIsSeeAll(cat as object, cardIndex as integer, cardCount as integer) as boolean
    if cat = invalid then return false
    rowType = ""
    if cat.type <> invalid then rowType = cat.type
    if rowType = HC_PromotionalCard() then return false
    items = cat.result
    if items = invalid then return false
    if items.Count() < HC_SeeAllThreshold() + 1 then return false
    return cardIndex = cardCount - 1
end function

function HomeNavPayloadForCard(cat as object, cardIndex as integer, cardCount as integer) as object
    if cat = invalid then return invalid

    if HomeCardIsSeeAll(cat, cardIndex, cardCount) then
        items = cat.result
        refItem = invalid
        if items.Count() > HC_SeeAllThreshold() then refItem = items[HC_SeeAllThreshold()]
        if refItem = invalid and items.Count() > 0 then refItem = items[items.Count() - 1]
        if refItem = invalid then return invalid

        id = ""
        if refItem._id <> invalid then id = refItem._id
        tp = ""
        if refItem.type <> invalid then tp = refItem.type
        categoryId = ""
        if cat._id <> invalid then categoryId = cat._id
        genereTitle = ""
        if cat.name <> invalid then genereTitle = cat.name

        return {
            route: RouteSeries()
            state: {
                id: id
                categoryId: categoryId
                genere_title: genereTitle
                type: tp
            }
        }
    end if

    items = cat.result
    if items = invalid or cardIndex < 0 then return invalid
    if cardIndex >= items.Count() then return invalid

    item = items[cardIndex]
    if item = invalid then return invalid

    rowType = ""
    if cat.type <> invalid then rowType = cat.type

    if rowType = HC_TypeContinueWatching() then
        contentId = ""
        if item._id <> invalid then contentId = item._id
        return {
            route: RouteVideoPlayer()
            state: {
                detail: item
                contentId: contentId
                nextVideo: []
            }
        }
    end if

    id = ""
    if item._id <> invalid then id = item._id
    tp = ""
    if item.type <> invalid then tp = item.type
    if id = "" or tp = "" then return invalid

    return {
        route: RouteDetail()
        state: {
            id: id
            type: tp
        }
    }
end function

sub NavigateHomeCardSelection(vm as object, cat as object, cardIndex as integer, cardCount as integer)
    if vm = invalid then return
    payload = HomeNavPayloadForCard(cat, cardIndex, cardCount)
    if payload = invalid then return
    if payload.route = invalid or payload.state = invalid then return
    vm.callFunc("NavigatePush", payload.route, payload.state)
end sub
