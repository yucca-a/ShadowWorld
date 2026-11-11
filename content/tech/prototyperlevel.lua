local TechTree = require("techtree")
if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then table.insert(TechTree.BONUS_TECH, "CARTOGRAPHY") end
-- 科技书和科技等级机制削弱
local function newGetTechBonuses(self)
    local bonus = {}
    for i, v in ipairs(TechTree.BONUS_TECH) do
        bonus[v] = 0
        -- bonus[v] = self[string.lower(v) .. "_bonus"] or nil
        -- local tempbonus = self[string.lower(v) .. "_tempbonus"]
        -- if tempbonus ~= nil then
        --     if bonus[v] ~= nil then
        --         bonus[v] = math.max(bonus[v], tempbonus)
        --     else
        --         bonus[v] = tempbonus
        --     end
        -- end
    end
    return bonus
end
local function CopyTechTrees(src, dest) for i, v in ipairs(TechTree.AVAILABLE_TECH) do dest[v] = src[v] or 0 end end
local PROTOTYPER_TAGS = {"prototyper"}
local function SortByRecName(a, b)
    if a.recname == b.recname then
        return a.amount < b.amount
    end
    return a.recname < b.recname
end
local function newEvaluateTechTrees(self)
	local enabled = self.inst.player_classified == nil or self.inst.player_classified.iscraftingenabled:value()
    local pos = self.inst:GetPosition()

    local ents
	if self.override_current_prototyper then
		if enabled
			and self.override_current_prototyper:IsValid()
			and self.override_current_prototyper:HasTags(PROTOTYPER_TAGS) 
			and not self.override_current_prototyper:HasOneOfTags(self.exclude_tags)
			and (self.override_current_prototyper.components.prototyper.restrictedtag == nil or self.inst:HasTag(self.override_current_prototyper.components.prototyper.restrictedtag))
			and self.override_current_prototyper.components.prototyper:CanUsePrototyper(self.inst)
			then

			ents = {self.override_current_prototyper}
		else
			self.override_current_prototyper = nil
		end
	end
	
	if enabled and ents == nil then
		ents = TheSim:FindEntities(pos.x, pos.y, pos.z, TUNING.RESEARCH_MACHINE_DIST, PROTOTYPER_TAGS, self.exclude_tags)
	end

	CopyTechTrees(self.accessible_tech_trees, self.old_accessible_tech_trees)
    local old_station_recipes = self.station_recipes
    local old_prototyper = self.current_prototyper
    self.current_prototyper = nil
    self.station_recipes = {}

    local prototyper_active = false
	if ents then
		for i, v in ipairs(ents) do
			if v.components.prototyper and (v.components.prototyper.restrictedtag == nil or self.inst:HasTag(v.components.prototyper.restrictedtag)) then
				if not prototyper_active then
					--activate the first machine in the list. This will be the one you're closest to.
					v.components.prototyper:TurnOn(self.inst)

					--prototyper:GetTrees() returns a deepcopy, which we no longer want
					CopyTechTrees(v.components.prototyper.trees, self.accessible_tech_trees)

					if v.components.craftingstation then
						local recs = v.components.craftingstation:GetRecipes(self.inst)
						for _, recname in ipairs(recs) do
							local recipe = GetValidRecipe(recname)
							if recipe and recipe.nounlock then
								--only nounlock recipes can be unlocked via crafting station
                                local has_unlocked_skin = false
                                if recipe.unlocks_from_skin and (recipe.unlocks_from_skin == SKINUNLOCKS.CRAFTINGSTATION) and self.inst.isplayer then
                                    local prefabskins = PREFAB_SKINS[recipe.product]
                                    if prefabskins ~= nil then
                                        for _, skin in ipairs(prefabskins) do
                                            if TheInventory:CheckClientOwnership(self.inst.userid, skin) then
                                                has_unlocked_skin = true
                                                break
                                            end
                                        end
                                    end
                                else
                                    has_unlocked_skin = true
                                end
                                self.station_recipes[recname] = v.components.craftingstation:GetRecipeCraftingLimit(recipe.name) or has_unlocked_skin or nil
							end
						end
					end

					prototyper_active = true
					self.current_prototyper = v
				else
					--you've already activated a machine. Turn all the other machines off.
					v.components.prototyper:TurnOff(self.inst)
				end
            end
        end
    end

    --V2C: Hacking giftreceiver logic in here so we do
    --     not have to duplicate the same search logic
    if self.inst.components.giftreceiver ~= nil then
        self.inst.components.giftreceiver:SetGiftMachine(
            self.current_prototyper ~= nil and
            self.current_prototyper:HasTag("giftmachine") and
            CanEntitySeeTarget(self.inst, self.current_prototyper) and
            self.inst.components.inventory.isopen and --ignores .isvisible, as long as it's .isopen
            self.current_prototyper or
            nil)
    end

    --add any character specific bonuses to your current tech levels.
	CopyTechTrees(self.accessible_tech_trees, self.accessible_tech_trees_no_temp)
    if not prototyper_active then
        for i, v in ipairs(TechTree.AVAILABLE_TECH) do
            local bonus = self[TechTree.AVAILABLE_TECH_BONUS[v] or string.lower(v).."_bonus"] or 0
            local tempbonus = self[TechTree.AVAILABLE_TECH_TEMPBONUS[v] or string.lower(v).."_tempbonus"] or 0
            self.accessible_tech_trees_no_temp[v] = bonus
            self.accessible_tech_trees[v] = math.max(tempbonus, bonus)
        end
    else
        for i, v in ipairs(TechTree.BONUS_TECH) do
            local bonus = self[TechTree.AVAILABLE_TECH_BONUS[v] or string.lower(v).."_bonus"] or 0
            local tempbonus = self[TechTree.AVAILABLE_TECH_TEMPBONUS[v] or string.lower(v).."_tempbonus"] or 0
            self.accessible_tech_trees_no_temp[v] = math.max(self.accessible_tech_trees_no_temp[v], bonus)
            self.accessible_tech_trees[v] = math.max(self.accessible_tech_trees[v], tempbonus, bonus)
        end
    end

    if old_prototyper ~= nil and
        old_prototyper ~= self.current_prototyper and
        old_prototyper.components.prototyper ~= nil and
        old_prototyper.entity:IsValid() then
        old_prototyper.components.prototyper:TurnOff(self.inst)
    end

    local trees_changed = false

    local craftinglimitdata
    local lostcraftinglimitdata
    for recname, amount in pairs(self.station_recipes) do
        if old_station_recipes[recname] then
            if old_station_recipes[recname] ~= amount then
                trees_changed = true
            end
            old_station_recipes[recname] = nil
        else
            self.inst.replica.builder:AddRecipe(recname)
            trees_changed = true
        end
        if amount ~= true then -- We have a max number allowed, add it.
            if craftinglimitdata == nil then
                craftinglimitdata = {}
            end
            table.insert(craftinglimitdata, {recname = recname, amount = amount,})
        end
    end

    if next(old_station_recipes) ~= nil then
        for recname, amount in pairs(old_station_recipes) do
            self.inst.replica.builder:RemoveRecipe(recname)
            if amount ~= true then
                lostcraftinglimitdata = true
            end
        end
		trees_changed = true
    end

    if craftinglimitdata then
        table.sort(craftinglimitdata, SortByRecName)
        for i = 1, CRAFTINGSTATION_LIMITED_RECIPES_COUNT do
            local data = craftinglimitdata[i]
            if data then
                self.inst.replica.builder:SetRecipeCraftingLimit(i, data.recname, data.amount)
            else
                self.inst.replica.builder:SetRecipeCraftingLimit(i, nil, nil)
            end
        end
    elseif lostcraftinglimitdata then
        for i = 1, CRAFTINGSTATION_LIMITED_RECIPES_COUNT do
            self.inst.replica.builder:SetRecipeCraftingLimit(i, nil, nil)
        end
    end

    if not trees_changed then
        for k, v in pairs(self.old_accessible_tech_trees) do
            if v ~= self.accessible_tech_trees[k] then
                trees_changed = true
                break
            end
        end
		--V2C: not required anymore; both trees should have the same keys now
        --[[if not trees_changed then
            for k, v in pairs(self.accessible_tech_trees) do
                if v ~= self.old_accessible_tech_trees[k] then
                    trees_changed = true
                    break
                end
            end
        end]]
    end

    if trees_changed then
        self.inst:PushEvent("techtreechange", { level = self.accessible_tech_trees })
        self.inst.replica.builder:SetTechTrees(self.accessible_tech_trees)
    end

	if self.override_current_prototyper ~= nil then
		if self.override_current_prototyper ~= self.current_prototyper then
			self.override_current_prototyper = nil
		elseif self.override_current_prototyper ~= old_prototyper then
            if not self.override_current_prototyper.components.prototyper or not self.override_current_prototyper.components.prototyper.dontopencraftingmenuonevaulatetechtrees then
			    self.inst.replica.builder:OpenCraftingMenu()
            end
		end
	end
