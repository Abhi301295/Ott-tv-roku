sub init()
    m.newHost = m.top.findNode("newHost")
    m.cleanHost = m.top.findNode("cleanHost")
    m.defaultHost = m.top.findNode("defaultHost")
    m.lastFocusTarget = "video"
    CacheFocusNodes()
    OnPanelChanged()
end sub

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
    SetPanelText("oldGenres", genres)
    SetPanelText("oldCreator", creator)
    SetPanelText("oldDescription", description)

    ApplyPanelAvatar(m.top.findNode("newAvatar"), m.top.findNode("newUserFallback"), avatar)
    ApplyCleanAvatar(avatar, ReelsFallback(creator, "User"))
    showCreator = creator <> "" or avatar <> ""
    m.top.findNode("newUserCard").visible = showCreator
    m.top.findNode("cleanUserCard").visible = showCreator
    m.top.findNode("oldInfoCard").visible = description <> "" or creator <> ""
    OnPanelChanged()
end sub

sub OnPanelChanged()
    if m.newHost = invalid then return
    layout = UCase(m.top.layout)
    m.newHost.visible = layout = "NEW_UI"
    m.cleanHost.visible = layout = "CLEAN_UI"
    m.defaultHost.visible = layout <> "NEW_UI" and layout <> "CLEAN_UI"

    inset = m.top.topInset
    if inset < 0 then inset = 0
    if layout = "NEW_UI" then
        LayoutNewUiPanel(inset)
    else if layout = "CLEAN_UI" then
        LayoutCleanUiPanel(inset)
    else
        m.defaultHost.translation = [RL_NewUiPanelLeft(), inset + 170]
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
    padBottom = Int(contentH * 0.10 + 0.5)
    outerW = RL_VideoOuterW()
    videoLeft = Int((1920 - outerW) / 2)

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
    hostX = RL_NewUiPanelLeft() + RL_NewUiOverlayPadLeft()
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

    m.top.findNode("oldLikeBg").blendColor = "0xffffff14"
    m.top.findNode("oldCommentBg").blendColor = "0xffffff14"
    m.top.findNode("oldLikeCount").color = transparent
    m.top.findNode("oldCommentCount").color = transparent
    m.top.findNode("oldTitleBg").blendColor = "0xffffff14"
    m.top.findNode("oldInfoBg").blendColor = "0xffffff14"

    likeOn = (target = "like")
    commentOn = (target = "comment")

    ' Detail cards: glass + ring only — no scale/lift (user/parity: ring focus only).
    SetCardFocusChrome(m.newTitleBg, m.newTitleBorder, false, glass15, glass35, border05, white)
    SetCardFocusChrome(m.newUserBg, m.newUserBorder, false, glass15, glass35, border05, white)
    ResetCardLayoutNoScale(m.top.findNode("newTitleCard"))
    ResetCardLayoutNoScale(m.top.findNode("newUserCard"))

    if isClean then
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
    else
        SetCircleFocusChrome(likeOn, glass15, glass40, border05, white)
        SetCommentFocusChrome(commentOn, glass15, glass40, border05, white)
        RunCircleFocus("like", likeOn, animate and not pulseActive)
        RunCircleFocus("comment", commentOn, animate)
    end if

    if target = "detail0" then
        SetCardFocusChrome(m.newTitleBg, m.newTitleBorder, true, glass15, glass35, border05, white)
        m.top.findNode("oldTitleBg").blendColor = "0xffffff26"
    else if target = "detail1" then
        SetCardFocusChrome(m.newUserBg, m.newUserBorder, true, glass15, glass35, border05, white)
        m.top.findNode("oldInfoBg").blendColor = "0xffffff26"
    else if target = "like" then
        m.top.findNode("oldLikeCount").color = white
    else if target = "comment" then
        m.top.findNode("oldCommentCount").color = white
    end if

    if animate and target <> m.lastFocusTarget then
        print "[REELS_SOCIAL_DBG] focusAnim "; m.lastFocusTarget; "->"; target; " dur="; RL_FocusTransitionSec(); " layout="; layout
    end if
    m.lastFocusTarget = target
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

' Like pulse: never exceed focused NewCircleButton scale(1.15).
' Sequence: shrink first → pump up to focus max → slight dip → settle at focus size.
' ⚠ Parity Note: brs-engine ignores nested Group.scale; pulse resizes Poster bounds.
sub RunHeartPulse()
    layout = UCase(m.top.layout)
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
        m.pulseScaleNode = m.oldLike
        m.pulseCircle = m.top.findNode("oldLikeBg")
        m.pulseRing = invalid
        m.pulseIcon = m.top.findNode("oldLikeIcon")
        focusAnim = invalid
    end if
    if m.pulseIcon = invalid and m.pulseCircle = invalid then
        print "[REELS_SOCIAL_DBG] heartPulse abort layout="; layout
        return
    end if

    if focusAnim <> invalid then focusAnim.control = "stop"
    if m.pulseStepTimer <> invalid then m.pulseStepTimer.control = "stop"

    ' Settle scale = current focus size (1.15 when like focused, else 1.0).
    base = 1.0
    if m.top.focusTarget = "like" then base = 1.15
    if m.pulseScaleNode <> invalid and m.pulseScaleNode.scale <> invalid then
        if m.pulseScaleNode.scale[0] > base then base = m.pulseScaleNode.scale[0]
    end if
    if base > 1.15 then base = 1.15
    m.pulseBaseScale = base
    m.pulseMaxScale = 1.15
    m.heartPulseActive = true
    m.pulseStep = 0
    m.pulseIsOld = (layout <> "NEW_UI" and layout <> "CLEAN_UI")

    if m.pulseScaleNode <> invalid then m.pulseScaleNode.scale = [1.0, 1.0]
    ' Pehle small — then pump up to focused max (never above 1.15).
    ApplyHeartPulseScale(m.pulseMaxScale * 0.82)
    print "[REELS_SOCIAL_DBG] heartPulse start layout="; layout; " settle="; base; " max="; m.pulseMaxScale

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
        if m.pulseIcon <> invalid then
            sz = Int(48 * f + 0.5)
            m.pulseIcon.width = sz
            m.pulseIcon.height = sz
            m.pulseIcon.translation = [125 - Int(sz / 2), 44 - Int(sz / 2)]
        end if
        return
    end if

    btn = Int(80 * f + 0.5)
    if btn < 40 then btn = 40
    off = (80 - btn) / 2.0
    if m.pulseCircle <> invalid then
        m.pulseCircle.width = btn
        m.pulseCircle.height = btn
        m.pulseCircle.translation = [off, off]
        m.pulseCircle.blendColor = "0xffffff66"
    end if
    if m.pulseRing <> invalid then
        m.pulseRing.width = btn
        m.pulseRing.height = btn
        m.pulseRing.translation = [off, off]
        m.pulseRing.blendColor = "0xffffffff"
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
        if m.pulseIsOld = true then
            m.pulseIcon.width = 48
            m.pulseIcon.height = 48
            m.pulseIcon.translation = [101, 20]
        else
            m.pulseIcon.width = 32
            m.pulseIcon.height = 32
            m.pulseIcon.translation = [24, 24]
        end if
    end if
    if m.pulseScaleNode <> invalid then
        s = m.pulseBaseScale
        m.pulseScaleNode.scale = [s, s]
    end if
    m.pulseScaleNode = invalid
    m.pulseCircle = invalid
    m.pulseRing = invalid
    m.pulseIcon = invalid
    m.heartPulseActive = false
    ApplyPanelFocus(false)
    print "[REELS_SOCIAL_DBG] heartPulse done layout="; UCase(m.top.layout)
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
