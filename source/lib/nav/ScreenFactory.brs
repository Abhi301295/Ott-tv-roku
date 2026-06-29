' ScreenFactory.brs — route string → SceneGraph screen node (ViewManager consumer).

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
    if route = RouteReels() then
        return CreateObject("roSGNode", "ReelsScreen")
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
