' Parallax vertical-slide hero — parity heroBannerParallax.tsx.
' ⚠ Parity Note: meta hides during slide, then contentAnim reveals after HC_HeroMetaBeforePosterSec.

function PX_HeroH() as integer
    return 918
end function

function PX_PosterW() as integer
    return 2016
end function

function PX_PosterH() as integer
    return 964
end function

function PX_PosterX() as integer
    return -48
end function

function PX_PosterRestY() as integer
    return -53
end function

function PX_NextPosterY() as integer
    return -23
end function

function PX_MetaH() as integer
    return 322
end function

function PX_MetaY() as integer
    bottomY = Int(PX_HeroH() * 0.55 + 0.5)
    return bottomY - PX_MetaH()
end function

function PX_FrostH() as integer
    ' Snug pill: 8px top + 42px thumb row + 2px bottom (no dead grey band).
    return PX_FrostPadY() + PX_MaxThumbSlotH() + 2
end function

function PX_FrostPadX() as integer
    return 16
end function

function PX_FrostPadY() as integer
    ' React: padding 8px top/bottom inside the frost pill.
    return 8
end function

function PX_MaxThumbSlotH() as integer
    ' React active thumb outer height 42px.
    return 42
end function

function PX_FrostLift() as integer
    ' Whole strip on hero — leave 0 unless moving entire pill on screen.
    return 0
end function

function PX_FrostPanelY() as integer
    ' Grey background only — negative = move grey UP inside the pill.
    return -19
end function

function PX_FrostY() as integer
    return PX_HeroH() - Int(PX_HeroH() * 0.35 + 0.5) - PX_FrostH() - PX_FrostLift()
end function

function PX_ThumbSpringDur() as float
    return 0.4
end function

function PX_DotSpringDur() as float
    return 0.5
end function

function PX_SlideEaseKeys() as object
    return [0.0, 0.08, 0.2, 0.38, 0.58, 0.78, 0.92, 1.0]
end function

function PX_SlideEaseFractions() as object
    return [0.0, 0.18, 0.38, 0.56, 0.72, 0.86, 0.96, 1.0]
end function

function PX_ThumbDims(isActive as boolean) as object
    d = {}
    d.fw = 52
    d.fh = 32
    d.tw = 50
    d.th = 30
    d.op = 0.5
    d.inset = 1
    d.shellUri = "pkg:/images/ui/parallax_thumb_idle.png"
    d.maskUri = "pkg:/images/ui/parallax_thumb_mask_sm.png"
    if isActive then
        d.fw = 72
        d.fh = 42
        d.tw = 68
        d.th = 38
        d.op = 1.0
        d.inset = 2
        d.shellUri = "pkg:/images/ui/parallax_thumb_active.png"
        d.maskUri = "pkg:/images/ui/parallax_thumb_mask_lg.png"
    end if
    d.yOff = Int((PX_MaxThumbSlotH() - d.fh) / 2)
    return d
end function

