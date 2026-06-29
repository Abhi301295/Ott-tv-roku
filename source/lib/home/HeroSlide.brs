' HeroSlide.brs — shared slide index math for all hero variants.
'
' HeroBannerHost dispatches by theme; each active child exposes the same callFunc
' surface for HomeScreen D-pad routing:
'   HeroGoNext, HeroGoPrev, HeroToggleMute, PauseAutoAdvance, ResumeAutoAdvance,
'   PauseHeroPlayback, ResumeHeroPlayback
'
' ⚠ Parity Note — slide transition differs per variant (do not unify visuals here):
'   Cinematic  — meta-first crossfade + optional trailer (heroBannerCinematic.tsx)
'   Parallax   — vertical slide + frost thumb strip (parallaxSlide hero)
'   PageFlip   — curl/page-flip strip (pageFlip hero)
'   OTT        — single activeItem fade/scale, no carousel (banner/index.tsx)

function HeroSlideCount(items as object) as integer
    if items = invalid then return 0
    return items.Count()
end function

function HeroSlideNextIndex(current as integer, count as integer) as integer
    if count < 2 then return current
    return (current + 1) mod count
end function

function HeroSlidePrevIndex(current as integer, count as integer) as integer
    if count < 2 then return current
    prev = current - 1
    if prev < 0 then prev = count - 1
    return prev
end function

function HeroSlideItemAt(items as object, index as integer) as object
    if items = invalid then return invalid
    if index < 0 or index >= items.Count() then return invalid
    return items[index]
end function
