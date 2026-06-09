sub init()
    m.focusBorder = m.top.findNode("focusBorder")
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
    w = 240
    h = 300
    if m.top.listType = true then
        w = 272
        h = 340
    end if
    m.focusBorder.boxWidth = w + 6
    m.focusBorder.boxHeight = h + 6
    m.skeleton.boxWidth = w
    m.skeleton.boxHeight = h
    m.thumb.width = w
    m.thumb.height = h

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
    CardApplySkeleton(m.skeleton, m.top.cNeutral700, m.top.cNeutral800)
    CardApplyFocusBorder(m.focusBorder, m.top.focusedState, m.top.cPrimary500)
end sub
