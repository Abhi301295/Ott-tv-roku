sub init()
    m.items = []
    m.activeIndex = 0
    m.isFading = false

    m.nextPoster = m.top.findNode("nextPoster")
    m.activePoster = m.top.findNode("activePoster")
    m.activeLayer = m.top.findNode("activeLayer")
    m.titleLabel = m.top.findNode("titleLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.descLabel = m.top.findNode("descLabel")
    m.dotsHost = m.top.findNode("dotsHost")
    m.swipeTimer = m.top.findNode("swipeTimer")
    m.fadeAnim = m.top.findNode("fadeAnim")
    m.zoomAnim = m.top.findNode("zoomAnim")

    m.swipeTimer.duration = HC_HeroSwipeMs() / 1000.0
    m.fadeAnim.duration = HC_HeroCrossfadeSec()
    m.zoomAnim.duration = HC_HeroZoomSec()

    m.swipeTimer.observeField("fire", "OnSwipeTimer")
    m.fadeAnim.observeField("state", "OnFadeAnimState")
    m.top.observeField("visible", "OnVisibleChanged")
end sub

sub OnVisibleChanged()
    if m.top.visible = true then
        StartSwipeTimer()
    else
        StopSwipeTimer()
    end if
end sub

sub OnBannerItemsChanged()
    StopSwipeTimer()
    m.isFading = false
    m.activeIndex = 0
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0

    items = m.top.bannerItems
    if items = invalid then
        m.items = []
    else
        m.items = items
    end if

    ApplySlides()
    ApplyMeta()
    BuildDots()
    if m.top.visible and m.items.Count() > 1 then StartSwipeTimer()
end sub

sub OnThemeChanged()
    if m.titleLabel <> invalid then m.titleLabel.color = m.top.cNeutral50
    if m.genreLabel <> invalid then m.genreLabel.color = m.top.cNeutral50
    if m.descLabel <> invalid then m.descLabel.color = "0xf8f1f7cc"
    UpdateDots()
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
    if m.activePoster <> invalid then
        m.activePoster.uri = GetHeroBannerImage(active)
        m.activePoster.scale = [1.0, 1.0]
        m.activePoster.translation = [-240, 0]
    end if
    if m.nextPoster <> invalid then
        m.nextPoster.uri = GetHeroBannerImage(nxt)
        m.nextPoster.scale = [1.0, 1.0]
        m.nextPoster.translation = [-240, 0]
    end if
    StartKenBurns()
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
end sub

sub BuildDots()
    if m.dotsHost = invalid then return
    count = m.dotsHost.getChildCount()
    for i = count - 1 to 0 step -1
        m.dotsHost.removeChildIndex(i)
    end for
    total = ItemCount()
    if total < 2 then return

    x = 0
    gap = 12
    for i = 0 to total - 1
        dot = CreateObject("roSGNode", "Rectangle")
        dot.width = 10
        dot.height = 10
        dot.translation = [x, 0]
        dot.color = m.top.cPrimary500
        dot.opacity = 0.35
        m.dotsHost.appendChild(dot)
        x = x + gap
    end for
    UpdateDots()
end sub

sub UpdateDots()
    if m.dotsHost = invalid then return
    count = m.dotsHost.getChildCount()
    for i = 0 to count - 1
        dot = m.dotsHost.getChild(i)
        if dot = invalid then continue for
        if i = m.activeIndex then
            dot.opacity = 1.0
            dot.width = 24
        else
            dot.opacity = 0.35
            dot.width = 10
        end if
    end for
end sub

sub StartKenBurns()
    if m.zoomAnim = invalid or m.activePoster = invalid then return
    m.activePoster.scale = [1.0, 1.0]
    m.zoomAnim.control = "stop"
    m.zoomAnim.control = "start"
end sub

sub StartSwipeTimer()
    if m.swipeTimer = invalid or ItemCount() < 2 then return
    m.swipeTimer.control = "start"
end sub

sub StopSwipeTimer()
    if m.swipeTimer = invalid then return
    m.swipeTimer.control = "stop"
end sub

sub OnSwipeTimer()
    if m.isFading or ItemCount() < 2 then return
    BeginCrossfade()
end sub

sub BeginCrossfade()
    if m.fadeAnim = invalid or m.activeLayer = invalid then return
    m.isFading = true
    m.activeLayer.opacity = 1.0
    m.fadeAnim.control = "stop"
    m.fadeAnim.control = "start"
end sub

sub OnFadeAnimState()
    if m.fadeAnim = invalid then return
    if m.fadeAnim.state <> "stopped" then return
    if not m.isFading then return

    count = ItemCount()
    if count > 0 then
        m.activeIndex = (m.activeIndex + 1) mod count
    end if
    m.isFading = false
    if m.activeLayer <> invalid then m.activeLayer.opacity = 1.0
    ApplySlides()
    ApplyMeta()
    UpdateDots()
end sub
