sub init()
    m.contentHost = m.top.findNode("contentHost")
    m.avatarImg = m.top.findNode("avatarImg")
    m.initialsLbl = m.top.findNode("initialsLbl")
    m.circleBg = m.top.findNode("circleBg")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressArc = m.top.findNode("progressArc")
    m.welcomeLbl = m.top.findNode("welcomeLbl")
    m.statusLbl = m.top.findNode("statusLbl")
    m.fadeIn = m.top.findNode("fadeIn")
    m.arcTimer = m.top.findNode("arcTimer")
    m.statusTimer = m.top.findNode("statusTimer")

    m.arcFrame = 0
    m.statusIndex = 0
    m.statusMessages = CopySelectingStatusMessages()

    if m.arcTimer <> invalid then m.arcTimer.observeField("fire", "OnArcTick")
    if m.statusTimer <> invalid then m.statusTimer.observeField("fire", "OnStatusTick")

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
    neutral50 = m.top.neutral50
    if neutral50 = invalid or neutral50 = "" then neutral50 = "0xf8f1f7ff"
    avatarBg = m.top.avatarBg
    if avatarBg = invalid or avatarBg = "" then avatarBg = "0x404040ff"

    if m.welcomeLbl <> invalid then m.welcomeLbl.color = neutral50
    if m.statusLbl <> invalid then m.statusLbl.color = primary
    if m.initialsLbl <> invalid then m.initialsLbl.color = neutral50
    if m.circleBg <> invalid then m.circleBg.blendColor = avatarBg
    if m.progressTrack <> invalid then m.progressTrack.blendColor = neutral50
end sub

sub OnRunningChanged()
    if m.top.running = true then
        StartMotion()
    else
        StopMotion()
    end if
end sub

sub StartMotion()
    m.arcFrame = 0
    m.statusIndex = 0
    ApplyArcFrame()
    ApplyStatusText()
    if m.contentHost <> invalid then m.contentHost.opacity = 0.0
    if m.fadeIn <> invalid then m.fadeIn.control = "start"
    if m.arcTimer <> invalid then m.arcTimer.control = "start"
    if m.statusTimer <> invalid then m.statusTimer.control = "start"
end sub

sub StopMotion()
    if m.fadeIn <> invalid then m.fadeIn.control = "stop"
    if m.arcTimer <> invalid then m.arcTimer.control = "stop"
    if m.statusTimer <> invalid then m.statusTimer.control = "stop"
    if m.contentHost <> invalid then m.contentHost.opacity = 0.0
end sub

sub OnArcTick()
    m.arcFrame = m.arcFrame + 2
    if m.arcFrame >= ProfileArcFrameCount() then m.arcFrame = 0
    ApplyArcFrame()
end sub

sub OnStatusTick()
    if m.statusMessages = invalid or m.statusMessages.Count() = 0 then return
    m.statusIndex = m.statusIndex + 1
    if m.statusIndex >= m.statusMessages.Count() then m.statusIndex = 0
    ApplyStatusText()
end sub

sub ApplyArcFrame()
    if m.progressArc = invalid then return
    m.progressArc.uri = ProfileArcFrameUriForIndex(m.arcFrame)
end sub

sub ApplyStatusText()
    if m.statusLbl = invalid then return
    if m.statusMessages = invalid or m.statusMessages.Count() = 0 then return
    m.statusLbl.text = m.statusMessages[m.statusIndex]
end sub
