sub InitReelsSocial()
    m.reelDetailPanel = m.top.findNode("reelDetailPanel")
    m.commentSidebar = m.top.findNode("commentSidebar")
    m.reelSwitchAnim = m.top.findNode("reelSwitchAnim")
    m.reelSwitchInterp = m.top.findNode("reelSwitchInterp")
    m.reelSwitchOpacityInterp = m.top.findNode("reelSwitchOpacityInterp")
    m.reelSwitchScaleInterp = m.top.findNode("reelSwitchScaleInterp")
    m.reelSwitchCornerInterp = m.top.findNode("reelSwitchCornerInterp")
    m.reelSwitchCornerOpacityInterp = m.top.findNode("reelSwitchCornerOpacityInterp")
    m.reelsFocusZone = "video"
    m.reelsSwitching = false
    m.localLikes = {}
    m.localIsLiked = {}
    m.lastSyncedReelId = ""
    m.likeTask = invalid
    m.commentTask = invalid

    m.initialFocusTimer = CreateObject("roSGNode", "Timer")
    m.initialFocusTimer.duration = RL_InitialFocusSec()
    m.initialFocusTimer.repeat = false
    m.top.appendChild(m.initialFocusTimer)
    m.initialFocusTimer.observeField("fire", "OnReelsInitialFocus")

    m.switchResetTimer = CreateObject("roSGNode", "Timer")
    m.switchResetTimer.duration = RL_SwitchAnimSec()
    m.switchResetTimer.repeat = false
    m.top.appendChild(m.switchResetTimer)
    m.switchResetTimer.observeField("fire", "OnReelsSwitchAnimDone")

    m.sidebarRefocusTimer = CreateObject("roSGNode", "Timer")
    m.sidebarRefocusTimer.duration = RL_SidebarRefocusSec()
    m.sidebarRefocusTimer.repeat = false
    m.top.appendChild(m.sidebarRefocusTimer)
    m.sidebarRefocusTimer.observeField("fire", "OnReelsSidebarRefocus")

    if m.commentSidebar <> invalid then
        m.commentSidebar.observeField("action", "OnCommentSidebarAction")
        SyncCommentSidebarTheme()
    end if
    SyncReelsDetailPanel()
end sub

sub DisposeReelsSocial()
    KillReelsLikeTask()
    if m.commentSidebar <> invalid and m.commentSidebar.isOpen = true then
        m.commentSidebar.isOpen = false
    end if
end sub

sub KillReelsLikeTask()
    if m.likeTask <> invalid then m.likeTask.unobserveField("apiResult")
    m.likeTask = invalid
end sub

function CurrentReel() as object
    if m.reels = invalid or m.reels.Count() = 0 then return invalid
    if m.currentIndex < 0 or m.currentIndex >= m.reels.Count() then return invalid
    return m.reels[m.currentIndex]
end function

function ReelLikeState(reel as object) as boolean
    if reel = invalid then return false
    id = ReelsId(reel)
    if id <> "" and m.localIsLiked[id] <> invalid then return m.localIsLiked[id]
    return ReelsIsLiked(reel)
end function

function ReelLikesCount(reel as object) as integer
    if reel = invalid then return 0
    id = ReelsId(reel)
    if id <> "" and m.localLikes[id] <> invalid then return m.localLikes[id]
    return ReelsLikes(reel)
end function

sub SyncReelsDetailPanel()
    if m.reelDetailPanel = invalid then return
    reel = CurrentReel()
    if reel = invalid then return
    reelId = ReelsId(reel)
    liked = ReelLikeState(reel)
    m.lastSyncedReelId = reelId

    ' Theme first — OnReelChanged paints creator badge from cPrimary*; XML defaults are blue.
    if m.cPrimary400 <> invalid then m.reelDetailPanel.cPrimary400 = m.cPrimary400
    if m.cPrimary500 <> invalid then m.reelDetailPanel.cPrimary500 = m.cPrimary500
    if m.cPrimary600 <> invalid then m.reelDetailPanel.cPrimary600 = m.cPrimary600
    m.reelDetailPanel.layout = ThemeReelLayout()
    m.reelDetailPanel.reel = reel
    m.reelDetailPanel.isLiked = liked
    m.reelDetailPanel.likesCount = ReelLikesCount(reel)
    m.reelDetailPanel.commentsCount = ReelsCommentsCount(reel)
    m.reelDetailPanel.topInset = RL_ShellTopInset()
    m.reelDetailPanel.contentViewportW = m.viewportW
    m.reelDetailPanel.videoOuterX = m.videoX
    if m.panelHostX <> invalid and m.panelHostX >= 0 then
        m.reelDetailPanel.panelHostX = m.panelHostX
    else
        m.reelDetailPanel.panelHostX = -1
    end if
    m.reelDetailPanel.focusTarget = ReelsDetailFocusTarget()
    m.reelDetailPanel.visible = true
    ' Heart pulse only on explicit like (ToggleReelLike) — not on up/down reel change.
    if m.metaHost <> invalid then m.metaHost.visible = false
