sub init()
    if m.global <> invalid and m.global.hasField("sessionLogoutInFlight") then
        m.global.sessionLogoutInFlight = false
    end if

    m.bgImage = m.top.findNode("bgImage")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")
    m.title = m.top.findNode("title")
    m.phoneTab = m.top.findNode("phoneTab")
    m.remoteTab = m.top.findNode("remoteTab")
    m.phoneCard = m.top.findNode("phoneCard")
    m.phoneCardBorder = m.top.findNode("phoneCardBorder")
    m.remoteCard = m.top.findNode("remoteCard")
    m.remoteCardBorder = m.top.findNode("remoteCardBorder")
    m.phonePanel = m.top.findNode("phonePanel")
    m.remotePanel = m.top.findNode("remotePanel")
    m.step1Badge = m.top.findNode("step1Badge")
    m.step2Badge = m.top.findNode("step2Badge")
    m.step1Num = m.top.findNode("step1Num")
    m.step2Num = m.top.findNode("step2Num")
    m.step1Text = m.top.findNode("step1Text")
    m.step2Text = m.top.findNode("step2Text")
    m.orLabel = m.top.findNode("orLabel")
    m.dividerTop = m.top.findNode("dividerTop")
    m.dividerBottom = m.top.findNode("dividerBottom")
    m.qrPad = m.top.findNode("qrPad")
    m.qrGlow = m.top.findNode("qrGlow")
    m.qrSkeleton = m.top.findNode("qrSkeleton")
    m.qrErrorLabel = m.top.findNode("qrErrorLabel")
    m.qrImage = m.top.findNode("qrImage")
    m.userCodeLabel = m.top.findNode("userCodeLabel")
    m.emailField = m.top.findNode("emailField")
    m.passwordField = m.top.findNode("passwordField")
    m.loginBtn = m.top.findNode("loginBtn")
    m.formError = m.top.findNode("formError")
    m.formErrorBox = m.top.findNode("formErrorBox")
    m.formErrorBg = m.top.findNode("formErrorBg")
    m.formErrorBorder = m.top.findNode("formErrorBorder")
    m.loginSpinner = m.top.findNode("loginSpinner")
    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimeout = m.top.findNode("pollTimeout")
    m.onboardRetry = m.top.findNode("onboardRetry")

    m.mode = "phone"
    m.deviceCode = ""
    m.userCode = ""
    m.email = ""
    m.password = ""
    m.onboardInFlight = false
    m.pollInFlight = false

    m.FOCUS_PHONE_TAB = 0
    m.FOCUS_REMOTE_TAB = 1
    m.FOCUS_EMAIL = 2
    m.FOCUS_PASSWORD = 3
    m.FOCUS_LOGIN_BTN = 4
    m.focusIndex = m.FOCUS_PHONE_TAB

    ' Avoid a visible Login -> Profile flash on startup when a session already exists.
    if HasActiveSession() then
        m.top.visible = false
        RedirectIfAlreadyAuthenticated()
        return
    end if

    m.title.text = CopyLoginTitle()
    m.phoneTab.label = CopyUsePhone()
    m.remoteTab.label = CopyUseRemote()
    m.top.findNode("step1Text").text = CopyStep1()
    m.top.findNode("step2Text").text = CopyStep2()
    m.top.findNode("orLabel").text = CopyOr()
    m.loginBtn.label = CopyLoginBtn()
    m.emailField.label = CopyEmailHint()
    m.passwordField.label = CopyPasswordHint()

    m.top.observeField("keyEvent", "OnRemoteKeyField")
    m.pollTimer.observeField("fire", "OnPollFire")
    m.pollTimeout.observeField("fire", "OnPollTimeout")
    m.onboardRetry.observeField("fire", "OnOnboardRetryFire")
    m.phoneTab.observeField("hasFocus", "OnPhoneTabFocus")
    m.remoteTab.observeField("hasFocus", "OnRemoteTabFocus")

    LoadThemeTokens()
    ApplyLoginBranding()
    ApplyThemeColors()
    UpdateTabColors()
    UpdateLoginButton()

    ' Login is the first screen, so business config may still be resolving. Re-apply the
    ' themed colors when it lands (parity with HomeScreen) so the tabs/QR/fields don't get
    ' stranded on dark fallbacks if the tokens arrive after mount.
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    LoginScreen_ApplyFocus()
    FetchOnboardDevice()
