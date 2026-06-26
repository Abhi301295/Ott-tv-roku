' VideoService.brs — pure helpers for the video player (parity with
' src/features/contentdetail/video/index.tsx + services/action.ts updateVideoProgress).
' Kept side-effect free so the screen stays a thin controller and this is unit-reasoned.

' Stream URL from the play payload (detail.playList.hls.url).
function VideoStreamUrl(detail as object) as string
    if detail = invalid then return ""
    raw = ""
    if detail.playList <> invalid and detail.playList.hls <> invalid then
        if detail.playList.hls.url <> invalid then raw = detail.playList.hls.url
    end if
    if raw = "" and detail.videoUrl <> invalid then raw = detail.videoUrl
    if raw = "" then return ""
    return MediaStreamUrl(raw)
end function

' Roku streamFormat from the URL extension (parity with the web isHls check:
' m3u8/ts/fmp4/mpd → hls, otherwise mp4).
function VideoStreamFormat(url as string) as string
    if url = "" then return "mp4"
    bare = url
    q = Instr(1, bare, "?")
    if q > 0 then bare = Left(bare, q - 1)
    lc = LCase(bare)
    if Instr(1, lc, ".m3u8") > 0 then return "hls"
    if Instr(1, lc, ".mpd") > 0 then return "dash"
    if Instr(1, lc, ".ts") > 0 then return "hls"
    if Instr(1, lc, ".fmp4") > 0 then return "hls"
    return "mp4"
end function

' Resume position in seconds: 0 when Start Over, else continueWatching[0].progress.
function VideoResumeSeconds(detail as object, startOver as boolean) as integer
    if startOver then return 0
    if detail = invalid then return 0
    cw = detail.continueWatching
    if cw = invalid or cw.Count() = 0 then return 0
    first = cw[0]
    if first = invalid or first.progress = invalid then return 0
    return CInt(VideoToNumber(first.progress))
end function

' Intro window (skipStart..skipEnd). Skip Intro shows while position is inside it.
function VideoIntroStart(detail as object) as integer
    if detail = invalid or detail.skipStart = invalid then return 0
    return CInt(VideoToNumber(detail.skipStart))
end function

function VideoIntroEnd(detail as object) as integer
    if detail = invalid or detail.skipEnd = invalid then return 0
    return CInt(VideoToNumber(detail.skipEnd))
end function

' Binge trigger seconds-before-end (binge || nextEpisodeTriggerTime || nextContentTriggerTime || 10).
function VideoBingeTrigger(detail as object) as integer
    if detail <> invalid then
        if detail.binge <> invalid and VideoToNumber(detail.binge) > 0 then return CInt(VideoToNumber(detail.binge))
        if detail.nextEpisodeTriggerTime <> invalid and VideoToNumber(detail.nextEpisodeTriggerTime) > 0 then return CInt(VideoToNumber(detail.nextEpisodeTriggerTime))
        if detail.nextContentTriggerTime <> invalid and VideoToNumber(detail.nextContentTriggerTime) > 0 then return CInt(VideoToNumber(detail.nextContentTriggerTime))
    end if
    return 10
end function

' The next playable item (nextVideoList[currentIndex+1]); suppressed for trailers.
function VideoNextItem(nextList as object, currentIndex as integer, isTrailer as boolean) as object
    if isTrailer then return invalid
    if nextList = invalid then return invalid
    nextIdx = currentIndex + 1
    if nextIdx < 0 or nextIdx >= nextList.Count() then return invalid
    return nextList[nextIdx]
end function

' videoId used for the progress endpoint (videoId ?? _id).
function VideoProgressId(detail as object) as string
    if detail = invalid then return ""
    if detail.videoId <> invalid and detail.videoId <> "" then return detail.videoId
    if detail._id <> invalid then return detail._id
    return ""
end function

' POST path + body for updateVideoProgress: /videos/{videoId}/progress
' body { content, progress, totalDuration } (parity with action.ts).
function VideoProgressPath(videoId as string) as string
    return Endpoints().DETAIL.UPDATE_VIDEO_PROGRESS + videoId + "/progress"
end function

function VideoProgressBody(contentId as string, progressSecs as integer, totalSecs as integer) as object
    return {
        content: contentId
        progress: progressSecs
        totalDuration: totalSecs
    }
end function

function VideoIsTrailer(detail as object) as boolean
    if detail = invalid then return false
    return detail.isTrailer = true
end function

' Reels play inline on web with no updateVideoProgress — only detail player posts progress.
function VideoIsReel(detail as object) as boolean
    if detail = invalid then return false
    return detail.isReel = true
end function

' Subtitle tracks for the ContentNode
' detail.subtitles[].{lang|value|language, path|url}). Returns [] when none.
function VideoSubtitleTracks(detail as object) as object
    out = []
    if detail = invalid or detail.subtitles = invalid then return out
    for each s in detail.subtitles
        if s <> invalid then
            lang = ""
            if s.lang <> invalid and s.lang <> "" then
                lang = s.lang
            else if s.language <> invalid and s.language <> "" then
                lang = s.language
            else if s.value <> invalid and s.value <> "" then
                lang = s.value
            end if
            path = ""
            if s.path <> invalid and s.path <> "" then path = s.path
            if path = "" and s.url <> invalid and s.url <> "" then path = s.url
            if lang <> "" and path <> "" then
                out.Push({ lang: lang, url: path })
            end if
        end if
    end for
    return out
end function

' hh:mm:ss (parity with formatTime; placeholder when unknown).
function VideoFormatTime(t as dynamic) as string
    n = VideoToNumber(t)
    if n = invalid or n < 0 then return "00:--:--"
    total = CInt(n)
    h = total \ 3600
    m = (total mod 3600) \ 60
    s = total mod 60
    return VideoPad2(h) + ":" + VideoPad2(m) + ":" + VideoPad2(s)
end function

function VideoPad2(n as integer) as string
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' Tolerant numeric coercion (handles string/int/float/invalid from JSON).
function VideoToNumber(v as dynamic) as float
    if v = invalid then return 0.0
    t = type(v)
    if t = "roString" or t = "String" then
        if v = "" then return 0.0
        return Val(v)
    end if
    ' Cover both unboxed names (Integer/Float/Double/LongInteger) and boxed/JSON-parsed
    ' names. brs ParseJson yields "roInteger" for whole numbers (confirmed via telnet:
    ' progress 22 -> type=roInteger), which the old list missed and so returned 0.
    if t = "roInt" or t = "Integer" or t = "roInteger" or t = "roFloat" or t = "Float" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger" then
        return v
    end if
    return 0.0
end function

' Skip Intro pill — literal parity with video/index.tsx className:
' text-neutral-50 (dark.theme --neutral-50 = #ffffff), ring-white/70 when focused.
function VideoSkipIntroTextColor() as string
    return "0xffffffff"
end function

' Loose lang match (en / eng / English) for subtitle track selection.
function VideoCaptionLangMatches(selected as string, candidate as string) as boolean
    if selected = "" or candidate = "" then return false
    s = LCase(selected)
    c = LCase(candidate)
    if s = c then return true
    if Left(s, 2) = Left(c, 2) and Len(s) >= 2 and Len(c) >= 2 then return true
  ' ISO 639-1 vs 639-2 (en vs eng).
    if s = "en" and Left(c, 3) = "eng" then return true
    if c = "en" and Left(s, 3) = "eng" then return true
    return false
end function
