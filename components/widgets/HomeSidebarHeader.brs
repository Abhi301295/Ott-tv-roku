' HomeSidebarHeader.brs — vertical sidebar menu (HeaderType.SIDEBAR).

sub init()
    m.bg = m.top.findNode("bg")
    m.menuCol = m.top.findNode("menuCol")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")
    m.avatarMask = m.top.findNode("avatarMask")
    m.avatarImg = m.top.findNode("avatarImg")
    m.widthAnim = m.top.findNode("widthAnim")
    m.widthInterp = m.top.findNode("widthInterp")
    m.avatarAnim = m.top.findNode("avatarAnim")
    m.avatarInterp = m.top.findNode("avatarInterp")
    m.itemRows = []
    m.ITEM_H = 58
    m.ITEM_GAP = 34
    m.ICON_DISP = 32
    m.ICON_SRC = 96
    m.ICON_SLOT = 50
    m.PAD_L = 14
    m.LABEL_GAP = 20
    m.PAD_R = 6
    m.LOGO_Y = 100
    m.LOGO_EXPANDED_W = 160
    m.LOGO_EXPANDED_H = 52
    m.LOGO_COLLAPSED_SIZE = 44
    m.COLLAPSED = ThemeSidebarCollapsedWidth()
    m.EXPANDED = ThemeSidebarExpandedWidth()
    m.currentWidth = m.COLLAPSED
    m.skipWidthAnim = true
    if m.widthAnim <> invalid then m.widthAnim.observeField("state", "OnWidthAnimState")

    m.fontRegular = CreateObject("roSGNode", "Font")
    m.fontRegular.uri = "pkg:/fonts/Inter-Regular.ttf"
    m.fontRegular.size = 18

    m.fontRegular20 = CreateObject("roSGNode", "Font")
    m.fontRegular20.uri = "pkg:/fonts/Inter-Regular.ttf"
    m.fontRegular20.size = 20

    m.fontMedium20 = CreateObject("roSGNode", "Font")
    m.fontMedium20.uri = "pkg:/fonts/Inter-Medium.ttf"
    m.fontMedium20.size = 20

    m.fontBold20 = CreateObject("roSGNode", "Font")
    m.fontBold20.uri = "pkg:/fonts/Inter-Bold.ttf"
    m.fontBold20.size = 20

    ApplyWidth(false)
end sub

sub OnMenuChanged()
    BuildMenu()
end sub

sub OnLayoutChanged()
    instant = m.top.instantLayout = true
    ApplyFocus()
    ApplyWidth(not instant)
    OnLogoChanged()
end sub

function SidebarTargetWidth() as integer
    w = m.COLLAPSED
    if m.top.headerActive then w = m.EXPANDED
    return w
end function

function SidebarAvatarX(expanded as boolean) as integer
    if expanded then return 78
    return Int((m.COLLAPSED - 64) / 2)
end function

sub ApplyWidth(animate as boolean)
    targetW = SidebarTargetWidth()
    expanded = m.top.headerActive

    if m.bg <> invalid then m.bg.color = m.top.cNeutral800

    if animate and not m.skipWidthAnim and m.widthAnim <> invalid and m.widthInterp <> invalid then
        fromW = m.currentWidth
        if fromW = targetW then
            m.top.sidebarWidth = targetW
        else
            m.widthInterp.keyValue = [fromW, targetW]
            m.widthAnim.control = "start"
        end if
    else if m.bg <> invalid then
        m.bg.width = targetW
        m.currentWidth = targetW
        m.top.sidebarWidth = targetW
    end if

    if m.avatarMask <> invalid then
        ax = SidebarAvatarX(expanded)
        if animate and not m.skipWidthAnim and m.avatarAnim <> invalid and m.avatarInterp <> invalid then
            fromT = m.avatarMask.translation
            m.avatarInterp.keyValue = [fromT, [ax, 980]]
            m.avatarAnim.control = "start"
        else
            m.avatarMask.translation = [ax, 980]
        end if
    end if

    m.skipWidthAnim = false
    ApplyItemLayout(expanded)
end sub

sub OnWidthAnimState()
    if m.widthAnim = invalid then return
    if m.widthAnim.state <> "stopped" then return
    if m.bg <> invalid then m.currentWidth = m.bg.width
    m.top.sidebarWidth = m.currentWidth
