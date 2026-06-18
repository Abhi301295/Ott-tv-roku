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
    m.LIST_SCROLL_ANIM_STEPS = 18
    m.listScrollAnimTimer = CreateObject("roSGNode", "Timer")
    m.listScrollAnimTimer.duration = 0.016
    m.listScrollAnimTimer.repeat = true
    m.top.appendChild(m.listScrollAnimTimer)
    m.listScrollAnimTimer.observeField("fire", "OnListScrollAnimTick")
    m.logoutBtn = m.top.findNode("logoutBtn")
    m.confirmPopup = m.top.findNode("confirmPopup")
    m.otpPopup = m.top.findNode("otpPopup")
    m.selectingOverlay = m.top.findNode("selectingOverlay")
    m.selectingLabel = m.top.findNode("selectingLabel")
    m.autoSelectTimer = m.top.findNode("autoSelectTimer")
    m.bgImage = m.top.findNode("bgImage")
    m.bgOverlay = m.top.findNode("bgOverlay")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")

    m.profiles = []
    m.avatars = []
    m.profilesLoaded = false   ' the auto-select loop must not run until profiles load
    m.focusArea = "profiles"   ' "profiles" | "logout"
    m.profileIndex = 0
    m.selectedProfile = invalid
    m.popup = ""               ' "" | "confirm" | "otp"
    m.selecting = false
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

    m.title.text = CopyChooseProfile()
    m.logoutBtn.label = CopyLogout()

    LoadProfileTokens()
    m.uiSpec = ProfileUiSpec()
    m.useSquareAvatars = ProfileUsesSquareAvatars()
    ApplyProfileLayoutFromSpec()
    ApplyProfileSkeletonLayout()
    ApplyProfileColors()
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

    ShowLoading(true)
    FetchProfiles()

    ' Pre-open keep-alive connections on the rest of the pool while the user picks a
    ' profile, so the home screen's burst of requests right after select are all warm.
    ' MUST use a Bearer path (same auth as select-profile). CHECK_UPDATE uses Basic auth
    ' and poisons the pooled connection — select-profile then 404s until app reload.
    WarmHttpConnections(Endpoints().PROFILE.GET_LOGIN_PROFILES)
    ProfileSelectLog("PROFILE_INIT", "mounted")
end sub

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
    if m.profileFetchRetryTimer <> invalid then m.profileFetchRetryTimer.control = "stop"
    if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
    m.profilesTask = invalid
    m.selectTask = invalid
    m.logoutTask = invalid
    m.verifyTask = invalid
    m.refreshTask = invalid
    m.selecting = false
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

sub LoadProfileTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    m.cPrimary500 = TC("primary-500", "#0b75e0")
    m.cPrimary600 = TC("primary-600", "#0760bb")
    m.cPrimary700 = TC("primary-700", "#04478b")
    m.cNeutral50 = TC("neutral-50", "#ffffff")
    m.cNeutral100 = TC("neutral-100", "#f8f8f8")
    m.cNeutral300 = TC("neutral-300", "#d6d6d6")
    m.cNeutral400 = TC("neutral-400", "#c8c8c8")
    m.cAmber400 = "0xf59e0bff"
    m.cNeutral500 = TC("neutral-500", "#e279ce")
    m.cNeutral600 = TC("neutral-600", "#3d3d3d")
    m.cNeutral800 = TC("neutral-800", "#121212")
    m.cNeutral700 = "0x404040ff"
    ' neutral-900 (tertiary/background) drives the themed dialog surfaces, matching
    ' React's bg-neutral-900 on the confirm/OTP popups.
    m.cNeutral900 = TC("neutral-900", "#0a0a0a")
    m.cBg = "0x141414ff"        ' dark backdrop (clean circular masking)
    m.cCardBg = "0x171717ff"
    ' Color behind the avatar corners; switches to a near-black scrim color when a
    ' background image is shown so the corner-mask circle keeps blending cleanly.
    m.cAvatarBg = m.cBg
end sub

