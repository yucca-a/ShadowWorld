require "behaviours/panic"
require("behaviours/avoidelectricfence")
local BrainCommon = require("brains/braincommon")
local ShouldTriggerPanic = BrainCommon.ShouldTriggerPanic
BrainCommon.ShouldTriggerPanic = function(inst)
    local result = ShouldTriggerPanic(inst)
    if result and inst.components.combat ~= nil and inst.components.combat.target ~= nil and inst.components.combat.defaultdamage > 0 then
        return GetTime() - inst.components.combat.lastwasattackedtime > inst.components.combat.min_attack_period * 2
    end
    return result
end
BrainCommon.PanicTrigger = function(inst) return WhileNode(function() return BrainCommon.ShouldTriggerPanic(inst) end, "PanicTrigger", Panic(inst)) end

-- 2025.8.22 melon:被电僵直cd延长至5倍
if TUNING.hardmode2hm then
    TUNING.ELECTROCUTE_DEFAULT_DELAY.max = TUNING.ELECTROCUTE_DEFAULT_DELAY.max * 5
    TUNING.ELECTROCUTE_DEFAULT_DELAY.min = TUNING.ELECTROCUTE_DEFAULT_DELAY.max - 2 -- 范围小一点
end
-- 无效滴电击
local ShouldAvoidElectricFence = BrainCommon.ShouldAvoidElectricFence
BrainCommon.ShouldAvoidElectricFence = function(inst)
    local result = ShouldAvoidElectricFence(inst)
    if result and inst.components.combat ~= nil and inst.components.combat.target ~= nil and inst.components.combat.defaultdamage > 0 then
        return GetTime() - inst.components.combat.lastwasattackedtime > inst.components.combat.min_attack_period * 2
    end
    return result
end

BrainCommon.ElectricFencePanicTrigger = function(inst)
    return WhileNode(function() return BrainCommon.ShouldAvoidElectricFence(inst) end, "ElectricShock", AvoidElectricFence(inst))
end

-- local BanElectrocuteState_tags = {"chess"}
-- local BanElectrocuteState_prefabs = {"hutch"}
-- local function BanElectrocuteState(inst)
--     if table.contains(BanElectrocuteState_prefabs,inst.prefab) then return true end
--     for i,v in pairs(BanElectrocuteState_tags) do 
--         if inst:HasTag(v) then return true end
--     end
--     return false
-- end

-- local CanEntityBeElectrocuted = GLOBAL.CanEntityBeElectrocuted
-- GLOBAL.CanEntityBeElectrocuted = function(inst, ...)
--     if BanElectrocuteState(inst) then return false end
--     return CanEntityBeElectrocuted(inst, ...)
-- end
require("stategraphs/commonstates") -- 2025.8.26 melon:CommonHandlers报nil
local try_electrocute_onattacked = rawget(CommonHandlers, "TryElectrocuteOnAttacked")
rawset(CommonHandlers, "TryElectrocuteOnAttacked", function(inst, data, ...)
    if inst.components.combat ~= nil and inst.components.combat.target ~= nil and inst.components.combat.defaultdamage > 0
    and GetTime() - inst.components.combat.lastwasattackedtime <= inst.components.combat.min_attack_period * 2 then
        if CanEntityBeElectrocuted(inst) and CanEntityBeElectrocuted(inst) 
        and CommonHandlers.AttackCanElectrocute(inst, data) and not (inst.components.inventory and inst.components.inventory:IsInsulated())
        and (not inst.sg:HasAnyStateTag("nointerrupt", "noelectrocute") or inst.sg:HasStateTag("canelectrocute")) 
        and not CommonHandlers.ElectrocuteRecoveryDelay(inst) then
            CommonHandlers.UpdateElectrocuteRecoveryDelay(inst)
            CommonHandlers.SpawnElectrocuteFx(inst, data)
        end
        return false
    end
    return try_electrocute_onattacked(inst, data, ...)
end)

-- local onattacked = rawget(CommonHandlers, "OnAttacked")
-- rawset(CommonHandlers, "OnAttacked", function(...)
--     local event = onattacked(hitreact_cooldown, max_hitreacts, skip_cooldown_fn, ...)
--     hitreact_cooldown = type(hitreact_cooldown) == "number" and hitreact_cooldown or nil
--     if hitreact_cooldown ~= nil or max_hitreacts ~= nil or skip_cooldown_fn ~= nil then
-- 		return EventHandler("attacked", function(inst, data)
--             if inst.components.health and not inst.components.health:IsDead() and CommonHandlers.TryElectrocuteOnAttacked then
--             event.fn(inst, data, hitreact_cooldown, max_hitreacts, skip_cooldown_fn) 
--         end)
-- 	else
-- 	    return event
-- 	end
-- end)