' HomeConstants.brs — card/row types and paging (parity with variable.constant.ts).

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

' Cinematic hero timing (parity with heroBannerCinematic.tsx).
function HC_HeroHeight() as integer
    return 918
end function

function HC_HeroSwipeMs() as integer
    return 15000
end function

function HC_HeroCrossfadeSec() as float
    return 1.2
end function

function HC_HeroZoomSec() as float
    return 8.0
end function

' Delay before fetching/loading a slide's trailer (parity TRAILER_LOAD_DELAY 2500ms).
function HC_HeroTrailerDelaySec() as float
    return 2.5
end function

' Max time the loading skeleton waits for the hero poster to paint before it drops
' anyway, so a slow/blocked image can never strand the shimmer on screen.
function HC_HomeSkeletonMaxSec() as float
    return 5.0
end function
