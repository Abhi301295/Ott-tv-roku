sub init()
    m.scrim = m.top.findNode("scrim")
    m.drawer = m.top.findNode("drawer")
    m.panelHost = m.top.findNode("panelHost")
    m.panel = m.top.findNode("panel")
    m.panelEdge = m.top.findNode("panelEdge")
    m.topBleed = m.top.findNode("topBleed")
    m.headerHost = m.top.findNode("headerHost")
    m.headerBg = m.top.findNode("headerBg")
    m.headerRule = m.top.findNode("headerRule")
    m.title = m.top.findNode("title")
    m.countLbl = m.top.findNode("countLbl")
    m.closeBtn = m.top.findNode("closeBtn")
    m.closeOuter = m.top.findNode("closeOuter")
    m.closeBorder = m.top.findNode("closeBorder")
    m.closeBg = m.top.findNode("closeBg")
    m.closeIcon = m.top.findNode("closeIcon")
    m.listClip = m.top.findNode("listClip")
    m.listHost = m.top.findNode("listHost")
    m.commentLoaderHost = m.top.findNode("commentLoaderHost")
    m.commentLoaderSpin = m.top.findNode("commentLoaderSpin")
    m.commentLoaderRing = m.top.findNode("commentLoaderRing")
    m.commentLoaderArc = m.top.findNode("commentLoaderArc")
    m.commentLoaderText = m.top.findNode("commentLoaderText")
    m.commentLoaderAnim = m.top.findNode("commentLoaderAnim")
    m.emptyLbl = m.top.findNode("emptyLbl")
    m.slideAnim = m.top.findNode("slideAnim")
    m.slideInterp = m.top.findNode("slideInterp")
    m.scrimInterp = m.top.findNode("scrimInterp")
    m.focusTimer = m.top.findNode("focusTimer")

    m.focusZone = "close"
    m.focusIndex = 0
    m.rows = []
    m.comments = []
    m.fetchTask = invalid
    m.isOpen = false
    m.isClosing = false
    m.loading = false
    m.listScrollY = 0
    m.openX = 1270.0
    m.closedX = 1920.0
    m.rowH = RL_CommentRowH()
    m.rowW = 618

    m.top.observeField("keyEvent", "OnKey")
    if m.slideAnim <> invalid then m.slideAnim.observeField("state", "OnSlideAnimState")
    if m.focusTimer <> invalid then m.focusTimer.observeField("fire", "OnFocusFirstComment")
    ApplyCommentSidebarLayout()
    SnapDrawerClosed()
    m.top.visible = true
end sub

