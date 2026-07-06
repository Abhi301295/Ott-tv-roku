' LiveTvService.brs — helpers for Live TV screen + player nav (parity livetv/index.tsx).

function LT_FormatTime(ms as longinteger) as string
    if ms <= 0 then return ""
    hours = LT_LocalHours(ms)
    minutes = LT_LocalMinutes(ms)
    ampm = "AM"
    if hours >= 12 then ampm = "PM"
    h12 = hours Mod 12
    if h12 = 0 then h12 = 12
    minStr = Str(minutes).Trim()
    if minutes < 10 then minStr = "0" + minStr
    return Str(h12).Trim() + ":" + minStr + " " + ampm
end function

function LT_FormatTimelineTime(ms as longinteger) as string
    if ms <= 0 then return ""
    hours = LT_LocalHours(ms)
    minutes = LT_LocalMinutes(ms)
    hStr = Str(hours).Trim()
    if hours < 10 then hStr = "0" + hStr
    mStr = Str(minutes).Trim()
    if minutes < 10 then mStr = "0" + mStr
    return hStr + ":" + mStr
end function

function LT_FormatDuration(startMs as longinteger, endMs as longinteger) as string
    diffMins = Int(((endMs - startMs) / (60& * 1000&)) + 0.5)
    if diffMins >= 60 then
        hrs = Int(diffMins / 60)
        mins = diffMins Mod 60
        if mins > 0 then return Str(hrs).Trim() + "hr " + Str(mins).Trim() + "m"
        return Str(hrs).Trim() + "hr"
    end if
    return Str(diffMins).Trim() + "m"
end function

function LT_BackdropUrl(channelName as string, programTitle as string, category as string) as string
    ch = LCase(channelName)
    title = LCase(programTitle)
    if Instr(1, ch, "hbo") > 0 or Instr(1, title, "jumanji") > 0 then
        return "https://images.unsplash.com/photo-1448375240586-882707db888b?q=80&w=1200&auto=format&fit=crop"
    end if
    if Instr(1, ch, "espn") > 0 then
        return "https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop"
    end if
    if Instr(1, ch, "discover") > 0 then
        return "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1200&auto=format&fit=crop"
    end if
    if Instr(1, ch, "national") > 0 or Instr(1, ch, "geo") > 0 then
        return "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?q=80&w=1200&auto=format&fit=crop"
    end if
    if category = "News" then
        return "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1200&auto=format&fit=crop"
    end if
    if category = "Sports" then
        return "https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop"
    end if
    if category = "Documentary" then
        return "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?q=80&w=1200&auto=format&fit=crop"
    end if
    if category = "Kids" then
        return "https://images.unsplash.com/photo-1472457897821-70d3819a0e24?q=80&w=1200&auto=format&fit=crop"
    end if
    if category = "Series" then
        return "https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?q=80&w=1200&auto=format&fit=crop"
    end if
    return "https://images.unsplash.com/photo-1448375240586-882707db888b?q=80&w=1200&auto=format&fit=crop"
end function

function LT_FindProgramIndexAtTime(channel as object, nowMs as longinteger) as integer
    if channel = invalid or channel.programs = invalid then return 0
    progs = channel.programs
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p <> invalid and nowMs >= p.startTime and nowMs < p.endTime then return i
    end for
    return 0
end function

sub LT_AppendRectBorder(parent as object, x as integer, y as integer, w as integer, h as integer, color as string, thick as integer)
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

' renderChannelLogo() — per-channel logo inside h-12 w-[70px] bg-white/5 box.
sub LT_AppendChannelLogo(parent as object, x as integer, y as integer, channelName as string)
    if parent = invalid then return
    boxW = LT_LogoBoxW()
    boxH = LT_LogoBoxH()
    nm = LCase(channelName)

    if Instr(1, nm, "hbo") > 0 then
        lbl = LT_MakeLabel("HBO", "pkg:/fonts/Inter-Bold.ttf", 24, LT_ColorWhite(), boxW, boxH, "center", false, "center")
        lbl.translation = [x, y]
        parent.appendChild(lbl)
        return
    end if

    if Instr(1, nm, "espn") > 0 then
        ' ⚠ Parity Note: React uses font-black italic; Roku uses Inter-Bold at red-500.
        lbl = LT_MakeLabel("ESPN", "pkg:/fonts/Inter-Bold.ttf", 24, LT_ColorRed500(), boxW, boxH, "center", false, "center")
        lbl.translation = [x, y]
        parent.appendChild(lbl)
        return
    end if

    if Instr(1, nm, "discover") > 0 then
        dotSz = 10
        gap = 4
        textFs = 14
        textW = 50
        contentW = dotSz + gap + textW
        startX = x + Int((boxW - contentW) / 2)
        dotY = y + Int((boxH - dotSz) / 2)
        dot = CreateObject("roSGNode", "Rectangle")
        dot.translation = [startX, dotY]
        dot.width = dotSz
        dot.height = dotSz
        dot.color = LT_ColorBlue400()
        parent.appendChild(dot)
        lbl = LT_MakeLabel("Discovery", "pkg:/fonts/Inter-Bold.ttf", textFs, LT_ColorWhite(), textW, boxH, "left", false, "center")
        lbl.translation = [startX + dotSz + gap, y]
        parent.appendChild(lbl)
        return
    end if

    if Instr(1, nm, "nature") > 0 or Instr(1, nm, "geo") > 0 or Instr(1, nm, "national") > 0 then
        frameW = 10
        frameH = 20
        gap = 6
        textFs = 10
        textW = 38
        contentW = frameW + gap + textW
        startX = x + Int((boxW - contentW) / 2)
        frameY = y + Int((boxH - frameH) / 2)
        LT_AppendRectBorder(parent, startX, frameY, frameW, frameH, LT_ColorYellow400(), 2)
        lbl = LT_MakeLabel("Nat Geo", "pkg:/fonts/Inter-Bold.ttf", textFs, LT_ColorWhite(), textW, boxH, "left", false, "center")
        lbl.translation = [startX + frameW + gap, y]
        parent.appendChild(lbl)
        return
    end if

    abbr = UCase(Left(channelName, 3))
    lbl = LT_MakeLabel(abbr, "pkg:/fonts/Inter-Bold.ttf", 14, LT_ColorGray300(), boxW, boxH, "center", false, "center")
    lbl.translation = [x, y]
    parent.appendChild(lbl)
