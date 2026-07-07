' ProfileUiSpec.brs — numeric parity with React profile.tsx + userProfile.tsx (case 4/6).
' Values from theme.css + tailwind (FHD_1080, FontScale LARGE). Grep [PROFILE_UI] to compare.

function ProfileUiDebugEnabled() as boolean
    return false
end function

function ProfileUiSpec() as object
    return {
        ' profile.tsx screen chrome
        screenPadX: 40
        listPadLeft: 24
        contentMarginTop: 128       ' mt-32
        titleMarginTop: 24          ' mt-6 on h1
        titleMarginBottom: 64        ' m-b-64
        titleFont: 41                ' fs-34 * 1.2 (LARGE)
        titleX: 64                   ' p-x-40 + pl-24
        titleY: 152                  ' contentMarginTop + titleMarginTop
        headerBackdropOpacity: 0.30   ' bg-black/30 (profile.tsx header strip)
        headerBackdropPadX: 16
        headerBackdropPadY: 12
        logoY: 48
        profilesX: 64
        profilesY: 265               ' titleY + titleLine + titleMarginBottom

        ' userProfile.tsx Original card
        cardSize: 150
        cardRadius: 12
        cardMarginBottom: 20          ' mb-5 = 1.25rem
        borderWidth: 2               ' bw-2 outer theme border when focused
        innerFaceInset: 6            ' inner gradient face (padding band start)
        innerFaceSize: 138           ' cardSize - innerFaceInset*2
        ringInset: 12                ' inner progress ring — gap from outer border
        innerContentSize: 122        ' initials inside inner ring
        outerFocusScale: 1.25         ' wrapper scale-125 origin-left
        innerFocusScale: 1.25         ' card scale-125 when focused
        focusOffsetX: 0.0            ' square branch has no horizontal pop
        animMs: 300
        animSteps: 18                 ' ~300ms @ 60fps
        initialsFont: 30             ' text-3xl = 1.875rem
        nameFont: 18                 ' text-lg font-medium
        hintFont: 12                 ' text-xs fw-800 (PIN hint)
        hintAutoFont: 18              ' text-lg fw-900 auto-select countdown
        hintMarginTop: 4              ' mt-1 between name and hint
        nameOffsetY: 170             ' card 150 + mb-5 20
        hintOffsetY: 196             ' name + 18 + mt-1 4
        rowGap: 16                   ' profile.tsx space-y-16 (--m-16)
        rowItemMarginTop: 56          ' userProfile.tsx mt-14 (3.5rem @ 16px)
        rowPitch: 206                ' unfocused slot: 150+20+18+16
        ' React flex row stretches full list width; text-center on hint centers in this span.
        hintRowWidth: 1760           ' 1920 - p-x-40*2 (profile list content width)

        ' progress SVG (inner border + fill animation)
        progressStroke: 4
        progressPerimeter: 580
        progressBlue: "0x3b82f6ff"

        ' profile.tsx loading skeleton (SkeletonBox + ml-20 name pill)
        skAvatarSize: 150
        skNameWidth: 190
        skNameHeight: 22
        skNameMarginLeft: 80          ' ml-20
        skRowHeight: 166              ' min-h-[166px]

        ' netComponent.tsx edit/lock badge (-bottom-1 -left-1, w-12 h-12, icon w-6 h-6)
        editBadgeSize: 48
        editIconSize: 24
        editBadgeInset: 4
    }
end function

' TEMP: default on until BE profile-edit permission is wired per profile.
function ProfileEditBadgeDefaultVisible() as boolean
    return true
end function

function ProfileUiRowPitch() as integer
    return ProfileUiSpec().rowPitch
end function

function ProfileUiTitlePos() as object
    s = ProfileUiSpec()
    return { x: s.titleX, y: s.titleY }
end function

function ProfileUiProfilesPos() as object
    s = ProfileUiSpec()
    return { x: s.profilesX, y: ProfileListTopY() }
end function

' Bottom of the title row + margin — profile list must start here (never overlap title).
function ProfileListTopY() as integer
    s = ProfileUiSpec()
    titleLine = s.titleFont + 8
    return s.titleY + titleLine + s.titleMarginBottom
end function

function ProfileListHeaderClipHeight() as integer
    return ProfileListTopY()
end function

function ProfileSquareFocusScale() as float
    s = ProfileUiSpec()
    return s.outerFocusScale * s.innerFocusScale
end function

' Full row height: scaled card + name below + optional hint (no overlap with next row).
function ProfileSquareRowContentHeight(focused as boolean, showHint as boolean) as integer
    s = ProfileUiSpec()
    scale = 1.0
    if focused then scale = ProfileSquareFocusScale()
    cardH = Int(s.cardSize * scale + 0.5)
    nameY = cardH + s.cardMarginBottom
    bottom = nameY + s.nameFont + 4
    if showHint then bottom = bottom + s.hintMarginTop + s.hintAutoFont + 4
    return bottom
end function

function ProfileListViewportBottomY() as integer
    return 954   ' logout at y=970 minus 16px gap
end function

function ProfileListViewportHeight() as integer
    h = ProfileListViewportBottomY() - ProfileListTopY()
    if h < 120 then h = 120
    return h
end function

function ProfileListViewportWidth() as integer
    return ProfileUiSpec().hintRowWidth
end function

function ProfileArcFrameCount() as integer
    return 151
end function

function ProfileArcFrameUriForIndex(idx as integer) as string
    last = ProfileArcFrameCount() - 1
    if idx < 0 then idx = 0
    if idx > last then idx = last
    suffix = idx.ToStr()
    if idx < 10 then
        suffix = "00" + suffix
    else if idx < 100 then
        suffix = "0" + suffix
    end if
    return "pkg:/images/ui/profile_arc_" + suffix + ".png"
end function

function ProfileArcMaskFrameUriForIndex(idx as integer) as string
    last = ProfileArcFrameCount() - 1
    if idx < 0 then idx = 0
    if idx > last then idx = last
    suffix = idx.ToStr()
    if idx < 10 then
        suffix = "00" + suffix
    else if idx < 100 then
        suffix = "0" + suffix
    end if
    return "pkg:/images/ui/profile_arc_mask_" + suffix + ".png"
end function

function ProfileArcFrameUriForProgress(progress as float) as string
    last = ProfileArcFrameCount() - 1
    idx = Int(progress * last + 0.5)
    return ProfileArcFrameUriForIndex(idx)
end function
