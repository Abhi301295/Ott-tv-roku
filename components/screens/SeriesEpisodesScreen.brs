' SeriesEpisodesScreen.brs — parity with features/contentdetail/season/seriesEpisode.tsx.
' Two panes: season tabs (left) + vertical episode list (right). Selecting an episode
' opens the player with the full cross-season binge queue; selecting a trailer plays it alone.

' ── Geometry ─────────────────────────────────────────────────────────────────
function SE_SeasonTabWidth() as integer: return 560: end function
function SE_SeasonTabHeight() as integer: return 64: end function
function SE_SeasonTabPitch() as integer: return 80: end function
function SE_SeasonBaseY() as integer: return 300: end function
function SE_SeasonViewHeight() as integer: return 740: end function

function SE_CardWidth() as integer: return 1180: end function
function SE_CardHeight() as integer: return 200: end function
function SE_CardPitch() as integer: return 224: end function
function SE_EpBaseY() as integer: return 250: end function
function SE_EpViewHeight() as integer: return 790: end function
function SE_ThumbW() as integer: return 320: end function
function SE_ThumbH() as integer: return 180: end function

sub init()
    m.bg = m.top.findNode("bg")
    m.seriesTitle = m.top.findNode("seriesTitle")
    m.seriesMeta = m.top.findNode("seriesMeta")
    m.seasonsHost = m.top.findNode("seasonsHost")
    m.episodesHost = m.top.findNode("episodesHost")
    m.sectionHeading = m.top.findNode("sectionHeading")
    m.sectionSubtitle = m.top.findNode("sectionSubtitle")
    m.leftMask = m.top.findNode("leftMask")
    m.rightMask = m.top.findNode("rightMask")
    m.loadingLabel = m.top.findNode("loadingLabel")

    m.contentId = ""
    m.contentType = ""
    m.seasons = []
    m.continueWatching = []
    m.genres = []
    m.trailerList = []
    m.tabs = []
    m.tabNodes = []
    m.tabFrames = []
    m.episodes = []
    m.epCards = []
    m.epFrames = []
    m.activeSeason = invalid
    m.isTrailerActive = false
    m.activeTabIndex = 0
    m.seasonFocusIndex = 0
    m.episodeIndex = 0
    m.focusZone = "episodes"
    m.seasonScrollY = 0
    m.epScrollY = 0
    m.loading = true

    m.vm = FindViewManager(m.top)
    LoadSeriesTokens()
    ApplyStaticColors()

    m.top.observeField("keyEvent", "OnKey")
    if m.global <> invalid and m.global.hasField("businessResolved") then
        m.global.observeField("businessResolved", "OnBusinessResolved")
    end if

    ShowLoading(true)
end sub

sub OnNavStateReady()
    state = m.top.navState
    if state = invalid then return
    if state.id <> invalid then m.contentId = state.id
    if state.type <> invalid then m.contentType = state.type
    if m.contentId = "" then return
    FetchSeries()
end sub

sub OnDispose()
    ' No timers/video to tear down; left for parity with the screen interface.
end sub

sub OnBusinessResolved()
    LoadSeriesTokens()
    ApplyStaticColors()
    if not m.loading then
        RebuildSeasonTabs()
        RebuildEpisodeCards()
        ApplySeasonFocus()
        ApplyEpisodeFocus()
    end if
end sub

sub LoadSeriesTokens()
    m.tokens = {}
    tm = m.top.getScene().findNode("themeManager")
    if tm <> invalid and tm.themeTokens <> invalid then m.tokens = tm.themeTokens
    m.cPrimary500 = TCse("primary-500", "#0b75e0")
    m.cPrimary600 = TCse("primary-600", "#0760bb")
    m.cPrimary700 = TCse("primary-700", "#04478b")
    m.cNeutral50 = TCse("neutral-50", "#f5f5f5")
    m.cNeutral300 = TCse("neutral-300", "#d6d6d6")
    m.cNeutral700 = TCse("neutral-700", "#404040")
    m.cNeutral800 = TCse("neutral-800", "#121212")
end sub

function TCse(name as string, fallbackHex as string) as string
    return ThemeTokenColor(m.tokens, name, fallbackHex)
end function

