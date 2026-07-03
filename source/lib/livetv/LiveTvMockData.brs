' LiveTvMockData.brs — port of src/features/livetv/mockData.ts generateEPGData().

function LT_Categories() as object
    return ["News", "Sports", "Movies", "Documentary", "Kids", "Series"]
end function

function LT_SpecialTemplates() as object
    return [
        { title: "Evening Report", durationMins: 25, desc: "A quick wrap of the top stories making headlines this evening, local and international.", category: "News" }
        { title: "Curb Your Enthusiasm", durationMins: 85, desc: "Larry David stars as himself in this landmark comedy series that details his life.", category: "Series" }
        { title: "Succession", durationMins: 30, desc: "The Roy family is known for controlling the biggest media and entertainment company.", category: "Series" }
        { title: "Do Not Disturb", durationMins: 30, desc: "A comedic look at hotel guests and staff during their late night antics.", category: "Series" }
        { title: "Privileges", durationMins: 30, desc: "An inside look at the lives and drama of the ultra-wealthy elite.", category: "Series" }
        { title: "Fish And Shark", durationMins: 30, desc: "A documentary exploring marine life and predator patterns in deep oceans.", category: "Documentary" }
        { title: "The Mission", durationMins: 30, desc: "A team of explorers travel to remote regions to execute search and rescue.", category: "Movies" }
        { title: "The Citadel", durationMins: 30, desc: "A thrilling spy drama about a global syndicate and their operations.", category: "Series" }
        { title: "Jumanji Movies", durationMins: 180, desc: "The 1995 classic film, starring Robin Williams, follows young Alan Parrish who discovers a mysterious board game.", category: "Movies" }
    ]
end function

function LT_ProgramTemplate(category as string, index as integer) as object
    news = [
        { title: "Morning headlines", desc: "A quick wrap of the top stories making headlines this morning." }
        { title: "World report", desc: "In-depth coverage of international news events and political developments." }
        { title: "Market watch", desc: "Latest updates from the stock market and financial trends." }
        { title: "Tech today", desc: "Exploring the latest breakthroughs in consumer tech and AI." }
    ]
    sports = [
        { title: "Pre-match", desc: "Pundit predictions and tactical discussions ahead of kickoff." }
        { title: "Premier league: City vs Reds", desc: "Live coverage of the highly anticipated match." }
        { title: "Post-match analysis", desc: "Post-game interviews and expert analysis." }
        { title: "Highlights", desc: "A recap of the best goals and defining moments." }
    ]
    movies = [
        { title: "Romcom (cont.)", desc: "A lighthearted story of two star-crossed lovers." }
        { title: "The last horizon", desc: "A stranded space crew races against a dying ship's systems." }
        { title: "Trailers", desc: "First-look teasers of upcoming blockbuster films." }
        { title: "Midnight Mystery", desc: "A detective investigates bizarre disappearances." }
    ]
    documentary = [
        { title: "Planet Earth", desc: "Stunning wildlife cinematography from remote habitats." }
        { title: "Ocean Deep", desc: "Exploring the mysteries of the deepest ocean trenches." }
        { title: "Ancient Worlds", desc: "Archaeological discoveries reshaping history." }
        { title: "Space Frontiers", desc: "Missions pushing the boundaries of human exploration." }
    ]
    kids = [
        { title: "Cartoon hour", desc: "Animated adventures for the whole family." }
        { title: "Learning fun", desc: "Educational segments with songs and games." }
        { title: "Puppet show", desc: "Classic puppet characters in a new adventure." }
        { title: "Bedtime tales", desc: "Gentle stories to wind down the evening." }
    ]
    series = [
        { title: "Episode 1", desc: "The season premiere sets up a new mystery." }
        { title: "Episode 2", desc: "Tensions rise as alliances shift." }
        { title: "Episode 3", desc: "A shocking reveal changes everything." }
        { title: "Episode 4", desc: "The team regroups for a daring plan." }
    ]
    bank = news
    if category = "Sports" then bank = sports
    if category = "Movies" then bank = movies
    if category = "Documentary" then bank = documentary
    if category = "Kids" then bank = kids
    if category = "Series" then bank = series
    idx = index Mod bank.Count()
    tpl = bank[idx]
    return { title: tpl.title, desc: tpl.desc, category: category }
end function

