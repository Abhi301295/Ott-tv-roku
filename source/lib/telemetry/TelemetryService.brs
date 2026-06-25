' TelemetryService.brs
' Fire-and-forget TV telemetry → Dynatrace POC bridge (POST /telemetry/events).
' Gated by config.telemetryEnabled + business enableAnalytics (when resolved).

function TE_EventAppStart() as string: return "app_start": end function
function TE_EventPlaybackStart() as string: return "playback_start": end function
function TE_EventBuffering() as string: return "buffering": end function
function TE_EventPlaybackError() as string: return "playback_error": end function

function TE_MinBufferMs() as integer: return 500: end function

function TelemetryEndpointUrl() as string
    cfg = AppConfig()
    base = cfg.telemetryBaseUrl
    if base = invalid or base = "" then return ""
    if Right(base, 1) = "/" then base = Left(base, Len(base) - 1)
    return base + "/telemetry/events"
end function

function TelemetryEnabled() as boolean
    cfg = AppConfig()
    if cfg.telemetryEnabled <> invalid and cfg.telemetryEnabled = false then return false
    if m.global <> invalid and m.global.businessResolved <> invalid then
        if not IsFeatureEnabled(m.global.businessResolved, "enableAnalytics") then return false
    end if
    return true
end function

function TelemetrySessionId() as string
    if m.global = invalid then return GenerateUUID()
    if not m.global.hasField("telemetrySessionId") or m.global.telemetrySessionId = invalid or m.global.telemetrySessionId = "" then
        m.global.addFields({ telemetrySessionId: GenerateUUID() })
    end if
    return m.global.telemetrySessionId
end function

function TelemetryIsoNow() as string
    dt = CreateObject("roDateTime")
    dt.Mark()
    return dt.ToISOString()
end function

function TelemetryAppVersion() as string
    cfg = AppConfig()
    ver = cfg.appVersion
    if ver <> invalid and ver <> "" then return ver
    info = CreateObject("roAppInfo")
    return info.GetVersion()
end function

function TelemetryBasePayload() as object
    return {
        device_type: "roku"
        session_id: TelemetrySessionId()
        device_id: GetDeviceId()
        app_version: TelemetryAppVersion()
        client_timestamp: TelemetryIsoNow()
    }
end function

' Single-quote wrap for curl -d '{...}' — escape any apostrophes in the JSON body.
function TelemetryEscapeForCurl(text as string) as string
    if text = invalid then return ""
    return text.Replace("'", "'\''")
end function

function TelemetryCurlCommand(url as string, jsonBody as string) as string
    safe = TelemetryEscapeForCurl(jsonBody)
    return "curl -s -w ""\nHTTP %{http_code}\n"" -X POST """ + url + """ -H ""Content-Type: application/json"" -d '" + safe + "'"
end function

sub TelemetryLogRequest(url as string, payload as object)
    jsonBody = FormatJson(payload)
    eventName = ""
    if payload <> invalid and payload.event_name <> invalid then eventName = payload.event_name
    session = ""
    if payload <> invalid and payload.session_id <> invalid then session = Left(payload.session_id, 8)

    print "[TELEMETRY_DBG] send event="; eventName; " session="; session
    print "[TELEMETRY_DBG] url="; url
    print "[TELEMETRY_DBG] payload="; jsonBody
    print "[TELEMETRY_DBG] curl="; TelemetryCurlCommand(url, jsonBody)
end sub

' Spawn a background Task — never blocks the render thread.
sub TelemetryIngest(fromNode as object, eventName as string, extra as object)
    if not TelemetryEnabled() then
        print "[TELEMETRY_DBG] skip disabled event="; eventName
        return
    end if
    url = TelemetryEndpointUrl()
    if url = "" then
        print "[TELEMETRY_DBG] skip no endpoint event="; eventName
        return
    end if

    payload = TelemetryBasePayload()
    payload.event_name = eventName
    if extra <> invalid then
        for each key in extra
            payload[key] = extra[key]
        end for
    end if

    scene = invalid
    if fromNode <> invalid then scene = fromNode.getScene()

    host = invalid
    if m.global <> invalid and m.global.hasField("telemetryClient") and m.global.telemetryClient <> invalid then
        host = m.global.telemetryClient
    end if
    if host = invalid and scene <> invalid then host = scene.findNode("telemetryClient")
    if host = invalid then
        print "[TELEMETRY_DBG] skip no telemetryClient event="; eventName
        return
    end if

    TelemetryLogRequest(url, payload)
    host.callFunc("Submit", { url: url, payload: payload })
end sub

' ── Event helpers (one per API event we support on OTT VOD) ─────────────────

sub TelemetryTrackAppStart(fromNode as object)
    if m.global <> invalid and m.global.hasField("telemetryAppStartSent") and m.global.telemetryAppStartSent = true then return
    if m.global <> invalid then
        if not m.global.hasField("telemetryAppStartSent") then m.global.addFields({ telemetryAppStartSent: false })
        m.global.telemetryAppStartSent = true
    end if
    TelemetryIngest(fromNode, TE_EventAppStart(), {})
end sub

sub TelemetryTrackPlaybackStart(fromNode as object, contentId as string, playbackPosMs as integer)
    extra = { playback_pos_ms: playbackPosMs }
    if contentId <> "" then extra.content_id = contentId
    TelemetryIngest(fromNode, TE_EventPlaybackStart(), extra)
end sub

sub TelemetryTrackBuffering(fromNode as object, contentId as string, playbackPosMs as integer, bufferDurationMs as integer)
    extra = {
        playback_pos_ms: playbackPosMs
        buffer_duration_ms: bufferDurationMs
    }
    if contentId <> "" then extra.content_id = contentId
    TelemetryIngest(fromNode, TE_EventBuffering(), extra)
end sub

sub TelemetryTrackPlaybackError(fromNode as object, contentId as string, playbackPosMs as integer, errorCode as string, errorMessage as string)
    extra = {
        playback_pos_ms: playbackPosMs
        error_code: errorCode
        error_message: Left(errorMessage, 512)
    }
    if contentId <> "" then extra.content_id = contentId
    TelemetryIngest(fromNode, TE_EventPlaybackError(), extra)
end sub

function TelemetryContentId(contentId as string, detail as object) as string
    if contentId <> "" then return contentId
    if detail <> invalid and detail._id <> invalid and detail._id <> "" then return detail._id
    if detail <> invalid and detail.id <> invalid and detail.id <> "" then return detail.id
    return ""
end function
