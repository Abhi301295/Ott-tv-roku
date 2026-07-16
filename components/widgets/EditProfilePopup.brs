sub init()
    m.inputShadow = m.top.findNode("inputShadow")
    m.inputBorder = m.top.findNode("inputBorder")
    m.inputFill = m.top.findNode("inputFill")
    m.nameLabel = m.top.findNode("nameLabel")
    m.placeholderLabel = m.top.findNode("placeholderLabel")
    m.clearBg = m.top.findNode("clearBg")
    m.clearIconImg = m.top.findNode("clearIconImg")
    m.cancelShadow = m.top.findNode("cancelShadow")
    m.cancelBorder = m.top.findNode("cancelBorder")
    m.cancelFill = m.top.findNode("cancelFill")
    m.cancelLabel = m.top.findNode("cancelLabel")
    m.saveShadow = m.top.findNode("saveShadow")
    m.saveBorder = m.top.findNode("saveBorder")
    m.saveFill = m.top.findNode("saveFill")
    m.saveLabel = m.top.findNode("saveLabel")
    m.cardBorder = m.top.findNode("cardBorder")
    m.cardFill = m.top.findNode("cardFill")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.clearIcon = m.top.findNode("clearIcon")
    m.inputGroup = m.top.findNode("inputGroup")
    m.cancelGroup = m.top.findNode("cancelGroup")
    m.saveGroup = m.top.findNode("saveGroup")

    m.focus = "input"
    m.name = ""
    m.top.observeField("keyEvent", "OnKey")
    OnProfileChanged()
    ApplyTheme()
    UpdateUi()
end sub

sub OnProfileChanged()
    m.name = m.top.profileName
    if m.name = invalid then m.name = ""
    m.top.editedName = m.name
    if m.nameLabel <> invalid then UpdateUi()
end sub

sub OnSavingChanged()
    if m.saveLabel = invalid then return
    UpdateUi()
end sub

sub OnThemeChanged()
    if m.cardFill = invalid then return
    ApplyTheme()
    UpdateUi()
end sub

sub ApplyTheme()
    m.cardBorder.blendColor = m.top.cNeutral700
    m.cardFill.blendColor = "0x000000ff"
    m.title.color = m.top.cNeutral50
    m.subtitle.color = m.top.cNeutral400
    m.inputFill.blendColor = "0xffffffff"
    m.nameLabel.color = "0x000000ff"
    m.cancelLabel.color = m.top.cNeutral50
    m.cancelShadow.blendColor = "0x000000ff"
    m.saveShadow.blendColor = "0x000000ff"
end sub

function EditNameTrimmed() as string
    if m.name = invalid then return ""
    return m.name.Trim()
end function

sub UpdateUi()
    if m.nameLabel = invalid then return
    saving = (m.top.isSaving = true)
    valid = (EditNameTrimmed() <> "")
    inputFocused = (m.focus = "input" or m.focus = "clear")

    m.nameLabel.text = m.name
    m.placeholderLabel.visible = (m.name = "")
    m.inputBorder.blendColor = m.top.cNeutral600
    m.inputShadow.visible = false
    if inputFocused then
        m.inputBorder.blendColor = m.top.cPrimary500
        m.inputShadow.visible = true
    end if

    if m.focus = "clear" and not saving then
        m.clearBg.blendColor = m.top.cPrimary500
        if m.clearIconImg <> invalid then m.clearIconImg.uri = "pkg:/images/ui/ic_edit_clear_24_white.png"
    else
        m.clearBg.blendColor = "0x00000000"
        if m.clearIconImg <> invalid then m.clearIconImg.uri = "pkg:/images/ui/ic_edit_clear_24.png"
    end if
    ' Keep clear at rest size — scale would eat the input top/bottom margin.
    if m.clearIcon <> invalid then m.clearIcon.scale = [1.0, 1.0]

    ' Cancel: bg-primary-600 + border-primary-500 when focused (editProfilePopup.tsx).
    if m.focus = "cancel" and not saving then
        m.cancelBorder.blendColor = m.top.cPrimary500
        m.cancelFill.blendColor = m.top.cPrimary600
        m.cancelShadow.visible = true
    else
        m.cancelBorder.blendColor = m.top.cNeutral600
        m.cancelFill.blendColor = "0x000000ff"
        m.cancelShadow.visible = false
    end if

    ' Save: bg-neutral-800 + border-primary-500 when focused.
    if m.focus = "save" and not saving and valid then
        m.saveBorder.blendColor = m.top.cPrimary500
        m.saveFill.blendColor = m.top.cNeutral800
        m.saveShadow.visible = true
    else
        m.saveBorder.blendColor = m.top.cNeutral600
        m.saveFill.blendColor = m.top.cNeutral900
        m.saveShadow.visible = false
    end if

    m.saveLabel.color = m.top.cPortalPrimary
    m.saveLabel.text = "Save"
    if saving then m.saveLabel.text = "Saving..."

    opacity = 1.0
    if saving then opacity = 0.5
    m.nameLabel.opacity = opacity
    m.placeholderLabel.opacity = opacity
    m.clearIcon.opacity = opacity
    m.cancelGroup.opacity = opacity
    if saving or not valid then
        m.saveGroup.opacity = 0.5
    else
        m.saveGroup.opacity = 1.0
    end if

    ' Keep groups at rest scale — never Group.scale the row (breaks Cancel/Save layout).
    if m.inputGroup <> invalid then m.inputGroup.scale = [1.0, 1.0]
    if m.cancelGroup <> invalid then m.cancelGroup.scale = [1.0, 1.0]
    if m.saveGroup <> invalid then m.saveGroup.scale = [1.0, 1.0]
end sub

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press or m.top.isSaving then return

    key = LCase(ev.key)
    if m.focus = "input" then
        if key = "right" then
            SetEditFocus("clear")
        else if key = "down" then
            SetEditFocus("cancel")
        else if key = "ok" then
            m.top.action = "keyboard"
        end if
    else if m.focus = "clear" then
        if key = "left" then
            SetEditFocus("input")
        else if key = "down" then
            SetEditFocus("save")
        else if key = "ok" then
            BackspaceEditName()
        end if
    else if m.focus = "cancel" then
        if key = "up" then
            SetEditFocus("input")
        else if key = "right" then
            SetEditFocus("save")
        else if key = "ok" then
            m.top.action = "cancel"
        end if
    else if m.focus = "save" then
        if key = "up" then
            SetEditFocus("clear")
        else if key = "left" then
            SetEditFocus("cancel")
        else if key = "ok" and EditNameTrimmed() <> "" then
            m.top.editedName = EditNameTrimmed()
            m.top.action = "save"
        end if
    end if
end sub

sub SetEditFocus(target as string)
    m.focus = target
    print "[PROFILE_EDIT_DBG] modal focus="; target
    UpdateUi()
end sub

sub BackspaceEditName()
    n = Len(m.name)
    if n > 0 then m.name = Left(m.name, n - 1)
    m.top.editedName = m.name
    print "[PROFILE_EDIT_DBG] backspace length="; Len(m.name)
    UpdateUi()
end sub
