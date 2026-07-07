' ProfileSelectFlow.brs — profile select API then navigate home (parity profile.tsx).


' ── Selection ────────────────────────────────────────────────────────────────

sub SelectProfile(profile as object)
    if profile = invalid then return
    m.selectedProfile = profile
    if ProfileNeedsPin(profile) then
        OpenOtp()
    else
        DoSelectProfile(profile._id)
    end if
end sub


sub DoSelectProfile(profileId as string)
    if m.selecting then
        ProfileSelectLogNode("PROFILE_SELECT", "skipped (already selecting)", m.top)
        return
    end if
    if IsOrphaned() then
        ProfileSelectLogNode("PROFILE_SELECT", "skipped (orphaned) id=" + profileId, m.top)
        return
    end if
    m.selecting = true
    StopAutoSelect()
    ApplyProfileSelectingState()
    m.pendingNavigateProfileId = profileId
    m.pendingNavigateAvatar = ""
    if m.selectedProfile <> invalid and m.selectedProfile.avatar <> invalid then
        m.pendingNavigateAvatar = m.selectedProfile.avatar
    end if
    ProfileSelectLogNode("PROFILE_SELECT", "api select id=" + profileId, m.top)
    WarmHttpConnection(SelectProfilePath())
    KillProfileTask(m.selectTask)
    m.selectTask = ApiPost(SelectProfilePath(), SelectProfilePayload(profileId))
    m.selectTask.observeField("apiResult", "OnProfileSelectResponse")
    StartHttpTask(m.selectTask)
end sub


sub OnProfileSelectResponse()
    if m.top.dispose = true then return
    if not m.selecting then return
    if m.selectTask = invalid then return
    api = m.selectTask.apiResult
    if api = invalid then return

    profileId = m.pendingNavigateProfileId
    avatar = m.pendingNavigateAvatar
    ok = false
    if api.ok and ApplySelectProfileTokens(api.result) then ok = true
    if not ok and api.httpStatus = 404 and (GetRefreshToken() <> "" or GetAccessToken() <> "") then
        ProfileSelectLogNode("PROFILE_SELECT", "select 404 ignored (session valid)", m.top)
        ok = true
    end if

    if ok then
        PersistSelectedProfile(profileId, avatar)
        ProfileSelectLogNode("PROFILE_SELECT", "select ok -> home", m.top)
        NavigateToHomeAfterSelect(profileId, avatar)
        return
    end if

    m.selecting = false
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    ApplyProfileSelectingState()
    ProfileSelectLogNode("PROFILE_SELECT_FAIL", "httpStatus=" + ProfileSelectFmt(api.httpStatus), m.top)
    ShowAlert(m.top, 2, MsgFailedSelectProfile())
    ResetAutoSelect()
    ApplyProfileFocus()
end sub


' React userProfile.tsx loading branch — SkeletonBox on the selected row only.
sub ApplyProfileSelectingState()
    selId = ""
    if m.selecting = true and m.selectedProfile <> invalid and m.selectedProfile._id <> invalid then
        selId = m.selectedProfile._id
    end if
    if m.avatars = invalid then return
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        active = false
        if selId <> "" and i < m.profiles.Count() then
            if m.profiles[i]._id = selId then active = true
        end if
        if av.hasField("selectingState") then av.selectingState = active
        if active then
            if av.hasField("hintText") then av.hintText = ""
            if av.hasField("progress") then av.progress = 0.0
            RaiseSelectingAvatarZ(av)
        end if
    end for
end sub


' Later profile rows paint above earlier siblings; lift the selecting row so its glow halo
' is not covered (React netComponent focused chrome uses elevated z-index).
sub RaiseSelectingAvatarZ(av as object)
    if av = invalid or m.profilesContainer = invalid then return
    parent = av.getParent()
    if parent = invalid then return
    if not parent.isSameNode(m.profilesContainer) then return
    parent.removeChild(av)
    parent.appendChild(av)
end sub


' profile.tsx selectProfile → navigate(ROUTES.HOME, { replace: true }); home loader owns CW/hero.
sub NavigateToHomeAfterSelect(profileId as string, avatar as string)
    m.selecting = false
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    ProfileTransitionHide(m.vm)
    SetValueByKey(SK_SelectedItem(), "Home", "app")
    if m.vm <> invalid then
        m.vm.callFunc("NavigateReplace", RouteHome(), { selectProfileId: profileId, selectAvatar: avatar })
    else
        ShowAlert(m.top, 2, MsgFailedSelectProfile())
        ResetAutoSelect()
        ApplyProfileFocus()
    end if
end sub