end sub

function ReelsDetailFocusTarget() as string
    if m.reelsFocusZone = "like" then return "like"
    if m.reelsFocusZone = "comment" then return "comment"
    if m.reelsFocusZone = "detail0" then return "detail0"
    if m.reelsFocusZone = "detail1" then return "detail1"
    return "video"
end function

sub OnReelsInitialFocus()
    m.reelsFocusZone = "video"
    SyncReelsDetailPanel()
end sub

sub OnReelsSwitchAnimDone()
    m.reelsSwitching = false
    if m.reelSwitchAnim <> invalid then m.reelSwitchAnim.control = "stop"
    SettleReelSwitchChrome()
end sub

sub SettleReelSwitchChrome()
    ' React .reel-enter-active end state: translateY(0) scale(1) opacity 1.
    if m.videoColumn <> invalid then
        m.videoColumn.translation = [m.videoX, 0]
        m.videoColumn.scale = [1.0, 1.0]
        m.videoColumn.opacity = 1.0
    end if
    if m.videoCornerHost <> invalid then
        m.videoCornerHost.translation = [m.shellOffX + m.videoX, m.shellOffY]
        m.videoCornerHost.opacity = 1.0
    end if
end sub

sub OnReelsSidebarRefocus()
    ' Focus target already set by CloseCommentSidebar (like | comment) — React setFocus(target).
    if m.reelsFocusZone = invalid or m.reelsFocusZone = "" then m.reelsFocusZone = "comment"
    SyncReelsDetailPanel()
end sub

sub SyncCommentSidebarTheme()
    if m.commentSidebar = invalid then return
    m.commentSidebar.cNeutral50 = m.cNeutral50
    m.commentSidebar.cNeutral400 = m.cNeutral400
    m.commentSidebar.cNeutral700 = m.cNeutral700
    m.commentSidebar.cNeutral900 = m.cPageBg
    if m.cPrimary500 <> invalid then m.commentSidebar.cPrimary500 = m.cPrimary500
    if m.cPrimary600 <> invalid then m.commentSidebar.cPrimary600 = m.cPrimary600
end sub

sub AnimateReelSwitch(dir as integer)
    ' React index.css .reel-enter.up/down → .reel-enter-active:
    ' opacity 0→1 ease-out, translateY(±60)→0 + scale(0.98)→1, cubic-bezier(0.22,1,0.36,1).
    if m.videoColumn = invalid then return
    m.reelsSwitching = true
    x = m.videoX
    startY = RL_ReelEnterOffsetY()
    if dir < 0 then startY = -RL_ReelEnterOffsetY()
    outerW = RL_VideoOuterW()
    outerH = RL_VideoOuterH()
    m.videoColumn.scaleRotateCenter = [outerW / 2.0, outerH / 2.0]
    m.videoColumn.translation = [x, startY]
    m.videoColumn.scale = [0.98, 0.98]
    m.videoColumn.opacity = 0.0

    cornerX = m.shellOffX + m.videoX
    cornerStartY = m.shellOffY + startY
    cornerEndY = m.shellOffY
    if m.videoCornerHost <> invalid then
        m.videoCornerHost.translation = [cornerX, cornerStartY]
        m.videoCornerHost.opacity = 0.0
    end if

    if m.reelSwitchInterp <> invalid then
        m.reelSwitchInterp.keyValue = [[x, startY], [x, 0]]
    end if
    if m.reelSwitchOpacityInterp <> invalid then
        m.reelSwitchOpacityInterp.keyValue = [0.0, 1.0]
    end if
    if m.reelSwitchScaleInterp <> invalid then
        m.reelSwitchScaleInterp.keyValue = [[0.98, 0.98], [1.0, 1.0]]
    end if
    if m.reelSwitchCornerInterp <> invalid then
        m.reelSwitchCornerInterp.keyValue = [[cornerX, cornerStartY], [cornerX, cornerEndY]]
    end if
    if m.reelSwitchCornerOpacityInterp <> invalid then
        m.reelSwitchCornerOpacityInterp.keyValue = [0.0, 1.0]
    end if
    if m.reelSwitchAnim <> invalid then m.reelSwitchAnim.control = "start"
    if m.switchResetTimer <> invalid then m.switchResetTimer.control = "start"
