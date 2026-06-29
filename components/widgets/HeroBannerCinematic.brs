' Cinematic hero — parity heroBannerCinematic.tsx.
' ⚠ Parity Note: meta animates before poster on every slide (meta-first ordering);
' trailer auto-advance pauses while isVideoPlaying. Do not reorder meta/poster here.
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
    m.slidePosterTimer = m.top.findNode("slidePosterTimer")
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
    m.metaBeforePosterReady = false
    m.awaitingPosterReveal = false
    m.trailerCache = {}
    m.detailTask = invalid

    m.viewportW = 1920
    ApplyViewportLayout()

    m.swipeTimer.duration = HC_HeroSwipeMs() / 1000.0
    m.zoomAnim.duration = HC_HeroZoomSec()
    if m.nextZoomAnim <> invalid then m.nextZoomAnim.duration = HC_HeroZoomSec()
    m.barAnim.duration = HC_HeroSwipeMs() / 1000.0
    m.trailerTimer.duration = HC_HeroTrailerDelaySec()
    if m.metaAnim <> invalid then m.metaAnim.duration = HC_HeroMetaEntranceSec()

    m.swipeTimer.observeField("fire", "OnSwipeTimer")
    if m.slidePosterTimer <> invalid then m.slidePosterTimer.observeField("fire", "OnSlidePosterTimer")
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

    leftVig = m.top.findNode("leftVignette")
    if leftVig <> invalid then
        leftVig.width = Int(w * HC_HeroLeftGradWidthPct() + 0.5)
        leftVig.height = HC_HeroLeftGradHeight()
    end if

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
    GoToSlide(HeroSlidePrevIndex(m.activeIndex, ItemCount()))
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
    m.metaBeforePosterReady = false
    m.awaitingPosterReveal = false
    if m.slidePosterTimer <> invalid then m.slidePosterTimer.control = "stop"
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0

    items = m.top.bannerItems
    if items = invalid then
        m.items = []
    else
        m.items = items
    end if

    ApplyMeta()
    BuildBars()
    UpdateCounter()
    ApplyNavChromeVisibility()
    PlayMetaEntrance()
    ApplySlides()
    ArmPosterRevealTimer()
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
    return HeroSlideCount(m.items)
end function

function NextSlideIndex() as integer
    return HeroSlideNextIndex(m.activeIndex, ItemCount())
end function

function ItemAt(index as integer) as object
    return HeroSlideItemAt(m.items, index)
end function

sub ApplySlides()
    active = ItemAt(m.activeIndex)
    nxt = ItemAt(NextSlideIndex())
    HideTrailerVideo()
    posterUri = GetHeroBannerImage(active)
    nextUri = GetHeroBannerImage(nxt)
    m.lastPosterUri = posterUri

    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    ' Keep the next slide hidden until a transition reveals the active poster.
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
    ' Ken Burns must not run while the poster is invisible (first skeleton handoff).
    if not m.firstReveal then StartKenBurns()
    MaybeCompletePosterLoad()
end sub

' Cached posters can report loadStatus=ready before the observer fires.
sub MaybeCompletePosterLoad()
    if m.activePoster = invalid then return
    if m.activePoster.loadStatus = "ready" then OnActivePosterLoad()
end sub

sub OnActivePosterLoad()
    if m.activePoster = invalid then return
    status = m.activePoster.loadStatus

    if status = "ready" then
        if m.metaBeforePosterReady and m.activePoster.opacity < 1.0 then
            CompletePosterReveal()
        else if m.firstReveal then
            ' Poster stays hidden until the meta-first timer elapses.
        else if not m.isVideoPlaying then
            m.activePoster.opacity = 1.0
            StartKenBurns()
        end if
    else if status = "failed" then
        m.firstReveal = false
        m.activePoster.opacity = 1.0
        if not m.isVideoPlaying then StartKenBurns()
        if not m.posterReadyFired then
            m.posterReadyFired = true
            m.top.posterReady = true
        end if
    end if
