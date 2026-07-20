' CardHelper.brs — thumbnail resolution and card geometry (parity with helper.ts
' and the Tailwind sizes on each React card component).

function HC_CardTypeHorizontal() as string
    return "HORIZONTAL"
end function

function HC_CardTypeVertical() as string
    return "VERTICAL"
end function

function HC_CardGap() as integer
    return 10
end function

function HC_SeeAllThreshold() as integer
    return 10
end function

' Exact type match only — parity with helper.ts getCardImgByType (no first-thumb fallback).
function GetCardImgByTypeExact(cardType as string, thumbnails as object) as string
    if thumbnails = invalid or cardType = "" then return ""
    for each thumb in thumbnails
        if thumb <> invalid and thumb.type = cardType and thumb.path <> invalid and thumb.path <> "" then
            return thumb.path
        end if
    end for
    return ""
end function

' OTT Banner (components/banner/index.tsx): HORIZONTAL from thumbnails only.
' React convertToBannerItem copies thumbnails→banners then picks HORIZONTAL — it never
' uses the API banners[] field or a VERTICAL / first-thumb fallback for the hero poster.
function GetOttBannerImage(item as object) as string
    if item = invalid then return ""
    return GetCardImgByTypeExact(HC_CardTypeHorizontal(), item.thumbnails)
end function

' Pick the thumbnail URL whose type matches the card orientation.
function GetCardImgByType(cardType as string, thumbnails as object) as string
    if thumbnails = invalid then return ""
    if cardType <> "" then
        for each thumb in thumbnails
            if thumb <> invalid and thumb.type = cardType and thumb.path <> invalid and thumb.path <> "" then
                return thumb.path
            end if
        end for
    end if
    for each thumb in thumbnails
        if thumb <> invalid and thumb.path <> invalid and thumb.path <> "" then
            return thumb.path
        end if
    end for
    return ""
end function

function GetContinueProgressPercent(item as object) as float
    if item = invalid then return 0.0
    cw = item.continueWatching
    if cw = invalid then return 0.0
    if type(cw) = "roAssociativeArray" then
        pct = cw.progressPercentage
        if pct <> invalid then return pct
        return 0.0
    end if
    if cw.Count() < 1 then return 0.0
    entry = cw[0]
    if entry = invalid then return 0.0
    pct = entry.progressPercentage
    if pct = invalid then return 0.0
    return pct
end function

' Banner/promo image priority matches banner.tsx getImageSource().
function ResolveBannerImage(item as object, thumbFallback as string) as string
    if item = invalid then return thumbFallback
    promos = item.promoBanners
    if promos <> invalid and promos.Count() > 0 and promos[0].path <> invalid then
        return promos[0].path
    end if
    banners = item.banners
    if banners <> invalid and banners.Count() > 0 and banners[0].path <> invalid then
        return banners[0].path
    end if
    if thumbFallback <> "" then return thumbFallback
    if item.thumbnails <> invalid then
        return GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
    end if
    return ""
end function

' Map a home category row to the Roku card component id used in ContentRow.
function CardComponentForRow(rowType as string, cardType as string) as string
    if rowType = HC_TypeContinueWatching() then return "ContinueWatchCard"
    if rowType = HC_TypeTopContents() then return "NumberedVerticalCard"
    if rowType = HC_TypeBanner() or rowType = HC_PromotionalCard() then return "BannerCard"
    if rowType = HC_TypeContentList() and cardType = HC_CardTypeHorizontal() then return "HorizontalCard"
    if rowType = HC_TypeContentList() and cardType = HC_CardTypeVertical() then return "VerticalCard"
    return "VerticalCard"
end function

function HC_PromotionalCard() as string
    return "PROMOTIONAL"
end function

' Fixed row geometry shared by Home and Genre (content.tsx, netflixContent.tsx,
' and genre-list/Content.tsx).
' Anchor focused row on a 1080p canvas (netflixContent.tsx ~65vh = 702).
' When displayTitle is on, titles sit under the poster (~415px below row top). At 702
' they land past the visible/safe bottom — pull the pin up so title stays on-screen.
function HC_NetflixAnchorY() as integer
    if HC_IsDisplayTitleEnabled() then return 620
    return 702
