sub init()
    m.top.functionName = "runFetch"
end sub

sub runFetch()
    url = m.top.manifestUrl
    levels = []
    if url <> invalid and url <> "" then
        text = FetchText(url)
        if text <> "" then levels = ParseMasterPlaylist(text, url)
    end if
    m.top.levels = levels
    m.top.done = true
end sub

function FetchText(url as string) as string
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    if not xfer.AsyncGetToString() then return ""
    msg = wait(15000, port)
    if msg = invalid then
        xfer.AsyncCancel()
        return ""
    end if
    if type(msg) = "roUrlEvent" and msg.GetInt() = 1 and msg.GetResponseCode() = 200 then
        return msg.GetString()
    end if
    return ""
end function

' Parse #EXT-X-STREAM-INF RESOLUTION/BANDWIDTH + the following variant URL line.
' Returns [{ label, url, height, bandwidth }] deduped by height, highest first.
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
            ' Next non-empty, non-comment line is the variant URI.
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

    ' Sort highest resolution first (simple insertion sort; lists are tiny).
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

' Resolve a variant URI against the master URL (absolute / host-relative / path-relative).
' For path-relative URIs with no query of their own we carry over the master's query
' string, since token-in-query CDNs sign relative children with the same token.
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