sub init()
    m.items = []
    m.activeIndex = 0
    m.isSliding = false
    m.contentReady = true
    m.posterReadyFired = false
    m.slideDir = "up"
    m.thumbProgressBar = invalid
    m.thumbProgressAnim = invalid
    m.thumbTransAnim = invalid
    m.dotTransAnim = invalid
    m.nextKenAnim = invalid
    m.thumbSlots = []
    m.dotNodes = []
    m.pendingContentReveal = false

    m.nextClip = m.top.findNode("nextClip")
    m.nextPoster = m.top.findNode("nextPoster")
    m.activeLayer = m.top.findNode("activeLayer")
    m.activePoster = m.top.findNode("activePoster")
    m.slideShadow = m.top.findNode("slideShadow")
    m.metaHost = m.top.findNode("metaHost")
    m.accentLine = m.top.findNode("accentLine")
    m.titleLabel = m.top.findNode("titleLabel")
    m.ratingHost = m.top.findNode("ratingHost")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreHost = m.top.findNode("genreHost")
    m.genreLabel = m.top.findNode("genreLabel")
    m.qualityBadge = m.top.findNode("qualityBadge")
    m.qualityBg = m.top.findNode("qualityBg")
    m.qualityLabel = m.top.findNode("qualityLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.frostStrip = m.top.findNode("frostStrip")
    m.frostInner = m.top.findNode("frostInner")
    m.frostPanel = m.top.findNode("frostPanel")
    m.frostFocusRing = m.top.findNode("frostFocusRing")
    m.thumbHost = m.top.findNode("thumbHost")
    m.vertDots = m.top.findNode("vertDots")
    m.swipeTimer = m.top.findNode("swipeTimer")
    m.contentDelayTimer = m.top.findNode("contentDelayTimer")
    m.slideAnim = m.top.findNode("slideAnim")
    m.slideInterp = m.top.findNode("slideInterp")
    m.parallaxAnim = m.top.findNode("parallaxAnim")
    m.parallaxInterp = m.top.findNode("parallaxInterp")
    m.contentAnim = m.top.findNode("contentAnim")
    m.contentOpacityInterp = m.top.findNode("contentOpacityInterp")
    m.accentAnim = m.top.findNode("accentAnim")
    m.accentWidthInterp = m.top.findNode("accentWidthInterp")

    if m.metaHost <> invalid then m.metaHost.translation = [48, PX_MetaY()]
    if m.swipeTimer <> invalid then
        m.swipeTimer.duration = HC_HeroParallaxSwipeSec()
        m.swipeTimer.observeField("fire", "OnSwipeTimer")
    end if
    if m.contentDelayTimer <> invalid then
        m.contentDelayTimer.duration = HC_HeroMetaBeforePosterSec()
        m.contentDelayTimer.observeField("fire", "OnContentDelay")
    end if
    if m.contentAnim <> invalid then m.contentAnim.duration = HC_HeroContentRevealSec()
    if m.accentAnim <> invalid then m.accentAnim.duration = HC_HeroParallaxAccentSec()
    if m.slideAnim <> invalid then m.slideAnim.observeField("state", "OnSlideAnimState")
    if m.activePoster <> invalid then m.activePoster.observeField("loadStatus", "OnPosterLoad")
    m.top.observeField("visible", "OnVisibleChanged")
    ResetPosterTransforms()
end sub

sub ResetPosterTransforms()
    if m.nextPoster <> invalid then
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [PX_PosterX(), PX_NextPosterY()]
        m.nextPoster.width = PX_PosterW()
        m.nextPoster.height = PX_PosterH()
    end if
    if m.activePoster <> invalid then
        m.activePoster.scale = [1.0, 1.0]
        m.activePoster.translation = [PX_PosterX(), PX_PosterRestY()]
        m.activePoster.width = PX_PosterW()
        m.activePoster.height = PX_PosterH()
    end if
end sub

sub ClearRuntimeAnims()
    ClearThumbProgressAnim()
    if m.thumbTransAnim <> invalid then
        m.top.removeChild(m.thumbTransAnim)
        m.thumbTransAnim = invalid
    end if
    if m.dotTransAnim <> invalid then
        m.top.removeChild(m.dotTransAnim)
        m.dotTransAnim = invalid
    end if
    if m.nextKenAnim <> invalid then
        m.top.removeChild(m.nextKenAnim)
        m.nextKenAnim = invalid
    end if
end sub

sub OnVisibleChanged()
    if m.top.visible = true then
        if m.swipeTimer <> invalid and ItemCount() > 1 then m.swipeTimer.control = "start"
    else
        if m.swipeTimer <> invalid then m.swipeTimer.control = "stop"
    end if
end sub

sub OnThemeChanged()
    if m.titleLabel <> invalid then m.titleLabel.color = m.top.cNeutral50
    if m.ratingLabel <> invalid then m.ratingLabel.color = m.top.cNeutral50
    if m.genreLabel <> invalid then m.genreLabel.color = m.top.cNeutral50
    if m.descLabel <> invalid then m.descLabel.color = "0xf8f1f7cc"
    if m.accentLine <> invalid then m.accentLine.color = m.top.cPrimary500
    if m.frostFocusRing <> invalid then m.frostFocusRing.color = m.top.cPrimary500
    RebuildFrostStrip()
    RebuildVertDots()
    ApplyFrostFocus()
end sub

sub OnFocusTargetChanged()
    ApplyFrostFocus()
end sub

sub ApplyFrostFocus()
    ' Parallax frost strip = indicator only (React has no focus/click on thumbs).
    ' Hero zone still receives LEFT/RIGHT/OK via HomeScreen; no ring on the pill.
    if m.frostFocusRing <> invalid then m.frostFocusRing.visible = false
    if m.frostStrip <> invalid then m.frostStrip.scale = [1.0, 1.0]
end sub

sub OnBannerItemsChanged()
    items = m.top.bannerItems
    if items = invalid then
        m.items = []
    else
        m.items = items
    end if
    m.activeIndex = 0
    m.isSliding = false
    m.contentReady = true
    m.posterReadyFired = false
    m.pendingContentReveal = false
    m.thumbSlots = []
    m.dotNodes = []
    if m.top.posterReady = true then m.top.posterReady = false
    if m.activeLayer <> invalid then m.activeLayer.translation = [0, 0]
    ClearRuntimeAnims()
    ResetPosterTransforms()
    ShowSlide(0, false)
end sub

function ItemCount() as integer
    return HeroSlideCount(m.items)
end function

function NextIndex(idx as integer) as integer
    return HeroSlideNextIndex(idx, ItemCount())
end function

function PrevIndex(idx as integer) as integer
    return HeroSlidePrevIndex(idx, ItemCount())
end function

sub ShowSlide(index as integer, delayContent as boolean)
    count = ItemCount()
    if count = 0 then
        m.top.visible = false
        MarkPosterReady()
        return
    end if
    m.top.visible = true
    if index < 0 then index = 0
    if index >= count then index = count - 1
    CommitSlideIndex(index)
    RebuildFrostStrip()
    RebuildVertDots()
    if delayContent then
        m.pendingContentReveal = true
    else
        PlayContentReveal()
    end if
    ApplyFrostFocus()
end sub

sub CommitSlideIndex(index as integer)
    m.activeIndex = index
    item = m.items[index]
    ApplyMeta(item)

    uri = GetHeroBannerImage(item)
    nextUri = GetHeroBannerImage(m.items[NextIndex(index)])

    if m.activePoster <> invalid and uri <> "" then m.activePoster.uri = uri
    if m.nextPoster <> invalid and nextUri <> "" then m.nextPoster.uri = nextUri
end sub

sub ApplyMeta(item as object)
    HeroApplyMeta(item, m.titleLabel, m.ratingHost, m.ratingLabel, m.genreLabel, m.qualityBadge, m.qualityLabel, m.descLabel, m.top.cPrimary500, m.qualityBg)
end sub

sub ClearThumbProgressAnim()
    if m.thumbProgressAnim <> invalid then
        m.top.removeChild(m.thumbProgressAnim)
        m.thumbProgressAnim = invalid
    end if
    m.thumbProgressBar = invalid
end sub

sub PX_RemoveThumbBar(refs as object)
    if refs = invalid or refs.bar = invalid then return
    refs.frame.removeChild(refs.bar)
    refs.bar = invalid
end sub

sub PX_AddThumbBar(refs as object, dims as object)
    if refs = invalid then return
    PX_RemoveThumbBar(refs)
    bar = refs.frame.createChild("Rectangle")
    bar.id = "thumbProgress"
    bar.translation = [dims.inset, dims.yOff + dims.fh - 2]
    bar.width = 0
    bar.height = 2
    bar.color = m.top.cPrimary500
    refs.bar = bar
    m.thumbProgressBar = bar
end sub

sub StartThumbProgress(barW as integer)
    ClearThumbProgressAnim()
    if m.thumbProgressBar = invalid or barW < 1 then return

    m.thumbProgressBar.width = 0.0
    anim = m.top.createChild("Animation")
    anim.duration = 5.5
    anim.repeat = false
    anim.easeFunction = "linear"
    interp = anim.createChild("FloatFieldInterpolator")
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.0, barW]
    interp.fieldToInterp = m.thumbProgressBar.id + ".width"
    m.thumbProgressAnim = anim
    anim.control = "start"
