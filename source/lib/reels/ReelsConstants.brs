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
    ' React reels index.tsx: border-[1px] on the video frame.
    return 1
end function

function RL_VideoRadius() as integer
    ' React inner video/poster: rounded-[10px].
    return 10
end function

function RL_VideoOuterRadius() as integer
    ' React outer frame: rounded-[12px].
    return 12
end function

function RL_VideoBorderColor() as string
    return "0xa3a3a3ff"
end function

' NEW_UI detail host — React index.tsx: left: calc(50% + 28.125vh) at FHD.
function RL_NewUiPanelLeft() as integer
    return Int(960.0 + (28.125 * 1080.0 / 100.0) + 0.5)
end function

' Overlay on NEW_UI: p-l-40 (index.tsx detail panel wrapper).
function RL_NewUiOverlayPadLeft() as integer
    return 40
end function

' ReelDetailPanel NEW_UI: p-x-20 p-b-40 gap-12.
function RL_NewUiPanelPadX() as integer
    return 20
end function

function RL_NewUiPanelPadBottom() as integer
    return 40
end function

function RL_NewUiCardGap() as integer
    return 12
end function

function RL_NewUiActionsMt() as integer
    return 8
end function

function RL_NewUiActionsMl() as integer
    return 12
end function

function RL_NewUiMusicGap() as integer
    ' ReelDetailPanel gap-6 — not in custom gap tokens → Tailwind default 1.5rem = 24px.
    return 24
end function

function RL_NewUiMusicIcon() as integer
    ' w-8 h-8 = 2rem = 32px (width tokens are not FontScale-scaled).
    return 32
end function

function RL_NewUiAvatarSize() as integer
    return 64
end function

function RL_NewUiAvatarTextGap() as integer
    ' flex items-center gap-12 → --gap-12 = 0.75rem = 12px.
    return 12
end function

' FontScale.LARGE → RL_RemPx — matches fs-30 / fs-22 / fs-18 / fs-20 in ReelDetailPanel.tsx.
function RL_NewUiTitleFont() as integer
    return RL_RemPx(1.875)
end function

function RL_NewUiCreatorFont() as integer
    return RL_RemPx(1.375)
end function

function RL_NewUiGenreFont() as integer
    return RL_RemPx(1.125)
end function

function RL_NewUiCountFont() as integer
    return RL_RemPx(1.25)
end function

function RL_NewUiCardW() as integer
    return 543
end function

function RL_NewUiTitleCardH() as integer
    ' p-y-16 + 2×fs-30 leading-tight + m-b-8 + music row 32 + p-y-16.
    return 16 + (RL_NewUiTitleFont() * 2) + 8 + 32 + 16
end function

function RL_NewUiUserCardH() as integer
    ' p-y-16 + avatar 64 + p-y-16.
    return 96
end function

function RL_NewUiActionsBlockH() as integer
    ' Circle 80 + gap-3 (12) + count line (~fs-20).
    return 80 + 12 + RL_NewUiCountFont() + 4
end function

' CLEAN_UI — ReelDetailPanel.tsx left info max-w-[400px] / right pl-[80px] gap-10.
function RL_CleanUiCardW() as integer
    return 400
end function

function RL_CleanUiCardPadX() as integer
    return 20
end function

function RL_CleanUiCardPadY() as integer
    return 16
end function

function RL_CleanUiInfoPr() as integer
    ' Left column pr-[30px] before the video spacer.
    return 30
end function

function RL_CleanUiActionsPl() as integer
    ' Right column pl-[80px] after the video spacer.
    return 80
end function

function RL_CleanUiCardGap() as integer
    ' theme.css --gap-8: 0.5rem.
    return 8
end function

function RL_CleanUiActionsGap() as integer
    ' theme.css --gap-10: 0.625rem.
    return 10
end function

function RL_CleanUiTitleMb() as integer
    ' m-b-12 under title before genre pills.
    return 12
end function

function RL_CleanUiAvatarSize() as integer
    return 48
end function

function RL_CleanUiAvatarTextGap() as integer
    ' theme.css --gap-4: 0.25rem (avatar → name).
    return 4
end function

function RL_CleanUiTitleFont() as integer
    return RL_RemPx(1.875)
