-- 麦斯威尔削弱
-- 注:原文件残留的"给法典配方加蛋白石"与 tech/moonrockidol.lua 重复,已注释避免副作用
-- AddRecipePostInit("waxwelljournal", function(inst) table.insert(inst.ingredients, Ingredient("opalpreciousgem", 1)) end)

-- local function ResetTakeDemage(inst)
--     local numpets = inst.components.petleash:GetNumPets()
--     inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 + 0.1 * numpets, "waxwellpets")
-- end

-- AddPrefabPostInit(
--     "waxwell",
--     function(inst)
--         -- AddWrapAbility(inst)
--         if not TheWorld.ismastersim then
--             return inst
--         end
--         -- local current_health_percent = inst.components.health:GetPercent()
--         -- inst.components.health.maxhealth = inst.components.health.maxhealth + 75
--         -- inst.components.health:SetPercent(current_health_percent)
--         local oldOnSpawnPet = inst.components.petleash.onspawnfn
--         inst.components.petleash:SetOnSpawnFn(
--             function(...)
--                 oldOnSpawnPet(...)
--                 ResetTakeDemage(inst)
--             end
--         )
--         local OnDespawnPet = inst.components.petleash.ondespawnfn
--         inst.components.petleash:SetOnDespawnFn(
--             function(...)
--                 OnDespawnPet(...)
--                 ResetTakeDemage(inst)
--             end
--         )
--     end
-- )

-- 普通怪物 24秒 -> 8秒;Boss 12秒 -> 4秒
TUNING.SHADOW_PILLAR_DURATION = 8
TUNING.SHADOW_PILLAR_DURATION_BOSS = 4
