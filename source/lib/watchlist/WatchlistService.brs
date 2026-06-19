' WatchlistService.brs — parity with features/list-detail/services/action.ts

function WL_ParseFirstFolder(api as object) as object
    if api = invalid or api.ok <> true then return invalid
    if api.result = invalid or api.result.data = invalid then return invalid
    data = api.result.data
    if data.Count() < 1 then return invalid
    folder = data[0]
    if folder = invalid then return invalid
    id = ""
    if folder._id <> invalid then id = folder._id
    if id = "" then return invalid
    name = ""
    if folder.name <> invalid then name = folder.name
    return { id: id, name: name }
end function

function WL_ParseDetailItems(api as object) as object
    items = []
    if api = invalid or api.ok <> true then return items
    if api.result = invalid or api.result.data = invalid then return items
    return api.result.data
end function

function WL_DetailHasMore(api as object, batchCount as integer) as boolean
    if batchCount < 1 then return false
    if batchCount < WL_PageLimit() then return false
    if api <> invalid and api.result <> invalid and api.result.total <> invalid then
        total = api.result.total
        if total = invalid or total = 0 then return false
    end if
    return true
end function

function WL_ItemContentType(item as object) as string
    if item = invalid then return ""
    tp = ""
    if item.contentType <> invalid and item.contentType <> "" then tp = item.contentType
    if tp = "" and item.type <> invalid then tp = item.type
    return tp
end function

function WL_BuildDetailPath(folderId as string) as string
    return Endpoints().MY_LIST.MY_LIST_DETAIL + folderId + "/details"
end function

' Parity listDetailCard.tsx CheckType().
function WL_FormatContentType(contentType as string) as string
    if contentType = invalid or contentType = "" then return ""
    if contentType = "SERIES_AND_EPISODES" then return "Series"
    if contentType = "SINGLE_VIDEO" then return "Movies"
    return contentType
end function