sub ApplyStaticColors()
    if m.bg <> invalid then m.bg.color = m.cNeutral800
    if m.leftMask <> invalid then m.leftMask.color = m.cNeutral800
    if m.rightMask <> invalid then m.rightMask.color = m.cNeutral800
    if m.seriesTitle <> invalid then m.seriesTitle.color = m.cNeutral50
    if m.seriesMeta <> invalid then m.seriesMeta.color = m.cNeutral300
    if m.sectionHeading <> invalid then m.sectionHeading.color = m.cNeutral50
    if m.sectionSubtitle <> invalid then m.sectionSubtitle.color = m.cNeutral300
    if m.loadingLabel <> invalid then m.loadingLabel.color = m.cNeutral300
end sub

sub ShowLoading(show as boolean)
    m.loading = show
    if m.loadingLabel <> invalid then m.loadingLabel.visible = show
end sub

' ── Fetch ────────────────────────────────────────────────────────────────────

sub FetchSeries()
    ShowLoading(true)
    tp = m.contentType
    if tp = "" then tp = "SERIES_AND_EPISODES"
    path = DetailContentPath(m.contentId, tp)
    m.seriesTask = ApiGet(path)
    m.seriesTask.observeField("apiResult", "OnSeriesResponse")
    StartHttpTask(m.seriesTask)
end sub

sub OnSeriesResponse()
    if m.seriesTask = invalid then return
    m.seriesTask.unobserveField("apiResult")
    api = m.seriesTask.apiResult
    m.seriesTask = invalid

    if api = invalid or api.statusCode = invalid or api.statusCode <> 200 or api.result = invalid then
        ShowAlert(m.top, 2, CopyDetailLoadFailed())
        ShowLoading(false)
        return
    end if

    data = api.result
    if data.seasons <> invalid then m.seasons = data.seasons
    if data.continueWatching <> invalid then m.continueWatching = data.continueWatching
    if data.genres <> invalid then m.genres = data.genres
    m.seriesThumbnails = data.thumbnails

    title = ""
    if data.title <> invalid then title = data.title
    m.seriesTitle.text = title
    m.seriesMeta.text = SE_SeriesMetaLine(data)

    m.trailerList = SE_BuildTrailerList(m.seasons, data.thumbnails)

    ShowLoading(false)
    BuildTabModel()
    SelectInitialSeason(data)
    RebuildSeasonTabs()
    RebuildEpisodeCards()
    ApplySeasonFocus()
    ApplyEpisodeFocus()
end sub

function SE_SeriesMetaLine(data as object) as string
    out = ""
    if data.year <> invalid then out = Str(data.year).Trim()
    cnt = 0
    if data.seasons <> invalid then cnt = data.seasons.Count()
    if cnt > 0 then
        seasonsTxt = cnt.ToStr() + " Seasons"
        if out <> "" then out = out + " " + Chr(8226) + " "
        out = out + seasonsTxt
    end if
    return out
end function

' ── Tab model ────────────────────────────────────────────────────────────────

sub BuildTabModel()
    m.tabs = []
    sorted = SE_SortSeasonsDescending(m.seasons)
    for each s in sorted
        m.tabs.Push({ kind: "season", season: s })
    end for
    if m.trailerList.Count() > 0 then
        m.tabs.Push({ kind: "trailer" })
    end if
end sub

sub SelectInitialSeason(data as object)
    initial = invalid
    savedId = SE_GetLastSeason(m.contentId)
    if savedId <> "" then
        for each s in m.seasons
            if s <> invalid and s._id = savedId then
                initial = s
                exit for
            end if
        end for
    end if

    if initial = invalid and m.continueWatching.Count() > 0 then
        lastSeasonNum = m.continueWatching[0].season
        if lastSeasonNum <> invalid then
            for each s in m.seasons
                if s <> invalid and SE_SeasonNumber(s) = Int(lastSeasonNum) then
                    initial = s
                    exit for
                end if
            end for
        end if
    end if

    if initial = invalid and m.seasons.Count() > 0 then
        best = invalid
        for each s in m.seasons
            if s <> invalid then
                if best = invalid or SE_SeasonNumber(s) > SE_SeasonNumber(best) then best = s
            end if
        end for
        initial = best
    end if

    m.isTrailerActive = false
    m.activeSeason = initial
    if initial <> invalid then
        m.episodes = initial.episodes
        if m.episodes = invalid then m.episodes = []
        SE_SaveLastSeason(m.contentId, initial._id)
    else
        m.episodes = []
    end if

    ' Active tab index + focus the saved/first episode (parity with the initial setFocus).
    m.activeTabIndex = TabIndexForActive()
    m.seasonFocusIndex = m.activeTabIndex
    m.episodeIndex = 0
    savedEp = SE_GetLastEpisode(m.contentId)
    if savedEp <> "" and m.episodes <> invalid then
        for i = 0 to m.episodes.Count() - 1
            ep = m.episodes[i]
            if ep <> invalid and ep._id = savedEp then
                m.episodeIndex = i
                exit for
            end if
        end for
    end if
    m.focusZone = "episodes"
    UpdateSectionHeader()
