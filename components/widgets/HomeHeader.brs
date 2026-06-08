sub init()
    m.scrim = m.top.findNode("scrim")
    m.logoPoster = m.top.findNode("logoPoster")
    m.logoLabel = m.top.findNode("logoLabel")
    m.menuRow = m.top.findNode("menuRow")
    m.avatarImg = m.top.findNode("avatarImg")
    m.avatarBg = m.top.findNode("avatarBg")

    m.itemLabels = []
    m.itemUnderlines = []

    m.menuFont = CreateObject("roSGNode", "Font")
    m.menuFont.uri = "pkg:/fonts/DMSans-Medium.ttf"
    m.menuFont.size = 24

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
    m.itemLabels = []
    m.itemUnderlines = []
    if m.menuRow = invalid then return

    count = m.menuRow.getChildCount()
    for i = count - 1 to 0 step -1
        m.menuRow.removeChildIndex(i)
    end for

    texts = m.top.menuTexts
    if texts = invalid then return

    for each t in texts
        item = m.menuRow.createChild("Group")
        lbl = item.createChild("Label")
        lbl.text = t
        lbl.font = m.menuFont
        lbl.height = 36
        lbl.color = m.top.cNeutral200
        und = item.createChild("Rectangle")
        und.height = 3
        und.width = 0
        und.translation = [0, 42]
        und.color = m.top.cPrimary500
        und.visible = false
        m.itemLabels.Push(lbl)
        m.itemUnderlines.Push(und)
    end for

    m.layoutTimer.control = "start"
    ApplyFocus()
end sub

' Underline widths and horizontal centering need measured label sizes, so finalize
' once the row has been laid out.
sub OnLayoutTimer()
    for i = 0 to m.itemLabels.Count() - 1
        lbl = m.itemLabels[i]
        und = m.itemUnderlines[i]
        if lbl = invalid or und = invalid then continue for
        r = lbl.boundingRect()
        w = 0
        if r <> invalid then w = r.width
        und.width = w
    end for

    rr = m.menuRow.boundingRect()
    if rr <> invalid and rr.width > 0 then
        x = Int((1920 - rr.width) / 2)
        m.menuRow.translation = [x, 34]
    end if

    ApplyFocus()
end sub

sub ApplyFocus()
    fIdx = m.top.focusedIndex
    sIdx = m.top.selectedIndex
    active = m.top.headerActive

    for i = 0 to m.itemLabels.Count() - 1
        lbl = m.itemLabels[i]
        und = m.itemUnderlines[i]
        if lbl = invalid or und = invalid then continue for

        isFocused = (active and i = fIdx)
        isSelected = (i = sIdx)

        if isFocused then
            lbl.color = m.top.cNeutral50
            und.color = m.top.cNeutral50
            und.visible = true
        else if isSelected then
            lbl.color = m.top.cNeutral50
            und.color = m.top.cPrimary500
            und.visible = true
        else
            lbl.color = m.top.cNeutral200
            und.visible = false
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
