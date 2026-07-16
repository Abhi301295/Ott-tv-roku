' AppShell.brs — persistent header shell (parity with PageContainer + Header in React).
' Routes with showSideMenu=true keep the app header visible across screen swaps.

function RouteShowSideMenu(route as string) as boolean
    if route = RouteLogin() then return false
    if route = RouteLoginProfile() then return false
    if route = RouteDetail() then return false
    if route = RouteVideoPlayer() then return false
    if route = RouteSeriesEpisodes() then return false
    return true
end function

function FindAppHeader(fromNode as object) as object
    vm = FindViewManager(fromNode)
    if vm = invalid then return invalid
    return vm.findNode("appHeader")
end function

function ShellContentOffsetX(header as object) as integer
    if not ThemeIsSidebarHeader() then return 0
    if header = invalid or header.visible <> true then return 0
    expanded = false
    if header.headerActive = true then expanded = true
    return ThemeSidebarOffset(expanded)
end function

' Netflix top bar is fixed over content (ottHeader.tsx). Reels clears it via top-[96px].
function ShellContentOffsetY(header as object) as integer
    if not ThemeIsNetflixHeader() then return 0
    if header = invalid or header.visible <> true then return 0
    return 96
end function

function ShellContentViewportW(header as object) as integer
    return 1920 - ShellContentOffsetX(header)
end function

sub ShellSetFocus(vm as object, zone as string)
    if vm = invalid then return
    if vm.hasField("shellFocus") then vm.shellFocus = zone
end sub

sub ShellEnterHeader(vm as object, menuIndex = invalid as dynamic)
    header = invalid
    if vm <> invalid then header = vm.findNode("appHeader")
    if header = invalid then return
    ShellSetFocus(vm, "header")
    if menuIndex <> invalid then
        header.focusedIndex = menuIndex
        if vm.hasField("menuIndex") then vm.menuIndex = menuIndex
    end if
    header.headerActive = true
    AppShellNotifyLayoutChange(vm)
end sub

sub ShellEnterContent(vm as object)
    header = invalid
    if vm <> invalid then header = vm.findNode("appHeader")
    if header <> invalid then header.headerActive = false
    ShellSetFocus(vm, "content")
    AppShellNotifyLayoutChange(vm)
end sub

' Leave the header menu and hand off to the active screen (hero, rows, etc.).
sub AppShellLeaveHeader(vm as object, action = "" as string)
    ShellEnterContent(vm)
    screen = AppShellActiveScreen(vm)
    if screen = invalid then return
    if action <> "" and screen.hasField("shellEnterAction") then screen.shellEnterAction = action
    if screen.hasField("shellEnterContent") then screen.shellEnterContent = true
end sub

sub AppShellNotifyLayoutChange(vm as object)
    if vm = invalid then return
    screen = AppShellActiveScreen(vm)
    if screen = invalid then return
    if screen.hasField("shellLayoutRev") then
        rev = 0
        if screen.shellLayoutRev <> invalid then rev = screen.shellLayoutRev
        screen.shellLayoutRev = rev + 1
    end if
end sub

function HeaderSelectedIndexForNav(items as object, route as string, state as object) as integer
    if items = invalid then return 0

    if state <> invalid and state.selectedID <> invalid and state.selectedID <> "" then
        sid = state.selectedID
        for i = 0 to items.Count() - 1
            it = items[i]
            if it <> invalid and it.text = sid then return i
        end for
    end if

    if route = RouteGenere() and state <> invalid and state.type <> invalid and state.type <> "" then
        tp = state.type
        for i = 0 to items.Count() - 1
            it = items[i]
            if it = invalid then continue for
            if it.route = route and it.type = tp then return i
        end for
    end if

    ' See All / new-release — keep last header tab (parity React localStorage SelectedItem).
    if route = RouteSeries() or route = RouteNewRelease() then
        saved = RegistryRead(SK_SelectedItem(), "app")
        if saved <> invalid and saved <> "" then
            for i = 0 to items.Count() - 1
                it = items[i]
                if it <> invalid and it.text = saved then return i
            end for
        end if
        for i = 0 to items.Count() - 1
            it = items[i]
            if it <> invalid and it.route = RouteHome() then return i
        end for
    end if

    if route = RouteHome() then
        for i = 0 to items.Count() - 1
            it = items[i]
            if it <> invalid and it.route = RouteHome() then return i
        end for
    end if

    return HeaderSelectedIndex(items, route)
end function