end function

function RL_CleanUiTitleLineH() as integer
    ' Roku clips the whole label when height ≈ font size; need extra box vs CSS leading-tight.
    return RL_CleanUiTitleFont() + 20
end function

function RL_CleanUiCreatorFont() as integer
    return RL_RemPx(1.25)
end function

function RL_CleanUiGenreFont() as integer
    ' text-sm @ FontScale LARGE.
    return RL_RemPx(0.875)
end function

function RL_CleanUiCountFont() as integer
    return RL_RemPx(1.25)
end function

function RL_CleanUiUserCardH() as integer
    return RL_CleanUiCardPadY() + RL_CleanUiAvatarSize() + RL_CleanUiCardPadY()
end function

' CommentSidebar.tsx: width 650, maxWidth 50vw → 650 at FHD.
function RL_CommentSidebarW() as integer
    return 650
end function

function RL_CommentSidebarBg() as string
    ' CommentSidebar.tsx hardcoded #14141c.
    return "0x14141cff"
end function

function RL_CommentSidebarScrim() as string
    ' CommentSidebar.tsx rgba(0,0,0,0.3).
    return "0x0000004d"
end function

' Netflix header clearance — React reels `top-[96px]` (= var(--p-96)).
function RL_ShellTopInset() as integer
    if ThemeIsNetflixHeader() then return 96
    return 0
end function

function RL_ContentH() as integer
    return 1080 - RL_ShellTopInset()
end function

' Outer frame (incl. border) fits the content band so bottom rounded corners
' stay on-screen. React border-[1px] sits on the same h-full box (not outside it).
function RL_VideoOuterH() as integer
    return RL_ContentH()
end function

function RL_VideoOuterW() as integer
    return Int(RL_VideoOuterH() * 9.0 / 16.0 + 0.5)
end function

function RL_VideoH() as integer
    return RL_VideoOuterH() - (RL_VideoBorderW() * 2)
end function

function RL_VideoW() as integer
    return RL_VideoOuterW() - (RL_VideoBorderW() * 2)
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

function RL_InitialFocusSec() as float
    return 0.1
end function

function RL_SwitchAnimSec() as float
    return 0.45
end function

function RL_CommentLimit() as integer
    return 10
end function

function RL_CommentFocusSec() as float
    return 0.35
end function

function RL_SidebarCloseSec() as float
    ' CommentSidebar.tsx comment-sidebar-exit: 250ms ease-in.
    return 0.25
end function

function RL_SidebarEnterSec() as float
    ' CommentSidebar.tsx comment-sidebar-enter: 300ms cubic-bezier(0.22, 1, 0.36, 1).
    return 0.3
end function

function RL_FocusTransitionSec() as float
    ' ReelDetailPanel NewCircleButton / NewDetailCard: transition-all duration-400 ease-out.
    return 0.4
end function

function RL_SidebarRefocusSec() as float
    return 0.3
end function

function RL_LikeErrorCopy() as string
    return "Failed to update like"
end function

function RL_CommentsErrorCopy() as string
    return "Failed to load comments"
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

sub ReelsDbg(tag as string, msg as string)
    print "[REELS_SOCIAL_DBG] " + tag + " " + msg
end sub

function ReelsDbgStr(val as dynamic) as string
    if val = invalid then return "invalid"
    if val = true then return "true"
    if val = false then return "false"
    return Str(val).Trim()
end function

sub ReelsDbgApi(tag as string, api as object)
    if api = invalid then
        ReelsDbg(tag, "api=invalid")
        return
    end if
    ok = false
    status = 0
    msg = ""
    if api.ok <> invalid then ok = api.ok
    if api.statusCode <> invalid then status = api.statusCode
    if api.message <> invalid then msg = api.message.ToStr()
    ReelsDbg(tag, "ok=" + ReelsDbgStr(ok) + " status=" + Str(status).Trim() + " message=" + Left(msg, 100))
end sub

sub ReelsDbgThumbProbe(reel as object, index as integer)
    if reel = invalid then return
    ReelsDbg("thumbnail", "index=" + Str(index).Trim() + " mobileVertical=" + ReelsDbgStr(ReelsVerticalThumb(reel) <> ""))
end sub
