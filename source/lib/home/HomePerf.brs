' HomePerf.brs — optional CW/boot timing hooks (no-op in production builds).

function CwPerfMs(span as object) as integer
    if span = invalid then return -1
    return span.TotalMilliseconds()
end function

sub CwPerfMark(span as object, tag as string, detail = "" as string)
end sub

sub CwPerfInstant(tag as string, detail = "" as string)
end sub

function CwPerfBool(v as boolean) as string
    if v then return "true"
    return "false"
end function

sub HomeBootLog(span as object, tag as string, detail = "" as string)
end sub
