sub init()
    m.newHost = m.top.findNode("newHost")
    m.cleanHost = m.top.findNode("cleanHost")
    m.defaultHost = m.top.findNode("defaultHost")
    m.lastFocusTarget = "video"
    CacheFocusNodes()
    OnPanelChanged()
end sub

function PanelContentViewportW() as integer
    w = m.top.contentViewportW
    if w = invalid or w < 1 then return 1920
    return w
end function

function PanelVideoOuterLeft() as integer
    x = m.top.videoOuterX
    if x <> invalid and x >= 0 then return x
    return RL_VideoOuterLeftInBand(PanelContentViewportW())
end function

function PanelDetailHostX() as integer
    x = m.top.panelHostX
    if x <> invalid and x >= 0 then return x
    return PanelVideoOuterLeft() + RL_VideoOuterW() + RL_NewUiOverlayPadLeft()
end function

sub CacheFocusNodes()
    m.newLikeBtn = m.top.findNode("newLikeBtn")
    m.newLikeScale = m.top.findNode("newLikeScale")
    m.newCommentBtn = m.top.findNode("newCommentBtn")
    m.newCommentScale = m.top.findNode("newCommentScale")
    m.newLikeCount = m.top.findNode("newLikeCount")
    m.newCommentCount = m.top.findNode("newCommentCount")
    m.newLikeCircle = m.top.findNode("newLikeCircle")
    m.newLikeRing = m.top.findNode("newLikeRing")
    m.newCommentCircle = m.top.findNode("newCommentCircle")
    m.newCommentRing = m.top.findNode("newCommentRing")
    m.newTitleBg = m.top.findNode("newTitleBg")
    m.newTitleBorder = m.top.findNode("newTitleBorder")
    m.newUserBg = m.top.findNode("newUserBg")
    m.newUserBorder = m.top.findNode("newUserBorder")

    m.newLikeFocusAnim = m.top.findNode("newLikeFocusAnim")
    m.newCommentFocusAnim = m.top.findNode("newCommentFocusAnim")
    m.newLikeScaleInterp = m.top.findNode("newLikeScaleInterp")
    m.newLikeLiftInterp = m.top.findNode("newLikeLiftInterp")
    m.newLikeCountInterp = m.top.findNode("newLikeCountInterp")
    m.newCommentScaleInterp = m.top.findNode("newCommentScaleInterp")
    m.newCommentLiftInterp = m.top.findNode("newCommentLiftInterp")
    m.newCommentCountInterp = m.top.findNode("newCommentCountInterp")

    m.cleanLikeBtn = m.top.findNode("cleanLikeBtn")
    m.cleanLikeScale = m.top.findNode("cleanLikeScale")
    m.cleanCommentBtn = m.top.findNode("cleanCommentBtn")
    m.cleanCommentScale = m.top.findNode("cleanCommentScale")
    m.cleanLikeCount = m.top.findNode("cleanLikeCount")
    m.cleanCommentCount = m.top.findNode("cleanCommentCount")
    m.cleanLikeFocusAnim = m.top.findNode("cleanLikeFocusAnim")
    m.cleanCommentFocusAnim = m.top.findNode("cleanCommentFocusAnim")
    m.cleanLikeScaleInterp = m.top.findNode("cleanLikeScaleInterp")
    m.cleanLikeLiftInterp = m.top.findNode("cleanLikeLiftInterp")
    m.cleanLikeCountInterp = m.top.findNode("cleanLikeCountInterp")
    m.cleanCommentScaleInterp = m.top.findNode("cleanCommentScaleInterp")
    m.cleanCommentLiftInterp = m.top.findNode("cleanCommentLiftInterp")
    m.cleanCommentCountInterp = m.top.findNode("cleanCommentCountInterp")
    m.cleanLikeRing = m.top.findNode("cleanLikeRing")

    m.oldLike = m.top.findNode("oldLike")
    m.oldComment = m.top.findNode("oldComment")
    m.oldActions = m.top.findNode("oldActions")
    m.oldTitleCard = m.top.findNode("oldTitleCard")
    m.oldInfoCard = m.top.findNode("oldInfoCard")
    m.oldCreatorBadge = m.top.findNode("oldCreatorBadge")
    m.oldGenrePill = m.top.findNode("oldGenrePill")
    m.oldInfoEnterAnim = m.top.findNode("oldInfoEnterAnim")
    m.oldTitleEnterAnim = m.top.findNode("oldTitleEnterAnim")
    m.oldActionsEnterAnim = m.top.findNode("oldActionsEnterAnim")

    dur = RL_FocusTransitionSec()
    if m.newLikeFocusAnim <> invalid then m.newLikeFocusAnim.duration = dur
    if m.newCommentFocusAnim <> invalid then m.newCommentFocusAnim.duration = dur
    if m.cleanLikeFocusAnim <> invalid then m.cleanLikeFocusAnim.duration = dur
    if m.cleanCommentFocusAnim <> invalid then m.cleanCommentFocusAnim.duration = dur
end sub

sub OnReelChanged()
    if m.newHost = invalid then return
    reel = m.top.reel
    title = "Untitled Reel"
    creator = ""
    avatar = ""
    genres = "Original Audio"
    cleanGenre = "Original Audio"
    description = ""
    if reel <> invalid then
        if ReelsTitle(reel) <> "" then title = ReelsTitle(reel)
        creator = ReelsCreatorName(reel)
        avatar = ReelsCreatorAvatar(reel)
        description = ReelsDescription(reel)
        names = []
        for each genre in ReelsGenres(reel)
            nm = ReelsFieldName(genre)
            if nm <> "" then names.Push(nm)
        end for
        if names.Count() > 0 then
            genres = JoinReelGenres(names)
            cleanGenre = names[0]
        end if
    end if

    SetPanelText("newTitle", title)
    SetPanelText("newGenres", genres)
    SetPanelText("newCreator", "@" + ReelsFallback(creator, "User"))
    SetPanelText("cleanTitle", title)
    SetPanelText("cleanGenres", cleanGenre)
    SetPanelText("cleanCreator", ReelsFallback(creator, "User"))
    SetPanelText("oldTitle", title)
    SetPanelText("oldDescription", description)
    ' DEFAULT-only chrome — do not touch when CLEAN/NEW is active.
    if UCase(m.top.layout) <> "NEW_UI" and UCase(m.top.layout) <> "CLEAN_UI" then
        ApplyOldCreatorBadge(creator)
        ApplyOldGenrePill(cleanGenre)
    end if

    ApplyPanelAvatar(m.top.findNode("newAvatar"), m.top.findNode("newUserFallback"), avatar)
    ApplyCleanAvatar(avatar, ReelsFallback(creator, "User"))
    showCreator = creator <> "" or avatar <> ""
    m.top.findNode("newUserCard").visible = showCreator
    m.top.findNode("cleanUserCard").visible = showCreator
    m.top.findNode("oldInfoCard").visible = description <> "" or creator <> ""
    OnPanelChanged()
    if UCase(m.top.layout) <> "NEW_UI" and UCase(m.top.layout) <> "CLEAN_UI" then
        PlayOldEnterAnim()
    end if
end sub

