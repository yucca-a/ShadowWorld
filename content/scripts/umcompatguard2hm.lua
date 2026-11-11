-- Match the implementation being replaced, not a workshop version number.
-- Source paths and debug line numbers differ between hosts; executable Lua
-- instructions, constants and child prototypes must still match the profiles.
local M = {}
local cache = setmetatable({}, {__mode = "k"})

local function Fingerprint(fn)
    local dump = string.dump(fn)
    if dump:sub(1, 6) ~= "\27Lua\81\0" or dump:byte(7) ~= 1 then return nil end
    local intsize, sizesize, codesize, numsize = dump:byte(8, 11)
    if intsize ~= 4 or codesize ~= 4 or numsize ~= 8 or dump:byte(12) ~= 0 or
        (sizesize ~= 4 and sizesize ~= 8) then return nil end
    local pos, h1, h2, length = 13, 0, 0, 0
    local function Take(n)
        if n < 0 or pos + n - 1 > #dump then error("invalid Lua prototype") end
        local s = dump:sub(pos, pos + n - 1)
        pos = pos + n
        return s
    end
    local function UInt(n)
        local s, v = Take(n), 0
        for i = n, 1, -1 do v = v * 256 + s:byte(i) end
        return v
    end
    local function Feed(s)
        for i = 1, #s do
            local byte = s:byte(i)
            h1 = (h1 * 65599 + byte) % 2147483647
            h2 = (h2 * 131 + byte) % 2147483629
        end
        length = length + #s
    end
    local function Count(n)
        -- Decimal delimiters make lengths independent of size_t width.
        Feed(tostring(n) .. ":")
    end
    local function LuaString(keep)
        local n = UInt(sizesize)
        if keep then Count(n) end
        local s = Take(n)
        if keep then Feed(s) end
    end
    local Prototype
    Prototype = function(depth)
        if depth > 64 then error("prototype nesting limit") end
        LuaString(false) -- chunk filename
        Take(8) -- source line range
        Feed(Take(4)) -- upvalue/parameter/vararg/stack layout
        local n = UInt(4)
        Count(n); Feed(Take(n * codesize))
        n = UInt(4); Count(n)
        for i = 1, n do
            local tag = UInt(1)
            Count(tag)
            if tag == 1 then Feed(Take(1))
            elseif tag == 3 then Feed(Take(numsize))
            elseif tag == 4 then LuaString(true)
            elseif tag ~= 0 then error("unknown constant type") end
        end
        n = UInt(4); Count(n)
        for i = 1, n do Prototype(depth + 1) end
        n = UInt(4); Take(n * 4) -- line table
        n = UInt(4)
        for i = 1, n do LuaString(false); Take(8) end -- local debug names
        n = UInt(4)
        for i = 1, n do LuaString(false) end -- upvalue debug names
    end
    Prototype(0)
    if pos ~= #dump + 1 then return nil end
    return string.format("%08x:%08x:%d", h1, h2, length)
end

function M.Fingerprint(fn)
    if type(fn) ~= "function" then return nil end
    if cache[fn] ~= nil then return cache[fn] or nil end
    local ok, value = pcall(Fingerprint, fn)
    cache[fn] = ok and value or false
    return ok and value or nil
end

function M.Match(fn, file, hashes)
    if type(fn) ~= "function" or type(hashes) ~= "table" then return false end
    local info = debug.getinfo(fn, "S")
    local source = info and info.source and ("/" .. info.source:gsub("\\", "/")) or ""
    if source:sub(-#file) ~= file then return false end
    local value = M.Fingerprint(fn)
    return value ~= nil and hashes[value] == true
end

local profiles
function M.Known(fn, id)
    profiles = profiles or require("umcompatprofiles2hm")
    local profile = profiles[id]
    return profile and M.Match(fn, profile.file, profile.hashes) or false
end

function M.Slot(fn, name)
    if type(fn) ~= "function" then return nil end
    for i = 1, 128 do
        local key, value = debug.getupvalue(fn, i)
        if key == nil then return nil end
        if key == name then return {owner = fn, index = i, value = value} end
    end
end

-- Bounded, cycle-safe discovery is used only while installing a known hook.
function M.Find(fn, name)
    local seen, visited = {}, 0
    local function Search(current, depth)
        if type(current) ~= "function" or seen[current] or depth > 12 or visited >= 256 then return nil end
        seen[current], visited = true, visited + 1
        local direct = M.Slot(current, name)
        if direct then return direct end
        for i = 1, 128 do
            local key, value = debug.getupvalue(current, i)
            if key == nil then break end
            if type(value) == "function" then
                local slot = Search(value, depth + 1)
                if slot then return slot end
            end
        end
    end
    return Search(fn, 0)
end

function M.Replace(slot, replacement)
    if not slot then return false end
    local _, value = debug.getupvalue(slot.owner, slot.index)
    if value ~= slot.value then return false end
    return debug.setupvalue(slot.owner, slot.index, replacement) ~= nil
end

return M
