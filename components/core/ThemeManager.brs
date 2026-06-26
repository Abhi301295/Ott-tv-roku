sub init()
    m.top.loading = true
    m.top.ready = false
    m.top.error = ""

    ' Seed early so screens can observe before the HTTP response lands.
    if m.global <> invalid and not m.global.hasField("businessResolved") then
        m.global.addFields({ businessResolved: EmptyResolved() })
    end if

    FetchBusinessConfig()
end sub

sub FetchBusinessConfig()
    path = Endpoints().BUSINESS_CONFIG
    m.configTask = ApiGet(path)
    m.configTask.observeField("apiResult", "OnConfigResponse")
    StartHttpTask(m.configTask)
end sub

sub OnConfigResponse()
    task = m.configTask
    if task = invalid then return

    api = task.apiResult
    if api = invalid or not api.ok then
        m.top.error = task.errorMessage
        if m.top.error = "" then m.top.error = "Failed to load business config"
        ApplyFallbackTheme()
        m.top.loading = false
        m.top.ready = true
        return
    end if

    cfg = api.result
    resolved = BuildResolved(cfg)
    ApplyResolvedTheme(m.top, resolved)

    if m.global <> invalid then
        if not m.global.hasField("businessResolved") then
            m.global.addFields({ businessResolved: resolved })
        else
            m.global.businessResolved = resolved
        end if
        if not m.global.hasField("businessConfigRaw") then
            m.global.addFields({ businessConfigRaw: cfg })
        else
            m.global.businessConfigRaw = cfg
        end if
    end if

    m.top.loading = false
    m.top.ready = true
end sub

' Dev defaults when API fails (channel still boots).
' Leave colors empty so BuildThemeTokens falls back to the static dark theme
' (DarkThemeTokens) — the same behavior as the React app when the backend
' returns colors:null. This keeps neutrals white/#e5e5e5 (no pink secondary),
' primary #0092ff, and background #1f1f22, matching LG.
sub ApplyFallbackTheme()
    resolved = EmptyResolved()
    resolved.portalPrimaryColor = ""
    resolved.portalSecondaryColor = ""
    resolved.portalTertiaryColor = ""
    resolved.brandingLogo = ""
    resolved.appName = "OTT Accelerator"
    ApplyResolvedTheme(m.top, resolved)

    if m.global <> invalid then
        if not m.global.hasField("businessResolved") then
            m.global.addFields({ businessResolved: resolved })
        else
            m.global.businessResolved = resolved
        end if
    end if
end sub