end sub

function TabIndexForActive() as integer
    for i = 0 to m.tabs.Count() - 1
        t = m.tabs[i]
        if m.isTrailerActive then
            if t.kind = "trailer" then return i
        else if t.kind = "season" and m.activeSeason <> invalid then
            if t.season._id = m.activeSeason._id then return i
        end if
    end for
    return 0
end function

sub UpdateSectionHeader()
    heading = ""
    sub2 = ""
    if m.isTrailerActive then
        heading = "Trailers & More"
    else if m.activeSeason <> invalid then
        if m.activeSeason.title <> invalid and m.activeSeason.title <> "" then
            heading = m.activeSeason.title
        else
            heading = "Season " + SE_SeasonNumber(m.activeSeason).ToStr()
        end if
        disc = ""
        if m.episodes.Count() > 0 and m.episodes[0].discretion <> invalid then disc = m.episodes[0].discretion
        genre = ""
        if m.genres <> invalid and m.genres.Count() > 0 and m.genres[0].name <> invalid then genre = m.genres[0].name
        if disc <> "" then sub2 = disc
        if genre <> "" then
            if sub2 <> "" then sub2 = sub2 + " " + Chr(8226) + " "
            sub2 = sub2 + genre
        end if
    end if
    m.sectionHeading.text = heading
    m.sectionSubtitle.text = sub2
end sub

' ── Season tabs (rendered) ─────────────────────────────────────────────────────

sub RebuildSeasonTabs()
    ClearHost(m.seasonsHost)
    m.tabNodes = []
    m.tabFrames = []
    y = 0
    for i = 0 to m.tabs.Count() - 1
        t = m.tabs[i]
        node = m.seasonsHost.createChild("Group")
        node.translation = [0, y]

        leftLabel = node.createChild("Label")
        leftLabel.translation = [20, 16]
        leftLabel.width = 360
        leftLabel.height = 32
        font = leftLabel.createChild("Font")
        font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
        font.size = 24

        rightLabel = node.createChild("Label")
        rightLabel.translation = [380, 16]
        rightLabel.width = 160
        rightLabel.height = 32
        rightLabel.horizAlign = "right"
        rfont = rightLabel.createChild("Font")
        rfont.uri = "pkg:/fonts/Inter-Regular.ttf"
        rfont.size = 24

        if t.kind = "trailer" then
            leftLabel.text = "Trailers & More"
            rightLabel.text = m.trailerList.Count().ToStr() + " trailers"
        else
            leftLabel.text = "Season " + SE_SeasonNumber(t.season).ToStr()
            epc = 0
            if t.season.episodes <> invalid then epc = t.season.episodes.Count()
            rightLabel.text = epc.ToStr() + " episodes"
        end if

        m.tabNodes.Push({ node: node, left: leftLabel, right: rightLabel })
        m.tabFrames.Push(invalid)
        y = y + SE_SeasonTabPitch()
    end for
    ApplySeasonScroll()
end sub

sub ApplySeasonFocus()
    for i = 0 to m.tabNodes.Count() - 1
        entry = m.tabNodes[i]
        isActive = (i = m.activeTabIndex)
        isFocused = (m.focusZone = "seasons" and i = m.seasonFocusIndex)
        if isActive then
            entry.left.color = m.cPrimary500
            entry.right.color = m.cPrimary600
        else
            entry.left.color = m.cNeutral50
            entry.right.color = m.cNeutral50
        end if
        frame = m.tabFrames[i]
        frame = CardEnsureFocusFrame(entry.node, frame, 0, 0, SE_SeasonTabWidth(), SE_SeasonTabHeight(), m.cPrimary600)
        m.tabFrames[i] = frame
        CardApplyFocusBorder(frame, isFocused, m.cPrimary600)
    end for
    ApplySeasonScroll()
end sub

