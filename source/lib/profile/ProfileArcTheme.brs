' Portal gradient for profile auto-select ring (parity with React netComponent linearGradient).

function ProfileArcFallbackPrimaryHex() as string
    return "#0b75e0"
end function

function ProfileArcFallbackSecondaryHex() as string
    return "#d355cb"
end function

function ProfileArcFallbackTertiaryHex() as string
    return "#ff6b00"
end function

function ProfileArcHexToRoku(hex as string) as string
    if hex = invalid or hex = "" then return "0x000000ff"
    h = hex
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) = 8 then return "0x" + h
    if Len(h) = 6 then return "0x" + h + "ff"
    return "0x000000ff"
end function

function ProfilePortalRokuColors(resolved as object) as object
    primary = ProfileArcFallbackPrimaryHex()
    secondary = ProfileArcFallbackSecondaryHex()
    tertiary = ProfileArcFallbackTertiaryHex()
    if resolved <> invalid then
        if resolved.portalPrimaryColor <> invalid and resolved.portalPrimaryColor <> "" then
            primary = resolved.portalPrimaryColor
        end if
        if resolved.portalSecondaryColor <> invalid and resolved.portalSecondaryColor <> "" then
            secondary = resolved.portalSecondaryColor
        end if
        if resolved.portalTertiaryColor <> invalid and resolved.portalTertiaryColor <> "" then
            tertiary = resolved.portalTertiaryColor
        end if
    end if
    return {
        primary: ProfileArcHexToRoku(primary)
        secondary: ProfileArcHexToRoku(secondary)
        tertiary: ProfileArcHexToRoku(tertiary)
    }
end function

function ProfileArcRgbKey(c as string) as string
    if c = invalid or c = "" then return "000000"
    h = c
    if Left(h, 2) = "0x" then h = Mid(h, 3)
    if Len(h) >= 8 then h = Left(h, 6)
    return LCase(h)
end function

function ProfileArcColorKey(primary as string, secondary as string, tertiary as string) as string
    return ProfileArcRgbKey(primary) + "_" + ProfileArcRgbKey(secondary) + "_" + ProfileArcRgbKey(tertiary)
end function

function ProfileArcParseRokuRgb(c as string) as object
    if c = invalid or c = "" then return { r: 0, g: 0, b: 0 }
    h = c
    if Left(h, 2) = "0x" then h = Mid(h, 3)
    if Len(h) < 6 then return { r: 0, g: 0, b: 0 }
    return {
        r: val("0x" + Left(h, 2))
        g: val("0x" + Mid(h, 3, 2))
        b: val("0x" + Mid(h, 5, 2))
    }
end function

function ProfileArcFrameSuffix(idx as integer) as string
    suffix = idx.ToStr()
    if idx < 10 then
        suffix = "00" + suffix
    else if idx < 100 then
        suffix = "0" + suffix
    end if
    return suffix
end function

function ProfileArcTmpFramePath(idx as integer, key as string) as string
    return "tmp:/parc_" + key + "_" + ProfileArcFrameSuffix(idx) + ".png"
end function

function ProfileArcEnsureGlobalFields(global as object) as void
    if global = invalid then return
    if not global.hasField("profileArcBakeKey") then
        global.addFields({
            profileArcBakeKey: ""
            profileArcBakeReady: false
        })
    end if
end function

function ProfileArcResolvedFrameUri(idx as integer, primary as string, secondary as string, tertiary as string, global as object) as string
    key = ProfileArcColorKey(primary, secondary, tertiary)
    if global <> invalid then
        ProfileArcEnsureGlobalFields(global)
        if global.profileArcBakeReady = true and global.profileArcBakeKey = key then
            return ProfileArcTmpFramePath(idx, key)
        end if
    end if
    return ProfileArcFrameUriForIndex(idx)
end function

