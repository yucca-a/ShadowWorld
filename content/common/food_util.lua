local foods = require("foodsdata2hm")

for _, recipe in pairs (foods) do
    if recipe.warlyOnly then
        AddCookerRecipe("portablecookpot", recipe)
    else
        AddCookerRecipe("cookpot", recipe)
        AddCookerRecipe("portablecookpot", recipe)
        AddCookerRecipe("archive_cookpot", recipe)
    end

    if recipe.card_def then
        AddRecipeCard("cookpot", recipe)
    end

    RegisterInventoryItemAtlas(recipe.atlasname, recipe.name .. ".tex")
end

local spicedfoods = {}
GenerateSpicedFoods(foods)

local spices = require("spicedfoods")

local spicers = {
    "portablespicer"
}

for k, data in pairs(spices) do
    for name, v in pairs(foods) do
        if data.basename == name then
            spicedfoods[k] = data
        end
    end
end

for i, v in pairs(spicers) do
    for n, b in pairs(spicedfoods) do
        AddCookerRecipe(v, b)
    end
end