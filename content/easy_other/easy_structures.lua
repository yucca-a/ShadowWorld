----------------------------[建筑(可放置到地上的)]-------------------------------
--------------------------------------------------------------------------------
local hardmode = TUNING.hardmode2hm

-- Recipe-preview mods can temporarily set a client's ismastersim flag. Their
-- temporary entities must never mutate or broadcast the server's station index.
local function UnregisterReskinPrototyper2hm(inst)
    if not TheNet:GetIsServer() or not TheWorld or not TheWorld.ismastersim or
        not TheShard or inst.persist == false or inst.persists == false then return end
    local persistent = TheWorld.components and TheWorld.components.persistent2hm
    local data = persistent and persistent.data
    local stations = data and data.reskinprototyper2hm
    if type(stations) ~= "table" then return end
    local worldid, id = tostring(TheShard:GetShardId()), tostring(inst.GUID)
    local entries = stations[worldid]
    if type(entries) ~= "table" or entries[id] == nil then return end
    entries[id] = nil
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_prototyper_update"),
        nil, nil, DataDumper(stations, nil, true))
end

-- 泰拉瑞亚宝箱彩蛋
-- 2025.3.16 melon:加个开关,，单纯加了个if
if GetModConfigData("Terra Easter egg") then
    if not GetModConfigData("daywalker2") then
        AddPrefabPostInit("terrariumchest", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.container ~= nil then inst.components.container:EnableInfiniteStackSize(true) end
            if inst.components.lootdropper ~= nil then inst.components.lootdropper:SetLoot({"chestupgrade_stacksize"}) end
        end)
    end
    
	local function ShouldCollapse(inst)
		if inst.components.container and inst.components.container.infinitestacksize then
			--NOTE: should already have called DropEverything(nil, true) (worked or deconstructed)
			--      so everything remaining counts as an "overstack"
			local overstacks = 0
			for k, v in pairs(inst.components.container.slots) do
				local stackable = v.components.stackable
				if stackable then
					overstacks = overstacks + math.ceil(stackable:StackSize() / (stackable.originalmaxsize or stackable.maxsize))
					if overstacks >= TUNING.COLLAPSED_CHEST_EXCESS_STACKS_THRESHOLD then
						return true
					end
				end
			end
		end
		return false
	end
	local function ConvertToCollapsed(inst, droploot)
		local x, y, z = inst.Transform:GetWorldPosition()
		if droploot then
			local fx = SpawnPrefab("collapse_small")
			fx.Transform:SetPosition(x, y, z)
			fx:SetMaterial("wood")
			inst.components.lootdropper.min_speed = 2.25
			inst.components.lootdropper.max_speed = 2.75
			inst.components.lootdropper:DropLoot()
			inst.components.lootdropper.min_speed = nil
			inst.components.lootdropper.max_speed = nil
		end

		inst.components.container:Close()
		inst.components.workable:SetWorkLeft(2)

		local pile = SpawnPrefab("collapsed_dragonflychest")
		pile.Transform:SetPosition(x, y, z)
		pile:SetChest(inst)
	end
    AddPrefabPostInit("dragonflychest", function(inst) -- 2025.4.13 melon:升级龙蝇箱不掉启迪碎片掉弹性
        if not TheWorld.ismastersim then return end
        if inst.components.upgradeable ~= nil then  -- 有可升级组件
            local onupgradefn2hm = inst.components.upgradeable.onupgradefn
            inst.components.upgradeable.onupgradefn = function(inst,...)
                onupgradefn2hm(inst,...) -- 升级函数执行后将掉落改为弹性
                if inst.components.upgradeable.numupgrades > 0 and inst.components.lootdropper ~= nil then inst.components.lootdropper:SetLoot({"chestupgrade_stacksize"}) end
            end
        end
		for k, v in pairs(inst.event_listening or {}) do
			for i, listener in ipairs(v) do
				if listener.event == "ondeconstructstructure" and listener.source == TheWorld then
					inst:RemoveEventCallback("ondeconstructstructure", listener.fn, TheWorld)
					break
				end
			end
		end
		inst:ListenForEvent("ondeconstructstructure", function(_, user)
			if ShouldCollapse(inst) then
				inst.components.container:DropEverythingUpToMaxStacks(TUNING.COLLAPSED_CHEST_MAX_EXCESS_STACKS_DROPS)
				if not inst.components.container:IsEmpty() then
					ConvertToCollapsed(inst, false)
					inst.no_delete_on_deconstruct = true
					return
				end
			elseif inst.components.container ~= nil then
				--We might still have some overstacks, just not enough to "collapse"
				inst.components.container:DropEverything()
			end

			--fallback to default
			inst.no_delete_on_deconstruct = nil
		end, TheWorld)
    end)
    -- 2025.4.13 melon:升级箱子不掉启迪碎片掉弹性
    AddPrefabPostInit("treasurechest", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.upgradeable ~= nil then  -- 有可升级组件
            local onupgradefn2hm = inst.components.upgradeable.onupgradefn
            inst.components.upgradeable.onupgradefn = function(inst,...)
                onupgradefn2hm(inst,...) -- 升级函数执行后将掉落改为弹性
                if inst.components.upgradeable.numupgrades > 0 and inst.components.lootdropper ~= nil then inst.components.lootdropper:SetLoot({"chestupgrade_stacksize"}) end
            end
        end
    end)
end  -- 2025.3.16 end

-- 科学机器精炼材料
if GetModConfigData("Science Machine Refine Materials") then
    local materials = {
        cutgrass = {n = 3, loot = "rope"},
        rocks = {n = 3, loot = "cutstone"},
        log = {n = 4, loot = "boards"},
        cutreeds = {n = 4, loot = "papyrus"}
    }
    local function OnRefuseItem(inst, giver)
        if inst.components.workable then inst.components.workable.onwork(inst) end
        giver.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl2_ding")
    end
    local function forProcess(inst, recipe, giver, prefab, blackprefabs, skinname, skin_id, alt_skin_ids)
        -- 没有解锁的配方不进行制作
        if not (recipe and recipe.ingredients and giver.components.builder:KnowsRecipe(recipe)) then return false end
        -- 制作成品的素材不足,则尝试制作将其的素材作为成品进行制作,但本次期间该成品不会再尝试制作了
        if not giver.components.builder:HasIngredients(recipe) then
            table.insert(blackprefabs, prefab)
            for k, v in pairs(recipe.ingredients) do
                if v and v.type and v.type ~= prefab and not table.contains(blackprefabs, v.type) and AllRecipes[v.type] then
                    if forProcess(inst, AllRecipes[v.type], giver, prefab, blackprefabs) then return true end
                end
            end
            return false
        end
        if skinname then
            local chooseskin = recipe.chooseskin
            recipe.chooseskin = skinname
            local result = giver.components.builder:DoBuild(recipe.name, nil, nil, skinname)
            recipe.chooseskin = chooseskin
            return result
        end
        return giver.components.builder:DoBuild(recipe.name)
    end
    local function OnGivenItem(inst, giver, item)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        if item.prototyperfn2hm then
            if item:prototyperfn2hm(inst, giver) then
                inst:PushEvent("ms_giftopened")
                if item:IsValid() then
                    if inst.notactive2hm then
                        if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    else
                        if inventory.GiveActiveItem then
                            inventory:GiveActiveItem(item) 
                        else
                            inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    end
                end
                return
            end
        end
        if item.prefab == "gears" and inst.level2hm and inst.level2hm:value() < 10 then
            item.components.stackable:Get(1):Remove()
            inst.level2hm:set(inst.level2hm:value() + 1)
            local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
            shinefx.AnimState:SetTime(10 * FRAMES)
            shinefx.entity:SetParent(inst.entity)
            inst:PushEvent("ms_giftopened")
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
            return
        end
        if materials[item.prefab] and item.components.stackable and item.components.stackable.stacksize >= materials[item.prefab].n then
            local loot = materials[item.prefab].loot
            local need = materials[item.prefab].n
            inst:PushEvent("ms_giftopened")
            local level = inst.level2hm:value()
            local num = math.min(math.floor(item.components.stackable.stacksize / need), level)
            item.components.stackable:Get(need * num):Remove()
            if item:IsValid() then
                if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
            end
            local valueidx = num
            for i = 1, num do
                local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                if spawn.components.stackable then
                    local v = math.min(valueidx, spawn.components.stackable.maxsize)
                    spawn.components.stackable:SetStackSize(v)
                    valueidx = valueidx - v
                    if valueidx <= 0 then
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                        break
                    end
                end
                if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
            end
        elseif (AllRecipes[item.prefab] or (giver.prefab == "wendy" and (item.prefab == "butterfly" or item.prefab == "moonbutterfly"))) and giver and giver.components.builder then -- 温蒂配方兼容
            recipe = AllRecipes[item.prefab]
			if item.prefab == "butterfly" then
			recipe = AllRecipes["wendy_butterfly"] 
			elseif item.prefab == "moonbutterfly" then
			recipe = AllRecipes["wendy_moonbutterfly"] 
			end
            local prefab = item.prefab
            local skinname = item.skinname
            local skin_id = item.skin_id
            local alt_skin_ids = item.alt_skin_ids
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
            local hasevent
            local _SpawnPrefab = GLOBAL.SpawnPrefab
            GLOBAL.SpawnPrefab = function(name, skin, _skin_id, creator, ...)
                if name == prefab then
                    skin = skin or skinname
                    _skin_id = _skin_id or skin_id
                end
                local ent = _SpawnPrefab(name, skin, _skin_id, creator, ...)
                if name == prefab then ent.alt_skin_ids = alt_skin_ids end
                return ent
            end
            for i = 1, inst.level2hm:value(), 1 do
                if forProcess(inst, recipe, giver, prefab, {}, skinname, skin_id, alt_skin_ids) then
                    if not hasevent then
                        hasevent = true
                        inst:PushEvent("ms_giftopened")
                    end
                else
                    if not hasevent then OnRefuseItem(inst, giver) end
                    break
                end
            end
            GLOBAL.SpawnPrefab = _SpawnPrefab
        else
            OnRefuseItem(inst, giver)
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
        end
    end

    local function AcceptTest(inst, item, giver)
        if inst:HasTag("burnt") then return false end
        if inst.prefab == "reskin_tool" and item and item.prefab == inst.prefab then return false end
        if not giver or not giver.components.inventory then return false end
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if item.prototyperfn2hm then return true end
        if materials[item.prefab] and item.components.stackable then return true end
        if inst.level2hm:value() < 10 and item.prefab == "gears" then
            if inst.prefab == "reskin_tool" then return false end
            return true 
        end
        if AllRecipes[item.prefab] and giver and giver.components.builder then return true end
		if (item.prefab == "butterfly" or  item.prefab == "moonbutterfly") and giver and giver.components.builder then return true end -- 温蒂配方兼容
        return false
    end
    local function DisplayNameFn(inst)
        if inst.level2hm:value() ~= 1 then
            return inst.name .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 10 and " Max" or "")
        else
            return inst.name
        end
    end
    local function OnSave(inst, data) data.level = inst.level2hm and inst.level2hm:value() or 1 end
    local function OnLoad(inst, data) if data ~= nil then if data.level ~= nil then inst.level2hm:set(data.level) end end end
    AddPrefabPostInit("researchlab", function(inst)
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "researchlab.level2hm", "upgrade2hmdirty")
        if not TheWorld.ismastersim then return end
        inst.level2hm:set(1)
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            inst.traderitemowner2hm = item.components.inventoryitem and item.components.inventoryitem.owner
            if materials[item.prefab] then count = count or (materials[item.prefab].n * self.inst.level2hm:value()) end
            local result = oldAcceptGift(self, giver, item, count)
            inst.traderitemowner2hm = nil
            return result
        end
        inst:ListenForEvent("onburnt", function()
            inst:RemoveComponent("trader") 
            UnregisterReskinPrototyper2hm(inst)
        end)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst.components.persistent2hm.data.id = inst.GUID
        SetOnSave2hm(inst, OnSave)
        SetOnLoad2hm(inst, OnLoad)
        inst:ListenForEvent("onremove", function()
            UnregisterReskinPrototyper2hm(inst)
        end)
    end)
end

-- 炼金引擎兑换金块
if GetModConfigData("Alchemy Engine Redeem Gold Nugget") then
    local disabletrader = GetModConfigData("Alchemy Engine Redeem Gold Nugget") == -1
    local materials = {
        -- 2025.3.16 melon
        cutgrass = {n = 3, loot = "cutreeds"}, -- 芦苇->2草
        cutreeds = {n = 1, loot = "cutgrass", numtogive = 2}, -- 3草->芦苇
        poop = {n = 1, loot = "spoiled_food", numtogive = 4}, -- 便便->腐烂物
        jellybean = {n = 1, loot = "smallcandy2hm", numtogive = 5}, -- 糖豆->小糖豆
		-- 2025.4.10 melon
        wormlight = {n = 1, loot = "wormlight_lesser", numtogive = 3},-- 发光浆果->3小发光浆果
        wormlight_lesser = {n = 6, loot = "wormlight", numtogive = 1},-- 6小发光浆果->发光浆果
        ancientfruit_nightvision = {n = 1, loot = "wormlight_lesser"},-- 夜莓->小发光浆果
        -- 原本的
        twigs = {n = 3, loot = "log"},
        log = {n = 1, loot = "twigs", numtogive = 2},
        redgem = {n = 2, loot = "bluegem"},
        bluegem = {n = 2, loot = "redgem"},
        purplegem = {n = 3, loot = "orangegem"},
        orangegem = {n = 3, loot = "yellowgem"},
        yellowgem = {n = 3, loot = "greengem"},
        rocks = {n = 3, loot = "flint"},
        flint = {n = 2, loot = "rocks"},
        nitre = {n = 3, loot = "goldnugget"},
        goldnugget = {n = 2, loot = "nitre"},
        cutstone = {n = 2, loot = "marble"},
        marble = {n = 1, loot = "cutstone"},
        moonrocknugget = {n = 2, proxy = "marble", loot = "moonrocknugget"},
        smallmeat = {n = 3, loot = "meat"},
        meat = {n = 1, loot = "smallmeat", numtogive = 2},
        fishmeat = {n = 1, loot = "fishmeat_small", numtogive = 2},
        fishmeat_small = {n = 3, loot = "fishmeat"},
        beefalowool = {n = 2, loot = "beardhair"},
        beardhair = {n = 2, loot = "beefalowool"},
        houndstooth = {n = 2, loot = "boneshard"},
        boneshard = {n = 2, loot = "houndstooth"},
        spoiled_food = {n = 6, loot = "poop"},
        mosquitosack = {n = 2, loot = "spidergland"},
        spidergland = {n = 2, loot = "mosquitosack"},
        steelwool = {n = 1, loot = "silk", numtogive = TUNING.DSTU and 1 or 3},
        -- 需要等级大于30
        moonglass_charged = {n = 3, loot = "purebrilliance", level = 30},
        purebrilliance = {n = 1, loot = "moonglass_charged", numtogive = 2, level = 30},
        horrorfuel = {n = 3, loot = "dreadstone", level = 30},
        dreadstone = {n = 1, loot = "horrorfuel", numtogive = 2, level = 30},
        nightmarefuel = {n = 1, proxy = "horrorfuel", loot = "nightmarefuel", numtogive = 2, level = 30}
    }

    if TUNING.DSTU then
        materials.monstersmallmeat = {n = 3, loot = "monstermeat"}
        materials.monstermeat = {n = 1, loot = "monstersmallmeat", numtogive = 2}
		materials.coontail = {n = 2, loot = "rat_tail"}
    end

    local function OnRefuseItem(inst, giver, item)
        if inst.components.workable then inst.components.workable.onwork(inst) end
        giver.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl1_ding")
    end

    local function OnGivenItem(inst, giver, item)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        if item.prototyperfn2hm then
            if item:prototyperfn2hm(inst, giver) then
                inst:PushEvent("ms_giftopened")
            else
                OnRefuseItem(inst, giver)
            end
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
            return
        end
        if item.prefab == "gears" and inst.level2hm and inst.level2hm:value() < 40 and item.components.stackable and item.components.stackable.stacksize >= 4 then
            item.components.stackable:Get(4):Remove()
            inst.level2hm:set(inst.level2hm:value() + 1)
            local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
            shinefx.AnimState:SetTime(10 * FRAMES)
            shinefx.entity:SetParent(inst.entity)
            inst:PushEvent("ms_giftopened")
            if item:IsValid() then
                if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
            end
            return
        end
        if materials[item.prefab] and item.components.stackable and
            (materials[item.prefab].proxy or item.components.stackable.stacksize >= materials[item.prefab].n) then
            local level = inst.level2hm:value()
            local loot = materials[item.prefab].loot
            local proxy = materials[item.prefab].proxy
            local need = materials[item.prefab].n
            if proxy then
                local prefab = item.prefab
                if item:IsValid() then
                    if inst.notactive2hm then
                        if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    else
                        if inventory.GiveActiveItem then
                            inventory:GiveActiveItem(item) 
                        else
                            inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    end
                end
                local has, num_found = giver.components.inventory:Has(proxy, need)
                if has then
                    inst:PushEvent("ms_giftopened")
                    local num = math.min(math.floor(num_found / need), level)
                    giver.components.inventory:ConsumeByName(proxy, num * need)
                    local numtogive = (materials[prefab].numtogive or 1) * num
                    local valueidx = numtogive
                    for index = 1, numtogive do
                        local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                        if spawn.components.stackable then
                            local v = math.min(valueidx, spawn.components.stackable.maxsize)
                            spawn.components.stackable:SetStackSize(v)
                            valueidx = valueidx - v
                            if valueidx <= 0 then
                                if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                                end
                                break
                            end
                        end
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                    end
                else
                    OnRefuseItem(inst, giver)
                end
            else
                inst:PushEvent("ms_giftopened")
                local num = math.min(math.floor(item.components.stackable.stacksize / need), level)
                local numtogive = (materials[item.prefab].numtogive or 1) * num
                item.components.stackable:Get(num * need):Remove()
                if item:IsValid() then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
                for index = 1, numtogive do
                    local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                    inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end
        elseif not disabletrader and item.components.tradable and item.components.tradable.goldvalue > 0 then
            inst:PushEvent("ms_giftopened")
            local goldvalue = item.components.tradable.goldvalue * (item.components.stackable and item.components.stackable.stacksize or 1)
            item:Remove()
            local valueidx = goldvalue
            for k = 1, goldvalue do
                local spawn = inst.components.lootdropper:SpawnLootPrefab("goldnugget")
                if spawn.components.stackable then
                    local v = math.min(valueidx, spawn.components.stackable.maxsize)
                    spawn.components.stackable:SetStackSize(v)
                    valueidx = valueidx - v
                    if valueidx <= 0 then
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                        break
                    end
                end
                if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end
        else
            OnRefuseItem(inst, giver)
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
        end
    end

    local function AcceptTest(inst, item, giver)
        if inst:HasTag("burnt") then return false end
        if inst.prefab == "reskin_tool" and item and item.prefab == inst.prefab then return false end
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if item.prototyperfn2hm then return true end
        if materials[item.prefab] and item.components.stackable then
            return item.components.stackable.stacksize >= (materials[item.prefab].n or 1) and
                       (materials[item.prefab].level == nil or inst.level2hm:value() >= materials[item.prefab].level)
        end
        if inst.level2hm:value() < 40 and item.prefab == "gears" and item.components.stackable and item.components.stackable.stacksize >= 4 then
            if inst.prefab == "reskin_tool" then return false end
            return true
        end
        return not disabletrader and item.components.tradable ~= nil and item.components.tradable.goldvalue > 0
    end
    local function DisplayNameFn(inst)
        if inst.level2hm:value() ~= 1 then
            return inst.name .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 40 and " Max" or "")
        else
            return inst.name
        end
    end
    local function OnSave(inst, data) data.level = inst.level2hm and inst.level2hm:value() or 1 end
    local function OnLoad(inst, data) if data ~= nil then if data.level ~= nil then inst.level2hm:set(data.level) end end end
    AddPrefabPostInit("researchlab2", function(inst)
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "researchlab.level2hm", "upgrade2hmdirty")
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.level2hm:set(1)
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            inst.traderitemowner2hm = item.components.inventoryitem and item.components.inventoryitem.owner
            if item.prefab == "gears" and self.inst.level2hm:value() < 40 then
                count = count or 4
            elseif materials[item.prefab] and not materials[item.prefab].proxy then
                count = count or (materials[item.prefab].n * self.inst.level2hm:value())
            elseif not disabletrader and item.components.tradable ~= nil and item.components.tradable.goldvalue > 0 then
                count = count or self.inst.level2hm:value()
            end
            local result = oldAcceptGift(self, giver, item, count)
            inst.traderitemowner2hm = nil
            return result
        end
        inst:ListenForEvent("onburnt", function()
            inst:RemoveComponent("trader")
            UnregisterReskinPrototyper2hm(inst)
        end)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst.components.persistent2hm.data.id = inst.GUID
        SetOnSave2hm(inst, OnSave)
        SetOnLoad2hm(inst, OnLoad)
        inst:ListenForEvent("onremove", function()
            UnregisterReskinPrototyper2hm(inst)
        end)
    end)
