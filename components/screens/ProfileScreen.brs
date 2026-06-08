sub init()
    m.title = m.top.findNode("title")
    m.errorLabel = m.top.findNode("errorLabel")
    m.skeletonGroup = m.top.findNode("skeletonGroup")
    m.profilesContainer = m.top.findNode("profilesContainer")
    m.logoutBtn = m.top.findNode("logoutBtn")
    m.loaderOverlay = m.top.findNode("loaderOverlay")
    m.selectSpinner = m.top.findNode("selectSpinner")
    m.confirmPopup = m.top.findNode("confirmPopup")
    m.otpPopup = m.top.findNode("otpPopup")
    m.autoSelectTimer = m.top.findNode("autoSelectTimer")
    m.bgImage = m.top.findNode("bgImage")
    m.bgOverlay = m.top.findNode("bgOverlay")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")

    m.profiles = []
    m.avatars = []
    m.focusArea = "profiles"   ' "profiles" | "logout"
    m.profileIndex = 0
    m.selectedProfile = invalid
    m.pendingProfileId = ""
    m.popup = ""               ' "" | "confirm" | "otp"
    m.selecting = false
    m.loggingOut = false
    m.AUTO_TOTAL_MS = 15000
    m.AUTO_SELECT_MS = 15500
    m.AUTO_TICK_MS = 100
    ' Per-tick counter (parity with reference ProfileScene): reset to 0 on every
    ' focus change so each profile always gets a fresh, full 15s.
    m.autoElapsedMs = 0
    m.autoProfileIndex = -1
    m.autoProfileId = ""
    m.autoSelectArmed = false

    m.title.text = CopyChooseProfile()
    m.logoutBtn.label = CopyLogout()

    LoadProfileTokens()
    ApplyProfileColors()
    ApplyProfileBranding()

    m.vm = FindViewManager(m.top)

    m.top.observeField("keyEvent", "OnKey")
    m.autoSelectTimer.observeField("fire", "OnAutoTick")
    m.confirmPopup.observeField("action", "OnConfirmAction")
    m.otpPopup.observeField("submitted", "OnOtpSubmitted")
    if m.vm <> invalid then m.vm.observeField("overlayDismiss", "OnOverlayDismiss")

    ShowLoading(true)
    FetchProfiles()
end sub

' ── Theme ────────────────────────────────────────────────────────────────────

sub LoadProfileTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    m.cPrimary500 = TC("primary-500", "#0b75e0")
    m.cPrimary600 = TC("primary-600", "#0760bb")
    m.cPrimary700 = TC("primary-700", "#04478b")
    m.cNeutral50 = TC("neutral-50", "#f8f1f7")
    m.cNeutral400 = TC("neutral-400", "#9ea4b0")
    m.cNeutral500 = TC("neutral-500", "#e279ce")
    m.cNeutral600 = TC("neutral-600", "#a12189")
    m.cNeutral700 = "0x404040ff"
    m.cBg = "0x141414ff"        ' dark backdrop (clean circular masking)
    m.cCardBg = "0x171717ff"
    ' Color behind the avatar corners; switches to a near-black scrim color when a
    ' background image is shown so the corner-mask circle keeps blending cleanly.
    m.cAvatarBg = m.cBg
end sub

function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

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

    ' Inject colors into the overlays.
    m.confirmPopup.cPrimary500 = m.cPrimary500
    m.confirmPopup.cPrimary600 = m.cPrimary600
    m.confirmPopup.cNeutral500 = m.cNeutral500
    m.confirmPopup.cCardBg = m.cCardBg
    m.confirmPopup.cCardBorder = m.cNeutral600

    m.otpPopup.cPrimary500 = m.cPrimary500
    m.otpPopup.cPrimary600 = m.cPrimary600
    m.otpPopup.cNeutral600 = m.cNeutral600
    m.otpPopup.cNeutral700 = m.cNeutral700
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
        m.bgOverlay.opacity = 1.0
        ' Avatar corners now sit over the near-black scrim, not the solid page bg.
        m.cAvatarBg = "0x080a0cff"
    end if