sub ApplyOldCreatorBadge(creator as string)
    badge = m.oldCreatorBadge
    lbl = m.top.findNode("oldCreator")
    if badge = invalid or lbl = invalid then return
    if creator = "" then
        badge.visible = false
        lbl.visible = false
        return
    end if
    ' React: p-x-12 p-y-6 rounded-lg fs-20 fw-700 tracking-wide uppercase.
    text = UCase(creator)
    lbl.text = text
    lbl.visible = true
    badge.visible = true
    fontSz = RL_OldUiCreatorFont()
    SetLabelFontSize(lbl, fontSz)
    padX = RL_OldUiCreatorBadgePadX()
    padY = RL_OldUiCreatorBadgePadY()
    badgeH = RL_OldUiCreatorBadgeH()
    ' Bold uppercase + tracking-wide (0.025em) — 0.6 under-pads and clips into corners.
    charW = Int(fontSz * 0.72 + 0.5)
    textW = Len(text) * charW
    if Len(text) > 1 then textW = textW + Int(0.025 * fontSz * (Len(text) - 1) + 0.5)
    if textW < 48 then textW = 48
    badgeW = textW + (padX * 2)
    if badgeW > 320 then
        badgeW = 320
        textW = badgeW - (padX * 2)
    end if
    uriW = 160
    if badgeW > 280 then
        uriW = 320
    else if badgeW > 240 then
        uriW = 280
    else if badgeW > 200 then
        uriW = 240
    else if badgeW > 160 then
        uriW = 200
    else if badgeW > 120 then
        uriW = 160
    else
        uriW = 120
    end if
    badge.uri = "pkg:/images/ui/reels_creator_badge_fill_" + uriW.ToStr() + "x36.png"
    badge.width = badgeW
    badge.height = badgeH
    ' React: linear-gradient(primary-600 → primary-400) — solid primary-600.
    primary = m.top.cPrimary600
    if primary = invalid or primary = "" then primary = m.top.cPrimary500
    if primary = invalid or primary = "" then primary = "0x2563ebff"
    badge.blendColor = primary
    ' Horizontal inset = p-x-12; vertical pad comes from taller badge + vertAlign center.
    lbl.width = textW
    lbl.height = badgeH
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    m.oldCreatorTextW = textW
    m.oldCreatorBadgeW = badgeW
    m.oldCreatorBadgeH = badgeH
    m.oldCreatorPadX = padX
    m.oldCreatorPadY = padY
end sub

sub ApplyOldGenrePill(genre as string)
    pill = m.oldGenrePill
    lbl = m.top.findNode("oldGenres")
    if pill = invalid or lbl = invalid then return
    if genre = "" then genre = "Original Audio"
    lbl.text = genre
    SetLabelFontSize(lbl, RL_OldUiGenreFont())
    textW = Len(genre) * Int(RL_OldUiGenreFont() * 0.55 + 0.5)
    if textW < 40 then textW = 40
    pillW = textW + 32
    if pillW > 280 then pillW = 280
    uriW = 160
    if pillW > 240 then
        uriW = 280
    else if pillW > 200 then
        uriW = 240
    else if pillW > 160 then
        uriW = 200
    else if pillW > 120 then
        uriW = 160
    else
        uriW = 120
    end if
    pillH = RL_OldUiGenrePillH()
    pill.uri = "pkg:/images/ui/reels_genre_pill_fill_" + uriW.ToStr() + "x32.png"
    pill.width = pillW
    pill.height = pillH
    pill.blendColor = "0xffffff26"
    pill.visible = true
    lbl.width = pillW
    lbl.height = pillH
end sub

sub PlayOldEnterAnim()
    ' CLEAN_UI reel-fade-in: opacity 0→1, translateY +20→0; actions delayed 0.2s.
    titleY = RL_OldUiActionsH() + RL_OldUiGap()
    infoY = titleY + 170 + RL_OldUiGap()
    if m.oldTitleCardY <> invalid then titleY = m.oldTitleCardY
    if m.oldInfoCardY <> invalid then infoY = m.oldInfoCardY
    if m.oldTitleCard <> invalid then
        m.oldTitleCard.opacity = 0.0
        m.oldTitleCard.translation = [0, titleY + 20]
    end if
    if m.oldInfoCard <> invalid then
        m.oldInfoCard.opacity = 0.0
        m.oldInfoCard.translation = [0, infoY + 20]
    end if
    if m.oldActions <> invalid then
        m.oldActions.opacity = 0.0
        m.oldActions.translation = [0, 20]
    end if
    titleInterp = m.top.findNode("oldTitleYInterp")
    infoInterp = m.top.findNode("oldInfoYInterp")
    if titleInterp <> invalid then
        titleInterp.keyValue = [[0.0, titleY + 20], [0.0, titleY]]
    end if
    if infoInterp <> invalid then
        infoInterp.keyValue = [[0.0, infoY + 20], [0.0, infoY]]
    end if
    for each animId in ["oldTitleEnterAnim", "oldInfoEnterAnim", "oldActionsEnterAnim"]
        anim = m.top.findNode(animId)
        if anim <> invalid then
            anim.control = "stop"
            anim.control = "start"
        end if
    end for
end sub

sub SettleOldEnterState()
    ' Stop DEFAULT enter anims and snap to end state so CLEAN/NEW never inherit opacity 0.
    titleY = RL_OldUiActionsH() + RL_OldUiGap()
    infoY = titleY + 170 + RL_OldUiGap()
    if m.oldTitleCardY <> invalid then titleY = m.oldTitleCardY
    if m.oldInfoCardY <> invalid then infoY = m.oldInfoCardY
    for each animId in ["oldTitleEnterAnim", "oldInfoEnterAnim", "oldActionsEnterAnim"]
        anim = m.top.findNode(animId)
        if anim <> invalid then anim.control = "stop"
    end for
    if m.oldTitleCard <> invalid then
        m.oldTitleCard.opacity = 1.0
        m.oldTitleCard.translation = [0, titleY]
    end if
    if m.oldInfoCard <> invalid then
        m.oldInfoCard.opacity = 1.0
        m.oldInfoCard.translation = [0, infoY]
    end if
    if m.oldActions <> invalid then
        m.oldActions.opacity = 1.0
        m.oldActions.translation = [0, 0]
    end if
end sub

sub OnPanelChanged()
    if m.newHost = invalid then return
    layout = UCase(m.top.layout)
    m.newHost.visible = layout = "NEW_UI"
    m.cleanHost.visible = layout = "CLEAN_UI"
    m.defaultHost.visible = layout <> "NEW_UI" and layout <> "CLEAN_UI"

    ' Settled DEFAULT chrome when not animating in — avoids opacity=0 bleed after layout switch.
    if layout = "NEW_UI" or layout = "CLEAN_UI" then
        SettleOldEnterState()
    end if

    inset = m.top.topInset
    if inset < 0 then inset = 0
    if layout = "NEW_UI" then
        LayoutNewUiPanel(inset)
    else if layout = "CLEAN_UI" then
        LayoutCleanUiPanel(inset)
    else
        LayoutOldUiPanel(inset)
    end if

    likes = m.top.likesCount.ToStr()
    comments = m.top.commentsCount.ToStr()
    SetPanelText("newLikeCount", likes)
    SetPanelText("newCommentCount", comments)
    SetPanelText("cleanLikeCount", likes)
    SetPanelText("cleanCommentCount", comments)
    SetPanelText("oldLikeCount", likes)
    SetPanelText("oldCommentCount", comments)

    ' React: liked heart fill+stroke #ef4444; else white outline.
    likedIcon32 = "pkg:/images/ui/reels_heart_outline_32.png"
    likedIcon48 = "pkg:/images/ui/reels_heart_outline_48.png"
    if m.top.isLiked then
        likedIcon32 = "pkg:/images/ui/reels_heart_filled_32.png"
        likedIcon48 = "pkg:/images/ui/reels_heart_filled_48.png"
    end if
    m.top.findNode("newLikeIcon").uri = likedIcon32
    m.top.findNode("cleanLikeIcon").uri = likedIcon32
    m.top.findNode("oldLikeIcon").uri = likedIcon48

    ' Content/layout refresh keeps current focus chrome without restarting motion.
    ApplyPanelFocus(false)
