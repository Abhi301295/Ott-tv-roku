' LiveTvScreen.brs — parity with src/features/livetv/index.tsx (mock EPG).

sub init()
    m.bg = m.top.findNode("bg")
    m.contentHost = m.top.findNode("contentHost")
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.heroMeta = m.top.findNode("heroMeta")
    m.spotlightLbl = m.top.findNode("spotlightLbl")
    m.titleLbl = m.top.findNode("titleLbl")
    m.timeLbl = m.top.findNode("timeLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.playNowBtn = m.top.findNode("playNowBtn")
    m.playNowBg = m.top.findNode("playNowBg")
    m.playBeginningBtn = m.top.findNode("playBeginningBtn")
    m.playBeginningBg = m.top.findNode("playBeginningBg")
    m.playBeginningBorder = m.top.findNode("playBeginningBorder")
    m.timelineHost = m.top.findNode("timelineHost")
    m.rowsHost = m.top.findNode("rowsHost")
    m.liveLine = m.top.findNode("liveLine")
    m.nowTimer = m.top.findNode("nowTimer")

    m.vm = FindViewManager(m.top)
    m.channels = []
    m.timelineStart = 0&
    m.timelineEnd = 0&
    m.currentTime = 0&
    m.channelIndex = 0
    m.programIndex = 0
    m.focusZone = "channel"
    m.heroBtnIndex = 0
    m.scrollLeft = 0
    m.scrollTop = 0
    m.shellOffX = 0
    m.disposed = false
    m.selectedChannel = invalid
    m.selectedProgram = invalid

    ApplyShellLayout()
    LoadEpgData()
    UpdateNowTime()
    RenderAll()

    if m.nowTimer <> invalid then
        m.nowTimer.duration = LT_NowTickMs() / 1000.0
        m.nowTimer.observeField("fire", "OnNowTimer")
        m.nowTimer.control = "start"
    end if
    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
    ' Route mount only; mock EPG is generated locally.
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

sub ApplyShellLayout()
    header = FindAppHeader(m.top)
    offX = ShellContentOffsetX(header)
    m.shellOffX = offX
    if m.contentHost <> invalid then m.contentHost.translation = [offX, 0]
end sub

sub LoadEpgData()
    data = LT_GenerateEPGData()
    if data = invalid then return
    if data.channels <> invalid then m.channels = data.channels
    if data.timelineStart <> invalid then m.timelineStart = data.timelineStart
    if data.timelineEnd <> invalid then m.timelineEnd = data.timelineEnd
    if m.channels.Count() > 0 then
        m.channelIndex = 0
        m.programIndex = LT_FindProgramIndexAtTime(m.channels[0], m.currentTime)
        SyncSelectedProgram()
    end if
    print "[LIVETV_DBG] load_epg channels=" + Str(m.channels.Count()).Trim() + " timelineStart=" + Str(m.timelineStart).Trim()
end sub

sub UpdateNowTime()
    dt = CreateObject("roDateTime")
    dt.Mark()
    m.currentTime = dt.AsSeconds() * 1000&
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
    if m.heroBackdrop <> invalid then m.heroBackdrop.uri = url
    if m.spotlightLbl <> invalid then m.spotlightLbl.text = ch.name + " Spotlight"
    if m.titleLbl <> invalid then m.titleLbl.text = prog.title
    if m.timeLbl <> invalid then
        m.timeLbl.text = LT_FormatTime(prog.startTime) + " - " + LT_FormatTime(prog.endTime)
    end if
    if m.descLbl <> invalid then m.descLbl.text = prog.description
end sub

sub RenderTimeline()
    if m.timelineHost = invalid then return
    m.timelineHost.removeChildrenIndex(m.timelineHost.getChildCount(), 0)
    ppm = LT_PixelsPerMinute()
    marker = m.timelineStart
    x = 0
    while marker <= m.timelineEnd
        lbl = CreateObject("roSGNode", "Label")
        lbl.text = LT_FormatTimelineTime(marker)
        lbl.translation = [x - m.scrollLeft, 12]
        lbl.width = 80
        lbl.height = 24
        lbl.color = LT_ColorZinc400()
        font = CreateObject("roSGNode", "Font")
        font.uri = "pkg:/fonts/Inter-Medium.ttf"
        font.size = 16
        lbl.appendChild(font)
        m.timelineHost.appendChild(lbl)
        marker = marker + (30& * 60& * 1000&)
        x = x + (30 * ppm)
    end while
end sub

sub RenderRows()
    if m.rowsHost = invalid then return
    m.rowsHost.removeChildrenIndex(m.rowsHost.getChildCount(), 0)
    if m.channels.Count() = 0 then return

    rowH = LT_RowHeight()
    chW = LT_ChannelColWidth()
    ppm = LT_PixelsPerMinute()
    buffer = LT_BufferRows()
    viewH = LT_ViewportHeight()

    startIdx = m.channelIndex - 3
    floorIdx = Int(m.scrollTop / rowH) - buffer
    if floorIdx > startIdx then startIdx = floorIdx
    if startIdx < 0 then startIdx = 0

    endIdx = m.channelIndex + 4
    ceilIdx = Int((m.scrollTop + viewH) / rowH) + buffer
    if ceilIdx > endIdx then endIdx = ceilIdx
    if endIdx > m.channels.Count() then endIdx = m.channels.Count()

    gridW = 1920 - chW

    for absIdx = startIdx to endIdx - 1
        channel = m.channels[absIdx]
        if channel = invalid then continue for
        rowY = absIdx * rowH - m.scrollTop
        row = CreateObject("roSGNode", "Group")
        row.translation = [0, rowY]

        chFocused = (m.focusZone = "channel" or m.focusZone = "program") and absIdx = m.channelIndex
        cellBg = LT_ColorChannelBg()
        if chFocused and m.focusZone = "channel" then cellBg = LT_ColorFocusBg()

        cell = CreateObject("roSGNode", "Rectangle")
        cell.width = chW
        cell.height = rowH
        cell.color = cellBg
        row.appendChild(cell)

        if chFocused and m.focusZone = "channel" then
            accent = CreateObject("roSGNode", "Rectangle")
            accent.width = 3
            accent.height = rowH
            accent.color = LT_ColorFocusAccent()
            row.appendChild(accent)
        end if

        nameLbl = CreateObject("roSGNode", "Label")
        dispName = channel.name
        nm = LCase(channel.name)
        if nm = "hbo" or nm = "espn" or nm = "discovery" or Instr(1, nm, "national") > 0 then dispName = "Channel"
        nameLbl.text = dispName
        nameLbl.translation = [72, 24]
        nameLbl.width = chW - 80
        nameLbl.height = 28
        nameLbl.color = LT_ColorGray300()
        if chFocused then nameLbl.color = LT_ColorWhite()
        nf = CreateObject("roSGNode", "Font")
        nf.uri = "pkg:/fonts/Inter-SemiBold.ttf"
        nf.size = 18
        nameLbl.appendChild(nf)
        row.appendChild(nameLbl)

        numLbl = CreateObject("roSGNode", "Label")
        numLbl.text = channel.channelNumber
        numLbl.translation = [72, 52]
        numLbl.width = chW - 80
        numLbl.height = 24
        numLbl.color = LT_ColorZinc400()
        numf = CreateObject("roSGNode", "Font")
        numf.uri = "pkg:/fonts/Inter-Medium.ttf"
        numf.size = 16
        numLbl.appendChild(numf)
        row.appendChild(numLbl)

        progHost = CreateObject("roSGNode", "Group")
        progHost.translation = [chW, 0]
        progHost.clippingRect = [0, 0, gridW, rowH]

        if channel.programs <> invalid then
            for pIdx = 0 to channel.programs.Count() - 1
                prog = channel.programs[pIdx]
                if prog = invalid then continue for
                if prog.endTime <= m.timelineStart then continue for
                if prog.startTime >= m.timelineEnd then exit for

                left = Int(((prog.startTime - m.timelineStart) / (60& * 1000&)) * ppm) - m.scrollLeft
                width = Int(((prog.endTime - prog.startTime) / (60& * 1000&)) * ppm)
                if width < 40 then width = 40
                if left + width < 0 then continue for
                if left > gridW then continue for

                pFocused = absIdx = m.channelIndex and pIdx = m.programIndex and m.focusZone = "program"
                pbg = LT_ColorProgramBg()
                if pFocused then pbg = LT_ColorFocusBg()

                block = CreateObject("roSGNode", "Rectangle")
                block.translation = [left, 0]
                block.width = width
                block.height = rowH
                block.color = pbg
                progHost.appendChild(block)

                if pFocused then
                    border = CreateObject("roSGNode", "Rectangle")
                    border.translation = [left, 0]
                    border.width = 3
                    border.height = rowH
                    border.color = LT_ColorFocusAccent()
                    progHost.appendChild(border)
                end if

                if width >= 80 then
                    tLbl = CreateObject("roSGNode", "Label")
                    tLbl.text = prog.title
                    tLbl.translation = [left + 12, 16]
                    tLbl.width = width - 24
                    tLbl.height = 28
                    tLbl.color = LT_ColorGray300()
                    if pFocused then tLbl.color = LT_ColorWhite()
                    tf = CreateObject("roSGNode", "Font")
                    tf.uri = "pkg:/fonts/Inter-SemiBold.ttf"
                    tf.size = 16
                    tLbl.appendChild(tf)
                    progHost.appendChild(tLbl)

                    dLbl = CreateObject("roSGNode", "Label")
                    dLbl.text = LT_FormatDuration(prog.startTime, prog.endTime)
                    dLbl.translation = [left + 12, 48]
                    dLbl.width = width - 24
                    dLbl.height = 20
                    dLbl.color = LT_ColorZinc400()
                    df = CreateObject("roSGNode", "Font")
                    df.uri = "pkg:/fonts/Inter-Regular.ttf"
                    df.size = 14
                    dLbl.appendChild(df)
                    progHost.appendChild(dLbl)
                end if
            end for
        end if

        row.appendChild(progHost)
        m.rowsHost.appendChild(row)
    end for
end sub

sub UpdateLiveLine()
    if m.liveLine = invalid then return
    if m.currentTime < m.timelineStart or m.currentTime > m.timelineEnd then
        m.liveLine.visible = false
        return
    end if
    ppm = LT_PixelsPerMinute()
    left = LT_ChannelColWidth() + Int(((m.currentTime - m.timelineStart) / (60& * 1000&)) * ppm) - m.scrollLeft
    m.liveLine.translation = [left, 0]
    m.liveLine.visible = true
end sub

sub UpdateFocusChrome()
    if m.playNowBg = invalid or m.playBeginningBg = invalid then return
    if m.focusZone = "hero" and m.heroBtnIndex = 0 then
        m.playNowBg.color = LT_ColorFocusAccent()
        m.playBeginningBg.color = HexToRokuColor("#ffffff", "1a")
    else
        m.playNowBg.color = LT_ColorFocusAccent()
        m.playBeginningBg.color = "0x00000000"
    end if
    if m.focusZone = "hero" and m.heroBtnIndex = 1 then
        m.playBeginningBg.color = HexToRokuColor("#ffffff", "1a")
        if m.playBeginningBorder <> invalid then m.playBeginningBorder.color = HexToRokuColor("#ffffff", "ff")
    else if m.playBeginningBorder <> invalid then
        m.playBeginningBorder.color = HexToRokuColor("#ffffff", "66")
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
    viewH = LT_ViewportHeight()
    gridW = 1920 - LT_ChannelColWidth()

    cardLeft = Int(((prog.startTime - m.timelineStart) / (60& * 1000&)) * ppm)
    cardWidth = Int(((prog.endTime - prog.startTime) / (60& * 1000&)) * ppm)
    relLeft = cardLeft - m.scrollLeft
    relRight = relLeft + cardWidth
    if relLeft < 150 or relRight > gridW - 150 then
        m.scrollLeft = cardLeft - 150
        if m.scrollLeft < 0 then m.scrollLeft = 0
    end if

    rowTop = m.channelIndex * rowH
    targetTop = rowTop - Int(viewH / 2) + Int(rowH / 2)
    if targetTop < 0 then targetTop = 0
    maxTop = m.channels.Count() * rowH - viewH
    if maxTop < 0 then maxTop = 0
    if targetTop > maxTop then targetTop = maxTop
    m.scrollTop = targetTop
end sub

sub PlayFocusedChannel()
    if m.vm = invalid or m.selectedChannel = invalid then return
    state = LiveTvVideoPlayerPayload(m.selectedChannel)
    if state = invalid then
        ShowAlert(m.top, 2, "Unable to start live stream.")
        return
    end if
    print "[LIVETV_DBG] play channel=" + m.selectedChannel.name + " id=" + state.contentId
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
        if m.focusZone = "hero" then
            PlayFocusedChannel()
        else
            PlayFocusedChannel()
        end if
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
    if m.focusZone = "hero" then return
    if m.focusZone = "program" then
        m.focusZone = "channel"
        CenterScrollForFocus()
        RenderAll()
        return
    end if
    if m.channelIndex > 0 then
        m.channelIndex = m.channelIndex - 1
        ch = m.channels[m.channelIndex]
        ref = m.selectedProgram
        if ref <> invalid and ch <> invalid then
            m.programIndex = LT_FindProgramOverlapping(ch, ref.startTime, ref.endTime)
        end if
        SyncSelectedProgram()
        CenterScrollForFocus()
        RenderAll()
        return
    end if
    m.focusZone = "hero"
    m.heroBtnIndex = 0
    RenderAll()
end sub

sub HandleDown()
    if m.focusZone = "hero" then
        m.focusZone = "channel"
        RenderAll()
        return
    end if
    if m.focusZone = "channel" then
        if m.channelIndex < m.channels.Count() - 1 then
            m.channelIndex = m.channelIndex + 1
            ch = m.channels[m.channelIndex]
            ref = m.selectedProgram
            if ref <> invalid and ch <> invalid then
                m.programIndex = LT_FindProgramOverlapping(ch, ref.startTime, ref.endTime)
            end if
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "program" and m.channelIndex < m.channels.Count() - 1 then
        m.channelIndex = m.channelIndex + 1
        ch = m.channels[m.channelIndex]
        ref = m.selectedProgram
        if ref <> invalid and ch <> invalid then
            m.programIndex = LT_FindProgramOverlapping(ch, ref.startTime, ref.endTime)
        end if
        SyncSelectedProgram()
        CenterScrollForFocus()
        RenderAll()
    end if
end sub

sub HandleLeft()
    if m.focusZone = "hero" then
        if m.heroBtnIndex > 0 then m.heroBtnIndex = m.heroBtnIndex - 1
        UpdateFocusChrome()
        return
    end if
    if m.focusZone = "program" then
        if m.programIndex > 0 then
            m.programIndex = m.programIndex - 1
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        else
            m.focusZone = "channel"
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "channel" then
        m.scrollLeft = m.scrollLeft - (30 * LT_PixelsPerMinute())
        if m.scrollLeft < 0 then m.scrollLeft = 0
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
            m.programIndex = LT_FindProgramIndexAtTime(ch, m.currentTime)
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
        return
    end if
    if m.focusZone = "program" then
        ch = m.channels[m.channelIndex]
        if ch = invalid or ch.programs = invalid then return
        if m.programIndex < ch.programs.Count() - 1 then
            m.programIndex = m.programIndex + 1
            SyncSelectedProgram()
            CenterScrollForFocus()
            RenderAll()
        end if
    end if
end sub

sub OnDispose()
    m.disposed = true
    if m.nowTimer <> invalid then m.nowTimer.control = "stop"
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")
end sub
