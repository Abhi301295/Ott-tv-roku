' BrowseConstants.brs — shared geometry for listing grids (series / genre / new-release).

function BS_ItemsPerRow() as integer
    return 6
end function

' Parity VARAIBLE_CONSTANT.SERIES_LIST_PAGE.limit (27).
function BS_SeriesPageLimit() as integer
    return 27
end function

function BS_ListLeft() as integer
    return 56
end function

function BS_TitleY() as integer
    return 72
end function

function BS_RowStartY() as integer
    return 162
end function

function BS_RowPitch() as integer
    return 400
end function

function BS_ViewHeight() as integer
    return 900
end function

' VerticalCard with listType=true (parity with seriesRow listType prop).
function BS_ListCardW() as integer
    return 272
end function

function BS_ListCardH() as integer
    return 340
end function

function BS_ListCardPitch() as integer
    return BS_ListCardW() + HC_CardGap()
end function

function BS_ListEmptyCopy() as string
    return "We are sorry, we can not find the content"
end function

function GL_CataloguePageLimit() as integer
    return 10
end function

function GL_RowAnchorY() as integer
    return HC_OttAnchorY()
end function

' Scrollable viewport below the OTT hero anchor (no extra peek padding in clamp math).
function GL_GenreViewHeight() as integer
    return 1080 - GL_RowAnchorY()
end function

' Shell rows to materialize ahead/behind focus (parity Home MaterializeNearbyRows).
function GL_PrefetchAhead() as integer
    return 2
end function

' Genre row title — React genre-list Content.tsx fs-38 @ FontScale LARGE (2.375 * 1.2 * 16 ≈ 46).
function GL_RowTitleFontSize() as integer
    return 46
end function

' Genre empty state — React Content.tsx fs-30 @ FontScale LARGE (1.875 * 1.2 * 16 = 36).
function GL_EmptyTitleFontSize() as integer
    return 36
end function

' Background warm-up after first row reveal — materialize shell rows 1..N-1.
function GL_PrefetchWarmupMax() as integer
    return 5
end function
