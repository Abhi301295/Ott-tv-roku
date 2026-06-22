' LoginService.brs — device onboard, token poll, redirect (parity with login services).

' Included by LoginScreen; MsgDeviceLimitExceeded lives in LoginStrings.brs.

function LoginDevicePayload() as object
    return {
        clientId: GetDeviceId()
        name: "RokuTV"
    }
end function

function FormatQRCodeNumber(code as string) as string
    if code = invalid or code = "" then return ""
    out = ""
    for i = 1 to Len(code)
        if i > 1 and ((i - 1) mod 4) = 0 then out = out + "-"
        out = out + Mid(code, i, 1)
    end for
    return out
end function

' QR image for the device code (web generates this client-side via react-qr-code;
' Roku has no native QR node, so render a scannable PNG from the same userCode).
function QrImageUrl(userCode as string, sizePx as integer) as string
    if userCode = invalid or userCode = "" then return ""
    s = Stri(sizePx).Trim()
    return "https://api.qrserver.com/v1/create-qr-code/?size=" + s + "x" + s + "&margin=0&data=" + UrlEncode(userCode)
end function

' Minimal percent-encoding (device codes are alphanumeric, but be safe).
function UrlEncode(value as string) as string
    out = ""
    for i = 1 to Len(value)
        ch = Mid(value, i, 1)
        if (ch >= "0" and ch <= "9") or (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or ch = "-" or ch = "_" or ch = "." then
            out = out + ch
        else
            ba = CreateObject("roByteArray")
            ba.FromAsciiString(ch)
            out = out + "%" + UCase(ba.ToHexString())
        end if
    end for
    return out
end function

' Poll/onboard is only "done" when the API returns session tokens (web: if (loginDeviceToken)).
function HasLoginTokens(result as object) as boolean
    if result = invalid then return false
    if result.authToken <> invalid and result.authToken <> "" then return true
    if result.cognitoAccessToken <> invalid and result.cognitoAccessToken <> "" then return true
    return false
end function

function IsAuthPendingMessage(message as string) as boolean
    if message = invalid or message = "" then return false
    return Instr(1, LCase(message), "authorization pending") > 0
end function

sub ApplyLoginTokens(deviceToken as object)
    if deviceToken = invalid then return

    accessToken = deviceToken.authToken
    if accessToken = invalid or accessToken = "" then
        accessToken = deviceToken.cognitoAccessToken
    end if

    refreshToken = deviceToken.refreshToken
    if refreshToken = invalid or refreshToken = "" then
        refreshToken = deviceToken.cognitoRefreshToken
    end if

    if accessToken <> invalid and accessToken <> "" then
        SetAccessToken(accessToken)
        SetCognitoToken(accessToken)
    end if
    if refreshToken <> invalid and refreshToken <> "" then
        SetRefreshToken(refreshToken)
    end if
end sub

' Refresh session (parity with checkRefreshToken in login/services/action.ts).
' API may return result as { authToken } or a raw JWT string in result.
function ApplyRefreshTokens(result as dynamic) as boolean
    if result = invalid then return false

    rt = type(result)
    if rt = "roString" or rt = "String" then
        tok = result
        if tok = "" then return false
        SetAccessToken(tok)
        SetCognitoToken(tok)
        print "[PROFILE_FETCH_DBG] refresh applied access token (string result)"
        return true
    end if

    if rt <> "roAssociativeArray" and rt <> "AssocArray" then return false

    authToken = invalid
    if result.authToken <> invalid then authToken = result.authToken
    if (authToken = invalid or authToken = "") and result.cognitoAccessToken <> invalid then
        authToken = result.cognitoAccessToken
    end if
    if authToken = invalid or authToken = "" then return false

    SetAccessToken(authToken)
    SetCognitoToken(authToken)

    refreshToken = invalid
    if result.refreshToken <> invalid then refreshToken = result.refreshToken
    if (refreshToken = invalid or refreshToken = "") and result.cognitoRefreshToken <> invalid then
        refreshToken = result.cognitoRefreshToken
    end if
    if refreshToken <> invalid and refreshToken <> "" then
        SetRefreshToken(refreshToken)
    end if
    print "[PROFILE_FETCH_DBG] refresh applied access token (object result)"
    return true
end function

' Navigate after successful login (parity with handleRedirect in login/index.tsx).
sub HandleLoginRedirect(deviceToken as object, viewManager as object, fromNode = invalid as object)
    if deviceToken = invalid or viewManager = invalid then return

    nextStep = deviceToken.nextStep
    if nextStep = invalid then nextStep = ""

    if nextStep = NextStepDeviceLimit() then
        RegistryDelete(SK_CognitoToken(), "auth")
        RegistryDelete(SK_CognitoRefreshToken(), "auth")
        RegistryDelete(SK_RefreshToken(), "auth")
        if fromNode <> invalid then
            ShowAlert(fromNode, 2, MsgDeviceLimitExceeded())
        end if
        return
    end if

    ApplyLoginTokens(deviceToken)

    ' Web: SelectProfile(60) → Home (profile already chosen server-side);
    '      HomePage(40)      → profile picker.
    ' TEMP (profile branch): Home isn't built yet, so the 60 case also lands on the
    ' profile picker. Restore the Home navigation below once the Home screen exists.
    if nextStep = NextStepSelectProfile() then
        SetValueByKey(SK_SelectedItem(), "Home", "app")
        ' viewManager.callFunc("NavigateReplace", RouteHome(), {})
        viewManager.callFunc("NavigateReplace", RouteLoginProfile(), { directLogin: true })
        return
    end if

    if nextStep = NextStepHomePage() then
        viewManager.callFunc("NavigateReplace", RouteLoginProfile(), { directLogin: true })
        return
    end if

    ' Web navigates to LOGIN for unknown nextStep; on Roku that re-mounts LoginScreen
    ' and re-fetches QR — stay on login until poll returns a known nextStep + tokens.
end sub

' Session-expiry handler — parity with axios.instance.ts 403 handler + logoutSession():
' when an API result is flagged shouldLogout (HTTP 403), clear all tokens and send
' the user back to Login. Returns true when it handled a logout so the caller can
' stop processing the (now invalid) response.
function HandleSessionExpiry(fromNode as object, api as object) as boolean
    if api = invalid then return false
    if api.shouldLogout <> true then return false

    ' HttpTask already clears storage on shouldLogout; repeat defensively (idempotent)
    ' so this also works when called from non-task paths.
    ClearStorage()

    msg = "Session expired. Please log in again."
    if api.message <> invalid and api.message <> "" then msg = api.message
    ShowAlert(fromNode, 2, msg)

    ' Replace with Login — but not if we're already on Login (avoids a reload loop
    ' when a pre-login call on the login screen itself returns 403).
    vm = FindViewManager(fromNode)
    if vm <> invalid and vm.currentRoute <> RouteLogin() then
        vm.callFunc("NavigateReplace", RouteLogin(), {})
    end if
    return true
end function
