-- 友好果蝇无敌
AddPrefabPostInit("friendlyfruitfly", MakeOnlyPlayerTarget)
-- 果蝇增强
local function IsFruitFly(dude)
    if dude:HasTag("fruitfly") then
        if not dude.hascausedhavoc then dude.hascausedhavoc = true end
        return true
    end
end
local function OnlordfruitflyAttacked(inst, data) if data and data.attacker then inst.components.combat:ShareTarget(data.attacker, 30, IsFruitFly, 12) end end
TUNING.LORDFRUITFLY_FRUITFLY_AMOUNT = 8
TUNING.FRUITFLY_ATTACK_PERIOD = 8
AddPrefabPostInit("lordfruitfly", function(inst)
    if not TheWorld.ismastersim then return end
    inst.components.locomotor.walkspeed = TUNING.FRUITFLY_WALKSPEED * 1.5
    inst:ListenForEvent("attacked", OnlordfruitflyAttacked)
end)
AddPrefabPostInit("fruitfly", function(inst)
    if not TheWorld.ismastersim then return end
    inst.CanTargetAndAttack = function()
        if not inst.hascausedhavoc and inst.components.follower.leader ~= nil then inst.hascausedhavoc = true end
        return inst.hascausedhavoc and inst.components.combat and (inst.components.combat.target == nil or not inst.components.combat:InCooldown())
    end
end)
require "behaviours/runaway"
local RUN_AWAY_DIST = 12
local STOP_RUN_AWAY_DIST = 16
AddBrainPostInit("fruitflybrain", function(self)
    if not self.inst:HasTag("lordfruitfly") then
        table.insert(self.bt.root.children, 3,
                     WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst.components.combat:InCooldown() end, "Dodge",
                               RunAway(self.inst, function() return self.inst.components.combat.target end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)))
    end
end)

-- AddComponentPostInit("armor", function(self)
--     local GetAbsorption = self.GetAbsorption
--     self.GetAbsorption = function(self) end
-- end)

-- local testsize = {}
-- AddPrefabPostInitAny(function(inst)
--     if not testsize[inst.prefab] and inst.AnimState and inst.components.health then
--         local bbx1, bby1, bbx2, bby2 = inst.AnimState:GetVisualBB()
--         local bby = math.abs(bby2 - bby1)
--         local targetsize
--         if bby < 2 then
--             targetsize = "short"
--         elseif bby < 4 then
--             targetsize = "med"
--         else
--             targetsize = "tall"
--         end
--         testsize[inst.prefab] = targetsize
--         print(inst.name,"体型", inst.prefab, targetsize, math.ceil(bby))
--     end
-- end)
