sub init()
    m.scaler = m.top.findNode("scaler")
    m.avatarMask = m.top.findNode("avatarMask")
    m.circleBg = m.top.findNode("circleBg")
    m.avatarImg = m.top.findNode("avatarImg")
    m.initials = m.top.findNode("initials")
    m.ring = m.top.findNode("ring")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressArcRing = m.top.findNode("progressArcRing")
    m.dot = m.top.findNode("dot")
    m.lockBadge = m.top.findNode("lockBadge")
    m.editBadge = m.top.findNode("editBadge")
    m.editIcon = m.top.findNode("editIcon")
    m.leftLockIcon = m.top.findNode("leftLockIcon")
    m.nameLabel = m.top.findNode("nameLabel")
    m.hintLabel = m.top.findNode("hintLabel")
    m.focusAnim = m.top.findNode("focusAnim")
    m.focusInterp = m.top.findNode("focusInterp")
    m.offsetInterp = m.top.findNode("offsetInterp")
    m.sizeAnimTimer = m.top.findNode("sizeAnimTimer")

    ' OTTPlay React parity: focused profile wrapper uses origin-left scale-125.
    m.FOCUS_SCALE = 1.25
    m.REST_SCALE = 1.0
    ' Focused profile also pops out of the rail a little to the right; all
    ' unfocused profiles return to x=0 so the default column stays aligned.
    m.FOCUS_OFFSET_X = 34.0
    m.REST_OFFSET_X = 0.0
    m.SIZE_ANIM_STEPS = 10
    m.DEFOCUS_ANIM_STEPS = 4
    m.animStepCount = m.SIZE_ANIM_STEPS
    m.visualScale = m.REST_SCALE
    m.visualOffsetX = m.REST_OFFSET_X

    m.top.focusable = true
    m.top.drawFocusFeedback = false
    ' Manual sizing uses a left-center anchor: grow rightward while vertical growth
    ' stays centered in the profile row, matching React's origin-left transform.
    m.scaler.scaleRotateCenter = [0, 0]
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.observeField("fire", "OnSizeAnimTick")

    OnColorsChanged()
    OnPortalColorsChanged()
    OnDataChanged()
    OnHintChanged()
    OnFocusChanged()
end sub

sub OnColorsChanged()
    if m.ring = invalid then return
    m.ring.blendColor = m.top.ringColor
    m.nameLabel.color = m.top.nameColor
end sub

sub OnPortalColorsChanged()
    if m.progressArcRing = invalid then return
    m.progressArcRing.portalPrimary = m.top.portalPrimary
    m.progressArcRing.portalSecondary = m.top.portalSecondary
    m.progressArcRing.portalTertiary = m.top.portalTertiary
end sub

sub OnDataChanged()
    if m.avatarImg = invalid then return
    uri = m.top.avatarUri
    if uri <> invalid and uri <> "" then
        m.avatarImg.uri = uri
        m.avatarImg.visible = true
        m.initials.text = ""
    else
        m.avatarImg.visible = false
        m.initials.text = m.top.initials
    end if
    m.nameLabel.text = m.top.profileName
end sub

sub OnHintChanged()
    if m.hintLabel = invalid then return
    txt = m.top.hintText
    m.hintLabel.text = txt
    m.hintLabel.visible = (m.top.focusedState = true and txt <> "")
end sub

sub OnFocusChanged()
    if m.ring = invalid then return
    focused = (m.top.focusedState = true)
    locked = (m.top.parentalLock = true)
    progress = m.top.progress

    ' Unlocked + focused once auto-select starts → filling multicolor arc + track.
    ' Otherwise (just focused, or locked) → static white ring + dot.
    showArc = (focused and not locked and progress > 0)

    if focused then
        m.circleBg.visible = true
    else
        m.circleBg.visible = false
    end if

    m.progressTrack.visible = showArc
    if m.progressArcRing <> invalid then
        m.progressArcRing.visible = showArc
        if showArc then
            last = ProfileArcFrameCount() - 1
            idx = Int(progress * last + 0.5)
            m.progressArcRing.arcFrame = idx
        end if
    end if

    m.ring.visible = (focused and not showArc)
    m.dot.visible = (focused and not showArc)
    ' React shows a left badge on focus: edit icon for unlocked, lock icon for locked.
    showBadge = (focused and (progress = 0 or locked))
    m.editBadge.visible = showBadge
    m.editIcon.visible = (showBadge and not locked)
    m.leftLockIcon.visible = (showBadge and locked)
    m.lockBadge.visible = false
    ' Match current OTTPlay React/LG visual pass: profile rail shows only avatars
    ' and focus affordances, not side labels.
    m.nameLabel.visible = false
    m.hintLabel.visible = false

    AnimateScale(focused)
end sub

