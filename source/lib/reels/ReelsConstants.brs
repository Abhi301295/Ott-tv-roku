' ReelsConstants.brs — parity with features/reels/ @ FontScale LARGE, FHD 1080.
' Baseline from reelsDbgPrintTokenSpec() in src/features/reels/reelsDbg.ts.

function RL_FontScale() as float
    return 1.2
end function

function RL_RootPx() as integer
    return 16
end function

function RL_RemPx(baseRem as float) as integer
    return Int(baseRem * RL_FontScale() * RL_RootPx() + 0.5)
end function

function RL_VideoBorderW() as integer
    return 4
end function

function RL_VideoRadius() as integer
    return 10
end function

function RL_VideoBorderColor() as string
    return "0xa3a3a3ff"
end function

' max-w-[56.25vh] at 1080p → 607.5px; 9:16 aspect at full height.
function RL_VideoH() as integer
    return 1080
end function

function RL_VideoW() as integer
    return 608
end function

function RL_ProgressMaxW() as integer
    return 700
end function

function RL_ProgressH() as integer
    return 8
end function

function RL_ProgressBottom() as integer
    return 4
end function

function RL_MetaBottom() as integer
    ' React absolute bottom-28 → 7rem @ 16px = 112px.
    return 112
end function

function RL_MetaPadBottom() as integer
    ' React inner p-b-80 → var(--p-80) = 5rem = 80px.
    return 80
end function

function RL_MetaVideoGap() as integer
    return 32
end function

function RL_ProgressPadX() as integer
    return 32
end function

function RL_VideoProgressW(videoW as integer) as integer
    inner = videoW - (RL_ProgressPadX() * 2)
    if inner > RL_ProgressMaxW() then return RL_ProgressMaxW()
    if inner < 200 then return 200
    return inner
end function

function RL_MetaBottomReserve() as integer
    return RL_MetaBottom() + RL_MetaPadBottom()
end function

function RL_MetaLeft() as integer
    return 32
end function

function RL_MetaPadX() as integer
    return 64
end function

function RL_MetaMaxW() as integer
    return 896
end function

function RL_CreatedByFontSize() as integer
    return RL_RemPx(1.25)
end function

function RL_ContentTypeFontSize() as integer
    return RL_RemPx(1.5)
end function

function RL_TitleFontSize() as integer
    return RL_RemPx(3.125)
end function

function RL_DescFontSize() as integer
    return RL_RemPx(1.5)
end function

function RL_PillFontSize() as integer
    return RL_RemPx(1.25)
end function

function RL_PillPadX() as integer
    return 16
end function

function RL_PillPadY() as integer
    return 8
end function

function RL_PillGap() as integer
    return 12
end function

function RL_PillRowGap() as integer
    return 12
end function

function RL_OverlayRingSize() as integer
    return 128
end function

function RL_SeekPreviewMs() as float
    return 0.8
end function

function RL_SeekStepSec() as integer
    return 10
end function

function RL_PageLimit() as integer
    return 10
end function

function RL_PrefetchThreshold() as integer
    return 3
end function

function RL_SeedMin() as integer
    return 100000
end function

function RL_SeedMax() as integer
    return 999999
end function

function RL_SkeletonMaxSec() as float
    return 12.0
end function

function RL_EmptyCopy() as string
    return "No reels available right now."
end function

function RL_ErrorCopy() as string
    return "Failed to load reels"
end function

function RL_PillShapeUri() as string
    ' Solid white pill — tint via blendColor (LoginTabButton pattern). Avoid toast_cap_* (gradient caps).
    return "pkg:/images/ui/tab_phone.png"
end function

function RL_AvatarSize() as integer
    return 32
end function

function RL_DescMaxLines() as integer
    return 2
end function

function RL_VideoSkeletonShapeUri() as string
    return "pkg:/images/ui/sk_base.png"
end function

function RL_DummyThumbPosterUri() as string
    ' Full-frame fallback — React posterUrl uses Images.THUMBNAIL when no vertical thumb.
    return "pkg:/images/ui/reels_thumb_placeholder.png"
end function

function RL_DummyThumbBgHex() as string
    return "#fafafb"
end function

function RL_OverlayCircleSize() as integer
    return 112
end function

function RL_OverlayPlaySize() as integer
    return 80
end function

function RL_OverlayPauseSize() as integer
    ' React buffering pause SVG w-50 ht-50.
    return 50
end function

' React reels play/pause SVG fill="blue" (not theme primary).
function RL_OverlayIconBlue() as string
    return "0x0000ffff"
end function

function RL_OverlayCircleOpacity() as float
    ' React bg-black/70 on the inner disc.
    return 0.7
end function

' brs-desktop reports friendly name "BrightScript Simulator" — its HTML5 video plane
' does not honor embedded width/height the way real Roku hardware does (see
' HeroBannerCinematic.xml, VideoPlayerScreen.brs). Inline reel video is device-only.
function ReelsIsSimulator() as boolean
    di = CreateObject("roDeviceInfo")
    if di = invalid then return false
    fn = di.GetFriendlyName()
    if fn = invalid or fn = "" then return false
    s = LCase(fn.ToStr())
    if Instr(1, s, "simulator") > 0 then return true
    if Instr(1, s, "brightscript") > 0 then return true
    return false
end function

function ReelsUseInlineVideo() as boolean
    return not ReelsIsSimulator()
end function
