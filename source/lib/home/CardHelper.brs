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

' Pick the thumbnail URL whose type matches the card orientation.
function GetCardImgByType(cardType as string, thumbnails as object) as string
    if thumbnails = invalid or cardType = "" then return ""
    for each thumb in thumbnails
        if thumb <> invalid and thumb.type = cardType and thumb.path <> invalid and thumb.path <> "" then
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
