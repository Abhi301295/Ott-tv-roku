sub init()
    m.scaler = m.top.findNode("scaler")
    m.selectingGroup = m.top.findNode("selectingGroup")
    m.skA = m.top.findNode("skA")
    m.skB = m.top.findNode("skB")
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
    m.editBadgeBg = m.top.findNode("editBadgeBg")
    m.leftLockIcon = m.top.findNode("leftLockIcon")
    m.editFocusBtn = m.top.findNode("editFocusBtn")
    m.editFocusBorder = m.top.findNode("editFocusBorder")
    m.editFocusBg = m.top.findNode("editFocusBg")
    m.editFocusIcon = m.top.findNode("editFocusIcon")
    m.nameLabel = m.top.findNode("nameLabel")
    m.hintLabel = m.top.findNode("hintLabel")
    m.focusAnim = m.top.findNode("focusAnim")
    m.focusInterp = m.top.findNode("focusInterp")
    m.offsetInterp = m.top.findNode("offsetInterp")
    m.sizeAnimTimer = m.top.findNode("sizeAnimTimer")
    m.editScaleTimer = m.top.findNode("editScaleTimer")
    m.editBorderFlashTimer = m.top.findNode("editBorderFlashTimer")

    ' userProfile.tsx: profile wrapper scale-125 only when PROFILE focused (not edit).
    ' Edit control sits left with ml-4 + gap-6; avatar column starts after that gap.
    m.FOCUS_SCALE = 1.25
    m.REST_SCALE = 1.0
    m.EDIT_FOCUS_SCALE = 1.25
    m.EDIT_REST_SCALE = 1.0
    m.EDIT_SCALE_STEPS = 18
    m.EDIT_BTN_SIZE = 48
    m.EDIT_ICON_SIZE = 20
    m.editVisualScale = m.EDIT_REST_SCALE
    m.editBorderFlash = false
    m.wasEditFocused = false
    spec = ProfileUiSpec()
    m.AVATAR_COLUMN_X = spec.editFocusX + spec.editFocusSize + spec.editFocusGap
    m.FOCUS_POP_X = 34.0
    m.REST_OFFSET_X = m.AVATAR_COLUMN_X
    m.FOCUS_OFFSET_X = m.AVATAR_COLUMN_X + m.FOCUS_POP_X
    m.SIZE_ANIM_STEPS = 10
    m.DEFOCUS_ANIM_STEPS = 4
    m.animStepCount = m.SIZE_ANIM_STEPS
    m.visualScale = m.REST_SCALE
    m.visualOffsetX = m.REST_OFFSET_X

    m.top.focusable = true
    m.top.drawFocusFeedback = false
    m.scaler.scaleRotateCenter = [0, 0]
    if m.selectingGroup <> invalid then m.selectingGroup.scaleRotateCenter = [0, 0]
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.observeField("fire", "OnSizeAnimTick")
    if m.editScaleTimer <> invalid then m.editScaleTimer.observeField("fire", "OnEditScaleTick")
    if m.editBorderFlashTimer <> invalid then m.editBorderFlashTimer.observeField("fire", "OnEditBorderFlashEnd")

    OnColorsChanged()
    OnPortalColorsChanged()
    OnDataChanged()
    OnHintChanged()
    ApplyEditFocusBtnLayout()
    OnFocusChanged()
end sub

sub OnSelectingChanged()
    show = (m.top.selectingState = true)
    if m.nameLabel <> invalid then m.nameLabel.visible = (not show and m.top.focusedState = true)
    if m.hintLabel <> invalid then
        if show then
            m.hintLabel.visible = false
        else
            m.hintLabel.visible = (m.top.focusedState = true and m.top.hintText <> "")
        end if
    end if
    if show then
        ' Freeze focus scale so size-anim ticks cannot keep restarting the skeleton shimmer.
        SnapSelectingFocusScale()
    end if
    if m.selectingGroup <> invalid then
        m.selectingGroup.visible = show
        if show then
            if m.skA <> invalid then m.skA.running = true
            if m.skB <> invalid then m.skB.running = true
            SyncSelectingSkeletonScale()
            OnSkColorsChanged()
        else
            m.selectingGroup.scale = [1.0, 1.0]
        end if
    end if
    if m.skA <> invalid then m.skA.running = show
    if m.skB <> invalid then m.skB.running = show
    if show then
        HideAvatarForSelecting()
    else
        ShowAvatarAfterSelecting()
    end if
