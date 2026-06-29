' OTT single-banner hero — parity banner/index.tsx (activeItem, no carousel).
' ⚠ Parity Note: HeroGoNext/Prev are no-ops; no multi-slide timer or trailer.
sub init()
    m.bannerPoster = m.top.findNode("bannerPoster")
    m.heroBg = m.top.findNode("heroBg")
    m.imageHost = m.top.findNode("imageHost")
    m.imageFallback = m.top.findNode("imageFallback")
    m.gradLeft = m.top.findNode("gradLeft")
    m.gradTop = m.top.findNode("gradTop")
    m.gradBottom = m.top.findNode("gradBottom")
    m.titleLabel = m.top.findNode("titleLabel")
    m.ratingHost = m.top.findNode("ratingHost")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.qualityBadge = m.top.findNode("qualityBadge")
    m.qualityBg = m.top.findNode("qualityBg")
    m.qualityLabel = m.top.findNode("qualityLabel")
    m.maturityBadge = m.top.findNode("maturityBadge")
    m.maturityLabel = m.top.findNode("maturityLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.fadeAnim = m.top.findNode("fadeAnim")
    m.fadeInterp = m.top.findNode("fadeInterp")
    m.scaleAnim = m.top.findNode("scaleAnim")
    m.scaleInterp = m.top.findNode("scaleInterp")
    m.fallbackItems = []
    m.posterReadyFired = false
    if m.bannerPoster <> invalid then m.bannerPoster.observeField("loadStatus", "OnPosterLoad")
    m.posterReadyTimer = CreateObject("roSGNode", "Timer")
    m.posterReadyTimer.duration = HC_OttPosterReadyMaxSec()
    m.posterReadyTimer.repeat = false
    m.top.appendChild(m.posterReadyTimer)
    m.posterReadyTimer.observeField("fire", "OnPosterReadyTimeout")
    if m.fadeAnim <> invalid then m.fadeAnim.duration = HC_HeroOttFadeSec()
    if m.scaleAnim <> invalid then m.scaleAnim.duration = HC_HeroOttFadeSec()
    ApplyViewportLayout()
end sub

sub OnContentWidthChanged()
    ApplyViewportLayout()
end sub

' Clip hero to the content area right of the sidebar (parity with HeroBannerCinematic).
sub ApplyViewportLayout()
    w = m.top.contentWidth
    if w = invalid or w < 400 then w = 1920

    m.top.clippingRect = [0, 0, w, 1080]
    m.top.clippingRectClipsChildren = true

    if m.heroBg <> invalid then m.heroBg.width = w
    if m.imageHost <> invalid then
        m.imageHost.clippingRect = [0, 0, w, 1080]
        m.imageHost.clippingRectClipsChildren = true
    end if
    if m.imageFallback <> invalid then m.imageFallback.width = w
    if m.bannerPoster <> invalid then m.bannerPoster.width = w
    if m.gradTop <> invalid then m.gradTop.width = w
    if m.gradBottom <> invalid then m.gradBottom.width = w
end sub

sub OnThemeChanged()
    if m.titleLabel <> invalid then m.titleLabel.color = m.top.cNeutral50
    if m.ratingLabel <> invalid then m.ratingLabel.color = m.top.cNeutral50
    if m.genreLabel <> invalid then m.genreLabel.color = m.top.cNeutral50
    if m.descLabel <> invalid then m.descLabel.color = "0xffffffe6"
    item = m.top.activeItem
    if item = invalid and m.fallbackItems.Count() > 0 then item = m.fallbackItems[0]
    ApplyMeta(item)
end sub

sub OnBannerItemsChanged()
    items = m.top.bannerItems
    if items = invalid then
        m.fallbackItems = []
    else
        m.fallbackItems = items
    end if
    if m.top.activeItem = invalid and m.fallbackItems.Count() > 0 then
        m.top.activeItem = m.fallbackItems[0]
    end if
end sub

sub OnActiveItemChanged()
    item = m.top.activeItem
    if item = invalid and m.fallbackItems.Count() > 0 then item = m.fallbackItems[0]
    ApplyMeta(item)
    uri = GetOttBannerImage(item)
    m.posterReadyFired = false
    if m.top.posterReady = true then m.top.posterReady = false
    if m.bannerPoster = invalid then return
    if uri <> "" then
        m.bannerPoster.uri = uri
        m.bannerPoster.visible = true
        BeginFadeIn()
        st = m.bannerPoster.loadStatus
        if st = "ready" or st = "failed" then
            MarkPosterReady()
        else if m.posterReadyTimer <> invalid then
            m.posterReadyTimer.control = "stop"
            m.posterReadyTimer.control = "start"
        end if
    else
        m.bannerPoster.visible = false
        MarkPosterReady()
    end if
end sub

sub ApplyMeta(item as object)
    HeroApplyOttMeta(item, m.titleLabel, m.ratingHost, m.ratingLabel, m.genreLabel, m.qualityBadge, m.qualityLabel, m.descLabel, m.top.cPrimary500, m.qualityBg, m.maturityBadge, m.maturityLabel)
    if m.maturityBadge <> invalid and m.maturityLabel <> invalid and item <> invalid then
        mat = ""
        if item.maturityRating <> invalid then mat = item.maturityRating
        if mat <> "" then
            w = Len(mat) * 10 + 24
            if w < 44 then w = 44
            bg = m.maturityBadge.findNode("maturityBg")
            border = m.maturityBadge.findNode("maturityBorder")
            if bg <> invalid then bg.width = w
            if border <> invalid then border.width = w
            m.maturityLabel.width = w
        end if
    end if
end sub

sub BeginFadeIn()
    if m.bannerPoster = invalid then return
    m.bannerPoster.opacity = 0.0
    m.bannerPoster.scale = [1.05, 1.05]
    if m.fadeInterp <> invalid and m.fadeAnim <> invalid then
        m.fadeInterp.keyValue = [0.0, 1.0]
        m.fadeAnim.control = "start"
    end if
    if m.scaleInterp <> invalid and m.scaleAnim <> invalid then
        m.scaleInterp.keyValue = [[1.05, 1.05], [1.0, 1.0]]
        m.scaleAnim.control = "start"
    end if
end sub

sub OnPosterLoad()
    if m.bannerPoster = invalid then return
    st = m.bannerPoster.loadStatus
    if st = "ready" or st = "failed" then
        if m.posterReadyTimer <> invalid then m.posterReadyTimer.control = "stop"
        MarkPosterReady()
    end if
end sub

sub OnPosterReadyTimeout()
    if m.posterReadyFired then return
    MarkPosterReady()
end sub

sub MarkPosterReady()
    if m.posterReadyFired then return
    m.posterReadyFired = true
    if m.top.posterReady <> true then m.top.posterReady = true
end sub

function HeroGoNext(dummy = invalid as dynamic) as boolean
    return true
end function

function HeroGoPrev(dummy = invalid as dynamic) as boolean
    return true
end function

function HeroToggleMute(dummy = invalid as dynamic) as boolean
    return true
end function

function PauseAutoAdvance(dummy = invalid as dynamic) as boolean
    return true
end function

function ResumeAutoAdvance(dummy = invalid as dynamic) as boolean
    return true
end function

function ResumeHeroPlayback(dummy = invalid as dynamic) as boolean
    return true
end function

function PauseHeroPlayback(dummy = invalid as dynamic) as boolean
    return true
end function