' CommentSidebar.tsx: fixed top-[96px] right-0 bottom-0, width 650, bg #14141c.
' panelHost owns that band — scroll stays inside it and never enters the shell header (y<96).
sub ApplyCommentSidebarLayout()
    inset = RL_ShellTopInset()
    panelW = RL_CommentSidebarW()
    panelX = 1920 - panelW
    panelH = 1080 - inset
    hPadX = RL_CommentHeaderPadX()
    hPadY = RL_CommentHeaderPadY()
    closeSz = RL_CommentCloseSize()
    listPadX = RL_CommentListPadX()
    listPadY = RL_CommentListPadY()
    headerH = hPadY + closeSz + hPadY

    m.openX = panelX * 1.0
    m.closedX = 1920.0
    m.rowW = panelW - (listPadX * 2)
    m.listViewH = panelH - headerH - listPadY
    if m.listViewH < 200 then m.listViewH = 200

    if m.scrim <> invalid then m.scrim.color = RL_CommentSidebarScrim()
    if m.panelHost <> invalid then
        m.panelHost.translation = [0, inset]
        m.panelHost.clippingRect = [0, 0, panelW, panelH]
        m.panelHost.clippingRectClipsChildren = true
    end if
    if m.panelEdge <> invalid then
        m.panelEdge.translation = [0, 0]
        m.panelEdge.width = 1
        m.panelEdge.height = panelH
        m.panelEdge.color = RL_CommentPanelBorder()
    end if
    if m.panel <> invalid then
        m.panel.translation = [1, 0]
        m.panel.width = panelW - 1
        m.panel.height = panelH
        m.panel.color = RL_CommentSidebarBg()
    end if
    if m.headerHost <> invalid then m.headerHost.translation = [0, 0]
    if m.headerBg <> invalid then
        m.headerBg.width = panelW
        m.headerBg.height = headerH
        m.headerBg.color = RL_CommentSidebarBg()
    end if
    if m.headerRule <> invalid then
        m.headerRule.translation = [0, headerH]
        m.headerRule.width = panelW
        m.headerRule.color = RL_CommentPanelBorder()
    end if
    if m.title <> invalid then
        m.title.translation = [hPadX, hPadY]
        m.title.height = closeSz
    end if
    if m.countLbl <> invalid then
        m.countLbl.translation = [hPadX + 160, hPadY]
        m.countLbl.height = closeSz
    end if
    if m.closeBtn <> invalid then
        m.closeBtn.translation = [panelW - hPadX - closeSz, hPadY]
        m.closeBtn.scaleRotateCenter = [closeSz / 2.0, closeSz / 2.0]
    end if
    ' Close focus rings: hollow outer primary +2px, white 2px ring, red fill on panel.
    if m.closeOuter <> invalid then
        m.closeOuter.translation = [-2, -2]
        m.closeOuter.width = closeSz + 4
        m.closeOuter.height = closeSz + 4
        m.closeOuter.uri = "pkg:/images/ui/reels_circle_ring_64.png"
        m.closeOuter.loadDisplayMode = "scaleToFit"
    end if
    if m.closeBg <> invalid then
        m.closeBg.translation = [0, 0]
        m.closeBg.width = closeSz
        m.closeBg.height = closeSz
    end if
    if m.closeBorder <> invalid then
        m.closeBorder.translation = [0, 0]
        m.closeBorder.width = closeSz
        m.closeBorder.height = closeSz
        m.closeBorder.uri = "pkg:/images/ui/reels_circle_ring_64.png"
        m.closeBorder.loadDisplayMode = "scaleToFit"
    end if
    if m.closeIcon <> invalid then
        m.closeIcon.translation = [12, 12]
        m.closeIcon.width = 24
        m.closeIcon.height = 24
    end if
    if m.listClip <> invalid then
        m.listClip.translation = [listPadX, headerH + listPadY]
        m.listClip.clippingRect = [0, 0, m.rowW, m.listViewH]
        m.listClip.clippingRectClipsChildren = true
    end if
    ' Header above list; both stay inside panelHost so shell header never sees scroll bleed.
    if m.panelHost <> invalid and m.headerHost <> invalid then m.panelHost.appendChild(m.headerHost)
    if m.topBleed <> invalid then
        m.topBleed.translation = [0, 0]
        m.topBleed.width = panelW
        m.topBleed.height = inset
        m.topBleed.color = RL_CommentSidebarBg()
        ' Under the transparent shell header — hides scroll bleed without covering header labels (header paints above).
        if m.drawer <> invalid then m.drawer.appendChild(m.topBleed)
    end if
    if m.commentLoaderHost <> invalid then
        m.commentLoaderHost.translation = [Int(m.rowW / 2), Int(m.listViewH / 2)]
    end if
    if m.emptyLbl <> invalid then
        m.emptyLbl.translation = [0, Int(m.listViewH / 2) - 40]
        m.emptyLbl.width = m.rowW
        m.emptyLbl.text = RL_CommentEmptyCopy()
    end if
    ApplyCommentLoaderColors()
    if m.focusTimer <> invalid then m.focusTimer.duration = RL_CommentFocusSec()
end sub

sub ApplyCommentLoaderColors()
    ring = m.top.cNeutral50
    arc = m.top.cPrimary600
    if ring = invalid or ring = "" then ring = "0xf5f5f5ff"
    if arc = invalid or arc = "" then arc = "0x0760bbff"
    if m.commentLoaderRing <> invalid then m.commentLoaderRing.blendColor = ring
    if m.commentLoaderArc <> invalid then m.commentLoaderArc.blendColor = arc
    if m.commentLoaderText <> invalid then m.commentLoaderText.color = ring
end sub

sub SnapDrawerClosed()
    if m.slideAnim <> invalid then m.slideAnim.control = "stop"
    if m.focusTimer <> invalid then m.focusTimer.control = "stop"
    if m.drawer <> invalid then m.drawer.translation = [m.closedX, 0]
    if m.scrim <> invalid then
        m.scrim.opacity = 0.0
        m.scrim.visible = false
    end if
    m.isOpen = false
    m.isClosing = false
    m.loading = false
    SetLoaderRunning(false)
