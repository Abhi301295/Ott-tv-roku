' LiveTvScreen.brs — pixel parity with src/features/livetv/index.tsx (mock EPG).

sub init()
    m.bg = m.top.findNode("bg")
    m.sidebarOccluder = m.top.findNode("sidebarOccluder")
    m.contentHost = m.top.findNode("contentHost")
    m.heroBackdropHost = m.top.findNode("heroBackdropHost")
    m.heroControlsHost = m.top.findNode("heroControlsHost")
    m.epgBg = m.top.findNode("epgBg")
    m.timelineRowBg = m.top.findNode("timelineRowBg")
    m.timelineCornerBg = m.top.findNode("timelineCornerBg")
    m.timelineCornerBorder = m.top.findNode("timelineCornerBorder")
    m.timelineTodayLbl = m.top.findNode("timelineTodayLbl")
    m.timelineBottomBorder = m.top.findNode("timelineBottomBorder")
    m.gridScrollBg = m.top.findNode("gridScrollBg")
    m.heroBackdropA = m.top.findNode("heroBackdropA")
    m.heroBackdropB = m.top.findNode("heroBackdropB")
    m.heroGradL = m.top.findNode("heroGradL")
    m.heroMeta = m.top.findNode("heroMeta")
    m.spotlightLbl = m.top.findNode("spotlightLbl")
    m.titleLbl = m.top.findNode("titleLbl")
    m.timeLbl = m.top.findNode("timeLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.heroBtnRow = m.top.findNode("heroBtnRow")
    m.playNowBg = m.top.findNode("playNowBg")
    m.playNowRing = m.top.findNode("playNowRing")
    m.playNowIcon = m.top.findNode("playNowIcon")
    m.playNowLbl = m.top.findNode("playNowLbl")
    m.playBeginningBtn = m.top.findNode("playBeginningBtn")
    m.playBeginningFill = m.top.findNode("playBeginningFill")
    m.playBeginningBorder = m.top.findNode("playBeginningBorder")
    m.playBeginningRing = m.top.findNode("playBeginningRing")
    m.playBeginningIcon = m.top.findNode("playBeginningIcon")
    m.playBeginningLbl = m.top.findNode("playBeginningLbl")
    m.epgHost = m.top.findNode("epgHost")
    m.epgTopBorder = m.top.findNode("epgTopBorder")
    m.timelineHost = m.top.findNode("timelineHost")
    m.liveDotHost = m.top.findNode("liveDotHost")
    m.gridClip = m.top.findNode("gridClip")
    m.channelColHost = m.top.findNode("channelColHost")
    m.channelColBg = m.top.findNode("channelColBg")
    m.channelColBorder = m.top.findNode("channelColBorder")
    m.channelRowsHost = m.top.findNode("channelRowsHost")
    m.programGridHost = m.top.findNode("programGridHost")
    m.programScrollHost = m.top.findNode("programScrollHost")
    m.liveLine = m.top.findNode("liveLine")
    m.nowTimer = m.top.findNode("nowTimer")
    m.initialFocusTimer = m.top.findNode("initialFocusTimer")
    m.backdropSwapTimer = m.top.findNode("backdropSwapTimer")
    m.backdropFadeAnim = m.top.findNode("backdropFadeAnim")
    m.backdropFadeInterp = m.top.findNode("backdropFadeInterp")

    m.vm = FindViewManager(m.top)
    m.viewportW = LT_CanvasW()
    m.shellOffX = 0
    m.channels = []
    m.displayTimelineStart = 0&
    m.displayTimelineEnd = 0&
    m.currentTime = 0&
    m.channelIndex = 0
    m.programIndex = 0
    m.focusZone = "program"
    m.heroBtnIndex = 0
    m.scrollLeft = 0
    m.scrollTop = 0
    m.disposed = false
    m.selectedChannel = invalid
    m.selectedProgram = invalid
    m.backdropUrl = ""
    m.backdropFrontIsA = true
    m.pendingBackdropUrl = ""
    m.heroTitleLines = 1

    ApplyShellLayout()
    UpdateNowTime()
    LoadEpgData()
    InitScrollToNow()
    RenderAll()

    if m.nowTimer <> invalid then
        m.nowTimer.duration = LT_NowTickMs() / 1000.0
        m.nowTimer.observeField("fire", "OnNowTimer")
        m.nowTimer.control = "start"
    end if
    if m.initialFocusTimer <> invalid then
        m.initialFocusTimer.observeField("fire", "OnInitialFocusTimer")
        m.initialFocusTimer.control = "start"
    end if
    if m.backdropSwapTimer <> invalid then
        m.backdropSwapTimer.observeField("fire", "OnBackdropSwapTimer")
    end if
    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
end sub

sub OnShellEnterContent()
    ApplyShellLayout()
    RenderAll()
end sub

sub OnShellLayoutRev()
    ApplyShellLayout()
    RenderAll()
end sub

sub OnBusinessResolved()
    ApplyShellLayout()
end sub

sub OnInitialFocusTimer()
    m.focusZone = "program"
    m.heroBtnIndex = 0
    CenterScrollForFocus()
    RenderAll()
end sub

sub ApplyShellLayout()
    header = FindAppHeader(m.top)
    offX = ShellContentOffsetX(header)
    vw = ShellContentViewportW(header)
    m.shellOffX = offX
    m.viewportW = vw
    if m.sidebarOccluder <> invalid then
        m.sidebarOccluder.width = offX
        m.sidebarOccluder.visible = offX > 0
    end if
    if m.contentHost <> invalid then
        m.contentHost.translation = [offX, 0]
        m.contentHost.clippingRect = [0, 0, vw, LT_CanvasH()]
    end if
    if m.bg <> invalid then
        m.bg.translation = [offX, 0]
        m.bg.width = vw
    end if

    heroH = LT_HeroHeight()
    epgH = LT_EpgHeight()
    gridH = LT_GridClipHeight()
    gradLW = LT_HeroGradLeftW(vw)
    metaW = LT_HeroMetaMaxW(vw)
    tl = 1
    if m.heroTitleLines <> invalid and m.heroTitleLines > 0 then tl = m.heroTitleLines

    if m.heroBackdropA <> invalid then
        m.heroBackdropA.width = vw
        m.heroBackdropA.height = heroH
    end if
    if m.heroBackdropB <> invalid then
        m.heroBackdropB.width = vw
        m.heroBackdropB.height = heroH
    end if
    if m.heroGradL <> invalid then
        m.heroGradL.width = gradLW
        m.heroGradL.height = heroH
    end if
    if m.heroBackdropHost <> invalid then
        m.heroBackdropHost.clippingRect = [0, 0, vw, heroH]
    end if
    if m.heroControlsHost <> invalid then
        m.heroControlsHost.clippingRect = [0, 0, vw, heroH]
    end if
    if m.spotlightLbl <> invalid then m.spotlightLbl.width = metaW
    if m.titleLbl <> invalid then m.titleLbl.width = metaW
    if m.timeLbl <> invalid then m.timeLbl.width = metaW
    ApplyHeroBtnLayout()
    ApplyHeroMetaStack(tl)
    if m.epgHost <> invalid then m.epgHost.translation = [0, heroH]
    if m.epgBg <> invalid then
        m.epgBg.width = vw
        m.epgBg.height = epgH
    end if
    if m.epgTopBorder <> invalid then m.epgTopBorder.width = vw
    tlH = LT_TimelineHeight()
    if m.timelineRowBg <> invalid then
        m.timelineRowBg.width = vw
        m.timelineRowBg.height = tlH
    end if
    if m.timelineCornerBg <> invalid then
        m.timelineCornerBg.width = LT_ChannelColWidth()
        m.timelineCornerBg.height = tlH
    end if
    if m.timelineCornerBorder <> invalid then
        m.timelineCornerBorder.height = tlH
    end if
    if m.timelineTodayLbl <> invalid then
        m.timelineTodayLbl.translation = [0, Int((tlH - 24) / 2)]
    end if
    if m.timelineBottomBorder <> invalid then
        m.timelineBottomBorder.translation = [0, tlH - 1]
        m.timelineBottomBorder.width = vw
    end if
    if m.gridScrollBg <> invalid then
        m.gridScrollBg.width = vw
        m.gridScrollBg.height = gridH
    end if
    if m.gridClip <> invalid then
        m.gridClip.translation = [0, tlH]
        m.gridClip.clippingRect = [0, 0, vw, gridH]
    end if
    if m.channelColHost <> invalid then m.channelColHost.clippingRect = [0, 0, LT_ChannelColWidth(), gridH]
    if m.channelRowsHost <> invalid then m.channelRowsHost.clippingRect = [0, 0, LT_ChannelColWidth(), gridH]
    if m.channelColBg <> invalid then
        m.channelColBg.width = LT_ChannelColWidth()
        m.channelColBg.height = gridH
    end if
    if m.channelColBorder <> invalid then
        m.channelColBorder.translation = [LT_ChannelColWidth() - 1, 0]
        m.channelColBorder.height = gridH
    end if
    if m.programGridHost <> invalid then
        m.programGridHost.clippingRect = [0, 0, vw - LT_ChannelColWidth(), gridH]
    end if
    if m.programScrollHost <> invalid then
        m.programScrollHost.clippingRect = [0, 0, vw - LT_ChannelColWidth(), gridH]
    end if
    if m.liveLine <> invalid then m.liveLine.height = gridH
end sub

sub ApplyHeroBtnLayout()
    playW = LT_PlayNowBtnW()
    begW = LT_PlayBeginningBtnW()
    btnH = LT_HeroBtnH()
    ringPad = LT_FocusRingW()
    iconX = LT_HeroBtnPadX()
    iconY = LT_HeroBtnIconY()
    labelX = LT_HeroBtnLabelX()
    iconSz = LT_HeroBtnIconSize()

    if m.playNowBg <> invalid then
        m.playNowBg.width = playW
        m.playNowBg.height = btnH
        m.playNowBg.uri = LT_PlayNowFillUri()
        m.playNowBg.scale = [1.0, 1.0]
    end if
    if m.playNowRing <> invalid then
        m.playNowRing.width = playW + ringPad * 2
        m.playNowRing.height = btnH + ringPad * 2
        m.playNowRing.translation = [-ringPad, -ringPad]
        m.playNowRing.scale = [1.0, 1.0]
    end if
    if m.playNowIcon <> invalid then
        m.playNowIcon.width = iconSz
        m.playNowIcon.height = iconSz
        m.playNowIcon.translation = [iconX, iconY]
    end if
    if m.playNowLbl <> invalid then
        m.playNowLbl.translation = [labelX, 0]
        m.playNowLbl.width = LT_HeroBtnLabelW(playW)
        m.playNowLbl.height = btnH
        m.playNowLbl.horizAlign = "left"
    end if

    if m.playBeginningBtn <> invalid then
        m.playBeginningBtn.translation = [playW + LT_HeroBtnGap(), 0]
    end if
    if m.playBeginningBorder <> invalid then
        m.playBeginningBorder.width = begW
        m.playBeginningBorder.height = btnH
        m.playBeginningBorder.scale = [1.0, 1.0]
    end if
    if m.playBeginningFill <> invalid then
        m.playBeginningFill.width = begW - 2
        m.playBeginningFill.height = btnH - 2
        m.playBeginningFill.translation = [1, 1]
        m.playBeginningFill.scale = [1.0, 1.0]
    end if
    if m.playBeginningRing <> invalid then
        m.playBeginningRing.width = begW + ringPad * 2
        m.playBeginningRing.height = btnH + ringPad * 2
        m.playBeginningRing.translation = [-ringPad, -ringPad]
        m.playBeginningRing.scale = [1.0, 1.0]
    end if
    if m.playBeginningIcon <> invalid then
        m.playBeginningIcon.width = iconSz
        m.playBeginningIcon.height = iconSz
        m.playBeginningIcon.translation = [iconX, iconY]
    end if
    if m.playBeginningLbl <> invalid then
        m.playBeginningLbl.translation = [labelX, 0]
        m.playBeginningLbl.width = LT_HeroBtnLabelW(begW)
        m.playBeginningLbl.height = btnH
        m.playBeginningLbl.horizAlign = "left"
    end if
end sub

sub ApplyHeroDescLabel()
    if m.descLbl = invalid then return
    tl = 1
    if m.heroTitleLines <> invalid and m.heroTitleLines > 0 then tl = m.heroTitleLines
    m.descLbl.width = LT_HeroDescWidth(m.viewportW)
    m.descLbl.height = 0
    m.descLbl.numLines = LT_HeroDescNumLines()
    m.descLbl.lineSpacing = LT_HeroDescLineSpacing()
    m.descLbl.wrap = true
    m.descLbl.vertAlign = "top"
    m.descLbl.horizAlign = "left"
    m.descLbl.ellipsizeOnBoundary = true
    m.descLbl.translation = [0, LT_HeroDescY(tl)]
end sub

sub ApplyHeroMetaStack(titleLines as integer)
    if titleLines < 1 then titleLines = 1
    if titleLines > 2 then titleLines = 2
    m.heroTitleLines = titleLines
    if m.titleLbl <> invalid then
        m.titleLbl.translation = [0, LT_HeroTitleY()]
        m.titleLbl.height = LT_HeroTitleStackH(titleLines)
    end if
    if m.timeLbl <> invalid then
        m.timeLbl.translation = [0, LT_HeroTimeY(titleLines)]
        m.timeLbl.height = LT_HeroTimeH()
    end if
    if m.descLbl <> invalid then
        ApplyHeroDescLabel()
    end if
    if m.heroBtnRow <> invalid then
        m.heroBtnRow.translation = [0, LT_HeroBtnRowY(titleLines)]
    end if
    if m.heroMeta <> invalid then
        m.heroMeta.translation = [LT_HeroMetaLeft(), LT_HeroMetaY(titleLines)]
    end if
end sub

sub LoadEpgData()
    data = LT_GenerateEPGData()
    if data = invalid then return
    if data.channels <> invalid then m.channels = data.channels
    m.displayTimelineStart = LT_DisplayTimelineStartMs()
    m.displayTimelineEnd = LT_DisplayTimelineEndMs()
    if m.channels.Count() > 0 then
        m.channelIndex = 0
        m.programIndex = LT_FindProgramIndexAtTime(m.channels[0], m.currentTime)
        SyncSelectedProgram()
    end if
end sub

sub UpdateNowTime()
    m.currentTime = LT_NowMs()
end sub

sub InitScrollToNow()
    ppm = LT_PixelsPerMinute()
    nowOff = Int(((m.currentTime - m.displayTimelineStart) / (60& * 1000&)) * ppm)
    m.scrollLeft = nowOff - LT_ScrollMarginX()
    if m.scrollLeft < 0 then m.scrollLeft = 0
end sub

sub OnNowTimer()
    UpdateNowTime()
    UpdateLiveLine()
end sub

sub SyncSelectedProgram()
    if m.channels.Count() = 0 then return
    ch = m.channels[m.channelIndex]
    if ch = invalid or ch.programs = invalid or ch.programs.Count() = 0 then return
    if m.programIndex < 0 or m.programIndex >= ch.programs.Count() then m.programIndex = 0
    m.selectedChannel = ch
    m.selectedProgram = ch.programs[m.programIndex]
end sub

sub RenderAll()
    UpdateHero()
    RenderTimeline()
    RenderRows()
    UpdateLiveLine()
    UpdateFocusChrome()
end sub

sub UpdateHero()
    if m.selectedChannel = invalid or m.selectedProgram = invalid then return
    ch = m.selectedChannel
    prog = m.selectedProgram
    cat = ""
    if prog.category <> invalid then cat = prog.category
    url = LT_BackdropUrl(ch.name, prog.title, cat)
    if m.spotlightLbl <> invalid then m.spotlightLbl.text = UCase(ch.name) + " SPOTLIGHT"
    titleLines = 1
    if m.titleLbl <> invalid then
        m.titleLbl.text = prog.title
    end if
    if m.timeLbl <> invalid then
        m.timeLbl.text = LT_FormatTime(prog.startTime) + " - " + LT_FormatTime(prog.endTime)
    end if
    if m.descLbl <> invalid then
        desc = ""
        if prog.description <> invalid then desc = prog.description
        m.descLbl.text = desc
    end if
    if m.titleLbl <> invalid then
        wl = m.titleLbl.wrappedLines
        if wl <> invalid and wl > 0 then titleLines = wl
    end if
    ApplyHeroMetaStack(titleLines)
    if url <> "" and url <> m.backdropUrl then
        if m.backdropUrl = "" then
            SetBackdropImmediate(url)
        else
            StartBackdropCrossfade(url)
        end if
    end if
end sub

sub StartBackdropCrossfade(url as string)
    m.pendingBackdropUrl = url
    front = m.heroBackdropA
    if not m.backdropFrontIsA then front = m.heroBackdropB
    if front = invalid then
        SetBackdropImmediate(url)
        return
    end if
    if m.backdropFadeInterp <> invalid and m.backdropFadeAnim <> invalid then
        m.backdropFadeInterp.keyValue = [LT_BackdropOpacity(), LT_BackdropFadeOpacity()]
        m.backdropFadeAnim.control = "start"
    else
        front.opacity = LT_BackdropFadeOpacity()
    end if
    if m.backdropSwapTimer <> invalid then m.backdropSwapTimer.control = "start"
end sub

sub OnBackdropSwapTimer()
    url = m.pendingBackdropUrl
    if url = "" then return
    back = m.heroBackdropB
    front = m.heroBackdropA
    if not m.backdropFrontIsA then
        back = m.heroBackdropA
        front = m.heroBackdropB
    end if
    if back <> invalid then
        back.uri = url
        back.opacity = LT_BackdropOpacity()
    end if
    if front <> invalid then front.opacity = 0.0
    m.backdropFrontIsA = not m.backdropFrontIsA
    m.backdropUrl = url
    m.pendingBackdropUrl = ""
end sub

sub SetBackdropImmediate(url as string)
    if m.heroBackdropA <> invalid then
        m.heroBackdropA.uri = url
        m.heroBackdropA.opacity = LT_BackdropOpacity()
    end if
    if m.heroBackdropB <> invalid then m.heroBackdropB.opacity = 0.0
    m.backdropUrl = url
    m.backdropFrontIsA = true
end sub

sub RenderTimeline()
    if m.timelineHost = invalid then return
    m.timelineHost.removeChildrenIndex(m.timelineHost.getChildCount(), 0)
    ppm = LT_PixelsPerMinute()
    marker = m.displayTimelineStart
    gridW = m.viewportW - LT_ChannelColWidth()
    tlH = LT_TimelineHeight()
    markW = 56
    while marker <= m.displayTimelineEnd
        x = Int(((marker - m.displayTimelineStart) / (60& * 1000&)) * ppm) - m.scrollLeft
        if x >= -markW and x <= gridW + markW then
            lbl = LT_MakeLabel(LT_FormatTimelineTime(marker), "pkg:/fonts/Inter-SemiBold.ttf", LT_FsTimelineMarker(), LT_ColorGray400(), markW, 16, "center", false)
            lbl.translation = [x - Int(markW / 2), Int((tlH - 16) / 2)]
            m.timelineHost.appendChild(lbl)
        end if
        marker = marker + (30& * 60& * 1000&)
    end while
end sub

sub AppendLiveTvBorder(parent as object, x as integer, y as integer, w as integer, h as integer, color as string, thick as integer)
    if parent = invalid then return
    top = CreateObject("roSGNode", "Rectangle")
    top.translation = [x, y]
    top.width = w
    top.height = thick
    top.color = color
    parent.appendChild(top)
    bot = CreateObject("roSGNode", "Rectangle")
    bot.translation = [x, y + h - thick]
    bot.width = w
    bot.height = thick
    bot.color = color
    parent.appendChild(bot)
    lft = CreateObject("roSGNode", "Rectangle")
    lft.translation = [x, y]
    lft.width = thick
    lft.height = h
    lft.color = color
    parent.appendChild(lft)
    rgt = CreateObject("roSGNode", "Rectangle")
    rgt.translation = [x + w - thick, y]
    rgt.width = thick
    rgt.height = h
    rgt.color = color
    parent.appendChild(rgt)
end sub

sub RenderRows()
    if m.channelRowsHost = invalid or m.programScrollHost = invalid then return
    m.channelRowsHost.removeChildrenIndex(m.channelRowsHost.getChildCount(), 0)
    m.programScrollHost.removeChildrenIndex(m.programScrollHost.getChildCount(), 0)
    if m.channels.Count() = 0 then return

    rowH = LT_RowHeight()
    chW = LT_ChannelColWidth()
    ppm = LT_PixelsPerMinute()
    buffer = LT_BufferRows()
    clipH = LT_GridClipHeight()
    gridW = m.viewportW - chW
    pad = LT_ProgramPad()

    startIdx = m.channelIndex - 3
    floorIdx = Int(m.scrollTop / rowH) - buffer
    if floorIdx > startIdx then startIdx = floorIdx
    if startIdx < 0 then startIdx = 0

    endIdx = m.channelIndex + 4
    ceilIdx = Int((m.scrollTop + clipH) / rowH) + buffer
    if ceilIdx > endIdx then endIdx = ceilIdx
    if endIdx > m.channels.Count() then endIdx = m.channels.Count()

    chScroll = CreateObject("roSGNode", "Group")
    chScroll.translation = [0, -m.scrollTop]
    m.channelRowsHost.appendChild(chScroll)

    progScroll = CreateObject("roSGNode", "Group")
    progScroll.translation = [Int(-m.scrollLeft), Int(-m.scrollTop)]
    m.programScrollHost.appendChild(progScroll)

    winLeft = m.scrollLeft
    winRight = m.scrollLeft + gridW

    for absIdx = startIdx to endIdx - 1
        channel = m.channels[absIdx]
        if channel = invalid then continue for
        rowY = absIdx * rowH

        chRow = CreateObject("roSGNode", "Group")
        chRow.translation = [0, rowY]
        chFocused = absIdx = m.channelIndex and m.focusZone = "channel"

        cellBg = LT_ColorChannelBg()
        if chFocused then cellBg = LT_ColorFocusBg()

        cell = CreateObject("roSGNode", "Rectangle")
        cell.width = chW
        cell.height = rowH
        cell.color = cellBg
        chRow.appendChild(cell)

        borderR = CreateObject("roSGNode", "Rectangle")
        borderR.translation = [chW - 1, 0]
        borderR.width = 1
        borderR.height = rowH
        if chFocused then
            borderR.color = LT_ColorFocusAccent()
        else
            borderR.color = LT_ColorBorderWhite5()
        end if
        chRow.appendChild(borderR)

        rowBorderB = CreateObject("roSGNode", "Rectangle")
        rowBorderB.translation = [0, rowH - 1]
        rowBorderB.width = chW
        rowBorderB.height = 1
        rowBorderB.color = LT_ColorBorderWhite5()
        chRow.appendChild(rowBorderB)

        logoY = LT_LogoBoxY()
        logoX = LT_ChannelPadX()
        logoBox = CreateObject("roSGNode", "Rectangle")
        logoBox.translation = [logoX, logoY]
        logoBox.width = LT_LogoBoxW()
        logoBox.height = LT_LogoBoxH()
        logoBox.color = LT_ColorLogoBoxBg()
        chRow.appendChild(logoBox)
        AppendLiveTvBorder(chRow, logoX, logoY, LT_LogoBoxW(), LT_LogoBoxH(), LT_ColorLogoBoxBorder(), 1)
        LT_AppendChannelLogo(chRow, logoX, logoY, channel.name)

        textX = LT_ChannelTextX()
        textW = chW - textX - 8
        textY = LT_ChannelTextY()
        dispName = channel.name
        nm = LCase(channel.name)
        if nm = "hbo" or nm = "espn" or nm = "discovery" or Instr(1, nm, "national") > 0 then dispName = "Channel"
        nameColor = LT_ColorGray300()
        if chFocused then nameColor = LT_ColorWhite()
        nameLbl = LT_MakeLabel(dispName, "pkg:/fonts/Inter-SemiBold.ttf", LT_FsChannelName(), nameColor, textW, LT_ChannelNameLineH(), "left", false, "top")
        nameLbl.translation = [textX, textY]
        chRow.appendChild(nameLbl)

        numY = textY + LT_ChannelNameLineH() + LT_ChannelNumberMarginTop()
        numLbl = LT_MakeLabel(channel.channelNumber, "pkg:/fonts/Inter-Medium.ttf", LT_FsChannelNumber(), LT_ColorZinc400(), textW, LT_ChannelNumberLineH(), "left", false, "top")
        numLbl.translation = [textX, numY]
        chRow.appendChild(numLbl)

        chScroll.appendChild(chRow)

        progRow = CreateObject("roSGNode", "Group")
        progRow.translation = [0, rowY]

        rowLine = CreateObject("roSGNode", "Rectangle")
        rowLine.translation = [0, rowH - 1]
        rowLine.width = ((m.displayTimelineEnd - m.displayTimelineStart) / (60& * 1000&)) * ppm
        rowLine.height = 1
        rowLine.color = LT_ColorBorderWhite5()
        progRow.appendChild(rowLine)

        if channel.programs <> invalid then
            for pIdx = 0 to channel.programs.Count() - 1
                prog = channel.programs[pIdx]
                if prog = invalid then continue for
                if prog.endTime <= m.displayTimelineStart then continue for
                if prog.startTime >= m.displayTimelineEnd then exit for

                left = Int(((prog.startTime - m.displayTimelineStart) / (60& * 1000&)) * ppm)
                width = Int(((prog.endTime - prog.startTime) / (60& * 1000&)) * ppm)
                if width < 48 then width = 48
                if left + width < winLeft then continue for
                if left > winRight then continue for

                pFocused = absIdx = m.channelIndex and pIdx = m.programIndex and m.focusZone = "program"
                pbg = LT_ColorProgramBg()
                if pFocused then pbg = LT_ColorFocusBg()

                card = CreateObject("roSGNode", "Group")
                card.translation = [left, 0]

                if pFocused then
                    sh = CreateObject("roSGNode", "Rectangle")
                    sh.translation = [0, 0]
                    sh.width = width
                    sh.height = rowH
                    sh.color = LT_ColorFocusShadow()
                    sh.opacity = 0.35
                    card.appendChild(sh)
                end if

                block = CreateObject("roSGNode", "Rectangle")
                block.width = width
                block.height = rowH
                block.color = pbg
                card.appendChild(block)

                edgePx = LT_ProgramEdgePx()
                edgeColor = LT_ColorBorderWhite5()
                if pFocused then edgeColor = LT_ColorFocusAccent()

                divR = CreateObject("roSGNode", "Rectangle")
                divR.translation = [width - edgePx, 0]
                divR.width = edgePx
                divR.height = rowH
                divR.color = edgeColor
                card.appendChild(divR)

                divB = CreateObject("roSGNode", "Rectangle")
                divB.translation = [0, rowH - edgePx]
                divB.width = width
                divB.height = edgePx
                divB.color = edgeColor
                card.appendChild(divB)

                if width >= 64 then
                    timeColor = LT_ColorGray400()
                    if pFocused then timeColor = LT_ColorFocusAccent()
                    tLbl = LT_MakeLabel(LT_FormatTime(prog.startTime), "pkg:/fonts/Inter-Medium.ttf", LT_FsProgramTime(), timeColor, width - pad * 2, LT_FsProgramTime() + 2, "left", false, "top")
                    tLbl.translation = [pad, pad]
                    card.appendChild(tLbl)

                    titleLbl = LT_MakeLabel(prog.title, "pkg:/fonts/Inter-SemiBold.ttf", LT_FsProgramTitle(), LT_ColorWhite(), width - pad * 2, LT_FsProgramTitle() + 4, "left", false, "top")
                    titleLbl.translation = [pad, pad + 18]
                    card.appendChild(titleLbl)

                    dLbl = LT_MakeLabel(LT_FormatDuration(prog.startTime, prog.endTime), "pkg:/fonts/Inter-Medium.ttf", LT_FsProgramDuration(), LT_ColorGray500(), width - pad * 2, LT_FsProgramDuration() + 2, "left", false, "top")
                    dLbl.translation = [pad, rowH - pad - LT_FsProgramDuration() - 2]
                    card.appendChild(dLbl)
                end if

                progRow.appendChild(card)
            end for
        end if

        progScroll.appendChild(progRow)
    end for
end sub

sub UpdateLiveLine()
    chW = LT_ChannelColWidth()
    gridTop = LT_TimelineHeight()
    if m.currentTime < m.displayTimelineStart or m.currentTime > m.displayTimelineEnd then
        if m.liveLine <> invalid then m.liveLine.visible = false
        if m.liveDotHost <> invalid then m.liveDotHost.visible = false
        return
    end if
    ppm = LT_PixelsPerMinute()
    nowX = Int(((m.currentTime - m.displayTimelineStart) / (60& * 1000&)) * ppm)
    if m.liveLine <> invalid then
        m.liveLine.translation = [Int(nowX - m.scrollLeft), 0]
        m.liveLine.visible = true
    end if
    if m.liveDotHost <> invalid then
        m.liveDotHost.translation = [Int(chW + nowX - m.scrollLeft - 5), gridTop - 10]
        m.liveDotHost.visible = true
    end if
end sub

sub UpdateFocusChrome()
  playFocused = m.focusZone = "hero" and m.heroBtnIndex = 0
  begFocused = m.focusZone = "hero" and m.heroBtnIndex = 1

  if m.playNowRing <> invalid then m.playNowRing.visible = playFocused
  if m.playNowBg <> invalid then m.playNowBg.blendColor = LT_ColorFocusAccent()

  if m.playBeginningRing <> invalid then m.playBeginningRing.visible = begFocused
  if m.playBeginningFill <> invalid then
    if begFocused then
      m.playBeginningFill.blendColor = LT_ColorBtnFocusBgWhite10()
      m.playBeginningFill.visible = true
    else
      m.playBeginningFill.visible = false
    end if
  end if
  if m.playBeginningBorder <> invalid then
    if begFocused then
      m.playBeginningBorder.uri = LT_PillOutlineFocusUri()
    else
      m.playBeginningBorder.uri = LT_PillOutlineUri()
    end if
  end if
  if m.playBeginningIcon <> invalid then
    if begFocused then
      m.playBeginningIcon.uri = LT_PlayIconStrokeWhiteUri()
    else
      m.playBeginningIcon.uri = LT_PlayIconStrokeUri()
    end if
  end if
  if m.playBeginningLbl <> invalid then
    if begFocused then
      m.playBeginningLbl.color = LT_ColorWhite()
    else
      m.playBeginningLbl.color = LT_ColorGray300()
    end if
  end if
end sub

sub CenterScrollForFocus()
    if m.channels.Count() = 0 then return
    ch = m.channels[m.channelIndex]
    if ch = invalid or ch.programs = invalid then return
    if m.programIndex < 0 or m.programIndex >= ch.programs.Count() then return
    prog = ch.programs[m.programIndex]
    if prog = invalid then return

    ppm = LT_PixelsPerMinute()
    rowH = LT_RowHeight()
    clipH = LT_GridClipHeight()
    gridW = m.viewportW - LT_ChannelColWidth()
    margin = LT_ScrollMarginX()

    cardLeft = Int(((prog.startTime - m.displayTimelineStart) / (60& * 1000&)) * ppm)
    cardWidth = Int(((prog.endTime - prog.startTime) / (60& * 1000&)) * ppm)
    relLeft = cardLeft - m.scrollLeft
    relRight = relLeft + cardWidth
    if relLeft < margin or relRight > gridW - margin then
        m.scrollLeft = cardLeft - margin
        if m.scrollLeft < 0 then m.scrollLeft = 0
    end if

    rowTop = m.channelIndex * rowH
    targetTop = rowTop - Int(clipH / 2) + Int(rowH / 2)
    if targetTop < 0 then targetTop = 0
    maxTop = m.channels.Count() * rowH - clipH
    if maxTop < 0 then maxTop = 0
    if targetTop > maxTop then targetTop = maxTop
    m.scrollTop = targetTop
end sub

sub EnterLiveTvHeader()
    if m.vm = invalid then return
    menuItems = m.vm.menuItems
    if menuItems = invalid or menuItems.Count() = 0 then
        flags = HeaderMenuFeatureFlags(m.top)
        menuItems = HeaderMenuItems(flags.reels, flags.epg)
    end if
    idx = HeaderSelectedIndexForNav(menuItems, RouteLiveTv(), invalid)
    ShellEnterHeader(m.vm, idx)
end sub

sub PlayFocusedChannel()
    if m.vm = invalid or m.selectedChannel = invalid then return
    state = LiveTvVideoPlayerPayload(m.selectedChannel)
    if state = invalid then
        ShowAlert(m.top, 2, "Unable to start live stream.")
        return
    end if
    m.vm.callFunc("NavigatePush", RouteVideoPlayer(), state)
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid then return
    key = ""
    if ev.key <> invalid then key = ev.key
    if key = "" then return

    if key = "back" then
        if m.vm <> invalid then m.vm.callFunc("NavigateBack", "", invalid)
        return
    end if

    if key = "OK" or key = "select" then
        PlayFocusedChannel()
        return
    end if

    if key = "up" then
        HandleUp()
        return
    end if
    if key = "down" then
        HandleDown()
        return
    end if
    if key = "left" then
        HandleLeft()
        return
    end if
    if key = "right" then
        HandleRight()
        return
    end if
end sub

sub HandleUp()
    if m.focusZone = "hero" then
        if NavUpOpensHeaderFromContent() then EnterLiveTvHeader()
        return
    end if
    if m.focusZone = "program" and m.channelIndex = 0 then
        m.focusZone = "hero"
        m.heroBtnIndex = 0
        RenderAll()
        return
    end if
    if m.focusZone = "program" then
        MoveProgramVertical(-1)
        return
    end if
    if m.focusZone = "channel" then
        if m.channelIndex > 0 then
            m.channelIndex = m.channelIndex - 1
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
            return
        end if
        m.focusZone = "hero"
        m.heroBtnIndex = 0
        RenderAll()
    end if
end sub

sub HandleDown()
    if m.focusZone = "hero" then
        m.focusZone = "program"
        CenterScrollForFocus()
        RenderAll()
        return
    end if
    if m.focusZone = "channel" then
        if m.channelIndex < m.channels.Count() - 1 then
            m.channelIndex = m.channelIndex + 1
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "program" then
        MoveProgramVertical(1)
    end if
end sub

sub MoveProgramVertical(dir as integer)
    if m.channels.Count() = 0 then return
    target = m.channelIndex + dir
    if target < 0 or target >= m.channels.Count() then return
    ref = m.selectedProgram
    if ref = invalid then return
    ch = m.channels[target]
    if ch = invalid then return
    m.channelIndex = target
    m.programIndex = LT_FindProgramOverlapping(ch, ref.startTime, ref.endTime)
    SyncSelectedProgram()
    CenterScrollForFocus()
    RenderAll()
end sub

sub HandleLeft()
    if m.focusZone = "hero" then
        if m.heroBtnIndex > 0 then m.heroBtnIndex = m.heroBtnIndex - 1
        UpdateFocusChrome()
        return
    end if
    if m.focusZone = "program" then
        ch = m.channels[m.channelIndex]
        prog = m.selectedProgram
        if ch = invalid or prog = invalid then return
        if LT_IsFirstVisibleProgramAtScroll(ch, prog, m.displayTimelineStart, m.scrollLeft, LT_PixelsPerMinute()) then
            m.focusZone = "channel"
            print "[LIVETV_DBG] focus program->channel row="; m.channelIndex; " prog="; m.programIndex
            RenderAll()
            return
        end if
        nIdx = LT_FindProgramLeftNeighbor(ch, prog)
        if nIdx >= 0 then
            m.programIndex = nIdx
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "channel" then
        if NavLeftOpensSidebarFromContent(true) then
            print "[LIVETV_DBG] focus channel->sidebar row="; m.channelIndex
            EnterLiveTvHeader()
            return
        end if
        m.scrollLeft = m.scrollLeft - (30 * LT_PixelsPerMinute())
        if m.scrollLeft < 0 then m.scrollLeft = 0
        print "[LIVETV_DBG] channel scrollLeft="; m.scrollLeft
        RenderAll()
    end if
end sub

sub HandleRight()
    if m.focusZone = "hero" then
        if m.heroBtnIndex < 1 then m.heroBtnIndex = m.heroBtnIndex + 1
        UpdateFocusChrome()
        return
    end if
    if m.focusZone = "channel" then
        ch = m.channels[m.channelIndex]
        if ch <> invalid and ch.programs <> invalid and ch.programs.Count() > 0 then
            m.focusZone = "program"
            if m.programIndex < 0 or m.programIndex >= ch.programs.Count() then
                m.programIndex = LT_FindProgramIndexAtTime(ch, m.currentTime)
            end if
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "program" then
        ch = m.channels[m.channelIndex]
        prog = m.selectedProgram
        if ch = invalid or prog = invalid then return
        nIdx = LT_FindProgramRightNeighbor(ch, prog)
        if nIdx >= 0 then
            m.programIndex = nIdx
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
    end if
end sub

sub OnDispose()
    m.disposed = true
    if m.nowTimer <> invalid then m.nowTimer.control = "stop"
    if m.initialFocusTimer <> invalid then m.initialFocusTimer.control = "stop"
    if m.backdropSwapTimer <> invalid then m.backdropSwapTimer.control = "stop"
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
end sub