sub ApplySeasonScroll()
    if m.focusZone <> "seasons" then return
    cardTop = m.seasonFocusIndex * SE_SeasonTabPitch()
    cardBottom = cardTop + SE_SeasonTabHeight()
    if cardTop < m.seasonScrollY then
        m.seasonScrollY = cardTop
    else if cardBottom > m.seasonScrollY + SE_SeasonViewHeight() then
        m.seasonScrollY = cardBottom - SE_SeasonViewHeight()
    end if
    if m.seasonScrollY < 0 then m.seasonScrollY = 0
    m.seasonsHost.translation = [40, SE_SeasonBaseY() - m.seasonScrollY]
end sub

' ── Episode cards (rendered) ───────────────────────────────────────────────────

sub RebuildEpisodeCards()
    ClearHost(m.episodesHost)
    m.epCards = []
    m.epFrames = []
    list = m.episodes
    if m.isTrailerActive then list = m.trailerList
    if list = invalid then list = []

    y = 0
    for i = 0 to list.Count() - 1
        ep = list[i]
        if ep = invalid then continue for
        card = m.episodesHost.createChild("Group")
        card.translation = [0, y]

        thumb = card.createChild("Poster")
        thumb.translation = [16, 10]
        thumb.width = SE_ThumbW()
        thumb.height = SE_ThumbH()
        thumb.loadDisplayMode = "scaleToFill"
        uri = ""
        if ep.thumbnails <> invalid then uri = GetCardImgByType(HC_CardTypeHorizontal(), ep.thumbnails)
        if uri <> "" then thumb.uri = uri

        ' Progress bar (parity with the EpisodeCard progress overlay).
        pct = 0.0
        if not m.isTrailerActive then pct = SE_EpisodeProgress(m.continueWatching, m.activeSeason, ep)
        if pct > 0 then
            track = card.createChild("Rectangle")
            track.translation = [16, 182]
            track.width = SE_ThumbW()
            track.height = 6
            track.color = m.cNeutral700
            fill = card.createChild("Rectangle")
            fill.translation = [16, 182]
            fw = Int(SE_ThumbW() * pct / 100)
            if fw < 2 then fw = 2
            if fw > SE_ThumbW() then fw = SE_ThumbW()
            fill.width = fw
            fill.height = 6
            fill.color = m.cPrimary500
        end if

        titleLabel = card.createChild("Label")
        titleLabel.translation = [360, 14]
        titleLabel.width = 800
        titleLabel.height = 44
        titleLabel.maxLines = 1
        titleLabel.color = m.cNeutral50
        tf = titleLabel.createChild("Font")
        tf.uri = "pkg:/fonts/Inter-Bold.ttf"
        tf.size = 32
        tt = ""
        if ep.title <> invalid then tt = ep.title
        titleLabel.text = tt

        descLabel = card.createChild("Label")
        descLabel.translation = [360, 62]
        descLabel.width = 800
        descLabel.height = 64
        descLabel.wrap = true
        descLabel.maxLines = 2
        descLabel.lineSpacing = 6
        descLabel.color = m.cNeutral300
        df = descLabel.createChild("Font")
        df.uri = "pkg:/fonts/Inter-Regular.ttf"
        df.size = 22
        dd = ""
        if ep.description <> invalid then dd = ep.description
        descLabel.text = dd

        metaLabel = card.createChild("Label")
        metaLabel.translation = [360, 140]
        metaLabel.width = 800
        metaLabel.height = 28
        metaLabel.color = m.cNeutral50
        mf = metaLabel.createChild("Font")
        mf.uri = "pkg:/fonts/Inter-SemiBold.ttf"
        mf.size = 20
        if m.isTrailerActive then
            metaLabel.text = ""
        else
            metaLabel.text = SE_EpisodeMetaLine(ep)
        end if

        m.epCards.Push(card)
        m.epFrames.Push(invalid)
        y = y + SE_CardPitch()
    end for

    if m.episodeIndex >= m.epCards.Count() then m.episodeIndex = 0
    ApplyEpisodeScroll()
end sub

sub ApplyEpisodeFocus()
    for i = 0 to m.epCards.Count() - 1
        card = m.epCards[i]
        isFocused = (m.focusZone = "episodes" and i = m.episodeIndex)
        frame = m.epFrames[i]
        frame = CardEnsureFocusFrame(card, frame, 0, 0, SE_CardWidth(), SE_CardHeight(), m.cPrimary600)
        m.epFrames[i] = frame
        CardApplyFocusBorder(frame, isFocused, m.cPrimary600)
    end for
    ApplyEpisodeScroll()
end sub

