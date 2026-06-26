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
    m.cNeutral600 = TC("neutral-600", "#3d3d3d")
    m.cNeutral700 = TC("neutral-700", "#404040")
    m.cNeutral800 = TC("neutral-800", "#121212")
    m.cAmber400 = TC("amber-400", "#f59e0b")
    m.cNeutral500 = TC("neutral-500", "#e279ce")
    ' neutral-900 (tertiary/background) drives the themed dialog surfaces, matching
    ' React's bg-neutral-900 on the confirm/OTP popups.
    m.cNeutral900 = TC("neutral-900", "#0a0a0a")
    m.cBg = m.cNeutral900
    m.cCardBg = m.cNeutral900
    ' Color behind the avatar corners; switches to a near-black scrim when the
    ' focus backdrop is visible so the corner-mask circle keeps blending cleanly.
    m.cAvatarBg = m.cBg
    LoadProfilePortalColors()
end sub

sub LoadProfilePortalColors()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    portal = ProfilePortalRokuColors(resolved)
    m.cPortalPrimary = portal.primary
    m.cPortalSecondary = portal.secondary
    m.cPortalTertiary = portal.tertiary
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
    if m.bg <> invalid then m.bg.color = m.cNeutral900
    if m.headerTextBackdrop <> invalid then
        m.headerTextBackdrop.color = "0x000000ff"
        if m.uiSpec <> invalid then
            m.headerTextBackdrop.opacity = m.uiSpec.headerBackdropOpacity
        end if
    end if
    m.title.color = m.cNeutral50
    m.errorLabel.color = m.cPrimary500
    m.logoLabel.color = m.cPrimary500

    ' Profile shimmer — same palette as SkeletonConfig.brs (React SkeletonBox).
    skColors = SkeletonResolveColors(m.tokens)
    for each id in ["sk0a", "sk0b", "sk1a", "sk1b", "sk2a", "sk2b"]
        sk = m.top.findNode(id)
        if sk <> invalid then
            sk.baseColor = skColors.base
            sk.highlightColor = skColors.highlight
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
    ApplyProfileArcColors()
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

sub ApplyProfileArcColors()
    LoadProfilePortalColors()
    for each av in m.avatars
        if av <> invalid and av.hasField("portalPrimary") then
            av.portalPrimary = m.cPortalPrimary
            av.portalSecondary = m.cPortalSecondary
            av.portalTertiary = m.cPortalTertiary
        end if
    end for
    if m.selectingOverlay <> invalid then
        m.selectingOverlay.primaryColor = m.cPortalPrimary
        m.selectingOverlay.portalSecondary = m.cPortalSecondary
        m.selectingOverlay.portalTertiary = m.cPortalTertiary
    end if
    if m.vm <> invalid then
        node = ProfileTransitionNode(m.vm)
        if node <> invalid then
            node.primaryColor = m.cPortalPrimary
            node.portalSecondary = m.cPortalSecondary
            node.portalTertiary = m.cPortalTertiary
        end if
    end if
    EnsureProfileArcBakeTask()
    ProfileArcStartBake(m.profileArcBakeTask, m.global, m.cPortalPrimary, m.cPortalSecondary, m.cPortalTertiary)
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

sub ApplyProfileBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved

    if resolved <> invalid then
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
            m.profileBgUri = url
        else
            m.profileBgUri = "pkg:/images/ui/profile_default_bg_base.png"
        end if
        m.cAvatarBg = m.cNeutral900
    end if

    if m.bgImage <> invalid then
        m.bgImage.uri = m.profileBgUri
        m.bgImage.opacity = 1.0
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

    if ProfileHandleSessionExpiry(api) then return

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

function ProfileHandleSessionExpiry(api as object) as boolean
    if HandleSessionExpiry(m.top, api) then
        print "[PROFILE_FETCH_DBG] session expired -> login"
        ProfileFetchAbort()
        return true
    end if
    return false
end function

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

    if ProfileHandleSessionExpiry(api) then return

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
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        focused = (m.focusArea = "profiles" and i = m.profileIndex)
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
' dwell). Home dismisses the overlay when row 0 mediaReady (see HomeScreen.brs).

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
    if HandleSessionExpiry(m.top, api) then
        CancelHomePrefetch()
        return
    end if
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
    if HandleSessionExpiry(m.top, api) then
        CancelHomePrefetch()
        return
    end if
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

