' Alert.brs — global toast trigger (parity with showAlert + react-toastify).
' type 1 = info/success, type 2 = error (matches web showAlert signature).

sub ShowAlert(fromNode as object, alertType as integer, message as string)
    if fromNode = invalid or message = invalid or message = "" then return
    scene = fromNode.getScene()
    if scene = invalid then return
    if not scene.hasField("alertMessage") then return
    scene.alertType = alertType
    scene.alertMessage = message
end sub