end

-- 灵子分解器分解道具
if GetModConfigData("Shadow Manipulator Break Down Objects") then
    TUNING.MAGIC_PROTOTYPER_MAXWELL_SPAWN_RABBIT_CHANCE = 0
    TUNING.MAGIC_PROTOTYPER_SPAWN_RABBIT_CHANCE = 0
    local DESTSOUNDS = {
        {
            -- magic
            soundpath = "dontstarve/common/destroy_magic",
            ing = {"nightmarefuel", "livinglog"}
        },
        {
            -- cloth
            soundpath = "dontstarve/common/destroy_clothing",
            ing = {"silk", "beefalowool"}
        },
        {
            -- tool
            soundpath = "dontstarve/common/destroy_tool",
            ing = {"twigs"}
        },
        {
            -- gem
            soundpath = "dontstarve/common/gem_shatter",
            ing = {"redgem", "bluegem", "greengem", "purplegem", "yellowgem", "orangegem"}
        },
        {
            -- wood
            soundpath = "dontstarve/common/destroy_wood",
            ing = {"log", "boards"}
        },
        {
            -- stone
            soundpath = "dontstarve/common/destroy_stone",
            ing = {"rocks", "cutstone"}
        },
        {
            -- straw
            soundpath = "dontstarve/common/destroy_straw",
            ing = {"cutgrass", "cutreeds"}
        }
    }
    local DESTSOUNDSMAP = {}
    for i, v in ipairs(DESTSOUNDS) do for i2, v2 in ipairs(v.ing) do DESTSOUNDSMAP[v2] = v.soundpath end end
    DESTSOUNDS = nil

    local lastitemprefab
    local levelchance = {0.5, 0.75, 1}
    local function processspawncomponents(spawn)
        if spawn.components.finiteuses then spawn.components.finiteuses:SetPercent(0.01) end
        if spawn.components.fueled then spawn.components.fueled:SetPercent(0.01) end
        if spawn.components.armor then spawn.components.armor:SetPercent(0.01) end
        if spawn.components.perishable then spawn.components.perishable:SetPercent(TUNING.PERISH_STALE) end
    end
    local function destroystructure(inst, item, giver)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        local recipe = AllRecipes[item.prefab]
        if recipe == nil or FunctionOrValue(recipe.no_deconstruction, item) then
            if item.components.stackable ~= nil and lastitemprefab ~= item.prefab then
                lastitemprefab = item.prefab
                item.components.stackable:Get():Remove()
            else
                lastitemprefab = item.prefab
                item:Remove()
            end
            return
        end
        local itemcomponent = item.components.finiteuses or item.components.fueled or item.components.armor or item.components.perishable
        local ingredient_percent = math.min(itemcomponent and itemcomponent:GetPercent() or 1, 1) / recipe.numtogive
        if lastitemprefab == item.prefab and item.components.stackable ~= nil then
            ingredient_percent = ingredient_percent * item.components.stackable.stacksize
        end
        for i, v in ipairs(recipe.ingredients) do
            if giver ~= nil and DESTSOUNDSMAP[v.type] ~= nil then giver.SoundEmitter:PlaySound(DESTSOUNDSMAP[v.type]) end
            if string.sub(v.type, -3) ~= "gem" or string.sub(v.type, -11, -4) == "precious" then
                local amt = v.amount * ingredient_percent * (levelchance[inst.level2hm and inst.level2hm:value()] or 0.5)
				if item.prefab == "rope" then amt = 2 * ingredient_percent * (levelchance[inst.level2hm and inst.level2hm:value()] or 0.5) end
                if amt > 0 then
                    local total = math.floor(amt)
                    local valueidx = total
                    for n = 1, total do
                        local spawn = inst.components.lootdropper:SpawnLootPrefab(v.type)
                        if spawn.components.stackable then
                            local v = math.min(valueidx, spawn.components.stackable.maxsize)
                            spawn.components.stackable:SetStackSize(v)
                            valueidx = valueidx - v
                            if valueidx <= 0 then
                                processspawncomponents(spawn)
                                if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                                end
                                break
                            end
                        end
                        processspawncomponents(spawn)
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                    end
                    local chance = amt - total
                    if chance > 0 and math.random() < chance then
                        local spawn = inst.components.lootdropper:SpawnLootPrefab(v.type)
                        processspawncomponents(spawn)
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                    end
                end
            end
        end
        local item_todelete = item
        if item.components.stackable ~= nil and lastitemprefab ~= item.prefab then item_todelete = item.components.stackable:Get() end
        lastitemprefab = item.prefab
        item_todelete.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if item_todelete.components.inventory ~= nil then item_todelete.components.inventory:DropEverything() end
        if item_todelete.components.container ~= nil then item_todelete.components.container:DropEverything() end
        if item_todelete.components.spawner ~= nil and item_todelete.components.spawner:IsOccupied() then item_todelete.components.spawner:ReleaseChild() end
        if item_todelete.components.occupiable ~= nil and item_todelete.components.occupiable:IsOccupied() then
            local item_todelete = item_todelete.components.occupiable:Harvest()
            if item_todelete ~= nil then
                item_todelete.Transform:SetPosition(item.Transform:GetWorldPosition())
                item_todelete.components.inventoryitem:OnDropped()
            end
        end
        if item_todelete.components.trap ~= nil then item_todelete.components.trap:Harvest() end
        if item_todelete.components.dryer ~= nil then item_todelete.components.dryer:DropItem() end
        if item_todelete.components.harvestable ~= nil then item_todelete.components.harvestable:Harvest() end
        if item_todelete.components.stewer ~= nil then item_todelete.components.stewer:Harvest() end
        item:PushEvent("ondeconstructstructure", giver)
        item_todelete:Remove()
    end

    local function OnGivenItem(inst, giver, item)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题（下同）
        -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
        giver.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
        if item.prototyperfn2hm then
            if item:prototyperfn2hm(inst, giver) then
                if item:IsValid() then
                    if inst.notactive2hm then
                        if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    else
                        if inventory.GiveActiveItem then
                            inventory:GiveActiveItem(item) 
                        else
                            inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    end
                end
                return
            end
        end
        if item.prefab == "greengem" and inst.level2hm and inst.level2hm:value() < 3 then
            item.components.stackable:Get(1):Remove()
            inst.level2hm:set(inst.level2hm:value() + 1)
            local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
            shinefx.AnimState:SetTime(10 * FRAMES)
            shinefx.entity:SetParent(inst.entity)
            if item:IsValid() then
                if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
            end
            return
        end
        destroystructure(inst, item, giver)
    end

    local function OnRefuseItem(inst, giver, item)
        if inst.components.workable then inst.components.workable.onwork(inst) end
        giver.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl4_ding")
    end

    local function AcceptTest(inst, item, giver)
        if inst:HasTag("burnt") then return false end
        if inst.prefab == "reskin_tool" and item and (item.prefab == "greengem" or item.prefab == inst.prefab) then return false end
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if item.prototyperfn2hm then return true end
        if item and item:HasAnyTag("irreplaceable", "cursed", "curse2hm") then return false end
        if item and item.prefab == "greengem" and inst.level2hm:value() >= 3 then return false end
        if item and item.prefab == "wagpunk_bits" then return false end
        if item and item.components.tempequip2hm then return false end
        return true
    end

    local function DisplayNameFn(inst)
        if inst.level2hm:value() ~= 1 then
            return inst.name .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 3 and " Max" or "")
        else
            return inst.name
        end
    end
    local function OnSave(inst, data) data.level = inst.level2hm and inst.level2hm:value() or 1 end
    local function OnLoad(inst, data) if data ~= nil then if data.level ~= nil then inst.level2hm:set(data.level) end end end
    AddPrefabPostInit("researchlab4", function(inst)
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "researchlab.level2hm", "upgrade2hmdirty")
        if not TheWorld.ismastersim then return end
        inst.level2hm:set(1)
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(inst, giver, item, count)
            if item == nil then return end
            inst.traderitemowner2hm = item.components.inventoryitem and item.components.inventoryitem.owner
            if item.components.stackable and item.prefab == lastitemprefab then count = item.components.stackable.stacksize end
            local result = oldAcceptGift(inst, giver, item, count)
            inst.traderitemowner2hm = nil
            return result
        end
        inst:ListenForEvent("onburnt", function() 
            inst:RemoveComponent("trader") 
            UnregisterReskinPrototyper2hm(inst)
        end)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst.components.persistent2hm.data.id = inst.GUID
        SetOnSave2hm(inst, OnSave)
        SetOnLoad2hm(inst, OnLoad)
        inst:ListenForEvent("onremove", function()
            UnregisterReskinPrototyper2hm(inst)
        end)
    end)
end

-- 暗影操控器兑换暗影魔法
if GetModConfigData("Prestihatitator Redeem shadowmagic Tag") then
    local function OnRefuseItem(inst, giver, item)
        if inst.components.workable then inst.components.workable.onwork(inst) end
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
    end
    
    local function RemoveTag(inst)
        if inst.components.persistent2hm and inst.components.persistent2hm.data.shadowmagiccycle and TheWorld.state.cycles -
            inst.components.persistent2hm.data.shadowmagiccycle > 20 then
            local shadowmagic_tag = inst.components.persistent2hm.data.shadowmagic_tag
            local magician_tag = inst.components.persistent2hm.data.magician_tag
            local magician_component = inst.components.persistent2hm.data.magician_component
            if inst:HasTag("shadowmagic") and not shadowmagic_tag then inst:RemoveTag("shadowmagic") end
            if inst:HasTag("magician") and not magician_tag then inst:RemoveTag("magician") end
            if inst.components.magician and not magician_component then inst:RemoveComponent("magician") end
            if inst.components.reader ~= nil then
                inst.components.reader:SetSanityPenaltyMultiplier(inst.components.persistent2hm.data.originalsanity_mult or 1)
            end
            local fx = SpawnPrefab("shadow_despawn")
            inst:AddChild(fx)
            if inst.components.talker then inst.components.talker:Say((TUNING.isCh2hm and "我体内的暗影魔法渴望燃料..." or "The shadow magic within me craves fuel...")) end
            inst:StopWatchingWorldState("cycles", RemoveTag)
        end
    end

    local function OnGivenItem(inst, giver, item)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        if item.prototyperfn2hm then
            if item:prototyperfn2hm(inst, giver) then
                inst:PushEvent("ms_giftopened")
                if item:IsValid() then
                    if inst.notactive2hm then
                        if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    else
                        if inventory.GiveActiveItem then
                            inventory:GiveActiveItem(item) 
                        else
                            inventory:GiveItem(item, nil, inst:GetPosition())
                        end
                    end
                end
                return
            end
        end
        if item.components.stackable.stacksize < 4 then
            OnRefuseItem(inst, giver)
            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
            return
        end
        item.components.stackable:Get(4):Remove()
        if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题
        -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_alchemy_gift_recieve")
        if giver ~= nil then
            if giver:HasTag("shadowmagic") then giver.components.persistent2hm.data.shadowmagic_tag = true end
            if giver:HasTag("magician") then giver.components.persistent2hm.data.magician_tag = true end
            if giver.components.magician then giver.components.persistent2hm.data.magician_component = true end
            if not giver:HasTag("shadowmagic") then giver:AddTag("shadowmagic") end
            if not giver:HasTag("magician") then giver:AddTag("magician") end
            if not giver.components.magician then giver:AddComponent("magician") end
            if giver.components.reader ~= nil and (giver.components.reader.sanity_mult or 1) > 1 then
                giver.components.persistent2hm.data.originalsanity_mult = giver.components.reader.sanity_mult or 1
                giver.components.reader:SetSanityPenaltyMultiplier(1)
            end
            if giver.components.persistent2hm then giver.components.persistent2hm.data.shadowmagiccycle = TheWorld.state.cycles end
            if giver.components.rider and not giver.components.rider:IsRiding() then
                giver.sg:GoToState("changeoutsidewardrobe")
            else
                giver.SoundEmitter:PlaySound("dontstarve/sanity/shadowrock_up")
                local x,y,z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("sanity_raise")
                fx.Transform:SetPosition(x, 4, z)
                giver:AddChild(fx)
            end
            local equip = giver.components.inventory and giver.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
            if equip and equip:IsValid() and equip.checkstatus2hm then equip:checkstatus2hm() end
            giver:WatchWorldState("cycles", RemoveTag)
        end
    end

    local function AcceptTest(inst, item, giver)
        if inst:HasTag("burnt") then return false end
        if item and item.prefab == "reskin_tool" and item.prefab ~= inst.prefab and 
        giver and giver.components.persistent2hm and giver.components.persistent2hm.data.shadowmagiccycle then 
            return true 
        end
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if item.prefab ~= "nightmarefuel" or giver == nil then return false end
        if not giver:HasTag("shadowmagic") or not giver:HasTag("magician") or not giver.components.magician or
            (giver.components.reader ~= nil and (giver.components.reader.sanity_mult or 1) > 1) then return true end
        return false
    end
    local function resetshadowmagic(inst)
        if inst.components.persistent2hm and inst.components.persistent2hm.data.shadowmagiccycle and TheWorld.state.cycles -
            inst.components.persistent2hm.data.shadowmagiccycle <= 20 then
            if not inst:HasTag("shadowmagic") then inst:AddTag("shadowmagic") end
            if not inst:HasTag("magician") then inst:AddTag("magician") end
            if not inst.components.magician then inst:AddComponent("magician") end
            if inst.components.reader ~= nil and (inst.components.reader.sanity_mult or 1) > 1 then
                inst.components.reader:SetSanityPenaltyMultiplier(1)
            end
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
            if equip and equip:IsValid() and equip.checkstatus2hm then equip:checkstatus2hm() end
            inst:WatchWorldState("cycles", RemoveTag)
        end
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        if inst.prefab ~= "waxwell" and inst.components.petleash then
            local oldOnSpawnPet = inst.components.petleash.onspawnfn
            inst.components.petleash:SetOnSpawnFn(function(inst, pet, ...)
                if pet and pet:HasTag("shadowminion") and pet.components.skinner and not (inst.components.health:IsDead() or inst:HasTag("playerghost")) then
                    pet.components.skinner:CopySkinsFromPlayer(inst)
                end
                return oldOnSpawnPet(inst, pet, ...)
            end)
        end
        inst:DoTaskInTime(0, resetshadowmagic)
    end)
    AddComponentPostInit("magician", function(self)
        local OnRemoveFromEntity = self.OnRemoveFromEntity
        self.OnRemoveFromEntity = function(self, ...)
            if self.inst:IsValid() and self.inst:HasTag("player") and self.inst.components.persistent2hm then
                self.inst:DoTaskInTime(0, resetshadowmagic)
            end
            if OnRemoveFromEntity then OnRemoveFromEntity(self, ...) end
        end
    end)
    AddPrefabPostInit("waxwelljournal", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.aoespell and inst.components.spellbook then
            local oldSetSpellFn = inst.components.aoespell.SetSpellFn
            inst.components.aoespell.SetSpellFn = function(self, fn, ...)
                local spellname = inst.components.spellbook.spellname
                if fn and (spellname == STRINGS.SPELLS.SHADOW_WORKER or spellname == STRINGS.SPELLS.SHADOW_PROTECTOR) then
                    return oldSetSpellFn(self, function(inst, doer, pos, ...)
                        if doer and doer.prefab ~= "waxwell" and doer.components.petleash and doer.components.petleash.numpets >=
                            doer.components.petleash.maxpets then return false, "NO_MAX_SANITY" end
                        return fn(inst, doer, pos, ...)
                    end, ...)
                end
                return oldSetSpellFn(self, fn, ...)
            end
        end
        if inst.components.fueled and inst.components.fueled.TakeFuelItem then
            local TakeFuelItem = inst.components.fueled.TakeFuelItem
            inst.components.fueled.TakeFuelItem = function(self, item, doer, ...)
                local result = TakeFuelItem(self, item, doer, ...)
                if result and doer and doer:IsValid() and doer:HasTag("player") and doer.components.persistent2hm and
                    doer.components.persistent2hm.data.shadowmagiccycle then
                    if TheWorld.state.cycles - doer.components.persistent2hm.data.shadowmagiccycle > 20 and doer.sg and not IsEntityDeadOrGhost(doer) then
                        if doer.components.rider and not doer.components.rider:IsRiding() then
                            doer.sg:GoToState("changeoutsidewardrobe")
                        else
                            doer.SoundEmitter:PlaySound("dontstarve/sanity/shadowrock_up")
                            local fx = SpawnPrefab("sanity_raise")
                            fx.Transform:SetScale(1.25, 1.25, 1.25)
                            doer:AddChild(fx)
                        end
                    end
                    doer.components.persistent2hm.data.shadowmagiccycle = math.max(doer.components.persistent2hm.data.shadowmagiccycle + 1,
                                                                                   TheWorld.state.cycles - 20)
                    resetshadowmagic(doer)
                end
                return result
            end
        end
    end)
    AddPrefabPostInit("researchlab3", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(inst, giver, item, count)
            if item == nil then return end
            if item.prefab == "nightmarefuel" then count = count or 4 end
            return oldAcceptGift(inst, giver, item, count)
        end
        inst:ListenForEvent("onburnt", function() 
            inst:RemoveComponent("trader") 
            UnregisterReskinPrototyper2hm(inst)
        end)
        inst:ListenForEvent("onremove", function()
            UnregisterReskinPrototyper2hm(inst)
        end)
    end)
