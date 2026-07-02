sub init()
    m.top.functionName = "runFetch"
end sub

sub runFetch()
    m.top.done = false
    url = m.top.manifestUrl
    levels = []
    firstMedia = ""
    isHls = false
    status = 0
    resolvedUrl = ""
    streamFormat = ""
    resolvePath = ""

    if url <> invalid and url <> "" then
        if not m.top.forceProbe and not TrailerNeedsResolve(url) then
            resolvedUrl = url
            streamFormat = TrailerStreamFormat(url)
            resolvePath = "direct_ext"
        else
        cookies = m.top.httpCookies
        if cookies = invalid then cookies = ""

        probe = FetchProbeSample(url, cookies)
        status = 0
        sample = ""
        probeFullText = ""
        if probe <> invalid then
            status = probe.status
            sample = probe.text
            if probe.fullText <> invalid then probeFullText = probe.fullText
        end if
        statusCode = 0
        if status <> invalid then statusCode = CInt(status)

        if statusCode = 200 or statusCode = 206 then
            if sample <> "" and IsHlsPlaylistText(sample) then
                text = probeFullText
                if text = "" then
                    fetched = FetchUrlText(url, cookies)
                    if fetched <> invalid then
                        text = fetched.text
                        status = fetched.status
                        if status <> invalid then statusCode = CInt(status)
                    end if
                end if
                if text <> "" then
                    isHls = true
                    levels = ParseMasterPlaylist(text, url)
                    firstMedia = ParseFirstMediaUri(text, url)
                    if firstMedia <> "" then
                        resolvedUrl = firstMedia
                        streamFormat = TrailerStreamFormat(firstMedia)
                        resolvePath = "manifest_segment"
                    else
                        resolvedUrl = url
                        streamFormat = "hls"
                        resolvePath = "manifest_hls"
                    end if
                end if
            else if sample <> "" and IsRawMp4Sample(sample) then
                resolvedUrl = url
                streamFormat = "mp4"
                resolvePath = "raw_mp4"
            else if sample <> "" then
                probeText = probeFullText
                if probeText = "" then probeText = sample
                lineMedia = ParseFirstMediaUri(probeText, url)
                if lineMedia <> "" then
                    resolvedUrl = lineMedia
                    streamFormat = TrailerStreamFormat(lineMedia)
                    resolvePath = "manifest_line"
                end if
            end if
        end if

        if resolvedUrl = "" then
            cands = BuildMp4CandidateUrls(url)
            for each cand in cands
                hs = HeadStatus(cand, cookies)
                if hs = 200 or hs = 206 then
                    resolvedUrl = cand
                    streamFormat = "mp4"
                    resolvePath = "head_mp4"
                    exit for
                end if
            end for
        end if

        if resolvedUrl = "" then
            resolvedUrl = url
            streamFormat = "hls"
            resolvePath = "hls_direct"
        end if

        if firstMedia = "" and resolvedUrl <> "" and resolvePath = "head_mp4" then
            firstMedia = resolvedUrl
        end if
        end if
    end if

    m.top.fetchStatus = status
    m.top.isHlsManifest = isHls
    m.top.firstMediaUrl = firstMedia
    m.top.levels = levels
    m.top.resolvedUrl = resolvedUrl
    m.top.streamFormat = streamFormat
    m.top.resolvePath = resolvePath
    m.top.done = true
end sub

function IsHlsPlaylistText(text as string) as boolean
    if text = "" then return false
    return Instr(1, text, "#EXTM3U") > 0 or Instr(1, text, "#EXTINF") > 0 or Instr(1, text, "#EXT-X-STREAM-INF") > 0
end function

function ParseFirstMediaUri(text as string, baseUrl as string) as string
    lines = text.Split(Chr(10))
    for each raw in lines
        line = StripCR(raw)
        if line <> "" and Left(line, 1) <> "#" then
            lc = LCase(line)
            if Left(lc, 4) = "http" or Instr(1, lc, ".mp4") > 0 or Instr(1, lc, ".m3u8") > 0 or Instr(1, lc, ".ts") > 0 then
                return ResolveUrl(baseUrl, line)
            end if
        end if
    end for
    return ""
