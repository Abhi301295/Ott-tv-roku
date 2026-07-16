' ProfileAutoSelect.brs — countdown auto-select for the profile picker.


' ── Auto-select (15s on focus, non-locked) ───────────────────────────────────

' Re-arm the countdown for the currently focused profile, starting a fresh 15.5s
' window. Called on every navigation, so any focus change restarts timing from zero.
sub ResetAutoSelect()
    StopAutoSelect()

    if not ProfileAutoLoginEnabled() then return
    if not m.profilesLoaded then return   ' do not start the loop before profiles load
    if m.focusArea <> "profiles" then return
    if m.profiles = invalid or m.profiles.Count() = 0 then return
    if m.profileIndex < 0 or m.profileIndex >= m.profiles.Count() then return
    if ProfileNeedsPin(m.profiles[m.profileIndex]) then return   ' locked profiles never auto-select

    m.autoArmedIndex = m.profileIndex
    if m.autoClock <> invalid then m.autoStartMs = m.autoClock.TotalMilliseconds()
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "start"
end sub

' Disarm and stop the countdown; clear arc chrome so it cannot linger on edit focus.
sub StopAutoSelect()
    m.autoArmedIndex = -1
    if m.autoSelectTimer <> invalid then m.autoSelectTimer.control = "stop"
    if m.avatars = invalid then return
    for i = 0 to m.avatars.Count() - 1
        av = m.avatars[i]
        if av = invalid then continue for
        if av.hasField("progress") then av.progress = 0.0
    end for
end sub

' Wall-time elapsed (ms) since the current window started; 0 when idle.
function AutoElapsedMs() as integer
    if m.autoArmedIndex < 0 or m.autoClock = invalid then return 0
    elapsed = m.autoClock.TotalMilliseconds() - m.autoStartMs
    if elapsed < 0 then elapsed = 0
    return elapsed
end function

' Ring fill fraction (0.0–1.0) for the profile at index i; reaches 1.0 at AUTO_TOTAL_MS.
function AutoProgressFor(i as integer) as float
    if m.autoArmedIndex <> i then return 0.0
    frac = AutoElapsedMs() / m.AUTO_TOTAL_MS
    if frac > 1.0 then frac = 1.0
    return frac
end function

' True if this ProfileScreen is not the top screen in the ViewManager stack.
function IsOrphaned() as boolean
    if m.vm = invalid then return false
    host = m.vm.findNode("screenHost")
    if host = invalid then return false
    count = host.getChildCount()
    if count < 1 then return false
    active = host.getChild(count - 1)
    if active = invalid then return false
    return not active.isSameNode(m.top)
end function


' Push countdown copy onto the focused row when the second ticks down.
sub RefreshAutoSelectHint(index as integer)
    if m.focusArea <> "profiles" then return
    if index < 0 or m.avatars = invalid or index >= m.avatars.Count() then return
    if m.autoArmedIndex <> index then return
    av = m.avatars[index]
    if av = invalid then return
    hint = FocusHint(index)
    if av.hintText = hint then return
    av.hintText = hint
    ApplyProfileHintStyle(av, index, hint)
end sub


sub OnAutoTick()
    if m.autoArmedIndex < 0 then return              ' not armed — nothing to do
    if not m.profilesLoaded then return

    ' Only the active (top-of-stack) screen runs the countdown; a backgrounded
    ' instance stops so it cannot auto-navigate.
    if IsOrphaned() then
        StopAutoSelect()
        return
    end if

    ' Pause (but keep timing) while an overlay/selection/logout is in progress.
    if m.popup <> "" or m.selecting or m.loggingOut then return
    if m.focusArea <> "profiles" then return
    if m.profiles = invalid or m.profiles.Count() = 0 then return

    ' Focus drifted from the armed profile without a reset — re-arm for the new one.
    if m.profileIndex <> m.autoArmedIndex then
        ResetAutoSelect()
        ApplyProfileFocus()
        return
    end if

    p = m.profiles[m.profileIndex]
    if ProfileNeedsPin(p) then return

    ' Drive the ring from real elapsed wall-time, then select once the window completes.
    if m.avatars <> invalid and m.avatars.Count() > m.profileIndex then
        m.avatars[m.profileIndex].progress = AutoProgressFor(m.profileIndex)
        RefreshAutoSelectHint(m.profileIndex)
    end if

    if AutoElapsedMs() >= m.AUTO_SELECT_MS then
        StopAutoSelect()
        SelectProfile(p)
    end if
end sub
