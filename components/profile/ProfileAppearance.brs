' ProfileAppearance.brs — profile screen theme tokens, layout, and branding.


' ── Theme ────────────────────────────────────────────────────────────────────

sub LoadProfileTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    m.cPrimary500 = TC("primary-500", "#0b75e0")
    m.cPrimary600 = TC("primary-600", "#0760bb")
    m.cPrimary700 = TC("primary-700", "#04478b")
    m.cNeutral50 = TC("neutral-50", "#ffffff")
    m.cNeutral100 = TC("neutral-100", "#f8f8f8")
    m.cNeutral300 = TC("neutral-300", "#d6d6d6")
    m.cNeutral400 = TC("neutral-400", "#c8c8c8")
    m.cNeutral600 = TC("neutral-600", "#3d3d3d")
    m.cNeutral700 = TC("neutral-700", "#404040")
    m.cNeutral800 = TC("neutral-800", "#121212")
    m.cAmber400 = TC("amber-400", "#f59e0b")
    m.cNeutral500 = TC("neutral-500", "#e279ce")
    ' neutral-900 (tertiary/background) drives the themed dialog surfaces, matching
    ' React's bg-neutral-900 on the confirm/OTP popups.
    m.cNeutral900 = TC("neutral-900", "#0a0a0a")
    m.cBg = m.cNeutral900
    m.cCardBg = m.cNeutral900
    ' Color behind the avatar corners; switches to a near-black scrim when the
    ' focus backdrop is visible so the corner-mask circle keeps blending cleanly.
    m.cAvatarBg = m.cBg
    LoadProfilePortalColors()
end sub


sub LoadProfilePortalColors()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved
    portal = ProfilePortalRokuColors(resolved)
    m.cPortalPrimary = portal.primary
    m.cPortalSecondary = portal.secondary
    m.cPortalTertiary = portal.tertiary
end sub


function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

' React userProfile.tsx branches on HEADER_STYLE === NETFLIX vs SIDEBAR (cases 4/6).

sub ApplyProfileLayoutFromSpec()
    if m.uiSpec = invalid then m.uiSpec = ProfileUiSpec()
    titlePos = ProfileUiTitlePos()
    listPos = ProfileUiProfilesPos()
    listTopY = ProfileListTopY()
    if m.title <> invalid then
        m.title.translation = [titlePos.x, titlePos.y]
        titleFont = m.title.findNode("font")
        if titleFont <> invalid then titleFont.size = m.uiSpec.titleFont
    end if
    if m.errorLabel <> invalid then
        m.errorLabel.translation = [titlePos.x, titlePos.y + m.uiSpec.titleFont + 8]
    end if
    if m.profilesScrollHost <> invalid then
        m.profilesScrollHost.translation = [listPos.x, 0]
    end if
    if m.profilesViewport <> invalid then
        vw = ProfileListViewportWidth()
        vh = ProfileListViewportHeight()
        m.profilesViewport.maskSize = [vw, vh]
        m.profilesViewport.maskOffset = [0, listTopY]
    end if
    m.listContentPadY = listTopY
    if m.skeletonGroup <> invalid then
        m.skeletonGroup.translation = [listPos.x, listTopY]
    end if
    ApplyProfileHeaderBackdrop()
    ProfileUiLogScreen(titlePos.x, titlePos.y, listPos.x, listTopY, ProfileRowPitch())
end sub


sub ApplyProfileHeaderBackdrop()
    if m.headerTextBackdrop = invalid then return
    if m.uiSpec = invalid then m.uiSpec = ProfileUiSpec()
    s = m.uiSpec
    titlePos = ProfileUiTitlePos()
    padX = s.headerBackdropPadX
    padY = s.headerBackdropPadY
    topY = s.logoY - padY
    if topY < 0 then topY = 0
    bottomY = titlePos.y + s.titleFont + padY
    w = 900 + padX * 2
    m.headerTextBackdrop.translation = [titlePos.x - padX, topY]
    m.headerTextBackdrop.width = w
    m.headerTextBackdrop.height = bottomY - topY
    m.headerTextBackdrop.opacity = s.headerBackdropOpacity