end

-- 土地夯实器或强征传送塔兑换沙之石
local turfopt = GetModConfigData("Terra Firma Tamper Redeem Desert Stone")
if turfopt then
    local function OnRefuseItem(inst, giver, item)
        inst.components.workable.onwork(inst)
        giver.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
    end
    local function OnGivenItem(inst, giver, item)
        local inventory = inst.traderitemowner2hm and inst.traderitemowner2hm.components.container or giver.components.inventory
        if item.prototyperfn2hm then
            if item:prototyperfn2hm(inst, giver) then
                if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end  -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题
                -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
                inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
            else
                OnRefuseItem(inst, giver)
            end
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
            return
        end
        if item.prefab == "thulecite" and inst.level2hm and inst.level2hm:value() < 40 then
            item.components.stackable:Get(1):Remove()
            inst.level2hm:set(inst.level2hm:value() + 1)
            local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
            shinefx.AnimState:SetTime(10 * FRAMES)
            shinefx.entity:SetParent(inst.entity)
            if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end  -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题
            -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
            if item:IsValid() then
                if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
            end
            return
        end
        if item.components.tradable.goldvalue ~= nil and item.components.tradable.goldvalue > 0 then
            if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end  -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题
            -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
            local goldvalue = item.components.tradable.goldvalue * (item.components.stackable and item.components.stackable.stacksize or 1)
            local valueidx = goldvalue
            for k = 1, goldvalue do
                local spawn = inst.components.lootdropper:SpawnLootPrefab("townportaltalisman")
                if spawn.components.stackable then
                    local v = math.min(valueidx, spawn.components.stackable.maxsize)
                    spawn.components.stackable:SetStackSize(v)
                    valueidx = valueidx - v
                    if valueidx <= 0 then
                        if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                            giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                        end
                        break
                    end
                end
                if not inventory:GiveItem(spawn, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end
            item:Remove()
        elseif item.components.tradable.rocktribute ~= nil and item.components.tradable.rocktribute > 0 then
            if inst.components.prototyper then inst.components.prototyper.onactivate(inst, giver) end  -- 2026.2.15 YeFeng:补传giver参数，修复官方更新后onactivate延迟回调中doer为nil导致崩溃的问题
            -- if inst.components.prototyper then inst.components.prototyper.onactivate(inst) end
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
            local rockvalue = item.components.tradable.rocktribute * (item.components.stackable and item.components.stackable.stacksize or 1)
            local valueidx = rockvalue
            for k = 1, rockvalue do
                local spawn = inst.components.lootdropper:SpawnLootPrefab("rocks")
                if spawn.components.stackable then
                    local v = math.min(valueidx, spawn.components.stackable.maxsize)
                    spawn.components.stackable:SetStackSize(v)
                    valueidx = valueidx - v
                    if valueidx <= 0 then
                        inventory:GiveItem(spawn, nil, inst:GetPosition())
                        break
                    end
                end
                inventory:GiveItem(spawn, nil, inst:GetPosition())
            end
            item:Remove()
        else
            OnRefuseItem(inst, giver)
            if item:IsValid() then
                if inst.notactive2hm then
                    if not inventory:GiveItem(item, nil, inst:GetPosition()) and inventory ~= giver.components.inventory then
                        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                else
                    if inventory.GiveActiveItem then
                        inventory:GiveActiveItem(item) 
                    else
                        inventory:GiveItem(item, nil, inst:GetPosition())
                    end
                end
            end
        end
    end
    local function AcceptTest(inst, item)
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if item.prototyperfn2hm then return true end
        if item.prefab == "thulecite" and inst.level2hm:value() < 40 then return true end
        return item.components.tradable ~= nil and item.components.tradable.rocktribute ~= nil and item.components.tradable.rocktribute > 0
    end
    local function DisplayNameFn(inst)
        if inst.level2hm:value() ~= 1 then
            return inst.name .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 40 and " Max" or "")
        else
            return inst.name
        end
    end
    local function OnSave(inst, data) data.level = inst.level2hm and inst.level2hm:value() or 1 end
    local function OnLoad(inst, data) if data ~= nil then if data.level ~= nil then inst.level2hm:set(data.level) end end end
    AddPrefabPostInit(turfopt == -1 and "townportal" or "turfcraftingstation", function(inst)
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "researchlab.level2hm", "upgrade2hmdirty")
        if not TheWorld.ismastersim then return end
        inst.level2hm:set(1)
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.acceptnontradable = true
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            inst.traderitemowner2hm = item.components.inventoryitem and item.components.inventoryitem.owner
            if item.components.tradable ~= nil and item.components.tradable.rocktribute ~= nil and item.components.tradable.rocktribute > 0 then
                count = count or self.inst.level2hm:value()
            end
            local result = oldAcceptGift(self, giver, item, count)
            inst.traderitemowner2hm = nil
            return result
        end
        inst:ListenForEvent("onburnt", function() inst:RemoveComponent("trader") end)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst.components.persistent2hm.data.id = inst.GUID
        SetOnSave2hm(inst, OnSave)
        SetOnLoad2hm(inst, OnLoad)
    end)
end

