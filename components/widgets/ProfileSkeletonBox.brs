sub init()
    m.glow = m.top.findNode("glow")
    m.sk = m.top.findNode("sk")
    ApplyLayout()
    ApplyColors()
    OnRunningChanged()
end sub

sub OnLayoutChanged()
    ApplyLayout()
    OnRunningChanged()
end sub

sub OnColorsChanged()
    ApplyColors()
end sub

sub OnRunningChanged()
    active = (m.top.running = true)
    if m.sk <> invalid then m.sk.running = active
    if m.glow <> invalid then
        ' Glow tracks glowVisible — shimmer running is separate (React box-shadow is always on the wrapper).
        m.glow.visible = (m.top.glowVisible = true)
    end if
end sub

function BoxScale() as float
    scale = m.top.layoutScale
    if scale < 1.0 then scale = 1.0
    return scale
end function

function ScaleInt(v as float) as integer
    return Int(v + 0.5)
end function

function ResolveGlowUri() as string
    kind = m.top.glowKind
    if kind = "pill" then return SkeletonProfileNameGlowUri()
    if kind = "avatarSquare" then return SkeletonProfileAvatarGlowUri(true)
    return SkeletonProfileAvatarGlowUri(false)
end function

function ResolveGlowSize() as object
    kind = m.top.glowKind
    if kind = "pill" then return SkeletonProfileNameGlowSize()
    return SkeletonProfileAvatarGlowSize()
end function

sub ApplyLayout()
    if m.sk = invalid then return
    scale = BoxScale()
    bw = ScaleInt(m.top.boxWidth * scale)
    bh = ScaleInt(m.top.boxHeight * scale)

    m.sk.translation = [0, 0]
    m.sk.boxWidth = bw
    m.sk.boxHeight = bh
    if m.top.shapeUri <> invalid and m.top.shapeUri <> "" then
        m.sk.shapeUri = m.top.shapeUri
    end if

    if m.glow = invalid then return
    glowUri = ResolveGlowUri()
    glowBase = ResolveGlowSize()
    pads = SkeletonGlowLayoutPads(glowUri)
    padX = ScaleInt(pads.padX * scale)
    padY = ScaleInt(pads.padY * scale)

    m.glow.uri = glowUri
    m.glow.translation = [-padX, -padY]
    m.glow.width = ScaleInt(glowBase[0] * scale)
    m.glow.height = ScaleInt(glowBase[1] * scale)
    ApplySkeletonGlowPoster(m.glow)
end sub

sub ApplyColors()
    if m.sk = invalid then return
    m.sk.baseColor = m.top.baseColor
    m.sk.highlightColor = m.top.highlightColor
end sub
