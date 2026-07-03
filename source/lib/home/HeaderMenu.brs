' HeaderMenu.brs — top-bar menu entries (parity with HeaderList.ts MENU_LIST,
' filtered by reelsEnabled and epgManagement like ottHeader.tsx menuList).

function HM_TypeSingleVideo() as string
    return "SINGLE_VIDEO"
end function

function HM_TypeSeries() as string
    return "SERIES_AND_EPISODES"
end function

' Read feature flags from business config + ThemeManager (post-resolve overrides).
function HeaderMenuFeatureFlags(fromNode as object) as object
    reels = false
    epg = false
    scene = invalid
    if fromNode <> invalid then scene = fromNode.getScene()
    if scene <> invalid and scene.global <> invalid then
        resolved = scene.global.businessResolved
        if resolved <> invalid then
            reels = IsFeatureEnabled(resolved, "reelsEnabled")
            epg = IsFeatureEnabled(resolved, "epgManagement")
        end if
    end if
    tm = invalid
    if scene <> invalid then tm = scene.findNode("themeManager")
    if tm <> invalid and tm.reelsEnabled = true then reels = true
    if tm <> invalid and tm.epgEnabled = true then epg = true
    return { reels: reels, epg: epg }
end function

' Order matches HeaderList.ts: Profile before Reels; Live TV after Reels.
function HeaderMenuItems(reelsEnabled as boolean, epgEnabled as boolean) as object
    items = [
        { text: "Home", route: RouteHome(), type: "" }
        { text: "Search", route: RouteSearch(), type: "" }
        { text: "Movies", route: RouteGenere(), type: HM_TypeSingleVideo() }
        { text: "Series", route: RouteGenere(), type: HM_TypeSeries() }
        { text: "My Watchlist", route: RouteMyListDetail(), type: "" }
        { text: "Profile", route: RouteLoginProfile(), type: "" }
    ]
    if reelsEnabled then
        items.Push({ text: "Reels", route: RouteReels(), type: "" })
    end if
    if epgEnabled then
        items.Push({ text: "Live TV", route: RouteLiveTv(), type: "" })
    end if
    return items
end function

' Index of the menu entry whose route matches the active screen (defaults to Home).
function HeaderSelectedIndex(items as object, route as string) as integer
    if items = invalid then return 0
    for i = 0 to items.Count() - 1
        if items[i] <> invalid and items[i].route = route then return i
    end for
    return 0
end function
