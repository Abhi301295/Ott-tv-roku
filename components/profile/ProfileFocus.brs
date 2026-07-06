' ProfileFocus.brs — avatar list build, focus ring, and key routing.


' Focus the stored profile if present, else the first (parity with focusSelf logic).
function InitialFocusIndex() as integer
    stored = GetProfileId()
    if stored <> "" then
        for i = 0 to m.profiles.Count() - 1
            if m.profiles[i]._id = stored then return i
        end for
    end if
    return 0
end function


sub BuildAvatars()
    m.listScrollY = 0
    ' Clear any previous avatars.
    while m.profilesContainer.getChildCount() > 0
        m.profilesContainer.removeChildIndex(0)
    end while
    m.avatars = []

    pitch = ProfileRowPitch()
    square = ProfileUsesSquareAvatars()
    compName = "ProfileAvatar"
    if square then compName = "ProfileAvatarSquare"

    for i = 0 to m.profiles.Count() - 1
        p = m.profiles[i]
        av = m.profilesContainer.createChild(compName)
        nm = ""
        if p.name <> invalid then nm = p.name
        av.profileName = nm
        av.initials = ProfileInitials(nm)
        av.parentalLock = (p.parentalLock = true)
        av.rowIndex = i

        if square then
            av.cardTopColor = m.cNeutral600
            av.cardBottomColor = m.cNeutral800
            av.cardBackingColor = m.cBg
            av.borderColor = m.cPrimary700
            av.nameColor = m.cNeutral50
            av.hintColor = m.cNeutral400
            av.observeField("layoutHeight", "OnAvatarLayoutChanged")
        else
            av.bgColor = m.cAvatarBg
            av.ringColor = m.cNeutral50
            av.nameColor = m.cNeutral50
            if p.avatar <> invalid then av.avatarUri = p.avatar
        end if
        m.avatars.Push(av)
    end for
    ReflowProfileRows()
    ApplyProfileListScrollSnap()
    ApplyProfileArcColors()
end sub

' ── Focus ────────────────────────────────────────────────────────────────────

sub ApplyProfileFocus()
    prevIdx = -1
    if m.prevProfileIndex <> invalid then prevIdx = m.prevProfileIndex
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        focused = (m.focusArea = "profiles" and i = m.profileIndex)
        if av.hasField("snapRest") then
            av.snapRest = (not focused and i <> prevIdx)
        end if
        if focused then
            av.hintText = FocusHint(i)
            if ProfileNeedsPin(m.profiles[i]) then
                av.hintColor = m.cAmber400
            else
                av.hintColor = m.cNeutral400
            end if
        else
            av.hintText = ""
        end if
        if focused then
            av.progress = AutoProgressFor(i)
        else
            av.progress = 0.0
        end if
        av.focusedState = focused
    end for

    ' Logout button focus (bg-primary-600 when focused).
    if m.focusArea = "logout" then
        m.logoutBtn.bgColor = m.cPrimary600
    else
        m.logoutBtn.bgColor = m.cPrimary500
    end if
    m.logoutBtn.showShadow = false
    m.prevProfileIndex = m.profileIndex
    LayoutProfileRows()
    ApplyProfileFocusBackground()
end sub

' Locked profiles show a PIN hint; square avatars also show auto-select countdown text.
function FocusHint(index as integer) as string
    p = m.profiles[index]
    if ProfileNeedsPin(p) then return CopyEnterPinHint()
    if m.useSquareAvatars = true and m.autoArmedIndex = index then
        frac = AutoProgressFor(index)
        if frac > 0 and frac < 1.0 then
            secs = Int((1.0 - frac) * 15 + 0.999)
            if secs < 1 then secs = 1
            return CopyAutoSelectingIn(secs)
        end if
    end if
    return ""
end function

' ── Key handling ─────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return

    ' Route keys to an open overlay first.
    if m.popup = "confirm" then
        m.confirmPopup.keyEvent = ev
        return
    else if m.popup = "otp" then
        m.otpPopup.keyEvent = ev
        return
    end if

    if not ev.press then return
    if m.selecting or m.loggingOut then return

    key = ev.key
    if m.focusArea = "profiles" then
        HandleProfilesKey(key)
    else if m.focusArea = "logout" then
        HandleLogoutKey(key)
    end if
end sub


sub HandleProfilesKey(key as string)
    changed = false
    if key = "up" then
        if m.profileIndex > 0 then
            m.profileIndex = m.profileIndex - 1
            changed = true
        end if
    else if key = "down" then
        if m.profileIndex < m.profiles.Count() - 1 then
            m.profileIndex = m.profileIndex + 1
            changed = true
        else if m.logoutBtn.visible and m.focusArea <> "logout" then
            m.focusArea = "logout"
            changed = true
        end if
    else if key = "left" or key = "right" then
        ' Single-column list — no horizontal move; do not reset auto-select.
        return
    else if key = "OK" or key = "ok" then
        if m.profiles.Count() > 0 then SelectProfile(m.profiles[m.profileIndex])
        return
    end if
    if changed then
        ResetAutoSelect()
        ApplyProfileFocus()
    end if
end sub


sub HandleLogoutKey(key as string)
    if key = "up" then
        if m.focusArea = "logout" and m.profiles.Count() > 0 then
            m.focusArea = "profiles"
            ResetAutoSelect()
            ApplyProfileFocus()
        end if
    else if key = "OK" or key = "ok" then
        OpenConfirm()
    end if
end sub
