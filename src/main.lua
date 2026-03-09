--[[
DesynCC Library
Copyright 2026 Afonya

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local class = require("desyncc.class")

local task, taskClass = class()
task.lastId = 0
task.lastTime = 0

--- Creates a new task
--- @param func function The function to execute
--- @return table
function task:new(func)
    local cls = self:super()
    local time = os.epoch("utc")
    if self.lastTime ~= time then
        self.lastId = 0
        self.lastTime = time
    end
    cls.id = tostring(time) .. "#" .. tostring(self.lastId+1)
    self.lastId = self.lastId + 1
    cls.coroutine = coroutine.create(func)
    -- Defines if the task is waiting for a promise/other task/event/time
    cls.waitingFor = {
        is = false,
        typ = nil,
        id = nil
    }
    cls.eventQueue = {}
    cls.returned = {
        is = false,
        values = {}
    }
    cls.isRunning = false
    cls:queueEvent({ "desyncc_task_start" })
    return cls
end

--- Returns what the task is waiting for
--- @return table|nil
function taskClass:getWaiting()
    if self.waitingFor.is then
        return self.waitingFor
    end
end

--- Returns the ID of the task
---@return string
function taskClass:getId()
    return self.id
end

--- Sets the task to wait for another task
--- @param id string The ID of the task to wait for
function taskClass:waitForTask(id)
    self.waitingFor = {
        is = true,
        typ = "task",
        id = id
    }
end

--- Sets the task to wait for a promise
--- @param id string The ID of the promise to wait for
function taskClass:waitForPromise(id)
    self.waitingFor = {
        is = true,
        typ = "promise",
        id = id
    }
end

--- Sets the task to wait for an event
--- @param id string The name of the event to wait for
function taskClass:waitForEvent(id)
    self.waitingFor = {
        is = true,
        typ = "event",
        id = id
    }
end

--- Sets the task to wait until a given timestamp
--- @param timestamp number The timestamp to wait until in milliseconds since the unix epoch
function taskClass:waitForTime(timestamp)
    self.waitingFor = {
        is = true,
        typ = "time",
        id = tostring(timestamp)
    }
end

--- Clears the wait state of the task
function taskClass:clearWait()
    self.waitingFor = {
        is = false,
        typ = nil,
        id = nil
    }
end

--- Adds an event to the event queue of the task
--- @param event table
function taskClass:queueEvent(event)
    table.insert(self.eventQueue, event)
end

--- Returns whatever the task function returned.
---@return ... The returned values of the task function or nil if the task hasn't returned yet
function taskClass:getReturned()
    if self.returned.is then
        return table.unpack(self.returned.values)
    end
end

--- Returns the status of the task coroutine
--- @return string
function taskClass:getStatus()
    return coroutine.status(self.coroutine)
end

--- Sets the returned values of the task function
---@param values table
function taskClass:setReturned(values)
    self.returned.is = true
    self.returned.values = values
end

--- Gets the next event from the event queue of the task
--- @param noCheckWait boolean Whether to ignore the wait state of the task or not
--- @return table|nil
function taskClass:getNextEvent(noCheckWait)
    local wait = self:getWaiting()
    if noCheckWait or not wait then
        return table.remove(self.eventQueue, 1)
    end
    while #self.eventQueue > 0 do
        local v = self.eventQueue[1]
        if wait.typ == "task" then
            if v[1] == "desyncc_task_finished" then
                return table.remove(self.eventQueue, 1)
            end
        elseif wait.typ == "promise" then
            if (v[1] == "desyncc_promise_rejected") or (v[1] == "desyncc_promise_resolved") then
                return table.remove(self.eventQueue, 1)
            end
        elseif wait.typ == "event" then
            if v[1] == wait.id then
                return table.remove(self.eventQueue, 1)
            end
        elseif wait.typ == "time" then
            if v[1] == "desyncc_time_reached" then
                return table.remove(self.eventQueue, 1)
            end
        end
        table.remove(self.eventQueue, 1)
    end
end

--- Clears the event queue of the task
function taskClass:clearEventQueue()
    self.eventQueue = {}
end

local promise, promiseClass = class()
promise.lastId = 0
promise.lastTime = 0

--- Creates a new promise
--- @param func function The function to execute to resolve the promise. function(resolve, reject) end
--- @return table
function promise:new(func)
    local cls = self:super()
    local time = os.epoch("utc")
    if self.lastTime ~= time then
        self.lastId = 0
        self.lastTime = time
    end
    cls.id = tostring(time) .. "#" .. tostring(self.lastId+1)
    self.lastId = self.lastId + 1
    cls.func = func
    cls.taskId = nil
    cls.resolved = {
        is = false,
        values = {}
    }
    cls.rejected = {
        is = false,
        values = {}
    }
    -- Event handlers for the promise
    cls.afters = {}
    cls.catches = {}
    return cls
end

--- Resolves the promise
--- @param ... any
function promiseClass:resolve(...)
    if self.resolved.is then
        error("Promise is already resolved")
    end
    if self.rejected.is then
        error("Promise is already rejected")
    end
    self.resolved.is = true
    self.resolved.values = {...}
    for k, v in ipairs(self.afters) do
        v(...)
    end
end

--- Rejects the promise
--- @param ... any
function promiseClass:reject(...)
    if self.resolved.is then
        error("Promise is already resolved")
    end
    if self.rejected.is then
        error("Promise is already rejected")
    end
    self.rejected.is = true
    self.rejected.values = {...}
    if #self.catches < 1 then
        error("Uncaught promise reject: "..textutils.serialise({...}))
    end
    for k, v in ipairs(self.catches) do
        v(...)
    end
end

--- Creates a task for the promise
--- @return table The task for the promise
function promiseClass:getTask()
    if self.taskId ~= nil then
        error("Promise already has a task")
    end
    local tsk = task:new(function ()
        local function res(...)
            self:resolve(...)
        end
        local function rej(...)
            self:reject(...)
        end
        local ok, err = pcall(self.func, res, rej)
        if (not ok) and (not (self.resolved.is or self.rejected.is)) then
            self:reject(err)
        elseif not ok then
            error(err)
        end
    end)
    self.taskId = tsk.id
    return tsk
end

--- Returns the ID of the task of the promise
--- @return string|nil The ID of the task, or nil if the task hasn't been created yet
function promiseClass:getTaskId()
    return self.taskId
end

--- Returns whether the promise resolved/rejected
--- @return string|nil
--- @return ...
function promiseClass:getOutcome()
    if self.resolved.is then
        return "resolved", table.unpack(self.resolved.values)
    elseif self.rejected.is then
        return "rejected", table.unpack(self.rejected.values)
    end
end

--- Returns the ID of the promise
--- @return string
function promiseClass:getId()
    return self.id
end

--- Registers an event handler that fires when the promise resolves
--- @param func function The function to execute when the promise resolves. function(...) end
function promiseClass:after(func)
    table.insert(self.afters, func)
end

--- Registers an event handler that fires when the promise rejects
--- @param func function The function to execute when the promise rejects. function(...) end
function promiseClass:catch(func)
    table.insert(self.catches, func)
end

local desyncc, desynccClass = class()
desyncc.version = "1.0.0"

--- Creates a new desyncc instance.
--- @return table
function desyncc:new()
    local cls = self:super()
    cls.tasks = {}
    cls.promises = {}
    cls.events = {}
    return cls
end

--- Returns the version of DesynCC
--- @return string
function desyncc:getVersion()
    return self.version
end

--- Creates a new promise
--- @param func function The function to execute to resolve the promise. function(resolve, reject) end
--- @return table The promise controller
function desynccClass:promise(func)
    local prom = promise:new(func)
    table.insert(self.promises, prom)
    table.insert(self.tasks, prom:getTask())
    return {
        after = function (...)
            prom:after(...)
        end,
        catch = function (...)
            prom:catch(...)
        end,
        await = function ()
            self:getRunningTask():waitForPromise(prom:getId())
            while true do
                local data = { coroutine.yield() }
                if data[1] == "desyncc_promise_resolved" then
                    return table.unpack(data, 2)
                elseif data[1] == "desyncc_promise_rejected" then
                    error("Promise rejected: " .. table.concat(data, ", ", 2))
                end
            end
        end,
        result = function ()
            return prom:getOutcome()
        end,
        status = function ()
            local tsk = self:getTask(prom:getTaskId())
            if tsk ~= nil then
                return tsk:getStatus()
            end
        end,
        id = function ()
            return prom:getId(), prom:getTaskId()
        end
    }
end

--- Creates a simple async function
--- @param func function The function to execute. function() end
--- @return function The promise controller
function desynccClass:async(func)
    return function (...)
        local args = { ... }
        return self:promise(function (res, rej)
            local resp = { pcall(func, table.unpack(args)) }
            if resp[1] then
                res(table.unpack(resp, 2))
            else
                rej(table.unpack(resp, 2))
            end
        end)
    end
end

--- Creates a task
--- @param func function The function to execute in the task. function() end
--- @return table The promise controller
function desynccClass:task(func)
    return self:async(func)()
end

--- Schedules func to run after the timeout
---@param func function The function to run when the timeout is reached
---@param timeout number The timeout in miliseconds
--- @return table The timeout object
function desynccClass:timeout(func, timeout)
    return self:task(function ()
        local time = os.epoch("utc") + timeout
        self:getRunningTask():waitForTime(time)
        while true do
            local data = { coroutine.yield() }
            if data[1] == "desyncc_time_reached" then
                break
            end
        end
        func()
    end)
end

--- Schedules func to run periodically with the given interval
---@param func function The function to run periodically with the given interval
---@param interval number The interval in miliseconds
--- @return table The interval object
function desynccClass:interval(func, interval)
    local removed = false
    local tsk = self:task(function ()
        while true do
            local time = os.epoch("utc") + interval
            self:getRunningTask():waitForTime(time)
            while true do
                local data = { coroutine.yield() }
                if data[1] == "desyncc_time_reached" then
                    break
                end
            end
            if removed then
                break
            end
            func()
        end
    end)
    tsk.remove = function ()
        removed = true
    end
    return tsk
end

--- Creates an event listener
--- @param event string The event
--- @param callback function The callback function to execute when the event is fired. function(...) end
function desynccClass:on(event, callback)
    if self.events[event] == nil then
        self.events[event] = {}
    end
    table.insert(self.events[event], {
        callback = callback,
        once = false
    })
end

--- Creates an event listener that fires only once
--- @param event string The event
--- @param callback function The callback function to execute when the event is fired. function(...) end
function desynccClass:once(event, callback)
    if self.events[event] == nil then
        self.events[event] = {}
    end
    table.insert(self.events[event], {
        callback = callback,
        once = true
    })
end

--- Removes an event listener
--- @param event string The event
--- @param callback function The callback function
function desynccClass:off(event, callback)
    if self.events[event] == nil then
        return
    end
    for k, v in ipairs(self.events[event]) do
        if v.callback == callback then
            table.remove(self.events[event], k)
            break
        end
    end
end

--- Fires the callback functions for the event in new tasks
--- @param event string The event
--- @param ... unknown The arguments to pass to the callback functions
function desynccClass:call(event, ...)
    if self.events[event] == nil then
        return
    end
    for k, v in ipairs(self.events[event]) do
        local tsk = task:new(v.callback)
        tsk:clearEventQueue()
        tsk:queueEvent({ ... })
        table.insert(self.tasks, tsk)
        if v.once then
            table.remove(self.events[event], k)
        end
    end
end

--- Finds a task with ID id
--- @param id string|nil The ID of the task, or nil to find the main task
--- @return table|nil
function desynccClass:getTask(id)
    if id == nil then
        return self.tasks[1]
    end
    for k, v in ipairs(self.tasks) do
        if v:getId() == id then
            return v
        end
    end
end

--- Finds a promise with ID id
--- @param id string The ID of the promise
--- @return table|nil
function desynccClass:getPromise(id)
    for k, v in ipairs(self.promises) do
        if v:getId() == id then
            return v
        end
    end
end

--- Returns the currently running task. Or the main task if there is no running task. Or nil if there are no tasks at all.
--- @return table|nil
function desynccClass:getRunningTask()
    for k, v in ipairs(self.tasks) do
        if v.isRunning then
            return v
        end
    end
    return self.tasks[1]
end

--- Resumes a task
--- @param id string The ID of the task to resume
--- @return boolean Whether the main task died or not
function desynccClass:resumeTask(id)
    for k, v in ipairs(self.tasks) do
        if v:getId() == id then
            if v:getStatus() == "suspended" then
                local event = v:getNextEvent(false)
                if event ~= nil then
                    --[[print("Events for task",k)
                    for k,v in ipairs(v.eventQueue) do
                        print(textutils.serialise(v))
                    end
                    print("------------------")
                    print("Executing event", event[1], "for task",k)]]
                    v:clearWait()
                    v.isRunning = true
                    local res = { coroutine.resume(v.coroutine, table.unpack(event)) }
                    v.isRunning = false
                    if not res[1] then
                        error("Error in task " .. v.id .. ": " .. res[2])
                    end
                    --print("Task",k,"returned with",err)
                    if coroutine.status(v.coroutine) == "dead" then
                        --print("Task",k,v:getId(),"finished")
                        v:setReturned({ table.unpack(res, 2) })
                        if k == 1 then
                            return true
                        end
                    else
                        if res[2] then
                            v:waitForEvent(res[2])
                        end
                    end
                end
            end
            break
        end
    end
    return false
end

--- Starts the main loop
--- @param func function The main function to execute
function desynccClass:start(func)
    local mainTask = task:new(func)
    table.insert(self.tasks, mainTask)
    while #self.tasks > 0 do
        os.queueEvent("desyncc_tick")
        local event = { os.pullEventRaw() }
        if event[1] ~= "desyncc_tick" then
            --print("Got event: ", event[1])
            self:call(table.unpack(event))
        end
        if event[1] == "terminate" then
            print("DesynCC: Terminating...")
            break
        end
        for k, v in ipairs(self.tasks) do
            if v:getStatus() == "suspended" then
                local wait = v:getWaiting()
                if wait == nil then
                    if event[1] ~= "desyncc_tick" then
                        --print("Queuing for task: ", k)
                        v:queueEvent(event)
                    end
                else
                    if event[1] ~= "desyncc_tick" then
                        --print("Task",k,"is waiting for",textutils.serialise(wait))
                    end
                    if wait.typ == "task" then
                        if self:getTask(wait.id):getStatus() == "dead" then
                            local ret = { self:getTask(wait.id):getReturned() }
                            v:queueEvent({ "desyncc_task_finished", table.unpack(ret) })
                            if event[1] ~= "desyncc_tick" then
                                --print("Queuing for task (waiting for task): ", k)
                                v:queueEvent(event)
                            end
                        end
                    elseif wait.typ == "promise" then
                        local outcome = { self:getPromise(wait.id):getOutcome() }
                        if outcome[1] ~= nil then
                            outcome[1] = "desyncc_promise_" .. outcome[1]
                            v:queueEvent(outcome)
                            if event[1] ~= "desyncc_tick" then
                                --print("Queuing for task (waiting for promise): ", k)
                                v:queueEvent(event)
                            end
                        end
                    elseif wait.typ == "event" then
                        if event[1] == wait.id then
                            if event[1] ~= "desyncc_tick" then
                                --print("Queuing for task (waiting for event): ", k)
                                v:queueEvent(event)
                            end
                        end
                    elseif wait.typ == "time" then
                        local time = os.epoch("utc")
                        --print("Task",k,"waiting until",wait.id,"time is",time)
                        if time >= tonumber(wait.id) then
                            v:queueEvent({ "desyncc_time_reached" })
                            if event[1] ~= "desyncc_tick" then
                                --print("Queuing for task (waiting for time): ", k)
                                v:queueEvent(event)
                            end
                        end
                    end
                end
                local die = self:resumeTask(v:getId())
                if die then
                    error("Main task died")
                end
            end
        end
    end
end

return desyncc