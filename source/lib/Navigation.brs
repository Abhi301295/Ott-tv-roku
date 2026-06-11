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

    ' Profile selection swallows Back (web pushes history to block it). Stay put.
    if route = RouteLoginProfile() then
        return true
    end if

    if route = RouteHome() then
        ExitApp(viewManager)
        return true
    end if

    ' Any other screen → return to the previous screen. Pop to the live instance in the
    ' stack when one exists (so we don't stack a fresh HomeScreen + leave the old one's
    ' hero running underneath); otherwise fall back to replacing with Home.
    if viewManager.callFunc("NavigatePop") = true then return true
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
    ' Scene has no close(); signal main.brs (which owns roSGScreen) to close instead.
    scene = fromNode.getScene()
    if scene <> invalid and scene.hasField("exitChannel") then
        scene.exitChannel = true
    end if
end function

function GetInitialRoute() as string
    ' If a session already exists, boot straight into profile selection
    ' (parity with web's authenticated-route guard); otherwise show Login.
    if HasActiveSession() then
        return RouteLoginProfile()
    end if
    return RouteLogin()
end function
