' GenreListService.brs — GET contents/catalogue parity with features/genre-list/.

function GL_BuildCatalogueQuery(page as integer, listType as string) as object
    return { page: page, limit: GL_CataloguePageLimit(), type: listType }
end function

function GL_NormalizeCategory(raw as object) as object
    if raw = invalid then return invalid
    items = raw.result
    if items = invalid or items.Count() = 0 then return invalid
    return {
        _id: raw._id
        name: raw.name
        type: HC_TypeContentList()
        cardType: HC_CardTypeVertical()
        result: items
    }
end function

function GL_PageHasMore(api as object, batchCount as integer) as boolean
    if api = invalid or api.result = invalid then return false
    if batchCount = 0 then return false
    return true
end function

function GL_FocusedItem(categories as object, rowIdx as integer, cardIdx as integer, cardCount as integer) as object
    if categories = invalid then return invalid
    if rowIdx < 0 or rowIdx >= categories.Count() then return invalid
    cat = categories[rowIdx]
    if cat = invalid or cat.result = invalid then return invalid
    if HomeCardIsSeeAll(cat, cardIdx, cardCount) then
        limit = HC_SeeAllThreshold()
        if cat.result.Count() < limit then limit = cat.result.Count()
        if limit < 1 then return invalid
        return cat.result[limit - 1]
    end if
    if cardIdx < 0 or cardIdx >= cat.result.Count() then return invalid
    return cat.result[cardIdx]
end function