end sub

sub LoadThemeTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    ' Cache the colors used by interactive states (parity with Tailwind tokens).
    m.cActive = TC("primary-600", "#0760bb")        ' bg-primary-600 (active tab / focused btn)
    m.cShadow = TC("primary-700", "#04478b")         ' shadow-primary-700
    m.cInactive = TC("background", "#1f1f22")        ' bg-ui-background (inactive tab) — dark default from dark.theme.ts
    m.cTabText = TC("neutral-50", "#ffffff")         ' text-neutral-50
    m.cBtnEnabledBg = TC("primary-500", "#0b75e0")   ' bg-primary-500 (enabled, unfocused)
    m.cBtnFocusBg = m.cActive                        ' bg-primary-600 (enabled, focused)
    m.cBtnDisabledBg = TC("neutral-600", "#a12189")  ' bg-neutral-600 (disabled)
    m.cBtnDisabledText = TC("neutral-400", "#ce4fb6")' text-neutral-400 (disabled)
    m.cFieldBg = TC("neutral-700", "#ffffff")        ' bg-neutral-700 (input bg, unfocused)
    m.cFieldBgFocus = TC("neutral-900", "#ffffff")   ' bg-neutral-900 (input bg, focused)
    m.cFieldText = TC("neutral-50", "#ffffff")       ' text-neutral-50 (typed text + unfocused placeholder)
    m.cFieldBorder = TC("neutral-100", "#efdceb")    ' border-neutral-100 (focused input)
    ' Focused placeholder = browser-default muted gray (web drops the neutral-50
    ' override when focused). Not a theme token, so hardcode like the badge number.
    m.cFieldPlaceholderFocus = "0x9ea4b0ff"
end sub

function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

' Business config resolved after mount — re-pull tokens and recolor everything.
sub OnBusinessResolved()
    LoadThemeTokens()
    ApplyLoginBranding()
    ApplyThemeColors()
    UpdateTabColors()
    UpdateLoginButton()
end sub

' Emulate CSS tracking-widest (letter-spacing ~0.1em) by inserting a thin space
' between characters. Also lets the hyphenated code wrap like the web (2 lines).
function TrackWide(s as string) as string
    if s = invalid or s = "" then return ""
    sp = Chr(8201) ' THIN SPACE
    out = ""
    for i = 1 to Len(s)
        out = out + Mid(s, i, 1)
        if i < Len(s) then out = out + sp
    end for
    return out
end function

' One-time recolor of all static (non-interactive) elements from theme tokens.
sub ApplyThemeColors()
    m.title.color = TC("neutral-50", "#ffffff")
    m.logoLabel.color = TC("primary-500", "#0b75e0")

    cardBg = TC("background", "#1f1f22")
    cardBorder = TC("neutral-500", "#e279ce")
    m.phoneCard.blendColor = cardBg
    m.phoneCardBorder.blendColor = cardBorder
    m.remoteCard.blendColor = cardBg
    m.remoteCardBorder.blendColor = cardBorder

    ' Badge bg uses neutral-50 (theme), but the number uses text-neutral-950 which
    ' is NOT mapped in the web Tailwind config — it falls back to Tailwind's default
    ' #0a0a0a (dark). So hardcode dark to match React/LG (not the white theme token).
    badgeBg = TC("neutral-50", "#ffffff")
    m.step1Badge.blendColor = badgeBg
    m.step2Badge.blendColor = badgeBg
    m.step1Num.color = "0x0a0a0aff"
    m.step2Num.color = "0x0a0a0aff"

    bodyText = TC("neutral-500", "#e279ce")
    m.step1Text.color = bodyText
    m.step2Text.color = bodyText
    m.orLabel.color = bodyText

    dividerColor = TC("neutral-600", "#a12189")
    m.dividerTop.color = dividerColor
    m.dividerBottom.color = dividerColor

    m.userCodeLabel.color = TC("neutral-50", "#ffffff")
    m.qrPad.blendColor = TC("neutral-50", "#ffffff")
    if m.qrGlow <> invalid then m.qrGlow.blendColor = TC("primary-500", "#0092ff")
    m.qrErrorLabel.color = TC("primary-500", "#0b75e0")
    ' Error box — web: bg-primary-800/20, border-primary-500, text-primary-500
    m.formError.color = TC("primary-500", "#0b75e0")
    m.formErrorBorder.blendColor = TC("primary-500", "#0b75e0")
    m.formErrorBg.blendColor = TC("primary-800", "#0b3a82")

    m.emailField.bgColor = m.cFieldBg
    m.emailField.bgColorFocused = m.cFieldBgFocus
    m.emailField.textColor = m.cFieldText
    m.emailField.placeholderColor = m.cFieldText
    m.emailField.placeholderColorFocused = m.cFieldPlaceholderFocus
    m.emailField.borderColor = m.cFieldBorder
    m.passwordField.bgColor = m.cFieldBg
    m.passwordField.bgColorFocused = m.cFieldBgFocus
    m.passwordField.textColor = m.cFieldText
    m.passwordField.placeholderColor = m.cFieldText
    m.passwordField.placeholderColorFocused = m.cFieldPlaceholderFocus
    m.passwordField.borderColor = m.cFieldBorder
