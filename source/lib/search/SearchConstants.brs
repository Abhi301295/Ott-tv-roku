' SearchConstants.brs — parity with React search token_spec @ FontScale LARGE, FHD 1080.

function SR_PageBg() as string
    return "0x1f1f22ff"
end function

function SR_OuterMarginTop() as integer
    return 48
end function

function SR_ColGap() as integer
    return 24
end function

function SR_ColPadX() as integer
    return 24
end function

function SR_ColPadTop() as integer
    return 40
end function

function SR_ColMarginTop() as integer
    return 40
end function

function SR_LeftBasisPct() as integer
    return 40
end function

function SR_RightBasisPct() as integer
    return 60
end function

function SR_ContentPadTop() as integer
    return SR_OuterMarginTop() + SR_ColMarginTop() + SR_ColPadTop()
end function

function SR_InputH() as integer
    return 70
end function

function SR_InputPadX() as integer
    return 16
end function

function SR_InputFontSize() as integer
    return 34
end function

function SR_InputPlaceholderFontSize() as integer
    return 28
end function

function SR_InputBorderW() as integer
    return 2
end function

function SR_InputWrapperMarginLeft() as integer
    return 0
end function

function SR_KeyboardMarginTop() as integer
    return 32
end function

function SR_KeyboardPanelPadX() as integer
    return 4
end function

function SR_KeyboardPanelPadBottom() as integer
    return 0
end function

function SR_KeyH() as integer
    return 70
end function

function SR_KeyW() as integer
    return 60
end function

function SR_KeyWAa() as integer
    return 55
end function

function SR_KeyWSpecial() as integer
    return 70
end function

function SR_KeyWSpace() as integer
    return 300
end function

function SR_KeyWClear() as integer
    return 220
end function

function SR_KeyGap() as integer
    ' Horizontal gap between keys — fits 10-key row with outer border width in 768px column.
    return 12
end function

function SR_KeyRowGap() as integer
    return 14
end function

function SR_KeyBottomGap() as integer
    return 16
end function

function SR_KeyFocusScale() as float
    return 1.1
end function

function SR_KeyFontSize() as integer
    return 24
end function

function SR_KeySpecialFontSize() as integer
    return 19
end function

function SR_GridMarginLeft() as integer
    return 60
end function

function SR_GridGapY() as integer
    return 24
end function

function SR_GridGapX() as integer
    return 16
end function

function SR_GridMinCol() as integer
    return 300
end function

function SR_CardW() as integer
    return 280
end function

function SR_CardH() as integer
    return 150
end function

function SR_CardMarginRight() as integer
    return 10
end function

function SR_CardTitleMarginTop() as integer
    return 40
end function

function SR_CardTitleMaxW() as integer
    return 230
end function

function SR_CardTitleFontSize() as integer
    return 24
end function

function SR_CardTitleLineH() as integer
    return 22
end function

function SR_CardFocusBorderW() as integer
    return 3
end function

function SR_CardRowPitch() as integer
    return SR_CardTitleMarginTop() + SR_CardH() + SR_CardTitleMarginTop() + SR_CardTitleLineH() + SR_GridGapY()
end function

function SR_ResultCap() as integer
    return 15
end function

' Pinned Tailwind neutrals — do NOT use API tertiary shades (see CardCommon.brs / VideoPlayerScreen).
function SR_PinPageBg() as string
    return "0x1f1f22ff"
end function

function SR_PinInputBg() as string
    return "0x181818ff"
end function

function SR_PinInputBorderFocus() as string
    return "0xc8c8c8ff"
end function

function SR_PinKeyBg() as string
    return "0x0a0a0aff"
end function

function SR_PinKeyBorder() as string
    return "0x181818ff"
end function

function SR_PinText() as string
    return "0xffffffff"
end function

function SR_PinPlaceholder() as string
    return "0x888888ff"
end function

function SR_PinPrimary500() as string
    return "0x0092ffff"
end function

function SR_PinPrimary700() as string
    return "0x80bbe9ff"
end function

function SR_CardColPitch() as integer
    return SR_CardW() + SR_GridGapX()
end function

' React bg-neutral-950 is hardcoded #0a0a0a in Tailwind build (not var(--neutral-950)).
function SR_KeyFillColor() as string
    return "0x0a0a0aff"
end function

function SR_PlaceholderColor() as string
    return "0x6b7280ff"
end function

function SR_KeyBorderColor() as string
    return "0x404040ff"
end function

function SR_KeyCornerRadius() as integer
    return 12
end function

function SR_PanelCornerRadius() as integer
    return 16
end function

function SR_PanelDropShadowUri() as string
    return "pkg:/images/ui/search_keyboard_shadow.png"
end function

function SR_PanelShadowSpread() as integer
    ' L/R shadow width only — keep in sync with SHADOW_SPREAD_H in gen_search_keyboard_assets.py
    return 8
end function

function SR_PanelShadowBlurH() as integer
    return 8
end function

function SR_PanelShadowBlurB() as integer
    return 12
end function

function SR_PanelShadowDropY() as integer
    return 16
end function

function SR_PanelDropShadowOpacity() as float
    return 0.38
end function

function SR_KeyOuterH() as integer
    return SR_KeyH() + (2 * SR_InputBorderW())
end function

function SR_KeyFillUri(kw as integer, kh as integer) as string
    return "pkg:/images/ui/search_key_fill_" + Stri(kw).Trim() + "x" + Stri(kh).Trim() + ".png"
end function

function SR_ApiLimit() as integer
    return 30
end function

function SR_InputPlaceholder() as string
    return "Search Raven, She..."
end function

function SR_EmptyCopy() as string
    return "We are sorry, we can not find the content"
end function

function SR_LoadingCopy() as string
    return "Loading"
end function

function SR_KeyBackspace() as string
    return "⌫"
end function

function SR_KeyAa() as string
    return "Aa"
end function

function SR_Key123() as string
    return "123"
end function

function SR_KeyAbc() as string
    return "ABC"
end function

function SR_KeySpace() as string
    return "Space"
end function

function SR_KeyClear() as string
    return "CLEAR"
end function