-- 辉煌铁匠铺制造纯粹辉煌
if GetModConfigData("Alchemy Engine Redeem Gold Nugget") then
    local materials = {moonglass_charged = {n = 3, loot = "purebrilliance"}, purebrilliance = {n = 1, loot = "moonglass_charged", numtogive = 2}}
    local function OnRefuseItem(inst, giver, item)
        inst.components.workable.onwork(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl4_ding")
    end
    local function OnGivenItem(inst, giver, item)
        if materials[item.prefab] and item.components.stackable and item.components.stackable.stacksize >= materials[item.prefab].n then
            inst.components.prototyper.onactivate(inst, giver)
            -- inst.components.prototyper.onactivate(inst)
            local loot = materials[item.prefab].loot
            local need = materials[item.prefab].n
            local num = 1
            local numtogive = (materials[item.prefab].numtogive or 1) * num
            -- local num = math.floor(item.components.stackable.stacksize / need)
            item.components.stackable:Get(num * need):Remove()
            if item and item:IsValid() then giver.components.inventory:GiveItem(item, nil, inst:GetPosition()) end
            for index = 1, numtogive do
                local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
            end
        else
            inst.components.workable.onwork(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
        end
    end
    local function AcceptTest(inst, item, giver)
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if materials[item.prefab] and item.components.stackable then return true end
    end
    AddPrefabPostInit("lunar_forge", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            if materials[item.prefab] then count = count or (materials[item.prefab].n) end
            return oldAcceptGift(self, giver, item, count)
        end
        inst:ListenForEvent("onburnt", function() inst:RemoveComponent("trader") end)
    end)
end

-- 暗影术基座制作绝望石
if GetModConfigData("Alchemy Engine Redeem Gold Nugget") then
    local materials = {
        horrorfuel = {n = 3, loot = "dreadstone"},
        dreadstone = {n = 1, loot = "horrorfuel", numtogive = 2},
        nightmarefuel = {n = 1, proxy = "horrorfuel", loot = "nightmarefuel", numtogive = 2}
    }
    local function OnRefuseItem(inst, giver, item)
        inst.components.workable.onwork(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl4_ding")
    end
    local function OnGivenItem(inst, giver, item)
        if materials[item.prefab] and item.components.stackable and
            (materials[item.prefab].proxy or item.components.stackable.stacksize >= materials[item.prefab].n) then
            local loot = materials[item.prefab].loot
            local proxy = materials[item.prefab].proxy
            local need = materials[item.prefab].n
            if proxy then
                if item and item:IsValid() then giver.components.inventory:GiveItem(item, nil, inst:GetPosition()) end
                local has, num_found = giver.components.inventory:Has(proxy, need)
                if has then
                    inst.components.prototyper.onactivate(inst, giver)
                    -- inst.components.prototyper.onactivate(inst)
                    -- local num =math.floor(num_found / need)
                    local num = 1
                    giver.components.inventory:ConsumeByName(proxy, num * need)
                    local numtogive = (materials[item.prefab].numtogive or 1) * num
                    for index = 1, numtogive do
                        local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                        giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                    end
                else
                    OnRefuseItem(inst, giver)
                end
            else
                inst.components.prototyper.onactivate(inst, giver)
                -- inst.components.prototyper.onactivate(inst)
                local num = 1
                local numtogive = (materials[item.prefab].numtogive or 1) * num
                -- local num = math.floor(item.components.stackable.stacksize / need)
                item.components.stackable:Get(num * need):Remove()
                if item and item:IsValid() then giver.components.inventory:GiveItem(item, nil, inst:GetPosition()) end
                for index = 1, numtogive do
                    local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end
        else
            OnRefuseItem(inst, giver)
            giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
        end
    end
    local function AcceptTest(inst, item, giver)
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if materials[item.prefab] and item.components.stackable then return true end
    end
    AddPrefabPostInit("shadow_forge", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            if materials[item.prefab] and not materials[item.prefab].proxy then count = count or (materials[item.prefab].n) end
            return oldAcceptGift(self, giver, item, count)
        end
        inst:ListenForEvent("onburnt", function() inst:RemoveComponent("trader") end)
    end)
end

-- 智囊团制作浮木
if GetModConfigData("Alchemy Engine Redeem Gold Nugget") then
    local materials = {log = {n = 2, other = "saltrock", loot = "driftwood_log"}}
    local function OnGivenItem(inst, giver, item)
        if materials[item.prefab] and item.components.stackable and item.components.stackable.stacksize >= materials[item.prefab].n then
            inst.components.prototyper.onactivate(inst, giver)
            -- inst.components.prototyper.onactivate(inst)
            local loot = materials[item.prefab].loot
            local need = materials[item.prefab].n
            local other = materials[item.prefab].other
            if other and giver.components.inventory:Has(other, 1, true) then
                giver.components.inventory:ConsumeByName(other, 1)
                local num = 1
                item.components.stackable:Get(num * need):Remove()
                local numtogive = (materials[item.prefab].numtogive or 1) * num
                if item and item:IsValid() then giver.components.inventory:GiveItem(item, nil, inst:GetPosition()) end
                for index = 1, numtogive do
                    local spawn = inst.components.lootdropper:SpawnLootPrefab(loot)
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
                return
            end
        end
        inst.components.workable.onwork(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
        giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
    end
    local function OnRefuseItem(inst, giver, item)
        inst.components.workable.onwork(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
    end
    local function AcceptTest(inst, item, giver)
        if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
        if materials[item.prefab] and item.components.stackable and item.components.stackable.stacksize >= materials[item.prefab].n then return true end
    end
    AddPrefabPostInit("seafaring_prototyper", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader.deleteitemonaccept = false
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptTest(AcceptTest)
        inst.components.trader.onaccept = OnGivenItem
        inst.components.trader.onrefuse = OnRefuseItem
        local oldAcceptGift = inst.components.trader.AcceptGift
        inst.components.trader.AcceptGift = function(self, giver, item, count)
            if item == nil then return end
            if materials[item.prefab] then count = count or (materials[item.prefab].n) end
            return oldAcceptGift(self, giver, item, count)
        end
        inst:ListenForEvent("onburnt", function() inst:RemoveComponent("trader") end)
    end)
end

-- 钓具容器兑换鱼和海鱼
if GetModConfigData("Tackle Receptacle Use Fish Redeem") then
    local disabletrader = GetModConfigData("Tackle Receptacle Use Fish Redeem") == -1
    if disabletrader then
        local containers = require("containers")
        containers.params.tacklestation2hm = {
            widget = {slotpos = {}, animbank = "ui_fish_box_5x4", animbuild = "ui_fish_box_5x4", pos = Vector3(0, 220, 0), side_align_tip = 160},
            type = "chest"
        }
        for y = 2.5, -0.5, -1 do
            for x = -1, 3 do table.insert(containers.params.tacklestation2hm.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0)) end
        end
        local newitemtestfn = containers.params.shadow_container.itemtestfn
        local olditemtestfn = containers.params.tacklecontainer.itemtestfn
        local function ismeatdried2hm(item)
            return item ~= nil and item.prefab ~= nil and string.match(item.prefab, "_dried") ~= nil and item.dryveggies2hm == nil
        end
        containers.params.tacklestation2hm.itemtestfn = function(container, item, slot)
            if not container.containeritem2hm then container.containeritem2hm = true end
            return item.prefab ~= nil and (newitemtestfn == nil or newitemtestfn(container, item, slot)) and
                       ((olditemtestfn ~= nil and olditemtestfn(container, item, slot)) or table.contains(CRAFTING_FILTERS.FISHING.recipes, item.prefab) or
                           item:HasTag("preparedfood") or item.prefab == "seeds" or string.match(item.prefab, "_seeds") or item:HasTag("treeseed") or
                           ismeatdried2hm(item))
        end
        local POCKETDIMENSIONCONTAINER_DEFS = require("prefabs/pocketdimensioncontainer_defs").POCKETDIMENSIONCONTAINER_DEFS
        table.insert(POCKETDIMENSIONCONTAINER_DEFS,
                     {name = "tacklestation2hm", prefab = "tacklestation2hm", ui = "anim/ui_fish_box_5x4.zip", widgetname = "tacklestation2hm"})
        AddClassPostConstruct("widgets/containerwidget", function(self)
            local oldOpen = self.Open
            self.Open = function(self, container, doer, ...)
                local result = oldOpen(self, container, doer, ...)
                if container.prefab == "tacklestation2hm" and self.bgimage and self.bganim then
                    if self.bgimage.SetTint then self.bgimage:SetTint(1, 1, 1, 0.25) end
                    if self.bganim.inst and self.bganim.inst.AnimState then self.bganim.inst.AnimState:SetMultColour(1, 1, 1, 0.25) end
                end
                return result
            end
        end)
        -- 种子袋永鲜
        TUNING.SEEDPOUCH_PRESERVER_RATE = 0
        local preserverrate = 0.15
        if CONFIGS_LEGION then preserverrate = 0 end
        local function perish_rate_multiplier(inst, item)
            return item and
                       ((item:HasTag("spider") or item:HasTag("spore") or item.prefab == "seeds" or string.match(item.prefab, "_seeds") or
                           item:HasTag("treeseed")) and 0 or
                           ((item:HasTag("preparedfood") or ismeatdried2hm(item)) and preserverrate)) or 1
        end
        AddPrefabPostInit("tacklestation2hm", function(inst)
            if not TheWorld.ismastersim then return end
            if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then preserverrate = 0 end
            inst:AddComponent("preserver")
            inst.components.preserver:SetPerishRateMultiplier(perish_rate_multiplier)
        end)
        local function onopen(inst)
            if not inst:HasTag("burnt") and inst.components.prototyper and inst.SoundEmitter then
                inst.components.prototyper.onactivate(inst, nil)
                -- inst.components.prototyper.onactivate(inst)
                inst.SoundEmitter:PlaySound("hookline/common/tackle_station/recieive_item")
            end
        end
        local function onclose(inst)
            if not inst:HasTag("burnt") and inst.components.workable and inst.SoundEmitter then
                inst.components.workable.onwork(inst)
                inst.SoundEmitter:PlaySound("hookline/common/tackle_station/place")
            end
        end
        local function onwork(inst)
            if not inst:HasTag("burnt") then if inst.components.container_proxy ~= nil then inst.components.container_proxy:Close() end end
        end
        local function AttachShadowContainer(inst)
            if TheWorld and TheWorld.GetPocketDimensionContainer and inst.components.container_proxy then
                inst.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer("tacklestation2hm"))
            end
        end
        AddPrefabPostInit("tacklestation", function(inst)
            if inst.components.container_proxy then return end
            inst:AddComponent("container_proxy")
            -- inst.repairmaterials2hm = {moonstorm_spark = TUNING.SPEAR_WATHGRITHR_LIGHTNING_USES / 20}
            -- inst.displaynamefn = displaynamefn
            if not TheWorld.ismastersim then return end
            inst:ListenForEvent("worked", onwork)
            if not inst.OnLoadPostPass then
                inst.OnLoadPostPass = AttachShadowContainer
            else
                local OnLoadPostPass = inst.OnLoadPostPass
                inst.OnLoadPostPass = function(...)
                    AttachShadowContainer(...)
                    return OnLoadPostPass(...)
                end
            end
            inst.components.container_proxy:SetOnOpenFn(onopen)
            inst.components.container_proxy:SetOnCloseFn(onclose)
            if not POPULATING then AttachShadowContainer(inst) end
            --     inst:AddComponent("repairable2hm")
            --     inst.components.repairable2hm.customrepair = customrepair
            -- end)
            -- AddPrefabPostInit("tacklestation2hm",function (inst)
            --     inst.moongleamlevel2hm = net_smallbyte(inst.GUID, "wigfridspear.moongleamlevel2hm", "upgrade2hmdirty")
            --     inst.moongleamlevel2hm:set(0)
        end)
    else
        local trading_items = {
            {prefabs = {"kelp"}, min_count = 2, max_count = 4, reset = false, add_filler = false},
            {prefabs = {"kelp"}, min_count = 2, max_count = 3, reset = false, add_filler = false},
            {prefabs = {"seeds"}, min_count = 4, max_count = 6, reset = false, add_filler = false},
            {prefabs = {"tentaclespots"}, min_count = 1, max_count = 1, reset = false, add_filler = true},
            {prefabs = {"cutreeds"}, min_count = 1, max_count = 2, reset = false, add_filler = true},
            {
                prefabs = {
                    -- These trinkets are generally good for team play, but tend to be poor for solo play.
                    -- Theme
                    "trinket_12", -- Dessicated Tentacle
                    "trinket_25", -- Air Unfreshener
                    -- Team
                    "trinket_1", -- Melted Marbles
                    -- Fishing
                    "trinket_17", -- Bent Spork
                    "trinket_8" -- Rubber Bung
                },
                min_count = 1,
                max_count = 1,
                reset = false,
                add_filler = true
            },
            {
                prefabs = {"durian_seeds", "pepper_seeds", "eggplant_seeds", "pumpkin_seeds", "onion_seeds", "garlic_seeds"},
                min_count = 1,
                max_count = 2,
                reset = false,
                add_filler = true
            }
        }
        local trading_filler = {"seeds", "kelp", "seeds", "seeds"}

        local function OnGivenItem(inst, giver, item)
            inst.components.prototyper.onactivate(inst, giver)
            -- inst.components.prototyper.onactivate(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
            local selected_index = math.random(1, #inst.trading_items)
            local selected_item = inst.trading_items[selected_index]

            local isabigheavyfish = item.components.weighable and item.components.weighable:GetWeightPercent() >= TUNING.WEIGHABLE_HEAVY_WEIGHT_PERCENT or false
            local bigheavyreward = isabigheavyfish and math.random(1, 2) or 0

            local filler_min = 2 -- Not biasing minimum for filler.
            local filler_max = 4 + bigheavyreward
            local reward_count = math.random(selected_item.min_count, selected_item.max_count) + bigheavyreward

            for k = 1, reward_count do
                local spawn = inst.components.lootdropper:SpawnLootPrefab(selected_item.prefabs[math.random(1, #selected_item.prefabs)])
                giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
            end

            if selected_item.add_filler then
                for i = filler_min, filler_max do
                    local spawn = inst.components.lootdropper:SpawnLootPrefab(trading_filler[math.random(1, #trading_filler)])
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end

            if item:HasTag("oceanfish") then
                local goldmin, goldmax, goldprefab = 1, 2, "goldnugget"
                if item.prefab:find("oceanfish_medium_") == 1 then
                    goldmin, goldmax = 2, 4
                    if item.prefab == "oceanfish_medium_6_inv" or item.prefab == "oceanfish_medium_7_inv" then -- YoT events.
                        goldprefab = "lucky_goldnugget"
                    end
                end

                local amt = math.random(goldmin, goldmax) + bigheavyreward
                for i = 1, amt do
                    local spawn = inst.components.lootdropper:SpawnLootPrefab(goldprefab)
                    giver.components.inventory:GiveItem(spawn, nil, inst:GetPosition())
                end
            end

            -- Cycle out rewards.
            table.remove(inst.trading_items, selected_index)
            if #inst.trading_items == 0 or selected_item.reset then inst.trading_items = deepcopy(trading_items) end
            item:Remove()
        end

        local function OnRefuseItem(inst, giver, item)
            inst.components.workable.onwork(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl3_ding")
        end

        local function AcceptTest(inst, item)
            if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then return false end
            return item:HasTag("fish")
        end
        AddPrefabPostInit("tacklestation", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.trader then return end
            inst.trading_items = deepcopy(trading_items)
            inst:AddComponent("trader")
            inst.components.trader.deleteitemonaccept = false
            inst.components.trader.acceptnontradable = true
            inst.components.trader:SetAcceptTest(AcceptTest)
            inst.components.trader.onaccept = OnGivenItem
            inst.components.trader.onrefuse = OnRefuseItem
            inst:ListenForEvent("onburnt", function() inst:RemoveComponent("trader") end)
        end)
    end
end

-- 制图桌制作蓝图
if GetModConfigData("Cartographer's Desk Make Blueprint") then
    -- 可以添加女武神之力的图纸
    local valkyrie_sketchLoot
    if not TUNING.erasablepapertag2hm then
        TUNING.erasablepapertag2hm = true
        AddComponentPostInit("erasablepaper", function(self) self.inst:AddTag("erasablepaper") end)
    end
    local txt = TUNING.isCh2hm and "制图" or "Cartography"
    STRINGS.ACTIONS.BLUEPRINT2HM = txt
    local blueprintaction = Action({priority = -0.01})
    blueprintaction.id = "BLUEPRINT2HM"
    blueprintaction.str = txt
    blueprintaction.fn = function(act)
        if act.invobject and act.invobject:IsValid() and act.target and act.target:IsValid() and act.doer and act.doer:IsValid() and
            act.doer.components.inventory then
            if act.invobject.prefab == "papyrus" then
                local items = act.doer.components.inventory:GetItemsWithTag("erasablepaper")
                if #items > 0 then
                    for index, item in ipairs(items) do
                        if item:IsValid() and
                            (item.prefab == "blueprint" or item.prefab == "cookingrecipecard" or item:HasTag("scrapbook_note") or item.components.scrapbookable or
                                item:HasTag("sketch") or item:HasTag("tacklesketch") or item.components.yotb_skinunlocker) then
                            -- 不能复制女武神勋章需要的BOSS图纸
                            if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then
                                local sketchname = item.GetSpecificSketchPrefab and item:GetSpecificSketchPrefab() or nil
                                if sketchname and not valkyrie_sketchLoot then
                                    local medal = SpawnPrefab("valkyrie_certificate")
                                    if medal then
                                        if medal.valkyrie_sketchLoot then
                                            valkyrie_sketchLoot = medal.valkyrie_sketchLoot or {}
                                        else
                                            valkyrie_sketchLoot = {}
                                        end
                                        medal:Remove()
                                    else
                                        valkyrie_sketchLoot = {}
                                    end
                                end
                                if sketchname and valkyrie_sketchLoot[sketchname] then return end
                            end
                            local newitem = SpawnPrefab(item.prefab)
                            if newitem then
                                if act.doer.soundemitter then
                                    act.doer.soundemitter:PlaySound("dontstarve/common/together/packaged")
                                end
                                if act.invobject.components.stackable and act.invobject.components.stackable.stacksize > 1 then
                                    act.invobject.components.stackable:SetStackSize(act.invobject.components.stackable.stacksize - 1)
                                else
                                    act.invobject:Remove()
                                end
                                newitem:SetPersistData(item:GetPersistData())
                                if newitem.components.inventoryitem then
                                    act.doer.components.inventory:GiveItem(newitem, nil, act.target:GetPosition())
                                else
                                    newitem.Transform:SetPosition(act.target.Transform:GetWorldPosition())
                                    if act.target.lootdropper then act.target.lootdropper:FlingItem(newitem) end
                                end
                                return true
                            end
                        end
                    end
                end
            end
            local recipe = AllRecipes[act.invobject.prefab]
            if recipe and not recipe.nounlock and (recipe.builder_tag == nil or act.doer:HasTag(recipe.builder_tag)) and act.doer.components.builder and
                act.doer.components.builder:KnowsRecipe(recipe, true) and act.doer.components.inventory:Has("papyrus", 1) then
                local blueprint = SpawnPrefab("blueprint")
                if blueprint then
                    if act.doer.soundemitter then act.doer.soundemitter:PlaySound("dontstarve/common/together/packaged") end
                    act.doer.components.inventory:ConsumeByName("papyrus", 1)
                    blueprint.recipetouse = recipe.name or "unknown"
                    blueprint.components.teacher:SetRecipe(blueprint.recipetouse)
                    blueprint.components.named:SetName(STRINGS.NAMES[string.upper(blueprint.recipetouse)] .. " " .. STRINGS.NAMES.BLUEPRINT)
                    act.doer.components.inventory:GiveItem(blueprint, nil, act.target:GetPosition())
                    return true
                end
            end
        end
    end
    AddAction(blueprintaction)
    table.insert(TUNING.USEITEMFNS2HM, function(inst, doer, target, actions)
        if target.prefab == "cartographydesk" then
            if inst.prefab == "papyrus" then
                table.insert(actions, ACTIONS.BLUEPRINT2HM)
            else
                local recipe = AllRecipes[inst.prefab]
                if recipe and not recipe.nounlock and (recipe.builder_tag == nil or doer:HasTag(recipe.builder_tag)) and doer.replica and doer.replica.builder and
                    doer.replica.builder:KnowsRecipe(recipe, true) then table.insert(actions, ACTIONS.BLUEPRINT2HM) end
            end
        end
    end)
    AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.BLUEPRINT2HM, function(inst, action) return "dolongaction" end))
    AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.BLUEPRINT2HM, function(inst, action) return "dolongaction" end))
end

-- 沙之石激活传送塔
if GetModConfigData("townportal use sandstone activate") then
    local select_if_mark = GetModConfigData("townportal use sandstone activate")
    select_if_mark = select_if_mark == true or select_if_mark == 2  -- melon:是否有标记
    local function addfx(inst)
        if not inst.sandstonefx2hm then
            local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
            fx.AnimState:SetMultColour(1, 1, 1, 0.5)
            fx.entity:SetParent(inst.entity)
            inst.sandstonefx2hm = fx
        end
        if inst:HasTag("channeled2hm") then
            inst.sandstonefx2hm:Show()
        else
            inst.sandstonefx2hm:Hide()
        end
    end
    AddComponentPostInit("channelable", function(self)
        local oldIsChanneling = self.IsChanneling
        self.IsChanneling = function(self, ...) return (self.inst.prefab == "townportal" and self.channeler == self.inst) or oldIsChanneling(self, ...) end
        local oldStartChanneling = self.StartChanneling
        self.StartChanneling = function(self, channeler, ...)
            if self.inst.prefab == "townportal" and channeler and channeler:IsValid() and channeler.prefab == "townportaltalisman" then
                TheWorld:PushEvent("townportaldeactivated", self.inst) -- 2025.10.3 melon:修复科雷更新导致的bug
                channeler:Remove()
                self.channeler = self.inst
                if self.onchannelingfn ~= nil then self.onchannelingfn(self.inst, self.inst) end
                self.inst:StartUpdatingComponent(self)
                self.inst.components.persistent2hm.data.townportaltalisman = true
                self.inst:AddTag("channeled2hm")
                addfx(self.inst)
                return true
            end
            return oldStartChanneling(self, channeler, ...)
        end
        local oldStopChanneling = self.StopChanneling
        self.StopChanneling = function(self, aborted, ...)
            if self.inst.prefab == "townportal" and self.channeler == self.inst then
                self.inst.components.persistent2hm.data.townportaltalisman = nil
                self.inst:RemoveTag("channeled2hm")
                self.channeler = nil
                self.inst:StopUpdatingComponent(self)
                addfx(self.inst)
                if self.onstopchannelingfn ~= nil then self.onstopchannelingfn(self.inst, aborted) end
                self.inst.components.lootdropper:FlingItem(SpawnPrefab("townportaltalisman"))
                return
            end
            return oldStopChanneling(self, aborted, ...)
        end
    end)
    -- 打断正在沙之石激活的传送塔
    AddComponentAction("SCENE", "channelable", function(inst, doer, actions, right)
        if right and inst:HasTag("channelable") and inst:HasTag("channeled") and not doer:HasTag("channeling") and inst:HasTag("channeled2hm") then
            if ACTIONS.STOPCHANNELING.instant == true then ACTIONS.STOPCHANNELING.instant = false end
            table.insert(actions, ACTIONS.STOPCHANNELING)
        elseif ACTIONS.STOPCHANNELING.instant ~= true then
            ACTIONS.STOPCHANNELING.instant = true
        end
    end)
    AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.STOPCHANNELING, function(inst, action) return "dolongaction" end))
    AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.STOPCHANNELING, function(inst, action) return "dolongaction" end))
    local function processpersistent(inst)
        if inst.components.persistent2hm.data.townportaltalisman and inst.components.channelable then
            inst.components.channelable:StartChanneling(SpawnPrefab("townportaltalisman"))
        end
    end
    AddPrefabPostInit("townportal", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst:DoTaskInTime(0, processpersistent)
    end)
    local function marbleUSEITEM(inst, doer, actions, right, target) return target.prefab == "townportal" end
    local function marbleUSEITEMdoaction(inst, doer, target, pos, act)
        if target.components.channelable and not target:HasTag("channeled2hm") then
            if not target:HasTag("channeled") and target:HasTag("channelable") then
                local item = inst.components.stackable and inst.components.stackable:Get() or inst
                target.components.channelable:StartChanneling(item)
                return true
            elseif not target:HasTag("channeled") and not target:HasTag("channelable") and inst.components.teleporter then
                local teleporter = inst.components.teleporter.targetTeleporter
                if teleporter and teleporter:IsValid() and teleporter.prefab == "townportal" and teleporter.components.channelable and
                    teleporter:HasTag("channeled") and teleporter:HasTag("channeled2hm") then
                    teleporter.components.channelable:StopChanneling(true)
                    local item = inst.components.stackable and inst.components.stackable:Get() or inst
                    target.components.channelable:StartChanneling(item)
                    return true
                end
            end
        end
    end
    STRINGS.ACTIONS.ACTION2HM.TOWNPORTALTALISMAN = TUNING.isCh2hm and "激活" or "Activate"
    AddPrefabPostInit("townportaltalisman", function(inst)
        inst.actionothercondition2hm = marbleUSEITEM
        if not TheWorld.ismastersim then return end
        inst:AddComponent("action2hm")
        inst.components.action2hm.actionfn = marbleUSEITEMdoaction
    end)
    -- 2025.7.30 melon:沙之石传送改动.选择夹角最小的懒人塔进行传送--------------------------
    -- 沙之石传送，站塔旁边，传送夹角更小的塔   (塔->自己，塔->目标塔)的夹角
    -- 去除一遍不合法的塔------------------
    local function check(list)
        if list == nil then return false end
        local res = false
        for i = #list, 1, -1 do
            if not list[i]:IsValid() then
                table.remove(list, i)  -- 从表中移除
                res = true
            end
        end
        return res
    end
    -- 删除一个塔的标记-----------------------
    local function remove_one_mark(inst)
        if TUNING.townportal_mark2hm == nil or TUNING.townportal_mark2hm[inst] == nil then return end
        for j=#TUNING.townportal_mark2hm[inst], 1, -1 do
            TUNING.townportal_mark2hm[inst][j]:Remove()
            table.remove(TUNING.townportal_mark2hm[inst], j)
        end
        TUNING.townportal_mark2hm[inst] = nil
        if inst.mark_fx2hm then inst.mark_fx2hm:Remove() end
    end
    -- 删除所有标记-----------------------
    local function remove_all_mark(list) -- 不能用下标遍历，内层可以
        if list == nil then return end
        for k,item in pairs(list) do
            for j=#item, 1, -1 do -- item里的可以这么遍历
                item[j]:Remove()
                table.remove(item, j) -- 从表中移除
            end
            list[k] = nil -- 删除
        end
    end
    -- 2025.8.28 melon:用特效标记其它塔的方向-------------------------
    local DIST = 7 -- 距离塔7个石墙距离
    local function reset_mark(list) -- TUNING.townportal_list2hm
        check(list)
        if list == nil or #list < 2 then return end
        remove_all_mark(TUNING.townportal_mark2hm)
        if TUNING.townportal_mark2hm == nil then TUNING.townportal_mark2hm = {} end -- 保存标记
        for i=1,#list do
            local t1 = list[i]
            if TUNING.townportal_mark2hm[t1] == nil then TUNING.townportal_mark2hm[t1] = {} end
            for j=1,#list do
                local t2 = list[j]
                -- 在塔t1附近画塔t2的标记
                if t1 ~= t2 then -- 不给自己画
                    local x,y,z = t1.Transform:GetWorldPosition()
                    local a,b,c = t2.Transform:GetWorldPosition()
                    local dx = a-x
                    local dz = c-z
                    -- 将标记放在塔附近的圆形上---------
                    local sqrt = math.sqrt(dx^2 + dz^2)
                    -- 画标记，并保存
                    local fx = SpawnPrefab("pocketwatch_warp_marker")
                    fx.Transform:SetPosition(x + dx*DIST/sqrt, 0, z + dz*DIST/sqrt) -- 先乘再除应该更准确
                    -- 根据塔t2自己的标记id画
                    fx.AnimState:PlayAnimation("mark".. tostring(math.clamp(t2.mark_id2hm or 1,1,4)) .. "_pre") --mark2_pre/mark3_pre/mark4_pre
                    local color = t2.mark_color2hm -- 要防止是空
                    fx.AnimState:SetMultColour(color and color.r or 1,color and color.g or 1,color and color.b or 1,1) -- 颜色
                    fx:Show()
                    table.insert(TUNING.townportal_mark2hm[t1], fx)
                end
            end
        end
    end
    -- 减少沙石的san消耗------------------------------------
    local function OnStartTeleporting(inst, doer)
        if doer:HasTag("player") then
            if doer.components.talker ~= nil then
                doer.components.talker:ShutUp()
            end
            if doer.components.sanity ~= nil then
                doer.components.sanity:DoDelta(-30) -- 改为30
            end
        end
    end
    -- 2025.8.31 melon:每个塔随机一个标记，随机之后固定 -----
    local function saveandloadmarkid2hm(inst) -- 保存
        local oldsave = inst.OnSave
        inst.OnSave = function(inst, data)
            if oldsave ~= nil then oldsave(inst, data) end
            data.mark_id2hm = inst.mark_id2hm
            data.mark_color2hm = inst.mark_color2hm
        end
        local oldload = inst.OnLoad
        inst.OnLoad = function(inst, data)
            if oldload ~= nil then oldload(inst, data) end
            inst.mark_id2hm = data and data.mark_id2hm
            inst.mark_color2hm = data and data.mark_color2hm
        end
    end
    -- 生成，刚做的时候展示
    local mark_colors = {
        {r=1, g=1, b=1}, -- 2个  概率大
        {r=1, g=1, b=1},
        {r=255 / 255, g=193 / 255, b=37 / 255}, -- 橙
        {r=50 / 255, g=205 / 255, b=50 / 255}, -- 绿
        {r=238 / 255, g=130 / 255, b=238 / 255}, -- 粉
    }
    local function set_mark_id(inst)
        if inst.mark_id2hm == nil then inst.mark_id2hm = math.random(4) end
        if inst.mark_color2hm == nil then inst.mark_color2hm = mark_colors[math.random(#mark_colors)] end
        -- 刚建造时展示一下自己的符号
        local x,y,z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("pocketwatch_warp_marker")
        fx.Transform:SetPosition(x, 0, z + 1.5) -- (0, 1)
        fx.AnimState:PlayAnimation("mark".. tostring(math.clamp(inst.mark_id2hm,1,4)) .. "_pre")
        fx.AnimState:SetMultColour(inst.mark_color2hm.r or 1,inst.mark_color2hm.g or 1,inst.mark_color2hm.b or 1,1)
        fx:Show()
        inst.mark_fx2hm = fx
    end
    -- 所有塔存到TUNING里
    AddPrefabPostInit("townportal", function(inst)
        if not TheWorld.ismastersim then return end
        if TUNING.townportal_list2hm == nil then TUNING.townportal_list2hm = {} end
        table.insert(TUNING.townportal_list2hm, inst)
        if inst.components.teleporter then
            inst.components.teleporter.onActivate = OnStartTeleporting
        end
        if select_if_mark then -- 是否画标记
            -- 2025.8.31 melon:每个塔随机一个标记，随机之后固定。刚建造时展示一下
            saveandloadmarkid2hm(inst) -- 保存
            inst.mark_idtask2hm = inst:DoTaskInTime(0, set_mark_id)
            -- 2025.8.28 melon:做新的、拆塔时刷新一下所有塔的标记点
            inst.marktask2hm = inst:DoTaskInTime(0, function(inst) reset_mark(TUNING.townportal_list2hm) end)
            -- 删除时删除相关的点
            local _Remove = inst.Remove
            inst.Remove = function(inst)
                remove_one_mark(inst)
                if _Remove ~= nil then _Remove(inst) end
            end
        end
    end)
    local function ToggleOnPhysics(inst)
        inst.sg.statemem.isphysicstoggle = nil
        inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
    end
    local function ToggleOffPhysics(inst)
        inst.sg.statemem.isphysicstoggle = true
        inst.Physics:SetCollisionMask(COLLISION.GROUND)
    end
    -- 仅改为UseTemporaryExit
    AddStategraphState("wilson", State{
        name = "entertownportal2hm",
        tags = { "doing", "busy", "nopredict", "nomorph", "nodangle" },
        onenter = function(inst, data)
            ToggleOffPhysics(inst)
            inst.Physics:Stop()
            inst.components.locomotor:Stop()
            inst.sg.statemem.target = data.teleporter
            inst.sg.statemem.teleportarrivestate = "exittownportal_pre"
            inst.AnimState:PlayAnimation("townportal_enter_pre")
            inst.sg.statemem.fx = SpawnPrefab("townportalsandcoffin_fx")
            inst.sg.statemem.fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end,
        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                inst.sg.statemem.isteleporting = true
                inst.components.health:SetInvincible(true)
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(false)
                end
                inst.DynamicShadow:Enable(false)
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst:Hide()
            end),
            TimeEvent(26 * FRAMES, function(inst)
                if inst.sg.statemem.target ~= nil and
                    inst.sg.statemem.target.components.teleporter ~= nil and
                    -- 改为临时传送点
                    inst.sg.statemem.target.components.teleporter:UseTemporaryExit(inst, inst.sg.statemem.target) then
                    inst:Hide()
                    inst.sg.statemem.fx:KillFX()
                else
                    inst.sg:GoToState("exittownportal")
                end
            end),
        },
        onexit = function(inst)
            inst.sg.statemem.fx:KillFX()
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
            if inst.sg.statemem.isteleporting then
                inst.components.health:SetInvincible(false)
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(true)
                end
                inst:Show()
                inst.DynamicShadow:Enable(true)
            end
        end,
    })
    -- 计算(p1p2,p1p3)夹角的cos值，距离  cos值越大，夹角越小
    -- 2025.8.1 melon:优化，用 cos*|cos| 代替cos来比较 用平方代替开方减少运算
    local function angle_len(p1, p2, p3)
        if p1 == nil or p2 == nil or p3 == nil then return end
        local v1 = {x = p2.x - p1.x, z = p2.z - p1.z}
        local v2 = {x = p3.x - p1.x, z = p3.z - p1.z}
        local dot = v1.x * v2.x + v1.z * v2.z
        dot = dot * math.abs(dot)  -- dot*|dot|可保留符号
        -- local len = math.sqrt(v1.x^2 + v1.z^2) * math.sqrt(v2.x^2 + v2.z^2)
        local len = (v1.x^2 + v1.z^2) * (v2.x^2 + v2.z^2)
        return dot/len, len
    end
    -- 先仅按角度画叉标记试试，画在塔附近的正方形上(比画在圈上的好处:避免算cos/sin减少计算)
    -- 找夹角更小的塔
    local function findteleporter(doer, near_townportal)
        -- 先去除一遍不合法的塔  被敲了的
        local ifchange = check(TUNING.townportal_list2hm)
        if ifchange then reset_mark(TUNING.townportal_mark2hm) end
        -- 至少2个塔
        if TUNING.townportal_list2hm == nil or #TUNING.townportal_list2hm < 2 then return nil end
        local angle = nil
        local len = nil
        local min_town = nil -- 夹角最小的塔
        -- 找个不是near_townportal的算一个初始角度
        if TUNING.townportal_list2hm[1] ~= near_townportal then
            angle, len = angle_len(near_townportal:GetPosition(), doer:GetPosition(), TUNING.townportal_list2hm[1]:GetPosition())
            min_town = TUNING.townportal_list2hm[1]
        else
            angle, len = angle_len(near_townportal:GetPosition(), doer:GetPosition(), TUNING.townportal_list2hm[2]:GetPosition())
            min_town = TUNING.townportal_list2hm[2]
        end
        local cur_angle = nil
        local cur_len = nil
        for _, town in ipairs(TUNING.townportal_list2hm) do
            if town:IsValid() and town ~= near_townportal and town ~= min_town then
                cur_angle, cur_len = angle_len(near_townportal:GetPosition(), doer:GetPosition(), town:GetPosition())
                if cur_angle == angle and cur_len < len or cur_angle > angle then -- 越大夹角越近?
                    angle = cur_angle
                    len = cur_len
                    min_town = town
                end
            end
        end
        return min_town
    end
    local function Findtownportal(doer)
        return FindEntity(doer, 8, -- 半径范围(黑虚线半径6)
                function(guy) return guy.prefab == "townportal" end,
                {"townportal"}, nil)
    end
    -- 使用传送时遍历TUNING.townportal_list2hm进行选择
    local _fn = ACTIONS.TELEPORT.fn
    ACTIONS.TELEPORT.fn = function(act)
        local choose_townportal = nil
        -- 判断离塔够近
        local near_townportal = Findtownportal(act.doer) -- 找到8距离以内的塔
        if near_townportal ~= nil then
            if act.doer ~= nil and act.doer.sg ~= nil then
                -- 寻找最符合站位的teleporter
                local teleporter = findteleporter(act.doer, near_townportal)
                -- 替换原有的teleporter
                if act.invobject ~= nil and teleporter ~= nil then
                    if act.doer.sg.currentstate.name == "dolongaction" then -- 仅改用沙之石的情况
                        choose_townportal = teleporter
                    end
                end
            end
        end
        if choose_townportal ~= nil then
            if act.invobject.components.stackable then
                act.invobject.components.stackable:Get():Remove() -- 删除1个
            end
            act.doer.sg:GoToState("entertownportal2hm", { teleporter = choose_townportal })
            return true
        else
            return _fn(act) -- 原本的传送
        end
    end
    -- 2025.7.30 end ----------------------------------------------------------------
end

-- 假人交换随从
local mannequinmode = GetModConfigData("mannequin swap follower")
if mannequinmode then
    AddComponentPostInit("combat", function(class)
        local oldTryRetarget = class.TryRetarget
        class.TryRetarget = function(self)
            if self.inst.components.follower then
                local leader = self.inst.components.follower:GetLeader()
                if leader and leader.prefab == "sewing_mannequin" then
                    return
                end
            end
            return oldTryRetarget(self)
        end
    end)
    AddPrefabPostInit("sewing_mannequin", function(inst)
        if not TheWorld.ismastersim then return end
        if mannequinmode ~= -1 then
            if inst.components.inventory then inst:RemoveComponent("inventory") end
            inst:AddComponent("inventory")
            inst.components.inventory.maxslots = 20
            if not inst.components.preserver then
                inst:AddComponent("preserver")
                inst.components.preserver:SetPerishRateMultiplier(function(inst, item)
                    return item and item:HasTag("spider") and 0 or 1
                end)
            end
        end
        if inst.components.activatable and not inst.components.leader then
            inst:AddComponent("leader")
            if inst.sg == nil then
                inst:SetStateGraph("SGwormhole")
                inst.AnimState:PlayAnimation("idle")
            end
            local OnActivate = inst.components.activatable.OnActivate
            inst.components.activatable.OnActivate = function(inst, doer, ...)
                local result, reason = OnActivate(inst, doer, ...)
                if doer and doer:IsValid() and doer.components.leader and inst.components.leader then
                    local time = GetTime()
                    local doerfollowers = {}
                    local instfollowers = {}
                    for follower, status in pairs(doer.components.leader.followers) do
                        if status and follower and follower:IsValid() and not follower:IsInLimbo() and not follower:HasTag("abigail") and
                            not follower.LinkToPlayer and not follower:HasTag("swc2hm") and follower.components.health and follower.components.follower and
                            follower.components.combat and follower.components.combat.defaultdamage > 0 and not follower.components.combat.target then
                            -- and (not follower.components.persistent2hm or (not follower.components.persistent2hm.data.rangemonster)) then
                            if follower:HasTag("swp2hm") and follower.components.childspawner2hm and follower.components.childspawner2hm.numchildrenoutside > 0 and
                                follower.components.playerprox2hm and follower.components.playerprox2hm.isclose then
                                follower.components.playerprox2hm.isclose = false
                                follower:PushEvent("onfar2hm")
                                if follower.components.playerprox2hm.onfar ~= nil then
                                    follower.components.playerprox2hm.onfar(follower)
                                end
                            end
                            doerfollowers[follower] = {
                                maxfollowtime = follower.components.follower.maxfollowtime,
                                time = follower.components.follower.targettime and follower.components.follower.targettime > time and
                                    math.floor(follower.components.follower.targettime - time)
                            }
                        end
                    end
                    local inventory = inst.components.inventory
                    if mannequinmode ~= -1 and inventory then
                        for k = 1, inventory.maxslots do
                            local v = inventory.itemslots[k]
                            if v ~= nil and v.components.health and v.components.follower and v.components.combat then
                                if v.components.follower.leader == nil then inst.components.leader:AddFollower(v) end
                                if v.components.combat.target then v.components.combat:DropTarget() end
                                inventory:DropItem(v, true, true)
                            end
                        end
                    end
                    for follower, status in pairs(inst.components.leader.followers) do
                        if status and follower and follower:IsValid() and not follower:IsInLimbo() and not follower:HasTag("swc2hm") and
                            follower.components.health and follower.components.follower and follower.components.combat and
                            follower.components.combat.defaultdamage > 0 and not follower.components.combat.target and
                            -- 2025.8.17 melon:小分队不跟随非芜猴
                            (doer.prefab == "wonkey" or (follower.prefab ~= "powder_monkey_p" and follower.prefab ~= "prime_mate_p")) then
                            if follower:HasTag("swp2hm") and follower.components.childspawner2hm and follower.components.childspawner2hm.numchildrenoutside > 0 and
                                follower.components.playerprox2hm and follower.components.playerprox2hm.isclose then
                                follower.components.playerprox2hm.isclose = false
                                follower:PushEvent("onfar2hm")
                                if follower.components.playerprox2hm.onfar ~= nil then
                                    follower.components.playerprox2hm.onfar(follower)
                                end
                            end
                            instfollowers[follower] = {
                                maxfollowtime = follower.components.follower.maxfollowtime,
                                time = follower.components.follower.targettime and follower.components.follower.targettime > time and
                                    math.floor(follower.components.follower.targettime - time)
                            }
                        end
                    end
                    local leftslot = 0
                    if mannequinmode ~= -1 and inventory then
                        for k = 1, inventory.maxslots do if not inventory.itemslots[k] then leftslot = leftslot + 1 end end
                    end
                    if not result then
                        result = not IsTableEmpty(doerfollowers) or not IsTableEmpty(instfollowers)
                        if result then
                            inst.AnimState:PlayAnimation("swap")
                            inst.SoundEmitter:PlaySound("stageplay_set/mannequin/swap")
                            inst.AnimState:PushAnimation("idle", false)
                        end
                    end
                    for follower, data in pairs(doerfollowers) do
                        inst.components.leader:AddFollower(follower)
                        if data.maxfollowtime then follower.components.follower.maxfollowtime = data.maxfollowtime end
                        if data.time then follower.components.follower:AddLoyaltyTime(data.time) end
                        if mannequinmode ~= -1 and follower.components.inventoryitem and follower.components.inventoryitem.canbepickedupalive and leftslot > 0 then
                            leftslot = leftslot - 1
                            SpawnPrefab("spawn_fx_small").Transform:SetPosition(follower.Transform:GetWorldPosition())
                            inventory:GiveItem(follower)
                            if follower.components.perishable and follower:HasTag("spider") then follower.components.perishable:StopPerishing() end
                        end
                    end
                    for follower, data in pairs(instfollowers) do
                        doer.components.leader:AddFollower(follower)
                        if data.maxfollowtime then follower.components.follower.maxfollowtime = data.maxfollowtime end
                        if data.time then follower.components.follower:AddLoyaltyTime(data.time) end
                    end
                end
                return result, reason
            end
        end
    end)

    -- 鱼人被寄存到假人后，lunarmerm_thorns_fx 的 leader 会变成假人；
    -- 假人没有 combat 组件，核心 merm_fx.lua 会索引 leader.components.combat 崩溃。
    -- 这里包一层保护：单个尖刺 FX 更新出错时移除该 FX，避免整个服务器崩溃。
    AddPrefabPostInit("lunarmerm_thorns_fx", function(inst)
        if not TheWorld.ismastersim then return end
        local ul = inst.components.updatelooper
        if ul == nil or ul.onupdatefns == nil then return end
        for i, fn in ipairs(ul.onupdatefns) do
            ul.onupdatefns[i] = function(fx, dt)
                local ok, err = pcall(fn, fx, dt)
                if not ok then
                    print("[HappyPatch] lunarmerm_thorns_fx update error: " .. tostring(err))
                    if fx:IsValid() then fx:Remove() end
                end
            end
        end
    end)
end

-- 龙鳞火锅烹批量饪
local dragonflyfurnace = GetModConfigData("dragonfly furnace stewer")
if dragonflyfurnace and not ModManager:GetMod("workshop-3193922031") then
    local cooking = require("cooking")
    local containers = require("containers")
    local ImageButton = require "widgets/imagebutton"
    local Text = require "widgets/text"
    cooking.recipes.dragonflyfurnace = cooking.recipes.portablecookpot
    -- 新UI
    containers.params.dragonflyfurnace.widget.animbank = "ui_dragonflyfurnace2hm"
    containers.params.dragonflyfurnace.widget.animbuild = "ui_dragonflyfurnace2hm"
    -- 额外增加一个只能放红宝石的格子
    containers.params.dragonflyfurnace.itemtestfn = function(container, item, slot, ...)
        return (slot == 1 and item.prefab == "redgem") or ((slot == nil or slot > 1) and not item:HasTag("irreplaceable"))
    end
    containers.params.dragonflyfurnace.usespecificslotsforitems = true
    AddPrefabPostInit("dragonflyfurnace", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.container ~= nil then
            local GetSpecificSlotForItem = inst.components.container.GetSpecificSlotForItem
            inst.components.container.GetSpecificSlotForItem = function(self, item, ...)
                local result = GetSpecificSlotForItem(self, item, ...)
                if result >= 2 then
                    for i = self.numslots, 2, -1 do
                        local item = self.slots[i]
                        if not item then return i end
                    end
                elseif result == 1 then
                    local item = self.slots[1]
                    if not item then return 1 end
                end
                return result
            end
            local olddestroyfn = inst.components.container.DestroyContentsConditionally
            if olddestroyfn then
                inst.components.container.DestroyContentsConditionally = function(self, ...)
                    local itemdata = {}
                    for k = 1, self.numslots do
                        local item = self:GetItemInSlot(k)
                        if item then 
                            itemdata[k] = {
                                itemprefab = item.prefab,
                                itemstack = item.components.stackable and item.components.stackable:StackSize()
                            } 
                        end
                    end
                    olddestroyfn(self, ...)
                    for i, v in pairs(itemdata) do
                        if self:GetItemInSlot(i) == nil and v and v.itemprefab == "log" then
                            local charcoal = SpawnPrefab("charcoal")
                            if not charcoal then return end
                            if v.itemstack and charcoal.components.stackable then charcoal.components.stackable:SetStackSize(v.itemstack) end
                            local result = self:GiveItem(charcoal, i)
                            if not result then charcoal:Remove() end
                        end
                    end
                end
            end
        end
        if inst.components.incinerator then
            local oldfn = inst.components.incinerator.shouldincinerateitemfn
            inst.components.incinerator.shouldincinerateitemfn = function(inst, item, ...)
                local slotnum = item.components.inventoryitem and item.components.inventoryitem:GetSlotNum()
                if slotnum == 1 then
                    return false
                else
                    return oldfn(inst, item, ...)
                end
            end
        end
    end)
    -- 新增UI格子图标和数字显示
    AddClassPostConstruct("widgets/containerwidget", function(self)
        local oldOpen = self.Open
        self.Open = function(self, container, doer, ...)
            local result = oldOpen(self, container, doer, ...)
            if container and container.prefab ~= "dragonflyfurnace" then return result end
            local image = self:AddChild(Image("images/inventoryimages2.xml", "portablecookpot_item.tex"))
            image:SetSize(75,75)
            image:SetPosition(-72, 127, 0)
            local text = self:AddChild(Text(NUMBERFONT, 42))
            text:SetPosition(-72, 84, 0)
            text:SetString((TUNING.isCh2hm and "剩：" or "Uses：") .. tostring(container.redgem2hm:value()))
            self.portablecookpot_item2hm = image
            self.text2hm =text
            for k, v in pairs(self.inv) do
                if k == 1 then
                    v:SetBGImage2("images/inventoryimages2.xml", "redgem.tex", {1, 1, 1, 0.5})
                    local w, h = v.bgimage:GetSize()
                    v.bgimage2:SetSize(w, h)
                end
            end
            return result
        end
        local oldClose = self.Close
        self.Close = function(self, ...)
            if self.container and self.container.prefab ~= "dragonflyfurnace" then return oldClose(self, ...) end
            if self.portablecookpot_item2hm then
                self.portablecookpot_item2hm:Kill()
                self.portablecookpot_item2hm = nil
            end
            if self.text2hm then
                self.text2hm:Kill()
                self.text2hm = nil
            end
            oldClose(self, ...)
        end
    end)
    -- 做饭期间可以加燃料缩短做饭时间
    local function clearfuel(inst) if inst.components.fueled then inst.components.fueled.currentfuel = 0 end end
    local function ontakefuel(inst, fuelvalue)
        inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
        local self = inst.components.stewer
        if self and self:IsCooking() and self.task and self.targettime and fuelvalue then
            fuelvalue = fuelvalue * 0.7
            local dostew = self.task.fn
            if self.task ~= nil then self.task:Cancel() end
            self.targettime = math.max(self.targettime - fuelvalue, GetTime())
            self.task = self.inst:DoTaskInTime(self.targettime - GetTime(), dostew, self)
        end
        inst:DoTaskInTime(0, clearfuel)
    end
    local function startcookfn(inst)
        if inst.stewercooktask2hm then
            inst.stewercooktask2hm:Cancel()
            inst.SoundEmitter:KillSound("snd")
            inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_rattle", "snd")
        else
            inst.SoundEmitter:KillSound("loop")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/place")
        end
        inst.AnimState:PlayAnimation("incinerate")
        inst.AnimState:PushAnimation("hi", true)
        local time = inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime() + FRAMES
        inst.stewercooktask2hm = inst:DoTaskInTime(time, startcookfn)
        -- 做饭期间可以把东西放火炉上烹饪
        if not inst:HasTag("burnt") then inst:AddTag("burnt") end
        if not inst.components.cooker then
            inst:AddComponent("cooker")
            if inst.updatecookitem2hm then inst.updatecookitem2hm(inst, 0.15) end
        end
        -- 做饭期间可以给燃料缩短做饭时间
        if not inst.components.fueled then
            inst:AddComponent("fueled")
            inst.components.fueled.maxfuel = TUNING.CAMPFIRE_FUEL_MAX
            inst.components.fueled.currentfuel = 0
            inst.components.fueled.accepting = true
            inst.components.fueled:SetTakeFuelFn(ontakefuel)
        end
    end
    -- local function autoHarvest(inst) inst.components.stewer:Harvest(inst) end
    local function donecookfn(inst)
        if inst.stewercooktask2hm then
            inst.stewercooktask2hm:Cancel()
            inst.stewercooktask2hm = nil
        end
        inst.SoundEmitter:KillSound("snd")
        inst.SoundEmitter:KillSound("loop")
        -- inst:DoTaskInTime(0, autoHarvest)
        inst:RemoveTag("burnt")
        if inst.components.fueled then inst:RemoveComponent("fueled") end
    end
    -- 收获后，去除厨师食谱
    local function onharvest(inst, harvester)
        inst:RemoveComponent("cooker")
        if not inst.components.container:IsEmpty() and harvester and harvester:IsValid() and harvester:HasTag("player") then
            inst.components.container:Open(harvester)
        end
    end
    -- 如果是烹饪时进行的检测,需要判断是否是全食材;如果不是主厨，则不支持主厨食谱
    local itemtestfn = containers.params.cookpot.itemtestfn
    local function resetdragonflyfurnacerecipes(inst) cooking.recipes.dragonflyfurnace = cooking.recipes.portablecookpot end
    local function startcookfntest(inst, doer)
        if inst.components.stewer.targettime ~= nil then return false end
        local foods = 0
        for k, v in pairs(inst.components.container.slots) do
            if k ~= 1 and itemtestfn(inst.components.container, v, k) then 
                foods = foods + 1
            end 
        end
        if foods < 4 then return false end
        -- if dragonflyfurnace == -1 and doer and doer:IsValid() then
        --     cooking.recipes.dragonflyfurnace = doer:HasTag("masterchef") and cooking.recipes.portablecookpot or cooking.recipes.cookpot
        --     inst:DoTaskInTime(0, resetdragonflyfurnacerecipes)
        -- end
        local redgem = inst.components.container:GetItemInSlot(1)
        cooking.recipes.dragonflyfurnace = ((doer and doer:IsValid() and doer:HasTag("masterchef")) or 
        (inst.redgem2hm ~= nil and inst.redgem2hm:value() > 0) or (redgem and redgem.prefab == "redgem")) and cooking.recipes.portablecookpot or cooking.recipes.cookpot
        return true
    end
    local function cancook(self)
        if self.inst.components.container == nil then return false end
        local foods = 0
        for k, v in pairs(self.inst.components.container.slots) do
            if k ~= 1 and itemtestfn(self.inst.components.container, v, k) then 
                foods = foods + 1
            end 
        end
        if foods < 4 then return false end
        return true
    end
    -- 红锅次数保存和加载
    local function saveandload(inst)
        local oldOnSave = inst.OnSave
        inst.OnSave = function(inst, data)
            if oldOnSave then oldOnSave(inst, data) end
            data.redgem2hm = inst.redgem2hm and inst.redgem2hm:value() or 0
        end
        local oldOnLoad = inst.OnLoad
        inst.OnLoad = function(inst, data)
            if oldOnLoad then oldOnLoad(inst, data) end
            if data ~= nil and data.redgem2hm ~= nil then
                inst.redgem2hm:set(data.redgem2hm)
            end
        end
    end
    -- 兼容智能锅
    COOKINGPOTS = COOKINGPOTS or {}
    COOKINGPOTS.dragonflyfurnace = COOKINGPOTS.dragonflyfurnace or {}
    local function perish_rate_multiplier(inst, item) return inst.components.stewer:IsCooking() and 0 or 1 end
    AddPrefabPostInit("dragonflyfurnace", function(inst)
        inst:AddTag("stewer")
        inst.redgem2hm = net_byte(inst.GUID, "dragonflyfurnace.redgem2hm", "masterchef2hm")
        if not TheWorld.ismastersim then return end
        if not (inst.components.container and inst.components.container.numslots == 5) or inst.components.stewer then return end
        -- 移除烧烤组件来避免做饭烹饪按钮复用问题
        inst:RemoveComponent("cooker")
        inst:AddComponent("stewer")
        local self = inst.components.stewer
        self.multi2hm = true
        -- self.autoharvest2hm = true
        self.startcookfntest2hm = startcookfntest
        self.onstartcooking = startcookfn
        self.oncontinuecooking = startcookfn
        self.ondonecooking = donecookfn
        self.onharvest = onharvest
        self.CanCook = cancook
        self.cooktimemult = 0.8
        if not inst.components.preserver then
            inst:AddComponent("preserver")
            inst.components.preserver:SetPerishRateMultiplier(perish_rate_multiplier)
        end
        inst.redgem2hm:set(0)
        saveandload(inst)
    end)
    -- 普通的烤熟按钮客户端响应
    local monstermeats = {cookedmonstermeat = "cookedmeat", cookedmonstersmallmeat = "cookedsmallmeat", um_monsteregg_cooked = "bird_egg_cooked"}
    local transformitems = {boards = "charcoal"}
    local function cookfn(doer, inst)
        local docook
        if inst.components.stewer and not inst.components.stewer:IsCooking() and inst.components.container and not inst.components.container:IsEmpty() then
            local replacelist = {}
            for i, v in pairs(inst.components.container.slots) do
                if i ~= 1 and v:IsValid() then
                    if transformitems[v.prefab] then
                        local size = v.components.stackable and v.components.stackable.stacksize or 1
                        local newitem = SpawnPrefab(transformitems[v.prefab])
                        v:Remove()
                        if newitem.components.stackable then newitem.components.stackable.stacksize = size end
                        inst.components.container:GiveItem(newitem, i)
                        if not docook then docook = true end
                    elseif v.components.cookable then
                        local size = v.components.stackable and v.components.stackable.stacksize or 1
                        local newitem = v.components.cookable:Cook(inst, doer)
                        v:Remove()
                        local replace = inst.updatecookitem2hm ~= nil and monstermeats[newitem.prefab]
                        local replacesize
                        if replace then
                            local replacesizechance = size * 0.15
                            replacesize = math.floor(replacesizechance)
                            local replacechance = replacesizechance - replacesize
                            if replacechance > 0 then replacesize = replacesize + (math.random() < replacechance and 1 or 0) end
                            if replacesize >= 1 then
                                size = size - replacesize
                            else
                                replace = nil
                            end
                        end
                        if size > 0 then
                            if newitem.components.stackable then newitem.components.stackable.stacksize = size end
                            inst.components.container:GiveItem(newitem, i)
                            if replace then
                                local item = SpawnPrefab(replace)
                                if item.components.stackable and replacesize then
                                    item.components.stackable.stacksize = replacesize
                                end
                                table.insert(replacelist, item)
                            end
                        else
                            newitem:Remove()
                            if replace then
                                local item = SpawnPrefab(replace)
                                if item.components.stackable and replacesize then
                                    item.components.stackable.stacksize = replacesize
                                end
                                inst.components.container:GiveItem(item, i)
                            end
                        end
                        if not docook then docook = true end
                    end
                end
            end
            for index, item in ipairs(replacelist) do inst.components.container:GiveItem(item) end
        end
        if docook then
            inst.AnimState:PlayAnimation("hi_hit")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/light")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/fire_LP", "loop")
        end
    end
    AddModRPCHandler("MOD_HARDMODE", "cookbtn2hm", cookfn)
    local function cookbtnfn(inst, doer)
        if inst.components.container and inst.components.stewer and TheWorld.ismastersim then
            cookfn(doer, inst)
        elseif inst.replica.container ~= nil and inst:HasTag("stewer") then
            SendModRPCToServer(GetModRPC("MOD_HARDMODE", "cookbtn2hm"), inst)
        end
    end
    -- 添加一个做饭按钮和一个烤熟按钮，且做饭按钮替代原来的摧毁按钮作为主要按钮
    local cookpotbtnfn = containers.params.cookpot.widget.buttoninfo.fn
    local olddestroyfn = containers.params.dragonflyfurnace.widget.buttoninfo.fn
    local oldslotpos = containers.params.dragonflyfurnace.widget.slotpos
    local oldslotbg = containers.params.dragonflyfurnace.widget.slotbg
    for i ,v in pairs(oldslotpos) do
        local oldpos = v
        v = Vector3(oldpos.x, oldpos.y - 34, oldpos.z)
    end
    table.insert(oldslotpos, 1, Vector3(0, 4+102,  0))
    table.insert(oldslotbg,{ image = "inv_slot_dragonflyfurnace.tex", atlas = "images/hud2.xml" })
    containers.params.dragonflyfurnace.widget.buttoninfo.fn = cookpotbtnfn
    local function destroyfn(doer, inst) if inst.components.container then olddestroyfn(inst, doer) end end
    AddModRPCHandler("MOD_HARDMODE", "destroybtn2hm", destroyfn)
    local function destroybtnfn(inst, doer)
        if inst.components.container then
            olddestroyfn(inst, doer)
        elseif inst.replica.container ~= nil and inst:HasTag("stewer") then
            SendModRPCToServer(GetModRPC("MOD_HARDMODE", "destroybtn2hm"), inst)
        end
    end
    AddClassPostConstruct("widgets/containerwidget", function(self)
        local Open = self.Open
        self.Open = function(self, container, doer, ...)
            if container and container.prefab == "dragonflyfurnace" and doer and doer:IsValid() then
                local redgem = container.replica.container:GetItemInSlot(1)
                container.masterchef2hm = doer:HasTag("masterchef") or (container.redgem2hm ~= nil and container.redgem2hm:value() > 0) or (redgem and redgem.prefab == "redgem")
            end
            Open(self, container, doer, ...)
            if container and container.prefab == "dragonflyfurnace" and self.button then
                local widget = container.replica.container and container.replica.container:GetWidget()
                if widget and widget.buttoninfo ~= nil and widget.slotpos ~= nil then
                    local finalslot = (widget.slotpos[3] + widget.slotpos[4]) / 2
                    local pos1 = Vector3(finalslot.x, finalslot.y - 91, finalslot.z)
                    local finalslot2 = widget.slotpos[1] --+ widget.slotpos[2]) / 2
                    local pos2 = Vector3(finalslot2.x, finalslot.y + 164, finalslot2.z)
                    local btnpos = widget.buttoninfo.position
                    local posmain = Vector3(btnpos.x, finalslot.y - 134, btnpos.z)
                    -- 原摧毁按钮挪位置
                    self.button:SetPosition(pos2)
                    self.button.image:SetScale(1.07, 0.95, 1.07)
                    -- self.button.image:SetScale(0.77, 1.07, 1.07)
                    -- 添加一个烤熟按钮
                    local btn = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex", nil, nil,
                                                        {1, 1}, {0, 0}))
                    btn:SetPosition(pos1)
                    btn.image:SetScale(1.07)
                    btn.text:SetPosition(2, -2)
                    btn:SetFont(BUTTONFONT)
                    btn:SetDisabledFont(BUTTONFONT)
                    btn:SetTextSize(33)
                    btn.text:SetVAlign(ANCHOR_MIDDLE)
                    btn.text:SetColour(0, 0, 0, 1)
                    btn:SetText(STRINGS.ACTIONS.STORE.COOK)
                    -- 添加一个做饭按钮
                    local btn2 = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex", nil, nil,
                                                        {1, 1}, {0, 0}))
                    btn2:SetPosition(posmain)
                    btn2.image:SetScale(1.07)
                    btn2.text:SetPosition(2, -2)
                    btn2:SetFont(BUTTONFONT)
                    btn2:SetDisabledFont(BUTTONFONT)
                    btn2:SetTextSize(33)
                    btn2.text:SetVAlign(ANCHOR_MIDDLE)
                    btn2.text:SetColour(0, 0, 0, 1)
                    btn2:SetText(STRINGS.NAMES.COOKPOT)
                    container.destroybtn2hm = self.button
                    container.cookbtn2hm = btn
                    self.destroybtn2hm = self.button
                    self.cookbtn2hm = btn
                    self.button = btn2
                    self.destroybtn2hm:SetOnClick(function() destroybtnfn(container, doer) end)
                    self.cookbtn2hm:SetOnClick(function() cookbtnfn(container, doer) end)
                    self.button:SetOnClick(function() cookpotbtnfn(container, doer) end)
                    if widget.buttoninfo.validfn(container) then
                        self.button:Enable()
                    else
                        self.button:Disable()
                    end
                end
            end
        end
        local Close = self.Close
        self.Close = function(self, ...)
            if self.container and self.container.destroybtn2hm then self.container.destroybtn2hm = nil end
            if self.container and self.container.cookbtn2hm then self.container.cookbtn2hm = nil end
            if self.isopen then
                if self.cookbtn2hm then
                    self.cookbtn2hm:Kill()
                    self.cookbtn2hm = nil
                end
                if self.destroybtn2hm then
                    self.destroybtn2hm:Kill()
                    self.destroybtn2hm = nil
                end
            end
            Close(self, ...)
        end
    end)
    -- 智能锅智能兼容火炉模式
    if isModuleAvailable("widgets/foodcrafting") then
        AddClassPostConstruct("widgets/foodcrafting", function(self, ...)
            local Open = self.Open
            self.Open = function(self, cooker_inst, ...)
                local container
                if cooker_inst.prefab then
                    container = cooker_inst
                elseif cooker_inst.inst.prefab then
                    container = cooker_inst.inst
                end
                if container.prefab == "dragonflyfurnace" then
                    container.prefab = container.masterchef2hm and "portablecookpot" or "cookpot"
                else
                    container = nil
                end
                Open(self, cooker_inst, ...)
                if container then container.prefab = "dragonflyfurnace" end
            end
            local _UpdateFoodStats = self._UpdateFoodStats
            self._UpdateFoodStats = function(self, ingdata, num_ing, inv_ings, ...)
                if self._cooker.prefab ~= "dragonflyfurnace"  then _UpdateFoodStats(self, ingdata, num_ing, inv_ings, ...) end
                if self._cooker.replica and self._cooker.replica.container then
                    local redgem = self._cooker.replica.container:GetItemInSlot(1)
                    if redgem and redgem.prefab == "redgem" then
                        num_ing = num_ing - 1
                    end
                elseif self._cooker.inst.replica and self._cooker.inst.replica.container then
                    local redgem = self._cooker.inst.replica.container:GetItemInSlot(1)
                    if redgem and redgem.prefab == "redgem" then
                        num_ing = num_ing - 1
                    end
                end
                _UpdateFoodStats(self, ingdata, num_ing, inv_ings, ...)
            end
        end)
    end
    -- 校验摧毁，烤熟和主要的做饭按钮
    local destroyvalidfn = containers.params.dragonflyfurnace.widget.buttoninfo.validfn
    local cookpotvalidfn = containers.params.cookpot.widget.buttoninfo.validfn
    containers.params.dragonflyfurnace.widget.buttoninfo.validfn = function(inst, ...)
        if inst.destroybtn2hm then
            if destroyvalidfn(inst, ...) then
                inst.destroybtn2hm:Enable()
            else
                inst.destroybtn2hm:Disable()
            end
        end
        if inst.cookbtn2hm then
            local result = false
            if inst.replica.container ~= nil and not inst.replica.container:IsEmpty() then
                for k, v in pairs(inst.replica.container:GetItems()) do
                    if k ~= 1 and v ~= nil and (v:HasTag("cookable") or transformitems[v.prefab]) then
                        result = true
                        break
                    end
                end
            end
            if result then
                inst.cookbtn2hm:Enable()
            else
                inst.cookbtn2hm:Disable()
            end
        end
        if inst.replica.container ~= nil then
            local foods = 0
            for k, v in pairs(inst.replica.container:GetItems()) do
                if k ~= 1 and itemtestfn(inst.replica.container, v, k) then
                    foods = foods + 1
                end
            end
            if foods == 4 then return true end
            return false
        end
    end

    local portablespicer = GetModConfigData("Portable Crock Pot Multi")
    if portablespicer then
        local containers = require("containers")
        containers.params.portablespicer.acceptsstacks = true
        AddPrefabPostInit("portablespicer", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.stewer then inst.components.stewer.multi2hm = true end
        end)
    end

    local portable_foods = require("preparedfoods_warly")
    if dragonflyfurnace or portablespicer then
        local cooking = require("cooking")
        local function givecontaineritem(container, item, src_pos)
            if item.components.stackable and not container.infinitestacksize then
                local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                if slotsize and item.components.stackable.stacksize > slotsize then
                    local size = item.components.stackable.stacksize
                    local totalsize = size + slotsize
                    for i = slotsize, totalsize, slotsize do
                        local giveitem = item.components.stackable:Get(slotsize)
                        container:GiveItem(giveitem, nil, i > size and src_pos or nil)
                        if giveitem and giveitem:IsValid() then giveitem.currplayer2hm = nil end
                    end
                    return
                end
            end
            container:GiveItem(item, nil, src_pos)
        end
        -- 红宝石一个充能三次
        local charge_number = hardmode and 5 or 10
        AddComponentPostInit("stewer", function(self)
            local StartCooking = self.StartCooking
            function self:StartCooking(doer)
                -- 防止右键火炉烹饪从而让火炉无视食材限制制作东西
                if self.startcookfntest2hm and not self.startcookfntest2hm(self.inst, doer) then return end
                -- 消耗食材时变为批量消耗食材
                local DestroyContents
                if self.multi2hm then
                    DestroyContents = self.inst.components.container.DestroyContents
                    self.inst.components.container.DestroyContents = function(container, ...)
                        local allredgem2hm
                        -- 检测是否是大厨料理
                        if self.product then
                            for i, v in pairs(portable_foods) do
                                if self.product == v.name then
                                    self.isportable_foods = true
                                end
                            end
                        end
                        if self.isportable_foods then
                            for k, v in pairs(container.slots) do
                                if k == 1 and v and v.prefab == "redgem" then 
                                    if v.components.stackable then
                                        allredgem2hm = (v.components.stackable:StackSize() or 0) * charge_number
                                    end
                                end
                            end
                            allredgem2hm = allredgem2hm or 0 + (self.inst.redgem2hm and self.inst.redgem2hm:value() or 0) -- 2025.10.22:or 0
                            if doer and doer:IsValid() and doer:HasTag("masterchef") then allredgem2hm = 99999 end
                            if allredgem2hm ~= nil then self.allredgem2hm = allredgem2hm end
                        end
                        local stacksize2hm = nil
                        for k, v in pairs(container.slots) do
                            -- 2025.7.30 melon:修批量调味不消耗料理bug
                            if v.components.stackable and (container.inst.prefab ~= "dragonflyfurnace" or k ~= 1) then
                                if container.inst.prefab == "dragonflyfurnace" then
                                    stacksize2hm = stacksize2hm and math.min(not self.isportable_foods and stacksize2hm or math.min(allredgem2hm, stacksize2hm), v.components.stackable.stacksize) or v.components.stackable.stacksize
                                else
                                    stacksize2hm = stacksize2hm and math.min(stacksize2hm, v.components.stackable.stacksize) or v.components.stackable.stacksize
                                end
                            elseif container.inst.prefab ~= "dragonflyfurnace" or k ~= 1 then -- 2025.7.30
                                stacksize2hm = 1
                                break
                            end
                        end
                        self.stacksize2hm = stacksize2hm
                        if not stacksize2hm then return DestroyContents(container, ...) end
                        for k, v in pairs(container.slots) do
                            if v.components.stackable and (container.inst.prefab ~= "dragonflyfurnace" or k ~= 1) then -- 2025.7.30
                                v.components.stackable:Get(stacksize2hm):Remove()
                            elseif container.inst.prefab ~= "dragonflyfurnace" or k ~= 1 then -- 2025.7.30
                                v:Remove()
                            end
                        end
                        -- 做饭时间翻倍
                        if not self.inst:HasTag("spicer") then
                            local cooktime = self.targettime - GetTime()
                            cooktime = cooktime * self.stacksize2hm
                            self.targettime = GetTime() + cooktime
                            if self.task ~= nil then
                                local fn = self.task.fn
                                self.task:Cancel()
                                self.task = self.inst:DoTaskInTime(cooktime, fn, self)
                            end
                        end
                    end
                end
                StartCooking(self, doer)
                -- 大厨料理结算次数
                if self.isportable_foods and doer and doer:IsValid() and not doer:HasTag("masterchef") then
                    local consume = math.min(self.allredgem2hm or 1, self.stacksize2hm or 1)
                    local redgem_needs = math.ceil(consume / charge_number)
                    local remaining = redgem_needs * charge_number - consume
                    if self.inst.redgem2hm ~= nil and self.inst.redgem2hm:value() <= 0 then
                        for k, v in ipairs(self.inst.components.container.slots) do
                            if k == 1 and v and v.prefab == "redgem" then 
                                if v.components.stackable then
                                    v.components.stackable:Get(redgem_needs):Remove()
                                else
                                    v:Remove()
                                end
                            end
                        end
                        self.inst.redgem2hm:set(remaining)
                    elseif self.inst.redgem2hm ~= nil and self.inst.redgem2hm:value() > 0 then
                        if self.inst.redgem2hm:value() < consume then
                            consume = consume - self.inst.redgem2hm:value()
                            redgem_needs = math.ceil(consume / charge_number)
                            remaining = redgem_needs * charge_number - consume
                            for k, v in ipairs(self.inst.components.container.slots) do
                                if k == 1 and v and v.prefab == "redgem" then 
                                    if v.components.stackable then
                                        v.components.stackable:Get(redgem_needs):Remove()
                                    else
                                        v:Remove()
                                    end
                                end
                            end
                            self.inst.redgem2hm:set(remaining)
                        else
                            self.inst.redgem2hm:set(self.inst.redgem2hm:value() - consume)
                        end
                    end
                end
                self.isportable_foods = nil
                self.allredgem2hm = nil
                if DestroyContents then self.inst.components.container.DestroyContents = DestroyContents end
            end
            local OnSave = self.OnSave
            function self:OnSave()
                local data = OnSave(self)
                data.stacksize2hm = self.stacksize2hm
                data.isportable_foods = self.isportable_foods
                data.allredgem2hm = self.allredgem2hm
                return data
            end
            local OnLoad = self.OnLoad
            function self:OnLoad(data)
                if data ~= nil then
                    if data.stacksize2hm then self.stacksize2hm = data.stacksize2hm end
                    if data.isportable_foods then self.isportable_foods = data.isportable_foods end
                    if data.allredgem2hm then self.allredgem2hm = data.isportable_foods end
                end
                OnLoad(self, data)
            end
            -- 收获时变为批量收获;自动采收则全部收完,非自动采收则只收取部分,再调用一次收取接口
            local Harvest = self.Harvest
            function self:Harvest(harvester)
                if self.done and self.product and ((self.stacksize2hm and self.stacksize2hm > 1) or self.autoharvest2hm) then
                    local loot = SpawnPrefab(self.product)
                    if loot ~= nil then
                        local recipe = cooking.GetRecipe(self.inst.prefab, self.product)
                        local stacksize = (recipe and recipe.stacksize or 1) * (self.autoharvest2hm and (self.stacksize2hm or 1) or (self.stacksize2hm - 1))
                        if stacksize > 1 and loot.components.stackable then loot.components.stackable:SetStackSize(stacksize) end
                        if self.spoiltime ~= nil and loot.components.perishable ~= nil then
                            local spoilpercent = self:GetTimeToSpoil() / self.spoiltime
                            loot.components.perishable:SetPercent(self.product_spoilage * spoilpercent)
                            loot.components.perishable:StartPerishing()
                        end
                        if self.autoharvest2hm and harvester ~= nil and harvester.components.container ~= nil then
                            givecontaineritem(harvester.components.container, loot)
                        elseif harvester ~= nil and harvester.components.inventory ~= nil then
                            givecontaineritem(harvester.components.inventory, loot, self.inst:GetPosition())
                        elseif self.inst.components.lootdropper then
                            self.inst.components.lootdropper:FlingItem(loot)
                        else
                            loot:Remove()
                        end
                    end
                    if self.autoharvest2hm then self.product = nil end
                end
                return Harvest(self, harvester)
            end
        end)
    end