end sub

' Selecting skeleton is static-size; stop focus scale animation so layout churn does not
' restart ProfileSkeletonBox shimmer while select/prefetch runs.
sub SnapSelectingFocusScale()
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
    scale = m.REST_SCALE
    x = m.REST_OFFSET_X
    if m.top.focusedState = true then
        scale = m.FOCUS_SCALE
        x = m.FOCUS_OFFSET_X
    end if
    m.visualScale = scale
    m.visualOffsetX = x
    m.lastScale = scale
    m.lastOffsetX = x
    ApplyAvatarSize(scale)
    if m.scaler <> invalid then
        m.scaler.scale = [1.0, 1.0]
        m.scaler.translation = [x, SizeOffsetY(scale)]
    end if
end sub

sub HideAvatarForSelecting()
    for each node in [m.avatarMask, m.ring, m.progressTrack, m.progressArcRing, m.dot, m.editBadge, m.editFocusBtn, m.circleBg]
        if node <> invalid then node.visible = false
    end for
end sub

sub ShowAvatarAfterSelecting()
    if m.avatarMask <> invalid then m.avatarMask.visible = true
    ApplyFocusChrome()
end sub

function RefreshFocusChrome() as boolean
    if m.top.selectingState = true then return true
    ApplyFocusChrome()
    ' Chrome-only refresh — do not restart row scale animation (column may already be scaled).
    return true
end function

' Sized to match ApplyAvatarSize — bake focus scale into skeleton dims (same as avatar chrome).
sub SyncSelectingSkeletonScale()
    if m.selectingGroup = invalid then return
    scale = SelectingSkeletonScale()
    m.selectingGroup.scale = [1.0, 1.0]
    ApplySelectingSkeletonLayout(scale)
end sub

function SelectingSkeletonScale() as float
    scale = m.visualScale
    if scale < m.REST_SCALE then scale = m.REST_SCALE
    if m.top.selectingState = true and m.top.focusedState = true and scale < m.FOCUS_SCALE then
        scale = m.FOCUS_SCALE
    end if
    return scale
end function

function ScaleInt(v as float) as integer
    return Int(v + 0.5)
end function

sub ApplySelectingSkeletonLayout(scale as float)
    spec = ProfileUiSpec()
    inset = 8 * scale
    skAx = ScaleInt(inset)
    skAy = ScaleInt(inset)
    nameW = spec.skNameWidth
    nameH = spec.skNameHeight
    marginL = spec.skNameMarginLeft
    avatarSz = spec.skAvatarSize
    nameY = ScaleInt((spec.skRowHeight * scale - nameH * scale) / 2.0)
    nameX = skAx + ScaleInt(avatarSz * scale) + ScaleInt(marginL * scale)

    if m.skA <> invalid then
        m.skA.layoutScale = scale
        m.skA.translation = [skAx, skAy]
        m.skA.boxWidth = avatarSz
        m.skA.boxHeight = avatarSz
        m.skA.glowKind = "avatar"
        m.skA.shapeUri = SkeletonProfileAvatarShapeUri(false)
        m.skA.glowVisible = false
    end if

    if m.skB <> invalid then
        m.skB.visible = true
        m.skB.layoutScale = scale
        m.skB.translation = [nameX, nameY]
        m.skB.boxWidth = nameW
        m.skB.boxHeight = nameH
        m.skB.glowKind = "pill"
        m.skB.shapeUri = SkeletonProfileNameShapeUri()
        m.skB.glowVisible = false
    end if
end sub

sub OnSkColorsChanged()
    if m.skA <> invalid then
        m.skA.baseColor = m.top.skBaseColor
        m.skA.highlightColor = m.top.skHighlightColor
    end if
    if m.skB <> invalid then
        m.skB.baseColor = m.top.skBaseColor
        m.skB.highlightColor = m.top.skHighlightColor
    end if
    if m.top.selectingState = true then SyncSelectingSkeletonScale()