end

local function newKnowsRecipe(self, recipe, ignore_tempbonus, cached_tech_trees)
    if type(recipe) == "string" then recipe = GetValidRecipe(recipe) end

    if recipe == nil then return false end
    if self.freebuildmode then
        return true
    elseif recipe.builder_tag ~= nil and not self.inst:HasTag(recipe.builder_tag) then
        return false
    elseif recipe.no_builder_tag ~= nil and self.inst:HasTag(recipe.no_builder_tag) then
        return false
    elseif recipe.builder_skill ~= nil and not (self.inst.components.skilltreeupdater and
        self.inst.components.skilltreeupdater:IsActivated(recipe.builder_skill)) then
        return false
    elseif recipe.no_builder_skill ~= nil and self.inst.components.skilltreeupdater and
        self.inst.components.skilltreeupdater:IsActivated(recipe.no_builder_skill) then
        return false
    elseif self.station_recipes[recipe.name] or table.contains(self.recipes, recipe.name) then
        return true
    end

    if cached_tech_trees ~= nil and cached_tech_trees[recipe.level] ~= nil then
        return cached_tech_trees[recipe.level]
    end

    for i, v in ipairs(TechTree.AVAILABLE_TECH) do
        local bonuskey = (TechTree.AVAILABLE_TECH_BONUS and TechTree.AVAILABLE_TECH_BONUS[v]) or (string.lower(v) .. "_bonus")
        local tempkey = (TechTree.AVAILABLE_TECH_TEMPBONUS and TechTree.AVAILABLE_TECH_TEMPBONUS[v]) or (string.lower(v) .. "_tempbonus")
        local bonus = self[bonuskey] or 0
        local tempbonus = ignore_tempbonus and 0 or (self[tempkey] or 0)
        if (recipe.level[v] or 0) > math.max(bonus, tempbonus) then
            if cached_tech_trees ~= nil then cached_tech_trees[recipe.level] = false end
            return false
        end
    end

    if cached_tech_trees ~= nil then cached_tech_trees[recipe.level] = true end
    return true