end sub

' DEFAULT OldDetailCard — fonts via RL_RemPx (FontScale LARGE); title↔pill = m-b-16; desc line-clamp-4.
sub LayoutOldUiPanel(inset as integer)
    cardW = RL_OldUiCardW()
    pad = RL_OldUiPad()
    gap = RL_OldUiGap()
    titleFont = RL_OldUiTitleFont()
    titleLineH = RL_OldUiTitleLineH()
    titleMb = RL_OldUiTitleMb()
    genreFont = RL_OldUiGenreFont()
    pillH = RL_OldUiGenrePillH()
    descFont = RL_OldUiDescFont()
    descLineH = RL_OldUiDescLineH()
    descLines = RL_OldUiDescMaxLines()
    creatorFont = RL_OldUiCreatorFont()
    badgeH = RL_OldUiCreatorBadgeH()
    creatorMb = RL_OldUiCreatorMb()
    textW = cardW - (pad * 2)

    titleLbl = m.top.findNode("oldTitle")
    genresLbl = m.top.findNode("oldGenres")
    descLbl = m.top.findNode("oldDescription")
    creatorLbl = m.top.findNode("oldCreator")
    SetLabelFontSize(titleLbl, titleFont)
    SetLabelFontSize(genresLbl, genreFont)
    SetLabelFontSize(descLbl, descFont)
    SetLabelFontSize(creatorLbl, creatorFont)
    SetLabelFontSize(m.top.findNode("oldLikeLabel"), RL_OldUiActionLabelFont())
    SetLabelFontSize(m.top.findNode("oldCommentLabel"), RL_OldUiActionLabelFont())
    SetLabelFontSize(m.top.findNode("oldLikeCount"), RL_OldUiActionCountFont())
    SetLabelFontSize(m.top.findNode("oldCommentCount"), RL_OldUiActionCountFont())

    titleText = ""
    if titleLbl <> invalid then titleText = titleLbl.text
    estTitleW = Len(titleText) * Int(titleFont * 0.55 + 0.5)
    titleLines = 1
    if estTitleW > textW then titleLines = 2
    titleTextH = titleLineH * titleLines
    titleCardH = pad + titleTextH + titleMb + pillH + pad

    if titleLbl <> invalid then
        titleLbl.translation = [pad, pad]
        titleLbl.width = textW
        titleLbl.height = titleTextH
        titleLbl.wrap = true
        titleLbl.maxLines = 2
        titleLbl.vertAlign = "top"
    end if

    pillY = pad + titleTextH + titleMb
    pill = m.oldGenrePill
    if pill <> invalid then
        pill.translation = [pad, pillY]
        pill.height = pillH
    end if
    if genresLbl <> invalid then
        genresLbl.translation = [pad, pillY]
        genresLbl.height = pillH
    end if

    titleBg = m.top.findNode("oldTitleBg")
    titleBorder = m.top.findNode("oldTitleBorder")
    if titleBg <> invalid then
        titleBg.width = cardW
        titleBg.height = titleCardH
    end if
    if titleBorder <> invalid then
        titleBorder.width = cardW
        titleBorder.height = titleCardH
    end if

    hasCreator = false
    if m.oldCreatorBadge <> invalid then hasCreator = (m.oldCreatorBadge.visible = true)
    ' Card height follows content (React OldDetailCard) — only reserve used description lines.
    descText = ""
    if descLbl <> invalid then descText = descLbl.text
    hasDesc = (descText <> "")
    usedDescLines = 0
    if hasDesc then
        charsPerLine = Int(textW / (descFont * 0.5 + 0.5))
        if charsPerLine < 12 then charsPerLine = 12
        usedDescLines = Int((Len(descText) + charsPerLine - 1) / charsPerLine)
        if usedDescLines < 1 then usedDescLines = 1
        if usedDescLines > descLines then usedDescLines = descLines
    end if
    descH = descLineH * usedDescLines
    infoCardH = pad * 2
    descY = pad
    if hasCreator then
        infoCardH = pad + badgeH + pad
        if hasDesc then infoCardH = pad + badgeH + creatorMb + descH + pad
        descY = pad + badgeH + creatorMb
        badgeX = pad
        badgeY = pad
        if m.oldCreatorBadge <> invalid then m.oldCreatorBadge.translation = [badgeX, badgeY]
        ' Label: same origin as badge; height = badgeH + vertAlign center → equal top/bottom pad.
        insetX = RL_OldUiCreatorBadgePadX()
        if m.oldCreatorPadX <> invalid then insetX = m.oldCreatorPadX
        if creatorLbl <> invalid then
            creatorLbl.translation = [badgeX + insetX, badgeY]
            if m.oldCreatorTextW <> invalid then creatorLbl.width = m.oldCreatorTextW
            if m.oldCreatorBadgeH <> invalid then
                creatorLbl.height = m.oldCreatorBadgeH
            else
                creatorLbl.height = badgeH
            end if
            creatorLbl.vertAlign = "center"
            creatorLbl.horizAlign = "center"
        end if
        ' Re-tint from live panel fields (theme may arrive after first reel paint).
        primary = m.top.cPrimary600
        if primary = invalid or primary = "" then primary = m.top.cPrimary500
        if primary <> invalid and primary <> "" and m.oldCreatorBadge <> invalid then
            m.oldCreatorBadge.blendColor = primary
        end if
    else if hasDesc then
        infoCardH = pad + descH + pad
    end if

    if descLbl <> invalid then
        descLbl.translation = [pad, descY]
        descLbl.width = textW
        descLbl.visible = hasDesc
        ' LiveTV / comments: height=0 + numLines + ellipsize (maxLines alone caps early).
        descLbl.height = 0
        descLbl.wrap = true
        descLbl.vertAlign = "top"
        descLbl.lineSpacing = RL_OldUiDescLineSpacing()
        if usedDescLines > 0 then
            descLbl.numLines = usedDescLines
        else
            descLbl.numLines = 1
        end if
        descLbl.ellipsizeOnBoundary = true
        descLbl.color = "0xffffffd9"
    end if

    infoBg = m.top.findNode("oldInfoBg")
    infoBorder = m.top.findNode("oldInfoBorder")
    if infoBg <> invalid then
        infoBg.width = cardW
        infoBg.height = infoCardH
    end if
    if infoBorder <> invalid then
        infoBorder.width = cardW
        infoBorder.height = infoCardH
    end if

    titleY = RL_OldUiActionsH() + gap
    infoY = titleY + titleCardH + gap
    m.oldTitleCardY = titleY
    m.oldInfoCardY = infoY
    m.oldTitleCardH = titleCardH
    m.oldInfoCardH = infoCardH

    if m.oldTitleCard <> invalid then m.oldTitleCard.translation = [0, titleY]
    if m.oldInfoCard <> invalid then m.oldInfoCard.translation = [0, infoY]

    m.defaultHost.translation = [PanelDetailHostX(), inset + 120]
end sub

function PlayHeartPulse() as boolean
    RunHeartPulse()
    return true
end function

