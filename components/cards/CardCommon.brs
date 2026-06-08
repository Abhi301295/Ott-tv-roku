' Shared focus ring + poster load handling for home card widgets.

sub CardApplyFocusBorder(border as object, focused as boolean, color as string)
    if border = invalid then return
    border.visible = focused
    if focused and color <> invalid and color <> "" then border.color = color
end sub

sub CardOnPosterLoad(poster as object, skeleton as object)
    if poster = invalid then return
    status = poster.loadStatus
    if status = "ready" or status = "failed" then
        if skeleton <> invalid then
            skeleton.running = false
            skeleton.visible = false
        end if
        if status = "failed" and poster <> invalid then poster.visible = false
    end if
end sub

sub CardInjectTheme(card as object, primary500 as string, primary600 as string, primary700 as string, neutral50 as string, neutral800 as string)
    if card = invalid then return
    if card.hasField("cPrimary500") then card.cPrimary500 = primary500
    if card.hasField("cPrimary600") then card.cPrimary600 = primary600
    if card.hasField("cPrimary700") then card.cPrimary700 = primary700
    if card.hasField("cNeutral50") then card.cNeutral50 = neutral50
    if card.hasField("cNeutral800") then card.cNeutral800 = neutral800
end sub
