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

    screen.Show()

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.IsScreenClosed() then return
        end if
    end while
end sub
