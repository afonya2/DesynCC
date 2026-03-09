--[[
DesynCC Test - Async await test
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
print("This test should print 'nil', then 'Before the function is awaited', then 'suspended', then it should wait for ~5 seconds. After that it should print 'a b', then 'After the function is awaited', then 'a b'")
print("--------------")
local desyncc = require("desyncc.main")

local sys = desyncc:new()

local testAsync = sys:async(function (a,b)
    os.sleep(5)
    print(a,b)
    return "a", "b"
end)

local function main()
    local as = testAsync("Hello,", "world!")
    print(textutils.serialise(as.result()))
    print("Before the function is awaited")
    print(as.status())
    print(as.await())
    print("After the function is awaited")
    print(as.result())
end

sys:start(main)