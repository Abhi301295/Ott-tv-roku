' ReelsService.brs — GET media/v1/contents/reels (parity features/reels/services/action.ts).

function ReelsRandomSeed() as integer
    return RL_SeedMin() + Rnd(RL_SeedMax() - RL_SeedMin() + 1)
end function

function ReelsBuildQuery(page as integer, limit as integer, seed as integer) as object
    return {
        page: page
        limit: limit
        seed: seed
    }
end function

function ReelsParseResponse(api as object) as object
    out = { items: [], total: 0, page: 0, limit: RL_PageLimit() }
    if api = invalid or api.ok <> true then return out
    if api.statusCode <> invalid and api.statusCode <> 200 then return out
    if api.result = invalid then return out

    listing = invalid
    if api.result.data <> invalid then listing = api.result.data
    if listing = invalid and api.result.listing <> invalid then listing = api.result.listing
    if listing = invalid then return out

    out.items = ReelsCoerceList(listing)
    if api.result.total <> invalid then out.total = api.result.total
    if api.result.page <> invalid then out.page = api.result.page
    if api.result.limit <> invalid then out.limit = api.result.limit
    return out
end function

' API JSON may be a true array, a keyed map ("0","1",…), or a single object.
function ReelsCoerceList(val as object) as object
    if val = invalid then return []
    t = type(val)
    if t = "roArray" then
        items = []
        for each item in val
            if item <> invalid then items.Push(item)
        end for
        return items
    end if
    if t = "roAssociativeArray" or t = "AssociativeArray" then
        if val.name <> invalid or val.title <> invalid or val._id <> invalid then
            return [val]
        end if
        ' Numeric keys ("0","1",…) — AA for-each order is unstable; walk by index.
        ordered = ReelsCoerceNumericKeyedList(val)
        if ordered.Count() > 0 then return ordered
        items = []
        for each key in val
            item = val[key]
            if item <> invalid and type(item) <> "roString" and type(item) <> "String" then
                items.Push(item)
            end if
        end for
        return items
    end if
    return []
end function

function ReelsCoerceNumericKeyedList(val as object) as object
    items = []
    if val = invalid then return items
    maxIdx = -1
    for each key in val
        if key = invalid then continue for
        ks = key.ToStr()
        if ks = "" then continue for
        if not ReelsIsDigits(ks) then return []
        idx = ks.ToInt()
        if idx > maxIdx then maxIdx = idx
    end for
    if maxIdx < 0 then return items
    i = 0
    while i <= maxIdx
        item = val[Str(i).Trim()]
        if item <> invalid then items.Push(item)
        i = i + 1
    end while
    return items
end function

function ReelsIsDigits(s as string) as boolean
    if s = invalid or s = "" then return false
    i = 1
    while i <= Len(s)
        ch = Mid(s, i, 1)
        if Asc(ch) < Asc("0") or Asc(ch) > Asc("9") then return false
        i = i + 1
    end while
    return true
end function

function ReelsPageHasMore(batchCount as integer, accumulated as integer, total as integer) as boolean
    if batchCount < RL_PageLimit() then return false
    if total > 0 and accumulated >= total then return false
    return true
end function

function ReelsStreamUrl(reel as object) as string
    if reel = invalid then return ""
    raw = ""
    pl = reel.playList
    if pl <> invalid and type(pl) = "roAssociativeArray" then
        hls = pl.hls
        if hls <> invalid and type(hls) = "roAssociativeArray" then
            if hls.url <> invalid and hls.url <> "" then raw = hls.url.ToStr()
        end if
    end if
    if raw = "" and reel.path <> invalid then raw = reel.path.ToStr()
    if raw = "" then return ""
    return MediaStreamUrl(raw)
end function

function ReelsIsMobilePlatform(plat as dynamic) as boolean
    if plat = invalid then return false
    ' React Plateform.MOBILE === "3" (common.enum.ts).
    if plat = 3 or plat = "3" or UCase(plat.ToStr()) = "MOBILE" then return true
    return false
end function

function ReelsThumbIsVertical(t as object) as boolean
    if t = invalid then return false
    tp = t.type
    if tp <> invalid and UCase(tp.ToStr()) = "VERTICAL" then return true
    ar = t.aspectRatio
    if ar <> invalid then
        s = LCase(ar.ToStr())
        if Instr(1, s, "9:16") > 0 or Instr(1, s, "9/16") > 0 then return true
    end if
    return false
end function

function ReelsCollectThumbnailLists(reel as object) as object
    lists = []
    if reel = invalid then return lists
    fieldNames = ["thumbnails", "banners", "promoBanners"]
    for each fieldName in fieldNames
        val = invalid
        if reel[fieldName] <> invalid then val = reel[fieldName]
        if val <> invalid then lists.Push(val)
    end for
    if reel.content <> invalid then
        for each fieldName in fieldNames
            val = invalid
            if reel.content[fieldName] <> invalid then val = reel.content[fieldName]
            if val <> invalid then lists.Push(val)
        end for
    end if
    return lists
