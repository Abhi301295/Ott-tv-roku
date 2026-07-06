' BrowsePageLoader.brs — PageContainer bg-black + HomeLoader (spinner.tsx).
' Screens implement OnBrowseLoaderTimeout() to force-hide when paint never signals.
' Host fields: top, bg, loaderHost, loaderPageBg, pageLoader, pageBgRest, tokens,
' cNeutral700, cNeutral50, cPrimary600, loaderVeilBg (optional), loaderParent (optional).

function BrowseLoaderMaxSec() as float
    return 12.0
end function

function BrowseLoaderPageBg(host as object) as string
    if host <> invalid and host.loaderVeilBg <> invalid and host.loaderVeilBg <> "" then return host.loaderVeilBg
    return "0x000000ff"
end function

sub BrowseApplyPageLoaderColors(host as object)
    if host = invalid or host.pageLoader = invalid then return
    tokens = host.tokens
    if tokens = invalid then tokens = {}
    ring = ""
    arc = ""
    if host.cNeutral50 <> invalid and host.cNeutral50 <> "" then ring = host.cNeutral50
    if host.cPrimary600 <> invalid and host.cPrimary600 <> "" then arc = host.cPrimary600
    if ring = "" then ring = ThemeTokenColor(tokens, "neutral-50", "#f5f5f5")
    if arc = "" then arc = ThemeTokenColor(tokens, "primary-600", "#0760bb")
    host.pageLoader.neutral50 = ring
    host.pageLoader.primary600 = arc
end sub

sub BrowseApplyLoaderVeil(host as object, show as boolean, restingPageBg as string)
    if host = invalid then return
    if show then
        bg = BrowseLoaderPageBg(host)
        if host.bg <> invalid then host.bg.color = bg
        if host.loaderPageBg <> invalid then
            host.loaderPageBg.color = bg
            host.loaderPageBg.visible = true
        end if
    else
        if host.loaderPageBg <> invalid then host.loaderPageBg.visible = false
        if restingPageBg <> invalid and restingPageBg <> "" and host.bg <> invalid then
            host.bg.color = restingPageBg
        end if
    end if
end sub

sub BrowseRaiseLoaderHost(host as object)
    if host = invalid or host.loaderHost = invalid then return
    host.loaderHost.visible = true
    parent = host.top
    if host.loaderParent <> invalid then parent = host.loaderParent
    if parent <> invalid then parent.appendChild(host.loaderHost)
end sub

sub BrowseStartLoaderAnim(loader as object)
    if loader = invalid then return
    if loader.running = true then
        BrowseNudgeLoaderSpin(loader)
        return
    end if
    loader.running = true
end sub

sub BrowseNudgeLoaderSpin(loader as object)
    if loader = invalid then return
    loader.callFunc("NudgeSpin", invalid)
end sub

sub BrowseRestartLoaderAnim(loader as object)
    if loader = invalid then return
    if loader.running <> true then
        loader.running = true
        return
    end if
    BrowseNudgeLoaderSpin(loader)
end sub

sub BrowseEnsureLoaderRunning(host as object)
    if host = invalid or host.pageLoader = invalid then return
    if host.pageLoader.running <> true then
        BrowseShowPageLoader(host, host.pageBgRest)
        return
    end if
    BrowseRaiseLoaderHost(host)
    BrowseApplyLoaderVeil(host, true, host.pageBgRest)
    BrowseNudgeLoaderSpin(host.pageLoader)
end sub

sub BrowseEnsureLoaderTimeout(host as object)
    if host = invalid or host.top = invalid then return
    if host.loaderTimeout <> invalid then return
    t = CreateObject("roSGNode", "Timer")
    t.duration = BrowseLoaderMaxSec()
    t.repeat = false
    host.top.appendChild(t)
    host.loaderTimeout = t
    t.observeField("fire", "OnBrowseLoaderTimeout")
end sub

sub BrowseArmLoaderTimeout(host as object)
    BrowseEnsureLoaderTimeout(host)
    if host.loaderTimeout <> invalid then host.loaderTimeout.control = "start"
end sub

sub BrowseDisarmLoaderTimeout(host as object)
    if host = invalid or host.loaderTimeout = invalid then return
    host.loaderTimeout.control = "stop"
end sub

function BrowsePageLoaderRunning(host as object) as boolean
    if host = invalid or host.pageLoader = invalid then return false
    return host.pageLoader.running = true
end function

sub BrowseShowPageLoader(host as object, restingPageBg as string)
    if host = invalid then return
    BrowseRaiseLoaderHost(host)
    BrowseApplyLoaderVeil(host, true, restingPageBg)
    BrowseApplyPageLoaderColors(host)
    BrowseStartLoaderAnim(host.pageLoader)
    BrowseArmLoaderTimeout(host)
end sub

' hideHost=false keeps loaderHost mounted (Home).
' Drop the veil first so the spinner never freezes on screen over an empty frame.
sub BrowseHidePageLoader(host as object, restingPageBg as string, hideHost=true as boolean)
    if host = invalid then return
    BrowseDisarmLoaderTimeout(host)
    if hideHost and host.loaderHost <> invalid then host.loaderHost.visible = false
    if host.pageLoader <> invalid then host.pageLoader.running = false
    BrowseApplyLoaderVeil(host, false, restingPageBg)
end sub

sub BrowseDetachThumbPaintWatch(watch as object)
    if watch = invalid then return
    if watch.hasField("loadStatus") then watch.unobserveField("loadStatus")
end sub

sub BrowseDetachHostPaintWatch(host as object)
    if host = invalid then return
    BrowseDetachThumbPaintWatch(host.thumbPaintWatch)
    host.thumbPaintWatch = invalid
end sub

function BrowseThumbPainted(thumb as object) as boolean
    return BrowseThumbPaintComplete(thumb)
end function

' ready, failed, or no URI — safe to drop the page loader.
function BrowseThumbPaintComplete(thumb as object) as boolean
    if thumb = invalid then return true
    uri = thumb.uri
    if uri = invalid or uri = "" then return true
    status = thumb.loadStatus
    if status = "ready" or status = "failed" then return true
    return false
end function

' Observe thumb loadStatus; returns true when already complete (reveal now).
function BrowseAttachThumbPaintWatch(host as object, thumb as object, callback as string) as boolean
    if host = invalid then return true
    BrowseDetachHostPaintWatch(host)
    if thumb = invalid then return true
    if BrowseThumbPaintComplete(thumb) then return true
    host.thumbPaintWatch = thumb
    thumb.observeField("loadStatus", callback)
    return false
end function