end sub

' Tab colors follow selection (onFocus switches mode in the web app).
sub UpdateTabColors()
    isPhone = (m.mode = "phone")
    if isPhone then
        m.phoneTab.bgColor = m.cActive
        m.remoteTab.bgColor = m.cInactive
    else
        m.phoneTab.bgColor = m.cInactive
        m.remoteTab.bgColor = m.cActive
    end if
    m.phoneTab.textColor = m.cTabText
    m.remoteTab.textColor = m.cTabText

    ' shadow-primary-700 on the selected tab (parity with shadow-lg shadow-primary-700)
    shadow = m.cShadow
    m.phoneTab.shadowColor = shadow
    m.remoteTab.shadowColor = shadow
    m.phoneTab.showShadow = isPhone
    m.remoteTab.showShadow = not isPhone
end sub

' Login button has 3 states (disabled / enabled / enabled+focused), parity with emailLogin.tsx.
sub UpdateLoginButton()
    valid = ValidateEmail(m.email) and (m.password <> "")
    loading = (m.loginSpinner <> invalid and m.loginSpinner.visible = true)

    if (not valid) or loading then
        m.loginBtn.bgColor = m.cBtnDisabledBg
        m.loginBtn.textColor = m.cBtnDisabledText
    else if m.focusIndex = m.FOCUS_LOGIN_BTN then
        m.loginBtn.bgColor = m.cBtnFocusBg
        m.loginBtn.textColor = m.cTabText
    else
        m.loginBtn.bgColor = m.cBtnEnabledBg
        m.loginBtn.textColor = m.cTabText
    end if

    ' While loading, the button text is replaced by the in-button spinner (web parity).
    if loading then
        m.loginBtn.label = ""
    else
        m.loginBtn.label = CopyLoginBtn()
    end if

    ' shadow-primary-700 when the (enabled) Login button is focused — parity with
    ' the web focused state. Also acts as the TV focus indicator.
    m.loginBtn.shadowColor = m.cShadow
    m.loginBtn.showShadow = (m.focusIndex = m.FOCUS_LOGIN_BTN and valid and not loading)
end sub

' Toggle the in-button loader (spinner inside the Login button + disabled style).
sub SetLoginLoading(loading as boolean)
    ' BusySpinner animates automatically while visible.
    m.loginSpinner.visible = loading
    UpdateLoginButton()
end sub

' Error box — show/hide the bordered container together with its text (web parity).
' Showing the error pushes the fields + button down so the error sits above them
' (web flow), instead of overlaying the top of the card.
sub ShowFormError(msg as string)
    m.formError.text = msg
    m.formError.visible = true
    if m.formErrorBox <> invalid then m.formErrorBox.visible = true
    LayoutForm(true)
end sub

sub HideFormError()
    m.formError.text = ""
    m.formError.visible = false
    if m.formErrorBox <> invalid then m.formErrorBox.visible = false
    LayoutForm(false)
