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

' ── HeaderType (header.tsx HEADER_STYLE / theme.config.ts headerStyle) ─────
function TC_HeaderSidebar() as string
    return "SIDEBAR"
end function

function TC_HeaderNetflix() as string
    return "NETFLIX"
end function

' ── HeroBannerStyle (heroBannerSwitch.tsx / theme.config.ts heroBannerStyle) ─
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
' Active layout config — change the return values below (mirrors theme.config.ts).
' headerStyle also controls Profile UI: NETFLIX → circular avatars, SIDEBAR → square cards.
'
' Layout presets (change ThemeHomeLayout / ThemeHeaderStyle / ThemeHeroBannerStyle):
'
'   Case 1 — Baseline Netflix home + top bar + cinematic hero
'     ThemeHomeLayout()      → TC_HomeLayoutNetflix()
'     ThemeHeaderStyle()     → TC_HeaderNetflix()
'     ThemeHeroBannerStyle() → TC_HeroCinematicZoom()
'
'   Case 2 — Netflix home + top bar + page-flip hero
'     ThemeHomeLayout()      → TC_HomeLayoutNetflix()
'     ThemeHeaderStyle()     → TC_HeaderNetflix()
'     ThemeHeroBannerStyle() → TC_HeroPageFlip()
'
'   Case 3 — Netflix home + top bar + parallax hero
'     ThemeHomeLayout()      → TC_HomeLayoutNetflix()
'     ThemeHeaderStyle()     → TC_HeaderNetflix()
'     ThemeHeroBannerStyle() → TC_HeroParallaxSlide()
'
'   Case 4 — Netflix home + sidebar + cinematic hero (Profile: square avatars)
'     ThemeHomeLayout()      → TC_HomeLayoutNetflix()
'     ThemeHeaderStyle()     → TC_HeaderSidebar()
'     ThemeHeroBannerStyle() → TC_HeroCinematicZoom()
'
'   Case 5 — OTT home + top bar (hero style ignored; banner follows row focus)
'     ThemeHomeLayout()      → TC_HomeLayoutOtt()
'     ThemeHeaderStyle()     → TC_HeaderNetflix()
'     ThemeHeroBannerStyle() → (any — not used for OTT home)
'
'   Case 6 — OTT home + sidebar (Profile: square avatars)
'     ThemeHomeLayout()      → TC_HomeLayoutOtt()
'     ThemeHeaderStyle()     → TC_HeaderSidebar()
'     ThemeHeroBannerStyle() → (any — not used for OTT home)
'
' After editing: make sim
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
    return TC_HomeLayoutNetflix()
end function

function ThemeHeaderStyle() as string
    return TC_HeaderNetflix()
end function

function ThemeHeroBannerStyle() as string
    return TC_HeroCinematicZoom()
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

function ThemeIsNetflixHeader() as boolean
    return ThemeHeaderStyle() = TC_HeaderNetflix()
end function

' True when the layout exposes top Netflix bar or left sidebar nav.
function ThemeHasHomeNav() as boolean
    return ThemeIsSidebarHeader() or ThemeIsNetflixHeader()
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
