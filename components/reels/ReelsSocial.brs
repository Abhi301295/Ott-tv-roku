sub InitReelsSocial()
    m.reelDetailPanel = m.top.findNode("reelDetailPanel")
    m.commentSidebar = m.top.findNode("commentSidebar")
    m.reelSwitchAnim = m.top.findNode("reelSwitchAnim")
    m.reelSwitchInterp = m.top.findNode("reelSwitchInterp")
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
        m.commentSidebar.cNeutral50 = m.cNeutral50
        m.commentSidebar.cNeutral400 = m.cNeutral400
        m.commentSidebar.cNeutral700 = m.cNeutral700
        m.commentSidebar.cNeutral900 = m.cPageBg
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
    navPulse = false
    if reelId <> "" and reelId <> m.lastSyncedReelId and liked then navPulse = true
    m.lastSyncedReelId = reelId

    m.reelDetailPanel.layout = ThemeReelLayout()
    m.reelDetailPanel.reel = reel
    m.reelDetailPanel.isLiked = liked
    m.reelDetailPanel.likesCount = ReelLikesCount(reel)
    m.reelDetailPanel.commentsCount = ReelsCommentsCount(reel)
    m.reelDetailPanel.topInset = RL_ShellTopInset()
    m.reelDetailPanel.focusTarget = ReelsDetailFocusTarget()
    m.reelDetailPanel.visible = true
    if navPulse and m.reelDetailPanel <> invalid then m.reelDetailPanel.callFunc("PlayHeartPulse")
    if m.metaHost <> invalid then m.metaHost.visible = false
    print "[REELS_SOCIAL_DBG] panel sync index="; m.currentIndex; " layout="; ThemeReelLayout(); " likes="; ReelLikesCount(reel)
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
    print "[REELS_SOCIAL_DBG] initial focus zone=video"
end sub

sub OnReelsSwitchAnimDone()
    m.reelsSwitching = false
    if m.reelSwitchAnim <> invalid then m.reelSwitchAnim.control = "stop"
end sub

sub OnReelsSidebarRefocus()
    m.reelsFocusZone = "comment"
    SyncReelsDetailPanel()
    print "[REELS_SOCIAL_DBG] sidebar closed refocus=comment"
end sub

sub AnimateReelSwitch(dir as integer)
    if m.videoColumn = invalid then return
    m.reelsSwitching = true
    fromY = m.videoColumn.translation[1]
    delta = 1080
    if dir < 0 then delta = -1080
    if m.reelSwitchInterp <> invalid then
        m.reelSwitchInterp.keyValue = [[m.videoColumn.translation[0], fromY], [m.videoColumn.translation[0], fromY + delta]]
    end if
    if m.reelSwitchAnim <> invalid then m.reelSwitchAnim.control = "start"
    if m.switchResetTimer <> invalid then m.switchResetTimer.control = "start"
    m.videoColumn.translation = [m.videoColumn.translation[0], fromY]
end sub

sub ReelsSocialAfterReelLoad()
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
    print "[REELS_SOCIAL_DBG] like optimistic id="; reelId; " liked="; m.localIsLiked[reelId]; " count="; likes
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
        print "[REELS_SOCIAL_DBG] like rollback id="; reelId
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
    m.commentSidebar.reelId = ReelsId(reel)
    m.commentSidebar.totalComments = ReelsCommentsCount(reel)
    m.commentSidebar.isOpen = true
    print "[REELS_SOCIAL_DBG] comments open reel="; m.commentSidebar.reelId
end sub

sub CloseCommentSidebar(focusTarget as string)
    if m.commentSidebar = invalid then return
    ' Slide out (comment-sidebar-exit 250ms) before hiding; FinishClose sets visible=false.
    m.commentSidebar.requestClose = true
    if focusTarget <> "" then m.reelsFocusZone = focusTarget
    if m.sidebarRefocusTimer <> invalid then m.sidebarRefocusTimer.control = "start"
end sub