' React CLEAN_UI: flex center; left info items-end pb-[10%] pr-[30px]; right pl-[80px] items-center.
sub LayoutCleanUiPanel(inset as integer)
    cardW = RL_CleanUiCardW()
    padX = RL_CleanUiCardPadX()
    padY = RL_CleanUiCardPadY()
    titleFont = RL_CleanUiTitleFont()
    creatorFont = RL_CleanUiCreatorFont()
    genreFont = RL_CleanUiGenreFont()
    countFont = RL_CleanUiCountFont()
    avatarSz = RL_CleanUiAvatarSize()

    titleLbl = m.top.findNode("cleanTitle")
    genresLbl = m.top.findNode("cleanGenres")
    creatorLbl = m.top.findNode("cleanCreator")
    SetLabelFontSize(titleLbl, titleFont)
    SetLabelFontSize(genresLbl, genreFont)
    SetLabelFontSize(creatorLbl, creatorFont)
    SetLabelFontSize(m.top.findNode("cleanLikeCount"), countFont)
    SetLabelFontSize(m.top.findNode("cleanCommentCount"), countFont)
    SetLabelFontSize(m.top.findNode("cleanAvatarInitial"), creatorFont)

    titleLineH = RL_CleanUiTitleLineH()
    titleText = ""
    if titleLbl <> invalid then titleText = titleLbl.text
    titleMaxW = cardW - (padX * 2)
    estTitleW = Len(titleText) * Int(titleFont * 0.55 + 0.5)
    titleLines = 1
    if estTitleW > titleMaxW then titleLines = 2
    titleTextH = titleLineH * titleLines
    ' py-1.5 capsule — height locked to 32px genre-pill assets.
    pillH = 32
    titleCardH = padY + titleTextH + RL_CleanUiTitleMb() + pillH + padY
    userCardH = RL_CleanUiUserCardH()
    cardGap = RL_CleanUiCardGap()

    if titleLbl <> invalid then
        titleLbl.translation = [padX, padY]
        titleLbl.width = titleMaxW
        titleLbl.height = titleTextH
        titleLbl.vertAlign = "top"
        titleLbl.horizAlign = "left"
        titleLbl.visible = true
    end if

    pill = m.top.findNode("cleanGenrePill")
    pillText = "Original Audio"
    if genresLbl <> invalid and genresLbl.text <> "" then pillText = genresLbl.text
    ' px-4 (16+16) + text width; pick nearest pre-rendered capsule asset.
    pillInnerW = Len(pillText) * Int(genreFont * 0.58 + 0.5)
    if pillInnerW < 48 then pillInnerW = 48
    pillW = pillInnerW + 32
    if pillW > cardW - (padX * 2) then pillW = cardW - (padX * 2)
    pillAssetW = 160
    if pillW <= 120 then
        pillAssetW = 120
    else if pillW <= 160 then
        pillAssetW = 160
    else if pillW <= 200 then
        pillAssetW = 200
    else if pillW <= 240 then
        pillAssetW = 240
    else
        pillAssetW = 280
    end if
    pillW = pillAssetW
    pillY = padY + titleTextH + RL_CleanUiTitleMb()
    if pill <> invalid then pill.translation = [padX, pillY]
    pillBg = m.top.findNode("cleanGenrePillBg")
    pillRing = m.top.findNode("cleanGenrePillRing")
    fillUri = "pkg:/images/ui/reels_genre_pill_fill_" + pillAssetW.ToStr() + "x32.png"
    ringUri = "pkg:/images/ui/reels_genre_pill_ring_" + pillAssetW.ToStr() + "x32.png"
    if pillBg <> invalid then
        pillBg.uri = fillUri
        pillBg.width = pillW
        pillBg.height = pillH
        ' Transparent fill — React pill is border-only + backdrop-blur.
        pillBg.blendColor = "0xffffff00"
    end if
    if pillRing <> invalid then
        pillRing.uri = ringUri
        pillRing.width = pillW
        pillRing.height = pillH
        ' border-white/30
        pillRing.blendColor = "0xffffff4d"
    end if
    if genresLbl <> invalid then
        genresLbl.translation = [0, 0]
        genresLbl.width = pillW
        genresLbl.height = pillH
        genresLbl.horizAlign = "center"
    end if

    titleBg = m.top.findNode("cleanTitleBg")
    titleBorder = m.top.findNode("cleanTitleBorder")
    ' Prefer native-size fill/border so rounded-[24px] is not stretched.
    titleUriH = 112
    if titleCardH > 130 then titleUriH = 148
    titleFillUri = "pkg:/images/ui/reels_card_fill_400x" + titleUriH.ToStr() + ".png"
    titleBorderUri = "pkg:/images/ui/reels_card_border_400x" + titleUriH.ToStr() + ".png"
    if titleBg <> invalid then
        titleBg.width = cardW
        titleBg.height = titleCardH
        titleBg.uri = titleFillUri
        titleBg.blendColor = "0xffffff26"
    end if
    if titleBorder <> invalid then
        titleBorder.width = cardW
        titleBorder.height = titleCardH
        titleBorder.uri = titleBorderUri
        titleBorder.blendColor = "0xffffff0d"
    end if

    userCard = m.top.findNode("cleanUserCard")
    hasCreator = false
    if userCard <> invalid then hasCreator = (userCard.visible = true)

    avatarBg = m.top.findNode("cleanAvatarBg")
    avatarMask = m.top.findNode("cleanAvatarMask")
    avatar = m.top.findNode("cleanAvatar")
    avatarRing = m.top.findNode("cleanAvatarRing")
    avatarInitial = m.top.findNode("cleanAvatarInitial")
    userBg = m.top.findNode("cleanUserBg")
    userBorder = m.top.findNode("cleanUserBorder")
    verified = m.top.findNode("cleanVerified")

    if avatarBg <> invalid then
        avatarBg.translation = [padX, padY]
        avatarBg.width = avatarSz
        avatarBg.height = avatarSz
    end if
    if avatarMask <> invalid then
        avatarMask.translation = [padX + 2, padY + 2]
        avatarMask.maskSize = [avatarSz - 4, avatarSz - 4]
    end if
    if avatar <> invalid then
        avatar.width = avatarSz - 4
        avatar.height = avatarSz - 4
    end if
    if avatarRing <> invalid then
        avatarRing.translation = [padX, padY]
        avatarRing.width = avatarSz
        avatarRing.height = avatarSz
    end if
    if avatarInitial <> invalid then
        avatarInitial.translation = [padX, padY]
        avatarInitial.width = avatarSz
        avatarInitial.height = avatarSz
    end if

    nameX = padX + avatarSz + RL_CleanUiAvatarTextGap()
    creatorName = ""
    if creatorLbl <> invalid then creatorName = creatorLbl.text
    verifiedW = 72
    verifiedH = 20
    nameVerifiedGap = 8
    ' Remaining row after avatar — full name fits; Verified sits after text (gap-2).
    nameMaxW = cardW - nameX - padX - verifiedW - nameVerifiedGap
    if nameMaxW < 80 then nameMaxW = 80
    textW = Len(creatorName) * Int(creatorFont * 0.62 + 0.5)
    if textW < 40 then textW = 40
    if textW > nameMaxW then textW = nameMaxW
    if creatorLbl <> invalid then
        creatorLbl.translation = [nameX, padY]
        creatorLbl.width = nameMaxW
        creatorLbl.height = avatarSz
    end if
    if verified <> invalid then
        verified.translation = [nameX + textW + nameVerifiedGap, padY + Int((avatarSz - verifiedH) / 2)]
    end if
    verifiedBg = m.top.findNode("cleanVerifiedBg")
    if verifiedBg <> invalid then
        verifiedBg.width = verifiedW
        verifiedBg.height = verifiedH
    end if
    if userBg <> invalid then
        userBg.width = cardW
        userBg.height = userCardH
        userBg.blendColor = "0xffffff26"
    end if
    if userBorder <> invalid then
        userBorder.width = cardW
        userBorder.height = userCardH
        userBorder.blendColor = "0xffffff0d"
    end if

    stackH = titleCardH
    if hasCreator then stackH = stackH + cardGap + userCardH

    contentH = 1080 - inset
    ' React: pb-[10%] on the left column — CSS % padding uses containing-block width.
    padBottom = RL_CleanUiInfoPb()
    outerW = RL_VideoOuterW()
    videoLeft = PanelVideoOuterLeft()

    infoX = videoLeft - RL_CleanUiInfoPr() - cardW
    if infoX < 16 then infoX = 16
    infoY = inset + contentH - padBottom - stackH
    if infoY < inset then infoY = inset

    titleCard = m.top.findNode("cleanTitleCard")
    if titleCard <> invalid then titleCard.translation = [0, 0]
    if userCard <> invalid then userCard.translation = [0, titleCardH + cardGap]

    m.cleanHost.translation = [0, 0]
    m.top.findNode("cleanInfo").translation = [infoX, infoY]

    countGap = 12
    actionsGap = RL_CleanUiActionsGap()
    commentY = 80 + countGap + countFont + actionsGap
    likeCount = m.top.findNode("cleanLikeCount")
    commentCount = m.top.findNode("cleanCommentCount")
    if likeCount <> invalid then likeCount.translation = [-10, 80 + countGap]
    if commentCount <> invalid then commentCount.translation = [-10, 80 + countGap]
    commentNode = m.top.findNode("cleanComment")
    if commentNode <> invalid then commentNode.translation = [0, commentY]
    m.cleanCommentBaseY = commentY

    actionsH = commentY + 80 + countGap + countFont
    actionsX = videoLeft + outerW + RL_CleanUiActionsPl()
    actionsY = inset + Int((contentH - actionsH) / 2) + 10
    if actionsY < inset then actionsY = inset
    m.top.findNode("cleanActions").translation = [actionsX, actionsY]
