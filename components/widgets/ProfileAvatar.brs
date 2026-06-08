sub init()
    m.scaler = m.top.findNode("scaler")
    m.circleBg = m.top.findNode("circleBg")
    m.avatarImg = m.top.findNode("avatarImg")
    m.initials = m.top.findNode("initials")
    m.cornerMask = m.top.findNode("cornerMask")
    m.ring = m.top.findNode("ring")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressArc = m.top.findNode("progressArc")
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

    m.ARC_FRAMES = 151
    ' Focused profile must read clearly larger than the rail avatars on TV.
    ' Roku's simulator/downscale makes 1.25 subtle, so use a stronger pop.
    m.FOCUS_SCALE = 1.38
    m.REST_SCALE = 1.0
    ' Focused profile also pops out of the rail a little to the right; all
    ' unfocused profiles return to x=0 so the default column stays aligned.
    m.FOCUS_OFFSET_X = 34.0
    m.REST_OFFSET_X = 0.0

    m.top.focusable = true
    m.top.drawFocusFeedback = false
    ' Keep the left edge fixed so the focused avatar grows rightward, matching
    ' the OTTPlay React profile rail. Vertical growth stays centered per slot.
    m.scaler.scaleRotateCenter = [0, 83]

    OnColorsChanged()
    OnDataChanged()
    OnHintChanged()
    OnFocusChanged()
end sub

sub OnColorsChanged()
    if m.cornerMask = invalid then return
    m.cornerMask.blendColor = m.top.bgColor
    m.ring.blendColor = m.top.ringColor
    m.nameLabel.color = m.top.nameColor
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

    m.progressTrack.visible = showArc
    m.progressArc.visible = showArc
    if showArc then m.progressArc.uri = ArcFrameUri(progress)

    m.ring.visible = (focused and not showArc)
    m.dot.visible = (focused and not showArc)
    ' React shows a left badge on focus: edit icon for unlocked, lock icon for locked.
    showBadge = (focused and (progress = 0 or locked))
    m.editBadge.visible = showBadge
    m.editIcon.visible = (showBadge and not locked)
    m.leftLockIcon.visible = (showBadge and locked)
    m.lockBadge.visible = false
    m.nameLabel.visible = focused
    m.hintLabel.visible = (focused and m.top.hintText <> "")

    AnimateScale(focused)
end sub

' Smoothly pop the avatar in (1.0 → 1.25 + right offset) on focus and out on blur.
' The first call (init) just snaps to the resting scale without animating.
sub AnimateScale(focused as boolean)
    target = m.REST_SCALE
    targetX = m.REST_OFFSET_X
    if focused then
        target = m.FOCUS_SCALE
        targetX = m.FOCUS_OFFSET_X
    end if

    if m.lastScale = invalid then
        m.scaler.scale = [target, target]
        m.scaler.translation = [targetX, 0.0]
        m.lastScale = target
        m.lastOffsetX = targetX
        return
    end if

    if m.lastScale = target and m.lastOffsetX = targetX then return

    m.focusAnim.control = "stop"
    m.focusInterp.keyValue = [[m.lastScale, m.lastScale], [target, target]]
    m.offsetInterp.keyValue = [[m.lastOffsetX, 0.0], [targetX, 0.0]]
    m.focusAnim.control = "start"
    m.lastScale = target
    m.lastOffsetX = targetX
end sub

' Map progress (0..1) to one of the pre-rendered arc frames (parity with the
' reference's UiProfileProgressArcUri frame mapping).
function ArcFrameUri(progress as float) as string
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
    return "pkg:/images/ui/profile_arc_" + suffix + ".png"
end function