end function

' React pins the focused row at 65vh on the 1080p canvas.
function HC_OttAnchorY() as integer
    if HC_IsDisplayTitleEnabled() then return 620
    return 702
end function

function HC_RowPitchForLayout(homeLayout as string) as integer
    if homeLayout = HC_HomeLayoutOtt() then return HC_OttRowPitch()
    return HC_RowPitch()
end function

function HC_AnchorYForLayout(homeLayout as string) as integer
    if homeLayout = HC_HomeLayoutOtt() then return HC_OttAnchorY()
    return HC_NetflixAnchorY()
end function

' ContentRow.tsx: title + cards strip + m-b-75 between rows.
function HC_RowCardsTop() as integer
    return 55
end function

function HC_RowMarginBottom() as integer
    return 75
end function

function HC_CardTitleExtraH() as integer
    ' Space under Horizontal/Vertical posters for the title line + pb-2.
    if HC_IsDisplayTitleEnabled() then return 56
    return 0
end function

' Poster-only height — card shimmer must not grow when displayTitle is on.
function HC_CardPosterHeight(compName as string) as integer
    if compName = "ContinueWatchCard" then return 286
    if compName = "HorizontalCard" then return 312
    if compName = "VerticalCard" then return 300
    if compName = "NumberedVerticalCard" then return 260
    if compName = "BannerCard" then return 400
    if compName = "SeeAllCard" then return 305
    return 286
end function

function HC_CardUsesDisplayTitle(compName as string) as boolean
    if not HC_IsDisplayTitleEnabled() then return false
    return (compName = "HorizontalCard" or compName = "VerticalCard")
end function

' Thin title-line shimmer under the poster (React keeps title outside the card pulse).
function HC_CardTitleShimmerH() as integer
    return 22
end function

function HC_CardTitleShimmerGap() as integer
    return 8
end function

function HC_CardTitleShimmerWidth(posterW as integer) as integer
    w = Int(posterW * 0.72 + 0.5)
    if w < 80 then w = 80
    if w > posterW then w = posterW
    return w
end function

function HC_IsDisplayTitleEnabled() as boolean
    ' Mirrors FeatureDisplayTitle / DefaultFeatures.displayTitle without requiring
    ' BusinessConfig.brs on every CardHelper consumer.
    if m.global <> invalid and m.global.businessResolved <> invalid then
        f = m.global.businessResolved.features
        if f <> invalid and f.displayTitle <> invalid then
            v = f.displayTitle
            t = type(v)
            if t = "roBoolean" or t = "Boolean" then return v
            if t = "roInteger" or t = "Integer" or t = "roFloat" or t = "Float" then return (v <> 0)
            if t = "roString" or t = "String" then
                s = LCase(v)
                return (s = "true" or s = "1" or s = "yes")
            end if
        end if
    end if
    return false
end function

function HC_CardHeight(compName as string) as integer
    base = HC_CardPosterHeight(compName)
    ' Title sits under Horizontal/Vertical posters only (React same).
    if HC_CardUsesDisplayTitle(compName) then return base + HC_CardTitleExtraH()
    return base
end function

function HC_ContentRowLayoutHeight(cat as object) as integer
    ' Title band + cards strip + m-b-75; grow when card titles are on.
    return 446 + HC_CardTitleExtraH()
end function

function HC_RowPitch() as integer
    return 460 + HC_CardTitleExtraH()
end function

function HC_OttRowPitch() as integer
    return 460 + HC_CardTitleExtraH()
end function

function CardComponentWidth(compName as string, orientation = "" as string) as integer
    if compName = "HorizontalCard" then return 556
    if compName = "ContinueWatchCard" then return 556
    if compName = "NumberedVerticalCard" then return 392
    if compName = "VerticalCard" then return 256
    if compName = "BannerCard" then return 1776
    if compName = "SeeAllCard" then
        if orientation = HC_CardTypeHorizontal() then return 546
        return 256
    end if
    return 256
end function

