' ProfileSelectFlow.brs — profile select API + home catalog prefetch navigate.


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
        profileName = ""
        if m.selectedProfile <> invalid and m.selectedProfile.name <> invalid then profileName = m.selectedProfile.name
        PersistSelectedProfile(profileId, avatar, profileName)
        ProfileSelectLogNode("PROFILE_SELECT", "select ok -> prefetch + navigate", m.top)
        BeginHomePrefetch(profileId, avatar)
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


' ── Home catalog prefetch ─────────────────────────────────────────────────────
' React navigates to Home as soon as select-profile succeeds (selecting shimmer ends).
' CW + /contents/home start on ViewManager so they survive Profile dispose and fill
' HomeBootCache while Home mounts (Home waits briefly if still in flight).

sub BeginHomePrefetch(profileId as string, avatar as string)
    m.pendingNavigateProfileId = profileId
    m.pendingNavigateAvatar = avatar
    m.prefetching = true
    if m.vm <> invalid then
        m.vm.callFunc("StartHomePrefetch", profileId)
    else
        HomeBootCacheClear()
        HomeBootCacheBegin(profileId)
    end if
    FinishPrefetchNavigate()
end sub


sub FinishPrefetchNavigate()
    if not m.prefetching then return
    profileId = m.pendingNavigateProfileId
    avatar = m.pendingNavigateAvatar
    m.prefetching = false
    m.selecting = false
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    SetValueByKey(SK_SelectedItem(), "Home", "app")
    if m.vm <> invalid then
        m.vm.callFunc("NavigateReplace", RouteHome(), { selectProfileId: profileId, selectAvatar: avatar })
    else
        HomeBootCacheClear()
        ShowAlert(m.top, 2, MsgFailedSelectProfile())
        ResetAutoSelect()
        ApplyProfileFocus()
    end if
end sub


sub CancelHomePrefetch()
    m.prefetching = false
    m.selecting = false
    if m.vm <> invalid then m.vm.callFunc("StopHomePrefetch", invalid)
    HomeBootCacheClear()
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    ApplyProfileSelectingState()
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
        if av.hasField("selectingState") and av.selectingState <> active then
            av.selectingState = active
        end if
        if active then
            if av.hasField("hintText") and av.hintText <> "" then av.hintText = ""
            if av.hasField("progress") and av.progress <> 0.0 then av.progress = 0.0
            RaiseSelectingAvatarZ(av)
        end if
    end for
end sub


' Later profile rows paint above earlier siblings; lift the selecting row so its glow halo
' is not covered (React netComponent focused chrome uses elevated z-index).
' Only move when needed — removeChild+appendChild resets Skeleton Animation and freezes shimmer.
sub RaiseSelectingAvatarZ(av as object)
    if av = invalid or m.profilesContainer = invalid then return
    parent = av.getParent()
    if parent = invalid then return
    if not parent.isSameNode(m.profilesContainer) then return
    n = parent.getChildCount()
    if n < 1 then return
    last = parent.getChild(n - 1)
    if last <> invalid and last.isSameNode(av) then return
    parent.removeChild(av)
    parent.appendChild(av)
end sub
