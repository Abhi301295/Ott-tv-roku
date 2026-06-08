' HomeConstants.brs — card/row types and paging (parity with variable.constant.ts).

function HC_TypeContinueWatching() as string
    return "CONTINUE_WATCHING"
end function

function HC_TypeBanner() as string
    return "BANNER"
end function

function HC_TypeContentList() as string
    return "CONTENT_LIST"
end function

function HC_TypeTopContents() as string
    return "TOP_CONTENTS"
end function

function HC_HomePageStart() as integer
    return 1
end function

function HC_HomePageLimit() as integer
    return 4
end function

' Static theme default (parity with theme.config.ts homeLayout).
function HC_HomeLayoutNetflix() as string
    return "NETFLIX"
end function

function HC_HomeLayoutOtt() as string
    return "OTT"
end function
