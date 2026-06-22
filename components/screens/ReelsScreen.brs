' ReelsScreen.brs — parity with src/features/reels/index.tsx

sub init()
    m.bg = m.top.findNode("bg")
    m.vm = FindViewManager(m.top)
    m.contentHost = m.top.findNode("contentHost")
    m.skeletonHost = m.top.findNode("skeletonHost")
    m.videoColumn = m.top.findNode("videoColumn")
    m.videoFrame = m.top.findNode("videoFrame")
    m.videoBorder = m.top.findNode("videoBorder")
    m.videoClip = m.top.findNode("videoClip")
    m.videoPlaceholder = m.top.findNode("videoPlaceholder")
    m.videoDummyArt = m.top.findNode("videoDummyArt")
    m.videoPoster = m.top.findNode("videoPoster")
    m.videoNode = m.top.findNode("videoNode")
    m.overlayHost = m.top.findNode("overlayHost")
    m.overlayRing = m.top.findNode("overlayRing")
    m.overlayArc = m.top.findNode("overlayArc")
    m.overlayCircle = m.top.findNode("overlayCircle")
    m.overlayPlay = m.top.findNode("overlayPlay")
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
    m.creatorLbl = m.top.findNode("creatorLbl")
    m.contentTypeLbl = m.top.findNode("contentTypeLbl")
    m.titleLbl = m.top.findNode("titleLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.pillHost = m.top.findNode("pillHost")
    m.emptyHost = m.top.findNode("emptyHost")
    m.emptyLbl = m.top.findNode("emptyLbl")
    m.seekPreviewTimer = m.top.findNode("seekPreviewTimer")
    m.skeletonTimeout = m.top.findNode("skeletonTimeout")

    m.reels = []
    m.currentIndex = 0
    m.page = 0
    m.hasMore = true
    m.loading = false
    m.loadingMore = false
    m.initialLoad = true
    m.seed = ReelsRandomSeed()
    m.hasUserInteracted = false
    m.isPlaying = false
    m.isBuffering = false
    m.pendingStreamUrl = ""
    m.playRequested = false
    m.position = 0.0
    m.duration = 0.0
    m.viewportW = 1920
    m.shellOffX = 0
    m.videoX = 0
    m.metaX = 0
    m.metaY = 0
    m.metaColW = RL_MetaMaxW()
    m.disposed = false
    m.reelsTask = invalid
    m.showingSkeleton = false
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
    if m.skeletonTimeout <> invalid then
        m.skeletonTimeout.duration = RL_SkeletonMaxSec()
        m.skeletonTimeout.observeField("fire", "OnSkeletonTimeout")
    end if
    if m.overlayAnim <> invalid then m.overlayAnim.control = "start"

    if m.videoPoster <> invalid then m.videoPoster.observeField("loadStatus", "OnReelPosterLoad")

    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
    ReelsDbg("init", "ReelsScreen ready seed=" + Str(m.seed) + " sim=" + ReelsDbgStr(ReelsIsSimulator()) + " inlineVideo=" + ReelsDbgStr(m.useInlineVideo))
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
end sub

sub OnShellLayoutRev()
    ApplyReelsShellLayout()
end sub

sub OnReelsVisibleChanged()
    if m.top.visible <> true then return
    if m.disposed then return
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
    ApplyStaticColors()
end sub

sub OnDispose()
    if not m.top.dispose then return
    m.disposed = true
    ReelsDbg("dispose", "stopping video + fetch")
    KillReelsTask()
    StopVideo()
    StopTimers()
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
    if m.videoNode <> invalid then
        m.videoNode.unobserveField("state")
        m.videoNode.unobserveField("position")
        m.videoNode.unobserveField("duration")
    end if
    if m.videoPoster <> invalid then
        m.videoPoster.unobserveField("loadStatus")
    end if
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
    if m.skeletonTimeout <> invalid then
        m.skeletonTimeout.control = "stop"
        m.skeletonTimeout.unobserveField("fire")
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
    m.cPageBg = TC("neutral-900", "#0a0a0a")
    m.cPrimary500 = TC("primary-500", "#0b75e0")
    m.cPrimary600 = TC("primary-600", "#0760bb")
    m.cNeutral50 = TC("neutral-50", "#f5f5f5")
    m.cNeutral400 = TC("neutral-400", "#a3a3a3")
    m.cNeutral700 = TC("neutral-700", "#404040")
    m.cNeutral800 = TC("neutral-800", "#262626")
    ' React bg-blue-600/60 & bg-white/20 use alpha + backdrop-blur. Roku has no blur —
    ' composite onto page bg as opaque colors so Poster blendColor stays sharp (no wash-out).
    blueHex = "#2563eb"
    if m.tokens <> invalid and m.tokens["blue-600"] <> invalid and m.tokens["blue-600"] <> "" then
        blueHex = m.tokens["blue-600"]
    end if
    whiteHex = "#ffffff"
    if m.tokens <> invalid and m.tokens["neutral-50"] <> invalid and m.tokens["neutral-50"] <> "" then
        whiteHex = m.tokens["neutral-50"]
    end if
    mutedHex = "#f5f5f5"
    if m.tokens <> invalid and m.tokens["neutral-50"] <> invalid and m.tokens["neutral-50"] <> "" then
        mutedHex = m.tokens["neutral-50"]
    end if
    m.cCategoryBg = CompositeOverBg(blueHex, 0.6, m.cPageBg)
    m.cCategoryFg = m.cNeutral50
    m.cGenreBg = CompositeOverBg(whiteHex, 0.2, m.cPageBg)
    m.cGenreFg = m.cNeutral50
    m.cMetaMuted = CompositeOverBg(mutedHex, 0.8, m.cPageBg)
    m.cMetaBody = CompositeOverBg(mutedHex, 0.85, m.cPageBg)
    m.cProgressTrack = CompositeOverBg(whiteHex, 0.2, m.cPageBg)
    m.cOverlayCircle = CompositeOverBg("#0a0a0a", 0.7, m.cPageBg)
    m.cSeekPreviewBg = CompositeOverBg("#0a0a0a", 0.8, m.cPageBg)
    ReelsDbg("colors", "category=" + m.cCategoryBg + " genre=" + m.cGenreBg)
end sub

function ParseHexRgb(hex as string) as object
    s = hex
    if Left(s, 1) = "#" then s = Mid(s, 2)
    if Len(s) < 6 then return { r: 0, g: 0, b: 0 }
    return {
        r: Val(Mid(s, 1, 2), 16)
        g: Val(Mid(s, 3, 2), 16)
        b: Val(Mid(s, 5, 2), 16)
    }
end function

function ParseRokuRgb(c as string) as object
    s = c
    if Left(s, 2) = "0x" then s = Mid(s, 3)
    if Len(s) < 6 then return { r: 0, g: 0, b: 0 }
    return {
        r: Val(Mid(s, 1, 2), 16)
        g: Val(Mid(s, 3, 2), 16)
        b: Val(Mid(s, 5, 2), 16)
    }
end function

' Flatten React /60 and /20 alphas onto the solid page fill (sim-safe, no backdrop-blur).
function CompositeOverBg(fgHex as string, alpha as float, bgRoku as string) as string
    fg = ParseHexRgb(fgHex)
    bg = ParseRokuRgb(bgRoku)
    inv = 1.0 - alpha
    r = Int(fg.r * alpha + bg.r * inv + 0.5)
    g = Int(fg.g * alpha + bg.g * inv + 0.5)
    b = Int(fg.b * alpha + bg.b * inv + 0.5)
    if r > 255 then r = 255
    if g > 255 then g = 255
    if b > 255 then b = 255
    hex = Right("0" + StrI(r, 16).Trim(), 2)
    hex = hex + Right("0" + StrI(g, 16).Trim(), 2)
    hex = hex + Right("0" + StrI(b, 16).Trim(), 2)
    return "0x" + hex + "ff"
end function

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
    if m.videoBorder <> invalid then m.videoBorder.color = m.cNeutral400
    if m.videoPlaceholder <> invalid then m.videoPlaceholder.color = m.cNeutral700
    if m.videoDummyArt <> invalid then m.videoDummyArt.blendColor = m.cNeutral400
    if m.progressTrack <> invalid then m.progressTrack.color = m.cProgressTrack
    if m.progressFill <> invalid then m.progressFill.color = m.cPrimary500
    if m.overlayArc <> invalid then m.overlayArc.blendColor = m.cPrimary500
    if m.overlayCircle <> invalid then m.overlayCircle.blendColor = m.cOverlayCircle
    if m.overlayPlay <> invalid then m.overlayPlay.blendColor = m.cPrimary500
    if m.emptyLbl <> invalid then m.emptyLbl.color = m.cNeutral50
    if m.creatorAvatar <> invalid then m.creatorAvatar.blendColor = m.cPrimary600
    if m.creatorInitial <> invalid then m.creatorInitial.color = m.cNeutral50
    if m.creatorLbl <> invalid then m.creatorLbl.color = m.cMetaMuted
    if m.contentTypeLbl <> invalid then m.contentTypeLbl.color = m.cMetaMuted
    if m.titleLbl <> invalid then m.titleLbl.color = m.cNeutral50
    if m.descLbl <> invalid then m.descLbl.color = m.cMetaBody
    if m.seekPreviewBg <> invalid then m.seekPreviewBg.color = m.cSeekPreviewBg
    if m.seekPreviewLbl <> invalid then m.seekPreviewLbl.color = m.cNeutral50
end sub

sub ApplyReelsShellLayout()
    header = FindAppHeader(m.top)
    m.shellOffX = ShellContentOffsetX(header)
    m.viewportW = ShellContentViewportW(header)
    if m.contentHost <> invalid then m.contentHost.translation = [m.shellOffX, 0]

    vw = RL_VideoW()
    vh = RL_VideoH()

    ' Center video column; metadata sits in a left column (React wide-layout parity).
    m.videoX = Int((m.viewportW - vw) / 2)
    m.metaX = RL_MetaLeft() + RL_MetaPadX()
    m.metaColW = m.videoX - m.metaX - RL_MetaVideoGap()
    if m.metaColW < 400 then m.metaColW = 400
    if m.metaColW > RL_MetaMaxW() then m.metaColW = RL_MetaMaxW()
    m.metaY = RL_MetaTop()

    if m.videoColumn <> invalid then
        m.videoColumn.translation = [m.videoX, 0]
    end if
    SyncVideoNodeLayout()

    absX = ReelsVideoAbsX()
    if m.overlayHost <> invalid then
        m.overlayHost.translation = [absX + Int(vw / 2), Int(vh / 2)]
    end if

    progressW = RL_VideoProgressW(vw)
    ph = RL_ProgressH()
    px = absX + Int((vw - progressW) / 2)
    py = vh - RL_ProgressBottom() - ph
    if m.progressHost <> invalid then m.progressHost.translation = [px, py]
    if m.progressTrack <> invalid then m.progressTrack.width = progressW
    if m.seekPreview <> invalid then
        m.seekPreview.translation = [absX + Int(vw / 2) - 60, py - 56]
    end if

    if m.metaHost <> invalid then m.metaHost.translation = [m.metaX, m.metaY]
    ApplyMetaWidths()
    LayoutMetaLabels()
    ReelsDbg("layout", "offX=" + Str(m.shellOffX) + " viewportW=" + Str(m.viewportW) + " metaX=" + Str(m.metaX) + " metaW=" + Str(m.metaColW) + " videoX=" + Str(m.videoX) + " videoW=" + Str(RL_VideoW()) + " videoAbsX=" + Str(ReelsVideoAbsX()))
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
    m.videoNode.translation = [absX, bw]
    m.videoNode.width = vw
    m.videoNode.height = vh
    ReelsDbg("video_layout", "absX=" + Str(absX) + " y=" + Str(bw) + " w=" + Str(vw) + " h=" + Str(vh))
end sub

sub ApplyMetaWidths()
    cw = m.metaColW
    if m.creatorLbl <> invalid then m.creatorLbl.width = cw - 40
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
    if m.pillHost <> invalid then m.pillHost.translation = [0, y]
end sub

sub ResetAndFetch()
    m.page = 0
    m.hasMore = true
    m.reels = []
    m.currentIndex = 0
    m.hasUserInteracted = false
    m.initialLoad = true
    StopVideo()
    HideContent()
    ShowEmpty(false)
    ShowSkeleton(true, "boot")
    FetchPage(1)
end sub

sub HideContent()
    if m.videoColumn <> invalid then m.videoColumn.visible = false
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

sub ShowSkeleton(show as boolean, reason as string)
    m.showingSkeleton = show
    if m.skeletonHost = invalid then return
    m.skeletonHost.removeChildrenIndex(m.skeletonHost.getChildCount(), 0)
    if show then BuildReelsSkeleton()
    m.skeletonHost.visible = show
    if show then
        ReelsDbg("skeleton", "on reason=" + reason)
        if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "start"
    else
        ReelsDbg("skeleton", "off reason=" + reason)
        if m.skeletonTimeout <> invalid then m.skeletonTimeout.control = "stop"
    end if
end sub

sub BuildReelsSkeleton()
    if m.skeletonHost = invalid then return
    base = CardContrastSkeletonBase(m.cPageBg, m.cNeutral800)
    hi = CardSkeletonHighlightColor()

    tile = m.skeletonHost.createChild("Group")
    tile.translation = [m.videoX, 0]
    sk = tile.createChild("Skeleton")
    sk.boxWidth = RL_VideoW()
    sk.boxHeight = RL_VideoH()
    sk.shapeUri = RL_VideoSkeletonShapeUri()
    CardApplySkeleton(sk, base, hi)

    meta = m.skeletonHost.createChild("Group")
    meta.translation = [m.metaX, m.metaY]
    skW1 = Int(m.metaColW * 0.4)
    skW2 = Int(m.metaColW * 0.7)
    skW3 = m.metaColW
    skW4 = Int(m.metaColW * 0.85)
    lines = [48, 28, 60, 48]
    widths = [skW1, skW2, skW3, skW4]
    ly = 0
    for i = 0 to 3
        ln = meta.createChild("Skeleton")
        ln.boxWidth = widths[i]
        ln.boxHeight = lines[i]
        ln.translation = [0, ly]
        ln.shapeUri = RL_VideoSkeletonShapeUri()
        CardApplySkeleton(ln, base, hi)
        ly = ly + lines[i] + 16
    end for
end sub

sub OnSkeletonTimeout()
    ReelsDbg("skeleton", "timeout — force off")
    ShowSkeleton(false, "timeout")
    if m.reels.Count() > 0 and m.videoColumn <> invalid and m.videoColumn.visible = false then
        ShowReelContent()
    end if
end sub

sub ApplyVideoPosterLayout()
    vw = RL_VideoW()
    vh = RL_VideoH()
    CardApplyPosterCover(m.videoPoster, m.videoClip, vw, vh)
    if m.videoPlaceholder <> invalid then
        m.videoPlaceholder.width = vw
        m.videoPlaceholder.height = vh
    end if
    if m.videoDummyArt <> invalid then
        art = RL_DummyThumbArtSize()
        m.videoDummyArt.width = art
        m.videoDummyArt.height = art
        m.videoDummyArt.translation = [Int((vw - art) / 2), Int((vh - art) / 2)]
        m.videoDummyArt.uri = RL_DummyThumbArtUri()
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
    SyncVideoNodeLayout()
end sub

sub ApplyReelPoster(reel as object)
    ApplyVideoPosterLayout()
    thumb = ReelsVerticalThumb(reel)
    useDummy = thumb = ""
    ReelsDbg("poster", "dummy=" + ReelsDbgStr(useDummy) + " thumb=" + Left(thumb, 80))

    if m.videoPlaceholder <> invalid then m.videoPlaceholder.visible = true
    if m.videoDummyArt <> invalid then m.videoDummyArt.visible = useDummy
    if m.videoPoster <> invalid then
        if useDummy then
            m.videoPoster.uri = ""
            m.videoPoster.visible = false
        else
            m.videoPoster.visible = true
            m.videoPoster.uri = thumb
        end if
    end if
    if m.videoNode <> invalid then m.videoNode.visible = false
    if not m.useInlineVideo and m.videoNode <> invalid then
        m.videoNode.control = "stop"
        m.videoNode.content = invalid
    end if
end sub

sub OnReelPosterLoad()
    if m.disposed or m.videoPoster = invalid then return
    status = m.videoPoster.loadStatus
    ReelsDbg("poster_load", "status=" + status)
    if status = "ready" then
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        m.videoPoster.visible = true
    else if status = "failed" then
        m.videoPoster.visible = false
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = true
    end if
end sub

sub FetchPage(pageNum as integer)
    if m.loadingMore then return
    if pageNum > 1 and not m.hasMore then return

    m.loadingMore = true
    m.loading = true
    m.fetchingPage = pageNum
    if pageNum = 1 then ShowSkeleton(true, "fetch")

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
            ShowSkeleton(false, "fetch_fail")
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
    ReelsDbg("response", "accumulated=" + Str(accumulated) + " hasMore=" + ReelsDbgStr(m.hasMore))

    if accumulated = 0 then
        ShowSkeleton(false, "empty")
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
    m.pendingStreamUrl = ReelsStreamUrl(reel)
    ReelsDbgThumbProbe(reel, m.currentIndex)
    ReelsDbg("video_load", "index=" + Str(m.currentIndex) + " url=" + Left(m.pendingStreamUrl, 80) + " poster=" + ReelsDbgStr(ReelsHasPoster(reel)))

    ApplyMeta(reel)
    ShowSkeleton(false, "reel_ready")
    ShowReelContent()
    ApplyReelPoster(reel)

    m.position = 0.0
    m.duration = 0.0
    UpdateProgressBar()
    m.isBuffering = false
    m.isPlaying = false
    UpdateOverlay()

    if m.pendingStreamUrl = "" then
        ReelsDbg("video_load", "no stream url — poster only")
    end if
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
    if m.progressHost <> invalid then m.progressHost.visible = true
    if m.metaHost <> invalid then m.metaHost.visible = true
    if m.overlayHost <> invalid then m.overlayHost.visible = true
    ' Simulator: keep Video hidden so only the clipped Poster shows in the frame.
    if not m.useInlineVideo and m.videoNode <> invalid then
        m.videoNode.visible = false
        m.videoNode.control = "stop"
    end if
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
            if Len(creator) > 0 then initial = UCase(Left(creator, 1))
            if m.creatorInitial <> invalid then m.creatorInitial.text = initial
            if m.creatorLbl <> invalid then m.creatorLbl.text = creator
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
        pill = CreatePill(catName, m.cCategoryBg, m.cCategoryFg)
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
        pill = CreatePill(label, m.cGenreBg, m.cGenreFg)
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
        if m.videoPlaceholder <> invalid then m.videoPlaceholder.visible = false
        if m.videoNode <> invalid then m.videoNode.visible = true
        if m.videoPoster <> invalid then m.videoPoster.visible = false
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        UpdateOverlay()
    else if state = "playing" then
        m.isBuffering = false
        m.isPlaying = true
        if m.videoPlaceholder <> invalid then m.videoPlaceholder.visible = false
        if m.videoNode <> invalid then m.videoNode.visible = true
        if m.videoPoster <> invalid then m.videoPoster.visible = false
        if m.videoDummyArt <> invalid then m.videoDummyArt.visible = false
        ShowSkeleton(false, "playing")
        UpdateOverlay()
    else if state = "paused" then
        m.isPlaying = false
        m.isBuffering = false
        UpdateOverlay()
    else if state = "finished" then
        m.isPlaying = true
        m.isBuffering = false
        UpdateOverlay()
    else if state = "error" then
        ReelsDbg("video_state", "error — keep poster")
        m.isBuffering = false
        m.isPlaying = false
        ShowSkeleton(false, "error")
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
        ShowSkeleton(false, "position")
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
        ReelsDbg("play", "pause")
    else
        if not EnsureVideoContent() then return
        m.playRequested = true
        SyncVideoNodeLayout()
        if m.videoPoster <> invalid then m.videoPoster.visible = false
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

sub SwitchReel(dir as integer)
    if m.reels.Count() = 0 then return
    old = m.currentIndex
    n = m.reels.Count()
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

    if key = "up" then
        SwitchReel(-1)
    else if key = "down" then
        SwitchReel(1)
    else if key = "back" then
        return
    else if key = "left" or key = "rev" then
        if m.loading then return
        SeekBy(-RL_SeekStepSec())
    else if key = "right" or key = "fwd" then
        if m.loading then return
        SeekBy(RL_SeekStepSec())
    else if key = "ok" or key = "play" or key = "select" or key = "enter" then
        if m.loading then
            ReelsDbg("key", "play ignored — still loading")
            return
        end if
        ReelsDbg("key", "play key=" + key)
        TogglePlayPause()
    end if
end sub
