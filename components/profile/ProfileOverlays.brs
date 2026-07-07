' ProfileOverlays.brs — confirm logout, OTP pin, and overlay dismiss.


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

