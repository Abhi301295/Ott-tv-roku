' BusinessConfig.brs
' Parse and resolve business config API payload (parity with BusinessConfigContext).

function DefaultFeatures() as object
    return {
        enableDarkMode: false
        enableNotifications: true
        enableAnalytics: true
        maintenanceMode: false
        enableRegistration: true
        enableSocialLogin: false
        reelsEnabled: false
        epgManagement: false
        geoBlockingEnabled: true
        subscriptionEnabled: true
        profileAutoLogin: true
        enableSideBarMenu: true
        displayTitle: false
        isBingeWatch: true
        enableTrailerOnBanner: true
        enableHomeBanner: false
        enableCardFocus: false
    }
end function

function EmptyResolved() as object
    return {
        appName: ""
        appDescription: ""
        supportEmail: ""
        contactPhone: ""
        portalPrimaryColor: ""
        portalSecondaryColor: ""
        portalTertiaryColor: ""
        lightThemeBackground: ""
        darkThemeBackground: ""
        brandingLogo: ""
        brandingFavicon: ""
        loginBackgroundImage: ""
        privacyPolicyLink: ""
        termsConditionsLink: ""
        instagramLink: ""
        facebookLink: ""
        googlePlayLink: ""
        appStoreLink: ""
        fontFamily: ""
        features: DefaultFeatures()
    }
end function

' cfg = API "result" object from GET businesses/frontend/config
function BuildResolved(cfg as object) as object
    if cfg = invalid then return EmptyResolved()

    resolved = EmptyResolved()
    ss = cfg.systemSettings

    general = invalid
    portal = invalid
    mobile = invalid
    branding = invalid
    features = DefaultFeatures()

    if ss <> invalid then
        if ss.general <> invalid then general = ss.general
        if ss.portalDesign <> invalid then portal = ss.portalDesign
        if ss.mobileTheming <> invalid then mobile = ss.mobileTheming
        if ss.branding <> invalid then branding = ss.branding
        if ss.features <> invalid then
            features = MergeFeatures(DefaultFeatures(), ss.features)
        end if
    end if

    title = ""
    if cfg.title <> invalid then title = cfg.title

    colors = cfg.colors
    primary = ""
    secondary = ""
    tertiary = ""
    if colors <> invalid then
        if colors.primary <> invalid then primary = colors.primary
        if colors.secondary <> invalid then secondary = colors.secondary
        if colors.tertiary <> invalid then tertiary = colors.tertiary
    end if

    logo = ""
    if cfg.logo <> invalid then logo = cfg.logo

    if general <> invalid then
        if general.appName <> invalid and general.appName <> "" then
            resolved.appName = general.appName
        else
            resolved.appName = title
        end if
        if general.appDescription <> invalid then resolved.appDescription = general.appDescription
        if general.supportEmail <> invalid then resolved.supportEmail = general.supportEmail
        if general.contactPhone <> invalid then resolved.contactPhone = general.contactPhone
    else
        resolved.appName = title
    end if

    if portal <> invalid then
        if portal.primaryColor <> invalid and portal.primaryColor <> "" then
            resolved.portalPrimaryColor = portal.primaryColor
        else
            resolved.portalPrimaryColor = primary
        end if
        if portal.secondaryColor <> invalid and portal.secondaryColor <> "" then
            resolved.portalSecondaryColor = portal.secondaryColor
        else
            resolved.portalSecondaryColor = secondary
        end if
        if portal.tertiaryColor <> invalid and portal.tertiaryColor <> "" then
            resolved.portalTertiaryColor = portal.tertiaryColor
        else
            resolved.portalTertiaryColor = tertiary
        end if
    else
        resolved.portalPrimaryColor = primary
        resolved.portalSecondaryColor = secondary
        resolved.portalTertiaryColor = tertiary
    end if

    if mobile <> invalid then
        if mobile.lightThemeBackground <> invalid then resolved.lightThemeBackground = mobile.lightThemeBackground
        if mobile.darkThemeBackground <> invalid then resolved.darkThemeBackground = mobile.darkThemeBackground
    end if

    if branding <> invalid then
        if branding.logo <> invalid and branding.logo <> "" then
            resolved.brandingLogo = branding.logo
        else
            resolved.brandingLogo = logo
        end if
        if branding.favicon <> invalid then resolved.brandingFavicon = branding.favicon
        if branding.loginBackgroundImage <> invalid then resolved.loginBackgroundImage = branding.loginBackgroundImage

        footer = branding.footer
        if footer <> invalid then
            if footer.privacyPolicyLink <> invalid then resolved.privacyPolicyLink = footer.privacyPolicyLink
            if footer.termsConditionsLink <> invalid then resolved.termsConditionsLink = footer.termsConditionsLink
            if footer.instagramLink <> invalid then resolved.instagramLink = footer.instagramLink
            if footer.facebookLink <> invalid then resolved.facebookLink = footer.facebookLink
            if footer.googlePlayLink <> invalid then resolved.googlePlayLink = footer.googlePlayLink
            if footer.appStoreLink <> invalid then resolved.appStoreLink = footer.appStoreLink
        end if
    else
        resolved.brandingLogo = logo
    end if

    if cfg.fontFamily <> invalid and cfg.fontFamily.selected <> invalid then
        resolved.fontFamily = cfg.fontFamily.selected
    end if

    resolved.features = features
    return resolved
