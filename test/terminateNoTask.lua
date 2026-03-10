--[[
DesynCC Test - Taskless promise termination
Copyright 2026 Afonya

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

package.path = "/?.lua;/?/init.lua;" .. package.path
print("--------------")
print("This test should create a promise that resolves when an event is called. However the promise gets terminated before the event is called. It should result in an error because the promise is already rejected.")
print("--------------")
local desyncc = require("desyncc.main")

local sys = desyncc:new()

local function testPromise()
    return sys:promise(function (resolve, reject)
        sys:once("test", function ()
            resolve("Hello, world!")
        end)
    end)
end

local function main()
    local prom = testPromise()
    sys:getRunningTask():waitForTime(os.epoch("utc") + 1000)
    coroutine.yield()
    prom.terminate()
    sys:call("test")
    sys:getRunningTask():waitForTime(os.epoch("utc") + 1000)
    coroutine.yield()
end

sys:start(main)