end sub

sub ReelsSocialAfterReelLoad()
    ' Up/down reel change always restores video focus (React REEL_VIDEO_CONTAINER).
    if m.commentSidebar = invalid or m.commentSidebar.isOpen <> true then
        m.reelsFocusZone = "video"
    end if
    SyncReelsDetailPanel()
    if m.initialFocusTimer <> invalid then m.initialFocusTimer.control = "start"
end sub

sub ToggleReelLike()
    reel = CurrentReel()
    if reel = invalid then return
    reelId = ReelsId(reel)
    if reelId = "" then return
    wasLiked = ReelLikeState(reel)
    likes = ReelLikesCount(reel)
    m.localIsLiked[reelId] = not wasLiked
    if wasLiked then
        likes = likes - 1
        if likes < 0 then likes = 0
    else
        likes = likes + 1
    end if
    m.localLikes[reelId] = likes
    SyncReelsDetailPanel()
    ' Pulse immediately after sync — deferred timer races ApplyPanelFocus scale snaps.
    if not wasLiked and m.reelDetailPanel <> invalid then m.reelDetailPanel.callFunc("PlayHeartPulse")
    KillReelsLikeTask()
    path = ReelsLikePath(reelId, not wasLiked)
    m.likeTask = ApiPatch(path, {})
    m.likeTask.observeField("apiResult", "OnReelLikeResponse")
    StartHttpTask(m.likeTask)
end sub

sub OnReelLikeResponse()
    if m.likeTask = invalid then return
    api = m.likeTask.apiResult
    reel = CurrentReel()
    if reel = invalid then return
    reelId = ReelsId(reel)
    if api = invalid or api.ok <> true then
        m.localIsLiked.Delete(reelId)
        m.localLikes.Delete(reelId)
        SyncReelsDetailPanel()
        ShowAlert(m.top, 2, RL_LikeErrorCopy())
        return
    end if
    ReelsDbgApi("like", api)
end sub

sub OpenCommentSidebar()
    if m.commentSidebar = invalid then return
    reel = CurrentReel()
    if reel = invalid then return
    ' Kill page Spinner first — shared id collision previously left it visible on the left.
    HidePageLoader("comments_open")
    if m.loaderHost <> invalid then m.loaderHost.visible = false
    if m.pageLoader <> invalid then m.pageLoader.running = false
    if m.loaderCenter <> invalid then m.loaderCenter.translation = [960, 518]
    SyncCommentSidebarTheme()
    m.commentSidebar.reelId = ReelsId(reel)
    m.commentSidebar.totalComments = ReelsCommentsCount(reel)
    m.commentSidebar.isOpen = true
end sub

sub CloseCommentSidebar(focusTarget as string)
    if m.commentSidebar = invalid then return
    ' Slide out (comment-sidebar-exit 250ms) before hiding; FinishClose sets isOpen=false.
    m.commentSidebar.requestClose = true
    ' React: LEFT → REEL_LIKE_BTN; Back/close OK → REEL_COMMENT_BTN.
    if focusTarget <> "" then m.reelsFocusZone = focusTarget else m.reelsFocusZone = "comment"
    if m.sidebarRefocusTimer <> invalid then m.sidebarRefocusTimer.control = "start"
end sub

sub OnCommentSidebarAction()
    if m.commentSidebar = invalid then return
    act = m.commentSidebar.action
    if act = invalid or act = "" then return
    m.commentSidebar.action = ""
    if act = "close_like" then
        CloseCommentSidebar("like")
    else if act = "close" then
        CloseCommentSidebar("comment")
    end if
end sub

