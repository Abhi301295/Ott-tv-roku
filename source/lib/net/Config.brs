' Config.brs
' Runtime configuration (parity with the web app's src/utils/constant/env.ts).
'
' Values resolve in this order:
'   1. pkg:/config.json   (gitignored; copy from config.example.json)
'   2. built-in defaults  (dev backend, so the channel runs out of the box)
'
' Returns a cached associative array via m.global so it is read once.

function AppConfig() as object
    if m.global <> invalid and m.global.appConfig <> invalid then
        return m.global.appConfig
    end if

    cfg = {
        apiBaseUrl: "https://ottacceleratordev.appskeeper.in"
        businessDomain: "roku-tv"
        basicAuthUser: "OTT_USR"
        basicAuthPassword: "OTT_PWD"
        appVersion: "1.0.0"
    }

    overrides = ReadConfigJson()
    if overrides <> invalid then
        for each key in overrides
            cfg[key] = overrides[key]
        end for
    end if

    if m.global <> invalid then
        m.global.addFields({ appConfig: cfg })
    end if

    return cfg
end function

' Reads pkg:/config.json if present. Returns invalid when missing/unparseable.
function ReadConfigJson() as object
    ' Probe existence first; ReadAsciiFile prints a console error for a missing file.
    fs = CreateObject("roFileSystem")
    if fs = invalid or not fs.Exists("pkg:/config.json") then return invalid

    text = ReadAsciiFile("pkg:/config.json")
    if text = invalid or text = "" then return invalid

    parsed = ParseJson(text)
    if parsed = invalid then return invalid

    return parsed
end function
