' ThemeConfig.brs — parity with src/config/theme.config.ts and HEADER_STYLE in header.tsx.
' Home / header / hero cinematic|parallax / Genre card-focus follow BE feature flags.
' reelLayout remains static (theme.config.ts).

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

' ── ReelLayout (theme.config.ts reelLayout) ─────────────────────────────────
function TC_ReelLayoutDefault() as string
    return "DEFAULT"
end function

function TC_ReelLayoutNewUi() as string
    return "NEW_UI"
end function

function TC_ReelLayoutCleanUi() as string
    return "CLEAN_UI"
end function

' ── CardFocusTrailerPlayback ────────────────────────────────────────────────
function TC_CardFocusTrailerEnabled() as string
    return "ENABLED"
end function

function TC_CardFocusTrailerDisabled() as string
    return "DISABLED"
end function

' ═══════════════════════════════════════════════════════════════════════════════
' Active config
'
' BE (admin / business-config):
'   enableHomeBanner      → ThemeHomeLayout / ThemeIsOttHome / ThemeIsNetflixHome
'   enableSideBarMenu     → ThemeIsNetflixHeader / ThemeIsSidebarHeader / ThemeHeaderStyle
'   enableTrailerOnBanner → ThemeHeroBannerStyle cinematic|parallax + card-focus trailer
'   enableCardFocus       → Genre HeroBannerCardFocus vs Ott Banner
'
' Static (theme.config.ts):
'   ThemeReelLayout() → DEFAULT | NEW_UI | CLEAN_UI
'
' Profile avatars follow header: NETFLIX top bar → circular; SIDEBAR → square.
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

' React index.tsx: features.enableHomeBanner (not static theme.config.homeLayout).
function ThemeHomeLayout() as string
    if FeatureEnableHomeBanner() then return TC_HomeLayoutNetflix()
    return TC_HomeLayoutOtt()
end function

' React header.tsx: enableSideBarMenu=true → Netflix top bar; false → sidebar.
function ThemeHeaderStyle() as string
    if FeatureEnableSideBarMenu() then return TC_HeaderNetflix()
    return TC_HeaderSidebar()
end function

function ThemeHeroBannerStyle() as string
    if FeatureEnableTrailerOnBanner() then return TC_HeroCinematicZoom()
    return TC_HeroParallaxSlide()
end function

function ThemeReelLayout() as string
    ' Mirrors theme.config.ts reelLayout: ReelLayout.DEFAULT (static — not API).
    return TC_ReelLayoutDefault()
end function

' React theme.config cardFocusTrailerPlayback — still DISABLED for old Banner path.
' Card-focus / HeroBannerCardFocus trailers use features.enableTrailerOnBanner instead.
function ThemeCardFocusTrailerPlayback() as string
    return TC_CardFocusTrailerDisabled()
end function

' ── Predicates ───────────────────────────────────────────────────────────────
' React header.tsx: enableSideBarMenu=true → NetflixHeader (top bar); false → sidebar.
function ThemeIsNetflixHeader() as boolean
    return FeatureEnableSideBarMenu()
end function

function ThemeIsSidebarHeader() as boolean
    return not ThemeIsNetflixHeader()
end function

' React home/index.tsx: enableHomeBanner=true → NetflixContent; false → OTT Content.
function ThemeIsNetflixHome() as boolean
    return FeatureEnableHomeBanner()
end function

function ThemeIsOttHome() as boolean
    if FeatureEnableHomeBanner() then return false
    return true
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

' Netflix top bar: UP from the top content row opens the header.
' Sidebar: LEFT from the leftmost column opens the menu; UP stays in the vertical stack.
function NavUpOpensHeaderFromContent() as boolean
    return not ThemeIsSidebarHeader()
end function

function NavLeftOpensSidebarFromContent(isLeftmostColumn as boolean) as boolean
    return ThemeIsSidebarHeader() and isLeftmostColumn
end function