end sub

sub OnOpenChanged()
    show = (m.top.isOpen = true)
    if show then
        ApplyCommentSidebarLayout()
        if m.scrim <> invalid then
            m.scrim.visible = true
            m.scrim.opacity = 0.0
        end if
        if m.drawer <> invalid then m.drawer.translation = [m.closedX, 0]
        m.focusZone = "close"
        m.focusIndex = 0
        m.listScrollY = 0
        UpdateCountLabel()
        PaintCloseFocus()
        FetchComments()
        StartSlideIn()
    else if not m.isClosing then
        ClearList()
        KillCommentTask()
        SnapDrawerClosed()
    end if
end sub

sub OnRequestClose()
    if m.top.requestClose <> true then return
    m.top.requestClose = false
    if m.isClosing then return
    if m.top.isOpen <> true and not m.isOpen then return
    StartSlideOut()
end sub

sub StartSlideIn()
    m.isClosing = false
    m.isOpen = true
    if m.drawer = invalid or m.slideAnim = invalid or m.slideInterp = invalid then
        if m.drawer <> invalid then m.drawer.translation = [m.openX, 0]
        if m.scrim <> invalid then m.scrim.opacity = 1.0
        return
    end if
    curX = m.closedX
    if m.drawer.translation <> invalid then curX = m.drawer.translation[0]
    curOp = 0.0
    if m.scrim <> invalid then curOp = m.scrim.opacity
    m.slideAnim.duration = RL_SidebarEnterSec()
    m.slideAnim.easeFunction = "easeOutCubic"
    m.slideInterp.keyValue = [[curX, 0.0], [m.openX, 0.0]]
    if m.scrimInterp <> invalid then m.scrimInterp.keyValue = [curOp, 1.0]
    m.slideAnim.control = "stop"
    m.slideAnim.control = "start"
end sub

sub StartSlideOut()
    m.isClosing = true
    if m.focusTimer <> invalid then m.focusTimer.control = "stop"
    if m.drawer = invalid or m.slideAnim = invalid or m.slideInterp = invalid then
        FinishClose()
        return
    end if
    curX = m.openX
    if m.drawer.translation <> invalid then curX = m.drawer.translation[0]
    curOp = 1.0
    if m.scrim <> invalid then curOp = m.scrim.opacity
    m.slideAnim.duration = RL_SidebarCloseSec()
    m.slideAnim.easeFunction = "easeInCubic"
    m.slideInterp.keyValue = [[curX, 0.0], [m.closedX, 0.0]]
    if m.scrimInterp <> invalid then m.scrimInterp.keyValue = [curOp, 0.0]
    m.slideAnim.control = "stop"
    m.slideAnim.control = "start"
end sub

sub OnSlideAnimState()
    if m.slideAnim = invalid then return
    if m.slideAnim.state <> "stopped" then return
    if m.isClosing then FinishClose()
end sub

sub FinishClose()
    ClearList()
    KillCommentTask()
    SnapDrawerClosed()
    m.top.isOpen = false
end sub

sub OnReelChanged()
    if m.top.isOpen <> true then return
    UpdateCountLabel()
    FetchComments()
end sub

sub UpdateCountLabel()
    if m.countLbl = invalid then return
    ' React: bare totalComments next to title (not "N comments").
    m.countLbl.text = m.top.totalComments.ToStr()
    if m.title <> invalid then
        ' Approximate title width for fs-24 bold "Comments" (~9ch) then gap-3.
        m.countLbl.translation = [RL_CommentHeaderPadX() + 168, RL_CommentHeaderPadY()]
    end if
end sub

sub SetLoaderRunning(on as boolean)
    ApplyCommentLoaderColors()
    if m.commentLoaderHost <> invalid then m.commentLoaderHost.visible = on
    if m.commentLoaderAnim <> invalid then
        if on then
            m.commentLoaderAnim.control = "start"
        else
            m.commentLoaderAnim.control = "stop"
        end if
    end if
end sub

