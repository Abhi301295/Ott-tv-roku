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
    m.prevFocusArea = "profiles"
    m.LIST_SCROLL_ANIM_STEPS = 4
    m.listScrollAnimTimer = CreateObject("roSGNode", "Timer")
    m.listScrollAnimTimer.duration = 0.016
    m.listScrollAnimTimer.repeat = true
    m.top.appendChild(m.listScrollAnimTimer)
    m.listScrollAnimTimer.observeField("fire", "OnListScrollAnimTick")
    m.logoutBtn = m.top.findNode("logoutBtn")
    m.confirmPopup = m.top.findNode("confirmPopup")
    m.otpPopup = m.top.findNode("otpPopup")
    m.editProfilePopup = m.top.findNode("editProfilePopup")
    m.selectingOverlay = m.top.findNode("selectingOverlay")
    m.autoSelectTimer = m.top.findNode("autoSelectTimer")
    m.bg = m.top.findNode("bg")
    m.bgImage = m.top.findNode("bgImage")
    m.bgBottomVignette = m.top.findNode("bgBottomVignette")
    m.bgFocusScrim = m.top.findNode("bgFocusScrim")
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
    m.popup = ""               ' "" | "confirm" | "otp" | "edit"
    m.selecting = false
    m.prefetching = false
    m.loggingOut = false
    m.editingProfile = invalid
    m.editSaving = false
    m.editRefetchPending = false
    m.editKeyboardDialog = invalid
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
    m.editProfilePopup.observeField("action", "OnEditProfileAction")
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
    KillProfileTask(m.editTask)
    if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
    if m.profileFetchRetryTimer <> invalid then m.profileFetchRetryTimer.control = "stop"
    m.profilesTask = invalid
    m.selectTask = invalid
    m.logoutTask = invalid
    m.verifyTask = invalid
    m.refreshTask = invalid
    m.editTask = invalid
    m.selecting = false
    m.prefetching = false
    m.loggingOut = false
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    CloseEditKeyboardDialog()
end sub


sub KillProfileTask(task as object)
    if task = invalid then return
    task.unobserveField("apiResult")
end sub

' ── Theme ────────────────────────────────────────────────────────────────────


' React userProfile.tsx currently hardcodes `true ? NetComponent : original`.
function ProfileUsesSquareAvatars() as boolean
    return false
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
    rowLead = 0
    if m.useSquareAvatars = true and m.uiSpec <> invalid then
        gap = m.uiSpec.rowGap
        rowLead = m.uiSpec.rowItemMarginTop
    end if

    y = padY
    m.rowTops = []
    for i = 0 to m.avatars.Count() - 1
        if i > 0 and (gap > 0 or rowLead > 0) then y = y + gap + rowLead
        m.rowTops.Push(y)
        m.avatars[i].translation = [0, y]
        h = ProfileAvatarRowHeight(i)
        y = y + h
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
    wasAutoLogin = ProfileAutoLoginEnabled()
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
    nowAutoLogin = ProfileAutoLoginEnabled()
    if wasAutoLogin <> nowAutoLogin then
        print "[PROFILE_EDIT_DBG] profileAutoLogin resolved="; nowAutoLogin
        ResetAutoSelect()
        ApplyProfileFocus()
    end if
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
        skBox = m.top.findNode(id)
        if skBox <> invalid then skBox.running = show
    end for
    host = m.profilesScrollHost
    if host = invalid then host = m.profilesContainer
    if host <> invalid then host.visible = not show
    ApplyProfileFocusBackground()
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
    if m.editRefetchPending then
        print "[PROFILE_EDIT_DBG] refetch response ok=true count="; m.profiles.Count()
        m.editRefetchPending = false
    end if
    ProfileSelectLogNode("PROFILE_FETCH", "ok count=" + ProfileSelectFmt(m.profiles.Count()), m.top)
    SaveProfilesMeta(m.profiles)
    BuildAvatars()
    ApplyProfileColors()

    m.logoutBtn.visible = (GetRefreshToken() <> "")

    m.focusArea = "profiles"
    m.profileIndex = InitialFocusIndex()
    ResetAutoSelect()
    ApplyProfileFocus()