end function

function ReelsThumbPath(t as object) as string
    if t = invalid then return ""
    if t.path <> invalid and t.path <> "" then return t.path.ToStr()
    if t.url <> invalid and t.url <> "" then return t.url.ToStr()
    if t.avifPath <> invalid and t.avifPath <> "" then return t.avifPath.ToStr()
    return ""
end function

function ReelsThumbByType(list as object, cardType as string) as string
    if list = invalid or cardType = "" then return ""
    for each thumb in ReelsCoerceList(list)
        if thumb = invalid then continue for
        tp = thumb.type
        if tp <> invalid then tp = UCase(tp.ToStr())
        if tp = cardType then
            p = ReelsThumbPath(thumb)
            if p <> "" then return p
        end if
    end for
    return ""
end function

function ReelsVerticalThumb(reel as object) as string
    ' React getVerticalThumbnail: MOBILE + VERTICAL from thumbnails[].
    if reel = invalid then return ""
    lists = ReelsCollectThumbnailLists(reel)
    for each thumbs in lists
        list = ReelsCoerceList(thumbs)
        for each t in list
            if t = invalid then continue for
            if not ReelsIsMobilePlatform(t.platform) then continue for
            if not ReelsThumbIsVertical(t) then continue for
            p = ReelsThumbPath(t)
            if p <> "" then return p
        end for
    end for
    return ""
end function

function ReelsAnyThumbPath(reel as object) as string
    ' When API omits MOBILE VERTICAL, use any usable still so the frame is not empty.
    if reel = invalid then return ""
    lists = ReelsCollectThumbnailLists(reel)
    ' Prefer any VERTICAL, then any MOBILE, then first path.
    for each thumbs in lists
        for each t in ReelsCoerceList(thumbs)
            if t = invalid then continue for
            if not ReelsThumbIsVertical(t) then continue for
            p = ReelsThumbPath(t)
            if p <> "" then return p
        end for
    end for
    for each thumbs in lists
        for each t in ReelsCoerceList(thumbs)
            if t = invalid then continue for
            if not ReelsIsMobilePlatform(t.platform) then continue for
            p = ReelsThumbPath(t)
            if p <> "" then return p
        end for
    end for
    for each thumbs in lists
        for each t in ReelsCoerceList(thumbs)
            if t = invalid then continue for
            p = ReelsThumbPath(t)
            if p <> "" then return p
        end for
    end for
    return ""
end function

function ReelsHasPoster(reel as object) as boolean
    ' React always supplies posterUrl (vertical thumb or Images.THUMBNAIL fallback).
    return true
end function

function ReelsPosterUri(reel as object) as string
    thumb = ReelsVerticalThumb(reel)
    if thumb = "" then thumb = ReelsAnyThumbPath(reel)
    if thumb <> "" then return thumb
    return RL_DummyThumbPosterUri()
end function

function ReelsFieldName(obj as object) as string
    if obj = invalid then return ""
    t = type(obj)
    if t = "roString" or t = "String" then return obj.ToStr()
    if t = "roAssociativeArray" or t = "AssociativeArray" then
        if obj.name <> invalid then return obj.name.ToStr()
        if obj.title <> invalid then return obj.title.ToStr()
    end if
    return ""
end function

function ReelsTitle(reel as object) as string
    if reel = invalid then return ""
    if reel.content <> invalid then
        c = reel.content
        contentValType = type(c)
        if contentValType = "roAssociativeArray" or contentValType = "AssociativeArray" then
            if c.title <> invalid and c.title <> "" then return c.title.ToStr()
            if c.name <> invalid and c.name <> "" then return c.name.ToStr()
        end if
    end if
    if reel.title <> invalid and reel.title <> "" then return reel.title.ToStr()
    if reel.name <> invalid and reel.name <> "" then return reel.name.ToStr()
    return ""
end function

function ReelsContentType(reel as object) as string
    if reel = invalid then return ""
    nm = ReelsFieldName(reel.contentType)
    if nm = "" then return ""
    return UCase(nm)
end function

function ReelsDescription(reel as object) as string
    if reel = invalid or reel.description = invalid then return ""
    return reel.description.ToStr()
end function

' Parity with React getCreatedByName: array → [0].name; object → .name.
function ReelsCreatorName(reel as object) as string
    if reel = invalid then return ""
    cb = reel.createdBy
    if cb = invalid then return ""

    t = type(cb)
    if t = "roArray" then
        if cb.Count() < 1 then return ""
        first = cb[0]
        if first = invalid then return ""
        if first.name = invalid or first.name = "" then return ""
        return first.name.ToStr()
    end if

    if t = "roAssociativeArray" or t = "AssociativeArray" then
        key0 = "0"
        if cb[key0] <> invalid then
            first = cb[key0]
            ft = type(first)
            if ft = "roAssociativeArray" or ft = "AssociativeArray" then
                if first.name <> invalid and first.name <> "" then return first.name.ToStr()
            end if
        end if
        if cb.name <> invalid and cb.name <> "" then return cb.name.ToStr()
    end if
    return ""