end sub


sub ApplyProfileSkeletonLayout()
    pitch = ProfileRowPitch()
    square = ProfileUsesSquareAvatars()
    s = ProfileUiSpec()
    nameX = s.skAvatarSize + s.skNameMarginLeft
    nameY = Int((s.skRowHeight - s.skNameHeight) / 2.0 + 0.5)
    avatarKind = "avatar"
    if square then avatarKind = "avatarSquare"
    avatarShape = SkeletonProfileAvatarShapeUri(square)
    pillShape = SkeletonProfileNameShapeUri()
    slots = [
        { a: "sk0a", b: "sk0b", y: 0 }
        { a: "sk1a", b: "sk1b", y: pitch }
        { a: "sk2a", b: "sk2b", y: pitch * 2 }
    ]
    for each slot in slots
        boxA = m.top.findNode(slot.a)
        boxB = m.top.findNode(slot.b)
        if boxA <> invalid then
            boxA.translation = [0, slot.y]
            boxA.layoutScale = 1.0
            boxA.glowKind = avatarKind
            boxA.boxWidth = s.skAvatarSize
            boxA.boxHeight = s.skAvatarSize
            boxA.shapeUri = avatarShape
            boxA.glowVisible = true
        end if
        if boxB <> invalid then
            if square then
                boxB.visible = false
                boxB.running = false
                boxB.glowVisible = false
            else
                boxB.visible = true
                boxB.translation = [nameX, slot.y + nameY]
                boxB.layoutScale = 1.0
                boxB.glowKind = "pill"
                boxB.boxWidth = s.skNameWidth
                boxB.boxHeight = s.skNameHeight
                boxB.shapeUri = pillShape
                boxB.glowVisible = true
            end if
        end if
    end for
end sub


sub ApplyProfileColors()
    if m.bg <> invalid then m.bg.color = "0x000000ff"
    ApplyProfileFocusBackground()
    if m.headerTextBackdrop <> invalid then
        m.headerTextBackdrop.color = "0x000000ff"
        if m.uiSpec <> invalid then
            m.headerTextBackdrop.opacity = m.uiSpec.headerBackdropOpacity
        end if
    end if
    m.title.color = m.cNeutral50
    m.errorLabel.color = m.cPrimary500
    m.logoLabel.color = m.cPrimary500

    ' Shimmer fill: theme primary-700/500 (React SkeletonBox defaults).
    ' Wrapper glow: baked sk_glow_*.png — React boxShadow rgba(0, 146, 255, 0.4).
    skColors = SkeletonResolveColors(m.tokens)
    for each id in ["sk0a", "sk0b", "sk1a", "sk1b", "sk2a", "sk2b"]
        sk = m.top.findNode(id)
        if sk <> invalid then
            sk.baseColor = skColors.base
            sk.highlightColor = skColors.highlight
        end if
    end for

    ' Logout button (bg-primary-500) — focus styling handled in ApplyProfileFocus.
    m.logoutBtn.bgColor = m.cPrimary500
    m.logoutBtn.textColor = m.cNeutral50
    m.logoutBtn.shadowColor = m.cPrimary500

    ' confirmpopup.tsx — scrim bg-black/30; card bg-black; borders neutral-600.
    m.confirmPopup.cPrimary500 = m.cPrimary500
    m.confirmPopup.cPrimary600 = m.cPrimary600
    m.confirmPopup.cNeutral50 = m.cNeutral50
    m.confirmPopup.cNeutral300 = m.cNeutral300
    m.confirmPopup.cNeutral600 = m.cNeutral600
    m.confirmPopup.cNeutral950 = TailwindNeutral950Color()
    m.confirmPopup.cCardBg = "0x000000ff"
    m.confirmPopup.cCardBorder = m.cNeutral600

    m.otpPopup.cPrimary500 = m.cPrimary500
    m.otpPopup.cPrimary600 = m.cPrimary600
    m.otpPopup.cNeutral600 = m.cNeutral600
    m.otpPopup.cNeutral700 = m.cNeutral700
    m.otpPopup.cCardBg = m.cNeutral900

    ' Profile name inherits body/title light text (React: same tone as text-neutral-50 h1).
    for each av in m.avatars
        if av <> invalid then
            if av.hasField("nameColor") then av.nameColor = m.cNeutral50
            if av.hasField("hintColor") then av.hintColor = m.cNeutral400
            if av.hasField("skBaseColor") then av.skBaseColor = skColors.base
            if av.hasField("skHighlightColor") then av.skHighlightColor = skColors.highlight
        end if
    end for
