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
    -- Defines if the task is waiting for a promise/other task/event
    cls.waitingFor = {
        is = false,
        typ = nil,
        id = nil
    }
    cls.eventQueue = {}
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

--- Sets the event to wait for an event
--- @param id string The name of the event to wait for
function taskClass:waitForEvent(id)
    self.waitingFor = {
        is = true,
        typ = "event",
        id = id
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

--- Adds an event to the event queue for the task
--- @param event table
function taskClass:queueEvent(event)
    table.insert(self.eventQueue, event)
end

--- Gets the next event from the event queue for the task
--- @return table
function taskClass:getNextEvent()
    return table.remove(self.eventQueue, 1)
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
    self.resolved.is = true
    self.resolved.values = {...}
    for k, v in ipairs(self.afters) do
        v(...)
    end
end

--- Rejects the promise
--- @param ... any
function promiseClass:reject(...)
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
        if not ok then
            self:reject(err)
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

--- Creates a new desyncc instance.
--- @return table
function desyncc:new()
    local cls = self:super()
    cls.tasks = {}
    cls.promises = {}
    return cls
end

--- Creates a new promise
--- @param func function The function to execute to resolve the promise. function(resolve, reject) end
--- @return table The async function
function desynccClass:promise(func)
    local prom = promise:new(func)
    table.insert(self.promises, prom)
    table.insert(self.tasks, prom:getTask())
    return {
        after = prom.after,
        catch = prom.catch,
        await = function ()
            self.tasks[1]:waitForPromise(prom:getId())
            local data = { coroutine.yield() }
            return table.unpack(data)
        end
    }
end

--- Creates a simple async function
--- @param func function The function to execute. function() end
--- @return table The async function
function desynccClass:async(func)
    return {}
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

--- Resumes a task
--- @param id string The ID of the task to resume
--- @return boolean Whether the main task died or not
function desynccClass:resumeTask(id)
    for k, v in ipairs(self.tasks) do
        if v:getId() == id then
            local event = v:getNextEvent()
            if event ~= nil then
                local success, err = coroutine.resume(v.coroutine, table.unpack(event))
                if not success then
                    error("Error in task " .. v.id .. ": " .. err)
                end
                if coroutine.status(v.coroutine) == "dead" then
                    table.remove(self.tasks, k)
                    if k == 1 then
                        return true
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
        if event[1] == "terminate" then
            print("DesynCC: Terminating...")
            break
        end
        for k, v in ipairs(self.tasks) do
            local wait = v:getWaiting()
            if wait == nil then
                if event[1] ~= "desyncc_tick" then
                    v:queueEvent(event)
                end
                local die = self:resumeTask(v:getId())
                if die then
                    error("Main task died")
                end
            else
                if wait.typ == "task" then
                    if self:getTask(wait.id) == nil then
                        if event[1] ~= "desyncc_tick" then
                            v:queueEvent(event)
                        end
                        v:clearWait()
                        local die = self:resumeTask(v:getId())
                        if die then
                            error("Main task died")
                        end
                    end
                elseif wait.typ == "promise" then
                    local outcome = self:getPromise(wait.id):getOutcome()
                    if outcome ~= nil then
                        v:queueEvent({outcome})
                        if event[1] ~= "desyncc_tick" then
                            v:queueEvent(event)
                        end
                        v:clearWait()
                        local die = self:resumeTask(v:getId())
                        if die then
                            error("Main task died")
                        end
                    end
                elseif wait.typ == "event" then
                    if event[1] == wait.id then
                        if event[1] ~= "desyncc_tick" then
                            v:queueEvent(event)
                        end
                        v:clearWait()
                        local die = self:resumeTask(v:getId())
                        if die then
                            error("Main task died")
                        end
                    end
                end
            end
        end
    end
end

return desyncc