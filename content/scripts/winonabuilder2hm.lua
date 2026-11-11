-- Local Winona enhancements must not disable UM's separately configured work ability.
local Guard = require("umcompatguard2hm")
local M = {}

function M.Install(env, nohungry)
    local G = env.GLOBAL
    local config = G.rawget(G, "UM_CONFIG")
    local worker = config and config.WINONAWORKER or not config and G.TUNING.DSTU and G.TUNING.DSTU.WINONA_WORKER
    env.AddPrefabPostInit("winona", function(inst)
        -- Preserve native character tags in every configuration. The crafting
        -- enhancement only changes BUILD, never the worker or its gathering route.
        if not G.TheWorld.ismastersim or not worker or inst.multiplierapplied then return end
        local listeners = inst.event_listeners and inst.event_listeners.hungerdelta
        for _, update in ipairs(listeners and listeners[inst] or {}) do
            if Guard.Known(update, "winona_worker_update") or Guard.Known(update, "winona_worker_update_stable") then
                update(inst)
                inst.winonaworkerinitialized2hm = true
                return
            end
        end
    end)
    if not nohungry then return end
    local function CraftingOnly(sg)
        local handler = sg.actionhandlers[G.ACTIONS.BUILD]
        if not handler or type(handler.deststate) ~= "function" then return end
        local Build = handler.deststate
        handler.deststate = function(inst, action, ...)
            local result = Build(inst, action, ...)
            if inst.prefab ~= "winona" or result ~= "dohungrybuild" then return result end
            local recipe = action and G.GetValidRecipe(action.recipe)
            if recipe and recipe.sg_state ~= nil then return result end
            return inst:HasTag("fastbuilder") and "domediumaction"
                or inst:HasTag("slowbuilder") and "dolongestaction" or "dolongaction"
        end
    end
    env.AddStategraphPostInit("wilson", CraftingOnly)
    env.AddStategraphPostInit("wilson_client", CraftingOnly)
end

return M