end sub

sub OnColorsChanged()
    if m.ring = invalid then return
    m.ring.blendColor = m.top.ringColor
    m.nameLabel.color = m.top.nameColor
    ApplyFocusChrome()
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
    ' PIN / auto-select hint only on PROFILE column (React: focused && …).
    showHint = (m.top.selectingState <> true and m.top.focusedState = true and m.top.editFocused <> true and txt <> "")
    m.hintLabel.visible = showHint
end sub

sub OnFocusChanged()
    if m.ring = invalid then return
    ApplyFocusChrome()
    if m.top.selectingState = true then return
    ' Profile column scales only when PROFILE focused. Edit column has its own scale.
    ' Column nav (Left/Right) snaps; row nav (Up/Down) animates restore→scale.
    if m.top.scaleSnap = true then
        m.top.scaleSnap = false
        SnapAvatarScale(m.top.focusedState = true)
    else
        AnimateScale(m.top.focusedState = true)
    end if
end sub

' Ring / name / badges follow PROFILE column only (netComponent.tsx `focused`).
' Left edit follows profile OR edit column. Never show profile ring while edit owns focus.
sub ApplyFocusChrome()
    if m.ring = invalid then return
    if m.top.selectingState = true then return
    focused = (m.top.focusedState = true)
    editFocused = (m.top.editFocused = true)
    ' Profile chrome only when PROFILE column owns focus — not during edit (or both-true overlap).
    profileChrome = (focused and not editFocused)
    locked = (m.top.parentalLock = true)
    progress = m.top.progress
    showArc = (profileChrome and not locked and progress > 0)

    if m.circleBg <> invalid then m.circleBg.visible = profileChrome
    m.progressTrack.visible = showArc
    if m.progressArcRing <> invalid then
        m.progressArcRing.visible = showArc
        if showArc then
            last = ProfileArcFrameCount() - 1
            idx = Int(progress * last + 0.5)
            m.progressArcRing.arcFrame = idx
        else
            m.progressArcRing.arcFrame = 0
        end if
    end if

    ' White focus ring + bottom dot (screenshot without auto-select arc).
    m.ring.visible = (profileChrome and not showArc)
    m.dot.visible = (profileChrome and not showArc)

    canEdit = true
    if m.top.hasField("showEditBadge") then canEdit = (m.top.showEditBadge = true)

    showLeftEdit = (canEdit and (focused or editFocused))
    if m.editFocusBtn <> invalid then m.editFocusBtn.visible = showLeftEdit
    ApplyEditFocusBtnStyle(focused, editFocused, showLeftEdit)

    showLockBadge = (profileChrome and locked)
    if m.editBadge <> invalid then m.editBadge.visible = showLockBadge
    if m.editIcon <> invalid then m.editIcon.visible = false
    if m.leftLockIcon <> invalid then m.leftLockIcon.visible = showLockBadge
    if m.editBadgeBg <> invalid and showLockBadge then
        m.editBadgeBg.blendColor = m.top.ringColor
        m.editBadge.scale = [1.0, 1.0]
    end if

    m.lockBadge.visible = false
    if profileChrome then
        m.nameLabel.visible = true
        if m.hintLabel <> invalid then m.hintLabel.visible = (m.top.hintText <> "")
    else
        m.nameLabel.visible = false
        if m.hintLabel <> invalid then
            m.hintLabel.visible = false
            m.hintLabel.text = ""
        end if
    end if
end sub