end function

' React reads profilePicture from the same array/object branch as createdBy.name.
function ReelsCreatorAvatar(reel as object) as string
    if reel = invalid or reel.createdBy = invalid then return ""
    cb = reel.createdBy
    t = type(cb)
    creator = invalid
    if t = "roArray" then
        if cb.Count() > 0 then creator = cb[0]
    else if t = "roAssociativeArray" or t = "AssociativeArray" then
        if cb["0"] <> invalid then
            creator = cb["0"]
        else
            creator = cb
        end if
    end if
    if creator = invalid or creator.profilePicture = invalid then return ""
    return creator.profilePicture.ToStr()
end function

function ReelsId(reel as object) as string
    if reel = invalid then return ""
    if reel._id <> invalid then return reel._id.ToStr()
    if reel.id <> invalid then return reel.id.ToStr()
    return ""
end function

function ReelsIsLiked(reel as object) as boolean
    if reel = invalid or reel.isLiked = invalid then return false
    return reel.isLiked = true
end function

function ReelsLikes(reel as object) as integer
    if reel = invalid or reel.likes = invalid then return 0
    return reel.likes
end function

function ReelsCommentsCount(reel as object) as integer
    if reel = invalid or reel.commentsCount = invalid then return 0
    return reel.commentsCount
end function

function ReelsLikePath(reelId as string, action as boolean) as string
    return Endpoints().REEL_LIKE + "/" + reelId + BuildQueryString({ action: action })
end function

function ReelsCommentsQuery(reelId as string) as object
    return { reel: reelId, limit: RL_CommentLimit() }
end function

function ReelsParseComments(api as object) as object
    if api = invalid or api.ok <> true then return []
    if api.statusCode <> invalid and api.statusCode <> 200 then return []
    if api.result = invalid or api.result.data = invalid then return []
    return ReelsCoerceList(api.result.data)
end function

function ReelsCommentName(comment as object) as string
    if comment = invalid or comment.name = invalid then return ""
    first = ""
    last = ""
    if comment.name.first <> invalid then first = comment.name.first.ToStr()
    if comment.name.last <> invalid then last = comment.name.last.ToStr()
    if first = "" then return last
    if last = "" then return first
    return first + " " + last
end function

function ReelsCommentText(comment as object) as string
    if comment = invalid or comment.comment = invalid then return ""
    return comment.comment.ToStr()
end function

function ReelsCommentAvatar(comment as object) as string
    if comment = invalid or comment.avatar = invalid then return ""
    return comment.avatar.ToStr()
end function

function ReelsCommentLikes(comment as object) as integer
    if comment = invalid or comment.likes = invalid then return 0
    return comment.likes
end function

function ReelsCommentReplies(comment as object) as integer
    if comment = invalid or comment.replies = invalid then return 0
    return comment.replies
end function

function ReelsObjectName(val as object) as string
    if val = invalid then return ""
    t = type(val)
    if t = "roString" or t = "String" then return val.ToStr()
    if val.name <> invalid then return val.name.ToStr()
    if t = "roArray" then
        for each entry in val
            nm = ReelsObjectName(entry)
            if nm <> "" then return nm
        end for
        return ""
    end if
    if t = "roAssociativeArray" or t = "AssociativeArray" then
        key0 = "0"
        if val[key0] <> invalid then
            nm = ReelsObjectName(val[key0])
            if nm <> "" then return nm
        end if
        for each entry in val
            if type(entry) = "roAssociativeArray" or type(entry) = "AssociativeArray" then
                nm = ReelsObjectName(entry)
                if nm <> "" then return nm
            end if
        end for
    end if
    return ""
end function

function ReelsCategories(reel as object) as object
    if reel = invalid then return []
    return ReelsCoerceList(reel.categories)
end function

function ReelsGenres(reel as object) as object
    if reel = invalid then return []
    return ReelsCoerceList(reel.genres)
end function

' Minimal VideoPlayerScreen nav payload for simulator playback (fullscreen).
function ReelsVideoPlayerPayload(reel as object) as object
    if reel = invalid then return invalid
    url = ReelsStreamUrl(reel)
    if url = "" then return invalid

    contentId = ""
    if reel.content <> invalid and reel.content._id <> invalid then
        contentId = reel.content._id.ToStr()
    else if reel._id <> invalid then
        contentId = reel._id.ToStr()
    end if

    detail = {
        playList: { hls: { url: url } }
        title: ReelsTitle(reel)
        continueWatching: []
        isTrailer: false
        isReel: true
    }
    if reel._id <> invalid then detail._id = reel._id
    if reel.videoId <> invalid then detail.videoId = reel.videoId

    return {
        detail: detail
        contentId: contentId
        startOver: true
        nextVideoList: []
        currentIndex: 0
    }
end function
