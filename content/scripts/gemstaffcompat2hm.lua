-- Gem Core's legacy green-staff patch expects direct upvalues. Other mods can
-- wrap the constructor; resolve the original closure without replacing it.
local M = {}

local function Direct(fn, wanted)
    if type(fn) ~= "function" then return end
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if name == nil then return end
        if name == wanted then return value, i, fn end
        i = i + 1
    end
end

local function Find(fn, wanted)
    local value, index, scope = Direct(fn, wanted)
    if scope then return value, index, scope end
    local seen, queue, head = {}, {{fn, 0}}, 1
    local match
    while head <= #queue do
        local row = queue[head]
        head = head + 1
        local current, depth = row[1], row[2]
        if type(current) == "function" and not seen[current] then
            seen[current] = true
            value, index, scope = Direct(current, wanted)
            if scope then
                -- Two candidate closures are not safe to guess between.
                if match and (match[2] ~= index or match[3] ~= scope) then return end
                match = {value, index, scope}
            else
                local i = 1
                while true do
                    local name, child = debug.getupvalue(current, i)
                    if name == nil then break end
                    if type(child) == "function" and not seen[child] then
                        if depth >= 8 or #queue >= 128 then return end
                        queue[#queue + 1] = {child, depth + 1}
                    end
                    i = i + 1
                end
            end
        end
    end
    if match then return unpack(match) end
end

function M.Wrap(callback, loadstaff, warn)
    return function(...)
        local staff = loadstaff()
        local green = staff and staff.fns and staff.fns.green
        local destroy, destroyindex, destroyscope = Find(green, "destroystructure")
        local haunt = Find(green, "onhauntgreen")
        local haunted, hauntindex, hauntscope = Find(haunt, "destroystructure")
        -- The environment adapter must operate on the actual recipe loop, not
        -- an arbitrary wrapper around it. Unsupported replacements stay intact.
        local spawn = Direct(destroy, "SpawnLootPrefab")
        if type(destroy) ~= "function" or type(spawn) ~= "function" or haunted ~= destroy then
            warn("[GemStaffCompat2hm] Green staff internals were replaced; skipped only Gem Core legacy deconstruction adapter. Existing staff spell remains active.")
            return
        end
        local originalenv = getfenv(callback)
        local original = originalenv.UpvalueHacker
        local adapter = {}
        function adapter.GetUpvalue(fn, ...)
            if fn == green and select("#", ...) == 1 and (...) == "destroystructure" then
                return destroy, destroyindex, destroyscope
            end
            return original.GetUpvalue(fn, ...)
        end
        function adapter.SetUpvalue(fn, replacement, ...)
            local first, second = ...
            if fn == green and select("#", ...) == 1 and first == "destroystructure" then
                return debug.setupvalue(destroyscope, destroyindex, replacement)
            elseif fn == green and select("#", ...) == 2 and first == "onhauntgreen" and second == "destroystructure" then
                return debug.setupvalue(hauntscope, hauntindex, replacement)
            end
            return original.SetUpvalue(fn, replacement, ...)
        end
        -- Isolate only this callback, never replace the global Gem Core API.
        setfenv(callback, setmetatable({UpvalueHacker = adapter}, {__index = originalenv, __newindex = originalenv}))
        return callback(...)
    end
end

function M.Install(manager)
    local gem = manager and manager:GetMod("workshop-1378549454")
    local callbacks = gem and gem.postinitfns and gem.postinitfns.SimPostInit
    if not callbacks or gem.gemstaffcompat2hm then return end
    for i, callback in ipairs(callbacks) do
        local info = debug.getinfo(callback, "S")
        local source = info and info.source and info.source:gsub("\\", "/") or ""
        if source:match("/gemscripts/gemdictionary/loot%.lua$") and type(Direct(callback, "_destroystructureEnv")) == "table" then
            callbacks[i] = M.Wrap(callback, function() return require("prefabs/staff_common") end, print)
            gem.gemstaffcompat2hm = true
        end
    end
end

return M
