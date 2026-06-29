' SessionInterceptor.brs
' Global session-expiry side effects when ProcessApiResponse sets shouldLogout on
' apiResult. HttpClient.WatchRequest observes apiResult before screen handlers so
' navigation runs first; screens never read shouldLogout.

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
    if m.global <> invalid then m.global.sessionLogoutInFlight = false
end sub
