sub init()
    m.panelHost = m.top.findNode("panelHost")
    m.panelDropShadow = m.top.findNode("panelDropShadow")
    m.rowsHost = m.top.findNode("rowsHost")
    m.keyRows = []
    m.letterRows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", SR_KeyAa()]
        [SR_Key123(), "Z", "X", "C", "V", "B", "N", "M", SR_KeyBackspace()]
    ]
    m.numberRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", SR_KeyAa()]
        [SR_KeyAbc(), ".", ",", "?", "!", "#", "%", "^", SR_KeyBackspace()]
    ]
    m.bottomRow = [SR_KeySpace(), SR_KeyClear()]
    m.panelPadTop = 0
    m.panelPadX = SR_KeyboardPanelPadX()
    m.panelPadBottom = SR_KeyboardPanelPadBottom()
    m.keyIdSeq = 0
    BuildKeyboard()
end sub

sub OnLayoutModeChanged()
    savedRow = m.top.focusedRow
    savedCol = m.top.focusedCol
    BuildKeyboard()
    m.top.focusedRow = savedRow
    m.top.focusedCol = savedCol
    ApplyKeyFocus()
end sub

sub OnFocusChanged()
    ApplyKeyFocus()
end sub

sub OnThemeChanged()
    ApplyKeyFocus()
end sub

function KeyOuterWidth(label as string) as integer
    return KeyWidth(label) + (2 * SR_InputBorderW())
end function

function KeyWidth(label as string) as integer
    if label = SR_KeySpace() then return SR_KeyWSpace()
    if label = SR_KeyClear() then return SR_KeyWClear()
    if label = SR_Key123() or label = SR_KeyAbc() or label = SR_KeyBackspace() then return SR_KeyWSpecial()
    if KeyIsAaToggle(label) then return SR_KeyWAa()
    return SR_KeyW()
end function

function KeyIsAaToggle(label as string) as boolean
    return label = SR_KeyAa()
end function

function KeyIsLetter(label as string) as boolean
    if label = invalid or label = "" then return false
    if Len(label) <> 1 then return false
    ch = UCase(label)
    if ch >= "A" and ch <= "Z" then return true
    return false
end function

function KeyDisplayLabel(canonical as string) as string
    if KeyIsAaToggle(canonical) then
        if m.top.upperCase = true then return SR_KeyAa()
        return SR_KeyAAToggle()
    end if
    if m.top.numberMode <> true and KeyIsLetter(canonical) then
        if m.top.upperCase = true then return UCase(canonical)
        return LCase(canonical)
    end if
    return canonical
end function

function KeyFontSize(label as string) as integer
    if label = SR_Key123() or label = SR_KeyAbc() or KeyIsAaToggle(label) or label = SR_KeyClear() then
        return SR_KeySpecialFontSize()
    end if
    return SR_KeyFontSize()
end function

