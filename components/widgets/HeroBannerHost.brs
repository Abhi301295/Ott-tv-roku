sub init()
    ' HeroBannerHost selects one child by theme; all children expose the same callFunc
    ' surface (HeroGoNext/Prev, PauseAutoAdvance, etc.) documented in HeroSlide.brs.
    m.heroCinematic = m.top.findNode("heroCinematic")
    m.heroPageFlip = m.top.findNode("heroPageFlip")
    m.heroParallax = m.top.findNode("heroParallax")
    m.heroOtt = m.top.findNode("heroOtt")
    m.activeHero = invalid
    ApplyHeroSelection()
    WireHeroObservers()
    ' HomeScreen hides this host (visible=false) when another tab/screen covers Home. The
    ' active hero child keeps visible=true unless we clear it — swipe/trailer timers then
    ' keep firing contents/view fetches while the user is on Reels or VideoPlayer.
    m.top.observeField("visible", "OnHostVisibleChanged")
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
    ' Sync items before showing the child so OnVisibleChanged sees a populated slide list.
    SyncToActiveHero()
    if m.activeHero <> invalid then m.activeHero.visible = true
    ApplyAutoAdvanceHold()
end sub

sub HideAllHeroes()
    for each h in [m.heroCinematic, m.heroPageFlip, m.heroParallax, m.heroOtt]
        if h <> invalid then h.visible = false
    end for
end sub

' Mirror host visibility onto hero children so each widget's OnVisibleChanged runs
' StopTrailer / CancelDetailFetch when Home is covered or disposed.
sub OnHostVisibleChanged()
    if m.top.visible = true then
        ApplyHeroSelection()
        ResumeActiveHeroPlayback()
    else
        PauseActiveHeroPlayback()
    end if
end sub

' Tear down swipe/trailer timers on every active child (host visible=false or explicit pause).
sub PauseActiveHeroPlayback()
    if m.activeHero <> invalid then m.activeHero.callFunc("PauseHeroPlayback", invalid)
    HideAllHeroes()
end sub

' Re-arm swipe + trailer on the active child. Called when the host becomes visible and
' from HomeScreen stack resume — hero.visible may already be true so OnVisibleChanged alone
' is not enough to reschedule trailers after a push/pop.
sub ResumeActiveHeroPlayback()
    if m.top.visible <> true then return
    if m.activeHero = invalid then return
    m.activeHero.callFunc("ResumeHeroPlayback", invalid)
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

sub OnAutoAdvanceHoldChanged()
    ApplyAutoAdvanceHold()
end sub

sub ApplyAutoAdvanceHold()
    if m.activeHero = invalid then return
    if m.top.autoAdvanceHold = true then
        m.activeHero.callFunc("PauseAutoAdvance", invalid)
    else
        m.activeHero.callFunc("ResumeAutoAdvance", invalid)
    end if
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

function PauseAutoAdvance(dummy = invalid as dynamic) as boolean
    if m.activeHero <> invalid then m.activeHero.callFunc("PauseAutoAdvance", invalid)
    return true
end function

function ResumeAutoAdvance(dummy = invalid as dynamic) as boolean
    if m.activeHero <> invalid then m.activeHero.callFunc("ResumeAutoAdvance", invalid)
    return true
end function

function PauseHeroPlayback(dummy = invalid as dynamic) as boolean
    PauseActiveHeroPlayback()
    return true
end function

function ResumeHeroPlayback(dummy = invalid as dynamic) as boolean
    if m.top.visible <> true then return true
    if m.activeHero = invalid then ApplyHeroSelection()
    if m.activeHero <> invalid then
        if m.activeHero.visible <> true then m.activeHero.visible = true
        m.activeHero.callFunc("ResumeHeroPlayback", invalid)
    end if
    return true
end function
