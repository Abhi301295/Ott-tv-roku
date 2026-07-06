' LiveTvConstants.brs — hardcoded colors + timing from src/features/livetv/index.tsx.
' Layout numbers live in LiveTvLayout.brs.

function LT_MockChannelCount() as integer
    return 24
end function

function LT_NowTickMs() as integer
    return 15000
end function

function LT_DisplayTimelineStartMs() as longinteger
    return LT_LocalMidnightMs()
end function

function LT_DisplayTimelineEndMs() as longinteger
    return LT_DisplayTimelineStartMs() + (36& * 60& * 60& * 1000&)
end function

function LT_ColorBg() as string
    return HexToRokuColor("#0C111A", "ff")
end function

function LT_ColorChannelBg() as string
    return HexToRokuColor("#0C111A", "ff")
end function

function LT_ColorFocusBg() as string
    return HexToRokuColor("#151D2A", "ff")
end function

function LT_ColorFocusAccent() as string
    return HexToRokuColor("#E5007A", "ff")
end function

function LT_ColorProgramBg() as string
    return HexToRokuColor("#0B0F17", "4d")
end function

function LT_ColorPinkSpotlight() as string
    return HexToRokuColor("#ec4899", "ff")
end function

function LT_ColorPinkRing30() as string
    return HexToRokuColor("#E5007A", "4d")
end function

function LT_ColorFocusShadow() as string
    return HexToRokuColor("#E5007A", "59")
end function

function LT_ColorWhite() as string
    return HexToRokuColor("#ffffff", "ff")
end function

function LT_ColorGray300() as string
    return HexToRokuColor("#d1d5db", "ff")
end function

function LT_ColorRed500() as string
    return HexToRokuColor("#ef4444", "ff")
end function

function LT_ColorBlue400() as string
    return HexToRokuColor("#60a5fa", "ff")
end function

function LT_ColorYellow400() as string
    return HexToRokuColor("#facc15", "ff")
end function

function LT_ColorGray400() as string
    return HexToRokuColor("#9ca3af", "ff")
end function

function LT_ColorGray500() as string
    return HexToRokuColor("#6b7280", "ff")
end function

function LT_ColorZinc400() as string
    return HexToRokuColor("#a1a1aa", "ff")
end function

function LT_ColorBorderWhite5() as string
    return HexToRokuColor("#ffffff", "0d")
end function

function LT_ColorLogoBoxBg() as string
    return HexToRokuColor("#ffffff", "0d")
end function

function LT_ColorLogoBoxBorder() as string
    return HexToRokuColor("#ffffff", "1a")
end function

function LT_ColorBtnBorderWhite40() as string
    return HexToRokuColor("#ffffff", "66")
end function

function LT_ColorBtnFocusBgWhite10() as string
    return HexToRokuColor("#ffffff", "1a")
end function

function LT_ColorBtnFocusRingWhite20() as string
    return HexToRokuColor("#ffffff", "33")
end function

function LT_ColorAccentRing50() as string
    return HexToRokuColor("#E5007A", "80")
end function

function LT_PillOutlineFocusUri() as string
    return "pkg:/images/ui/livetv_pill_outline_focus.png"
end function

function LT_PillOutlineUri() as string
    return "pkg:/images/ui/livetv_pill_outline.png"
end function

function LT_PillFillUri() as string
    return "pkg:/images/ui/livetv_pill_fill.png"
end function

function LT_PillRingUri() as string
    return "pkg:/images/ui/livetv_pill_ring.png"
end function

function LT_PlayNowRingUri() as string
    return "pkg:/images/ui/livetv_play_ring.png"
end function

function LT_PlayNowFillUri() as string
    return "pkg:/images/ui/livetv_play_fill.png"
end function

function LT_PlayIconFillUri() as string
    return "pkg:/images/ui/livetv_ic_play_fill.png"
end function

function LT_PlayIconStrokeUri() as string
    return "pkg:/images/ui/livetv_ic_play_stroke.png"
end function

function LT_PlayIconStrokeWhiteUri() as string
    return "pkg:/images/ui/livetv_ic_play_stroke_white.png"
end function
