local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("warly")

-- 沃利右键自身园艺学简编
if GetModConfigData("Warly Right Self Action") == true then
    AddReadBookRightSelfAction("warly", "book_horticulture", GetModConfigData("Warly Right Self Horticulture Abridged"),
                               STRINGS.RECIPE_DESC.BOOK_HORTICULTURE)
end

-- 沃利使用新鲜武器增伤
if GetModConfigData("Warly Use Perishable Weapon") then
    local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
        if mount == nil then
            if weapon ~= nil and weapon.components.perishable then
                if weapon.components.perishable:IsSpoiled() then
                    return 0.75
                elseif weapon.components.perishable:IsStale() then
                    return 1.25
                else
                    return 1.75
                end
            end
        end
        return 1
    end
    AddPrefabPostInit("warly", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.combat.customdamagemultfn then
            inst.components.combat.customdamagemultfn = CustomCombatDamage
        else
            local old = inst.components.combat.customdamagemultfn
            inst.components.combat.customdamagemultfn = function(...) return (old(...) or 1) * CustomCombatDamage(...) end
        end
    end)
end

-- 沃利吃食物双倍回血回理智
if GetModConfigData("Warly Eat Food Double Health Sanity") then
    AddPrefabPostInit("warly", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.eater ~= nil then inst.components.eater:SetAbsorptionModifiers(3, 0.75, 2.5) end
    end)
end

-- 沃利重复食物仅损失理智但有额外理智损益,负面收益减半
if GetModConfigData("Warly Food Memory Only Sanity") then
    AddPrefabPostInit("warly", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.foodmemory then
            inst.components.foodmemory.GetFoodMultiplier2hm = inst.components.foodmemory.GetFoodMultiplier
            inst.components.foodmemory.GetFoodMultiplier = function() return 1 end
        end
        if inst.components.eater then
            local _custom_stats_mod_fn = inst.components.eater.custom_stats_mod_fn
            inst.components.eater.custom_stats_mod_fn = function(inst, health_delta, hunger_delta, sanity_delta, food, ...)
                if _custom_stats_mod_fn then
                    health_delta, hunger_delta, sanity_delta = _custom_stats_mod_fn(inst, health_delta, hunger_delta, sanity_delta, food, ...)
                end
                local base_mult = inst.components.foodmemory and inst.components.foodmemory.GetFoodMultiplier2hm and
                                      inst.components.foodmemory:GetFoodMultiplier2hm(food.prefab) or 1
                if health_delta < 0 then health_delta = health_delta / 2 end
                if hunger_delta < 0 then hunger_delta = hunger_delta / 2 end
                if sanity_delta < 0 then
                    sanity_delta = sanity_delta / 2
                else
                    sanity_delta = sanity_delta * base_mult
                end
                if hardmode and base_mult < 1 then sanity_delta = sanity_delta - 50 * (1 - base_mult) end
                return health_delta, hunger_delta, sanity_delta
            end
        end
    end)
end

