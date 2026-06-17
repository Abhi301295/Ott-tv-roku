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
        print "[LAYOUT] header="; ThemeHeaderStyle()
    end if
    SyncToActiveHeader()
end sub

sub SyncToActiveHeader()
    if m.activeHeader = invalid then return
    if m.activeHeader.hasField("menuItems") then
        m.activeHeader.menuItems = m.top.menuItems
    end if
    if m.activeHeader.hasField("menuTexts") then
        m.activeHeader.menuTexts = m.top.menuTexts
    end if
    m.activeHeader.focusedIndex = m.top.focusedIndex
    m.activeHeader.selectedIndex = m.top.selectedIndex
    m.activeHeader.headerActive = m.top.headerActive
    m.activeHeader.logoUri = m.top.logoUri
    if m.activeHeader.hasField("logoCroppedUri") then
        m.activeHeader.logoCroppedUri = m.top.logoCroppedUri
    end if
    m.activeHeader.appName = m.top.appName
    m.activeHeader.avatarUri = m.top.avatarUri
    m.activeHeader.cPrimary500 = m.top.cPrimary500
    m.activeHeader.cNeutral50 = m.top.cNeutral50
    m.activeHeader.cNeutral200 = m.top.cNeutral200
    m.activeHeader.cNeutral800 = m.top.cNeutral800
    m.activeHeader.cNeutral950 = m.top.cNeutral950
    if m.activeHeader.hasField("scrimOpacity") then
        m.activeHeader.scrimOpacity = m.top.scrimOpacity
    end if
end sub

sub OnMenuChanged()
    SyncToActiveHeader()
end sub

sub OnFocusProxy()
    SyncToActiveHeader()
end sub

sub OnBrandingProxy()
    SyncToActiveHeader()
end sub

sub OnThemeProxy()
    SyncToActiveHeader()
end sub

sub OnScrimProxy()
    SyncToActiveHeader()
end sub
