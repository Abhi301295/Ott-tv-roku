' SeriesEpisodesService.brs — season/episode helpers for the Series Episodes screen
' (parity with features/contentdetail/season/seriesEpisode.tsx + seasonTabs.tsx + seriesRow.tsx).

' Numeric season value (season can be Int, Float, or String like "2").
function SE_SeasonNumber(season as object) as integer
    if season = invalid then return 0
    v = season.season
    if v = invalid then return 0
    t = type(v)
    if t = "roString" or t = "String" then return Int(Val(v))
    return Int(v)
end function

' Tabs are listed newest-first (parity with seasonTabs sort: descending by season number).
function SE_SortSeasonsDescending(seasons as object) as object
    out = []
    if seasons = invalid then return out
    for each s in seasons
        if s <> invalid then out.Push(s)
    end for
    n = out.Count()
    for i = 0 to n - 2
        for j = 0 to n - 2 - i
            if SE_SeasonNumber(out[j]) < SE_SeasonNumber(out[j + 1]) then
                tmp = out[j]
                out[j] = out[j + 1]
                out[j + 1] = tmp
            end if
        end for
    end for
    return out
end function

' The binge queue: every episode across every season, ascending by season number
' (parity with allEpisodesAcrossSeasons in handleCardVideoPlay).
function SE_FlattenEpisodesAscending(seasons as object) as object
    out = []
    if seasons = invalid then return out
    asc = []
    for each s in seasons
        if s <> invalid then asc.Push(s)
    end for
    n = asc.Count()
    for i = 0 to n - 2
        for j = 0 to n - 2 - i
            if SE_SeasonNumber(asc[j]) > SE_SeasonNumber(asc[j + 1]) then
                tmp = asc[j]
                asc[j] = asc[j + 1]
                asc[j + 1] = tmp
            end if
        end for
    end for
    for each s in asc
        if s <> invalid and s.episodes <> invalid then
            for each ep in s.episodes
                if ep <> invalid then out.Push(ep)
            end for
        end if
    end for
    return out
end function

' Locate the playing episode inside the flattened queue (match videoId then _id).
function SE_FindEpisodeIndex(list as object, episode as object) as integer
    if list = invalid or episode = invalid then return 0
    for i = 0 to list.Count() - 1
        ep = list[i]
        if ep <> invalid then
            if ep.videoId <> invalid and episode.videoId <> invalid and ep.videoId = episode.videoId then return i
            if ep._id <> invalid and episode._id <> invalid and ep._id = episode._id then return i
        end if
    end for
    return 0
end function

' Synthesize a trailer episode per season that carries a preview URL (parity with the
' trailers map in seriesEpisode.tsx). episode = -1 marks a trailer (hides the meta line).
function SE_BuildTrailerList(seasons as object, thumbnails as object) as object
    out = []
    if seasons = invalid then return out
    for each s in seasons
        if s <> invalid and s.preview <> invalid and s.preview.url <> invalid and s.preview.url <> "" then
            ptype = "application/vnd.apple.mpegurl"
            if s.preview.type <> invalid and s.preview.type <> "" then ptype = s.preview.type
            sid = ""
            if s._id <> invalid then sid = s._id
            stitle = "Season"
            if s.title <> invalid and s.title <> "" then stitle = s.title
            sdesc = "Official season trailer"
            if s.description <> invalid and s.description <> "" then sdesc = s.description
            thumbs = invalid
            if thumbnails <> invalid and thumbnails.Count() > 0 then thumbs = [thumbnails[0]]
            out.Push({
                _id: sid
                videoId: sid
                title: stitle + " - Trailer"
                description: sdesc
                season: -1
                episode: -1
                thumbnails: thumbs
                playList: { hls: { url: s.preview.url, type: ptype } }
                isTrailer: true
            })
        end if
    end for
    return out
end function

' Progress % for an episode's card (parity with getProgress: match season + episode number).
function SE_EpisodeProgress(continueWatching as object, season as object, episode as object) as float
    if continueWatching = invalid or season = invalid or episode = invalid then return 0.0
    sNum = SE_SeasonNumber(season)
    epNo = 0
    if episode.episode <> invalid then epNo = Int(episode.episode)
    for each cw in continueWatching
        if cw <> invalid and cw.season <> invalid and cw.episode <> invalid then
            if Int(cw.season) = sNum and Int(cw.episode) = epNo then
                if cw.progressPercentage <> invalid then return cw.progressPercentage
                return 0.0
            end if
        end if
    end for
    return 0.0
end function

' Video-player nav state for a regular episode (parity with the episode branch of
' handleCardVideoPlay). VideoPlayerScreen reads detail/contentId/nextVideoList/currentIndex/startOver.
function SE_PlayEpisodePayload(seriesId as string, episode as object, seasons as object) as object
    queue = SE_FlattenEpisodesAscending(seasons)
    idx = SE_FindEpisodeIndex(queue, episode)
    return {
        detail: episode
        contentId: seriesId
        startOver: false
        nextVideoList: queue
        currentIndex: idx
        nextVideoPlay: true
        firstEp: (idx = 0)
        isTrailer: false
    }
end function

' Video-player nav state for a trailer (parity with the trailer branch: no binge queue).
function SE_PlayTrailerPayload(seriesId as string, trailer as object) as object
    return {
        detail: trailer
        contentId: seriesId
        startOver: true
        nextVideoList: []
        currentIndex: 0
        nextVideoPlay: false
        isTrailer: true
    }
end function

' ── Last-watched persistence (parity with saveLastSeason/saveLastEpisode in helper.ts,
'    which use localStorage keyed by the series id) ────────────────────────────────────

function SE_LastSeasonKey(seriesId as string) as string: return "lastSeason_" + seriesId: end function
function SE_LastEpisodeKey(seriesId as string) as string: return "lastEpisode_" + seriesId: end function

sub SE_SaveLastSeason(seriesId as string, seasonId as string)
    if seriesId = "" or seasonId = "" then return
    RegistryWrite(SE_LastSeasonKey(seriesId), seasonId, "app")
end sub

function SE_GetLastSeason(seriesId as string) as string
    if seriesId = "" then return ""
    return RegistryRead(SE_LastSeasonKey(seriesId), "app")
end function

sub SE_SaveLastEpisode(seriesId as string, episodeId as string)
    if seriesId = "" or episodeId = "" then return
    RegistryWrite(SE_LastEpisodeKey(seriesId), episodeId, "app")
end sub

function SE_GetLastEpisode(seriesId as string) as string
    if seriesId = "" then return ""
    return RegistryRead(SE_LastEpisodeKey(seriesId), "app")
end function

' Estimated runtime line "Episode N • X min" (parity with the EpisodeCard meta line).
function SE_EpisodeMetaLine(episode as object) as string
    if episode = invalid then return ""
    epNum = 0
    if episode.episode <> invalid then epNum = Int(episode.episode)
    if epNum <= 0 then return ""
    out = "Episode " + epNum.ToStr()
    rt = ""
    if episode.estimatedRunTime <> invalid then
        t = type(episode.estimatedRunTime)
        if t = "roString" or t = "String" then
            rt = episode.estimatedRunTime
        else
            rt = Str(episode.estimatedRunTime).Trim()
        end if
    end if
    if rt <> "" then out = out + " " + Chr(8226) + " " + rt + " min"
    return out
end function