end

AddComponentPostInit("builder", function(self)
    self.old_accessible_tech_trees = self.old_accessible_tech_trees or {}
    -- 万物百科读一次给三次机会,且能获得制图桌科技
    local GiveTempTechBonus = self.GiveTempTechBonus
    self.GiveTempTechBonus = function(self, tech, ...)
        if tech then tech.CARTOGRAPHY = TUNING.FUNCTIONAL_MEDAL_IS_OPEN and 2 or nil end
        GiveTempTechBonus(self, tech, ...)
        if tech and self.temptechbonus_count then self.temptechbonus_count = self.temptechbonus_count + 2 end
    end
    self.GetTechBonuses = newGetTechBonuses
    self.EvaluateTechTrees = newEvaluateTechTrees
    self.KnowsRecipe = newKnowsRecipe
    -- 使用万物百科不再能解锁科技配方了
    local oldConsumeTempTechBonuses = self.ConsumeTempTechBonuses
    self.ConsumeTempTechBonuses = function(self, ...)
        self.disableunclockadd2hm = true
        self.inst:DoTaskInTime(0, function() self.disableunclockadd2hm = nil end)
        return oldConsumeTempTechBonuses(self, ...)
    end
    local oldUnlockRecipe = self.UnlockRecipe
    self.UnlockRecipe = function(self, ...)
        if self.disableunclockadd2hm then return end
        return oldUnlockRecipe(self, ...)
    end
    local oldAddRecipe = self.AddRecipe
    self.AddRecipe = function(self, ...)
        if self.disableunclockadd2hm then return end
        return oldAddRecipe(self, ...)
    end
    local oldKnowsRecipe = self.KnowsRecipe
    self.KnowsRecipe = function(self, recipe, ignore_tempbonus, ...)
        return oldKnowsRecipe(self, recipe, ignore_tempbonus, ...) or (recipe and recipe.name and self:IsBuildBuffered(recipe.name))
    end
end)
local function newReplicaGetTechBonuses(self)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:GetTechBonuses()
    elseif self.classified ~= nil then
        local bonus = {}
        for i, v in ipairs(TechTree.BONUS_TECH) do
            bonus[v] = 0
            -- local bonus_netvar = self.classified[string.lower(v) .. "bonus"]
            -- bonus[v] = bonus_netvar ~= nil and bonus_netvar:value() or nil
            -- local tempbonus_netvar = self.classified[string.lower(v) .. "tempbonus"]
            -- if tempbonus_netvar ~= nil then
            --     if bonus[v] ~= nil then
            --         bonus[v] = math.max(bonus[v], tempbonus_netvar:value())
            --     else
            --         bonus[v] = tempbonus_netvar:value()
            --     end
            -- end
        end
        return bonus
    end
    return {}