end sub

function PX_ThumbFrameW(isActive as boolean) as integer
    if isActive then return 72
    return 52
end function

function PX_ThumbFrameH(isActive as boolean) as integer
    if isActive then return 42
    return 32
end function

function PX_EstimateStripW(count as integer) as integer
    w = PX_FrostPadX() * 2
    for i = 0 to count - 1
        w = w + PX_ThumbFrameW(i = m.activeIndex)
        if i < count - 1 then w = w + 12
    end for
    return w
end function

sub PositionFrostStrip(stripW as integer)
    if m.frostStrip = invalid then return
    if stripW < 120 then stripW = 120
    m.frostStrip.translation = [Int((1920 - stripW) / 2), PX_FrostY()]
    if m.frostInner <> invalid then
        m.frostInner.clippingRect = [0, 0, stripW, PX_FrostH()]
    end if
    if m.frostPanel <> invalid then
        m.frostPanel.width = stripW
        m.frostPanel.height = PX_FrostH()
        m.frostPanel.translation = [0, PX_FrostPanelY()]
    end if
    if m.frostFocusRing <> invalid then
        m.frostFocusRing.boxWidth = stripW + 8
        m.frostFocusRing.boxHeight = PX_FrostH() + 8
    end if
    if m.thumbHost <> invalid then
        ' 8px pad top/bottom — thumbs (max 42px) centered in 58px pill.
        m.thumbHost.translation = [PX_FrostPadX(), PX_FrostPadY()]
    end if