end sub

function LT_MakeLabel(text as string, fontUri as string, fontSize as integer, color as string, width as integer, height as integer, hAlign as string, wrap as boolean, vAlign = "top" as string) as object
    lbl = CreateObject("roSGNode", "Label")
    lbl.text = text
    lbl.width = width
    lbl.height = height
    lbl.color = color
    lbl.horizAlign = hAlign
    lbl.vertAlign = vAlign
    lbl.wrap = wrap
    lbl.lineSpacing = 0
    f = CreateObject("roSGNode", "Font")
    f.uri = fontUri
    f.size = fontSize
    lbl.font = f
    return lbl
end function

function LT_VisiblePrograms(channel as object, timelineStart as longinteger, timelineEnd as longinteger) as object
    out = []
    if channel = invalid or channel.programs = invalid then return out
    for each prog in channel.programs
        if prog = invalid then continue for
        if prog.startTime < timelineEnd and prog.endTime > timelineStart then
            out.Push(prog)
        end if
    end for
    return out
end function

function LT_IsFirstVisibleProgram(channel as object, prog as object, timelineStart as longinteger, timelineEnd as longinteger) as boolean
    if channel = invalid or prog = invalid then return false
    visible = LT_VisiblePrograms(channel, timelineStart, timelineEnd)
    if visible.Count() = 0 then return false
    first = visible[0]
    if first = invalid then return false
    if first.id <> invalid and prog.id <> invalid then return first.id = prog.id
    return first.startTime = prog.startTime and first.endTime = prog.endTime
end function

function LT_FindProgramLeftNeighbor(channel as object, current as object) as integer
    if channel = invalid or channel.programs = invalid or current = invalid then return -1
    progs = channel.programs
    best = -1
    bestEnd = 0&
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p = invalid then continue for
        if p.endTime <= current.startTime and p.endTime > bestEnd then
            bestEnd = p.endTime
            best = i
        end if
    end for
    return best
end function

function LT_FindProgramRightNeighbor(channel as object, current as object) as integer
    if channel = invalid or channel.programs = invalid or current = invalid then return -1
    progs = channel.programs
    best = -1
    bestStart = 9223372036854775807&
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p = invalid then continue for
        if p.startTime >= current.endTime and p.startTime < bestStart then
            bestStart = p.startTime
            best = i
        end if
    end for
    return best
end function

function LT_FindProgramOverlapping(channel as object, startMs as longinteger, endMs as longinteger) as integer
    if channel = invalid or channel.programs = invalid then return 0
    progs = channel.programs
    best = 0
    minDist = 9223372036854775807&
    center = (startMs + endMs) / 2&
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p = invalid then continue for
        overlaps = (p.startTime < endMs) and (p.endTime > startMs)
        if overlaps then
            progCenter = (p.startTime + p.endTime) / 2&
            dist = progCenter - center
            if dist < 0 then dist = -dist
            if dist < minDist then
                minDist = dist
                best = i
            end if
        end if
    end for
    return best
end function

function LT_MockStreamUrl() as string
    return "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
end function

function LiveTvVideoPlayerPayload(channel as object) as object
    if channel = invalid then return invalid
    cid = ""
    if channel.id <> invalid then cid = channel.id
    cnum = ""
    if channel.channelNumber <> invalid then cnum = channel.channelNumber
    cname = ""
    if channel.name <> invalid then cname = channel.name
    detail = {
        _id: cid
        title: cname
        isLive: true
        playList: { hls: { url: LT_MockStreamUrl() } }
        continueWatching: []
    }
    return {
        type: "LIVE"
        contentId: cid
        title: cname
        channelNumber: cnum
        detail: detail
        startOver: true
        nextVideoList: []
        currentIndex: 0
    }
end function
