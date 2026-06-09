' Shared focus ring + poster load handling for home card widgets.

sub CardApplyFocusBorder(border as object, focused as boolean, color as string)
    if border = invalid then return
    border.visible = focused
    if focused and color <> invalid and color <> "" then
        ' The focus frame is a tintable 9-patch Poster (rounded, even border) — tint it via
        ' blendColor. Fall back to .color for any legacy Rectangle border.
        if border.hasField("blendColor") then
            border.blendColor = color
        else if border.hasField("color") then
            border.color = color
        end if
    end if
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

sub CardInjectTheme(card as object, primary500 as string, primary600 as string, primary700 as string, neutral50 as string, neutral800 as string, neutral700 = "" as string)
    if card = invalid then return
    if card.hasField("cPrimary500") then card.cPrimary500 = primary500
    if card.hasField("cPrimary600") then card.cPrimary600 = primary600
    if card.hasField("cPrimary700") then card.cPrimary700 = primary700
    if card.hasField("cNeutral50") then card.cNeutral50 = neutral50
    if card.hasField("cNeutral800") then card.cNeutral800 = neutral800
    if neutral700 <> "" and card.hasField("cNeutral700") then card.cNeutral700 = neutral700
end sub

' Placeholder shimmer — parity with React bg-neutral-700 / neutral-800 pulse.
sub CardApplySkeleton(skeleton as object, neutral700 as string, neutral800 as string)
    if skeleton = invalid then return
    base = neutral700
    highlight = neutral800
    if base = invalid or base = "" then base = "0x404040ff"
    if highlight = invalid or highlight = "" then highlight = "0x262626ff"
    skeleton.baseColor = base
    skeleton.highlightColor = highlight
    ' Shimmer the card placeholder while its thumbnail loads (it stops itself on load),
    ' so a loading row reads as an intentional shimmer, not flat grey boxes.
    if skeleton.hasField("animate") then skeleton.animate = true
end sub
