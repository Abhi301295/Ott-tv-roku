' UpNextLayout.brs — exact heroBanner.tsx Up Next dimensions (do not change).

function UN_W() as integer
    return 155
end function

function UN_H() as integer
    return 220
end function

function UN_RIGHT() as integer
    return 28
end function

function UN_TOP_Y(heroH as integer) as integer
    ' top: 28% of hero container
    return Int(heroH * 0.28 + 0.5)
end function

function UN_HOST_X(screenW as integer) as integer
    return screenW - UN_RIGHT() - UN_W()
end function

function UN_LABEL_H() as integer
    return 14
end function

function UN_LABEL_MB() as integer
    return 8
end function

function UN_CARD_Y() as integer
    return UN_LABEL_H() + UN_LABEL_MB()
end function

function UN_TITLE_LEFT() as integer
    return 14
end function

function UN_TITLE_RIGHT() as integer
    return 6
end function

function UN_TITLE_BOTTOM() as integer
    return 10
end function

function UN_TITLE_W() as integer
    return UN_W() - UN_TITLE_LEFT() - UN_TITLE_RIGHT()
end function

function UN_TITLE_Y() as integer
    return UN_H() - UN_TITLE_BOTTOM() - 20
end function

function UN_SHADOW_OX() as integer
    return -6
end function

function UN_SHADOW_OY() as integer
    return 4
end function

function UN_CORNER_R() as integer
    return 14
end function

function UN_TLX() as float
    return UN_W() * 0.18
end function

function UN_BLX() as float
    return UN_W() * 0.04
end function

function UN_STRIP_COUNT() as integer
    return 44
end function

' Left edge of cutout at y (polygon 18% top → 4% bottom).
function UN_LeftX(y as float) as float
    return UN_TLX() + (UN_BLX() - UN_TLX()) * (y / UN_H())
end function

' Right edge including 14px top-right / bottom-right arcs.
function UN_RightX(y as float) as float
    r = UN_CORNER_R()
    w = UN_W()
    h = UN_H()
    cx = w - r
    if y < r then
        dy = r - y
        return cx + Sqr(r * r - dy * dy)
    else if y > h - r then
        dy = y - (h - r)
        return cx + Sqr(r * r - dy * dy)
    end if
    return w
end function