end sub

' Focus the stored profile if present, else the first (parity with focusSelf logic).

sub OpenEditProfile()
    if m.profiles = invalid or m.profileIndex < 0 or m.profileIndex >= m.profiles.Count() then return
    if not ProfileEditBadgeVisibleForRow(m.profileIndex) then return
    m.editingProfile = m.profiles[m.profileIndex]
    m.popup = "edit"
    m.editSaving = false
    ApplyEditPopupTheme()
    m.editProfilePopup.profileName = EditProfileNameValue(m.editingProfile)
    m.editProfilePopup.isKid = (m.editingProfile.isKid = true)
    m.editProfilePopup.isSaving = false
    m.editProfilePopup.visible = true
    SetOverlayOpen(true)
    ApplyProfileFocusBackground()
    ApplyProfileOverlayBackdrop(true)
    print "[PROFILE_EDIT_DBG] open profileId="; EditProfileId(m.editingProfile)
end sub

sub CloseEditProfile()
    m.popup = ""
    m.editSaving = false
    if m.editProfilePopup <> invalid then
        m.editProfilePopup.isSaving = false
        m.editProfilePopup.visible = false
    end if
    CloseEditKeyboardDialog()
    SetOverlayOpen(false)
    ApplyProfileOverlayBackdrop(false)
    ApplyProfileFocus()
end sub

' profile.tsx: showOtpPopup|showPopUp|editingProfile → blur-md scale-[0.98] brightness-75
' on the profile list + logout only. Poster bg + gradient layers stay full-strength
' (they sit outside that div); EditProfilePopUp then paints bg-black/50 backdrop-blur-sm.
' ⚠ Parity Note: SceneGraph cannot Gaussian-blur live UI — content dim + scale approximates
' brightness-75/blur-md; overlay scrim+veil approximates backdrop-blur-sm (see EditProfilePopup).
sub ApplyProfileOverlayBackdrop(active as boolean)
    opacity = 1.0
    scale = 1.0
    if active then
        opacity = 0.75
        scale = 0.98
    end if
    for each id in ["profilesScrollHost", "profileHeaderChrome", "skeletonGroup", "logoutBtn"]
        node = m.top.findNode(id)
        if node = invalid then continue for
        if node.hasField("opacity") then node.opacity = opacity
        if node.hasField("scale") then
            node.scale = [scale, scale]
            node.scaleRotateCenter = [960, 540]
        end if
    end for
    ' Poster + vignettes stay under ApplyProfileFocusBackground (opacity 0|1), matching React.
    if active = false then ApplyProfileFocusBackground()
end sub

sub ApplyEditPopupTheme()
    if m.editProfilePopup = invalid then return
    if m.cPrimary500 <> invalid then m.editProfilePopup.cPrimary500 = m.cPrimary500
    if m.cPrimary600 <> invalid then m.editProfilePopup.cPrimary600 = m.cPrimary600
    if m.cNeutral50 <> invalid then m.editProfilePopup.cNeutral50 = m.cNeutral50
    if m.cNeutral400 <> invalid then m.editProfilePopup.cNeutral400 = m.cNeutral400
    if m.cNeutral600 <> invalid then m.editProfilePopup.cNeutral600 = m.cNeutral600
    if m.cNeutral700 <> invalid then m.editProfilePopup.cNeutral700 = m.cNeutral700
    if m.cNeutral800 <> invalid then m.editProfilePopup.cNeutral800 = m.cNeutral800
    if m.cNeutral900 <> invalid then m.editProfilePopup.cNeutral900 = m.cNeutral900
    if m.cPrimary500 <> invalid then m.editProfilePopup.cPortalPrimary = m.cPrimary500
end sub

