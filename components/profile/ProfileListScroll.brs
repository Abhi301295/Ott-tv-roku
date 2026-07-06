' ProfileListScroll.brs — vertical list scroll animation for profile avatars.


sub UpdateProfileListScrollTarget()
    if m.rowTops = invalid or m.rowTops.Count() = 0 then
        m.listScrollTarget = 0
        return
    end if
    if m.listScrollTarget = invalid then m.listScrollTarget = 0

    viewH = ProfileListViewportHeight()
    padY = ProfileListTopY()
    if m.listContentPadY <> invalid and m.listContentPadY > 0 then padY = m.listContentPadY
    target = m.listScrollY
    if target = invalid then target = 0

    if m.focusArea = "profiles" and m.profileIndex >= 0 and m.profileIndex < m.rowTops.Count() then
        idx = m.profileIndex
        rowTop = m.rowTops[idx]
        rowBottom = rowTop + ProfileAvatarRowHeight(idx)
        visTop = rowTop - target
        visBottom = rowBottom - target
        if visTop < padY then
            target = rowTop - padY
        else if visBottom > padY + viewH then
            target = rowBottom - padY - viewH
        end if
    end if

    contentH = m.listContentHeight
    if contentH = invalid then contentH = padY
    maxScroll = contentH - padY - viewH
    if maxScroll < 0 then maxScroll = 0
    if target > maxScroll then target = maxScroll
    if target < 0 then target = 0
    m.listScrollTarget = target
end sub


sub AnimateProfileListScroll()
    if m.profilesContainer = invalid then return
    if m.listScrollTarget = invalid then m.listScrollTarget = 0
    if m.listScrollY = invalid then m.listScrollY = 0

    delta = m.listScrollTarget - m.listScrollY
    if delta < 0 then delta = -delta
    if delta < 1 then
        m.listScrollY = m.listScrollTarget
        m.profilesContainer.translation = [0, -m.listScrollY]
        if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
        return
    end if

    m.listScrollAnimFrom = m.listScrollY
    m.listScrollAnimTo = m.listScrollTarget
    m.listScrollAnimStep = 0
    if m.listScrollAnimTimer <> invalid then
        m.listScrollAnimTimer.control = "stop"
        m.listScrollAnimTimer.control = "start"
    end if
end sub


sub OnListScrollAnimTick()
    if m.profilesContainer = invalid then return
    m.listScrollAnimStep = m.listScrollAnimStep + 1
    t = m.listScrollAnimStep / m.LIST_SCROLL_ANIM_STEPS
    if t > 1.0 then t = 1.0

    inv = 1.0 - t
    eased = 1.0 - (inv * inv * inv)
    y = m.listScrollAnimFrom + ((m.listScrollAnimTo - m.listScrollAnimFrom) * eased)
    m.listScrollY = y
    m.profilesContainer.translation = [0, -m.listScrollY]

    if t >= 1.0 and m.listScrollAnimTimer <> invalid then
        m.listScrollAnimTimer.control = "stop"
        m.listScrollY = m.listScrollTarget
        m.profilesContainer.translation = [0, -m.listScrollY]
    end if
end sub


sub ApplyProfileListScrollSnap()
    UpdateProfileListScrollTarget()
    if m.listScrollTarget = invalid then m.listScrollTarget = 0
    m.listScrollY = m.listScrollTarget
    if m.listScrollAnimTimer <> invalid then m.listScrollAnimTimer.control = "stop"
    if m.profilesContainer <> invalid then m.profilesContainer.translation = [0, -m.listScrollY]
end sub


' Brief scroll glide on focus move; retargets each keypress for snappy navigation.
sub FollowProfileListScroll()
    UpdateProfileListScrollTarget()
    AnimateProfileListScroll()
end sub