end sub

sub LayoutNewUiPanel(inset as integer)
    titleCard = m.top.findNode("newTitleCard")
    userCard = m.top.findNode("newUserCard")
    actions = m.top.findNode("newActions")
    titleBg = m.top.findNode("newTitleBg")
    titleBorder = m.top.findNode("newTitleBorder")
    titleLbl = m.top.findNode("newTitle")
    genresLbl = m.top.findNode("newGenres")
    musicIcon = m.top.findNode("musicIcon")
    creatorLbl = m.top.findNode("newCreator")

    titleFont = RL_NewUiTitleFont()
    genreFont = RL_NewUiGenreFont()
    creatorFont = RL_NewUiCreatorFont()
    countFont = RL_NewUiCountFont()
    SetLabelFontSize(titleLbl, titleFont)
    SetLabelFontSize(genresLbl, genreFont)
    SetLabelFontSize(creatorLbl, creatorFont)
    SetLabelFontSize(m.top.findNode("newLikeCount"), countFont)
    SetLabelFontSize(m.top.findNode("newCommentCount"), countFont)

    cardW = RL_NewUiCardW()
    titleH = RL_NewUiTitleCardH()
    userH = RL_NewUiUserCardH()
    actionsH = RL_NewUiActionsBlockH()
    gap = RL_NewUiCardGap()
    actionsMt = RL_NewUiActionsMt()
    padBottom = RL_NewUiPanelPadBottom()
    padX = RL_NewUiPanelPadX()

    titleTextH = titleFont * 2
    musicY = 16 + titleTextH + 8
    musicSz = RL_NewUiMusicIcon()
    musicGap = RL_NewUiMusicGap()
    if titleLbl <> invalid then
        titleLbl.translation = [padX, 16]
        titleLbl.width = cardW - (padX * 2)
        titleLbl.height = titleTextH
    end if
    if musicIcon <> invalid then
        musicIcon.width = musicSz
        musicIcon.height = musicSz
        musicIcon.translation = [padX, musicY]
        musicIcon.opacity = 0.8
    end if
    if genresLbl <> invalid then
        ' flex items-center gap-6 (24px): text shares the icon row height.
        genresLbl.translation = [padX + musicSz + musicGap, musicY]
        genresLbl.width = cardW - padX - (padX + musicSz + musicGap)
        genresLbl.height = musicSz
    end if
    if titleBg <> invalid then
        titleBg.width = cardW
        titleBg.height = titleH
    end if
    if titleBorder <> invalid then
        titleBorder.width = cardW
        titleBorder.height = titleH
    end if

    avatarSz = RL_NewUiAvatarSize()
    avatarGap = RL_NewUiAvatarTextGap()
    avatarMask = m.top.findNode("newAvatarMask")
    avatar = m.top.findNode("newAvatar")
    avatarRing = m.top.findNode("newAvatarRing")
    userBg = m.top.findNode("newUserBg")
    userBorder = m.top.findNode("newUserBorder")
    if avatarMask <> invalid then
        avatarMask.translation = [padX, 16]
        avatarMask.maskSize = [avatarSz, avatarSz]
    end if
    if avatar <> invalid then
        avatar.width = avatarSz
        avatar.height = avatarSz
    end if
    if avatarRing <> invalid then
        avatarRing.translation = [padX, 16]
        avatarRing.width = avatarSz
        avatarRing.height = avatarSz
    end if
    if creatorLbl <> invalid then
        creatorLbl.translation = [padX + avatarSz + avatarGap, 16]
        creatorLbl.width = cardW - (padX + avatarSz + avatarGap) - padX
        creatorLbl.height = avatarSz
    end if
    if userBg <> invalid then
        userBg.width = cardW
        userBg.height = userH
    end if
    if userBorder <> invalid then
        userBorder.width = cardW
        userBorder.height = userH
    end if

    hasCreator = false
    if userCard <> invalid then hasCreator = (userCard.visible = true)

    stackH = titleH + gap
    if hasCreator then stackH = stackH + userH + gap
    stackH = stackH + actionsMt + actionsH

    contentH = 1080 - inset
    hostY = inset + (contentH - padBottom - stackH)
    if hostY < inset then hostY = inset
    hostX = PanelDetailHostX()
    m.newHost.translation = [hostX, hostY]

    y = 0
    if titleCard <> invalid then
        titleCard.translation = [0, y]
        titleCard.scale = [1.0, 1.0]
    end if
    y = y + titleH + gap
    if userCard <> invalid then
        userCard.translation = [0, y]
        userCard.scale = [1.0, 1.0]
        if hasCreator then y = y + userH + gap
    end if
    y = y + actionsMt
    if actions <> invalid then actions.translation = [RL_NewUiActionsMl(), y]
end sub

sub SetLabelFontSize(lbl as object, sz as integer)
    if lbl = invalid then return
    if lbl.font = invalid then return
    lbl.font.size = sz
end sub

sub OnFocusTargetChanged()
    if m.newHost = invalid then return
    ApplyPanelFocus(true)
end sub

