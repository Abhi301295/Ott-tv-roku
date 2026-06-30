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
    ShowSelectingOverlay(true)
    ApplyProfileFocus()
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
        ProfileSelectLogNode("PROFILE_SELECT", "select ok -> prefetch home", m.top)
        BeginHomePrefetch(profileId, avatar)
        return
    end if

    m.selecting = false
    ShowSelectingOverlay(false)
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    ProfileSelectLogNode("PROFILE_SELECT_FAIL", "httpStatus=" + ProfileSelectFmt(api.httpStatus), m.top)
    ShowAlert(m.top, 2, MsgFailedSelectProfile())
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

' ── Home catalog prefetch (welcome overlay) ───────────────────────────────────
' Keep: shell overlay + CW/categories prefetch into boot cache + status phases
' while APIs are in flight. Navigate as soon as both responses land (no artificial
' dwell). Home dismisses the overlay when row 0 paintedReady (CW row when applicable).

sub BeginHomePrefetch(profileId as string, avatar as string)
    HomeBootCacheClear()
    m.prefetching = true
    m.prefetchCatalogHandled = false
    m.prefetchCwRetriesLeft = HC_PrefetchMaxRetries()
    m.prefetchCatRetriesLeft = HC_PrefetchMaxRetries()
    if m.prefetchClock = invalid then m.prefetchClock = CreateObject("roTimespan")
    m.prefetchStartMs = m.prefetchClock.TotalMilliseconds()
    m.pendingNavigateProfileId = profileId
    m.pendingNavigateAvatar = avatar
    HomeBootCacheBegin(profileId)
    ' Phase 0 already set by ProfileTransitionShow; advance to preparing home.
    AdvanceWelcomeStatus(m.vm, 1)
    print "[PREFETCH_DBG] start profileId="; profileId; " max_ms="; HC_PrefetchMaxMs(); " retries="; HC_PrefetchMaxRetries()
    StartHomePrefetchFetches()
    ArmPrefetchGate()
end sub


sub TryCompletePrefetchCatalog()
    if not m.prefetching then return
    if not HomeBootCacheIsReady() then return
    if m.prefetchCatalogHandled = true then return
    m.prefetchCatalogHandled = true
    if m.prefetchGateTimer <> invalid then m.prefetchGateTimer.control = "stop"
    AdvanceWelcomeStatus(m.vm, 2)
    FinishPrefetchNavigate()
end sub


sub StartHomePrefetchFetches()
    StartPrefetchCwFetch()
    StartPrefetchCatFetch()
end sub


sub StartPrefetchCwFetch()
    if not m.prefetching then return
    KillProfileTask(m.prefetchCwTask)
    m.prefetchCwTask = invalid
    cwPath = Endpoints().HOME.CONTINUE_WATCHING
    print "[PREFETCH_DBG] cw_fetch outbound"
    m.prefetchCwTask = ApiGet(cwPath)
    m.prefetchCwTask.observeField("apiResult", "OnPrefetchCwResponse")
    StartHttpTask(m.prefetchCwTask)
end sub


sub StartPrefetchCatFetch()
    if not m.prefetching then return
    KillProfileTask(m.prefetchCatTask)
    m.prefetchCatTask = invalid
    catPath = Endpoints().HOME.CATEGORY_LIST
    print "[PREFETCH_DBG] home_fetch outbound"
    m.prefetchCatTask = ApiGet(catPath)
    m.prefetchCatTask.observeField("apiResult", "OnPrefetchCatResponse")
    StartHttpTask(m.prefetchCatTask)
end sub


sub SchedulePrefetchCwRetry()
    if m.prefetchCwRetryTimer = invalid then
        m.prefetchCwRetryTimer = CreateObject("roSGNode", "Timer")
        m.prefetchCwRetryTimer.duration = HC_PrefetchRetryDelaySec()
        m.prefetchCwRetryTimer.repeat = false
        m.top.appendChild(m.prefetchCwRetryTimer)
        m.prefetchCwRetryTimer.observeField("fire", "OnPrefetchCwRetry")
    end if
    m.prefetchCwRetryTimer.control = "stop"
    m.prefetchCwRetryTimer.control = "start"
end sub


sub SchedulePrefetchCatRetry()
    if m.prefetchCatRetryTimer = invalid then
        m.prefetchCatRetryTimer = CreateObject("roSGNode", "Timer")
        m.prefetchCatRetryTimer.duration = HC_PrefetchRetryDelaySec()
        m.prefetchCatRetryTimer.repeat = false
        m.top.appendChild(m.prefetchCatRetryTimer)
        m.prefetchCatRetryTimer.observeField("fire", "OnPrefetchCatRetry")
    end if
    m.prefetchCatRetryTimer.control = "stop"
    m.prefetchCatRetryTimer.control = "start"
end sub


sub OnPrefetchCwRetry()
    if not m.prefetching then return
    StartPrefetchCwFetch()
end sub


sub OnPrefetchCatRetry()
    if not m.prefetching then return
    StartPrefetchCatFetch()
end sub


sub PrefetchMarkCwDone(api as object)
    HomeBootCacheSetCw(api)
    TryCompletePrefetchCatalog()
