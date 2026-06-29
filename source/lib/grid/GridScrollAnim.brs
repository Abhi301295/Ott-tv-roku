' GridScrollAnim.brs — shared Vector2D translation animations for grid row hosts.

sub GridAnimateTranslation(node as object, from as object, target as object, anim as object, interp as object, stopIfRunning as boolean, fieldToInterp as string)
    if node = invalid then return
    if from = invalid or target = invalid then return
    if from[0] = target[0] and from[1] = target[1] then return
    if anim = invalid or interp = invalid then
        node.translation = target
        return
    end if
    if stopIfRunning and anim.state = "running" then anim.control = "stop"
    if fieldToInterp <> "" then interp.fieldToInterp = fieldToInterp
    interp.keyValue = [from, target]
    anim.control = "start"
end sub