end sub

' Top-aligned form. Without an error, keep extra breathing room above Email.
' With an error, the error box owns the top slot and fields start below it.
sub LayoutForm(hasError as boolean)
    if m.emailField = invalid then return
    if hasError then
        m.emailField.translation = [64, 103]
        m.passwordField.translation = [64, 191]
        m.loginBtn.translation = [64, 295]
    else
        m.emailField.translation = [64, 55]
        m.passwordField.translation = [64, 143]
        m.loginBtn.translation = [64, 247]
    end if
    by = m.loginBtn.translation[1]
    m.loginSpinner.translation = [443, by + 12]
end sub

sub ApplyLoginBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    if resolved = invalid then return

    url = resolved.loginBackgroundImage
    if url <> invalid and url <> "" then
        m.bgImage.uri = url
        m.bgImage.visible = true
    end if

    logoUrl = resolved.brandingLogo
    if logoUrl <> invalid and logoUrl <> "" then
        m.logoPoster.uri = logoUrl
        m.logoPoster.visible = true
        m.logoLabel.visible = false
    else if resolved.appName <> invalid and resolved.appName <> "" then
        m.logoLabel.text = resolved.appName
        m.logoLabel.visible = true
    end if
end sub

sub OnRemoteKeyField()
    ev = m.top.keyEvent
    if ev = invalid then return
    if ev.key = invalid or ev.press = invalid then return
    LoginScreen_OnKey(ev.key, ev.press)
end sub

sub LoginScreen_ApplyFocus()
    m.emailField.focusedState = (m.focusIndex = m.FOCUS_EMAIL)
    m.passwordField.focusedState = (m.focusIndex = m.FOCUS_PASSWORD)

    if m.focusIndex = m.FOCUS_PHONE_TAB then
        SetLoginMode("phone")
        m.phoneTab.setFocus(true)
    else if m.focusIndex = m.FOCUS_REMOTE_TAB then
        SetLoginMode("remote")
        m.remoteTab.setFocus(true)
    else if m.focusIndex = m.FOCUS_EMAIL then
        SetLoginMode("remote")
        m.emailField.setFocus(true)
    else if m.focusIndex = m.FOCUS_PASSWORD then
        SetLoginMode("remote")
        m.passwordField.setFocus(true)
    else if m.focusIndex = m.FOCUS_LOGIN_BTN then
        SetLoginMode("remote")
        m.loginBtn.setFocus(true)
    end if

    UpdateLoginButton()
end sub

sub RedirectIfAlreadyAuthenticated()
    vm = FindViewManager(m.top)
    if vm <> invalid then
        vm.callFunc("NavigateReplace", RouteLoginProfile(), { directLogin: true })
    end if
end sub

sub OnPhoneTabFocus()
    if m.phoneTab.hasFocus then
        m.focusIndex = m.FOCUS_PHONE_TAB
        SetLoginMode("phone")
    end if
end sub

sub OnRemoteTabFocus()
    if m.remoteTab.hasFocus then
        m.focusIndex = m.FOCUS_REMOTE_TAB
        SetLoginMode("remote")
    end if
end sub

sub SetLoginMode(mode as string)
    m.mode = mode
    isPhone = (mode = "phone")

    m.phonePanel.visible = isPhone
    m.phoneCard.visible = isPhone
    m.phoneCardBorder.visible = isPhone
    m.remotePanel.visible = not isPhone
    m.remoteCard.visible = not isPhone
    m.remoteCardBorder.visible = not isPhone

    UpdateTabColors()

    if isPhone then
        if m.deviceCode <> "" then StartPollTimers()
    else
        StopPollTimers()
    end if
end sub

sub ShowQrSkeleton(show as boolean)
    if m.qrSkeleton = invalid then return
    if show then
        ' Exact parity with React's SkeletonBox: baseColor #ffffff, highlightColor #f3f3f3
        ' (literal hex in emailLogin/login index, NOT theme tokens) — a white box on the
        ' near-white QR pad with a very faint grey shimmer band, plus the blue glow below.
        m.qrSkeleton.baseColor = "0xffffffff"
        m.qrSkeleton.highlightColor = "0xf3f3f3ff"
        if m.qrSkeleton.hasField("animate") then m.qrSkeleton.animate = true
        m.qrImage.visible = false
        m.qrErrorLabel.visible = false
        if m.qrGlow <> invalid then m.qrGlow.visible = true
        m.qrSkeleton.visible = true
        m.qrSkeleton.running = true
    else
        m.qrSkeleton.running = false
        m.qrSkeleton.visible = false
        if m.qrGlow <> invalid then m.qrGlow.visible = false
    end if
