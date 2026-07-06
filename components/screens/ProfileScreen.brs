sub init()
    m.title = m.top.findNode("title")
    m.errorLabel = m.top.findNode("errorLabel")
    m.skeletonGroup = m.top.findNode("skeletonGroup")
    m.profilesScrollHost = m.top.findNode("profilesScrollHost")
    m.profilesViewport = m.top.findNode("profilesViewport")
    m.profilesContainer = m.top.findNode("profilesContainer")
    m.headerTextBackdrop = m.top.findNode("headerTextBackdrop")
    m.listContentPadY = ProfileListTopY()
    m.listScrollY = 0
    m.listScrollTarget = 0
    m.prevProfileIndex = -1
    m.LIST_SCROLL_ANIM_STEPS = 4
    m.listScrollAnimTimer = CreateObject("roSGNode", "Timer")
    m.listScrollAnimTimer.duration = 0.016
    m.listScrollAnimTimer.repeat = true
    m.top.appendChild(m.listScrollAnimTimer)
    m.listScrollAnimTimer.observeField("fire", "OnListScrollAnimTick")
    m.logoutBtn = m.top.findNode("logoutBtn")
    m.confirmPopup = m.top.findNode("confirmPopup")
    m.otpPopup = m.top.findNode("otpPopup")
    m.selectingOverlay = m.top.findNode("selectingOverlay")
    m.autoSelectTimer = m.top.findNode("autoSelectTimer")
    m.bg = m.top.findNode("bg")
    m.bgImage = m.top.findNode("bgImage")
    m.profileBgUri = "pkg:/images/ui/profile_default_bg_base.png"
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")
    m.profileHeaderChrome = m.top.findNode("profileHeaderChrome")

    m.profiles = []
    m.avatars = []
    m.profilesLoaded = false   ' the auto-select loop must not run until profiles load
    m.focusArea = "profiles"   ' "profiles" | "logout"
    m.profileIndex = 0
    m.selectedProfile = invalid
    m.popup = ""               ' "" | "confirm" | "otp"
    m.selecting = false
    m.prefetching = false
    m.prefetchCwTask = invalid
    m.prefetchCatTask = invalid
    m.prefetchClock = invalid
    m.prefetchStartMs = -1
    m.prefetchCatalogHandled = false
    m.prefetchCwRetriesLeft = 0
    m.prefetchCatRetriesLeft = 0
    m.prefetchCwRetryTimer = invalid
    m.prefetchCatRetryTimer = invalid
    m.loggingOut = false
    m.AUTO_TOTAL_MS = 15000      ' progress ring reaches 100% at 15s (parity with React)
    m.AUTO_SELECT_MS = 15500     ' auto-select fires after 15s + a 500ms buffer
    '
    ' Auto-select model (single source of truth):
    '   • m.autoArmedIndex — the profile index the countdown is running for, or -1 when
    '     idle. Every navigation re-arms it from scratch; nothing else can select.
    '   • m.autoStartMs    — the monotonic clock time the window began. Elapsed is always
    '     derived as (clock now - start), so timing tracks true wall-time and never drifts
    '     with the Timer's irregular firing rate on the simulator. We read TotalMilliseconds
    '     directly and never call Mark() (unreliable on the simulator).
    m.autoClock = CreateObject("roTimespan")
    m.autoStartMs = 0
    m.autoArmedIndex = -1
    m.PROFILE_FETCH_MAX_RETRIES = 3
    m.profileFetchRetriesLeft = 0
    m.profileFetchRefreshTried = false
    m.profileFetchAwaiting = false
    m.profileFetchGivingUp = false
    m.profileLoginShowToast = false
    m.profileLoginDeferLogout = false

    m.title.text = CopyChooseProfile()
    m.logoutBtn.label = CopyLogout()

    LoadProfileTokens()
    m.uiSpec = ProfileUiSpec()
    m.useSquareAvatars = ProfileUsesSquareAvatars()
    ApplyProfileLayoutFromSpec()
    ApplyProfileSkeletonLayout()
    ApplyProfileColors()
    ApplyProfileArcColors()
    ApplyProfileBranding()

    m.vm = FindViewManager(m.top)

    ' Theme/branding can resolve AFTER this screen mounts (the business-config fetch
    ' lands a moment after the fast boot/fallback theme). Re-apply colors and branding
    ' whenever the resolved config updates so the logo + background always appear,
    ' regardless of load ordering.
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    m.top.observeField("keyEvent", "OnKey")
    m.autoSelectTimer.observeField("fire", "OnAutoTick")
    m.confirmPopup.observeField("action", "OnConfirmAction")
    m.otpPopup.observeField("submitted", "OnOtpSubmitted")
    m.otpPopup.observeField("action", "OnOtpAction")
    if m.vm <> invalid then m.vm.observeField("overlayDismiss", "OnOverlayDismiss")

    m.profileLoginDeferTimer = CreateObject("roSGNode", "Timer")
    m.profileLoginDeferTimer.duration = 0.02
    m.profileLoginDeferTimer.repeat = false
    m.top.appendChild(m.profileLoginDeferTimer)
    m.profileLoginDeferTimer.observeField("fire", "OnProfileLoginDefer")

    ShowLoading(true)
    FetchProfiles()

    ' Pre-open keep-alive on the pool (cheap profiles/list GET per worker) while the
    ' user picks a profile — never warm home/CW here (those are real prefetch fetches).
    WarmHttpPool()
    ProfileSelectLog("PROFILE_INIT", "mounted")
