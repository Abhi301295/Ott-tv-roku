sub init()
    m.top.loading = true
    m.top.ready = false
    m.top.error = ""

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
        m.global.addFields({
            businessResolved: resolved
            businessConfigRaw: cfg
        })
    end if

    m.top.loading = false
    m.top.ready = true
end sub

' Dev defaults when API fails (channel still boots).
sub ApplyFallbackTheme()
    resolved = EmptyResolved()
    cfg = AppConfig()
    resolved.portalPrimaryColor = "#0b75e0"
    resolved.portalSecondaryColor = "#e279ce"
    resolved.portalTertiaryColor = "#ffffff"
    resolved.brandingLogo = ""
    resolved.appName = "OTT Accelerator"
    ApplyResolvedTheme(m.top, resolved)

    if m.global <> invalid then
        m.global.addFields({ businessResolved: resolved })
    end if
end sub
