-----------------------------------------------------------------------------------
---------------------[[2025.5.19 melon:永不妥协补丁]]------------------------------
-- 永不妥协补丁  大部分功能与mod: 永不妥协补丁(uncompromising patch) 一样
-----------------------------------------------------------------------------------
-- 引用
local UpvalueHacker = require("upvaluehacker2hm")
local UMGuard = require("umcompatguard2hm")
-- 五格锅所必需的动态料理防崩溃适配也统一由此入口加载。
-- 关闭可选补丁时，只保留当前确实启用的五格锅所需部分。
local optionalpatch = GetModConfigData("um_patch")
-- Guard each upstream implementation before replacing it. Critical cloud
-- correctness remains active; performance/visual adjustments follow um_patch.
if TUNING.DSTU then require("umperformance2hm").Install(env, optionalpatch) end
local fivepot = TUNING.hardmode2hm and GetModConfigData("food_change") and GetModConfigData("cooking_change") == -3
if TUNING.DSTU and UM_CONFIG and UM_CONFIG.FOOD_STATS and (optionalpatch or fivepot) then
    modimport("easy_other/um_food_stats.lua")
end
if not optionalpatch then return end
require("umwinonaworker2hm").Install(env)
-----------------------------------------------------------------------------------
--[[修改列表:
将妥协的瓶中信出宝藏概率34%改回60%
修复雪球砸亮茄崩溃
妥协厨师袋也可以移动中打开
熊皮衣格子
修复动态料理属性及多模组锅具兼容
优化两版妥协天气与测试版生态任务，自动跳过未知上游实现
修复已核对测试版薇诺娜死亡与复活时工作监听的清理和恢复
修复沃托克斯编织暗影重载后恢复掉落
修复修补工具包互修和零收益扣次
佩戴巧手勋章时可使用电能转换套件

滑行手杖(马头杖)加移速减cd
输出老鼠分时输出扣分物品名字和分数(根据TUNING.isCh2hm判断中英文输出)
月龙、时令龙不再传送至玩家附近
月麟甲加耐久 发光范围更大
维希幽闭恐惧由独立选项控制
修复温蒂灵魂万灵药不能双倍的问题，但概率减半
熊大脱加载不再动

开启鼠潮时自动打开老鼠分宣告
合并过冷和过热的血量上限扣减
--]]
--------------------------------------------------------------------------------------------------------
if TUNING.DSTU then

    -- Reviewed beta songs inspected combat.target and nearby training dummies
    -- instead of the entity this attack hit. Antlion deals damage via spikes,
    -- so its zero defaultdamage must not make an actual boss hit ineligible.
    local function ValidBattlesongAttack(attacker, data)
        local victim = data and data.target
        if victim == nil or not victim:IsValid() or victim.components.health == nil or victim.components.combat == nil then return false end
        if victim:HasTag("eyeturret") or victim:HasTag("structure") or victim:HasTag("wall") or victim:HasTag("veggie") or
            victim:HasTag("balloon") or victim:HasTag("groundspike") or victim:HasTag("smashable") or victim:HasTag("companion") or
            (victim:HasTag("prey") and not victim:HasTag("hostile")) then return false end
        if victim.components.combat.defaultdamage <= 0 and not (victim:HasTag("hostile") or victim:HasTag("epic")) then return false end
        if data.projectile and data.projectile.components.projectile and data.projectile.components.projectile:IsBounced() then return false end
        if data.weapon and data.weapon.components.inventoryitem == nil then return false end
        return true
    end
    local function RepairBattlesongAttackFilter(inst)
        if not TheWorld.ismastersim or not inst.songdata then return end
        local slot = UMGuard.Find(inst.songdata.ONAPPLY, "CheckValidAttackData")
        if slot and UMGuard.Known(slot.value, "battlesong_attack_filter") then
            if UMGuard.Replace(slot, ValidBattlesongAttack) then
                TUNING.UM_COMPAT_STATUS2HM = TUNING.UM_COMPAT_STATUS2HM or {}
                TUNING.UM_COMPAT_STATUS2HM.wigfrid_battlesongs = {applied = true, reason = "reviewed beta actual-hit victim filter"}
            end
        end
    end
    AddPrefabPostInit("battlesong_healthgain", RepairBattlesongAttackFilter)
    AddPrefabPostInit("battlesong_sanitygain", RepairBattlesongAttackFilter)

    local electrical_type = UPGRADETYPES.ELECTRICAL
    if electrical_type and ModManager:GetMod("workshop-1909182187") then
        local kit_prefab = "winona_upgradekit_electrical"
        local upgrader_tag = electrical_type .. "_upgrader"
        local upgradeable_tag = electrical_type .. "_upgradeable"
        local upgradeuser_tag = electrical_type .. "_upgradeuser"

        -- 巧手考验勋章不授予 has_handy_medal。沿用原版升级动作。
        table.insert(TUNING.USEITEMFNS2HM, function(inst, doer, target, actions)
            if inst.prefab == kit_prefab and target and target:HasTag(upgradeable_tag) and inst:HasTag(upgrader_tag) and
                doer:HasTag("has_handy_medal") and not doer:HasTag(upgradeuser_tag) then
                table.insert(actions, ACTIONS.UPGRADE)
            end
        end)

        AddPrefabPostInit(kit_prefab, function(inst)
            if not TheWorld.ismastersim then return end
            local upgrader = inst.components.upgrader
            if not upgrader then return end

            local CanUpgrade = upgrader.CanUpgrade
            function upgrader:CanUpgrade(target, doer, ...)
                if self.upgradetype == electrical_type and target.components.upgradeable.upgradetype == electrical_type and
                    doer and doer:HasTag("has_handy_medal") then
                    return true
                end
                return CanUpgrade(self, target, doer, ...)
            end
        end)
    end

    local gem_repair_values = TUNING.DSTU.GEM_REPAIRER_REPAIR_VALUE
    if ACTIONS.UM_GEM_REPAIR and gem_repair_values then
        AddPrefabPostInitAny(function(inst)
            if inst.prefab ~= "um_gem_repair_kit" or not TheWorld.ismastersim then return end
            local repairer = inst.components.gemrepairer
            if not repairer then return end

            -- UM's earlier PrefabPostInitAny enables repairs for every finite-use item.
            if inst.um_cangemrepair then inst.um_cangemrepair:set(false) end

            local OnUsed = repairer.OnUsed
            repairer.OnUsed = function(self, target, doer, ...)
                if target.prefab == "um_gem_repair_kit" then return false, "NO_REPAIR_NEEDED" end

                local repair_count = target.um_repaircount or 1
                local repair_value = gem_repair_values[math.clamp(repair_count, 1, #gem_repair_values)]
                if repair_value <= repair_count / 10 then
                    -- UM counts a zero-point enchantment repair as success. At this tier
                    -- the kit should only be spent if it can restore the item itself.
                    local finiteuses = target.components.finiteuses
                    local armor = target.components.armor
                    local uses_worn = finiteuses and finiteuses:GetPercent() < 1
                    local armor_worn = armor and not armor:IsIndestructible() and armor:GetPercent() < 1
                    if not uses_worn and not armor_worn then return false, "NO_REPAIR_NEEDED" end
                end
                return OnUsed(self, target, doer, ...)
            end
        end)
    end

    do
        -- Current beta rolls its own buttery butterfly on spawn. Keep the
        -- upstream roll/save marker; do not run a second conversion here.

        if UPGRADETYPES.SOUL_SHADOW then
            local function IsWovenShadow(inst)
                return inst.wortox_minion or inst.wortox_woven2hm
            end

            local function PreserveWovenShadow(inst)
                if not TheWorld.ismastersim then return end

                -- World saves and boat bottles both use the prefab's save record.
                local OnSave, OnLoad = inst.OnSave, inst.OnLoad
                inst.OnSave = function(inst, data, ...)
                    if IsWovenShadow(inst) then data.wortox_woven2hm = true end
                    if OnSave then return OnSave(inst, data, ...) end
                end
                inst.OnLoad = function(inst, data, ...)
                    if data and data.wortox_woven2hm == true then inst.wortox_woven2hm = true end
                    if OnLoad then return OnLoad(inst, data, ...) end
                end

                local lootdropper = inst.components.lootdropper
                if lootdropper == nil then return end

                -- Loot tables can change after loading, and DropLoot can add seasonal loot.
                local GenerateLoot, DropLoot = lootdropper.GenerateLoot, lootdropper.DropLoot
                function lootdropper:GenerateLoot(...)
                    if IsWovenShadow(self.inst) then return {} end
                    return GenerateLoot(self, ...)
                end
                function lootdropper:DropLoot(...)
                    if IsWovenShadow(self.inst) then return end
                    return DropLoot(self, ...)
                end
            end

            for _, prefab in ipairs({
                "stalker_minion", "stalker_minion1", "stalker_minion2",
                "crawlingnightmare", "nightmarebeak", "ruinsnightmare", "shadowthrall_mouth"
            }) do
                AddPrefabPostInit(prefab, PreserveWovenShadow)
            end
        end

        -- 2025.8.22 melon:将妥协的瓶中信出宝藏概率34%改回60%
        if TUNING.MESSAGEBOTTLE_NOTE_CHANCE > 0.4 then TUNING.MESSAGEBOTTLE_NOTE_CHANCE = 0.4 end
        -- 2025.5.3 melon:修复雪球砸亮茄崩溃-------------------------------------------
        AddStategraphPostInit("lunarthrall_plant_vine", function(sg)
            if sg.events and sg.events.attacked and sg.events.attacked.fn then
                local attacked = sg.events.attacked.fn
                sg.events.attacked.fn = function(inst, ...)
                    -- Only guard UM's health-less vine; preserve native
                    -- electrocution handling and any later upstream behavior.
                    if inst.components.health then return attacked(inst, ...) end
                end
            end
        end)
        -- 2025.5.3 melon:妥协厨师袋也可以移动中打开(但需要防止毒雾影响)-------------------------
        -- 防毒雾写在lunar_shadow_items.lua了
        AddPrefabPostInit("spicepack", function(inst)
            inst:RemoveTag("portablestorage")
            inst:AddTag("portablestoragePG")
            if not TheWorld.ismastersim then return end
            if inst.components.container.droponopen then inst.components.container.droponopen = nil end
        end)
        -- 熊皮大衣的六格口袋
        local containers = require("containers")
        containers.params.pack2hm2p3 =
        {
            widget =
            {
                slotpos = {},
                animbank = "ui_icepack_2x3",
                animbuild = "ui_icepack_2x3",
                pos = Vector3(-5, -70, 0),
            },
            issidewidget = true,
            type = "pack",
        }
        for y = 0, 2 do
            table.insert(containers.params.pack2hm2p3.widget.slotpos, Vector3(-162, -75 * y + 75, 0))
            table.insert(containers.params.pack2hm2p3.widget.slotpos, Vector3(-162 + 75, -75 * y + 75, 0))
        end
        local function OnContainerChanged(inst)
            if inst.components.container:IsEmpty() then inst.components.inventoryitem.cangoincontainer = true
            else inst.components.inventoryitem.cangoincontainer = false end
        end
        local function SetBeargerVestPockets(inst)
            inst:AddTag("pocketbackpack")
            if not TheWorld.ismastersim then
                local OnEntityReplicated = inst.OnEntityReplicated
                inst.OnEntityReplicated = function(inst, ...)
                    if OnEntityReplicated then OnEntityReplicated(inst, ...) end
                    inst.replica.container:WidgetSetup("pack2hm2p3")
                end
                return
            end
            if inst.components.container then
                -- 测试版已经接好了穿脱和耐久耗尽逻辑，只覆盖它的四格布局。
                inst.components.container:WidgetSetup("pack2hm2p3")
                return
            end
            inst:AddComponent("container")
            inst.components.container.itemtestfn = function() return true end
            inst.components.container:WidgetSetup("pack2hm2p3")
            if inst.components.equippable ~= nil then
                local _onequipfn = inst.components.equippable.onequipfn
                inst.components.equippable.onequipfn = function(inst, owner)
                    if inst.components.container ~= nil then inst.components.container:Open(owner) end
                    if _onequipfn ~= nil then _onequipfn(inst, owner) end
                end
                local _onunequipfn = inst.components.equippable.onunequipfn
                inst.components.equippable.onunequipfn = function(inst, owner)
                    if inst.components.container ~= nil then inst.components.container:Close(owner) end
                    if _onunequipfn ~= nil then _onunequipfn(inst, owner) end
                end
            end
            -- 检查有无燃料组件 没燃料的时候掉落东西
            if inst.components.fueled ~= nil then
                local _depleted = inst.components.fueled.depleted
                inst.components.fueled:SetDepletedFn(function(inst)
                    if inst.components.container ~= nil then
                        inst.components.container:DropEverything()
                    end
                    if _depleted ~= nil then _depleted(inst) end
                end)
            end
            -- 监听事件
            inst:ListenForEvent("itemget", OnContainerChanged)
            inst:ListenForEvent("itemlose", OnContainerChanged)
        end
        -- 正式版从 DSTU 读取设置，测试版已迁移到 UM_CONFIG。
        if TUNING.DSTU.POCKET_POWERTRIP or (UM_CONFIG and UM_CONFIG.POCKET_POWERTRIP) then
            AddPrefabPostInit("beargervest", SetBeargerVestPockets)
        end
    end

    do
        -- 滑行手杖(马头杖)加移速-------------------------------------------------------
        AddPrefabPostInit("the_real_charles_t_horse", function(inst)
            if not TheWorld.ismastersim then return end
            inst.components.equippable.walkspeedmult = 1.25 -- 装备移速
        end)
        -- 输出老鼠分时输出扣分物品代码-------------------------------------------------------
        -- 2025.8.22 melon:根据妥协的更新进行修改
        local function IsAVersionOfRot(v)
            local rotprefabs = {"spoiled_food", "rottenegg", "spoiled_fish", "spoiled_fish_small"}
            return table.contains(rotprefabs, v.prefab)
        end
        -- 2025.9.5 melon:排除的算分容器 钓鱼容器、暗影空间
        local safe_container = {"meatrack", "mushroom_light", "mushroom_light2", "tacklestation2hm", "shadowbank_tackle2hm", "shadow_container", "offering_pot_upgraded", }
        local function SnifferFoodScoreCalculations(inst, container, v)
            local stackmult = v.components.stackable and v.components.stackable:StackSize() or 1
            local preparedmult = v:HasTag("preparedfood") and 2 or 1
            local delta = not container and (v:HasTag("fresh") and 5 or v:HasTag("stale") and 10 or (v:HasTag("spoiled") or IsAVersionOfRot(v)) and 15)
                or (v:HasTag("stale") and 2.5 or (v:HasTag("spoiled") or IsAVersionOfRot(v)) and 5) or 0
            delta = (delta > 0 and ((delta * preparedmult) * stackmult) or delta) -- 分解1
            -- 输出物品名字和分数
            if v and v.prefab and inst.foodscore < 240 and delta > 0 and TUNING.DSTU.ANNOUNCE_BASESTATUS then
                local owner = v.components.inventoryitem and (v.components.inventoryitem:GetGrandOwner() or v.components.inventoryitem.owner)
                local owner_is_player = owner and owner:HasTag("player")
                local owner_name = owner and owner.prefab
                -- 2025.9.5 melon:排除一些容器
                if table.contains(safe_container, owner_name) then return end
                if TUNING.isCh2hm then
                    TheNet:SystemMessage(string.format("%-20s %-15s %-10s", "食物: " .. (STRINGS.NAMES[string.upper(v.prefab)] or v.prefab), (owner_is_player and " 玩家: " or " 容器: ") .. (owner_name and (STRINGS.NAMES[string.upper(owner_name)] or owner_name) or "无"), " 分数: " .. delta))
                else
                    TheNet:SystemMessage(string.format("%-20s %-15s %-10s", "Food: " .. (STRINGS.NAMES[string.upper(v.prefab)] or v.prefab), (owner_is_player and " player: " or " container: ") .. (owner_name and (STRINGS.NAMES[string.upper(owner_name)] or owner_name) or "none"), " score: " .. delta))
                end
            end
            inst.foodscore = inst.foodscore + delta -- 分解2
            -- 原有代码分解为上面2行 便于输出
            -- inst.foodscore = inst.foodscore + (delta > 0 and ((delta * preparedmult) * stackmult) or delta)
        end

        local NO_CONTAINER_PREFABS = {"lureplant", "catcoon"}
        local function IsProperContainer(owner)
            return not owner or owner and not (table.contains(NO_CONTAINER_PREFABS, owner.prefab) or owner:HasAnyTag("lamp", "yots_post", "krampus_middleman", "pocketdimension_container", "buried"))
        end
        
        local NOTAGS = {"engineeringbatterypowered", "smallcreature", "_container", "spore", "NORATCHECK", "_combat", "_health", "balloon", "heavy", "projectile", "frozen", "deployedfarmplant", "outofreach"}
        local function TimeForACheckUp(inst, dev)
            local x, y, z = inst.Transform:GetWorldPosition()
        
            local ents = TheSim:FindEntities(x, 0, z, 40, {"_inventoryitem"}, NOTAGS)

            inst.ratscore = -60
            inst.itemscore = 0
            inst.foodscore = 0
        
            inst.ratburrows = TheWorld.components.ratcheck ~= nil and TheWorld.components.ratcheck:GetBurrows() or 0
            inst.burrowbonus = 15 * inst.ratburrows
        
            if ents ~= nil then
                for i, v in ipairs(ents) do
                    if (inst.ratscore + inst.itemscore + inst.foodscore + inst.burrowbonus) < 240 then
                        local container = v.components.inventoryitem:IsHeld() and (v.components.inventoryitem:GetGrandOwner() or v.components.inventoryitem.owner)
                        if IsProperContainer(container) then
                            if container then
                                SnifferFoodScoreCalculations(inst, true, v)
                            else
                                SnifferFoodScoreCalculations(inst, false, v)
                                if TUNING.DSTU.ITEMCHECK and v:HasAnyTag("_equippable", "tool", "gem") then
                                    local delta = 30
                                    if v.components.stackable then delta = math.min(30, v.components.stackable:StackSize() * 5) end
                                    -- 输出物品名字和分数
                                    if v.prefab and inst.itemscore < 240 and TUNING.DSTU.ANNOUNCE_BASESTATUS then
                                        local owner = v.components.inventoryitem and (v.components.inventoryitem:GetGrandOwner() or v.components.inventoryitem.owner)
                                        local owner_name = owner and owner.prefab
                                        if TUNING.isCh2hm then
                                            TheNet:SystemMessage(string.format("%-20s %-15s %-10s", "物品: " .. (STRINGS.NAMES[string.upper(v.prefab)] or v.prefab), " 容器: " .. (owner_name and (STRINGS.NAMES[string.upper(owner_name)] or owner_name) or "无"), " 分数: " .. delta))
                                        else
                                            TheNet:SystemMessage(string.format("%-20s %-15s %-10s", "Item: " .. (STRINGS.NAMES[string.upper(v.prefab)] or v.prefab), " container: " .. (owner_name and (STRINGS.NAMES[string.upper(owner_name)] or owner_name) or "none"), " score: " .. delta))
                                        end
                                    end
                                    inst.itemscore = inst.itemscore + delta -- Oooh, wants wants! We steal!
                                end
                            end
                        end
                    end
                end
            end
        
            inst.ratscore = inst.ratscore + inst.itemscore + inst.foodscore + inst.burrowbonus
            if inst.ratscore > 0 and TUNING.DSTU.ANNOUNCE_BASESTATUS then
                if TUNING.isCh2hm then
                    TheNet:SystemMessage("以上来自为爽而虐-配置:永不妥协补丁")
                else
                    TheNet:SystemMessage("The above is from Shadow World. Option:um_patch")
                end
            end
            if TUNING.DSTU.ANNOUNCE_BASESTATUS then
                if TUNING.isCh2hm then
                    TheNet:SystemMessage("-------------------------")
                    TheNet:SystemMessage("物品分 = " .. inst.itemscore)
                    TheNet:SystemMessage("食物分 = " .. inst.foodscore)
                    TheNet:SystemMessage("鼠巢分 = " .. inst.burrowbonus)
                    -- TheNet:SystemMessage("老鼠分 = " .. inst.ratscore)
                else
                    TheNet:SystemMessage("-------------------------")
                    TheNet:SystemMessage("Itemscore = " .. inst.itemscore)
                    TheNet:SystemMessage("Foodscore = " .. inst.foodscore)
                    TheNet:SystemMessage("Burrowbonus = " .. inst.burrowbonus)
                    TheNet:SystemMessage("Ratscore = " .. inst.ratscore)
                end
            end
            if inst.ratscore > 240 then inst.ratscore = 240 end
            if TUNING.DSTU.ANNOUNCE_BASESTATUS then
                if TUNING.isCh2hm then
                    TheNet:SystemMessage("老鼠分 = " .. inst.ratscore)
                    TheNet:SystemMessage("鼠潮倒计时 = " .. (TheWorld.components.ratcheck:GetRatTimer() ~= nil and TheWorld.components.ratcheck:GetRatTimer() or "... not available? timer is 0 second") .. "s")
                    TheNet:SystemMessage("-------------------------")
                else
                    TheNet:SystemMessage("True Ratscore = " .. inst.ratscore)
                    TheNet:SystemMessage("Timer = " .. (TheWorld.components.ratcheck:GetRatTimer() ~= nil and TheWorld.components.ratcheck:GetRatTimer() or "... not available? timer is 0 second") .. "s")
                    TheNet:SystemMessage("-------------------------")
                end
            end
        
            if not dev then
                TheWorld:PushEvent("reducerattimer", { value = inst.ratscore })
        
                inst.ratwarning = inst.ratscore / 48

                if inst.ratscore >= 60 then
                    if math.random() > 0.85 then
                        if inst.ratwarning > 5 then inst.ratwarning = 5 end
        
                        for c = 1, (inst.ratwarning) do
                            inst:DoTaskInTime((c / 5), function(inst)
                                local warning = SpawnPrefab("uncompromising_ratwarning")
                                warning.Transform:SetPosition(inst.Transform:GetWorldPosition())
                            end)
                        end
        
                        local players = TheSim:FindEntities(x, y, z, 40, {"player"}, {"playerghost"})
                        for a, b in ipairs(players) do
                            if math.random() > 0.5 then
                                local str = inst.burrowbonus > inst.itemscore and inst.burrowbonus > inst.foodscore and "BURROWS"
                                    or inst.itemscore > inst.burrowbonus and inst.itemscore > inst.foodscore and "ITEMS"
                                    or inst.foodscore > inst.burrowbonus and inst.foodscore > inst.itemscore and "FOOD" or nil
                                if str then
                                    b:DoTaskInTime(2 + math.random(), function(b) b.components.talker:Say(GetString(b, "ANNOUNCE_RATSNIFFER_"..str, "LEVEL_1")) end)
                                end
                            end
                        end
                    end
                end
            end
        end
        -------------------------------------------
        AddPrefabPostInit("uncompromising_ratsniffer",function(inst)
            if not TheWorld.ismastersim then return end
            local _TimeForACheckUp = nil -- 记录原来的函数
            local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
            local listeners = inst.event_listeners and inst.event_listeners["rat_sniffer"]
            for i, func in ipairs(listeners and listeners[inst] or {}) do -- 找函数
                if UMGuard.Known(func, "legacy_rat_check") and UpvalueHacker.GetUpvalue(func, "SnifferFoodScoreCalculations") then
                    _TimeForACheckUp = func -- 调用SnifferFoodScoreCalculations的即为所找监听函数
                    count_fn = count_fn + 1
                end
            end
            if _TimeForACheckUp ~= nil and count_fn == 1 then
                inst:RemoveEventCallback("rat_sniffer", _TimeForACheckUp)
                inst:ListenForEvent("rat_sniffer", TimeForACheckUp)
                inst.TimeForACheckUp2hm = TimeForACheckUp -- 保存 方便后续修改
                -- 妥协汉化改了写法，判断路径对才改，所以不需要DoTaskInTime(1了
            end
        end)
        -- 2025.9.19 melon:鱼人头盔、鱼人工具、魔法帽不算老鼠分(魔法帽使用时会算分)
        local no_rat_prefabs = {
            "tophat", "mermarmorhat", "mermarmorupgradedhat", "merm_tool", "merm_tool_upgraded",
            -- doll body/hat  2025.10.21
            "costume_doll_body", "costume_blacksmith_body", "costume_mirror_body", "costume_queen_body",
            "costume_king_body", "costume_tree_body", "costume_fool_body", 
            "mask_dollhat", "mask_dollbrokenhat", "mask_dollrepairedhat", "mask_blacksmithhat", 
            "mask_mirrorhat", "mask_queenhat", "mask_kinghat", "mask_treehat", "mask_foolhat", 
        }
        for _,prefab in ipairs(no_rat_prefabs) do
            AddPrefabPostInit(prefab,function(inst) inst:AddTag("NORATCHECK") end)
        end
        -- 月龙、时令龙不再传送至玩家附近-------------------------------------------------------
        local function LeaveWorld(inst) inst:Remove() end
        local function OnEntitySleep(inst)
            local PlayerPosition = inst:GetNearestPlayer()
            if inst.shouldGoAway then
                LeaveWorld(inst)
            else
                -- do nothing
            end
        end
        AddPrefabPostInit("moonmaw_dragonfly",function(inst)
            if not TheWorld.ismastersim then return end
            -- 2025.8.17 melon:第2天月龙也不跟过来。但会导致非夏天脱加载不消失，要第2天才消失。
            -- "seasontick" 这个监听事件妥协放到TheWorld.event_listeners里了
            if TheWorld.event_listeners and TheWorld.event_listeners["seasontick"] then
                for i, func in ipairs(TheWorld.event_listeners["seasontick"][inst] or {}) do -- 找函数
                    if UpvalueHacker.GetUpvalue(func, "OnSeasonChange") then -- seasontick里找OnSeasonChange
                        local fn, i, prv = UpvalueHacker.GetUpvalue(func, "OnSeasonChange")
                        if UMGuard.Known(fn, "legacy_moonmaw_season") and
                            UMGuard.Known(UpvalueHacker.GetUpvalue(fn, "OnEntitySleep"), "legacy_moonmaw_sleep") then
                            UpvalueHacker.SetUpvalue(fn, OnEntitySleep, "OnEntitySleep")
                        end
                    end
                end
            end
            -- "entitysleep"
            local _OnEntitySleep = nil -- 记录原来的函数
            local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
            local listeners = inst.event_listeners and inst.event_listeners["entitysleep"]
            for i, func in ipairs(listeners and listeners[inst] or {}) do -- 找函数
                if UMGuard.Known(func, "legacy_moonmaw_sleep") and UpvalueHacker.GetUpvalue(func, "LeaveWorld") then
                    -- TheNet:SystemMessage(debug.getinfo(func, "S").source or "nil")
                    _OnEntitySleep = func -- 调用LeaveWorld的即为所找监听函数
                    count_fn = count_fn + 1
                end
            end
            if _OnEntitySleep ~= nil and count_fn == 1 then
                inst:RemoveEventCallback("entitysleep", _OnEntitySleep)
                inst:ListenForEvent("entitysleep", OnEntitySleep)
                inst.OnEntitySleep2hm = OnEntitySleep -- 保存 方便后续修改
            end
        end)
        AddPrefabPostInit("mock_dragonfly",function(inst)
            if not TheWorld.ismastersim then return end
            -- 2025.8.17 melon:第2天时令龙也不跟过来。但会导致非夏天脱加载不消失，要第2天才消失。
            -- "seasontick" 这个监听事件妥协放到TheWorld.event_listeners里了
            if TheWorld.event_listeners and TheWorld.event_listeners["seasontick"] then
                for i, func in ipairs(TheWorld.event_listeners["seasontick"][inst] or {}) do -- 找函数
                    if UpvalueHacker.GetUpvalue(func, "OnSeasonChange") then -- seasontick里找OnSeasonChange
                        local fn, i, prv = UpvalueHacker.GetUpvalue(func, "OnSeasonChange")
                        if UMGuard.Known(fn, "legacy_dragon_season") and
                            UMGuard.Known(UpvalueHacker.GetUpvalue(fn, "OnEntitySleep"), "legacy_dragon_sleep") then
                            UpvalueHacker.SetUpvalue(fn, OnEntitySleep, "OnEntitySleep")
                        end
                    end
                end
            end
            -- "entitysleep"
            local _OnEntitySleep = nil -- 记录原来的函数
            local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
            local listeners = inst.event_listeners and inst.event_listeners["entitysleep"]
            for i, func in ipairs(listeners and listeners[inst] or {}) do -- 找函数
                if UMGuard.Known(func, "legacy_dragon_sleep") and UpvalueHacker.GetUpvalue(func, "LeaveWorld") then
                    _OnEntitySleep = func -- 调用LeaveWorld的即为所找监听函数
                    count_fn = count_fn + 1
                end
            end
            if _OnEntitySleep ~= nil and count_fn == 1 then
                inst:RemoveEventCallback("entitysleep", _OnEntitySleep)
                inst:ListenForEvent("entitysleep", OnEntitySleep)
                inst.OnEntitySleep2hm = OnEntitySleep -- 保存 方便后续修改
            end
        end)
        -- 月麟甲加耐久 发光范围更大-----------------------------------------------
        AddPrefabPostInit("armor_glassmail",function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.armor then
                inst.components.armor.maxcondition = inst.components.armor.maxcondition + 555
                inst.components.armor.condition = inst.components.armor.condition + 555
            end
        end)
        AddPrefabPostInit("armor_glassmail_shards",function(inst)
            inst.Light:SetRadius(2.3) -- 原本2
        end)
        -- 2025.8.31 melon:修复温蒂灵魂万灵药不能双倍的问题，但概率减半---------------------
        local function elixir_numtogive(recipe, doer)
            local total = 1
            if doer.components.skilltreeupdater and doer.components.skilltreeupdater:IsActivated("wendy_potion_yield") then
                if math.random() < 0.2 then total = total+1 end -- 原本0.4概率
                if math.random() < 0.05 then total = total+1 end -- 原本0.1概率
                if total > 1 then doer:PushEvent("craftedextraelixir",total) end
            end
            return total	
        end
        AddRecipe2(
            "ghostlyelixir_fastregen",
            { Ingredient(GLOBAL.CHARACTER_INGREDIENT.HEALTH, 50), Ingredient("ghostflower", 3) }, -- 简单版:50生命+3哀悼(困难版由role/wendy.lua覆盖)
            TECH.NONE,
            { builder_tag = "elixirbrewer", override_numtogive_fn = elixir_numtogive, no_deconstruction=true},
            { "CHARACTER" }
        )
        -- 熊大脱加载不乱跑-------------------------------------------------------
        -- 会让熊大容易脱仇恨
        AddPrefabPostInit("bearger", function(inst)
            if not TheWorld.ismastersim then return end
            inst.entity:SetCanSleep(true) -- 熊大脱加载不再动
        end)
        -- 2025.10.7 melon:犀牛心移动到犀牛脚下
        local function DeactivateShield(inst)
            inst.Physics:ClearCollisionMask()
            inst.Physics:Stop()
            inst.Physics:CollidesWith(COLLISION.WORLD)
            if inst:HasTag("forcefield") then
                inst:RemoveTag("forcefield")
                if inst._fx ~= nil then
                    inst._fx:kill_fx()
                    inst._fx = nil
                end
                if inst._unshieldtask ~= nil then
                    inst._unshieldtask:Cancel()
                end
            end
        end

        local function ActivateShield(inst)
            if inst.components.health and not inst.components.health:IsDead() then
                inst:AddTag("forcefield")
                if inst._fx ~= nil then
                    inst._fx:kill_fx()
                end
                inst._fx = SpawnPrefab("forcefieldfx")
                inst._fx.entity:SetParent(inst.entity)
                inst._fx.Transform:SetPosition(0, -0.2, 0)
                inst._fx.Transform:SetScale(1,1,1)
                inst._fx.AnimState:SetMultColour(0, 0, 0, 1)

                if inst._unshieldtask ~= nil then
                    inst._unshieldtask:Cancel()
                end
                inst._unshieldtask = inst:DoTaskInTime(20, DeactivateShield) --If somehow AG can't reach this, we'll give a pity timer of 20 seconds.
            end
            if TheSim:FindFirstEntityWithTag("minotaur") and not inst.minotaur then --Updating it this way till we get a fix
                local minotaur = TheSim:FindFirstEntityWithTag("minotaur")
                if minotaur and minotaur:HasTag("swc2hm") and minotaur.swp2hm and minotaur.swp2hm:IsValid() then
                    minotaur = minotaur.swp2hm
                end
                inst.minotaur = minotaur
                if minotaur and type(minotaur.OrganUpdate) == "function" then minotaur:OrganUpdate(minotaur) end
            elseif inst.minotaur then
                if inst.minotaur:HasTag("swc2hm") and inst.minotaur.swp2hm and inst.minotaur.swp2hm:IsValid() then
                    inst.minotaur = inst.minotaur.swp2hm
                end
                if type(inst.minotaur.OrganUpdate) == "function" then inst.minotaur:OrganUpdate(inst.minotaur) end
            end
        end

        AddPrefabPostInit("minotaur_organ", function(inst)
            if not TheWorld.ismastersim then return end
            local periodtask = nil
            local count_task = 0
            if inst.pendingtasks then
                -- TheNet:SystemMessage(tostring(GetTableSize(inst.pendingtasks)))
                for a,b in pairs(inst.pendingtasks) do
                    -- TheNet:SystemMessage(debug.getinfo(a.fn, "S").source or "nil")
                    -- 路径对、间隔对
                    if UMGuard.Known(a.fn, "legacy_organ_shield") and a.period == 1 then
                        periodtask = a
                        count_task = count_task + 1
                    end
                end
            end
            if periodtask ~= nil and count_task == 1 then
                periodtask:Cancel() -- 取消原有task
                inst.task2hm = inst:DoTaskInTime(1, ActivateShield)
            end
            inst:DoTaskInTime(60, function(inst) -- 60秒
                local m = inst.minotaur or TheSim:FindFirstEntityWithTag("minotaur")
                if m and m:HasTag("swc2hm") and m.swp2hm and m.swp2hm:IsValid() then
                    m = m.swp2hm
                end
                if m and m:IsValid() and inst:IsValid() and inst.Transform then inst.Transform:SetPosition(m.Transform:GetWorldPosition()) end
            end)
        end)
        -- 2025.10.13 melon:去掉犀牛影子的"minotaur"tag,这样心就不会保护影子了
        -- AddPrefabPostInit("minotaur", function(inst)
        --     inst:AddTag("minotaur2hm") -- 用于防止犀牛与影子互相索敌
        --     if not TheWorld.ismastersim then return end
        --     inst:DoTaskInTime(0.3, function(inst)
        --         if inst:HasTag("swc2hm") then inst:RemoveTag("minotaur") end
        --     end)
        -- end)
        -- 2025.10.15 melon:让暗影触手和荆棘不打犀牛
        -- AddPrefabPostInit("bigshadowtentacle", function(inst)
        --     if not TheWorld.ismastersim then return end
        --     if inst.components.combat then inst.components.combat:AddNoAggroTag("minotaur") end
        -- end)
    end

    -- 等鼠潮组件挂载后，再按妥协的实际配置设置播报。
    AddSimPostInit(function()
        if not TheWorld.ismastersim then return end
        local beta = ModManager:GetMod("workshop-3193922031")
        local um = beta or ModManager:GetMod("workshop-2039181790")
        if not um then return end

        local announce = um.GetModConfigData("rat_raids") == true and TheWorld.components.ratcheck ~= nil
        TUNING.DSTU.ANNOUNCE_BASESTATUS = announce
        if beta and UM_CONFIG then UM_CONFIG.ANNOUNCE_BASESTATUS = announce end
    end)
    if TUNING.DSTU.MAXTEMPDAMAGE then modimport("easy_other/um_temperature_penalty.lua") end
end -- if TUNING.DSTU
----------------------------------------------------------------------------------------------------
-- 测试用  金斧子攻击生成老鼠分检查点
-- if TUNING.DSTU then
--     AddPrefabPostInit("goldenaxe", function(inst) -- 金斧子
--         if not TheWorld.ismastersim then return end
--         local _onattack = inst.components.weapon.onattack
--         inst.components.weapon.onattack = function(inst, ...) -- 生成1个对象方便测试
--             SpawnPrefab("uncompromising_ratsniffer").Transform:SetPosition(inst.Transform:GetWorldPosition())
--             if _onattack ~= nil then _onattack(inst, ...) end
--         end
--     end)
-- end
