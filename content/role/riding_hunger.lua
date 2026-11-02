-------------------------------------------------------------------------------------
-------------------------[[2025.7.25 melon:骑乘险境]]---------------------------------
-- 骑牛收到攻击扣除伤害2%的饥饿
-- 滑铲时allmiss2hm不扣，梦魇鞍不扣
-------------------------------------------------------------------------------------
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat ~= nil then
        local _GetAttacked_Internal = inst.components.combat.GetAttacked_Internal -- 别少个self↓
        inst.components.combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
            if damage ~= nil and self.inst.components.rider:IsRiding() and self.inst.components.rider.saddle and self.inst.components.rider.saddle.prefab ~= "saddle_shadow" and self.inst.components.hunger and not self.inst.allmiss2hm then
                self.inst.components.hunger:DoDelta(-0.02 * damage)
            end
            return _GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end
    end
end)