end sub

' Tear down timers/tasks when ViewManager removes this screen (prevents orphaned
' auto-select ticks and late apiResult handlers after logout/navigation).

' Tear down timers/tasks when ViewManager removes this screen (prevents orphaned
' auto-select ticks and late apiResult handlers after logout/navigation).
sub OnDispose()
    if not m.top.dispose then return
    ProfileSelectLogNode("PROFILE_DISPOSE", "stopping timers + tasks", m.top)
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "stop"
    KillProfileTask(m.profilesTask)
    KillProfileTask(m.logoutTask)
    KillProfileTask(m.verifyTask)
    KillProfileTask(m.refreshTask)
    KillProfileTask(m.selectTask)
    KillProfileTask(m.prefetchCwTask)
    KillProfileTask(m.prefetchCatTask)
    if m.prefetchGateTimer <> invalid then m.prefetchGateTimer.control = "stop"
    if m.prefetchCwRetryTimer <> invalid then m.prefetchCwRetryTimer.control = "stop"
    if m.prefetchCatRetryTimer <> invalid then m.prefetchCatRetryTimer.control = "stop"
    m.prefetchCatalogHandled = false
    if m.profileFetchRetryTimer <> invalid then m.profileFetchRetryTimer.control = "stop"
    if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
    m.profilesTask = invalid
    m.selectTask = invalid
    m.logoutTask = invalid
    m.verifyTask = invalid
    m.refreshTask = invalid
    m.selecting = false
    m.prefetching = false
    m.loggingOut = false
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
end sub


sub KillProfileTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

' ── Theme ────────────────────────────────────────────────────────────────────


' React userProfile.tsx branches on HEADER_STYLE === NETFLIX vs SIDEBAR (cases 4/6).
function ProfileUsesSquareAvatars() as boolean
    return ThemeIsSidebarHeader()
end function


function ProfileRowPitch() as integer
    if ProfileUsesSquareAvatars() then return ProfileUiRowPitch()
    return 210
end function


' Cumulative row layout — each row gets the height of its scaled card + name (+ hint).
sub LayoutProfileRows()
    ReflowProfileRows()
    FollowProfileListScroll()
end sub


