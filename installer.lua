--[[
DesynCC Installer
Copyright 2026 Afonya

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- The repository to download from
local repo = "afonya2/DesynCC"
-- The branch to download from
local branch = "main"
-- The files to download + features
local files = {
    ["base"] = {
        ["src/main.lua"] = "desyncc/main.lua",
        ["src/class.lua"] = "desyncc/class.lua",
    },
    ["test"] = {
        ["test/runTests.lua"] = "desyncc/test/runTests.lua",
        ["test/asyncAwait.lua"] = "desyncc/test/asyncAwait.lua",
        ["test/interval.lua"] = "desyncc/test/interval.lua",
        ["test/timeout.lua"] = "desyncc/test/timeout.lua",
        ["test/promiseAfter.lua"] = "desyncc/test/promiseAfter.lua",
        ["test/promiseAwait.lua"] = "desyncc/test/promiseAwait.lua",
        ["test/promiseCatch.lua"] = "desyncc/test/promiseCatch.lua",
        ["test/promiseCrash.lua"] = "desyncc/test/promiseCrash.lua",
        ["test/promisePoll.lua"] = "desyncc/test/promisePoll.lua",
        ["test/event.lua"] = "desyncc/test/event.lua",
        ["test/eventOnce.lua"] = "desyncc/test/eventOnce.lua",
        ["test/terminate.lua"] = "desyncc/test/terminate.lua",
        ["test/terminateAwait.lua"] = "desyncc/test/terminateAwait.lua",
        ["test/terminateNoTask.lua"] = "desyncc/test/terminateNoTask.lua",
    }
}

local args = { ... }
local function main()
    term.setTextColor(colors.blue)
    print("Welcome to the DesynCC installer!")
    print("This installer will download the necessary files for DesynCC to work.")
    print("You can choose to install additional features by passing them as arguments to this installer.")
    print("---------------------")

    term.setTextColor(colors.orange)
    print("Available features:")
    for k, v in pairs(files) do
        if k ~= "base" then
            print(" - " .. k)
        end
    end

    term.setTextColor(colors.yellow)
    local features = { "base" }
    for k, v in ipairs(args) do
        if files[v] then
            table.insert(features, v)
        else
            term.setTextColor(colors.red)
            print("Unknown feature: " .. v)
        end
    end

    term.setTextColor(colors.green)
    print("The following features will be installed:")
    for _, feature in ipairs(features) do
        print(" - " .. feature)
    end

    term.setTextColor(colors.white)
    io.write("Do you want to proceed with installation? [y/n]: ")
    local cont = io.read()
    if cont:lower() ~= "y" then
        term.setTextColor(colors.red)
        print("Installation cancelled.")
        return
    end

    local function downloadFile(url, target)
        local req, err = http.get(url)
        if not req then
            term.setTextColor(colors.red)
            print("Failed to download " .. url .. ": " .. err)
            return false
        end
        local content = req.readAll()
        req.close()
        local file = fs.open(target, "w")
        file.write(content)
        file.close()
        return true
    end
    for k, v in ipairs(features) do
        for k, v in pairs(files[v]) do
            local url = "https://raw.githubusercontent.com/" .. repo .. "/refs/heads/" .. branch .. "/" .. k
            local target = v
            local succ = downloadFile(url, target)
            if succ then
                term.setTextColor(colors.green)
                print("Downloaded " .. k .. " to " .. target)
            else
                return
            end
        end
    end

    term.setTextColor(colors.blue)
    print("Installation complete! You can now use DesynCC by requiring 'desyncc.main'.")
end

main()