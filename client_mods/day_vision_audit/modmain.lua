local G = GLOBAL
local json = require("json")
local history, last, attached, lastcall = {}, nil, nil, -1

local function Label(value)
    if G.type(value) == "table" then
        return value.prefab and (value.prefab.."#"..G.tostring(value.GUID)) or "table"
    end
    return G.tostring(value)
end

local function Palette(value)
    if G.type(value) ~= "table" then return Label(value) end
    local result = {}
    for _, key in G.ipairs({"day", "dusk", "night", "full_moon"}) do result[key] = Label(value[key]) end
    return result
end

local function Read(fn)
    local ok, value = G.pcall(fn)
    if ok then return value end
    return "unavailable"
end

local function Snapshot(vision)
    local state = G.TheWorld and G.TheWorld.state or {}
    local sources = {}
    for _, entry in G.ipairs(vision.forcednightvisionstack or {}) do
        sources[#sources + 1] = {source=Label(entry.source), priority=entry.priority,
            nonightvisioncc=entry.nonightvisioncc == true, palette=Palette(entry.cctable)}
    end
    local equipment = {}
    local inventory = vision.inst.replica and vision.inst.replica.inventory
    if inventory and inventory.GetEquips then
        Read(function()
            for slot, item in G.pairs(inventory:GetEquips()) do
                equipment[G.tostring(slot)] = {item=Label(item), nightvision=item:HasTag("nightvision")}
            end
        end)
    end
    local cube = G.TheWorld and G.TheWorld.components and G.TheWorld.components.colourcube
    local skill = vision.inst.components.skilltreeupdater
    return {phase=state.phase, isday=state.isday, isnight=state.isnight, fullmoon=state.isfullmoon,
        role=vision.inst.prefab, equipment=vision.nightvision == true, forced=vision.forcenightvision == true,
        nonightvisioncc=vision.nonightvisioncc == true, ghost=vision.ghostvision == true,
        palette=Palette(vision.currentcctable), custom=Palette(vision.overridecctable), sources=sources,
        colourcube=cube and Read(function() return cube:GetDebugString() end) or "unavailable",
        equipped=equipment, nightmodules=vision.inst._nightvision_modcount,
        wx78_plainvision=skill and Read(function() return skill:IsActivated("wx78_circuitry_betabuffs_1") end),
        polarvision=vision.polarvision,
        henv=vision.inst.henv_nightvision and Read(function() return vision.inst.henv_nightvision:value() end)}
end

local function Trace()
    local rows = {}
    for depth=3,9 do
        local info = G.debug.getinfo(depth, "Sl")
        if not info then break end
        rows[#rows + 1] = (info.short_src or info.source or "?")..":"..G.tostring(info.currentline)
    end
    return G.table.concat(rows, " <- ")
end

local function Emit(reason, vision)
    if vision.inst ~= G.ThePlayer then return end
    local snapshot = Snapshot(vision)
    local encoded = json.encode(snapshot)
    if reason == "poll" and encoded == last then return end
    last = encoded
    G.print("[DayVisionAudit] "..json.encode({reason=reason, time=G.GetTime(), state=snapshot, calls=history}))
end

-- Logging failures never replace a game's return value or interrupt its callback.
local function Record(vision, method, argument, trace, implementation)
    if vision.inst ~= G.ThePlayer then return end
    history[#history + 1] = {time=G.GetTime(), method=method, argument=argument, trace=trace,
        implementation=implementation, state=Snapshot(vision)}
    if #history > 24 then G.table.remove(history, 1) end
    if G.TheWorld and G.TheWorld.state.isday and G.GetTime() - lastcall >= 1 then
        lastcall = G.GetTime()
        Emit("day-call", vision)
    end
end

local function Attach(inst)
    if inst ~= G.ThePlayer then return end
    local vision = inst.components.playervision
    if not vision or vision.dayvisionaudit then return end
    vision.dayvisionaudit = true
    history, last, attached, lastcall = {}, nil, vision, -1
    for _, method in G.ipairs({"ForceNightVision", "ForceNoNightVisionCC", "PushForcedNightVision",
        "PopForcedNightVision", "SetCustomCCTable", "UpdateCCTable"}) do
        local original = vision[method]
        if G.type(original) == "function" then
            local implementation = Read(function()
                local info = G.debug.getinfo(original, "S")
                return (info.source or "?")..":"..G.tostring(info.linedefined)
            end)
            vision[method] = function(self, ...)
                local first = (...)
                local ok, argument, trace = G.pcall(function() return Label(first), Trace() end)
                local function Finish(...)
                    if ok then G.pcall(Record, self, method, argument, trace, implementation) end
                    return ...
                end
                return Finish(original(self, ...))
            end
        end
    end
    G.pcall(Emit, "attached", vision)
    for _, event in G.ipairs({"ccoverrides", "ccphasefn", "setinpolar"}) do
        inst:ListenForEvent(event, function(_, value)
            G.pcall(function()
                Record(vision, "event:"..event, event == "ccoverrides" and Palette(value) or Label(value), Trace())
            end)
            inst:DoTaskInTime(0, function() G.pcall(Emit, event.."+0", vision) end)
        end)
    end
    -- These are observations of the renderer's event inputs. They also catch
    -- mods that bypass PlayerVision and issue a world override directly.
    inst:ListenForEvent("overridecolourcube", function(_, value)
        G.pcall(function() Record(vision, "event:overridecolourcube", Label(value), Trace()) end)
        inst:DoTaskInTime(0, function() G.pcall(Emit, "overridecolourcube+0", vision) end)
    end, G.TheWorld)
    inst:WatchWorldState("phase", function()
        for _, delay in G.ipairs({0, 1, 3}) do
            inst:DoTaskInTime(delay, function()
                if attached == vision then G.pcall(Emit, "phase+"..delay, vision) end
            end)
        end
    end)
    inst:DoPeriodicTask(5, function() G.pcall(Emit, "poll", vision) end)
end

G.print("[DayVisionAudit] loaded 1.1; waiting for local player")
AddSimPostInit(function()
    -- The local player may be assigned after prefab postinit or after migration.
    G.TheWorld:DoPeriodicTask(1, function()
        if G.ThePlayer then Attach(G.ThePlayer) end
    end)
end)