function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

' React userProfile.tsx branches on HEADER_STYLE === NETFLIX vs SIDEBAR (cases 4/6).
function ProfileUsesSquareAvatars() as boolean
    return ThemeIsSidebarHeader()
end function

function ProfileRowPitch() as integer
    if ProfileUsesSquareAvatars() then return ProfileUiRowPitch()
    return 210
end function

sub ApplyProfileLayoutFromSpec()
    if m.uiSpec = invalid then m.uiSpec = ProfileUiSpec()
    titlePos = ProfileUiTitlePos()
    listPos = ProfileUiProfilesPos()
    listTopY = ProfileListTopY()
    if m.title <> invalid then
        m.title.translation = [titlePos.x, titlePos.y]
        titleFont = m.title.findNode("font")
        if titleFont <> invalid then titleFont.size = m.uiSpec.titleFont
    end if
    if m.errorLabel <> invalid then
        m.errorLabel.translation = [titlePos.x, titlePos.y + m.uiSpec.titleFont + 8]
    end if
    if m.profilesScrollHost <> invalid then
        m.profilesScrollHost.translation = [listPos.x, 0]
    end if
    if m.profilesViewport <> invalid then
        vw = ProfileListViewportWidth()
        vh = ProfileListViewportHeight()
        m.profilesViewport.maskSize = [vw, vh]
        m.profilesViewport.maskOffset = [0, listTopY]
    end if
    m.listContentPadY = listTopY
    if m.skeletonGroup <> invalid then
        m.skeletonGroup.translation = [listPos.x, listTopY]
    end if
    ApplyProfileHeaderBackdrop()
    ProfileUiLogScreen(titlePos.x, titlePos.y, listPos.x, listTopY, ProfileRowPitch())
end sub

sub ApplyProfileHeaderBackdrop()
    if m.headerTextBackdrop = invalid then return
    if m.uiSpec = invalid then m.uiSpec = ProfileUiSpec()
    s = m.uiSpec
    titlePos = ProfileUiTitlePos()
    padX = s.headerBackdropPadX
    padY = s.headerBackdropPadY
    topY = s.logoY - padY
    if topY < 0 then topY = 0
    bottomY = titlePos.y + s.titleFont + padY
    w = 900 + padX * 2
    m.headerTextBackdrop.translation = [titlePos.x - padX, topY]
    m.headerTextBackdrop.width = w
    m.headerTextBackdrop.height = bottomY - topY
    m.headerTextBackdrop.opacity = s.headerBackdropOpacity
end sub

sub ApplyProfileSkeletonLayout()
    pitch = ProfileRowPitch()
    square = ProfileUsesSquareAvatars()
    slots = [
        { a: "sk0a", b: "sk0b", y: 0 }
        { a: "sk1a", b: "sk1b", y: pitch }
        { a: "sk2a", b: "sk2b", y: pitch * 2 }
    ]
    for each slot in slots
        skA = m.top.findNode(slot.a)
        skB = m.top.findNode(slot.b)
        if skA <> invalid then skA.translation = [0, slot.y]
        if skB <> invalid then
            if square then
                skB.visible = false
                skB.running = false
            else
                skB.visible = true
                skB.translation = [170, slot.y + 66]
            end if
        end if
    end for
end sub

