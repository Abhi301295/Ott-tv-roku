' GridFocus.brs — shared focus/scroll math for paginated row+column grids.
' Pure functions only; screens keep animation nodes and geometry constants.

function GridClampColIndex(rowIdx as integer, colIdx as integer, rowNodes as object) as integer
    if rowNodes = invalid then return colIdx
    if rowIdx < 0 or rowIdx >= rowNodes.Count() then return colIdx
    entry = rowNodes[rowIdx]
    if entry = invalid or entry.cards = invalid then return colIdx
    if colIdx >= entry.cards.Count() then return entry.cards.Count() - 1
    if colIdx < 0 then return 0
    return colIdx
end function

function GridClampScrollY(rowIdx as integer, scrollY as integer, rowPitch as integer, rowCardH as integer, viewH as integer) as integer
    rowTop = rowIdx * rowPitch
    rowBottom = rowTop + rowCardH
    if rowTop < scrollY then scrollY = rowTop
    if rowBottom > scrollY + viewH then scrollY = rowBottom - viewH
    if scrollY < 0 then scrollY = 0
    return scrollY
end function

function GridClampRowScrollX(colIdx as integer, scrollX as integer, cardPitch as integer, cardW as integer, viewW as integer) as integer
    cardLeft = colIdx * cardPitch
    cardRight = cardLeft + cardW
    if cardLeft < scrollX then scrollX = cardLeft
    if cardRight > scrollX + viewW then scrollX = cardRight - viewW
    if scrollX < 0 then scrollX = 0
    return scrollX
end function

function GridShouldLoadMore(hasMore as boolean, loading as boolean, rowCount as integer, rowIdx as integer) as boolean
    if not hasMore then return false
    if loading then return false
    if rowCount = 0 then return false
    return rowIdx = rowCount - 1
end function
