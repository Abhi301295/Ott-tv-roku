' DetailService.brs — content detail helpers (parity with contentdetail/index.tsx +
' features/contentdetail/services/action.ts).

function DetailContentPath(id as string, tp as string) as string
    ep = Endpoints().DETAIL.CONTENT_VIEW
    return ep + "/" + id + "?type=" + EncodeQueryValue(tp)
end function

function DetailRecommendQuery(title as string, contentId as string, limit = 10 as integer) as object
    return {
        limit: limit
        title: title
        content: contentId
    }
end function

' Banner image for the detail backdrop (horizontal card type on banners[]).
function DetailBannerUri(content as object) as string
    if content = invalid then return ""
    banners = content.banners
    if banners = invalid or banners.Count() = 0 then return ""
    typed = []
    for each b in banners
        if b <> invalid then
            row = b
            if row.type = invalid or row.type = "" then row.type = HC_CardTypeHorizontal()
            typed.Push(row)
        end if
    end for
    uri = GetCardImgByType(HC_CardTypeHorizontal(), typed)
    if uri <> "" then return uri
    if content.thumbnails <> invalid then
        return GetCardImgByType(HC_CardTypeHorizontal(), content.thumbnails)
    end if
    return ""
end function

' Inject a synthetic Trailer season ahead of real seasons (parity with getContentData).
function EnrichDetailContent(raw as object, tp as string) as object
    if raw = invalid then return invalid
    content = raw
    content.type = tp

    trailerSrc = invalid
    if content.trailer <> invalid then trailerSrc = content.trailer
    trailerEp = {
        _id: "trailer-episode"
        title: "Trailer"
        thumbnails: content.thumbnails
        playList: { hls: trailerSrc }
        subtitles: content.trailerSubtitles
        continueWatching: []
        videoId: ""
    }

    trailerSeason = {
        title: "Trailer"
        season: "Trailer"
        _id: "trailer"
        episodes: [trailerEp]
    }

    seasons = []
    if content.seasons <> invalid then
        for each s in content.seasons
            seasons.Push(s)
        end for
    end if

    merged = [trailerSeason]
    for each s in seasons
        merged.Push(s)
    end for
    content.seasons = merged
    return content
end function

function ImdbValue(rating as dynamic) as float
    if rating = invalid then return 0.0
    s = ""
    if type(rating) = "roString" or type(rating) = "String" then
        s = rating
    else
        s = Str(rating).Trim()
    end if
    if s = "" then return 0.0
    return Val(s)
end function

' Mirror detail/index.tsx formatRating(): "" when 0, one decimal kept for .5, else rounded.
function FormatDetailRating(rating as dynamic) as string
    v = ImdbValue(rating)
    if v = 0 then return ""
    frac = v - Int(v)
    if Abs(frac - 0.5) < 0.001 then
        return Int(v).ToStr() + ".5"
    end if
    rounded = Int(v + 0.5)
    return rounded.ToStr() + ".0"
end function

function DetailContentTypeName(content as object) as string
    if content = invalid or content.contentType = invalid then return ""
    if content.contentType.name = invalid then return ""
    return content.contentType.name
end function

function DetailIsMovie(content as object) as boolean
    return DetailContentTypeName(content) = "Movie"
end function

function DetailIsSeries(content as object) as boolean
    return DetailContentTypeName(content) = "Series"
end function

function DetailHasPreview(content as object) as boolean
    if content = invalid or content.preview = invalid then return false
    if content.preview.url = invalid then return false
    return content.preview.url <> ""
end function

function DetailShowTrailerButton(content as object) as boolean
    return DetailHasPreview(content) and DetailIsMovie(content)
end function

function DetailShowMoreEpisodesButton(content as object) as boolean
    return DetailIsSeries(content)
end function

function DetailWatchNowLabel(content as object) as string
    if content = invalid then return CopyWatchNow()
    cw = content.continueWatching
    if cw <> invalid and cw.Count() > 0 then
        entry = cw[0]
        label = CopyContinueWatching()
        if entry <> invalid and entry.season <> invalid and entry.episode <> invalid then
            label = label + " S" + entry.season.ToStr() + " E" + entry.episode.ToStr()
        end if
        return label
    end if
    tp = ""
    if content.type <> invalid then tp = content.type
    if tp = HM_TypeSingleVideo() or tp = HM_TypeSeries() then
        return CopyWatchNow()
    end if
    return CopyWatch()
end function

function DetailMetaLine(content as object) as string
    if content = invalid then return ""
    out = ""
    if content.discretion <> invalid and content.discretion <> "" then
        out = content.discretion
    end if
    genres = FormatHeroGenres(content)
    if genres <> "" then
        ' React renders `after:content-['•']` (U+2022 bullet) at the meta font size,
        ' with ~5px margin each side. Use the same glyph (not the smaller U+00B7 middot).
        if out <> "" then out = out + " " + Chr(8226) + " "
        out = out + genres
    end if
    return out
end function

function DetailPlayEpisode(content as object, startOver as boolean) as object
    if content = invalid then return invalid
    tp = ""
    if content.type <> invalid then tp = content.type
    episode = invalid
    if tp = HM_TypeSingleVideo() then
        episode = content
    else if content.seasons <> invalid and content.seasons.Count() > 1 then
        season = content.seasons[1]
        if season <> invalid and season.episodes <> invalid and season.episodes.Count() > 0 then
            episode = season.episodes[0]
        end if
    end if
    if episode = invalid then return invalid

    nextList = []
    currentIdx = 0
    if tp <> HM_TypeSingleVideo() and content.seasons <> invalid and content.seasons.Count() > 1 then
        season = content.seasons[1]
        if season <> invalid and season.episodes <> invalid then
            nextList = season.episodes
            for i = 0 to nextList.Count() - 1
                ep = nextList[i]
                if ep <> invalid and ep.videoId <> invalid and episode.videoId <> invalid then
                    if ep.videoId = episode.videoId then
                        currentIdx = i
                        exit for
                    end if
                end if
            end for
        end if
    end if

    contentId = ""
    if content._id <> invalid then contentId = content._id

    return {
        detail: episode
        contentId: contentId
        startOver: startOver
        nextVideoList: nextList
        currentIndex: currentIdx
    }
end function

function DetailTrailerPayload(content as object) as object
    if content = invalid or not DetailHasPreview(content) then return invalid
    contentId = ""
    if content._id <> invalid then contentId = content._id
    trailerDetail = content
    trailerDetail.videoId = content.videoId
    if trailerDetail.videoId = invalid then trailerDetail.videoId = content._id
    trailerDetail.title = content.title + " - Trailer"
    trailerDetail.playList = { hls: content.preview }
    if content.previewSubtitles <> invalid then
        trailerDetail.subtitles = content.previewSubtitles
    else if content.subtitles <> invalid then
        trailerDetail.subtitles = content.subtitles
    end if
    trailerDetail.continueWatching = []
    trailerDetail.isTrailer = true
    return {
        detail: trailerDetail
        contentId: contentId
        startOver: true
        nextVideoPlay: false
    }
end function
