' LiveTvService.brs — helpers for Live TV screen + player nav (parity livetv/index.tsx).

function LT_FormatTime(ms as longinteger) as string
    if ms <= 0 then return ""
    dt = CreateObject("roDateTime")
    dt.FromSeconds(Int(ms / 1000&))
    dt.ToLocalTime()
    hours = dt.GetHours()
    minutes = dt.GetMinutes()
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
    dt = CreateObject("roDateTime")
    dt.FromSeconds(Int(ms / 1000&))
    dt.ToLocalTime()
    hours = dt.GetHours()
    minutes = dt.GetMinutes()
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