sub FetchComments()
    KillCommentTask()
    if m.focusTimer <> invalid then m.focusTimer.control = "stop"
    ShowLoading(true)
    reelId = m.top.reelId
    if reelId = "" then
        ShowLoading(false)
        ShowEmpty(true)
        return
    end if
    m.fetchTask = ApiGetQuery(Endpoints().REEL_COMMENTS, ReelsCommentsQuery(reelId))
    m.fetchTask.observeField("apiResult", "OnCommentsResponse")
    StartHttpTask(m.fetchTask)
end sub

sub OnCommentsResponse()
    if m.fetchTask = invalid then return
    api = m.fetchTask.apiResult
    m.fetchTask.unobserveField("apiResult")
    m.fetchTask = invalid
    ShowLoading(false)
    ok = (api <> invalid and api.ok = true and (api.statusCode = invalid or api.statusCode = 200))
    m.comments = ReelsParseComments(api)
    ReelsDbgApi("comments", api)
    if not ok then
        ShowAlert(m.top, 2, RL_CommentsErrorCopy())
        ShowEmpty(true)
        m.focusZone = "close"
        PaintCloseFocus()
        return
    end if
    if m.comments.Count() = 0 then
        ShowEmpty(true)
        m.focusZone = "close"
        PaintCloseFocus()
        return
    end if
    ShowEmpty(false)
    BuildList()
    ' React: setFocus first comment 350ms after load.
    if m.focusTimer <> invalid then
        m.focusTimer.control = "stop"
        m.focusTimer.control = "start"
    else
        OnFocusFirstComment()
    end if
end sub

sub OnFocusFirstComment()
    if m.top.isOpen <> true or m.isClosing then return
    if m.comments.Count() = 0 then return
    m.focusZone = "item"
    m.focusIndex = 0
    ApplyItemFocus()
end sub

sub ShowLoading(show as boolean)
    m.loading = show
    SetLoaderRunning(show)
    if show then
        if m.emptyLbl <> invalid then m.emptyLbl.visible = false
        if m.listHost <> invalid then m.listHost.visible = false
    end if
end sub

sub ShowEmpty(show as boolean)
    if m.emptyLbl <> invalid then m.emptyLbl.visible = show
    if m.listHost <> invalid then m.listHost.visible = not show
end sub

sub ClearListRows()
    if m.listHost = invalid then return
    while m.listHost.getChildCount() > 0
        m.listHost.removeChildIndex(0)
    end while
    m.rows = []
    m.listScrollY = 0
    if m.listHost <> invalid then m.listHost.translation = [0, 0]
end sub

sub ClearList()
    ClearListRows()
    m.comments = []
end sub

function EstimateCommentLines(text as string, bodyW as integer) as integer
    ' React line-clamp-3 — return how many line slots the card needs (1..3).
    if text = invalid or text = "" then return 1
    if bodyW < 80 then bodyW = 80
    ' Narrow estimate so long text always gets the full 3-line Label height.
    charsPerLine = Int(bodyW / 14)
    if charsPerLine < 16 then charsPerLine = 16
    n = Len(text)
    if n <= charsPerLine then return 1
    if n <= charsPerLine * 2 then return 2
    return RL_CommentBodyMaxLines()
end function

function CommentRowHeightForLines(lines as integer) as integer
    padY = RL_CommentItemPadY()
    avatarSz = RL_CommentAvatarSize()
    gap = RL_CommentItemGap()
    bodyH = lines * RL_CommentBodyLineH()
    return padY + avatarSz + gap + bodyH + RL_CommentBodyMetaGap() + RL_CommentMetaH() + padY
end function

sub BuildList()
    ClearListRows()
    rowW = m.rowW
    maxItems = m.comments.Count()
    if maxItems > RL_CommentLimit() then maxItems = RL_CommentLimit()
    y = 0
    for i = 0 to maxItems - 1
        c = m.comments[i]
        if c = invalid then continue for
        padX = RL_CommentItemPadX()
        bodyW = rowW - padX - RL_CommentAvatarSize() - RL_CommentItemGap() - padX
        bodyTxt = ReelsCommentText(c)
        lines = EstimateCommentLines(bodyTxt, bodyW)
        rowH = CommentRowHeightForLines(lines)
        row = CreateCommentRow(c, rowW, rowH, lines)
        row.h = rowH
        row.group.translation = [0, y]
        m.listHost.appendChild(row.group)
        m.rows.Push(row)
        y = y + rowH + RL_CommentItemMb()
    end for
    m.listHost.visible = true
    m.focusZone = "close"
    PaintCloseFocus()
    PaintAllItemFocus()
