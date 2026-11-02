require "prefabutil"

local recipes = require "recipes2hm"

for _, recipe in pairs(recipes.Recipes) do
    local addRecipe = true
    if recipe.openFunc then
        for _, key in pairs(recipe.openFunc) do
            if not GetModConfigData(key) then
                addRecipe = false
                break
            end
        end
    end
    if addRecipe then
        if TUNING.isCh2hm then
            STRINGS.NAMES[string.upper(recipe.name)] = recipe.displayName_ch
            STRINGS.RECIPE_DESC[string.upper(recipe.description)] = recipe.displayDesc_ch
        else
            STRINGS.NAMES[string.upper(recipe.name)] = recipe.displayName_en
            STRINGS.RECIPE_DESC[string.upper(recipe.description)] = recipe.displayDesc_en
        end

        local ingredients = {}
        for k, v in pairs(recipe.ingredients) do
            table.insert(ingredients, Ingredient(k, v))
        end
        local atlas, image
        if not recipe.noatlas then
            atlas = recipe.atlas or ("images/"..(recipe.product or recipe.name)..".xml")
        end
        if not recipe.noimage then
            image = recipe.image or ((recipe.product or recipe.name)..".tex")
        end
        local config = {}
        config.atlas = atlas
        config.image = image
        if recipes.MoreDataKeys then
            for i, key in ipairs(recipes.MoreDataKeys) do
                if recipe[key] ~= nil then
                    config[key] = recipe[key]
                end
            end
        end

        AddRecipe2(recipe.name, ingredients, recipe.tech, config, recipe.filters)
    end
end