end function

function ParseMasterPlaylist(text as string, masterUrl as string) as object
    out = []
    seenHeights = {}
    lines = text.Split(Chr(10))
    i = 0
    count = lines.Count()
    while i < count
        line = StripCR(lines[i])
        if Left(line, 18) = "#EXT-X-STREAM-INF:" then
            attrs = Mid(line, 19)
            height = ParseResolutionHeight(attrs)
            bandwidth = ParseAttrInt(attrs, "BANDWIDTH")
            j = i + 1
            uri = ""
            while j < count
                cand = StripCR(lines[j])
                if cand <> "" and Left(cand, 1) <> "#" then
                    uri = cand
                    exit while
                end if
                j = j + 1
            end while
            if uri <> "" and height > 0 then
                hk = height.ToStr()
                if seenHeights[hk] = invalid then
                    seenHeights[hk] = true
                    out.Push({
                        label: height.ToStr() + "p"
                        url: ResolveUrl(masterUrl, uri)
                        height: height
                        bandwidth: bandwidth
                    })
                end if
            end if
            i = j
        else
            i = i + 1
        end if
    end while

    for a = 1 to out.Count() - 1
        cur = out[a]
        b = a - 1
        while b >= 0 and out[b].height < cur.height
            out[b + 1] = out[b]
            b = b - 1
        end while
        out[b + 1] = cur
    end for
    return out
end function

function ParseResolutionHeight(attrs as string) as integer
    idx = Instr(1, UCase(attrs), "RESOLUTION=")
    if idx = 0 then return 0
    rest = Mid(attrs, idx + 11)
    xpos = Instr(1, LCase(rest), "x")
    if xpos = 0 then return 0
    afterX = Mid(rest, xpos + 1)
    num = ""
    for c = 1 to Len(afterX)
        ch = Mid(afterX, c, 1)
        if ch >= "0" and ch <= "9" then
            num = num + ch
        else
            exit for
        end if
    end for
    if num = "" then return 0
    return Int(Val(num))
end function

function ParseAttrInt(attrs as string, key as string) as integer
    idx = Instr(1, UCase(attrs), UCase(key) + "=")
    if idx = 0 then return 0
    rest = Mid(attrs, idx + Len(key) + 1)
    num = ""
    for c = 1 to Len(rest)
        ch = Mid(rest, c, 1)
        if ch >= "0" and ch <= "9" then
            num = num + ch
        else
            exit for
        end if
    end for
    if num = "" then return 0
    return Int(Val(num))
end function

function ResolveUrl(masterUrl as string, uri as string) as string
    if Left(LCase(uri), 4) = "http" then return uri

    scheme = ""
    host = ""
    pathPart = masterUrl
    q = Instr(1, masterUrl, "://")
    if q > 0 then
        scheme = Left(masterUrl, q + 2)
        afterScheme = Mid(masterUrl, q + 3)
        slash = Instr(1, afterScheme, "/")
        if slash > 0 then
            host = Left(afterScheme, slash - 1)
            pathPart = Mid(afterScheme, slash)
        else
            host = afterScheme
            pathPart = "/"
        end if
    end if

    masterQuery = ""
    qpos = Instr(1, pathPart, "?")
    if qpos > 0 then
        masterQuery = Mid(pathPart, qpos)
        pathPart = Left(pathPart, qpos - 1)
    end if

    if Left(uri, 1) = "/" then
        resolved = scheme + host + uri
    else
        lastSlash = 0
        for c = 1 to Len(pathPart)
            if Mid(pathPart, c, 1) = "/" then lastSlash = c
        end for
        baseDir = Left(pathPart, lastSlash)
        resolved = scheme + host + baseDir + uri
    end if

    if Instr(1, uri, "?") = 0 and masterQuery <> "" then
        resolved = resolved + masterQuery
    end if
    return resolved
end function

function StripCR(s as string) as string
    if s = invalid then return ""
    if Len(s) > 0 and Right(s, 1) = Chr(13) then return Left(s, Len(s) - 1)
    return s
end function
