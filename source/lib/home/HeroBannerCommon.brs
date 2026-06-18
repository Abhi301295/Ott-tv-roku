' HeroBannerCommon.brs — shared metadata + star rating for all hero variants.

function HeroFormatRating(rating as dynamic) as string
    if rating = invalid then return ""
    s = Str(rating)
    if s = "" then return ""
    v = Val(s)
    if v = 0 and s <> "0" and s <> "0.0" then return ""
    frac = v - Int(v)
    if frac >= 0.4 and frac <= 0.6 then return Str(Int(v)) + ".5"
    return Str(Int(v + 0.5))
end function

function HeroTruncate(text as string, maxLen as integer) as string
    if text = invalid or text = "" then return ""
    if Len(text) <= maxLen then return text
    return Left(text, maxLen) + "..."
end function

function HeroGenreLine(item as object, maxGenres as integer) as string
    if maxGenres < 1 then maxGenres = 4
    if item = invalid or item.genres = invalid then return ""
    parts = []
    for each g in item.genres
        if g <> invalid and g.name <> invalid and g.name <> "" then
            parts.Push(g.name)
            if parts.Count() >= maxGenres then exit for
        end if
    end for
    if parts.Count() = 0 then return ""
    line = ""
    for i = 0 to parts.Count() - 1
        if i > 0 then line = line + "  ·  "
        line = line + parts[i]
    end for
    return line
end function

function HeroOttGenreLine(item as object) as string
    line = HeroGenreLine(item, 5)
    if item = invalid then return line
  ' Parity banner/index.tsx: genres + discretion with comma separator.
    if item.discretion <> invalid and item.discretion <> "" then
        if line <> "" then
            line = line + ",  ·  " + item.discretion
        else
            line = item.discretion
        end if
    end if
    return line
end function

function HeroQualityLabel(item as object) as string
    if item = invalid or item.quality = invalid then return ""
    q = item.quality
    if q = invalid or q = "" then return ""
    return UCase(q)
end function

sub HeroApplyQualityBadge(item as object, qualityBadge as object, qualityBg as object, qualityLabel as object)
    if qualityBadge = invalid then return
    q = HeroQualityLabel(item)
    if q = "" then
        qualityBadge.visible = false
        return
    end if
    if qualityLabel <> invalid then qualityLabel.text = q
    w = Len(q) * 11 + 28
    if w < 56 then w = 56
    if qualityBg <> invalid then qualityBg.width = w
    if qualityLabel <> invalid then qualityLabel.width = w
    qualityBadge.visible = true
end sub

sub HeroApplyMaturityBadge(item as object, maturityBadge as object, maturityLabel as object)
    if maturityBadge = invalid then return
    m = ""
    if item <> invalid and item.maturityRating <> invalid then m = item.maturityRating
    if m = "" then
        maturityBadge.visible = false
        return
    end if
    if maturityLabel <> invalid then maturityLabel.text = m
    w = Len(m) * 10 + 24
    if w < 44 then w = 44
    maturityBadge.visible = true
end sub

' IMDB star rating (parity StarRating in heroBanner.tsx / banner/index.tsx).
sub HeroBuildStars(item as object, ratingHost as object, ratingLabel as object, primaryColor as string)
    if ratingHost = invalid then return
    for i = ratingHost.getChildCount() - 1 to 1 step -1
        ratingHost.removeChildIndex(i)
    end for

    imdb = invalid
    if item <> invalid and item.imdb <> invalid then imdb = item.imdb
    if imdb = invalid or FormatHeroRating(imdb) = "" then
        ratingHost.visible = false
        return
    end if

    if ratingLabel <> invalid then ratingLabel.text = FormatHeroRating(imdb)
    normalized = HeroStarRating(imdb)
    full = Int(normalized)
    half = 0
    if (normalized - full) >= 0.5 then half = 1
    blank = 5 - full - half
    if blank < 0 then blank = 0

    blankColor = "0x31383Aff"
    starUri = "pkg:/images/ui/star.png"
    sz = 22
    for i = 1 to full
        HeroAppendStar(ratingHost, starUri, sz, "full", primaryColor, blankColor)
    end for
    if half = 1 then HeroAppendStar(ratingHost, starUri, sz, "half", primaryColor, blankColor)
    for i = 1 to blank
        HeroAppendStar(ratingHost, starUri, sz, "blank", primaryColor, blankColor)
    end for
    ratingHost.visible = true
