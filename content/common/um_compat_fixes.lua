-- Correctness fixes stay active even when the optional UM adjustments are disabled.
-- Bells transfer their beefalo into the saved payload; other protected items stay out.
modimport("common/beef_bell_pack.lua")
local function HasUnbundlableItem(container)
    if container then
        for slot = 1, 6 do
            local item = container:GetItemInSlot(slot)
            if item and item:HasTag("nobundling") and item.prefab ~= "beef_bell" and item.prefab ~= "shadow_beef_bell" then return true end
        end
    end
    return false
end

AddPrefabPostInit("silksack", function(inst)
    if not TheWorld.ismastersim or not inst.WrapStuff then return end
    local WrapStuff = inst.WrapStuff
    inst.WrapStuff = function(inst, owner, ...)
        -- Check again on the server: widget validation alone cannot protect an RPC.
        if HasUnbundlableItem(inst.components.container) then
            if owner and owner.components.talker then owner.components.talker:Say(GetString(owner, "ACTIONFAIL_GENERIC")) end
            return false
        end
        return WrapStuff(inst, owner, ...)
    end
end)

-- UM keeps this widget in its private modparams table, outside containers.params.
local containers = require("containers")
local widgetsetup = containers.widgetsetup
containers.widgetsetup = function(container, prefab, ...)
    local result = widgetsetup(container, prefab, ...)
    if (prefab or container.inst.prefab) == "silksack" then
        local button = container.widget and container.widget.buttoninfo
        if button and button.validfn and not button.nobundlingguard2hm then
            button.nobundlingguard2hm = true
            local validfn = button.validfn
            button.validfn = function(inst, ...)
                if HasUnbundlableItem(inst.replica.container or inst.components.container) then return false end
                return validfn(inst, ...)
            end
        end
    end
    return result
end

AddStategraphPostInit("wilson", function(sg)
    local handler = sg.actionhandlers[ACTIONS.ATTACK]
    if not sg.states.wathomleap or not handler then return end
    local deststate = handler.deststate
    handler.deststate = function(inst, action, ...)
        -- Keep UM's bookkeeping and all other weapons on their existing route.
        local state = deststate(inst, action, ...)
        local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if inst:HasTag("wathom") and weapon and (weapon.prefab == "icestaff2" or weapon.prefab == "icestaff3") and
            not inst.sg:HasStateTag("attack") and not (inst.components.rider and inst.components.rider:IsRiding()) then
            return "wathomleap"
        end
        return state
    end
end)