-- 沃利右键自身烹饪
if GetModConfigData("Warly Right Self Action") == -1 then
	local function harvestcookpot(inst)
	if not inst:HasTag("playerghost") and inst.pot2hm and inst.pot2hm:IsValid() and inst.pot2hm.components.stewer then
		inst.pot2hm.components.stewer:Harvest(inst)
	end
	end
	local function processcookpot(inst, pot)
	inst.pot2hm = pot
	pot.master2hm = inst
	RemovePhysicsColliders(pot)
	pot:RemoveComponent("workable")
	pot:RemoveComponent("hauntable")
	pot:RemoveComponent("burnable")
	pot:RemoveComponent("propagator")
	pot:RemoveComponent("portablestructure")
	pot:AddTag("NOCLICK")
	pot:RemoveTag("structure")
	pot.Physics:SetActive(false)
	pot.DynamicShadow:Enable(false)
	pot.MiniMapEntity:SetEnabled(false)
	pot.components.container.skipautoclose = true
	pot:Hide()
	inst:AddChild(pot)
	pot:AddTag("NOBLOCK")
	pot.persists = false
	if pot.components.stewer and pot.components.stewer.ondonecooking then
		local ondonecooking = pot.components.stewer.ondonecooking
		pot.components.stewer.ondonecooking = function(pot, ...)
		ondonecooking(pot, ...)
		if not inst:HasTag("playerghost") then
			if inst.components.talker then inst.components.talker:Say((TUNING.isCh2hm and "美味已成~" or "Perfect Cook~")) end
			inst:DoTaskInTime(0, harvestcookpot)
			end
		end
	end
	end
	local function OnSave(inst, data) data.pot = InGamePlay() and (inst.pot2hm and inst.pot2hm:IsValid() and inst.pot2hm:GetPersistData() or nil) or data.pot end
	local function initcookpot(inst)
	if not (inst.pot2hm and inst.pot2hm:IsValid()) then
		local pot = SpawnPrefab("portablecookpot")
		if pot then
			processcookpot(inst, pot)
			if inst.components.persistent2hm.data.pot then pot:SetPersistData(inst.components.persistent2hm.data.pot) end
		end
	end
	if inst.components.persistent2hm.data.pot then inst.components.persistent2hm.data.pot = nil end
	end
	AddPrefabPostInit("warly", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.persistent2hm == nil then inst:AddComponent("persistent2hm") end
	SetOnSave2hm(inst, OnSave)
	inst:DoTaskInTime(0, initcookpot)
	end)
	AddRightSelfAction("warly", 1, "dolongaction", nil, function(act)
	if act.doer and act.doer.prefab == "warly" and act.doer.pot2hm then
		local pot = act.doer.pot2hm
		if pot and pot:IsValid() then
			if pot.components.stewer and not pot.components.stewer:IsCooking() then
				if pot.components.stewer:IsDone() then
					return pot.components.stewer:Harvest(act.doer)
				elseif pot.components.container and act.doer == pot.master2hm then
					if pot.components.container.openlist[act.doer] then
						pot.components.container:Close(act.doer)
					else
						pot.components.container:Open(act.doer)
					end
					return true
				end
			end
		else
			act.doer:DoTaskInTime(0, initcookpot)
		end
	end
	end, STRINGS.NAMES.PORTABLECOOKPOT_ITEM, nil, STRINGS.CHARACTERS.WARLY.DESCRIBE.PORTABLECOOKPOT_ITEM.COOKING_LONG)
	if hardmode then
        for i = #TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WARLY, 1, -1 do
            if TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WARLY[i] == "portablecookpot_item" then
                table.remove(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WARLY, i)
                break
            end
        end
	end
end

-- 沃利每天免费烹饪一次
if GetModConfigData("Warly Free Cook Per Day") then
    AddComponentPostInit("stewer", function(self)
        local StartCooking = self.StartCooking
        self.StartCooking = function(self, doer, ...)
            if self.targettime == nil and not self.multi2hm and doer and doer:IsValid() and doer.prefab == "warly" and doer.components.inventory and
                doer.components.persistent2hm and (doer.components.persistent2hm.data.freecook or -1) < TheWorld.state.cycles and self.inst.components.container and
                -- 2025.7.9 melon:兼容5格锅 (== 4)->(==4 or ==5)
                (self.inst.components.container.numslots == 4 or self.inst.components.container.numslots == 5) and not self.inst.components.container.acceptsstacks and not self.inst:HasTag("spicer") then
                doer.components.persistent2hm.data.freecook = TheWorld.state.cycles
                local DestroyContents = self.inst.components.container.DestroyContents
                self.inst.components.container.DestroyContents = function(container, ...)
                    local item = container:RemoveItem(container.slots[(hardmode and math.random() < 0.35) and 2 or 1])
                    if item then doer.components.inventory:GiveItem(item) end
                    if doer.components.talker then doer.components.talker:Say((TUNING.isCh2hm and "巧夺天工~" or "Free a ingredient~")) end
                    DestroyContents(container, ...)
                end
                StartCooking(self, doer, ...)
                if doer.components.sanity then doer.components.sanity:DoDelta(TUNING.SANITY_LARGE) end
                self.inst.components.container.DestroyContents = DestroyContents
                return
            end
            StartCooking(self, doer, ...)
        end
    end)
end

-- 沃利收集食谱升级
if GetModConfigData("Warly Food Collect") then
    local function OnLoad(inst, data)
        if data and data.cooklist2hm and data.sanity2hm then
            inst.cooklist2hm = data.cooklist2hm
            inst.components.sanity.max = inst.components.sanity.max + #inst.cooklist2hm
            inst.components.sanity.current = data.sanity2hm
        end
    end
    local function OnSave(inst, data)
        data.cooklist2hm = inst.cooklist2hm
        data.sanity2hm = inst.components.sanity.current
    end
    local function OnLearnCookbookRecipe(inst, data)
        if data and data.product and not table.contains(inst.cooklist2hm, data.product) and inst.components.sanity then
            table.insert(inst.cooklist2hm, data.product)
            inst.components.sanity.max = inst.components.sanity.max + 1
            inst.components.sanity:DoDelta(1)
        end
    end
    AddPrefabPostInit("warly", function(inst)
        if not TheWorld.ismastersim then return end
        inst.cooklist2hm = {}
        SetOnLoad(inst, OnLoad)
        SetOnSave(inst, OnSave)
        inst:ListenForEvent("learncookbookrecipe", OnLearnCookbookRecipe)
    end)
end