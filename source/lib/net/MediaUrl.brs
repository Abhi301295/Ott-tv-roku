' MediaUrl.brs — map private stream paths to the output CDN (S3).
' Detail playback uses full playList.hls.url on S3; reels often ship reel.path as
' /private/videos/... which must play on the same CDN host, not apiBaseUrl.

function MediaCdnBaseUrl() as string
    cfg = AppConfig()
    if cfg.cdnBaseUrl <> invalid and cfg.cdnBaseUrl <> "" then
        base = cfg.cdnBaseUrl.ToStr()
        if Right(base, 1) = "/" then base = Left(base, Len(base) - 1)
        return base
    end if
    return "https://ott-accelerator-bucket-output.s3.us-east-1.amazonaws.com"
end function

' Playable stream URL — parity with detail.playList.hls.url on the output bucket.
function MediaStreamUrl(path as dynamic) as string
    if path = invalid or path = "" then return ""
    s = path.ToStr()
    lc = LCase(s)
    if Left(lc, 7) = "http://" or Left(lc, 8) = "https://" then
        return MediaRewritePrivateStreamOrigin(s)
    end if
    if Left(lc, 9) = "/private/" then
        return MediaCdnBaseUrl() + s
    end if
    if Left(lc, 8) = "private/" then
        return MediaCdnBaseUrl() + "/" + s
    end if
    return s
end function

function MediaPlayUrlHost(url as string) as string
    if url = "" then return "empty"
    lc = LCase(url)
    if Instr(1, lc, "amazonaws.com") > 0 then return "s3"
    cfg = AppConfig()
    apiBase = cfg.apiBaseUrl
    if apiBase <> invalid and apiBase <> "" then
        apiLc = LCase(apiBase)
        while Len(apiLc) > 0 and Right(apiLc, 1) = "/"
            apiLc = Left(apiLc, Len(apiLc) - 1)
        end while
        if apiLc <> "" and Instr(1, lc, apiLc) = 1 then return "api"
    end if
    return "other"
end function

' Telnet: grep [PLAY_URL_DBG] — resolved URL handed to the Video node.
sub MediaLogPlayUrl(source as string, url as string)
    if url = invalid or url = "" then
        print "[PLAY_URL_DBG] src=" + source + " host=empty url="
        return
    end if
    print "[PLAY_URL_DBG] src=" + source + " host=" + MediaPlayUrlHost(url) + " url=" + Left(url, 128)
end sub

function MediaRewritePrivateStreamOrigin(url as string) as string
    lc = LCase(url)
    priv = Instr(1, lc, "/private/")
    if priv = 0 then return url

    cfg = AppConfig()
    apiBase = cfg.apiBaseUrl
    if apiBase = invalid then apiBase = ""
    apiLc = LCase(apiBase)
    while Len(apiLc) > 0 and Right(apiLc, 1) = "/"
        apiLc = Left(apiLc, Len(apiLc) - 1)
    end while

    if apiLc <> "" and Left(lc, Len(apiLc)) = apiLc then
        return MediaCdnBaseUrl() + Mid(url, priv)
    end if

    return url
end function
