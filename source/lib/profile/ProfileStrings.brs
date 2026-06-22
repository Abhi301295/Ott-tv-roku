' ProfileStrings.brs — user-facing profile strings (parity with profile.enum.ts +
' profile.tsx + messages.ts). Centralized for one source of truth / localization.

function CopyChooseProfile() as string: return "Who's Watching?": end function
function CopyLogout() as string: return "Logout": end function
function CopyLoggingOut() as string: return "Logging out...": end function

' Confirm (logout) popup
function CopyLogoutTitle() as string: return "Log Out": end function
function CopyLogoutPrompt() as string: return "Are you sure you want to Logout?": end function
function CopyCancel() as string: return "Cancel": end function
function CopyLogoutConfirm() as string: return "Log Out": end function
function CopyLoggingOutBtn() as string: return "Logging Out": end function

' OTP / parental-lock popup
function CopyParentalLock() as string: return "Parental Lock": end function
function CopyUseThisPin() as string: return "Use this 6 digit PIN to access all adult profiles": end function
function CopyContinue() as string: return "Continue": end function
function CopyEnterPinHint() as string: return "Enter PIN to access": end function

function CopyAutoSelectingIn(secs as integer) as string
    if secs < 0 then secs = 0
    return "Auto-selecting in " + secs.ToStr() + "s"
end function

function CopyWelcomeBack(name as string) as string
    if name = invalid or name = "" then return "Welcome back"
    return "Welcome back, " + name
end function

' Ordered welcome-overlay status copy — advance forward only, never repeat.
function CopyWelcomeStatusPhases() as object
    return [
        "Setting up your profile...",
        "Preparing your home...",
        "Curating your watchlist...",
        "Almost there..."
    ]
end function

function CopySelectingStatusMessages() as object
    return CopyWelcomeStatusPhases()
end function

' Toast / inline messages (parity with messages.ts)
function MsgFailedSelectProfile() as string: return "Failed to select profile. Please try again.": end function
function MsgFailedSelectAfterPin() as string: return "Failed to select profile after PIN verification.": end function
function MsgInvalidPin() as string: return "Invalid PIN. Please try again.": end function
function MsgLoggedOut() as string: return "Logged out successfully": end function
function MsgFailedLoadProfiles() as string: return "Failed to load profiles. Please try again.": end function