end
local function newReplicaKnowsRecipe(self, recipe, ignore_tempbonus, cached_tech_trees)
    if type(recipe) == "string" then recipe = GetValidRecipe(recipe) end

    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:KnowsRecipe(recipe, ignore_tempbonus, cached_tech_trees)
    elseif self.classified ~= nil then
        if recipe ~= nil then
            if self.classified.isfreebuildmode:value() then
                return true
            elseif recipe.builder_tag ~= nil and not self.inst:HasTag(recipe.builder_tag) then
                return false
            elseif recipe.no_builder_tag ~= nil and self.inst:HasTag(recipe.no_builder_tag) then
                return false
            elseif recipe.builder_skill ~= nil and not (self.inst.components.skilltreeupdater and
                self.inst.components.skilltreeupdater:IsActivated(recipe.builder_skill)) then
                return false
            elseif recipe.no_builder_skill ~= nil and self.inst.components.skilltreeupdater and
                self.inst.components.skilltreeupdater:IsActivated(recipe.no_builder_skill) then
                return false
            elseif self.classified.recipes[recipe.name] ~= nil and self.classified.recipes[recipe.name]:value() then
                return true
            elseif (self.classified.bufferedbuilds[recipe.name] ~= nil and self.classified.bufferedbuilds[recipe.name]:value()) or
                self.classified._bufferedbuildspreview[recipe.name] == true then
                return true
            end

            if cached_tech_trees ~= nil and cached_tech_trees[recipe.level] ~= nil then
                return cached_tech_trees[recipe.level]
            end

            for i, v in ipairs(TechTree.AVAILABLE_TECH) do
                local bonuskey = (TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED and TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[v]) or (string.lower(v) .. "bonus")
                local tempkey = (TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED and TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[v]) or (string.lower(v) .. "tempbonus")
                local bonus = self.classified[bonuskey]
                local tempbonus = not ignore_tempbonus and self.classified[tempkey] or nil
                if (recipe.level[v] or 0) > math.max(
                        (bonus ~= nil and bonus:value() or 0),
                        (tempbonus ~= nil and tempbonus:value() or 0)) then
                    if cached_tech_trees ~= nil then cached_tech_trees[recipe.level] = false end
                    return false
                end
            end

            if cached_tech_trees ~= nil then cached_tech_trees[recipe.level] = true end
            return true
        end
    end
    return false
end

AddClassPostConstruct("components/builder_replica", function(self)
    self.GetTechBonuses = newReplicaGetTechBonuses
    self.KnowsRecipe = newReplicaKnowsRecipe
end)
local function newGetHintTextForRecipe(self, player, recipe)
    local validmachines = {}
    local adjusted_level = deepcopy(recipe.level)

    for k, v in pairs(TUNING.PROTOTYPER_TREES) do
        local canbuild = CanPrototypeRecipe(adjusted_level, v)
        if canbuild then table.insert(validmachines, {TREE = tostring(k), SCORE = 0}) end
    end

    if #validmachines > 0 then
        if #validmachines == 1 then
            -- There's only once machine is valid. Return that one.
            return "NEEDS" .. validmachines[1].TREE
        end

        -- There's more than one machine that gives the valid tech level! We have to find the "lowest" one (taking bonus into account).
        for k, v in pairs(validmachines) do
            for rk, rv in pairs(adjusted_level) do
                local prototyper_level = TUNING.PROTOTYPER_TREES[v.TREE][rk]
                if prototyper_level and (rv > 0 or prototyper_level > 0) then
                    if rv == prototyper_level then
                        -- recipe level matches, add 1 to the score
                        v.SCORE = v.SCORE + 1
                    elseif rv < prototyper_level then
                        -- recipe level is less than prototyper level, remove 1 per level the prototyper overshot the recipe
                        v.SCORE = v.SCORE - (prototyper_level - rv)
                    end
                end
            end
        end

        table.sort(validmachines, function(a, b) return (a.SCORE) > (b.SCORE) end)

        return "NEEDS" .. validmachines[1].TREE
    end

    return recipe.hint_msg or "CANTRESEARCH"
end
AddClassPostConstruct("widgets/redux/craftingmenu_details", function(self) self._GetHintTextForRecipe = newGetHintTextForRecipe end)