sub ApplyPanelFocus(animate as boolean)
    target = m.top.focusTarget
    pulseActive = (m.heartPulseActive = true)
    white = "0xffffffff"
    ' React NewCircleButton: unfocused rgba(255,255,255,0.15); focused 0.40 + white border.
    glass15 = "0xffffff26"
    glass40 = "0xffffff66"
    glass35 = "0xffffff59"
    border05 = "0xffffff0d"
    transparent = "0x00000000"
    layout = UCase(m.top.layout)
    isClean = (layout = "CLEAN_UI")
    isNew = (layout = "NEW_UI")
    isDefault = (not isClean and not isNew)
    likeOn = (target = "like")
    commentOn = (target = "comment")

    if isClean then
        ApplyCleanPanelFocus(likeOn, commentOn, animate, pulseActive, glass15, glass40, border05, white)
    else if isNew then
        ApplyNewPanelFocus(target, likeOn, commentOn, animate, pulseActive, glass15, glass40, glass35, border05, white)
    else if isDefault then
        ApplyDefaultPanelFocus(target, likeOn, commentOn, pulseActive, glass15, transparent, white)
    end if

    m.lastFocusTarget = target
end sub

sub ApplyCleanPanelFocus(likeOn as boolean, commentOn as boolean, animate as boolean, pulseActive as boolean, glass15 as string, glass40 as string, border05 as string, white as string)
    m.top.findNode("cleanLikeCircle").blendColor = glass15
    m.top.findNode("cleanCommentCircle").blendColor = glass15
    m.top.findNode("cleanLikeRing").blendColor = border05
    m.top.findNode("cleanCommentRing").blendColor = border05
    if likeOn then
        m.top.findNode("cleanLikeCircle").blendColor = glass40
        m.top.findNode("cleanLikeRing").blendColor = white
    end if
    if commentOn then
        m.top.findNode("cleanCommentCircle").blendColor = glass40
        m.top.findNode("cleanCommentRing").blendColor = white
    end if
    RunCircleFocus("like", likeOn, animate and not pulseActive)
    RunCircleFocus("comment", commentOn, animate)
end sub

sub ApplyNewPanelFocus(target as string, likeOn as boolean, commentOn as boolean, animate as boolean, pulseActive as boolean, glass15 as string, glass40 as string, glass35 as string, border05 as string, white as string)
    ' Detail cards: glass + ring only — no scale/lift.
    SetCardFocusChrome(m.newTitleBg, m.newTitleBorder, false, glass15, glass35, border05, white)
    SetCardFocusChrome(m.newUserBg, m.newUserBorder, false, glass15, glass35, border05, white)
    ResetCardLayoutNoScale(m.top.findNode("newTitleCard"))
    ResetCardLayoutNoScale(m.top.findNode("newUserCard"))
    SetCircleFocusChrome(likeOn, glass15, glass40, border05, white)
    SetCommentFocusChrome(commentOn, glass15, glass40, border05, white)
    RunCircleFocus("like", likeOn, animate and not pulseActive)
    RunCircleFocus("comment", commentOn, animate)
    if target = "detail0" then
        SetCardFocusChrome(m.newTitleBg, m.newTitleBorder, true, glass15, glass35, border05, white)
    else if target = "detail1" then
        SetCardFocusChrome(m.newUserBg, m.newUserBorder, true, glass15, glass35, border05, white)
    end if
end sub

sub ApplyDefaultPanelFocus(target as string, likeOn as boolean, commentOn as boolean, pulseActive as boolean, glass15 as string, transparent as string, white as string)
    ' OldActionButton idle: border transparent in React — on Roku use same faint white/08 as cards
    ' (0x00000000 blend leaves the white ring PNG fully visible on sim).
    ' OldDetailCard idle: rgba(255,255,255,0.08); focused: rgba(255,255,255,0.4).
    likeBorder = m.top.findNode("oldLikeBorder")
    commentBorder = m.top.findNode("oldCommentBorder")
    titleBorder = m.top.findNode("oldTitleBorder")
    infoBorder = m.top.findNode("oldInfoBorder")
    idleBorder = "0xffffff14"
    focusBorder = "0xffffff66"
    ' Pulse owns Like chrome sizes (same as CLEAN circle pulse) — do not snap mid-beat.
    if pulseActive <> true then EnsureOldLikeChromeSize()
    m.top.findNode("oldLikeBg").blendColor = "0xffffff14"
    m.top.findNode("oldCommentBg").blendColor = "0xffffff14"
    m.top.findNode("oldTitleBg").blendColor = "0xffffff14"
    m.top.findNode("oldInfoBg").blendColor = "0xffffff14"
    if likeBorder <> invalid then likeBorder.blendColor = idleBorder
    if commentBorder <> invalid then commentBorder.blendColor = idleBorder
    if titleBorder <> invalid then titleBorder.blendColor = idleBorder
    if infoBorder <> invalid then infoBorder.blendColor = idleBorder
    m.top.findNode("oldLikeCount").color = transparent
    m.top.findNode("oldCommentCount").color = transparent
    ' Focus scale is baked into pulse poster sizes (CLEAN pattern) — keep Group.scale at 1.
    if m.oldLike <> invalid then m.oldLike.scale = [1.0, 1.0]
    if m.oldComment <> invalid then m.oldComment.scale = [1.0, 1.0]

    if likeOn then
        m.top.findNode("oldLikeBg").blendColor = glass15
        if likeBorder <> invalid then likeBorder.blendColor = focusBorder
        if pulseActive <> true then ApplyOldLikeFocusScale(true)
        m.top.findNode("oldLikeCount").color = white
    else if pulseActive <> true then
        ApplyOldLikeFocusScale(false)
    end if
    if commentOn then
        m.top.findNode("oldCommentBg").blendColor = glass15
        if commentBorder <> invalid then commentBorder.blendColor = focusBorder
        if m.oldComment <> invalid then m.oldComment.scale = [1.05, 1.05]
        m.top.findNode("oldCommentCount").color = white
    end if
    if target = "detail0" then
        m.top.findNode("oldTitleBg").blendColor = glass15
        if titleBorder <> invalid then titleBorder.blendColor = focusBorder
    else if target = "detail1" then
        m.top.findNode("oldInfoBg").blendColor = glass15
        if infoBorder <> invalid then infoBorder.blendColor = focusBorder
    end if
end sub

' Restores idle 250×150 Like chrome + icon/label layout (never leave pulse mid-sizes).
sub EnsureOldLikeChromeSize()
    ApplyOldLikePulseLayout(1.0)
end sub

' OldActionButton focus scale(1.05) via poster bounds (Group.scale unreliable on sim).
sub ApplyOldLikeFocusScale(focused as boolean)
    if focused then
        ApplyOldLikePulseLayout(1.05)
    else
        ApplyOldLikePulseLayout(1.0)
    end if
end sub