' Edit column: rest when profile focused; layout-size scale-125 when edit focused.
' ⚠ Parity Note: SceneGraph Group.scale on this control vanishes in the sim — grow via width/height.
sub ApplyEditFocusBtnStyle(focused as boolean, editFocused as boolean, visible as boolean)
    if m.editFocusBtn = invalid then return
    if not visible then
        StopEditScaleAnim()
        m.editVisualScale = m.EDIT_REST_SCALE
        m.editFocusBtn.scale = [1.0, 1.0]
        ApplyEditFocusBtnSize(m.EDIT_REST_SCALE)
        m.editBorderFlash = false
        m.wasEditFocused = false
        if m.editBorderFlashTimer <> invalid then m.editBorderFlashTimer.control = "stop"
        if m.editFocusBorder <> invalid then m.editFocusBorder.visible = false
        return
    end if

    bg = m.top.cNeutral800
    if bg = invalid or bg = "" then bg = "0x262626ff"
    border = m.top.ringColor
    if border = invalid or border = "" then border = "0xffffffff"
    icon = m.top.cNeutral400
    if icon = invalid or icon = "" then icon = "0xc8c8c8ff"
    targetScale = m.EDIT_REST_SCALE
    showBorder = false

    if editFocused then
        bg = m.top.portalPrimary
        icon = "0xffffffff"
        targetScale = m.EDIT_FOCUS_SCALE
        ' Brief white ring on the edit control itself (React class overlap), not the avatar ring.
        if m.wasEditFocused <> true then StartEditBorderFlash()
        showBorder = (m.editBorderFlash = true)
    else if focused then
        showBorder = true
        border = m.top.cNeutral600
        if border = invalid or border = "" then border = "0x3d3d3dff"
    end if
    m.wasEditFocused = editFocused

    if m.editFocusBg <> invalid then m.editFocusBg.blendColor = bg
    if m.editFocusBorder <> invalid then
        m.editFocusBorder.visible = showBorder
        m.editFocusBorder.blendColor = border
    end if
    if m.editFocusIcon <> invalid then m.editFocusIcon.blendColor = icon
    AnimateEditScale(targetScale)
    print "[PROFILE_EDIT_DBG] colEdit editFocused=" + editFocused.ToStr() + " editScale=" + targetScale.ToStr() + " colProfile=" + focused.ToStr() + " border=" + showBorder.ToStr()
end sub

sub StartEditBorderFlash()
    m.editBorderFlash = true
    if m.editBorderFlashTimer <> invalid then
        m.editBorderFlashTimer.control = "stop"
        m.editBorderFlashTimer.control = "start"
    end if
end sub

sub OnEditBorderFlashEnd()
    m.editBorderFlash = false
    if m.top.editFocused = true then
        ApplyEditFocusBtnStyle(m.top.focusedState = true, true, true)
    end if
end sub

' Grow/shrink the edit circle by layout size (keeps visual center at rest 48×48 slot).
sub ApplyEditFocusBtnSize(scale as float)
    if m.editFocusBtn = invalid then return
    m.editFocusBtn.scale = [1.0, 1.0]
    btn = m.EDIT_BTN_SIZE * scale
    icon = m.EDIT_ICON_SIZE * scale
    ' Rest slot is 48×48 at translation editFocusX/Y; expand around center.
    rest = m.EDIT_BTN_SIZE
    ox = (rest - btn) / 2.0
    oy = (rest - btn) / 2.0
    spec = ProfileUiSpec()
    m.editFocusBtn.translation = [spec.editFocusX + ox, spec.editFocusY + oy]

    if m.editFocusBg <> invalid then
        m.editFocusBg.translation = [0, 0]
        m.editFocusBg.width = btn
        m.editFocusBg.height = btn
    end if
    if m.editFocusBorder <> invalid then
        m.editFocusBorder.translation = [-1 * scale, -1 * scale]
        m.editFocusBorder.width = btn + 2 * scale
        m.editFocusBorder.height = btn + 2 * scale
    end if
    if m.editFocusIcon <> invalid then
        pad = (btn - icon) / 2.0
        m.editFocusIcon.translation = [pad, pad]
        m.editFocusIcon.width = icon
        m.editFocusIcon.height = icon
    end if
end sub