end sub

sub GlowPosterIn()
    if m.posterGlowAnim = invalid then
        if m.activePoster <> invalid then m.activePoster.opacity = 1.0
        return
    end if
    if m.activePoster <> invalid then m.activePoster.opacity = 0.0
    m.posterGlowAnim.control = "stop"
    m.posterGlowAnim.control = "start"
end sub

sub ArmPosterRevealTimer()
    if m.slidePosterTimer = invalid then return
    m.metaBeforePosterReady = false
    m.awaitingPosterReveal = true
    m.slidePosterTimer.duration = HC_HeroMetaBeforePosterSec()
    m.slidePosterTimer.control = "stop"
    m.slidePosterTimer.control = "start"
end sub

sub OnSlidePosterTimer()
    m.metaBeforePosterReady = true
    if m.awaitingPosterReveal then
        m.awaitingPosterReveal = false
        RevealPosterAfterMeta()
    end if
end sub

' Meta leads each slide change; the poster loads hidden, then glows in after a short gap.
sub RevealPosterAfterMeta()
    active = ItemAt(m.activeIndex)
    if active = invalid then return
    posterUri = GetHeroBannerImage(active)
    m.lastPosterUri = posterUri
    nxt = ItemAt(NextSlideIndex())
    HideTrailerVideo()

    if m.activePoster <> invalid then
        m.activePoster.uri = posterUri
        m.activePoster.scale = [1.0, 1.0]
        m.activePoster.translation = [0, 0]
        m.activePoster.visible = true
        m.activePoster.opacity = 0.0
    end if
    if m.nextPoster <> invalid then
        m.nextPoster.uri = GetHeroBannerImage(nxt)
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [0, 0]
    end if
    if m.nextLayer <> invalid then m.nextLayer.opacity = 0.0
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0

    m.isFading = false

    if m.activePoster <> invalid and m.activePoster.loadStatus = "ready" then
        CompletePosterReveal()
    else
        MaybeCompletePosterLoad()
    end if
end sub

sub CompletePosterReveal()
    if m.activePoster = invalid then return
    if m.activePoster.opacity >= 1.0 then return
    if m.firstReveal then m.firstReveal = false
    GlowPosterIn()
    StartKenBurns()
    if not m.posterReadyFired then
        m.posterReadyFired = true
        m.top.posterReady = true
    end if
    if m.top.visible then ScheduleTrailer()
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
    HeroPlayCinematicMetaEntrance(m.metaHost, m.metaAnim)
end sub

sub StartKenBurns()
    if m.isVideoPlaying then return
    if m.zoomAnim = invalid or m.activePoster = invalid then return
    m.activePoster.scale = [1.0, 1.0]
    m.zoomAnim.control = "stop"
    m.zoomAnim.control = "start"
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

' Advance to a slide (auto-advance or prev/next arrows).
sub GoToSlide(targetIndex as integer)
    if ItemCount() < 2 or m.isFading then return
    if targetIndex < 0 or targetIndex >= ItemCount() then return
    if targetIndex = m.activeIndex then return

    m.isFading = true
    StopTrailer()
    if m.slidePosterTimer <> invalid then m.slidePosterTimer.control = "stop"
    if m.posterGlowAnim <> invalid then m.posterGlowAnim.control = "stop"
    if m.zoomAnim <> invalid then m.zoomAnim.control = "stop"
    if m.nextZoomAnim <> invalid then m.nextZoomAnim.control = "stop"
    if m.nextPoster <> invalid then m.nextPoster.scale = [1.0, 1.0]

    m.activeIndex = targetIndex
    UpdateCounter()
    BuildBars()

    if m.activeLayer <> invalid then m.activeLayer.opacity = 0.0
    if m.nextLayer <> invalid then m.nextLayer.opacity = 0.0

    ApplyMeta()
    PlayMetaEntrance()
    ArmPosterRevealTimer()
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
