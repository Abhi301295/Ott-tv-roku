sub init()
    m.thumb = m.top.findNode("thumb")
    m.focusRing = m.top.findNode("focusRing")
    m.titleLbl = m.top.findNode("titleLbl")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    ApplyFocus()
end sub

sub OnThemeChanged()
    ApplyFocus()
end sub

sub ApplyAll()
    if m.titleLbl <> invalid and m.top.title <> invalid then m.titleLbl.text = m.top.title
    uri = m.top.thumbnailUri
    if m.thumb <> invalid then
        if uri <> invalid and uri <> "" then
            m.thumb.uri = uri
            m.thumb.visible = true
        else
            m.thumb.visible = false
        end if
    end if
    ApplyFocus()
end sub

sub ApplyFocus()
    focused = m.top.focusedState = true
    if m.focusRing <> invalid then
        m.focusRing.visible = focused
        if focused then
            m.focusRing.color = m.top.cPrimary700
        end if
    end if
    if m.titleLbl <> invalid then
        if focused then
            m.titleLbl.color = m.top.cPrimary700
        else
            m.titleLbl.color = m.top.cNeutral50
        end if
    end if
    if m.thumb <> invalid then
        if focused then
            m.thumb.scale = [1.05, 1.05]
        else
            m.thumb.scale = [1.0, 1.0]
        end if
    end if
end sub
