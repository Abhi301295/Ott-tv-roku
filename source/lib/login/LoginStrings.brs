' LoginStrings.brs — user-facing login strings (parity with login.enum.ts + index.tsx).
' Centralized here so copy lives in one place (and is ready for future localization).

function CopyLoginTitle() as string: return "Choose how to Sign In": end function
function CopyUsePhone() as string: return "Use Phone": end function
function CopyUseRemote() as string: return "Use Remote": end function
function CopyStep1() as string
    ' Two lines — parity with index.tsx <br /> split
    return "Use your phone or tablet's camera and" + Chr(10) + "point to this code, or go to accelerator.com/tv1"
end function
function CopyStep2() as string: return "Confirm this code on your phone or tablet": end function
function CopyOr() as string: return "or": end function
function CopyLoginBtn() as string: return "Login": end function
function CopyEmailHint() as string: return "Email": end function
function CopyPasswordHint() as string: return "Password": end function
function CopyQrLoadFailed() as string: return "Failed to load QR code. Retrying...": end function
function CopyAuthTimeout() as string: return "Authentication timed out. Please try again.": end function
function CopyFormInvalid() as string: return "Please enter a valid email and password": end function
function CopyLoginFailed() as string: return "Login failed. Please try again.": end function
function CopyInvalidCredentials() as string: return "Invalid email or password": end function
function MsgDeviceLimitExceeded() as string: return "Device limit exceeded.": end function