sub ApplyProfileColors()
    m.title.color = m.cNeutral50
    m.errorLabel.color = m.cPrimary500
    m.logoLabel.color = m.cPrimary500

    ' Skeleton shimmer = primary-700 base, primary-500 highlight (parity with SkeletonBox).
    for each id in ["sk0a", "sk0b", "sk1a", "sk1b", "sk2a", "sk2b"]
        sk = m.top.findNode(id)
        if sk <> invalid then
            sk.baseColor = m.cPrimary700
            sk.highlightColor = m.cPrimary500
        end if
    end for

    ' Logout button (bg-primary-500) — focus styling handled in ApplyProfileFocus.
    m.logoutBtn.bgColor = m.cPrimary500
    m.logoutBtn.textColor = m.cNeutral50
    m.logoutBtn.shadowColor = m.cPrimary500

    ' Inject colors into the overlays. Dialog surfaces follow the BE theme:
    ' card/button fills = neutral-900 (bg-neutral-900), borders = neutral-600/500.
    m.confirmPopup.cPrimary500 = m.cPrimary500
    m.confirmPopup.cPrimary600 = m.cPrimary600
    m.confirmPopup.cNeutral300 = m.cNeutral300
    m.confirmPopup.cNeutral500 = m.cNeutral500
    m.confirmPopup.cCardBg = m.cNeutral900
    m.confirmPopup.cCardBorder = m.cNeutral600

    m.otpPopup.cPrimary500 = m.cPrimary500
    m.otpPopup.cPrimary600 = m.cPrimary600
    m.otpPopup.cNeutral600 = m.cNeutral600
    m.otpPopup.cNeutral700 = m.cNeutral700
    m.otpPopup.cCardBg = m.cNeutral900

    ' Profile name inherits body/title light text (React: same tone as text-neutral-50 h1).
    for each av in m.avatars
        if av <> invalid then
            if av.hasField("nameColor") then av.nameColor = m.cNeutral50
            if av.hasField("hintColor") then av.hintColor = m.cNeutral400
        end if
    end for
end sub

' Cumulative row layout — each row gets the height of its scaled card + name (+ hint).
sub LayoutProfileRows()
    ReflowProfileRows()
    UpdateProfileListScrollTarget()
    AnimateProfileListScroll()
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

sub UpdateProfileListScrollTarget()
    if m.rowTops = invalid or m.rowTops.Count() = 0 then
        m.listScrollTarget = 0
        return
    end if
    if m.listScrollTarget = invalid then m.listScrollTarget = 0

    viewH = ProfileListViewportHeight()
    padY = ProfileListTopY()
    if m.listContentPadY <> invalid and m.listContentPadY > 0 then padY = m.listContentPadY
    target = m.listScrollY
    if target = invalid then target = 0

    if m.focusArea = "profiles" and m.profileIndex >= 0 and m.profileIndex < m.rowTops.Count() then
        idx = m.profileIndex
        rowTop = m.rowTops[idx]
        rowBottom = rowTop + ProfileAvatarRowHeight(idx)
        visTop = rowTop - target
        visBottom = rowBottom - target
        if visTop < padY then
            target = rowTop - padY
        else if visBottom > padY + viewH then
            target = rowBottom - padY - viewH
        end if
    end if

    contentH = m.listContentHeight
    if contentH = invalid then contentH = padY
    maxScroll = contentH - padY - viewH
    if maxScroll < 0 then maxScroll = 0
    if target > maxScroll then target = maxScroll
    if target < 0 then target = 0
    m.listScrollTarget = target
end sub

sub AnimateProfileListScroll()
    if m.profilesContainer = invalid then return
    if m.listScrollTarget = invalid then m.listScrollTarget = 0
    if m.listScrollY = invalid then m.listScrollY = 0

    delta = m.listScrollTarget - m.listScrollY
    if delta < 0 then delta = -delta
    if delta < 1 then
        m.listScrollY = m.listScrollTarget
        m.profilesContainer.translation = [0, -m.listScrollY]
        if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
        return
    end if

    m.listScrollAnimFrom = m.listScrollY
    m.listScrollAnimTo = m.listScrollTarget
    m.listScrollAnimStep = 0
    if m.listScrollAnimTimer <> invalid then
        m.listScrollAnimTimer.control = "stop"
        m.listScrollAnimTimer.control = "start"
    end if
end sub

