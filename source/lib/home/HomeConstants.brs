' HomeConstants.brs — card/row types and paging (parity with variable.constant.ts).

' Turbo home load: rows first, hero trailer after first content is visible.
function HomeLoadTurboEnabled() as boolean
    return true
end function

function HC_TypeContinueWatching() as string
    return "CONTINUE_WATCHING"
end function

function HC_TypeBanner() as string
    return "BANNER"
end function

function HC_TypeContentList() as string
    return "CONTENT_LIST"
end function

function HC_TypeTopContents() as string
    return "TOP_CONTENTS"
end function

function HC_HomePageStart() as integer
    return 1
end function

function HC_HomePageLimit() as integer
    return 4
end function

' Static theme default (parity with theme.config.ts homeLayout).
function HC_HomeLayoutNetflix() as string
    return "NETFLIX"
end function

function HC_HomeLayoutOtt() as string
    return "OTT"
end function

' Home page fill behind hero + rows — hardcoded, not API tokens (light themes remap neutrals).
function HC_HomeCinematicBg() as string
    return "0x0a0a0aff"
end function

function HC_HomeOttPageBg() as string
    return "0xf8f8f8ff"
end function

function HC_WelcomePhaseDwellSec() as float
    return 0.55
end function

' Profile → Home prefetch window (welcome overlay stays on ProfileScreen).
function HC_PrefetchMaxMs() as integer
    return 12000
end function

function HC_PrefetchMaxRetries() as integer
    return 2
end function

function HC_PrefetchRetryDelaySec() as float
    return 0.6
end function

' Cinematic hero timing (parity with heroBannerCinematic.tsx).
function HC_HeroHeight() as integer
    return 918
end function

function HC_HeroLeftGradWidthPct() as float
    return 0.65
end function

function HC_HeroLeftGradHeight() as integer
    return HC_HeroHeight() + 200
end function

' Gap after meta entrance starts before the poster fades in (meta → poster ordering).
function HC_HeroMetaBeforePosterSec() as float
    return 0.15
end function

' Cinematic metaHost fade + slide-up (heroBannerCinematic.tsx textVisible).
function HC_HeroMetaEntranceSec() as float
    return 0.6
end function

' Parallax frost-strip meta fade-in after slide settles.
function HC_HeroContentRevealSec() as float
    return 0.5
end function

function HC_HeroParallaxAccentSec() as float
    return 0.7
end function

function HC_HeroParallaxSwipeSec() as float
    return 5.5
end function

function HC_HeroPageFlipSwipeSec() as float
    return 5.0
end function

function HC_HeroOttFadeSec() as float
    return 0.7
end function

function HC_HeroSwipeMs() as integer
    return 15000
end function

function HC_HeroZoomSec() as float
    return 8.0
end function

' Minimum poster display before trailer playback (parity TRAILER_LOAD_DELAY 2500ms).
function HC_HeroTrailerDelaySec() as float
    return 2.5
end function

' Max time the loading skeleton waits for the hero poster to paint before it drops
' anyway, so a slow/blocked image can never strand the shimmer on screen.
function HC_HomeSkeletonMaxSec() as float
    if HomeLoadTurboEnabled() then return 2.0
    return 5.0
end function

' Hard ceiling for a single select-profile attempt. Reset on every retry/request so a
' hung socket retries instead of failing the whole flow after one slow response.
function HC_SelectWatchdogSec() as float
    return 20.0
end function

' How long row building may wait for the hero trailer to go live before it builds
' anyway. Resolve may start when the poster paints, but playback waits TRAILER_LOAD_DELAY;
' this window gives the preview the render thread first. If a slide has no trailer, rows
' still appear promptly.
function HC_RowBuildGateSec() as float
    if HomeLoadTurboEnabled() then return 0.0
    return 3.5
end function

' OTT has no hero trailer — do not hold row build for the cinematic preview gate.
function HC_RowBuildGateSecForLayout(homeLayout as string) as float
    if homeLayout = HC_HomeLayoutOtt() then return 0.0
    return HC_RowBuildGateSec()
end function

' Max wait for continue-watching before rows may build (OTT builds on categories;
' Netflix waits for both APIs but this caps a hung CW endpoint).
function HC_ContinueBootMaxSec() as float
    return 4.0
end function

' Safety net for the rows shimmer — mirror HC_HomeSkeletonMaxSec for the hero.
function HC_RowsSkeletonMaxSec() as float
    if HomeLoadTurboEnabled() then return 1.5
    return 8.0
end function

function HC_RowsSkeletonMaxSecForLayout(homeLayout as string) as float
    if homeLayout = HC_HomeLayoutOtt() then return 5.0
    return HC_RowsSkeletonMaxSec()
end function

function HC_RowsForceHideSec() as float
    return 2.0
end function

' OTT hero banner: do not block boot on a slow CDN poster — fire posterReady after this.
function HC_OttPosterReadyMaxSec() as float
    return 2.0
end function