end sub

' ── Loading / shimmer ──────────────────────────────────────────────────────────

sub ShowLoading(show as boolean)
    m.skeletonGroup.visible = show
    for each id in ["sk0a", "sk0b", "sk1a", "sk1b", "sk2a", "sk2b"]
        sk = m.top.findNode(id)
        if sk <> invalid then sk.running = show
    end for
    m.profilesContainer.visible = not show
end sub

' Rounded loader shown while a profile is being selected.
sub ShowSelectLoader(show as boolean)
    m.selecting = show
    m.loaderOverlay.visible = show
    m.selectSpinner.visible = show
end sub

sub ShowProfileError(msg as string)
    m.errorLabel.text = msg
    m.errorLabel.visible = (msg <> "")
end sub

' ── Fetch profiles ───────────────────────────────────────────────────────────

sub FetchProfiles()
    path = Endpoints().PROFILE.GET_LOGIN_PROFILES
    m.profilesTask = ApiGet(path)
    m.profilesTask.observeField("apiResult", "OnProfilesResponse")
    StartHttpTask(m.profilesTask)
end sub

sub OnProfilesResponse()
    if m.profilesTask = invalid then return
    api = m.profilesTask.apiResult
    if api = invalid then return

    if HandleSessionExpiry(m.top, api) then return

    ShowLoading(false)

    if not api.ok or api.result = invalid then
        ShowProfileError(MsgFailedLoadProfiles())
        LogoutToLogin(false)
        return
    end if

    m.profiles = ExtractProfiles(api.result)
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
    ' Clear any previous avatars.
    while m.profilesContainer.getChildCount() > 0
        m.profilesContainer.removeChildIndex(0)
    end while
    m.avatars = []

    for i = 0 to m.profiles.Count() - 1
        p = m.profiles[i]
        av = m.profilesContainer.createChild("ProfileAvatar")
        av.bgColor = m.cAvatarBg
        av.ringColor = m.cNeutral50
        av.nameColor = m.cNeutral50
        ' Keep enough pitch for the enlarged focused avatar while fitting 4 rows.
        av.translation = [0, i * 220]
        nm = ""
        if p.name <> invalid then nm = p.name
        av.profileName = nm
        av.initials = ProfileInitials(nm)
        if p.avatar <> invalid then av.avatarUri = p.avatar
        av.parentalLock = (p.parentalLock = true)
        m.avatars.Push(av)
    end for
end sub

' ── Focus ────────────────────────────────────────────────────────────────────

sub ApplyProfileFocus()
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        focused = (m.focusArea = "profiles" and i = m.profileIndex)
        if focused then
            av.hintText = FocusHint(i)
        else
            av.hintText = ""
        end if
        ' Progress reflects the focused profile's auto-select elapsed; others reset.
        if focused then
            frac = m.autoElapsedMs / m.AUTO_TOTAL_MS
            if frac > 1.0 then frac = 1.0
            av.progress = frac
        else
            av.progress = 0.0
        end if
        av.focusedState = focused
    end for

    ' Logout button focus (bg-primary-600 + glow when focused).
    if m.focusArea = "logout" then
        m.logoutBtn.bgColor = m.cPrimary600
        m.logoutBtn.showShadow = true
    else
        m.logoutBtn.bgColor = m.cPrimary500
        m.logoutBtn.showShadow = false
    end if
end sub

' Locked profiles show a PIN hint; unlocked ones show the filling progress ring (no text).
function FocusHint(index as integer) as string
    p = m.profiles[index]
    if ProfileNeedsPin(p) then return CopyEnterPinHint()
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
    if key = "up" then
        if m.profileIndex > 0 then
            m.profileIndex = m.profileIndex - 1
        end if
        ResetAutoSelect()
        ApplyProfileFocus()
    else if key = "down" then
        if m.profileIndex < m.profiles.Count() - 1 then
            m.profileIndex = m.profileIndex + 1
        else if m.logoutBtn.visible then
            m.focusArea = "logout"
        end if
        ResetAutoSelect()
        ApplyProfileFocus()
    else if key = "left" or key = "right" then
        ResetAutoSelect()
        ApplyProfileFocus()
    else if key = "OK" or key = "ok" then
        if m.profiles.Count() > 0 then SelectProfile(m.profiles[m.profileIndex])
    end if