end sub

sub BuildMenu()
    if m.menuCol = invalid then return
    m.menuCol.removeChildrenIndex(m.menuCol.getChildCount(), 0)
    m.itemRows = []

    items = m.top.menuItems
    if items = invalid then return

    y = 0
    for i = 0 to items.Count() - 1
        it = items[i]
        if it = invalid then continue for

        row = m.menuCol.createChild("Group")
        row.translation = [0, y]

        bg = row.createChild("Rectangle")
        bg.id = "bg"
        bg.width = m.EXPANDED
        bg.height = m.ITEM_H
        bg.color = m.top.cNeutral700
        bg.visible = false

        icon = row.createChild("Poster")
        icon.id = "icon"
        icon.width = m.ICON_DISP
        icon.height = m.ICON_DISP
        icon.loadWidth = m.ICON_SRC
        icon.loadHeight = m.ICON_SRC
        icon.loadDisplayMode = "scaleToFit"
        if it.icon <> invalid then icon.uri = it.icon
        icon.blendColor = "0xffffffff"

        lbl = row.createChild("Label")
        lbl.id = "label"
        lbl.width = SidebarLabelWidth()
        lbl.height = m.ITEM_H + 6
        lbl.wrap = false
        lbl.ellipsizeOnBoundary = false
        lbl.horizAlign = "left"
        lbl.vertAlign = "center"
        lbl.color = m.top.cNeutral100
        lbl.visible = false
        if it.text <> invalid then lbl.text = it.text
        ApplySidebarFont(lbl, "regular", 20)

        m.itemRows.Push({ row: row, bg: bg, icon: icon, label: lbl, item: it })
        y = y + m.ITEM_H + m.ITEM_GAP
    end for
    ApplyItemLayout(m.top.headerActive)
    ApplyFocus()
end sub

function SidebarLabelX() as integer
    return m.PAD_L + m.ICON_SLOT + m.LABEL_GAP
end function

function SidebarLabelWidth() as integer
    w = m.EXPANDED - SidebarLabelX() - m.PAD_R
    if w < 100 then w = 100
    return w
end function

sub ApplyItemLayout(expanded as boolean)
  ' headerMenuItem.tsx: pl-14, w-50 icon slot, pl-20 gap, items-center row.
    iconY = Int((m.ITEM_H - m.ICON_DISP) / 2)
    iconXExpanded = m.PAD_L + Int((m.ICON_SLOT - m.ICON_DISP) / 2)
    iconXCollapsed = Int((m.COLLAPSED - m.ICON_DISP) / 2)
    labelX = SidebarLabelX()
    labelW = SidebarLabelWidth()

    for i = 0 to m.itemRows.Count() - 1
        entry = m.itemRows[i]
        if entry = invalid then continue for
        icon = entry.icon
        lbl = entry.label
        bg = entry.bg
        if icon <> invalid then
            if expanded then
                icon.translation = [iconXExpanded, iconY]
            else
                icon.translation = [iconXCollapsed, iconY]
            end if
        end if
        if lbl <> invalid then
            if expanded then
                lbl.translation = [labelX, -3]
                lbl.width = labelW
            end if
        end if
        if bg <> invalid then
            if expanded then
                bg.width = m.EXPANDED
            else
                bg.width = m.COLLAPSED
            end if
        end if
    end for
end sub

sub OnFocusChanged()
    ApplyFocus()
end sub

sub ApplySidebarFont(lbl as object, weight as string, size as integer)
    if lbl = invalid then return
    if weight = "bold" and size = 20 then
        lbl.font = m.fontBold20
    else if weight = "medium" and size = 20 then
        lbl.font = m.fontMedium20
    else if size = 20 then
        lbl.font = m.fontRegular20
    else
        lbl.font = m.fontRegular
    end if
end sub