sub OnListScrollAnimTick()
    if m.profilesContainer = invalid then return
    m.listScrollAnimStep = m.listScrollAnimStep + 1
    t = m.listScrollAnimStep / m.LIST_SCROLL_ANIM_STEPS
    if t > 1.0 then t = 1.0

    inv = 1.0 - t
    eased = 1.0 - (inv * inv * inv)
    y = m.listScrollAnimFrom + ((m.listScrollAnimTo - m.listScrollAnimFrom) * eased)
    m.listScrollY = y
    m.profilesContainer.translation = [0, -m.listScrollY]

    if t >= 1.0 and m.listScrollAnimTimer <> invalid then
        m.listScrollAnimTimer.control = "stop"
        m.listScrollY = m.listScrollTarget
        m.profilesContainer.translation = [0, -m.listScrollY]
    end if
end sub

sub ApplyProfileListScrollSnap()
    UpdateProfileListScrollTarget()
    if m.listScrollTarget = invalid then m.listScrollTarget = 0
    m.listScrollY = m.listScrollTarget
    if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
    if m.profilesContainer <> invalid then m.profilesContainer.translation = [0, -m.listScrollY]
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
    UpdateProfileListScrollTarget()
    SmoothProfileListScrollStep()
end sub

' Gentle scroll follow while a row grows/shrinks during focus scale animation.
sub SmoothProfileListScrollStep()
    if m.profilesContainer = invalid then return
    if m.listScrollTarget = invalid then m.listScrollTarget = 0
    if m.listScrollY = invalid then m.listScrollY = 0
    delta = m.listScrollTarget - m.listScrollY
    if delta > -0.5 and delta < 0.5 then
        m.listScrollY = m.listScrollTarget
    else
        m.listScrollY = m.listScrollY + (delta * 0.28)
    end if
    m.profilesContainer.translation = [0, -m.listScrollY]
end sub

' The resolved business config (theme tokens + branding) arrived/updated — re-apply
' so the dialog colors, logo and login background reflect the live theme.
sub OnBusinessResolved()
    LoadProfileTokens()
    m.uiSpec = ProfileUiSpec()
    m.useSquareAvatars = ProfileUsesSquareAvatars()
    ApplyProfileLayoutFromSpec()
    ApplyProfileSkeletonLayout()
    ApplyProfileColors()
    ApplySquareAvatarColors()
    ApplyProfileBranding()
    ApplyProfileFocus()
end sub

sub ApplySquareAvatarColors()
    if m.useSquareAvatars <> true then return
    for each av in m.avatars
        av.cardTopColor = m.cNeutral600
        av.cardBottomColor = m.cNeutral800
        av.cardBackingColor = m.cBg
        av.borderColor = m.cPrimary700
        av.nameColor = m.cNeutral50
        av.hintColor = m.cNeutral400
    end for
end sub

sub ApplyProfileBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return

    logoUrl = resolved.brandingLogo
    if logoUrl <> invalid and logoUrl <> "" then
        m.logoPoster.uri = logoUrl
        m.logoPoster.visible = true
        m.logoLabel.visible = false
    else if resolved.appName <> invalid and resolved.appName <> "" then
        m.logoLabel.text = resolved.appName
        m.logoLabel.visible = true
    end if

    url = resolved.loginBackgroundImage
    if url <> invalid and url <> "" then
        m.bgImage.uri = url
        m.bgImage.opacity = 1.0
        m.bgOverlay.opacity = 0.55
        ' Avatar corners now sit over the near-black scrim, not the solid page bg.
        m.cAvatarBg = "0x080a0cff"
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
    host = m.profilesScrollHost
    if host = invalid then host = m.profilesContainer
    if host <> invalid then host.visible = not show
end sub

sub ShowSelectingOverlay(show as boolean)
    if m.selectingOverlay <> invalid then m.selectingOverlay.visible = show
    if m.selectingLabel <> invalid then
        m.selectingLabel.text = CopySelecting()
        if show then m.selectingLabel.color = m.cPrimary500
    end if
    if m.logoutBtn <> invalid and show then m.logoutBtn.visible = false
end sub

sub ShowProfileError(msg as string)
    m.errorLabel.text = msg
    m.errorLabel.visible = (msg <> "")