elseif dragonflyfurnace then
    local cooking = require("cooking")
    local containers = require("containers")
    local ImageButton = require "widgets/imagebutton"
    cooking.recipes.dragonflyfurnace = cooking.recipes.portablecookpot
    -- 做饭期间可以加燃料缩短做饭时间
    local function clearfuel(inst) if inst.components.fueled then inst.components.fueled.currentfuel = 0 end end
    local function ontakefuel(inst, fuelvalue)
        inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
        local self = inst.components.stewer
        if self and self:IsCooking() and self.task and self.targettime and fuelvalue then
            local dostew = self.task.fn
            if self.task ~= nil then self.task:Cancel() end
            self.targettime = math.max(self.targettime - fuelvalue, GetTime())
            self.task = self.inst:DoTaskInTime(self.targettime - GetTime(), dostew, self)
        end
        inst:DoTaskInTime(0, clearfuel)
    end
    local function startcookfn(inst)
        if inst.stewercooktask2hm then
            inst.stewercooktask2hm:Cancel()
            inst.SoundEmitter:KillSound("snd")
            inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_rattle", "snd")
        else
            inst.SoundEmitter:KillSound("loop")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/place")
        end
        inst.AnimState:PlayAnimation("incinerate")
        inst.AnimState:PushAnimation("hi", true)
        local time = inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime() + FRAMES
        inst.stewercooktask2hm = inst:DoTaskInTime(time, startcookfn)
        -- 做饭期间可以把东西放火炉上烹饪
        if not inst:HasTag("burnt") then inst:AddTag("burnt") end
        if not inst.components.cooker then
            inst:AddComponent("cooker")
            if inst.updatecookitem2hm then inst.updatecookitem2hm(inst, 0.15) end
        end
        -- 做饭期间可以给燃料缩短做饭时间
        if not inst.components.fueled then
            inst:AddComponent("fueled")
            inst.components.fueled.maxfuel = TUNING.CAMPFIRE_FUEL_MAX
            inst.components.fueled.currentfuel = 0
            inst.components.fueled.accepting = true
            inst.components.fueled:SetTakeFuelFn(ontakefuel)
        end
    end
    -- local function autoHarvest(inst) inst.components.stewer:Harvest(inst) end
    local function donecookfn(inst)
        if inst.stewercooktask2hm then
            inst.stewercooktask2hm:Cancel()
            inst.stewercooktask2hm = nil
        end
        inst.SoundEmitter:KillSound("snd")
        inst.SoundEmitter:KillSound("loop")
        -- inst:DoTaskInTime(0, autoHarvest)
        inst:RemoveTag("burnt")
        if inst.components.fueled then inst:RemoveComponent("fueled") end
    end
    -- 收获后，去除厨师食谱
    local function onharvest(inst, harvester)
        inst:RemoveComponent("cooker")
        if not inst.components.container:IsEmpty() and harvester and harvester:IsValid() and harvester:HasTag("player") then
            inst.components.container:Open(harvester)
        end
    end
    -- 如果是烹饪时进行的检测,需要判断是否是全食材;如果不是主厨，则不支持主厨食谱
    local itemtestfn = containers.params.cookpot.itemtestfn
    local function resetdragonflyfurnacerecipes(inst) cooking.recipes.dragonflyfurnace = cooking.recipes.portablecookpot end
    local function startcookfntest(inst, doer)
        if inst.components.stewer.targettime ~= nil then return false end
        for k, v in pairs(inst.components.container.slots) do if not itemtestfn(inst.components.container, v, k) then return false end end
        if doer and doer:IsValid() and dragonflyfurnace == true and not ModManager:GetMod("workshop-3193922031") then
            cooking.recipes.dragonflyfurnace = doer:HasTag("masterchef") and cooking.recipes.portablecookpot or cooking.recipes.cookpot
            inst:DoTaskInTime(0, resetdragonflyfurnacerecipes)
        end
        return true
    end
    -- 兼容智能锅
    COOKINGPOTS = COOKINGPOTS or {}
    COOKINGPOTS.dragonflyfurnace = COOKINGPOTS.dragonflyfurnace or {}
    local function perish_rate_multiplier(inst, item) return inst.components.stewer:IsCooking() and 0 or 1 end
    AddPrefabPostInit("dragonflyfurnace", function(inst)
        inst:AddTag("stewer")
        if not TheWorld.ismastersim then return end
        if not (inst.components.container and inst.components.container.numslots == 4) or inst.components.stewer then return end
        -- 移除烧烤组件来避免做饭烹饪按钮复用问题
        inst:RemoveComponent("cooker")
        inst:AddComponent("stewer")
        local self = inst.components.stewer
        self.multi2hm = true
        -- self.autoharvest2hm = true
        self.startcookfntest2hm = startcookfntest
        self.onstartcooking = startcookfn
        self.oncontinuecooking = startcookfn
        self.ondonecooking = donecookfn
        self.onharvest = onharvest
        self.cooktimemult = 0.8
        if not inst.components.preserver then
            inst:AddComponent("preserver")
            inst.components.preserver:SetPerishRateMultiplier(perish_rate_multiplier)
        end
    end)
    -- 普通的烤熟按钮客户端响应
    local monstermeats = {cookedmonstermeat = "cookedmeat", cookedmonstersmallmeat = "cookedsmallmeat", um_monsteregg_cooked = "bird_egg_cooked"}
    local transformitems = {boards = "charcoal"}
    local function cookfn(doer, inst)
        local docook
        if inst.components.stewer and not inst.components.stewer:IsCooking() and inst.components.container and not inst.components.container:IsEmpty() then
            local replacelist = {}
            for i, v in pairs(inst.components.container.slots) do
                if v:IsValid() then
                    if transformitems[v.prefab] then
                        local size = v.components.stackable and v.components.stackable.stacksize or 1
                        local newitem = SpawnPrefab(transformitems[v.prefab])
                        v:Remove()
                        if newitem.components.stackable then newitem.components.stackable.stacksize = size end
                        inst.components.container:GiveItem(newitem, i)
                        if not docook then docook = true end
                    elseif v.components.cookable then
                        local size = v.components.stackable and v.components.stackable.stacksize or 1
                        local newitem = v.components.cookable:Cook(inst, doer)
                        v:Remove()
                        local replace = inst.updatecookitem2hm ~= nil and monstermeats[newitem.prefab]
                        local replacesize
                        if replace then
                            local replacesizechance = size * 0.15
                            replacesize = math.floor(replacesizechance)
                            local replacechance = replacesizechance - replacesize
                            if replacechance > 0 then replacesize = replacesize + (math.random() < replacechance and 1 or 0) end
                            if replacesize >= 1 then
                                size = size - replacesize
                            else
                                replace = nil
                            end
                        end
                        if size > 0 then
                            if newitem.components.stackable then newitem.components.stackable.stacksize = size end
                            inst.components.container:GiveItem(newitem, i)
                            if replace then
                                local item = SpawnPrefab(replace)
                                if item.components.stackable and replacesize then
                                    item.components.stackable.stacksize = replacesize
                                end
                                table.insert(replacelist, item)
                            end
                        else
                            newitem:Remove()
                            if replace then
                                local item = SpawnPrefab(replace)
                                if item.components.stackable and replacesize then
                                    item.components.stackable.stacksize = replacesize
                                end
                                inst.components.container:GiveItem(item, i)
                            end
                        end
                        if not docook then docook = true end
                    end
                end
            end
            for index, item in ipairs(replacelist) do inst.components.container:GiveItem(item) end
        end
        if docook then
            inst.AnimState:PlayAnimation("hi_hit")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/light")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/fire_LP", "loop")
        end
    end
    AddModRPCHandler("MOD_HARDMODE", "cookbtn2hm", cookfn)
    local function cookbtnfn(inst, doer)
        if inst.components.container and inst.components.stewer and TheWorld.ismastersim then
            cookfn(doer, inst)
        elseif inst.replica.container ~= nil and inst:HasTag("stewer") then
            SendModRPCToServer(GetModRPC("MOD_HARDMODE", "cookbtn2hm"), inst)
        end
    end
    -- 添加一个做饭按钮和一个烤熟按钮，且做饭按钮替代原来的摧毁按钮作为主要按钮
    local cookpotbtnfn = containers.params.cookpot.widget.buttoninfo.fn
    local olddestroyfn = containers.params.dragonflyfurnace.widget.buttoninfo.fn
    containers.params.dragonflyfurnace.widget.buttoninfo.fn = cookpotbtnfn
    local function destroyfn(doer, inst) if inst.components.container then olddestroyfn(inst, doer) end end
    AddModRPCHandler("MOD_HARDMODE", "destroybtn2hm", destroyfn)
    local function destroybtnfn(inst, doer)
        if inst.components.container then
            olddestroyfn(inst, doer)
        elseif inst.replica.container ~= nil and inst:HasTag("stewer") then
            SendModRPCToServer(GetModRPC("MOD_HARDMODE", "destroybtn2hm"), inst)
        end
    end
    AddClassPostConstruct("widgets/containerwidget", function(self)
        local Open = self.Open
        self.Open = function(self, container, doer, ...)
            if container and container.prefab == "dragonflyfurnace" and dragonflyfurnace == true and ModManager:GetMod("workshop-3193922031") and doer and doer:IsValid() then
                container.masterchef2hm = doer:HasTag("masterchef")
            end
            Open(self, container, doer, ...)
            if container and container.prefab == "dragonflyfurnace" and self.button then
                local widget = container.replica.container and container.replica.container:GetWidget()
                if widget and widget.buttoninfo ~= nil and widget.slotpos ~= nil then
                    local finalslot = (widget.slotpos[3] + widget.slotpos[4]) / 2
                    local pos1 = Vector3(finalslot.x, finalslot.y - 57, finalslot.z)
                    local finalslot2 = (widget.slotpos[1] + widget.slotpos[2]) / 2
                    local pos2 = Vector3(finalslot2.x, finalslot.y + 130, finalslot2.z)
                    local btnpos = widget.buttoninfo.position
                    local posmain = Vector3(btnpos.x, finalslot.y - 100, btnpos.z)
                    -- 原摧毁按钮挪位置
                    self.button:SetPosition(pos2)
                    self.button.image:SetScale(1.07, 0.95, 1.07)
                    -- self.button.image:SetScale(0.77, 1.07, 1.07)
                    -- 添加一个烤熟按钮
                    local btn = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex", nil, nil,
                                                        {1, 1}, {0, 0}))
                    btn:SetPosition(pos1)
                    btn.image:SetScale(1.07)
                    btn.text:SetPosition(2, -2)
                    btn:SetFont(BUTTONFONT)
                    btn:SetDisabledFont(BUTTONFONT)
                    btn:SetTextSize(33)
                    btn.text:SetVAlign(ANCHOR_MIDDLE)
                    btn.text:SetColour(0, 0, 0, 1)
                    btn:SetText(STRINGS.ACTIONS.STORE.COOK)
                    -- 添加一个做饭按钮
                    local btn2 = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex", nil, nil,
                                                        {1, 1}, {0, 0}))
                    btn2:SetPosition(posmain)
                    btn2.image:SetScale(1.07)
                    btn2.text:SetPosition(2, -2)
                    btn2:SetFont(BUTTONFONT)
                    btn2:SetDisabledFont(BUTTONFONT)
                    btn2:SetTextSize(33)
                    btn2.text:SetVAlign(ANCHOR_MIDDLE)
                    btn2.text:SetColour(0, 0, 0, 1)
                    btn2:SetText(STRINGS.NAMES.COOKPOT)
                    container.destroybtn2hm = self.button
                    container.cookbtn2hm = btn
                    self.destroybtn2hm = self.button
                    self.cookbtn2hm = btn
                    self.button = btn2
                    self.destroybtn2hm:SetOnClick(function() destroybtnfn(container, doer) end)
                    self.cookbtn2hm:SetOnClick(function() cookbtnfn(container, doer) end)
                    self.button:SetOnClick(function() cookpotbtnfn(container, doer) end)
                    if widget.buttoninfo.validfn(container) then
                        self.button:Enable()
                    else
                        self.button:Disable()
                    end
                end
            end
        end
        local Close = self.Close
        self.Close = function(self, ...)
            if self.container and self.container.destroybtn2hm then self.container.destroybtn2hm = nil end
            if self.container and self.container.cookbtn2hm then self.container.cookbtn2hm = nil end
            if self.isopen then
                if self.cookbtn2hm then
                    self.cookbtn2hm:Kill()
                    self.cookbtn2hm = nil
                end
                if self.destroybtn2hm then
                    self.destroybtn2hm:Kill()
                    self.destroybtn2hm = nil
                end
            end
            Close(self, ...)
        end
    end)
    -- 智能锅智能兼容火炉模式
    if dragonflyfurnace == -1 and isModuleAvailable("widgets/foodcrafting") then
        AddClassPostConstruct("widgets/foodcrafting", function(self, ...)
            local Open = self.Open
            self.Open = function(self, cooker_inst, ...)
                local container
                if cooker_inst.prefab then
                    container = cooker_inst
                elseif cooker_inst.inst.prefab then
                    container = cooker_inst.inst
                end
                if container.prefab == "dragonflyfurnace" then
                    container.prefab = container.masterchef2hm and "portablecookpot" or "cookpot"
                else
                    container = nil
                end
                Open(self, cooker_inst, ...)
                if container then container.prefab = "dragonflyfurnace" end
            end
        end)
    end
    -- 校验摧毁，烤熟和主要的做饭按钮
    local destroyvalidfn = containers.params.dragonflyfurnace.widget.buttoninfo.validfn
    local cookpotvalidfn = containers.params.cookpot.widget.buttoninfo.validfn
    containers.params.dragonflyfurnace.widget.buttoninfo.validfn = function(inst, ...)
        if inst.destroybtn2hm then
            if destroyvalidfn(inst, ...) then
                inst.destroybtn2hm:Enable()
            else
                inst.destroybtn2hm:Disable()
            end
        end
        if inst.cookbtn2hm then
            local result = false
            if inst.replica.container ~= nil and not inst.replica.container:IsEmpty() then
                for k, v in pairs(inst.replica.container:GetItems()) do
                    if v ~= nil and (v:HasTag("cookable") or transformitems[v.prefab]) then
                        result = true
                        break
                    end
                end
            end
            if result then
                inst.cookbtn2hm:Enable()
            else
                inst.cookbtn2hm:Disable()
            end
        end
        if cookpotvalidfn(inst, ...) then
            for k, v in pairs(inst.replica.container:GetItems()) do if not itemtestfn(inst.replica.container, v, k) then return false end end
            return true
        end
    end

    local portablespicer = GetModConfigData("Portable Crock Pot Multi")
    if portablespicer then
        local containers = require("containers")
        containers.params.portablespicer.acceptsstacks = true
        AddPrefabPostInit("portablespicer", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.stewer then inst.components.stewer.multi2hm = true end
        end)
    end

    if dragonflyfurnace or portablespicer then
        local cooking = require("cooking")
        local function givecontaineritem(container, item, src_pos)
            if item.components.stackable and not container.infinitestacksize then
                local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                if slotsize and item.components.stackable.stacksize > slotsize then
                    local size = item.components.stackable.stacksize
                    local totalsize = size + slotsize
                    for i = slotsize, totalsize, slotsize do
                        local giveitem = item.components.stackable:Get(slotsize)
                        container:GiveItem(giveitem, nil, i > size and src_pos or nil)
                        if giveitem and giveitem:IsValid() then giveitem.currplayer2hm = nil end
                    end
                    return
                end
            end
            container:GiveItem(item, nil, src_pos)
        end
        AddComponentPostInit("stewer", function(self)
            local StartCooking = self.StartCooking
            function self:StartCooking(doer)
                -- 防止右键火炉烹饪从而让火炉无视食材限制制作东西
                if self.startcookfntest2hm and not self.startcookfntest2hm(self.inst, doer) then return end
                -- 消耗食材时变为批量消耗食材
                local DestroyContents
                if self.multi2hm then
                    DestroyContents = self.inst.components.container.DestroyContents
                    self.inst.components.container.DestroyContents = function(container, ...)
                        local stacksize2hm = nil
                        for k, v in pairs(container.slots) do
                            if v.components.stackable then
                                stacksize2hm = stacksize2hm and math.min(stacksize2hm, v.components.stackable.stacksize) or v.components.stackable.stacksize
                            else
                                stacksize2hm = 1
                                break
                            end
                        end
                        self.stacksize2hm = stacksize2hm
                        if not stacksize2hm then return DestroyContents(container, ...) end
                        for k, v in pairs(container.slots) do
                            if v.components.stackable then
                                v.components.stackable:Get(stacksize2hm):Remove()
                            else
                                v:Remove()
                            end
                        end
                        -- 做饭时间翻倍
                        if not self.inst:HasTag("spicer") then
                            local cooktime = self.targettime - GetTime()
                            cooktime = cooktime * self.stacksize2hm
                            self.targettime = GetTime() + cooktime
                            if self.task ~= nil then
                                local fn = self.task.fn
                                self.task:Cancel()
                                self.task = self.inst:DoTaskInTime(cooktime, fn, self)
                            end
                        end
                    end
                end
                StartCooking(self, doer)
                if DestroyContents then self.inst.components.container.DestroyContents = DestroyContents end
            end
            local OnSave = self.OnSave
            function self:OnSave()
                local data = OnSave(self)
                data.stacksize2hm = self.stacksize2hm
                return data
            end
            local OnLoad = self.OnLoad
            function self:OnLoad(data)
                if data and data.stacksize2hm then self.stacksize2hm = data.stacksize2hm end
                OnLoad(self, data)
            end
            -- 收获时变为批量收获;自动采收则全部收完,非自动采收则只收取部分,再调用一次收取接口
            local Harvest = self.Harvest
            function self:Harvest(harvester)
                if self.done and self.product and ((self.stacksize2hm and self.stacksize2hm > 1) or self.autoharvest2hm) then
                    local loot = SpawnPrefab(self.product)
                    if loot ~= nil then
                        local recipe = cooking.GetRecipe(self.inst.prefab, self.product)
                        local stacksize = (recipe and recipe.stacksize or 1) * (self.autoharvest2hm and (self.stacksize2hm or 1) or (self.stacksize2hm - 1))
                        if stacksize > 1 and loot.components.stackable then loot.components.stackable:SetStackSize(stacksize) end
                        if self.spoiltime ~= nil and loot.components.perishable ~= nil then
                            local spoilpercent = self:GetTimeToSpoil() / self.spoiltime
                            loot.components.perishable:SetPercent(self.product_spoilage * spoilpercent)
                            loot.components.perishable:StartPerishing()
                        end
                        if self.autoharvest2hm and harvester ~= nil and harvester.components.container ~= nil then
                            givecontaineritem(harvester.components.container, loot)
                        elseif harvester ~= nil and harvester.components.inventory ~= nil then
                            givecontaineritem(harvester.components.inventory, loot, self.inst:GetPosition())
                        elseif self.inst.components.lootdropper then
                            self.inst.components.lootdropper:FlingItem(loot)
                        else
                            loot:Remove()
                        end
                    end
                    if self.autoharvest2hm then self.product = nil end
                end
                return Harvest(self, harvester)
            end
        end)
    end