sub HandleReelsSocialKey(key as string)
    if m.commentSidebar <> invalid and m.commentSidebar.isOpen = true then
        m.commentSidebar.keyEvent = { key: key, press: true }
        return
    end if
    if m.reelsSwitching = true then return

    layout = ThemeReelLayout()
    isNew = (layout = TC_ReelLayoutNewUi())
    isClean = (layout = TC_ReelLayoutCleanUi())
    isDefault = (not isNew and not isClean)

    if m.reelsFocusZone = "video" then
        if key = "left" or key = "rev" then
            if NavLeftOpensSidebarFromContent(true) then
                EnterReelsHeader()
            else
                SeekBy(-RL_SeekStepSec())
            end if
        else if key = "right" or key = "fwd" then
            m.reelsFocusZone = "like"
            SyncReelsDetailPanel()
        else if key = "up" then
            if m.currentIndex = 0 then
                if NavUpOpensHeaderFromContent() then EnterReelsHeader()
            else
                SwitchReel(-1)
                AnimateReelSwitch(-1)
            end if
        else if key = "down" then
            SwitchReel(1)
            AnimateReelSwitch(1)
        else if key = "ok" or key = "play" or key = "select" or key = "enter" then
            if not m.loading then TogglePlayPause()
        end if
    else if m.reelsFocusZone = "like" then
        if key = "left" then
            m.reelsFocusZone = "video"
            SyncReelsDetailPanel()
        else if key = "right" then
            ' NEW_UI + DEFAULT: horizontal like | comment.
            if isNew or isDefault then
                m.reelsFocusZone = "comment"
                SyncReelsDetailPanel()
            end if
        else if key = "up" then
            if isNew then
                m.reelsFocusZone = ReelsSocialDetailFocusUp()
                SyncReelsDetailPanel()
            else
                ' CLEAN_UI / DEFAULT: UP from actions → header.
                if NavUpOpensHeaderFromContent() then EnterReelsHeader()
            end if
        else if key = "down" then
            if isClean then
                m.reelsFocusZone = "comment"
                SyncReelsDetailPanel()
            else if isDefault then
                ' DEFAULT: Like/Comment row → title card.
                m.reelsFocusZone = "detail0"
                SyncReelsDetailPanel()
            end if
        else if key = "ok" or key = "select" then
            ToggleReelLike()
        end if
    else if m.reelsFocusZone = "comment" then
        if key = "left" then
            if isNew or isDefault then
                m.reelsFocusZone = "like"
                SyncReelsDetailPanel()
            else
                ' CLEAN_UI: left from comment column → video.
                m.reelsFocusZone = "video"
                SyncReelsDetailPanel()
            end if
        else if key = "up" then
            if isNew then
                m.reelsFocusZone = ReelsSocialDetailFocusUp()
                SyncReelsDetailPanel()
            else if isClean then
                m.reelsFocusZone = "like"
                SyncReelsDetailPanel()
            else
                ' DEFAULT: UP from actions → header.
                if NavUpOpensHeaderFromContent() then EnterReelsHeader()
            end if
        else if key = "down" then
            if isDefault then
                m.reelsFocusZone = "detail0"
                SyncReelsDetailPanel()
            end if
        else if key = "ok" or key = "select" then
            OpenCommentSidebar()
        end if
    else if m.reelsFocusZone = "detail0" then
        if key = "up" then
            m.reelsFocusZone = "like"
            SyncReelsDetailPanel()
        else if key = "down" then
            if ReelsSocialHasDetail1() then
                m.reelsFocusZone = "detail1"
            else
                m.reelsFocusZone = "like"
            end if
            SyncReelsDetailPanel()
        else if key = "left" then
            m.reelsFocusZone = "video"
            SyncReelsDetailPanel()
        else if key = "right" then
            m.reelsFocusZone = "like"
            SyncReelsDetailPanel()
        end if
    else if m.reelsFocusZone = "detail1" then
        if key = "up" then
            m.reelsFocusZone = "detail0"
            SyncReelsDetailPanel()
        else if key = "down" or key = "right" then
            m.reelsFocusZone = "like"
            SyncReelsDetailPanel()
        else if key = "left" then
            m.reelsFocusZone = "video"
            SyncReelsDetailPanel()
        end if
    end if
end sub

function ReelsSocialHasDetail1() as boolean
    if m.reelDetailPanel = invalid then return false
    layout = ThemeReelLayout()
    if layout = TC_ReelLayoutCleanUi() then return false
    if layout = TC_ReelLayoutNewUi() then
        card = m.reelDetailPanel.findNode("newUserCard")
    else
        card = m.reelDetailPanel.findNode("oldInfoCard")
    end if
    if card = invalid then return false
    return card.visible = true
end function

function ReelsSocialHasUserCard() as boolean
    return ReelsSocialHasDetail1()
end function

function ReelsSocialDetailFocusUp() as string
    if ReelsSocialHasDetail1() then return "detail1"
    return "detail0"
end function
