sub init()
    m.items = []
    m.activeIndex = 0
    m.isFading = false

    m.nextPoster = m.top.findNode("nextPoster")
    m.nextLayer = m.top.findNode("nextLayer")
    m.activePoster = m.top.findNode("activePoster")
    m.activeLayer = m.top.findNode("activeLayer")
    m.metaHost = m.top.findNode("metaHost")
    m.titleLabel = m.top.findNode("titleLabel")
    m.ratingHost = m.top.findNode("ratingHost")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.qualityBadge = m.top.findNode("qualityBadge")
    m.qualityBg = m.top.findNode("qualityBg")
    m.qualityLabel = m.top.findNode("qualityLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.barsHost = m.top.findNode("barsHost")
    m.heroBarFill = m.top.findNode("heroBarFill")
    m.counterHost = m.top.findNode("counterHost")
    m.counterCurrent = m.top.findNode("counterCurrent")
    m.counterTotal = m.top.findNode("counterTotal")
    m.swipeTimer = m.top.findNode("swipeTimer")
    m.fadeAnim = m.top.findNode("fadeAnim")
    m.zoomAnim = m.top.findNode("zoomAnim")
    m.nextZoomAnim = m.top.findNode("nextZoomAnim")
    m.barAnim = m.top.findNode("barAnim")
    m.barInterp = m.top.findNode("barInterp")
    m.metaAnim = m.top.findNode("metaAnim")

    m.trailerVideo = m.top.findNode("trailerVideo")
    m.trailerTimer = m.top.findNode("trailerTimer")
    m.videoFadeAnim = m.top.findNode("videoFadeAnim")
    m.posterGlowAnim = m.top.findNode("posterGlowAnim")
    m.muteBtn = m.top.findNode("muteBtn")
    m.muteIcon = m.top.findNode("muteIcon")
    m.prevArrow = m.top.findNode("prevArrow")
    m.nextArrow = m.top.findNode("nextArrow")
    m.prevFocusRing = m.top.findNode("prevFocusRing")
    m.nextFocusRing = m.top.findNode("nextFocusRing")
    m.muteFocusRing = m.top.findNode("muteFocusRing")

    m.isVideoPlaying = false
    m.posterReadyFired = false
    m.firstReveal = true
    m.playingForIndex = -1
    ' Index the in-progress crossfade is heading to (-1 = auto-advance to the next slide).
    m.fadeTargetIndex = -1
    ' True while a crossfade is settling onto the next slide: the already-loaded next
    ' layer stays visible until the active layer's copy of the new poster decodes, so the
    ' previous slide's image is never flashed back during the swap.
    m.crossfadeLanding = false
    ' Upcoming slide's poster, preloaded onto the next layer only AFTER the landing swap
    ' (so the next layer keeps showing the just-revealed slide until then).
    m.pendingNextUri = invalid
    m.trailerCache = {}
    m.detailTask = invalid

    m.viewportW = 1920
    ApplyViewportLayout()

    m.swipeTimer.duration = HC_HeroSwipeMs() / 1000.0
    m.fadeAnim.duration = HC_HeroCrossfadeSec()
    m.zoomAnim.duration = HC_HeroZoomSec()
    if m.nextZoomAnim <> invalid then m.nextZoomAnim.duration = HC_HeroZoomSec()
    m.barAnim.duration = HC_HeroSwipeMs() / 1000.0
    m.trailerTimer.duration = HC_HeroTrailerDelaySec()

    m.swipeTimer.observeField("fire", "OnSwipeTimer")
    m.fadeAnim.observeField("state", "OnFadeAnimState")
    m.trailerTimer.observeField("fire", "OnTrailerTimer")
    m.trailerVideo.observeField("state", "OnTrailerState")
    m.top.observeField("visible", "OnVisibleChanged")
    if m.activePoster <> invalid then m.activePoster.observeField("loadStatus", "OnActivePosterLoad")
    if m.nextPoster <> invalid then m.nextPoster.observeField("loadStatus", "OnNextPosterLoad")
end sub

sub OnContentWidthChanged()
    ApplyViewportLayout()
end sub

' Reposition right-edge controls for the usable width after a left sidebar inset.
sub ApplyViewportLayout()
    w = m.top.contentWidth
    if w = invalid or w < 400 then w = 1920
    m.viewportW = w

    m.top.clippingRect = [0, 0, w, 1080]
    m.top.clippingRectClipsChildren = true

    heroBg = m.top.findNode("heroBg")
    if heroBg <> invalid then heroBg.width = w

    bottomVig = m.top.findNode("bottomVignette")
    if bottomVig <> invalid then bottomVig.width = w

    if m.prevArrow <> invalid then m.prevArrow.translation = [10, 435]
    if m.nextArrow <> invalid then m.nextArrow.translation = [w - 58, 435]
    if m.muteBtn <> invalid then m.muteBtn.translation = [w - 80, 520]
    if m.counterHost <> invalid then m.counterHost.translation = [w - 220, 600]
end sub

sub OnVisibleChanged()
    if m.top.visible = true then
        StartSwipeTimer()
        ScheduleTrailer()
    else
        StopSwipeTimer()
        StopTrailer()
        CancelDetailFetch()
    end if
end sub

' ── Focus + D-pad actions (parity with the portal arrows / mute button) ──────
' The parent HomeScreen owns the focus state and tells the hero which control is
' focused via the focusTarget field; the hero just renders the ring highlight.
sub OnFocusTargetChanged()
    t = m.top.focusTarget
    SetBtnFocus(m.prevArrow, m.prevFocusRing, (t = "prev"))
    SetBtnFocus(m.nextArrow, m.nextFocusRing, (t = "next"))
    SetBtnFocus(m.muteBtn, m.muteFocusRing, (t = "mute"))
end sub

sub SetBtnFocus(grp as object, ring as object, on as boolean)
    if ring <> invalid then
        if on then ring.opacity = 1.0 else ring.opacity = 0.0
    end if
    if grp <> invalid and grp.id <> "muteBtn" then
        if on then grp.opacity = 1.0 else grp.opacity = 0.85
    end if
end sub

' OK on the next arrow → advance one slide (parity triggerFade).
function HeroGoNext() as void
    if ItemCount() < 2 then return
    RestartSwipeTimer()
    GoToSlide(NextSlideIndex())
end function

' OK on the prev arrow → go back one slide (parity goToPrev).
function HeroGoPrev() as void
    if ItemCount() < 2 then return
    RestartSwipeTimer()
    p = m.activeIndex - 1
    if p < 0 then p = ItemCount() - 1
    GoToSlide(p)
end function

' OK on the mute control → toggle trailer audio (parity toggleMute).
function HeroToggleMute() as void
    if m.trailerVideo = invalid then return
    m.trailerVideo.mute = not m.trailerVideo.mute
    UpdateMuteIcon()
end function

function PauseAutoAdvance(dummy = invalid as dynamic) as boolean
    StopSwipeTimer()
    return true
end function

function ResumeAutoAdvance(dummy = invalid as dynamic) as boolean
    if not m.top.visible or ItemCount() < 2 then return true
    if m.isVideoPlaying then return true
    RestartSwipeTimer()
    return true
end function

sub UpdateMuteIcon()
    if m.muteIcon = invalid or m.trailerVideo = invalid then return
    if m.trailerVideo.mute then
        m.muteIcon.uri = "pkg:/images/ui/vol_off.png"
    else
        m.muteIcon.uri = "pkg:/images/ui/vol_on.png"
    end if
end sub

' Manual navigation gives the new slide a full fresh window.
sub RestartSwipeTimer()
    if m.swipeTimer = invalid then return
    m.swipeTimer.control = "stop"
    if ItemCount() >= 2 then m.swipeTimer.control = "start"
end sub

sub OnBannerItemsChanged()
    StopSwipeTimer()
    StopTrailer()
    m.isFading = false
    m.activeIndex = 0
    m.posterReadyFired = false
    m.firstReveal = true
    m.crossfadeLanding = false
    m.pendingNextUri = invalid
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0

    items = m.top.bannerItems
    if items = invalid then
        m.items = []
    else
        m.items = items
    end if

    ApplySlides()
    ApplyMeta()
    BuildBars()
    UpdateCounter()
    ApplyNavChromeVisibility()
    PlayMetaEntrance()
    if m.top.visible then ScheduleTrailer()
    if m.top.visible and m.items.Count() > 1 then StartSwipeTimer()
end sub

sub OnThemeChanged()
    if m.titleLabel <> invalid then m.titleLabel.color = m.top.cNeutral50
    if m.ratingLabel <> invalid then m.ratingLabel.color = m.top.cNeutral50
    if m.genreLabel <> invalid then m.genreLabel.color = m.top.cNeutral50
    if m.descLabel <> invalid then m.descLabel.color = "0xf8f1f7cc"
    if m.counterCurrent <> invalid then m.counterCurrent.color = m.top.cNeutral50
    ApplyRingTheme()
    BuildBars()
    BuildStars(ItemAt(m.activeIndex))
end sub

' Tint the prev/next/mute focus rings with the theme primary-500 token (parity with the
' React .banner-focusable outline: 3px solid var(--primary-500)). The ring PNG is a white
' glass ring, so blendColor multiplies it to the active brand color.
sub ApplyRingTheme()
    c = m.top.cPrimary500
    if c = invalid or c = "" then return
    if m.prevFocusRing <> invalid then m.prevFocusRing.blendColor = c
    if m.nextFocusRing <> invalid then m.nextFocusRing.blendColor = c
    if m.muteFocusRing <> invalid then m.muteFocusRing.blendColor = c
end sub

function ItemCount() as integer
    if m.items = invalid then return 0
    return m.items.Count()
end function

function NextSlideIndex() as integer
    count = ItemCount()
    if count < 2 then return m.activeIndex
    return (m.activeIndex + 1) mod count
end function

function ItemAt(index as integer) as object
    if m.items = invalid or index < 0 or index >= m.items.Count() then return invalid
    return m.items[index]
end function

sub ApplySlides()
    active = ItemAt(m.activeIndex)
    nxt = ItemAt(NextSlideIndex())
    HideTrailerVideo()
    posterUri = GetHeroBannerImage(active)
    nextUri = GetHeroBannerImage(nxt)
    m.lastPosterUri = posterUri

    if m.crossfadeLanding then
        ' Settling onto the slide we just crossfaded to. The next layer already shows this
        ' exact (decoded) image, so keep it visible and load the active poster's own copy
        ' UNDER it at opacity 0. OnActivePosterLoad swaps them once it has decoded, so the
        ' previous slide's image is never repainted on top during the handoff.
        if m.nextLayer <> invalid then m.nextLayer.opacity = 1.0
        if m.activeLayer <> invalid then m.activeLayer.opacity = 0.0
        if m.activePoster <> invalid then
            m.activePoster.opacity = 1.0
            m.activePoster.uri = posterUri
            m.activePoster.scale = [1.0, 1.0]
            m.activePoster.translation = [0, 0]
            m.activePoster.visible = true
            ' Do NOT read loadStatus synchronously here: right after assigning a new .uri
            ' it still reports the PREVIOUS image's "ready", so finishing now would reveal
            ' the OLD poster for a frame before the new one decodes (the auto-advance
            ' flash). Wait for OnActivePosterLoad to fire "ready" for the NEW uri — until
            ' then the next layer keeps showing the correct (new) image.
        end if
        ' Hold the upcoming-slide preload until the swap (the next layer must keep showing
        ' the current image, not the one after it).
        m.pendingNextUri = nextUri
        return
    end if

    ' Initial reveal (off the skeleton): poster shown directly, next layer hidden.
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    ' The next-slide layer is only shown DURING a crossfade (BeginCrossfade reveals it).
    ' Keeping it hidden otherwise guarantees a transparent active poster can never expose
    ' the wrong (next) image — the dark hero background shows through instead.
    if m.nextLayer <> invalid then m.nextLayer.opacity = 0.0
    if m.activePoster <> invalid then
        ' Only the very first reveal glows in from transparent (coming off the skeleton).
        if m.firstReveal then
            m.activePoster.opacity = 0.0
        else
            m.activePoster.opacity = 1.0
        end if
        m.activePoster.uri = posterUri
        m.activePoster.scale = [1.0, 1.0]
        m.activePoster.translation = [0, 0]
        m.activePoster.visible = true
    end if
    if m.nextPoster <> invalid then
        m.nextPoster.uri = nextUri
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [0, 0]
    end if
    ' Ken Burns must not run while the poster is invisible (first skeleton handoff) — the
    ' 8s zoom would finish before the fade-in and the image looks static (no React glow).
    if not m.firstReveal and not m.crossfadeLanding then
        StartKenBurns()
    end if
    MaybeCompletePosterLoad()
end sub

' Cached posters can report loadStatus=ready before the observer fires — complete the
' first-reveal glow + Ken Burns without waiting on a second event.
sub MaybeCompletePosterLoad()
    if m.activePoster = invalid then return
    if m.activePoster.loadStatus = "ready" then OnActivePosterLoad()
end sub

' Complete the crossfade handoff: the active poster now holds the new image too, so reveal
' it and retire the next layer in the same frame (both show the same image → invisible
' swap), then preload the upcoming slide onto the now-hidden next layer.
sub FinishCrossfadeLanding()
    m.crossfadeLanding = false
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    if m.nextLayer <> invalid then m.nextLayer.opacity = 0.0
    StopNextKenBurns()
    if m.nextPoster <> invalid and m.pendingNextUri <> invalid then
        m.nextPoster.uri = m.pendingNextUri
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [0, 0]
    end if
    m.pendingNextUri = invalid
    StartKenBurns()
end sub

' Diagnostics: report whether the hero poster bitmap actually loaded. loadStatus goes
' "loading" → "ready" on success, or "failed" if the URL/size can't be decoded.
sub OnActivePosterLoad()
    if m.activePoster = invalid then return
    status = m.activePoster.loadStatus
    expected = ""
    if m.lastPosterUri <> invalid then expected = m.lastPosterUri

    if status = "ready" then
        if m.crossfadeLanding then
            ' Active poster now holds the new slide's bitmap — swap layers in one frame.
            FinishCrossfadeLanding()
        else if m.firstReveal then
            ' Glow the first poster in (fade 0 → 1); Ken Burns starts once visible.
            m.firstReveal = false
            GlowPosterIn()
            StartKenBurns()
            print "[HERO_DBG] poster_glow_in ken_burns=start"
        else
            m.activePoster.opacity = 1.0
            if not m.isVideoPlaying then StartKenBurns()
        end if
        ' Signal the home screen the moment the first slide's poster has painted, so the
        ' loading skeleton can drop straight onto a real hero (no black flash).
        if not m.posterReadyFired then
            m.posterReadyFired = true
            m.top.posterReady = true
        end if
    else if status = "failed" then
        ' Decode failed — don't leave the poster invisible.
        if m.crossfadeLanding then FinishCrossfadeLanding()
        m.firstReveal = false
        m.activePoster.opacity = 1.0
        if not m.isVideoPlaying then StartKenBurns()
    end if
end sub

sub GlowPosterIn()
    if m.posterGlowAnim = invalid then
        if m.activePoster <> invalid then m.activePoster.opacity = 1.0
        return
    end if
    m.posterGlowAnim.control = "stop"
    m.posterGlowAnim.control = "start"
end sub

' Video must be invisible (not just opacity=0) when idle — otherwise it occludes poster.
sub HideTrailerVideo()
    if m.trailerVideo = invalid then return
    m.trailerVideo.visible = false
    m.trailerVideo.opacity = 0.0
end sub

sub OnNextPosterLoad()
    if m.nextPoster = invalid then return
end sub

sub ApplyMeta()
    item = ItemAt(m.activeIndex)
    title = ""
    if item <> invalid then
        if item.title <> invalid and item.title <> "" then
            title = item.title
        else if item.name <> invalid then
            title = item.name
        end if
    end if
    if m.titleLabel <> invalid then m.titleLabel.text = title
    if m.genreLabel <> invalid then m.genreLabel.text = FormatHeroGenres(item)

    desc = ""
    if item <> invalid and item.description <> invalid then desc = item.description
    if m.descLabel <> invalid then m.descLabel.text = TruncateHeroText(desc, 150)

    ApplyQuality(item)
    BuildStars(item)
end sub

sub ApplyQuality(item as object)
    if m.qualityBadge = invalid then return
    q = ""
    if item <> invalid and item.quality <> invalid then q = item.quality
    if q = "" then
        m.qualityBadge.visible = false
        return
    end if
    m.qualityLabel.text = q
    w = Len(q) * 11 + 28
    if w < 56 then w = 56
    m.qualityBg.width = w
    m.qualityLabel.width = w
    m.qualityBadge.visible = true
end sub

' ── IMDB star rating (parity with StarRating: numeric + 5 themed stars) ───────
sub BuildStars(item as object)
    if m.ratingHost = invalid then return
    ' Drop everything except the rating label (index 0).
    for i = m.ratingHost.getChildCount() - 1 to 1 step -1
        m.ratingHost.removeChildIndex(i)
    end for

    imdb = invalid
    if item <> invalid and item.imdb <> invalid then imdb = item.imdb
    if imdb = invalid or FormatHeroRating(imdb) = "" then
        m.ratingHost.visible = false
        return
    end if

    m.ratingLabel.text = FormatHeroRating(imdb)
    normalized = HeroStarRating(imdb)
    full = Int(normalized)
    half = 0
    if (normalized - full) >= 0.5 then half = 1
    blank = 5 - full - half
    if blank < 0 then blank = 0

    blankColor = "0x31383Aff"
    for i = 1 to full
        AppendStar("full", blankColor)
    end for
    if half = 1 then AppendStar("half", blankColor)
    for i = 1 to blank
        AppendStar("blank", blankColor)
    end for

    m.ratingHost.visible = true
end sub

sub AppendStar(kind as string, blankColor as string)
    starUri = "pkg:/images/ui/star.png"
    sz = 22
    if kind = "half" then
        g = m.ratingHost.createChild("Group")
        base = g.createChild("Poster")
        base.uri = starUri
        base.width = sz
        base.height = sz
        base.blendColor = blankColor
        clip = g.createChild("Group")
        clip.clippingRect = [0, 0, sz / 2, sz]
        clip.clippingRectClipsChildren = true
        fill = clip.createChild("Poster")
        fill.uri = starUri
        fill.width = sz
        fill.height = sz
        fill.blendColor = m.top.cPrimary500
        return
    end if

    p = m.ratingHost.createChild("Poster")
    p.uri = starUri
    p.width = sz
    p.height = sz
    if kind = "full" then
        p.blendColor = m.top.cPrimary500
    else
        p.blendColor = blankColor
    end if
end sub

' ── Progress bars (parity with animated cinematic progress indicators) ───────
' Background/done bars are rebuilt per slide; the active fill is a persistent node
' (heroBarFill) so the timer animation never loses its field binding.
sub BuildBars()
    if m.barsHost = invalid then return
    if m.barAnim <> invalid then m.barAnim.control = "stop"
    if m.heroBarFill <> invalid then m.heroBarFill.width = 0

    count = m.barsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.barsHost.removeChildIndex(i)
    end for

    total = ItemCount()
    if total < 2 then
        if m.heroBarFill <> invalid then m.heroBarFill.visible = false
        return
    end if

    gap = 8
    activeX = 0
    x = 0
    for i = 0 to total - 1
        w = 28
        if i = m.activeIndex then w = 48
        bar = m.barsHost.createChild("Rectangle")
        bar.width = w
        bar.height = 4
        bar.color = "0xffffff33"
        bar.translation = [x, 0]

        if i < m.activeIndex then
            done = bar.createChild("Rectangle")
            done.width = w
            done.height = 4
            done.color = "0xffffff99"
        else if i = m.activeIndex then
            activeX = x
        end if

        x = x + w + gap
    end for

    if m.heroBarFill <> invalid then
        m.heroBarFill.color = m.top.cPrimary500
        m.heroBarFill.translation = [activeX, 290]
        m.heroBarFill.width = 0
        m.heroBarFill.visible = true
    end if

    StartPosterProgress()
end sub

' Blue tick fills over the FIXED slide window (15s) — its duration is tied to the slide
' timer, never to the trailer length (parity: progress = SWIPE_INTERVAL for the slide).
sub StartPosterProgress()
    if m.barAnim = invalid then return
    m.barAnim.duration = HC_HeroSwipeMs() / 1000.0
    StartBarFill()
end sub

sub StartBarFill()
    if m.barAnim = invalid or m.barInterp = invalid or m.heroBarFill = invalid then return
    m.heroBarFill.width = 0
    m.barAnim.control = "stop"
    m.barAnim.control = "start"
end sub

sub UpdateCounter()
    if m.counterHost = invalid then return
    total = ItemCount()
    if total < 2 then
        m.counterHost.visible = false
        return
    end if
    m.counterCurrent.text = PadTwo(m.activeIndex + 1)
    m.counterTotal.text = PadTwo(total)
    m.counterHost.visible = true
end sub

' React only portals prev/next when items.length > 1 — hide (not disable) on single-slide heroes.
sub ApplyNavChromeVisibility()
    multi = (ItemCount() > 1)
    if m.prevArrow <> invalid then m.prevArrow.visible = multi
    if m.nextArrow <> invalid then m.nextArrow.visible = multi
end sub

function PadTwo(n as integer) as string
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' Text entrance: reset to start pose, then fade + slide up (parity textVisible).
sub PlayMetaEntrance()
    if m.metaHost = invalid then return
    if m.metaAnim = invalid then
        m.metaHost.opacity = 1.0
        return
    end if
    m.metaAnim.control = "stop"
    m.metaHost.opacity = 0.0
    m.metaHost.translation = [64, 364]
    m.metaAnim.control = "start"
end sub

sub StartKenBurns()
    if m.isVideoPlaying then return
    if m.zoomAnim = invalid or m.activePoster = invalid then return
    m.activePoster.scale = [1.0, 1.0]
    m.zoomAnim.control = "stop"
    m.zoomAnim.control = "start"
end sub

sub StartNextKenBurns()
    if m.isVideoPlaying then return
    if m.nextZoomAnim = invalid or m.nextPoster = invalid then return
    m.nextPoster.scale = [1.0, 1.0]
    m.nextZoomAnim.control = "stop"
    m.nextZoomAnim.control = "start"
end sub

sub StopNextKenBurns()
    if m.nextZoomAnim <> invalid then m.nextZoomAnim.control = "stop"
    if m.nextPoster <> invalid then m.nextPoster.scale = [1.0, 1.0]
end sub

' The slide runs for a FIXED duration (HC_HeroSwipeMs). The timer keeps running even
' while a trailer plays, so one slide is never stretched to the full trailer length —
' it always advances on the fixed window (parity intent + user requirement).
' LG pauses the 15s auto-advance while a trailer plays (heroBannerCinematic.tsx clears the
' setInterval on isVideoPlaying) and advances on the trailer "ended" event instead.
sub StartSwipeTimer()
    if m.swipeTimer = invalid or ItemCount() < 2 then return
    if m.isVideoPlaying then return
    m.swipeTimer.control = "start"
end sub

sub StopSwipeTimer()
    if m.swipeTimer = invalid then return
    m.swipeTimer.control = "stop"
end sub

sub OnSwipeTimer()
    if m.isFading or ItemCount() < 2 then return
    GoToSlide(NextSlideIndex())
end sub

' Crossfade to an arbitrary slide (auto-advance uses NextSlideIndex; the arrows can pass
' any target so the user can step forward AND backward through the carousel).
sub GoToSlide(targetIndex as integer)
    if ItemCount() < 2 or m.isFading then return
    if targetIndex < 0 or targetIndex >= ItemCount() then return
    if targetIndex = m.activeIndex then return
    m.fadeTargetIndex = targetIndex
    ' Counter + progress bars update immediately on navigation (parity: the "01 / 04"
    ' label and active bar track the click, not the 1.2s crossfade). The META text is
    ' intentionally NOT animated here — it animates exactly once after the crossfade
    ' settles (OnFadeAnimState), so the title/desc never play their entrance twice.
    m.activeIndex = targetIndex
    UpdateCounter()
    BuildBars()
    ' The preloaded next layer holds the auto-advance image; for an explicit jump (e.g.
    ' previous) repoint it at the chosen slide before revealing it in the crossfade.
    if m.nextPoster <> invalid then
        newUri = GetHeroBannerImage(ItemAt(targetIndex))
        if m.nextPoster.uri <> newUri then m.nextPoster.uri = newUri
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [0, 0]
    end if
    BeginCrossfade()
end sub

sub BeginCrossfade()
    if m.fadeAnim = invalid or m.activeLayer = invalid then return
    ' Hide any playing trailer first so the poster crossfade isn't covered by the video.
    StopTrailer()
    m.isFading = true
    m.activeLayer.opacity = 1.0
    ' Reveal the preloaded next slide underneath so fading the active layer crossfades to it.
    if m.nextLayer <> invalid then m.nextLayer.opacity = 1.0
    if m.metaHost <> invalid then m.metaHost.opacity = 0.0
    StartNextKenBurns()
    m.fadeAnim.control = "stop"
    m.fadeAnim.control = "start"
end sub

sub OnFadeAnimState()
    if m.fadeAnim = invalid then return
    if m.fadeAnim.state <> "stopped" then return
    if not m.isFading then return

    count = ItemCount()
    target = m.fadeTargetIndex
    if count > 0 and (target < 0 or target >= count) then target = (m.activeIndex + 1) mod count
    ' activeIndex/counter/bars were already advanced in GoToSlide; reconcile only if the
    ' fade somehow started without it (defensive — shouldn't happen).
    if count > 0 and m.activeIndex <> target then
        m.activeIndex = target
        UpdateCounter()
        BuildBars()
    end if
    m.fadeTargetIndex = -1
    m.isFading = false
    m.crossfadeLanding = true
    ApplySlides()
    ' The meta was hidden (opacity 0) for the whole crossfade; set the new slide's text
    ' and play its entrance ONCE here — the only place the title/desc animate per slide.
    ApplyMeta()
    PlayMetaEntrance()
    if m.top.visible then ScheduleTrailer()
