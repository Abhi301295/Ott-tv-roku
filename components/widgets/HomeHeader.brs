' HomeHeader.brs — Netflix top bar (parity with ottHeader.tsx NetflixMenuItem).
'
' Each menu item mirrors the React <button>:
'   px-4 py-2  →  PAD_X=16, PAD_Y=8
'   fs-24 font-medium / font-bold when selected
'   default:     text-neutral-200
'   focused:     rounded-full scale-105 border-b-2 border-neutral-50, text-neutral-200
'   selected:    text-neutral-50 font-bold border-b-2 border-primary-500 (straight)
'   focused+selected: focus shape + scale, selected color + bold + primary border

sub init()
    m.scrim = m.top.findNode("scrim")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")
    m.menuRow = m.top.findNode("menuRow")
    m.avatarImg = m.top.findNode("avatarImg")
    m.avatarBg = m.top.findNode("avatarBg")

    m.itemRoots = []
    m.itemLabels = []
    m.itemSelBars = []
    m.itemFocusL = []
    m.itemFocusM = []
    m.itemFocusR = []
    m.itemScaleAnims = []
    m.itemScaleInterps = []
    m.itemFocusState = []

    ' React: fs-24 = 1.5rem × fontScale LARGE(1.2) = 1.8rem ≈ 28.8px at 16px root.
    ' px-4 py-2 → 16px / 8px padding. Pill is rounded-full so cap radius = half height.
    m.PAD_X = 16
    m.PAD_Y = 8
    m.ITEM_H = 48
    m.BORDER_W = 2
    m.CAP_R = 24

    m.fontMedium = CreateObject("roSGNode", "Font")
    m.fontMedium.uri = "pkg:/fonts/Inter-Medium.ttf"
    m.fontMedium.size = 29

    m.fontBold = CreateObject("roSGNode", "Font")
    m.fontBold.uri = "pkg:/fonts/Inter-Bold.ttf"
    m.fontBold.size = 29

    m.layoutTimer = CreateObject("roSGNode", "Timer")
    m.layoutTimer.duration = 0.1
    m.layoutTimer.repeat = false
    m.top.appendChild(m.layoutTimer)
    m.layoutTimer.observeField("fire", "OnLayoutTimer")
end sub

sub OnMenuChanged()
    BuildMenu()
end sub

sub OnThemeChanged()
    if m.logoLabel <> invalid then m.logoLabel.color = m.top.cNeutral50
    for i = 0 to m.itemSelBars.Count() - 1
        if m.itemSelBars[i] <> invalid then m.itemSelBars[i].color = m.top.cPrimary500
        if m.itemFocusL[i] <> invalid then m.itemFocusL[i].blendColor = m.top.cNeutral50
        if m.itemFocusM[i] <> invalid then m.itemFocusM[i].color = m.top.cNeutral50
        if m.itemFocusR[i] <> invalid then m.itemFocusR[i].blendColor = m.top.cNeutral50
    end for
    ApplyFocus()
end sub

sub OnAvatarChanged()
    if m.avatarImg = invalid then return
    uri = m.top.avatarUri
    if uri <> invalid and uri <> "" then
        m.avatarImg.uri = uri
        m.avatarImg.visible = true
    else
        m.avatarImg.visible = false
    end if
end sub

sub OnLogoChanged()
    uri = m.top.logoUri
    if uri <> invalid and uri <> "" then
        m.logoPoster.uri = uri
        m.logoPoster.visible = true
        m.logoLabel.visible = false
    else
        m.logoPoster.visible = false
        m.logoLabel.text = m.top.appName
        m.logoLabel.visible = (m.top.appName <> "")
    end if
end sub

sub OnFocusChanged()
    ApplyFocus()
end sub

sub BuildMenu()
    m.itemRoots = []
    m.itemLabels = []
    m.itemSelBars = []
    m.itemFocusL = []
    m.itemFocusM = []
    m.itemFocusR = []
    m.itemScaleAnims = []
    m.itemScaleInterps = []
    m.itemFocusState = []
    if m.menuRow = invalid then return

    count = m.menuRow.getChildCount()
    for i = count - 1 to 0 step -1
        m.menuRow.removeChildIndex(i)
    end for

    texts = m.top.menuTexts
    if texts = invalid then return

    capR = m.CAP_R
    borderY = m.ITEM_H - m.BORDER_W

    idx = 0
    for each t in texts
        root = m.menuRow.createChild("Group")
        root.id = "hdrItem" + StrI(idx).Trim()
        root.scale = [1.0, 1.0]

        lbl = root.createChild("Label")
        lbl.text = t
        lbl.font = m.fontMedium
        lbl.translation = [m.PAD_X, m.PAD_Y]
        lbl.height = m.ITEM_H - (2 * m.PAD_Y)
        lbl.color = m.top.cNeutral200

        ' Selected: straight blue bottom border (border-b-2 border-primary-500).
        sel = root.createChild("Rectangle")
        sel.height = m.BORDER_W
        sel.width = 0
        sel.translation = [0, borderY]
        sel.color = m.top.cPrimary500
        sel.visible = false

        ' Focused: rounded-full bottom border (border-b-2 border-neutral-50).
        fL = root.createChild("Poster")
        fL.uri = "pkg:/images/ui/focus_cap_left.png"
        fL.width = capR
        fL.height = capR
        fL.translation = [0, m.ITEM_H - capR]
        fL.blendColor = m.top.cNeutral50
        fL.visible = false

        fM = root.createChild("Rectangle")
        fM.height = m.BORDER_W
        fM.width = 0
        fM.translation = [capR, borderY]
        fM.color = m.top.cNeutral50
        fM.visible = false

        fR = root.createChild("Poster")
        fR.uri = "pkg:/images/ui/focus_cap_right.png"
        fR.width = capR
        fR.height = capR
        fR.translation = [0, m.ITEM_H - capR]
        fR.blendColor = m.top.cNeutral50
        fR.visible = false

        m.itemRoots.Push(root)
        m.itemLabels.Push(lbl)
        m.itemSelBars.Push(sel)
        m.itemFocusL.Push(fL)
        m.itemFocusM.Push(fM)
        m.itemFocusR.Push(fR)

        ' Per-item scale tween (transition-all duration-200): outQuad over 200ms.
        anim = m.menuRow.createChild("Animation")
        anim.duration = 0.2
        anim.easeFunction = "outQuad"
        interp = anim.createChild("Vector2DFieldInterpolator")
        interp.fieldToInterp = root.id + ".scale"
        interp.key = [0.0, 1.0]
        interp.keyValue = [[1.0, 1.0], [1.0, 1.0]]
        m.itemScaleAnims.Push(anim)
        m.itemScaleInterps.Push(interp)
        m.itemFocusState.Push(false)

        idx = idx + 1
    end for

    m.layoutTimer.control = "start"
    ApplyFocus()
