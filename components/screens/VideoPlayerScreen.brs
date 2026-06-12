' VideoPlayerScreen.brs — parity with src/features/contentdetail/video/index.tsx.
'
' Leak policy (hard requirement): every Timer is a child node we explicitly stop in
' OnDispose; the Video is stopped and its content cleared; all observeField hooks are
' removed; a final progress beacon is flushed. ViewManager sets dispose=true before the
' node leaves the tree, so nothing keeps ticking in the background.

sub init()
    m.videoNode = m.top.findNode("videoNode")
    m.loaderGroup = m.top.findNode("loaderGroup")
    m.loaderArc = m.top.findNode("loaderArc")
    m.loaderAnim = m.top.findNode("loaderAnim")
    m.controlsGroup = m.top.findNode("controlsGroup")
    m.btnBack = m.top.findNode("btnBack")
    m.btnPlay = m.top.findNode("btnPlay")
    m.btnFwd = m.top.findNode("btnFwd")
    m.btnSettings = m.top.findNode("btnSettings")
    m.timeLabel = m.top.findNode("timeLabel")
    m.scrubFill = m.top.findNode("scrubFill")
    m.scrubKnob = m.top.findNode("scrubKnob")
    m.skipIntroBtn = m.top.findNode("skipIntroBtn")
    m.skipIntroBg = m.top.findNode("skipIntroBg")
    m.skipIntroLabel = m.top.findNode("skipIntroLabel")
    m.bingeCard = m.top.findNode("bingeCard")
    m.bingeThumb = m.top.findNode("bingeThumb")
    m.bingeTitle = m.top.findNode("bingeTitle")
    m.bingeCountdownLabel = m.top.findNode("bingeCountdownLabel")
    m.bingeGlow = m.top.findNode("bingeGlow")
    m.settingsOverlay = m.top.findNode("settingsOverlay")
    m.settingsPanel = m.top.findNode("settingsPanel")
    m.settingsTitle = m.top.findNode("settingsTitle")
    m.settingsClose = m.top.findNode("settingsClose")
    m.settingsRows = m.top.findNode("settingsRows")

    m.SCRUB_W = 1280

    ' State.
    m.detail = invalid
    m.contentId = ""
    m.nextList = []
    m.currentIndex = 0
    m.startOver = false
    m.isTrailer = false
    m.resumeSecs = 0
    ' Resume position to apply once playback is seekable. content.playStart resumes
    ' instantly on devices, but the brs-desktop simulator ignores playStart for HLS,
    ' so we also fire an explicit .seek on the first "playing" transition (the same
    ' mechanism skip-intro / +10 use, which the sim honors). -1 = nothing pending.
    m.pendingSeek = -1
    m.introStart = 0
    m.introEnd = 0
    m.bingeTrigger = 10
    m.nextItem = invalid
    m.duration = 0.0
    m.position = 0.0
    m.playing = false
    m.ended = false               ' true once the stream finishes (replay-on-play, fwd disabled)
    m.reloading = false           ' true during a stop→content→play swap (ignore the stop's spinner-off)
    m.spinnerOn = false
    m.disposed = false

    m.controlIds = ["back", "play", "fwd", "settings"]
    m.controlIndex = 1            ' default focus = play (parity playFocusSelf)
    m.controlsVisible = false
    m.focusMode = "controls"      ' controls | skip | binge | settings

    m.skipVisible = false
    m.bingeVisible = false
    m.settingsOpen = false

    m.capOptions = []             ' [{ label, lang }] — off + each subtitle lang
    m.selectedSubtitle = "off"

    m.masterUrl = ""
    m.qualityOptions = []         ' [{ label, url, height }] — Auto + parsed variant ladder
    m.selectedQualityHeight = -1  ' -1 = Auto (ABR)

    ' Playback speed (parity with settingPopUp.tsx speedItems). Roku's Video node has no
    ' public variable-rate playback API, so the selection is tracked/highlighted and
    ' applied best-effort; it does not re-rate HLS the way the web <video> playbackRate does.
    m.speedOptions = [{ label: "0.5x", rate: 0.5 }, { label: "1x", rate: 1.0 }, { label: "2x", rate: 2.0 }]
    m.selectedSpeed = 1.0

    ' Collapsible settings model (parity with settingPopUp.tsx accordion).
    m.sections = []               ' [{ kind:"quality"|"caption", title, expanded }]
    m.settingsFlat = []           ' flattened focusable rows (close + headers + options)
    m.settingsFocus = 0
    m.rowRefs = []                ' parallel render nodes for focus highlighting
    m.manifestTask = invalid

    m.advancing = false           ' guards against double auto-advance (finished + countdown)
    m.progressInFlight = false
    m.progressTask = invalid

    m.vm = FindViewManager(m.top)
    LoadVideoTokens()
    ApplyControlColors()

    ' Timers (children so the SG owns their lifecycle; we stop them in OnDispose).
    m.hideTimer = CreateObject("roSGNode", "Timer")
    m.hideTimer.duration = 5
    m.hideTimer.repeat = false
    m.top.appendChild(m.hideTimer)
    m.hideTimer.observeField("fire", "OnHideTimer")

    m.progressTimer = CreateObject("roSGNode", "Timer")
    m.progressTimer.duration = 5
    m.progressTimer.repeat = true
    m.top.appendChild(m.progressTimer)
    m.progressTimer.observeField("fire", "OnProgressTimer")

    if m.videoNode <> invalid then
        m.videoNode.notificationInterval = 0.5
        m.videoNode.observeField("state", "OnVideoState")
        m.videoNode.observeField("position", "OnVideoPosition")
        m.videoNode.observeField("duration", "OnVideoDuration")
    end if

    m.top.observeField("keyEvent", "OnKey")
    if m.vm <> invalid then m.vm.observeField("overlayDismiss", "OnOverlayDismiss")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if
