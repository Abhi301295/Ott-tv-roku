' SeriesListService.brs — GET contents/filter parity with features/series/.

function SL_BuildQuery(page as integer, listType as string, categoryId as string, genreId as string) as object
    q = { page: page, type: listType, limit: BS_SeriesPageLimit() }
    if categoryId <> "" then q.category = categoryId
    if genreId <> "" then q.genre = genreId
    return q
end function

' Append flat listing items into row chunks of itemsPerRow (parity with transformSeries).
function SL_AppendRows(rows as object, items as object, itemsPerRow as integer) as object
    if rows = invalid then rows = []
    if items = invalid or items.Count() = 0 then return rows

    flatCount = 0
    for each row in rows
        if row <> invalid and row.items <> invalid then flatCount = flatCount + row.items.Count()
    end for

    for i = 0 to items.Count() - 1
        item = items[i]
        if item = invalid then continue for
        globalIdx = flatCount + i
        rowIdx = Int(globalIdx / itemsPerRow)
        while rows.Count() <= rowIdx
            rows.Push({ items: [] })
        end while
        row = rows[rowIdx]
        row.items.Push(item)
        rows[rowIdx] = row
    end for
    return rows
end function

' Pick the fuller array — API often returns both listing (partial) and data (page).
function SL_ParseSeriesListing(api as object) as object
    items = []
    if api = invalid or api.result = invalid then return items
    result = api.result
    dataItems = []
    listingItems = []
    if result.data <> invalid then dataItems = result.data
    if result.listing <> invalid then listingItems = result.listing
    if dataItems.Count() >= listingItems.Count() then return dataItems
    return listingItems
end function

function SL_FlatItemCount(rows as object) as integer
    count = 0
    if rows = invalid then return 0
    for each row in rows
        if row <> invalid and row.items <> invalid then count = count + row.items.Count()
    end for
    return count
end function

function SL_PageHasMore(api as object, listingCount as integer, loadedCount as integer) as boolean
    if api = invalid or api.result = invalid then return false
    if listingCount = 0 then return false
    result = api.result
    if result.total <> invalid and result.total > 0 then
        return loadedCount < result.total
    end if
    if listingCount < BS_SeriesPageLimit() then return false
    return true
end function
