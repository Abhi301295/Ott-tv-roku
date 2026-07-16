sub init()
    m.spec = ProfileUiSpec()
    m.cardScaler = m.top.findNode("cardScaler")
    m.selectingGroup = m.top.findNode("selectingGroup")
    m.skA = m.top.findNode("skA")
    m.scaler = m.cardScaler
    m.cardStack = m.top.findNode("cardStack")
    m.cardInner = m.top.findNode("cardInner")
    m.outerBorder = m.top.findNode("outerBorder")
    m.cardBacking = m.top.findNode("cardBacking")
    m.cardBottom = m.top.findNode("cardBottom")
    m.cardTopRamp = m.top.findNode("cardTopRamp")
    m.innerBottom = m.top.findNode("innerBottom")
    m.innerRamp = m.top.findNode("innerRamp")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressArc = m.top.findNode("progressArc")
    m.cardClip = m.top.findNode("cardClip")
    m.initialsLabel = m.top.findNode("initialsLabel")
    m.initialsFont = m.initialsLabel.findNode("font")
    m.lockBadge = m.top.findNode("lockBadge")
    m.lockBadgeBg = m.top.findNode("lockBadgeBg")
    m.nameLabel = m.top.findNode("nameLabel")
    m.hintLabel = m.top.findNode("hintLabel")
    m.sizeAnimTimer = m.top.findNode("sizeAnimTimer")

    m.CARD = m.spec.cardSize
    m.ARC_FRAMES = 151
    m.FOCUS_SCALE = m.spec.outerFocusScale * m.spec.innerFocusScale
    m.REST_SCALE = 1.0
    m.FOCUS_OFFSET_X = m.spec.focusOffsetX
    m.REST_OFFSET_X = 0.0
    m.SIZE_ANIM_STEPS = 10
    m.DEFOCUS_ANIM_STEPS = 4
    m.animStepCount = m.SIZE_ANIM_STEPS
    m.visualScale = m.REST_SCALE
    m.visualOffsetX = m.REST_OFFSET_X

    m.top.focusable = true
    m.top.drawFocusFeedback = false
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.observeField("fire", "OnSizeAnimTick")

    ApplyLayoutFromSpec()
    OnColorsChanged()
    OnDataChanged()
    OnHintChanged()
    OnFocusChanged()
    OnSelectingChanged()
end sub

sub OnSelectingChanged()
    show = (m.top.selectingState = true)
    if m.cardStack <> invalid then m.cardStack.visible = not show
    if m.nameLabel <> invalid then m.nameLabel.visible = not show
    if m.hintLabel <> invalid then m.hintLabel.visible = false
    if show then SnapSelectingFocusScale()
    if m.selectingGroup <> invalid then
        m.selectingGroup.visible = show
        if show then
            SyncSelectingSkeletonScale()
        else
            m.selectingGroup.scale = [1.0, 1.0]
        end if
    end if
    if m.skA <> invalid then m.skA.running = show
    if show then
        keepHint = (m.top.focusedState = true and m.top.hintText <> "")
        holdH = ProfileSquareRowContentHeight(m.top.focusedState = true, keepHint)
        if holdH < m.spec.skRowHeight then holdH = m.spec.skRowHeight
        m.top.layoutHeight = holdH
    else
        if m.hintLabel <> invalid then
            m.hintLabel.visible = (m.top.focusedState = true and m.top.hintText <> "")
        end if
        showHint = false
        if m.hintLabel <> invalid then showHint = m.hintLabel.visible
        UpdateLayoutHeight(showHint)
    end if
end sub

sub SnapSelectingFocusScale()
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
    scale = m.FOCUS_SCALE
    x = m.FOCUS_OFFSET_X
    if m.top.focusedState <> true then
        scale = m.REST_SCALE
        x = m.REST_OFFSET_X
    end if
    m.visualScale = scale
    m.visualOffsetX = x
    m.lastScale = scale
    m.lastOffsetX = x
    ApplyScales(scale, x)
end sub