end sub

sub OnNavStateReady()
    state = m.top.navState
    if state = invalid then return
    if state.detail <> invalid then m.detail = state.detail
    if state.contentId <> invalid then m.contentId = state.contentId
    if state.nextVideoList <> invalid then m.nextList = state.nextVideoList
    if state.currentIndex <> invalid then m.currentIndex = state.currentIndex
    if state.startOver <> invalid then m.startOver = (state.startOver = true)
    if m.detail = invalid then return
    LoadAndPlay()
end sub

sub LoadVideoTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens
    m.cPrimary500 = ThemeTokenColor(m.tokens, "primary-500", "#0b75e0")
    m.cPrimary700 = ThemeTokenColor(m.tokens, "primary-700", "#04478b")
    m.cNeutral50 = ThemeTokenColor(m.tokens, "neutral-50", "#f5f5f5")
    m.cNeutral300 = ThemeTokenColor(m.tokens, "neutral-300", "#adadad")
    ' Settings option fill (parity with SettingOption bg-neutral-400): API secondary shade.
    m.cNeutral400 = ThemeTokenColor(m.tokens, "neutral-400", "#9ea4b0")
    ' Settings panel (parity with settingPopUp bg-neutral-950 — see SettingsPanelBgColor).
    m.cSettingsPanel = SettingsPanelBgColor()
end sub

' React settingPopUp uses bg-neutral-950, but tailwind.config.js maps neutral-50..900 and
' 1000 to CSS vars — NOT 950. The class therefore resolves to Tailwind's built-in
' neutral-950 (#0a0a0a), not the API --neutral-950 from generateBgTokens. Using the API
' neutral-950 token on Roku produced a light pink panel when tertiary is a light brand color.
function SettingsPanelBgColor() as string
    return HexToRokuColor("#0a0a0a", "ff")
end function

sub OnBusinessResolved()
    LoadVideoTokens()
    ApplyControlColors()
    if m.settingsOpen then RenderSettings()
end sub

' Scrubber + binge glow track primary-500; text tracks neutral tokens.
sub ApplyControlColors()
    if m.scrubFill <> invalid then m.scrubFill.color = m.cPrimary500
    if m.scrubKnob <> invalid then m.scrubKnob.blendColor = m.cPrimary500
    if m.bingeGlow <> invalid then m.bingeGlow.blendColor = m.cPrimary500
    if m.loaderArc <> invalid then m.loaderArc.blendColor = m.cPrimary500
    if m.timeLabel <> invalid then m.timeLabel.color = m.cNeutral50
    ' Settings surface matches React's rendered bg-neutral-950; title uses API neutral-50.
    if m.settingsPanel <> invalid then m.settingsPanel.color = m.cSettingsPanel
    if m.settingsTitle <> invalid then m.settingsTitle.color = m.cNeutral50
    if m.settingsClose <> invalid then m.settingsClose.blendColor = m.cNeutral50
    ' Control icons are white (neutral-50) glyphs; React dims them with opacity (op-30)
    ' and brightens to op-100 on focus — so the tint is the API token, not a baked grey.
    for each b in [m.btnBack, m.btnPlay, m.btnFwd, m.btnSettings]
        if b <> invalid then b.blendColor = m.cNeutral50
    end for
    ApplyControlFocus()
end sub

' ── Load / play ──────────────────────────────────────────────────────────────

sub LoadAndPlay()
    if m.videoNode = invalid or m.detail = invalid then return

    url = VideoStreamUrl(m.detail)
    if url = "" then
        ShowAlert(m.top, 2, CopyVideoLoadFailed())
        return
    end if

    m.isTrailer = VideoIsTrailer(m.detail)
    m.resumeSecs = VideoResumeSeconds(m.detail, m.startOver)
    m.introStart = VideoIntroStart(m.detail)
    m.introEnd = VideoIntroEnd(m.detail)
    m.bingeTrigger = VideoBingeTrigger(m.detail)
    m.nextItem = VideoNextItem(m.nextList, m.currentIndex, m.isTrailer)
    m.duration = 0.0
    m.position = 0.0

    fmt = VideoStreamFormat(url)
    m.masterUrl = url
    m.selectedQualityHeight = -1
    m.qualityOptions = [{ label: CopyVideoQualityAuto(), url: url, height: -1 }]

    ' Captions list for the dropdown (off + each subtitle lang).
    m.capOptions = [{ label: CopyVideoCaptionsOff(), lang: "off" }]
    for each tk in VideoSubtitleTracks(m.detail)
        m.capOptions.Push({ label: tk.lang, lang: tk.lang })
    end for
    m.selectedSubtitle = "off"

    ShowSpinner(true)
    m.videoNode.content = BuildContent(url, m.resumeSecs)
    m.videoNode.control = "play"

    if fmt = "hls" then FetchQualityLadder(url)
