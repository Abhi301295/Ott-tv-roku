' ContentRowCatalogue.brs — shared ContentRow shell creation for catalogue screens.
' GenreListScreen is the first consumer; HomeScreen migrates in Phase C.

function CRC_RowSlotHeight(cat as object) as integer
    return HC_ContentRowLayoutHeight(cat)
end function

' Build a theme assocarray from screen host fields (cPrimary*, cNeutral*).
function CRC_ThemeFromHost(host as object) as object
    theme = {}
    if host = invalid then return theme
    if host.cPrimary500 <> invalid then theme.cPrimary500 = host.cPrimary500
    if host.cPrimary600 <> invalid then theme.cPrimary600 = host.cPrimary600
    if host.cPrimary700 <> invalid then theme.cPrimary700 = host.cPrimary700
    if host.cNeutral50 <> invalid then theme.cNeutral50 = host.cNeutral50
    if host.cNeutral700 <> invalid then theme.cNeutral700 = host.cNeutral700
    if host.cNeutral800 <> invalid then theme.cNeutral800 = host.cNeutral800
    if host.cNeutral950 <> invalid then theme.cNeutral950 = host.cNeutral950
    if host.cPageBg <> invalid then theme.cPageBg = host.cPageBg
    return theme
end function

sub CRC_ApplyRowTheme(row as object, theme as object, ottRowReveal = true as boolean)
    if row = invalid or theme = invalid then return
    if row.hasField("ottRowReveal") then row.ottRowReveal = ottRowReveal
    if theme.rowTitleFontSize <> invalid and row.hasField("rowTitleFontSize") then
        row.rowTitleFontSize = theme.rowTitleFontSize
    end if
    if theme.cPrimary500 <> invalid then row.cPrimary500 = theme.cPrimary500
    if theme.cPrimary600 <> invalid then row.cPrimary600 = theme.cPrimary600
    if theme.cPrimary700 <> invalid then row.cPrimary700 = theme.cPrimary700
    if theme.cNeutral50 <> invalid then row.cNeutral50 = theme.cNeutral50
    if theme.cNeutral700 <> invalid then row.cNeutral700 = theme.cNeutral700
    if theme.cNeutral800 <> invalid then row.cNeutral800 = theme.cNeutral800
    if theme.cNeutral950 <> invalid then row.cNeutral950 = theme.cNeutral950
    if theme.cPageBg <> invalid and row.hasField("cPageBg") then row.cPageBg = theme.cPageBg
end sub

function CRC_CreateShellRow(rowsHost as object, cat as object, y as integer, theme as object) as object
    if rowsHost = invalid or cat = invalid then return invalid
    row = rowsHost.createChild("ContentRow")
    CRC_ApplyRowTheme(row, theme)
    row.callFunc("PrepareShell", cat)
    row.translation = [0, y]
    return row
end function

' First catalogue row — categoryData populates cards immediately (row 0 reveal path).
function CRC_CreateDataRow(rowsHost as object, cat as object, y as integer, theme as object) as object
    if rowsHost = invalid or cat = invalid then return invalid
    row = rowsHost.createChild("ContentRow")
    CRC_ApplyRowTheme(row, theme)
    row.categoryData = cat
    row.translation = [0, y]
    return row
end function

' Record row in host lists and advance the vertical cursor.
function CRC_AppendRowRecord(host as object, row as object, y as integer, cat as object) as integer
    if host = invalid or row = invalid or cat = invalid then return y
    if host.rowTops <> invalid then host.rowTops.Push(y)
    if host.rowWidgets <> invalid then host.rowWidgets.Push(row)
    nextY = y + CRC_RowSlotHeight(cat)
    host.rowContentHeight = nextY
    return nextY
end function

' Append shell rows for newly fetched catalogue pages (pagination).
sub CRC_AppendShellRowsFrom(rowsHost as object, categories as object, host as object, theme as object, startIdx as integer)
    if rowsHost = invalid or categories = invalid or host = invalid then return
    if startIdx < 0 then startIdx = 0
    y = host.rowContentHeight
    if y = invalid then y = 0
    for i = startIdx to categories.Count() - 1
        if host.rowWidgets <> invalid and i < host.rowWidgets.Count() then continue for
        cat = categories[i]
        if cat = invalid then continue for
        row = CRC_CreateShellRow(rowsHost, cat, y, theme)
        if row = invalid then continue for
        if host.rowTops <> invalid then host.rowTops.Push(y)
        if host.rowWidgets <> invalid then host.rowWidgets.Push(row)
        y = y + CRC_RowSlotHeight(cat)
    end for
    host.rowContentHeight = y
end sub

function CRC_ContentHeight(rowTops as object, categories as object) as integer
    if rowTops = invalid or rowTops.Count() = 0 then return 0
    if categories = invalid or categories.Count() = 0 then return 0
    lastIdx = rowTops.Count() - 1
    if lastIdx < 0 or lastIdx >= categories.Count() then return 0
    cat = categories[lastIdx]
    if cat = invalid then return 0
    return rowTops[lastIdx] + CRC_RowSlotHeight(cat)
end function

sub CRC_ClearHost(rowsHost as object)
    if rowsHost = invalid then return
    for i = rowsHost.getChildCount() - 1 to 0 step -1
        rowsHost.removeChildIndex(i)
    end for
end sub
