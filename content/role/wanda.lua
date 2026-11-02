-- 旺达能力削弱，警钟攻击力不超过68，鞭子类武器攻击范围初始不超过1.75
-- if TUNING.POCKETWATCH_SHADOW_DAMAGE > 68 then
--     TUNING.POCKETWATCH_SHADOW_DAMAGE = 68
-- end
-- if TUNING.WHIP_RANGE > 1.75 then
--     TUNING.WHIP_RANGE = 1.75
-- end

-- 2025.5.17 melon:蓝加到裂开的不老表上
-- AddRecipePostInit("pocketwatch_heal", function(inst) table.insert(inst.ingredients, Ingredient("bluegem", 1)) end)
AddRecipePostInit("pocketwatch_recall", function(inst) table.insert(inst.ingredients, Ingredient("orangegem", 1)) end)
AddRecipePostInit("pocketwatch_revive", function(inst) table.insert(inst.ingredients, Ingredient("greengem", 1)) end)

-- AddPrefabPostInit(
--     "wanda",
--     function(inst)
--         AddWrapAbility(inst)
--     end
-- )
