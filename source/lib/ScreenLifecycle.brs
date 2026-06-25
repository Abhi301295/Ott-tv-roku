' ScreenLifecycle.brs — pause/destroy contract for route screens (ViewManager).
' Covered or replaced screens must stop timers, HTTP listeners, and Video nodes before
' the next screen (especially VideoPlayer) mounts.

' Push: screen stays on stack but is out of scope — visible=false triggers each
' screen's visible observer (Home hero, Reels inline video, etc.).
sub ScreenPause(screen as object)
    if screen = invalid then return
    if screen.hasField("visible") then screen.visible = false
end sub

' Replace / pop: full teardown before removeChild. Order is pause → dispose so
' OnDispose runs after visible handlers have stopped media.
sub ScreenDestroy(screen as object)
    if screen = invalid then return
    ScreenPause(screen)
    if screen.hasField("dispose") then screen.dispose = true
end sub
