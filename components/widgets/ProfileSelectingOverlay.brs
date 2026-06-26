sub init()
    m.contentHost = m.top.findNode("contentHost")
    m.avatarImg = m.top.findNode("avatarImg")
    m.initialsLbl = m.top.findNode("initialsLbl")
    m.circleBg = m.top.findNode("circleBg")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressArcRing = m.top.findNode("progressArcRing")
    m.welcomeLbl = m.top.findNode("welcomeLbl")
    m.statusLbl = m.top.findNode("statusLbl")
    m.fadeIn = m.top.findNode("fadeIn")
    m.arcTimer = m.top.findNode("arcTimer")
    m.statusTimer = m.top.findNode("statusTimer")

    m.arcFrame = 0
    m.arcMotionActive = false

    if m.arcTimer <> invalid then m.arcTimer.observeField("fire", "OnArcTick")
    if m.statusTimer <> invalid then m.statusTimer.control = "stop"

    OnColorsChanged()
    OnProfileChanged()
end sub

sub OnProfileChanged()
    nm = m.top.profileName
    if nm = invalid then nm = ""
    if m.welcomeLbl <> invalid then m.welcomeLbl.text = CopyWelcomeBack(nm)

    uri = m.top.avatarUri
    if m.avatarImg <> invalid then
        if uri <> invalid and uri <> "" then
            m.avatarImg.uri = uri
            m.avatarImg.visible = true
            if m.initialsLbl <> invalid then m.initialsLbl.text = ""
        else
            m.avatarImg.visible = false
            if m.initialsLbl <> invalid then m.initialsLbl.text = m.top.initials
        end if
    end if
end sub

sub OnColorsChanged()
    primary = m.top.primaryColor
    if primary = invalid or primary = "" then primary = "0x0b75e0ff"
    secondary = m.top.portalSecondary
    if secondary = invalid or secondary = "" then secondary = "0xd355cbff"
    tertiary = m.top.portalTertiary
    if tertiary = invalid or tertiary = "" then tertiary = ProfileArcHexToRoku(ProfileArcFallbackTertiaryHex())
    neutral50 = m.top.neutral50
    if neutral50 = invalid or neutral50 = "" then neutral50 = "0xf8f1f7ff"
    avatarBg = m.top.avatarBg
    if avatarBg = invalid or avatarBg = "" then avatarBg = "0x404040ff"

    if m.welcomeLbl <> invalid then m.welcomeLbl.color = neutral50
    if m.statusLbl <> invalid then m.statusLbl.color = primary
    if m.initialsLbl <> invalid then m.initialsLbl.color = neutral50
    if m.circleBg <> invalid then m.circleBg.blendColor = avatarBg
    if m.progressTrack <> invalid then m.progressTrack.blendColor = neutral50
    if m.progressArcRing <> invalid then
        m.progressArcRing.portalPrimary = primary
        m.progressArcRing.portalSecondary = secondary
        m.progressArcRing.portalTertiary = tertiary
    end if
end sub

sub OnRunningChanged()
    if m.top.running = true then
        StartMotion(m.arcMotionActive <> true)
    else
        StopMotion()
    end if
end sub

' coldStart=false resumes arc mid-spin without resetting frame or fade-in.
sub StartMotion(coldStart as boolean)
    if coldStart = false and m.arcMotionActive = true then return
    if coldStart = false and m.arcTimer <> invalid and m.arcTimer.control = "start" then
        m.arcMotionActive = true
        return
    end if

    m.arcMotionActive = true
    m.arcFrame = 0
    ApplyArcFrame()
    ApplyStatusLabel()
    if m.contentHost <> invalid then m.contentHost.opacity = 0.0
    if m.fadeIn <> invalid then m.fadeIn.control = "start"
    if m.arcTimer <> invalid then m.arcTimer.control = "start"
end sub

sub StopMotion()
    m.arcMotionActive = false
    if m.fadeIn <> invalid then m.fadeIn.control = "stop"
    if m.arcTimer <> invalid then m.arcTimer.control = "stop"
    if m.statusTimer <> invalid then m.statusTimer.control = "stop"
    if m.contentHost <> invalid then m.contentHost.opacity = 0.0
    ClearStatusLabel()
end sub

sub ClearStatusLabel()
    if m.statusLbl <> invalid then m.statusLbl.text = ""
end sub

function ClearStatusLabelFunc() as boolean
    ClearStatusLabel()
    return true
end function

' Prefetch phases only — apply label immediately; never rotate idle messages.
sub OnStatusTextChanged()
    ApplyStatusLabel()
end sub

sub ApplyStatusLabel()
    if m.statusLbl = invalid then return
    txt = m.top.statusText
    if txt = invalid then txt = ""
    if m.statusLbl.text <> txt then m.statusLbl.text = txt
end sub

sub OnArcTick()
    m.arcFrame = m.arcFrame + 2
    if m.arcFrame >= ProfileArcFrameCount() then m.arcFrame = 0
    ApplyArcFrame()
end sub

sub ApplyArcFrame()
    if m.progressArcRing = invalid then return
    m.progressArcRing.arcFrame = m.arcFrame
end sub
