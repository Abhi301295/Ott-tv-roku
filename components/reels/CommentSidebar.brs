sub init()
    m.scrim = m.top.findNode("scrim")
    m.drawer = m.top.findNode("drawer")
    m.panel = m.top.findNode("panel")
    m.title = m.top.findNode("title")
    m.countLbl = m.top.findNode("countLbl")
    m.closeBtn = m.top.findNode("closeBtn")
    m.loadingLbl = m.top.findNode("loadingLbl")
    m.emptyLbl = m.top.findNode("emptyLbl")
    m.listHost = m.top.findNode("listHost")
    m.slideAnim = m.top.findNode("slideAnim")
    m.slideInterp = m.top.findNode("slideInterp")
    m.scrimInterp = m.top.findNode("scrimInterp")
    m.focus = "close"
    m.comments = []
    m.fetchTask = invalid
    m.isOpen = false
    m.isClosing = false
    m.openX = 1270.0
    m.closedX = 1920.0
    m.top.observeField("keyEvent", "OnKey")
    if m.slideAnim <> invalid then
        m.slideAnim.observeField("state", "OnSlideAnimState")
    end if
    ApplyCommentSidebarLayout()
    SnapDrawerClosed()
    m.top.visible = true
end sub

' CommentSidebar.tsx: fixed top-[96px] right-0 bottom-0, width 650, bg #14141c.
' Children are local to drawer; drawer.translation.x slides between closedX and openX.
sub ApplyCommentSidebarLayout()
    inset = RL_ShellTopInset()
    panelW = RL_CommentSidebarW()
    panelX = 1920 - panelW
    panelH = 1080 - inset
    padX = 24
    padY = 20
    m.openX = panelX * 1.0
    m.closedX = 1920.0
    if m.scrim <> invalid then m.scrim.color = RL_CommentSidebarScrim()
    if m.panel <> invalid then
        m.panel.translation = [0, inset]
        m.panel.width = panelW
        m.panel.height = panelH
        m.panel.color = RL_CommentSidebarBg()
    end if
    contentW = panelW - (padX * 2) - 56
    if m.title <> invalid then
        m.title.translation = [padX, inset + padY]
        m.title.width = contentW
    end if
    if m.countLbl <> invalid then
        m.countLbl.translation = [padX, inset + padY + 48]
        m.countLbl.width = contentW
    end if
    if m.closeBtn <> invalid then
        m.closeBtn.translation = [panelW - padX - 48, inset + padY]
    end if
    listY = inset + padY + 100
    if m.loadingLbl <> invalid then
        m.loadingLbl.translation = [padX, listY]
        m.loadingLbl.width = contentW
    end if
    if m.emptyLbl <> invalid then
        m.emptyLbl.translation = [padX, listY]
        m.emptyLbl.width = contentW
    end if
    if m.listHost <> invalid then
        m.listHost.translation = [padX, listY]
    end if
    m.rowW = contentW
end sub

sub SnapDrawerClosed()
    if m.slideAnim <> invalid then m.slideAnim.control = "stop"
    if m.drawer <> invalid then m.drawer.translation = [m.closedX, 0]
    if m.scrim <> invalid then
        m.scrim.opacity = 0.0
        m.scrim.visible = false
    end if
    m.isOpen = false
    m.isClosing = false
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
        UpdateCountLabel()
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
    m.slideAnim.easeFunction = "outCubic"
    m.slideInterp.keyValue = [[curX, 0.0], [m.openX, 0.0]]
    if m.scrimInterp <> invalid then m.scrimInterp.keyValue = [curOp, 1.0]
    m.slideAnim.control = "stop"
    m.slideAnim.control = "start"
    print "[REELS_SOCIAL_DBG] sidebar slideIn dur="; RL_SidebarEnterSec()
end sub

sub StartSlideOut()
    m.isClosing = true
    if m.drawer = invalid or m.slideAnim = invalid or m.slideInterp = invalid then
        FinishClose()
        return
    end if
    curX = m.openX
    if m.drawer.translation <> invalid then curX = m.drawer.translation[0]
    curOp = 1.0
    if m.scrim <> invalid then curOp = m.scrim.opacity
    m.slideAnim.duration = RL_SidebarCloseSec()
    m.slideAnim.easeFunction = "inCubic"
    m.slideInterp.keyValue = [[curX, 0.0], [m.closedX, 0.0]]
    if m.scrimInterp <> invalid then m.scrimInterp.keyValue = [curOp, 0.0]
    m.slideAnim.control = "stop"
    m.slideAnim.control = "start"
    print "[REELS_SOCIAL_DBG] sidebar slideOut dur="; RL_SidebarCloseSec()
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
    print "[REELS_SOCIAL_DBG] sidebar closed"
