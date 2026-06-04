' Endpoints.brs
' API endpoint paths (parity with src/utils/constant/api.endpoint.ts).
' All paths are relative to AppConfig().apiBaseUrl.

function Endpoints() as object
    version = "v1"
    media = "media"
    base = media + "/" + version

    return {
        LOGIN: {
            ONBOARD_DEVICE: base + "/device"
            DEVICE_TOKEN: base + "/device/token"
            REFRESH_TOKEN: base + "/sessions/refresh"
            LOGOUT_SESSION: base + "/sessions/logout"
            EMAIL_TOKEN: base + "/accounts/signin"
            CHECK_UPDATE: base + "/configuration"
        }
        HOME: {
            CATEGORY_LIST: base + "/contents/home"
            CONTINUE_WATCHING: base + "/videos/continue-watching"
        }
        SERIES: {
            SERIES_LIST: base + "/contents/filter"
            GENERE_LIST: base + "/contents/catalogue"
        }
        DETAIL: {
            CONTENT_VIEW: base + "/contents/view"
            WATCH_LIST: base + "/watch-list"
            SAVE_WATCH_LIST: base + "/watch-list/add"
            REMOVE_FROM_WATCH_LIST: base + "/watch-list/"
            UPDATE_VIDEO_PROGRESS: base + "/videos/"
            RECOMENDED_VIDEOS: base + "/contents/recommend"
        }
        MY_LIST: {
            MY_LIST_LISTING: base + "/watch-list/my-list"
            MY_LIST_DETAIL: base + "/watch-list/"
        }
        PROFILE: {
            GET_AVATAR_LIST: base + "/customers/profile/avatars"
            ADD_PROFILE: base + "/customers/add-profile"
            PROFILE_DETAILS: base + "/customers/profile"
            UPDATE_PROFILE: base + "/customers/profile"
            PROFILE_LIST: base + "/customers/profiles/list"
            USER_PROFILE: base + "/customers/profile"
            VERIFY_PIN: base + "/customers/verify-pin"
            VERIFY_PIN_BEFORE_LOGIN: base + "/accounts/parental-pin/verify-before-login"
            SELECT_PROFILE: base + "/accounts/select-profile"
            GET_LOGIN_PROFILES: base + "/customers/profiles/list"
            SELECT_PROFILE_TO_WATCH: base + "/accounts/select-profile"
            SELECT_PROFILE_TO_WATCH_BEFORE_LOGIN: base + "/customers/user/select-profile"
        }
        SEARCH: {
            SEARCH_LIST: base + "/contents/search"
        }
        COOKIES: {
            GET_COOKIES: media + "/signed-cookies?key=private/movies/*"
        }
        FILTER: base + "/contents/filter"
        GET_NEW_RELEASE_LIST: base + "/contents/new-release"
        SAVE_AD_VIEW: base + "/ads/view"
        REELS_LIST: base + "/contents/reels"
        BUSINESS_CONFIG: base + "/businesses/frontend/config"
    }
end function
