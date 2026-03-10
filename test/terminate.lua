--[[
DesynCC Test - Promise terminate test
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
print("This test should start an async function, print 'start' then it should terminate the function and keep the main thread alive for ~10 seconds. It shouldn't print 'Hello, world!'")
print("--------------")
local desyncc = require("desyncc.main")

local sys = desyncc:new()

local testAsync = sys:async(function ()
    os.sleep(5)
    print("Hello, world!")
end)

local function main()
    local as = testAsync()
    print("start")
    as.terminate()
    local endTime = os.epoch("utc") + 10000
    while true do
        if os.epoch("utc") > endTime then
            break
        end
        os.sleep(0)
    end
end

sys:start(main)