function LT_ChannelNameBase(category as string, slot as integer) as string
    news = ["News 24", "Global News", "City Report", "Morning Live"]
    sports = ["Sports HD", "Game Day", "Arena TV", "Champions Live"]
    movies = ["Cinema Plus", "Movie Hub", "Film World", "Blockbuster"]
    documentary = ["Discover Doc", "Wild Earth", "Nature Plus", "Geo Channel"]
    kids = ["Kids Planet", "Cartoon Network", "Toon Time", "Fun Zone"]
    series = ["Prime Drama", "HBO Hits", "FX Hub", "Series Plus"]
    bank = news
    if category = "Sports" then bank = sports
    if category = "Movies" then bank = movies
    if category = "Documentary" then bank = documentary
    if category = "Kids" then bank = kids
    if category = "Series" then bank = series
    return bank[slot Mod bank.Count()]
end function

function LT_MidnightTodayMs() as longinteger
    dt = CreateObject("roDateTime")
    dt.Mark()
    dt.ToLocalTime()
    sec = dt.AsSeconds()
    hour = dt.GetHours()
    min = dt.GetMinutes()
    s = dt.GetSeconds()
    midnightSec = sec - (hour * 3600 + min * 60 + s)
    return midnightSec * 1000&
end function

function LT_Pad2(n as integer) as string
    s = Str(n).Trim()
    if Len(s) < 2 then return "0" + s
    return s
end function

function LT_DeterministicDurationMins(channelIdx as integer, progIdx as integer) as integer
    durations = [30, 45, 60, 90, 120]
    pick = (channelIdx * 17 + progIdx * 7) Mod durations.Count()
    return durations[pick]
end function

function LT_GenerateEPGData() as object
    channels = []
    count = LT_MockChannelCount()
    categories = LT_Categories()
    specials = LT_SpecialTemplates()
    midnightToday = LT_MidnightTodayMs()
    startOfTimeline = midnightToday - (6& * 60& * 60& * 1000&)
    endOfTimeline = midnightToday + (48& * 60& * 60& * 1000&)

    for i = 0 to count - 1
        channelName = ""
        channelNumber = ""
        isSpecial = false

        if i = 0 then
            channelName = "HBO"
            channelNumber = "232"
            isSpecial = true
        else if i = 1 then
            channelName = "ESPN"
            channelNumber = "111"
            isSpecial = true
        else if i = 2 then
            channelName = "Discovery"
            channelNumber = "121"
            isSpecial = true
        else if i = 3 then
            channelName = "National Geographic"
            channelNumber = "266"
            isSpecial = true
        else
            category = categories[i Mod categories.Count()]
            nameBase = LT_ChannelNameBase(category, Int(i / categories.Count()))
            if i >= 12 then
                channelName = nameBase + " " + Str(Int(i / 12) + 1).Trim()
            else
                channelName = nameBase
            end if
            channelNumber = LT_Pad2(i + 1)
        end if

        programs = []
        currentTime = startOfTimeline
        progIndex = 0

        if isSpecial then
            while currentTime < endOfTimeline
                template = specials[progIndex Mod specials.Count()]
                durationMs = template.durationMins * 60& * 1000&
                programs.Push({
                    id: "p_" + Str(i).Trim() + "_" + Str(progIndex).Trim()
                    title: template.title
                    description: template.desc
                    startTime: currentTime
                    endTime: currentTime + durationMs
                    category: template.category
                })
                currentTime = currentTime + durationMs
                progIndex = progIndex + 1
            end while
        else
            category = categories[i Mod categories.Count()]
            while currentTime < endOfTimeline
                durationMins = LT_DeterministicDurationMins(i, progIndex)
                durationMs = durationMins * 60& * 1000&
                template = LT_ProgramTemplate(category, progIndex)
                progIndex = progIndex + 1
                programs.Push({
                    id: "p_" + Str(i).Trim() + "_" + Str(progIndex).Trim()
                    title: template.title
                    description: template.desc
                    startTime: currentTime
                    endTime: currentTime + durationMs
                    category: template.category
                })
                currentTime = currentTime + durationMs
            end while
        end if

        logo = UCase(Left(channelName, 3))

        channels.Push({
            id: "ch_" + Str(i).Trim()
            name: channelName
            logo: logo
            channelNumber: channelNumber
            programs: programs
        })
    end for

    print "[LIVETV_DBG] mock_epg channels=" + Str(channels.Count()).Trim()
    return {
        channels: channels
        timelineStart: startOfTimeline
        timelineEnd: endOfTimeline
    }
end function