end sub

' Build the playback ContentNode (url + resume + subtitle tracks). Shared by initial
' load, episode auto-advance, and quality-variant reload.
function BuildContent(url as string, startSecs as integer) as object
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = VideoStreamFormat(url)
    if m.detail <> invalid and m.detail.title <> invalid then content.title = m.detail.title
    if startSecs > 0 then
        content.playStart = startSecs       ' instant resume on real devices
        m.pendingSeek = startSecs           ' fallback .seek for sim / firmwares that ignore playStart
    else
        m.pendingSeek = -1
    end if
    tracks = VideoSubtitleTracks(m.detail)
    if tracks.Count() > 0 then
        subs = []
        for each tk in tracks
            subs.Push({ Url: tk.url, Language: tk.lang, Description: tk.lang, TrackName: tk.lang })
        end for
        content.subtitleTracks = subs
    end if
    return content
end function

' Apply a pending resume offset once the stream is actually playing. Devices honor
' content.playStart (so position is already at the offset and we no-op); when playStart
' is ignored (sim / some firmwares) the stream starts at 0 and we seek explicitly. This
' is the same .seek path skip-intro / +10 use, so it works everywhere.
sub ApplyPendingSeek()
    if m.pendingSeek < 0 then return
    target = m.pendingSeek
    m.pendingSeek = -1
    if m.videoNode = invalid then return
    curPos = m.videoNode.position
    if curPos = invalid then curPos = 0
    ' Only seek when playStart clearly didn't take (still near the start).
    if target > 2 and curPos < target - 3 then
        m.videoNode.seek = target
        m.position = target
        UpdateScrubber()
    end if
end sub

' Fetch + parse the HLS master so the Quality dropdown shows real resolutions.
sub FetchQualityLadder(url as string)
    if m.manifestTask <> invalid then
        m.manifestTask.unobserveField("done")
        m.manifestTask.control = "stop"
    end if
    m.manifestTask = CreateObject("roSGNode", "ManifestTask")
    m.manifestTask.manifestUrl = url
    m.manifestTask.observeField("done", "OnManifestDone")
    m.manifestTask.control = "RUN"
end sub

sub OnManifestDone()
    if m.disposed or m.manifestTask = invalid then return
    levels = m.manifestTask.levels
    opts = [{ label: CopyVideoQualityAuto(), url: m.masterUrl, height: -1 }]
    if levels <> invalid then
        for each lv in levels
            opts.Push({ label: lv.label, url: lv.url, height: lv.height })
        end for
    end if
    m.qualityOptions = opts
    ' If the settings panel is open on Quality, refresh it live.
    if m.settingsOpen then
        BuildSettingsFlat()
        RenderSettings()
    end if
end sub

sub OnVideoState()
    if m.videoNode = invalid or m.disposed then return
    state = m.videoNode.state

    if state = "buffering" then
        ' Genuine buffering only — never while we're sitting at the finished end.
        if not m.ended then ShowSpinner(true)
    else if state = "playing" then
        ShowSpinner(false)
        m.reloading = false
        m.advancing = false
        m.ended = false
        if not m.playing then
            m.playing = true
            m.progressTimer.control = "start"
        end if
        ApplyPendingSeek()
        UpdatePlayIcon()
        ApplyControlFocus()
        if not m.controlsVisible then ShowControls(true)
    else if state = "paused" then
        ShowSpinner(false)
        m.playing = false
        UpdatePlayIcon()
    else if state = "finished" then
        OnVideoFinished()
    else if state = "stopped" then
        ' A stop we triggered for a content swap keeps the spinner; an external stop clears it.
        if not m.reloading then ShowSpinner(false)
    else if state = "error" then
        ShowSpinner(false)
        m.reloading = false
        m.playing = false
        EnterEndedState()
        ShowAlert(m.top, 2, CopyVideoLoadFailed())
    end if
end sub

sub OnVideoDuration()
    if m.videoNode = invalid then return
    d = m.videoNode.duration
    if d <> invalid and d > 0 then
        m.duration = d
        UpdateScrubber()
    end if
end sub

sub OnVideoPosition()
    if m.videoNode = invalid or m.disposed then return
    if m.ended or m.reloading then return
    m.position = m.videoNode.position
    if m.duration <= 0 and m.videoNode.duration > 0 then m.duration = m.videoNode.duration
    UpdateScrubber()
    EvaluateSkipIntro()
    EvaluateBinge()
end sub

