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

function SL_PageHasMore(api as object, listingCount as integer) as boolean
    if api = invalid or api.result = invalid then return false
    if api.result.total <> invalid and api.result.total = 0 then return false
    if listingCount = 0 then return false
    if listingCount < BS_SeriesPageLimit() then return false
    return true
end function