end sub

sub ShowQrError(msg as string)
    ShowQrSkeleton(false)
    m.qrImage.visible = false
    m.qrErrorLabel.text = msg
    m.qrErrorLabel.visible = true
end sub

sub ShowQrCode(userCode as string)
    ShowQrSkeleton(false)
    m.qrErrorLabel.visible = false
    m.qrImage.uri = QrImageUrl(userCode, 150)
    m.qrImage.visible = true
end sub

sub FetchOnboardDevice()
    if m.onboardInFlight then return
    m.onboardInFlight = true
    ShowQrSkeleton(true)
    m.userCodeLabel.text = ""

    path = Endpoints().LOGIN.ONBOARD_DEVICE
    m.onboardTask = ApiPost(path, LoginDevicePayload())
    m.onboardTask.observeField("apiResult", "OnOnboardResponse")
    StartHttpTask(m.onboardTask)
end sub

sub OnOnboardResponse()
    api = m.onboardTask.apiResult
    ' apiResult is invalid while the request is in flight (and observeField can fire on
    ' registration). Ignore those — keep showing the shimmer until the real result, so
    ' the QR doesn't flash "Failed to load" before the code appears.
    if api = invalid then return

    m.onboardInFlight = false
    if api.shouldLogout = true then return
    if not api.ok or api.result = invalid then
        ShowQrError(CopyQrLoadFailed())
        MaybeToastApiError(api)
        ScheduleOnboardRetry()
        return
    end if

    result = api.result
    userCode = ""
    deviceId = ""
    if result.userCode <> invalid then userCode = result.userCode
    if result.deviceId <> invalid then deviceId = result.deviceId

    if userCode = "" and deviceId = "" then
        ShowQrError(CopyQrLoadFailed())
        ScheduleOnboardRetry()
        return
    end if

    m.userCode = userCode
    m.deviceCode = deviceId
    m.userCodeLabel.text = TrackWide(FormatQRCodeNumber(userCode))

    if userCode <> "" then
        ShowQrCode(userCode)
    else
        ShowQrError(CopyQrLoadFailed())
    end if

    CancelOnboardRetry()
    if m.onboardTask <> invalid then
        m.onboardTask.unobserveField("apiResult")
    end if

    if m.mode = "phone" then StartPollTimers()
end sub

sub CancelOnboardRetry()
    m.onboardRetry.control = "stop"
end sub

sub ScheduleOnboardRetry()
    m.onboardRetry.control = "stop"
    m.onboardRetry.control = "start"
end sub

sub OnOnboardRetryFire()
    m.onboardRetry.control = "stop"
    FetchOnboardDevice()
end sub

sub StartPollTimers()
    StopPollTimers()
    m.pollTimer.control = "start"
    m.pollTimeout.control = "start"
    ' First poll after 6s (parity with setInterval(checkDeviceToken, 6000) — not immediate).
end sub

sub StopPollTimers()
    m.pollTimer.control = "stop"
    m.pollTimeout.control = "stop"
end sub

sub OnPollFire()
    if m.mode <> "phone" or m.deviceCode = "" then return
    PollDeviceToken()
end sub

sub OnPollTimeout()
    StopPollTimers()
    m.userCode = ""
    m.userCodeLabel.text = ""
    ShowQrError(CopyAuthTimeout())
    m.deviceCode = ""
    FetchOnboardDevice()
end sub

sub PollDeviceToken()
    if m.deviceCode = "" or m.pollInFlight = true then return
    m.pollInFlight = true

    path = Endpoints().LOGIN.DEVICE_TOKEN
    m.pollTask = ApiPatch(path, { deviceCode: m.deviceCode })
    m.pollTask.observeField("apiResult", "OnPollResponse")
    StartHttpTask(m.pollTask)