sub ReflowProfileRows()
    if m.avatars = invalid or m.avatars.Count() = 0 then return

    ' All header styles share the same list top — first row never sits under logo/title.
    padY = ProfileListTopY()
    m.listContentPadY = padY
    gap = 0
    if m.useSquareAvatars = true and m.uiSpec <> invalid then gap = m.uiSpec.rowGap

    y = padY
    m.rowTops = []
    for i = 0 to m.avatars.Count() - 1
        m.rowTops.Push(y)
        m.avatars[i].translation = [0, y]
        h = ProfileAvatarRowHeight(i)
        y = y + h
        if i < m.avatars.Count() - 1 and gap > 0 then y = y + gap
    end for
    m.listContentHeight = y
end sub


function ProfileAvatarRowHeight(index as integer) as integer
    if index < 0 or index >= m.avatars.Count() then return ProfileRowPitch()
    if m.useSquareAvatars <> true then return ProfileRowPitch()
    av = m.avatars[index]
    if av <> invalid and av.hasField("layoutHeight") and av.layoutHeight > 0 then
        return av.layoutHeight
    end if
    focused = (m.focusArea = "profiles" and index = m.profileIndex)
    showHint = false
    if focused and av <> invalid and av.hasField("hintText") then
        txt = av.hintText
        showHint = (txt <> invalid and txt <> "")
    end if
    return ProfileSquareRowContentHeight(focused, showHint)
end function


sub OnAvatarLayoutChanged(event as object)
    if m.top.dispose = true then return
    if m.useSquareAvatars <> true then return
    ReflowProfileRows()
    FollowProfileListScroll()
end sub

sub OnBusinessResolved()
    LoadProfileTokens()
    m.uiSpec = ProfileUiSpec()
    m.useSquareAvatars = ProfileUsesSquareAvatars()
    ApplyProfileLayoutFromSpec()
    ApplyProfileSkeletonLayout()
    ApplyProfileColors()
    ApplyProfileArcColors()
    ApplySquareAvatarColors()
    ApplyProfileBranding()
    ApplyProfileFocus()
end sub


sub EnsureProfileArcBakeTask()
    if m.profileArcBakeTask <> invalid then return
    m.profileArcBakeTask = CreateObject("roSGNode", "ProfileArcBakeTask")
    m.profileArcBakeTask.id = "profileArcBakeTask"
    m.top.appendChild(m.profileArcBakeTask)
    m.profileArcBakeTask.observeField("done", "OnProfileArcBakeDone")
end sub


sub OnProfileArcBakeDone()
    if m.profileArcBakeTask = invalid then return
    if m.profileArcBakeTask.done <> true then return
    key = m.profileArcBakeTask.colorKey
    if key = invalid then key = ""
    if m.global <> invalid then
        ProfileArcEnsureGlobalFields(m.global)
        m.global.profileArcBakeKey = key
        m.global.profileArcBakeReady = true
    end if
end sub


' ── Loading / shimmer ──────────────────────────────────────────────────────────

sub ShowLoading(show as boolean)
    ApplyProfileSkeletonLayout()
    m.skeletonGroup.visible = show
    for each id in ["sk0a", "sk0b", "sk1a", "sk1b", "sk2a", "sk2b"]
        sk = m.top.findNode(id)
        if sk <> invalid then sk.running = show
    end for
    for each id in ["sk0aGlow", "sk0bGlow", "sk1aGlow", "sk1bGlow", "sk2aGlow", "sk2bGlow"]
        glow = m.top.findNode(id)
        if glow <> invalid then glow.visible = show
    end for
    if ProfileUsesSquareAvatars() then
        for each id in ["sk0bGlow", "sk1bGlow", "sk2bGlow"]
            glow = m.top.findNode(id)
            if glow <> invalid then glow.visible = false
        end for
    end if
    host = m.profilesScrollHost
    if host = invalid then host = m.profilesContainer
    if host <> invalid then host.visible = not show
    ApplyProfileFocusBackground()
end sub


