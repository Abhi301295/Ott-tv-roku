' LiveTvLayout.brs — computed layout from src/features/livetv/index.tsx @ 1920×1080 FHD.
' Every value cites the React class or constant it mirrors.

function LT_CanvasH() as integer
    return 1080
end function

function LT_CanvasW() as integer
    return 1920
end function

' index.tsx PIXELS_PER_MINUTE
function LT_PixelsPerMinute() as integer
    return 10
end function

' index.tsx ROW_HEIGHT — channel + program row
function LT_RowHeight() as integer
    return 90
end function

' index.tsx TIMELINE_HEIGHT — ht-48; +8px on Roku so scrolled row labels never paint into markers.
function LT_TimelineHeight() as integer
    return 56
end function

' index.tsx VIEWPORT_HEIGHT — vertical scroll centering (not clip height)
function LT_ViewportHeight() as integer
    return 380
end function

' index.tsx BUFFER_ROWS
function LT_BufferRows() as integer
    return 6
end function

' ChannelCell w-[200px]
function LT_ChannelColWidth() as integer
    return 200
end function

' h-[45vh] @ 1080
function LT_HeroHeight() as integer
    return Int(LT_CanvasH() * 0.45)
end function

' h-[55vh] @ 1080
function LT_EpgHeight() as integer
    return LT_CanvasH() - LT_HeroHeight()
end function

' calc(55vh - TIMELINE_HEIGHT)
function LT_GridClipHeight() as integer
    return LT_EpgHeight() - LT_TimelineHeight()
end function

' Hero meta — absolute bottom-6 left-10 max-w-[50%]
function LT_HeroMetaLeft() as integer
    return 40
end function

function LT_HeroMetaBottom() as integer
    return 24
end function

function LT_HeroMetaMaxW(viewportW as integer) as integer
    return Int(viewportW * 0.5)
end function

' Hero gradient — from-[#0C111A] via-[#0C111A]/85 w-[60%]
function LT_HeroGradLeftW(viewportW as integer) as integer
    return Int(viewportW * 0.6)
end function

' Hero stack spacing (Tailwind mb-* / gap-*)
function LT_HeroSpotlightH() as integer
    return 18
end function

function LT_HeroSpotlightMb() as integer
    return 4
end function

function LT_HeroTitleMb() as integer
    return 8
end function

function LT_HeroTimeMb() as integer
    return 8
end function

function LT_HeroDescMb() as integer
    return 20
end function

function LT_HeroBtnGap() as integer
    return 16
end function

' text-4xl leading-tight — 36px × 1.25 per line, max 2 lines
function LT_HeroTitleLineH() as integer
    return Int(LT_FsHeroTitle() * 1.25 + 0.5)
end function

function LT_HeroTitleH() as integer
    return LT_HeroTitleLineH() * 2
end function

function LT_HeroTimeH() as integer
    ' text-sm leading-normal → ~20px line box (not just 14px em).
    return 20
end function

function LT_HeroTitleY() as integer
    return LT_HeroSpotlightH() + LT_HeroSpotlightMb()
end function

function LT_HeroTitleStackH(titleLines as integer) as integer
    lines = titleLines
    if lines < 1 then lines = 1
    if lines > 2 then lines = 2
    return LT_HeroTitleLineH() * lines
end function

function LT_HeroTimeY(titleLines as integer) as integer
    y = LT_HeroSpotlightH() + LT_HeroSpotlightMb()
    y = y + LT_HeroTitleStackH(titleLines) + LT_HeroTitleMb()
    return y
end function

' Description inherits hero meta max-w-[50%] (same container as title/time in index.tsx).
function LT_HeroDescWidth(viewportW as integer) as integer
    return LT_HeroMetaMaxW(viewportW)
end function

function LT_HeroDescNumLines() as integer
    return 3
end function

function LT_HeroDescH() as integer
    fs = LT_FsHeroMeta()
    lines = LT_HeroDescNumLines()
    ' text-sm leading-relaxed → line-height 1.625
    return Int(fs * 1.625 * lines + 0.5)
end function

function LT_HeroDescLineSpacing() as integer
    return 9
end function

function LT_HeroDescY(titleLines as integer) as integer
    return LT_HeroTimeY(titleLines) + LT_HeroTimeH() + LT_HeroTimeMb()
end function

function LT_HeroBtnRowY(titleLines as integer) as integer
    return LT_HeroDescY(titleLines) + LT_HeroDescH() + LT_HeroDescMb()
end function

function LT_HeroMetaStackH(titleLines as integer) as integer
    stackH = LT_HeroSpotlightH() + LT_HeroSpotlightMb()
    stackH = stackH + LT_HeroTitleStackH(titleLines) + LT_HeroTitleMb()
    stackH = stackH + LT_HeroTimeH() + LT_HeroTimeMb()
    stackH = stackH + LT_HeroDescH() + LT_HeroDescMb()
    stackH = stackH + LT_HeroBtnH()
    return stackH