sub OnVideoFinished()
    ShowSpinner(false)
    m.playing = false
    m.progressTimer.control = "stop"

    ' Auto-advance to the next episode when there is one (binge).
    if m.nextItem <> invalid and not m.isTrailer then
        PlayNext()
        return
    end if

    ' No next item — flush a final progress beacon at full duration, then sit in the
    ' "ended" state so the user can replay (we do NOT auto-pop the screen).
    m.position = m.duration
    UpdateScrubber()
    FlushProgress()
    EnterEndedState()
end sub

' Park the player at the end: show controls, focus play (= replay), disable forward.
sub EnterEndedState()
    m.ended = true
    m.playing = false
    m.reloading = false
    m.advancing = false           ' clear so a later replay/advance isn't blocked
    m.controlIndex = 1            ' play/replay
    m.focusMode = "controls"
    UpdatePlayIcon()
    ShowControls(true)
    ApplyControlFocus()
end sub

' ── Controls ─────────────────────────────────────────────────────────────────

sub ShowSpinner(show as boolean)
    if m.spinnerOn = show then return
    m.spinnerOn = show
    if m.loaderGroup <> invalid then m.loaderGroup.visible = show
    if m.loaderAnim <> invalid then
        if show then
            m.loaderAnim.control = "start"
        else
            m.loaderAnim.control = "stop"
        end if
    end if
end sub

sub ShowControls(show as boolean)
    m.controlsVisible = show
    if m.controlsGroup <> invalid then m.controlsGroup.visible = show
    if show then
        ApplyControlFocus()
        RestartHideTimer()
    end if
end sub

sub RestartHideTimer()
    if m.hideTimer = invalid then return
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub OnHideTimer()
    if m.settingsOpen then return
    if m.ended then return            ' keep controls up at the end so replay stays visible
    ShowControls(false)
end sub

' Pause icon while playing; play icon when paused or ended (ended = replay).
sub UpdatePlayIcon()
    if m.btnPlay = invalid then return
    if m.playing and not m.ended then
        m.btnPlay.uri = "pkg:/images/ui/ic_v_pause.png"
    else
        m.btnPlay.uri = "pkg:/images/ui/ic_v_play.png"
    end if
end sub

sub UpdateScrubber()
    if m.duration <= 0 then return
    frac = m.position / m.duration
    if frac < 0 then frac = 0
    if frac > 1 then frac = 1
    w = Int(frac * m.SCRUB_W)
    if m.scrubFill <> invalid then m.scrubFill.width = w
    if m.scrubKnob <> invalid then m.scrubKnob.translation = [w - 10, -7]
    if m.timeLabel <> invalid then
        m.timeLabel.text = VideoFormatTime(m.position) + "  /  " + VideoFormatTime(m.duration)
    end if
end sub

' Focused control = full opacity, others dimmed (parity op-100 / op-30). Icons keep their
' neutral-50 tint (set in ApplyControlColors); only opacity changes, matching React.
sub ApplyControlFocus()
    dimOp = 0.3
    disabledOp = 0.12
    if m.btnBack <> invalid then m.btnBack.opacity = dimOp
    if m.btnPlay <> invalid then m.btnPlay.opacity = dimOp
    if m.btnFwd <> invalid then m.btnFwd.opacity = dimOp
    if m.btnSettings <> invalid then m.btnSettings.opacity = dimOp

    ' Forward (+10) is disabled once the stream has ended (nothing to skip to).
    if m.ended and m.btnFwd <> invalid then m.btnFwd.opacity = disabledOp

    if m.focusMode <> "controls" then return
    id = m.controlIds[m.controlIndex]
    if id = "back" and m.btnBack <> invalid then m.btnBack.opacity = 1.0
    if id = "play" and m.btnPlay <> invalid then m.btnPlay.opacity = 1.0
    if id = "fwd" and m.btnFwd <> invalid and not m.ended then m.btnFwd.opacity = 1.0
    if id = "settings" and m.btnSettings <> invalid then m.btnSettings.opacity = 1.0
end sub

sub TogglePlayPause()
    if m.videoNode = invalid then return
    ' At the end, play means replay from the start.
    if m.ended then
        ReplayFrom(0)
        return
    end if
    if m.playing then
        m.videoNode.control = "pause"
        m.playing = false
        FlushProgress()
    else
        m.videoNode.control = "resume"
        m.playing = true
    end if
    UpdatePlayIcon()
end sub

sub SeekBy(deltaSecs as integer)
    if m.videoNode = invalid then return

    ' Ended: forward is disabled; backward replays from near the end.
    if m.ended then
        if deltaSecs < 0 then
            target = m.duration + deltaSecs
            if target < 0 then target = 0
            ReplayFrom(target)
        end if
        return
    end if

    target = m.position + deltaSecs
    if target < 0 then target = 0
    ' Never seek to the exact end (that strands the player in a finished/buffering limbo).
    if m.duration > 0 and target > m.duration - 1 then target = m.duration - 1
    m.videoNode.seek = target
    m.position = target
    UpdateScrubber()
end sub

