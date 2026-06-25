' TelemetryClient.brs
' App-wide telemetry queue (parity with HttpClient). One worker, FIFO, no render-thread blocking.

sub init()
    m.queue = []
    m.maxQueue = 64

    m.worker = CreateObject("roSGNode", "TelemetryWorker")
    m.worker.id = "telemetryWorker"
    m.top.appendChild(m.worker)
    m.worker.observeField("completed", "OnWorkerCompleted")
    m.worker.control = "RUN"

    if m.global <> invalid then
        if not m.global.hasField("telemetryClient") then
            m.global.addFields({ telemetryClient: m.top })
        else
            m.global.telemetryClient = m.top
        end if
    end if
end sub

function Submit(job as object) as void
    if job = invalid then return
    if m.queue.Count() >= m.maxQueue then
        dropped = m.queue.Shift()
        droppedName = ""
        if dropped <> invalid and dropped.payload <> invalid and dropped.payload.event_name <> invalid then
            droppedName = dropped.payload.event_name
        end if
        print "[TELEMETRY_DBG] queue full — dropped oldest event="; droppedName
    end if
    m.queue.Push(job)
    Pump()
end function

sub OnWorkerCompleted()
    Pump()
end sub

sub Pump()
    if m.queue.Count() = 0 then return
    if m.worker = invalid then return
    if m.worker.available <> true then return

    job = m.queue.Shift()
    m.worker.available = false
    m.worker.job = job
end sub
