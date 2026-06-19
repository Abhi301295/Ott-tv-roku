sub init()
    m.headerNetflix = m.top.findNode("headerNetflix")
    m.headerSidebar = m.top.findNode("headerSidebar")
    m.activeHeader = invalid
    ApplyHeaderSelection()
end sub

sub ApplyHeaderSelection()
    if m.headerNetflix <> invalid then m.headerNetflix.visible = false
    if m.headerSidebar <> invalid then m.headerSidebar.visible = false

    if ThemeIsSidebarHeader() then
        m.activeHeader = m.headerSidebar
    else
        m.activeHeader = m.headerNetflix
    end if

    if m.activeHeader <> invalid then
        m.activeHeader.visible = true
    end if
    SyncAllToActiveHeader()
end sub

' Full sync — header widget switch / first paint only.
sub SyncAllToActiveHeader()
    SyncMenuToActiveHeader()
    SyncFocusToActiveHeader()
    SyncBrandingToActiveHeader()
    SyncThemeToActiveHeader()
    SyncScrimToActiveHeader()
end sub

' Focus / selection must NOT reassign menuItems — that rebuilds every row in BuildMenu().
sub SyncFocusToActiveHeader()
    if m.activeHeader = invalid then return
    m.activeHeader.focusedIndex = m.top.focusedIndex
    m.activeHeader.selectedIndex = m.top.selectedIndex
    m.activeHeader.headerActive = m.top.headerActive
end sub

sub SyncMenuToActiveHeader()
    if m.activeHeader = invalid then return
    if m.activeHeader.hasField("menuItems") then
        m.activeHeader.menuItems = m.top.menuItems
    end if
    if m.activeHeader.hasField("menuTexts") then
        m.activeHeader.menuTexts = m.top.menuTexts
    end if
end sub

sub SyncBrandingToActiveHeader()
    if m.activeHeader = invalid then return
    m.activeHeader.logoUri = m.top.logoUri
    if m.activeHeader.hasField("logoCroppedUri") then
        m.activeHeader.logoCroppedUri = m.top.logoCroppedUri
    end if
    m.activeHeader.appName = m.top.appName
    m.activeHeader.avatarUri = m.top.avatarUri
end sub

sub SyncThemeToActiveHeader()
    if m.activeHeader = invalid then return
    m.activeHeader.cPrimary500 = m.top.cPrimary500
    m.activeHeader.cNeutral50 = m.top.cNeutral50
    m.activeHeader.cNeutral200 = m.top.cNeutral200
    m.activeHeader.cNeutral800 = m.top.cNeutral800
    m.activeHeader.cNeutral950 = m.top.cNeutral950
end sub

sub SyncScrimToActiveHeader()
    if m.activeHeader = invalid then return
    if m.activeHeader.hasField("scrimOpacity") then
        m.activeHeader.scrimOpacity = m.top.scrimOpacity
    end if
end sub

sub OnMenuChanged()
    SyncMenuToActiveHeader()
end sub

sub OnFocusProxy()
    SyncFocusToActiveHeader()
end sub

sub OnBrandingProxy()
    SyncBrandingToActiveHeader()
end sub

sub OnThemeProxy()
    SyncThemeToActiveHeader()
end sub

sub OnScrimProxy()
    SyncScrimToActiveHeader()
end sub
