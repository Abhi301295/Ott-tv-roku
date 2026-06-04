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

sub ShowRoute(route as string, state as object, replace as boolean)
    if replace and m.stack.Count() > 0 then
        entry = m.stack[m.stack.Count() - 1]
        if entry.screen <> invalid then
            m.screenHost.removeChild(entry.screen)
        end if
        m.stack.Pop()
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
