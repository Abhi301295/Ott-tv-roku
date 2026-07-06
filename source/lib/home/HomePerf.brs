' HomePerf.brs — CW/boot timing hooks for telnet perf reports.
' Grep telnet for [BOOT] and [PERF]. Toggle via HomePerfEnabled().

function HomePerfEnabled() as boolean
  return true
end function

function CwPerfMs(span as object) as integer
  if span = invalid then return -1
  return span.TotalMilliseconds()
end function

sub CwPerfMark(span as object, tag as string, detail = "" as string)
  if not HomePerfEnabled() then return
  ms = CwPerfMs(span)
  line = "[PERF] " + tag
  if ms >= 0 then line = line + " +" + Str(ms).Trim() + "ms"
  if detail <> "" then line = line + " " + detail
  print line
end sub

sub CwPerfInstant(tag as string, detail = "" as string)
  if not HomePerfEnabled() then return
  line = "[PERF] " + tag
  if detail <> "" then line = line + " " + detail
  print line
end sub

function CwPerfBool(v as boolean) as string
  if v then return "true"
  return "false"
end function

sub HomeBootLog(span as object, tag as string, detail = "" as string)
  if not HomePerfEnabled() then return
  ms = CwPerfMs(span)
  line = "[BOOT] " + tag
  if ms >= 0 then line = line + " +" + Str(ms).Trim() + "ms"
  if detail <> "" then line = line + " " + detail
  print line
end sub
