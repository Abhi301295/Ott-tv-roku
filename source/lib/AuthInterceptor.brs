' AuthInterceptor.brs
' Request auth header selection (parity with axios.instance.ts interceptors).

function BuildDefaultHeaders() as object
    cfg = AppConfig()
    return {
        "Content-Type": "application/json"
        "domain-name": cfg.businessDomain
        "Accept-Language": "EN"
        "accept": "application/json"
        "Platform": "4"
        "Timezone": GetDeviceTimezone()
    }
end function

' Picks Bearer access / refresh / Basic auth based on URL path substring.
function ApplyAuthHeader(url as string, headers as object) as object
    ep = Endpoints()
    authToken = GetAccessToken()
    refreshToken = GetRefreshToken()
    authKey = GetAuthBase64Key()

    ' Profile flows (web uses access token for these paths)
    if authToken <> "" and (
        Instr(1, url, ep.PROFILE.GET_LOGIN_PROFILES) > 0 or
        Instr(1, url, ep.PROFILE.SELECT_PROFILE_TO_WATCH_BEFORE_LOGIN) > 0 or
        Instr(1, url, ep.PROFILE.VERIFY_PIN_BEFORE_LOGIN) > 0
    ) then
        headers["authorization"] = "Bearer " + authToken
        return headers
    end if

    ' Media / content APIs
    if authToken <> "" and (
        Instr(1, url, ep.HOME.CATEGORY_LIST) > 0 or
        Instr(1, url, ep.HOME.CONTINUE_WATCHING) > 0 or
        Instr(1, url, ep.PROFILE.SELECT_PROFILE) > 0 or
        Instr(1, url, ep.SERIES.GENERE_LIST) > 0 or
        Instr(1, url, ep.DETAIL.CONTENT_VIEW) > 0 or
        Instr(1, url, ep.DETAIL.WATCH_LIST) > 0 or
        Instr(1, url, ep.DETAIL.SAVE_WATCH_LIST) > 0 or
        Instr(1, url, ep.DETAIL.UPDATE_VIDEO_PROGRESS) > 0 or
        Instr(1, url, ep.DETAIL.RECOMENDED_VIDEOS) > 0 or
        Instr(1, url, ep.COOKIES.GET_COOKIES) > 0 or
        Instr(1, url, ep.SEARCH.SEARCH_LIST) > 0 or
        Instr(1, url, ep.GET_NEW_RELEASE_LIST) > 0 or
        Instr(1, url, ep.SERIES.SERIES_LIST) > 0 or
        Instr(1, url, ep.MY_LIST.MY_LIST_LISTING) > 0 or
        Instr(1, url, ep.MY_LIST.MY_LIST_DETAIL) > 0 or
        Instr(1, url, ep.SAVE_AD_VIEW) > 0 or
        Instr(1, url, ep.REELS_LIST) > 0
    ) then
        headers["authorization"] = "Bearer " + authToken
        return headers
    end if

    ' Logout / refresh session
    if refreshToken <> "" and (
        Instr(1, url, ep.LOGIN.LOGOUT_SESSION) > 0 or
        Instr(1, url, ep.LOGIN.REFRESH_TOKEN) > 0
    ) then
        headers["authorization"] = "Bearer " + refreshToken
        return headers
    end if

    ' Version / configuration check
    if authKey <> "" and Instr(1, url, ep.LOGIN.CHECK_UPDATE) > 0 then
        headers["authorization"] = authKey
        return headers
    end if

    ' Pre-login fallback
    if authKey <> "" then
        headers["authorization"] = authKey
    end if

    return headers
end function

function GetDeviceTimezone() as string
    tz = RegistryRead(SK_TimeZone(), "app")
    if tz <> "" then return tz
    return "UTC"
end function

' Returns true when the UI should NOT show an error toast (422, device-token 401).
function ShouldSuppressErrorToast(url as string, httpStatus as integer, body as object) as boolean
    if httpStatus = 422 then return true

    if httpStatus = 401 and Instr(1, url, "/media/v1/device/token") > 0 then
        return true
    end if

    return false
end function

' Parse response envelope; set shouldLogout on 403 (parity with axios 403 handler).
function ProcessApiResponse(url as string, httpStatus as integer, responseText as string) as object
    result = {
        ok: false
        httpStatus: httpStatus
        statusCode: httpStatus
        message: ""
        result: invalid
        shouldLogout: false
        suppressToast: false
    }

    body = invalid
    if responseText <> "" then
        body = ParseJson(responseText)
    end if

    if body <> invalid and body.statusCode <> invalid then
        result.statusCode = body.statusCode
    end if

    if body <> invalid and body.message <> invalid then
        result.message = body.message
    end if

    if body <> invalid and body.result <> invalid then
        result.result = body.result
    end if

    if result.statusCode = 403 then
        result.shouldLogout = true
        result.ok = false
        return result
    end if

    if result.statusCode = 422 then
        result.suppressToast = true
        result.ok = false
        return result
    end if

    result.suppressToast = ShouldSuppressErrorToast(url, httpStatus, body)

    if httpStatus >= 200 and httpStatus < 300 then
        result.ok = true
    end if

    return result
end function