' Rows rendered below the hero — skip empty rows and the dedicated BANNER category.
' Hero slide image — parity with heroBannerCinematic getBannerImage().
function GetHeroBannerImage(item as object) as string
    if item = invalid then return ""
    if item.banners <> invalid and item.banners.Count() > 0 then
        for each banner in item.banners
            if banner <> invalid and banner.type = HC_CardTypeHorizontal() and banner.path <> invalid and banner.path <> "" then
                return banner.path
            end if
        end for
        first = item.banners[0]
        if first <> invalid and first.path <> invalid and first.path <> "" then
            return first.path
        end if
    end if
    return GetCardImgByType(HC_CardTypeHorizontal(), item.thumbnails)
end function

' Banner strip for the Netflix hero (parity with netflixContent bannerItems).
function ExtractBannerItems(categories as object) as object
    if categories = invalid then return []
    for each cat in categories
        if cat = invalid then continue for
        rowType = ""
        if cat.type <> invalid then rowType = cat.type
        if rowType = HC_TypeBanner() then
            items = cat.result
            if items <> invalid and items.Count() > 0 then return items
        end if
    end for
    contentRows = FilterContentRows(categories)
    if contentRows.Count() > 0 then
        first = contentRows[0]
        if first <> invalid and first.result <> invalid and first.result.Count() > 0 then
            return first.result
        end if
    end if
    return []
end function

' First content card for OTT focus-reactive banner (parity with Content.tsx activeItem).
function ExtractOttActiveItem(categories as object) as object
    contentRows = FilterContentRows(categories)
    for each cat in contentRows
        if cat = invalid then continue for
        items = cat.result
        if items <> invalid and items.Count() > 0 then return items[0]
    end for
    banner = ExtractBannerItems(categories)
    if banner.Count() > 0 then return banner[0]
    return invalid
end function

function ItemAtRowCard(categories as object, rowIndex as integer, cardIndex as integer) as object
    if categories = invalid then return invalid
    contentRows = FilterContentRows(categories)
    if rowIndex < 0 or rowIndex >= contentRows.Count() then return invalid
    cat = contentRows[rowIndex]
    if cat = invalid or cat.result = invalid then return invalid
    if cardIndex < 0 or cardIndex >= cat.result.Count() then return invalid
    return cat.result[cardIndex]
end function

function TruncateHeroText(text as string, maxLen as integer) as string
    if text = invalid or text = "" then return ""
    if Len(text) <= maxLen then return text
    return Left(text, maxLen) + "..."
end function

' Mirror heroBannerCinematic formatRating(): always one decimal; .5 preserved,
' otherwise rounded to the nearest whole number.
function FormatHeroRating(rating as dynamic) as string
    if rating = invalid then return ""
    s = ""
    if type(rating) = "roString" or type(rating) = "String" then
        s = rating
    else
        s = Str(rating).Trim()
    end if
    if s = "" then return ""
    v = Val(s)
    frac = v - Int(v)
    if Abs(frac - 0.5) < 0.001 then
        whole = Int(v)
        return whole.ToStr() + ".5"
    end if
    rounded = Int(v + 0.5)
    return rounded.ToStr() + ".0"
end function

' Normalized 0–5 rating for star rendering (imdb is often 0–10).
function HeroStarRating(rating as dynamic) as float
    if rating = invalid then return 0.0
    s = ""
    if type(rating) = "roString" or type(rating) = "String" then
        s = rating
    else
        s = Str(rating).Trim()
    end if
    if s = "" then return 0.0
    v = Val(s)
    if v > 5 then return v / 2.0
    return v
end function

function FormatHeroGenres(item as object) as string
    if item = invalid or item.genres = invalid then return ""
    out = ""
    limit = 4
    if item.genres.Count() < limit then limit = item.genres.Count()
    for i = 0 to limit - 1
        genre = item.genres[i]
        if genre = invalid or genre.name = invalid or genre.name = "" then continue for
        if out <> "" then out = out + " · "
        out = out + genre.name
    end for
    return out
end function

function FilterContentRows(categories as object) as object
    rows = []
    if categories = invalid then return rows
    for each cat in categories
        if cat = invalid then continue for
        rowType = ""
        if cat.type <> invalid then rowType = cat.type
        if rowType = HC_TypeBanner() then continue for
        items = cat.result
        if items = invalid or items.Count() = 0 then continue for
        rows.Push(cat)
    end for
    return rows
end function