end sub

' ── Trailer autoplay (parity with hero trailer fetch + HLS playback) ─────────

' Reset any current trailer and arm the 2.5s load delay for the active slide.
sub ScheduleTrailer()
    StopTrailer()
    CancelDetailFetch()
    if m.trailerTimer = invalid or ItemCount() < 1 then return
    m.trailerTimer.control = "stop"
    m.trailerTimer.control = "start"
end sub

' Drop the in-flight detail request so a late response from a previous slide can never
' resolve a trailer onto the wrong slide (stops poster/label/video desync).
sub CancelDetailFetch()
    if m.detailTask <> invalid then
        m.detailTask.unobserveField("apiResult")
        m.detailTask.control = "stop"
        m.detailTask = invalid
    end if
end sub

sub OnTrailerTimer()
    if not m.top.visible then return
    item = ItemAt(m.activeIndex)
    if item = invalid then return

    url = DirectTrailerUrl(item)
    if url <> "" then
        LoadTrailer(url)
        return
    end if

    id = ""
    if item._id <> invalid then id = item._id
    if id <> "" and m.trailerCache[id] <> invalid then
        LoadTrailer(m.trailerCache[id])
        return
    end if

    FetchTrailerDetail(item)
end sub

' item.trailer.url is prioritised over item.preview.url (parity fetchTrailerUrl).
function DirectTrailerUrl(item as object) as string
    if item = invalid then return ""
    if item.trailer <> invalid and item.trailer.url <> invalid and item.trailer.url <> "" then
        return item.trailer.url
    end if
    if item.preview <> invalid and item.preview.url <> invalid and item.preview.url <> "" then
        return item.preview.url
    end if
    return ""
