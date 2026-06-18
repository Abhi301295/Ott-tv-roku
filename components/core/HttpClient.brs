' HttpClient.brs
' App-wide HTTP dispatcher. Owns a small pool of persistent keep-alive workers and
' a FIFO queue. ApiClient.StartHttpTask() hands requests here via callFunc("Submit").
' Registers itself on m.global so every screen reaches the same warm pool.

sub init()
    m.poolSize = 3
    m.workers = []
    m.queue = []

    for i = 0 to m.poolSize - 1
        w = CreateObject("roSGNode", "HttpWorker")
        w.id = "hw" + Str(i).Trim()
        m.top.appendChild(w)
        w.observeField("completed", "OnWorkerCompleted")
        w.control = "RUN"
        m.workers.Push(w)
    end for

    if m.global <> invalid and m.global.httpClient = invalid then
        m.global.addFields({ httpClient: m.top })
    end if
end sub

' Public (callFunc): queue a request handle (HttpRequest node) for dispatch.
function Submit(req as object) as void
    if req = invalid then return
    m.queue.Push(req)
    Pump()
end function

' Public (callFunc): open/refresh a keep-alive connection on every worker by firing
' one cheap GET each. Results are intentionally ignored. Call this while there is
' idle time (e.g. on the profile screen) so the next screen's requests are warm.
function WarmAll(path as string) as void
    if path = invalid or path = "" then return
    for i = 0 to m.workers.Count() - 1
        r = CreateObject("roSGNode", "HttpRequest")
        r.method = "GET"
        r.path = path
        m.queue.Push(r)
    end for
    Pump()
end function

' Drop every job still waiting for a worker (in-flight requests are left alone).
function ClearQueue(dummy = invalid as dynamic) as integer
    dropped = m.queue.Count()
    if dropped > 0 then
        print "[HTTP] queue cleared, dropped="; dropped
        m.queue = []
    end if
    return dropped
end function

sub OnWorkerCompleted()
    Pump()
end sub

sub Pump()
    if m.queue.Count() = 0 then return
    for each w in m.workers
        if m.queue.Count() = 0 then exit for
        if w.available = true then
            req = m.queue.Shift()
            ' Mark busy before handing off so a concurrent Pump can't double-assign.
            w.available = false
            w.job = req
        end if
    end for
end sub
