' VideoPlayback.brs — playback state math and ContentNode build (parity video/index.tsx).
' Pure helpers; VideoPlayerScreen owns nodes, timers, and Video node control.

function VP_PlaybackKey(state as object) as string
    if state = invalid then return ""
    if state.type <> invalid and state.type = "LIVE" then
        id = ""
        if state.contentId <> invalid and state.contentId <> "" then id = state.contentId
        if id = "" and state.detail <> invalid and state.detail._id <> invalid then id = state.detail._id
        return "live:" + id
    end if
    id = ""
    if state.contentId <> invalid and state.contentId <> "" then id = state.contentId
    if id = "" and state.detail <> invalid and state.detail._id <> invalid then id = state.detail._id
    so = "0"
    if state.startOver = true then so = "1"
    return id + ":so" + so
end function

' Build the playback ContentNode (url + resume + optional subtitle tracks).
' Sidecar VTT is deferred (includeSubtitles=false) until the user picks a caption —
' attaching tracks on initial load can make the Roku player fetch VTT and restart HLS.
function VP_BuildContent(url as string, startSecs as integer, includeSubtitles as boolean, detail as object) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = VideoStreamFormat(url)
    if detail <> invalid and detail.title <> invalid then content.title = detail.title
    pendingSeek = -1
    if startSecs > 0 then
        content.playStart = startSecs
        pendingSeek = startSecs
    end if
    if includeSubtitles and detail <> invalid then
        tracks = VideoSubtitleTracks(detail)
        if tracks.Count() > 0 then
            subs = []
            for each tk in tracks
                subs.Push({ Language: tk.lang, Description: tk.lang, TrackName: tk.url })
            end for
            content.subtitleTracks = subs
        end if
    end if
    return { content: content, pendingSeek: pendingSeek }
end function

' Apply a pending resume offset once the stream is playing. Devices honor playStart;
' when playStart is ignored the stream starts at 0 and we seek explicitly.
function VP_ShouldApplyPendingSeek(pendingSeek as integer, currentPos as float) as boolean
    if pendingSeek < 0 then return false
    if pendingSeek <= 2 then return false
    if currentPos = invalid then currentPos = 0
    return currentPos < pendingSeek - 3
end function

' Clamp a relative seek; never land on the exact end (strands player in finished limbo).
function VP_ClampSeekPosition(position as float, deltaSecs as integer, duration as float) as float
    target = position + deltaSecs
    if target < 0 then target = 0
    if duration > 0 and target > duration - 1 then target = duration - 1
    return target
end function

' Ended-state rewind target for the back-10 control.
function VP_EndedRewindTarget(duration as float, deltaSecs as integer) as float
    target = duration + deltaSecs
    if target < 0 then target = 0
    return target
end function

function VP_InIntroWindow(position as float, introStart as integer, introEnd as integer) as boolean
    return (introEnd > introStart) and (position >= introStart) and (position <= introEnd)
end function

function VP_SkipIntroPosition(introEnd as integer) as integer
    if introEnd <= 0 then return 0
    return introEnd + 1
end function

function VP_BingeShouldShow(nextItem as object, isTrailer as boolean, duration as float, position as float, bingeTrigger as integer) as boolean
    if nextItem = invalid then return false
    if isTrailer then return false
    if duration <= 0 then return false
    remaining = duration - position
    return remaining <= bingeTrigger
end function

function VP_BingeCountdownSeconds(duration as float, position as float) as integer
    remaining = duration - position
    cd = Int(remaining + 0.999)
    if cd < 0 then cd = 0
    return cd
end function

function VP_BingeShouldAdvance(remaining as float) as boolean
    return remaining <= 0
end function

function VP_ShouldPostProgress(isTrailer as boolean, isReel as boolean, isLive as boolean, position as float, videoId as string) as boolean
    if isTrailer then return false
    if isReel then return false
    if isLive then return false
    if videoId = "" then return false
    if position <= 0 then return false
    return true
end function

' HLS sim sometimes fires finished after the first segment while duration is still wrong.
function VP_IsSpuriousHlsFinish(alreadyIgnored as boolean, duration as float, position as float) as boolean
    if alreadyIgnored then return false
    if duration <= 0 then return false
    if duration >= 30 then return false
    return position >= duration - 1
end function
