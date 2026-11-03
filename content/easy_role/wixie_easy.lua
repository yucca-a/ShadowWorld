-- Stable UM calculates fear on the client; Public Beta calculates it on the
-- server and replicates a net_string. Keep both paths disabled and zeroed.
local function NeverGainFear() return false end
local function NoFear() return 0 end

local function ClearFear(inst)
    if not inst:IsValid() then return end
    inst.no_claustrophobia = true
    inst.noclaustrophobia2hm = true
    inst.CanGainClaustrophobia = NeverGainFear
    inst.GetClaustrophobia = NoFear
    inst.wixiepanic = false
    inst.claustrophobiarate = 0
    inst.claustrophobiamodifier = 0
    inst.headmodifier, inst.bodymodifier = 0, 0
    inst.claustrophobiahidden = nil
    if type(inst.claustrophobia) == "number" then
        inst.claustrophobia = 0
    elseif inst.claustrophobia ~= nil and TheWorld.ismastersim then
        inst.claustrophobia:set(0)
    end
    -- Retain the cancelled task handle: UM's OnInit tests it before recreating.
    if inst.wixietask ~= nil then inst.wixietask:Cancel() end
    if inst._claustrophobiacdtask ~= nil then
        inst._claustrophobiacdtask:Cancel()
        inst._claustrophobiacdtask = nil
    end
end

local function RemoveFearListeners(inst)
    for _, event in ipairs({"equip", "unequip", "newstate", "um_claustrophobiapanic"}) do
        local callbacks = inst.event_listeners ~= nil and inst.event_listeners[event] or nil
        local own = callbacks ~= nil and callbacks[inst] or nil
        local remove = {}
        for _, fn in ipairs(own or {}) do
            local source = debug.getinfo(fn, "S").source:gsub("\\", "/")
            if source:sub(-#"/scripts/prefabs/wixie.lua") == "/scripts/prefabs/wixie.lua" or source == "scripts/prefabs/wixie.lua" then
                table.insert(remove, fn)
            end
        end
        for _, fn in ipairs(remove) do inst:RemoveEventCallback(event, fn) end
    end
end

AddPrefabPostInit("wixie", function(inst)
    ClearFear(inst)
    RemoveFearListeners(inst)
    -- UM creates its frame task in a zero-delay init; cancel after that init.
    inst:DoTaskInTime(.1, ClearFear)
end)

-- Also guard legacy client RPCs and already queued Beta panic events.
for _, graph in ipairs({"wilson", "wilson_client"}) do
    AddStategraphPostInit(graph, function(sg)
        for _, name in ipairs({"claustrophobic", "claustrophobic_loop", "claustrophobic_pst"}) do
            local state = sg.states[name]
            if state ~= nil then
                local enter = state.onenter
                state.onenter = function(inst, ...)
                    if inst.prefab == "wixie" and inst.noclaustrophobia2hm then
                        ClearFear(inst)
                        inst.sg:GoToState("idle")
                        return
                    end
                    if enter ~= nil then return enter(inst, ...) end
                end
            end
        end
    end)
end
