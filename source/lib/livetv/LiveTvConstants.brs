' LiveTvConstants.brs — layout + hardcoded colors from src/features/livetv/index.tsx.

function LT_PixelsPerMinute() as integer
    return 10
end function

function LT_RowHeight() as integer
    return 90
end function

function LT_TimelineHeight() as integer
    return 48
end function

function LT_ChannelColWidth() as integer
    return 200
end function

function LT_HeroHeight() as integer
    return 486
end function

function LT_ViewportHeight() as integer
    return 380
end function

function LT_BufferRows() as integer
    return 6
end function

' React generates 210 channels; Roku mock caps count for render budget.
function LT_MockChannelCount() as integer
    return 24
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

function LT_ColorWhite() as string
    return HexToRokuColor("#ffffff", "ff")
end function

function LT_ColorGray300() as string
    return HexToRokuColor("#d1d5db", "ff")
end function

function LT_ColorGray400() as string
    return HexToRokuColor("#9ca3af", "ff")
end function

function LT_ColorZinc400() as string
    return HexToRokuColor("#a1a1aa", "ff")
end function

function LT_NowTickMs() as integer
    return 15000
end function