end sub

sub OnPollResponse()
    m.pollInFlight = false
    task = m.pollTask
    m.pollTask = invalid
    if task = invalid then return

    api = task.apiResult
    if api = invalid then return
    if api.shouldLogout = true then return

    ' Complete on tokens OR an explicit device-limit result; otherwise keep polling
    ' (pending/empty keeps the QR alive, web parity).
    if api.ok and api.result <> invalid and (HasLoginTokens(api.result) or api.result.nextStep = NextStepDeviceLimit()) then
        StopPollTimers()
        CancelOnboardRetry()
        vm = FindViewManager(m.top)
        HandleLoginRedirect(api.result, vm, m.top)
        return
    end if

    if IsAuthPendingMessage(api.message) then return

    MaybeToastApiError(api)
end sub

sub MaybeToastApiError(api as object)
    if api = invalid then return
    if api.suppressToast = true then return
    if api.httpStatus = 401 then return
    if api.message = invalid or api.message = "" then return
    ShowAlert(m.top, 2, api.message)
end sub

sub SubmitEmailLogin()
    HideFormError()
    if not ValidateEmail(m.email) or m.password = "" then
        ShowFormError(CopyFormInvalid())
        return
    end if

    SetLoginLoading(true)
    path = Endpoints().LOGIN.EMAIL_TOKEN
    m.emailTask = ApiPatch(path, { email: m.email, password: m.password })
    m.emailTask.observeField("apiResult", "OnEmailResponse")
    StartHttpTask(m.emailTask)
end sub

sub OnEmailResponse()
    api = m.emailTask.apiResult
    ' apiResult is invalid while the request is in flight (and observeField can fire on
    ' registration). Ignore those spurious fires — only act on the final result, so the
    ' button keeps its spinner instead of flashing "Login failed" then the real error.
    if api = invalid then return

    SetLoginLoading(false)
    if api.shouldLogout = true then return

    ' Device limit exceeded → always a toast (web parity: showAlert(2, DEVICE_LIMIT_EXCEEDED)),
    ' never the inline error. Checked first so it works regardless of HTTP status.
    if api.result <> invalid and api.result.nextStep = NextStepDeviceLimit() then
        vm = FindViewManager(m.top)
        HandleLoginRedirect(api.result, vm, m.top)
        return
    end if

    ' API responded but login did not succeed. Web shows a fixed inline message (no toast):
    '  - no HTTP response at all (network failure) → "Login failed. Please try again." (catch)
    '  - server rejected the request (4xx)        → "Invalid email or password"
    if not api.ok or api.result = invalid then
        if m.emailTask.httpStatus <= 0 then
            ShowFormError(CopyLoginFailed())
        else
            ShowFormError(CopyInvalidCredentials())
        end if
        return
    end if

    token = api.result

    ' Success → store tokens and navigate per nextStep (parity with handleRedirect).
    if token.authToken <> invalid and token.authToken <> "" then
        deviceToken = {
            authToken: token.authToken
            cognitoAccessToken: token.authToken
            refreshToken: token.refreshToken
            cognitoRefreshToken: token.refreshToken
            nextStep: token.nextStep
        }
        vm = FindViewManager(m.top)
        HandleLoginRedirect(deviceToken, vm, m.top)
    else
        ShowFormError(CopyInvalidCredentials())
    end if
end sub

function ValidateEmail(email as string) as boolean
    if email = invalid or email = "" then return false
    at = Instr(1, email, "@")
    if at < 2 then return false
    dot = Instr(at + 1, email, ".")
    return dot > at + 1
end function

