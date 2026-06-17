' HomePerf.brs — CW shimmer handoff timing. Grep simulator output for [CW_PERF].

function CwPerfMs(span as object) as integer
    if span = invalid then return -1
    return span.TotalMilliseconds()
end function

sub CwPerfMark(span as object, tag as string, detail = "" as string)
    ms = CwPerfMs(span)
    if detail <> "" then
        print "[CW_PERF] +"; ms; "ms "; tag; " | "; detail
    else
        print "[CW_PERF] +"; ms; "ms "; tag
    end if
end sub

sub CwPerfInstant(tag as string, detail = "" as string)
    if detail <> "" then
        print "[CW_PERF] "; tag; " | "; detail
    else
        print "[CW_PERF] "; tag
    end if
end sub

function CwPerfBool(v as boolean) as string
    if v then return "true"
    return "false"
end function
