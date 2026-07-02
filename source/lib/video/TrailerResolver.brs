' TrailerResolver.brs — browser-style trailer URL resolution for Roku Video.
' Extension-less private keys may be raw MP4 bytes, an HLS manifest, or 403; this
' module probes/sniffs/HEAD-checks candidates before handing a playable URL to Video.

function TrailerPathExtension(bare as string) as string
    if bare = "" then return ""
    slash = 0
    for c = 1 to Len(bare)
        if Mid(bare, c, 1) = "/" then slash = c
    end for
    filename = bare
    if slash > 0 then filename = Mid(bare, slash + 1)
    dot = Instr(1, filename, ".")
    if dot = 0 then return ""
    return LCase(Mid(filename, dot + 1))
end function

function TrailerNeedsResolve(url as string) as boolean
    if url = "" then return false
    bare = TrailerUrlWithoutQuery(url)
    ext = TrailerPathExtension(bare)
    if ext = "mp4" or ext = "m3u8" or ext = "mpd" or ext = "ts" or ext = "fmp4" then return false
    return true
end function

function TrailerUrlWithoutQuery(url as string) as string
    if url = "" then return ""
    q = Instr(1, url, "?")
    if q > 0 then return Left(url, q - 1)
    return url
end function

function IsRawMp4Sample(sample as string) as boolean
    if sample = "" then return false
    return Instr(1, sample, "ftyp") > 0
end function

function TrailerUrlIsPresigned(url as string) as boolean
    if url = "" then return false
    q = Instr(1, LCase(url), "?")
    if q = 0 then return false
    query = LCase(Mid(url, q))
    return Instr(1, query, "x-amz-algorithm=") > 0 or Instr(1, query, "x-amz-signature=") > 0
end function

function TrailerPushUniqueCandidate(out as object, seen as object, cand as string) as void
    if cand = "" then return
    if seen[cand] <> invalid then return
    seen[cand] = true
    out.Push(cand)
end function

' Ordered fallbacks when the manifest key is private (403) but a segment may be public.
function BuildMp4CandidateUrls(sourceUrl as string) as object
    out = []
    bare = TrailerUrlWithoutQuery(sourceUrl)
    if bare = "" then return out
    if not TrailerNeedsResolve(bare) then return out
    seen = {}
    TrailerPushUniqueCandidate(out, seen, bare + "31.mp4")
    TrailerPushUniqueCandidate(out, seen, bare + "1.mp4")
    TrailerPushUniqueCandidate(out, seen, bare + "01.mp4")
    TrailerPushUniqueCandidate(out, seen, bare + ".mp4")
    for i = 2 to 9
        TrailerPushUniqueCandidate(out, seen, bare + i.ToStr() + ".mp4")
        TrailerPushUniqueCandidate(out, seen, bare + "0" + i.ToStr() + ".mp4")
    end for
    return out
end function

function TrailerStreamFormat(url as string) as string
    if url = "" then return "mp4"
    bare = url
    q = Instr(1, bare, "?")
    if q > 0 then bare = Left(bare, q - 1)
    lc = LCase(bare)
    if Instr(1, lc, ".m3u8") > 0 then return "hls"
    if Instr(1, lc, ".mpd") > 0 then return "dash"
    if Instr(1, lc, ".ts") > 0 then return "hls"
    if Instr(1, lc, ".fmp4") > 0 then return "hls"
    return "mp4"
end function

function HeadStatus(url as string, cookies as string) as integer
    if url = "" then return 0
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if cookies <> invalid and cookies <> "" then xfer.AddHeader("Cookie", cookies)
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    if not xfer.AsyncHead() then return 0
    msg = wait(12000, port)
    if msg = invalid then
        xfer.AsyncCancel()
        return 0
    end if
    if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then return msg.GetResponseCode()
    return 0
end function

function FetchUrlText(url as string, cookies as string) as object
    if url = "" then return { text: "", status: 0 }
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if cookies <> invalid and cookies <> "" then xfer.AddHeader("Cookie", cookies)
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    if not xfer.AsyncGetToString() then return { text: "", status: 0 }
    msg = wait(15000, port)
    if msg = invalid then
        xfer.AsyncCancel()
        return { text: "", status: 0 }
    end if
    if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
        code = msg.GetResponseCode()
        if code = 200 then return { text: msg.GetString(), status: code }
        return { text: "", status: code }
    end if
    return { text: "", status: 0 }
end function

' Presigned S3 URLs often 403 on Range requests; fall back to a full GET for sniffing.
function FetchProbeSample(url as string, cookies as string) as object
    if url = "" then return { text: "", status: 0, fullText: "" }
    ranged = FetchRange(url, cookies, 0, 2047)
    status = 0
    if ranged <> invalid and ranged.status <> invalid then status = CInt(ranged.status)
    if status = 200 or status = 206 then
        text = ""
        if ranged.text <> invalid then text = ranged.text
        return { text: text, status: status, fullText: "" }
    end if
    if not TrailerUrlIsPresigned(url) then return { text: "", status: status, fullText: "" }

    full = FetchUrlText(url, cookies)
    fullStatus = 0
    if full.status <> invalid then fullStatus = CInt(full.status)
    if fullStatus <> 200 or full.text = "" then
        return { text: "", status: fullStatus, fullText: "" }
    end if
    head = Left(full.text, 2048)
    return { text: head, status: fullStatus, fullText: full.text }
end function

function FetchRange(url as string, cookies as string, startByte as integer, endByte as integer) as object
    if url = "" then return { text: "", status: 0 }
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if cookies <> invalid and cookies <> "" then xfer.AddHeader("Cookie", cookies)
    rangeHdr = "bytes=" + startByte.ToStr() + "-" + endByte.ToStr()
    xfer.AddHeader("Range", rangeHdr)
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    if not xfer.AsyncGetToString() then return { text: "", status: 0 }
    msg = wait(15000, port)
    if msg = invalid then
        xfer.AsyncCancel()
        return { text: "", status: 0 }
    end if
    if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
        code = msg.GetResponseCode()
        if code = 200 or code = 206 then return { text: msg.GetString(), status: code }
        return { text: "", status: code }
    end if
    return { text: "", status: 0 }
end function