end function

' px-6 py-3 rounded-full — 24h pad, 12v pad, ~18px icon
function LT_HeroBtnPadX() as integer
    return 24
end function

function LT_HeroBtnPadY() as integer
    return 12
end function

function LT_HeroBtnH() as integer
    return 44
end function

function LT_HeroBtnIconSize() as integer
    return 18
end function

function LT_HeroBtnIconGap() as integer
    return 8
end function

function LT_PlayNowBtnW() as integer
    return 152
end function

function LT_PlayBeginningBtnW() as integer
    return 248
end function

function LT_HeroBtnIconY() as integer
    return Int((LT_HeroBtnH() - LT_HeroBtnIconSize()) / 2)
end function

function LT_HeroBtnLabelX() as integer
    return LT_HeroBtnPadX() + LT_HeroBtnIconSize() + LT_HeroBtnIconGap()
end function

function LT_HeroBtnLabelW(btnW as integer) as integer
    return btnW - LT_HeroBtnLabelX() - LT_HeroBtnPadX()
end function

' Typography — Tailwind classes in hero (default rem, not fs-* tokens)
function LT_FsHeroSpotlight() as integer
    return 14
end function

function LT_FsHeroTitle() as integer
    return 36
end function

function LT_FsHeroMeta() as integer
    return 14
end function

function LT_FsHeroBtn() as integer
    return 14
end function

' Program card — p-3, text-[11px], text-[14px]
function LT_ProgramPad() as integer
    return 12
end function

function LT_FsProgramTime() as integer
    return 11
end function

function LT_FsProgramTitle() as integer
    return 14
end function

function LT_FsProgramDuration() as integer
    return 11
end function

' Channel cell — px-4 gap-3, logo h-12 w-[70px]
function LT_ChannelPadX() as integer
    return 16
end function

function LT_ChannelGap() as integer
    return 12
end function

function LT_LogoBoxW() as integer
    return 70
end function

function LT_LogoBoxH() as integer
    return 48
end function

function LT_LogoBoxRadius() as integer
    return 4
end function

function LT_FsChannelName() as integer
    return 14
end function

function LT_FsChannelNumber() as integer
    return 14
end function

' Timeline corner — px-6, text-sm
function LT_TimelineCornerPadX() as integer
    return 24
end function

function LT_FsTimelineToday() as integer
    return 14
end function

function LT_FsTimelineMarker() as integer
    return 12
end function

' Horizontal scroll margin — onCardFocus 150px
function LT_ScrollMarginX() as integer
    return 150
end function

' Program card edges — border-r border-b (Tailwind default 1px).
function LT_ProgramEdgePx() as integer
    return 1
end function

' Focus — React scale-[1.01] on program card; omitted on Roku (scales Labels → blurry text).
function LT_FocusScale() as float
    return 1.0
end function

function LT_FocusRingW() as integer
    return 4
end function

' Backdrop — opacity-70 / fade opacity-30, duration-300, swap at 150ms
function LT_BackdropOpacity() as float
    return 0.7
end function

function LT_BackdropFadeOpacity() as float
    return 0.3
end function

function LT_BackdropFadeMs() as integer
    return 150
end function

function LT_BackdropTransitionMs() as integer
    return 300
end function

' Live indicator — w-2.5 h-2.5, w-[1.5px] line
function LT_LiveDotSize() as integer
    return 10
end function

function LT_LiveLineW() as integer
    return 2
end function

function LT_InitialFocusDelayMs() as integer
    return 100
end function

' Y of heroMeta group — bottom-anchored stack; titleLines = 1 or 2 wrapped lines.
function LT_HeroMetaY(titleLines as integer) as integer
    return LT_HeroHeight() - LT_HeroMetaBottom() - LT_HeroMetaStackH(titleLines)
end function

' Channel text column X — px-4 + logo + gap-3
function LT_ChannelTextX() as integer
    return LT_ChannelPadX() + LT_LogoBoxW() + LT_ChannelGap()
end function

' Logo Y — vertically centered in ROW_HEIGHT
function LT_LogoBoxY() as integer
    return Int((LT_RowHeight() - LT_LogoBoxH()) / 2)
end function

' Channel name column — text-sm leading-snug + m-t-1 + text-sm (flex items-center row).
function LT_ChannelNameLineH() as integer
    return 20
end function

function LT_ChannelNumberMarginTop() as integer
    return 4
end function

function LT_ChannelNumberLineH() as integer
    return 20
end function

function LT_ChannelTextBlockH() as integer
    return LT_ChannelNameLineH() + LT_ChannelNumberMarginTop() + LT_ChannelNumberLineH()
end function

function LT_ChannelTextY() as integer
    return Int((LT_RowHeight() - LT_ChannelTextBlockH()) / 2)
end function
