' Entry point for the OTT Accelerator Roku channel.
' This is a scaffold; the full SceneGraph implementation follows the
' phased plan in ROKU_IMPLEMENTATION_PLAN.md.

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Pass deep link / launch args to the scene for later routing.
    if args <> invalid then
        scene.setField("launchArgs", args)
    end if

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then return
        end if
    end while
end sub
