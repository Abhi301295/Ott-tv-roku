' SearchService.brs — GET media/v1/contents/search (parity search/services/action.ts).

function SearchBuildPath(keyword as string, page as integer, limit as integer) as string
    ep = Endpoints().SEARCH.SEARCH_LIST
    q = "page=" + Str(page) + "&limit=" + Str(limit)
    if keyword <> invalid and keyword <> "" then
        q = q + "&keyword=" + keyword
    else
        q = q + "&keyword="
    end if
    return ep + "?" + q
end function

function SearchParseListing(api as object) as object
    items = []
    if api = invalid or api.ok <> true then return items
    if api.result = invalid then return items
    listing = invalid
    if api.result.listing <> invalid then listing = api.result.listing
    if listing = invalid and api.result.data <> invalid then listing = api.result.data
    if listing = invalid then return items
    cap = SR_ResultCap()
    for i = 0 to listing.Count() - 1
        if i >= cap then exit for
        items.Push(listing[i])
    end for
    return items
end function

function SearchHorizontalThumb(item as object) as string
    if item = invalid then return ""
    thumbs = item.thumbnails
    if thumbs = invalid then return ""
    for each t in thumbs
        if t = invalid then continue for
        if t.type = "HORIZONTAL" and t.path <> invalid and t.path <> "" then return t.path
    end for
    return ""
end function
