sub init()
    m.focusBorder = m.top.findNode("focusBorder")
    m.rankLabel = m.top.findNode("rankLabel")
    m.thumb = m.top.findNode("thumb")
    m.skeleton = m.top.findNode("skeleton")
    m.thumb.observeField("loadStatus", "OnThumbLoad")
    ApplyAll()
end sub

sub OnDataChanged()
    ApplyAll()
end sub

sub OnFocusChanged()
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub

sub OnThemeChanged()
    ApplyAll()
end sub

sub OnThumbLoad()
    CardOnPosterLoad(m.thumb, m.skeleton)
end sub

sub ApplyAll()
    m.rankLabel.text = Str(m.top.rank + 1)
    m.rankLabel.color = m.top.cNeutral50

    uri = m.top.thumbnailUri
    if uri <> invalid and uri <> "" then
        m.thumb.uri = uri
        m.thumb.visible = true
        m.skeleton.visible = true
        m.skeleton.running = true
    else
        m.thumb.visible = false
        m.skeleton.visible = true
        m.skeleton.running = true
    end if
    m.skeleton.baseColor = m.top.cPrimary700
    m.skeleton.highlightColor = m.top.cPrimary500
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