sub ShowKeyboardDialog(field as string, initial as string, secure as boolean)
    ' Prefer StandardKeyboardDialog (Roku's recommended replacement for the legacy
    ' KeyboardDialog — enhanced graphics + keyboardDomain/voice support). On hosts
    ' that don't implement it yet (e.g. the simulator's brs-scenegraph v0.1.0 falls
    ' back to a blank Node), drop down to the legacy KeyboardDialog so it still works.
    ' Detect real support via hasField: an unimplemented type is created as a
    ' bare Node (no "keyboard" field), while a real (Standard)KeyboardDialog has it.
    isStandard = true
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    if dialog = invalid or not dialog.hasField("keyboard") then
        isStandard = false
        dialog = CreateObject("roSGNode", "KeyboardDialog")
    end if

    if field = "email" then
        dialog.title = CopyEmailHint()
        if isStandard then dialog.keyboardDomain = "email"
    else
        dialog.title = CopyPasswordHint()
        if isStandard then dialog.keyboardDomain = "generic"
    end if
    dialog.text = initial
    dialog.buttons = ["OK", "Cancel"]

    ' Secure (password) masking — set on the internal keyboard and, when present,
    ' its textEditBox (accessed via node fields; findNode by id is unreliable here).
    kb = dialog.keyboard
    if kb <> invalid then kb.secureMode = secure
    if isStandard then
        teb = dialog.textEditBox
        if teb <> invalid then teb.secureMode = secure
    end if

    m.activeField = field
    m.keyboardDialog = dialog
    dialog.observeField("buttonSelected", "OnKeyboardButton")
    dialog.observeField("wasClosed", "OnKeyboardClosed")
    m.top.getScene().dialog = dialog
end sub

sub OnKeyboardButton()
    dialog = m.keyboardDialog
    if dialog = invalid then return

    if dialog.buttonSelected = 0 then
        text = dialog.text
        if m.activeField = "email" then
            m.email = text
            m.emailField.value = text
            m.focusIndex = m.FOCUS_PASSWORD
            LoginScreen_ApplyFocus()
        else
            m.password = text
            m.passwordField.value = text
            m.focusIndex = m.FOCUS_LOGIN_BTN
            LoginScreen_ApplyFocus()
        end if
        UpdateLoginButton()
    end if

    CloseKeyboardDialog()
end sub

sub OnKeyboardClosed()
    CloseKeyboardDialog()
end sub

sub CloseKeyboardDialog()
    if m.keyboardDialog <> invalid then
        m.top.getScene().dialog = invalid
        m.keyboardDialog = invalid
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    return LoginScreen_OnKey(key, press)
end function

function LoginScreen_OnKey(key as string, press as boolean) as boolean
    if not press then return false

    key = LCase(key)
    fi = m.FOCUS_PHONE_TAB

    if key = "right" or key = "down" then
        if m.focusIndex = fi then
            ' Switch to Remote: focus the email field by default (remote tab stays
            ' visually active). The tabs remain reachable via Up from email.
            m.focusIndex = m.FOCUS_EMAIL
            LoginScreen_ApplyFocus()
            return true
        else if m.focusIndex = m.FOCUS_REMOTE_TAB then
            m.focusIndex = m.FOCUS_EMAIL
            LoginScreen_ApplyFocus()
            return true
        else if m.mode = "remote" and m.focusIndex < m.FOCUS_LOGIN_BTN then
            m.focusIndex = m.focusIndex + 1
            LoginScreen_ApplyFocus()
            return true
        end if
    else if key = "left" or key = "up" then
        if m.focusIndex = m.FOCUS_REMOTE_TAB then
            m.focusIndex = fi
            LoginScreen_ApplyFocus()
            return true
        else if m.focusIndex = m.FOCUS_EMAIL then
            m.focusIndex = m.FOCUS_REMOTE_TAB
            LoginScreen_ApplyFocus()
            return true
        else if m.mode = "remote" and m.focusIndex > m.FOCUS_REMOTE_TAB then
            m.focusIndex = m.focusIndex - 1
            LoginScreen_ApplyFocus()
            return true
        end if
    else if key = "ok" then
        if m.focusIndex = fi or m.focusIndex = m.FOCUS_REMOTE_TAB then
            LoginScreen_ApplyFocus()
            return true
        else if m.focusIndex = m.FOCUS_EMAIL then
            ShowKeyboardDialog("email", m.email, false)
            return true
        else if m.focusIndex = m.FOCUS_PASSWORD then
            ShowKeyboardDialog("password", m.password, true)
            return true
        else if m.focusIndex = m.FOCUS_LOGIN_BTN then
            SubmitEmailLogin()
            return true
        end if
    end if

    return false
end function