' Center-pump layout for the 250×150 Like card — identical math to CLEAN's 80×80 circle pulse.
sub ApplyOldLikePulseLayout(f as float)
    if f > 1.2 then f = 1.2
    if f < 0.7 then f = 0.7
    cw = 250
    ch = 150
    w = Int(cw * f + 0.5)
    h = Int(ch * f + 0.5)
    if w < 120 then w = 120
    if h < 72 then h = 72
    offX = (cw - w) / 2.0
    offY = (ch - h) / 2.0
    bg = m.top.findNode("oldLikeBg")
    border = m.top.findNode("oldLikeBorder")
    icon = m.top.findNode("oldLikeIcon")
    lbl = m.top.findNode("oldLikeLabel")
    count = m.top.findNode("oldLikeCount")
    if bg <> invalid then
        bg.width = w
        bg.height = h
        bg.translation = [offX, offY]
    end if
    if border <> invalid then
        border.width = w
        border.height = h
        border.translation = [offX, offY]
    end if
    ' Base icon center (125, 44); label/count centers map around card center (125, 75).
    iconSz = Int(48 * f + 0.5)
    if iconSz < 24 then iconSz = 24
    if icon <> invalid then
        icon.width = iconSz
        icon.height = iconSz
        icon.translation = [125.0 - iconSz / 2.0, 75.0 + (44.0 - 75.0) * f - iconSz / 2.0]
    end if
    labelH = Int(30 * f + 0.5)
    if labelH < 18 then labelH = 18
    if lbl <> invalid then
        lbl.width = w
        lbl.height = labelH
        lbl.translation = [offX, 75.0 + (91.0 - 75.0) * f - labelH / 2.0]
        SetLabelFontSize(lbl, Int(RL_OldUiActionLabelFont() * f + 0.5))
    end if
    countH = Int(32 * f + 0.5)
    if countH < 18 then countH = 18
    if count <> invalid then
        count.width = w
        count.height = countH
        count.translation = [offX, 75.0 + (124.0 - 75.0) * f - countH / 2.0]
        SetLabelFontSize(count, Int(RL_OldUiActionCountFont() * f + 0.5))
    end if
end sub

sub SetCircleFocusChrome(focused as boolean, glass15 as string, glass40 as string, border05 as string, white as string)
    if m.newLikeCircle = invalid then return
    if focused then
        m.newLikeCircle.blendColor = glass40
        m.newLikeRing.blendColor = white
    else
        m.newLikeCircle.blendColor = glass15
        m.newLikeRing.blendColor = border05
    end if
end sub

sub SetCommentFocusChrome(focused as boolean, glass15 as string, glass40 as string, border05 as string, white as string)
    if m.newCommentCircle = invalid then return
    if focused then
        m.newCommentCircle.blendColor = glass40
        m.newCommentRing.blendColor = white
    else
        m.newCommentCircle.blendColor = glass15
        m.newCommentRing.blendColor = border05
    end if
end sub

sub SetCardFocusChrome(bg as object, border as object, focused as boolean, glass15 as string, glass35 as string, border05 as string, white as string)
    if bg = invalid then return
    if focused then
        bg.blendColor = glass35
        if border <> invalid then border.blendColor = white
    else
        bg.blendColor = glass15
        if border <> invalid then border.blendColor = border05
    end if
end sub

' React NewCircleButton: scale(1.15) translateY(-6) + count opacity over duration-400.
' Scale pivots at circle center via newLikeScale; lift stays on outer btn group.
sub RunCircleFocus(which as string, focused as boolean, animate as boolean)
    isClean = (UCase(m.top.layout) = "CLEAN_UI")
    liftNode = m.newLikeBtn
    scaleNode = m.newLikeScale
    count = m.newLikeCount
    anim = m.newLikeFocusAnim
    scaleInterp = m.newLikeScaleInterp
    liftInterp = m.newLikeLiftInterp
    countInterp = m.newLikeCountInterp
    if isClean then
        liftNode = m.cleanLikeBtn
        scaleNode = m.cleanLikeScale
        count = m.cleanLikeCount
        anim = m.cleanLikeFocusAnim
        scaleInterp = m.cleanLikeScaleInterp
        liftInterp = m.cleanLikeLiftInterp
        countInterp = m.cleanLikeCountInterp
    end if
    if which = "comment" then
        if isClean then
            liftNode = m.cleanCommentBtn
            scaleNode = m.cleanCommentScale
            count = m.cleanCommentCount
            anim = m.cleanCommentFocusAnim
            scaleInterp = m.cleanCommentScaleInterp
            liftInterp = m.cleanCommentLiftInterp
            countInterp = m.cleanCommentCountInterp
        else
            liftNode = m.newCommentBtn
            scaleNode = m.newCommentScale
            count = m.newCommentCount
            anim = m.newCommentFocusAnim
            scaleInterp = m.newCommentScaleInterp
            liftInterp = m.newCommentLiftInterp
            countInterp = m.newCommentCountInterp
        end if
    end if
    if liftNode = invalid or scaleNode = invalid then return

    targetScale = 1.0
    targetLift = 0.0
    targetOp = 0.0
    if focused then
        targetScale = 1.15
        targetLift = -6.0
        targetOp = 1.0
    end if

    ' Heart-pulse owns like scale — ApplyPanelFocus must not snap it mid-animation.
    if which = "like" and m.heartPulseActive = true then
        liftNode.translation = [0.0, targetLift]
        if count <> invalid then count.opacity = targetOp
        return
    end if

    curScale = 1.0
    if scaleNode.scale <> invalid then curScale = scaleNode.scale[0]
    curLift = 0.0
    if liftNode.translation <> invalid then curLift = liftNode.translation[1]
    curOp = 0.0
    if count <> invalid then curOp = count.opacity

    near = Abs(curScale - targetScale) < 0.001 and Abs(curLift - targetLift) < 0.1 and Abs(curOp - targetOp) < 0.01
    if near then
        scaleNode.scale = [targetScale, targetScale]
        liftNode.translation = [0.0, targetLift]
        if count <> invalid then count.opacity = targetOp
        return
    end if

    if not animate or anim = invalid or scaleInterp = invalid then
        if anim <> invalid then anim.control = "stop"
        scaleNode.scale = [targetScale, targetScale]
        liftNode.translation = [0.0, targetLift]
        if count <> invalid then count.opacity = targetOp
        return
    end if

    scaleInterp.keyValue = [[curScale, curScale], [targetScale, targetScale]]
    liftInterp.keyValue = [[0.0, curLift], [0.0, targetLift]]
    if countInterp <> invalid then countInterp.keyValue = [curOp, targetOp]
    anim.control = "stop"
    anim.control = "start"
end sub

' Like pulse (React .heart-pulse 400ms): shrink → pump → slight dip → settle.
' ⚠ Parity Note: brs-engine ignores nested Group.scale — CLEAN/NEW/DEFAULT all resize
' Poster bounds from center (circle 80×80 / OldActionButton 250×150).
sub RunHeartPulse()
    layout = UCase(m.top.layout)
    m.pulseIsOld = false
    m.pulseScaleNode = m.newLikeScale
    m.pulseCircle = m.top.findNode("newLikeCircle")
    m.pulseRing = m.top.findNode("newLikeRing")
    m.pulseIcon = m.top.findNode("newLikeIcon")
    focusAnim = m.newLikeFocusAnim
    if layout = "CLEAN_UI" then
        m.pulseScaleNode = m.cleanLikeScale
        m.pulseCircle = m.top.findNode("cleanLikeCircle")
        m.pulseRing = m.top.findNode("cleanLikeRing")
        m.pulseIcon = m.top.findNode("cleanLikeIcon")
        focusAnim = m.cleanLikeFocusAnim
    else if layout <> "NEW_UI" then
        m.pulseIsOld = true
        m.pulseScaleNode = invalid
        m.pulseCircle = m.top.findNode("oldLikeBg")
        m.pulseRing = m.top.findNode("oldLikeBorder")
        m.pulseIcon = m.top.findNode("oldLikeIcon")
        focusAnim = invalid
        if m.oldLike <> invalid then m.oldLike.scale = [1.0, 1.0]
    end if
    if m.pulseCircle = invalid and m.pulseIcon = invalid then
        return
    end if

    if focusAnim <> invalid then focusAnim.control = "stop"
    if m.pulseStepTimer <> invalid then m.pulseStepTimer.control = "stop"

    ' Ceiling = current like size. CLEAN/NEW focus 1.15; DEFAULT OldActionButton focus 1.05.
    base = 1.0
    if m.top.focusTarget = "like" then
        if m.pulseIsOld = true then
            base = 1.05
        else
            base = 1.15
        end if
    end if
    m.pulseBaseScale = base
    m.pulseMaxScale = base
    m.heartPulseActive = true
    m.pulseStep = 0

    if m.pulseIsOld <> true and m.pulseScaleNode <> invalid then m.pulseScaleNode.scale = [1.0, 1.0]
    ' Same beat as CLEAN: shrink first, then pump back up to current size (not past it).
    ApplyHeartPulseScale(m.pulseMaxScale * 0.82)

    if m.pulseStepTimer = invalid then
        m.pulseStepTimer = CreateObject("roSGNode", "Timer")
        m.pulseStepTimer.repeat = true
        m.top.appendChild(m.pulseStepTimer)
        m.pulseStepTimer.observeField("fire", "OnHeartPulseStep")
    end if
    m.pulseStepTimer.duration = 0.12
    m.pulseStepTimer.control = "start"