sub AnimateEditScale(targetScale as float)
    if m.editFocusBtn = invalid then return
    if m.editVisualScale = invalid then m.editVisualScale = m.EDIT_REST_SCALE
    delta = m.editVisualScale - targetScale
    if delta < 0 then delta = -delta
    if delta < 0.01 then
        m.editVisualScale = targetScale
        ApplyEditFocusBtnSize(targetScale)
        return
    end if
    m.editAnimFrom = m.editVisualScale
    m.editAnimTo = targetScale
    m.editAnimStep = 0
    if m.editScaleTimer <> invalid then
        m.editScaleTimer.control = "stop"
        m.editScaleTimer.control = "start"
    else
        m.editVisualScale = targetScale
        ApplyEditFocusBtnSize(targetScale)
    end if
end sub

sub StopEditScaleAnim()
    if m.editScaleTimer <> invalid then m.editScaleTimer.control = "stop"
end sub

sub OnEditScaleTick()
    if m.editFocusBtn = invalid then
        StopEditScaleAnim()
        return
    end if
    m.editAnimStep = m.editAnimStep + 1
    steps = m.EDIT_SCALE_STEPS
    t = m.editAnimStep / steps
    if t > 1.0 then t = 1.0
    inv = 1.0 - t
    eased = 1.0 - (inv * inv * inv)
    scale = m.editAnimFrom + ((m.editAnimTo - m.editAnimFrom) * eased)
    m.editVisualScale = scale
    ApplyEditFocusBtnSize(scale)
    if t >= 1.0 then StopEditScaleAnim()
end sub

sub ApplyEditFocusBtnLayout()
    if m.editFocusBtn = invalid then return
    ApplyEditFocusBtnSize(m.EDIT_REST_SCALE)
end sub

' Instant profile-column scale (column Left/Right). Row Up/Down uses AnimateScale instead.
sub SnapAvatarScale(focused as boolean)
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
    scale = m.REST_SCALE
    x = m.REST_OFFSET_X
    if focused then
        scale = m.FOCUS_SCALE
        x = m.FOCUS_OFFSET_X
    end if
    m.visualScale = scale
    m.visualOffsetX = x
    m.lastScale = scale
    m.lastOffsetX = x
    ApplyAvatarSize(scale)
    if m.scaler <> invalid then
        m.scaler.scale = [1.0, 1.0]
        m.scaler.translation = [x, SizeOffsetY(scale)]
    end if
    ApplyNameRevealLayout(scale)
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
    if m.top.selectingState = true then
        if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
        SnapSelectingFocusScale()
        SyncSelectingSkeletonScale()
        return
    end if
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
    ApplyNameRevealLayout(scale)

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
    ApplyEditBadgeLayout(scale)
    ApplyNameRevealLayout(scale)
end sub

' netComponent.tsx name reveal: left-full ml-20 from the scaled ring edge.
sub ApplyNameRevealLayout(scale as float)
    if m.nameLabel = invalid then return
    spec = ProfileUiSpec()
    ringSize = 166 * scale
    colX = m.REST_OFFSET_X
    if m.visualOffsetX <> invalid then colX = m.visualOffsetX
    nameX = colX + ringSize + spec.skNameMarginLeft
    nameY = Int((166 * scale - 40) / 2)
    if nameY < 0 then nameY = 0
    m.nameLabel.translation = [nameX, nameY]
    if m.hintLabel <> invalid then
        m.hintLabel.translation = [nameX, nameY + 42]
    end if
end sub

' netComponent.tsx: absolute -bottom-1 -left-1, w-12 h-12 badge, w-6 h-6 icon.
sub ApplyEditBadgeLayout(scale as float)
    if m.editBadge = invalid then return
    spec = ProfileUiSpec()
    ringSize = 166 * scale
    badgeSize = spec.editBadgeSize * scale
    iconSize = spec.editIconSize * scale
    inset = spec.editBadgeInset * scale

    m.editBadge.translation = [-inset, ringSize - badgeSize + inset]
    if m.editBadgeBg <> invalid then
        m.editBadgeBg.width = badgeSize
        m.editBadgeBg.height = badgeSize
    end if
    iconPad = (badgeSize - iconSize) / 2
    for each node in [m.editIcon, m.leftLockIcon]
        if node <> invalid then
            node.translation = [iconPad, iconPad]
            node.width = iconSize
            node.height = iconSize
        end if
    end for
end sub

