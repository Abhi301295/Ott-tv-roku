' ReelsScreen.brs — parity with src/features/reels/index.tsx

sub init()
    m.bg = m.top.findNode("bg")
    m.vm = FindViewManager(m.top)
    m.contentHost = m.top.findNode("contentHost")
    m.loaderHost = m.top.findNode("loaderHost")
    m.loaderPageBg = m.top.findNode("loaderPageBg")
    m.pageLoader = m.top.findNode("pageLoader")
    m.loaderCenter = m.top.findNode("loaderCenter")
    m.videoColumn = m.top.findNode("videoColumn")
    m.videoFrame = m.top.findNode("videoFrame")
    m.videoBorder = m.top.findNode("videoBorder")
    m.videoClip = m.top.findNode("videoClip")
    m.videoPlaceholder = m.top.findNode("videoPlaceholder")
    m.videoDummyArt = m.top.findNode("videoDummyArt")
    m.videoPoster = m.top.findNode("videoPoster")
    m.videoNode = m.top.findNode("videoNode")
    m.videoCornerHost = m.top.findNode("videoCornerHost")
    m.cornerTL = m.top.findNode("videoCornerTL")
    m.cornerTR = m.top.findNode("videoCornerTR")
    m.cornerBL = m.top.findNode("videoCornerBL")
    m.cornerBR = m.top.findNode("videoCornerBR")
    m.overlayHost = m.top.findNode("overlayHost")
    m.overlayRing = m.top.findNode("overlayRing")
    m.overlayArc = m.top.findNode("overlayArc")
    m.overlayCircle = m.top.findNode("overlayCircle")
    m.overlayPlay = m.top.findNode("overlayPlay")
    m.overlayPause = m.top.findNode("overlayPause")
    m.overlayAnim = m.top.findNode("overlayAnim")
    m.progressHost = m.top.findNode("progressHost")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.seekPreview = m.top.findNode("seekPreview")
    m.seekPreviewLbl = m.top.findNode("seekPreviewLbl")
    m.metaHost = m.top.findNode("metaHost")
    m.creatorRow = m.top.findNode("creatorRow")
    m.creatorAvatar = m.top.findNode("creatorAvatar")
    m.creatorInitial = m.top.findNode("creatorInitial")
    m.creatorLblBold = m.top.findNode("creatorLblBold")
    m.creatorLblRest = m.top.findNode("creatorLblRest")
    m.contentTypeLbl = m.top.findNode("contentTypeLbl")
    m.titleLbl = m.top.findNode("titleLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.pillHost = m.top.findNode("pillHost")
    m.emptyHost = m.top.findNode("emptyHost")
    m.emptyLbl = m.top.findNode("emptyLbl")
    m.seekPreviewTimer = m.top.findNode("seekPreviewTimer")

    m.reels = []
    m.currentIndex = 0
    m.page = 0
    m.hasMore = true
    m.loading = false
    m.loadingMore = false
    m.initialLoad = true
    m.seed = ReelsRandomSeed()
    m.hasUserInteracted = false
    m.hasStartedOnce = false
    m.isPlaying = false
    m.isBuffering = false
    m.pendingStreamUrl = ""
    m.playRequested = false
    m.position = 0.0
    m.duration = 0.0
    m.viewportW = 1920
    m.shellOffX = 0
    m.shellOffY = 0
    m.videoX = 0
    m.metaX = 0
    m.metaY = 0
    m.metaColW = RL_MetaMaxW()
    m.metaContentH = 0
    m.pillBlockH = 0
    m.disposed = false
    m.reelsTask = invalid
    m.fetchingPage = 1
    m.useInlineVideo = ReelsUseInlineVideo()

    LoadReelsTokens()
    ApplyStaticColors()
    ApplyVideoPosterLayout()
    ApplyReelsShellLayout()

    if m.videoNode <> invalid then
        m.videoNode.notificationInterval = 0.25
        m.videoNode.observeField("state", "OnVideoState")
        m.videoNode.observeField("position", "OnVideoPosition")
        m.videoNode.observeField("duration", "OnVideoDuration")
    end if
    if m.seekPreviewTimer <> invalid then
        m.seekPreviewTimer.duration = RL_SeekPreviewMs()
        m.seekPreviewTimer.observeField("fire", "OnSeekPreviewHide")
    end if
    if m.overlayAnim <> invalid then m.overlayAnim.control = "start"

    if m.videoPoster <> invalid then m.videoPoster.observeField("loadStatus", "OnReelPosterLoad")

    m.pageBgRest = m.cPageBg
    ApplyPageLoaderLayout(m.viewportW)
    m.top.observeField("keyEvent", "OnKey")
    m.top.observeField("visible", "OnReelsVisibleChanged")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
    InitReelsSocial()
    ReelsDbg("init", "ReelsScreen ready seed=" + Str(m.seed) + " sim=" + ReelsDbgStr(ReelsIsSimulator()) + " inlineVideo=" + ReelsDbgStr(m.useInlineVideo) + " layout=" + ThemeReelLayout())
end sub

sub OnNavStateReady()
    ReelsDbg("nav_ready", "route=reels")
    if m.vm <> invalid then ShellEnterContent(m.vm)
    ResetAndFetch()
end sub

sub OnShellEnterContent()
    if m.top.shellEnterContent <> true then return
    m.top.shellEnterContent = false
    ReelsDbg("shell_content", "focus content index=" + Str(m.currentIndex))
    m.reelsFocusZone = "video"
    SyncReelsDetailPanel()
    if m.initialFocusTimer <> invalid then m.initialFocusTimer.control = "start"
end sub

sub OnShellLayoutRev()
    ApplyReelsShellLayout()
end sub

sub OnReelsVisibleChanged()
    if m.disposed then return
    if m.top.visible <> true then
        ReelsDbg("visible", "paused — stop video + fetch")
        KillReelsTask()
        StopVideo()
        StopTimers()
        return
    end if
    if m.reels.Count() = 0 then return
    ReelsDbg("visible", "resume poster+play index=" + Str(m.currentIndex))
    m.isPlaying = false
    m.isBuffering = false
    m.playRequested = false
    StopVideo()
    ShowReelContent()
    ApplyReelPoster(m.reels[m.currentIndex])
    UpdateOverlay()
end sub

sub OnBusinessResolved()
    LoadReelsTokens()
    m.pageBgRest = m.cPageBg
    ApplyStaticColors()
    BrowseApplyPageLoaderColors(m)
    if m.commentSidebar <> invalid then
        m.commentSidebar.cNeutral50 = m.cNeutral50
        m.commentSidebar.cNeutral400 = m.cNeutral400
        m.commentSidebar.cNeutral700 = m.cNeutral700
        m.commentSidebar.cNeutral900 = m.cPageBg
        m.commentSidebar.cPrimary500 = m.cPrimary500
        m.commentSidebar.cPrimary600 = m.cPrimary600
    end if
    ' Re-sync detail panel so creator badge picks up API primary (not XML blue defaults).
    if m.reelDetailPanel <> invalid then SyncReelsDetailPanel()
end sub

sub OnDispose()
    if not m.top.dispose then return
    m.disposed = true
    ReelsDbg("dispose", "stopping video + fetch")
    KillReelsTask()
    StopVideo()
    StopTimers()
    BrowseHidePageLoader(m, m.pageBgRest)
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
    m.top.unobserveField("visible")
    if m.videoNode <> invalid then
        m.videoNode.unobserveField("state")
        m.videoNode.unobserveField("position")
        m.videoNode.unobserveField("duration")
    end if
    if m.videoPoster <> invalid then
        m.videoPoster.unobserveField("loadStatus")
    end if
    DisposeReelsSocial()
end sub

sub KillReelsTask()
    if m.reelsTask = invalid then return
    m.reelsTask.unobserveField("apiResult")
    m.reelsTask = invalid
end sub

sub StopTimers()
    if m.seekPreviewTimer <> invalid then
        m.seekPreviewTimer.control = "stop"
        m.seekPreviewTimer.unobserveField("fire")
    end if
end sub

sub StopVideo()
    if m.videoNode = invalid then return
    m.playRequested = false
    m.videoNode.control = "stop"
    m.videoNode.content = invalid
    m.videoNode.visible = false
end sub

sub LoadReelsTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens

    ' Theme — React reels/index.tsx bg-black.
    m.cPageBg = SK_LoadingPageBg()
    ' Fallbacks = React OldDetailCard gradient CSS defaults (#2563eb / #60a5fa); API primary overrides.
    m.cPrimary400 = TC("primary-400", "#60a5fa")
    m.cPrimary500 = TC("primary-500", "#3b82f6")
    m.cPrimary600 = TC("primary-600", "#2563eb")
    m.cPrimary700 = TC("primary-700", "#1d4ed8")
    m.cNeutral50 = TC("neutral-50", "#f5f5f5")
    m.cNeutral400 = TC("neutral-400", "#a3a3a3")
    m.cNeutral700 = TC("neutral-700", "#404040")

    ' Hardcoded — React text-white / op-80 / opacity-85 (not theme tokens).
    m.cTextWhite = HexToRokuColor("#ffffff", "ff")
    m.cTextWhite80 = HexToRokuColor("#ffffff", "cc")
    m.cTextWhite85 = HexToRokuColor("#ffffff", "d9")

    ' Hardcoded — React bg-blue-600/60, bg-white/20, bg-black/80 (Tailwind literals).
    m.cCategoryBg = HexToRokuColor("#2563eb", "99")
    m.cGenreBg = HexToRokuColor("#ffffff", "33")
    m.cProgressTrack = HexToRokuColor("#ffffff", "33")
    m.cSeekPreviewBg = HexToRokuColor("#000000", "cc")
    m.cOverlayCircle = HexToRokuColor("#000000", "ff")
    m.cVideoFrameBg = RL_VideoFrameBgColor()
    m.cVideoBorderIdle = RL_VideoBorderColor()
    m.cVideoBorderPrePlay = RL_VideoBorderColorPrePlay()
end sub

function TC(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

function TCA(name as string, alphaHex as string, fallbackHex as string) as string
    hex = fallbackHex
    if m.tokens <> invalid and m.tokens[name] <> invalid and m.tokens[name] <> "" then
        hex = m.tokens[name]
    end if
    return HexToRokuColor(hex, alphaHex)
end function

sub ApplyStaticColors()
    if m.bg <> invalid then m.bg.color = m.cPageBg
    SyncVideoFrameChrome()
    if m.videoDummyArt <> invalid then m.videoDummyArt.blendColor = m.cNeutral400
    if m.progressTrack <> invalid then m.progressTrack.color = m.cProgressTrack
    if m.progressFill <> invalid then m.progressFill.color = m.cPrimary500
    if m.overlayArc <> invalid then m.overlayArc.blendColor = m.cPrimary500
    if m.overlayCircle <> invalid then
        m.overlayCircle.blendColor = m.cOverlayCircle
        m.overlayCircle.opacity = RL_OverlayCircleOpacity()
    end if
    ' Icons are pre-rendered blue (#0000ff) at native size — no blendColor (keeps edges clean).
    if m.overlayPlay <> invalid then m.overlayPlay.blendColor = "0xffffffff"
    if m.overlayPause <> invalid then m.overlayPause.blendColor = "0xffffffff"
    if m.emptyLbl <> invalid then m.emptyLbl.color = m.cNeutral50
    if m.creatorAvatar <> invalid then m.creatorAvatar.blendColor = m.cPrimary600
    if m.creatorInitial <> invalid then m.creatorInitial.color = m.cNeutral50
    if m.creatorLblBold <> invalid then m.creatorLblBold.color = m.cTextWhite80
    if m.creatorLblRest <> invalid then m.creatorLblRest.color = m.cTextWhite80
    if m.contentTypeLbl <> invalid then m.contentTypeLbl.color = m.cTextWhite80
    if m.titleLbl <> invalid then m.titleLbl.color = m.cTextWhite
    if m.descLbl <> invalid then m.descLbl.color = m.cTextWhite85
    if m.seekPreviewBg <> invalid then m.seekPreviewBg.color = m.cSeekPreviewBg
    if m.seekPreviewLbl <> invalid then m.seekPreviewLbl.color = m.cTextWhite
end sub

sub SyncVideoFrameChrome()
    ' React: border-white/80 before first play, border-white/20 after; bg-[#111].
    borderColor = m.cVideoBorderPrePlay
    if m.hasStartedOnce = true then borderColor = m.cVideoBorderIdle
    if borderColor = invalid or borderColor = "" then borderColor = RL_VideoBorderColorPrePlay()
    if m.videoBorder <> invalid then m.videoBorder.color = borderColor
    fill = m.cVideoFrameBg
    if fill = invalid or fill = "" then fill = RL_VideoFrameBgColor()
    if m.videoPlaceholder <> invalid then
        m.videoPlaceholder.color = fill
        m.videoPlaceholder.visible = true
    end if
    ApplyVideoCornerLayout()
    ReelsDbg("frame_chrome", "startedOnce=" + ReelsDbgStr(m.hasStartedOnce) + " border=" + borderColor + " fill=" + fill)
end sub

sub ApplyReelsShellLayout()
    header = FindAppHeader(m.top)
    m.shellOffX = ShellContentOffsetX(header)
    m.shellOffY = ShellContentOffsetY(header)
    m.viewportW = ShellContentViewportW(header)
    if m.contentHost <> invalid then m.contentHost.translation = [m.shellOffX, m.shellOffY]

    vw = RL_VideoW()
    vh = RL_VideoH()
    outerW = RL_VideoOuterW()

    ' Center the outer frame (border included); metadata sits left of it.
    m.videoX = Int((m.viewportW - outerW) / 2)
    m.metaX = RL_MetaLeft() + RL_MetaPadX()
    m.metaColW = m.videoX - m.metaX - RL_MetaVideoGap()
    if m.metaColW < 400 then m.metaColW = 400
    if m.metaColW > RL_MetaMaxW() then m.metaColW = RL_MetaMaxW()

    if m.videoColumn <> invalid then
        ' Rest pose when not mid enter-anim (React .reel-enter-active end state).
        if m.reelsSwitching <> true then
            m.videoColumn.translation = [m.videoX, 0]
            m.videoColumn.scale = [1.0, 1.0]
            m.videoColumn.opacity = 1.0
        end if
    end if
    SyncVideoNodeLayout()

    absX = ReelsVideoAbsX()
    if m.overlayHost <> invalid then
        m.overlayHost.translation = [absX + Int(vw / 2), m.shellOffY + RL_VideoBorderW() + Int(vh / 2)]
    end if

    progressW = RL_VideoProgressW(vw)
    ph = RL_ProgressH()
    px = absX + Int((vw - progressW) / 2)
    py = m.shellOffY + RL_VideoBorderW() + vh - RL_ProgressBottom() - ph
    if m.progressHost <> invalid then m.progressHost.translation = [px, py]
    if m.progressTrack <> invalid then m.progressTrack.width = progressW
    if m.seekPreview <> invalid then
        m.seekPreview.translation = [absX + Int(vw / 2) - 60, py - 56]
    end if

    ApplyMetaWidths()
    if m.metaContentH > 0 then LayoutMetaLabels()
    PositionMetaHost()
    ApplyVideoCornerLayout()
    ReelsDbg("layout", "offX=" + Str(m.shellOffX) + " offY=" + Str(m.shellOffY) + " viewportW=" + Str(m.viewportW) + " outer=" + Str(outerW) + "x" + Str(RL_VideoOuterH()) + " videoX=" + Str(m.videoX) + " corners=TLTRBLBR")
end sub

function ReelsVideoAbsX() as integer
    return m.shellOffX + m.videoX + RL_VideoBorderW()
end function

sub SyncVideoNodeLayout()
    if m.videoNode = invalid then return
    bw = RL_VideoBorderW()
    vw = RL_VideoW()
    vh = RL_VideoH()
    absX = ReelsVideoAbsX()
    m.videoNode.translation = [absX, m.shellOffY + bw]
    m.videoNode.width = vw
    m.videoNode.height = vh
    ReelsDbg("video_layout", "absX=" + Str(absX) + " y=" + Str(bw) + " w=" + Str(vw) + " h=" + Str(vh))
end sub

sub ApplyMetaWidths()
    cw = m.metaColW
    if m.creatorLblRest <> invalid then m.creatorLblRest.width = cw - 58
    if m.contentTypeLbl <> invalid then m.contentTypeLbl.width = cw
    if m.titleLbl <> invalid then m.titleLbl.width = cw
    if m.descLbl <> invalid then m.descLbl.width = cw
end sub

sub LayoutMetaLabels()
    y = 0
    if m.creatorRow <> invalid and m.creatorRow.visible = true then
        m.creatorRow.translation = [0, y]
        y = y + 40
    end if
    if m.contentTypeLbl <> invalid and m.contentTypeLbl.text <> "" then
        m.contentTypeLbl.translation = [0, y]
        m.contentTypeLbl.visible = true
        y = y + 36
    else if m.contentTypeLbl <> invalid then
        m.contentTypeLbl.visible = false
    end if
    if m.titleLbl <> invalid and m.titleLbl.visible = true and m.titleLbl.text <> "" then
        m.titleLbl.translation = [0, y]
        y = y + 132
    end if
    if m.descLbl <> invalid and m.descLbl.visible = true then
        m.descLbl.translation = [0, y]
        y = y + 72
    end if
    if m.pillHost <> invalid then
        m.pillHost.translation = [0, y]
        if m.pillBlockH > 0 then y = y + m.pillBlockH
    end if
    m.metaContentH = y
    PositionMetaHost()
end sub

' React reels index.tsx TV info overlay: absolute bottom-28 + inner p-b-80.
sub PositionMetaHost()
    if m.metaHost = invalid then return
    reserve = RL_MetaBottomReserve()
    m.metaY = RL_VideoH() - reserve - m.metaContentH
    if m.metaY < 0 then m.metaY = 0
    m.metaHost.translation = [m.metaX, m.metaY]
    ReelsDbg("meta_pos", "y=" + Str(m.metaY) + " h=" + Str(m.metaContentH) + " reserve=" + Str(reserve))
end sub

sub ResetAndFetch()
    m.page = 0
    m.hasMore = true
    m.reels = []
    m.currentIndex = 0
    m.hasUserInteracted = false
    m.hasStartedOnce = false
    m.initialLoad = true
    StopVideo()
    HideContent()
    ShowEmpty(false)
    ShowPageLoader("boot")
    FetchPage(1)
end sub

sub ApplyPageLoaderLayout(viewportW as integer)
    if viewportW < 1 then viewportW = 1920
    if m.loaderPageBg <> invalid then
        m.loaderPageBg.width = 1920
        m.loaderPageBg.height = 1080
    end if
    ' Full-screen center — React Spinner is viewport-centered (not content-band offset).
    if m.loaderCenter <> invalid then m.loaderCenter.translation = [960, 518]
end sub

sub ShowPageLoader(reason as string)
    ' Never stack the page Spinner over an open comments drawer.
    if m.commentSidebar <> invalid and m.commentSidebar.isOpen = true then return
    ApplyPageLoaderLayout(m.viewportW)
    BrowseShowPageLoader(m, m.pageBgRest)
    ReelsDbg("page_loader", "show reason=" + reason)
end sub

sub HidePageLoader(reason as string)
    BrowseHidePageLoader(m, m.pageBgRest)
    if m.loaderHost <> invalid then
        m.loaderHost.visible = false
        m.loaderHost.opacity = 1.0
    end if
    if m.pageLoader <> invalid then m.pageLoader.running = false
    if m.loaderCenter <> invalid then m.loaderCenter.translation = [960, 518]
    ReelsDbg("page_loader", "hide reason=" + reason)
end sub

sub OnBrowseLoaderTimeout()
    if not BrowsePageLoaderRunning(m) then return
    if m.reels.Count() > 0 and m.videoColumn <> invalid and m.videoColumn.visible = false then
        ShowReelContent()
    end if
    CompleteReelsReveal()
end sub

function ReelsPaintGateOpen() as boolean
    return BrowseThumbPaintComplete(m.videoPoster)
end function

sub TryCompleteReelsReveal()
    if not BrowsePageLoaderRunning(m) then return
    if ReelsPaintGateOpen() then CompleteReelsReveal()
end sub

sub CompleteReelsReveal()
    if m.reels.Count() > 0 then ShowReelContent()
    HidePageLoader("reveal")
end sub

sub HideContent()
    if m.videoColumn <> invalid then m.videoColumn.visible = false
    if m.videoCornerHost <> invalid then m.videoCornerHost.visible = false
    if m.overlayHost <> invalid then m.overlayHost.visible = false
    if m.progressHost <> invalid then m.progressHost.visible = false
    if m.videoNode <> invalid then
        m.videoNode.visible = false
        m.videoNode.control = "stop"
    end if
    if m.metaHost <> invalid then m.metaHost.visible = false
end sub

sub ShowEmpty(show as boolean)
    ReelsDbg("empty", "visible=" + ReelsDbgStr(show))
    if m.emptyHost <> invalid then m.emptyHost.visible = show
    if m.emptyLbl <> invalid then m.emptyLbl.text = RL_EmptyCopy()
end sub

sub ApplyVideoCornerLayout()
    if m.videoCornerHost = invalid then return
    bw = RL_VideoBorderW()
    r = RL_VideoOuterRadius()
    outerW = RL_VideoOuterW()
    outerH = RL_VideoOuterH()

    m.videoCornerHost.translation = [m.shellOffX + m.videoX, m.shellOffY]
    pageBg = m.cPageBg
    if pageBg = invalid or pageBg = "" then pageBg = "0x0a0a0aff"
    for each corner in [m.cornerTL, m.cornerTR, m.cornerBL, m.cornerBR]
        if corner <> invalid then
            corner.width = r
            corner.height = r
            ' Match page bg so corners punch rounded-[12px] on all 4 sides.
            corner.blendColor = pageBg
        end if
    end for
    if m.cornerTL <> invalid then m.cornerTL.translation = [0, 0]
    if m.cornerTR <> invalid then m.cornerTR.translation = [outerW - r, 0]
    if m.cornerBL <> invalid then m.cornerBL.translation = [0, outerH - r]
    if m.cornerBR <> invalid then m.cornerBR.translation = [outerW - r, outerH - r]
end sub

sub ApplyVideoPosterLayout()
    vw = RL_VideoW()
    vh = RL_VideoH()
    bw = RL_VideoBorderW()
    outerW = RL_VideoOuterW()
    outerH = RL_VideoOuterH()
    if m.videoBorder <> invalid then
        m.videoBorder.width = outerW
        m.videoBorder.height = outerH
    end if
    if m.videoClip <> invalid then
        m.videoClip.translation = [bw, bw]
        m.videoClip.clippingRect = [0, 0, vw, vh]
    end if
    CardApplyPosterCover(m.videoPoster, m.videoClip, vw, vh)
    if m.videoPlaceholder <> invalid then
        m.videoPlaceholder.width = vw
        m.videoPlaceholder.height = vh
    end if
    ring = RL_OverlayRingSize()
    circle = RL_OverlayCircleSize()
    playSz = RL_OverlayPlaySize()
    if m.overlayCircle <> invalid then
        m.overlayCircle.width = circle
        m.overlayCircle.height = circle
        m.overlayCircle.translation = [-Int(circle / 2), -Int(circle / 2)]
    end if
    if m.overlayPlay <> invalid then
        m.overlayPlay.width = playSz
        m.overlayPlay.height = playSz
        m.overlayPlay.translation = [-Int(playSz / 2), -Int(playSz / 2)]
    end if
    pauseSz = RL_OverlayPauseSize()
    if m.overlayPause <> invalid then
        m.overlayPause.width = pauseSz
        m.overlayPause.height = pauseSz
        m.overlayPause.translation = [-Int(pauseSz / 2), -Int(pauseSz / 2)]
    end if
    ApplyVideoCornerLayout()
    SyncVideoNodeLayout()
end sub

sub ApplyReelPoster(reel as object)
    ApplyVideoPosterLayout()
    thumb = ReelsVerticalThumb(reel)
    posterUri = ReelsPosterUri(reel)
    useDummy = (thumb = "") and (posterUri = RL_DummyThumbPosterUri())
    ReelsDbg("poster", "dummy=" + ReelsDbgStr(useDummy) + " uri=" + Left(posterUri, 80))

    SyncVideoFrameChrome()
    if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
    if m.videoPoster <> invalid then
        m.videoPoster.visible = true
        m.videoPoster.uri = posterUri
    end if
    ' Keep Video hidden until user plays — poster + #111 frame stay visible (React poster overlays).
    if m.videoNode <> invalid then
        m.videoNode.visible = false
        if not m.useInlineVideo then
            m.videoNode.control = "stop"
            m.videoNode.content = invalid
        end if
    end if
end sub

sub OnReelPosterLoad()
    if m.disposed or m.videoPoster = invalid then return
    status = m.videoPoster.loadStatus
    ReelsDbg("poster_load", "status=" + status)
    if status = "ready" then
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        m.videoPoster.visible = true
        TryCompleteReelsReveal()
    else if status = "failed" then
        ReelsDbg("poster_load", "failed -> dummy placeholder")
        m.videoPoster.uri = RL_DummyThumbPosterUri()
        m.videoPoster.visible = true
        SyncVideoFrameChrome()
        TryCompleteReelsReveal()
    end if
end sub

sub FetchPage(pageNum as integer)
    if m.loadingMore then return
    if pageNum > 1 and not m.hasMore then return

    m.loadingMore = true
    m.loading = true
    m.fetchingPage = pageNum
    if pageNum = 1 then ShowPageLoader("fetch")

    path = Endpoints().REELS_LIST
    q = ReelsBuildQuery(pageNum, RL_PageLimit(), m.seed)
    ReelsDbg("fetch", "path=" + path + " page=" + Str(pageNum) + " seed=" + Str(m.seed))
    KillReelsTask()
    m.reelsTask = ApiGetQuery(path, q)
    m.reelsTask.observeField("apiResult", "OnReelsResponse")
    StartHttpTask(m.reelsTask)
end sub

sub OnReelsResponse()
    if m.disposed then return
    if m.reelsTask = invalid then return
    m.reelsTask.unobserveField("apiResult")
    api = m.reelsTask.apiResult
    m.reelsTask = invalid
    m.loadingMore = false
    m.loading = false
    m.initialLoad = false

    ReelsDbgApi("response", api)
    parsed = ReelsParseResponse(api)
    batch = parsed.items
    if api = invalid or api.ok <> true or (api.statusCode <> invalid and api.statusCode <> 200) then
        if m.reels.Count() = 0 then
            HidePageLoader("fetch_fail")
            ShowEmpty(true)
            ShowAlert(m.top, 2, RL_ErrorCopy())
        end if
        m.hasMore = false
        return
    end if

    if m.page = 0 or m.fetchingPage = 1 then
        m.reels = batch
    else
        for each item in batch
            m.reels.Push(item)
        end for
    end if
    m.page = m.fetchingPage
    if parsed.page > 0 then m.page = parsed.page

    accumulated = m.reels.Count()
    m.hasMore = ReelsPageHasMore(batch.Count(), accumulated, parsed.total)
    ReelsDbg("response", "accumulated=" + Str(accumulated) + " hasMore=" + ReelsDbgStr(m.hasMore) + " seed=" + Str(m.seed).Trim())
    ReelsDbgOrder(batch, m.fetchingPage, m.seed)

    if accumulated = 0 then
        HidePageLoader("empty")
        ShowEmpty(true)
        return
    end if

    ShowEmpty(false)
    if m.currentIndex >= accumulated then m.currentIndex = 0
    LoadCurrentReel(true)
    MaybePrefetchPage()
end sub

sub MaybePrefetchPage()
    if m.loadingMore then return
    if not m.hasMore then return
    if m.reels.Count() = 0 then return
    if m.currentIndex < m.reels.Count() - RL_PrefetchThreshold() then return
    ReelsDbg("prefetch_page", "index=" + Str(m.currentIndex) + " len=" + Str(m.reels.Count()) + " next=" + Str(m.page + 1))
    FetchPage(m.page + 1)
end sub

sub LoadCurrentReel(isNew as boolean)
    if m.reels.Count() = 0 then return
    reel = m.reels[m.currentIndex]
    if reel = invalid then return

    StopVideo()
    m.playRequested = false
    m.hasStartedOnce = false
    m.pendingStreamUrl = ReelsStreamUrl(reel)
    ReelsDbgThumbProbe(reel, m.currentIndex)
    ReelsDbg("video_load", "index=" + Str(m.currentIndex) + " url=" + Left(m.pendingStreamUrl, 80) + " poster=" + ReelsDbgStr(ReelsHasPoster(reel)))

    ' Rest Y before paint — switch anim starts from ±60 after this load.
    if m.videoColumn <> invalid then m.videoColumn.translation = [m.videoX, 0]

    ApplyMeta(reel)
    ShowReelContent()
    ApplyReelPoster(reel)
    TryCompleteReelsReveal()

    m.position = 0.0
    m.duration = 0.0
    UpdateProgressBar()
    m.isBuffering = false
    m.isPlaying = false
    UpdateOverlay()

    if m.pendingStreamUrl = "" then
        ReelsDbg("video_load", "no stream url — poster only")
    end if
    ReelsSocialAfterReelLoad()
end sub

sub EnsureVideoContent() as boolean
    if m.videoNode = invalid then return false
    if m.videoNode.content <> invalid then return true
    if m.pendingStreamUrl = "" then return false

    content = CreateObject("roSGNode", "ContentNode")
    content.url = m.pendingStreamUrl
    content.streamFormat = VideoStreamFormat(m.pendingStreamUrl)
    reel = invalid
    if m.reels.Count() > 0 then reel = m.reels[m.currentIndex]
    if reel <> invalid and ReelsTitle(reel) <> "" then content.title = ReelsTitle(reel)
    m.videoNode.content = content
    ReelsDbg("video_content", "attached url=" + Left(m.pendingStreamUrl, 80))
    return true
end sub

sub ShowPosterFrame()
    m.playRequested = false
    if m.videoNode <> invalid then
        m.videoNode.visible = false
        m.videoNode.control = "stop"
        m.videoNode.content = invalid
    end if
    reel = invalid
    if m.reels.Count() > 0 then reel = m.reels[m.currentIndex]
    if reel <> invalid then ApplyReelPoster(reel)
end sub

sub ShowReelContent()
    if m.videoColumn <> invalid then m.videoColumn.visible = true
    if m.videoCornerHost <> invalid then m.videoCornerHost.visible = true
    if m.progressHost <> invalid then m.progressHost.visible = true
    if m.metaHost <> invalid then m.metaHost.visible = false
    if m.reelDetailPanel <> invalid and m.reels.Count() > 0 then m.reelDetailPanel.visible = true
    if m.overlayHost <> invalid then m.overlayHost.visible = true
    ' Simulator: keep Video hidden so only the clipped Poster shows in the frame.
    if not m.useInlineVideo and m.videoNode <> invalid then
        m.videoNode.visible = false
        m.videoNode.control = "stop"
    end if
    ' Content is on screen — never leave the page Spinner stacked over the reel/detail.
    if m.loaderHost <> invalid and m.loaderHost.visible = true then HidePageLoader("content")
    UpdateOverlay()
end sub

sub ApplyMeta(reel as object)
    if reel = invalid then return
    ReelsDbg("meta", "start")

    creator = ReelsCreatorName(reel)
    ReelsDbg("meta", "creator=" + Left(creator, 40))
    if m.creatorRow <> invalid then
        showCreator = creator <> ""
        m.creatorRow.visible = showCreator
        if showCreator then
            initial = ""
            rest = ""
            if Len(creator) > 0 then
                initial = UCase(Left(creator, 1))
                if Len(creator) > 1 then rest = Mid(creator, 2)
            end if
            if m.creatorInitial <> invalid then m.creatorInitial.text = initial
            if m.creatorLblBold <> invalid then
                m.creatorLblBold.text = initial
                m.creatorLblBold.visible = initial <> ""
            end if
            if m.creatorLblRest <> invalid then
                m.creatorLblRest.text = rest
                m.creatorLblRest.visible = rest <> ""
            end if
        else
            if m.creatorLblBold <> invalid then m.creatorLblBold.visible = false
            if m.creatorLblRest <> invalid then m.creatorLblRest.visible = false
        end if
    end if

    if m.contentTypeLbl <> invalid then m.contentTypeLbl.text = ReelsContentType(reel)
    title = ReelsTitle(reel)
    ReelsDbg("meta", "title=" + Left(title, 60))
    if m.titleLbl <> invalid then
        m.titleLbl.text = title
        m.titleLbl.visible = title <> ""
    end if
    desc = ReelsDescription(reel)
    if m.descLbl <> invalid then
        if desc <> "" then
            m.descLbl.text = desc
            m.descLbl.visible = true
        else
            m.descLbl.visible = false
        end if
    end if
    ReelsDbg("meta", "desc ok")
    BuildPills(reel)
    ReelsDbg("meta", "pills ok")
    LayoutMetaLabels()
end sub

sub BuildPills(reel as object)
    if m.pillHost = invalid then return
    m.pillHost.removeChildrenIndex(m.pillHost.getChildCount(), 0)

    x = 0
    y = 0
    rowH = 0
    maxW = m.metaColW

    cats = ReelsCategories(reel)
    for each c in cats
        if c = invalid then continue for
        catName = ReelsFieldName(c)
        if catName = "" then continue for
        pill = CreatePill(catName, m.cCategoryBg, m.cTextWhite)
        if pill = invalid then continue for
        pw = pill["w"]
        ph = pill["h"]
        grp = pill["group"]
        if grp = invalid then continue for
        if x + pw > maxW and x > 0 then
            x = 0
            y = y + rowH + RL_PillRowGap()
            rowH = 0
        end if
        grp.translation = [x, y]
        m.pillHost.appendChild(grp)
        x = x + pw + RL_PillGap()
        if ph > rowH then rowH = ph
    end for

    if cats.Count() > 0 then
        y = y + rowH + RL_PillRowGap()
        x = 0
        rowH = 0
    end if

    genres = ReelsGenres(reel)
    for each g in genres
        if g = invalid then continue for
        gName = ReelsFieldName(g)
        if gName = "" then continue for
        label = "#" + gName
        pill = CreatePill(label, m.cGenreBg, m.cTextWhite)
        if pill = invalid then continue for
        pw = pill["w"]
        ph = pill["h"]
        grp = pill["group"]
        if grp = invalid then continue for
        if x + pw > maxW and x > 0 then
            x = 0
            y = y + rowH + RL_PillRowGap()
            rowH = 0
        end if
        grp.translation = [x, y]
        m.pillHost.appendChild(grp)
        x = x + pw + RL_PillGap()
        if ph > rowH then rowH = ph
    end for

    m.pillBlockH = 0
    if cats.Count() > 0 or genres.Count() > 0 then
        m.pillBlockH = y + rowH
    end if
end sub

function CreatePill(text as string, bg as string, fg as string) as object
    padX = RL_PillPadX()
    padY = RL_PillPadY()
    fs = RL_PillFontSize()
    pillH = fs + padY * 2

    grp = CreateObject("roSGNode", "Group")
    lbl = CreateObject("roSGNode", "Label")
    lbl.text = text
    lbl.color = fg
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Inter-Regular.ttf"
    f.size = fs
    lbl.font = f

    estW = Len(text) * Int(fs * 0.52) + padX * 2
    if estW < pillH then estW = pillH
    lbl.width = estW
    lbl.height = pillH

    bgRect = CreateObject("roSGNode", "Poster")
    bgRect.uri = RL_PillShapeUri()
    bgRect.width = estW
    bgRect.height = pillH
    bgRect.loadDisplayMode = "scaleToFill"
    bgRect.blendColor = bg

    grp.appendChild(bgRect)
    grp.appendChild(lbl)
    return { "group": grp, "w": estW, "h": pillH }
end function

sub OnVideoState()
    if m.disposed or m.videoNode = invalid then return
    if not m.useInlineVideo then return
    state = m.videoNode.state
    ReelsDbg("video_state", state + " playReq=" + ReelsDbgStr(m.playRequested))

    if (state = "buffering" or state = "playing") and m.playRequested <> true then
        ReelsDbg("video_state", "blocked — no user play request")
        StopVideo()
        ShowPosterFrame()
        m.isPlaying = false
        m.isBuffering = false
        UpdateOverlay()
        return
    end if

    if state = "buffering" then
        m.isBuffering = true
        ' Keep poster until first decoded frames (React keeps poster overlays until hasStartedOnce).
        if m.videoPoster <> invalid then m.videoPoster.visible = true
        if m.videoNode <> invalid then m.videoNode.visible = true
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        UpdateOverlay()
    else if state = "playing" then
        m.isBuffering = false
        m.isPlaying = true
        m.hasStartedOnce = true
        SyncVideoFrameChrome()
        if m.videoPlaceholder <> invalid then m.videoPlaceholder.visible = false
        if m.videoNode <> invalid then m.videoNode.visible = true
        if m.videoPoster <> invalid then m.videoPoster.visible = false
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        HidePageLoader("playing")
        UpdateOverlay()
    else if state = "paused" then
        m.isPlaying = false
        m.isBuffering = false
        ' ⚠ Parity Note: React keeps the last decoded video frame when paused; Roku Video
        ' often goes black, so restore the poster still inside the rounded frame.
        if m.videoPoster <> invalid then m.videoPoster.visible = true
        if m.videoNode <> invalid then m.videoNode.visible = false
        if m.videoPlaceholder <> invalid then m.videoPlaceholder.visible = true
        UpdateOverlay()
    else if state = "finished" then
        m.isPlaying = true
        m.isBuffering = false
        UpdateOverlay()
    else if state = "error" then
        ReelsDbg("video_state", "error — keep poster")
        m.isBuffering = false
        m.isPlaying = false
        HidePageLoader("error")
        ShowPosterFrame()
        UpdateOverlay()
    end if
end sub

sub OnVideoDuration()
    if m.videoNode = invalid then return
    d = m.videoNode.duration
    if d = invalid or d <= 0 then return
    m.duration = d
    UpdateProgressBar()
end sub

sub OnVideoPosition()
    if m.disposed or m.videoNode = invalid then return
    curPos = m.videoNode.position
    if curPos = invalid then return
    m.position = curPos
    if curPos > 0 and m.isPlaying then
        m.isBuffering = false
        if m.videoPoster <> invalid then m.videoPoster.visible = false
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        if m.videoNode <> invalid then m.videoNode.visible = true
        HidePageLoader("position")
    end if
    UpdateProgressBar()
    UpdateOverlay()
end sub

sub UpdateProgressBar()
    if m.progressFill = invalid or m.progressTrack = invalid then return
    pw = m.progressTrack.width
    if pw = invalid or pw <= 0 then pw = RL_VideoProgressW(RL_VideoW())
    pct = 0.0
    if m.duration > 0 then pct = m.position / m.duration
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1
    m.progressFill.width = Int(pw * pct)
end sub

sub UpdateOverlay()
    if m.overlayHost = invalid then return
    show = false
    if not m.isPlaying then show = true
    if m.isBuffering and m.isPlaying then show = true
    m.overlayHost.visible = show

    if m.overlayRing <> invalid then m.overlayRing.visible = m.isBuffering and m.isPlaying
    if m.overlayArc <> invalid then m.overlayArc.visible = m.isBuffering and m.isPlaying
    showCircle = show
    if m.overlayCircle <> invalid then m.overlayCircle.visible = showCircle
    if m.overlayPlay <> invalid then
        m.overlayPlay.visible = not m.isPlaying and not m.isBuffering
    end if
    if m.overlayPause <> invalid then
        m.overlayPause.visible = m.isBuffering and m.isPlaying
    end if
end sub

sub TogglePlayPause()
    if m.pendingStreamUrl = "" then
        ReelsDbg("play", "ignored — no stream url")
        return
    end if

    if not m.useInlineVideo then
        PlayReelFullscreen()
        return
    end if

    if m.videoNode = invalid then return

    m.hasUserInteracted = true
    if m.isPlaying then
        m.playRequested = false
        m.videoNode.control = "pause"
        m.isPlaying = false
        if m.videoPoster <> invalid then m.videoPoster.visible = true
        if m.videoNode <> invalid then m.videoNode.visible = false
        ReelsDbg("play", "pause")
    else
        if not EnsureVideoContent() then return
        m.playRequested = true
        SyncVideoNodeLayout()
        ' Poster stays until state=playing (hasStartedOnce) so the frame never goes black.
        if m.videoPoster <> invalid then m.videoPoster.visible = true
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        m.videoNode.visible = true
        m.videoNode.control = "play"
        m.isPlaying = true
        m.isBuffering = true
        ReelsDbg("play", "play on OK")
    end if
    UpdateOverlay()
end sub

sub PlayReelFullscreen()
    if m.vm = invalid or m.reels.Count() = 0 then return
    reel = m.reels[m.currentIndex]
    state = ReelsVideoPlayerPayload(reel)
    if state = invalid then
        ReelsDbg("play", "fullscreen abort — bad payload")
        ShowAlert(m.top, 2, RL_ErrorCopy())
        return
    end if
    ReelsDbg("play", "fullscreen route=video_player url=" + Left(m.pendingStreamUrl, 80))
    m.vm.callFunc("NavigatePush", RouteVideoPlayer(), state)
end sub

sub SeekBy(delta as integer)
    if m.videoNode = invalid then return
    if m.videoNode.content = invalid then return
    target = m.position + delta
    if target < 0 then target = 0
    if m.duration > 0 and target > m.duration then target = m.duration
    m.videoNode.seek = target
    m.position = target
    UpdateProgressBar()
    ShowSeekPreview(target)
    ReelsDbg("seek", "delta=" + Str(delta) + " pos=" + Str(target))
end sub

sub ShowSeekPreview(secs as float)
    if m.seekPreview = invalid or m.seekPreviewLbl = invalid then return
    m.seekPreviewLbl.text = VideoFormatTime(secs)
    m.seekPreview.visible = true
    if m.seekPreviewTimer <> invalid then m.seekPreviewTimer.control = "start"
end sub

sub OnSeekPreviewHide()
    if m.seekPreview <> invalid then m.seekPreview.visible = false
end sub

sub EnterReelsHeader()
    ReelsDbg("nav", "enter header from index=" + Str(m.currentIndex))
    StopVideo()
    m.isPlaying = false
    m.isBuffering = false
    m.playRequested = false
    UpdateOverlay()
    if m.vm <> invalid then ShellEnterHeader(m.vm, invalid)
end sub

sub SwitchReel(dir as integer)
    if m.reels.Count() = 0 then return
    if dir = -1 and m.currentIndex = 0 then
        if NavUpOpensHeaderFromContent() then EnterReelsHeader()
        return
    end if
    n = m.reels.Count()
    old = m.currentIndex
    m.currentIndex = (m.currentIndex + dir + n) mod n
    ReelsDbg("nav", "dir=" + Str(dir) + " " + Str(old) + "->" + Str(m.currentIndex))
    LoadCurrentReel(true)
    MaybePrefetchPage()
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return

    key = LCase(ev.key.ToStr())
    if m.vm <> invalid and m.vm.shellFocus = "header" then
        ReelsDbg("key", "ignored shellFocus=header key=" + key)
        return
    end if
    if m.reels.Count() = 0 then return
    if key = "back" then return
    HandleReelsSocialKey(key)
end sub
