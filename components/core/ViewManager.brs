sub init()
    m.screenHost = m.top.findNode("screenHost")
    m.stack = []
    m.top.overlayOpen = false
    m.top.observeField("overlayDismiss", "OnOverlayDismissChanged")
end sub

' Push a new screen (keeps stack).
function NavigatePush(route as string, state = {} as object) as void
    ShowRoute(route, state, false)
end function

' Replace current screen (no stack growth).
function NavigateReplace(route as string, state = {} as object) as void
    ShowRoute(route, state, true)
end function

' Pop the top screen and reveal the one beneath it (true if a pop happened). Returning
' to a live instance avoids stacking fresh screens (e.g. a second HomeScreen whose hero
' would keep auto-rotating underneath).
function NavigatePop() as boolean
    if m.stack.Count() <= 1 then return false

    top = m.stack[m.stack.Count() - 1]
    if top.screen <> invalid then
        if top.screen.hasField("dispose") then top.screen.dispose = true
        m.screenHost.removeChild(top.screen)
    end if
    m.stack.Pop()

    prev = m.stack[m.stack.Count() - 1]
    if prev.screen <> invalid then
        ' Reveal the screen we're returning to — its visibility observer resumes any
        ' paused media (HomeScreen's hero trailer/carousel).
        prev.screen.visible = true
        prev.screen.setFocus(true)
    end if
    m.top.currentRoute = prev.route
    m.top.navState = prev.state
    m.top.overlayOpen = false
    return true
end function

sub ShowRoute(route as string, state as object, replace as boolean)
    if replace and m.stack.Count() > 0 then
        entry = m.stack[m.stack.Count() - 1]
        if entry.screen <> invalid then
            ' Let the screen tear down its timers/video before it leaves the tree —
            ' removeChild alone doesn't stop child Timers, which would keep an orphaned
            ' HomeScreen's hero auto-rotating (stacked instances) after navigation.
            if entry.screen.hasField("dispose") then entry.screen.dispose = true
            m.screenHost.removeChild(entry.screen)
        end if
        m.stack.Pop()
    else if not replace and m.stack.Count() > 0 then
        ' Push: pause the screen being covered so its timers/video/hero stop ticking in
        ' the background. Its visibility observer handles the actual teardown.
        covered = m.stack[m.stack.Count() - 1]
        if covered.screen <> invalid then covered.screen.visible = false
    end if

    screen = CreateScreenForRoute(route, state)
    m.screenHost.appendChild(screen)

    m.stack.Push({
        route: route
        state: state
        screen: screen
    })

    m.top.currentRoute = route
    m.top.navState = state
    screen.setFocus(true)
end sub

function CreateScreenForRoute(route as string, state as object) as object
    if route = RouteLogin() then
        screen = CreateObject("roSGNode", "LoginScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteLoginProfile() then
        screen = CreateObject("roSGNode", "ProfileScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteHome() then
        screen = CreateObject("roSGNode", "HomeScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteDetail() then
        screen = CreateObject("roSGNode", "DetailScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteVideoPlayer() then
        screen = CreateObject("roSGNode", "VideoPlayerScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteSeriesEpisodes() then
        screen = CreateObject("roSGNode", "SeriesEpisodesScreen")
        screen.navState = state
        return screen
    end if
    if route = RouteSeries() then
        screen = CreateObject("roSGNode", "SeriesScreen")
        screen.navState = state
        return screen
    end if
    return CreatePlaceholderScreen(route, state)
end function

function CreatePlaceholderScreen(route as string, state as object) as object
    group = CreateObject("roSGNode", "Group")
    group.id = "screen_" + route

    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = 1920
    bg.height = 1080
    bg.color = "0x0b1120"
    group.appendChild(bg)

    label = CreateObject("roSGNode", "Label")
    label.text = "Screen: " + route
    label.translation = [800, 520]
    group.appendChild(label)

    return group
end function

' Pop overlay dismiss flag after handlers run.
sub OnOverlayDismissChanged()
    if m.top.overlayDismiss = true then
        m.top.overlayDismiss = false
        m.top.overlayOpen = false
    end if
end sub