sub OnCommentSidebarAction()
    if m.commentSidebar = invalid then return
    if m.commentSidebar.action = "close" then
        m.commentSidebar.action = ""
        CloseCommentSidebar("comment")
    end if
end sub

sub HandleReelsSocialKey(key as string)
    if m.commentSidebar <> invalid and m.commentSidebar.isOpen = true then
        m.commentSidebar.keyEvent = { key: key, press: true }
        return
    end if
    if m.reelsSwitching = true then return

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
            print "[REELS_SOCIAL_DBG] focus video->like"
        else if key = "up" then
            if m.currentIndex = 0 then
                if NavUpOpensHeaderFromContent() then EnterReelsHeader()
            else
                AnimateReelSwitch(-1)
                SwitchReel(-1)
            end if
        else if key = "down" then
            AnimateReelSwitch(1)
            SwitchReel(1)
        else if key = "ok" or key = "play" or key = "select" or key = "enter" then
            if not m.loading then TogglePlayPause()
        end if
    else if m.reelsFocusZone = "like" then
        if key = "left" then
            m.reelsFocusZone = "video"
            SyncReelsDetailPanel()
            print "[REELS_SOCIAL_DBG] focus like->video"
        else if key = "right" then
            ' NEW_UI only: like | comment horizontal row.
            if ThemeReelLayout() = TC_ReelLayoutNewUi() then
                m.reelsFocusZone = "comment"
                SyncReelsDetailPanel()
                print "[REELS_SOCIAL_DBG] focus like->comment"
            end if
        else if key = "up" then
            if ThemeReelLayout() = TC_ReelLayoutNewUi() then
                m.reelsFocusZone = ReelsSocialDetailFocusUp()
                SyncReelsDetailPanel()
            else
                ' CLEAN_UI / DEFAULT: UP from actions → header.
                if NavUpOpensHeaderFromContent() then EnterReelsHeader()
            end if
        else if key = "down" then
            ' CLEAN_UI: vertical like → comment (ReelDetailPanel.tsx).
            if ThemeReelLayout() = TC_ReelLayoutCleanUi() then
                m.reelsFocusZone = "comment"
                SyncReelsDetailPanel()
                print "[REELS_SOCIAL_DBG] focus like->comment"
            end if
        else if key = "ok" or key = "select" then
            ToggleReelLike()
        end if
    else if m.reelsFocusZone = "comment" then
        if key = "left" then
            if ThemeReelLayout() = TC_ReelLayoutNewUi() then
                m.reelsFocusZone = "like"
                SyncReelsDetailPanel()
                print "[REELS_SOCIAL_DBG] focus comment->like"
            else
                ' CLEAN_UI: left from comment column → video.
                m.reelsFocusZone = "video"
                SyncReelsDetailPanel()
                print "[REELS_SOCIAL_DBG] focus comment->video"
            end if
        else if key = "up" then
            if ThemeReelLayout() = TC_ReelLayoutNewUi() then
                m.reelsFocusZone = ReelsSocialDetailFocusUp()
                SyncReelsDetailPanel()
            else
                ' CLEAN_UI: comment → like.
                m.reelsFocusZone = "like"
                SyncReelsDetailPanel()
                print "[REELS_SOCIAL_DBG] focus comment->like"
            end if
        else if key = "ok" or key = "select" then
            OpenCommentSidebar()
        end if
    else if m.reelsFocusZone = "detail0" then
        if key = "down" then
            if ReelsSocialHasUserCard() then
                m.reelsFocusZone = "detail1"
            else
                m.reelsFocusZone = "like"
            end if
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
        end if
    end if
end sub

function ReelsSocialHasUserCard() as boolean
    if m.reelDetailPanel = invalid then return false
    card = m.reelDetailPanel.findNode("newUserCard")
    if card = invalid then return false
    return card.visible = true
end function

function ReelsSocialDetailFocusUp() as string
    if ReelsSocialHasUserCard() then return "detail1"
    return "detail0"
end function
