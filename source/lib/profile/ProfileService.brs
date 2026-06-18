' ProfileService.brs — profile selection helpers (parity with profile/services/action.ts).
' Network orchestration (task create + observe) lives in ProfileScreen; these are the
' pure helpers: payloads, endpoint/token selection, response parsing, persistence.

' Extract the profile array from the GET profiles/list result envelope.
function ExtractProfiles(result as object) as object
    if result = invalid then return []
    if result.data <> invalid then return result.data
    return []
end function

' Persist meta the rest of the app reads later (parity with fetchProfiles side effects):
' first profile id => home, second => kid, first avatar => avatar.
sub SaveProfilesMeta(profiles as object)
    if profiles = invalid or profiles.Count() = 0 then return

    first = profiles[0]
    if first <> invalid and first._id <> invalid then
        SetValueByKey(SK_HomeProfileId(), first._id, "app")
    end if
    if first <> invalid and first.avatar <> invalid then
        SetValueByKey(SK_Avatar(), first.avatar, "app")
    end if

    if profiles.Count() > 1 then
        second = profiles[1]
        if second <> invalid and second._id <> invalid then
            SetValueByKey(SK_KidProfileId(), second._id, "app")
        end if
    end if
end sub

' Kid or unlocked profiles select directly; locked (non-kid) profiles require a PIN.
function ProfileNeedsPin(profile as object) as boolean
    if profile = invalid then return false
    if profile.isKid = true then return false
    return (profile.parentalLock = true)
end function

' Web: use SELECT_PROFILE when an access token exists, else the before-login endpoint.
function SelectProfilePath() as string
    ep = Endpoints()
    if GetAccessToken() <> "" then
        return ep.PROFILE.SELECT_PROFILE
    end if
    return ep.PROFILE.SELECT_PROFILE_TO_WATCH_BEFORE_LOGIN
end function

function SelectProfilePayload(profileId as string) as object
    return {
        profileId: profileId
        deviceId: GetDeviceId()
    }
end function

function VerifyPinPath() as string
    return Endpoints().PROFILE.VERIFY_PIN_BEFORE_LOGIN
end function

function VerifyPinPayload(profileId as string, pin as string) as object
    return {
        profileId: profileId
        pin: pin
        deviceId: GetDeviceId()
    }
end function

' Classify a select-profile HTTP status. A freshly-issued login token is briefly not yet
' active on the backend, so 401/404 — and transport-level failures (status <= 0) — are
' transient and worth retrying before surfacing an error. Single source of truth shared by
' the profile screen (PIN path) and the home boot select.
function SelectProfileRetriable(httpStatus as integer) as boolean
    return (httpStatus = 401 or httpStatus <= 0)
end function

' GET profiles uses the same transient-failure rules as select-profile.
function ProfileFetchRetriable(httpStatus as integer) as boolean
    return SelectProfileRetriable(httpStatus)
end function

' Persist the active profile identity after a successful select-profile. SaveProfilesMeta
' only ever stores profile #1's avatar, so the explicitly-chosen avatar is written here
' too — otherwise the home header would be stuck on the first profile's image.
sub PersistSelectedProfile(profileId as string, avatar as string)
    SetProfileId(profileId)
    if avatar <> "" then SetValueByKey(SK_Avatar(), avatar, "app")
end sub

' Store tokens returned by select-profile. Returns true when a valid token pair
' arrived (parity with the statusCode 200 + authToken + refreshToken check).
function ApplySelectProfileTokens(result as object) as boolean
    if result = invalid then return false
    authToken = result.authToken
    refreshToken = result.refreshToken
    if authToken = invalid or authToken = "" then return false
    if refreshToken = invalid or refreshToken = "" then return false

    SetAccessToken(authToken)
    SetRefreshToken(refreshToken)
    return true
end function

' PIN verify success accepts statusCode 200 as int or string (web compares "200").
function IsPinVerified(api as object) as boolean
    if api = invalid then return false
    if not api.ok then return false
    sc = api.statusCode
    return (sc = 200 or sc = "200")
end function

' First+last initial (parity with getInitials).
function ProfileInitials(name as dynamic) as string
    if name = invalid or name = "" then return ""
    trimmed = name.Trim()
    if trimmed = "" then return ""
    parts = trimmed.Split(" ")
    first = parts[0]
    if parts.Count() = 1 then
        return UCase(Left(first, 1))
    end if
    last = parts[parts.Count() - 1]
    return UCase(Left(first, 1) + Left(last, 1))
end function