end function

sub FetchTrailerDetail(item as object)
    id = ""
    if item._id <> invalid then id = item._id
    tp = ""
    if item.type <> invalid then tp = item.type
    if id = "" or tp = "" then return

    ' Cancel any previous request before starting a new one — only the live request may
    ' call back, so OnDetailResponse always reads the task for the CURRENT slide.
    CancelDetailFetch()

    path = Endpoints().DETAIL.CONTENT_VIEW + "/" + id
    task = ApiGetQuery(path, { type: tp })
    m.detailItemId = id
    m.detailReqIndex = m.activeIndex
    m.detailTask = task
    task.observeField("apiResult", "OnDetailResponse")
    StartHttpTask(task)
end sub

sub OnDetailResponse()
    if m.detailTask = invalid then return
    api = m.detailTask.apiResult
    m.detailTask = invalid
    if api = invalid or api.ok <> true or api.result = invalid then return

    res = api.result
    ' Same resolution order as fetchTrailerUrl() in heroBannerCinematic.tsx.
    url = ""
    if res.playList <> invalid and res.playList.hls <> invalid and res.playList.hls.url <> invalid then
        url = res.playList.hls.url
    end if
    if url = "" and res.preview <> invalid and res.preview.url <> invalid then
        url = res.preview.url
    end if
    ' No trailer/preview for this slide — poster simply stays for the fixed window.
    if url = "" then
        return
    end if

    if m.detailItemId <> invalid and m.detailItemId <> "" then
        if m.trailerCache.Count() >= 5 then
            for each k in m.trailerCache
                m.trailerCache.Delete(k)
                exit for
            end for
        end if
        m.trailerCache[m.detailItemId] = url
    end if

    ' Only start if the user is still on the slide we fetched for.
    if m.detailReqIndex = m.activeIndex and m.top.visible then
        LoadTrailer(url)
    else
    end if