end sub

function CreateCommentRow(c as object, rowW as integer, rowH as integer, lines as integer) as object
    padX = RL_CommentItemPadX()
    padY = RL_CommentItemPadY()
    avatarSz = RL_CommentAvatarSize()
    gap = RL_CommentItemGap()
    contentLeft = padX + avatarSz + gap
    bodyW = rowW - contentLeft - padX
    if lines < 1 then lines = 1
    if lines > RL_CommentBodyMaxLines() then lines = RL_CommentBodyMaxLines()
    bodyH = lines * RL_CommentBodyLineH()

    grp = CreateObject("roSGNode", "Group")
    grp.scaleRotateCenter = [rowW / 2.0, rowH / 2.0]

    ' CommentItem focused: rounded-2xl fill + 2px border (white PNG + blendColor).
    fill = grp.createChild("Poster")
    fill.width = rowW
    fill.height = rowH
    fill.uri = RL_CommentCardFillUri()
    fill.loadDisplayMode = "scaleToFill"
    fill.blendColor = "0x00000000"
    fill.visible = false

    border = grp.createChild("Poster")
    border.width = rowW
    border.height = rowH
    border.uri = RL_CommentCardBorderUri()
    border.loadDisplayMode = "scaleToFill"
    border.blendColor = "0x00000000"
    border.visible = false

    avatarBg = grp.createChild("Poster")
    avatarBg.translation = [padX, padY]
    avatarBg.width = avatarSz
    avatarBg.height = avatarSz
    avatarBg.uri = "pkg:/images/ui/avatar_circle.png"
    avatarBg.loadDisplayMode = "scaleToFill"
    avatarBg.blendColor = "0x6366f1ff"

    avatarUri = ReelsCommentAvatar(c)
    if avatarUri <> "" then
        mask = grp.createChild("MaskGroup")
        mask.translation = [padX, padY]
        mask.maskUri = "pkg:/images/ui/avatar_circle.png"
        mask.maskSize = [avatarSz, avatarSz]
        avatarImg = mask.createChild("Poster")
        avatarImg.width = avatarSz
        avatarImg.height = avatarSz
        avatarImg.uri = avatarUri
        avatarImg.loadDisplayMode = "scaleToZoom"
        avatarBg.visible = false
        ' img: border 2px solid rgba(255,255,255,0.1) — static.
        avatarRing = grp.createChild("Poster")
        avatarRing.translation = [padX, padY]
        avatarRing.width = avatarSz
        avatarRing.height = avatarSz
        avatarRing.uri = "pkg:/images/ui/reels_circle_ring_64.png"
        avatarRing.loadDisplayMode = "scaleToFit"
        avatarRing.blendColor = "0xffffff1a"
    end if

    initialLbl = grp.createChild("Label")
    initialLbl.translation = [padX, padY]
    initialLbl.width = avatarSz
    initialLbl.height = avatarSz
    initialLbl.horizAlign = "center"
    initialLbl.vertAlign = "center"
    initialLbl.color = "0xffffffff"
    initialLbl.font = CreateObject("roSGNode", "Font")
    initialLbl.font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
    initialLbl.font.size = 18
    nameStr = ReelsCommentName(c)
    if avatarUri <> "" then
        initialLbl.visible = false
    else if Len(nameStr) > 0 then
        initialLbl.text = UCase(Left(nameStr, 1))
    else
        initialLbl.text = "?"
    end if

    nameLbl = grp.createChild("Label")
    nameLbl.translation = [contentLeft, padY]
    nameLbl.width = bodyW
    nameLbl.height = avatarSz
    nameLbl.vertAlign = "center"
    nameLbl.text = nameStr
    nameLbl.color = "0xffffffff"
    nameLbl.font = CreateObject("roSGNode", "Font")
    nameLbl.font.uri = "pkg:/fonts/Inter-Bold.ttf"
    nameLbl.font.size = 22

    bodyY = padY + avatarSz + gap
    bodyLbl = grp.createChild("Label")
    bodyFont = CreateObject("roSGNode", "Font")
    bodyFont.uri = "pkg:/fonts/Inter-Regular.ttf"
    bodyFont.size = RL_CommentBodyFontSize()
    ' LiveTV hero desc: height=0 + numLines + ellipsizeOnBoundary (maxLines alone stops at 2).
    bodyLbl.font = bodyFont
    bodyLbl.translation = [contentLeft, bodyY]
    bodyLbl.width = bodyW
    bodyLbl.height = 0
    bodyLbl.vertAlign = "top"
    bodyLbl.horizAlign = "left"
    bodyLbl.wrap = true
    bodyLbl.lineSpacing = RL_CommentBodyLineSpacing()
    bodyLbl.numLines = lines
    bodyLbl.ellipsizeOnBoundary = true
    ' Comment text — text-white/80 (static).
    bodyLbl.color = "0xffffffcc"
    bodyLbl.text = ReelsCommentText(c)

    ' React: p m-b-12 then Like/Reply row — layout uses bodyH, Label auto-sizes via numLines.
    metaY = bodyY + bodyH + RL_CommentBodyMetaGap()
    likeIcon = grp.createChild("Poster")
    likeIcon.translation = [contentLeft, metaY + 4]
    likeIcon.width = 12
    likeIcon.height = 12
    likeIcon.uri = "pkg:/images/ui/reels_heart_outline_32.png"
    likeIcon.loadDisplayMode = "scaleToFit"
    likeIcon.blendColor = "0xffffff80"

    likeLbl = grp.createChild("Label")
    likeLbl.translation = [contentLeft + 16, metaY]
    likeLbl.width = 160
    likeLbl.height = RL_CommentMetaH()
    likeLbl.text = "Like (" + Str(ReelsCommentLikes(c)).Trim() + ")"
    likeLbl.color = "0xffffff80"
    likeLbl.font = CreateObject("roSGNode", "Font")
    likeLbl.font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
    likeLbl.font.size = 17

    replyIcon = grp.createChild("Poster")
    replyIcon.translation = [contentLeft + 180, metaY + 4]
    replyIcon.width = 12
    replyIcon.height = 12
    replyIcon.uri = "pkg:/images/ui/reels_comment_32.png"
    replyIcon.loadDisplayMode = "scaleToFit"
    replyIcon.blendColor = "0xffffff80"

    replyLbl = grp.createChild("Label")
    replyLbl.translation = [contentLeft + 196, metaY]
    replyLbl.width = 160
    replyLbl.height = RL_CommentMetaH()
    replyLbl.text = "Reply (" + Str(ReelsCommentReplies(c)).Trim() + ")"
    replyLbl.color = "0xffffff80"
    replyLbl.font = CreateObject("roSGNode", "Font")
    replyLbl.font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
    replyLbl.font.size = 17

    return {
        group: grp
        border: border
        fill: fill
        h: rowH
    }