sub SyncSelectingSkeletonScale()
    if m.selectingGroup = invalid then return
    scale = m.visualScale
    if scale < m.REST_SCALE then scale = m.REST_SCALE
    if m.top.selectingState = true and m.top.focusedState = true and scale < m.FOCUS_SCALE then
        scale = m.FOCUS_SCALE
    end if
    m.selectingGroup.scale = [1.0, 1.0]
    ApplySelectingSkeletonLayout(scale)
end sub

sub ApplySelectingSkeletonLayout(scale as float)
    spec = ProfileUiSpec()
    if m.skA <> invalid then
        m.skA.layoutScale = scale
        m.skA.translation = [0, 0]
        m.skA.boxWidth = spec.cardSize
        m.skA.boxHeight = spec.cardSize
        m.skA.glowKind = "avatarSquare"
        m.skA.shapeUri = SkeletonProfileAvatarShapeUri(true)
        m.skA.glowVisible = false
    end if
end sub

sub OnSkColorsChanged()
    if m.skA <> invalid then
        m.skA.baseColor = m.top.skBaseColor
        m.skA.highlightColor = m.top.skHighlightColor
    end if
end sub

sub ApplyLayoutFromSpec()
    ApplyLabelLayout()
end sub

' Name and hint sit below the scaled card foot so rows never overlap when focused.
sub ApplyLabelLayout()
    scale = m.visualScale
    if scale < 1.0 then scale = 1.0
    cardH = Int(m.CARD * scale + 0.5)
    nameY = cardH + m.spec.cardMarginBottom

    if m.nameLabel <> invalid then
        m.nameLabel.translation = [0, nameY]
        nameFont = m.nameLabel.findNode("font")
        if nameFont <> invalid then
            nameFont.size = m.spec.nameFont
            nameFont.uri = "pkg:/fonts/Inter-Medium.ttf"
        end if
        ' userProfile.tsx: text-center w-full under the 150px card (scaled when focused).
        m.nameLabel.width = cardH
        m.nameLabel.horizAlign = "center"
        m.nameLabel.height = m.spec.nameFont + 6
    end if
    showHint = false
    if m.hintLabel <> invalid then
        ' userProfile.tsx: text-center w-full mt-1 under the name (same column as the card).
        hintSize = m.spec.hintFont
        hintH = hintSize + 4
        hintUri = "pkg:/fonts/Inter-Bold.ttf"
        if m.top.hintBold = true then
            hintSize = m.spec.hintAutoFont
            hintH = hintSize + 6
            hintUri = "pkg:/fonts/Inter-Black.ttf"
        end if
        m.hintLabel.translation = [0, nameY + m.spec.nameFont + m.spec.hintMarginTop]
        hintFont = m.hintLabel.findNode("font")
        if hintFont <> invalid then
            hintFont.size = hintSize
            hintFont.uri = hintUri
        end if
        m.hintLabel.width = cardH
        m.hintLabel.horizAlign = "center"
        m.hintLabel.height = hintH
        showHint = m.hintLabel.visible
    end if
    UpdateLayoutHeight(showHint)
end sub

sub UpdateLayoutHeight(showHint as boolean)
    focused = (m.top.focusedState = true)
    h = ProfileSquareRowContentHeight(focused, showHint)
    if h < 1 then h = ProfileSquareRowContentHeight(false, false)
    if m.top.layoutHeight <> h then m.top.layoutHeight = h
end sub

sub OnColorsChanged()
    if m.cardBacking <> invalid then m.cardBacking.color = m.top.cardBackingColor
    if m.cardBottom <> invalid then m.cardBottom.color = m.top.cardBottomColor
    if m.cardTopRamp <> invalid then m.cardTopRamp.blendColor = m.top.cardTopColor
    if m.innerBottom <> invalid then m.innerBottom.color = m.top.cardBottomColor
    if m.innerRamp <> invalid then m.innerRamp.blendColor = m.top.cardTopColor
    if m.outerBorder <> invalid then m.outerBorder.blendColor = m.top.borderColor
    if m.lockBadgeBg <> invalid then m.lockBadgeBg.blendColor = m.top.cardBottomColor
    if m.nameLabel <> invalid then
        m.nameLabel.color = m.top.nameColor
        m.nameLabel.opacity = 1.0
    end if
    if m.hintLabel <> invalid then m.hintLabel.color = m.top.hintColor
    ProfileUiLogColors(m.top.cardTopColor, m.top.cardBottomColor, m.top.borderColor, m.top.nameColor)
