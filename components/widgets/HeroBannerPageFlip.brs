' Page-flip hero — parity heroBanner.tsx (curl strip flip).
' ⚠ Parity Note: no trailer playback; meta fades during curl (metaFadeAnim) then restores.

function PF_StripCount() as integer
    return 40
end function

function PF_StripW() as integer
    return 48  ' 1920 / 40
end function

function PF_FlipSec() as float
    return 0.9
end function

function PF_StripCurlSec() as float
    return 0.48
end function

sub init()
    m.items = []
    m.activeIndex = 0
    m.isFlipping = false
    m.posterReadyFired = false
    m.stripAnims = []

    m.nextPoster = m.top.findNode("nextPoster")
    m.activePage = m.top.findNode("activePage")
    m.activePoster = m.top.findNode("activePoster")
    m.stripHost = m.top.findNode("stripHost")
    m.curlFold = m.top.findNode("curlFold")
    m.curlFoldSoft = m.top.findNode("curlFoldSoft")
    m.spineShadow = m.top.findNode("spineShadow")
    m.metaHost = m.top.findNode("metaHost")
    m.upNextHost = m.top.findNode("upNextHost")
    m.upNextShape = m.top.findNode("upNextShape")
    m.upNextLabel = m.top.findNode("upNextLabel")
    m.upNextCard = m.top.findNode("upNextCard")
    m.upNextFocusRing = m.top.findNode("upNextFocusRing")
    m.titleLabel = m.top.findNode("titleLabel")
    m.ratingHost = m.top.findNode("ratingHost")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.qualityBadge = m.top.findNode("qualityBadge")
    m.qualityBg = m.top.findNode("qualityBg")
    m.qualityLabel = m.top.findNode("qualityLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.dotsHost = m.top.findNode("dotsHost")
    m.swipeTimer = m.top.findNode("swipeTimer")
    m.curlFoldAnim = m.top.findNode("curlFoldAnim")
    m.curlFoldInterp = m.top.findNode("curlFoldInterp")
    m.curlFoldSoftAnim = m.top.findNode("curlFoldSoftAnim")
    m.curlFoldSoftInterp = m.top.findNode("curlFoldSoftInterp")
    m.curlFoldFade = m.top.findNode("curlFoldFade")
    m.curlFoldSoftFade = m.top.findNode("curlFoldSoftFade")
    m.spineAnim = m.top.findNode("spineAnim")
    m.spineInterp = m.top.findNode("spineInterp")
    m.metaFadeAnim = m.top.findNode("metaFadeAnim")
    m.metaFadeInterp = m.top.findNode("metaFadeInterp")
    m.metaRestoreAnim = m.top.findNode("metaRestoreAnim")
    m.metaRestoreInterp = m.top.findNode("metaRestoreInterp")

    m.flipFinishTimer = CreateObject("roSGNode", "Timer")
    m.flipFinishTimer.duration = PF_FlipSec()
    m.flipFinishTimer.repeat = false
    m.top.appendChild(m.flipFinishTimer)
    m.flipFinishTimer.observeField("fire", "OnCurlComplete")

    if m.swipeTimer <> invalid then
        m.swipeTimer.duration = HC_HeroPageFlipSwipeSec()
        m.swipeTimer.observeField("fire", "OnSwipeTimer")
    end if
    if m.activePoster <> invalid then m.activePoster.observeField("loadStatus", "OnPosterLoad")
    m.top.observeField("visible", "OnVisibleChanged")
    ApplyUpNextLayout()
end sub

sub ApplyUpNextLayout()
    if m.upNextHost = invalid then return
    m.upNextHost.translation = [UN_HOST_X(1920), UN_TOP_Y(918)]
    lbl = m.top.findNode("upNextLabel")
    if lbl <> invalid then
        lbl.width = UN_W()
        lbl.height = UN_LABEL_H()
    end if
    card = m.top.findNode("upNextCard")
    if card <> invalid then card.translation = [0, UN_CARD_Y()]
    shadow = m.top.findNode("upNextShadow")
    if shadow <> invalid then shadow.translation = [UN_SHADOW_OX(), UN_SHADOW_OY()]
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
    if m.upNextFocusRing <> invalid then m.upNextFocusRing.color = m.top.cPrimary500
    if m.upNextShape <> invalid then m.upNextShape.cNeutral50 = m.top.cNeutral50
    ApplyUpNextFocus()
end sub

' Up Next is the page-flip "next" control — primary focus ring (parity cinematic next arrow).
sub OnFocusTargetChanged()
    ApplyUpNextFocus()
end sub

sub ApplyUpNextFocus()
    if m.upNextHost = invalid then return
    t = m.top.focusTarget
    on = (t = "next") and m.upNextHost.visible = true

    if m.upNextFocusRing <> invalid then m.upNextFocusRing.visible = on
    if m.upNextLabel <> invalid then
        if on then
            m.upNextLabel.color = m.top.cNeutral50
        else
            m.upNextLabel.color = "0xf8f1f799"
        end if
    end if
    if m.upNextCard <> invalid then
        if on then
            m.upNextCard.scale = [1.05, 1.05]
            m.upNextCard.scaleRotateCenter = [77.5, 110.0]
        else
            m.upNextCard.scale = [1.0, 1.0]
        end if
    end if
    if m.upNextShape <> invalid then
        m.upNextShape.focused = on
        m.upNextShape.cNeutral50 = m.top.cNeutral50
    end if
end sub

sub OnBannerItemsChanged()
    items = m.top.bannerItems
    if items = invalid then
        m.items = []
    else
        m.items = items
    end if
    m.activeIndex = 0
    m.isFlipping = false
    m.posterReadyFired = false
    if m.top.posterReady = true then m.top.posterReady = false
    ResetFlipPose()
    ShowSlide(0)
end sub

sub ResetFlipPose()
    ClearStripAnims()
    ClearStripHost()
    if m.flipFinishTimer <> invalid then m.flipFinishTimer.control = "stop"
    if m.curlFoldAnim <> invalid then m.curlFoldAnim.control = "stop"
    if m.curlFoldSoftAnim <> invalid then m.curlFoldSoftAnim.control = "stop"
    if m.curlFoldFade <> invalid then m.curlFoldFade.control = "stop"
    if m.curlFoldSoftFade <> invalid then m.curlFoldSoftFade.control = "stop"
    if m.spineAnim <> invalid then m.spineAnim.control = "stop"
    if m.spineShadow <> invalid then m.spineShadow.opacity = 0.0
    if m.curlFold <> invalid then
        m.curlFold.translation = [1920, 0]
        m.curlFold.opacity = 0.0
    end if
    if m.curlFoldSoft <> invalid then
        m.curlFoldSoft.translation = [1920, 0]
        m.curlFoldSoft.opacity = 0.0
    end if
    if m.metaHost <> invalid then m.metaHost.opacity = 1.0
    if m.upNextHost <> invalid then m.upNextHost.opacity = 1.0
    if m.activePage <> invalid then m.activePage.visible = true
    if m.stripHost <> invalid then m.stripHost.visible = false
end sub

sub ClearStripAnims()
    if m.stripAnims = invalid then return
    for each a in m.stripAnims
        if a <> invalid then m.top.removeChild(a)
    end for
    m.stripAnims = []
end sub

sub ClearStripHost()
    if m.stripHost = invalid then return
    m.stripHost.removeChildrenIndex(m.stripHost.getChildCount(), 0)
end sub

sub PushAnim(node as object)
    if node = invalid then return
    m.stripAnims.Push(node)
    node.control = "start"
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

sub ShowSlide(index as integer)
    count = ItemCount()
    if count = 0 then
        m.top.visible = false
        MarkPosterReady()
        return
    end if
    m.top.visible = true
    if index < 0 then index = 0
    if index >= count then index = count - 1
    m.activeIndex = index
    RefreshSlideVisuals()
end sub

sub RefreshSlideVisuals()
    item = m.items[m.activeIndex]
    ApplyMeta(item)

    uri = GetHeroBannerImage(item)
    if m.activePoster <> invalid and uri <> "" and m.activePoster.uri <> uri then
        m.activePoster.uri = uri
    end if

    nextIdx = NextIndex(m.activeIndex)
    nextUri = GetHeroBannerImage(m.items[nextIdx])
    if m.nextPoster <> invalid then
        if nextUri <> "" then
            if m.nextPoster.uri <> nextUri then m.nextPoster.uri = nextUri
            m.nextPoster.visible = true
        else
            m.nextPoster.visible = false
        end if
    end if

    BuildUpNext(nextIdx)
    BuildDots()
end sub

sub ApplyMeta(item as object)
    HeroApplyMeta(item, m.titleLabel, m.ratingHost, m.ratingLabel, m.genreLabel, m.qualityBadge, m.qualityLabel, m.descLabel, m.top.cPrimary500, m.qualityBg)
end sub

sub BuildUpNext(nextIdx as integer)
    if m.upNextHost = invalid then return
    count = ItemCount()
    if count < 2 then
        m.upNextHost.visible = false
        return
    end if
    nextItem = m.items[nextIdx]
    uri = GetHeroBannerImage(nextItem)
    if uri = "" then
        m.upNextHost.visible = false
        return
    end if
    if m.upNextShape = invalid then return

    heroUri = ""
    if m.activePoster <> invalid and m.activePoster.uri <> invalid then heroUri = m.activePoster.uri

    if m.upNextShape.posterUri <> uri then m.upNextShape.posterUri = uri
    m.upNextShape.heroUri = heroUri

    title = ""
    if nextItem.title <> invalid then title = nextItem.title
    if title = "" and nextItem.name <> invalid then title = nextItem.name
    titleStr = HeroTruncate(title, 40)
    if m.upNextShape.titleText <> titleStr then m.upNextShape.titleText = titleStr
    m.upNextShape.cNeutral50 = m.top.cNeutral50
    m.upNextHost.visible = true
end sub

sub BuildDots()
    if m.dotsHost = invalid then return
    m.dotsHost.removeChildrenIndex(m.dotsHost.getChildCount(), 0)
    count = ItemCount()
    if count < 2 then return
    for i = 0 to count - 1
        dot = m.dotsHost.createChild("Rectangle")
        if i = m.activeIndex then
            dot.width = 20
            dot.height = 6
            dot.color = m.top.cPrimary500
        else
            dot.width = 10
            dot.height = 6
            dot.color = "0xffffff66"
        end if
    end for
end sub

' 40 vertical slices curl right-to-left with perspective (scaleY + opacity) + paper back.
sub BuildStripCurl(uri as string)
    if m.stripHost = invalid or uri = "" then return
    ClearStripHost()
    ClearStripAnims()

    stripCount = PF_StripCount()
    stripW = PF_StripW()
    flipSec = PF_FlipSec()
    curlSec = PF_StripCurlSec()
    if stripCount > 1 then
        stagger = (flipSec - curlSec) / (stripCount - 1)
    else
        stagger = 0.0
    end if

    for i = 0 to stripCount - 1
        clipId = "sc" + i.toStr()
        pivotId = "sp" + i.toStr()
        pivotPath = "stripHost." + clipId + "." + pivotId

        clip = m.stripHost.createChild("Group")
        clip.id = clipId
        clip.translation = [i * stripW, 0]
        clip.clippingRect = [0, 0, stripW, 918]
        clip.clippingRectClipsChildren = true

        ' Paper back (warm off-white/brown — visible as column turns edge-on).
        back = clip.createChild("Rectangle")
        back.width = stripW
        back.height = 918
        back.color = "0x3d2e24ff"

        pivot = clip.createChild("Group")
        pivot.id = pivotId
        pivot.translation = [0, 459]
        pivot.scale = [1.0, 1.0]
        pivot.opacity = 1.0

        poster = pivot.createChild("Poster")
        poster.uri = uri
        poster.width = 1920
        poster.height = 918
        poster.translation = [-i * stripW, -459]
        poster.loadDisplayMode = "scaleToFill"

        ' Crease highlight on left edge of each column.
        crease = clip.createChild("Rectangle")
        crease.width = 1
        crease.height = 918
        crease.color = "0xffffff30"

        ' Page thickness shadow on right edge.
        shade = clip.createChild("Rectangle")
        shade.width = 5
        shade.height = 918
        shade.translation = [stripW - 5, 0]
        shade.color = "0x000000ff"
        shade.opacity = 0.5

        order = stripCount - 1 - i
        delay = order * stagger

        scaleAnim = m.top.createChild("Animation")
        scaleAnim.duration = curlSec
        scaleAnim.delay = delay
        scaleAnim.repeat = false
        scaleAnim.easeFunction = "inOutCubic"
        scaleInterp = scaleAnim.createChild("Vector2DFieldInterpolator")
        scaleInterp.key = [0.0, 1.0]
        scaleInterp.keyValue = [[1.0, 1.0], [0.001, 0.8]]
        scaleInterp.fieldToInterp = pivotPath + ".scale"
        PushAnim(scaleAnim)

        fadeAnim = m.top.createChild("Animation")
        fadeAnim.duration = curlSec
        fadeAnim.delay = delay
        fadeAnim.repeat = false
        fadeAnim.easeFunction = "inOutCubic"
        fadeInterp = fadeAnim.createChild("FloatFieldInterpolator")
        fadeInterp.key = [0.0, 1.0]
        fadeInterp.keyValue = [1.0, 0.08]
        fadeInterp.fieldToInterp = pivotPath + ".opacity"
        PushAnim(fadeAnim)
    end for
end sub

sub StartFoldShadows()
    if m.curlFoldInterp <> invalid and m.curlFoldAnim <> invalid then
        m.curlFoldInterp.keyValue = [[1880, 0], [-40, 0]]
        m.curlFoldAnim.control = "start"
    end if
    if m.curlFoldSoftInterp <> invalid and m.curlFoldSoftAnim <> invalid then
        m.curlFoldSoftInterp.keyValue = [[1960, 0], [-120, 0]]
        m.curlFoldSoftAnim.control = "start"
    end if
    if m.curlFoldFade <> invalid then m.curlFoldFade.control = "start"
    if m.curlFoldSoftFade <> invalid then m.curlFoldSoftFade.control = "start"
end sub

sub TriggerFlip(targetIndex as integer)
    if m.isFlipping or ItemCount() < 2 then return
    if targetIndex < 0 or targetIndex >= ItemCount() then return
    if targetIndex = m.activeIndex then return

    m.isFlipping = true
    m.pendingIndex = targetIndex

    behindUri = GetHeroBannerImage(m.items[targetIndex])
    if m.nextPoster <> invalid and behindUri <> "" then
        m.nextPoster.uri = behindUri
        m.nextPoster.visible = true
    end if

    activeUri = GetHeroBannerImage(m.items[m.activeIndex])
    if m.activePage <> invalid then m.activePage.visible = false
    if m.stripHost <> invalid then
        m.stripHost.visible = true
        BuildStripCurl(activeUri)
    end if

    if m.metaFadeInterp <> invalid and m.metaFadeAnim <> invalid then
        m.metaFadeInterp.keyValue = [1.0, 0.25]
        m.metaFadeAnim.control = "start"
    end if
    if m.upNextHost <> invalid then m.upNextHost.opacity = 0.35

    if m.spineAnim <> invalid then
        m.spineAnim.delay = 0.27
        if m.spineInterp <> invalid then m.spineInterp.keyValue = [0.0, 0.6]
        m.spineAnim.control = "start"
    end if

    StartFoldShadows()

    if m.flipFinishTimer <> invalid then
        m.flipFinishTimer.duration = PF_FlipSec()
        m.flipFinishTimer.control = "start"
    end if
end sub

sub OnCurlComplete()
    if not m.isFlipping then return

    ResetFlipPose()

    if m.pendingIndex <> invalid then m.activeIndex = m.pendingIndex
    m.pendingIndex = invalid
    m.isFlipping = false

    RefreshSlideVisuals()

    if m.metaRestoreInterp <> invalid and m.metaRestoreAnim <> invalid then
        m.metaRestoreInterp.keyValue = [0.25, 1.0]
        m.metaRestoreAnim.control = "start"
    else if m.metaHost <> invalid then
        m.metaHost.opacity = 1.0
    end if
end sub

sub OnSwipeTimer()
    if m.isFlipping or ItemCount() <= 1 then return
    TriggerFlip(NextIndex(m.activeIndex))
end sub

sub OnPosterLoad()
    if m.activePoster = invalid then return
    st = m.activePoster.loadStatus
    if st = "ready" or st = "failed" then
        if m.upNextShape <> invalid and m.activePoster.uri <> invalid then
            m.upNextShape.heroUri = m.activePoster.uri
        end if
        MarkPosterReady()
    end if
end sub

sub MarkPosterReady()
    if m.posterReadyFired then return
    m.posterReadyFired = true
    if m.top.posterReady <> true then m.top.posterReady = true
end sub

function HeroGoNext(dummy = invalid as dynamic) as boolean
    if ItemCount() <= 1 then return true
    if m.swipeTimer <> invalid then m.swipeTimer.control = "stop"
    TriggerFlip(NextIndex(m.activeIndex))
    if m.swipeTimer <> invalid then m.swipeTimer.control = "start"
    return true
end function

function HeroGoPrev(dummy = invalid as dynamic) as boolean
    if ItemCount() <= 1 then return true
    if m.swipeTimer <> invalid then m.swipeTimer.control = "stop"
    TriggerFlip(PrevIndex(m.activeIndex))
    if m.swipeTimer <> invalid then m.swipeTimer.control = "start"
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
    if m.swipeTimer <> invalid then
        m.swipeTimer.control = "stop"
        m.swipeTimer.control = "start"
    end if
    return true
end function

function ResumeHeroPlayback(dummy = invalid as dynamic) as boolean
    return ResumeAutoAdvance(invalid)
end function

function PauseHeroPlayback(dummy = invalid as dynamic) as boolean
    return PauseAutoAdvance(invalid)
end function
