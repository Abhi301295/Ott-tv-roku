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
            ' userProfile.tsx: unfocused text-neutral-400; focus applied in ApplyProfileFocus.
            av.nameColor = m.cNeutral400
            av.hintColor = m.cNeutral400
            av.observeField("layoutHeight", "OnAvatarLayoutChanged")
        else
            av.bgColor = m.cAvatarBg
            av.ringColor = m.cNeutral50
            av.nameColor = m.cNeutral50
            if av.hasField("showEditBadge") then av.showEditBadge = ProfileEditBadgeVisibleForRow(i)
            if av.hasField("editFocused") then av.editFocused = false
            if p.avatar <> invalid then av.avatarUri = p.avatar
        end if
        m.avatars.Push(av)
    end for
    ReflowProfileRows()
    ApplyProfileListScrollSnap()
    ApplyProfileArcColors()
end sub

' ── Focus ────────────────────────────────────────────────────────────────────

' Focus grid: each profile row has two columns — edit icon | profile.
' Only one cell is focused+scaled at a time.
'   Row nav (Up/Down): restore previous row's active column, scale the new row's same column.
'   Column nav (Left/Right): same row — snap scale to the other column (no row pop re-animation).
sub ApplyProfileFocus()
    prevIdx = -1
    if m.prevProfileIndex <> invalid then prevIdx = m.prevProfileIndex
    prevArea = "profiles"
    if m.prevFocusArea <> invalid and m.prevFocusArea <> "" then prevArea = m.prevFocusArea

    rowChanged = (m.profileIndex <> prevIdx)
    colChanged = false
    if not rowChanged then
        if (prevArea = "profiles" and m.focusArea = "edit") or (prevArea = "edit" and m.focusArea = "profiles") then
            colChanged = true
        end if
    end if

    print "[PROFILE_EDIT_DBG] ApplyProfileFocus area=" + m.focusArea + " idx=" + m.profileIndex.ToStr() + " rowNav=" + rowChanged.ToStr() + " colNav=" + colChanged.ToStr()
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        ' Profile column focused / Edit column focused — mutually exclusive.
        focused = (m.focusArea = "profiles" and i = m.profileIndex)
        editFocused = (m.focusArea = "edit" and i = m.profileIndex)

        if av.hasField("scaleSnap") then
            ' Column Left/Right on this row: snap profile scale; edit column style is instant.
            av.scaleSnap = (colChanged and i = m.profileIndex)
        end if
        if av.hasField("snapRest") then
            ' Row Up/Down: skipped rows snap to rest so only the new cell animates in.
            av.snapRest = (rowChanged and not focused and i <> prevIdx and i <> m.profileIndex)
        end if
        if focused then
            av.progress = AutoProgressFor(i)
        else
            av.progress = 0.0
        end if
        if m.useSquareAvatars = true then
            if focused then
                av.nameColor = m.cPrimary500
            else
                av.nameColor = m.cNeutral400
            end if
        end if
        ' Clear profile focus first when entering edit so the avatar ring/arc cannot linger.
        if focused then
            if av.hasField("editFocused") then av.editFocused = false
            av.focusedState = true
        else if editFocused then
            av.focusedState = false
            if av.hasField("editFocused") then av.editFocused = true
        else
            av.focusedState = false
            if av.hasField("editFocused") then av.editFocused = false
        end if
        if av.hasField("showEditBadge") then av.showEditBadge = ProfileEditBadgeVisibleForRow(i)
        if focused then
            av.hintText = FocusHint(i)
            ApplyProfileHintStyle(av, i, av.hintText)
        else
            av.hintText = ""
            if av.hasField("hintBold") then av.hintBold = false
        end if
    end for

    ' Logout button focus (bg-primary-600 when focused).
    if m.focusArea = "logout" then
        m.logoutBtn.bgColor = m.cPrimary600
    else
        m.logoutBtn.bgColor = m.cPrimary500
    end if
    m.logoutBtn.showShadow = false
    m.prevProfileIndex = m.profileIndex
    m.prevFocusArea = m.focusArea
    LayoutProfileRows()
    ApplyProfileFocusBackground()
    SyncAllAvatarFocusChrome()