function ProfileArcRuntimeBakeEnabled() as boolean
    di = CreateObject("roDeviceInfo")
    if di = invalid then return true
    fn = di.GetFriendlyName()
    if fn = invalid or fn = "" then return true
    s = LCase(fn.ToStr())
    if Instr(1, s, "simulator") > 0 then return false
    if Instr(1, s, "brightscript") > 0 then return false
    return true
end function

sub ProfileArcStartBake(task as object, global as object, primary as string, secondary as string, tertiary as string)
    if not ProfileArcRuntimeBakeEnabled() then return
    if task = invalid then return
    key = ProfileArcColorKey(primary, secondary, tertiary)
    if global <> invalid then
        ProfileArcEnsureGlobalFields(global)
        if global.profileArcBakeReady = true and global.profileArcBakeKey = key then return
        global.profileArcBakeReady = false
    end if
    if task.control = "run" and task.colorKey = key then return
    print "[PROFILE_ARC_DBG] bake_start key=" + key
    task.portalPrimary = primary
    task.portalSecondary = secondary
    task.portalTertiary = tertiary
    task.colorKey = key
    task.done = false
    task.control = "RUN"
end sub

function ProfileArcLerpInt(a as integer, b as integer, t as float) as integer
    return Int(a + ((b - a) * t) + 0.5)
end function

' React netComponent linearGradient stops: 70% primary, 90% secondary, 100% tertiary.
function ProfileArcGradientRgbChannels(t as float, primary as object, secondary as object, tertiary as object) as object
    if t <= 0.7 then return primary
    if t <= 0.9 then
        f = (t - 0.7) / 0.2
        return {
            r: ProfileArcLerpInt(primary.r, secondary.r, f)
            g: ProfileArcLerpInt(primary.g, secondary.g, f)
            b: ProfileArcLerpInt(primary.b, secondary.b, f)
        }
    end if
    f = (t - 0.9) / 0.1
    if f > 1.0 then f = 1.0
    return {
        r: ProfileArcLerpInt(secondary.r, tertiary.r, f)
        g: ProfileArcLerpInt(secondary.g, tertiary.g, f)
        b: ProfileArcLerpInt(secondary.b, tertiary.b, f)
    }
end function

function ProfileArcReactGradientT(x as integer, y as integer, wm as integer, hm as integer, cx as float, cy as float) as float
    if wm < 1 or hm < 1 then return 0.0
    dx = x - cx
    dy = y - cy
    gx = cx - dy
    gy = cy + dx
    px = gx / wm
    py = gy / hm
    t = (px + py) / 2.0
    if t < 0.0 then t = 0.0
    if t > 1.0 then t = 1.0
    return t
end function

sub ProfileArcBakeOneFrame(frameIdx as integer, key as string, primary as object, secondary as object, tertiary as object)
    mask = CreateObject("roBitmap", ProfileArcMaskFrameUriForIndex(frameIdx))
    if mask = invalid then return
    w = mask.GetWidth()
    h = mask.GetHeight()
    if w < 2 or h < 2 then return
    bytes = mask.GetByteArray(0, 0, w, h)
    if bytes = invalid then return

    wm = w - 1
    hm = h - 1
    cx = wm / 2.0
    cy = hm / 2.0

    for y = 0 to h - 1
        rowBase = y * w * 4
        for x = 0 to w - 1
            i = rowBase + (x * 4)
            a = bytes[i]
            if a >= 24 then
                t = ProfileArcReactGradientT(x, y, wm, hm, cx, cy)
                rgb = ProfileArcGradientRgbChannels(t, primary, secondary, tertiary)
                bytes[i] = a
                bytes[i + 1] = rgb.r
                bytes[i + 2] = rgb.g
                bytes[i + 3] = rgb.b
            else
                bytes[i] = 0
                bytes[i + 1] = 0
                bytes[i + 2] = 0
                bytes[i + 3] = 0
            end if
        end for
    end for

    out = CreateObject("roBitmap", { width: w, height: h, AlphaEnable: true })
    if out = invalid then return
    out.SetByteArray(0, 0, w, h, bytes)
    out.WriteFile(ProfileArcTmpFramePath(frameIdx, key))
end sub