' Reload the current stream at a given offset and play (used for replay after end and
' for recovering from a finished/stopped state where control="resume" won't restart).
sub ReplayFrom(startSecs as integer)
    if m.videoNode = invalid or m.masterUrl = "" then return
    m.ended = false
    m.reloading = true
    m.advancing = false
    m.playing = false
    m.position = startSecs
    ShowSpinner(true)
    m.videoNode.control = "stop"
    m.videoNode.content = invalid
    m.videoNode.content = BuildContent(m.masterUrl, startSecs)
    m.videoNode.control = "play"
    UpdatePlayIcon()
    UpdateScrubber()
    ShowControls(true)
end sub

' ── Skip Intro / Binge ───────────────────────────────────────────────────────

sub EvaluateSkipIntro()
    inIntro = (m.introEnd > m.introStart) and (m.position >= m.introStart) and (m.position <= m.introEnd)
    if inIntro = m.skipVisible then return
    m.skipVisible = inIntro
    if m.skipIntroBtn <> invalid then m.skipIntroBtn.visible = inIntro
    if inIntro then
        m.focusMode = "skip"
        HighlightSkip(true)
    else
        HighlightSkip(false)
        if m.focusMode = "skip" then RestoreControlsFocus()
    end if
end sub

sub HighlightSkip(on as boolean)
    if m.skipIntroLabel = invalid then return
    if on then
        m.skipIntroLabel.color = m.cPrimary500
    else
        m.skipIntroLabel.color = m.cNeutral50
    end if
end sub

sub DoSkipIntro()
    if m.introEnd <= 0 then return
    m.videoNode.seek = m.introEnd + 1
    m.position = m.introEnd + 1
    m.skipVisible = false
    if m.skipIntroBtn <> invalid then m.skipIntroBtn.visible = false
    RestoreControlsFocus()
end sub

sub EvaluateBinge()
    show = false
    if m.nextItem <> invalid and not m.isTrailer and m.duration > 0 then
        remaining = m.duration - m.position
        if remaining <= m.bingeTrigger then show = true
    end if

    if show then
        remaining = m.duration - m.position
        cd = Int(remaining + 0.999)
        if cd < 0 then cd = 0
        if not m.bingeVisible then
            m.bingeVisible = true
            BuildBingeCard()
            if m.bingeCard <> invalid then m.bingeCard.visible = true
            m.focusMode = "binge"
            if m.bingeGlow <> invalid then
                m.bingeGlow.visible = true
                m.bingeGlow.opacity = 0.6
            end if
        end if
        if m.bingeCountdownLabel <> invalid then
            m.bingeCountdownLabel.text = "Starts in " + cd.ToStr() + "s"
        end if
        ' Auto-advance when the countdown elapses (parity with the countdown effect).
        if remaining <= 0 then PlayNext()
    else
        if m.bingeVisible then
            m.bingeVisible = false
            if m.bingeCard <> invalid then m.bingeCard.visible = false
            if m.bingeGlow <> invalid then m.bingeGlow.visible = false
            if m.focusMode = "binge" then RestoreControlsFocus()
        end if
    end if
end sub

sub BuildBingeCard()
    if m.nextItem = invalid then return
    title = ""
    if m.nextItem.title <> invalid then title = m.nextItem.title
    if m.bingeTitle <> invalid then m.bingeTitle.text = title
    uri = ""
    if m.nextItem.thumbnails <> invalid then
        uri = GetCardImgByType(HC_CardTypeHorizontal(), m.nextItem.thumbnails)
    end if
    if m.bingeThumb <> invalid then m.bingeThumb.uri = uri
end sub

sub RestoreControlsFocus()
    m.focusMode = "controls"
    ApplyControlFocus()
end sub

' ── Play next (binge / auto-advance) ─────────────────────────────────────────

sub PlayNext()
    if m.nextItem = invalid then return
    if m.advancing then return
    m.advancing = true
    FlushProgress()

    nextEp = m.nextItem
    ' Reset binge/skip UI before swapping streams.
    m.bingeVisible = false
    if m.bingeCard <> invalid then m.bingeCard.visible = false
    if m.bingeGlow <> invalid then m.bingeGlow.visible = false
    m.skipVisible = false
    if m.skipIntroBtn <> invalid then m.skipIntroBtn.visible = false

    nextUrl = VideoStreamUrl(nextEp)
    if nextUrl = "" then
        GoBack()
        return
    end if

    m.detail = nextEp
    m.currentIndex = m.currentIndex + 1
    m.startOver = true                ' next episode always starts at 0
    m.playing = false
    m.ended = false
    m.reloading = true
    RestoreControlsFocus()

    ' Stop the finished stream cleanly before loading the next.
    ShowSpinner(true)
    m.videoNode.control = "stop"
    m.videoNode.content = invalid
    LoadAndPlay()
end sub

' ── Progress sync ────────────────────────────────────────────────────────────

sub OnProgressTimer()
    if not m.playing then return
    SendProgress()
end sub

sub FlushProgress()
    SendProgress()
end sub

