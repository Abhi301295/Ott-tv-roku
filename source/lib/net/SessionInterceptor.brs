' SessionInterceptor.brs
' Global session-expiry side effects (parity with axios 403 handler + logoutSession).
' ProcessApiResponse flags shouldLogout; HttpClient calls ApplyGlobalSessionExpiry
' when any request completes so individual screens do not each handle navigation.

function GetGlobalViewManager() as object
    if m.global <> invalid and m.global.viewManager <> invalid then
        return m.global.viewManager
    end if
    return invalid
end function

sub ApplyGlobalSessionExpiry(api as object)
    if api = invalid or api.shouldLogout <> true then return

    vm = GetGlobalViewManager()
    if vm = invalid then return
    if vm.currentRoute = RouteLogin() then return

    ' Parallel 401s can complete together — handle the redirect once.
    if m.global <> invalid and m.global.sessionLogoutInFlight = true then return
    if m.global <> invalid then m.global.sessionLogoutInFlight = true

    ' HttpWorker clears storage when shouldLogout is set; repeat defensively (idempotent).
    ClearStorage()

    msg = "Session expired. Please log in again."
    if api.message <> invalid and api.message <> "" then msg = api.message

    scene = vm.getScene()
    if scene <> invalid and scene.hasField("alertMessage") then
        scene.alertType = 2
        scene.alertMessage = msg
    end if

    print "[AUTH_DBG] session expired -> NavigateClearAndReplace login route="; vm.currentRoute
    vm.callFunc("NavigateClearAndReplace", RouteLogin(), {})
end sub

' Returns true when the global session interceptor will handle this response.
function ApiSessionEnded(api as object) as boolean
    return api <> invalid and api.shouldLogout = true
end function
