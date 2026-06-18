sub init()
    m.poster = m.top.findNode("poster")
    m.upNextTitle = m.top.findNode("upNextTitle")
    OnTitleChanged()
    OnFocusedChanged()
end sub

sub OnPosterUriChanged()
    uri = m.top.posterUri
    if m.poster = invalid then return

    if uri = invalid or uri = "" then
        m.poster.visible = false
        m.poster.uri = ""
        return
    end if

    m.poster.uri = uri
    m.poster.visible = true
end sub

sub OnHeroUriChanged()
end sub

sub OnTitleChanged()
    if m.upNextTitle <> invalid then m.upNextTitle.text = m.top.titleText
end sub

sub OnFocusedChanged()
    if m.upNextTitle = invalid then return
    if m.top.focused = true then
        m.upNextTitle.color = m.top.cNeutral50
    else
        m.upNextTitle.color = "0xf8f1f7cc"
    end if
end sub