sub SendProgress()
    if m.disposed then return
    if m.detail = invalid then return
    if m.isTrailer then return                ' trailers don't track progress
    videoId = VideoProgressId(m.detail)
    if videoId = "" then return
    if m.position <= 0 then return

    total = Int(m.duration)
    posSecs = Int(m.position)
    path = VideoProgressPath(videoId)
    body = VideoProgressBody(m.contentId, posSecs, total)
    task = ApiPost(path, body)
    ' Fire-and-forget: we don't observe the result (no UI depends on it), but we keep a
    ' reference so it isn't collected mid-flight.
    m.progressTask = task
    StartHttpTask(task)
end sub

' ── Keys ─────────────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.disposed then return

    key = ev.key

    if m.settingsOpen then
        HandleSettingsKey(key)
        return
    end if

    ' Any interaction reveals the controls and resets the idle hide timer.
    if not m.controlsVisible then
        ShowControls(true)
        ' fall through so the same press also acts (responsive parity).
    else
        RestartHideTimer()
    end if

    if m.focusMode = "skip" then
        HandleSkipKey(key)
    else if m.focusMode = "binge" then
        HandleBingeKey(key)
    else
        HandleControlsKey(key)
    end if
end sub

sub HandleControlsKey(key as string)
    if key = "left" then
        if m.controlIndex > 0 then m.controlIndex = m.controlIndex - 1
        ApplyControlFocus()
    else if key = "right" then
        if m.controlIndex < m.controlIds.Count() - 1 then m.controlIndex = m.controlIndex + 1
        ApplyControlFocus()
    else if key = "OK" or key = "ok" then
        id = m.controlIds[m.controlIndex]
        if id = "back" then
            SeekBy(-10)
        else if id = "play" then
            TogglePlayPause()
        else if id = "fwd" then
            SeekBy(10)
        else if id = "settings" then
            OpenSettings()
        end if
    else if key = "play" then
        TogglePlayPause()
    else if key = "rev" then
        SeekBy(-10)
    else if key = "fwd" then
        SeekBy(10)
    end if
end sub

sub HandleSkipKey(key as string)
    if key = "OK" or key = "ok" then
        DoSkipIntro()
    else if key = "down" or key = "left" or key = "right" then
        RestoreControlsFocus()
    end if
end sub

sub HandleBingeKey(key as string)
    if key = "OK" or key = "ok" then
        PlayNext()
    else if key = "down" or key = "left" then
        RestoreControlsFocus()
    end if
end sub

' ── Settings popup ───────────────────────────────────────────────────────────

sub OpenSettings()
    m.settingsOpen = true
    m.focusMode = "settings"
    if m.vm <> invalid then m.vm.overlayOpen = true
    if m.settingsOverlay <> invalid then m.settingsOverlay.visible = true
    m.hideTimer.control = "stop"
    ' Re-read theme tokens so panel/options pick up the latest API colors.
    LoadVideoTokens()
    ApplyControlColors()

    ' Build accordion sections (parity with settingPopUp.tsx): Quality (Auto + ladder)
    ' and Caption (off + langs). Both start collapsed.
    m.sections = []
    if m.qualityOptions.Count() > 0 then
        m.sections.Push({ kind: "quality", title: CopyVideoQuality(), expanded: false })
    end if
    if m.speedOptions.Count() > 0 then
        m.sections.Push({ kind: "speed", title: CopyVideoSpeed(), expanded: false })
    end if
    if m.capOptions.Count() > 1 then
        m.sections.Push({ kind: "caption", title: CopyVideoCaptions(), expanded: false })
    end if

    m.settingsFocus = 0
    BuildSettingsFlat()
    RenderSettings()
end sub

sub CloseSettings()
    m.settingsOpen = false
    if m.vm <> invalid then m.vm.overlayOpen = false
    if m.settingsOverlay <> invalid then m.settingsOverlay.visible = false
    RestoreControlsFocus()
    ShowControls(true)
end sub

sub OnOverlayDismiss()
    ' Global Back routes here first when an overlay is open (see NavigationHandleBack).
    if m.settingsOpen then CloseSettings()
end sub

' The option list backing a section.
function SectionOptions(section as object) as object
    if section.kind = "quality" then return m.qualityOptions
    if section.kind = "speed" then return m.speedOptions
    return m.capOptions
end function

' Flatten the accordion into a single focusable list: close, then each header, with
' that section's options inlined when it is expanded.
sub BuildSettingsFlat()
    flat = [{ kind: "close" }]
    for si = 0 to m.sections.Count() - 1
        flat.Push({ kind: "header", si: si })
        if m.sections[si].expanded then
            opts = SectionOptions(m.sections[si])
            for oi = 0 to opts.Count() - 1
                flat.Push({ kind: "option", si: si, oi: oi })
            end for
        end if
    end for
    m.settingsFlat = flat
    if m.settingsFocus >= flat.Count() then m.settingsFocus = flat.Count() - 1
    if m.settingsFocus < 0 then m.settingsFocus = 0
end sub