end sub

sub OnDataChanged()
    if m.initialsLabel <> invalid then m.initialsLabel.text = m.top.initials
    if m.nameLabel <> invalid then
        m.nameLabel.text = m.top.profileName
        m.nameLabel.color = m.top.nameColor
    end if
end sub

sub OnHintChanged()
    if m.hintLabel = invalid then return
    txt = m.top.hintText
    m.hintLabel.text = txt
    m.hintLabel.visible = (m.top.focusedState and txt <> "")
    if m.hintLabel.visible then m.hintLabel.color = m.top.hintColor
    ApplyLabelLayout()
end sub

sub OnFocusChanged()
    focused = m.top.focusedState
    if focused <> true then focused = false
    locked = (m.top.parentalLock = true)
    progress = m.top.progress
    if progress < 0 then progress = 0
    if progress > 1 then progress = 1

    ApplyCardChrome(focused)

    if m.outerBorder <> invalid then m.outerBorder.visible = focused

    showTrack = (focused and not locked)
    showArc = (showTrack and progress > 0)

    if m.progressTrack <> invalid then m.progressTrack.visible = showTrack
    if m.progressArc <> invalid then
        m.progressArc.visible = showArc
        if showArc then m.progressArc.uri = SquareArcFrameUri(progress)
    end if
    if m.lockBadge <> invalid then m.lockBadge.visible = (focused and locked)

    OnHintChanged()
    ApplyLabelLayout()
    if m.top.selectingState = true then return
    AnimateScale(focused)
    ProfileUiLogRow(m.top.rowIndex, focused, progress, m.visualScale, 1.0, m.lastOffsetX)
end sub

sub ApplyCardChrome(focused as boolean)
    scale = m.visualScale
    if scale <= 0 then scale = m.REST_SCALE

    inset = 0.0
    inner = m.CARD * scale
    if focused then
        inset = m.spec.ringInset * scale
        inner = m.spec.innerContentSize * scale
    end if

    faceInset = m.spec.innerFaceInset * scale
    faceSize = m.spec.innerFaceSize * scale

    if m.cardInner <> invalid then m.cardInner.visible = focused
    if focused and m.cardInner <> invalid then
        m.cardInner.maskOffset = [faceInset, faceInset]
        m.cardInner.maskSize = [faceSize, faceSize]
    end if
    if m.innerBottom <> invalid then
        m.innerBottom.width = faceSize
        m.innerBottom.height = faceSize
    end if
    if m.innerRamp <> invalid then
        m.innerRamp.width = faceSize
        m.innerRamp.height = faceSize
    end if

    if m.initialsLabel <> invalid then
        m.initialsLabel.translation = [inset, inset]
        m.initialsLabel.width = inner
        m.initialsLabel.height = inner
    end if
    if m.initialsFont <> invalid then
        m.initialsFont.size = Int(m.spec.initialsFont * scale + 0.5)
    end if
    if m.lockBadge <> invalid then
        badge = 32 * scale
        badgeX = inset + Int((inner - badge) / 2)
        badgeY = inset + inner - (16 * scale)
        m.lockBadge.translation = [badgeX, badgeY]
        if m.lockBadgeBg <> invalid then
            m.lockBadgeBg.width = badge
            m.lockBadgeBg.height = badge
        end if
        lockIcon = m.top.findNode("lockIcon")
        if lockIcon <> invalid then
            li = 16 * scale
            lockIcon.translation = [8 * scale, 8 * scale]
            lockIcon.width = li
            lockIcon.height = li
        end if
    end if
