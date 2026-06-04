' Registry.brs
' Persistent storage via roRegistry (parity with storage-service.tsx + StorageKey).
'
' Sections:
'   auth  — tokens
'   app   — profile, device, UI prefs, subscription flags

' ── Storage key names (match web StorageKey enum) ───────────────────────────

function SK_AuthToken() as string: return "authToken": end function
function SK_RefreshToken() as string: return "refreshToken": end function
function SK_CognitoToken() as string: return "cognitotoken": end function
function SK_CognitoRefreshToken() as string: return "cognitorefreshtoken": end function
function SK_ProfileId() as string: return "profileId": end function
function SK_DeviceId() as string: return "deviceId": end function
function SK_SelectedItem() as string: return "selectedItem": end function
function SK_HomeProfileId() as string: return "homeProfileId": end function
function SK_KidProfileId() as string: return "kidProfileId": end function
function SK_Avatar() as string: return "avatar": end function
function SK_IsSubscribed() as string: return "isSubscribed": end function
function SK_IsDefaultPlan() as string: return "isDefaultPlan": end function
function SK_ShowPremiumBadge() as string: return "showPremiumBadge": end function
function SK_Email() as string: return "email": end function
function SK_Phone() as string: return "phone": end function
function SK_CountryCode() as string: return "countryCode": end function
function SK_TimeZone() as string: return "timezone": end function

' ── Low-level read / write ───────────────────────────────────────────────────

function RegistryRead(key as string, section = "auth" as string) as string
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then
        val = ""
        sec.Read(key, val)
        return val
    end if
    return ""
end function

function RegistryWrite(key as string, value as string, section = "auth" as string) as void
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, value)
    sec.Flush()
end function

function RegistryDelete(key as string, section = "auth" as string) as void
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then
        sec.Delete(key)
        sec.Flush()
    end if
end function

' ── Tokens (auth section) ────────────────────────────────────────────────────

function GetAccessToken() as string
    return RegistryRead(SK_AuthToken(), "auth")
end function

function SetAccessToken(token as string) as void
    RegistryWrite(SK_AuthToken(), token, "auth")
end function

function GetRefreshToken() as string
    return RegistryRead(SK_RefreshToken(), "auth")
end function

function SetRefreshToken(token as string) as void
    RegistryWrite(SK_RefreshToken(), token, "auth")
end function

function GetCognitoToken() as string
    return RegistryRead(SK_CognitoToken(), "auth")
end function

function SetCognitoToken(token as string) as void
    RegistryWrite(SK_CognitoToken(), token, "auth")
end function

function GetCognitoRefreshToken() as string
    return RegistryRead(SK_CognitoRefreshToken(), "auth")
end function

function SetCognitoRefreshToken(token as string) as void
    RegistryWrite(SK_CognitoRefreshToken(), token, "auth")
end function

' Basic auth header for pre-login / config calls (parity with getAuthBase64Key).
function GetAuthBase64Key() as string
    cfg = AppConfig()
    user = cfg.basicAuthUser
    pass = cfg.basicAuthPassword
    if user = "" and pass = "" then return ""
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(user + ":" + pass)
    return "Basic " + ba.ToBase64String()
end function

' ── App section ──────────────────────────────────────────────────────────────

function GetProfileId() as string
    return RegistryRead(SK_ProfileId(), "app")
end function

function SetProfileId(id as string) as void
    RegistryWrite(SK_ProfileId(), id, "app")
end function

function GetDeviceId() as string
    id = RegistryRead(SK_DeviceId(), "app")
    if id <> "" then return id

    id = GenerateUUID()
    RegistryWrite(SK_DeviceId(), id, "app")
    return id
end function

function GetValueByKey(key as string) as string
    ' Try auth first, then app (parity with localStorage flat lookup).
    val = RegistryRead(key, "auth")
    if val <> "" then return val
    return RegistryRead(key, "app")
end function

function SetValueByKey(key as string, value as string, section = "app" as string) as void
    RegistryWrite(key, value, section)
end function

' True when any session token exists (parity with protected route check).
function HasActiveSession() as boolean
    if GetAccessToken() <> "" then return true
    if GetRefreshToken() <> "" then return true
    if GetCognitoToken() <> "" then return true
    return false
end function

' Logout: delete all known keys (roRegistry has no "clear section" API).
function ClearStorage() as void
    ClearAuthKeys()
    ClearAppKeys()
end function

sub ClearAuthKeys()
    keys = [
        SK_AuthToken()
        SK_RefreshToken()
        SK_CognitoToken()
        SK_CognitoRefreshToken()
    ]
    for each key in keys
        RegistryDelete(key, "auth")
    end for
end sub

sub ClearAppKeys()
    keys = [
        SK_ProfileId()
        SK_DeviceId()
        SK_SelectedItem()
        SK_HomeProfileId()
        SK_KidProfileId()
        SK_Avatar()
        SK_IsSubscribed()
        SK_IsDefaultPlan()
        SK_ShowPremiumBadge()
        SK_Email()
        SK_Phone()
        SK_CountryCode()
        SK_TimeZone()
    ]
    for each key in keys
        RegistryDelete(key, "app")
    end for
end sub

' ── UUID (device id) ─────────────────────────────────────────────────────────

function GenerateUUID() as string
    hex = "0123456789abcdef"
    uuid = ""
    for i = 0 to 35
        if i = 8 or i = 13 or i = 18 or i = 23
            uuid = uuid + "-"
        else if i = 14
            uuid = uuid + "4"
        else if i = 19
            r = Rnd(16)
            n = (r and 3) or 8
            uuid = uuid + hex.Mid(n, 1)
        else
            uuid = uuid + hex.Mid(Rnd(16), 1)
        end if
    end for
    return uuid
end function
