' Entry point for the OTT Accelerator Roku channel.

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    if scene = invalid then
        print "ERROR: MainScene failed to load — check component XML/scripts in debug console"
        return
    end if

    if args <> invalid then
        scene.launchArgs = args
    end if

    ' Exit the channel cleanly when the scene requests it (Back on Home). The render
    ' thread cannot close roSGScreen directly, so it flips exitChannel and we close here.
    scene.observeField("exitChannel", m.port)

    screen.Show()

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.IsScreenClosed() then return
        else if msgType = "roSGNodeEvent" then
            if msg.GetField() = "exitChannel" and msg.GetData() = true then
                screen.Close()
                return
            end if
        end if
    end while
end sub