end

-- 2025.8.8 melon:晾肉架改动:可晾晒蔬菜变蔬菜干、不可燃。----------
if GetModConfigData("meatrack_dry") then
    local PLANTS = {
        "carrot", "corn", "pumpkin", "eggplant", "durian", "pomegranate", 
        "dragonfruit", "watermelon", "tomato", "potato", "asparagus", 
        "onion", "garlic", "pepper",
        "fig", "cave_banana", "cactus_meat", -- 无花果/香蕉/仙人掌
        "red_cap", "blue_cap", "green_cap", "rock_avocado_fruit_ripe", -- 三色蘑菇/石果
    }
    AddPrefabPostInit("meatrack", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.burnable then -- 不可点燃 10.7 兼容写法
            inst.components.burnable.Ignite = function(...)
                inst.components.burnable:Extinguish(true)
            end
        end
        -- 2025.8.12 melon:修改图像,暂时用smallmeat代替
        if inst.components.dryingrack then
            local _showitemfn = inst.components.dryingrack.showitemfn
            inst.components.dryingrack.showitemfn = function(inst, slot, name, build)
                if table.contains(PLANTS, name) then -- 未晾干
                    name = "smallmeat"
                elseif string.find(name, "_dryplants2hm", 1, true) ~= nil then -- 晾干
                    name = "smallmeat_dried"
                end
                _showitemfn(inst, slot, name, build)
            end
        end
    end)
    -- 为作物添加晾干组件、晾干产物---------------------------------------
    local to_carrot = {"red_cap", "blue_cap", "green_cap", "rock_avocado_fruit_ripe"}
    for _, plantname in ipairs(PLANTS) do
        AddPrefabPostInit(plantname, function(inst)
            inst:AddTag("dryable")
            if not TheWorld.ismastersim then return end
            if not inst.components.dryable then inst:AddComponent("dryable") end
            if table.contains(to_carrot, plantname) then -- 蘑菇/石果晾好直接用胡萝卜的
                inst.components.dryable:SetProduct("carrot_dryplants2hm")
            else
                inst.components.dryable:SetProduct(plantname .. "_dryplants2hm")
            end
            inst.components.dryable:SetDryTime(TUNING.DRY_SUPERFAST) -- 2分钟晾好
        end)
    end
    -- 2025.8.8 melon:作物晾干可回3%血上限---------------------------------------
    local function OnEat2hm(inst, data)
        if inst.components.health and inst.components.health.penalty and inst.components.health.penalty > 0 and 
        inst.components.health.maxhealth and inst.components.eater and data and data.food and data.food.dryplants2hm and data.food.components.edible then
            inst.components.health:DeltaPenalty(-0.03) -- 200*0.03=6 150*0.03=4.5
        end
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat2hm)
        inst.OnEat_dryplants2hm = OnEat2hm
    end)
    -- 2025.8.17 melon:可放入冰箱或钓具容器---------------------------------------
    local containers = require("containers")
    if containers and containers.params and containers.params.icebox then
        local olditemtestfn = containers.params.icebox.itemtestfn
        containers.params.icebox.itemtestfn = function(container, item, slot)
            return olditemtestfn == nil or olditemtestfn(container, item, slot) or item and item.dryplants2hm
        end
    end
    if containers and containers.params and containers.params.tacklestation2hm then
        local olditemtestfn = containers.params.tacklestation2hm.itemtestfn
        containers.params.tacklestation2hm.itemtestfn = function(container, item, slot)
            return olditemtestfn == nil or olditemtestfn(container, item, slot) or item and item.dryplants2hm
        end
    end
