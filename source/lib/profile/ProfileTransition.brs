' Profile → Home welcome overlay — survives NavigateReplace; dismissed when Home row 0
' mediaReady (or paintedReady fallback). 15s safety timer in HomeScreen init.

function ProfileTransitionNode(vm as object) as object
    if vm = invalid then return invalid
    return vm.findNode("profileTransition")
end function

function ProfileTransitionActive() as boolean
    if m.global = invalid then return false
    if not m.global.hasField("profileTransitionActive") then return false
    return m.global.profileTransitionActive = true
end function

sub ProfileTransitionSetActive(active as boolean)
    if m.global = invalid then return
    if not m.global.hasField("profileTransitionActive") then
        m.global.addFields({ profileTransitionActive: active })
    else
        m.global.profileTransitionActive = active
    end if
end sub

sub ProfileTransitionShow(vm as object, name as string, uri as string, initials as string, portalPrimary as string, portalSecondary as string, portalTertiary as string, neutral50 as string, avatarBg as string)
    node = ProfileTransitionNode(vm)
    if node = invalid then return
    wasActive = ProfileTransitionActive()
    if name <> invalid then node.profileName = name
    if uri <> invalid then node.avatarUri = uri
    if initials <> invalid then node.initials = initials
    if portalPrimary <> invalid and portalPrimary <> "" then node.primaryColor = portalPrimary
    if portalSecondary <> invalid and portalSecondary <> "" then node.portalSecondary = portalSecondary
    if portalTertiary <> invalid and portalTertiary <> "" then node.portalTertiary = portalTertiary
    if neutral50 <> invalid and neutral50 <> "" then node.neutral50 = neutral50
    if avatarBg <> invalid and avatarBg <> "" then node.avatarBg = avatarBg
    ' Always reset status phases — a prior Home visit may have left the overlay on phase 3
    ' if first-row paint never happened (empty prefetch, etc.).
    WelcomeStatusPhaseReset()
    phases = CopyWelcomeStatusPhases()
    if phases <> invalid and phases.Count() > 0 then
        if m.global <> invalid then m.global.welcomeUxStatusPhase = 0
        node.statusText = phases[0]
    else
        node.statusText = ""
    end if
    node.callFunc("ClearStatusLabelFunc", invalid)
    ApplyStatusLabelOnNode(node)
    node.visible = true
    if not wasActive then node.running = true
    ProfileTransitionSetActive(true)
end sub

function WelcomeStatusPhaseCurrent() as integer
    if m.global = invalid then return -1
    if not m.global.hasField("welcomeUxStatusPhase") then return -1
    p = m.global.welcomeUxStatusPhase
    if p = invalid then return -1
    return p
end function

sub WelcomeStatusPhaseReset()
    if m.global = invalid then return
    if not m.global.hasField("welcomeUxStatusPhase") then
        m.global.addFields({ welcomeUxStatusPhase: -1 })
    else
        m.global.welcomeUxStatusPhase = -1
    end if
end sub

' Advance welcome status forward only — never repeat or go backwards.
sub AdvanceWelcomeStatus(vm as object, phaseIndex as integer)
    if vm = invalid then return
    phases = CopyWelcomeStatusPhases()
    if phases = invalid or phases.Count() = 0 then return
    maxIdx = phases.Count() - 1
    if phaseIndex < 0 then return
    if phaseIndex > maxIdx then phaseIndex = maxIdx

    current = WelcomeStatusPhaseCurrent()
    if phaseIndex <= current then return

    if m.global = invalid then return
    m.global.welcomeUxStatusPhase = phaseIndex
    ProfileTransitionUpdateStatus(vm, phases[phaseIndex])
end sub

sub ApplyStatusLabelOnNode(node as object)
    if node = invalid then return
    txt = node.statusText
    if txt = invalid then txt = ""
    lbl = node.findNode("statusLbl")
    if lbl <> invalid and lbl.text <> txt then lbl.text = txt
end sub

sub ProfileTransitionUpdateStatus(vm as object, status as string)
    if status = invalid or status = "" then return
    node = ProfileTransitionNode(vm)
    if node = invalid then return
    prev = ""
    if node.statusText <> invalid then prev = node.statusText
    if prev = status then return
    node.statusText = status
    ApplyStatusLabelOnNode(node)
end sub

sub ProfileTransitionHide(vm as object)
    node = ProfileTransitionNode(vm)
    if node = invalid then return
    if not ProfileTransitionActive() and node.visible <> true then return
    node.running = false
    node.visible = false
    node.statusText = ""
    node.callFunc("ClearStatusLabelFunc", invalid)
    WelcomeStatusPhaseReset()
    ProfileTransitionSetActive(false)
end sub
