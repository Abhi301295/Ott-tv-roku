' LoginService.brs — device onboard, token poll, redirect (parity with login services).

' Included by LoginScreen; MsgDeviceLimitExceeded lives in LoginCopy.brs.

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

    if nextStep = NextStepSelectProfile() then
        SetValueByKey(SK_SelectedItem(), "Home", "app")
        viewManager.callFunc("NavigateReplace", RouteHome(), {})
        return
    end if

    if nextStep = NextStepHomePage() then
        viewManager.callFunc("NavigateReplace", RouteLoginProfile(), { directLogin: true })
        return
    end if

    ' Web navigates to LOGIN for unknown nextStep; on Roku that re-mounts LoginScreen
    ' and re-fetches QR — stay on login until poll returns a known nextStep + tokens.
end sub

function FindViewManager(fromNode as object) as object
    scene = fromNode.getScene()
    if scene = invalid then return invalid
    return scene.findNode("viewManager")
end function
