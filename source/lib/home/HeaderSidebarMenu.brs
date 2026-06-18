' HeaderSidebarMenu.brs — sidebar menu with icons (parity HeaderList.ts + HeaderMenuItem).

function SidebarMenuItems(reelsEnabled as boolean) as object
    items = [
        { text: "Home", route: RouteHome(), type: "", icon: "pkg:/images/ui/menu_home.png", iconActive: "pkg:/images/ui/menu_home_active.png" }
        { text: "Search", route: RouteSearch(), type: "", icon: "pkg:/images/ui/menu_search.png", iconActive: "pkg:/images/ui/menu_search_active.png" }
        { text: "Movies", route: RouteGenere(), type: HM_TypeSingleVideo(), icon: "pkg:/images/ui/menu_tv.png", iconActive: "pkg:/images/ui/menu_tv_active.png" }
        { text: "Series", route: RouteGenere(), type: HM_TypeSeries(), icon: "pkg:/images/ui/menu_play.png", iconActive: "pkg:/images/ui/menu_play_active.png" }
        { text: "My Watchlist", route: RouteMyListDetail(), type: "", icon: "pkg:/images/ui/menu_list.png", iconActive: "pkg:/images/ui/menu_list_active.png" }
    ]
    if reelsEnabled then
        items.Push({ text: "Reels", route: RouteReels(), type: "", icon: "pkg:/images/ui/menu_reels.png", iconActive: "pkg:/images/ui/menu_reels_active.png" })
    end if
    items.Push({ text: "Profile", route: RouteLoginProfile(), type: "", icon: "pkg:/images/ui/menu_profile.png", iconActive: "pkg:/images/ui/menu_profile_active.png" })
    return items
end function

function SidebarCollapsedWidth() as integer
    return 100
end function

function SidebarExpandedWidth() as integer
    return 232
end function
