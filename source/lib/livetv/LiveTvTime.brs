' LiveTvTime.brs — local calendar math parity with JS new Date(); setHours(0,0,0,0).
' Offset from roDateTime.GetTimeZoneOffset(); host fallback in LiveTvDevTz.brs for brs-engine.

function LT_InferOffsetFromToLocalTime() as integer
    utc = CreateObject("roDateTime")
    utc.Mark()
    utcMins = utc.GetHours() * 60 + utc.GetMinutes()
    loc = CreateObject("roDateTime")
    loc.Mark()
    loc.ToLocalTime()
    locMins = loc.GetHours() * 60 + loc.GetMinutes()
    delta = utcMins - locMins
    while delta > 720
        delta = delta - 1440
    end while
    while delta < -720
        delta = delta + 1440
    end while
    return delta
end function

function LT_SimTimeZoneOffsetMin() as integer
    dt = CreateObject("roDateTime")
    dt.Mark()
    return dt.GetTimeZoneOffset()
end function

function LT_TimeZoneOffsetMin() as integer
    ' make sim writes full host offset (e.g. IST -330). brs-engine often returns a
    ' partial value (e.g. -326) that must not override the host file.
    devOff = LT_DevHostTimeZoneOffsetMin()
    if devOff <> 0 then return devOff
    offset = LT_SimTimeZoneOffsetMin()
    if offset <> 0 then return offset
    return LT_InferOffsetFromToLocalTime()
end function

function LT_NowMs() as longinteger
    dt = CreateObject("roDateTime")
    dt.Mark()
    return dt.AsSeconds() * 1000&
end function

' Local midnight today as UTC epoch ms (same instant as React timelineStart).
function LT_LocalMidnightMs() as longinteger
    dt = CreateObject("roDateTime")
    dt.Mark()
    utcSec = dt.AsSeconds()
    offsetMin = LT_TimeZoneOffsetMin()
    localSec = utcSec - offsetMin * 60
    midnightSec = Int(localSec / 86400) * 86400 + offsetMin * 60
    return midnightSec * 1000&
end function

' Epoch ms → Unix seconds without ms/1000 or Val(large) — both lose precision on brs-engine.
function LT_SecFromMs(ms as longinteger) as longinteger
    if ms <= 0 then return 0&
    s = Str(ms).Trim()
    n = Len(s)
    if n <= 3 then return 0&
    secStr = Left(s, n - 3)
    sec& = 0&
    for i = 1 to Len(secStr)
        ch = Mid(secStr, i, 1)
        d = Int(Val(ch))
        if d >= 0 and d <= 9 then
            sec& = sec& * 10& + Int(d)
        end if
    end for
    return sec&
end function

function LT_LocalPartsFromUtcMs(ms as longinteger) as object
    offsetMin = LT_TimeZoneOffsetMin()
    offSec& = offsetMin * 60&
    sec& = LT_SecFromMs(ms)
    localSec& = sec& - offSec&
    daySec& = localSec& Mod 86400&
    if daySec& < 0 then daySec& = daySec& + 86400&
    hours = Int(daySec& / 3600&)
    minutes = Int((daySec& Mod 3600&) / 60&)
    return { hours: hours, minutes: minutes }
end function

function LT_LocalHours(ms as longinteger) as integer
    parts = LT_LocalPartsFromUtcMs(ms)
    return parts.hours
end function

function LT_LocalMinutes(ms as longinteger) as integer
    parts = LT_LocalPartsFromUtcMs(ms)
    return parts.minutes
end function