end

-- 2025.5.17 melon:蘑菇灯菌伞灯 反鲜、范围更大--------------------------------------------
if GetModConfigData("mushroom_light") then
    local light_str =
    {
        {radius = 3.7, falloff = .85, intensity = 0.75}, -- 2.5
        {radius = 4.8, falloff = .85, intensity = 0.75}, -- 3.25
        {radius = 6.3, falloff = .85, intensity = 0.75}, -- 4.25
        {radius = 8.3, falloff = .85, intensity = 0.75}, -- 5.5
    }
    local fulllight_light_str =
    {
        radius = 8.3, falloff = 0.85, intensity = 0.75 -- 5.5
    }
    -- 腐烂速度
    TUNING.PERISH_MUSHROOM_LIGHT_MULT = -0.1
    AddPrefabPostInit("mushroom_light", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.burnable then -- 不可点燃 10.7 兼容写法
            inst.components.burnable.Ignite = function(...)
                inst.components.burnable:Extinguish(true)
            end
        end
        if inst.Physics then inst.Physics:SetCollides(false) end -- 碰撞?
        -- 修改含范围的参数
        for i, func in ipairs(inst.event_listeners["itemget"][inst]) do -- 找light的函数
            if UpvalueHacker.GetUpvalue(func, "fulllight_light_str") then
                -- local fn, i, prv = UpvalueHacker.GetUpvalue(func, "fulllight_light_str")
                UpvalueHacker.SetUpvalue(func, fulllight_light_str, "fulllight_light_str")
            end
            if UpvalueHacker.GetUpvalue(func, "light_str") then
                -- local fn, i, prv = UpvalueHacker.GetUpvalue(func, "light_str")
                UpvalueHacker.SetUpvalue(func, light_str, "light_str")
                break -- 改一次就行了
            end
            --[[ 示例:查看所有func用到的变量、函数
            local k = 1
            while true do
                local name, value = debug.getupvalue(func, k)
                if not name then break end
                print("#####", k, name, value)
                k = k + 1
            end
            --]]
        end
    end)
    AddPrefabPostInit("mushroom_light2", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.burnable then -- 不可点燃 10.7 兼容写法
            inst.components.burnable.Ignite = function(...)
                inst.components.burnable:Extinguish(true)
            end
        end
        if inst.Physics then inst.Physics:SetCollides(false) end -- 碰撞?
        -- 范围上面改了这里就不用改了
    end)
