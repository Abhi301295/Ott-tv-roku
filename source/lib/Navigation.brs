' Navigation.brs
' Back / exit behavior (parity with navigationService.ts).

function NavigationHandleBack(viewManager as object) as boolean
    ' 1) Close overlay first (More Like This, settings, etc.)
    if viewManager <> invalid and viewManager.overlayOpen = true then
        viewManager.overlayDismiss = true
        return true
    end if

  ' 2) Route-based back
    if viewManager = invalid then return false

    route = viewManager.currentRoute
    if route = "" then route = RouteLogin()

    if not IsAuthenticatedForNav() then
        viewManager.callFunc("NavigateReplace", RouteLogin(), {})
        return true
    end if

    if route = RouteHome() then
        ExitApp(viewManager)
        return true
    end if

    ' Any other screen → Home (replace), same as web
    viewManager.callFunc("NavigateReplace", RouteHome(), {})
    return true
end function

' Parity with navigationService: access OR refresh only.
function IsAuthenticatedForNav() as boolean
    if GetAccessToken() <> "" then return true
    if GetRefreshToken() <> "" then return true
    return false
end function

function ExitApp(fromNode as object) as void
    scene = fromNode.getScene()
    if scene <> invalid then
        scene.close()
    end if
end function

function GetInitialRoute() as string
    ' TEMP (login-only branch): always boot into Login so we can see + test the login
    ' flow. A leftover session must not route us to other screens yet. Restore the
    ' session check below once post-login navigation is implemented.
    ' if HasActiveSession() then
    '     return RouteLoginProfile()
    ' end if
    return RouteLogin()
end function
