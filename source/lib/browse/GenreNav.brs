' GenreNav.brs — card routing for genre catalogue rows (parity with genre-list/ContentRow.tsx).

function GenreNavPayloadForCard(cat as object, cardIndex as integer, cardCount as integer, listType as string) as object
    if cat = invalid then return invalid

    if HomeCardIsSeeAll(cat, cardIndex, cardCount) then
        genereId = ""
        if cat._id <> invalid then genereId = cat._id
        genereTitle = ""
        if cat.name <> invalid then genereTitle = cat.name
        tp = listType
        if tp = "" then tp = HM_TypeSingleVideo()
        return {
            route: RouteSeries()
            state: {
                genere_id: genereId
                genere_title: genereTitle
                type: tp
            }
        }
    end if

    items = cat.result
    if items = invalid or cardIndex < 0 or cardIndex >= items.Count() then return invalid
    item = items[cardIndex]
    if item = invalid then return invalid
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

sub NavigateGenreCardSelection(vm as object, cat as object, cardIndex as integer, cardCount as integer, listType as string)
    if vm = invalid then return
    payload = GenreNavPayloadForCard(cat, cardIndex, cardCount, listType)
    if payload = invalid then return
    if payload.route = invalid or payload.state = invalid then return
    BrowseDbg("genre_nav", "route=" + payload.route)
    BrowseDbgState("genre_nav_state", payload.state)
    vm.callFunc("NavigatePush", payload.route, payload.state)
end sub