sub LoadAppHeaderTheme(header as object)
    if header = invalid then return
    tokens = {}
    tm = header.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then tokens = tm.themeTokens

    header.cPrimary500 = ShellTokenColor(tokens, "primary-500", "#0092ff")
    header.cNeutral50 = ShellTokenColor(tokens, "neutral-50", "#ffffff")
    header.cNeutral200 = ShellTokenColor(tokens, "neutral-200", "#e5e5e5")
    header.cNeutral800 = ShellTokenColor(tokens, "neutral-800", "#121212")
    header.cNeutral950 = ShellTokenColor(tokens, "neutral-900", "#0a0a0a")
    if header.hasField("cPrimary700") then
        header.cPrimary700 = ShellTokenColor(tokens, "primary-700", "#80bbe9")
    end if
    if header.hasField("cNeutral100") then
        header.cNeutral100 = ShellTokenColor(tokens, "neutral-100", "#f8f8f8")
    end if
    if header.hasField("cNeutral700") then
        header.cNeutral700 = ShellTokenColor(tokens, "neutral-700", "#181818")
    end if
end sub

function ShellTokenColor(tokens as object, name as string, fallbackHex as string) as string
    hex = fallbackHex
    if tokens <> invalid and tokens[name] <> invalid and tokens[name] <> "" then
        hex = tokens[name]
    end if
    if Left(hex, 1) = "#" then hex = Mid(hex, 2)
    if Len(hex) = 8 then return "0x" + hex
    if Len(hex) = 6 then return "0x" + hex + "ff"
    return "0x0b75e0ff"
end function

sub ApplyAppHeaderBranding(header as object)
    if header = invalid then return
    avatarUri = RegistryRead(SK_Avatar(), "app")
    if avatarUri <> invalid then header.avatarUri = avatarUri

    resolved = invalid
    scene = header.getScene()
    if scene <> invalid and scene.global <> invalid then resolved = scene.global.businessResolved
    if resolved = invalid then return

    if resolved.brandingLogo <> invalid then
        header.logoUri = resolved.brandingLogo
        if header.hasField("logoCroppedUri") then header.logoCroppedUri = resolved.brandingLogo
    end if
    if resolved.appName <> invalid then header.appName = resolved.appName
end sub

sub SetupAppHeader(vm as object, route as string, state as object)
    if vm = invalid then return
    header = vm.findNode("appHeader")
    if header = invalid then return

    showMenu = RouteShowSideMenu(route)
    header.visible = showMenu

    if not showMenu then
        ShellSetFocus(vm, "content")
        return
    end if

    reels = false
    epg = false
    resolved = invalid
    scene = header.getScene()
    if scene <> invalid and scene.global <> invalid then resolved = scene.global.businessResolved
    if resolved <> invalid then
        reels = IsFeatureEnabled(resolved, "reelsEnabled")
        epg = IsFeatureEnabled(resolved, "epgManagement")
    end if
    tm = invalid
    if scene <> invalid then tm = scene.findNode("themeManager")
    if tm <> invalid and tm.reelsEnabled = true then reels = true
    if tm <> invalid and tm.epgEnabled = true then epg = true

    ' shellMenuBuilt / shellMenuReels / shellMenuEpg live on ViewManager's m (not interface fields).
    menuBuilt = false
    if m.shellMenuBuilt = true then menuBuilt = true
    if m.shellMenuReels <> reels then menuBuilt = false
    if m.shellMenuEpg <> epg then menuBuilt = false

    if not menuBuilt then
        menuItems = HeaderMenuItems(reels, epg)
        vm.menuItems = menuItems
        if ThemeIsSidebarHeader() then
            header.menuItems = SidebarMenuItems(reels, epg)
        else
            texts = []
            for each it in menuItems
                texts.Push(it.text)
            end for
            header.menuTexts = texts
        end if
        m.shellMenuReels = reels
        m.shellMenuEpg = epg
        m.shellMenuBuilt = true
        LoadAppHeaderTheme(header)
        ApplyAppHeaderBranding(header)
    end if

    menuItems = vm.menuItems
    if menuItems = invalid then menuItems = []

    idx = HeaderSelectedIndexForNav(menuItems, route, state)
    if route = RouteHome() then
        saved = RegistryRead(SK_SelectedItem(), "app")
        if saved = "Home" or saved = invalid or saved = "" then
            idx = HeaderSelectedIndex(menuItems, RouteHome())
        end if
    end if

    vm.menuIndex = idx
    header.scrimOpacity = 0.0
    header.selectedIndex = idx
    if vm.shellFocus = "header" then
        header.focusedIndex = idx
    end if
