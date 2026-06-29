' ProfileFetchFlow.brs — profile list fetch with auth refresh retry.


' ── Fetch profiles ───────────────────────────────────────────────────────────

sub FetchProfiles()
    m.profileFetchRetriesLeft = m.PROFILE_FETCH_MAX_RETRIES
    m.profileFetchRefreshTried = false
    m.profileFetchAwaiting = false
    if m.profileFetchRetryTimer <> invalid then m.profileFetchRetryTimer.control = "stop"
    FireProfileFetch()
end sub


sub FireProfileFetch()
    if m.profileFetchAwaiting = true then return
    KillProfileTask(m.profilesTask)
    m.profilesTask = invalid
    path = Endpoints().PROFILE.GET_LOGIN_PROFILES
    m.profilesTask = ApiGet(path)
    m.profileFetchAwaiting = true
    m.profilesTask.observeField("apiResult", "OnProfilesResponse")
    StartHttpTask(m.profilesTask)
end sub


sub ScheduleProfileFetchRetry()
    if m.profileFetchRetryTimer = invalid then
        m.profileFetchRetryTimer = CreateObject("roSGNode", "Timer")
        m.profileFetchRetryTimer.duration = 0.75
        m.profileFetchRetryTimer.repeat = false
        m.top.appendChild(m.profileFetchRetryTimer)
        m.profileFetchRetryTimer.observeField("fire", "OnProfileFetchRetry")
    end if
    m.profileFetchRetryTimer.control = "stop"
    m.profileFetchRetryTimer.control = "start"
end sub


sub OnProfileFetchRetry()
    if m.top.dispose = true then return
    if IsOrphaned() then return
    if m.profileFetchAwaiting = true then return
    FireProfileFetch()
end sub


sub AttemptProfileFetchRefresh()
    if GetRefreshToken() = "" then
        print "[PROFILE_FETCH_DBG] refresh skipped (no refresh token)"
        ProfileFetchGiveUp()
        return
    end if
    m.profileFetchAwaiting = true
    ProfileSelectLogNode("PROFILE_FETCH", "refresh session", m.top)
    print "[PROFILE_FETCH_DBG] refresh start"
    KillProfileTask(m.refreshTask)
    m.refreshTask = ApiGet(Endpoints().LOGIN.REFRESH_TOKEN)
    m.refreshTask.observeField("apiResult", "OnProfileFetchRefreshResponse")
    StartHttpTask(m.refreshTask)
end sub


sub OnProfileFetchRefreshResponse()
    if m.top.dispose = true then return
    if IsOrphaned() then return
    if m.refreshTask = invalid then return
    m.profileFetchAwaiting = false
    api = m.refreshTask.apiResult
    if api = invalid then return
    http = -1
    if api.httpStatus <> invalid then http = api.httpStatus
    print "[PROFILE_FETCH_DBG] refresh response http="; http; " ok="; CwPerfBool(api.ok = true)

    if api.ok and ApplyRefreshTokens(api.result) then
        ProfileSelectLogNode("PROFILE_FETCH", "refresh ok -> retry list", m.top)
        print "[PROFILE_FETCH_DBG] refresh ok -> retry profiles"
        m.profileFetchRetriesLeft = m.PROFILE_FETCH_MAX_RETRIES
        FireProfileFetch()
        return
    end if

    ProfileSelectLogNode("PROFILE_FETCH", "refresh failed httpStatus=" + ProfileSelectFmt(api.httpStatus), m.top)
    print "[PROFILE_FETCH_DBG] refresh failed -> give up"
    ProfileFetchGiveUp()
end sub


sub ProfileFetchAbort()
    m.profileFetchAwaiting = false
    if m.profileFetchRetryTimer <> invalid then m.profileFetchRetryTimer.control = "stop"
    KillProfileTask(m.profilesTask)
    KillProfileTask(m.refreshTask)
    ShowLoading(false)
end sub

' React profile.tsx catch -> handleLogout: clear loading, then navigate login.

' React profile.tsx catch -> handleLogout: clear loading, then navigate login.
sub ProfileFetchGiveUp()
    if m.profileFetchGivingUp = true then return
    m.profileFetchGivingUp = true
    ProfileFetchAbort()
    ProfileSelectLogNode("PROFILE_FETCH", "give up -> login", m.top)
    print "[PROFILE_FETCH_DBG] give up hasRefresh="; CwPerfBool(GetRefreshToken() <> "")
    if GetRefreshToken() = "" then
        m.profileLoginDeferLogout = false
        m.profileLoginShowToast = false
        ScheduleProfileLoginDefer()
        return
    end if
    ShowProfileError(MsgFailedLoadProfiles())
    m.profileLoginDeferLogout = true
    ScheduleProfileLoginDefer()
end sub


sub ScheduleProfileLoginDefer()
    if m.profileLoginDeferTimer = invalid then return
    m.profileLoginDeferTimer.control = "stop"
    m.profileLoginDeferTimer.control = "start"
end sub


sub ScheduleProfileNavigateLogin(showToast as boolean)
    m.profileLoginShowToast = showToast
    m.profileLoginDeferLogout = false
    ScheduleProfileLoginDefer()
end sub


sub OnProfileLoginDefer()
    if m.top.dispose = true then return
    if m.profileLoginDeferTimer <> invalid then m.profileLoginDeferTimer.control = "stop"
    if m.profileLoginDeferLogout = true then
        m.profileLoginDeferLogout = false
        print "[PROFILE_FETCH_DBG] deferred logout session API"
        DoLogout()
        return
    end if
    if m.vm = invalid then m.vm = FindViewManager(m.top)
    print "[PROFILE_FETCH_DBG] deferred navigate login"
    LogoutToLogin(m.profileLoginShowToast = true)
end sub