end

-- 眼球炮塔加强:统一配方、恢复、电击连锁及材料升级
if GetModConfigData("eyeturret") then modimport("easy_other/eyeturret2hm.lua") end

-- 新-----------------------------------------------------------------------------------
-- 哀悼之穴
if GetModConfigData("player_tomb") then
    local function SpawnGhost(x, y, z, data)
        if data then
            local ghost = SpawnPrefab("player_soul2hm")
            ghost.Transform:SetPosition(x, y, z)
            ghost.components.named:SetName(data.username)
            ghost.username = data.username
            ghost.cause = data.cause
            ghost.userid = data.userid
            ghost.afflicter = data.afflicter
            ghost.prefabName = data.prefabName
        end
    end

    local function AfterDeath(x, y, z, data)
        local ents = TheSim:FindEntities(x, y, z, 2, {"skeleton_player"}, {"skeleton_player_ghost"})
        local target, dis
        if ents then
            for _, ent in pairs(ents) do
                if ent.userid == data.userid then
                    local len = ent:GetDistanceSqToPoint(x, y, z)
                    if not target or len < dis then
                        target = ent
                        dis = len
                    end
                end
            end
        end
        if target then
            target:AddTag("skeleton_player_ghost")
            target:ListenForEvent("onremove", function()
                local x, y, z = target.Transform:GetWorldPosition()
                SpawnGhost(x, y, z, data)
            end)
            target.deadMsg = data
        else
            SpawnGhost(x, y, z, data)
        end
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("death", function(inst, data)
            data = data or {}
            local deadMsg = {
                userid = inst.userid,
                username = inst:GetDisplayName(),
                prefabName = inst.prefab,
            }
            local function SafeDeathName2hm(ent)
                if type(ent) ~= "table" or not ent.GetDisplayName then return "unknown" end
                local ok, r = pcall(ent.GetDisplayName, ent)
                if ok and type(r) == "string" and r ~= "" then return r end
                return "unknown"
            end
            if type(data.cause) == "table" then
                deadMsg.cause = SafeDeathName2hm(data.cause)
            elseif type(data.cause) == "string" then
                deadMsg.cause = data.cause
            else
                deadMsg.cause = "unknown"
            end
            if type(data.afflicter) == "table" then
                deadMsg.afflicter = SafeDeathName2hm(data.afflicter)
            elseif type(data.afflicter) == "string" then
                deadMsg.afflicter = data.afflicter
            end
            if deadMsg.userid and deadMsg.username then
                local x, y, z = inst.Transform:GetWorldPosition()
                TheWorld:DoTaskInTime(2, function()
                    AfterDeath(x, y, z, deadMsg)
                end)
            end
        end)
    end)
    local OnSave = function(inst, data)
        data.deadMsg = inst.deadMsg
    end
    local OnLoad = function(inst, data)
		if data == nil then return end
        inst.deadMsg = data.deadMsg
        if inst.deadMsg then
            inst:AddTag("skeleton_player_ghost")
            inst:ListenForEvent("onremove", function()
                local x, y, z = inst.Transform:GetWorldPosition()
                SpawnGhost(x, y, z, inst.deadMsg)
            end)
        end
    end
    AddPrefabPostInit("skeleton_player", function(inst)
        if not TheWorld.ismastersim then return end
        inst:AddTag("skeleton_player")
        SetOnSave(inst, OnSave)
        SetOnLoad(inst, OnLoad)
    end)

    -- 2025.5.31 melon:种植杂草多产一格(犁地草膏回上限用)------
    local weed_prefabs = {
        ["weed_forgetmelots"]=true, ["weed_tillweed"]=true, ["weed_firenettle"]=true,
    }
    local function SetupLoot_weed(lootdropper)
        local inst = lootdropper.inst
        local plant = inst.plant
        if plant then
            if inst.components.pickable ~= nil then
                if plant.weed_def.prefab and weed_prefabs[plant.weed_def.prefab] then -- 若为杂草
                    lootdropper:SetLoot({plant.weed_def.product, plant.weed_def.product})
                else
                    lootdropper:SetLoot({plant.weed_def.product})
                end
            end
        end
    end
    AddPrefabPostInit("player_tomb2hm", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.MakePickable_weed then
            local _MakePickable_weed = inst.MakePickable_weed
            inst.MakePickable_weed = function(inst, ...)
                _MakePickable_weed(inst, ...)
                if inst.components.lootdropper then
                    inst.components.lootdropper.lootsetupfn = SetupLoot_weed
                end
            end
        end
    end)
    -- 2025.5.31 end
end