end sub

function AppShellHandleHeaderKey(vm as object, key as string) as boolean
    if vm = invalid then return false
    if vm.shellFocus <> "header" then return false
    header = vm.findNode("appHeader")
    if header = invalid or header.visible <> true then return false

    menuItems = vm.menuItems
    if menuItems = invalid then menuItems = []
    menuIndex = vm.menuIndex
    if menuIndex = invalid then menuIndex = header.focusedIndex

    NotifyShellHeaderInteraction(vm)

    if ThemeIsSidebarHeader() then
        if key = "up" then
            if menuIndex > 0 then
                menuIndex = menuIndex - 1
                header.focusedIndex = menuIndex
                vm.menuIndex = menuIndex
            end if
            return true
        else if key = "down" then
            if menuIndex < menuItems.Count() - 1 then
                menuIndex = menuIndex + 1
                header.focusedIndex = menuIndex
                vm.menuIndex = menuIndex
            end if
            return true
        else if key = "right" then
            AppShellLeaveHeader(vm, "restore")
            return true
        else if key = "OK" or key = "ok" then
            AppShellSelectHeaderItem(vm, menuIndex)
            return true
        end if
        return false
    end if

    ' Netflix top bar
    if key = "left" then
        if menuIndex > 0 then
            menuIndex = menuIndex - 1
            header.focusedIndex = menuIndex
            vm.menuIndex = menuIndex
        end if
        return true
    else if key = "right" then
        if menuIndex < menuItems.Count() - 1 then
            menuIndex = menuIndex + 1
            header.focusedIndex = menuIndex
            vm.menuIndex = menuIndex
        end if
        return true
    else if key = "down" then
        AppShellLeaveHeader(vm, "hero")
        return true
    else if key = "OK" or key = "ok" then
        AppShellSelectHeaderItem(vm, menuIndex)
        return true
    end if
    return false
end function

sub NotifyShellHeaderInteraction(vm as object)
    if vm = invalid then return
    screen = AppShellActiveScreen(vm)
    if screen = invalid then return
    if not screen.hasField("shellHeaderNavTick") then return
    tick = 0
    if screen.shellHeaderNavTick <> invalid then tick = screen.shellHeaderNavTick
    screen.shellHeaderNavTick = tick + 1
end sub

' True when the header re-selected the same top-level tab with identical nav params
' (hand off focus only). Movies vs Series share RouteGenere() but differ by type.
function AppShellSameTabReselect(vm as object, item as object) as boolean
    if vm = invalid or item = invalid then return false
    if vm.currentRoute <> item.route then return false

    state = vm.navState
    if state = invalid then state = {}

    if item.route = RouteGenere() then
        curType = ""
        newType = ""
        if state.type <> invalid then curType = state.type
        if item.type <> invalid then newType = item.type
        return curType = newType
    end if

    return true
end function

sub AppShellSelectHeaderItem(vm as object, menuIndex as integer)
    menuItems = vm.menuItems
    if menuItems = invalid or menuIndex < 0 or menuIndex >= menuItems.Count() then return
    item = menuItems[menuIndex]
    if item = invalid then return

    header = vm.findNode("appHeader")
    if header <> invalid then header.selectedIndex = menuIndex
    vm.menuIndex = menuIndex
    SetValueByKey(SK_SelectedItem(), item.text, "app")

    if item.route = RouteHome() then
        if vm.currentRoute = RouteHome() then
            if ThemeIsSidebarHeader() then
                ShellEnterHeader(vm, menuIndex)
            else
                AppShellLeaveHeader(vm, "hero")
            end if
            return
        end if
        vm.callFunc("NavigateReplace", RouteHome(), {})
        return
    end if

    ' Same tab + same nav params — hand off to content; do not remount.
    if AppShellSameTabReselect(vm, item) then
        if vm.shellFocus = "header" then
            AppShellLeaveHeader(vm, "restore")
        end if
        return
    end if

    if vm.shellFocus = "header" then
        ShellEnterContent(vm)
    end if

    navState = { type: item.type, selectedID: item.text }
    vm.callFunc("NavigateReplace", item.route, navState)
end sub

function AppShellActiveScreen(vm as object) as object
    if vm = invalid then return invalid
    host = vm.findNode("screenHost")
    if host = invalid then return invalid
    count = host.getChildCount()
    if count < 1 then return invalid
    return host.getChild(count - 1)
end function