' Focus in: ~300ms ease-out (React duration-300). Focus out: shorter ease on the row
' just left; skipped rows snap so rapid up/down does not snake.
sub AnimateScale(focused as boolean)
    target = m.REST_SCALE
    targetX = m.REST_OFFSET_X
    if focused then
        target = m.FOCUS_SCALE
        targetX = m.FOCUS_OFFSET_X
    end if

    if m.visualScale = invalid then m.visualScale = m.REST_SCALE
    if m.visualOffsetX = invalid then m.visualOffsetX = m.REST_OFFSET_X

    if m.lastScale = invalid then
        ApplyAvatarSize(target)
        m.scaler.scale = [1.0, 1.0]
        m.scaler.translation = [targetX, SizeOffsetY(target)]
        m.visualScale = target
        m.visualOffsetX = targetX
        m.lastScale = target
        m.lastOffsetX = targetX
        return
    end if

    if not focused then
        if m.top.snapRest = true then
            m.top.snapRest = false
            SnapAvatarToRest()
            return
        end if
        fromScale = m.visualScale
        fromX = m.visualOffsetX
        if fromScale = target and fromX = targetX then return
        StartSizeAnimation(fromScale, target, fromX, targetX, m.DEFOCUS_ANIM_STEPS)
        m.lastScale = target
        m.lastOffsetX = targetX
        return
    end if

    m.top.snapRest = false
    fromScale = m.visualScale
    fromX = m.visualOffsetX
    if fromScale = target and fromX = targetX then return

    StartSizeAnimation(fromScale, target, fromX, targetX, m.SIZE_ANIM_STEPS)
    m.lastScale = target
    m.lastOffsetX = targetX
end sub

sub SnapAvatarToRest()
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
    ApplyAvatarSize(m.REST_SCALE)
    m.scaler.scale = [1.0, 1.0]
    m.scaler.translation = [m.REST_OFFSET_X, SizeOffsetY(m.REST_SCALE)]
    m.visualScale = m.REST_SCALE
    m.visualOffsetX = m.REST_OFFSET_X
    m.lastScale = m.REST_SCALE
    m.lastOffsetX = m.REST_OFFSET_X
end sub

sub StartSizeAnimation(fromScale as float, toScale as float, fromX as float, toX as float, steps as integer)
    m.animFromScale = fromScale
    m.animToScale = toScale
    m.animFromX = fromX
    m.animToX = toX
    m.animStep = 0
    m.animStepCount = steps
    if m.sizeAnimTimer <> invalid then
        m.sizeAnimTimer.control = "stop"
        m.sizeAnimTimer.control = "start"
    else
        ApplyAvatarSize(toScale)
        m.scaler.translation = [toX, SizeOffsetY(toScale)]
    end if
end sub

sub OnSizeAnimTick()
    m.animStep = m.animStep + 1
    steps = m.SIZE_ANIM_STEPS
    if m.animStepCount <> invalid and m.animStepCount > 0 then steps = m.animStepCount
    t = m.animStep / steps
    if t > 1.0 then t = 1.0

    ' Ease out cubic for the same "pop" feel as the React transition.
    inv = 1.0 - t
    eased = 1.0 - (inv * inv * inv)
    scale = m.animFromScale + ((m.animToScale - m.animFromScale) * eased)
    x = m.animFromX + ((m.animToX - m.animFromX) * eased)

    m.visualScale = scale
    m.visualOffsetX = x
    ApplyAvatarSize(scale)
    m.scaler.scale = [1.0, 1.0]
    m.scaler.translation = [x, SizeOffsetY(scale)]

    if t >= 1.0 and m.sizeAnimTimer <> invalid then
        m.sizeAnimTimer.control = "stop"
    end if
end sub

function SizeOffsetY(scale as float) as float
    return -((166 * scale) - 166) / 2
end function

sub ApplyAvatarSize(scale as float)
    ringSize = 166 * scale
    avatarSize = 150 * scale
    inset = 8 * scale

    if m.avatarMask <> invalid then
        m.avatarMask.maskSize = [avatarSize, avatarSize]
        m.avatarMask.maskOffset = [inset, inset]
    end if

    for each node in [m.circleBg, m.avatarImg, m.initials]
        if node <> invalid then
            node.translation = [inset, inset]
            node.width = avatarSize
            node.height = avatarSize
        end if
    end for

    for each node in [m.ring, m.progressTrack]
        if node <> invalid then
            node.translation = [0, 0]
            node.width = ringSize
            node.height = ringSize
        end if
    end for
    if m.progressArcRing <> invalid then
        m.progressArcRing.translation = [0, 0]
        m.progressArcRing.ringSize = ringSize
    end if

    if m.dot <> invalid then
        m.dot.translation = [74 * scale, 158 * scale]
        m.dot.width = 18 * scale
        m.dot.height = 18 * scale
    end if

    if m.lockBadge <> invalid then
        m.lockBadge.translation = [69 * scale, 150 * scale]
        m.lockBadge.width = 28 * scale
        m.lockBadge.height = 28 * scale
    end if
end sub