end sub

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
        ProfileFetchGiveUp()
        return
    end if
    ProfileSelectLogNode("PROFILE_FETCH", "refresh session", m.top)
    KillProfileTask(m.refreshTask)
    m.refreshTask = ApiGet(Endpoints().LOGIN.REFRESH_TOKEN)
    m.refreshTask.observeField("apiResult", "OnProfileFetchRefreshResponse")
    StartHttpTask(m.refreshTask)
end sub

sub OnProfileFetchRefreshResponse()
    if m.top.dispose = true then return
    if IsOrphaned() then return
    if m.refreshTask = invalid then return
    api = m.refreshTask.apiResult
    if api = invalid then return
    if HandleSessionExpiry(m.top, api) then return

    if api.ok and ApplyRefreshTokens(api.result) then
        ProfileSelectLogNode("PROFILE_FETCH", "refresh ok -> retry list", m.top)
        m.profileFetchRetriesLeft = m.PROFILE_FETCH_MAX_RETRIES
        m.profileFetchAwaiting = false
        FireProfileFetch()
        return
    end if

    ProfileSelectLogNode("PROFILE_FETCH", "refresh failed httpStatus=" + ProfileSelectFmt(api.httpStatus), m.top)
    ProfileFetchGiveUp()
end sub

sub ProfileFetchGiveUp()
    ShowLoading(false)
    ProfileSelectLogNode("PROFILE_FETCH", "give up -> login", m.top)
    ShowProfileError(MsgFailedLoadProfiles())
    LogoutToLogin(false)
end sub

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

    if HandleSessionExpiry(m.top, api) then return

    if not api.ok or api.result = invalid then
        if api.httpStatus = 401 and m.profileFetchRefreshTried <> true then
            m.profileFetchRefreshTried = true
            AttemptProfileFetchRefresh()
            return
        end if
        if ProfileFetchRetriable(api.httpStatus) and m.profileFetchRetriesLeft > 0 then
            m.profileFetchRetriesLeft = m.profileFetchRetriesLeft - 1
            ProfileSelectLogNode("PROFILE_FETCH", "retry httpStatus=" + ProfileSelectFmt(api.httpStatus) + " left=" + ProfileSelectFmt(m.profileFetchRetriesLeft), m.top)
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
end sub

' ── Focus ────────────────────────────────────────────────────────────────────

sub ApplyProfileFocus()
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        focused = (m.focusArea = "profiles" and i = m.profileIndex)
        if focused then
            if m.selecting then
                av.hintText = CopySelecting()
                av.hintColor = m.cPrimary500
            else
                av.hintText = FocusHint(i)
                if ProfileNeedsPin(m.profiles[i]) then
                    av.hintColor = m.cAmber400
                else
                    av.hintColor = m.cNeutral400
                end if
            end if
        else
            av.hintText = ""
        end if
        ' Progress reflects the focused profile's auto-select elapsed; others reset.
        if focused then
            if m.selecting then
                av.progress = 1.0
            else
                av.progress = AutoProgressFor(i)
            end if
        else
            av.progress = 0.0
        end if
        av.focusedState = focused
    end for

    ShowSelectingOverlay(m.selecting)

    ' Logout button focus (bg-primary-600 when focused). Selection is shown by the
    ' fill change only — no drop shadow (kept as-is per the current correct look;
    ' the shared LoginTabButton's shadow is reserved for the login tabs).
    if m.focusArea = "logout" then
        m.logoutBtn.bgColor = m.cPrimary600
    else
        m.logoutBtn.bgColor = m.cPrimary500
    end if
    m.logoutBtn.showShadow = false
    LayoutProfileRows()
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

' ── Auto-select (15s on focus, non-locked) ───────────────────────────────────