' Render the flat list into settingsRows; keep parallel node refs for focus updates.
sub RenderSettings()
    if m.settingsRows = invalid then return
    for i = m.settingsRows.getChildCount() - 1 to 0 step -1
        m.settingsRows.removeChildIndex(i)
    end for
    m.rowRefs = []

    y = 0
    for idx = 0 to m.settingsFlat.Count() - 1
        row = m.settingsFlat[idx]
        if row.kind = "close" then
            ' Close is the fixed poster in the XML (top-right), not a rendered row.
            m.rowRefs.Push({ kind: "close" })
        else if row.kind = "header" then
            section = m.sections[row.si]
            g = m.settingsRows.createChild("Group")
            g.translation = [0, y]
            ' Focus ring (parity with the header's `border border-neutral-50` when focused):
            ' rounded white outline tinted by the neutral-50 token, shown only on focus.
            hborder = g.createChild("Poster")
            hborder.translation = [0, -4]
            hborder.width = 500
            hborder.height = 56
            hborder.uri = "pkg:/images/ui/set_opt_focus.png"
            hborder.blendColor = m.cNeutral50
            hborder.visible = false
            title = g.createChild("Label")
            title.translation = [16, 0]
            title.width = 420
            title.height = 48
            title.vertAlign = "center"
            title.text = section.title
            title.color = m.cNeutral50
            title.opacity = 0.7
            title.font = MakeVideoFont("pkg:/fonts/Inter-SemiBold.ttf", 26)
            chev = g.createChild("Poster")
            chev.translation = [452, 14]
            chev.width = 28
            chev.height = 28
            chev.blendColor = m.cNeutral50
            chev.opacity = 0.7
            if section.expanded then
                chev.uri = "pkg:/images/ui/ic_v_chev_up.png"
            else
                chev.uri = "pkg:/images/ui/ic_v_chev_down.png"
            end if
            m.rowRefs.Push({ kind: "header", title: title, chev: chev, border: hborder })
            y = y + 64
        else
            opts = SectionOptions(m.sections[row.si])
            opt = opts[row.oi]
            g = m.settingsRows.createChild("Group")
            g.translation = [16, y]
            ' Option fill is a white rounded shape tinted by the API neutral-400 token
            ' (parity with React's bg-neutral-400) — not a baked color.
            bg = g.createChild("Poster")
            bg.width = 500
            bg.height = 56
            bg.uri = "pkg:/images/ui/set_opt.png"
            bg.blendColor = m.cNeutral400
            ' Focus ring (parity with border-neutral-50): a white rounded outline, tinted
            ' by the neutral-50 token and shown only when the row is focused.
            border = g.createChild("Poster")
            border.width = 500
            border.height = 56
            border.uri = "pkg:/images/ui/set_opt_focus.png"
            border.blendColor = m.cNeutral50
            border.visible = false
            lbl = g.createChild("Label")
            lbl.translation = [24, 0]
            lbl.width = 420
            lbl.height = 56
            lbl.vertAlign = "center"
            lbl.text = opt.label
            lbl.color = m.cNeutral50
            lbl.font = MakeVideoFont("pkg:/fonts/Inter-Regular.ttf", 24)
            chk = g.createChild("Poster")
            chk.translation = [456, 16]
            chk.width = 24
            chk.height = 24
            chk.uri = "pkg:/images/ui/ic_v_check.png"
            chk.blendColor = m.cNeutral50
            chk.visible = (OptionIsSelected(m.sections[row.si], opt))
            m.rowRefs.Push({ kind: "option", bg: bg, border: border, lbl: lbl, chk: chk })
            y = y + 64
        end if
    end for
    ApplySettingsFocus()
end sub

function OptionIsSelected(section as object, opt as object) as boolean
    if section.kind = "quality" then return opt.height = m.selectedQualityHeight
    if section.kind = "speed" then return opt.rate = m.selectedSpeed
    return opt.lang = m.selectedSubtitle
end function

function MakeVideoFont(uri as string, size as integer) as object
    font = CreateObject("roSGNode", "Font")
    font.uri = uri
    font.size = size
    return font
end function

' Highlight the focused row: close icon tints primary; header title/chevron go primary;
' option rows swap to the bordered background.
sub ApplySettingsFocus()
    focus = m.settingsFocus
    if m.settingsClose <> invalid then
        if m.settingsFlat[focus].kind = "close" then
            m.settingsClose.blendColor = m.cPrimary500
        else
            m.settingsClose.blendColor = m.cNeutral50
        end if
    end if
    for i = 0 to m.rowRefs.Count() - 1
        ref = m.rowRefs[i]
        focused = (i = focus)
        if ref.kind = "header" then
            ' React: headers inherit text-neutral-50 at opacity-70 (brighten to 100 on
            ' focus) and gain a `border border-neutral-50` box when focused.
            if focused then
                ref.title.opacity = 1.0
                ref.chev.opacity = 1.0
            else
                ref.title.opacity = 0.7
                ref.chev.opacity = 0.7
            end if
            ref.title.color = m.cNeutral50
            ref.chev.blendColor = m.cNeutral50
            if ref.border <> invalid then ref.border.visible = focused
        else if ref.kind = "option" then
            if ref.border <> invalid then ref.border.visible = focused
        end if
    end for
end sub

