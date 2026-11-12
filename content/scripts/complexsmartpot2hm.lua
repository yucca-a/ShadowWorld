-- Complex Smart Pot 3744378627: extend its own detector and panel rather than
-- creating a second preview. Optional client modules must never load on a server.
local M = {}
local pots = {cookpot=true, portablecookpot=true, medal_cookpot=true}

function M.Install(cooking, api)
    if not api.isModuleAvailable("container/container_detector") or
        not api.isModuleAvailable("ui/recipe_panel") then return end
    local detector = require("container/container_detector")
    if detector.shadowworld2hm then return end
    detector.shadowworld2hm = true
    detector.RegisterDevice({id="shadowworld2hm", is_brewer=false, test=function(inst)
        local c = inst.replica and inst.replica.container
        return c and ((pots[inst.prefab] and c:GetNumSlots()==5) or
            (inst.prefab=="dragonflyfurnace" and inst:HasTag("stewer")))
    end})
    local matcher = require("data/recipe_matcher")
    api.AddClassPostConstruct("ui/recipe_panel", function(panel)
        local setcooker = panel.SetCooker
        panel.SetCooker = function(self, name, ...)
            if name=="dragonflyfurnace" then
                name = self._player_inst and self._player_inst:HasTag("professionalchef") and "portablecookpot" or "cookpot"
            end
            return setcooker(self, name, ...)
        end
        local accepts, changed, ingredients = panel.SetAcceptsStacksFromContainer, panel.OnSlotChanged, panel.SetPotIngredients
        panel.SetAcceptsStacksFromContainer = function(self, inst, ...)
            local result = accepts(self, inst, ...)
            if inst and inst.prefab=="dragonflyfurnace" then
                self._max_slots = 4
                self._accepts_stacks = false
                self._use_quantity_matching = false
            end
            return result
        end
        panel.OnSlotChanged = function(self, ...)
            local inst = self._container
            if inst and inst.prefab=="dragonflyfurnace" then
                -- The furnace also contains fuel/gem slots; only 2..5 cook.
                self._slot_data = {}
                local c = inst.replica and inst.replica.container
                if c then
                    for slot=2,5 do
                        local item = c:GetItemInSlot(slot)
                        if item then self._slot_data[slot] = item.prefab end
                    end
                end
            end
            return cooking.WithCookerRules2hm(inst and inst.prefab, changed, self, ...)
        end
        panel.SetPotIngredients = function(self, prefabs, cooker, ...)
            local name = type(cooker)=="table" and cooker.prefab or cooker or self._cooker
            if not (pots[name] or name=="dragonflyfurnace") then
                return ingredients(self, prefabs, cooker, ...)
            end
            local bookname = name=="dragonflyfurnace" and self._cooker or name
            if not prefabs or #prefabs < self._max_slots then
                return cooking.WithCookerRules2hm(name, ingredients, self, prefabs, bookname, ...)
            end
            -- The cookbook deduplicates dishes between devices. Evaluate the
            -- current device's definitions, including its priority and cooker name.
            return cooking.WithCookerRules2hm(name, function()
                local names, tags = matcher.BuildNamesTags(prefabs)
                local matching, highlighted, best = {}, {}, -math.huge
                local book = cooking.recipes[bookname] or cooking.recipes.cookpot or {}
                for prefab, recipe in pairs(book) do
                    if recipe.test and recipe.test(bookname, names, tags) then
                        matching[prefab] = true
                        best = math.max(best, recipe.priority or 0)
                    end
                end
                for prefab in pairs(matching) do
                    local recipe = book[prefab]
                    if (recipe.priority or 0)==best then highlighted[prefab] = true end
                end
                self._pot_prefabs, self._possible_recipes = prefabs, nil
                self._matching_recipes = next(matching) and matching or nil
                self._highlighted_recipes = next(highlighted) and highlighted or nil
                self:RefreshDisplay()
            end)
        end
    end)
end

return M