sub BindSelectingOverlayProfile()
    if m.selectedProfile = invalid or m.vm = invalid then return
    p = m.selectedProfile
    nm = ""
    if p.name <> invalid then nm = p.name
    uri = ""
    if p.avatar <> invalid then uri = p.avatar
    ProfileTransitionShow(m.vm, nm, uri, ProfileInitials(nm), m.cPortalPrimary, m.cPortalSecondary, m.cPortalTertiary, m.cNeutral50, m.cAvatarBg)
end sub


sub ShowSelectingOverlay(show as boolean)
    if show then
        BindSelectingOverlayProfile()
    else
        ProfileTransitionHide(m.vm)
    end if
    ' Local overlay unused — shell overlay on ViewManager survives navigate to Home.
    if m.selectingOverlay <> invalid then
        m.selectingOverlay.running = false
        m.selectingOverlay.visible = false
    end if
    if m.profilesScrollHost <> invalid then m.profilesScrollHost.visible = not show
    if m.profileHeaderChrome <> invalid then m.profileHeaderChrome.visible = not show
    if m.logoutBtn <> invalid then
        if show then
            m.logoutBtn.visible = false
        else
            m.logoutBtn.visible = (GetRefreshToken() <> "")
        end if
    end if
end sub


sub ShowProfileError(msg as string)
    m.errorLabel.text = msg
    m.errorLabel.visible = (msg <> "")
end sub

' ── Fetch profiles ───────────────────────────────────────────────────────────


sub OnProfilesResponse(event as object)
    if m.top.dispose = true then return
    if IsOrphaned() then
        ProfileSelectLogNode("PROFILE_FETCH", "response ignored (orphaned)", m.top)
        return
    end if

    task = invalid
    if event <> invalid then task = event.getRoSGNode()
    if task = invalid then task = m.profilesTask
    if task = invalid then return
    if m.profilesTask <> invalid and not task.isSameNode(m.profilesTask) then return

    m.profileFetchAwaiting = false
    api = task.apiResult
    if api = invalid then return

    http = -1
    if api.httpStatus <> invalid then http = api.httpStatus
    print "[PROFILE_FETCH_DBG] profiles response http="; http; " ok="; CwPerfBool(api.ok = true); " refreshTried="; CwPerfBool(m.profileFetchRefreshTried = true)

    if not api.ok or api.result = invalid then
        if api.httpStatus = 401 and m.profileFetchRefreshTried = true then
            print "[PROFILE_FETCH_DBG] 401 after refresh -> give up"
            ProfileFetchGiveUp()
            return
        end if
        if api.httpStatus = 401 and m.profileFetchRefreshTried <> true then
            m.profileFetchRefreshTried = true
            print "[PROFILE_FETCH_DBG] 401 -> try refresh"
            AttemptProfileFetchRefresh()
            return
        end if
        if ProfileFetchRetriable(api.httpStatus) and m.profileFetchRetriesLeft > 0 then
            m.profileFetchRetriesLeft = m.profileFetchRetriesLeft - 1
            ProfileSelectLogNode("PROFILE_FETCH", "retry httpStatus=" + ProfileSelectFmt(api.httpStatus) + " left=" + ProfileSelectFmt(m.profileFetchRetriesLeft), m.top)
            print "[PROFILE_FETCH_DBG] transport retry left="; m.profileFetchRetriesLeft
            ScheduleProfileFetchRetry()
            return
        end if
        ProfileFetchGiveUp()
        return
    end if

    m.profileFetchRefreshTried = false
    ShowLoading(false)

    m.profiles = ExtractProfiles(api.result)
    m.profilesLoaded = true
    ProfileSelectLogNode("PROFILE_FETCH", "ok count=" + ProfileSelectFmt(m.profiles.Count()), m.top)
    SaveProfilesMeta(m.profiles)
    BuildAvatars()

    m.logoutBtn.visible = (GetRefreshToken() <> "")

    m.focusArea = "profiles"
    m.profileIndex = InitialFocusIndex()
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

' Focus the stored profile if present, else the first (parity with focusSelf logic).