end function

sub PaintCloseFocus()
    focused = (m.focusZone = "close")
    idleBg = RL_CommentCloseIdleBg()
    focusBg = RL_CommentCloseFocusBg()
    ' Outer ring: var(--primary-500). Soft 15px glow skipped — opaque disc reads as grey halo on sim.
    primary = m.top.cPrimary500
    if primary = invalid or primary = "" then primary = RL_CommentCloseOuterFallback()
    if m.closeBg <> invalid then
        if focused then m.closeBg.blendColor = focusBg else m.closeBg.blendColor = idleBg
    end if
    if m.closeBorder <> invalid then
        m.closeBorder.visible = focused
        m.closeBorder.blendColor = "0xffffffff"
    end if
    if m.closeOuter <> invalid then
        m.closeOuter.visible = focused
        m.closeOuter.blendColor = primary
    end if
    if m.closeBtn <> invalid then
        if focused then
            m.closeBtn.scale = [RL_CommentCloseFocusScale(), RL_CommentCloseFocusScale()]
        else
            m.closeBtn.scale = [1.0, 1.0]
        end if
    end if
end sub

sub PaintAllItemFocus()
    if m.rows = invalid then return
    for i = 0 to m.rows.Count() - 1
        PaintItemFocus(i, (m.focusZone = "item" and m.focusIndex = i))
    end for
end sub