sub BuildKeyboard()
    if m.rowsHost = invalid then return
    m.rowsHost.removeChildrenIndex(m.rowsHost.getChildCount(), 0)
    m.keyRows = []

    layout = m.letterRows
    if m.top.numberMode = true then layout = m.numberRows

    maxRowW = KeyboardMaxRowWidth(layout)

    y = 0
    for r = 0 to layout.Count() - 1
        rowData = layout[r]
        rowW = RowTotalWidth(rowData)
        rowGroup = m.rowsHost.createChild("Group")
        rowKeys = []
        x = 0
        for c = 0 to rowData.Count() - 1
            label = rowData[c]
            kw = KeyWidth(label)
            keyEntry = CreateKey(label, kw)
            key = keyEntry.node
            key.translation = [x, 0]
            rowGroup.appendChild(key)
            rowKeys.Push(keyEntry)
            x = x + KeyOuterWidth(label)
            if c < rowData.Count() - 1 then x = x + SR_KeyGap()
        end for
        rowGroup.translation = [Int((maxRowW - rowW) / 2), y]
        m.keyRows.Push(rowKeys)
        y = y + SR_KeyOuterH() + SR_KeyRowGap()
    end for

    bottom = m.rowsHost.createChild("Group")
    rowKeys = []
    rowW = RowTotalWidth(m.bottomRow)
    x = 0
    for c = 0 to m.bottomRow.Count() - 1
        label = m.bottomRow[c]
        kw = KeyWidth(label)
        keyEntry = CreateKey(label, kw)
        key = keyEntry.node
        key.translation = [x, 0]
        bottom.appendChild(key)
        rowKeys.Push(keyEntry)
        x = x + KeyOuterWidth(label)
        if c < m.bottomRow.Count() - 1 then x = x + SR_KeyBottomGap()
    end for
    bottom.translation = [Int((maxRowW - rowW) / 2), y + SR_KeyRowGap()]
    y = y + SR_KeyRowGap() + SR_KeyOuterH()
    m.keyRows.Push(rowKeys)

    LayoutPanel(maxRowW, y)
    m.top.panelWidth = maxRowW + (2 * m.panelPadX)
    m.top.panelHeight = y + m.panelPadTop + m.panelPadBottom
    ApplyKeyFocus()
end sub

function KeyboardMaxRowWidth(layout as object) as integer
    maxW = 0
    for r = 0 to layout.Count() - 1
        w = RowTotalWidth(layout[r])
        if w > maxW then maxW = w
    end for
    bottomW = RowTotalWidth(m.bottomRow)
    if bottomW > maxW then maxW = bottomW
    return maxW
end function

sub LayoutPanel(contentW as integer, contentH as integer)
    padX = m.panelPadX
    padTop = m.panelPadTop
    padBottom = m.panelPadBottom
    panelW = contentW + (2 * padX)
    panelH = contentH + padTop + padBottom

    ApplyPanelDropShadow(panelW, panelH)
    if m.rowsHost <> invalid then m.rowsHost.translation = [padX, padTop]
end sub

sub ApplyPanelDropShadow(panelW as integer, panelH as integer)
    if m.panelDropShadow = invalid then return
    spread = SR_PanelShadowSpread()
    dropY = SR_PanelShadowDropY()
    blurB = SR_PanelShadowBlurB()
    m.panelDropShadow.uri = SR_PanelDropShadowUri()
    m.panelDropShadow.width = panelW + (2 * spread)
    m.panelDropShadow.height = panelH + dropY + blurB
    m.panelDropShadow.translation = [-spread, 0]
    m.panelDropShadow.blendColor = "0x000000ff"
    m.panelDropShadow.opacity = SR_PanelDropShadowOpacity()
    m.panelDropShadow.loadDisplayMode = "scaleToFit"
end sub

function RowTotalWidth(rowData as object) as integer
    w = 0
    for i = 0 to rowData.Count() - 1
        w = w + KeyOuterWidth(rowData[i])
        if i < rowData.Count() - 1 then
            gap = SR_KeyGap()
            if rowData.Count() = 2 and (rowData[0] = SR_KeySpace() or rowData[1] = SR_KeyClear()) then
                gap = SR_KeyBottomGap()
            end if
            w = w + gap
        end if
    end for
    return w
end function

