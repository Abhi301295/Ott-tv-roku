' HeaderMenu.brs — top-bar menu entries (parity with HeaderList.ts MENU_LIST,
' filtered by the reels feature flag like ottHeader.tsx menuList).

function HM_TypeSingleVideo() as string
    return "SINGLE_VIDEO"
end function

function HM_TypeSeries() as string
    return "SERIES_AND_EPISODES"
end function

function HeaderMenuItems(reelsEnabled as boolean) as object
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
