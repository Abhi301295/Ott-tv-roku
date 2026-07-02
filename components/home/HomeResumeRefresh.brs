' HomeResumeRefresh.brs — silent CW refresh when the nav stack pops back to Home after playback.


sub OnStackResumed()
    if m.top.stackResumed <> true then return
    m.top.stackResumed = false
    if m.top.dispose = true then return
    if not IsHomeForeground() then return
    if m.rowsBuilt <> true then
        print "[HOME_REFRESH_DBG] stack_resumed skip rows_not_built"
        return
    end if
    if not HomeCatalogIsDirty(m.top) then
        print "[HOME_REFRESH_DBG] stack_resumed skip catalog_clean"
        return
    end if
    print "[HOME_REFRESH_DBG] stack_resumed silent_cw_refresh"
    StartSilentCwRefresh()
end sub


sub StartSilentCwRefresh()
    if m.cwRefreshInFlight = true then return
    if m.top.dispose = true then return
    if not IsHomeForeground() then return
    m.cwRefreshInFlight = true
    path = Endpoints().HOME.CONTINUE_WATCHING
    KillHomeCwRefreshTask()
    m.cwRefreshTask = ApiGet(path)
    m.cwRefreshTask.observeField("apiResult", "OnSilentCwResponse")
    StartHttpTask(m.cwRefreshTask)
end sub


sub KillHomeCwRefreshTask()
    if m.cwRefreshTask = invalid then return
    m.cwRefreshTask.unobserveField("apiResult")
    m.cwRefreshTask = invalid
end sub


sub OnSilentCwResponse()
    m.cwRefreshInFlight = false
    if m.top.dispose = true then return
    if m.cwRefreshTask = invalid then return
    api = m.cwRefreshTask.apiResult
    KillHomeCwRefreshTask()
    if not IsHomeForeground() then
        print "[HOME_REFRESH_DBG] silent_cw ignored not_foreground"
        return
    end if

    newCw = []
    if api <> invalid and api.ok = true and api.result <> invalid then
        listing = ExtractCategoryListing(api.result)
        if listing.Count() > 0 then newCw = TagContinueWatchingRows(listing)
    end if

    kept = CategoriesWithoutCw(m.categories)
    merged = PrependCategories(kept, newCw)
    oldFp = HomeCwFingerprint(m.categories)
    newFp = HomeCwFingerprint(merged)
    print "[HOME_REFRESH_DBG] silent_cw ok="; (api <> invalid and api.ok = true); " oldFp="; oldFp; " newFp="; newFp

    HomeCatalogClearDirty(m.top)
    if oldFp = newFp then
        print "[HOME_REFRESH_DBG] silent_cw no_change"
        return
    end if

    m.categories = merged
    ApplySilentCwCatalogUpdate()
end sub


sub ApplySilentCwCatalogUpdate()
    oldCats = m.contentRowCats
    if oldCats = invalid then oldCats = []
    m.contentRowCats = FilterContentRows(m.categories)

    oldHadCw = HomeCwSliceCount(oldCats) > 0
    newHadCw = HomeCwSliceCount(m.contentRowCats) > 0

    if newHadCw and m.rowWidgets <> invalid and m.rowWidgets.Count() > 0 and m.contentRowCats.Count() > 0 then
        row0 = m.rowWidgets[0]
        cat0 = m.contentRowCats[0]
        if row0 <> invalid and cat0 <> invalid and cat0.type = HC_TypeContinueWatching() then
            patched = row0.callFunc("PatchContinueWatching", cat0)
            if patched = true then
                ClampCardIndex()
                ApplyHomeFocus()
                print "[HOME_REFRESH_DBG] silent_cw patched row0 in_place cards="; row0.cardCount; " focus="; m.cardIndex
                return
            end if
        end if
    end if

    if oldHadCw <> newHadCw or m.contentRowCats.Count() <> oldCats.Count() then
        print "[HOME_REFRESH_DBG] silent_cw structure_change rebuild rows"
        RebuildHomeRowsSilent()
        return
    end if

    print "[HOME_REFRESH_DBG] silent_cw fallback_no_patch"
end sub


' Rebuild visible rows from m.categories without re-arming the boot shimmer.
sub RebuildHomeRowsSilent()
    if m.rowsHost = invalid then return
    DetachFirstRowWatch()
    ClearContentRows()
    m.contentRowCats = FilterContentRows(m.categories)
    m.rowBuildIndex = 0
    m.rowBuildY = 0
    m.rowTops = []
    m.rowContentHeight = 0
    m.rowsBuilt = false
    m.rowsDataReady = true
    m.rowGateElapsed = true
    m.rowsBuilt = true
    BuildContentRows()
    if m.rowsRevealed then ApplyHomeFocus()
end sub