end sub

' Cumulative row layout — each row gets the height of its scaled card + name (+ hint).

sub ApplySquareAvatarColors()
    if m.useSquareAvatars <> true then return
    skColors = SkeletonResolveColors(m.tokens)
    for each av in m.avatars
        av.cardTopColor = m.cNeutral600
        av.cardBottomColor = m.cNeutral800
        av.cardBackingColor = m.cBg
        av.borderColor = m.cPrimary700
        av.nameColor = m.cNeutral50
        av.hintColor = m.cNeutral400
        if av.hasField("skBaseColor") then av.skBaseColor = skColors.base
        if av.hasField("skHighlightColor") then av.skHighlightColor = skColors.highlight
    end for
end sub


sub ApplyProfileArcColors()
    LoadProfilePortalColors()
    for each av in m.avatars
        if av <> invalid and av.hasField("portalPrimary") then
            av.portalPrimary = m.cPortalPrimary
            av.portalSecondary = m.cPortalSecondary
            av.portalTertiary = m.cPortalTertiary
        end if
    end for
    if m.selectingOverlay <> invalid then
        m.selectingOverlay.primaryColor = m.cPortalPrimary
        m.selectingOverlay.portalSecondary = m.cPortalSecondary
        m.selectingOverlay.portalTertiary = m.cPortalTertiary
    end if
    if m.vm <> invalid then
        node = ProfileTransitionNode(m.vm)
        if node <> invalid then
            node.primaryColor = m.cPortalPrimary
            node.portalSecondary = m.cPortalSecondary
            node.portalTertiary = m.cPortalTertiary
        end if
    end if
    EnsureProfileArcBakeTask()
    ProfileArcStartBake(m.profileArcBakeTask, m.global, m.cPortalPrimary, m.cPortalSecondary, m.cPortalTertiary)
end sub


sub ApplyProfileBranding()
    resolved = invalid
    if m.global <> invalid then resolved = m.global.businessResolved

    if resolved <> invalid then
        logoUrl = resolved.brandingLogo
        if logoUrl <> invalid and logoUrl <> "" then
            m.logoPoster.uri = logoUrl
            m.logoPoster.visible = true
            m.logoLabel.visible = false
        else if resolved.appName <> invalid and resolved.appName <> "" then
            m.logoLabel.text = resolved.appName
            m.logoLabel.visible = true
        end if

        url = resolved.loginBackgroundImage
        if url <> invalid and url <> "" then
            m.profileBgUri = url
        else
            m.profileBgUri = "pkg:/images/ui/profile_default_bg_base.png"
        end if
        m.cAvatarBg = m.cNeutral900
    end if

    if m.bgImage <> invalid then
        m.bgImage.uri = m.profileBgUri
    end if
    ApplyProfileFocusBackground()
end sub


' React profile.tsx: loginBackgroundImage while a profile is focused; focusedProfile
' persists when the logout button is focused so the backdrop does not snap to black.
sub ApplyProfileFocusBackground()
    if m.bgImage = invalid then return
    showImage = false
    if m.profilesLoaded = true and m.avatars <> invalid and m.avatars.Count() > 0 then
        if m.focusArea = "profiles" or m.focusArea = "logout" then showImage = true
    end if
    m.bgImage.opacity = 0.0
    if showImage then m.bgImage.opacity = 1.0
end sub

' ── Loading / shimmer ──────────────────────────────────────────────────────────

