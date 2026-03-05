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
    return cls
end

--- Returns what the task is waiting for
---@return table|nil
function task:getWaiting()
    if self.waitingFor.is then
        return self.waitingFor
    end
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
    cls.resolved = {
        is = false,
        values = {}
    }
    cls.rejected = {
        is = false,
        values = {}
    }
    return cls
end

--- Resolves the promise
---@param ... any
function promiseClass:resolve(...)
    self.resolved.is = true
    self.resolved.values = {...}
end

--- Rejects the promise
---@param ... any
function promiseClass:reject(...)
    self.rejected.is = true
    self.rejected.values = {...}
end

--- Creates a task for the promise
--- @return table The task for the promise
function promiseClass:getTask()
    local tsk = task:new(function ()
        self.func(self.resolve, self.reject)
    end)
    return tsk
end

--- Returns whether the promise resolved/rejected
---@return string|nil
---@return ...
function promiseClass:getOutcome()
    if self.resolved.is then
        return "resolved", table.unpack(self.resolved.values)
    elseif self.rejected.is then
        return "rejected", table.unpack(self.rejected.values)
    end
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
    return {}
end

--- Creates a simple async function
--- @param func function The function to execute. function() end
--- @return table The async function
function desynccClass:async(func)
    return {}
end

--- Starts the main loop
--- @param func function The main function to execute
function desynccClass:start(func)
    local mainTask = task:new(func)
    table.insert(self.tasks, mainTask)
    while #self.tasks > 0 do
        local currentTask = self.tasks[1]
        if currentTask:getWaiting() == nil then
            local success, err = coroutine.resume(currentTask.coroutine)
            if not success then
                print("Error in task " .. currentTask.id .. ": " .. err)
            end
            table.remove(self.tasks, 1)
            table.insert(self.tasks, currentTask)
        end
        os.queueEvent("desyncc_tick")
        os.pullEventRaw()
    end
end

return desyncc