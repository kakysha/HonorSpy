local isPaused = 0

local work = {}
-- structure: [1] = {["func"] = function, ["args"] = {arg1, arg2, ...}}, [2] = ...

C_Timer.NewTicker(0.1, function()
    if isPaused > 0 then return end
    if #work < 1 then return end

    local currentWork = table.remove(work, 1)
    currentWork.func(unpack(currentWork.args))
end)

function HonorSpy:pauseWorker()
    isPaused = isPaused + 1
end

function HonorSpy:unpauseWorker()
    isPaused = isPaused - 1
end

function HonorSpy:isWorkerPaused()
    return isPaused > 0
end

function HonorSpy:addWork(func, ...)
    table.insert(work, {["func"] = func, ["args"] = {...}})
end

function HonorSpy:clearWork()
    wipe(work)
end
