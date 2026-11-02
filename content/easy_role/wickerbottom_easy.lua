local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wickerbottom")

-- 薇克巴顿不失眠
if GetModConfigData("Wickerbottom Is Not Insomniac") then AddPrefabPostInit("wickerbottom", function(inst) inst:RemoveTag("insomniac") end) end

-- 薇克巴顿免疫装备/怪物/黑夜三种掉理智
if GetModConfigData("Wickerbottom No Sanity Dapperness") then
    local function GetEquippableDapperness(owner, equippable)
        local dapperness = equippable:GetDapperness(owner, owner.components.sanity.no_moisture_penalty)
        return dapperness < 0 and 0 or dapperness
    end
    AddPrefabPostInit("wickerbottom", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.sanity:SetNegativeAuraImmunity(true)
        inst.components.sanity:SetPlayerGhostImmunity(true)
        inst.components.sanity:SetLightDrainImmune(true)
        inst.components.sanity.get_equippable_dappernessfn = GetEquippableDapperness
    end)
end

-- 薇克巴顿读书消耗更少耐久
if GetModConfigData("Wickerbottom Read Book Less Use") then
    AddComponentPostInit("book", function(self)
        local oldInteract = self.Interact
        self.Interact = function(self, fn, reader, ...)
            if reader.prefab == "wickerbottom" and reader.components.sanity and not self.inst:HasTag("shadowmagic") and self.inst.components.finiteuses and
            not self.inst:HasTag("cant_less_use2hm") then -- 2025.9.25 melon:勋章的植物图鉴不能读多次
                local success = true
                local reason
                if fn then
                    success, reason = fn(self.inst, reader)
                    if success then self.inst.components.finiteuses:Use(math.max(0.35, 1 - reader.components.sanity:GetPercent())) end
                end
                return success, reason
            else
                return oldInteract(self, fn, reader, ...)
            end
        end
    end)
    -- 2025.9.25 melon:给勋章的植物图鉴增加不可多次读标签
    if hardmode and TUNING.FUNCTIONAL_MEDAL_IS_OPEN then
        AddPrefabPostInit("medal_plant_book", function(inst) inst:AddTag("cant_less_use2hm") end)
    end
end

-- 薇克巴顿冰火魔杖
if GetModConfigData("Wickerbottom Use Staff") then
    local function createlight(staff, target, pos)
        local spike = SpawnPrefab(staff.prefab == "icestaff" and "staffcoldlight" or "emberlight")
        spike.Transform:SetPosition(pos:Get())
        staff.components.finiteuses:Use(4)
        local caster = staff.components.inventoryitem.owner
        if staff.prefab == "icestaff" then
            if caster ~= nil then spike.Transform:SetRotation(caster.Transform:GetRotation()) end
            --if spike.SetVariation then spike:SetVariation(math.random(4)) end
			if spike.components.timer then spike:DoTaskInTime(0, function()
				spike.components.timer:SetTimeLeft("extinguish", TUNING.EMBER_STAR_DURATION)
				end)
			end
        end
        if caster ~= nil then
            if caster.components.staffsanity then
                caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_MEDLARGE)
            elseif caster.components.sanity ~= nil then
                caster.components.sanity:DoDelta(-TUNING.SANITY_MEDLARGE)
            end
        end
    end
    local specialitems = {icestaff = true, firestaff = true, firepen = true}
    local function onunequip(inst, data)
        if data and data.item and data.item:IsValid() and specialitems[data.item.prefab] and data.item.wickerbottom2hm and data.item.components.spellcaster then
            data.item.wickerbottom2hm = nil
            data.item:RemoveComponent("spellcaster")
        end
    end
    local function onequip(inst, data)
        if not inst.wickerbottomrefresh2hm and data and data.item and data.item:IsValid() and specialitems[data.item.prefab] and
            not data.item.components.spellcaster then
			if data.item.prefab == "icestaff" and inst.components.builder and inst.components.builder.recipes then
				local recipes = inst.components.builder.recipes
				if table.contains(recipes, "researchlab3") then
					data.item.wickerbottom2hm = true
					data.item:AddComponent("spellcaster")
					data.item.components.spellcaster:SetSpellFn(createlight)
					data.item.components.spellcaster.canuseonpoint = true
				end
			elseif data.item.prefab == "firestaff" or data.item.prefab == "firepen" then
				data.item.wickerbottom2hm = true
				data.item:AddComponent("spellcaster")
				data.item.components.spellcaster:SetSpellFn(createlight)
				data.item.components.spellcaster.canuseonpoint = true
				--if data.item.prefab == "icestaff" then data.item.components.spellcaster.quickcast = true end
			end
        end
    end
    AddPrefabPostInit("wickerbottom", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("equip", onequip)
        inst:ListenForEvent("unequip", onunequip)
    end)