' Re-arm the countdown for the currently focused profile, starting a fresh 15.5s
' window. Called on every navigation, so any focus change restarts timing from zero.
sub ResetAutoSelect()
    StopAutoSelect()

    if not m.profilesLoaded then return   ' do not start the loop before profiles load
    if m.focusArea <> "profiles" then return
    if m.profiles = invalid or m.profiles.Count() = 0 then return
    if m.profileIndex < 0 or m.profileIndex >= m.profiles.Count() then return
    if ProfileNeedsPin(m.profiles[m.profileIndex]) then return   ' locked profiles never auto-select

    m.autoArmedIndex = m.profileIndex
    if m.autoClock <> invalid then m.autoStartMs = m.autoClock.TotalMilliseconds()
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "start"
end sub

' Disarm and stop the countdown.
sub StopAutoSelect()
    m.autoArmedIndex = -1
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "stop"
end sub

' Wall-time elapsed (ms) since the current window started; 0 when idle.
function AutoElapsedMs() as integer
    if m.autoArmedIndex < 0 or m.autoClock = invalid then return 0
    elapsed = m.autoClock.TotalMilliseconds() - m.autoStartMs
    if elapsed < 0 then elapsed = 0
    return elapsed
end function

' Ring fill fraction (0.0–1.0) for the profile at index i; reaches 1.0 at AUTO_TOTAL_MS.
function AutoProgressFor(i as integer) as float
    if m.autoArmedIndex <> i then return 0.0
    frac = AutoElapsedMs() / m.AUTO_TOTAL_MS
    if frac > 1.0 then frac = 1.0
    return frac
end function

' True if this ProfileScreen is not the top screen in the ViewManager stack (i.e. a
' leftover instance that should no longer run its auto-select loop).
function IsOrphaned() as boolean
    if m.vm = invalid then return false
    host = m.vm.findNode("screenHost")
    if host = invalid then return false
    count = host.getChildCount()
    if count < 1 then return false
    active = host.getChild(count - 1)
    if active = invalid then return false
    return not active.isSameNode(m.top)
end function

sub OnAutoTick()
    if m.autoArmedIndex < 0 then return              ' not armed — nothing to do
    if not m.profilesLoaded then return

    ' Only the active (top-of-stack) screen runs the countdown; a backgrounded
    ' instance stops so it cannot auto-navigate.
    if IsOrphaned() then
        StopAutoSelect()
        return
    end if

    ' Pause (but keep timing) while an overlay/selection/logout is in progress.
    if m.popup <> "" or m.selecting or m.loggingOut then return
    if m.focusArea <> "profiles" then return
    if m.profiles = invalid or m.profiles.Count() = 0 then return

    ' Focus drifted from the armed profile without a reset — re-arm for the new one.
    if m.profileIndex <> m.autoArmedIndex then
        ResetAutoSelect()
        ApplyProfileFocus()
        return
    end if

    p = m.profiles[m.profileIndex]
    if ProfileNeedsPin(p) then return

    ' Drive the ring from real elapsed wall-time, then select once the window completes.
    if m.avatars <> invalid and m.avatars.Count() > m.profileIndex then
        m.avatars[m.profileIndex].progress = AutoProgressFor(m.profileIndex)
    end if

    if AutoElapsedMs() >= m.AUTO_SELECT_MS then
        StopAutoSelect()
        SelectProfile(p)
    end if
end sub

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
    WarmHttpConnections(SelectProfilePath())
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

    if HandleSessionExpiry(m.top, api) then
        m.selecting = false
        ShowSelectingOverlay(false)
        ApplyProfileFocus()
        return
    end if

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
        m.selecting = false
        ShowSelectingOverlay(false)
        m.pendingNavigateProfileId = ""
        m.pendingNavigateAvatar = ""
        ProfileSelectLogNode("PROFILE_SELECT", "select ok -> navigate Home", m.top)
        SetValueByKey(SK_SelectedItem(), "Home", "app")
        if m.vm <> invalid then
            m.vm.callFunc("NavigateReplace", RouteHome(), { selectProfileId: profileId, selectAvatar: avatar })
        else
            ProfileSelectLogNode("PROFILE_SELECT_FAIL", "vm invalid id=" + profileId, m.top)
            ShowAlert(m.top, 2, MsgFailedSelectProfile())
            ResetAutoSelect()
            ApplyProfileFocus()
        end if
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