function CreateKey(label as string, kw as integer) as object
    g = CreateObject("roSGNode", "Group")
    m.keyIdSeq = m.keyIdSeq + 1
    g.id = "searchKey" + Str(m.keyIdSeq)
    kh = SR_KeyH()
    bw = SR_InputBorderW()
    totalW = kw + (2 * bw)
    totalH = kh + (2 * bw)
    g.scaleRotateCenter = [totalW / 2, totalH / 2]

    anim = g.createChild("Animation")
    anim.id = "scaleAnim"
    anim.duration = 0.2
    anim.easeFunction = "outQuad"
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.fieldToInterp = g.id + ".scale"
    interp.key = [0.0, 1.0]
    interp.keyValue = [[1.0, 1.0], [1.0, 1.0]]

    bg = g.createChild("Poster")
    bg.id = "bg"
    bg.uri = SR_KeyFillUri(kw, kh)
    bg.width = kw
    bg.height = kh
    bg.translation = [bw, bw]
    bg.loadDisplayMode = "scaleToFill"
    bg.blendColor = SR_KeyFillColor()

    border = g.createChild("FocusFrame")
    border.id = "borderFrame"
    border.boxWidth = totalW
    border.boxHeight = totalH
    border.thickness = bw
    border.radius = SR_KeyCornerRadius()
    border.translation = [0, 0]
    border.color = m.top.cNeutral700

    lbl = g.createChild("Label")
    lbl.id = "lbl"
    lbl.width = kw
    lbl.height = kh
    lbl.translation = [bw, bw]
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    lbl.text = KeyDisplayLabel(label)
    lbl.color = m.top.cNeutral50
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Inter-Medium.ttf"
    f.size = KeyFontSize(label)
    lbl.font = f

    return { node: g, label: label, anim: anim, interp: interp, scale: 1.0 }
end function

sub AnimateKeyScale(entry as object, target as float)
    if entry = invalid or entry.node = invalid then return
    node = entry.node
    cur = entry.scale
    if cur = invalid then cur = 1.0
    if Abs(cur - target) < 0.01 then return
    entry.scale = target
    interp = entry.interp
    anim = entry.anim
    if interp = invalid or anim = invalid then
        node.scale = [target, target]
        return
    end if
    interp.keyValue = [[cur, cur], [target, target]]
    anim.control = "start"
end sub

sub ApplyKeyFocus()
    fr = m.top.focusedRow
    fc = m.top.focusedCol
    active = m.top.focusActive = true
    for r = 0 to m.keyRows.Count() - 1
        row = m.keyRows[r]
        for c = 0 to row.Count() - 1
            entry = row[c]
            if entry = invalid then continue for
            node = entry.node
            if node = invalid then continue for
            bg = node.findNode("bg")
            border = node.findNode("borderFrame")
            lbl = node.findNode("lbl")
            isFoc = active and (r = fr and c = fc)
            if bg <> invalid then
                if isFoc then
                    bg.blendColor = m.top.cPrimary500
                else
                    bg.blendColor = SR_KeyFillColor()
                end if
            end if
            if border <> invalid then
                if isFoc then
                    border.color = m.top.cPrimary500
                else
                    border.color = m.top.cNeutral700
                end if
            end if
            if lbl <> invalid then lbl.color = m.top.cNeutral50
            if isFoc then
                AnimateKeyScale(entry, SR_KeyFocusScale())
            else
                AnimateKeyScale(entry, 1.0)
            end if
        end for
    end for
end sub

function RefreshKeyColors() as void
    ApplyKeyFocus()
end function

function KeyLabelAt(row as integer, col as integer) as string
    if row < 0 or row >= m.keyRows.Count() then return ""
    keys = m.keyRows[row]
    if col < 0 or col >= keys.Count() then return ""
    entry = keys[col]
    if entry = invalid then return ""
    return entry.label
end function

function PressFocusedKey() as void
    label = KeyLabelAt(m.top.focusedRow, m.top.focusedCol)
    if label = "" then return
    if KeyIsAaToggle(label) then
        m.top.upperCase = not m.top.upperCase
        return
    end if
    if label = SR_Key123() then
        m.top.numberMode = true
        return
    end if
    if label = SR_KeyAbc() then
        m.top.numberMode = false
        return
    end if
    out = label
    if label = SR_KeyBackspace() then
        out = "Backspace"
    else if label = SR_KeyClear() then
        out = "CLEAR"
    else if label = SR_KeySpace() then
        out = " "
    else if not m.top.numberMode and Len(label) = 1 then
        if m.top.upperCase = true then
            out = UCase(label)
        else
            out = LCase(label)
        end if
    end if
    m.top.keyPress = out
end function