end sub

sub HandleLogoutKey(key as string)
    if key = "up" then
        if m.profiles.Count() > 0 then
            m.focusArea = "profiles"
        end if
        ResetAutoSelect()
        ApplyProfileFocus()
    else if key = "OK" or key = "ok" then
        OpenConfirm()
    end if
end sub

' Restart the 15s auto-select countdown from zero for the currently focused
' profile. The countdown is owned by profile index + profile id; if focus moves,
' OnAutoTick refuses to select from the old countdown.
sub ResetAutoSelect()
    m.autoElapsedMs = 0
    m.autoProfileIndex = -1
    m.autoProfileId = ""
    m.autoSelectArmed = false

    if m.autoSelectTimer <> invalid then
        m.autoSelectTimer.control = "stop"
    end if

    if m.focusArea <> "profiles" then return
    if m.profiles = invalid or m.profiles.Count() = 0 then return
    if m.profileIndex < 0 or m.profileIndex >= m.profiles.Count() then return

    p = m.profiles[m.profileIndex]
    if ProfileNeedsPin(p) then return

    profileId = ""
    if p._id <> invalid then profileId = p._id

    m.autoProfileIndex = m.profileIndex
    m.autoProfileId = profileId
    m.autoSelectArmed = true

    if m.autoSelectTimer <> invalid then
        m.autoSelectTimer.control = "start"
    end if
end sub

' ── Auto-select (15s on focus, non-locked) ───────────────────────────────────

sub OnAutoTick()
    if m.popup <> "" or m.selecting or m.loggingOut then return
    if m.focusArea <> "profiles" then return
    if m.profiles.Count() = 0 then return
    if m.autoSelectArmed <> true then return
    if m.profileIndex <> m.autoProfileIndex then
        ResetAutoSelect()
        ApplyProfileFocus()
        return
    end if

    p = m.profiles[m.profileIndex]
    profileId = ""
    if p._id <> invalid then profileId = p._id
    if profileId <> m.autoProfileId then
        ResetAutoSelect()
        ApplyProfileFocus()
        return
    end if
    if ProfileNeedsPin(p) then return

    m.autoElapsedMs = m.autoElapsedMs + m.AUTO_TICK_MS
    frac = m.autoElapsedMs / m.AUTO_TOTAL_MS
    if frac > 1.0 then frac = 1.0
    if m.avatars <> invalid and m.avatars.Count() > m.profileIndex then
        m.avatars[m.profileIndex].progress = frac
    end if

    if m.autoElapsedMs >= m.AUTO_SELECT_MS then
        if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "stop"
        m.autoSelectArmed = false
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
    m.autoSelectArmed = false
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "stop"
    ShowSelectLoader(true)
    m.pendingProfileId = profileId
    path = SelectProfilePath()
    m.selectTask = ApiPost(path, SelectProfilePayload(profileId))
    m.selectTask.observeField("apiResult", "OnSelectResponse")
    StartHttpTask(m.selectTask)
end sub

sub OnSelectResponse()
    if m.selectTask = invalid then return
    api = m.selectTask.apiResult
    if api = invalid then return

    if HandleSessionExpiry(m.top, api) then return

    ShowSelectLoader(false)

    if api.ok and ApplySelectProfileTokens(api.result) then
        SetProfileId(m.pendingProfileId)
        NavigateHome()
        return
    end if

    ' Failure: toast + let the user retry (web also surfaces this alert).
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
    ClearStorage()
    SetOverlayOpen(false)
    if showToast then ShowAlert(m.top, 1, MsgLoggedOut())
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteLogin(), {})
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

' ── Navigation ───────────────────────────────────────────────────────────────

sub NavigateHome()
    SetValueByKey(SK_SelectedItem(), "Home", "app")
    if m.vm <> invalid then m.vm.callFunc("NavigateReplace", RouteHome(), {})
end sub
