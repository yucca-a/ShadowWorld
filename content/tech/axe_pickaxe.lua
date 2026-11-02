AddPrefabPostInit("multitool_axe_pickaxe", function(inst)
    inst:DoTaskInTime(0, function()
        if inst.components.tool then inst.components.tool:SetAction(ACTIONS.HAMMER, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY) end
        if inst.components.finiteuses then inst.components.finiteuses:SetConsumption(ACTIONS.HAMMER, 1) end
    end)
end)

AddRecipePostInit("multitool_axe_pickaxe",
                  function(inst) inst.ingredients = {Ingredient("hammer", 1), Ingredient("goldenpickaxe", 1), Ingredient("thulecite", 2)} end)

-- if TUNING.isCh2hm then STRINGS.NAMES.MULTITOOL_AXE_PICKAXE = "多用斧锤镐" end