end sub

sub ApplyHeartPulseScale(absScale as float)
    f = absScale
    if f > m.pulseMaxScale then f = m.pulseMaxScale
    if f < 0.7 then f = 0.7

    if m.pulseIsOld = true then
        ' Full rectangle from center — same relative beat as CLEAN full-circle pulse.
        ApplyOldLikePulseLayout(f)
        return
    end if

    btn = Int(80 * f + 0.5)
    if btn < 40 then btn = 40
    off = (80 - btn) / 2.0
    ' Size only — focus glass/ring stays under ApplyPanelFocus (pulse must not look focused).
    if m.pulseCircle <> invalid then
        m.pulseCircle.width = btn
        m.pulseCircle.height = btn
        m.pulseCircle.translation = [off, off]
    end if
    if m.pulseRing <> invalid then
        m.pulseRing.width = btn
        m.pulseRing.height = btn
        m.pulseRing.translation = [off, off]
    end if
    icon = Int(32 * f + 0.5)
    if icon < 16 then icon = 16
    if m.pulseIcon <> invalid then
        m.pulseIcon.width = icon
        m.pulseIcon.height = icon
        m.pulseIcon.translation = [(80 - icon) / 2.0, (80 - icon) / 2.0]
    end if
end sub

sub OnHeartPulseStep()
    if m.heartPulseActive <> true then return
    m.pulseStep = m.pulseStep + 1
    if m.pulseStep = 1 then
        ' Pump up to focused max size.
        m.pulseStepTimer.duration = 0.18
        ApplyHeartPulseScale(m.pulseMaxScale)
    else if m.pulseStep = 2 then
        ' Slight dip under max, still below focus ceiling.
        m.pulseStepTimer.duration = 0.1
        ApplyHeartPulseScale(m.pulseMaxScale * 0.92)
    else if m.pulseStep = 3 then
        ApplyHeartPulseScale(m.pulseBaseScale)
        FinishHeartPulse()
    else
        FinishHeartPulse()
    end if
end sub

sub FinishHeartPulse()
    if m.pulseStepTimer <> invalid then m.pulseStepTimer.control = "stop"
    if m.pulseIsOld = true then
        ' Settle at focus/idle size via same center layout (never 80×80 circle reset).
        ApplyOldLikePulseLayout(m.pulseBaseScale)
    else
        if m.pulseCircle <> invalid then
            m.pulseCircle.width = 80
            m.pulseCircle.height = 80
            m.pulseCircle.translation = [0, 0]
        end if
        if m.pulseRing <> invalid then
            m.pulseRing.width = 80
            m.pulseRing.height = 80
            m.pulseRing.translation = [0, 0]
        end if
        if m.pulseIcon <> invalid then
            m.pulseIcon.width = 32
            m.pulseIcon.height = 32
            m.pulseIcon.translation = [24, 24]
        end if
        if m.pulseScaleNode <> invalid then
            s = m.pulseBaseScale
            m.pulseScaleNode.scale = [s, s]
        end if
    end if
    m.pulseScaleNode = invalid
    m.pulseCircle = invalid
    m.pulseRing = invalid
    m.pulseIcon = invalid
    m.heartPulseActive = false
    ApplyPanelFocus(false)
end sub

' Detail cards keep fixed layout size. React NewDetailCard uses scale(1.03) on focus;
' ⚠ Parity Note: Roku shows glass + white ring only (no scale), per product focus chrome.
sub ResetCardLayoutNoScale(card as object)
    if card = invalid then return
    card.scale = [1.0, 1.0]
    if card.id = "newTitleCard" then
        bg = m.top.findNode("newTitleBg")
        border = m.top.findNode("newTitleBorder")
        h = RL_NewUiTitleCardH()
        w = RL_NewUiCardW()
        if bg <> invalid then
            bg.width = w
            bg.height = h
        end if
        if border <> invalid then
            border.width = w
            border.height = h
        end if
    else if card.id = "newUserCard" then
        bg = m.top.findNode("newUserBg")
        border = m.top.findNode("newUserBorder")
        h = RL_NewUiUserCardH()
        w = RL_NewUiCardW()
        if bg <> invalid then
            bg.width = w
            bg.height = h
        end if
        if border <> invalid then
            border.width = w
            border.height = h
        end if
    end if
end sub

sub ApplyCleanAvatar(uri as string, creatorName as string)
    avatar = m.top.findNode("cleanAvatar")
    mask = m.top.findNode("cleanAvatarMask")
    initial = m.top.findNode("cleanAvatarInitial")
    ring = m.top.findNode("cleanAvatarRing")
    if avatar = invalid then return
    letter = "U"
    if creatorName <> "" then letter = UCase(Left(creatorName, 1))
    if uri <> "" then
        avatar.uri = uri
        avatar.blendColor = "0xffffffff"
        if mask <> invalid then mask.visible = true
        if initial <> invalid then initial.visible = false
        if ring <> invalid then ring.visible = true
    else
        if mask <> invalid then mask.visible = false
        if initial <> invalid then
            initial.visible = true
            initial.text = letter
        end if
        if ring <> invalid then ring.visible = true
    end if
end sub

sub ApplyPanelAvatar(avatarNode as object, fallbackNode as object, uri as string)
    if avatarNode = invalid then return
    ring = m.top.findNode("newAvatarRing")
    if uri <> "" then
        avatarNode.uri = uri
        avatarNode.blendColor = "0xffffffff"
        if fallbackNode <> invalid then fallbackNode.visible = false
        ' Photo: border-2 border-white/30 via hollow ring (placeholder already bakes it).
        if ring <> invalid then ring.visible = true
    else
        avatarNode.uri = "pkg:/images/ui/reels_avatar_placeholder_64.png"
        avatarNode.blendColor = "0xffffffff"
        if fallbackNode <> invalid then fallbackNode.visible = false
        if ring <> invalid then ring.visible = false
    end if
end sub

sub SetPanelText(id as string, value as string)
    node = m.top.findNode(id)
    if node <> invalid then node.text = value
end sub

function ReelsFallback(value as string, fallback as string) as string
    if value = "" then return fallback
    return value
end function

function JoinReelGenres(names as object) as string
    out = ""
    for each name in names
        if out <> "" then out = out + " " + Chr(8226) + " "
        out = out + name
    end for
    return out
end function
