local TechTree = require("techtree")
-- 原型工具和制作站科技削弱
AddRecipePostInit("researchlab", function(inst) table.insert(inst.ingredients, Ingredient("gears", 1)) end)
AddRecipePostInit("researchlab2", function(inst) table.insert(inst.ingredients, Ingredient("gears", 4)) end)
AddRecipePostInit("researchlab4", function(inst) table.insert(inst.ingredients, Ingredient("greengem", 1)) end)
AddRecipePostInit("researchlab3", function(inst) table.insert(inst.ingredients, Ingredient("shadowheart", 1)) end)
AddRecipePostInit("seafaring_prototyper", function(inst) table.insert(inst.ingredients, Ingredient("driftwood_log", 8)) end)
AddRecipePostInit("tacklestation", function(inst) table.insert(inst.ingredients, Ingredient("slurtle_shellpieces", 4)) end)
AddRecipePostInit("cartographydesk", function(inst) table.insert(inst.ingredients, Ingredient("stash_map", 1)) end)
AddRecipePostInit("sculptingtable", function(inst) table.insert(inst.ingredients, Ingredient("fossil_piece", 1)) end)
-- 无限制开礼物
AddComponentPostInit("giftreceiver", function(self)
    self.giftmachine = TheWorld
    self.SetGiftMachine = nilfn
end)
-- 蓝图不可作祟
if GetModConfigData("Cartographer's Desk Make Blueprint") then AddPrefabPostInit("blueprint", function(inst) inst:AddTag("haunted") end) end
-- 锯马直接解锁
AddRecipePostInit("carpentry_station", function(inst)
    table.insert(inst.ingredients, Ingredient("gears", 2))
    inst.level = TechTree.Create()
end)
-- 优化科技研究动作
AddClassPostConstruct("widgets/redux/craftingmenu_widget", function(self)
    local specialtechs = {seafaring_prototyper = CRAFTING_FILTERS.SEAFARING.name, tacklestation = CRAFTING_FILTERS.FISHING.name}
    local researchtechlevels = {
        researchlab = TUNING.PROTOTYPER_TREES.SCIENCEMACHINE,
        researchlab2 = TUNING.PROTOTYPER_TREES.ALCHEMYMACHINE,
        researchlab3 = TUNING.PROTOTYPER_TREES.SHADOWMANIPULATOR,
        researchlab4 = TUNING.PROTOTYPER_TREES.PRESTIHATITATOR,
        turfcraftingstation = TUNING.PROTOTYPER_TREES.TURFCRAFTING,
        bookstation = TUNING.PROTOTYPER_TREES.BOOKCRAFT,
        carpentry_station = TUNING.PROTOTYPER_TREES.CARPENTRY_STATION,
        tacklestation = TUNING.PROTOTYPER_TREES.FISHING,
        seafaring_prototyper = TUNING.PROTOTYPER_TREES.SEAFARING_STATION
    }
    local sortedrecipes, seenrecipes = {}, {}
    local function addrecipe(name)
        if name ~= nil and not seenrecipes[name] then
            seenrecipes[name] = true
            sortedrecipes[#sortedrecipes + 1] = name
        end
    end
    for _, v in pairs(CRAFTING_FILTERS) do
        if v and v.recipes then
            for _, k in ipairs(FunctionOrValue(v.recipes)) do addrecipe(k) end
        end
    end
    for k in pairs(AllRecipes) do addrecipe(k) end
    local function whenopenprototyper(self, forceprefab)
        local builder = self.owner ~= nil and self.owner.replica.builder or nil
        local prototyper = builder ~= nil and builder:GetCurrentPrototyper() or nil
        local prefab = forceprefab or (prototyper ~= nil and prototyper.prefab)
        if prefab ~= nil and self._last_open_prefab == prefab and self._last_open_time == GetTime() then
            return
        end
        self._last_open_prefab = prefab
        self._last_open_time = GetTime()
        local crafting_station_def = prototyper ~= nil and PROTOTYPER_DEFS[prototyper.prefab] or nil
        local at_crafting_station = crafting_station_def ~= nil and crafting_station_def.is_crafting_station
        if (prototyper and prototyper.prefab and not at_crafting_station) or forceprefab then
            self.prototyperprefab2hm = forceprefab or prototyper.prefab
            local text = crafting_station_def ~= nil and crafting_station_def.filter_text or STRINGS.NAMES[string.upper(self.prototyperprefab2hm)] or
                             self.prototyperprefab2hm
            self.crafting_station_filter:SetHoverText(text)
            self.search_box.textbox.prompt:SetString(text)
            if crafting_station_def ~= nil then
                self.crafting_station_filter.filter_img:SetTexture(crafting_station_def.icon_atlas, crafting_station_def.icon_image)
            else
                local recipe = AllRecipes[self.prototyperprefab2hm]
                if recipe then
                    local image = recipe.imagefn ~= nil and recipe.imagefn() or recipe.image
                    self.crafting_station_filter.filter_img:SetTexture(recipe:GetAtlas(), image, image ~= recipe.image and recipe.image or nil)
                else
                    self.crafting_station_filter.filter_img:SetTexture(resolvefilepath(CRAFTING_ICONS_ATLAS), "filter_none.tex")
                end
            end
            self.crafting_station_filter.filter_img:ScaleToSize(54, 54)
            self.crafting_station_filter:Show()
            if specialtechs[self.prototyperprefab2hm] then
                self:SelectFilter(specialtechs[self.prototyperprefab2hm], false)
                if self.recipe_grid.dirty then self:UpdateRecipeGrid(false) end
                return
            end
            local techlevel = researchtechlevels[self.prototyperprefab2hm]
            if techlevel == nil or (self.prototyperprefab2hm == "bookstation" and GetModConfigData("role_nerf") and GetModConfigData("wickerbottom")) then
                if not (builder and builder.classified) then return end
                techlevel = {}
                for i, v in ipairs(TechTree.AVAILABLE_TECH) do
                    local vlevel = builder.classified[string.lower(v) .. "level"] or nil
                    techlevel[v] = vlevel ~= nil and vlevel:value() or 0
                end
            end
            if self.current_filter_name ~= nil and self.filter_buttons[self.current_filter_name] ~= nil then
                self.filter_buttons[self.current_filter_name].button:Unselect()
            end
            self.filtered_recipes = {}
            for _, recipe_name in ipairs(sortedrecipes) do
                local data = self.crafting_hud.valid_recipes[recipe_name]
                if data and data.meta and data.meta.build_state ~= "hide" and data.recipe and data.recipe.level then
                    local result
                    for key, value in pairs(data.recipe.level) do
                        if value ~= 0 then
                            if techlevel[key] ~= value then
                                result = false
                                break
                            else
                                result = true
                            end
                        end
                    end
                    if result == true then table.insert(self.filtered_recipes, data) end
                end
            end
            local old_scroll = self.recipe_grid.current_scroll_pos
            local old_target = self.recipe_grid.target_scroll_pos
            self:UpdateRecipeGrid(self.focus and not TheFrontEnd.tracking_mouse)
            if self.crafting_hud:IsCraftingOpen() and old_scroll ~= nil then
                self.recipe_grid.current_scroll_pos = old_scroll
                self.recipe_grid.target_scroll_pos = old_target or old_scroll
                self.recipe_grid:RefreshView()
            end
            self.current_filter_name = nil
        else
            self.prototyperprefab2hm = nil
        end
    end
    self.whenopenprototyper = whenopenprototyper
    if self.recipe_grid ~= nil then
        self.recipe_grid.custom_focus_check = function()
            return self.crafting_hud ~= nil and self.crafting_hud:IsCraftingOpen()
        end
    end
    local oldUpdateRecipeGrid = self.UpdateRecipeGrid
    if oldUpdateRecipeGrid ~= nil then
        self.UpdateRecipeGrid = function(self, set_focus)
            local old_scroll = self.recipe_grid.current_scroll_pos
            local old_target = self.recipe_grid.target_scroll_pos
            oldUpdateRecipeGrid(self, set_focus)
            -- Near a prototyper the station filter can rebuild the grid from several
            -- call paths. Keep the player's scroll position unless focus is requested.
            if not set_focus and self.prototyperprefab2hm ~= nil
                and self.crafting_hud:IsCraftingOpen() and old_scroll ~= nil then
                self.recipe_grid.current_scroll_pos = old_scroll
                self.recipe_grid.target_scroll_pos = old_target or old_scroll
                self.recipe_grid:RefreshView()
            end
        end
    end
    local OnCraftingMenuOpen = self.OnCraftingMenuOpen
    self.OnCraftingMenuOpen = function(self, ...)
        local ishudopen = self.crafting_hud:IsCraftingOpen()
        OnCraftingMenuOpen(self, ...)
        if not ishudopen or #self.filtered_recipes == 0 then whenopenprototyper(self) end
    end
    local oldOnControl = self.OnControl
    if oldOnControl ~= nil then
        self.OnControl = function(self, control, down)
            -- When a recipe cell has focus, core skips recipe_grid:OnControl, so the
            -- mouse wheel never reaches TrueScrollList. Forward wheel events here.
            if down and self.crafting_hud ~= nil and self.crafting_hud:IsCraftingOpen()
                and self.recipe_grid ~= nil
                and (control == CONTROL_SCROLLFWD or control == CONTROL_SCROLLBACK) then
                if self.recipe_grid:OnControl(control, down) then
                    return true
                end
            end
            return oldOnControl(self, control, down)
        end
    end
    if self.crafting_station_filter and self.crafting_station_filter.button then
        local onclick = self.crafting_station_filter.button.onclick
        self.crafting_station_filter.button.onclick = function(...)
            if self.prototyperprefab2hm then
                whenopenprototyper(self, self.prototyperprefab2hm)
            elseif onclick then
                onclick(...)
            end
        end
    end
end)
AddClassPostConstruct("screens/playerhud", function(self)
    local OpenCrafting = self.OpenCrafting
    self.OpenCrafting = function(self, ...)
        local ishudopen = self:IsCraftingOpen()
        OpenCrafting(self, ...)
        if ishudopen and self.controls and self.controls.craftingmenu and self.controls.craftingmenu.craftingmenu and
            self.controls.craftingmenu.craftingmenu.whenopenprototyper and self.controls.craftingmenu.craftingmenu then
            self.controls.craftingmenu.craftingmenu.whenopenprototyper(self.controls.craftingmenu.craftingmenu)
        end
    end
end)