sub ApplyEpisodeScroll()
    if m.focusZone <> "episodes" then return
    if m.epCards.Count() = 0 then return
    cardTop = m.episodeIndex * SE_CardPitch()
    cardBottom = cardTop + SE_CardHeight()
    if cardTop < m.epScrollY then
        m.epScrollY = cardTop
    else if cardBottom > m.epScrollY + SE_EpViewHeight() then
        m.epScrollY = cardBottom - SE_EpViewHeight()
    end if
    if m.epScrollY < 0 then m.epScrollY = 0
    m.episodesHost.translation = [700, SE_EpBaseY() - m.epScrollY]
end sub

sub ClearHost(host as object)
    if host = invalid then return
    for i = host.getChildCount() - 1 to 0 step -1
        host.removeChildIndex(i)
    end for
end sub

' ── Keys ──────────────────────────────────────────────────────────────────────

sub OnKey()
    ev = m.top.keyEvent
    if ev = invalid or ev.key = invalid or ev.press = invalid then return
    if not ev.press then return
    if m.loading then return

    if m.focusZone = "seasons" then
        HandleSeasonsKey(ev.key)
    else
        HandleEpisodesKey(ev.key)
    end if
end sub

sub HandleSeasonsKey(key as string)
    if m.tabs.Count() = 0 then return
    if key = "up" then
        if m.seasonFocusIndex > 0 then m.seasonFocusIndex = m.seasonFocusIndex - 1
        ApplySeasonFocus()
    else if key = "down" then
        if m.seasonFocusIndex < m.tabs.Count() - 1 then m.seasonFocusIndex = m.seasonFocusIndex + 1
        ApplySeasonFocus()
    else if key = "right" then
        ' Jump into the episode list of the currently active season (parity with onArrowPress).
        m.focusZone = "episodes"
        if m.episodeIndex >= m.epCards.Count() then m.episodeIndex = 0
        ApplySeasonFocus()
        ApplyEpisodeFocus()
    else if key = "OK" or key = "ok" then
        SelectTab(m.seasonFocusIndex)
    end if
end sub

sub HandleEpisodesKey(key as string)
    if key = "left" then
        m.focusZone = "seasons"
        ApplyEpisodeFocus()
        ApplySeasonFocus()
    else if key = "up" then
        if m.episodeIndex > 0 then m.episodeIndex = m.episodeIndex - 1
        ApplyEpisodeFocus()
    else if key = "down" then
        if m.episodeIndex < m.epCards.Count() - 1 then m.episodeIndex = m.episodeIndex + 1
        ApplyEpisodeFocus()
    else if key = "OK" or key = "ok" then
        PlayFocusedEpisode()
    end if
end sub

sub SelectTab(index as integer)
    if index < 0 or index >= m.tabs.Count() then return
    t = m.tabs[index]
    m.activeTabIndex = index
    m.episodeIndex = 0
    m.epScrollY = 0

    if t.kind = "trailer" then
        m.isTrailerActive = true
        m.activeSeason = invalid
        m.episodes = m.trailerList
    else
        m.isTrailerActive = false
        m.activeSeason = t.season
        m.episodes = t.season.episodes
        if m.episodes = invalid then m.episodes = []
        if m.contentId <> "" and m.activeSeason._id <> invalid then
            SE_SaveLastSeason(m.contentId, m.activeSeason._id)
            if m.episodes.Count() > 0 and m.episodes[0]._id <> invalid then
                SE_SaveLastEpisode(m.contentId, m.episodes[0]._id)
            end if
        end if
    end if

    m.focusZone = "episodes"
    UpdateSectionHeader()
    RebuildEpisodeCards()
    ApplySeasonFocus()
    ApplyEpisodeFocus()
end sub

sub PlayFocusedEpisode()
    list = m.episodes
    if m.isTrailerActive then list = m.trailerList
    if list = invalid or m.episodeIndex < 0 or m.episodeIndex >= list.Count() then return
    episode = list[m.episodeIndex]
    if episode = invalid or m.vm = invalid then return

    if m.isTrailerActive then
        state = SE_PlayTrailerPayload(m.contentId, episode)
    else
        if m.contentId <> "" and episode._id <> invalid then
            SE_SaveLastEpisode(m.contentId, episode._id)
        end if
        state = SE_PlayEpisodePayload(m.contentId, episode, m.seasons)
    end if
    m.vm.callFunc("NavigatePush", RouteVideoPlayer(), state)
end sub
