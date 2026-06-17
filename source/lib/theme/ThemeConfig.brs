' ThemeConfig.brs — parity with src/config/theme.config.ts and HEADER_STYLE in header.tsx.
' All layout variants are static build-time config (React does not read these from the API).

' ── AppTheme (theme.config.ts) ───────────────────────────────────────────────
function TC_AppThemeDark() as string
    return "DARK"
end function

function TC_AppThemeLight() as string
    return "LIGHT"
end function

function TC_AppThemeBlueDark() as string
    return "BLUE_DARK"
end function

function TC_AppThemeRed() as string
    return "RED"
end function

' ── FontScale ────────────────────────────────────────────────────────────────
function TC_FontScaleSmall() as string
    return "SMALL"
end function

function TC_FontScaleMedium() as string
    return "MEDIUM"
end function

function TC_FontScaleLarge() as string
    return "LARGE"
end function

' ── DeviceSize ─────────────────────────────────────────────────────────────
function TC_DeviceHd720() as string
    return "HD_720"
end function

function TC_DeviceFhd1080() as string
    return "FHD_1080"
end function

function TC_DeviceUhd4k() as string
    return "UHD_4K"
end function

' ── HomeLayout (theme.config.ts homeLayout) ──────────────────────────────────
function TC_HomeLayoutOtt() as string
    return "OTT"
end function

function TC_HomeLayoutNetflix() as string
    return "NETFLIX"
end function

' ── HeaderType (header.tsx HEADER_STYLE) ─────────────────────────────────────
function TC_HeaderSidebar() as string
    return "SIDEBAR"
end function

function TC_HeaderNetflix() as string
    return "NETFLIX"
end function

' ── HeroBannerStyle (heroBannerSwitch.tsx) ───────────────────────────────────
function TC_HeroPageFlip() as string
    return "PAGE_FLIP"
end function

function TC_HeroCinematicZoom() as string
    return "CINEMATIC_ZOOM"
end function

function TC_HeroParallaxSlide() as string
    return "PARALLAX_SLIDE"
end function

' ═══════════════════════════════════════════════════════════════════════════════
' Layout test cases — parity with src/config/layoutTest.config.ts (cases 1–6).
' Change LT_CaseId() return value (1–6), rebuild, reload Home.
' ═══════════════════════════════════════════════════════════════════════════════
function LT_CaseId() as integer
  ' ← CHANGE THIS NUMBER (1–6) to match React ACTIVE_LAYOUT_TEST_CASE
    return 4
end function

function LT_HomeLayout(caseId as integer) as string
    if caseId = 5 or caseId = 6 then return TC_HomeLayoutOtt()
    return TC_HomeLayoutNetflix()
end function

function LT_HeaderStyle(caseId as integer) as string
    if caseId = 4 or caseId = 6 then return TC_HeaderSidebar()
    return TC_HeaderNetflix()
end function

function LT_HeroStyle(caseId as integer) as string
    if caseId = 2 then return TC_HeroPageFlip()
    if caseId = 3 then return TC_HeroParallaxSlide()
    return TC_HeroCinematicZoom()
end function

function LT_CaseLabel(caseId as integer) as string
    if caseId = 1 then return "Baseline Netflix + top bar + cinematic"
    if caseId = 2 then return "Netflix + top bar + page-flip hero"
    if caseId = 3 then return "Netflix + top bar + parallax hero"
    if caseId = 4 then return "Netflix + sidebar + cinematic"
    if caseId = 5 then return "OTT focus-reactive banner + top bar"
    if caseId = 6 then return "OTT focus-reactive banner + sidebar"
    return "unknown"
end function

function LT_PrintChecks(caseId as integer) as string
    if caseId = 1 then return "top bar|auto hero ~15s|rows slide at 65vh"
    if caseId = 2 then return "page-flip hero ~5s|up-next chip right|dot indicators"
    if caseId = 3 then return "vertical parallax ~5.5s|frost strip bottom|staggered meta"
    if caseId = 4 then return "left sidebar LEFT/RIGHT|content offset right|auto hero"
    if caseId = 5 then return "LEFT/RIGHT changes banner|no auto-rotate|row overlap"
    if caseId = 6 then return "sidebar + OTT banner follows card focus"
    return ""
end function

function ThemeActiveLayoutTestCase() as integer
    return LT_CaseId()
end function

' ═══════════════════════════════════════════════════════════════════════════════
' Active config — driven by LT_CaseId() above (mirrors layoutTest.config.ts).
' ═══════════════════════════════════════════════════════════════════════════════
function ThemeAppTheme() as string
    return TC_AppThemeDark()
end function

function ThemeFontScale() as string
    return TC_FontScaleLarge()
end function

function ThemeDeviceSize() as string
    return TC_DeviceFhd1080()
end function

function ThemeHomeLayout() as string
    return LT_HomeLayout(ThemeActiveLayoutTestCase())
end function

function ThemeHeaderStyle() as string
    return LT_HeaderStyle(ThemeActiveLayoutTestCase())
end function

function ThemeHeroBannerStyle() as string
    return LT_HeroStyle(ThemeActiveLayoutTestCase())
end function

' ── Predicates ───────────────────────────────────────────────────────────────
function ThemeIsNetflixHome() as boolean
    return ThemeHomeLayout() = TC_HomeLayoutNetflix()
end function

function ThemeIsOttHome() as boolean
    return ThemeHomeLayout() = TC_HomeLayoutOtt()
end function

function ThemeIsSidebarHeader() as boolean
    return ThemeHeaderStyle() = TC_HeaderSidebar()
end function

function ThemeIsLayoutCase4() as boolean
    return ThemeActiveLayoutTestCase() = 4
end function

function ThemeIsNetflixHeader() as boolean
    return ThemeHeaderStyle() = TC_HeaderNetflix()
end function

' Sidebar widths — parity header.tsx collapsed (~100px) vs expanded (~220px).
function ThemeSidebarCollapsedWidth() as integer
    return 100
end function

function ThemeSidebarExpandedWidth() as integer
    return 232
end function

' Horizontal offset when the sidebar header is active (content sits to the right).
function ThemeSidebarOffset(expanded as boolean) as integer
    if not ThemeIsSidebarHeader() then return 0
    if expanded then return ThemeSidebarExpandedWidth()
    return ThemeSidebarCollapsedWidth()
end function

function ThemeContentOffsetX() as integer
    return ThemeSidebarOffset(false)
end function

function ThemeLayoutSummary() as string
    c = ThemeActiveLayoutTestCase()
    return "[LAYOUT TEST] case " + c.ToStr() + ": " + LT_CaseLabel(c) + " | home=" + ThemeHomeLayout() + " header=" + ThemeHeaderStyle() + " hero=" + ThemeHeroBannerStyle()
end function

function ThemeLayoutChecklist() as string
    return LT_PrintChecks(ThemeActiveLayoutTestCase())
end function