end sub


sub PrefetchMarkCatDone(api as object)
    HomeBootCacheSetCategories(api)
    TryCompletePrefetchCatalog()
end sub


function PrefetchApiOk(api as object) as boolean
    if api = invalid then return false
    return api.ok = true
end function


sub OnPrefetchCwResponse()
    if m.top.dispose = true then return
    if not m.prefetching then return
    if m.prefetchCwTask = invalid then return
    api = m.prefetchCwTask.apiResult
    if api = invalid then return
    if PrefetchApiOk(api) then
        print "[PREFETCH_DBG] cw_response ok=true"
        PrefetchMarkCwDone(api)
        return
    end if
    if m.prefetchCwRetriesLeft > 0 then
        m.prefetchCwRetriesLeft = m.prefetchCwRetriesLeft - 1
        print "[PREFETCH_DBG] cw_response ok=false retry_left="; m.prefetchCwRetriesLeft
        SchedulePrefetchCwRetry()
        return
    end if
    print "[PREFETCH_DBG] cw_response ok=false retries_exhausted mark_done"
    PrefetchMarkCwDone(api)
end sub


sub OnPrefetchCatResponse()
    if m.top.dispose = true then return
    if not m.prefetching then return
    if m.prefetchCatTask = invalid then return
    api = m.prefetchCatTask.apiResult
    if api = invalid then return
    if PrefetchApiOk(api) then
        print "[PREFETCH_DBG] home_response ok=true"
        PrefetchMarkCatDone(api)
        return
    end if
    if m.prefetchCatRetriesLeft > 0 then
        m.prefetchCatRetriesLeft = m.prefetchCatRetriesLeft - 1
        print "[PREFETCH_DBG] home_response ok=false retry_left="; m.prefetchCatRetriesLeft
        SchedulePrefetchCatRetry()
        return
    end if
    print "[PREFETCH_DBG] home_response ok=false retries_exhausted mark_done"
    PrefetchMarkCatDone(api)
end sub


sub ArmPrefetchGate()
    if m.prefetchGateTimer = invalid then
        m.prefetchGateTimer = CreateObject("roSGNode", "Timer")
        m.prefetchGateTimer.duration = 0.1
        m.prefetchGateTimer.repeat = true
        m.top.appendChild(m.prefetchGateTimer)
        m.prefetchGateTimer.observeField("fire", "OnPrefetchGateTick")
    end if
    m.prefetchGateTimer.control = "stop"
    m.prefetchGateTimer.control = "start"
end sub


sub OnPrefetchGateTick()
    if not m.prefetching then return
    elapsed = PrefetchElapsedMs()
    if elapsed >= HC_PrefetchMaxMs() then
        print "[PREFETCH_DBG] gate_timeout elapsed_ms="; elapsed; " navigate_anyway=true"
        HomeBootCacheForceComplete()
        if m.prefetchCatalogHandled <> true then TryCompletePrefetchCatalog()
        if m.prefetchCatalogHandled <> true then FinishPrefetchNavigate()
        return
    end if
    if HomeBootCacheIsReady() then TryCompletePrefetchCatalog()
end sub


function PrefetchElapsedMs() as integer
    if m.prefetchClock = invalid or m.prefetchStartMs < 0 then return 0
    return m.prefetchClock.TotalMilliseconds() - m.prefetchStartMs
end function


sub FinishPrefetchNavigate()
    if not m.prefetching then return
    profileId = m.pendingNavigateProfileId
    avatar = m.pendingNavigateAvatar
    m.prefetching = false
    m.selecting = false
    if m.prefetchGateTimer <> invalid then m.prefetchGateTimer.control = "stop"
    if m.prefetchCwRetryTimer <> invalid then m.prefetchCwRetryTimer.control = "stop"
    if m.prefetchCatRetryTimer <> invalid then m.prefetchCatRetryTimer.control = "stop"
    KillProfileTask(m.prefetchCwTask)
    KillProfileTask(m.prefetchCatTask)
    m.prefetchCwTask = invalid
    m.prefetchCatTask = invalid
    m.prefetchClock = invalid
    m.prefetchStartMs = -1
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    print "[PREFETCH_DBG] navigate_home profileId="; profileId
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
    m.prefetchCatalogHandled = false
    if m.prefetchGateTimer <> invalid then m.prefetchGateTimer.control = "stop"
    if m.prefetchCwRetryTimer <> invalid then m.prefetchCwRetryTimer.control = "stop"
    if m.prefetchCatRetryTimer <> invalid then m.prefetchCatRetryTimer.control = "stop"
    KillProfileTask(m.prefetchCwTask)
    KillProfileTask(m.prefetchCatTask)
    m.prefetchClock = invalid
    m.prefetchStartMs = -1
    HomeBootCacheClear()
    print "[PREFETCH_DBG] cancelled return_to_profiles"
    ProfileTransitionHide(m.vm)
    ShowSelectingOverlay(false)
    m.pendingNavigateProfileId = ""
    m.pendingNavigateAvatar = ""
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

' ── Logout ───────────────────────────────────────────────────────────────────