end sub

function PX_CreateThumbSlot(frame as object, uri as string, isActive as boolean, idx as integer) as object
    dims = PX_ThumbDims(isActive)
    refs = {}
    refs.frame = frame
    refs.isActive = isActive
    sid = idx.ToStr()
    laneH = PX_MaxThumbSlotH()

    shell = frame.createChild("Poster")
    shell.id = "pxShell" + sid
    shell.uri = dims.shellUri
    shell.width = dims.fw
    shell.height = dims.fh
    shell.translation = [0, dims.yOff]
    shell.loadDisplayMode = "scaleToFill"
    refs.shell = shell

    mg = frame.createChild("MaskGroup")
    mg.id = "pxMask" + sid
    mg.maskUri = dims.maskUri
    mg.maskSize = [dims.tw, dims.th]
    mg.translation = [dims.inset, dims.yOff + dims.inset]
    refs.mg = mg

    p = mg.createChild("Poster")
    p.id = "pxPoster" + sid
    p.uri = uri
    p.width = dims.tw
    p.height = dims.th
    p.loadDisplayMode = "scaleToFill"
    p.opacity = dims.op
    refs.poster = p

    ' Lane height drives LayoutGroup vertAlignment centering (no invisible spacer rect).
    lane = frame.createChild("Rectangle")
    lane.id = "pxLane" + sid
    lane.width = dims.fw
    lane.height = laneH
    lane.color = "0x00000000"
    lane.visible = false
    refs.slot = lane

    refs.bar = invalid
    if isActive then PX_AddThumbBar(refs, dims)

    return refs
end function

sub PX_SetThumbInstant(refs as object, isActive as boolean)
    if refs = invalid then return
    dims = PX_ThumbDims(isActive)
    refs.isActive = isActive

    refs.slot.width = dims.fw
    refs.shell.uri = dims.shellUri
    refs.shell.width = dims.fw
    refs.shell.height = dims.fh
    refs.shell.translation = [0, dims.yOff]
    refs.mg.maskUri = dims.maskUri
    refs.mg.maskSize = [dims.tw, dims.th]
    refs.mg.translation = [dims.inset, dims.yOff + dims.inset]
    refs.poster.width = dims.tw
    refs.poster.height = dims.th
    refs.poster.opacity = dims.op

    if isActive then
        PX_AddThumbBar(refs, dims)
    else
        PX_RemoveThumbBar(refs)
    end if
end sub

sub PX_AddThumbInterp(anim as object, node as object, fieldName as string, fromV as float, toV as float)
    if node = invalid then return
    interp = anim.createChild("FloatFieldInterpolator")
    interp.key = [0.0, 1.0]
    interp.keyValue = [fromV, toV]
    interp.fieldToInterp = node.id + "." + fieldName
end sub

sub PX_AddVec2Interp(anim as object, node as object, fieldName as string, fromV as object, toV as object)
    if node = invalid then return
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.key = [0.0, 1.0]
    interp.keyValue = [fromV, toV]
    interp.fieldToInterp = node.id + "." + fieldName
end sub

