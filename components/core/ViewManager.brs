sub init()
    m.screenHost = m.top.findNode("screenHost")
    m.appHeader = m.top.findNode("appHeader")
    m.stack = []
    m.menuItems = []
    m.shellMenuBuilt = false
    m.shellMenuReels = invalid
    m.top.overlayOpen = false
    m.homeBootCache = invalid
    m.homeCatalogDirty = false
    m.top.observeField("overlayDismiss", "OnOverlayDismissChanged")
end sub

function MarkHomeCatalogDirty() as void
    m.homeCatalogDirty = true
end function

function IsHomeCatalogDirty() as boolean
    return m.homeCatalogDirty = true
end function

function ClearHomeCatalogDirty() as void
    m.homeCatalogDirty = false
end function

function GetHomeBootCacheEntry() as object
    return m.homeBootCache
end function

function SetHomeBootCacheEntry(entry as object) as void
    m.homeBootCache = entry
end function

function ClearHomeBootCacheEntry() as void
    m.homeBootCache = invalid
end function

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
    ProfileTransitionHide(m.top)
    ClearHomeBootCacheEntry()
    m.homeCatalogDirty = false
    depth = m.stack.Count()
    ProfileSelectLog("NAV_CLEAR", "route=" + route + " stackDepth=" + ProfileSelectFmt(depth))
    while m.stack.Count() > 0
        entry = m.stack[m.stack.Count() - 1]
        if entry.screen <> invalid then
            ScreenDestroy(entry.screen)
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
        ScreenDestroy(top.screen)
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
        covered = m.stack[m.stack.Count() - 1]
        if covered.screen <> invalid then ScreenPause(covered.screen)
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
    ScreenDestroy(screen)
    DrainHttpQueueForNavigation()
    m.screenHost.removeChild(screen)
end sub

sub OnOverlayDismissChanged()
    if m.top.overlayDismiss = true then
        m.top.overlayDismiss = false
        m.top.overlayOpen = false
    end if
end sub
