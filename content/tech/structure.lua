-- 建筑科技削弱
AddRecipePostInit("firesuppressor", function(inst)
    table.insert(inst.ingredients, Ingredient("opalpreciousgem", 1))
    table.insert(inst.ingredients, Ingredient("deerclops_eyeball", 1))
end)