sub ApplyFocus()
    sel = m.top.selectedIndex
    foc = m.top.focusedIndex
    active = m.top.headerActive
    expanded = active

    ApplyItemLayout(expanded)

    for i = 0 to m.itemRows.Count() - 1
        entry = m.itemRows[i]
        if entry = invalid then continue for
        bg = entry.bg
        icon = entry.icon
        lbl = entry.label
        it = entry.item
        if icon = invalid then continue for

        isSel = (i = sel)
        isFoc = active and (i = foc)
        showSel = isSel

        if lbl <> invalid then lbl.visible = expanded

        if showSel then
            if lbl <> invalid then
                lbl.color = m.top.cNeutral50
                ApplySidebarFont(lbl, "bold", 20)
            end if
        else if lbl <> invalid then
            if isFoc then
                lbl.color = m.top.cPrimary700
                ApplySidebarFont(lbl, "medium", 20)
            else
                lbl.color = m.top.cNeutral100
                ApplySidebarFont(lbl, "regular", 18)
            end if
        end if

        if it <> invalid then
            if showSel or isFoc then
                uri = it.iconActive
                if uri = invalid or uri = "" then uri = it.icon
                if uri <> invalid and uri <> "" then icon.uri = uri
                icon.blendColor = m.top.cPrimary500
            else
                if it.icon <> invalid and it.icon <> "" then icon.uri = it.icon
                icon.blendColor = "0xffffffff"
            end if
        end if

        if bg <> invalid then
            if not expanded then
                bg.visible = false
            else if showSel then
                bg.visible = true
                bg.color = m.top.cNeutral700
            else if isFoc then
                bg.visible = true
                bg.color = m.top.cNeutral800
            else
                bg.visible = false
            end if
        end if
    end for
end sub

sub OnThemeChanged()
    if m.logoLabel <> invalid then m.logoLabel.color = m.top.cNeutral50
    if m.bg <> invalid then m.bg.color = m.top.cNeutral800
    ApplyFocus()
end sub

sub OnLogoChanged()
    uri = m.top.logoUri
    cropped = m.top.logoCroppedUri
    name = m.top.appName
    expanded = m.top.headerActive

    if m.logoPoster <> invalid then
        showUri = cropped
        if expanded and uri <> invalid and uri <> "" then showUri = uri
        if showUri <> invalid and showUri <> "" then
            m.logoPoster.uri = showUri
            m.logoPoster.visible = true
            m.logoPoster.loadDisplayMode = "scaleToFit"
            if expanded then
                ' Wide horizontal wordmark — parity with header.tsx expanded (max-w-40, pl-14).
                m.logoPoster.translation = [m.PAD_L, m.LOGO_Y]
                m.logoPoster.width = m.LOGO_EXPANDED_W
                m.logoPoster.height = m.LOGO_EXPANDED_H
                m.logoPoster.loadWidth = m.LOGO_EXPANDED_W * 2
                m.logoPoster.loadHeight = m.LOGO_EXPANDED_H * 2
            else
                m.logoPoster.translation = [Int((m.COLLAPSED - m.LOGO_COLLAPSED_SIZE) / 2), m.LOGO_Y]
                m.logoPoster.width = m.LOGO_COLLAPSED_SIZE
                m.logoPoster.height = m.LOGO_COLLAPSED_SIZE
                m.logoPoster.loadWidth = m.LOGO_COLLAPSED_SIZE * 2
                m.logoPoster.loadHeight = m.LOGO_COLLAPSED_SIZE * 2
            end if
            if m.logoLabel <> invalid then m.logoLabel.visible = false
        else
            m.logoPoster.visible = false
            if m.logoLabel <> invalid then
                m.logoLabel.text = name
                m.logoLabel.visible = (name <> "")
                if expanded then
                    m.logoLabel.translation = [m.PAD_L, m.LOGO_Y]
                    m.logoLabel.width = m.LOGO_EXPANDED_W
                    m.logoLabel.horizAlign = "left"
                else
                    m.logoLabel.translation = [8, m.LOGO_Y]
                    m.logoLabel.width = m.COLLAPSED - 16
                    m.logoLabel.horizAlign = "center"
                end if
            end if
        end if
    end if
end sub

sub OnAvatarChanged()
    if m.avatarImg = invalid then return
    uri = m.top.avatarUri
    if uri <> invalid and uri <> "" then
        m.avatarImg.uri = uri
        m.avatarImg.visible = true
    else
        m.avatarImg.visible = false
    end if
end sub
