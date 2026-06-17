sub init()
    m.bannerPoster = m.top.findNode("bannerPoster")
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
    uri = GetHeroBannerImage(item)
    m.posterReadyFired = false
    if m.top.posterReady = true then m.top.posterReady = false
    if m.bannerPoster = invalid then return
    if uri <> "" then
        m.bannerPoster.uri = uri
        m.bannerPoster.visible = true
        BeginFadeIn()
        st = m.bannerPoster.loadStatus
        if st = "ready" or st = "failed" then MarkPosterReady()
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
    if st = "ready" or st = "failed" then MarkPosterReady()
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
