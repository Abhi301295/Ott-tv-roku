sub init()
    m.contentHost = m.top.findNode("contentHost")
    m.avatarImg = m.top.findNode("avatarImg")
    m.initialsLbl = m.top.findNode("initialsLbl")
    m.circleBg = m.top.findNode("circleBg")
    m.progressTrack = m.top.findNode("progressTrack")
    m.loaderArc = m.top.findNode("loaderArc")
    m.welcomeLbl = m.top.findNode("welcomeLbl")
    m.statusLbl = m.top.findNode("statusLbl")
    m.fadeIn = m.top.findNode("fadeIn")
    m.spinnerAnim = m.top.findNode("spinnerAnim")

    m.motionActive = false

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
    if m.loaderArc <> invalid then m.loaderArc.blendColor = primary
end sub

sub OnRunningChanged()
    if m.top.running = true then
        StartMotion(m.motionActive <> true)
    else
        StopMotion()
    end if
end sub

' coldStart=false keeps the spinner Animation running across profile → Home navigate.
sub StartMotion(coldStart as boolean)
    if coldStart = false and m.motionActive = true then return
    if coldStart = false and m.spinnerAnim <> invalid and m.spinnerAnim.state = "running" then
        m.motionActive = true
        return
    end if

    m.motionActive = true
    ApplyStatusLabel()
    if m.contentHost <> invalid then m.contentHost.opacity = 0.0
    if m.fadeIn <> invalid then m.fadeIn.control = "start"
    if m.spinnerAnim <> invalid then m.spinnerAnim.control = "start"
end sub

sub StopMotion()
    m.motionActive = false
    if m.fadeIn <> invalid then m.fadeIn.control = "stop"
    if m.spinnerAnim <> invalid then m.spinnerAnim.control = "stop"
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

sub OnStatusTextChanged()
    ApplyStatusLabel()
end sub

sub ApplyStatusLabel()
    if m.statusLbl = invalid then return
    txt = m.top.statusText
    if txt = invalid then txt = ""
    if m.statusLbl.text <> txt then m.statusLbl.text = txt
end sub