end function

function MergeFeatures(base as object, overrides as object) as object
    merged = {}
    for each key in base
        merged[key] = base[key]
    end for
    if overrides <> invalid then
        for each key in overrides
            merged[key] = overrides[key]
        end for
    end if
    return merged
end function

function IsFeatureEnabled(resolved as object, featureName as string) as boolean
    if resolved = invalid or resolved.features = invalid then return false
    if resolved.features[featureName] = invalid then return false
    return CoerceFeatureFlag(resolved.features[featureName])
end function

' API JSON may return true/1/"true" — strict = true misses those (React treats them as on).
function CoerceFeatureFlag(value as dynamic) as boolean
    if value = invalid then return false
    t = type(value)
    if t = "roBoolean" or t = "Boolean" then return value
    if t = "roInteger" or t = "Integer" or t = "roFloat" or t = "Float" then return (value <> 0)
    if t = "roString" or t = "String" then
        s = LCase(value)
        return (s = "true" or s = "1" or s = "yes")
    end if
    return false
end function

function ResolvedBusinessFeatures() as object
    if m.global <> invalid and m.global.businessResolved <> invalid and m.global.businessResolved.features <> invalid then
        return m.global.businessResolved.features
    end if
    return DefaultFeatures()
end function

function FeatureFlagEnabled(name as string, defaultValue as boolean) as boolean
    features = ResolvedBusinessFeatures()
    if features[name] = invalid then return defaultValue
    return CoerceFeatureFlag(features[name])
end function

function ProfileAutoLoginEnabled() as boolean
    return FeatureFlagEnabled("profileAutoLogin", DefaultFeatures().profileAutoLogin)
end function

function FeatureEnableSideBarMenu() as boolean
    return FeatureFlagEnabled("enableSideBarMenu", DefaultFeatures().enableSideBarMenu)
end function

function FeatureEnableHomeBanner() as boolean
    return FeatureFlagEnabled("enableHomeBanner", DefaultFeatures().enableHomeBanner)
end function

function FeatureEnableCardFocus() as boolean
    return FeatureFlagEnabled("enableCardFocus", DefaultFeatures().enableCardFocus)
end function

function FeatureEnableTrailerOnBanner() as boolean
    return FeatureFlagEnabled("enableTrailerOnBanner", DefaultFeatures().enableTrailerOnBanner)
end function

function FeatureDisplayTitle() as boolean
    return FeatureFlagEnabled("displayTitle", DefaultFeatures().displayTitle)
end function

function FeatureIsBingeWatch() as boolean
    return FeatureFlagEnabled("isBingeWatch", DefaultFeatures().isBingeWatch)
end function
