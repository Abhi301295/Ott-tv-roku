' GridFlatFocus.brs — flat index grid focus/scroll math (Search results, etc.).

function GridClampFlatIndex(idx as integer, count as integer) as integer
    if count <= 0 then return 0
    if idx < 0 then return 0
    if idx >= count then return count - 1
    return idx
end function

function GridFlatRowForIndex(index as integer, cols as integer) as integer
    if cols < 1 then cols = 1
    return Int(index / cols)
end function

function GridFlatRowCount(itemCount as integer, cols as integer) as integer
    if itemCount < 1 then return 0
    if cols < 1 then cols = 1
    return Int((itemCount - 1) / cols) + 1
end function

function GridFlatColsForPanel(panelW as integer, marginLeft as integer, minColW as integer, gap as integer) as integer
    usable = panelW - marginLeft
    if usable < minColW then return 1
    cols = Int((usable + gap) / (minColW + gap))
    if cols < 1 then cols = 1
    return cols
end function

function GridClampFlatScrollY(scrollY as integer, rowTop as integer, scrollBottom as integer, viewH as integer, pad as integer, isLastRow as boolean) as integer
    if rowTop < scrollY + pad then scrollY = rowTop - pad
    if scrollBottom > scrollY + viewH then scrollY = scrollBottom - viewH
    if isLastRow then
        needY = scrollBottom - viewH
        if needY > scrollY then scrollY = needY
    end if
    if scrollY < 0 then scrollY = 0
    return scrollY
end function

function GridClampScrollMax(scrollY as integer, maxScroll as integer) as integer
    if maxScroll < 0 then maxScroll = 0
    if scrollY > maxScroll then return maxScroll
    if scrollY < 0 then return 0
    return scrollY
end function
