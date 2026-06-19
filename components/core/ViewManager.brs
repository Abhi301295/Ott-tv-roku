sub init()
    m.screenHost = m.top.findNode("screenHost")
    m.appHeader = m.top.findNode("appHeader")
    m.stack = []
    m.menuItems = []
    m.shellMenuBuilt = false
    m.shellMenuReels = invalid
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

' Tear down every screen in the stack and show a fresh route (logout / session reset).
function NavigateClearAndReplace(route as string, state = {} as object) as void
    depth = m.stack.Count()
    ProfileSelectLog("NAV_CLEAR", "route=" + route + " stackDepth=" + ProfileSelectFmt(depth))
    while m.stack.Count() > 0
        entry = m.stack[m.stack.Count() - 1]
        if entry.screen <> invalid then
            if entry.screen.hasField("visible") then entry.screen.visible = false
            if entry.screen.hasField("dispose") then entry.screen.dispose = true
            m.screenHost.removeChild(entry.screen)
        end if
        m.stack.Pop()
    end while
    DrainHttpQueueForNavigation()
    ShowRoute(route, state, false)
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
        if prev.screen.hasField("stackResumed") then prev.screen.stackResumed = true
    end if
    m.top.currentRoute = prev.route
    m.top.navState = prev.state
    SetupAppHeader(m.top, prev.route, prev.state)
    m.top.overlayOpen = false
    return true
end function

sub ShowRoute(route as string, state as object, replace as boolean)
    mode = "push"
    if replace then mode = "replace"
    ProfileSelectLog("NAV", mode + " route=" + route + " stackDepth=" + ProfileSelectFmt(m.stack.Count()))
    if replace and m.stack.Count() > 0 then
        entry = m.stack[m.stack.Count() - 1]
        TeardownReplacedScreen(entry.screen)
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
    SetupAppHeader(m.top, route, state)
    AssignScreenNavState(screen, state)
    screen.setFocus(true)
end sub

sub AssignScreenNavState(screen as object, state as object)
    if screen = invalid then return
    if screen.hasField("navState") then screen.navState = state
end sub

function HandleShellKey(key as string, press as boolean) as boolean
    if not press then return false
    return AppShellHandleHeaderKey(m.top, key)
end function

' Replace navigation: pause the outgoing screen, dispose it, and drop any HTTP jobs
' still waiting in the pool queue so Movies (or any new route) is not starved by Home
' boot fetches the user abandoned mid-load.
sub TeardownReplacedScreen(screen as object)
    if screen = invalid then return
    if screen.hasField("visible") then screen.visible = false
    if screen.hasField("dispose") then screen.dispose = true
    DrainHttpQueueForNavigation()
    m.screenHost.removeChild(screen)
end sub

function CreateScreenForRoute(route as string, state as object) as object
    if route = RouteLogin() then
        return CreateObject("roSGNode", "LoginScreen")
    end if
    if route = RouteLoginProfile() then
        return CreateObject("roSGNode", "ProfileScreen")
    end if
    if route = RouteHome() then
        return CreateObject("roSGNode", "HomeScreen")
    end if
    if route = RouteDetail() then
        return CreateObject("roSGNode", "DetailScreen")
    end if
    if route = RouteVideoPlayer() then
        return CreateObject("roSGNode", "VideoPlayerScreen")
    end if
    if route = RouteSeriesEpisodes() then
        return CreateObject("roSGNode", "SeriesEpisodesScreen")
    end if
    if route = RouteGenere() then
        return CreateObject("roSGNode", "GenreListScreen")
    end if
    if route = RouteSearch() then
        return CreateObject("roSGNode", "SearchScreen")
    end if
    if route = RouteMyListDetail() then
        return CreateObject("roSGNode", "MyListDetailScreen")
    end if
    if route = RouteSeries() or route = RouteNewRelease() then
        return CreateObject("roSGNode", "SeriesScreen")
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