end

-- 薇克巴顿控温书增强
if GetModConfigData("Wickerbottom Temperature Book") then
    AddPrefabPostInit("book_temperature", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.book and inst.components.book.onread then
            local old_onread = inst.components.book.onread
            inst.components.book.onread = function(inst, reader)
                local success, reason = old_onread(inst, reader)
                if success then
                    local x, y, z = reader.Transform:GetWorldPosition()
                    local players = FindPlayersInRange(x, y, z, TUNING.BOOK_TEMPERATURE_RADIUS, true)
                    for _, player in pairs(players) do
                        if player.components.temperature and player.components.moisture then
                            player:AddDebuff("book_temperature_buff2hm", "book_temperature_buff2hm")
                        end
                    end
                end
                return success, reason
            end
        end
    end)
end

-- 薇克巴顿每日一书,且可以作为免费的制作材料
if GetModConfigData("Wickerbottom Daily Book") then
    local TechTree = require("techtree")
    -- 书柜存放更多道具
    if not TUNING.erasablepapertag2hm then
        TUNING.erasablepapertag2hm = true
        AddComponentPostInit("erasablepaper", function(self) self.inst:AddTag("erasablepaper") end)
    end
    local containers = require("containers")
    local olditemtestfn = containers.params.bookstation.itemtestfn
    containers.params.bookstation.itemtestfn = function(container, item, slot, ...)
        return (olditemtestfn and olditemtestfn(container, item, slot, ...)) or item:HasTag("erasablepaper") or item:HasTag("scrapbook_page") or item.prefab ==
                   "stash_map" or item.prefab == "mapscroll"
    end
    -- 专属书柜存放有限制
    local books = {
        "book_birds",
        "book_gardening",
        "book_horticulture",
        "book_horticulture_upgraded",
        "book_silviculture",
        "book_sleep",
        "book_brimstone",
        "book_tentacles",
        "book_fish",
        "book_web",
        "book_temperature",
        "book_light",
        "book_light_upgraded",
        "book_fire",
        "book_moon",
        "book_rain",
        "book_bees",
        "book_research_station"
    }
    -- bookstation2hm兼容
    containers.params.bookstation2hm = {}
    containers.params.bookstation2hm.widget = containers.params.bookstation.widget
    containers.params.bookstation2hm.type = containers.params.bookstation.type
    containers.params.bookstation2hm.itemtestfn = function(container, item, slot)
        return container.init2hm or (slot and slot <= 16 and item:HasTag("dailybook2hm")) or ((slot == nil or slot > 16) and table.contains(books, item.prefab))
    end
    containers.params.bookstation2hm.usespecificslotsforitems = true
    containers.params.bookstation2hm.acceptsstacks = false
    AddClassPostConstruct("widgets/containerwidget", function(self)
        local oldOpen = self.Open
        self.Open = function(self, container, doer, ...)
            local result = oldOpen(self, container, doer, ...)
            if container and container.prefab == "bookstation2hm" then
                local atlas = resolvefilepath(CRAFTING_ATLAS)
                for k, v in pairs(self.inv) do
                    if k <= 16 then
                        v:SetBGImage2(atlas, "favorite_checked.tex", {1, 1, 1, 0.1})
                        local w, h = v.bgimage:GetSize()
                        v.bgimage2:SetSize(w, h)
                    end
                end
                if self.bgimage.SetTint then self.bgimage:SetTint(1, 1, 1, 0.25) end
                if self.bganim.inst and self.bganim.inst.AnimState then self.bganim.inst.AnimState:SetMultColour(1, 1, 1, 0.25) end
            end
            return result
        end
    end)
    local lockbooks = {"book_birds", "book_horticulture", "book_research_station", "book_light", "book_rain", "book_fish"}
    local function delayremove(inst) inst:DoTaskInTime(0, inst.Remove) end
    local function processbook(inst, book)
        book.master2hm = inst
        book:AddTag("dailybook2hm")
        book:AddTag("hide_percentage")
        if book.components.inventoryitem then
            book.components.inventoryitem:SetOnDroppedFn(delayremove)
            book:ListenForEvent("onputininventory", delayremove)
            book:ListenForEvent("ondropped", delayremove)
            book.components.inventoryitem.onactiveitemfn = delayremove
        end
        if book.components.finiteuses then
            book.components.finiteuses:SetMaxUses(1)
            book.components.finiteuses:SetUses(1)
            book:ListenForEvent("percentusedchange", delayremove)
        end
    end
    local function dailybook(inst)
        if not inst:HasTag("playerghost") and inst.components.persistent2hm and (inst.components.persistent2hm.data.dailybook or -1) < TheWorld.state.cycles and
            inst.bookstation2hm and inst.bookstation2hm:IsValid() and inst.bookstation2hm.components.container and
            #(inst.bookstation2hm.components.container:FindItems(function(item) return item and item:HasTag("dailybook2hm") end)) < 16 then
            inst.components.persistent2hm.data.dailybook = TheWorld.state.cycles
            local self = inst.bookstation2hm.components.container
            local slot
            for i = 1, math.min(self.numslots, 16) do
                if not self.slots[i] then
                    slot = i
                    break
                end
            end
            if not slot then return end
            local bookname = "book_research_station"
            if TheWorld.state.cycles > 0 then
                if inst.components.builder and inst.components.builder.recipes then
                    local recipes = inst.components.builder.recipes
                    local books2 = deepcopy(books)
                    for index, name in ipairs(books) do
                        if table.contains(recipes, name) or table.contains(lockbooks, name) then
                            table.insert(books2, name)
                            table.insert(books2, name)
                        end
                    end
                    bookname = books2[math.random(#books2)]
                else
                    bookname = books[math.random(#books)]
                end
            end
            local book = SpawnPrefab(bookname)
            if book and book:IsValid() then
                if book.components.inventoryitem then
                    book:AddTag("dailybook2hm")
                    self:GiveItem(book, slot)
                    processbook(inst, book)
                else
                    book:Remove()
                end
            end
        end
    end
    local function initbookstation(inst)
        if not (inst.bookstation2hm and inst.bookstation2hm:IsValid()) then
            local bookstation = SpawnPrefab("bookstation2hm")
            if bookstation and bookstation:IsValid() and bookstation.components.container then
                if inst.components.persistent2hm.data.bookstation then
                    bookstation.components.container.init2hm = true
                    bookstation:SetPersistData(inst.components.persistent2hm.data.bookstation)
                    bookstation.components.container.init2hm = nil
                    inst.components.persistent2hm.data.bookstation = nil
                end
                for i = 1, 16 do
                    local item = bookstation.components.container.slots[i]
                    if item and item:IsValid() then processbook(inst, item) end
                end
                bookstation:AddTag("dcs2hm")
                inst.bookstation2hm = bookstation
                bookstation.master2hm = inst
                bookstation.components.container.skipautoclose = true
                bookstation:Hide()
                inst:AddChild(bookstation)
                -- bookstation:RemoveFromScene()
                bookstation:AddTag("NOBLOCK")
                bookstation:RemoveTag("chest")
                if inst.components.builder and not inst.components.builder.DoBuild2hm then
                    inst.components.builder.DoBuild2hm = true
                    local DoBuild = inst.components.builder.DoBuild
                    inst.components.builder.DoBuild = function(self, ...)
                        local inst = self.inst
                        if inst.bookstation2hm and inst.bookstation2hm:IsValid() and inst.bookstation2hm.components.container and
                            inst.bookstation2hm.components.container.openlist and inst.bookstation2hm.components.container.openlist[inst] ~= nil then
                            inst.bookstation2hm.components.container:Close(inst)
                        end
                        return DoBuild(self, ...)
                    end
                end
                bookstation.persists = false
                dailybook(inst)
            end
        end
    end
    local function OnSave(inst, data)
        data.bookstation = InGamePlay() and (inst.bookstation2hm and inst.bookstation2hm:IsValid() and inst.bookstation2hm:GetPersistData() or nil) or
                               data.bookstation
    end
    local function rightselfstrfn2hm(act)
        if act.doer and act.doer.bookstationlevel2hm then return "BOOKSTATION" .. tostring(act.doer.bookstationlevel2hm:value()) end
    end
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION = STRINGS.NAMES.BOOKSTATION
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION0 = STRINGS.NAMES.BOOKSTATION .. " Lv0"
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION1 = STRINGS.NAMES.BOOKSTATION .. " Lv1"
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION2 = STRINGS.NAMES.BOOKSTATION .. " Lv2"
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION3 = STRINGS.NAMES.BOOKSTATION .. " Lv3"
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.BOOKSTATION4 = STRINGS.NAMES.BOOKSTATION .. " Lv4 Max"
    -- 奶奶自带科技
    if not PROTOTYPER_DEFS.wickerbottom then
        PROTOTYPER_DEFS.wickerbottom = {
            icon_atlas = "images/crafting_menu_avatars.xml",
            icon_image = "avatar_wickerbottom.tex",
            action_str = "WICKERBOTTOM",
            is_crafting_station = false
        }
    end
    if not STRINGS.ACTIONS.OPEN_CRAFTING.WICKERBOTTOM then STRINGS.ACTIONS.OPEN_CRAFTING.WICKERBOTTOM = TUNING.isCh2hm and "Learn with" or "请教" end
    AddPrefabPostInit("wickerbottom", function(inst)
        inst:AddTag("prototyper")
        inst.rightselfstrfn2hm = rightselfstrfn2hm
        inst.bookstationlevel2hm = net_byte(inst.GUID, "wickerbottomstation.level2hm")
        if not TheWorld.ismastersim then return end
        inst.bookstationlevel2hm:set(0)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        if not inst.components.prototyper then
            inst:AddComponent("prototyper")
            inst.components.prototyper.trees = {BOOKCRAFT = 0, SCIENCE = 1, MAGIC = 0}
        end
        inst:WatchWorldState("cycles", dailybook)
        SetOnSave2hm(inst, OnSave)
        inst:DoTaskInTime(0, initbookstation)
    end)
    AddRightSelfAction("wickerbottom", 1, "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "wickerbottom" and act.doer.bookstation2hm then
            local bookstation = act.doer.bookstation2hm
            if bookstation and bookstation:IsValid() and bookstation.components.container and act.doer == bookstation.master2hm then
                if bookstation.components.container.openlist[act.doer] then
                    bookstation.components.container:Close(act.doer)
                    -- if act.doer.components.builder ~= nil and act.doer.components.prototyper ~= nil then
                    --     return act.doer.components.builder:UsePrototyper(act.doer)
                    -- end
                else
                    bookstation.components.container:Open(act.doer)
                end
                return true
            else
                act.doer:DoTaskInTime(0, initbookstation)
            end
        end
    end, STRINGS.NAMES.BOOKSTATION)
    AddPrefabPostInit("bookstation2hm", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.container ~= nil then
            local GetSpecificSlotForItem = inst.components.container.GetSpecificSlotForItem
            inst.components.container.GetSpecificSlotForItem = function(self, item, ...)
                local result = GetSpecificSlotForItem(self, item, ...)
                if result >= 17 then
                    for i = self.numslots, 17, -1 do
                        local item = self.slots[i]
                        if not item then return i end
                    end
                elseif result == 1 then
                    for i = 1, math.min(self.numslots, 16) do
                        local item = self.slots[i]
                        if not item then return i end
                    end
                end
                return result
            end
        end
    end)
	-- 薇克巴顿根据书籍解锁进度动态增加攻击倍率
	if GetModConfigData("Knowledge is power") then
		local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
			if mount or not target:IsValid() then return 1 end
			local allbooks = {
				"book_birds",
				"book_gardening",
				"book_horticulture",
				"book_horticulture_upgraded",
				"book_silviculture",
				"book_sleep",
				"book_brimstone",
				"book_tentacles",
				"book_fish",
				"book_web",
				"book_temperature",
				"book_light",
				"book_light_upgraded",
				"book_fire",
				"book_moon",
				"book_rain",
				"book_bees",
				"book_research_station",
				"waxwelljournal"
			}
			local unlockbooks = {"book_birds", "book_horticulture", "book_research_station", "book_light", "book_rain", "book_fish"} -- 开局解锁的6本书
			local count = 0
			if inst.components.builder and inst.components.builder.recipes then
				local recipes = inst.components.builder.recipes
				for index, name in pairs(allbooks) do
					if table.contains(recipes, name) and not table.contains(unlockbooks, name) then
						table.insert(unlockbooks, name)
					end
				end
				count = #unlockbooks
			end
			-- 解锁2本、6本、12本、17本各一档位、麦书单独一档位
			return 1 + (count >= 2 and 0.1 or 0) + (count >= 6 and 0.1 or 0) + (count >= 12 and 0.1 or 0) + (count >= 17 and 0.1 or 0) + (inst:HasTag("shadowmagic") and 0.1 or 0)
		end
		local function processrolestrength(inst)
			if not TheWorld.ismastersim then return end
			if not inst.components.combat.customdamagemultfn then
				inst.components.combat.customdamagemultfn = CustomCombatDamage
			else
				local old = inst.components.combat.customdamagemultfn
				inst.components.combat.customdamagemultfn = function(...) return (old(...) or 1) * CustomCombatDamage(...) end
			end
		end
		AddPrefabPostInit("wickerbottom", processrolestrength)
	end
	
    -- 书柜动态等级
    local function NewRestoreBooks(inst)
        local wicker_bonus = 1
        local x, y, z = inst.Transform:GetWorldPosition()
        local players = FindPlayersInRange(x, y, z, TUNING.BOOKSTATION_BONUS_RANGE, true)
        for _, player in ipairs(players) do
            if player:HasTag("bookbuilder") then
                wicker_bonus = TUNING.BOOKSTATION_WICKER_BONUS
                break
            end
        end
        for k, v in pairs(inst.components.container.slots) do
            if v and v:HasTag("book") and not v:HasTag("dailybook2hm") and v.components.finiteuses then
                local percent = v.components.finiteuses:GetPercent()
                if percent < 1 then v.components.finiteuses:SetPercent(math.min(1, percent + (TUNING.BOOKSTATION_RESTORE_AMOUNT * wicker_bonus))) end
            end
        end
    end
    local updatemode = hardmode and GetModConfigData("role_nerf") and GetModConfigData("wickerbottom")
    local function resetbookstationlevel(inst)
        if not inst.init2hm then
            inst.init2hm = true
            inst:ListenForEvent("itemget", resetbookstationlevel)
            inst:ListenForEvent("itemlose", resetbookstationlevel)
            if inst.RestoreTask ~= nil and updatemode then
                inst.RestoreTask:Cancel()
                inst.RestoreTask = nil
            end
        end
        if not inst.components.container then return end
        local items = {}
        for k, v in pairs(inst.components.container.slots) do
            if v and v:IsValid() and v.prefab and table.contains(books, v.prefab) and not table.contains(items, v.prefab) then
                table.insert(items, v.prefab)
            end
        end
        local oldbookslevel2hm = inst.bookslevel2hm or 0
        inst.bookslevel2hm = math.min(math.floor(#items / 4), 4)
        if inst.bookslevel2hm == oldbookslevel2hm then
            if inst.master2hm and inst.master2hm:IsValid() and inst.master2hm.components.builder then
                inst.master2hm.components.builder:EvaluateTechTrees()
            end
            return
        elseif inst.bookslevel2hm > oldbookslevel2hm then
            local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
            shinefx.AnimState:SetTime(10 * FRAMES)
            local parent = inst.master2hm and inst.master2hm:IsValid() and inst.master2hm or inst
            parent:AddChild(shinefx)
            inst:PushEvent("ms_giftopened")
        elseif inst.bookslevel2hm < oldbookslevel2hm and inst.components.workable then
            inst.components.workable.onwork(inst)
        end
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl2_ding")
        if inst.level2hm then inst.level2hm:set(inst.bookslevel2hm) end
        if inst.master2hm and inst.master2hm:IsValid() and inst.master2hm.bookstationlevel2hm then
            inst.master2hm.bookstationlevel2hm:set(inst.bookslevel2hm)
        end
        if updatemode then
            if inst.RestoreTask ~= nil then
                inst.RestoreTask:Cancel()
                inst.RestoreTask = nil
            end
            if inst.bookslevel2hm > 0 then
                inst.RestoreTask = inst:DoPeriodicTask(TUNING.BOOKSTATION_RESTORE_TIME * (8 - inst.bookslevel2hm * 1.5) / 8, NewRestoreBooks)
            end
        end
        local prototyper = inst.components.prototyper or (inst.master2hm and inst.master2hm:IsValid() and inst.master2hm.components.prototyper) or nil
        if prototyper then
            prototyper.trees = TechTree.Create({
                SCIENCE = math.clamp(math.floor(inst.bookslevel2hm * 2 / 3) + 1, not hardmode and inst.prefab == "bookstation" and 2 or 0, 3),
                BOOKCRAFT = math.clamp(inst.bookslevel2hm, not hardmode and inst.prefab == "bookstation" and 1 or 0, 1),
                CARPENTRY = math.clamp(inst.bookslevel2hm, 0, 2),
                SEAFARING = math.clamp(inst.bookslevel2hm, 0, 2),
                CARTOGRAPHY = math.clamp(inst.bookslevel2hm - 1, 0, 2),
                MAGIC = math.clamp(inst.bookslevel2hm - 2, not hardmode and inst.prefab == "bookstation" and 1 or 0, 2),
                TURFCRAFTING = math.clamp(inst.bookslevel2hm - 2, 0, 2),
                MASHTURFCRAFTING = math.clamp(inst.bookslevel2hm - 2, 0, 2),
                FISHING = math.clamp(inst.bookslevel2hm - 3, 0, 1)
            })
            if prototyper.doers then
                for doer, v in pairs(prototyper.doers) do
                    if v and doer and doer ~= inst.master2hm and doer.components.builder then doer.components.builder:EvaluateTechTrees() end
                end
            end
            if inst.master2hm and inst.master2hm:IsValid() and inst.master2hm.components.builder then
                inst.master2hm.components.builder:EvaluateTechTrees()
            end
        end
    end
    local function DisplayNameFn(inst) return inst.name .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 4 and " Max" or "") end
    local function processbookstation(inst)
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "bookstation.level2hm")
        if not TheWorld.ismastersim then return end
        inst.level2hm:set(0)
        if inst.components.prototyper and hardmode then inst.components.prototyper.trees = {BOOKCRAFT = 0, SCIENCE = 1, MAGIC = 0} end
        inst:DoTaskInTime(0, resetbookstationlevel)
    end
    AddPrefabPostInit("bookstation", processbookstation)
    AddPrefabPostInit("bookstation2hm", processbookstation)
end


-- 无开关-------------------------------------------------------------------------------
-- 2025.9.5 melon:奶奶养蜂笔记的蜜蜂影子不打奶奶(超过领袖险境的仍然打)
AddPrefabPostInit("beeguard", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0.2, function(inst)
        if inst:HasTag("swc2hm") and inst.swp2hm and inst.swp2hm.components.follower and inst.swp2hm.components.follower.leader and inst.swp2hm.components.follower.leader:HasTag("player") then
            inst:AddToArmy(inst.swp2hm.components.follower.leader)
        end
    end)
end)

-- 奶奶和鱼妹莎草纸修书:一张纸修复50%耐久
if GetModConfigData("Wickerbottom Repair Book With Papyrus") then
    local repair_books = {
        "book_birds", "book_gardening", "book_horticulture", "book_horticulture_upgraded",
        "book_silviculture", "book_sleep", "book_brimstone", "book_tentacles", "book_fish",
        "book_web", "book_temperature", "book_light", "book_light_upgraded", "book_fire",
        "book_moon", "book_rain", "book_bees", "book_research_station"
    }
    for _, bookprefab in ipairs(repair_books) do
        AddPrefabPostInit(bookprefab, function(inst)
            local total = inst.components.finiteuses and inst.components.finiteuses.total or 3
            inst.repairmaterials2hm = {papyrus = total * 0.5}
            if not TheWorld.ismastersim then return end
            inst:AddComponent("repairable2hm")
            inst.components.repairable2hm.customrepair = function(book, repairuse, doer, repair_item)
                if doer and doer:IsValid() and (doer.prefab == "wickerbottom" or doer.prefab == "wurt") then
                    return -1 -- 走默认修复流程
                end
                return false -- 其他角色不能修
            end
        end)
    end
end

-- 奶奶天体科技制作后永久解锁:在原版天体科技下(拼好的祭坛/天体宝球提供CELESTIAL)制作过一次物品后
-- 永久解锁,不再需要靠近。原版机制完全不动(靠近祭坛临时解锁依然生效),只在制作成功后把状态永久化。
if GetModConfigData("Wickerbottom Touch Astral Altar Unlock Celestial") then
    -- 奶奶自带科技UI定义(每日一书关闭时也可能缺,这里兜底补上)
    if not PROTOTYPER_DEFS.wickerbottom then
        PROTOTYPER_DEFS.wickerbottom = {
            icon_atlas = "images/crafting_menu_avatars.xml",
            icon_image = "avatar_wickerbottom.tex",
            action_str = "WICKERBOTTOM",
            is_crafting_station = false
        }
    end
    -- 标记解锁并立即刷新科技(不给自己加prototyper组件,用原版科技加成celestial_bonus永久注入)
    local function mark_celestial_unlocked2hm(inst)
        if inst._celestial_unlocked2hm then return end
        inst._celestial_unlocked2hm = true
        if not inst.components.persistent2hm then
            inst:AddComponent("persistent2hm")
        end
        if inst.components.persistent2hm.data then
            inst.components.persistent2hm.data.celestial_unlocked2hm = true
        end
        if inst.components.builder then
            -- 用原版科技加成机制注入:EvaluateTechTrees每次评估自动叠加celestial_bonus,且原版trees_changed检测
            -- 只在科技树真变化时才SetTechTrees网络推送(旧方案包装EvaluateTechTrees无条件推送,每帧全量同步导致卡顿+快速堆叠失灵)
            inst.components.builder.celestial_bonus = 3
            inst.components.builder:EvaluateTechTrees()
        end
    end
    -- 永久解锁:已解锁则靠原版科技加成celestial_bonus注入(无prototyper时EvaluateTechTrees会读取self.celestial_bonus叠加到CELESTIAL)
    AddPrefabPostInit("wickerbottom", function(inst)
        if not TheWorld.ismastersim then return end
        -- 确保持久化组件存在(persistent2hm的data通过OnLoad从存档恢复)
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        -- 重进恢复:解锁过则恢复科技加成(OnLoad回调中data已从存档恢复,评估时自动生效)
        SetOnLoad2hm(inst, function(inst, data)
            if data and data.celestial_unlocked2hm then
                inst._celestial_unlocked2hm = true
                if inst.components.builder then
                    inst.components.builder.celestial_bonus = 3
                end
            end
        end)
        if inst.components.builder then
            -- 触发解锁:奶奶成功制作物品时,若当前正处于原版天体科技下(靠近拼好的祭坛/天体宝球,
            -- 由EvaluateTechTrees把CELESTIAL注入accessible_tech_trees),则把解锁状态永久化。
            -- 远离祭坛/未解锁时accessible_tech_trees.CELESTIAL为0,制作不会误触发。
            local old_build = inst.components.builder.DoBuild
            inst.components.builder.DoBuild = function(self, ...)
                local ok = old_build(self, ...)
                if ok and not self.inst._celestial_unlocked2hm
                    and self.accessible_tech_trees and self.accessible_tech_trees.CELESTIAL and self.accessible_tech_trees.CELESTIAL > 0 then
                    mark_celestial_unlocked2hm(self.inst)
                end
                return ok
            end
        end
    end)
end