end sub

' userProfile.tsx: EDIT_PROFILE_* is focusable whenever onEditProfile is provided (auth).
' Parental lock does not hide or block the left edit control.
function ProfileEditBadgeVisibleForRow(index as integer) as boolean
    if not ProfileEditBadgeDefaultVisible() then return false
    if GetAccessToken() = "" then return false
    if index < 0 or index >= m.profiles.Count() then return false
    return true
end function

sub SyncAllAvatarFocusChrome()
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        if av = invalid then continue for
        if av.hasField("selectingState") and av.selectingState = true then continue for
        av.callFunc("RefreshFocusChrome", invalid)
    end for
end sub

' Locked profiles show a PIN hint; auto-select countdown when the timer is armed.
function FocusHint(index as integer) as string
    p = m.profiles[index]
    if ProfileNeedsPin(p) then return CopyEnterPinHint()
    if m.autoArmedIndex = index then
        frac = AutoProgressFor(index)
        if frac >= 0 and frac < 1.0 then
            secs = Int((1.0 - frac) * 15 + 0.999)
            if secs < 1 then secs = 1
            return CopyAutoSelectingIn(secs)
        end if
    end if
    return ""
end function

sub ApplyProfileHintStyle(av as object, index as integer, hint as string)
    if av = invalid then return
    if ProfileNeedsPin(m.profiles[index]) then
        if m.useSquareAvatars = true then
            av.hintColor = m.cNeutral400
        else
            av.hintColor = m.cAmber400
        end if
        if av.hasField("hintBold") then av.hintBold = false
    else if hint <> "" then
        if m.useSquareAvatars = true then
            av.hintColor = m.cPrimary500
            if av.hasField("hintBold") then av.hintBold = true
        else
            av.hintColor = m.cNeutral50
            if av.hasField("hintBold") then av.hintBold = false
        end if
    else
        av.hintColor = m.cNeutral400
        if av.hasField("hintBold") then av.hintBold = false
    end if
end sub

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
    else if m.popup = "edit" then
        m.editProfilePopup.keyEvent = ev
        return
    end if

    if not ev.press then return
    if m.selecting or m.loggingOut then return

    key = ev.key
    if m.focusArea = "profiles" then
        HandleProfilesKey(key)
    else if m.focusArea = "edit" then
        HandleEditKey(key)
    else if m.focusArea = "logout" then
        HandleLogoutKey(key)
    end if
end sub


' Profile column keys. Up/Down = row nav (restore/scale profile cells). Left = column → edit.
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
        if key = "left" and ProfileEditBadgeVisibleForRow(m.profileIndex) then
            ' Column nav: edit scales, profile snaps to rest (same row).
            m.focusArea = "edit"
            StopAutoSelect()
            ApplyProfileFocus()
        end if
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

' Edit column keys. Up/Down = row nav among edit cells only (profiles never scale).
' Right = column → profile.
sub HandleEditKey(key as string)
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
        else if m.logoutBtn.visible then
            m.focusArea = "logout"
            changed = true
        end if
    else if key = "right" then
        ' Column nav: back to profile. Restart auto-select like React's focused effect so
        ' the white focus ring is replaced by the progress arc (same as normal profile focus).
        m.focusArea = "profiles"
        changed = true
    else if key = "OK" or key = "ok" then
        OpenEditProfile()
        return
    end if
    if changed then
        if m.focusArea = "profiles" then
            ResetAutoSelect()
        else
            StopAutoSelect()
        end if
        ApplyProfileFocus()
    end if
end sub


sub HandleLogoutKey(key as string)
    if key = "up" then
        if m.focusArea = "logout" and m.profiles.Count() > 0 then
            if ProfileEditBadgeVisibleForRow(m.profileIndex) then
                m.focusArea = "edit"
                StopAutoSelect()
            else
                m.focusArea = "profiles"
                ResetAutoSelect()
            end if
            ApplyProfileFocus()
        end if
    else if key = "OK" or key = "ok" then
        OpenConfirm()
    end if
end sub