sub OnEditProfileAction()
    action = m.editProfilePopup.action
    if action = "" then return
    m.editProfilePopup.action = ""
    if action = "cancel" then
        CloseEditProfile()
    else if action = "keyboard" then
        ShowEditKeyboardDialog()
    else if action = "save" then
        StartEditProfileSave(m.editProfilePopup.editedName)
    end if
end sub

sub ShowEditKeyboardDialog()
    CloseEditKeyboardDialog()
    isStandard = true
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    if dialog = invalid or not dialog.hasField("keyboard") then
        isStandard = false
        dialog = CreateObject("roSGNode", "KeyboardDialog")
    end if
    dialog.title = CopyProfileName()
    dialog.text = m.editProfilePopup.editedName
    dialog.buttons = ["OK", "Cancel"]
    if isStandard then dialog.keyboardDomain = "generic"
    m.editKeyboardDialog = dialog
    dialog.observeField("buttonSelected", "OnEditKeyboardButton")
    dialog.observeField("wasClosed", "OnEditKeyboardClosed")
    m.top.getScene().dialog = dialog
end sub

sub OnEditKeyboardButton()
    dialog = m.editKeyboardDialog
    if dialog = invalid then return
    if dialog.buttonSelected = 0 then
        m.editProfilePopup.profileName = dialog.text
    end if
    CloseEditKeyboardDialog()
end sub

sub OnEditKeyboardClosed()
    CloseEditKeyboardDialog()
end sub

sub CloseEditKeyboardDialog()
    if m.editKeyboardDialog <> invalid then
        m.top.getScene().dialog = invalid
        m.editKeyboardDialog = invalid
    end if
end sub

sub StartEditProfileSave(name as string)
    if m.editingProfile = invalid or m.editSaving then return
    trimmed = name.Trim()
    if trimmed = "" then return
    profileId = EditProfileId(m.editingProfile)
    if profileId = "" then return

    m.editSaving = true
    m.editProfilePopup.isSaving = true
    path = UpdateProfilePath(profileId)
    body = UpdateProfilePayload(trimmed, m.editingProfile.isKid = true)
    print "[PROFILE_EDIT_DBG] save start id="; profileId; " name="; trimmed
    KillProfileTask(m.editTask)
    m.editTask = ApiPatch(path, body)
    m.editTask.observeField("apiResult", "OnEditProfileSaveResponse")
    StartHttpTask(m.editTask)
end sub

sub OnEditProfileSaveResponse()
    if m.editTask = invalid then return
    api = m.editTask.apiResult
    if api = invalid then return
    ReconcileEditProfileSave(api)
end sub

sub ReconcileEditProfileSave(api as object)
    m.editSaving = false
    if m.editProfilePopup <> invalid then m.editProfilePopup.isSaving = false
    profileId = EditProfileId(m.editingProfile)
    ReconcileEditProfileListName(profileId, m.editProfilePopup.editedName)
    print "[PROFILE_EDIT_DBG] save response ok="; api.ok; " status="; api.statusCode
    if IsProfileUpdateSuccessful(api) then
        if profileId = GetProfileId() then SetValueByKey(SK_ProfileName(), m.editProfilePopup.editedName, "app")
        ShowAlert(m.top, 1, MsgProfileUpdated())
        m.editRefetchPending = true
        CloseEditProfile()
        FetchProfiles()
        return
    end if
    ShowAlert(m.top, 2, MsgFailedUpdateProfile())
end sub

sub ReconcileEditProfileListName(profileId as string, name as string)
    if profileId = "" or name = "" then return
    for each p in m.profiles
        if p <> invalid and EditProfileId(p) = profileId then
            p.name = name
            exit for
        end if
    end for
    if m.editingProfile <> invalid then m.editingProfile.name = name
end sub

function EditProfileId(profile as object) as string
    if profile = invalid then return ""
    if profile._id <> invalid then return profile._id
    if profile.id <> invalid then return profile.id
    return ""
end function

function EditProfileNameValue(profile as object) as string
    if profile = invalid or profile.name = invalid then return ""
    return profile.name
end function