end sub

sub LoadTrailer(url as string)
    if m.trailerVideo = invalid or url = "" then return
    ' Remember which slide this trailer belongs to so a late "playing" event from a
    ' previous slide can't fade an old video in over the new poster.
    m.playingForIndex = m.activeIndex
    ' Tear the old stream down fully so the new one always begins from its initial state.
    m.trailerVideo.control = "stop"
    m.trailerVideo.content = invalid
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    if Instr(1, LCase(url), ".m3u8") > 0 then
        content.streamFormat = "hls"
    else
        content.streamFormat = "mp4"
    end if
    m.trailerVideo.mute = true
    HideTrailerVideo()
    m.trailerVideo.seek = 0
    m.trailerVideo.content = content
    m.trailerVideo.control = "play"
end sub

sub OnTrailerState()
    if m.trailerVideo = invalid then return
    state = m.trailerVideo.state

    ' Ignore state from a stream that belongs to a slide we've already left.
    if m.playingForIndex <> m.activeIndex then
        if state = "playing" or state = "buffering" then
            m.trailerVideo.control = "stop"
            m.trailerVideo.content = invalid
            HideTrailerVideo()
        end if
        return
    end if

    if state = "playing" then
        if not m.isVideoPlaying then
            m.isVideoPlaying = true
            m.top.trailerPlaying = true
            ' Show the video node only once frames are ready — keeps poster visible while
            ' buffering and prevents the black Video rectangle from occluding it.
            if m.trailerVideo <> invalid then m.trailerVideo.visible = true
            BeginVideoFade()
            if m.muteBtn <> invalid then m.muteBtn.visible = true
            UpdateMuteIcon()
            ' Ken Burns stops while the video covers the poster (parity isVideoPlaying).
            if m.zoomAnim <> invalid then m.zoomAnim.control = "stop"
            ' Hold this slide for the full trailer: pause the fixed auto-advance window.
            StopSwipeTimer()
        end if
    else if state = "finished" then
        ' Parity handleEnded: the trailer ended, so advance to the next slide now.
        AdvanceAfterTrailer()
    else if state = "error" then
        ' Stall/error: fall back to the poster and resume the fixed auto-advance window.
        RevealPoster()
    end if