end sub

sub HeroAppendStar(host as object, starUri as string, sz as integer, kind as string, primaryColor as string, blankColor as string)
    if kind = "half" then
        g = host.createChild("Group")
        base = g.createChild("Poster")
        base.uri = starUri
        base.width = sz
        base.height = sz
        base.blendColor = blankColor
        clip = g.createChild("Group")
        clip.clippingRect = [0, 0, sz / 2, sz]
        clip.clippingRectClipsChildren = true
        fill = clip.createChild("Poster")
        fill.uri = starUri
        fill.width = sz
        fill.height = sz
        fill.blendColor = primaryColor
        return
    end if

    p = host.createChild("Poster")
    p.uri = starUri
    p.width = sz
    p.height = sz
    if kind = "full" then
        p.blendColor = primaryColor
    else
        p.blendColor = blankColor
    end if
end sub

sub HeroApplyMeta(item as object, titleLabel as object, ratingHost as object, ratingLabel as object, genreLabel as object, qualityBadge as object, qualityLabel as object, descLabel as object, primaryColor as string, qualityBg as object)
    if item = invalid then
        if titleLabel <> invalid then titleLabel.text = ""
        if ratingHost <> invalid then ratingHost.visible = false
        if genreLabel <> invalid then genreLabel.text = ""
        if qualityBadge <> invalid then qualityBadge.visible = false
        if descLabel <> invalid then descLabel.text = ""
        return
    end if

    title = ""
    if item.title <> invalid then title = item.title
    if title = "" and item.name <> invalid then title = item.name
    if titleLabel <> invalid then titleLabel.text = HeroTruncate(title, 48)

    HeroBuildStars(item, ratingHost, ratingLabel, primaryColor)

    if genreLabel <> invalid then genreLabel.text = HeroGenreLine(item, 4)

    HeroApplyQualityBadge(item, qualityBadge, qualityBg, qualityLabel)

    desc = ""
    if item.description <> invalid then desc = item.description
    if descLabel <> invalid then descLabel.text = HeroTruncate(desc, 160)
end sub

sub HeroApplyOttMeta(item as object, titleLabel as object, ratingHost as object, ratingLabel as object, genreLabel as object, qualityBadge as object, qualityLabel as object, descLabel as object, primaryColor as string, qualityBg as object, maturityBadge as object, maturityLabel as object)
    if item = invalid then
        if titleLabel <> invalid then titleLabel.text = ""
        if ratingHost <> invalid then ratingHost.visible = false
        if genreLabel <> invalid then genreLabel.text = ""
        if qualityBadge <> invalid then qualityBadge.visible = false
        if descLabel <> invalid then descLabel.text = ""
        return
    end if

    title = ""
    if item.title <> invalid then title = item.title
    if title = "" and item.name <> invalid then title = item.name
    if titleLabel <> invalid then titleLabel.text = title

    HeroBuildStars(item, ratingHost, ratingLabel, primaryColor)
    if genreLabel <> invalid then genreLabel.text = HeroOttGenreLine(item)
    HeroApplyQualityBadge(item, qualityBadge, qualityBg, qualityLabel)
    HeroApplyMaturityBadge(item, maturityBadge, maturityLabel)

    desc = ""
    if item.description <> invalid then desc = item.description
    if descLabel <> invalid then descLabel.text = HeroTruncate(desc, 180)
end sub