end sub

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
        ApplyScales(target, targetX)
        m.lastScale = target
        m.lastOffsetX = targetX
        ProfileUiLogDerived(m.top.rowIndex, focused, target, 1.0)
        return
    end if

    if not focused then
        if m.top.snapRest = true then
            m.top.snapRest = false
            SnapSquareAvatarToRest()
            ProfileUiLogDerived(m.top.rowIndex, focused, m.REST_SCALE, 1.0)
            return
        end if
        fromScale = m.visualScale
        fromX = m.visualOffsetX
        if fromScale = target and fromX = targetX then return
        StartSquareSizeAnimation(fromScale, target, fromX, targetX, m.DEFOCUS_ANIM_STEPS)
        m.lastScale = target
        m.lastOffsetX = targetX
        ProfileUiLogDerived(m.top.rowIndex, focused, target, 1.0)
        return
    end if

    m.top.snapRest = false
    fromScale = m.visualScale
    fromX = m.visualOffsetX
    if fromScale = target and fromX = targetX then return

    StartSquareSizeAnimation(fromScale, target, fromX, targetX, m.SIZE_ANIM_STEPS)
    m.lastScale = target
    m.lastOffsetX = targetX
    ProfileUiLogDerived(m.top.rowIndex, focused, target, 1.0)
end sub

sub SnapSquareAvatarToRest()
    if m.sizeAnimTimer <> invalid then m.sizeAnimTimer.control = "stop"
    ApplyScales(m.REST_SCALE, m.REST_OFFSET_X)
    m.lastScale = m.REST_SCALE
    m.lastOffsetX = m.REST_OFFSET_X
end sub

sub StartSquareSizeAnimation(fromScale as float, toScale as float, fromX as float, toX as float, steps as integer)
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
        ApplyScales(toScale, toX)
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

    inv = 1.0 - t
    eased = 1.0 - (inv * inv * inv)
    scale = m.animFromScale + ((m.animToScale - m.animFromScale) * eased)
    x = m.animFromX + ((m.animToX - m.animFromX) * eased)
    ApplyScales(scale, x)

    if t >= 1.0 and m.sizeAnimTimer <> invalid then
        m.sizeAnimTimer.control = "stop"
    end if
end sub

sub ApplyScales(scale as float, offsetX as float)
    m.visualScale = scale
    m.visualOffsetX = offsetX
    ApplyCardSize(scale)
    ApplyCardChrome(m.top.focusedState)

    if m.cardScaler <> invalid then
        m.cardScaler.scale = [1.0, 1.0]
        m.cardScaler.translation = [offsetX, ScaleOffsetY(scale)]
    end if
    ApplyLabelLayout()
end sub

sub ApplyCardSize(scale as float)
    card = m.CARD * scale
    faceInset = m.spec.innerFaceInset * scale
    faceSize = m.spec.innerFaceSize * scale

    if m.cardClip <> invalid then
        m.cardClip.maskSize = [card, card]
        m.cardClip.maskOffset = [0, 0]
    end if
    for each node in [m.cardBacking, m.cardBottom, m.cardTopRamp]
        if node <> invalid then
            node.width = card
            node.height = card
        end if
    end for

    if m.outerBorder <> invalid then
        m.outerBorder.width = card
        m.outerBorder.height = card
        m.outerBorder.translation = [0, 0]
    end if

    if m.cardInner <> invalid then
        m.cardInner.maskSize = [faceSize, faceSize]
        m.cardInner.maskOffset = [faceInset, faceInset]
    end if
    for each node in [m.innerBottom, m.innerRamp]
        if node <> invalid then
            node.width = faceSize
            node.height = faceSize
        end if
    end for

    for each node in [m.progressTrack, m.progressArc]
        if node <> invalid then
            node.width = card
            node.height = card
        end if
    end for
end sub

function ScaleOffsetY(scale as float) as float
    ' Grow from top-left — avoids negative Y pushing the top border under the row above.
    return 0.0
end function

function SquareArcFrameUri(progress as float) as string
    last = m.ARC_FRAMES - 1
    idx = Int(progress * last + 0.5)
    if idx < 0 then idx = 0
    if idx > last then idx = last
    suffix = idx.ToStr()
    if idx < 10 then
        suffix = "00" + suffix
    else if idx < 100 then
        suffix = "0" + suffix
    end if
    return "pkg:/images/ui/profile_sq_arc_" + suffix + ".png"
end function