sub AnimateThumbSlot(refs as object, toActive as boolean, anim as object)
    if refs = invalid or anim = invalid then return
    fromD = PX_ThumbDims(refs.isActive)
    toD = PX_ThumbDims(toActive)

    if toActive then
        refs.shell.uri = toD.shellUri
        refs.mg.maskUri = toD.maskUri
    end if

    PX_AddThumbInterp(anim, refs.slot, "width", fromD.fw, toD.fw)
    PX_AddThumbInterp(anim, refs.shell, "width", fromD.fw, toD.fw)
    PX_AddThumbInterp(anim, refs.shell, "height", fromD.fh, toD.fh)
    PX_AddVec2Interp(anim, refs.shell, "translation", [0, fromD.yOff], [0, toD.yOff])
    PX_AddVec2Interp(anim, refs.mg, "translation", [fromD.inset, fromD.yOff + fromD.inset], [toD.inset, toD.yOff + toD.inset])
    PX_AddThumbInterp(anim, refs.poster, "opacity", fromD.op, toD.op)
    PX_AddThumbInterp(anim, refs.poster, "width", fromD.tw, toD.tw)
    PX_AddThumbInterp(anim, refs.poster, "height", fromD.th, toD.th)

    refs.pendingActive = toActive
end sub

sub OnThumbTransitionDone()
    if m.thumbTransAnim = invalid or m.thumbTransAnim.state <> "stopped" then return
    for each refs in m.thumbSlots
        if refs.pendingActive <> invalid then
            toActive = refs.pendingActive
            refs.pendingActive = invalid
            PX_SetThumbInstant(refs, toActive)
        end if
    end for
    if m.thumbTransAnim <> invalid then
        m.top.removeChild(m.thumbTransAnim)
        m.thumbTransAnim = invalid
    end if
    StartThumbProgress(68)
end sub

sub AnimateThumbTransition(oldIdx as integer, newIdx as integer)
    if m.thumbSlots = invalid or m.thumbSlots.Count() = 0 then return
    if oldIdx = newIdx then return

    if m.thumbTransAnim <> invalid then
        m.top.removeChild(m.thumbTransAnim)
        m.thumbTransAnim = invalid
    end if
    ClearThumbProgressAnim()
    if oldIdx >= 0 and oldIdx < m.thumbSlots.Count() then PX_RemoveThumbBar(m.thumbSlots[oldIdx])

    anim = m.top.createChild("Animation")
    anim.duration = PX_ThumbSpringDur()
    anim.repeat = false
    anim.easeFunction = "outBack"
    anim.observeField("state", "OnThumbTransitionDone")

    if oldIdx >= 0 and oldIdx < m.thumbSlots.Count() then
        AnimateThumbSlot(m.thumbSlots[oldIdx], false, anim)
    end if
    if newIdx >= 0 and newIdx < m.thumbSlots.Count() then
        AnimateThumbSlot(m.thumbSlots[newIdx], true, anim)
    end if

    m.thumbTransAnim = anim
    anim.control = "start"
end sub

sub RebuildFrostStrip()
    if m.thumbHost = invalid or m.frostStrip = invalid then return
    ClearRuntimeAnims()
    m.thumbHost.removeChildrenIndex(m.thumbHost.getChildCount(), 0)
    m.thumbSlots = []

    count = ItemCount()
    if count < 2 then
        m.frostStrip.visible = false
        return
    end if

    for i = 0 to count - 1
        uri = GetHeroBannerImage(m.items[i])
        if uri = "" then continue for
        frame = m.thumbHost.createChild("Group")
        m.thumbSlots.Push(PX_CreateThumbSlot(frame, uri, i = m.activeIndex, i))
    end for

    stripW = PX_EstimateStripW(count)
    PositionFrostStrip(stripW)
    m.frostStrip.visible = true
    m.frostStrip.opacity = 1.0
    StartThumbProgress(68)
end sub

function PX_VertDotsH(count as integer, activeIdx as integer) as integer
    if count < 1 then return 0
    h = 0
    for i = 0 to count - 1
        if i = activeIdx then
            h = h + 28
        else
            h = h + 10
        end if
        if i < count - 1 then h = h + 6
    end for
    return h
end function

sub RebuildVertDots()
    if m.vertDots = invalid then return
    m.vertDots.removeChildrenIndex(m.vertDots.getChildCount(), 0)
    m.dotNodes = []
    count = ItemCount()
    if count < 2 then return
    for i = 0 to count - 1
        dot = m.vertDots.createChild("Poster")
        dot.id = "pxDot" + i.ToStr()
        dot.width = 4
        if i = m.activeIndex then
            dot.height = 28
            dot.uri = "pkg:/images/ui/parallax_dot_active.png"
            dot.blendColor = m.top.cPrimary500
        else
            dot.height = 10
            dot.uri = "pkg:/images/ui/parallax_dot_idle.png"
        end if
        dot.loadDisplayMode = "scaleToFill"
        m.dotNodes.Push(dot)
    end for
    PositionVertDots(m.activeIndex)