end sub

' Fade the trailer video in over the poster (poster stays underneath at full opacity).
sub BeginVideoFade()
    if m.videoFadeAnim = invalid then
        if m.trailerVideo <> invalid then m.trailerVideo.opacity = 1.0
        return
    end if
    m.videoFadeAnim.control = "stop"
    m.videoFadeAnim.control = "start"
end sub

' Trailer stalled/failed mid-slide: hide the video, restore the poster, and resume the
' fixed auto-advance window (parity: isVideoPlaying flips false -> setInterval re-arms).
sub RevealPoster()
    if m.videoFadeAnim <> invalid then m.videoFadeAnim.control = "stop"
    if m.trailerVideo <> invalid then
        m.trailerVideo.control = "stop"
        m.trailerVideo.content = invalid
        HideTrailerVideo()
    end if
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    if m.activePoster <> invalid then m.activePoster.opacity = 1.0
    if m.muteBtn <> invalid then m.muteBtn.visible = false
    m.isVideoPlaying = false
    m.top.trailerPlaying = false
    m.playingForIndex = -1
    StartKenBurns()
    if m.top.visible then StartSwipeTimer()
end sub

' Parity with React handleEnded: when the trailer's "ended" event fires it sets
' isVideoPlaying=false and calls triggerFade(), so the slide advances the instant the
' trailer finishes (held for the full trailer, never cut to the 15s window).
sub AdvanceAfterTrailer()
    if m.videoFadeAnim <> invalid then m.videoFadeAnim.control = "stop"
    if m.trailerVideo <> invalid then
        m.trailerVideo.control = "stop"
        m.trailerVideo.content = invalid
        HideTrailerVideo()
    end if
    if m.muteBtn <> invalid then m.muteBtn.visible = false
    m.isVideoPlaying = false
    m.top.trailerPlaying = false
    m.playingForIndex = -1
    ' Re-arm the fixed window for the upcoming slides, then advance immediately.
    if m.top.visible then StartSwipeTimer()
    if ItemCount() > 1 then GoToSlide(NextSlideIndex())
end sub

' Fully tear down the trailer (slide change / banner hidden). Poster is restored.
sub StopTrailer()
    if m.trailerTimer <> invalid then m.trailerTimer.control = "stop"
    if m.videoFadeAnim <> invalid then m.videoFadeAnim.control = "stop"
    if m.trailerVideo <> invalid then
        m.trailerVideo.control = "stop"
        m.trailerVideo.content = invalid
        HideTrailerVideo()
    end if
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    if m.activePoster <> invalid then m.activePoster.opacity = 1.0
    if m.muteBtn <> invalid then m.muteBtn.visible = false
    m.isVideoPlaying = false
    m.top.trailerPlaying = false
    m.playingForIndex = -1
end sub
