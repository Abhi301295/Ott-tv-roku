' MyListConstants.brs — parity with features/list-detail/ @ FHD.

function WL_EmptyCopy() as string
    return "No data in watchList"
end function

function WL_EmptyMaxW() as integer
    return 355
end function

function WL_EmptyFontSize() as integer
    ' React ListDetailCol.tsx fs-36 @ FontScale LARGE (2.25 * 1.2 * 16 ≈ 43).
    return 43
end function

function WL_EmptyTopY() as integer
    ' React pt-[20%] on the empty-state column.
    return Int(1080 * 0.20)
end function

function WL_PageLimit() as integer
    return 27
end function

' ── ListDetailCard geometry (parity listDetailCard.tsx) ─────────────────────

function WL_ThumbW() as integer
    return 368
end function

function WL_ThumbH() as integer
    return 208
end function

function WL_CardGap() as integer
    ' React listDetailRow gap-20.
    return 20
end function

function WL_CardPad() as integer
    ' React p-5 (theme --p-5 = 5px).
    return 5
end function

function WL_CardBorder() as integer
    ' React bw-3 focus border.
    return 3
end function

function WL_CardFocusRadius() as integer
    ' React radius-16 on the focus wrapper.
    return 16
end function

function WL_CardW() as integer
  ' Content width (thumb + text block).
    return WL_ThumbW()
end function

function WL_CardH() as integer
    ' Thumb + title block + meta row (m-t-24, lh-32, m-b-4, m-t-5, lh-21, m-b-10).
    return WL_ThumbH() + 24 + 32 + 4 + 5 + 22 + 10
end function

function WL_CardOuterW() as integer
    return WL_CardW() + 2 * WL_CardPad()
end function

function WL_CardOuterH() as integer
    return WL_CardH() + 2 * WL_CardPad()
end function

function WL_CardBorderBleed() as integer
    return WL_CardBorder()
end function

function WL_CardPitch() as integer
    return WL_CardOuterW() + WL_CardGap()
end function

function WL_RowPitch() as integer
    ' React listDetailRow m-b-60.
    return WL_CardOuterH() + 60
end function

function WL_ViewHeight() as integer
    return 900
end function

function WL_RowStartY() as integer
    return 162
end function

function WL_ItemsPerRow(viewportW as integer) as integer
    if viewportW < 1 then viewportW = 1808
    pitch = WL_CardPitch()
    if pitch < 1 then return 4
    n = Int((viewportW + WL_CardGap()) / pitch)
    if n < 1 then n = 1
    if n > 6 then n = 6
    return n
end function

function WL_TitleFontSize() as integer
    ' React fs-28 @ FontScale LARGE (1.75 * 1.2 * 16 ≈ 34).
    return 34
end function

function WL_TypeFontSize() as integer
    return 18
end function

function WL_LangFontSize() as integer
    return 14
end function

function WL_MetaDotSize() as integer
    return 10
end function