end sub

' Measure label widths, size each button's borders, and position items manually at a
' fixed 24px gap. Manual layout (vs LayoutGroup) means a focused item's scale-105 stays
' purely visual and never pushes its neighbors — parity with React's transform.
sub OnLayoutTimer()
    capR = m.CAP_R
    borderY = m.ITEM_H - m.BORDER_W
    gap = 24   ' space-x-6

    x = 0
    for i = 0 to m.itemLabels.Count() - 1
        lbl = m.itemLabels[i]
        if lbl = invalid then continue for

        r = lbl.boundingRect()
        textW = 0
        if r <> invalid then textW = r.width

        itemW = textW + (2 * m.PAD_X)

        m.itemSelBars[i].width = itemW

        fL = m.itemFocusL[i]
        fM = m.itemFocusM[i]
        fR = m.itemFocusR[i]
        fL.translation = [0, m.ITEM_H - capR]
        fR.translation = [itemW - capR, m.ITEM_H - capR]
        midW = itemW - (2 * capR)
        if midW < 0 then midW = 0
        fM.translation = [capR, borderY]
        fM.width = midW

        ' Fixed position + center anchor so scale-105 grows in place without reflow.
        root = m.itemRoots[i]
        root.translation = [x, 0]
        root.scaleRotateCenter = [itemW / 2, m.ITEM_H / 2]

        x = x + itemW + gap
    end for

    ' Center the row by its total unscaled width (drop the trailing gap).
    totalW = x - gap
    if totalW > 0 then
        ox = Int((1920 - totalW) / 2)
        m.menuRow.translation = [ox, 34]
    end if

    ApplyFocus()
end sub

sub ApplyFocus()
    fIdx = m.top.focusedIndex
    sIdx = m.top.selectedIndex
    active = m.top.headerActive

    for i = 0 to m.itemLabels.Count() - 1
        lbl = m.itemLabels[i]
        root = m.itemRoots[i]
        sel = m.itemSelBars[i]
        fL = m.itemFocusL[i]
        fM = m.itemFocusM[i]
        fR = m.itemFocusR[i]
        if lbl = invalid then continue for

        isFocused = (active and i = fIdx)
        isSelected = (i = sIdx)

        ' Border priority matches React class merge:
        '   focused only        → rounded white underline
        '   selected only       → straight blue underline
        '   focused + selected  → rounded blue underline (primary wins over neutral-50)
        showRounded = isFocused
        showStraight = (isSelected and not isFocused)

        fL.visible = showRounded
        fM.visible = showRounded
        fR.visible = showRounded
        sel.visible = showStraight

        if showRounded then
            if isSelected then
                fL.blendColor = m.top.cPrimary500
                fM.color = m.top.cPrimary500
                fR.blendColor = m.top.cPrimary500
            else
                fL.blendColor = m.top.cNeutral50
                fM.color = m.top.cNeutral50
                fR.blendColor = m.top.cNeutral50
            end if
        end if

        ' Text + font (React class merge order).
        if isSelected then
            lbl.color = m.top.cNeutral50
            lbl.font = m.fontBold
        else
            lbl.color = m.top.cNeutral200
            lbl.font = m.fontMedium
        end if

        ' scale-105 on the whole button when focused, eased over 200ms (transition-all
        ' duration-200). Only (re)start the animation when this item's focus state
        ' actually changes, so rapid nav stays smooth and doesn't restart mid-tween.
        if root <> invalid and m.itemScaleAnims <> invalid then
            if i < m.itemScaleAnims.Count() then
                wasFocused = m.itemFocusState[i]
                if showRounded <> wasFocused then
                    anim = m.itemScaleAnims[i]
                    interp = m.itemScaleInterps[i]
                    if anim <> invalid and interp <> invalid then
                        if showRounded then
                            interp.keyValue = [[1.0, 1.0], [1.05, 1.05]]
                        else
                            interp.keyValue = [[1.05, 1.05], [1.0, 1.0]]
                        end if
                        anim.control = "start"
                    end if
                    m.itemFocusState[i] = showRounded
                end if
            end if
        end if
    end for

    if m.scrim <> invalid then
        if active then
            m.scrim.opacity = 0.45
        else
            m.scrim.opacity = 0.2
        end if
    end if
end sub