end sub

sub PositionVertDots(activeIdx as integer)
    if m.vertDots = invalid then return
    dotsH = PX_VertDotsH(m.dotNodes.Count(), activeIdx)
    m.vertDots.translation = [1888, Int((PX_HeroH() - dotsH) / 2)]
end sub

sub AnimateDotTransition(oldIdx as integer, newIdx as integer)
    if m.dotNodes = invalid or m.dotNodes.Count() = 0 then return
    if oldIdx = newIdx then return

    if m.dotTransAnim <> invalid then
        m.top.removeChild(m.dotTransAnim)
        m.dotTransAnim = invalid
    end if

    anim = m.top.createChild("Animation")
    anim.duration = PX_DotSpringDur()
    anim.repeat = false
    anim.easeFunction = "outBack"

    if oldIdx >= 0 and oldIdx < m.dotNodes.Count() then
        dot = m.dotNodes[oldIdx]
        PX_AddThumbInterp(anim, dot, "height", 28.0, 10.0)
    end if
    if newIdx >= 0 and newIdx < m.dotNodes.Count() then
        dot = m.dotNodes[newIdx]
        dot.uri = "pkg:/images/ui/parallax_dot_active.png"
        dot.blendColor = m.top.cPrimary500
        PX_AddThumbInterp(anim, dot, "height", 10.0, 28.0)
    end if
    if oldIdx >= 0 and oldIdx < m.dotNodes.Count() then
        dot = m.dotNodes[oldIdx]
        dot.uri = "pkg:/images/ui/parallax_dot_idle.png"
    end if

    m.dotTransAnim = anim
    anim.control = "start"
    PositionVertDots(newIdx)
end sub

sub PlayContentReveal()
    m.pendingContentReveal = false
    HeroPlayParallaxContentReveal(m.metaHost, m.contentOpacityInterp, m.contentAnim, m.accentWidthInterp, m.accentAnim, m.frostStrip, m.vertDots, m.accentLine)
end sub

sub OnContentDelay()
    if m.pendingContentReveal then PlayContentReveal()
end sub

sub RestartSwipeTimer()
    if m.swipeTimer <> invalid then
        m.swipeTimer.control = "stop"
        m.swipeTimer.control = "start"
    end if
end sub

sub OnSwipeTimer()
    if m.isSliding or ItemCount() <= 1 then return
    BeginSlide("up", NextIndex(m.activeIndex))
end sub

sub ApplySlideEasing(dir as string)
    keys = PX_SlideEaseKeys()
    fracs = PX_SlideEaseFractions()
    heroH = PX_HeroH()
    restY = PX_PosterRestY()
    px = PX_PosterX()

    slideVals = []
    parallaxVals = []
    for i = 0 to fracs.Count() - 1
        f = fracs[i]
        if dir = "up" then
            slideVals.Push([0, -Int(heroH * f)])
            parallaxVals.Push([px, restY + Int(60 * f)])
        else
            slideVals.Push([0, Int(heroH * f)])
            parallaxVals.Push([px, restY - Int(60 * f)])
        end if
    end for

    if m.slideInterp <> invalid then
        m.slideInterp.key = keys
        m.slideInterp.keyValue = slideVals
    end if
    if m.parallaxInterp <> invalid then
        m.parallaxInterp.key = keys
        m.parallaxInterp.keyValue = parallaxVals
    end if
end sub

sub BeginNextKenBurn()
    if m.nextPoster = invalid then return
    if m.nextKenAnim <> invalid then m.top.removeChild(m.nextKenAnim)

    ' React: next layer scale(1.05)→scale(1) during slide (1200ms); match over slide duration.
    anim = m.top.createChild("Animation")
    anim.duration = 0.8
    anim.repeat = false
    anim.easeFunction = "outQuad"
    w = anim.createChild("FloatFieldInterpolator")
    w.key = [0.0, 1.0]
    w.keyValue = [PX_PosterW(), 1920.0]
    w.fieldToInterp = "nextPoster.width"
    h = anim.createChild("FloatFieldInterpolator")
    h.key = [0.0, 1.0]
    h.keyValue = [PX_PosterH(), 918.0]
    h.fieldToInterp = "nextPoster.height"
    t = anim.createChild("Vector2DFieldInterpolator")
    t.key = [0.0, 1.0]
    t.keyValue = [[PX_PosterX(), PX_NextPosterY()], [0.0, 0.0]]
    t.fieldToInterp = "nextPoster.translation"
    m.nextKenAnim = anim
    anim.control = "start"
