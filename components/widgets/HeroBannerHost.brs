sub init()
    m.heroCinematic = m.top.findNode("heroCinematic")
    m.heroPageFlip = m.top.findNode("heroPageFlip")
    m.heroParallax = m.top.findNode("heroParallax")
    m.heroOtt = m.top.findNode("heroOtt")
    m.activeHero = invalid
    ApplyHeroSelection()
    WireHeroObservers()
end sub

sub ApplyHeroSelection()
    HideAllHeroes()
    if ThemeIsOttHome() then
        m.activeHero = m.heroOtt
    else if ThemeHeroBannerStyle() = TC_HeroPageFlip() then
        m.activeHero = m.heroPageFlip
    else if ThemeHeroBannerStyle() = TC_HeroParallaxSlide() then
        m.activeHero = m.heroParallax
    else
        m.activeHero = m.heroCinematic
    end if
    if m.activeHero <> invalid then
        m.activeHero.visible = true
    end if
    SyncToActiveHero()
end sub

sub HideAllHeroes()
    for each h in [m.heroCinematic, m.heroPageFlip, m.heroParallax, m.heroOtt]
        if h <> invalid then h.visible = false
    end for
end sub

sub WireHeroObservers()
    for each h in [m.heroCinematic, m.heroPageFlip, m.heroParallax, m.heroOtt]
        if h <> invalid then h.observeField("posterReady", "OnChildPosterReady")
        if h <> invalid then h.observeField("trailerPlaying", "OnChildTrailerPlaying")
    end for
end sub

sub OnChildPosterReady()
    if m.activeHero = invalid then return
    if m.activeHero.posterReady = true and m.top.posterReady <> true then
        m.top.posterReady = true
    end if
end sub

sub OnChildTrailerPlaying()
    if m.activeHero = invalid then return
    playing = m.activeHero.trailerPlaying = true
    if m.top.trailerPlaying <> playing then m.top.trailerPlaying = playing
end sub

sub SyncToActiveHero()
    if m.activeHero = invalid then return
    m.activeHero.bannerItems = m.top.bannerItems
    if m.activeHero.hasField("activeItem") then m.activeHero.activeItem = m.top.activeItem
    SyncHeroTheme()
    SyncHeroFocus()
    SyncHeroViewport()
end sub

sub SyncHeroTheme()
    if m.activeHero = invalid then return
    m.activeHero.cNeutral50 = m.top.cNeutral50
    m.activeHero.cPrimary500 = m.top.cPrimary500
end sub

sub SyncHeroFocus()
    if m.activeHero = invalid then return
    m.activeHero.focusTarget = m.top.focusTarget
end sub

sub SyncHeroViewport()
    if m.activeHero = invalid then return
    if m.activeHero.hasField("contentWidth") then
        m.activeHero.contentWidth = m.top.contentWidth
    end if
end sub

sub OnBannerItemsChanged()
    SyncToActiveHero()
end sub

sub OnActiveItemChanged()
    SyncToActiveHero()
end sub

sub OnThemeChanged()
    SyncHeroTheme()
end sub

sub OnFocusTargetChanged()
    SyncHeroFocus()
end sub

sub OnContentWidthChanged()
    SyncHeroViewport()
end sub

function HeroGoNext(dummy = invalid as dynamic) as boolean
    if m.activeHero <> invalid then return m.activeHero.callFunc("HeroGoNext", invalid)
    return true
end function

function HeroGoPrev(dummy = invalid as dynamic) as boolean
    if m.activeHero <> invalid then return m.activeHero.callFunc("HeroGoPrev", invalid)
    return true
end function

function HeroToggleMute(dummy = invalid as dynamic) as boolean
    if m.activeHero <> invalid then return m.activeHero.callFunc("HeroToggleMute", invalid)
    return true
end function
