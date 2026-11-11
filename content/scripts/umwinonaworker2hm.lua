-- Upstream beta lifecycle defect only; local crafting compatibility lives in winona_easy.
local Guard = require("umcompatguard2hm")
local M = {}

function M.Install(env)
    local G = env.GLOBAL
    local config = G.rawget(G, "UM_CONFIG")
    if not config or not config.WINONAWORKER then return end
    local reported = {}
    local function Status(applied, reason, parts)
        local statuses = G.TUNING.UM_COMPAT_STATUS2HM
        if statuses then statuses.winona_worker = {applied = applied, reason = reason, parts = parts} end
        local key = tostring(applied) .. tostring(reason)
        if not reported[key] then
            reported[key] = true
            print("[ShadowWorld UM] winona_worker: " .. (applied and "applied" or "skipped") .. " (" .. reason .. ")")
        end
    end
    local function Listener(inst, event, profile)
        local listeners = inst.event_listeners and inst.event_listeners[event]
        for _, fn in ipairs(listeners and listeners[inst] or {}) do
            if Guard.Known(fn, profile) then return fn end
        end
    end
    local function SlotValue(fn, key)
        local slot = Guard.Slot(fn, key)
        return slot and slot.value
    end

    env.AddPrefabPostInit("winona", function(inst)
        if not G.TheWorld.ismastersim or inst.umworkerpatched2hm then return end
        local drain = Listener(inst, "performaction", "winona_worker_drain")
        local update = Listener(inst, "hungerdelta", "winona_worker_update")
        local work, efficient = inst.components.workmultiplier, inst.components.efficientuser
        if not drain or not update or not work or not efficient or not inst.components.hunger then
            Status(false, "upstream worker callbacks changed or absent")
            return
        end
        local human = Listener(inst, "ms_respawnedfromghost", "winona_worker_human")
        local ghost = Listener(inst, "ms_becameghost", "winona_worker_ghost")
        local workactions = SlotValue(update, "workiplier_actions")
        local useactions = SlotValue(update, "efficient_actions")
        if human and ghost and type(workactions) == "table" and type(useactions) == "table" then
            inst.umworkerpatched2hm = true
            inst:RemoveEventCallback("ms_respawnedfromghost", human)
            inst:RemoveEventCallback("ms_becameghost", ghost)
            inst:ListenForEvent("ms_becameghost", function(inst)
                -- The reviewed beta accidentally ListenForEvent()s again here.
                inst:RemoveEventCallback("performaction", drain)
                inst:RemoveEventCallback("hungerdelta", update)
                if inst._cdtask then inst._cdtask:Cancel(); inst._cdtask = nil end
                for _, action in ipairs(workactions) do work:RemoveMultiplier(action, "ohungy") end
                for _, action in ipairs(useactions) do efficient:RemoveMultiplier(action, "ohungy") end
                inst.multiplierapplied = false
            end)
            inst:ListenForEvent("ms_respawnedfromghost", function(inst, data)
                inst:RemoveEventCallback("performaction", drain)
                inst:RemoveEventCallback("hungerdelta", update)
                human(inst, data)
            end)
            Status(true, "reviewed beta worker lifecycle", {lifecycle = true})
        else
            Status(false, "upstream worker lifecycle changed or absent")
        end
    end)
end

return M
