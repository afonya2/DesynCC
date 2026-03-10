--[[
DesynCC Class System
Copyright 2026 Afonya

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local function copy(tbl, deep)
    local out = {}
    for k, v in pairs(tbl) do
        if deep and type(v) == "table" then
            out[k] = copy(v, true)
        else
            out[k] = v
        end
    end
    return out
end
local function mergeTable(base, addition, deep)
    for k, v in pairs(addition) do
        if type(v) == "table" then
            base[k] = copy(v, deep)
        else
            base[k] = v
        end
    end
    return base
end

--- This function is used to create a new class. It can be used to create a class that extends another class by passing the parent class as an argument.
--- @param extends table|nil The class to extend, or nil to create a new class.
--- @return table, table The static class with constructor and the class metatable.
local function class(extends)
    local cls = {}
    local static = {}

    if (extends ~= nil) then
        static = copy(extends, true)
    end

    --- Creates a new class
    --- @return table The new class
    function static:new(...)
        return self:super(...)
    end

    --- Creates a new class internally. Constructors should call this function to create a new class instance.
    --- @return table The new class
    function static:super(...)
        local out = {}
        if (extends ~= nil) then
            out = extends:new(...)
        end
        mergeTable(out, cls, true)
        return out
    end

    return static, cls
end

--[[local animal, animalClass = class()
function animal:new(name)
    local cls = self:super()
    cls.name = name
    return cls
end
function animalClass:getName()
    return self.name
end

local dog, dogClass = class(animal)
function dog:new(name)
    local cls = self:super(name)
    return cls
end
function dogClass:say()
    print("Woof!")
end

local cat, catClass = class(animal)
function cat:new(name)
    local cls = self:super(name)
    return cls
end
function catClass:say()
    print("Meow!")
end

local test = animal:new("Generic Animal")
print(test:getName()) -- Output: Generic Animal
local doge = dog:new("Buddy")
print(doge:getName()) -- Output: Buddy
doge:say() -- Output: Woof!
local car = cat:new("Whiskers")
print(car:getName()) -- Output: Whiskers
car:say() -- Output: Meow!]]

return class