end sub

sub OnReelChanged()
    if m.top.isOpen <> true then return
    UpdateCountLabel()
    FetchComments()
end sub

sub UpdateCountLabel()
    if m.countLbl = invalid then return
    m.countLbl.text = m.top.totalComments.ToStr() + " comments"
end sub

sub FetchComments()
    KillCommentTask()
    ShowLoading(true)
    reelId = m.top.reelId
    if reelId = "" then
        ShowLoading(false)
        ShowEmpty(true)
        return
    end if
    print "[REELS_SOCIAL_DBG] comments fetch reel="; reelId
    m.fetchTask = ApiGetQuery(Endpoints().REEL_COMMENTS, ReelsCommentsQuery(reelId))
    m.fetchTask.observeField("apiResult", "OnCommentsResponse")
    StartHttpTask(m.fetchTask)
end sub

sub OnCommentsResponse()
    if m.fetchTask = invalid then return
    api = m.fetchTask.apiResult
    ShowLoading(false)
    m.comments = ReelsParseComments(api)
    ReelsDbgApi("comments", api)
    print "[REELS_SOCIAL_DBG] comments parsed count="; m.comments.Count(); " ok="; (api <> invalid and api.ok = true)
    if m.comments.Count() = 0 then
        ShowEmpty(true)
        return
    end if
    ShowEmpty(false)
    BuildList()
end sub

sub ShowLoading(show as boolean)
    if m.loadingLbl <> invalid then m.loadingLbl.visible = show
    if show and m.emptyLbl <> invalid then m.emptyLbl.visible = false
    if show and m.listHost <> invalid then m.listHost.visible = false
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
end sub

sub ClearList()
    ClearListRows()
    m.comments = []
end sub

sub BuildList()
    ' Only clear row nodes — ClearList() also wipes m.comments and would empty the list.
    ClearListRows()
    y = 0
    rowW = 560
    if m.rowW <> invalid and m.rowW > 0 then rowW = m.rowW
    maxItems = m.comments.Count()
    if maxItems > RL_CommentLimit() then maxItems = RL_CommentLimit()
    print "[REELS_SOCIAL_DBG] comments build count="; maxItems
    for i = 0 to maxItems - 1
        c = m.comments[i]
        if c = invalid then continue for
        row = m.listHost.createChild("Group")
        row.translation = [0, y]
        bg = row.createChild("Rectangle")
        bg.width = rowW
        bg.height = 110
        bg.color = "0x00000000"
        nameLbl = row.createChild("Label")
        nameLbl.translation = [0, 0]
        nameLbl.width = rowW - 20
        nameLbl.height = 28
        nameLbl.text = ReelsCommentName(c)
        nameLbl.color = m.top.cNeutral50
        nameLbl.font = CreateObject("roSGNode", "Font")
        nameLbl.font.uri = "pkg:/fonts/Inter-Bold.ttf"
        nameLbl.font.size = 18
        bodyLbl = row.createChild("Label")
        bodyLbl.translation = [0, 34]
        bodyLbl.width = rowW - 20
        bodyLbl.height = 70
        bodyLbl.wrap = true
        bodyLbl.maxLines = 3
        bodyLbl.text = ReelsCommentText(c)
        bodyLbl.color = "0xffffffcc"
        bodyLbl.font = CreateObject("roSGNode", "Font")
        bodyLbl.font.uri = "pkg:/fonts/Inter-Regular.ttf"
        bodyLbl.font.size = 16
        y = y + 118
    end for
    m.listHost.visible = true
end sub

sub KillCommentTask()
    if m.fetchTask <> invalid then m.fetchTask.unobserveField("apiResult")
    m.fetchTask = invalid
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.top.isOpen <> true or m.isClosing then return
    key = LCase(ev.key)
    if key = "back" then
        m.top.action = "close"
    else if key = "ok" or key = "select" then
        if m.focus = "close" then m.top.action = "close"
    end if
end sub