sub HandleSettingsKey(key as string)
    maxIndex = m.settingsFlat.Count() - 1
    if key = "up" then
        if m.settingsFocus > 0 then m.settingsFocus = m.settingsFocus - 1
        ApplySettingsFocus()
    else if key = "down" then
        if m.settingsFocus < maxIndex then m.settingsFocus = m.settingsFocus + 1
        ApplySettingsFocus()
    else if key = "OK" or key = "ok" then
        row = m.settingsFlat[m.settingsFocus]
        if row.kind = "close" then
            CloseSettings()
        else if row.kind = "header" then
            ToggleSection(row.si)
        else if row.kind = "option" then
            SelectOption(row.si, row.oi)
        end if
    end if
end sub

' Accordion behaviour: expanding one section collapses the others (parity with the
' single expandedItem in settingPopUp.tsx).
sub ToggleSection(si as integer)
    nowExpanded = not m.sections[si].expanded
    for i = 0 to m.sections.Count() - 1
        m.sections[i].expanded = (i = si and nowExpanded)
    end for
    BuildSettingsFlat()
    RenderSettings()
end sub

sub SelectOption(si as integer, oi as integer)
    section = m.sections[si]
    if section.kind = "quality" then
        SelectQuality(oi)
    else if section.kind = "speed" then
        SelectSpeed(oi)
    else
        SelectCaption(oi)
    end if
    CloseSettings()
end sub

sub SelectSpeed(oi as integer)
    if oi < 0 or oi >= m.speedOptions.Count() then return
    m.selectedSpeed = m.speedOptions[oi].rate
    ' Best-effort: Roku exposes no playbackRate on the Video node (only trick-mode FF/RW),
    ' so unlike the web player the rate cannot be re-applied to the live HLS stream. The
    ' selection is persisted/highlighted for parity with the React settings popup.
end sub

sub SelectQuality(oi as integer)
    if oi < 0 or oi >= m.qualityOptions.Count() then return
    opt = m.qualityOptions[oi]
    if opt.height = m.selectedQualityHeight then return
    m.selectedQualityHeight = opt.height
    ' Roku has no in-session level switch; reload the chosen variant playlist at the
    ' current position ("Auto" reloads the master so ABR resumes).
    ReloadVariant(opt.url)
end sub

sub ReloadVariant(url as string)
    if m.videoNode = invalid or url = "" then return
    resumeAt = Int(m.position)
    m.reloading = true
    m.ended = false
    ShowSpinner(true)
    m.playing = false
    m.videoNode.control = "stop"
    m.videoNode.content = invalid
    m.videoNode.content = BuildContent(url, resumeAt)
    m.videoNode.control = "play"
end sub

sub SelectCaption(optIdx as integer)
    if optIdx < 0 or optIdx >= m.capOptions.Count() then return
    opt = m.capOptions[optIdx]
    m.selectedSubtitle = opt.lang
    ApplyCaptionSelection(opt.lang)
end sub

sub ApplyCaptionSelection(lang as string)
    if m.videoNode = invalid then return
    if lang = "off" then
        m.videoNode.globalCaptionMode = "Off"
        m.videoNode.subtitleTrack = ""
        return
    end if
    m.videoNode.globalCaptionMode = "On"
    ' Match the chosen language to an available track and enable it.
    avail = m.videoNode.availableSubtitleTracks
    if avail <> invalid then
        for each tk in avail
            if tk <> invalid and tk.Language = lang then
                m.videoNode.subtitleTrack = tk.TrackName
                return
            end if
        end for
    end if
end sub

' ── Navigation / teardown ────────────────────────────────────────────────────

sub GoBack()
    if m.vm <> invalid then m.vm.callFunc("NavigatePop")
end sub

' Hard teardown — the leak guard. Runs when ViewManager sets dispose=true on pop/replace.
sub OnDispose()
    if not m.top.dispose then return
    if m.disposed then return
    m.disposed = true

    ' Final progress beacon while we still know the position.
    FlushProgress()

    ' Stop every Timer + the loader animation.
    if m.hideTimer <> invalid then m.hideTimer.control = "stop"
    if m.progressTimer <> invalid then m.progressTimer.control = "stop"
    if m.loaderAnim <> invalid then m.loaderAnim.control = "stop"

    ' Stop the manifest fetch task if it's still running.
    if m.manifestTask <> invalid then
        m.manifestTask.unobserveField("done")
        m.manifestTask.control = "stop"
        m.manifestTask = invalid
    end if

    ' Stop + release the Video so no audio/decoder keeps running in the background.
    if m.videoNode <> invalid then
        m.videoNode.unobserveField("state")
        m.videoNode.unobserveField("position")
        m.videoNode.unobserveField("duration")
        m.videoNode.control = "stop"
        m.videoNode.content = invalid
    end if

    ' Drop observers + overlay flag.
    if m.vm <> invalid then
        m.vm.unobserveField("overlayDismiss")
        if m.vm.overlayOpen = true then m.vm.overlayOpen = false
    end if
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.unobserveField("businessResolved")
    end if
    m.top.unobserveField("keyEvent")

    m.progressTask = invalid
end sub