sub PaintItemFocus(index as integer, focused as boolean)
    if m.rows = invalid or index < 0 or index >= m.rows.Count() then return
    row = m.rows[index]
    if row = invalid then return
    ' React: bg white/12 + border 2px white/30 + rounded-2xl (+ scale 1.01).
    if row.fill <> invalid then
        row.fill.visible = focused
        if focused then
            row.fill.blendColor = RL_CommentItemFocusBg()
        else
            row.fill.blendColor = "0x00000000"
        end if
    end if
    if row.border <> invalid then
        row.border.visible = focused
        if focused then
            row.border.blendColor = RL_CommentItemFocusBorder()
        else
            row.border.blendColor = "0x00000000"
        end if
    end if
    if row.group <> invalid then
        if focused then
            s = RL_CommentItemFocusScale()
            row.group.scale = [s, s]
        else
            row.group.scale = [1.0, 1.0]
        end if
    end if
end sub

sub ApplyItemFocus()
    PaintCloseFocus()
    PaintAllItemFocus()
    ScrollFocusedIntoView()
end sub

sub ScrollFocusedIntoView()
    ' React scrollIntoView({ behavior: smooth, block: nearest }).
    if m.focusZone <> "item" then return
    if m.listHost = invalid or m.rows = invalid then return
    if m.focusIndex < 0 or m.focusIndex >= m.rows.Count() then return
    top = 0
    i = 0
    while i < m.focusIndex
        rh = RL_CommentRowH()
        if m.rows[i] <> invalid and m.rows[i].h <> invalid then rh = m.rows[i].h
        top = top + rh + RL_CommentItemMb()
        i = i + 1
    end while
    rowH = RL_CommentRowH()
    if m.rows[m.focusIndex] <> invalid and m.rows[m.focusIndex].h <> invalid then
        rowH = m.rows[m.focusIndex].h
    end if
    bottom = top + rowH
    viewTop = m.listScrollY
    viewBottom = viewTop + m.listViewH
    if top < viewTop then
        m.listScrollY = top
    else if bottom > viewBottom then
        m.listScrollY = bottom - m.listViewH
    end if
    if m.listScrollY < 0 then m.listScrollY = 0
    m.listHost.translation = [0, -m.listScrollY]
end sub

sub RequestClose(focusTarget as string)
    ' action consumed by ReelsSocial — close | close_like
    if focusTarget = "like" then
        m.top.action = "close_like"
    else
        m.top.action = "close"
    end if
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.top.isOpen <> true or m.isClosing then return
    key = LCase(ev.key.ToStr())

    if key = "back" then
        ' Escape/Back → close, refocus comment button (React default).
        RequestClose("comment")
        return
    end if

    if m.focusZone = "close" then
        HandleCloseKeys(key)
    else if m.focusZone = "item" then
        HandleItemKeys(key)
    end if
end sub

sub HandleCloseKeys(key as string)
    if key = "ok" or key = "select" then
        RequestClose("comment")
    else if key = "left" then
        ' React close onArrowPress LEFT → handleClose(REEL_LIKE_BTN).
        RequestClose("like")
    else if key = "down" then
        if m.comments.Count() > 0 and not m.loading then
            m.focusZone = "item"
            m.focusIndex = 0
            ApplyItemFocus()
        end if
    else if key = "up" or key = "right" then
        ' Stay on close — focus boundary.
    end if
end sub

sub HandleItemKeys(key as string)
    n = m.comments.Count()
    if n > m.rows.Count() then n = m.rows.Count()
    if key = "left" then
        ' React comment LEFT → handleClose(REEL_LIKE_BTN).
        RequestClose("like")
    else if key = "right" then
        ' Block right inside sidebar.
        return
    else if key = "up" then
        if m.focusIndex = 0 then
            m.focusZone = "close"
            ApplyItemFocus()
        else
            m.focusIndex = m.focusIndex - 1
            ApplyItemFocus()
        end if
    else if key = "down" then
        if m.focusIndex < n - 1 then
            m.focusIndex = m.focusIndex + 1
            ApplyItemFocus()
        end if
    else if key = "ok" or key = "select" then
        ' Comments are not actionable beyond focus chrome.
    end if
end sub

sub KillCommentTask()
    if m.fetchTask <> invalid then m.fetchTask.unobserveField("apiResult")
    m.fetchTask = invalid
end sub
