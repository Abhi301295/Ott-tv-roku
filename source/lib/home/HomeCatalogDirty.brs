' HomeCatalogDirty.brs — playback/session flag on ViewManager; home CW refresh reads it on stack resume.

function HomeCatalogVm(fromNode as object) as object
    if fromNode = invalid then return invalid
    return FindViewManager(fromNode)
end function

sub HomeCatalogMarkDirty(fromNode as object)
    vm = HomeCatalogVm(fromNode)
    if vm = invalid then return
    vm.callFunc("MarkHomeCatalogDirty")
end sub

sub HomeCatalogClearDirty(fromNode as object)
    vm = HomeCatalogVm(fromNode)
    if vm = invalid then return
    vm.callFunc("ClearHomeCatalogDirty")
end sub

function HomeCatalogIsDirty(fromNode as object) as boolean
    vm = HomeCatalogVm(fromNode)
    if vm = invalid then return false
    return vm.callFunc("IsHomeCatalogDirty")
end function

' Drop every continue-watching slice before merging a fresh CW response.
function CategoriesWithoutCw(categories as object) as object
    kept = []
    if categories = invalid then return kept
    for each cat in categories
        if cat = invalid then continue for
        tp = ""
        if cat.type <> invalid then tp = cat.type
        if tp = HC_TypeContinueWatching() then continue for
        kept.Push(cat)
    end for
    return kept
end function

' Stable ordering fingerprint: row item ids + progress percentages.
function HomeCwFingerprint(categories as object) as string
    if categories = invalid then return ""
    out = ""
    for each cat in categories
        if cat = invalid then continue for
        tp = ""
        if cat.type <> invalid then tp = cat.type
        if tp <> HC_TypeContinueWatching() then continue for
        items = cat.result
        if items = invalid or items.Count() = 0 then continue for
        for each item in items
            if item = invalid then continue for
            id = ""
            if item._id <> invalid then id = item._id
            part = id + ":" + Str(GetContinueProgressPercent(item))
            if out <> "" then out = out + "|"
            out = out + part
        end for
    end for
    return out
end function

function HomeCwSliceCount(categories as object) as integer
    count = 0
    if categories = invalid then return 0
    for each cat in categories
        if cat = invalid then continue for
        tp = ""
        if cat.type <> invalid then tp = cat.type
        if tp <> HC_TypeContinueWatching() then continue for
        items = cat.result
        if items <> invalid and items.Count() > 0 then count = count + 1
    end for
    return count
end function
