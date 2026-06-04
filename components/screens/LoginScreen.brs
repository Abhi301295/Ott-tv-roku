sub init()
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
    m.qrSkeleton = m.top.findNode("qrSkeleton")
    m.qrErrorLabel = m.top.findNode("qrErrorLabel")
    m.qrImage = m.top.findNode("qrImage")
    m.userCodeLabel = m.top.findNode("userCodeLabel")
    m.emailField = m.top.findNode("emailField")
    m.passwordField = m.top.findNode("passwordField")
    m.loginBtn = m.top.findNode("loginBtn")
    m.formError = m.top.findNode("formError")
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

    ApplyLoginBranding()
    ApplyThemeToTabs()

    if GetCognitoToken() <> "" then
        RedirectIfAlreadyAuthenticated()
        return
    end if

    LoginScreen_ApplyFocus()
    FetchOnboardDevice()
end sub

sub ApplyThemeToTabs()
    active = "0x4d57eaff"
    inactive = "0x1f1f22ff"
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid then
        if tm.primary600 <> invalid and tm.primary600 <> "" then
            active = HexColorToRg(tm.primary600)
        end if
    end if
    m.phoneTab.activeColor = active
    m.phoneTab.inactiveColor = inactive
    m.remoteTab.activeColor = active
    m.remoteTab.inactiveColor = inactive
    m.loginBtn.activeColor = active
    m.loginBtn.inactiveColor = "0x52525bff"
end sub

function HexColorToRg(hex as string) as string
    if hex = invalid or hex = "" then return "0x4d57eaff"
    h = hex
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) = 6 then return "0x" + h + "ff"
    if Len(h) = 8 then return "0x" + h
    return "0x4d57eaff"
end function

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

    m.phoneTab.selected = isPhone
    m.remoteTab.selected = not isPhone

    if isPhone then
        if m.deviceCode <> "" then StartPollTimers()
    else
        StopPollTimers()
    end if
end sub

sub ShowQrSkeleton(show as boolean)
    m.qrSkeleton.visible = show
    m.qrSkeleton.running = show
    if show then
        m.qrImage.visible = false
        m.qrErrorLabel.visible = false
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
    m.onboardInFlight = false

    api = m.onboardTask.apiResult
    if api = invalid or not api.ok or api.result = invalid then
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
    m.userCodeLabel.text = FormatQRCodeNumber(userCode)

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

    ' Only complete when tokens arrive — pending/empty result keeps polling (web parity).
    if api.ok and api.result <> invalid and HasLoginTokens(api.result) then
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
    m.formError.visible = false
    m.formError.text = ""
    if not ValidateEmail(m.email) or m.password = "" then
        m.formError.text = CopyFormInvalid()
        m.formError.visible = true
        return
    end if

    m.loginSpinner.visible = true
    path = Endpoints().LOGIN.EMAIL_TOKEN
    m.emailTask = ApiPatch(path, { email: m.email, password: m.password })
    m.emailTask.observeField("apiResult", "OnEmailResponse")
    StartHttpTask(m.emailTask)
end sub

sub OnEmailResponse()
    m.loginSpinner.visible = false
    api = m.emailTask.apiResult
    if api = invalid or not api.ok or api.result = invalid then
        if api <> invalid and api.message <> "" then
            m.formError.text = api.message
        else
            m.formError.text = CopyInvalidCredentials()
        end if
        m.formError.visible = true
        MaybeToastApiError(api)
        return
    end if

    token = api.result
    vm = FindViewManager(m.top)

    if token.nextStep = NextStepDeviceLimit() then
        ApplyLoginTokens(token)
        ShowAlert(m.top, 2, MsgDeviceLimitExceeded())
        if vm <> invalid then
            vm.callFunc("NavigateReplace", RouteLoginProfile(), { directLogin: true })
        end if
        return
    end if

    if token.authToken <> invalid and token.authToken <> "" then
        deviceToken = {
            cognitoAccessToken: token.authToken
            cognitoRefreshToken: token.refreshToken
            nextStep: token.nextStep
        }
        HandleLoginRedirect(deviceToken, vm, m.top)
    else
        m.formError.text = CopyInvalidCredentials()
        m.formError.visible = true
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
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    if field = "email" then
        dialog.title = CopyEmailHint()
    else
        dialog.title = CopyPasswordHint()
    end if
    dialog.text = initial
    dialog.buttons = ["OK", "Cancel"]

    kb = dialog.findNode("keyboard")
    if kb <> invalid then kb.secureMode = secure

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
            m.focusIndex = m.FOCUS_REMOTE_TAB
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
    else if key = "OK" then
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
