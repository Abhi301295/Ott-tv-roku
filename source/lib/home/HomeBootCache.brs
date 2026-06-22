' HomeBootCache.brs — in-memory CW + categories handoff (Profile prefetch → Home boot).
' Stored on ViewManager component m (roSGNode global AA fields do not persist reliably).

function HomeBootVmNode() as object
    if m.vm <> invalid then return m.vm
    if m.top <> invalid then return FindViewManager(m.top)
    return invalid
end function

function HomeBootCacheEntry() as object
    vm = HomeBootVmNode()
    if vm = invalid then return invalid
    entry = vm.callFunc("GetHomeBootCacheEntry")
    if entry = invalid then return invalid
    return entry
end function

sub HomeBootCacheSet(entry as object)
    vm = HomeBootVmNode()
    if vm = invalid then return
    vm.callFunc("SetHomeBootCacheEntry", entry)
end sub

sub HomeBootCacheBegin(profileId as string)
    HomeBootCacheSet({
        profileId: profileId
        cwDone: false
        catDone: false
        cwApi: invalid
        catApi: invalid
    })
end sub

sub HomeBootCacheClear()
    vm = HomeBootVmNode()
    if vm = invalid then return
    vm.callFunc("ClearHomeBootCacheEntry")
end sub

sub HomeBootCacheSetCw(api as object)
    entry = HomeBootCacheEntry()
    if entry = invalid then return
    HomeBootCacheSet({
        profileId: entry.profileId
        cwDone: true
        catDone: entry.catDone = true
        cwApi: api
        catApi: entry.catApi
    })
end sub

sub HomeBootCacheSetCategories(api as object)
    entry = HomeBootCacheEntry()
    if entry = invalid then return
    HomeBootCacheSet({
        profileId: entry.profileId
        cwDone: entry.cwDone = true
        catDone: true
        cwApi: entry.cwApi
        catApi: api
    })
end sub

sub HomeBootCacheForceComplete()
    entry = HomeBootCacheEntry()
    if entry = invalid then return
    HomeBootCacheSet({
        profileId: entry.profileId
        cwDone: true
        catDone: true
        cwApi: entry.cwApi
        catApi: entry.catApi
    })
end sub

function HomeBootCacheIsReady() as boolean
    entry = HomeBootCacheEntry()
    if entry = invalid then return false
    return entry.cwDone = true and entry.catDone = true
end function

function HomeBootCacheHasUsableData(profileId as string) as boolean
    entry = HomeBootCacheEntry()
    if entry = invalid then return false
    if entry.profileId <> profileId then return false
    if not HomeBootCacheIsReady() then return false

    cwCount = 0
    catCount = 0
    if entry.cwApi <> invalid and entry.cwApi.ok and entry.cwApi.result <> invalid then
        cwCount = ExtractCategoryListing(entry.cwApi.result).Count()
    end if
    if entry.catApi <> invalid and entry.catApi.ok and entry.catApi.result <> invalid then
        catCount = ExtractCategoryListing(entry.catApi.result).Count()
    end if
    return cwCount > 0 or catCount > 0
end function

function HomeBootCacheHasData(profileId as string) as boolean
    entry = HomeBootCacheEntry()
    if entry = invalid then return false
    if entry.profileId <> profileId then return false
    return HomeBootCacheIsReady()
end function

function HomeBootCacheConsume(profileId as string) as object
    if not HomeBootCacheHasData(profileId) then return invalid
    entry = HomeBootCacheEntry()

    cats = []
    cwCount = 0
    catCount = 0

    if entry.cwApi <> invalid and entry.cwApi.ok and entry.cwApi.result <> invalid then
        listing = ExtractCategoryListing(entry.cwApi.result)
        cwCount = listing.Count()
        if cwCount > 0 then
            cats = PrependCategories(cats, TagContinueWatchingRows(listing))
        end if
    end if

    if entry.catApi <> invalid and entry.catApi.ok and entry.catApi.result <> invalid then
        listing = ExtractCategoryListing(entry.catApi.result)
        catCount = listing.Count()
        if catCount > 0 then
            cats = AppendCategories(cats, listing)
        end if
    end if

    HomeBootCacheClear()
    return {
        categories: cats
        cwCount: cwCount
        catCount: catCount
    }
end function
