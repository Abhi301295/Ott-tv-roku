' HomeService.brs — home data helpers (parity with features/home/services/action.ts
' and features/home/index.tsx boot logic). Network orchestration lives in HomeScreen.

' Resolved home layout for this build (parity with themeConfig.homeLayout).
function HomeLayoutMode() as string
    layout = ThemeHomeLayout()
    print "[HOME_LAYOUT_DBG] homeLayout="; layout; " netflixHeader="; ThemeIsNetflixHeader(); " homeBanner="; FeatureEnableHomeBanner(); " cardFocus="; FeatureEnableCardFocus(); " trailerBanner="; FeatureEnableTrailerOnBanner(); " displayTitle="; FeatureDisplayTitle()
    return layout
end function

' Pull listing[] from a home/continue API result envelope.
function ExtractCategoryListing(result as object) as object
    if result = invalid then return []
    listing = result.listing
    if listing = invalid then return []
    return listing
end function

' Continue-watching rows are tagged before prepend (parity with index.tsx map).
function TagContinueWatchingRows(listing as object) as object
    if listing = invalid then return []
    tagged = []
    for each item in listing
        if item <> invalid then
            row = item
            row.type = HC_TypeContinueWatching()
            tagged.Push(row)
        end if
    end for
    return tagged
end function

function PrependCategories(existing as object, rows as object) as object
    merged = []
    if rows <> invalid then
        for each row in rows
            merged.Push(row)
        end for
    end if
    if existing <> invalid then
        for each row in existing
            merged.Push(row)
        end for
    end if
    return merged
end function

function AppendCategories(existing as object, rows as object) as object
    merged = []
    if existing <> invalid then
        for each row in existing
            merged.Push(row)
        end for
    end if
    if rows <> invalid then
        for each row in rows
            merged.Push(row)
        end for
    end if
    return merged
end function

' Pick the active profile and persist keys the home screen expects
' (parity with index.tsx fetchProfiles .then block).
function BootstrapActiveProfile(profiles as object) as object
    if profiles = invalid or profiles.Count() = 0 then return invalid

    active = profiles[0]
    for each p in profiles
        if p <> invalid and p.currentActive = true then
            active = p
            exit for
        end if
    end for

    if active = invalid or active._id = invalid then return invalid

    SetProfileId(active._id)
    SetValueByKey(SK_IsSubscribed(), "true", "app")
    SetValueByKey(SK_IsDefaultPlan(), "false", "app")
    SetValueByKey(SK_ShowPremiumBadge(), "false", "app")
    SetValueByKey(SK_Email(), "", "app")
    SetValueByKey(SK_Phone(), "", "app")
    SaveProfilesMeta(profiles)
    return active
end function

' Version gate (parity with checkVersion in index.tsx).
function EvaluateVersionUpdate(api as object) as object
    out = { showUpdate: false, forceUpdate: false }
    if api = invalid or api.ok <> true or api.result = invalid then return out

    gs = api.result.generalSetting
    if gs = invalid then return out
    appVer = gs.appVersion
    if appVer = invalid then return out
    lgTv = appVer.lgTv
    if lgTv = invalid then return out

    minimum = lgTv.minimumVersion
    if minimum = invalid or minimum = "" then return out

    cfg = AppConfig()
    current = "0"
    if cfg.appVersion <> invalid and cfg.appVersion <> "" then current = cfg.appVersion

    if Val(minimum) <= Val(current) then return out

    force = (lgTv.forceUpdate = true)
    out.forceUpdate = force
    if force then
        out.showUpdate = true
        return out
    end if

    lastClose = Val(GetValueByKey("lastCloseTime"))
    oneDayMs = 24 * 60 * 60 * 1000
    clock = CreateObject("roDateTime")
    nowMs = clock.AsSeconds() * 1000
    if lastClose = 0 or (nowMs - lastClose) > oneDayMs then
        out.showUpdate = true
    end if
    return out
end function

function HomeCategoryQuery(page as integer) as object
    return {
        page: page
        limit: HC_HomePageLimit()
    }
end function

' Debug line for the data-phase list (name, type, item count).
function FormatCategoryLine(cat as object, index as integer) as string
    if cat = invalid then return ""
    nm = ""
    if cat.name <> invalid then nm = cat.name
    tp = ""
    if cat.type <> invalid then tp = cat.type
    count = 0
    if cat.result <> invalid then count = cat.result.Count()
    return Str(index + 1) + ". " + nm + "  [" + tp + "]  (" + Str(count) + " items)"
end function

function BuildCategoryDebugText(categories as object, homeLayout as string, showUpdate as boolean) as string
    lines = "layout=" + homeLayout + "  rows=" + Str(categories.Count())
    if showUpdate then lines = lines + "  update=available"
    lines = lines + Chr(10)
    if categories = invalid or categories.Count() = 0 then
        return lines + "(no rows)"
    end if
    for i = 0 to categories.Count() - 1
        lines = lines + FormatCategoryLine(categories[i], i) + Chr(10)
    end for
    return lines
end function