end sub

sub BeginSlide(dir as string, targetIdx as integer)
    if m.isSliding or ItemCount() <= 1 then return
    m.isSliding = true
    m.slideDir = dir
    m.pendingIndex = targetIdx
    m.contentReady = false

    ' React: contentReady=false hides meta immediately; thumbs stay on OLD active during slide.
    HeroHideMetaHost(m.metaHost)

    revealUri = GetHeroBannerImage(m.items[targetIdx])
    if m.nextPoster <> invalid and revealUri <> "" then m.nextPoster.uri = revealUri
    ResetPosterTransforms()
    BeginNextKenBurn()

    ApplySlideEasing(dir)

    if dir = "up" then
        if m.slideShadow <> invalid then
            m.slideShadow.translation = [0, 642]
            m.slideShadow.uri = "pkg:/images/ui/grad_bottom.png"
            m.slideShadow.height = 276
            m.slideShadow.opacity = 1.0
        end if
    else
        if m.slideShadow <> invalid then
            m.slideShadow.translation = [0, 0]
            m.slideShadow.uri = "pkg:/images/ui/grad_top.png"
            m.slideShadow.height = 276
            m.slideShadow.opacity = 1.0
        end if
    end if

    if m.slideAnim <> invalid then m.slideAnim.control = "start"
    if m.parallaxAnim <> invalid then m.parallaxAnim.control = "start"
end sub

sub OnSlideAnimState()
    if m.slideAnim = invalid or m.slideAnim.state <> "stopped" then return
    if not m.isSliding then return

    targetIdx = m.pendingIndex
    oldIdx = m.activeIndex
    m.pendingIndex = invalid
    m.isSliding = false

    ' React: swap activeIndex while layer is off-screen, then reset transform — no flash of old slide.
    if targetIdx <> invalid then
        CommitSlideIndex(targetIdx)
        AnimateThumbTransition(oldIdx, targetIdx)
        AnimateDotTransition(oldIdx, targetIdx)
    end if

    if m.activeLayer <> invalid then m.activeLayer.translation = [0, 0]
    ResetPosterTransforms()

    if m.slideShadow <> invalid then
        m.slideShadow.opacity = 0.0
        m.slideShadow.uri = "pkg:/images/ui/grad_bottom.png"
        m.slideShadow.translation = [0, 642]
    end if

    m.pendingContentReveal = true
    m.contentReady = true
    if m.contentDelayTimer <> invalid then
        m.contentDelayTimer.control = "stop"
        m.contentDelayTimer.control = "start"
    else
        PlayContentReveal()
    end if
    RestartSwipeTimer()
end sub

sub OnPosterLoad()
    if m.activePoster = invalid then return
    st = m.activePoster.loadStatus
    if st = "ready" or st = "failed" then MarkPosterReady()
end sub

sub MarkPosterReady()
    if m.posterReadyFired then return
    m.posterReadyFired = true
    if m.top.posterReady <> true then m.top.posterReady = true
end sub

function HeroGoNext(dummy = invalid as dynamic) as boolean
    if ItemCount() < 2 then return true
    RestartSwipeTimer()
    BeginSlide("up", NextIndex(m.activeIndex))
    return true
end function

function HeroGoPrev(dummy = invalid as dynamic) as boolean
    if ItemCount() <= 1 then return true
    RestartSwipeTimer()
    BeginSlide("down", PrevIndex(m.activeIndex))
    return true
end function

function HeroToggleMute(dummy = invalid as dynamic) as boolean
    return true
end function

function PauseAutoAdvance(dummy = invalid as dynamic) as boolean
    if m.swipeTimer <> invalid then m.swipeTimer.control = "stop"
    return true
end function

function ResumeAutoAdvance(dummy = invalid as dynamic) as boolean
    if not m.top.visible or ItemCount() < 2 then return true
    RestartSwipeTimer()
    return true
end function

function ResumeHeroPlayback(dummy = invalid as dynamic) as boolean
    return ResumeAutoAdvance(invalid)
end function

function PauseHeroPlayback(dummy = invalid as dynamic) as boolean
    return PauseAutoAdvance(invalid)
end function