' ── Logout ───────────────────────────────────────────────────────────────────

sub OpenConfirm()
    m.popup = "confirm"
    m.confirmPopup.isLoggingOut = false
    m.confirmPopup.visible = true
    SetOverlayOpen(true)
end sub

sub CloseConfirm()
    m.popup = ""
    m.confirmPopup.visible = false
    SetOverlayOpen(false)
    ' Give the focused profile a fresh 15s after dismissing the dialog.
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

sub OnConfirmAction()
    action = m.confirmPopup.action
    if action = "cancel" then
        CloseConfirm()
    else if action = "logout" then
        m.confirmPopup.isLoggingOut = true
        DoLogout()
    end if
end sub

sub DoLogout()
    if not HasActiveSession() then
        LogoutToLogin(false)
        return
    end if
    m.loggingOut = true
    path = Endpoints().LOGIN.LOGOUT_SESSION
    m.logoutTask = ApiDelete(path, {})
    m.logoutTask.observeField("apiResult", "OnLogoutResponse")
    StartHttpTask(m.logoutTask)
end sub

sub OnLogoutResponse()
    ' Logout always ends at the login screen (web clears + redirects on success;
    ' a failure leaves nothing useful to stay for).
    m.loggingOut = false
    LogoutToLogin(true)
end sub

' Clear the session and return to login. showToast => "Logged out successfully".
sub LogoutToLogin(showToast as boolean)
    ProfileSelectLogNode("PROFILE_LOGOUT", "clear storage showToast=" + ProfileSelectFmt(showToast), m.top)
    ClearStorage()
    SetOverlayOpen(false)
    if showToast then ShowAlert(m.top, 1, MsgLoggedOut())
    if m.vm <> invalid then m.vm.callFunc("NavigateClearAndReplace", RouteLogin(), {})
end sub

' ── OTP (parental lock) ──────────────────────────────────────────────────────

sub OpenOtp()
    m.popup = "otp"
    m.otpPopup.verifying = false
    m.otpPopup.resetPin = true
    m.otpPopup.visible = true
    SetOverlayOpen(true)
end sub

sub CloseOtp()
    m.popup = ""
    m.otpPopup.visible = false
    SetOverlayOpen(false)
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

sub OnOtpAction()
    if m.otpPopup.action = "close" and not m.otpPopup.verifying then CloseOtp()
end sub

sub OnOtpSubmitted()
    pin = m.otpPopup.submitted
    if pin = invalid or Len(pin) <> 6 then return
    if m.selectedProfile = invalid then return

    m.otpPopup.verifying = true
    m.verifyTask = ApiPost(VerifyPinPath(), VerifyPinPayload(m.selectedProfile._id, pin))
    m.verifyTask.observeField("apiResult", "OnVerifyResponse")
    StartHttpTask(m.verifyTask)
end sub

sub OnVerifyResponse()
    if m.verifyTask = invalid then return
    api = m.verifyTask.apiResult
    if api = invalid then return

    if HandleSessionExpiry(m.top, api) then return

    if IsPinVerified(api) then
        m.popup = ""
        m.otpPopup.visible = false
        SetOverlayOpen(false)
        DoSelectProfile(m.selectedProfile._id)
    else
        ShowAlert(m.top, 2, MsgInvalidPin())
        m.otpPopup.verifying = false
        m.otpPopup.resetPin = true
    end if
end sub

' ── Overlay back-handling (Back closes the open popup) ───────────────────────

sub SetOverlayOpen(open as boolean)
    if m.vm = invalid then return
    m.vm.overlayOpen = open
end sub

sub OnOverlayDismiss()
    if m.vm = invalid then return
    if m.vm.overlayDismiss <> true then return
    if m.popup = "confirm" then
        if not m.loggingOut then CloseConfirm()
    else if m.popup = "otp" then
        if not m.otpPopup.verifying then CloseOtp()
    end if
end sub

