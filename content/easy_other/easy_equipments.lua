----------------------------[装备(可装备的)]------------------------------------
-------------------------------------------------------------------------------
local hardmode = TUNING.hardmode2hm
local InfusionView = require("weaponinfusionview2hm")
local RPCGuard = require("rpcguard2hm")
AddClassPostConstruct("widgets/itemtile", InfusionView.AttachTile)

-- 启迪之冠养老，保暖隔热防水绝缘冷源热源
local alterhat = GetModConfigData("Enlightened Crown Benefit From Spore")
if alterhat then
    local disablelight = alterhat == -1
    local function alterguardianhat_IsRed(inst) return inst.prefab == MUSHTREE_SPORE_RED end
    local function alterguardianhat_IsGreen(inst) return inst.prefab == MUSHTREE_SPORE_GREEN end
    local function alterguardianhat_IsBlue(inst) return inst.prefab == MUSHTREE_SPORE_BLUE end
    local function alterguardianhat_IsSeed(inst) return inst.prefab == "lunar_seed" end
    local function ondropped(inst)
        local owner = inst.externallyinsulatedowner2hm
        if owner and owner.components.inventory then
            owner.components.inventory.isexternallyinsulated:RemoveModifier(inst, "alterguardianhat")
            inst.externallyinsulatedowner2hm = nil
        end
    end
    local function onputininventory(inst)
        ondropped(inst)
        if inst.components.equippable.insulated then
            local owner = inst.components.inventoryitem:GetGrandOwner()
            if owner and owner.components.inventory then
                inst.externallyinsulatedowner2hm = owner
                owner.components.inventory.isexternallyinsulated:SetModifier(inst, true, "alterguardianhat")
            end
        end
    end
    local function activedisablelight(inst) if inst._light and inst._light:IsValid() then inst._light.Light:SetColour(180 / 255, 195 / 255, 150 / 255) end end
    local function alterguardianhat_update(inst)
        local r = #inst.components.container:FindItems(alterguardianhat_IsRed)
        local g = #inst.components.container:FindItems(alterguardianhat_IsGreen)
        local b = #inst.components.container:FindItems(alterguardianhat_IsBlue)
        local seed = #inst.components.container:FindItems(alterguardianhat_IsSeed) -- 天体宝珠
        -- 2025.6.23 兼容天体宝珠; 按玩家温度判断: >50隔热, <20保暖, 20~50不偏向
        g = g + seed
        local magiowner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
        local pt = magiowner and magiowner.components.temperature and magiowner.components.temperature:GetCurrent()
        if pt and pt > 50 then -- 玩家温度>50 加 blue(隔热)
            b = b + seed
        elseif pt and pt < 20 then -- 玩家温度<20 加 red(保暖)
            r = r + seed
        end
        -- 塞满判定
        local numslots = inst.components.container:GetNumSlots()
        local maxed = seed == numslots
        local function synclightradius2hm()
            if inst._light and inst._light:IsValid() then
                inst._light.Light:SetRadius(maxed and 8 or 4)
            elseif maxed and inst.components.equippable and inst.components.equippable:IsEquipped() then
                inst:DoTaskInTime(0, synclightradius2hm)
            end
        end
        synclightradius2hm()
        -- 塞满天体宝珠(lunar_seed)才给95%减伤(不可摧毁护甲), 否则0减伤
        if maxed then
            inst.components.armor:InitIndestructible(0.95)
        else
            inst.components.armor:SetAbsorption(0)
        end
        --------
        inst.components.waterproofer:SetEffectiveness(g * 0.2)
        if g >= 5 then
            inst.components.equippable.insulated = true
            onputininventory(inst)
        else
            ondropped(inst)
            inst.components.equippable.insulated = false
        end
        if r >= b then
            inst.components.insulator:SetWinter()
            inst.components.insulator:SetInsulation(r * 60 - b * 60)
        else
            inst.components.insulator:SetSummer()
            inst.components.insulator:SetInsulation(b * 60 - r * 60)
        end
        -- 热源/冷源: 有宝珠按玩家温度滞回温控(<20热源至35停, >50冷源至35停); 无宝珠按孢子计数(原版)
        if seed > 0 then
            local thermo = inst._alterhat_thermo2hm
            if thermo == "heat" then
                if (not pt) or pt >= 35 then thermo = nil end
            elseif thermo == "cool" then
                if (not pt) or pt <= 35 then thermo = nil end
            else
                if pt and pt < 20 then
                    thermo = "heat"
                elseif pt and pt > 50 then
                    thermo = "cool"
                end
            end
            inst._alterhat_thermo2hm = thermo
            if thermo == "heat" then
                inst:AddTag("HASHEATER")
                inst.components.heater:SetThermics(true, false)
                inst.components.heater.heat = 70
                inst.components.heater.equippedheat = 70
                inst.components.heater.carriedheat = 70
                inst.components.heater.carriedheatmultiplier = 2
            elseif thermo == "cool" then
                inst:AddTag("HASHEATER")
                inst.components.heater:SetThermics(false, true)
                inst.components.heater.heat = -5
                inst.components.heater.equippedheat = -5
                inst.components.heater.carriedheat = -5
                inst.components.heater.carriedheatmultiplier = 2
            else
                inst:RemoveTag("HASHEATER")
                inst.components.heater:SetThermics(false, false)
                inst.components.heater.heat = nil
                inst.components.heater.equippedheat = nil
                inst.components.heater.carriedheat = nil
                inst.components.heater.carriedheatmultiplier = 1
            end
        else
            inst._alterhat_thermo2hm = nil
            if r >= 5 or b >= 5 then
                inst:AddTag("HASHEATER")
                if r > b then
                    inst.components.heater:SetThermics(true, false)
                    inst.components.heater.heat = 70
                    inst.components.heater.equippedheat = 70
                    inst.components.heater.carriedheat = 70
                    inst.components.heater.carriedheatmultiplier = 2
                else
                    inst.components.heater:SetThermics(false, true)
                    inst.components.heater.heat = -5
                    inst.components.heater.equippedheat = -5
                    inst.components.heater.carriedheat = -5
                    inst.components.heater.carriedheatmultiplier = 2
                end
            else
                inst:RemoveTag("HASHEATER")
                inst.components.heater:SetThermics(false, false)
                inst.components.heater.heat = nil
                inst.components.heater.equippedheat = nil
                inst.components.heater.carriedheat = nil
                inst.components.heater.carriedheatmultiplier = 1
            end
        end
        if disablelight then activedisablelight(inst) end
    end
    AddPrefabPostInit("alterguardianhat", function(inst)
        inst:AddTag("waterproofer")
        inst:AddTag("goggles")
        inst:AddTag("moonstormgoggles")
        inst:AddTag("hide_percentage") -- 无限耐久,隐藏耐久显示
        if not TheWorld.ismastersim then return end
        if not inst.components.waterproofer then inst:AddComponent("waterproofer") end
        inst.components.waterproofer:SetEffectiveness(0)
        if not inst.components.insulator then inst:AddComponent("insulator") end
        inst.components.insulator:SetInsulation(0)
        if not inst.components.heater then inst:AddComponent("heater") end
        inst.components.heater:SetThermics(false, false)
        -- 启迪之冠塞满天体宝珠(lunar_seed)装备在头上才提供95%减伤, 否则0减伤
        if not inst.components.armor then inst:AddComponent("armor") end
        inst.components.armor:InitIndestructible(0)
        alterguardianhat_update(inst)
        inst:ListenForEvent("onputininventory", onputininventory)
        inst:ListenForEvent("ondropped", ondropped)
        if disablelight then
            inst:ListenForEvent("equipped", activedisablelight)
            inst:ListenForEvent("onopen", activedisablelight)
            inst:ListenForEvent("onclose", activedisablelight)
        end
        inst:ListenForEvent("itemget", alterguardianhat_update)
        inst:ListenForEvent("itemlose", alterguardianhat_update)
        -- inst:ListenForEvent("cycleschanged", alterguardianhat_update) -- 这样不知道为什么不起作用
        inst:ListenForEvent("equipped", alterguardianhat_update) -- 2025.6.23 melon:穿上时切换保暖/隔热
        -- 装备时每秒刷新温度逻辑(宝珠按玩家温度动态判定热源/冷源/保暖隔热)
        inst:DoPeriodicTask(1, function(inst)
            if inst.components.equippable and inst.components.equippable:IsEquipped() then
                alterguardianhat_update(inst)
            end
        end)
        if inst.components.preserver then inst.components.preserver:SetPerishRateMultiplier(TUNING.FISH_BOX_PRESERVER_RATE) end
    end)
    local function onperish(inst)
        if inst:HasTag("fresh") then
            if inst.components.insulator then
                inst.components.insulator:SetInsulation(240)
            elseif inst.components.waterproofer then
                inst.components.waterproofer:SetEffectiveness(1)
            end
        elseif inst:HasTag("stale") then
            if inst.components.insulator then
                inst.components.insulator:SetInsulation(120)
            elseif inst.components.waterproofer then
                inst.components.waterproofer:SetEffectiveness(0.75)
            end
        elseif inst:HasTag("spoiled") then
            if inst.components.insulator then
                inst.components.insulator:SetInsulation(60)
            elseif inst.components.waterproofer then
                inst.components.waterproofer:SetEffectiveness(0.5)
            end
        end
    end
    AddPrefabPostInit("red_mushroomhat", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.insulator then inst:AddComponent("insulator") end
        inst.components.insulator:SetWinter()
        inst.components.insulator:SetInsulation(240)
        inst:ListenForEvent("forceperishchange", onperish)
    end)
    AddPrefabPostInit("green_mushroomhat", function(inst)
        inst:AddTag("waterproofer")
        if not TheWorld.ismastersim then return end
        if not inst.components.waterproofer then inst:AddComponent("waterproofer") end
        inst.components.waterproofer:SetEffectiveness(1)
        inst:ListenForEvent("forceperishchange", onperish)
    end)
    AddPrefabPostInit("blue_mushroomhat", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.insulator then inst:AddComponent("insulator") end
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(240)
        inst:ListenForEvent("forceperishchange", onperish)
    end)
    AddPrefabPostInit("minerhat", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.resistance then
            inst:AddComponent("resistance")
            inst.components.resistance:AddResistance("quakedebris")
            inst.components.resistance:AddResistance("lunarhaildebris")
        end
    end)
    AddPrefabPostInit("beargervest", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.insulator then inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE * 2) end
        if TUNING.DSTU and inst.components.fueled then inst.components.fueled:SetSectionCallback(nil) end
    end)
    AddPrefabPostInit("icehat", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.insulator then inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE * 2) end
    end)
end

-- 多用斧镐万能
if GetModConfigData("Multi Tool Is Almighty Tool") then
    local function NewTerraform(self, pt, doer, ...)
        self.inst.RefreshSpecialAbility2hm(self.inst)
        return self.oldAction2hm(self, pt, doer, ...)
    end
    local TILLSOIL_IGNORE_TAGS = {"NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "WALKABLEPLATFORM", "soil"}
    local function NewTill(self, pt, doer, ...)
        if self.inst.oldtill2hm then return self.oldAction2hm(self, pt, doer, ...) end
        if not self.oldAction2hm(self, pt, doer, ...) then return false end
        local inst = self.inst
        local x, y, z = pt:Get()
        if not TheWorld.Map:GetTileAtPoint(x, 0, z) == WORLD_TILES.FARMING_SOIL then return false end
        local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(x, y, z)
        -- 获取地皮中心坐标点
        local spacing = 1.3
        -- 土堆间距
        local farm_plant_pos = {}
        -- 农场作物坐标
        local totaluse = 0
        -- 清除这块地皮上多余的土堆
        local ents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
        for _, ent in ipairs(ents) do
            if ent ~= doer and ent:HasTag("soil") then -- 是土堆，则清除
                if not ent:HasTag("NOCLICK") then totaluse = totaluse - 4 end
                ent:PushEvent("collapsesoil")
            end
        end
        -- 生成整齐的土堆
        for i = -1, 1 do
            for j = -1, 1 do
                local nx = cx + spacing * i
                local nz = cz + spacing * j
                local rot = doer and doer.Transform:GetRotation()
                if rot then
                    if rot <= -90 then
                        nx = cx + spacing * j
                        nz = cz - spacing * i
                    elseif rot <= 0 then
                        nx = cx - spacing * i
                        nz = cz - spacing * j
                    elseif rot >= 0 then
                        nx = cx - spacing * j
                        nz = cz + spacing * i
                    end
                end
                -- 生成的预置物名,默认为土堆
                local spawnItem = "farm_soil"
                if TheWorld.Map:IsDeployPointClear(Vector3(nx, 0, nz), nil, GetFarmTillSpacing(), nil, nil, nil, TILLSOIL_IGNORE_TAGS) then
                    local plant = SpawnPrefab(spawnItem)
                    plant.Transform:SetPosition(nx, 0, nz)
                    totaluse = totaluse + 4
                end
            end
        end
        inst.components.finiteuses:Use(totaluse)
        return true
    end
    local function RemoveSpecialAbility(inst)
        if inst.specialtask2m then
            inst.specialtask2m:Cancel()
            inst.specialtask2m = nil
        end
        local owner = inst.components.inventoryitem:GetGrandOwner()
        if owner and owner.sg and owner.sg:HasStateTag("busy") then
            inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
            return
        end
        -- 干草叉,耕地机
        inst:RemoveInherentAction(ACTIONS.TERRAFORM)
        inst:RemoveComponent("terraformer")
    end
    local function RefreshSpecialAbility(inst)
        if inst.specialtask2m then
            inst.specialtask2m:Cancel()
            inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
        end
    end
    local function AddSpecialAbility(inst)
        if inst.specialtask2m then
            inst.specialtask2m:Cancel()
            inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
            return
        end
        inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
        -- 干草叉,耕地机
        inst:AddInherentAction(ACTIONS.TERRAFORM)
        inst:AddComponent("terraformer")
        inst.components.terraformer.oldAction2hm = inst.components.terraformer.Terraform
        inst.components.terraformer.Terraform = NewTerraform
    end
    ACTIONS.SHAVE.priority = math.max((ACTIONS.ROW.priority or 0) + 1, ACTIONS.SHAVE.priority or 0)
    AddComponentAction("EQUIPPED", "shaver2hm", function(inst, doer, target, actions, right)
        if right then
            if target:HasTag("bearded") and 
                not (target:HasTag("beefalo") and (not target:HasTag("brushable") or target:HasTag("saddled"))) and
                (not target:HasTag("spiderden") or doer:HasTag("spiderwhisperer")) and
                not (target ~= doer and doer.replica.rider ~= nil and doer.replica.rider:IsRiding()) then table.insert(actions, ACTIONS.SHAVE) end
        end
    end)
    local oldSHAVEfn = ACTIONS.SHAVE.fn
    ACTIONS.SHAVE.fn = function(act)
        local specialprocess = false
        if act.invobject and act.invobject.components.shaver2hm and not act.invobject.components.shaver then
            specialprocess = true
            act.invobject:AddComponent("shaver")
        end
        local result = oldSHAVEfn(act)
        if specialprocess then act.invobject:RemoveComponent("shaver") end
        return result
    end
    AddStategraphPostInit("wilson", function(sg)
        local oldOnEnter = sg.states.shave.onenter
        sg.states.shave.onenter = function(inst)
            local specialprocess = false
            local invobject = nil
            if inst.bufferedaction and inst.bufferedaction.invobject and inst.bufferedaction.invobject.components.shaver2hm and
                not inst.bufferedaction.invobject.components.shaver then
                specialprocess = true
                invobject = inst.bufferedaction.invobject
                invobject:AddComponent("shaver")
            end
            oldOnEnter(inst)
            if specialprocess then invobject:RemoveComponent("shaver") end
        end
    end)
    -- 排队论支持批量
    local function clientDetect(target)
        return target:HasTag("bearded") and not (target:HasTag("beefalo") and not target:HasTag("brushable")) and
                   (not target:HasTag("spiderden") or ThePlayer:HasTag("spiderwhisperer")) and not target:HasTag("player") and
                   not (ThePlayer.replica.rider ~= nil and ThePlayer.replica.rider:IsRiding())
    end
    AddComponentPostInit("actionqueuer", function(self) if self.AddAction then self.AddAction("rightclick", "SHAVE", clientDetect) end end)
    local function modifyuseconsumption(uses, action, doer, target)
        if (action == ACTIONS.ROW or action == ACTIONS.ROW_FAIL or action == ACTIONS.ROW_CONTROLLER) and doer:HasTag("master_crewman") then
            uses = uses / 2
        end
        return uses
    end
    AddPrefabPostInit("multitool_axe_pickaxe", function(inst)
        inst:AddTag("allow_action_on_impassable")
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("ondropped", AddSpecialAbility)
        -- inst:ListenForEvent("onremove", inst.RemoveSpecialAbility2hm)
        inst.AddSpecialAbility2hm = AddSpecialAbility
        inst.RefreshSpecialAbility2hm = RefreshSpecialAbility
        inst.RemoveSpecialAbility2hm = RemoveSpecialAbility
        -- 干草叉,掉地上才有
        inst.components.finiteuses:SetConsumption(ACTIONS.TERRAFORM, 0.5)
        -- 剃须刀
        -- inst:AddComponent("shaver")
        -- inst:AddComponent("shaver2hm") -- 2025.10.4 melon:去除
        -- 铲子
        inst.components.tool:SetAction(ACTIONS.DIG, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
        inst:AddInherentAction(ACTIONS.DIG)
        inst.components.finiteuses:SetConsumption(ACTIONS.DIG, 4)
        -- 锤子
        inst.components.tool:SetAction(ACTIONS.HAMMER, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
        inst.components.finiteuses:SetConsumption(ACTIONS.HAMMER, 1.334)
        -- 园艺锄,耕地机
        inst:AddInherentAction(ACTIONS.TILL)
        inst:AddComponent("farmtiller")
        inst.components.farmtiller.oldAction2hm = inst.components.farmtiller.Till
        inst.components.farmtiller.Till = NewTill
        inst.components.finiteuses:SetConsumption(ACTIONS.TILL, 4)
        -- 桨
        inst:AddComponent("oar")
        inst.components.oar.force = TUNING.BOAT.OARS.MONKEY.FORCE
        inst.components.oar.max_velocity = TUNING.BOAT.OARS.MONKEY.MAX_VELOCITY
        inst.components.finiteuses:SetConsumption(ACTIONS.ROW, 0.2)
        inst.components.finiteuses:SetConsumption(ACTIONS.ROW_CONTROLLER, 0.2)
        inst.components.finiteuses:SetConsumption(ACTIONS.ROW_FAIL, TUNING.BOAT.OARS.MONKEY.ROW_FAIL_WEAR * 0.2)
        inst.components.finiteuses.modifyuseconsumption = modifyuseconsumption
        -- 钓鱼
        inst:AddComponent("fishingrod")
        inst.components.fishingrod:SetWaitTimes(2, 20) -- 等鱼事件 钓竿(4, 40)
        inst.components.fishingrod:SetStrainTimes(0, 5)
        -- 劈砍动作
        if ACTIONS.HACK and TOOLACTIONS[ACTIONS.HACK.id] then inst.components.tool:SetAction(ACTIONS.HACK) end
    end)
    AddComponentPostInit("playercontroller", function(self)
        if self.automation_tasks and self.automation_tasks.paddle and self.automation_tasks.paddle.IsValidOar then
            local oldIsValidOar = self.automation_tasks.paddle.IsValidOar
            self.automation_tasks.paddle.IsValidOar = function(ent, ...)
                return ent ~= nil and (oldIsValidOar(ent, ...) or ent.prefab == "multitool_axe_pickaxe")
            end
        end
    end)
    AddRecipePostInit("multitool_axe_pickaxe",
                      function(inst) inst.ingredients = {Ingredient("goldenpickaxe", 1), Ingredient("hammer", 1), Ingredient("thulecite", 2)} end)
end

-- 刮地皮头盔自动种树;放草叉自动刮地皮
if GetModConfigData("Turf-Raiser Helm Plant Tree Cone") then
    local containers = require("containers")
    if containers and containers.params and containers.params.antlionhat then
        local olditemtestfn = containers.params.antlionhat.itemtestfn
        local newitemtestfn = function(container, item, slot)
            return
                item:HasTag("deployable") or item:HasTag("tool") or item:HasTag("sharp") or item.prefab == "townportaltalisman" or item:HasTag("fertilizer") or
                    item.prefab == "cane" or item.prefab == "orangestaff" or item:HasTag("wateringcan") or item:HasTag("dryable") or
                    item.prefab == "trap" or item.prefab == "birdtrap" or item.prefab == "messagebottleempty" -- 20260215 YeFeng 支持陷阱和空瓶子放入刮地皮头盔
        end
        containers.params.antlionhat.itemtestfn = function(container, item, slot, ...)
            return (olditemtestfn == nil or olditemtestfn(container, item, slot, ...)) or newitemtestfn(container, item, slot)
        end
    end
    local function trywatersource(self, item, owner, ents, px, py, pz)
        for _, ent in ipairs(ents) do
            if ent and ent:IsValid() and ent ~= owner and ent:HasTag("watersource") and item and item:IsValid() and item.components.fillable:Fill(ent) then
                self.totalwork2hm = (self.totalwork2hm or 0) + 0.25
                return ent
            end
        end
    end
    TUNING.ANTLIONHAT_REPAIR2hm = 20
    -- 沿用原生 PerformBufferedAction 在 Do() 期间保留 bufferedaction 的约定，
    -- 让工作回调可通过 GetBufferedAction().invobject 读取实际工具。
    -- 不走 PushBufferedAction/PerformBufferedAction，避免取消玩家动作或触发转身、状态机。
    local function doitemaction(act)
        local owner = act.doer
        local previous = owner.bufferedaction
        -- 已有批量耕地工具共用此标记；头盔逐点耕地时只执行原生单点处理。
        local item = act.invobject
        local tiller = act.action == ACTIONS.TILL and item and item.components.farmtiller
        local singletill = tiller and tiller.oldAction2hm ~= nil
        local oldtill = singletill and item.oldtill2hm
        if singletill then item.oldtill2hm = true end
        owner.bufferedaction = act
        local ok, success, reason = pcall(act.Do, act)
        if owner.bufferedaction == act then owner.bufferedaction = previous end
        if singletill then item.oldtill2hm = oldtill end
        if not ok then error(success, 0) end
        return success, reason
    end
    local actions_antlionhat = {ACTIONS.NET, ACTIONS.CHOP, ACTIONS.DIG, ACTIONS.MINE, ACTIONS.HAMMER}
    local actions2_antlionhat = {ACTIONS.NET, ACTIONS.CHOP, ACTIONS.DIG, ACTIONS.MINE}
    local function canitemdospecactions(item)
        if item and item:IsValid() and item.components.tool then
            for _, action in ipairs(actions_antlionhat) do if item.components.tool:CanDoAction(action) then return true end end
        end
    end
    local function canuseitemwork(item, owner, isusefullequip)
        return item and item:IsValid() and (isusefullequip or (item.components.equippable and item.components.equippable.equipslot == EQUIPSLOTS.HANDS and
                   (item.components.equippable.restrictedtag == nil or owner:HasTag(item.components.equippable.restrictedtag)) and
                   (not item:HasTag("vetcurse_item") or owner:HasTag("vetcurse")))) and
                   ((item.inherentactions and (item.inherentactions[ACTIONS.TERRAFORM] or item.inherentactions[ACTIONS.TILL])) or
                       (item.components.tool and canitemdospecactions(item)) or (item.components.wateryprotection and item.components.fillable))
    end
    local enablemultitool = GetModConfigData("Multi Tool Is Almighty Tool")
    local function useitemtowork(self, ents, tileents, owner, item, px, py, pz, cx, cy, cz, x, y, ...)
        -- -- 角色被打断时不再工作
        -- if owner.sg and owner.sg.currentstate and owner.sg.currentstate.name == "mine_recoil" then
        --     self.continuework2hm = true
        --     return true
        -- end
        -- self.continuework2hm = true则本次工作完成后一定延迟后进行下次工作
        -- return true则本次不继续工作
        if enablemultitool and item and item:IsValid() and item.prefab == "multitool_axe_pickaxe" and item.components.finiteuses and
            item.components.finiteuses.current <= 20 then return true end
        -- 清理陷坑
        if item and item:IsValid() and (item.inherentactions and item.inherentactions[ACTIONS.TERRAFORM]) or
            (enablemultitool and item.prefab == "multitool_axe_pickaxe") then
            for _, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent ~= owner and item and item:IsValid() and ent.prefab == "antlion_sinkhole" and ent.persists and
                    ent.components.timer and item.components.finiteuses then
                    ent.remainingrepairs = ent.remainingrepairs or 1
                    local use = (ent.components.timer:GetTimeLeft("nextrepair") or 100) / TUNING.AUTOSAVE_INTERVAL * 4 *
                                    (item.components.finiteuses.consumption[ACTIONS.TERRAFORM] or .125)
                    if enablemultitool and item.prefab == "multitool_axe_pickaxe" and item.components.finiteuses.current <= use then return end
                    item.components.finiteuses:Use(use)
                    self:FinishTerraforming(px, py, pz)
                    ent.components.timer:StopTimer("nextrepair")
                    ent:PushEvent("timerdone", {name = "nextrepair"})
                    self.totalwork2hm = (self.totalwork2hm or 0) + 10
                    self.continuework2hm = true
                    return true
                elseif ent and ent:IsValid() and ent ~= owner and item and item:IsValid() and ent.prefab == "eyeofterror_sinkhole" and ent.persists and
                    ent.components.timer and item.components.finiteuses then
                    local use = (ent.components.timer:GetTimeLeft("repair") or 100) / TUNING.AUTOSAVE_INTERVAL * 4 *
                                    (item.components.finiteuses.consumption[ACTIONS.TERRAFORM] or .125)
                    if enablemultitool and item.prefab == "multitool_axe_pickaxe" and item.components.finiteuses.current <= use then return end
                    item.components.finiteuses:Use(use)
                    self:FinishTerraforming(px, py, pz)
                    ent.components.timer:StopTimer("repair")
                    ent:PushEvent("timerdone", {name = "repair"})
                    self.totalwork2hm = (self.totalwork2hm or 0) + 10
                    self.continuework2hm = true
                    return true
                end
            end
        end
        -- 捕虫,砍树,挖掘,挖矿,锤建筑
        local actions = self.handsitem2hm and actions2_antlionhat or actions_antlionhat
        for _, action in ipairs(actions) do
            if item and item:IsValid() and item.components.tool and item.components.tool:CanDoAction(action) then
                for _, ent in ipairs(ents) do
                    if ent and ent:IsValid() and ent ~= owner and item and item:IsValid() and (action == ACTIONS.MINE and ent.components.lunarhailbuildup or (ent:HasTag(action.id .. "_workable") and ent.components.workable and
                        ent.components.workable.action == action)) and not ent:HasTag("swc2hm") and not ent.rangeweapondata2hm then
                        for index = 1, 10 do
                            if ent and ent:IsValid() and item and item:IsValid() and not ent:HasTag("INLIMBO") and ent.components.workable and
                                ent.components.workable.action == action and ent.components.workable.workable then
                                local left = ent.components.workable.workleft
                                if doitemaction(BufferedAction(owner, ent, action, item)) then
                                    self.totalwork2hm = (self.totalwork2hm or 0) + 1
                                    if self.totalwork2hm and self.totalwork2hm >= 10 then
                                        self:FinishTerraforming(px, py, pz)
                                        self.continuework2hm = true
                                        return true
                                    end
                                    if ent:IsValid() and ent.components.workable and ent.components.workable.workleft == left then
                                        break
                                    end
                                else
                                    break
                                end
                            elseif ent and ent:IsValid() and item and item:IsValid() and not ent:HasTag("INLIMBO") and action == ACTIONS.MINE and 
                            ent.components.lunarhailbuildup and ent.components.lunarhailbuildup:IsBuildupWorkable() then
                                local _action = ACTIONS.REMOVELUNARBUILDUP
                                local left = ent.components.lunarhailbuildup.workleft
                                if doitemaction(BufferedAction(owner, ent, _action, item)) then
                                    self.totalwork2hm = (self.totalwork2hm or 0) + 1
                                    if self.totalwork2hm and self.totalwork2hm >= 10 then
                                        self:FinishTerraforming(px, py, pz)
                                        self.continuework2hm = true
                                        return true
                                    end
                                    if ent:IsValid() and ent.components.lunarhailbuildup and ent.components.lunarhailbuildup.workleft == left then
                                        break
                                    end
                                else
                                    break
                                end
                            else
                                break
                            end
                        end
                    end
                end
                if self.totalwork2hm and self.totalwork2hm > 0 then
                    self:FinishTerraforming(px, py, pz)
                    self.continuework2hm = true
                    return true
                end
            end
        end
        -- 干草叉刮地皮
        if item and item:IsValid() and item.inherentactions and item.inherentactions[ACTIONS.TERRAFORM] then
            if doitemaction(BufferedAction(owner, nil, ACTIONS.TERRAFORM, item, Vector3(cx, cy, cz))) then
                self.totalwork2hm = (self.totalwork2hm or 0) + 1
                self:FinishTerraforming(px, py, pz)
                return true
            end
        end
        -- 园艺锄挖坑
        if item and item:IsValid() and item.inherentactions and item.inherentactions[ACTIONS.TILL] and TheWorld.Map:GetTileAtPoint(cx, 0, cz) ==
            WORLD_TILES.FARMING_SOIL then
            local farm_plants = 0
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and ent ~= owner and ((ent:HasTag("soil") and not ent:HasTag("NOCLICK")) or ent:HasTag("farm_plant")) then
                    farm_plants = farm_plants + 1
                end
            end
            -- 地面上还有可能有物品导致挖坑不够
            if farm_plants < 9 then
                local farm_soils = 0
                for _, ent in ipairs(tileents) do
                    if ent and ent:IsValid() and ent ~= owner and ent:HasTag("soil") then
                        if not ent:HasTag("NOCLICK") then farm_soils = farm_soils + 1 end
                        ent:PushEvent("collapsesoil")
                    end
                end
                local spacing = 1.3
                local index = 1
                for i = -1, 1 do
                    for j = -1, 1 do
                        local nx = cx - spacing * i
                        local nz = cz - spacing * j
                        local rot = owner.Transform:GetRotation()
                        if rot then
                            if rot <= -90 then
                                nx = cx - spacing * j
                                nz = cz + spacing * i
                            elseif rot <= 0 then
                                nx = cx + spacing * i
                                nz = cz + spacing * j
                            elseif rot >= 0 then
                                nx = cx + spacing * j
                                nz = cz - spacing * i
                            end
                        end
                        if index <= farm_soils then
                            if TheWorld.Map:CanTillSoilAtPoint(nx, 0, nz, false) then
                                index = index + 1
                                TheWorld.Map:CollapseSoilAtPoint(nx, 0, nz)
                                SpawnPrefab("farm_soil").Transform:SetPosition(nx, 0, nz)
                            end
                        elseif item and item:IsValid() and doitemaction(BufferedAction(owner, nil, ACTIONS.TILL, item, Vector3(nx, 0, nz))) then
                            self.totalwork2hm = (self.totalwork2hm or 0) + 1
                        end
                    end
                end
            end
            if self.totalwork2hm and self.totalwork2hm > 0 then self:FinishTerraforming(px, py, pz) end
            return true
        end
        -- 水壶浇水
        if item and item:IsValid() and item:HasTag("wateringcan") and item.components.wateryprotection and item.components.fillable and
            item.components.finiteuses then
            local firsttrywatersource = item.components.finiteuses:GetPercent() <= 0
            local watersource = firsttrywatersource and trywatersource(self, item, owner, ents, px, py, pz) or nil
            if not firsttrywatersource or watersource then
                item.components.wateryprotection:SpreadProtectionAtPoint(px, 0, pz, 4)
                SpawnPrefab("ocean_splash_med2").Transform:SetPosition(px, 0, pz)
                self.totalwork2hm = (self.totalwork2hm or 0) + 0.25
                if firsttrywatersource then
                    if watersource and watersource:IsValid() and watersource:HasTag("watersource") and item and item:IsValid() then
                        item.components.fillable:Fill(watersource)
                    end
                else
                    watersource = trywatersource(self, item, owner, ents, px, py, pz)
                end
                self:FinishTerraforming(px, py, pz)
                self.continuework2hm = true
                return true
            elseif watersource then
                self:FinishTerraforming(px, py, pz)
                self.continuework2hm = true
                return true
            end
        end
    end
    -- 工作代码
    local function findnearents(px, py, pz, checkPhysicsRadius)
        local ents = TheSim:FindEntities(px, py, pz, checkPhysicsRadius and 8 or 4, nil,
                                         {"NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "walkableplatform", "walkableperipheral"})
        if not checkPhysicsRadius then return ents end
        local tmpents = {}
        for index, ent in ipairs(ents) do
            local range = 4 + ent:GetPhysicsRadius(0)
            if ent:GetDistanceSqToPoint(px, py, pz) < range * range then table.insert(tmpents, ent) end
        end
        return tmpents
    end
    -- 2025.9.6 melon:根据人物朝向给坑排序  table.sort会报nil，需要自己写
    local function sort_til(tils)
        for i=1, #tils do
            for j=1, #tils - 1 do
                local x1,y1,z1 = tils[j].Transform:GetWorldPosition()
                local x2,y2,z2 = tils[j+1].Transform:GetWorldPosition()
                if z1 > z2 then tils[j], tils[j+1] = tils[j+1], tils[j] end
            end
        end
    end
    local function newDoTerraform(self, px, py, pz, x, y, ...)
        -- 只处理蚁狮头盔
        if self.inst.prefab ~= "antlionhat" then return self.oldDoTerraform2hm(self, px, py, pz, x, y, ...) end
        self.totalwork2hm = 0
        -- 没有被装备则不工作
        local owner = self.inst.components.inventoryitem.owner
         if not (owner and owner:HasTag("player") and owner.components.locomotor and owner.components.inventory and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == self.inst) then
            self:StopTerraforming()
            return
        end
        -- 读取手部单位和容器内单位并预备补充容器内材料
        self.inst.itemname2hm = nil
        local item = self.container:GetItemInSlot(1)
        local handsitem = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if not ((item and item:IsValid()) or (handsitem and handsitem:IsValid())) then return end
        local canhandsitem = canuseitemwork(handsitem, owner, true)
        if item == nil and not canhandsitem then return end
        self.inst.itemname2hm = item and item.prefab
        -- 开始工作
        if item and item.prefab == "townportaltalisman" and item.components.stackable and self.inst.components.finiteuses then
            -- 消耗格子内沙之石补充耐久
            local needs = math.floor((self.inst.components.finiteuses.total - self.inst.components.finiteuses.current) / TUNING.ANTLIONHAT_REPAIR2hm)
            local stacksize = item.components.stackable.stacksize
            if needs and needs > 0 and stacksize then
                local uses = math.min(needs, stacksize)
                item.components.stackable:Get(uses):Remove()
                self.inst.components.finiteuses:Repair(uses * TUNING.ANTLIONHAT_REPAIR2hm)
            end
            return
        end
        -- 读取可操作对象
        if item and (item.prefab == "cane" or item.prefab == "orangestaff") then
            -- 重置陷阱,限速1次1个,以防恢复速度太快，必须手杖放格子里，否则会有不必要的性能
            local ents = findnearents(px, py, pz)
            for _, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent ~= owner and ent:HasTag("minesprung") and not ent:HasTag("mine_not_reusable") then
                    if doitemaction(BufferedAction(owner, ent, ACTIONS.RESETMINE)) then
                        self.totalwork2hm = (self.totalwork2hm or 0) + 1
                        self:FinishTerraforming(px, py, pz)
                        return true
                    end
                elseif ent and ent:IsValid() and ent ~= owner and ent.components.deployable and
                    (ent.prefab == "dug_trap_starfish" or (ent.components.mine and ent.components.mine.inactive == true)) then
                    if ent.components.deployable:Deploy(ent:GetPosition(), owner) then
                        self.totalwork2hm = (self.totalwork2hm or 0) + 1
                        self:FinishTerraforming(px, py, pz)
                        return true
                    end
                end
            end
        elseif canhandsitem then
            -- 手部有工具,优先使用手部工具并支持和格子内工具混用，此时不进行后续各类种植部署操作
            self.handsitem2hm = true
            local ents = findnearents(px, py, pz, true)
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and ent ~= owner and not table.contains(ents, ent) then table.insert(ents, ent) end
            end
            self.continuework2hm = nil
            if useitemtowork(self, ents, tileents, owner, handsitem, px, py, pz, cx, cy, cz, x, y, ...) then
                self.inst.itemname2hm = nil
                return self.continuework2hm
            elseif canuseitemwork(item, owner) then
                self.handsitem2hm = false
                if useitemtowork(self, ents, tileents, owner, item, px, py, pz, cx, cy, cz, x, y, ...) then return self.continuework2hm end
            end
        elseif canuseitemwork(item, owner) then
            -- 手部无工具，格子内有工具
            self.handsitem2hm = false
            local ents = findnearents(px, py, pz, true)
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and ent ~= owner and not table.contains(ents, ent) then table.insert(ents, ent) end
            end
            self.continuework2hm = nil
            if useitemtowork(self, ents, tileents, owner, item, px, py, pz, cx, cy, cz, x, y, ...) then return self.continuework2hm end
        elseif item and item:IsValid() and item.tile then
            -- 铺地皮
            self.totalwork2hm = 1
            return self.oldDoTerraform2hm(self, px, py, pz, x, y, ...)
        elseif item and item:IsValid() and item.components.fertilizer then
            -- 给枯萎浆果丛施肥
            local ents = findnearents(px, py, pz)
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and ent ~= owner and not table.contains(ents, ent) then table.insert(ents, ent) end
            end
            for _, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent ~= owner and item and item:IsValid() and not ent:HasTag("player") and item.components.stackable and
                    item.components.stackable.stacksize >= 1 and
                    ((ent:HasTag("notreadyforharvest") and not ent:HasTag("withered")) or ent:HasTag("fertile") or ent:HasTag("infertile") or
                        ent:HasTag("barren") or ent:HasTag("fertilizable")) then
                    if doitemaction(BufferedAction(owner, ent, ACTIONS.FERTILIZE, item)) then
                        self.totalwork2hm = (self.totalwork2hm or 0) + 1
                        self:FinishTerraforming(px, py, pz)
                        return true
                    end
                end
            end
        elseif item and item:IsValid() and item.components.deployable and item.components.deployable:IsDeployable(owner) and
            not item.components.farmplantable then
            -- 浆果丛各类等种植部署
            local spacing = item.components.deployable:DeploySpacingRadius()
            if item.components.deployable.spacing == DEPLOYSPACING.DEFAULT then
                if item._custom_candeploy_fn and item.components.deployable.mode == DEPLOYMODE.CUSTOM then
                    if item:HasTag("deployedfarmplant") then spacing = 1.3 end
                end
            end
            if item.components.deployable.usegridplacer then spacing = 2.1 end
            -- 陷阱范围调整
            if item.components.mine and spacing and spacing < 2 and not (handsitem and (handsitem.prefab == "cane" or handsitem.prefab == "orangestaff")) then
                spacing = 2
            end
            if spacing == nil or spacing == 0 then return end
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local obj = self.container:RemoveItem(item)
            if obj and obj:IsValid() then
                local num = math.floor(2 / spacing)
                for i = -num, num do
                    for j = -num, num do
                        local nx = cx - spacing * i
                        local nz = cz - spacing * j
                        local rot = owner.Transform:GetRotation()
                        if rot then
                            if rot <= -90 then
                                nx = cx - spacing * j
                                nz = cz + spacing * i
                            elseif rot <= 0 then
                                nx = cx + spacing * i
                                nz = cz + spacing * j
                            elseif rot >= 0 then
                                nx = cx + spacing * j
                                nz = cz - spacing * i
                            end
                        end
                        local changeent
                        if obj.prefab == "bullkelp_root" then
                            local ents = findnearents(px, py, pz)
                            for _, ent in ipairs(ents) do
                                if ent and ent.prefab == "bullkelp_plant" and ent:IsValid() and ent:IsOnOcean() then
                                    changeent = ent
                                    ent:AddTag("NOBLOCK")
                                    local _y
                                    nx, _y, nz = ent.Transform:GetWorldPosition()
                                    break
                                end
                            end
                        end
                        if obj.components.deployable:Deploy(Vector3(nx, 0, nz), owner, rot) then
                            self.totalwork2hm = (self.totalwork2hm or 0) + 1
                            self:FinishTerraforming(px, py, pz)
                            return true
                        end
                        if changeent then changeent:RemoveTag("NOBLOCK") end
                    end
                end
                self.container:GiveItem(obj)
            end
        elseif item and item:IsValid() and item.components.farmplantable then
            -- 种子埋坑里
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
            -- 2025.9.10 melon:在RemoveItem前先判断有无空位，没有就不执行RemoveItem----
            local xo = nil
            if not self.inst.plant3_3 then
                -- 判断有无可种位置
                local cantil = false
                xo = owner.Transform:GetWorldPosition() -- 2025.9.2 melon:只取x
                for _, ent in ipairs(tileents) do
                    local xe = ent.Transform:GetWorldPosition() -- 2025.9.2 melon:只取x
                    if ent and ent:IsValid() and ent ~= owner and ent:HasTag("soil") and not ent:HasTag("NOCLICK") and (self.inst.plant3_3 or math.abs(xo - xe) < 0.6) then
                        cantil = true
                        break
                    end
                end
                if not cantil then return true end -- 无可种位置，直接返回，true表示仍然尝试种
                sort_til(tileents) -- 2025.9.6 melon:给坑排序  table.sort会报nil，需要自己写
            end
            -- 原本逻辑--------------------------------------------
            local obj = self.container:RemoveItem(item)
            if obj and obj:IsValid() then
                for _, ent in ipairs(tileents) do
                    local xe = ent.Transform:GetWorldPosition() -- 2025.9.2 melon:只取x
                    if ent and ent:IsValid() and ent ~= owner and ent:HasTag("soil") and not ent:HasTag("NOCLICK") and
                    -- 2025.9.2 melon:判断ent和owner的x距离,小于种子间距(1.2)的一半,plant3_3为false才切换1*3种植
                    (self.inst.plant3_3 or math.abs(xo - xe) < 0.6) and
                    obj.components.farmplantable:Plant(ent, owner) then
                        self.totalwork2hm = (self.totalwork2hm or 0) + 1
                        self:FinishTerraforming(px, py, pz)
                        return true
                    end
                end
                self.container:GiveItem(obj)
            end
        elseif item and item:IsValid() and item.components.dryable then
            -- 晾肉架补充可晒物
            local ents = findnearents(px, py, pz)
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, py, pz)
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and ent ~= owner and not table.contains(ents, ent) then table.insert(ents, ent) end
            end
            for _, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent ~= owner and item and item:IsValid() and not ent:HasTag("player") and item.components.dryable and
                    item.components.stackable.stacksize >= 1 and ent.components.dryingrack and ent.components.container and ent.components.container.canbeopened and not ent.components.container:IsFull() then
                    local obj = self.container:RemoveItem(item)
                    if obj and obj:IsValid() then
                        if ent.components.container:GiveItem(obj) then
                            self.totalwork2hm = (self.totalwork2hm or 0) + 1
                            self:FinishTerraforming(px, py, pz)
                            return true
                        end
                        self.container:GiveItem(obj)
                    end
                end
            end
        end
    end
    -- 计算实际消耗耐久,是原来的十倍;补充用完的道具
    local function newFinishTerraforming(self, x, y, z, ...)
        if self.totalwork2hm and self.totalwork2hm > 0 then
            if self.inst.components.finiteuses then self.inst.components.finiteuses:Use(-(10 - self.totalwork2hm) / 10) end
            self.totalwork2hm = 0
        end
        if self.inst.itemname2hm and self.container:GetItemInSlot(1) == nil then
            local owner = self.inst.components.inventoryitem.owner
            if owner and owner.components.inventory then
                local newitem = owner.components.inventory:FindItem(function(item) return item.prefab == self.inst.itemname2hm end)
                if newitem ~= nil and newitem:IsValid() then
                    local item
                    if newitem.components.stackable and newitem.components.stackable.stacksize >
                        (newitem.components.stackable.originalmaxsize or newitem.components.stackable.maxsize) then
                        item = newitem.components.stackable:Get(newitem.components.stackable.originalmaxsize or newitem.components.stackable.maxsize)
                    else
                        item = newitem.components.inventoryitem:RemoveFromOwner(true)
                    end
                    self.container:GiveItem(item, 1)
                end
            end
            self.inst.itemname2hm = nil
        end
        return self.oldFinishTerraforming2hm(self, x, y, z, ...)
    end
    -- 切换手中道具或格子内道具都会刷新一次工作
    local function newOnUpdate(self, dt, ...)
        self.oldOnUpdate2hm(self, dt, ...)
        local px, py, pz = self.inst.Transform:GetWorldPosition()
        local x, y = TheWorld.Map:GetTileXYAtPoint(px, py, pz)
        if not ((self.last_x == nil and self.last_y == nil) or (self.last_x ~= x or self.last_y ~= y) or
            (self.last_x == x and self.last_y == y and self.repeat_delay == 0)) then
            local owner = self.inst.components.inventoryitem.owner
            local item = self.container:GetItemInSlot(1)
            local handsitem = owner and owner.components.inventory and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if self.last_owner2hm ~= owner or self.last_item2hm ~= item or self.last_handsitem2hm ~= handsitem then
                self.last_owner2hm = owner
                self.last_item2hm = item
                self.last_handsitem2hm = handsitem
                self.repeat_delay = nil
                local repeat_tile = self:DoTerraform(px, py, pz, x, y)
                self.last_x, self.last_y = x, y
                if repeat_tile then self.repeat_delay = self.repeat_tile_delay end
            end
        end
    end
    -- 快速修复耐久
    local function onitemget(inst, data)
        if inst.prefab == "antlionhat" and inst.components.container:GetItemInSlot(1) ~= nil and inst.components.autoterraformer then
            local item = inst.components.container:GetItemInSlot(1)
            if item and item.prefab == "townportaltalisman" and item.components.stackable and inst.components.finiteuses then
                local needs = math.floor((inst.components.finiteuses.total - inst.components.finiteuses.current) / TUNING.ANTLIONHAT_REPAIR2hm)
                local stacksize = item.components.stackable.stacksize
                if needs and needs > 0 and stacksize then
                    local uses = math.min(needs, stacksize)
                    item.components.stackable:Get(uses):Remove()
                    inst.components.finiteuses:Repair(uses * TUNING.ANTLIONHAT_REPAIR2hm)
                    inst.components.autoterraformer.totalwork2hm = 0
                    local px, py, pz = inst.Transform:GetWorldPosition()
                    inst.components.autoterraformer:FinishTerraforming(px, py, pz)
                end
            end
        end
    end
    AddComponentPostInit("autoterraformer", function(self)
        self.totalwork2hm = 0
        self.oldDoTerraform2hm = self.DoTerraform
        self.DoTerraform = newDoTerraform
        self.oldFinishTerraforming2hm = self.FinishTerraforming
        self.FinishTerraforming = newFinishTerraforming
        self.oldOnUpdate2hm = self.OnUpdate
        self.OnUpdate = newOnUpdate
        self.inst:ListenForEvent("itemget", onitemget)
    end)
    -- 2025.9.2 melon:放锄头/金锄头时切换3*3 或 1*3种植
    local function onitemget_antlionhat(inst, data)
        if data and data.item and data.item:IsValid() and (data.item.prefab == "farm_hoe" or data.item.prefab == "golden_farm_hoe") then
            inst.plant3_3 = not inst.plant3_3
            local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or nil
            local desc = inst.plant3_3 and (TUNING.isCh2hm and "3*3种植" or "planting 3*3") or (TUNING.isCh2hm and "1*3种植" or "planting 1*3")
            if owner and owner:HasTag("player") and owner.components.talker then
                owner.components.talker:Say(desc, 2, true) -- 显示2秒
            end
        end
    end
    -- 20260215 YeFeng 刮地皮头盔自动捕捉功能：放入陷阱自动捕捉小动物/鸟类，放入空瓶子自动收集恶液 --
    local AUTOTRAP_RANGE = 2.5 -- 捕捉距离
    local AUTOTRAP_PERIOD = 0.25 -- 扫描周期(秒)
    local AUTOTRAP_CANT_TAGS = {"player", "companion", "yourminion", "swc2hm", "INLIMBO", "FX", "NOCLICK", "notarget", "notraptrigger"}
    -- 根据陷阱类型获取可捕捉目标的标签
    local function gettraptargettags(trapprefab)
        if trapprefab == "trap" then return {"smallcreature"} end
        if trapprefab == "birdtrap" then return {"bird"} end
    end
    -- 判断格子内物品是否为自动捕捉/收集类
    local function isautotrapitem(prefab)
        return prefab == "trap" or prefab == "birdtrap" or prefab == "messagebottleempty"
    end
    -- 尝试自动捕捉附近生物/收集恶液
    local function doautotrap(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if not (owner and owner:IsValid() and owner:HasTag("player") and owner.components.inventory) then return end
        local item = inst.components.container and inst.components.container:GetItemInSlot(1)
        if not (item and item:IsValid() and isautotrapitem(item.prefab)) then
            -- 格子内不是陷阱/空瓶子了,停止任务
            if inst.autotraptask2hm then inst.autotraptask2hm:Cancel() inst.autotraptask2hm = nil end
            return
        end
        -- 检查玩家物品栏是否有空位
        if owner.components.inventory:IsFull() then return end
        local px, py, pz = owner.Transform:GetWorldPosition()
        if item.prefab == "messagebottleempty" then
            -- 空瓶子：自动收集附近恶液(gelblob_small_fx,带canbebottled标签)
            local ents = TheSim:FindEntities(px, py, pz, AUTOTRAP_RANGE, {"canbebottled"}, {"INLIMBO", "FX", "NOCLICK"})
            for _, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent.prefab == "gelblob_small_fx" and item.components.bottler and
                    doitemaction(BufferedAction(owner, ent, ACTIONS.BOTTLE, item)) then
                    -- 消耗头盔耐久
                    if inst.components.finiteuses then inst.components.finiteuses:Use(1) end
                    -- 播放音效
                    if owner.SoundEmitter then owner.SoundEmitter:PlaySound("rifts4/gelblob_storage/store") end
                    -- 自动从物品栏补充空瓶子
                    if not inst:IsValid() then return end
                    local slotitem = inst.components.container:GetItemInSlot(1)
                    if slotitem == nil then
                        local newitem = owner.components.inventory:FindItem(function(v) return v.prefab == "messagebottleempty" end)
                        if newitem and newitem:IsValid() then
                            local obj = newitem.components.inventoryitem:RemoveFromOwner(true)
                            if obj then inst.components.container:GiveItem(obj, 1) end
                        end
                    end
                    return
                end
            end
        else
            -- 陷阱：自动捕捉附近小动物/鸟类
            local musttags = gettraptargettags(item.prefab)
            local trap = item.components.trap
            if not musttags or not trap then return end
            if trap:IsSprung() and trap.lootprefabs == nil then trap:Reset() end
            local ents = trap:IsSprung() and {item} or TheSim:FindEntities(px, py, pz, AUTOTRAP_RANGE, musttags, AUTOTRAP_CANT_TAGS)
            for _, ent in ipairs(ents) do
                if trap:IsSprung() or (ent and ent:IsValid() and ent.components.health and not ent.components.health:IsDead()
                    and not (ent.components.follower and ent.components.follower:GetLeader()) and
                    ((ent.components.inventoryitem and ent.components.inventoryitem.trappable) or
                        (ent.components.lootdropper and ent.components.lootdropper.trappable))) then
                    -- 只省略落地/合拢动画；捕获产物、数据、事件及陷阱耐久仍由原生组件结算。
                    -- 不覆盖陷阱已有的捕获物，也不播放 springtrap 以免延迟动画重复结算。
                    if not trap:IsSprung() then
                        local previous = trap.target
                        trap.target = ent
                        ent:PushEvent("trapped", {trap = item})
                        trap:DoSpring()
                        if not trap:IsSprung() and trap.target == ent then trap.target = previous end
                    end
                    if trap:IsSprung() and trap.lootprefabs ~= nil then
                        local trapprefab = item.prefab
                        trap:Harvest(owner)
                        if item:IsValid() then
                            -- Harvest 会重新 Set；容器里的陷阱不能继续作为地面陷阱扫描。
                            trap:Reset()
                            if item.components.finiteuses and item.components.finiteuses:GetUses() <= 0 then item:Remove() end
                        end
                        -- 破损陷阱由原生 onharvest 消耗，不能再额外扣一次。
                        if not item:IsValid() then
                            local newitem = owner.components.inventory:FindItem(function(v) return v.prefab == trapprefab end)
                            if newitem and newitem:IsValid() then
                                local obj = newitem.components.stackable and newitem.components.stackable:Get(1) or newitem.components.inventoryitem:RemoveFromOwner(true)
                                if obj then inst.components.container:GiveItem(obj, 1) end
                            end
                        end
                        if inst.components.finiteuses then inst.components.finiteuses:Use(1) end
                        if owner.SoundEmitter then owner.SoundEmitter:PlaySound("dontstarve/common/trap_close") end
                        return
                    end
                end
            end
        end
    end
    -- 启动/停止自动捕捉任务
    local function startautotrap(inst)
        if inst.autotraptask2hm then return end -- 已在运行
        local item = inst.components.container and inst.components.container:GetItemInSlot(1)
        if item and item:IsValid() and isautotrapitem(item.prefab) then
            inst.autotraptask2hm = inst:DoPeriodicTask(AUTOTRAP_PERIOD, doautotrap)
        end
    end
    local function stopautotrap(inst)
        if inst.autotraptask2hm then
            inst.autotraptask2hm:Cancel()
            inst.autotraptask2hm = nil
        end
    end
    -- 格子内容变化时判断启停
    local function onautotrapitemchange(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if not (owner and owner:IsValid() and owner.components.inventory and
            owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == inst) then
            stopautotrap(inst)
            return
        end
        local item = inst.components.container and inst.components.container:GetItemInSlot(1)
        if item and item:IsValid() and isautotrapitem(item.prefab) then
            startautotrap(inst)
        else
            stopautotrap(inst)
        end
    end
    -- 20260215 YeFeng 刮地皮头盔自动捕捉功能 结束 -----------------------------

    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") and data.owner.components.carefulwalker then
            data.owner.carefulwalkingspeedmult2hm = data.owner.components.carefulwalker.carefulwalkingspeedmult
            data.owner.components.carefulwalker:SetCarefulWalkingSpeedMultiplier(1)
        end
        -- 20260215 YeFeng 装备时检查是否需要启动自动捕捉
        startautotrap(inst)
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") and data.owner.components.carefulwalker then
            data.owner.components.carefulwalker:SetCarefulWalkingSpeedMultiplier(data.owner.carefulwalkingspeedmult2hm or TUNING.CAREFUL_SPEED_MOD)
        end
        -- 20260215 YeFeng 卸下时停止自动捕捉
        stopautotrap(inst)
    end
    local processhack
    AddPrefabPostInit("antlionhat", function(inst)
        inst:AddTag("goggles")
        inst.repairmaterials2hm = {townportaltalisman = TUNING.ANTLIONHAT_REPAIR2hm}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
        inst:ListenForEvent("itemget", onitemget_antlionhat)-- 2025.9.2 melon:放锄头时切换3*3 或 1*3种植
        inst.onitemget_antlionhat2hm = onitemget_antlionhat
        -- 格子内容变化时判断自动捕捉启停
        inst:ListenForEvent("itemget", onautotrapitemchange)
        inst:ListenForEvent("itemlose", onautotrapitemchange)
        if ACTIONS.HACK and not processhack and TOOLACTIONS[ACTIONS.HACK.id] then
            processhack = true
            table.insert(actions_antlionhat, ACTIONS.HACK)
            table.insert(actions2_antlionhat, ACTIONS.HACK)
        end
    end)
    -- 暗影斧原生工作监听只在装备时注册。过滤未使用的手持斧，
    -- 槽内实际使用的斧则在同一个原生 working 事件中复用它已有的回调。
    AddPrefabPostInit("shadow_battleaxe", function(inst)
        if not TheWorld.ismastersim or not inst._onownerworking then return end
        local onownerworking = inst._onownerworking
        inst._onownerworking = function(owner, data)
            local act = owner:GetBufferedAction()
            if act then
                if act.invobject ~= inst or act.action ~= ACTIONS.CHOP or not data or act.target ~= data.target then return end
            elseif not (data and data.target and data.target.components.workable and
                data.target.components.workable:GetWorkAction() == ACTIONS.CHOP and owner.components.inventory and
                owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst) then
                return
            end
            return onownerworking(owner, data)
        end
    end)
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("working", function(owner, data)
            local act = owner:GetBufferedAction()
            local item = act and act.invobject
            if act and act.action == ACTIONS.CHOP and data and act.target == data.target and item and item:IsValid() and
                item.prefab == "shadow_battleaxe" and item._onownerworking and item.components.equippable and
                not item.components.equippable:IsEquipped() then
                item._onownerworking(owner, data)
            end
        end)
    end)
end

-- 铥矿棒格挡攻击
local ThuleciteMode = GetModConfigData("Thulecite Equip Parry")
if ThuleciteMode then
    local function Parry(inst, target, pos, caster)
        if not pos and target then pos = target:GetPosition() end
        caster:PushEvent("combat_parry", {direction = inst:GetAngleToPoint(pos), duration = 5, weapon = inst})
        inst.components.rechargeable:Discharge(12)
        inst.components.spellcaster.canuseontargets = false
        inst.components.spellcaster.canuseondead = false
        inst.components.spellcaster.canuseonpoint = false
        inst.components.spellcaster.canuseonpoint_water = false
        inst.components.spellcaster.spell = nil
        inst.reticule2hm:set(false)
        if inst.components.parryweapon then inst.components.parryweapon.parrytargets = {} end
    end
    local function OnPreParry(inst, doer)
        if doer and doer.SoundEmitter then
            if ThuleciteMode == -1 and doer.sg and doer.Physics then
                if doer.sg.statemem then doer.sg.statemem.isphysicstoggle = nil end
                doer.Physics:ClearCollisionMask()
                doer.Physics:CollidesWith(COLLISION.WORLD)
                doer.Physics:CollidesWith(COLLISION.OBSTACLES)
                doer.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
                doer.Physics:CollidesWith(COLLISION.CHARACTERS)
                doer.Physics:CollidesWith(COLLISION.GIANTS)
            end
            doer.SoundEmitter:PlaySound("dontstarve/creatures/lava_arena/trails/hide_pre")
        end
        if inst.components.parryweapon then inst.components.parryweapon.parrytargets = {} end
    end
    local function OnParry(inst, doer, attacker, damage)
        if doer and doer.SoundEmitter then
            doer:ShakeCamera(CAMERASHAKE.SIDE, 0.1, 0.03, 0.3)
            doer.SoundEmitter:PlaySound("dontstarve/creatures/lava_arena/trails/hide_hit")
            inst.components.finiteuses:Use(attacker and attacker:HasTag("epic") and 1 or 0.34)
            if doer.prefab == "wathgrithr" and doer.components.skilltreeupdater ~= nil and
                doer.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_shield_2") and inst.components.rechargeable and
                inst.components.rechargeable:GetPercent() < TUNING.WATHGRITHR_SHIELD_COOLDOWN_ONPARRY_REDUCTION then
                inst.components.rechargeable:SetPercent(TUNING.WATHGRITHR_SHIELD_COOLDOWN_ONPARRY_REDUCTION)
            end
        end
        if inst.components.parryweapon and inst.components.parryweapon.parrytargets and attacker and attacker:IsValid() then
            table.insert(inst.components.parryweapon.parrytargets, attacker.GUID)
        end
    end
    local function ReticuleTargetFn() return Vector3(ThePlayer.entity:LocalToWorldSpace(6.5, 0, 0)) end
    local function ReticuleMouseTargetFn(inst, mousepos)
        if mousepos ~= nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local dx = mousepos.x - x
            local dz = mousepos.z - z
            local l = dx * dx + dz * dz
            if l <= 0 then return inst.components.reticule.targetpos end
            l = 6.5 / math.sqrt(l)
            return Vector3(x + dx * l, 0, z + dz * l)
        end
    end
    local function ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
        local x, y, z = inst.Transform:GetWorldPosition()
        reticule.Transform:SetPosition(x, 0, z)
        local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
        if ease and dt ~= nil then
            local rot0 = reticule.Transform:GetRotation()
            local drot = rot - rot0
            rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
        end
        reticule.Transform:SetRotation(rot)
    end
    local function disableStatus(inst)
        inst.components.spellcaster.canuseontargets = false
        inst.components.spellcaster.canuseondead = false
        inst.components.spellcaster.canuseonpoint = false
        inst.components.spellcaster.canuseonpoint_water = false
        inst.components.spellcaster.spell = nil
        inst.reticule2hm:set(false)
    end
    local function enableStatus(inst)
        inst.components.spellcaster:SetSpellFn(Parry)
        inst.components.spellcaster.canuseontargets = true
        inst.components.spellcaster.canuseondead = true
        inst.components.spellcaster.canuseonpoint = true
        inst.components.spellcaster.canuseonpoint_water = true
        inst.reticule2hm:set(true)
    end
    local function UpdateStatus(inst)
        if not inst:IsValid() then return end
        local owner = inst.components.inventoryitem.owner
        if inst.components.equippable and inst.components.equippable:IsEquipped() and inst.components.rechargeable and inst.components.rechargeable:IsCharged() and
            owner and owner:IsValid() and owner:HasTag("player") and not owner:HasTag("playerghost") and
            not (owner.components.rider and owner.components.rider:IsRiding()) then
            enableStatus(inst)
        else
            disableStatus(inst)
        end
    end
    local function EnableReticule(inst, enable)
        if enable then
            if inst.components.reticule == nil then
                inst:AddComponent("reticule")
                inst.components.reticule.reticuleprefab = "reticulearc"
                inst.components.reticule.pingprefab = "reticulearcping"
                inst.components.reticule.targetfn = ReticuleTargetFn
                inst.components.reticule.mousetargetfn = ReticuleMouseTargetFn
                inst.components.reticule.updatepositionfn = ReticuleUpdatePositionFn
                inst.components.reticule.validcolour = {1, .75, 0, 1}
                inst.components.reticule.invalidcolour = {.5, 0, 0, 1}
                inst.components.reticule.ease = true
                inst.components.reticule.mouseenabled = true
                inst.components.reticule.ispassableatallpoints = true
                if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                    ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
            end
        elseif inst.components.reticule ~= nil then
            inst:RemoveComponent("reticule")
            if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
        end
    end
    local function OnreticuleDirty(inst) EnableReticule(inst, inst.reticule2hm:value()) end
    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            inst:ListenForEvent("mounted", inst._updatestatus, data.owner)
            inst:ListenForEvent("dismounted", inst._updatestatus, data.owner)
            inst:ListenForEvent("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            inst:RemoveEventCallback("mounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("dismounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    STRINGS.ACTIONS.CASTSPELL.RUINS_BAT = STRINGS.ACTIONS.CASTAOE.LAVAARENA_HEAVYBLADE
    local function actfn(act, inst)
        if act.action == ACTIONS.CASTSPELL and not act.pos and act.target then
            act.pos = DynamicPosition(not TheNet:IsDedicated() and TheInput:GetWorldPosition() or act.target:GetPosition())
        end
    end
    AddPrefabPostInit("ruins_bat", function(inst)
        inst.spelltype = "RUINS_BAT"
        if not inst:HasTag("parryweapon") then
            inst:AddTag("parryweapon2hm")
            inst:AddTag("allow_action_on_impassable")
            inst.reticule2hm = net_bool(inst.GUID, "ruinsbat.reticule2hm", "ruinsbatreticule2hmdirty")
            inst:ListenForEvent("ruinsbatreticule2hmdirty", OnreticuleDirty)
            inst.actfn2hm = actfn
        end
        if not TheWorld.ismastersim then return end
        if TheWorld:HasTag("cave") then inst.components.equippable.insulated = true end
        if not inst:HasTag("parryweapon") and not inst.components.parryweapon and not inst.components.rechargeable and not inst.components.spellcaster then
            inst:AddComponent("spellcaster")
            inst.components.spellcaster:SetSpellFn(Parry)
            inst.components.spellcaster.canuseontargets = true
            inst.components.spellcaster.canuseondead = true
            inst.components.spellcaster.canuseonpoint = true
            inst.components.spellcaster.canuseonpoint_water = true
            inst.components.spellcaster.canusefrominventory = false
            inst.components.spellcaster.can_cast_fn = truefn
            inst:AddComponent("parryweapon")
            inst.components.parryweapon.onpreparryfn = OnPreParry
            inst.components.parryweapon.onparryfn = OnParry
            inst:AddComponent("rechargeable")
            inst.components.rechargeable:SetMaxCharge(12)
            inst.components.rechargeable:SetOnChargedFn(UpdateStatus)
            inst.components.rechargeable:SetOnDischargedFn(UpdateStatus)
            inst:ListenForEvent("equipped", onequip)
            inst:ListenForEvent("unequipped", onunequip)
            inst._updatestatus = function() UpdateStatus(inst) end
        end
    end)
    AddComponentPostInit("parryweapon", function(self)
        local TryParry = self.TryParry
        self.TryParry = function(self, doer, attacker, damage, ...)
            if not (attacker and attacker:IsValid()) or TryParry(self, doer, attacker, damage, ...) then return true end
            if self.parrytargets and table.contains(self.parrytargets, attacker.GUID) then
                if self.onparryfn ~= nil then self.onparryfn(self.inst, doer, attacker, damage) end
                return true
            end
            return false
        end
        -- local OnPreParry = self.OnPreParry
        self.OnPreParry = function(self, doer, ...)
            if doer.sg then doer.sg:PushEvent("start_parry") end
            if self.onparrystart ~= nil then self.onparrystart(self.inst, doer) end
            if self.onpreparryfn ~= nil then self.onpreparryfn(self.inst, doer) end
        end
    end)
    AddStategraphPostInit("wilson", function(sg)
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject:HasTag("parryweapon2hm") then
                return "parry_pre"
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
    end)
    AddStategraphPostInit("wilson_client", function(sg)
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject:HasTag("parryweapon2hm") then
                return "parry_pre"
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
    end)
    AddPrefabPostInit("ruinshat", function(inst)
        if not TheWorld.ismastersim then return end
        if TheWorld:HasTag("cave") then inst.components.equippable.insulated = true end
    end)
    AddPrefabPostInit("armorruins", function(inst)
        if not TheWorld.ismastersim then return end
        if TheWorld:HasTag("cave") then inst.components.equippable.insulated = true end
    end)
end

-- 玻璃刀跳劈
local GlassCutter = GetModConfigData("Glass Cutter Leap Attack")
if GlassCutter then
    local function disableStatus(inst)
        inst.components.weapon:SetRange(nil)
        inst:RemoveTag("leapattack2hm")
        inst.components.spellcaster.canuseontargets = false
        inst.components.spellcaster.canuseondead = false
        inst.components.spellcaster.canuseonpoint = false
        inst.components.spellcaster.canuseonpoint_water = false
        inst.components.spellcaster.spell = nil
        inst.reticule2hm:set(false)
        inst.level2hm = 0
        inst.weaponlevel2hm:set(inst.level2hm)
        inst.components.weapon.attackrange = nil
        inst.components.weapon.hitrange = nil
        local owner = inst.components.inventoryitem.owner
        if owner and owner.prefab == "wathom" then
            inst.damagemultiplier2hm = nil
            inst.components.aoeweapon_leap:SetDamage(inst.components.weapon.damage)
        else
            inst.damagemultiplier2hm = 1.5
            inst.components.aoeweapon_leap:SetDamage(inst.components.weapon.damage * inst.damagemultiplier2hm)
        end
    end
    local function costhunger(inst, hungervalue)
        local owner = inst.components.inventoryitem.owner
        if owner and owner.components.hunger and owner.components.hunger.current > hungervalue then
            owner.components.hunger:DoDelta(-hungervalue)
            return true
        end
        return false
    end
    local function enableStatus(inst)
        local owner = inst.components.inventoryitem.owner
        if not owner or not owner.components.sanity then return disableStatus(inst) end
        -- if not owner.components.sanity:IsSane() then return disableStatus(inst) end
        local extrasanity = owner.components.sanity:IsInsanityMode() and ((owner.components.sanity:GetPercentWithPenalty() or 0) - 0.35) or
                                (0.65 - (owner.components.sanity:GetPercentWithPenalty() or 0))
        inst.level2hm =
            owner.prefab ~= "wathom" and (math.clamp(math.ceil(math.max(extrasanity / 0.2, inst.components.perishable:GetPercent() / 0.25)), 1, 4)) or 1
        inst.weaponlevel2hm:set(inst.level2hm)
        inst.components.weapon.attackrange = ({2, 4, 5, 6})[inst.level2hm]
        inst.components.weapon.hitrange = nil
        if owner.prefab ~= "wathom" then
            inst.damagemultiplier2hm = (1.25 + inst.level2hm * 0.25)
            inst.components.aoeweapon_leap:SetDamage(inst.components.weapon.damage * inst.damagemultiplier2hm)
        else
            inst.damagemultiplier2hm = nil
            inst.components.aoeweapon_leap:SetDamage(inst.components.weapon.damage)
        end
        inst:AddTag("leapattack2hm")
        inst.components.spellcaster:SetSpellFn(inst.spell2hm)
        inst.components.spellcaster.canuseontargets = true
        inst.components.spellcaster.canuseondead = true
        inst.components.spellcaster.canuseonpoint = true
        inst.components.spellcaster.canuseonpoint_water = true
        inst.reticule2hm:set(true)
    end
    local function actiondistanceFunc(inst, bufferedAction)
        return 20
    end
    local function UpdateStatus(inst)
        if not inst:IsValid() then return end
        local owner = inst.components.inventoryitem.owner
        if not inst.components.perishable or (inst.components.perishable.perishremainingtime or 0) <= 0 or not inst.components.equippable:IsEquipped() or
            not inst.components.rechargeable or not inst.components.rechargeable:IsCharged() or not (owner and owner:IsValid()) or not owner:HasTag("player") or
            owner:HasTag("playerghost") or (owner.components.rider and owner.components.rider:IsRiding()) then return disableStatus(inst) end
        enableStatus(inst)
    end
    local function AnvilStrike(inst, target, pos, doer)
        if doer.components.combat then
            doer.components.combat:RestartCooldown()
        end
        local x, y, z = doer.Transform:GetWorldPosition()
        if not pos then if target then pos = target:GetPosition() end end
        if TheWorld.Map:IsAboveGroundAtPoint(pos.x, pos.y, pos.z) or TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z) ~= nil then
            doer:PushEvent("combat_leap", {targetpos = pos, weapon = inst})
            local pulse_fx = SpawnPrefab("alterguardian_phase3trapgroundfx")
            pulse_fx.Transform:SetPosition(pos.x, 0, pos.z)
            pulse_fx.AnimState:SetDeltaTimeMultiplier(4)
            pulse_fx:DoTaskInTime(3, pulse_fx.Remove)
            pulse_fx.AnimState:SetMultColour(1, 1, 1, 0.5)
            inst.pulse_fx = pulse_fx
        else
            doer.components.talker:Say(TUNING.isCh2hm and "唔,差点跳到海里" or "Swimming is not a good idea.")
        end
    end
    local function OnPreLeap(inst, doer, startingpos, targetpos)
        if doer then
            if doer.components.combat then
                doer.components.combat:RestartCooldown()
            end
        end
    end
    local function OnLeap(inst, doer, startingpos, targetpos)
        if inst.pulse_fx and inst.pulse_fx:IsValid() then
            inst.pulse_fx.AnimState:PlayAnimation("meteorground_pst")
            inst.pulse_fx.AnimState:SetDeltaTimeMultiplier(1)
            inst.pulse_fx:ListenForEvent("animover", inst.pulse_fx.Remove)
            inst.pulse_fx = nil
        end
        local range = math.sqrt(distsq(startingpos.x, startingpos.z, targetpos.x, targetpos.z))
        if doer and doer.components.locomotor then
            doer.components.locomotor.isrunning = true
            doer.Physics:SetMotorVel(range / 2 + 2.5 + (inst.level2hm or 1) * 2.5, 0, 0)
            doer.components.locomotor:StartUpdatingInternal()
        end
        if not costhunger(inst, 4 + range / 4) then
            if inst:IsValid() and inst.components.rechargeable then inst.components.rechargeable:Discharge(6 + range / 2) end
        end
        UpdateStatus(inst)
        if inst.components.perishable then inst.components.perishable:AddTime(-(range / 8 + 2) * TUNING.MOONGLASS_CHARGED_PERISH_TIME / 75) end
        if inst.components.finiteuses then inst.components.finiteuses:Use(range / 8 + 2) end
        if doer and doer.sg then
            doer.sg:RemoveStateTag("busy")
            doer.sg:RemoveStateTag("doing")
            doer.sg:RemoveStateTag("nopredict")
            doer.sg:AddStateTag("idle")
        end
        if doer and doer.components.playercontroller then doer.components.playercontroller:Enable(true) end
    end
    local function ReticuleTargetFn()
        local player = ThePlayer
        local ground = TheWorld.Map
        local pos = Vector3()
        for r = 7, 0, -.25 do
            pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
            if ground:IsPassableAtPoint(pos:Get()) and not ground:IsGroundTargetBlocked(pos) then return pos end
        end
        return pos
    end
    local function EnableReticule(inst, enable)
        if enable then
            if inst.components.reticule == nil then
                inst:AddComponent("reticule")
                inst.components.reticule.reticuleprefab = "reticuleaoe"
                inst.components.reticule.pingprefab = "reticuleaoeping"
                inst.components.reticule.targetfn = ReticuleTargetFn
                inst.components.reticule.validcolour = {1, .75, 0, 1}
                inst.components.reticule.invalidcolour = {.5, 0, 0, 1}
                inst.components.reticule.ease = true
                inst.components.reticule.mouseenabled = true
                inst.components.reticule.ispassableatallpoints = true
                if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                    ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
            end
        elseif inst.components.reticule ~= nil then
            inst:RemoveComponent("reticule")
            if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
        end
    end
    local function OnreticuleDirty(inst) EnableReticule(inst, inst.reticule2hm:value()) end
    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            inst:ListenForEvent("sanitydelta", inst._updatestatus, data.owner)
            inst:ListenForEvent("mounted", inst._updatestatus, data.owner)
            inst:ListenForEvent("dismounted", inst._updatestatus, data.owner)
            inst:ListenForEvent("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            inst:RemoveEventCallback("sanitydelta", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("mounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("dismounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    local resetweaponperishableview = InfusionView.Refresh
    local function onrepaired(inst, repairuse, doer, repair_item, useitems)
        if repair_item.prefab == "moonglass_charged" or repair_item.prefab == "purebrilliance" then
            if inst.components.finiteuses:GetPercent() >= 1 then useitems = useitems + 0.5 end
            if not inst.components.perishable then
                inst:AddTag("show_spoilage")
                inst:AddComponent("perishable")
                inst.components.perishable.perishtime = TUNING.MOONGLASS_CHARGED_PERISH_TIME
                inst.components.perishable.perishremainingtime = TUNING.MOONGLASS_CHARGED_PERISH_TIME / 5 * math.clamp(useitems, 1, 5) *
                                                                     (repair_item.prefab == "purebrilliance" and 2 or 1)
                inst.components.perishable:StartPerishing()
                if not inst.resetviewtask2hm then inst.resetviewtask2hm = inst:DoTaskInTime(0, resetweaponperishableview) end
                UpdateStatus(inst)
            else
                inst.components.perishable:AddTime(TUNING.MOONGLASS_CHARGED_PERISH_TIME / 5 * useitems * (repair_item.prefab == "purebrilliance" and 2 or 1))
            end
        end
    end
    local function onperished(inst)
        if inst.components.perishable then
            inst:RemoveTag("show_spoilage")
            inst:RemoveComponent("perishable")
            inst:DoTaskInTime(0, resetweaponperishableview)
            UpdateStatus(inst)
        end
    end
    local function checkweapon(inst)
        if inst.components.perishable and (inst.components.perishable.perishremainingtime or 0) <= 0 then
            inst:RemoveTag("show_spoilage")
            inst:RemoveComponent("perishable")
            if not inst.resetviewtask2hm then inst.resetviewtask2hm = inst:DoTaskInTime(0, resetweaponperishableview) end
            UpdateStatus(inst)
        end
    end
    local function DisplayNameFn(inst)
        return inst:HasTag("show_spoilage") and ((TUNING.isCh2hm and "注能" or "Infused ") .. STRINGS.NAMES.GLASSCUTTER ..
                   (inst.weaponlevel2hm and inst.weaponlevel2hm:value() > 0 and
                       (" Lv" .. inst.weaponlevel2hm:value() .. (inst.weaponlevel2hm:value() >= 4 and " Max" or "")) or "")) or nil
    end
    local function itemtiletextfn(inst, itemtile)
        local leveltext
        local tmplevel = inst.weaponlevel2hm and inst.weaponlevel2hm:value()
        if tmplevel and tmplevel > 0 then
            leveltext = "Lv" .. tmplevel
            inst.spelltype = "GLASSCUTTER" .. tmplevel
            if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                ThePlayer.replica.inventory:IsHolding(inst) and ThePlayer.HUD and ThePlayer.HUD.controls and ThePlayer.HUD.controls.hover then
                ThePlayer.HUD.controls.hover:OnUpdate()
            end
        end
        return "weaponlevel2hmdirty", leveltext
    end
    STRINGS.ACTIONS.CASTSPELL.GLASSCUTTER = TUNING.isCh2hm and "跃斩" or "Leap Attack"
    STRINGS.ACTIONS.CASTSPELL.GLASSCUTTER1 = TUNING.isCh2hm and "跃斩 Lv1" or "Leap Atk Lv1"
    STRINGS.ACTIONS.CASTSPELL.GLASSCUTTER2 = TUNING.isCh2hm and "跃斩 Lv2" or "Leap Atk Lv2"
    STRINGS.ACTIONS.CASTSPELL.GLASSCUTTER3 = TUNING.isCh2hm and "跃斩 Lv3" or "Leap Atk Lv3"
    STRINGS.ACTIONS.CASTSPELL.GLASSCUTTER4 = TUNING.isCh2hm and "跃斩 Lv4 Max" or "Leap Atk Lv4 Max"
    AddPrefabPostInit("glasscutter", function(inst)
        if inst:HasTag("aoeweapon_leap") then return end
        inst.spelltype = "GLASSCUTTER"
        inst.repairmaterials2hm = {moonglass_charged = TUNING.GLASSCUTTER.USES / 7, purebrilliance = TUNING.GLASSCUTTER.USES / 3}
        if GetModConfigData("Construction Amulet Repair Equip") then inst.repairmaterials2hm.moonglass = TUNING.GLASSCUTTER.USES / 7 end
        inst.displaynamefn = DisplayNameFn
        inst.itemtilefn2hm = itemtiletextfn
        InfusionView.Install(inst)
        -- inst:AddTag("hide_percentage")
        inst:AddTag("show_spoilage")
        inst:AddTag("allow_action_on_impassable")
        inst._explode2hm = net_event(inst.GUID, "glasscutter._explode")
        inst.reticule2hm = net_bool(inst.GUID, "glasscutter.reticule2hm", "glasscutterreticule2hmdirty")
        inst:ListenForEvent("glasscutterreticule2hmdirty", OnreticuleDirty)
        inst.weaponlevel2hm = net_tinybyte(inst.GUID, "weapon.level2hm", "weaponlevel2hmdirty")
        if not TheWorld.ismastersim then
            inst:ListenForEvent("glasscutter._explode", CreateGroundFX)
            return inst
        end
        if GlassCutter == true and inst.components.weapon then
            local onattack = inst.components.weapon.onattack
            inst.components.weapon:SetOnAttack(function(inst, attacker, target, ...)
                local shadow_aligned, shadowcreature
                if target and target:IsValid() then
                    shadow_aligned = TUNING.DSTU and target:HasTag("shadow_aligned")
                    shadowcreature = target:HasOneOfTags({"shadowcreature", "nightmarecreature"})
                end
                if shadow_aligned then target:RemoveTag("shadow_aligned") end
                if onattack ~= nil then onattack(inst, attacker, target, ...) end
                if target:IsValid() then
                    if shadow_aligned then target:AddTag("shadow_aligned") end
                    if shadowcreature and target.components.health and target.components.health:IsDead() and attacker and attacker:IsValid() and
                        attacker.components.sanity then attacker.components.sanity:DoDelta(target.components.health.maxhealth * 0.05) end
                end
            end)
        end
        if inst.components.aoeweapon_leap then return end
        inst:AddComponent("aoeweapon_leap")
        if not inst.components.aoeweapon_leap.damage then
            inst:RemoveComponent("aoeweapon_leap")
            inst:RemoveTag("show_spoilage")
            inst:RemoveTag("allow_action_on_impassable")
            return
        end
        inst.components.aoeweapon_leap:SetDamage(inst.components.weapon.damage)
        inst.components.aoeweapon_leap:SetWorkActions()
        inst.components.aoeweapon_leap.tags = {"_combat"}
        inst.components.aoeweapon_leap:SetOnLeaptFn(OnLeap)
        inst.components.aoeweapon_leap:SetOnPreLeapFn(OnPreLeap)
        inst:AddComponent("perishable")
        inst.components.perishable.perishtime = TUNING.MOONGLASS_CHARGED_PERISH_TIME
        inst.components.perishable.perishremainingtime = 0
        inst.components.perishable:StartPerishing()
        inst:DoTaskInTime(0, checkweapon)
        inst:ListenForEvent("perished", onperished)
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.ignoremax = true
        inst.components.repairable2hm.onrepaired = onrepaired
        inst:AddComponent("spellcaster")
        inst.components.spellcaster:SetSpellFn(AnvilStrike)
        inst.components.spellcaster.canuseontargets = true
        inst.components.spellcaster.canuseondead = true
        inst.components.spellcaster.canuseonpoint = true
        inst.components.spellcaster.canuseonpoint_water = true
        inst.components.spellcaster.canusefrominventory = false
        inst.components.spellcaster.can_cast_fn = truefn
        inst.actiondistanceFunc2hm = actiondistanceFunc
        inst:AddComponent("rechargeable")
        inst.components.rechargeable:SetMaxCharge(24)
        inst.components.rechargeable:SetOnChargedFn(UpdateStatus)
        inst.components.rechargeable:SetOnDischargedFn(UpdateStatus)
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
        inst._updatestatus = function() UpdateStatus(inst) end
        inst.spell2hm = AnvilStrike
        inst.level2hm = 0
        inst.weaponlevel2hm:set(0)
    end)
    local leapattackstate = State {
        name = "leapattack2hm",
        tags = {"attack", "backstab", "busy", "notalking", "abouttoattack", "pausepredict", "nointerrupt"},
        onenter = function(inst, data)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            if target then
                local canRange = inst.components.combat:CalcAttackRangeSq(target)
                canRange = math.min(canRange * 1.2, canRange + 12)
                if inst:GetDistanceSqToInst(target) > canRange then
                    inst.sg:GoToState("knockback2hm", {
                        propsmashed = true,
                        knocker = inst,
                        radius = 3,
                        strengthmult = 1,
                    })
                    return
                end
            end
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk_leap", false)
            inst.Transform:SetEightFaced()
            -- inst.AnimState:ClearOverrideBuild("player_lunge")
            -- inst.AnimState:ClearOverrideBuild("player_attack_leap")
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            if inst.components.playercontroller ~= nil then inst.components.playercontroller:RemotePausePrediction() end
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst.sg.statemem.level = equip and equip.level2hm or 1
            costhunger(equip, 4)
            if equip and equip.components.perishable then equip.components.perishable:AddTime(-TUNING.MOONGLASS_CHARGED_PERISH_TIME / 75) end
            inst.sg.statemem.flash = 0
            if inst.prefab ~= "wathom" then
                inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1 + inst.sg.statemem.level * 0.25, "glasscutter2hm")
            end
        end,
        onexit = function(inst)
            if inst.prefab ~= "wathom" then inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "glasscutter2hm") end
            -- inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then inst.components.combat:CancelAttack() end
            inst.Transform:SetFourFaced()
            inst.components.locomotor:Stop()
            inst.Physics:ClearMotorVelOverride()
            inst:DoTaskInTime(0, function(inst) if inst.components.playercontroller then inst.components.playercontroller:Enable(true) end end)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            if inst.sg.statemem.flash then
                inst.components.bloomer:PopBloom("leap2hm")
                inst.components.colouradder:PopColour("leap2hm")
            end
            -- inst.AnimState:AddOverrideBuild("player_lunge")
            -- inst.AnimState:AddOverrideBuild("player_attack_leap")
        end,
        timeline = {
            TimeEvent(0 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.WORLD)
                local buffaction = inst:GetBufferedAction()
                local target = buffaction ~= nil and buffaction.target or nil
                if target ~= nil then
                    inst.sg.statemem.startingpos = inst:GetPosition()
                    inst.sg.statemem.targetpos = target:GetPosition()
                    if target ~= nil then
                        if inst.sg.statemem.startingpos.x ~= inst.sg.statemem.targetpos.x or inst.sg.statemem.startingpos.z ~= inst.sg.statemem.targetpos.z then
                            inst.leapvelocity2hm = math.sqrt(distsq(inst.sg.statemem.startingpos.x, inst.sg.statemem.startingpos.z,
                                                                    inst.sg.statemem.targetpos.x, inst.sg.statemem.targetpos.z)) / (12 * FRAMES)
                        end
                    end
                end
                inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
            end),
            TimeEvent(10 * FRAMES, function(inst) if inst.sg.statemem.flash then inst.components.colouradder:PushColour("leap2hm", .1, .1, 0, 0) end end),
            TimeEvent(11 * FRAMES, function(inst) if inst.sg.statemem.flash then inst.components.colouradder:PushColour("leap2hm", .2, .2, 0, 0) end end),
            TimeEvent(12 * FRAMES, function(inst)
                if inst.sg.statemem.flash then inst.components.colouradder:PushColour("leap2hm", .4, .4, 0, 0) end
                inst.sg:RemoveStateTag("abouttoattack")
                inst.components.locomotor:Stop()
                inst.Physics:ClearMotorVelOverride()
                inst:PerformBufferedAction()
                inst.components.playercontroller:Enable(false)
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
                inst.sg:RemoveStateTag("busy")
                inst.Physics:CollidesWith(COLLISION.OBSTACLES)
                inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
            end),
            TimeEvent(13 * FRAMES, function(inst)
                if inst.sg.statemem.flash then
                    inst.components.bloomer:PushBloom("leap2hm", "shaders/anim.ksh", -2)
                    inst.components.colouradder:PushColour("leap2hm", 1, 1, 0, 0)
                    inst.sg.statemem.flash = 1.3
                end
            end),
            TimeEvent(14 * FRAMES, function(inst)
                inst.leapvelocity2hm = inst.sg.statemem.level * 2.5 + (not inst:HasTag("wearingheavyarmor") and 2.5 or 0)
                SpawnPrefab("dirt_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
            TimeEvent(19 * FRAMES, function(inst) SpawnPrefab("dirt_puff").Transform:SetPosition(inst.Transform:GetWorldPosition()) end),
            TimeEvent(24 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("nointerrupt")
                inst.sg:RemoveStateTag("pausepredict")
                inst.sg:AddStateTag("idle")
                inst.leapvelocity2hm = 0
                inst.Physics:Stop()
                inst.Physics:CollidesWith(COLLISION.CHARACTERS) -- Re-enabling Wathom's normal collision.
                inst.Physics:CollidesWith(COLLISION.GIANTS)
                inst.components.playercontroller:Enable(true)
                if inst.sg.statemem.flash then inst.components.bloomer:PopBloom("leap2hm") end
            end)
        },
        onupdate = function(inst)
            if inst.sg.statemem.flash and inst.sg.statemem.flash > 0 then
                inst.sg.statemem.flash = math.max(0, inst.sg.statemem.flash - .1)
                local c = math.min(1, inst.sg.statemem.flash)
                inst.components.colouradder:PushColour("leap2hm", c, c, 0, 0)
            end
            if inst.leapvelocity2hm then inst.Physics:SetMotorVel(inst.leapvelocity2hm, 0, 0) end
        end,
        events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
    }
    AddStategraphState("wilson", leapattackstate)
    AddStategraphPostInit("wilson", function(sg)
        -- sg.states.combat_leap.tags.notalking = true
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if not (inst.components.rider and inst.components.rider:IsRiding()) and action.invobject and action.invobject:HasTag("aoeweapon_leap") and
                action.invobject:HasTag("leapattack2hm") then
                return "combat_leap_start"
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
        local Attack_Old = sg.actionhandlers[ACTIONS.ATTACK].deststate
        sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
            local handler = Attack_Old(inst, action, ...)
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider
            if not (rider and rider:IsRiding()) and equip and equip:HasTag("aoeweapon_leap") and equip:HasTag("leapattack2hm") and
                not inst.components.rider:IsRiding() then
                    return "leapattack2hm"
                end
            return handler
        end
    end)
    AddStategraphPostInit("wilson_client", function(sg)
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject:HasTag("aoeweapon_leap") and action.invobject:HasTag("leapattack2hm") then
                return "combat_leap_start"
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
        sg.states.combat_leap_start.server_states[hash("leapattack2hm")] = true
        local ClientAttack_Old = sg.actionhandlers[ACTIONS.ATTACK].deststate
        sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
            local handler = ClientAttack_Old(inst, action, ...)
            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider
            if equip and equip:HasTag("aoeweapon_leap") and equip:HasTag("leapattack2hm") and not (rider ~= nil and rider:IsRiding()) then
                return "combat_leap_start"
            end
            return handler
        end
    end)
end

-- 鳞甲防御冰冻
if GetModConfigData("Scalemail Parry Freezable") then
    if TUNING.ARMORDRAGONFLY_ABSORPTION < TUNING.ARMORWOOD_ABSORPTION then TUNING.ARMORDRAGONFLY_ABSORPTION = TUNING.ARMORWOOD_ABSORPTION end
    local function armordragonflytaskfn(inst) inst.armordragonflytask2hm = nil end
    AddComponentPostInit("freezable", function(self)
        local oldResolveWearOffTime = self.ResolveWearOffTime
        self.ResolveWearOffTime = function(self, wearofftime, ...)
            local time = oldResolveWearOffTime(self, wearofftime, ...)
            if self.inst:HasTag("player") and self.inst.armordragonfly2hm and time then time = time / 2 end
            return time
        end
        local oldUnFreeze = self.Unfreeze
        self.Unfreeze = function(self, ...)
            if self.inst:HasTag("player") and self.inst.armordragonfly2hm then
                if self.inst.armordragonflytask2hm then self.inst.armordragonflytask2hm:Cancel() end
                self.inst.armordragonflytask2hm = self.inst:DoTaskInTime(self.inst.prefab == "willow" and 3 or 2, armordragonflytaskfn)
            end
            return oldUnFreeze(self, ...)
        end
        local oldAddColdness = self.AddColdness
        self.AddColdness = function(self, ...)
            if self.inst:HasTag("player") and self.inst.armordragonfly2hm and (self.inst.armordragonflytask2hm or self:IsFrozen()) then return end
            return oldAddColdness(self, ...)
        end
        local oldFreeze = self.Freeze
        self.Freeze = function(self, ...)
            if self.inst:HasTag("player") and self.inst.armordragonfly2hm and (self.inst.armordragonflytask2hm or self:IsFrozen()) then return end
            return oldFreeze(self, ...)
        end
    end)
    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") and data.owner.components.freezable then
            data.owner.armordragonfly2hm = true
            if data.owner.armordragonflytask2hm then data.owner.armordragonflytask2hm:Cancel() end
            data.owner.armordragonflytask2hm = data.owner:DoTaskInTime(2, armordragonflytaskfn)
        end
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            data.owner.armordragonfly2hm = nil
            if data.owner.armordragonflytask2hm then
                data.owner.armordragonflytask2hm:Cancel()
                data.owner.armordragonflytask2hm = nil
            end
        end
    end
    AddPrefabPostInit("armordragonfly", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.armor then inst.components.armor.absorb_percent = TUNING.ARMORDRAGONFLY_ABSORPTION end
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
    end)
    -- 熔岩虫收回和召唤
    STRINGS.ACTIONS.STOPUSINGITEM.SHOWLAVAE2HM = TUNING.isCh2hm and "召唤" or "Out"
    STRINGS.ACTIONS.STOPUSINGITEM.HIDELAVAE2HM = TUNING.isCh2hm and "召回" or "In"
    local oldSTOPUSINGITEMstrfn = ACTIONS.STOPUSINGITEM.strfn
    ACTIONS.STOPUSINGITEM.strfn = function(act)
        local res = oldSTOPUSINGITEMstrfn(act)
        if res == "LAVAE_TOOTH" and act.invobject and act.invobject.prefab == "lavae_tooth" then
            return act.invobject:HasTag("haslavae2hm") and "HIDELAVAE2HM" or "SHOWLAVAE2HM"
        end
        return res
    end
    local function addtagforlavaetooth(inst)
        if inst and inst.components.petleash ~= nil and inst.components.petleash:IsFull() then
            inst:AddTag("haslavae2hm")
        else
            inst:RemoveTag("haslavae2hm")
        end
    end
    local function on_stop_use(inst)
        inst.components.useabletargeteditem.inuse_targeted = true
        if inst ~= nil and inst.components.petleash ~= nil and not inst.components.petleash:IsFull() then
            inst.components.petleash:SpawnPetAt(inst.Transform:GetWorldPosition())
            -- for k, v in pairs(inst.components.petleash.pets) do if v.components.hunger then v.components.hunger.current = 0 end end
            inst:DoTaskInTime(0, addtagforlavaetooth)
        elseif inst and inst.components.petleash ~= nil and inst.components.petleash:IsFull() then
            for k, v in pairs(inst.components.petleash.pets) do
                if v and (not v:IsValid() or (v.components.health and v.components.health:IsDead())) then return end
                inst.disableOnPetLost2hm = true
                local fx = SpawnPrefab("spawn_fx_medium")
                fx.Transform:SetPosition(v.Transform:GetWorldPosition())
                v:Remove()
            end
            inst.disableOnPetLost2hm = nil
            inst:DoTaskInTime(0, addtagforlavaetooth)
        end
    end
    AddPrefabPostInit("lavae_tooth", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.useabletargeteditem then return end
        inst:AddComponent("useabletargeteditem")
        inst.components.useabletargeteditem.inuse_targeted = true
        inst.components.useabletargeteditem.inventory_disableable = true
        inst.components.useabletargeteditem:SetOnStopUseFn(on_stop_use)
        inst:DoTaskInTime(0, addtagforlavaetooth)
        local oldOnPetLost = inst.OnPetLost
        inst.OnPetLost = function(...) if not inst.disableOnPetLost2hm then oldOnPetLost(...) end end
    end)
end

-- 建造护符修理装备
local amuletmode = GetModConfigData("Construction Amulet Repair Equip")
if amuletmode then
    if amuletmode == -1 then
        local function greenamuletUSEITEM(inst, doer, actions, right, target)
            return target and target.prefab and target.prefab ~= "greenamulet" and AllRecipes[target.prefab] ~= nil
        end
        local function actionfn(inst, doer, target, pos, act)
            if inst and inst.prefab == "greenamulet" and inst.components.finiteuses and target and target.prefab and target.prefab ~= "greenamulet" and
                AllRecipes[target.prefab] then
                local percentusedcomponent = target.components.armor or target.components.finiteuses or target.components.fueled
                if percentusedcomponent then
                    local percent = percentusedcomponent:GetPercent()
                    if percent < 1 then
                        local repair = math.min(1 - percent, 0.45)
                        inst.components.finiteuses:Use(repair / 0.45)
                        percentusedcomponent:SetPercent(percent + repair)
                        if doer and doer.SoundEmitter then doer.SoundEmitter:PlaySound("dontstarve/common/nightmareAddFuel") end
                        return true
                    end
                end
            end
        end
        STRINGS.ACTIONS.ACTION2HM.GREENAMULET = STRINGS.ACTIONS.REPAIR.GENERIC
        AddPrefabPostInit("greenamulet", function(inst)
            inst.actionothercondition2hm = greenamuletUSEITEM
            if not TheWorld.ismastersim then return end
            inst:AddComponent("action2hm")
            inst.components.action2hm.actionfn = actionfn
        end)
    end
    AddPrefabPostInit("armorgrass", function(inst)
        inst.repairmaterials2hm = {cutgrass = TUNING.ARMORGRASS / 12}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    -- AddPrefabPostInit("nightsword", function(inst)
    --     inst.repairmaterials2hm = {nightmarefuel = TUNING.NIGHTSWORD_USES / 7}
    --     if not TheWorld.ismastersim then return end
    --     inst:AddComponent("repairable2hm")
    -- end)
    AddPrefabPostInit("armor_sanity", function(inst)
        inst.repairmaterials2hm = {nightmarefuel = TUNING.ARMOR_SANITY / 8}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
	AddPrefabPostInit("woodcarvedhat", function(inst) -- 伍迪硬木帽可修理（某蛋仙人吐槽太不方便了qwq.）
	    local WOODCARVEDHAT = 262.5
        inst.repairmaterials2hm = {log = WOODCARVEDHAT / 8}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("armorwood", function(inst)
        inst.repairmaterials2hm = {log = TUNING.ARMORWOOD / 10}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("armormarble", function(inst)
        inst.repairmaterials2hm = {marble = TUNING.ARMORMARBLE / 7}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("armordragonfly", function(inst)
        inst.repairmaterials2hm = {dragon_scales = TUNING.ARMORDRAGONFLY}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("moonglassaxe", function(inst)
        inst.repairmaterials2hm = {moonglass = TUNING.AXE_USES / 3}
        if not TheWorld.ismastersim then return end
        if hardmode then inst.needgreenamulet2hm = true end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("ruinshat", function(inst)
        inst.repairmaterials2hm = {thulecite_pieces = TUNING.ARMOR_RUINSHAT / 25.5, thulecite = TUNING.ARMOR_RUINSHAT / 4.25}
        if not TheWorld.ismastersim then return end
        if hardmode then inst.needgreenamulet2hm = true end
        inst:AddComponent("repairable2hm")
    end)
    if hardmode then AddRecipePostInit("ruinshat", function(inst) table.insert(inst.ingredients, Ingredient("redgem", 1)) end) end
    AddPrefabPostInit("armorruins", function(inst)
        inst.repairmaterials2hm = {thulecite_pieces = TUNING.ARMORRUINS / 30, thulecite = TUNING.ARMORRUINS / 5}
        if not TheWorld.ismastersim then return end
        if hardmode then inst.needgreenamulet2hm = true end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("ruins_bat", function(inst)
        inst.repairmaterials2hm = {
            thulecite_pieces = TUNING.RUINS_BAT_USES / 30,
            thulecite = TUNING.RUINS_BAT_USES / 5,
            goldnugget = TUNING.RUINS_BAT_USES / 120
        }
        if not TheWorld.ismastersim then return end
        if hardmode then inst.needgreenamulet2hm = true end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("multitool_axe_pickaxe", function(inst)
        inst.repairmaterials2hm = {
            thulecite_pieces = TUNING.MULTITOOL_AXE_PICKAXE_USES / 13.5,
            thulecite = TUNING.MULTITOOL_AXE_PICKAXE_USES / 2.25,
            goldnugget = TUNING.MULTITOOL_AXE_PICKAXE_USES / 54
        }
        if not TheWorld.ismastersim then return end
        if hardmode then inst.needgreenamulet2hm = true end
        inst:AddComponent("repairable2hm")
    end)
    AddPrefabPostInit("batnosehat", function(inst)
        local time = math.max(TUNING.PERISH_SLOW * 2 / 3, TUNING.BATNOSEHAT_PERISHTIME * 2 / 3)
        inst.repairmaterials2hm = {milkywhites = time, goatmilk = time, butter = time}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
    end)
    local function orangestaffcycles(inst)
        if inst.components.finiteuses and inst.components.finiteuses:GetPercent() < 1 then inst.components.finiteuses:Repair(1) end
    end
    AddPrefabPostInit("orangestaff", function(inst)
        inst.repairmaterials2hm = {orangegem = TUNING.ORANGESTAFF_USES * 0.4}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
        inst:WatchWorldState("cycles", orangestaffcycles)
    end)
end

-- 香炉吸取影怪血量恢复耐久,且切换到其他手部装备后仍照明和继续吸取
if GetModConfigData("Shadow Thurible Has Light") then
    local function risefx(inst, repairvalue)
        if hardmode then repairvalue = repairvalue / 2 end
        local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
        -- SpawnPrefab("sanity_raise").Transform:SetPosition(inst.Transform:GetWorldPosition())
        local parent = owner or inst
        parent:AddChild(SpawnPrefab("sanity_raise"))
        if not (owner and owner:IsValid()) then return end
        if owner.prefab == "waxwell" then
            repairvalue = repairvalue * math.max(owner.shadowlevel2hm or 4, 4) / 2
        elseif owner.prefab == "wanda" and owner.age_state == "old" then
            repairvalue = repairvalue * 2
        end
        if inst.components.fueled and inst.components.fueled:GetPercent() < 1 then
            local percent = inst.components.fueled:GetPercent()
            inst.components.fueled:SetPercent(math.clamp(0, percent + repairvalue, 1))
            repairvalue = (repairvalue + percent) <= 1 and 0 or (repairvalue + percent - 1)
            if repairvalue <= 0 then return end
        end
        if (not hardmode or owner:HasTag("shadowmagic")) and owner.components.inventory then
            for k, equip in pairs(owner.components.inventory.equipslots) do
                if equip and equip:IsValid() and (equip.prefab == "skeletonhat" or equip.prefab == "armorskeleton") then
                    if equip.components.fueled and equip.components.fueled:GetPercent() < 1 then
                        local percent = equip.components.fueled:GetPercent()
                        equip.components.fueled:SetPercent(math.clamp(0, percent + repairvalue, 1))
                        repairvalue = (repairvalue + percent) <= 1 and 0 or (repairvalue + percent - 1)
                    elseif equip.components.armor and equip.components.armor:GetPercent() < 1 then
                        local percent = equip.components.armor:GetPercent()
                        equip.components.armor:SetPercent(math.clamp(0, percent + repairvalue, 1))
                        repairvalue = (repairvalue + percent) <= 1 and 0 or (repairvalue + percent - 1)
                    end
                    if repairvalue <= 0 then return end
                end
            end
        end
    end
    local function doshadowtask(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 18, nil, {"player", "INLIMBO"}, {"shadowcreature", "nightmarecreature"})
        local repairvalue = 0
        for _, ent in ipairs(ents) do
            if ent and ent:IsValid() and ent.prefab ~= "shadowchanneler" and ent.Transform and ent.components.health and not ent.components.health:IsDead() and
                not ent.locktarget2hm then
                local health = ent.components.health.currenthealth
                if health > 100 then
                    repairvalue = repairvalue + 0.01
                    ent.components.health:DoDelta(-100, false, inst.prefab, true, inst, true)
                elseif ent.components.lootdropper and (ent.components.lootdropper.loot or ent.components.lootdropper.chanceloottable) then
                    ent.disabledeath2hm = true
                    ent.components.lootdropper:SetLoot()
                    ent.components.lootdropper:SetChanceLootTable()
                    ent.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
                    ent.components.lootdropper.GenerateLoot = emptytablefn
                    ent.components.lootdropper.DropLoot = emptytablefn
                    ent.components.health:DoDelta(-health, false, inst.prefab, true, inst, true)
                    repairvalue = repairvalue + 0.01 + health / 10000
                else
                    ent.disabledeath2hm = true
                    ent.components.health:DoDelta(-health, false, inst.prefab, true, inst, true)
                    repairvalue = repairvalue + health / 10000
                end
                ent:AddChild(SpawnPrefab("sanity_lower"))
            end
        end
        if repairvalue <= 0 then return end
        inst:DoTaskInTime(1, risefx, repairvalue)
    end
    local function checkstatus(inst)
        if inst.checkstatustask2hm then inst.checkstatustask2hm = nil end
        if inst.components.fueled and inst.components.inventoryitem and inst.components.equippable then
            local enable = (inst.components.equippable:IsEquipped() or inst.bindplayer2hm or not inst.components.inventoryitem:IsHeld()) and not inst:IsAsleep()
            if enable then
                if not inst.shadowtask2hm then inst.shadowtask2hm = inst:DoPeriodicTask(2.5, doshadowtask, 1.25) end
            elseif inst.shadowtask2hm then
                inst.shadowtask2hm:Cancel()
                inst.shadowtask2hm = nil
            end
            local percent = inst.components.fueled:GetPercent()
            if percent > 0 and enable and not (inst._light2hm and inst._light2hm:IsValid()) then
                inst._light2hm = SpawnPrefab("deathcurselight2hm")
                inst._light2hm.Light:SetFalloff(0.4)
                inst._light2hm.Light:SetIntensity(.7)
                inst._light2hm.Light:SetRadius(inst.bindplayer2hm and 9 or 18)
                inst._light2hm.Light:SetColour(180 / 255, 195 / 255, 150 / 255)
                inst._light2hm.Light:Enable(true)
            elseif (percent <= 0 or not enable) and inst._light2hm and inst._light2hm:IsValid() then
                inst._light2hm:Remove()
                inst._light2hm = nil
            end
            if inst._light2hm and inst._light2hm:IsValid() then
                local owner = inst.components.inventoryitem:GetGrandOwner() or inst
                if owner and owner:IsValid() then owner:AddChild(inst._light2hm) end
                inst._light2hm.Light:SetRadius(inst.bindplayer2hm and 4 or 18)
            end
            if percent <= 0 and inst:HasTag("nightvision") then
                -- 停止照明和夜视
                inst:RemoveTag("nightvision")
                local owner = inst.components.inventoryitem.owner
                if inst.components.equippable:IsEquipped() and owner and owner:HasTag("player") and owner.components.inventory then
                    inst.disablethuriblecheck2hm = true
                    owner.components.inventory:Unequip(EQUIPSLOTS.HANDS)
                    owner.components.inventory:Equip(inst)
                    inst.disablethuriblecheck2hm = nil
                end
            elseif percent > 0 and not inst:HasTag("nightvision") then
                -- 启用照明和夜视
                inst:AddTag("nightvision")
                local owner = inst.components.inventoryitem.owner
                if inst.components.equippable:IsEquipped() and owner and owner:HasTag("player") and owner.components.inventory then
                    inst.disablethuriblecheck2hm = true
                    owner.components.inventory:Unequip(EQUIPSLOTS.HANDS)
                    owner.components.inventory:Equip(inst)
                    inst.disablethuriblecheck2hm = nil
                end
            end
        end
    end
    local function delaycheckstatus(inst) if not inst.checkstatustask2hm then inst.checkstatustask2hm = inst:DoTaskInTime(0, checkstatus) end end
    local function DoExtinguishSound(inst, owner)
        inst._soundtask = nil
        (owner ~= nil and owner:IsValid() and owner.SoundEmitter or inst.SoundEmitter):PlaySound("dontstarve/common/fireOut")
    end
    local function PlayExtinguishSound(inst)
        if inst._soundtask == nil and inst:GetTimeAlive() > 0 then
            inst._soundtask = inst:DoTaskInTime(0, DoExtinguishSound, inst.components.inventoryitem and inst.components.inventoryitem.owner)
        end
    end
    local function checknewequip(inst)
        if inst.thurible2hm then
            local equip = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip == nil or not equip:IsValid() or equip == inst.thurible2hm or equip.prefab == "thurible" or not inst.thurible2hm:IsValid() or
                (inst.thurible2hm.components.fueled and inst.thurible2hm.components.fueled.currentfuel <= 0) or
                (inst.thurible2hm.components.inventoryitem and inst.thurible2hm.components.inventoryitem:GetGrandOwner() ~= inst) then
                if inst.checkthuriblestask2hm and inst.thuribleonownerunequip2hm then
                    inst.checkthuriblestask2hm:Cancel()
                    inst.checkthuriblestask2hm = nil
                    inst:RemoveEventCallback("equip", checknewequip)
                    inst:RemoveEventCallback("unequip", inst.thuribleonownerunequip2hm)
                    inst.thuribleonownerunequip2hm = nil
                end
                if inst.thuriblesmoke2hm and inst.thuriblesmoke2hm:IsValid() then inst.thuriblesmoke2hm:Remove() end
                inst.thuriblesmoke2hm = nil
                if equip ~= inst.thurible2hm and inst.thurible2hm:IsValid() and inst.thurible2hm.components.fueled and
                    inst.thurible2hm.components.fueled.consuming then
                    inst.thurible2hm.components.fueled:StopConsuming()
                    PlayExtinguishSound(inst.thurible2hm)
                end
                if inst.thurible2hm:IsValid() then
                    inst.thurible2hm.bindplayer2hm = nil
                    if equip ~= inst.thurible2hm then inst.thurible2hm:RemoveTag("shadowlure") end
                    local thurible = inst.thurible2hm
                    inst.thurible2hm = nil
                    return checkstatus(thurible)
                else
                    inst.thurible2hm = nil
                end
            elseif not inst.thurible2hm.bindplayer2hm then
                if inst.thurible2hm.components.fueled and not inst.thurible2hm.components.fueled.consuming then
                    inst.thurible2hm.components.fueled:StartConsuming()
                end
                inst.thurible2hm.bindplayer2hm = inst
                inst.thurible2hm:AddTag("shadowlure")
                if not inst.thuriblesmoke2hm then
                    inst.thuriblesmoke2hm = SpawnPrefab("thurible_smoke")
                    inst.thuriblesmoke2hm.entity:AddFollower()
                    inst.thuriblesmoke2hm.Follower:FollowSymbol(inst.GUID, "swap_object", 68, -70, 0)
                end
                return checkstatus(inst.thurible2hm)
            elseif inst.thurible2hm.components.fueled and not inst.thurible2hm.components.fueled.consuming then
                inst.thurible2hm.components.fueled:StartConsuming()
            end
        end
    end
    local function onownerunequip(inst) inst:DoTaskInTime(0, checknewequip) end
    local rate = 5
    AddPrefabPostInit("thurible", function(inst)
        if not TheWorld.ismastersim then return end
        inst.checkstatus2hm = checkstatus
        inst:DoTaskInTime(0, checkstatus)
        inst:ListenForEvent("equipped", delaycheckstatus)
        inst:ListenForEvent("unequipped", delaycheckstatus)
        inst:ListenForEvent("ondropped", delaycheckstatus)
        inst:ListenForEvent("onputininventory", delaycheckstatus)
        inst:ListenForEvent("onfueldsectionchanged", delaycheckstatus)
        inst:ListenForEvent("entitysleep", delaycheckstatus)
        inst:ListenForEvent("entitywake", delaycheckstatus)
        if hardmode and inst.components.fueled then inst.components.fueled.rate_modifiers:SetModifier(inst.prefab, rate / 2, "2hm") end
        if inst.components.equippable then
            local onunequipfn = inst.components.equippable.onunequipfn
            inst.components.equippable.onunequipfn = function(inst, owner, ...)
                if inst:IsValid() and owner and owner:IsValid() and owner:HasTag("player") and inst.components.fueled and inst.components.fueled.currentfuel > 0 and
                    not inst.disablethuriblecheck2hm then
                    if owner.thurible2hm and owner.thurible2hm:IsValid() then
                        if owner.thurible2hm.components.fueled and owner.thurible2hm.components.fueled.consuming then
                            owner.thurible2hm.components.fueled:StopConsuming()
                        end
                        owner.thurible2hm.bindplayer2hm = nil
                        owner.thurible2hm:RemoveTag("shadowlure")
                    end
                    owner.thurible2hm = inst
                    if not owner.checkthuriblestask2hm and not owner.thuribleonownerunequip2hm then
                        owner.checkthuriblestask2hm = owner:DoPeriodicTask(1, checknewequip)
                        owner:ListenForEvent("equip", checknewequip)
                        owner.thuribleonownerunequip2hm = onownerunequip
                        owner:ListenForEvent("unequip", owner.thuribleonownerunequip2hm)
                    end
                    owner:DoTaskInTime(0, checknewequip)
                end
                return onunequipfn(inst, owner, ...)
            end
        end
    end)
    if hardmode then TUNING.THURIBLE_FUEL_MAX = TUNING.THURIBLE_FUEL_MAX * rate end
end

-- 骨头头盔影怪助战,召唤出的影怪会协助攻击但会因此消耗耐久
if GetModConfigData("Bone Helm No Remove") then
    local function locktarget(v, target)
        v:AddChild(SpawnPrefab("shadow_teleport_out2hm"))
        -- SpawnPrefab("shadow_teleport_out2hm").Transform:SetPosition(v.Transform:GetWorldPosition())
        local oldtargetfn = v.components.combat.targetfn
        v.components.combat:SetRetargetFunction(v.components.combat.retargetperiod or 3, function(...)
            if target:IsValid() and not target:IsInLimbo() and target ~= v then return target, true end
            local target, forcechange = oldtargetfn(...)
            return target, forcechange
        end)
        v.locktarget2hm = target
        v.disableexchange2hm = true
        v.disabledeath2hm = true
        if v.components.lootdropper and (v.components.lootdropper.loot or v.components.lootdropper.chanceloottable) then
            v.components.lootdropper:SetLoot()
            v.components.lootdropper:SetChanceLootTable()
            v.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            v.components.lootdropper.GenerateLoot = emptytablefn
            v.components.lootdropper.DropLoot = emptytablefn
        end
        v.components.combat:SuggestTarget(target)
        v.persists = false
        v:AddTag("companion")
        if v:HasTag("shadow") then v:RemoveTag("shadow") end
        v:ListenForEvent("entitysleep", function() v.wantstodespawn = true end, target)
        v:ListenForEvent("enterlimbo", function() v.wantstodespawn = true end, target)
        v:ListenForEvent("onremove", function() v.wantstodespawn = true end, target)
    end
    local shadowcreatures = {"terrorbeak", "crawlinghorror", "oceanhorror", "dreadeye"}
    local function OnHitOther(inst, data)
        local target = data and data.target or data.attacker
        if not (target and target:IsValid() and target.components.health and not target.components.health:IsDead() and target ~= inst) then return end
        local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if not (equip and equip:IsValid() and equip.prefab == "skeletonhat" and equip.components.armor and equip.components.armor:GetPercent() > 0) then
            return
        end
        inst.skeletonhatlocktarget2hm = target
        equip.locktarget2hm = target
        -- 驱使影怪攻击敌人,并记录该敌人从而后续召唤的影怪也会自动仇恨该敌人
        local handsequip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 36, {"shadowcreature"}, {"player", "INLIMBO"})
        for i, ent in ipairs(ents) do
            if ent and ent:IsValid() and not ent.locktarget2hm and ent.Transform and ent.components.health and not ent.components.health:IsDead() and
                ent.components.combat and table.contains(shadowcreatures, ent.prefab) then
                locktarget(ent, target)
                local needpercent = 0.05 * ent.components.health:GetPercent()
                if handsequip and handsequip:IsValid() and handsequip.prefab == "thurible" and handsequip.components.fueled and
                    handsequip.components.fueled:GetPercent() >= needpercent then
                    handsequip.components.fueled:SetPercent(math.clamp(0, handsequip.components.fueled:GetPercent() - needpercent, 1))
                else
                    equip.components.armor:SetPercent(math.clamp(0, equip.components.armor:GetPercent() - needpercent, 1))
                    if equip.components.armor:GetPercent() <= 0 then return end
                end
            end
        end
    end
    local function checkstatus(inst)
        if inst.components.armor and inst.components.inventoryitem and inst.components.equippable and inst.persists then
            local owner = inst.components.inventoryitem.owner
            local percent = inst.components.armor:GetPercent()
            if owner and owner:IsValid() and owner.components.sanity and inst.components.equippable:IsEquipped() then
                owner.components.sanity:SetInducedInsanity(inst, percent > 0)
            end
            inst.components.equippable.dapperness = percent > 0 and TUNING.CRAZINESS_MED or 0
            inst.components.armor.absorb_percent = percent > 0 and TUNING.ARMOR_SKELETONHAT_ABSORPTION or 0
            if percent > 0 and inst.components.equippable:IsEquipped() and owner and owner:IsValid() and owner:HasTag("player") and
                (not hardmode or owner:HasTag("shadowmagic")) then
                if inst.owner2hm and inst.owner2hm:IsValid() and inst.owner2hm ~= owner then
                    inst.owner2hm:RemoveEventCallback("newcombattarget", OnHitOther)
                    inst.owner2hm:RemoveEventCallback("attacked", OnHitOther)
                end
                inst.owner2hm = owner
                owner:ListenForEvent("newcombattarget", OnHitOther)
                owner:ListenForEvent("attacked", OnHitOther)
            elseif (percent <= 0 or not inst.components.equippable:IsEquipped()) then
                if inst.locktarget2hm then inst.locktarget2hm = nil end
                if inst.owner2hm and inst.owner2hm:IsValid() then
                    inst.owner2hm:RemoveEventCallback("newcombattarget", OnHitOther)
                    inst.owner2hm:RemoveEventCallback("attacked", OnHitOther)
                    if inst.owner2hm.skeletonhatlocktarget2hm then inst.owner2hm.skeletonhatlocktarget2hm = nil end
                end
                inst.owner2hm = nil
                -- 头盔失效时,驱散附近没有被驱使的影怪
                if not POPULATING and not inst.disablethuriblecheck2hm then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local ents = TheSim:FindEntities(x, y, z, 36, {"shadowcreature"}, {"player", "INLIMBO"})
                    for _, ent in ipairs(ents) do
                        if ent and ent:IsValid() and ent.components.health and not ent.components.health:IsDead() and not ent.locktarget2hm and
                            table.contains(shadowcreatures, ent.prefab) then
                            ent.disableexchange2hm = true
                            ent.disabledeath2hm = true
                            ent.wantstodespawn = true
                            if ent.components.lootdropper and (ent.components.lootdropper.loot or ent.components.lootdropper.chanceloottable) then
                                ent.components.lootdropper:SetLoot()
                                ent.components.lootdropper:SetChanceLootTable()
                                ent.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
                                ent.components.lootdropper.GenerateLoot = emptytablefn
                                ent.components.lootdropper.DropLoot = emptytablefn
                            end
                            ent.components.health:Kill()
                        end
                    end
                end
            end
        end
    end
    local function onpercent(inst, data)
        if data and data.percent then
            if not inst.armorpercent2hm or (inst.armorpercent2hm <= 0 and data.percent > 0) then checkstatus(inst) end
            inst.armorpercent2hm = data.percent
        end
    end
    AddPrefabPostInit("skeletonhat", function(inst)
        inst.repairmaterials2hm = {nightmarefuel = TUNING.ARMOR_SKELETONHAT / 10}
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
        if inst.components.armor then
            inst.components.armor:SetKeepOnFinished(true)
            inst.components.armor:SetOnFinished(checkstatus)
            inst:ListenForEvent("percentusedchange", onpercent)
        end
        inst.checkstatus2hm = checkstatus
        inst:DoTaskInTime(0, checkstatus)
        inst:ListenForEvent("equipped", checkstatus)
        inst:ListenForEvent("unequipped", checkstatus)
    end)
    -- 影怪出现后,自动被驱使攻击
    local function initshadowcreature(inst)
        if not inst:IsAsleep() and not inst.locktarget2hm and inst.components.health and not inst.components.health:IsDead() and inst.components.combat then
            local spawnedforplayer = inst.spawnedforplayer
            if not (spawnedforplayer and spawnedforplayer:IsValid() and spawnedforplayer.skeletonhatlocktarget2hm) then
                for _, player in ipairs(AllPlayers) do
                    if player and player:IsValid() and not player:HasTag("playerghost") and player.skeletonhatlocktarget2hm and player:IsNear(inst, 36) then
                        spawnedforplayer = player
                        break
                    end
                end
            end
            if not (spawnedforplayer and spawnedforplayer:IsValid() and spawnedforplayer.skeletonhatlocktarget2hm and spawnedforplayer.components.inventory) then
                return
            end
            local equip = spawnedforplayer.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
            if equip and equip:IsValid() and equip.prefab == "skeletonhat" and equip.persists and equip.components.armor and equip.components.armor:GetPercent() >
                0 and equip.locktarget2hm and equip.locktarget2hm:IsValid() and equip.locktarget2hm.components.health and
                not equip.locktarget2hm.components.health:IsDead() and
                (inst:IsNear(equip.locktarget2hm, 36) or spawnedforplayer:IsNear(equip.locktarget2hm, 36)) then
                locktarget(inst, equip.locktarget2hm)
                local handsequip = spawnedforplayer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                local needpercent = 0.05 * inst.components.health:GetPercent()
                if handsequip and handsequip:IsValid() and handsequip.prefab == "thurible" and handsequip.components.fueled and
                    handsequip.components.fueled:GetPercent() >= needpercent then
                    handsequip.components.fueled:SetPercent(math.clamp(0, handsequip.components.fueled:GetPercent() - needpercent, 1))
                else
                    equip.components.armor:SetPercent(math.clamp(0, equip.components.armor:GetPercent() - needpercent, 1))
                end
            end
        end
    end
    local function delayinitshadowcreature(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, initshadowcreature)
        inst:DoTaskInTime(0.5, initshadowcreature)
    end
    for index, value in ipairs(shadowcreatures) do AddPrefabPostInit(value, delayinitshadowcreature) end
end

-- 甲板照明灯装备头部
if GetModConfigData("Deck Illuminator Equip Head") then
    local LIGHT_RADIUS = {MIN = 2, MAX = 5}
    local LIGHT_COLOUR = Vector3(180 / 255, 195 / 255, 150 / 255)
    local LIGHT_INTENSITY = {MIN = 0.4, MAX = 0.8}
    local LIGHT_FALLOFF = .9
    local function lamp_fuelupdate(inst)
        if inst._light ~= nil and inst._light:IsValid() then
            local fuelpercent = inst.components.fueled:GetPercent()
            inst._light.Light:SetIntensity(Lerp(LIGHT_INTENSITY.MIN, LIGHT_INTENSITY.MAX, fuelpercent))
            inst._light.Light:SetRadius(Lerp(LIGHT_RADIUS.MIN, LIGHT_RADIUS.MAX, fuelpercent))
            inst._light.Light:SetFalloff(LIGHT_FALLOFF)
        end
    end
    local function lamp_turnoff(inst)
        inst.components.fueled:StopConsuming()
        if inst._lamp ~= nil and inst._lamp:IsValid() then
            inst._lamp:PushEvent("mast_lamp_off")
            inst._lamp.AnimState:PlayAnimation("off", true)
        end
        if inst._light and inst._light:IsValid() then inst._light.Light:Enable(false) end
    end
    local function lamp_turnon(inst)
        if not inst.components.fueled:IsEmpty() and inst.components.equippable:IsEquipped() then
            inst.components.fueled:StartConsuming()
            if inst._lamp ~= nil and inst._lamp:IsValid() then
                inst._lamp:PushEvent("mast_lamp_on")
                inst._lamp.AnimState:PlayAnimation("full", true)
            end
            if inst._light and inst._light:IsValid() then inst._light.Light:Enable(true) end
            lamp_fuelupdate(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
        end
    end
    local function onequiplamp(inst, owner)
        local upgrade_prefab = inst.upgrade_override or "mastupgrade_lamp"
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent("equipskinneditem", inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol("swap_hat", skin_build, "swap_hat", inst.GUID, upgrade_prefab)
        else
            owner.AnimState:OverrideSymbol("swap_hat", upgrade_prefab, "swap_hat")
        end
        owner.AnimState:ClearOverrideSymbol("headbase_hat")
        owner.AnimState:Show("HAT")
        owner.AnimState:Show("HAIR_HAT")
        -- owner.AnimState:Hide("HAIR_NOHAT")
        -- owner.AnimState:Hide("HAIR")
        if owner:HasTag("player") then
            -- owner.AnimState:Hide("HEAD")
            owner.AnimState:Show("HEAD_HAT")
            owner.AnimState:Show("HEAD_HAT_NOHELM")
            -- owner.AnimState:Hide("HEAD_HAT_HELM")
        end
        if inst._lamp == nil or not inst._lamp:IsValid() then
            if inst.linked_skinname then
                inst._lamp = SpawnPrefab(upgrade_prefab, inst.linked_skinname, inst.skin_id)
            else
                inst._lamp = SpawnPrefab(upgrade_prefab)
            end
            inst._lamp.Transform:SetScale(0.8, 0.8, 0.8)
            inst._lamp.AnimState:PlayAnimation("off", true)
            -- inst._lamp.AnimState:SetLayer(LAYER_BACKGROUND)
            inst._lamp._mast = owner
            inst._lamp.entity:SetParent(owner.entity)
            inst._lamp.entity:AddFollower():FollowSymbol(owner.GUID, "swap_hat", 0, -180, 0)
            inst._lamp.AnimState:SetInheritsSortKey(false)
        end
        if inst._light == nil or not inst._light:IsValid() then
            inst._light = SpawnPrefab("minerhatlight")
            inst._light.entity:SetParent(owner.entity)
            inst._light.Light:SetColour(LIGHT_COLOUR.x, LIGHT_COLOUR.y, LIGHT_COLOUR.z)
            lamp_fuelupdate(inst)
            inst._light.Light:Enable(false)
        end
        lamp_turnon(inst)
    end
    local function onunequiplamp(inst, owner)
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then owner:PushEvent("unequipskinneditem", inst:GetSkinName()) end
        owner.AnimState:ClearOverrideSymbol("headbase_hat")
        owner.AnimState:ClearOverrideSymbol("swap_hat")
        owner.AnimState:Hide("HAT")
        owner.AnimState:Hide("HAIR_HAT")
        owner.AnimState:Show("HAIR_NOHAT")
        owner.AnimState:Show("HAIR")
        if owner:HasTag("player") then
            owner.AnimState:Show("HEAD")
            owner.AnimState:Hide("HEAD_HAT")
            owner.AnimState:Hide("HEAD_HAT_NOHELM")
            owner.AnimState:Hide("HEAD_HAT_HELM")
        end
        if inst._lamp and inst._lamp:IsValid() then
            inst._lamp:Remove()
            inst._lamp = nil
        end
        if inst._light and inst._light:IsValid() then
            inst._light:Remove()
            inst._light = nil
        end
        lamp_turnoff(inst)
    end
    local function upgradelamp(inst)
        inst:AddTag("firefuellight")
        inst:AddTag("waterproofer")
        if not TheWorld.ismastersim then return end
        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)
        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip(onequiplamp)
        inst.components.equippable:SetOnUnequip(onunequiplamp)
        inst.components.equippable.walkspeedmult = TUNING.ICEHAT_SPEED_MULT
        inst:AddComponent("fueled")
        inst.components.fueled:InitializeFuelLevel(TUNING.MAST_LAMP_LIGHTTIME)
        inst.components.fueled:SetDepletedFn(lamp_turnoff)
        inst.components.fueled:SetUpdateFn(lamp_fuelupdate)
        inst.components.fueled:SetTakeFuelFn(lamp_turnon)
        inst.components.fueled:SetFirstPeriod(TUNING.TURNON_FUELED_CONSUMPTION, TUNING.TURNON_FULL_FUELED_CONSUMPTION)
        inst.components.fueled.accepting = true
        inst.components.fueled.canbespecialextinguished = true
    end
    AddPrefabPostInit("mastupgrade_lamp_item", upgradelamp)
    AddPrefabPostInit("mastupgrade_lamp_item_yotd", upgradelamp)
end

-- 眼球伞自愈隔热
if GetModConfigData("Eyebrella Swell Shade") then
    require("eyebrellashade2hm").Install(hardmode, AddPrefabPostInit, AddComponentPostInit)
end

-- 恐怖盾牌增强
if GetModConfigData("Shieldofterror Eat Owner") then
    local function eattarget(inst, target, owner, value)
        if not target.components.health then return end
        local current = target.components.health.currenthealth
        local v = math.abs(target.components.health:DoDelta(-value, nil, owner.nameoverride or owner.prefab or "NIL", nil, owner) or value)
        if target.components.health:IsDead() then
            v = current
            if owner ~= nil then owner:PushEvent("killed", {victim = target, attacker = owner}) end
            if target.components.combat and target.components.combat.onkilledbyother ~= nil then
                target.components.combat.onkilledbyother(target, owner)
            end
        end
        -- if target.Transform and owner ~= nil and owner.Transform then
        --     local fx = SpawnPrefab(math.random() < .5 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
        --     local x, y, z = target.Transform:GetWorldPosition()
        --     fx.Transform:SetPosition(x, y + 1.5, z)
        --     fx.Transform:SetRotation(owner.Transform:GetRotation())
        -- end
        if v <= 0 then return end
        -- if owner.SoundEmitter and inst.sound2hm then owner.SoundEmitter:PlaySound(inst.sound2hm) end
        if inst.components.armor:GetPercent() < 1 then
            local need = inst.components.armor.maxcondition - inst.components.armor.condition
            inst.components.armor:Repair(v * 2)
            if v <= need / 2 then return end
            v = v - need / 2
        end
        if owner and owner:IsValid() and not (owner.components.health and owner.components.health:IsDead()) then
            if owner.components.health and not owner.components.oldager and owner.components.health:GetPercent() < 1 then
                local current = owner.components.health.currenthealth
                owner.components.health:DoDelta(v / 8, nil, inst.prefab, nil, inst)
                local need = owner.components.health.currenthealth - current
                if v <= need * 8 then return end
                v = v - need * 8
            end
            if owner.components.hunger and owner.components.hunger:GetPercent() < 1 then owner.components.hunger:DoDelta(v / 6, nil, true) end
        end
    end
    local nocreaturetags = {
        "veggie",
        "structure",
        "wall",
        "balloon",
        "groundspike",
        "smashable",
        "companion",
        "equipmentmodel",
        "shadow",
        "shadowcreature",
        "shadowthrall",
        "nightmarecreature",
        "shadowchesspiece",
        "brightmare",
        "pigelite",
		"card"
    }
    local function IsValidVictim(victim)
        return victim.components.health and not victim.components.health:IsDead() and victim.components.combat and
            IsLifeDrainable(victim) and not victim:HasOneOfTags(nocreaturetags)
    end
    local function endeatattackertask(inst) inst.eatattacker2hmtask = nil end
    local function onattacked(inst, owner, data)
        if inst:IsValid() and owner and owner:IsValid() and not inst.eatattacker2hmtask and inst.components.armor and data and data.attacker and
            data.attacker:IsValid() and owner:IsNear(data.attacker, 4) and IsValidVictim(data.attacker) and
            (data.weapon == nil or
                (data.weapon.components.projectile == nil and (data.weapon.components.weapon == nil or data.weapon.components.weapon.projectile == nil))) then
            inst.eatattacker2hmtask = inst:DoTaskInTime(2, endeatattackertask)
            eattarget(inst, data.attacker, owner, 17)
        end
    end
    local function onhitother(inst, owner, data)
        local mount = owner and owner:IsValid() and owner.components.rider and owner.components.rider:IsRiding()
        if mount then return end
        if inst:IsValid() and owner and owner:IsValid() and not inst.eatattacker2hmtask and inst.components.armor and data and data.target and
            data.target:IsValid() and owner:IsNear(data.target, 4) and IsValidVictim(data.target) and owner.components.combat and
            owner.components.combat.lastdoattacktime and
            (not inst.lastdoattacktime2hm or owner.components.combat.lastdoattacktime - inst.lastdoattacktime2hm > 0.3) then
            inst.lastdoattacktime2hm = owner.components.combat.lastdoattacktime
            inst._hitcount2hm = (inst._hitcount2hm or 0) + 1
            if inst._hitcount2hm > 2.5 then
                inst._hitcount2hm = inst._hitcount2hm - 2.5
                inst.eatattacker2hmtask = inst:DoTaskInTime(0.3, endeatattackertask)
                eattarget(inst, data.target, owner, 17)
            end
        end
    end
    local function onequip(inst, data)
        if data and data.owner and data.owner:HasTag("player") then
            inst:ListenForEvent("attacked", inst.onattacked2hm, data.owner)
            if inst.prefab == "shieldofterror" then inst:ListenForEvent("onhitother", inst.onhitother2hm, data.owner) end
        end
    end
    local function onunequip(inst, data)
        if data and data.owner and data.owner:HasTag("player") then
            inst:RemoveEventCallback("attacked", inst.onattacked2hm, data.owner)
            if inst.prefab == "shieldofterror" then inst:RemoveEventCallback("onhitother", inst.onhitother2hm, data.owner) end
        end
    end
    local function endeatownertask(inst) inst.eatownercdtask2hm = nil end
    local function beforeTakeDamage(inst, self, damage)
        if damage and (damage >= self.condition or (not inst.eatownercdtask2hm and (self.condition - damage) / self.maxcondition < 0.5)) then
            local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
            if owner and owner:IsValid() and not owner:HasTag("equipmentmodel") then
                if owner.SoundEmitter and inst.sound2hm and owner.SoundEmitter:PlayingSound(inst.sound2hm) then return end
                local percent = damage >= self.condition and 1 or (1 - math.min((self.condition - damage) / self.maxcondition, 1))
                if owner.components.hunger and owner.components.hunger.current > 0 then
                    local hungerabsorption = inst.components.eater.hungerabsorption
                    if hungerabsorption == 0 or not hungerabsorption then hungerabsorption = 1.75 end
                    local needhunger = math.min(math.min(percent * owner.components.hunger.current, 17) * hungerabsorption, self.maxcondition - self.condition)
                    if needhunger > 0 then
                        self.condition = math.min(self.maxcondition, self.condition + needhunger)
                        owner.components.hunger:DoDelta(-needhunger / hungerabsorption, nil, true)
                        if owner.SoundEmitter and inst.sound2hm then owner.SoundEmitter:PlaySound(inst.sound2hm) end
                        if inst.eatownercdtask2hm then inst.eatownercdtask2hm:Cancel() end
                        inst.eatownercdtask2hm = inst:DoTaskInTime(math.max(0.3, (1 - percent) * 3), endeatownertask)
                    end
                elseif owner.components.health and owner.components.health.currenthealth > 0 then
                    local healthabsorption = inst.components.eater and inst.components.eater.healthabsorption
                    if healthabsorption == 0 or not healthabsorption then healthabsorption = 4 end
                    local needhealth = math.min(math.min(percent * owner.components.health.currenthealth, 17) * healthabsorption,
                                                self.maxcondition - self.condition)
                    if needhealth > 0 then
                        self.condition = math.min(self.maxcondition, self.condition + needhealth)
                        owner.components.health:DoDelta(-needhealth / healthabsorption, nil, inst.prefab, true, inst, true)
                        if owner.SoundEmitter and inst.sound2hm then owner.SoundEmitter:PlaySound(inst.sound2hm) end
                        if inst.eatownercdtask2hm then inst.eatownercdtask2hm:Cancel() end
                        inst.eatownercdtask2hm = inst:DoTaskInTime(math.max(0.3, (1 - percent) * 3), endeatownertask)
                    end
                end
            end
        end
    end
    local function OnUsedAsItem(self, action, doer, target)
        if action == ACTIONS.NET then
            if self:GetPercent() < 0.53 then beforeTakeDamage(self.inst, self, self.maxcondition * 0.03) end
            self:SetPercent(self:GetPercent() - 0.03)
        end
    end
    AddPrefabPostInit("shieldofterror", function(inst)
        if not TheWorld.ismastersim then return end
        inst.sound2hm = "terraria1/eye_shield/eat"
        inst:AddComponent("tool")
        inst.components.tool:SetAction(ACTIONS.NET)
        inst.onattacked2hm = function(owner, data) onattacked(inst, owner, data) end
        inst.onhitother2hm = function(owner, data) onhitother(inst, owner, data) end
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
        if inst.components.armor then
            local TakeDamage = inst.components.armor.TakeDamage
            inst.components.armor.TakeDamage = function(self, damage, ...)
                beforeTakeDamage(self.inst, self, damage)
                TakeDamage(self, damage, ...)
            end
            if not inst.components.armor.OnUsedAsItem then inst.components.armor.OnUsedAsItem = OnUsedAsItem end
        end
    end)
    AddPrefabPostInit("eyemaskhat", function(inst)
        if not TheWorld.ismastersim then return end
        inst.sound2hm = "terraria1/eyemask/eat"
        inst.onattacked2hm = function(owner, data) onattacked(inst, owner, data) end
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
        if inst.components.armor then
            local TakeDamage = inst.components.armor.TakeDamage
            inst.components.armor.TakeDamage = function(self, damage, ...)
                beforeTakeDamage(self.inst, self, damage)
                TakeDamage(self, damage, ...)
            end
        end
    end)
    AddStategraphPostInit("wilson", function(sg)
        local bugnet_start = sg.states.bugnet_start.onenter
        sg.states.bugnet_start.onenter = function(inst, ...)
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and equip.prefab == "shieldofterror" then
                inst.sg:GoToState("bugnet")
                return
            end
            bugnet_start(inst, ...)
        end
        local bugnet = sg.states.bugnet.onenter
        sg.states.bugnet.onenter = function(inst, ...)
            bugnet(inst, ...)
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and equip.prefab == "shieldofterror" then inst.AnimState:PlayAnimation("toolpunch") end
        end
    end)
    AddStategraphPostInit("wilson_client", function(sg)
        local bugnet_start = sg.states.bugnet_start.onenter
        sg.states.bugnet_start.onenter = function(inst, ...)
            bugnet_start(inst, ...)
            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and equip.prefab == "shieldofterror" then inst.sg:GoToState("bugnet") end
        end
        local bugnet = sg.states.bugnet.onenter
        sg.states.bugnet.onenter = function(inst, ...)
            bugnet(inst, ...)
            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and equip.prefab == "shieldofterror" then inst.AnimState:PlayAnimation("toolpunch") end
        end
    end)
end

-- 使用亮茄外壳或绝望石升级你的火把,外壳可以在装备时开启启迪状态同时释放催眠烟雾,绝望石可以召唤黑夜精灵袭击周围对自己有仇恨的敌人
if GetModConfigData("upgrade torch") then
    -- 亮茄尖刺攻击
    local TARGET_MUST_TAGS = {"_combat"}
    local TARGET_CANT_TAGS = {
        "lunarthrall_plant",
        "lunarthrall_plant_end",
        "playerghost",
        "ghost",
        "shadow",
        "shadowminion",
        "FX",
        "INLIMBO",
        "notarget",
        "noattack",
        "fx",
        "flight",
        "invisible"
    }
    local function newchooseaction(inst)
        if inst.components.freezable and inst.components.freezable:IsFrozen() then return end
        inst.target = inst.components.combat.target or FindEntity(inst, TUNING.LUNARTHRALL_PLANT_RANGE, function(guy)
            return guy ~= inst.parent2hm and guy.prefab ~= "lunarthrall_plant_vine" and guy.components.health and inst.components.combat:CanTarget(guy)
        end, TARGET_MUST_TAGS, TARGET_CANT_TAGS) or inst.target
        if not (inst.target and inst.target:IsValid() and inst.target.components.health and not inst.target.components.health:IsDead()) then
            inst.target = nil
            return
        end
        inst.mode = "attack"
        if inst.target and inst.mode == "attack" then
            inst.components.combat:SetTarget(inst.target)
            local dist = inst:GetDistanceSqToInst(inst.target)
            if dist < TUNING.LUNARTHRALL_PLANT_VINE_INITIATE_ATTACK * TUNING.LUNARTHRALL_PLANT_VINE_INITIATE_ATTACK then
                if not inst.components.timer:TimerExists("attack_cooldown") then inst:PushEvent("doattack") end
            elseif inst.target ~= inst.parent2hm then
                local pos = Vector3(inst.target.Transform:GetWorldPosition())
                local theta = inst:GetAngleToPoint(pos) * DEGREES
                local radius = math.sqrt(dist) - TUNING.LUNARTHRALL_PLANT_CLOSEDIST
                local ITERATIONS = 5
                local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
                local newpos = Vector3(inst.Transform:GetWorldPosition())
                local onwater = false
                for i = 1, ITERATIONS do
                    local testpos = newpos + offset * (i / ITERATIONS)
                    if not TheWorld.Map:IsVisualGroundAtPoint(testpos.x, testpos.y, testpos.z) then
                        onwater = true
                        break
                    end
                end
                newpos = newpos + offset
                dist = inst:GetDistanceSqToPoint(newpos)
                local moveback = nil
                for i, nub in ipairs(inst.tails) do
                    local nubdist = nub:GetDistanceSqToPoint(newpos)
                    if nubdist < dist then
                        dist = nubdist
                        moveback = true
                        break
                    end
                end
                if moveback and not onwater then
                    inst:PushEvent("moveback")
                else
                    if #inst.tails < 7 and not onwater then
                        inst:PushEvent("moveforward", {newpos = newpos})
                    else
                        inst:PushEvent("emerge")
                    end
                end
            end
        end
    end
    local function onvinehitother(inst, data)
        if data and data.target and data.target:IsValid() then data.target:AddDebuff("wormwood_vined_debuff", "wormwood_vined_debuff") end
    end
    local function vinedeath(inst) if inst.components.health and not inst.components.health:IsDead() then inst.components.health:Kill() end end
    local function vineback(inst)
        if not inst.target and inst.components.health and not inst.components.health:IsDead() and inst.sg then
            inst.mode = "return"
            inst:PushEvent("moveback")
        end
    end
    local function confirmlunarplanttentacleDespawn(inst)
        if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ~= "attack_pst" then
            inst.sg:GoToState("attack_pst")
            inst:DoTaskInTime(3, inst.Remove)
        else
            inst:Remove()
        end
    end
    local function lunarplanttentacleDespawn(inst)
        if not (inst.components.combat and inst.components.combat.target) then confirmlunarplanttentacleDespawn(inst) end
    end
    local function SpawnVineAttack(inst)
        local parent = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or inst
        local x, y, z = parent.Transform:GetWorldPosition()
        if parent == inst or (parent and not parent:HasTag("moving")) then
            x = x + math.random(1, 8) - 4
            z = z + math.random(1, 8) - 4
        end
        if TheWorld.Map:IsVisualGroundAtPoint(x, y, z) then
            if math.random() < 0.15 then
                local vine = SpawnPrefab("lunarthrall_plant_vine_end")
                vine.parent2hm = parent
                vine.ChooseAction = newchooseaction
                vine.Transform:SetPosition(x, y, z)
                vine.Transform:SetRotation(vine:GetAngleToPoint(x, y, z))
                if vine.sg then
                    vine.sg:RemoveStateTag("nub")
                    vine.sg:GoToState("hit")
                end
                vine:ListenForEvent("onhitother", onvinehitother)
                vine:DoTaskInTime(12, vinedeath)
                vine:DoTaskInTime(4, vineback)
                if vine.components.health then vine.components.health:StartRegen(-20, 1) end
            else
                local tentacle = SpawnPrefab("lunarplanttentacle")
                if tentacle then
                    tentacle.persists = false
                    tentacle.parent2hm = parent
                    tentacle.owner = parent
                    tentacle.Transform:SetPosition(x, y, z)
                    local target = FindEntity(tentacle, TUNING.LUNARTHRALL_PLANT_RANGE, function(guy)
                        return guy ~= parent and guy.prefab ~= "lunarthrall_plant_vine" and guy.components.health and tentacle.components.combat:CanTarget(guy)
                    end, TARGET_MUST_TAGS, TARGET_CANT_TAGS)
                    if target then tentacle.components.combat:SetTarget(target) end
                    tentacle:DoTaskInTime(4, lunarplanttentacleDespawn)
                    tentacle:DoTaskInTime(10, confirmlunarplanttentacleDespawn)
                end
            end
        end
    end
    -- 催眠云雾控制,效果能持续更久到knockout晕倒或sleeping睡着的敌人苏醒
    local function clouddebuffend(ent) end
    local function OnClearCloudProtection2(ent)
        ent.CloudProtectTask2hm2 = nil
        if ent.sg ~= nil and not ent.sg:HasStateTag("waking") and
            ((ent.components.grogginess ~= nil and ent.sg:HasStateTag("knockout")) or (ent.components.sleeper ~= nil and ent.sg:HasStateTag("sleeping"))) then
            ent.CloudProtectTask2hm2 = ent:DoTaskInTime(1, OnClearCloudProtection2)
            return
        end
        if ent:HasTag("player") and ent.components.sanity then
            ent.components.sanity:EnableLunacy(false, "upgradetorch2hm")
            if ent.components.sanity._lunacy_sources then ent.components.sanity._lunacy_sources:SetModifier(ent, nil, "upgradetorch2hm") end
        end
        if not ent:HasTag("player") and ent.components.locomotor then ent.components.locomotor:RemoveExternalSpeedMultiplier(ent, "lunargoopcloud2hm") end
        if ent.cloudcombat2hm then
            ent.cloudcombat2hm = nil
            if ent.components.combat then ent.components.combat.externaldamagetakenmultipliers:RemoveModifier(ent, "upgradetorch2hm") end
        end
    end
    local function OnClearCloudProtection(ent)
        ent.CloudProtectTask2hm = nil
        ent.CloudProtectTask2hm2 = ent:DoTaskInTime(1, OnClearCloudProtection2)
    end
    local function SetCloudProtection(ent, duration)
        if ent:IsValid() then
            if ent.CloudProtectTask2hm2 ~= nil then
                ent.CloudProtectTask2hm2:Cancel()
                ent.CloudProtectTask2hm2 = nil
            end
            if ent.CloudProtectTask2hm ~= nil then ent.CloudProtectTask2hm:Cancel() end
            ent.CloudProtectTask2hm = ent:DoTaskInTime(duration, OnClearCloudProtection)
            if ent:HasTag("player") and ent.components.sanity then ent.components.sanity:EnableLunacy(true, "upgradetorch2hm") end
        end
    end
    local CLOUD_RADIUS = 2.5
    local PHYSICS_PADDING = 3
    local SLEEPER_TAGS = {"player", "sleeper"}
    local SLEEPER_NO_TAGS = {"playerghost", "lunar_aligned", "INLIMBO"}
    local function DoCloudTask(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, y, z, CLOUD_RADIUS + PHYSICS_PADDING, nil, SLEEPER_NO_TAGS, SLEEPER_TAGS)) do
            if v:IsValid() and (v.CloudProtectTask2hm == nil or (v.protectcloud2hm and v.protectcloud2hm ~= inst)) and v.entity:IsVisible() and
                not (v.components.health ~= nil and v.components.health:IsDead()) then
                local range = v:GetPhysicsRadius(0) + CLOUD_RADIUS
                if v:GetDistanceSqToPoint(x, y, z) < range * range then
                    local enable
                    if v.components.combat then
                        v.cloudcombat2hm = math.min((v.cloudcombat2hm or 0) + 1, 5)
                        v.components.combat.externaldamagetakenmultipliers:SetModifier(v, 1 + 0.05 * v.cloudcombat2hm, "upgradetorch2hm")
                        enable = true
                    end
                    if not v:HasTag("player") and v.components.locomotor then
                        v.components.locomotor:SetExternalSpeedMultiplier(v, "lunargoopcloud2hm", v:HasTag("epic") and 0.8 or 0.65)
                        enable = true
                    end
                    if not (v.sg ~= nil and v.sg:HasStateTag("waking")) then
                        if v.components.grogginess ~= nil then
                            if not (v.sg ~= nil and v.sg:HasStateTag("knockout")) then
                                v.components.grogginess:AddGrogginess(TUNING.LUNAR_GRAZER_GROGGINESS, TUNING.LUNAR_GRAZER_KNOCKOUTTIME)
                            end
                            enable = true
                        elseif v.components.sleeper ~= nil then
                            if not (v.sg ~= nil and v.sg:HasStateTag("sleeping")) then
                                v.components.sleeper:AddSleepiness(TUNING.LUNAR_GRAZER_GROGGINESS, TUNING.LUNAR_GRAZER_KNOCKOUTTIME)
                            end
                            enable = true
                        end
                    end
                    if enable then SetCloudProtection(v, 0.5) end
                end
            end
        end
    end
    local function CloudSanityAura(inst, observer) return observer and observer.CloudProtectTask2hm and TUNING.SANITYAURA_MED or TUNING.SANITYAURA_SMALL end
    local function SpawnCloudAttack(inst)
        local cloud = SpawnPrefab("lunar_goop_cloud_fx")
        cloud.persists = false
        cloud:AddComponent("sanityaura")
        cloud.components.sanityaura.aurafn = CloudSanityAura
        local parent = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or inst
        cloud.parent2hm = parent
        cloud.Transform:SetPosition(parent.Transform:GetWorldPosition())
        local time = math.random()
        cloud:DoTaskInTime(5.1 + time, cloud.Remove)
        cloud:DoPeriodicTask(1, DoCloudTask, time)
        if parent and parent:IsValid() and parent:HasTag("activeprojectile") or (parent.sg and parent.sg:HasStateTag("moving")) then
            parent.protectcloud2hm = cloud
            SetCloudProtection(parent, 1.5)
            if inst.waitdelay2hm then inst.waitdelay2hm = nil end
        elseif inst.components.burnable and (inst.waitdelay2hm or 0) > 2 then
            inst.components.burnable:Extinguish()
        else
            inst.waitdelay2hm = (inst.waitdelay2hm or 0) + 1
        end
    end
    -- 毒云灼烧攻击
    local function darkcloudhurthealth(inst, value)
        if inst.components.health and not inst.components.health:IsDead() then inst.components.health:DoDelta(value, nil, "miasma") end
    end
    local function OnDarkCloudHealthDelta(inst, data)
        if data and data.oldpercent and data.newpercent and data.newpercent > data.oldpercent and not inst.components.health:IsDead() then
            inst:DoTaskInTime(0, darkcloudhurthealth,
                              inst.components.health.maxhealth * (data.oldpercent - data.newpercent) * (0.3 + (inst.darkcloudhealth2hm or 1) * 0.05))
        end
    end
    local function OnClearDarkCloudProtection2(ent)
        ent.DarkCloudProtectTask2hm2 = nil
        if ent:HasTag("player") and ent.components.sanity then ent.components.sanity:SetInducedInsanity(ent, false) end
        if not ent:HasTag("player") and ent.components.locomotor then ent.components.locomotor:RemoveExternalSpeedMultiplier(ent, "miasma2hm") end
        if ent.darkcloudhealth2hm then
            ent.darkcloudhealth2hm = nil
            ent:RemoveEventCallback("healthdelta", OnDarkCloudHealthDelta)
        end
    end
    local function OnClearDarkCloudProtection(ent)
        ent.DarkCloudProtectTask2hm = nil
        ent.DarkCloudProtectTask2hm2 = ent:DoTaskInTime(0.5, OnClearDarkCloudProtection2)
    end
    local function SetDarkCloudProtection(ent, duration)
        if ent:IsValid() then
            if ent.DarkCloudProtectTask2hm2 ~= nil then
                ent.DarkCloudProtectTask2hm2:Cancel()
                ent.DarkCloudProtectTask2hm2 = nil
            end
            if ent.DarkCloudProtectTask2hm ~= nil then ent.DarkCloudProtectTask2hm:Cancel() end
            ent.DarkCloudProtectTask2hm = ent:DoTaskInTime(duration, OnClearDarkCloudProtection)
            if ent:HasTag("player") and ent.components.sanity then ent.components.sanity:SetInducedInsanity(ent, true) end
        end
    end
    local MIASMA_RADIUS = 2
    local MIASMA_NO_TAGS = {"playerghost", "ghost", "shadow", "shadowminion", "noauradamage", "FX", "INLIMBO", "notarget", "noattack", "flight", "invisible"}
    local function DoDarkCloudTask(inst)
        if inst.task == nil and inst.StartAllWatchers then inst:StartAllWatchers() end
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, y, z, MIASMA_RADIUS + PHYSICS_PADDING, nil, MIASMA_NO_TAGS)) do
            if v:IsValid() and (v.DarkCloudProtectTask2hm == nil or (v.protectcloud2hm and v.protectcloud2hm ~= inst)) and v.entity:IsVisible() and
                v.components.health ~= nil and not v.components.health:IsDead() and
                (v.components.inventory == nil or not v.components.inventory:EquipHasTag("miasmaimmune")) then
                local range = v:GetPhysicsRadius(0) + MIASMA_RADIUS
                if v:GetDistanceSqToPoint(x, y, z) < range * range then
                    if v.protectcloud2hm then v.protectcloud2hm = nil end
                    if not v:HasTag("player") and v.components.locomotor then
                        v.components.locomotor:SetExternalSpeedMultiplier(v, "miasma2hm", v:HasTag("epic") and 0.8 or 0.65)
                    end
                    if v.darkcloudhealth2hm == nil then
                        v.darkcloudhealth2hm = 1
                        v:ListenForEvent("healthdelta", OnDarkCloudHealthDelta)
                    else
                        v.darkcloudhealth2hm = math.min(v.darkcloudhealth2hm + 1, 3)
                    end
                    if not v:HasTag("player") then
                        v.components.health:DoDelta(TUNING.MIASMA_DEBUFF_TICK_VALUE * 2, nil, "miasma")
                        if not v.components.health.takingfiredamage then
                            v.components.health.takingfiredamage = true
                            v.components.health.takingfiredamagestarttime = GetTime()
                            v:StartUpdatingComponent(v.components.health)
                        end
                        v.components.health.lastfiredamagetime = GetTime()
                    end
                    SetDarkCloudProtection(v, 0.25)
                end
            end
        end
    end
    local function DarkCloudSanityAura(inst, observer)
        return observer and observer.DarkCloudProtectTask2hm and -TUNING.SANITYAURA_MED or -TUNING.SANITYAURA_SMALL
    end
    local function SpawnDarkCloudAttack(inst)
        local cloud = SpawnPrefab("miasma_cloud")
        cloud.OnEntityWake = nil
        cloud.persists = false
        cloud:AddComponent("sanityaura")
        cloud.components.sanityaura.aurafn = DarkCloudSanityAura
        -- cloud.StartAllWatchers = nilfn
        local parent = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or inst
        local x, y, z = parent.Transform:GetWorldPosition()
        if parent == inst then
            x = x + math.random() * 8 - 4
            z = z + math.random() * 8 - 4
        end
        cloud.parent2hm = parent
        cloud.Transform:SetPosition(x, y, z)
        local time = math.random() * .5
        cloud:DoTaskInTime(5.1 + time, cloud.Remove)
        cloud:DoPeriodicTask(0.5, DoDarkCloudTask, time)
        if parent and parent:IsValid() and parent:HasTag("activeprojectile") or (parent.sg and parent.sg:HasStateTag("moving")) then
            if parent:HasTag("player") and cloud.watchers_exiting then cloud.watchers_exiting[parent] = true end
            parent.protectcloud2hm = cloud
            SetDarkCloudProtection(parent, 0.75)
            if inst.waitdelay2hm then inst.waitdelay2hm = nil end
        elseif inst.components.burnable and (inst.waitdelay2hm or 0) > 3 then
            inst.components.burnable:Extinguish()
        else
            inst.waitdelay2hm = (inst.waitdelay2hm or 0) + 1
        end
    end
    -- 工作
    local function stopwork(inst)
        if inst.task2hm ~= nil then
            inst.task2hm:Cancel()
            inst.task2hm = nil
        end
        if inst.protectcloud2hm then inst.protectcloud2hm = nil end
        if inst.waitdelay2hm then inst.waitdelay2hm = nil end
    end
    local function startwork(inst)
        if inst.fires then
            for i, fx in ipairs(inst.fires) do fx:Remove() end
            inst.fires = {}
        end
        if not inst.task2hm then
            if inst.upgrade2hm == "lunarplant_husk" then inst.task2hm = inst:DoPeriodicTask(0.75, SpawnVineAttack) end
            if inst.upgrade2hm == "purebrilliance" then inst.task2hm = inst:DoPeriodicTask(1, SpawnCloudAttack) end
            if inst.upgrade2hm == "dreadstone" then
                inst.task2hm = inst:DoPeriodicTask(0.5, SpawnDarkCloudAttack)
                local parent = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or inst
                if parent ~= nil and parent._shadowdsubmissive_task == nil and inst.components.shadowdominance then
                    parent:AddTag("shadowdominance")
                end
            end
        end
    end
    local function sleepstopwork(inst) if inst.upgrade2hm and inst.components.burnable and inst.components.burnable:IsBurning() then stopwork(inst) end end
    local function wakestartwork(inst) if inst.upgrade2hm and inst.components.burnable and inst.components.burnable:IsBurning() then startwork(inst) end end
    local function checkstatus(inst)
        inst.checkstatustask2hm = nil
        if inst.components.burnable and inst.components.burnable:IsBurning() then
            if inst:HasTag("fire") then inst:RemoveTag("fire") end
            startwork(inst)
        else
            stopwork(inst)
        end
    end
    local function onignite(inst, data)
        if inst.upgrade2hm then
            if inst.checkstatustask2hm then inst.checkstatustask2hm:Cancel() end
            if inst:HasTag("fire") then inst:RemoveTag("fire") end
            inst.checkstatustask2hm = inst:DoTaskInTime(0, checkstatus)
        end
    end
    local function onextinguish(inst, data)
        if inst.upgrade2hm then
            if inst.fires then
                for i, fx in ipairs(inst.fires) do fx:Remove() end
                inst.fires = {}
            end
            if inst.checkstatustask2hm then inst.checkstatustask2hm:Cancel() end
            inst.checkstatustask2hm = inst:DoTaskInTime(0, checkstatus)
        end
    end
    local function onsave(inst, data) data.upgrade2hm = inst.upgrade2hm end
    local function onload(inst, data)
        if data and data.upgrade2hm then
            inst.upgrade2hm = data.upgrade2hm
            inst.components.repairable2hm.ignoremax = nil
            if inst.components.weapon then inst.components.weapon:SetOnAttack() end
            if inst.components.lighter then inst:RemoveComponent("lighter") end
            if inst.upgrade2hm == "lunarplant_husk" then
                inst:AddTag("lunarplant2hm")
                inst.repairmaterials2hm.purebrilliance = nil
                inst.repairmaterials2hm.dreadstone = nil
            end
            if inst.upgrade2hm == "purebrilliance" then
                inst:AddTag("brilliance2hm")
                inst.components.fueled:InitializeFuelLevel(TUNING.TORCH_FUEL * 4)
                inst.repairmaterials2hm.lunarplant_husk = nil
                inst.repairmaterials2hm.dreadstone = nil
                inst:AddTag("gestaltprotection")
            end
            if inst.upgrade2hm == "dreadstone" then
                inst:AddTag("dreadstone2hm")
                inst.components.fueled:InitializeFuelLevel(TUNING.TORCH_FUEL * 4)
                inst.repairmaterials2hm.lunarplant_husk = nil
                inst.repairmaterials2hm.purebrilliance = nil
                inst:AddComponent("shadowdominance")
            end
            inst.clientupgrade2hm:set(true)
        end
    end
    local function onrepaired(inst, repairuse, doer, repair_item, useitems)
        if inst.upgrade2hm then return end
        onload(inst, {upgrade2hm = repair_item and repair_item.prefab})
        checkstatus(inst)
    end
    local function DisplayNameFn(inst)
        if inst:HasTag("lunarplant2hm") then return (TUNING.isCh2hm and "亮茄" or "Brightshade ") .. STRINGS.NAMES.TORCH end
        if inst:HasTag("brilliance2hm") then return STRINGS.NAMES.PUREBRILLIANCE .. (TUNING.isCh2hm and "" or " ") .. STRINGS.NAMES.TORCH end
        if inst:HasTag("dreadstone2hm") then return (TUNING.isCh2hm and "绝望石" or "Dreadstone ") .. STRINGS.NAMES.TORCH end
    end
    local function itemtilefn(inst)
        if not inst.bgimage2hm then
            if inst:HasTag("lunarplant2hm") then inst.bgimage2hm = "lunarplant_husk.tex" end
            if inst:HasTag("brilliance2hm") then inst.bgimage2hm = "purebrilliance.tex" end
            if inst:HasTag("dreadstone2hm") then inst.bgimage2hm = "dreadstone.tex" end
            if inst.bgimage2hm then inst.bgaltas2hm = GetInventoryItemAtlas(inst.bgimage2hm) end
        end
        return "upgrade2hmdirty", nil, inst.bgaltas2hm, inst.bgimage2hm
    end
    AddPrefabPostInit("torch", function(inst)
        inst.repairmaterials2hm = {lunarplant_husk = TUNING.TORCH_FUEL, purebrilliance = TUNING.TORCH_FUEL * 4, dreadstone = TUNING.TORCH_FUEL * 4}
        inst.displaynamefn = DisplayNameFn
        inst.itemtilefn2hm = itemtilefn
        inst.clientupgrade2hm = net_bool(inst.GUID, "torch.upgrade2hm", "upgrade2hmdirty")
        inst.clientupgrade2hm:set(false)
        if not TheWorld.ismastersim then return end
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.ignoremax = true
        inst.components.repairable2hm.onrepaired = onrepaired
        inst:ListenForEvent("onremove", stopwork)
        inst:ListenForEvent("entitysleep", sleepstopwork)
        inst:ListenForEvent("entitywake", wakestartwork)
        inst:ListenForEvent("onignite", onignite)
        inst:ListenForEvent("onextinguish", onextinguish)
        SetOnSave(inst, onsave)
        SetOnLoad(inst, onload)
    end)
end

-- 月熠奔雷/月熠晨星,装备时可以月熠充电
if GetModConfigData("Moongleam Weapon") then
    local Image = require "widgets/image"
    -- 储备月熠后的武器每5次攻击消耗1次耐久
    local function makeweaponconsumemoongleam(inst, fn)
        local OnAttack = inst.components.weapon.OnAttack
        inst.components.weapon.OnAttack = function(self, attacker, target, ...)
            if inst.moongleamlevel2hm:value() > 0 and attacker and attacker:IsValid() and attacker.components.combat and target and target:IsValid() then
                if attacker.components.combat.ignorehitrange then
                    if self.attackwear ~= 0 and not TheWorld:HasTag("cave") and math.random() < 0.01 * inst.moongleamlevel2hm:value() then
                        SpawnPrefab("lightning").Transform:SetPosition(target.Transform:GetWorldPosition())
                    end
                elseif attacker.components.combat.lastdoattacktime and
                    (not self.lastdoattacktime2hm or attacker.components.combat.lastdoattacktime - self.lastdoattacktime2hm > 0.3) then
                    self.lastdoattacktime2hm = attacker.components.combat.lastdoattacktime
                    self.moongleamidx2hm = (self.moongleamidx2hm or 0) + 1
                    if self.moongleamidx2hm >= 5 then
                        self.moongleamidx2hm = self.moongleamidx2hm - 5
                        if inst.moongleamupgradefn2hm then inst.moongleamupgradefn2hm(self.inst, -1) end
                    end
                end
            end
            OnAttack(self, attacker, target, ...)
        end
    end
    local function cancelmultithrow(inst)
        inst.multithrow2hm = nil
        inst.multithrow2hmdelay = nil
        inst.projectileneedstartpos2hm = nil
        inst.components.weapon.projectiletmp2hm = nil
    end
    local function spellattack(inst, target, pos, doer)
        if doer and doer:IsValid() and doer.components.combat and doer.components.playercontroller and inst.components.weapon and
            not inst.components.weapon.projectile then
            inst:AddTag("projectile")
            local dist = math.clamp(inst.moongleamlevel2hm:value() / 5 + 14, 14, 18)
            if target and not TestCombatTarget2hm(doer, target, 22) then
                if not pos then pos = target:IsValid() and target:GetPosition() or nil end
                target = nil
            end
            if target == nil and pos and pos.x then
                local ents = TheSim:FindEntities(pos.x, 0, pos.z, 4, {"_combat", "_health"}, {"FX", "DECOR", "INLIMBO"})
                for _, ent in ipairs(ents) do
                    if TestCombatTarget2hm(doer, ent, dist + 4) then
                        target = ent
                        break
                    end
                end
            end
            inst:RemoveTag("projectile")
            if target then
                inst.components.weapon.projectiletmp2hm = "bishop_charge"
                inst.projectileneedstartpos2hm = true
                local multithrow2hm = 1
                -- local multithrow2hm = math.clamp(math.min(math.ceil(inst.moongleamlevel2hm:value() / 10),
                --                                           math.ceil(target.components.health.currenthealth / 100)), 1, 3)
                if multithrow2hm > 1 then
                    inst.multithrow2hm = multithrow2hm
                    inst.multithrow2hmdelay = 0.2
                    inst.components.weapon:LaunchProjectile(inst, target)
                    inst:DoTaskInTime(inst.multithrow2hmdelay * multithrow2hm + 10 * FRAMES, cancelmultithrow)
                else
                    inst.components.weapon:LaunchProjectile(inst, target)
                    inst.components.weapon.projectiletmp2hm = nil
                    inst.projectileneedstartpos2hm = nil
                end
                if inst.components.rechargeable then
                    if inst.moongleamlevel2hm:value() >= 20 and not inst.usedrefreshcd2hm then
                        inst.usedrefreshcd2hm = true
                    else
                        if inst.usedrefreshcd2hm then inst.usedrefreshcd2hm = nil end
                        inst.components.rechargeable:Discharge(multithrow2hm * 12)
                    end
                end
                if inst.moongleamupgradefn2hm then inst.moongleamupgradefn2hm(inst, -multithrow2hm) end
            elseif doer.sg and doer.sg.currentstate and doer.sg.currentstate.name == "quickcastspell" then
                doer.sg:GoToState("idle", true)
            end
        end
    end
    local function nightstickstopcd(inst)
        if inst.spellcaster2hm and not inst.components.spellcaster then
            inst:AddComponent("spellcaster")
            inst.components.spellcaster:SetSpellFn(spellattack)
            inst.components.spellcaster.canuseontargets = true
            inst.components.spellcaster.can_cast_fn = truefn
            inst.components.spellcaster.canuseonpoint = true
            inst.components.spellcaster.canuseonpoint_water = true
            inst.components.spellcaster.quickcast = true
        end
    end
    local function nightstickstartcd(inst) if inst.components.spellcaster then inst:RemoveComponent("spellcaster") end end
    STRINGS.ACTIONS.CASTSPELL.NIGHTSTICK2HM = STRINGS.ACTIONS.CASTAOE.SPEAR_WATHGRITHR_LIGHTNING_CHARGED
    -- 晨星给予月熠后，武器基础伤害大幅度提高,且可以远程攻击,连射攻击,0级后恢复原样
    local function nightstickmoongleamupgrade(inst, v)
        local newlevel = math.clamp(inst.moongleamlevel2hm:value() + (v or 1), 0, 40)
        inst.components.weapon:SetDamage(((inst.planarupgrade2hm:value() and TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_DAMAGE or
                                             TUNING.SPEAR_WATHGRITHR_LIGHTNING_DAMAGE) - TUNING.NIGHTSTICK_DAMAGE) * newlevel / 25 + TUNING.NIGHTSTICK_DAMAGE)
        inst.moongleamlevel2hm:set(newlevel)
        if not inst.components.weapon.moongleaminit2hm then makeweaponconsumemoongleam(inst) end
        if newlevel > 0 then
            if newlevel >= 10 then
                if not inst:HasTag("fastrepair2hm") then inst:AddTag("fastrepair2hm") end
            elseif inst:HasTag("fastrepair2hm") then
                inst:RemoveTag("fastrepair2hm")
            end
            if not inst.components.spellcaster then
                inst.spellcaster2hm = true
                inst:AddComponent("spellcaster")
                inst.components.spellcaster:SetSpellFn(spellattack)
                inst.components.spellcaster.canuseontargets = true
                inst.components.spellcaster.can_cast_fn = truefn
                inst.components.spellcaster.canuseonpoint = true
                inst.components.spellcaster.canuseonpoint_water = true
                inst.components.spellcaster.quickcast = true
                if not POPULATING and newlevel < 10 and inst.components.equippable and inst.components.equippable:IsEquipped() then
                    inst.components.rechargeable:Discharge(12)
                end
            end
        else
            if inst:HasTag("fastrepair2hm") then inst:RemoveTag("fastrepair2hm") end
            if inst.spellcaster2hm then
                if inst.components.spellcaster then inst:RemoveComponent("spellcaster") end
                -- if inst.components.rechargeable then
                --     inst:RemoveComponent("rechargeable")
                --     inst:AddTag("rechargeable")
                -- end
                inst.spellcaster2hm = nil
            end
        end
    end
    -- 电羊角武器可以给月熠升级,如果月熠储备已经满额,则多出月熠用来恢复耐久
    local function customrepair(inst, repairuse, doer, repair_item)
        local leftlevel
        if inst.planarupgrade2hm then
            leftlevel = (inst.planarupgrade2hm:value() and 25 or 5) - inst.moongleamlevel2hm:value()
        else
            leftlevel = (inst.upgradeplanar2hm and 25 or 5) - inst.moongleamlevel2hm:value()
        end
        if leftlevel <= 0 then return -1 end
        if repair_item and repair_item:IsValid() and repair_item.components.stackable then
            local neednum = math.min(repair_item.components.stackable.stacksize, leftlevel)
            repair_item.components.stackable:Get(neednum):Remove()
            if inst.components.finiteuses then
                local oldpercent = inst.components.finiteuses:GetPercent()
                inst.components.finiteuses:Repair(neednum * repairuse / 2)
                local newpercent = inst.components.finiteuses:GetPercent()
                if newpercent > 1 then inst.components.finiteuses:SetPercent(math.max(oldpercent, 1)) end
            elseif inst.components.fueled then
                local oldpercent = inst.components.fueled:GetPercent()
                inst.components.fueled:DoDelta(neednum * repairuse / 2, doer)
                local newpercent = inst.components.fueled:GetPercent()
                if newpercent > 1 then inst.components.fueled:SetPercent(math.max(oldpercent, 1)) end
            end
            if inst.moongleamupgradefn2hm then inst.moongleamupgradefn2hm(inst, neednum) end
            return true
        end
    end
    -- 月熠晨星刚装备时也会进入CD,充能且10级以后无装备CD
    local function onequipped(inst, data)
        if inst.binduserid2hm and not POPULATING and data and data.owner then
            if data.owner.userid ~= inst.binduserid2hm then
                inst:DoTaskInTime(0, ForceUnequipWeapon2hm)
            elseif inst.bindusername2hm:value() == "" and data.owner.name then
                inst.bindusername2hm:set(data.owner.name)
            end
        end
        if inst.moongleamlevel2hm:value() > 0 and inst.moongleamlevel2hm:value() < 10 and inst.components.rechargeable then
            inst.components.rechargeable:Discharge(12)
        end
    end
    -- 晨星给予约束静电后，获得移速加成和位面伤害,但也会绑定充能玩家，非充能玩家装备后就掉落
    local function planarupgrade(inst, userid, name)
        if inst.components.fueled then inst:AddTag("moonsparkchargeable") end
        inst.planarupgrade2hm:set(true)
        inst.repairmaterials2hm.moonstorm_static_item = nil
        if not inst.binduserid2hm then inst.binduserid2hm = userid end
        if name and name ~= inst.bindusername2hm:value() then inst.bindusername2hm:set(name) end
        if not inst.components.planardamage then
            inst:AddComponent("planardamage")
            inst.components.planardamage:SetBaseDamage(TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_PLANAR_DAMAGE)
        end
        inst.components.equippable.walkspeedmult = math.max(TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_SPEED_MULT, inst.components.equippable.walkspeedmult or 1)
    end
    -- 晨星可以给予约束静电升级一次
    local function nightstickcustomrepair(inst, repairuse, doer, repair_item)
        if not (doer and doer.userid) then return end
        if repair_item and repair_item:IsValid() and repair_item.prefab == "moonstorm_static_item" then
            if inst.binduserid2hm then return end
            planarupgrade(inst, doer.userid, doer.name)
            if inst.components.fueled then inst.components.fueled:SetPercent(math.max(inst.components.fueled:GetPercent(), 1)) end
            repair_item:Remove()
            return true
        end
        return customrepair(inst, repairuse, doer, repair_item)
    end
    local function itemtilefn(inst, self)
        local leveltext
        local level = inst.moongleamlevel2hm and inst.moongleamlevel2hm:value()
        if level > 0 then
            leveltext = "󰀏" .. tostring(level)
            if not inst.bgimage2hm then
                inst.bgimage2hm = "moonstorm_spark.tex"
                inst.bgaltas2hm = GetInventoryItemAtlas(inst.bgimage2hm)
            end
            inst.spelltype = inst.spelltype or "NIGHTSTICK2HM"
        elseif inst.bgimage2hm then
            inst.bgimage2hm = nil
            inst.bgaltas2hm = nil
        end
        if inst.planarupgrade2hm and inst.planarupgrade2hm:value() and not inst.itemtile_lightning then
            inst.repairmaterials2hm.moonstorm_static_item = nil
            inst.itemtile_lightning = true
            if self.image and not self.image.itemtile_lightning then
                self.image.itemtile_lightning = self.image:AddChild(Image(GetInventoryItemAtlas("itemtile_lightning.tex"), "itemtile_lightning.tex",
                                                                          "default.tex"))
            end
        end
        return "upgrade2hmdirty", leveltext, inst.bgaltas2hm, inst.bgimage2hm
    end
    local function nightstickonload(inst, data)
        if data and data.binduserid2hm then planarupgrade(inst, data.binduserid2hm, data.bindusername2hm) end
        if data and data.moongleam2hm then nightstickmoongleamupgrade(inst, data.moongleam2hm) end
    end
    local function nightstickonsave(inst, data)
        data.moongleam2hm = inst.moongleamlevel2hm:value()
        data.binduserid2hm = inst.planarupgrade2hm:value() and inst.binduserid2hm
        data.bindusername2hm = inst.bindusername2hm:value() ~= "" and inst.bindusername2hm:value()
    end
    local function nightstickDisplayNameFn(inst)
        return (inst.planarupgrade2hm:value() and (TUNING.isCh2hm and "充能" or "Charged ") or "") ..
                   (inst.moongleamlevel2hm:value() > 0 and STRINGS.NAMES.MOONSTORM_SPARK or "") .. (TUNING.isCh2hm and "" or " ") .. STRINGS.NAMES.NIGHTSTICK ..
                   (inst.bindusername2hm:value() ~= "" and ("(" .. inst.bindusername2hm:value() .. ")") or "")
    end
    local function nightstickactfn2hm(act, inst)
        if act.action == ACTIONS.CASTSPELL then act.distance = math.clamp(inst.moongleamlevel2hm:value() / 5 + 14, 14, 18) end
    end
    AddPrefabPostInit("nightstick", function(inst)
        inst:AddTag("rechargeable")
        inst.actfn2hm = nightstickactfn2hm
        inst.repairmaterials2hm = {moonstorm_spark = TUNING.NIGHTSTICK_FUEL / 20, moonstorm_static_item = 1}
        inst.displaynamefn = nightstickDisplayNameFn
        inst.itemtilefn2hm = itemtilefn
        inst.moongleamlevel2hm = net_smallbyte(inst.GUID, "nightstick.moongleamlevel2hm", "upgrade2hmdirty")
        inst.moongleamlevel2hm:set(0)
        inst.planarupgrade2hm = net_bool(inst.GUID, "nightstick.planarupgrade2hm", "upgrade2hmdirty")
        inst.planarupgrade2hm:set(false)
        inst.bindusername2hm = net_string(inst.GUID, "nightstick.bindusername2hm")
        inst.bindusername2hm:set("")
        if not TheWorld.ismastersim then return end
        if not inst.components.rechargeable then inst:AddComponent("rechargeable") end
        inst.components.rechargeable:SetOnDischargedFn(nightstickstartcd)
        inst.components.rechargeable:SetOnChargedFn(nightstickstopcd)
        inst.moongleamupgradefn2hm = nightstickmoongleamupgrade
        SetOnLoad(inst, nightstickonload)
        SetOnSave(inst, nightstickonsave)
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.customrepair = nightstickcustomrepair
        inst:ListenForEvent("equipped", onequipped)
    end)
    -- 奔雷给予月熠后,电击伤害大幅度提高,并解除装备和冲刺限制,0级后恢复限制
    local function newLightning_OnCharged(inst) inst.components.aoetargeting:SetEnabled(true) end
    local function spearmoongleamupgrade(inst, v)
        local newlevel = math.clamp(inst.moongleamlevel2hm:value() + (v or 1), 0, 40)
        inst.components.weapon:SetElectric((TUNING.ELECTRIC_DAMAGE_MULT - 1) * newlevel / 25 + 1, (TUNING.ELECTRIC_WET_DAMAGE_MULT -
                                               TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT) * newlevel / 25 +
                                               TUNING.SPEAR_WATHGRITHR_LIGHTNING_WET_DAMAGE_MULT)
        inst.moongleamlevel2hm:set(newlevel)
        if not inst.components.weapon.moongleaminit2hm then makeweaponconsumemoongleam(inst) end
        if newlevel > 0 then
            if newlevel >= 10 then
                if not inst:HasTag("fastrepair2hm") then inst:AddTag("fastrepair2hm") end
            elseif inst:HasTag("fastrepair2hm") then
                inst:RemoveTag("fastrepair2hm")
            end
            if inst.insulated2hm == nil then
                inst.insulated2hm = inst.components.equippable.insulated or false
                inst.components.equippable.insulated = true
            end
            if not inst.restrictedtag2hm then
                inst.restrictedtag2hm = inst.components.equippable.restrictedtag
                inst.components.equippable.restrictedtag = nil
            end
            -- 命中敌人不恢复耐久
            if inst.components.aoeweapon_lunge and inst.components.aoeweapon_lunge.onhitfn and not inst.onhitfn2hm then
                inst.onhitfn2hm = inst.components.aoeweapon_lunge.onhitfn
                inst.components.aoeweapon_lunge.onhitfn = function(inst, ...)
                    local owner = inst.components.inventoryitem:GetGrandOwner()
                    if inst.onhitfn2hm and
                        not (owner ~= nil and owner.components.skilltreeupdater ~= nil and
                            owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_4")) then inst.onhitfn2hm(inst, ...) end
                end
            end
            -- 还消耗耐久
            if inst.components.aoeweapon_lunge and inst.components.aoeweapon_lunge.onlungedfn and not inst.onlungedfn2hm then
                inst.onlungedfn2hm = inst.components.aoeweapon_lunge.onlungedfn
                inst.components.aoeweapon_lunge.onlungedfn = function(inst, ...)
                    if inst.onlungedfn2hm then inst.onlungedfn2hm(inst, ...) end
                    -- 20级后可以无CD施法一次
                    if inst.usedrefreshcd2hm then
                        inst.usedrefreshcd2hm = nil
                    elseif inst.moongleamlevel2hm:value() >= 20 then
                        inst.usedrefreshcd2hm = true
                        inst.components.rechargeable:Discharge(0)
                    end
                    local owner = inst.components.inventoryitem:GetGrandOwner()
                    if inst.moongleamupgradefn2hm and
                        not (owner ~= nil and owner.components.skilltreeupdater ~= nil and
                            owner.components.skilltreeupdater:IsActivated("wathgrithr_arsenal_spear_4")) then
                        inst.moongleamupgradefn2hm(inst, -1)
                    end
                    -- 冲刺时无敌帧,可以打断后摇
                    if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name == "combat_lunge" then
                        if inst.moongleamlevel2hm:value() >= 10 then inst.sg:AddStateTag("temp_invincible") end
                        if inst.moongleamlevel2hm:value() >= 20 then
                            inst.sg:RemoveStateTag("busy")
                            inst.sg:AddStateTag("idle")
                        end
                    end
                end
            end
            if not inst.onchargedfn2hm and inst.components.rechargeable and inst.components.rechargeable.onchargedfn then
                inst.onchargedfn2hm = inst.components.rechargeable.onchargedfn
                inst.components.rechargeable.onchargedfn = newLightning_OnCharged
                if inst.components.rechargeable:IsCharged() then inst.components.aoetargeting:SetEnabled(true) end
            end
        else
            if inst:HasTag("fastrepair2hm") then inst:RemoveTag("fastrepair2hm") end
            if inst.insulated2hm ~= nil then
                inst.components.equippable.insulated = inst.insulated2hm
                inst.insulated2hm = nil
            end
            if inst.onchargedfn2hm then
                if inst.components.rechargeable then inst.components.rechargeable.onchargedfn = inst.onchargedfn2hm end
                inst.onchargedfn2hm = nil
                if inst._onskillrefresh and inst.components.inventoryitem and inst.components.inventoryitem.owner then
                    inst._onskillrefresh(inst, inst.components.inventoryitem.owner)
                else
                    inst.components.aoetargeting:SetEnabled(false)
                end
            end
            if inst.onlungedfn2hm ~= nil then
                if inst.components.aoeweapon_lunge then inst.components.aoeweapon_lunge.onlungedfn = inst.onlungedfn2hm end
                inst.onlungedfn2hm = nil
            end
            if inst.onhitfn2hm ~= nil then
                if inst.components.aoeweapon_lunge then inst.components.aoeweapon_lunge.onhitfn = inst.onhitfn2hm end
                inst.onhitfn2hm = nil
            end
            if inst.restrictedtag2hm then
                inst.components.equippable.restrictedtag = inst.restrictedtag2hm
                inst.restrictedtag2hm = nil
                inst:DoTaskInTime(0, ForceUnequipWeapon2hm, function(owner) return not owner:HasTag(inst.components.equippable.restrictedtag) end)
            end
        end
    end
    local recentspear
    local function spearonload(inst, data)
        if recentspear == inst then recentspear = nil end
        if data and data.moongleam2hm then spearmoongleamupgrade(inst, data.moongleam2hm) end
    end
    local function spearonsave(inst, data) data.moongleam2hm = inst.moongleamlevel2hm:value() end
    local function spearDisplayNameFn(inst)
        if inst.moongleamlevel2hm:value() > 0 then
            return (inst.upgradeplanar2hm and (TUNING.isCh2hm and "充能" or "Charged ") or "") .. STRINGS.NAMES.MOONSTORM_SPARK ..
                       (TUNING.isCh2hm and "" or " ") .. STRINGS.NAMES.SPEAR_WATHGRITHR_LIGHTNING
        end
    end
    local function processskillrefresh(oldfn)
        return function(inst, ...)
            local SetEnabled
            if inst.components.aoetargeting and inst.moongleamlevel2hm:value() >= 1 then
                SetEnabled = inst.components.aoetargeting.SetEnabled
                inst.components.aoetargeting.SetEnabled = nilfn
            end
            oldfn(inst, ...)
            if SetEnabled then
                inst.components.aoetargeting.SetEnabled = SetEnabled
                if inst.components.rechargeable then inst.components.aoetargeting:SetEnabled(inst.components.rechargeable:IsCharged()) end
            end
        end
    end
    local function spearpostinit(inst)
        inst.repairmaterials2hm = {moonstorm_spark = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_USES / 20}
        inst.displaynamefn = spearDisplayNameFn
        inst.itemtilefn2hm = itemtilefn
        inst.moongleamlevel2hm = net_smallbyte(inst.GUID, "wigfridspear.moongleamlevel2hm", "upgrade2hmdirty")
        inst.moongleamlevel2hm:set(0)
        if not TheWorld.ismastersim then return end
        inst.moongleamupgradefn2hm = spearmoongleamupgrade
        SetOnPreLoad(inst, spearonload)
        SetOnSave(inst, spearonsave)
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.customrepair = customrepair
        -- 升级的装备10级无切换CD,1级无冲刺技能加点限制
        if inst.components.equippable then
            if inst.components.equippable.onequipfn then
                local onequipfn = inst.components.equippable.onequipfn
                inst.components.equippable.onequipfn = processskillrefresh(function(inst, ...)
                    local Discharge
                    if inst.components.rechargeable and inst.moongleamlevel2hm:value() >= 10 then
                        Discharge = inst.components.rechargeable.Discharge
                        inst.components.rechargeable.Discharge = nilfn
                    end
                    onequipfn(inst, ...)
                    if Discharge then inst.components.rechargeable.Discharge = Discharge end
                end)
            end
            if inst.components.equippable.onunequipfn then
                inst.components.equippable.onunequipfn = processskillrefresh(inst.components.equippable.onunequipfn)
            end
        end
        if inst._onskillrefresh then inst._onskillrefresh = processskillrefresh(inst._onskillrefresh) end
    end
    local function clearrecentspear(inst) if recentspear == inst then recentspear = nil end end
    AddPrefabPostInit("spear_wathgrithr_lightning_charged", function(inst)
        inst.upgradeplanar2hm = true
        spearpostinit(inst)
        if not TheWorld.ismastersim then return end
        if not POPULATING then
            recentspear = inst
            inst:DoTaskInTime(0, clearrecentspear)
        end
    end)
    AddPrefabPostInit("spear_wathgrithr_lightning", function(inst)
        spearpostinit(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.upgradeable and inst.components.upgradeable.onupgradefn then
            local onupgradefn = inst.components.upgradeable.onupgradefn
            inst.components.upgradeable.onupgradefn = function(inst, ...)
                local level = inst.moongleamlevel2hm:value()
                onupgradefn(inst, ...)
                if recentspear and recentspear:IsValid() and level and level > 0 then spearmoongleamupgrade(recentspear, level) end
            end
        end
    end)
    AddStategraphPostInit("wilson", function(sg)
        sg.states.combat_lunge_start.tags.temp_invincible = true
        -- sg.states.combat_lunge.tags.temp_invincible = true
    end)
end

-- 蜂王冠升级为蜂巢
if GetModConfigData("hivehat") then
    local function customrepair(inst, repairuse, doer, repair_item)
        if repair_item and repair_item:IsValid() and (repair_item.prefab == "bee" or repair_item.prefab == "killerbee") then
            local isbee = repair_item.prefab == "bee"
            local hive = SpawnPrefab(isbee and "beehive" or "wasphive")
            hive.Transform:SetPosition((doer or inst).Transform:GetWorldPosition())
            if inst.components.armor and hive.components.health then hive.components.health:SetPercent(inst.components.armor:GetPercent()) end
            if repair_item.components.stackable then
                local neednum = math.min(repair_item.components.stackable.stacksize, isbee and TUNING.BEEHIVE_EMERGENCY_BEES or TUNING.WASPHIVE_EMERGENCY_WASPS)
                repair_item.components.stackable:Get(neednum):Remove()
                if hive.components.childspawner then
                    hive.components.childspawner.emergencychildreninside = math.min(neednum, hive.components.childspawner.maxemergencychildren)
                end
            else
                repair_item:Remove()
            end
            inst.persists = false
            inst:DoTaskInTime(0, inst.Remove)
            return true
        else
            return -1
        end
    end
    local function onequip(inst, data) if data.owner and data.owner:IsValid() then data.owner.hivehat2hm = true end end
    local function onunequip(inst, data) if data.owner and data.owner:IsValid() then data.owner.hivehat2hm = nil end end
    AddPrefabPostInit("hivehat", function(inst)
        inst.repairmaterials2hm = {bee = 1, killerbee = 1, beeswax = 2000, honeycomb = 2000, honey = 60}
        if not TheWorld.ismastersim then return end
        if inst.components.armor then
            local oldpercent = inst.components.armor:GetPercent()
            inst.components.armor:InitCondition(2000, 0.8)
            inst.components.armor:SetPercent(oldpercent)
        end
        inst:ListenForEvent("equipped", onequip)
        inst:ListenForEvent("unequipped", onunequip)
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.customrepair = customrepair
    end)
    -- 杀人蜂巢/蜂箱
    AddPrefabPostInit("wasphive", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.playerprox and inst.components.playerprox.onnear then
            local onnear = inst.components.playerprox.onnear
            inst.components.playerprox.onnear = function(inst, target, ...)
                if target and target.hivehat2hm then return end
                onnear(inst, target, ...)
            end
        end
    end)
    AddPrefabPostInit("beebox", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.childspawner and inst.components.childspawner.ReleaseAllChildren then
            local ReleaseAllChildren = inst.components.childspawner.ReleaseAllChildren
            inst.components.childspawner.ReleaseAllChildren = function(self, target, ...)
                if target and target.hivehat2hm then return end
                ReleaseAllChildren(self, target, ...)
            end
        end
    end)
	-- 蜂王冠兼容妥协采摘蜂箱无伤害
	local function hivehatprotectPG(inst)
		if not TheWorld.ismastersim then return end
		if inst.components.harvestable then
			local oldharvestfn = inst.components.harvestable.onharvestfn
			inst.components.harvestable.onharvestfn = function(inst, picker, ...)
				local isspring = TheWorld.state.isspring
				local hastagPG
				if picker == nil or not picker.components.inventory or TheWorld.state.iswinter then return oldharvestfn(inst, picker, ...) end
				local equip = picker.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
				if equip and equip.prefab ~= "hivehat" then return oldharvestfn(inst, picker, ...) end
				if equip and equip.prefab == "hivehat" and equip.components.armor then
					-- 若有表，则遍历表并增加特定标签后续处理，防止某些模组增加标签生物
					if equip.components.armor.tags then
						for i, tag in ipairs(equip.components.armor.tags) do
							if tag == "bee" then
								hastagPG = true
							elseif not tag == "bee" then
								table.insert(equip.components.armor.tags, 1, "bee")
								hastagPG = 1
							end
						end
					-- 原版及妥协模组中未给蜂王冠特定标签,添加临时标签
					elseif equip.components.armor.tags == nil then
						equip.components.armor.tags = {"bee"}
						hastagPG = false
					end 
				end
				oldharvestfn(inst, picker, ...)
				-- 恢复蜂王冠耐久
				if equip and equip.prefab == "hivehat" and equip.components.armor and hastagPG ~= nil then
					if isspring then
						equip.components.armor:Repair(40)
					else
						equip.components.armor:Repair(20)
					end
				end
				-- 移除临时标签
				if hastagPG == 1 and equip.components.armor and equip.components.armor.tags then
					table.insert(equip.components.armor.tags, 1, "bee")
				elseif hastagPG == false and equip.components.armor and equip.components.armor.tags then
					equip.components.armor.tags = nil
				end
			end
		end
	end
	if TUNING.DSTU then
		AddPrefabPostInit("beebox", hivehatprotectPG)
		AddPrefabPostInit("beebox_hermit", hivehatprotectPG)
	end
end

-- 四本后可以升级你的扫把,这个扫把可以每个世界各绑定一个科技...
if GetModConfigData("Reskin Tool Upgrade") then
    -- 多世界科技变动数据统一
    AddShardModRPCHandler("MOD_HARDMODE", "ms_prototyper_update", function(shard_id, islink, data)
        local data = RPCGuard.DecodeTable(data)
        if TheShard and data and TheWorld and TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data then
            local worldid = tostring(TheShard:GetShardId())
            shard_id = tostring(shard_id)
            local _data = TheWorld.components.persistent2hm.data
            TheWorld.components.persistent2hm.data.reskinprototyper2hm = _data.reskinprototyper2hm or {}
            TheWorld.components.persistent2hm.data.reskinprototyper2hm[worldid] = data[shard_id]
            if islink then return end
            TheWorld:PushEvent("prototyperupadat2hm", TheWorld.components.persistent2hm.data.reskinprototyper2hm)
        end
    end)

    local function GetActiveItem(giver)
        return giver.components.inventory:GetActiveItem()
    end

    local function GetNewActiveItem(giver, prefab)
        local inventory = giver.components.inventory
        local body_item = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
        local backpack = body_item and body_item.components.container
        for _, inv in pairs(backpack and {inventory, backpack} or {inventory}) do
            for slot, item in pairs(inv.itemslots or inv.slots) do
                if item and item.prefab == prefab then
                    inv:TakeActiveItemFromAllOfSlot(slot, giver)
                    return item
                end
            end
        end
    end

    local function unlinkprototyper(inst)
        if inst.components.spellcaster then inst.components.spellcaster.canusefrominventory = true end
        local data = inst.components.persistent2hm and inst.components.persistent2hm.data
        inst:RemoveTag("linkprototyper2hm")
        inst:RemoveComponent("trader")
        inst:RemoveComponent("lootdropper")
        inst.linkprototyper2hm:set("")
        inst.level2hm:set(1)
        inst.bgimage2hm = nil
        inst.bgaltas2hm = nil
        inst.disablebgimage2hm = nil
        if data then
            data.prototyper_GUID = nil
        end
        inst:RemoveEventCallback("onburnt", unlinkprototyper)
    end

    local function prototyperchange(inst, TheWorld, data)
        if not inst:HasTag("linkprototyper2hm") then return end
        if not TheShard or not data then return end
        local worldid = tostring(TheShard:GetShardId())
        local _data = inst.components.persistent2hm.data and inst.components.persistent2hm.data.prototyper_GUID
        if _data and data[worldid] and data[worldid][_data] == nil then
            unlinkprototyper(inst)
        end
    end
    local function linkprototyper(inst, prefab, level)
        if prefab == nil or level == nil then return end
        if not inst:HasTag("linkprototyper2hm") then inst:AddTag("linkprototyper2hm") end
        inst.linkprototyper2hm:set(prefab)
        inst.level2hm:set(level)
        local ent = SpawnPrefab(prefab)
        ent.persist = false
        local trader = ent.components.trader
        ent:Remove()
        if trader then
            local onacceptfn = trader.onaccept
            if onacceptfn then
                trader.onaccept = function(_inst, _giver, _item, _count, ...)
                    onacceptfn(_inst, _giver, _item, _count, ...)
                    if _giver and _item and not GetActiveItem(_giver) then
                        GetNewActiveItem(_giver, _item.prefab)
                    end
                end
            end
            if not inst.components.lootdropper then inst:AddComponent("lootdropper") end
            if not inst.components.trader then inst:AddComponent("trader") end
            inst.components.trader.deleteitemonaccept = trader.deleteitemonaccept
            inst.components.trader.acceptnontradable = trader.acceptnontradable
            inst.components.trader:SetAcceptTest(trader.test)
            inst.components.trader.onaccept = trader.onaccept
            inst.components.trader.onrefuse = trader.onrefuse
            inst.components.trader.AcceptGift = trader.AcceptGift
            inst:ListenForEvent("onburnt", unlinkprototyper)
        end
        if inst.components.spellcaster then inst.components.spellcaster.canusefrominventory = false end
    end
    -- 加载时寻找之前绑定的科技建筑
    local function findprototyper(inst_data, data)
        if type(inst_data) ~= "table" or type(data) ~= "table" then return end
        for i, v in pairs(data) do
            if i == inst_data.prototyper_GUID then
                return v
            end
        end
    end
    local function onload(inst)
        if inst:HasTag("linkprototyper2hm") then unlinkprototyper(inst) end
        local data = TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data
        local _data = inst.components.persistent2hm and inst.components.persistent2hm.data
        local worldid = tostring(TheShard:GetShardId())
        if TheShard and data and data.reskinprototyper2hm and data.reskinprototyper2hm[worldid] then
            local prototypersdata = data.reskinprototyper2hm[worldid]
            local link_prototyper = findprototyper(_data, prototypersdata)
            if not link_prototyper then return end
            local prefab = link_prototyper.prefab
            local level2hm = link_prototyper.level2hm or 1
            linkprototyper(inst, prefab, level2hm)
        end
    end
    -- 绑定一个科技建筑
    local function ongive(inst, prototyper, doer)
        if inst:HasTag("linkprototyper2hm") then unlinkprototyper(inst) end
        if hardmode and not (doer and doer.components.persistent2hm and doer.components.persistent2hm.data.shadowmagiccycle) then return end
        if prototyper and prototyper:IsValid() then
            local prefab = prototyper.prefab
            local level2hm = prototyper.level2hm ~= nil and prototyper.level2hm:value() or 1
            local prototyper_GUID = tostring(prototyper.GUID)
            if prefab and TheShard and prototyper_GUID then
                local data = TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data
                local worldid = tostring(TheShard:GetShardId())
                data.reskinprototyper2hm = data.reskinprototyper2hm or {}
                data.reskinprototyper2hm[worldid] = data.reskinprototyper2hm[worldid] or {}
                data.reskinprototyper2hm[worldid][prototyper_GUID] = data.reskinprototyper2hm[worldid][prototyper_GUID] or {}
                data.reskinprototyper2hm[worldid][prototyper_GUID].prefab = data.reskinprototyper2hm[worldid][prototyper_GUID].prefab or prefab
                data.reskinprototyper2hm[worldid][prototyper_GUID].level2hm = data.reskinprototyper2hm[worldid][prototyper_GUID].level2hm or level2hm
                if inst.components.persistent2hm and inst.components.persistent2hm.data then inst.components.persistent2hm.data.prototyper_GUID = prototyper_GUID end
                SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_prototyper_update"), nil, true, DataDumper(data.reskinprototyper2hm, nil, true))

                linkprototyper(inst, prefab, level2hm)
                local fx_prefab = "explode_reskin"
                local skin_fx = SKIN_FX_PREFAB[inst:GetSkinName()]
                if skin_fx ~= nil and skin_fx[1] ~= nil then fx_prefab = skin_fx[1] end
                SpawnPrefab(fx_prefab).Transform:SetPosition(doer.Transform:GetWorldPosition())
                return true
            end
        end
    end
    local function DisplayNameFn(inst)
        local v = inst.linkprototyper2hm:value()
        if v and v ~= "" then
            local vname = STRINGS.NAMES[string.upper(v)]
            return STRINGS.NAMES.RESKIN_TOOL .. (vname and (" " .. vname) or "") .. " Lv" .. inst.level2hm:value() .. (inst.level2hm:value() >= 3 and " Max" or "")
        end
    end
    local function itemtilefn(inst, self)
        if inst.disablebgimage2hm then return end
        local v = inst.linkprototyper2hm:value()
        if v and v ~= "" then
            if not inst.bgimage2hm and not inst.disablebgimage2hm then
                local recipe = AllRecipes[v]
                if recipe then
                    inst.bgimage2hm = recipe.imagefn ~= nil and recipe.imagefn() or recipe.image
                    inst.bgaltas2hm = GetInventoryItemAtlas(inst.bgimage2hm, true) or recipe:GetAtlas()
                else
                    inst.disablebgimage2hm = true
                    return
                end
            end
            -- if self.image and not self.image.revert2hm then
            --     self.image.revert2hm = true
            --     self.image:SetScale(1, -1, 1)
            -- end
        elseif inst.bgimage2hm then
            inst.bgimage2hm = nil
            inst.bgaltas2hm = nil
        end
        return "upgrade2hmdirty", nil, inst.bgaltas2hm, inst.bgimage2hm
    end
    AddPrefabPostInit("reskin_tool", function(inst)
        inst.linkprototyper2hm = net_string(inst.GUID, "reskin_tool.linkprototyper2hm", "upgrade2hmdirty")
        inst.level2hm = net_byte(inst.GUID, "researchlab.level2hm", "upgrade2hmdirty")
        inst.prototypername = net_string(inst.GUID, "reskin_tool.prototypername", "upgrade2hmdirty")
        inst.level2hm:set(1)
        inst.displaynamefn = DisplayNameFn
        inst.itemtilefn2hm = itemtilefn
        if not TheWorld.ismastersim then return end
        inst.prototyperfn2hm = ongive
        inst:AddComponent("persistent2hm")
        inst:DoTaskInTime(0, onload)
        inst.prototyperupadat2hm = function(TheWorld, data)
            prototyperchange(inst, TheWorld, data)
        end
        inst:ListenForEvent("prototyperupadat2hm", inst.prototyperupadat2hm, TheWorld)
    end)
    -- -- 打扫动作
    -- local sweepact = Action({mount_valid = true, encumbered_valid = true, priority = 1})
    -- sweepact.id = "SWEEP2HM"
    -- sweepact.strfn = function(act)
    --     local doer = act.doer
    --     if doer and doer.replica.inventory and doer.replica.inventory then
    --         local weapon = doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    --         if weapon and weapon.prefab == "reskin_tool" and weapon:HasTag("linkprototyper2hm") and weapon.linkprototyper2hm and
    --             weapon.linkprototyper2hm:value() ~= "" then return string.upper(weapon.linkprototyper2hm:value()) end
    --     end
    -- end
    -- sweepact.fn = function(act)
    --     if act.invobject and act.doer and act.doer.components.inventory then
    --         local weapon = act.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    --         if weapon and weapon.prefab == "reskin_tool" and weapon.bindprototyper2hm and weapon.bindprototyper2hm:IsValid() and
    --             weapon.bindprototyper2hm.components.trader then
    --             local count
    --             if weapon.bindprototyper2hm.components.trader:IsAcceptingStacks() then
    --                 count = (weapon.bindprototyper2hm.components.inventory ~= nil and
    --                             weapon.bindprototyper2hm.components.inventory:CanAcceptCount(act.invobject)) or
    --                             (act.invobject.components.stackable ~= nil and act.invobject.components.stackable.stacksize) or 1
    --                 if count <= 0 then return false end
    --             end
    --             local able, reason = weapon.bindprototyper2hm.components.trader:AbleToAccept(act.invobject, act.doer, count)
    --             if not able then return false, reason end
    --             weapon.bindprototyper2hm.notactive2hm = true
    --             weapon.bindprototyper2hm.components.trader:AcceptGift(act.doer, act.invobject, count)
    --             weapon.bindprototyper2hm.notactive2hm = nil
    --             local fx_prefab = "explode_reskin"
    --             local skin_fx = SKIN_FX_PREFAB[weapon:GetSkinName()]
    --             if skin_fx ~= nil and skin_fx[1] ~= nil then fx_prefab = skin_fx[1] end
    --             SpawnPrefab(fx_prefab).Transform:SetPosition(act.doer.Transform:GetWorldPosition())
    --             return true
    --         end
    --     end
    -- end
    -- AddAction(sweepact)
    -- local function sweepactfn(inst, doer, actions)
    --     if not (inst.replica.equippable and inst.replica.equippable:IsEquipped()) and not inst.replica.container and doer and doer.replica.inventory and
    --         doer.replica.inventory then
    --         local weapon = doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    --         if weapon and weapon.prefab == "reskin_tool" and weapon:HasTag("linkprototyper2hm") then table.insert(actions, ACTIONS.SWEEP2HM) end
    --     end
    -- end
    -- table.insert(TUNING.INVENTORYFNS2HM, sweepactfn)
    -- STRINGS.ACTIONS.SWEEP2HM = {}
    -- STRINGS.ACTIONS.SWEEP2HM.GENERIC = STRINGS.UI.BUGREPORTSCREEN.SUBMIT_FAILURE_TITLE
    -- STRINGS.ACTIONS.SWEEP2HM.RESEARCHLAB = STRINGS.ACTIONS.GIVE.GENERIC .. " " .. STRINGS.NAMES.RESEARCHLAB
    -- STRINGS.ACTIONS.SWEEP2HM.RESEARCHLAB2 = STRINGS.ACTIONS.GIVE.GENERIC .. " " .. STRINGS.NAMES.RESEARCHLAB2
    -- STRINGS.ACTIONS.SWEEP2HM.RESEARCHLAB4 = STRINGS.ACTIONS.GIVE.GENERIC .. " " .. STRINGS.NAMES.RESEARCHLAB4
    -- STRINGS.ACTIONS.SWEEP2HM.TURFCRAFTINGSTATION = STRINGS.ACTIONS.GIVE.GENERIC .. " " .. STRINGS.NAMES.TURFCRAFTINGSTATION
    -- AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.SWEEP2HM, "veryquickcastspell"))
    -- AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.SWEEP2HM, "veryquickcastspell"))
end

-- 便携式视界扩展器
if GetModConfigData("Horizon Expandinator") then
	-- 视野距离增大
	TUNING.DAPPERNESS_TINY = TUNING.DAPPERNESS_MED
	TUNING.SCRAP_MONOCLE_EXTRA_VIEW_DIST = 60

	local function _base_onequip(inst, owner, symbol_override, swap_hat_override)
		local skin_build = inst:GetSkinBuild()
		if skin_build ~= nil then
			owner:PushEvent("equipskinneditem", inst:GetSkinName())
			owner.AnimState:OverrideItemSkinSymbol(swap_hat_override or "swap_hat", skin_build, symbol_override or "swap_hat", inst.GUID, fname)
		else
			owner.AnimState:OverrideSymbol(swap_hat_override or "swap_hat", "hat_scrap_monocle", symbol_override or "swap_hat")
		end

		if inst.components.fueled ~= nil then
			inst.components.fueled:StartConsuming()
		end

		if inst.skin_equip_sound and owner.SoundEmitter then
			owner.SoundEmitter:PlaySound(inst.skin_equip_sound)
		end
	end
	local function opentop_onequip(inst, owner)
		_base_onequip(inst, owner)

		owner.AnimState:Show("HAT")
		owner.AnimState:Hide("HAIR_HAT")
		owner.AnimState:Show("HAIR_NOHAT")
		owner.AnimState:Show("HAIR")

		owner.AnimState:Show("HEAD")
		owner.AnimState:Hide("HEAD_HAT")
		owner.AnimState:Hide("HEAD_HAT_NOHELM")
		owner.AnimState:Hide("HEAD_HAT_HELM")
	end
	local function _onunequip(inst, owner)
		local skin_build = inst:GetSkinBuild()
		if skin_build ~= nil then
			owner:PushEvent("unequipskinneditem", inst:GetSkinName())
		end

		owner.AnimState:ClearOverrideSymbol("headbase_hat") --it might have been overriden by _onequip
		if owner.components.skinner ~= nil then
			owner.components.skinner.base_change_cb = owner.old_base_change_cb
		end

		owner.AnimState:ClearOverrideSymbol("swap_hat")
		owner.AnimState:Hide("HAT")
		owner.AnimState:Hide("HAIR_HAT")
		owner.AnimState:Show("HAIR_NOHAT")
		owner.AnimState:Show("HAIR")

		if owner:HasTag("player") then
			owner.AnimState:Show("HEAD")
			owner.AnimState:Hide("HEAD_HAT")
			owner.AnimState:Hide("HEAD_HAT_NOHELM")
			owner.AnimState:Hide("HEAD_HAT_HELM")
		end

		if inst.components.fueled ~= nil then
			inst.components.fueled:StopConsuming()
		end
	end
	-- 保存和加载升级效果
	local function _upgradeonsave(inst, data)
		if inst.upgradesandPG == true then
			data.upgradesandPG = true
		end
		if inst.upgrademoonPG == true then
			data.upgrademoonPG = true
		end
		if inst.upgradesnowPG == true then
			data.upgradesnowPG = true
		end
	end
	
	local function _upgradeonload(inst, data)
		if data and data.upgradesandPG == true then
			inst.upgradesandPG = true
			if not inst:HasTag("goggles") then inst:AddTag("goggles") end
			inst:AddTag("sandstormgoggles")
            if TheWorld.state.issummer and inst.components.insulator then
                inst.components.insulator:SetSummer()
                inst.components.insulator:SetInsulation(120) 
            end
		end
		if data and data.upgrademoonPG == true then
			inst.upgrademoonPG = true
			if not inst:HasTag("goggles") then inst:AddTag("goggles") end
			inst:AddTag("moonstormgoggles")
		end
		if data and data.upgradesnowPG == true then
			inst.upgradesnowPG = true
			if not inst:HasTag("goggles") then inst:AddTag("goggles") end
			inst:AddTag("snowstormgoggles")
            if not TheWorld.state.issummer and inst.components.insulator then 
                inst.components.insulator:SetWinter()
                inst.components.insulator:SetInsulation(120)
            end
		end
	end
    -- 根据当前世界季节切换保暖隔热效果
    local function changeinsulator(inst, world, season)
        if world and season == "summer" and inst.components.insulator and inst:HasTag("sandstormgoggles") then
            inst.components.insulator:SetSummer()
            inst.components.insulator:SetInsulation(120)
        elseif world and season ~= "summer" and inst.components.insulator and inst:HasTag("snowstormgoggles") then
            inst.components.insulator:SetWinter()
            inst.components.insulator:SetInsulation(120)
        end
    end

	AddPrefabPostInit("scrap_monoclehat", function(inst)
		if inst:HasTag("scrapmonolevision") then inst:RemoveTag("scrapmonolevision") end
		inst.repairmaterials2hm = {wagpunkbits_kit = TUNING.SCRAP_MONOCLEHAT_PERISHTIME / 2}
        -- 升级防风镜后更改名字
        inst.displaynamefn = function(inst)
            local name = STRINGS.NAMES.SCRAP_MONOCLEHAT
            local sandgoggles
            local moongoggles
            local snowgoggles
            if inst:HasTag("sandstormgoggles") or inst:HasTag("moonstormgoggles") or inst:HasTag("snowstormgoggles") then
                name = "- " .. name
            end
            if inst:HasTag("sandstormgoggles") then sandgoggles = TUNING.isCh2hm and "沙" or "Sand" end
            if inst:HasTag("moonstormgoggles") then moongoggles = TUNING.isCh2hm and "星" or "Moon" end
            if inst:HasTag("snowstormgoggles") then snowgoggles = TUNING.isCh2hm and "雪" or "Snow" end
            return (moongoggles or "") .. (moongoggles ~= nil and (sandgoggles ~= nil or snowgoggles ~= nil) and "/" or "") .. (sandgoggles or "") .. (sandgoggles ~= nil and snowgoggles ~= nil and "/" or "") .. (snowgoggles or "") .. name
        end
		if not TheWorld.ismastersim then return end
        inst.worldseasonchange = function(world, season) changeinsulator(inst, world, season) end
        inst:AddComponent("insulator")
		inst:AddComponent("repairable2hm")
        inst:ListenForEvent("ms_setseason",inst.worldseasonchange, TheWorld)
		-- 昼夜回san
		inst.dapperness_per_phase = {
					day   =   TUNING.DAPPERNESS_MED,
					dusk  =   TUNING.DAPPERNESS_MED,
					night =   TUNING.DAPPERNESS_MED,
				}
		-- 装/脱帽不影响视野效果
		if inst.components.equippable then 
			inst.components.equippable:SetOnEquip(opentop_onequip)
			inst.components.equippable:SetOnUnequip(_onunequip)
		end
		if not inst.components.inspectable then inst:AddComponent("inspectable") end
		-- 检查帽子 开/关 大视野功能
		local GetDescription = inst.components.inspectable.GetDescription
		inst.components.inspectable.GetDescription = function(self, ...)
			local player
			local desc, filter_context, author = GetDescription(self, ...)
			if inst.components.inventoryitem then
				local owner = inst.components.inventoryitem.owner
				if owner and owner:HasTag("player") then
					player = owner
				elseif owner and owner:HasTag("backpack") and owner.components.inventoryitem then
					player = owner.components.inventoryitem.owner
				end
			end
			if player and not player.changestatePG then player.changestatePG = 0 end
			if player and player:HasTag("player") and player.changestatePG == 0 then
				player:RemoveCameraExtraDistance("scrap_monoclehat")
				player:AddCameraExtraDistance("scrap_monoclehat", TUNING.SCRAP_MONOCLE_EXTRA_VIEW_DIST)
				player.changestatePG = 1
				desc = (desc or "") .. (TUNING.isCh2hm and "\n" .. "大视野模式" or "\n" .. "Max View Mode")
				player.TaskPG1 = player:DoPeriodicTask(1, function()
					if player.components.inventory then
						local hat = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
						if hat and hat.prefab == "scrap_monoclehat" then return end
						if not player.components.inventory:Has("scrap_monoclehat", 1, true) then
							player:RemoveCameraExtraDistance("scrap_monoclehat")
							player.changestatePG = 0
							if player.TaskPG1 then
								player.TaskPG1:Cancel()
								player.TaskPG1 = nil
							end
						end
					end
				end)
			elseif player and player:HasTag("player") and player.changestatePG == 1 then
				player:RemoveCameraExtraDistance("scrap_monoclehat")
				player.changestatePG = 0
				desc = (desc or "") .. (TUNING.isCh2hm and "\n" .. "默认视野" or "\n" .. "Default view")
				if player.TaskPG1 then
					player.TaskPG1:Cancel()
					player.TaskPG1 = nil
				end
			end
			return  desc, filter_context, author
		end
		local oldsave = inst.OnSave
		inst.OnSave = function(inst, data, ...)
			if oldsave then oldsave(inst, data, ...) end
			_upgradeonsave(inst, data)
		end
		local oldload = inst.OnLoad
		inst.OnLoad = function(inst, data, ...)
			if oldload then oldload(inst, data, ...) end
			_upgradeonload(inst, data)
		end
	end)
	-- 可用各类护目镜升级视野帽拥有防风沙功能
	local function upgradehatPG(inst, doer, target, pos, act)
		if inst.prefab == "deserthat" and not target.upgradesandPG then
			target.upgradesandPG = true
            target:AddTag("sandstormgoggles")
			if not target:HasTag("goggles") then target:AddTag("goggles") end
            if TheWorld.state.issummer and target.components.insulator then 
                target.components.insulator:SetSummer()
                target.components.insulator:SetInsulation(120) 
            end
			doer.SoundEmitter:PlaySound("dontstarve/HUD/repair_clothing")
			inst:Remove()
			return true
		elseif inst.prefab == "moonstorm_goggleshat" and not target.upgrademoonPG then
			target.upgrademoonPG = true
			if not target:HasTag("goggles") then target:AddTag("goggles") end
			target:AddTag("moonstormgoggles")
			doer.SoundEmitter:PlaySound("dontstarve/HUD/repair_clothing")
			inst:Remove()
			return true
		end
		if TUNING.DSTU and inst.prefab == "snowgoggles" and not target.upgradesnowPG then
			target.upgradesnowPG = true
            target:AddTag("snowstormgoggles")
			if not target:HasTag("goggles") then target:AddTag("goggles") end
             if not TheWorld.state.issummer and target.components.insulator then
                target.components.insulator:SetWinter()
                target.components.insulator:SetInsulation(120)
            end
			doer.SoundEmitter:PlaySound("dontstarve/HUD/repair_clothing")
			inst:Remove()
			return true
		end
		return false
	end
	local function upgradehatcondition(inst, doer, actions, right, target)
		if target.prefab == "scrap_monoclehat" then
			if inst.prefab == "deserthat" and not target.upgradesandPG and not target:HasTag("sandstormgoggles") then
				return true
			elseif inst.prefab == "moonstorm_goggleshat" and not target.upgrademoonPG and not target:HasTag("moonstormgoggles") then
				return true
			end
			if TUNING.DSTU and inst.prefab == "snowgoggles" and not target.upgradesnowPG and not target:HasTag("snowstormgoggles") then
				return true
			end
			return false
		end
		return false
	end
	STRINGS.ACTIONS.ACTION2HM.DESERTHAT = TUNING.isCh2hm and "升级" or "UPGRADE"
	STRINGS.ACTIONS.ACTION2HM.MOONSTORM_GOGGLESHAT = TUNING.isCh2hm and "升级" or "UPGRADE"
	AddPrefabPostInit("deserthat", function(inst)
		inst.actionothercondition2hm = upgradehatcondition
		if not TheWorld.ismastersim then return end
		inst:AddComponent("action2hm")
		inst.components.action2hm.actionfn = upgradehatPG
	end)
	AddPrefabPostInit("moonstorm_goggleshat", function(inst)
		inst.actionothercondition2hm = upgradehatcondition
		if not TheWorld.ismastersim then return end
		inst:AddComponent("action2hm")
		inst.components.action2hm.actionfn = upgradehatPG
	end)
	if TUNING.DSTU then
		STRINGS.ACTIONS.ACTION2HM.SNOWGOGGLES = TUNING.isCh2hm and "升级" or "UPGRADE"
		AddPrefabPostInit("snowgoggles", function(inst)
			inst.actionothercondition2hm = upgradehatcondition
			if not TheWorld.ismastersim then return end
			inst:AddComponent("action2hm")
			inst.components.action2hm.actionfn = upgradehatPG
		end)
	end
end

-- 拾荒尖帽增强
if GetModConfigData("scraphat") then
	-- 耐久增强
	TUNING.ARMOR_SCRAP_HAT = 840
	-- 受击反伤攻击者
	local function onattacked(inst, owner, data)
		if data and data.weapon and data.attacker ~= data.weapon then return end
		if inst:IsValid() and data and data.attacker and data.attacker:IsValid() and data.attacker.components.health and data.attacker.components.combat and 
			owner and owner:IsValid() and owner:IsNear(data.attacker, 6) and owner.sg and not owner.sg:HasStateTag("parrying") then
			local attackfx = SpawnPrefab("fx_dock_pop")
			data.attacker:AddChild(attackfx)
			data.attacker.components.combat:GetAttacked_Internal(inst, 23, inst)
		end
	end

	local function onequiped(inst, data)
        if inst:HasTag("broken") and data and data.owner then
            inst:DoTaskInTime(0, function()
                if inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() and data.owner.components.inventory ~= nil then
                    local item = data.owner.components.inventory:Unequip(inst.components.equippable.equipslot)
                    if item ~= nil then
                        data.owner.components.inventory:GiveItem(item, nil, data.owner:GetPosition())
                    end
                end
            end)
            return
        end
		if data and data.owner and data.owner:HasTag("player") then
			local owner = data.owner
			inst:ListenForEvent("attacked", inst.onattackedPG, data.owner)
		end
	end

	local function onunequiped(inst, data)
		inst:RemoveEventCallback("attacked", inst.onattackedPG, data.owner)
	end

    -- 0耐久不消失
    local function OnBroken(inst)
        inst:AddTag("broken")
    end

    local function OnRepaired(inst)
        inst:RemoveTag("broken")
    end
	AddPrefabPostInit("scraphat", function(inst)
		-- 可用自动修理机修理头盔
		if not TheWorld.ismastersim then return end
        MakeForgeRepairable(inst, FORGEMATERIALS.WAGPUNKBITS, OnBroken, OnRepaired)
		inst.onattackedPG = function(owner, data) onattacked(inst, owner, data) end
		inst:ListenForEvent("equipped", onequiped)
		inst:ListenForEvent("unequipped", onunequiped)
	end)
end



-- 新 ------------------------------------------------------------------------------
-- 新火腿棒
local newhambat = GetModConfigData("New Hambat 2")
TUNING.MAXHAMBATWEIGHT2HM = newhambat or 0
if newhambat then
    AddRecipePostInit("hambat", function(self)
        for _, ingredient in pairs(self.ingredients) do
            if ingredient.type == "meat" then
                ingredient.amount = ingredient.amount - 1
            end
        end
    end)
    AddPrefabPostInit("hambat", function(inst)
        inst:AddTag("hambat2hm")
        if not TheWorld.ismastersim then return end
        -- inst.components.perishable:SetPerishTime(TUNING.PERISH_SLOW)
        inst:AddComponent("hoverer2hm")
        inst:AddComponent("hambat2hm")
    end)
    local cooking = require "cooking"
    local _up_aliases = getupvalue2hm(AddRecipeCard, "aliases") or getupvalue2hm(cooking.CalculateRecipe, "aliases") or getupvalue2hm(cooking.IsCookingIngredient, "aliases") or {
        cookedsmallmeat = "smallmeat_cooked",
        cookedmonstermeat = "monstermeat_cooked",
        cookedmeat = "meat_cooked",
    }
    local function is_meat(item)
        local recipe = cooking.ingredients[_up_aliases[item.prefab] or item.prefab]
        if recipe and recipe.tags and recipe.tags.meat then return recipe end
        return false
    end

    local whitelist = {
        "fishmeat_small_dried",
        "fishmeat_dried",
        "fishmeat_small",
        "fishmeat",
        "fishmeat_cooked",
        "fishmeat_small_cooked",
    }
    local action = Action({})
    action.priority = 1
    action.id = "GIVEHAMBAT2HM"
    action.str = TUNING.isCh2hm and "补充" or "complement"
    action.fn = function(act)
        if act.target and act.target.components.hambat2hm and act.invobject then
            if hardmode and act.target.components.hambat2hm.weight and act.target.components.hambat2hm.weight >= 5 then
                if act.invobject and not (act.invobject:HasTag("fishmeat") or table.contains(whitelist, act.invobject.prefab)) then
                    if act.doer and act.doer.components and act.doer.components.talker then
                        act.doer:DoTaskInTime(0, function()
                            act.doer.components.talker:Say(TUNING.isCh2hm and ("需要用鱼肉补充") or ("Need to supplement with fish or meat products"))
                        end)
                    end
                    return false
                end
                return act.target.components.hambat2hm:AddMeat(is_meat(act.invobject), act.invobject)
            elseif (act.target.components.hambat2hm.weight and act.target.components.hambat2hm.weight < 5) or not hardmode then
                return act.target.components.hambat2hm:AddMeat(is_meat(act.invobject), act.invobject)
            end
            return false
        else
            return false, "不是火腿"
        end
    end
    -- 添加动作
    AddAction(action)
    AddComponentAction("USEITEM", "edible", function(inst, doer, target, actions)
        if is_meat(inst) then
            if target and target:HasTag("hambat2hm") then
                table.insert(actions, ACTIONS.GIVEHAMBAT2HM)
            end
        end
    end)
    local handler = ActionHandler(ACTIONS.GIVEHAMBAT2HM, function(inst, action) return "domediumaction" end)
    AddStategraphActionHandler("wilson", handler)
    AddStategraphActionHandler("wilson_client", handler)

    local action = Action({})
    action.priority = 1
    action.id = "EATHAMBAT2HM"
    action.str = TUNING.isCh2hm and "啃一口" or "taste"
    action.distance = 999999
    action.fn = function(act)
        if act.invobject and act.invobject.components.hambat2hm then
            return act.invobject.components.hambat2hm:Taste(act.doer)
        else
            return false, "不是火腿"
        end
    end
    -- 添加动作
    AddAction(action)
    -- AddComponentAction("POINT", "hambat2hm", function(inst, doer, pos, actions, right, target)
    --     local pressshift
    --     if TheWorld.ismastersim then
    --         pressshift = true
    --     else
    --         pressshift = TheInput:IsKeyDown(KEY_LALT)
    --     end
    --     if right and pressshift then
    -- -- AddComponentAction("USEITEM", "hambat2hm", function(inst, doer, target, actions, right)
    --     print("USEITEM hambat2hm", inst, doer, target, right)
    --     if inst.replica.hambat2hm and target == doer then

    AddComponentAction("INVENTORY", "hambat2hm", function(inst, doer, actions, right)
        -- print("INVENTORY", "hambat2hm", inst, doer, actions, right)
        if right and inst:HasTag("hambat2hm") then
            table.insert(actions, ACTIONS.EATHAMBAT2HM)
        end
    end)
    local handler = ActionHandler(ACTIONS.EATHAMBAT2HM, function(inst, action) return "eat" end)
    AddStategraphActionHandler("wilson", handler)
    AddStategraphActionHandler("wilson_client", handler)
    
    -- 2025.10.21 melon:眼面具/恐怖盾牌仅啃0.5的火腿  学习重置版
    if TUNING.DSTU then
        local function processhambat2hm_eat(inst)
            if inst.components.eater then
                local _Eat = inst.components.eater.Eat
                inst.components.eater.Eat = function(self, food, feeder)
                    if food and food.components.hambat2hm and food.components.hambat2hm.weight and food.components.hambat2hm.weight > 0.5 then -- 检查是否是火腿棒
                        if inst.components.armor then
                            inst.components.armor:Repair(12.5 * 0.75 * self.hungerabsorption)
                        end
                        local sound_name = inst.prefab == "shieldofterror" and "terraria1/eye_shield/eat" or inst.prefab == "eyemaskhat" and "terraria1/eyemask/eat"
                        if sound_name then
                            if not inst.inlimbo then -- 播放动画和音效
                                inst.AnimState:PlayAnimation("eat")
                                inst.AnimState:PushAnimation("idle", true)
                                inst.SoundEmitter:PlaySound(sound_name)
                            else -- 物品在背包中时，让持有者播放声音
                                local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
                                if owner and owner.SoundEmitter then
                                    owner.SoundEmitter:PlaySound(sound_name)
                                end
                            end
                        end
                        food.components.hambat2hm.weight = food.components.hambat2hm.weight - 0.5
                        -- 2025.10.22 melon:修复小眼吃完隐身的问题
                        if inst.prefab == "eyeofterror_mini" and inst.sg then inst.sg:GoToState("taunt") end
                        return true -- 表示成功"吃"了，但不移除食物
                    else
                        return _Eat(self, food, feeder)
                    end
                end
            end
        end
        local eater_prefabs = {"shieldofterror", "eyemaskhat", "pigman", "spider", "eyeofterror_mini", }
        for _, prefab in ipairs(eater_prefabs) do
            AddPrefabPostInit(prefab, function(inst)
                if not TheWorld.ismastersim then return end
                processhambat2hm_eat(inst)
                inst.processhambat2hm_eat = processhambat2hm_eat
            end)
        end
    end
end

------------------------------------------------------------------------------------------------
-- 2025.9.25 melon:涡流(刀)。每次攻击后可冲刺一次(没有无敌),并将敌人牵引一段距离造成一半伤害
if GetModConfigData("sword_vortex2hm") then
    AddRecipe2(
        "sword_vortex2hm",
        {Ingredient("nightmarefuel", 10),Ingredient("livinglog", 1)},
        TECH.SCIENCE_TWO,
        {
            atlas = "images/inventoryimages/sword_vortex2hm.xml", 
            images = "images/inventoryimages/sword_vortex2hm.tex",
        },
        {"WEAPONS"}
    )
    STRINGS.NAMES.SWORD_VORTEX2HM = TUNING.isCh2hm and "涡流" or "Vortex Sword"
    STRINGS.RECIPE_DESC.SWORD_VORTEX2HM = TUNING.isCh2hm and "每次攻击后可冲刺一次(没有无敌),并将敌人牵引一段距离造成一半伤害" or "Can dodge once after attack, pull target move half distance."
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.SWORD_VORTEX2HM = TUNING.isCh2hm and "涡流" or "Vortex Sword"
    -- 2025.10.3 melon:噩梦燃料修理
    if GetModConfigData("Construction Amulet Repair Equip") then
        AddPrefabPostInit("sword_vortex2hm", function(inst)
            inst.repairmaterials2hm = {nightmarefuel = math.floor(TUNING.NIGHTSWORD_USES * 2 / 12)} -- 16
            if not TheWorld.ismastersim then return end
            inst:AddComponent("repairable2hm")
        end)
    end
    -- 右键动作
    AddStategraphPostInit("wilson", function(inst)
        local _deststate = inst.actionhandlers[ACTIONS.CASTSPELL].deststate
        inst.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject:HasTag("sword_vortex2hm") then
                if inst.sword_vortex_count2hm and inst.sword_vortex_count2hm > 0 then -- 牵引次数>0才行
                    return "vortex2hm"
                else
                    return
                end
            end
            return _deststate(inst, action, ...)
        end
    end)
    -- 冲刺动作
    AddStategraphState("wilson", State {
        name = "vortex2hm",
        -- tags = {"busy", "evade", "no_stun", "canrotate", "pausepredict", "nopredict", "drowning"},
        tags = { "canrotate", "busy" },
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            local buffaction = inst:GetBufferedAction()
            if buffaction ~= nil and buffaction.pos ~= nil then
                inst:ForceFacePoint(buffaction:GetActionPoint():Get())
            elseif buffaction ~= nil and buffaction.target ~= nil then
                inst:ForceFacePoint(buffaction.target:GetPosition())
            end
            inst:PerformBufferedAction()
            inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")
            inst.AnimState:PushAnimation("wortox_portal_jumpin_lag", false)
            -- 动画速度  速度越快滑行越短
            local speed = inst.sword_vortex_target2hm and inst.sword_vortex_target2hm:HasTag("epic") and 2.5 or 4
            inst.AnimState:SetDeltaTimeMultiplier(speed) --速度? 动画速度快了滑行时间就短了
        end,
        timeline = {
            TimeEvent(0, function(inst)
                inst.Physics:SetMotorVelOverride(25, 0, 0) -- 滑行速度  原本20
            end),
        },
        events = {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
        onexit = function(inst)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst.AnimState:SetDeltaTimeMultiplier(1) --速度?
        end,
    })
end

if GetModConfigData("Nightsword Infused") then
    TUNING.GLASSCUTTER.DAMAGE = TUNING.GLASSCUTTER.DAMAGE * 75 / 68
    TUNING.NIGHTSWORD_DAMAGE = TUNING.NIGHTSWORD_DAMAGE * 75 / 68
    TUNING.NIGHTSWORD_USES = TUNING.NIGHTSWORD_USES * 1.5
    AddRecipePostInit("nightsword", function(inst) 
        if inst.ingredients and type(inst.ingredients) == "table" then
            for i, v in pairs(inst.ingredients) do
                if v and v.type == "nightmarefuel" and v.amount and v.amount > 0 then
                    v.amount = v.amount * 2
                elseif v and v.type == "livinglog" and v.amount and v.amount > 0 then
                    v.amount = v.amount * 2
                end
            end
        end
    end)
    local defaultdamage = 11
    local function disableStatus(inst)
        inst.level2hm = 0
        inst.weaponlevel2hm:set(inst.level2hm)
        local owner = inst.components.inventoryitem.owner
        if owner and owner.components.passive_shadows2hm then
            if owner.prefab == "waxwell" then
                owner.components.passive_shadows2hm:SetDamage(defaultdamage + inst.level2hm + 2)
            else
                owner.components.passive_shadows2hm:SetDamage(defaultdamage + inst.level2hm)
            end
            owner.components.passive_shadows2hm:SetMaxShadows(2 + inst.level2hm)
            owner.components.passive_shadows2hm.shouldcostsanity = false
            if owner.components.sanity and owner.components.sanity.get_equippable_dappernessfn and inst.components.equippable then
                local dapperness = owner.components.sanity.get_equippable_dappernessfn(owner, inst.components.equippable)
                local defaultdapperness = inst.components.equippable.dapperness
                local percent = dapperness / defaultdapperness
                if percent < 1 then
                    owner.components.passive_shadows2hm.shouldcostsanity = true
                    owner.components.passive_shadows2hm.costsanitypercent = 1 - percent
                end
            end
        end
        if owner and owner.components.combat then
            owner.components.combat.externaldamagemultipliers:RemoveModifier(inst, "nightsword2hm")
        end
    end

    local function enableStatus(inst)
        local owner = inst.components.inventoryitem.owner
        if not owner or not owner.components.sanity then return disableStatus(inst) end
        -- if not owner.components.sanity:IsSane() then return disableStatus(inst) end
        local extrasanity = owner.components.sanity:IsLunacyMode() and (1 - (owner.components.sanity:GetPercentWithPenalty() or 1)) * 2 or (1 - (owner.components.sanity:GetPercentWithPenalty() or 1)) * 3

        inst.level2hm = math.clamp(math.ceil(extrasanity + inst.components.perishable:GetPercent() / 0.5), 1, 4) or 1
        inst.weaponlevel2hm:set(inst.level2hm)
        if owner then
            if not owner.components.passive_shadows2hm then owner:AddComponent("passive_shadows2hm") end
            if owner.prefab == "waxwell" then
                owner.components.passive_shadows2hm:SetDamage(defaultdamage + inst.level2hm + 2)
            else
                owner.components.passive_shadows2hm:SetDamage(defaultdamage + inst.level2hm)
            end
            owner.components.passive_shadows2hm:SetMaxShadows(math.clamp(2 + inst.level2hm, 2, 5))
            owner.components.passive_shadows2hm.shouldcostsanity = true
            if inst.level2hm >= 4 then owner.components.passive_shadows2hm.costsanitypercent = 0 end
            if owner.components.combat then
                owner.components.combat.externaldamagemultipliers:SetModifier(inst, 1.12, "nightsword2hm")
            end
        end
    end

    local function UpdateStatus(inst)
        if not inst:IsValid() then return end
        local owner = inst.components.inventoryitem.owner
        if not inst.components.perishable or (inst.components.perishable.perishremainingtime or 0) <= 0 or not inst.components.equippable:IsEquipped()
            or not (owner and owner:IsValid()) or not owner:HasTag("player") or
            owner:HasTag("playerghost") then return disableStatus(inst) end
        enableStatus(inst)
    end

    local function removecomponent(owner)
        if owner and owner:IsValid() then 
            owner:RemoveComponent("passive_shadows2hm")
            if owner.components.combat then
                owner.components.combat.externaldamagemultipliers:RemoveModifier(inst, "nightsword2hm")
            end
        end
        
    end

    local perishtime = 480 * 1.5
    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            if not data.owner.components.passive_shadows2hm then data.owner:AddComponent("passive_shadows2hm") end
            if data.owner.passive_shadowsoldnum2hm then
                data.owner.components.passive_shadows2hm:SetDamageThreshold(data.owner.passive_shadowsoldnum2hm["damage_threshold"])
                data.owner.components.passive_shadows2hm.damage_dealt = data.owner.passive_shadowsoldnum2hm["damage_dealt"]
                data.owner.components.passive_shadows2hm.weapon = inst
                data.owner.passive_shadowsoldnum2hm = nil
            end
            UpdateStatus(inst)
            inst.removecomponent2hm = function(...) removecomponent(data.owner) end
            inst:ListenForEvent("onhitother", inst.UpdateStatus2hm, data.owner)
            inst:ListenForEvent("onremove", inst.removecomponent2hm)
        end
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            data.owner.passive_shadowsoldnum2hm = {}
            data.owner.passive_shadowsoldnum2hm["damage_threshold"] = data.owner.components.passive_shadows2hm.damage_threshold
            data.owner.passive_shadowsoldnum2hm["damage_dealt"] = data.owner.components.passive_shadows2hm.damage_dealt
            data.owner:RemoveComponent("passive_shadows2hm")
            UpdateStatus(inst)
            inst:RemoveEventCallback("onhitother", removecomponent, data.owner)
            inst:RemoveEventCallback("onremove", inst.removecomponent2hm)
        end
    end
    local resetweaponperishableview = InfusionView.Refresh
    local function onrepaired(inst, repairuse, doer, repair_item, useitems)
        if repair_item.prefab == "horrorfuel" or repair_item.prefab == "dreadstone" then
            if inst.components.finiteuses:GetPercent() >= 1 then useitems = useitems + 0.5 end
            if not inst.components.perishable then
                inst:AddTag("show_spoilage")
                inst:AddComponent("perishable")
                inst.components.perishable.perishtime = perishtime
                inst.components.perishable.perishremainingtime = perishtime / 3 * math.clamp(useitems, 1, 5) *
                                                                        (repair_item.prefab == "dreadstone" and 2 or 1)
                inst.components.perishable:StartPerishing()
                if not inst.resetviewtask2hm then inst.resetviewtask2hm = inst:DoTaskInTime(0, resetweaponperishableview) end
                UpdateStatus(inst)
            else
                inst.components.perishable:AddTime(perishtime / 3 * useitems * (repair_item.prefab == "dreadstone" and 2 or 1))
            end
        elseif repair_item.prefab == "nightmarefuel" and inst.components.finiteuses:GetPercent() >= 1 and inst.components.perishable then
            inst.components.perishable:AddTime(perishtime / 6)
        end
    end
    local function onperished(inst)
        if inst.components.perishable then
            inst:RemoveTag("show_spoilage")
            inst:RemoveComponent("perishable")
            inst:DoTaskInTime(0, resetweaponperishableview)
            UpdateStatus(inst)
        end
    end
    local function checkweapon(inst)
        if inst.components.perishable and (inst.components.perishable.perishremainingtime or 0) <= 0 then
            inst:RemoveTag("show_spoilage")
            inst:RemoveComponent("perishable")
            if not inst.resetviewtask2hm then inst.resetviewtask2hm = inst:DoTaskInTime(0, resetweaponperishableview) end
            UpdateStatus(inst)
        end
    end

    local function DisplayNameFn(inst)
        return inst:HasTag("show_spoilage") and ((TUNING.isCh2hm and "注魔的 " or "Infused ") .. STRINGS.NAMES.NIGHTSWORD ..
                    (inst.weaponlevel2hm and inst.weaponlevel2hm:value() > 0 and
                        (" Lv" .. inst.weaponlevel2hm:value() .. (inst.weaponlevel2hm:value() >= 4 and " Max" or "")) or "")) or nil
    end

    local function itemtiletextfn(inst, itemtile)
        local leveltext
        local tmplevel = inst.weaponlevel2hm and inst.weaponlevel2hm:value()
        if tmplevel and tmplevel > 0 then
            leveltext = "Lv" .. tmplevel
        end
        return "weaponlevel2hmdirty", leveltext
    end

    AddPrefabPostInit("nightsword", function(inst)
        inst.repairmaterials2hm = {horrorfuel = TUNING.NIGHTSWORD_USES / 4, dreadstone = TUNING.NIGHTSWORD_USES / 2}
        if GetModConfigData("Construction Amulet Repair Equip") then inst.repairmaterials2hm.nightmarefuel = TUNING.NIGHTSWORD_USES / 11 end
        inst.displaynamefn = DisplayNameFn
        inst.itemtilefn2hm = itemtiletextfn
        InfusionView.Install(inst)
        inst:AddTag("show_spoilage")
        inst.weaponlevel2hm = net_tinybyte(inst.GUID, "weapon.level2hm", "weaponlevel2hmdirty")
        if not TheWorld.ismastersim then return end
        inst:AddComponent("perishable")
        inst.components.perishable.perishtime = perishtime
        inst.components.perishable.perishremainingtime = 0
        inst.components.perishable:StartPerishing()
        inst:DoTaskInTime(0, checkweapon)
        inst:ListenForEvent("perished", onperished)
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.ignoremax = true
        inst.components.repairable2hm.onrepaired = onrepaired
        local equippable = inst.components.equippable
        if equippable then
            equippable.dapperness = TUNING.CRAZINESS_SMALL
            local dapperfn = equippable.dapperfn
            if dapperfn then
                -- Scale the existing aura so owner-specific modifiers still apply.
                local scale = TUNING.CRAZINESS_SMALL / TUNING.CRAZINESS_MED
                equippable.dapperfn = function(item, owner) return dapperfn(item, owner) * scale end
            end
            inst:ListenForEvent("equipped", onequip)
            inst:ListenForEvent("unequipped", onunequip)
        end
        inst.weaponlevel2hm:set(0)
        inst.level2hm = 0
        inst.UpdateStatus2hm = function(...) UpdateStatus(inst) end
    end)
end

-- ==================== 远古守护者之角强化远古装备 ====================
-- 守卫者之角(犀牛角)右键强化远古装备, 强化后改名并解锁特殊能力
-- 升级方式: 手持犀牛角右键装备, 走修理动作(材料里配置犀牛角), 每次强化消耗1个犀牛角
local ANCIENT_ENHANCE_TAG = "ancient_enhanced2hm" -- 强化标记(tag随存档持久化, 客户端同步)
-- 犀牛角强化远古装备仅犀牛"难度加强"档(配置2)才生效; 旧档true兼容
local MINOTAUR_HARD_ENHANCE = GetModConfigData("minotaur") == 2 or GetModConfigData("minotaur") == true
local SourceModifierList = require("util/sourcemodifierlist")

-- 强化后的名字
local ancient_equip_names = {
    multitool_axe_pickaxe = "远古多用镐斧",
    ruinshat = "远古铥矿皇冠",
    ruins_bat = "远古铥矿棒",
    armorruins = "远古铥矿盔甲",
    yellowamulet = "远古魔光护符",
}

local function ancient_displaynamefn(inst)
    if inst:HasTag(ANCIENT_ENHANCE_TAG) then
        return ancient_equip_names[inst.prefab]
    end
end

-- 犀牛角强化动作(全局函数, 供 easy_items 的犀牛角附魔合并调用)
function ancientenhance_condition2hm(inst, doer, actions, right, target)
    -- 未开启犀牛难度加强档: 强化不可用(即使装备已有强化标记, 效果也不生效)
    if not MINOTAUR_HARD_ENHANCE then return false end
    return target ~= nil and target:IsValid() and target.prefab ~= nil and ancient_equip_names[target.prefab] ~= nil and
        not target:HasTag(ANCIENT_ENHANCE_TAG)
end

function ancientenhance_actionfn2hm(inst, doer, target, pos, act)
    if not ancientenhance_condition2hm(inst, doer, nil, false, target) then return false end
    -- 按犀牛角状态roll: 成功则强化装备, 角的状态变化/消失由 roll 处理
    return horn_upgrade_roll2hm(inst, doer, function()
        target:AddTag(ANCIENT_ENHANCE_TAG)
        if target.ancient_enhance2hm then target.ancient_enhance2hm(target) end
    end)
end

-- ==================== 犀牛角磨损机制 ====================
-- 状态设计(独立prefab minotaurhorn_2): 普通角升级成功后转为微瑕角, 微瑕/破损用tag区分:
--   原版角: 升级成功不消耗, 1张角转为微瑕的minotaurhorn_2
--   微瑕角: 80%成功(角变破损) / 20%失败(角消失)
--   破损角: 50%成功(角保留) / 50%失败(角消失)
-- 独立prefab从代码层面隔断所有需要普通犀牛角的合成(配方按prefab名匹配, 微瑕/破损角无法作为普通角使用)
-- 状态tag随网络同步, 并经实体OnSave/OnLoad持久化(退出重进/重启服务器保留)

-- 变体角失败消失: 只消失1张(支持同状态堆叠)
local function remove_one_horn2hm(inst)
    if inst.components.stackable and inst.components.stackable.stacksize > 1 then
        inst.components.stackable:Get(1):Remove()
    else
        inst:Remove()
    end
end

-- 把犀牛角(1张)转换为对应状态的minotaurhorn_2, 放回原位置(背包原槽位/容器/地面)
local function convert_horn_to_variant2hm(inst, broken)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
    local x, y, z = inst.Transform:GetWorldPosition()
    local stacksize = inst.components.stackable and inst.components.stackable.stacksize or 1
    local newhorn = SpawnPrefab("minotaurhorn_2")
    if newhorn then
        newhorn:AddTag(broken and "broken_horn2hm" or "flawed_horn2hm")
        if owner and owner:IsValid() then
            if owner.components.inventory then
                -- 玩家背包/手上: 单张尽量放回原槽位, 堆叠多张放任意空位
                if stacksize == 1 then
                    local slot = owner.components.inventory:GetItemSlot(inst)
                    owner.components.inventory:GiveItem(newhorn, nil, slot)
                else
                    owner.components.inventory:GiveItem(newhorn)
                end
            elseif owner.components.container then
                -- 容器: 找原位置放回
                local slot = nil
                for k, v in pairs(owner.components.container.slots) do
                    if v == inst then slot = k break end
                end
                if slot then owner.components.container:GiveItem(newhorn, slot)
                else owner.components.container:GiveItem(newhorn) end
            else
                newhorn.Transform:SetPosition(x, y, z)
            end
        else
            newhorn.Transform:SetPosition(x, y, z)
        end
    end
    -- 原角: 单张直接移除; 堆叠多张取1张移除, 其余保持普通
    if stacksize > 1 then
        local single = inst.components.stackable:Get(1)
        if single and single ~= inst then single:Remove() end
    else
        inst:Remove()
    end
end

function horn_upgrade_roll2hm(inst, doer, successfn)
    if not successfn then return false end
    if inst.prefab == "minotaurhorn_2" then
        if inst:HasTag("broken_horn2hm") then
            -- 破损角: 50%成功且保留
            if math.random() < 0.5 then
                successfn()
                return true
            end
            -- 失败: 角消失
            remove_one_horn2hm(inst)
            return true
        else
            -- 微瑕角: 80%成功(角变破损)
            if math.random() < 0.8 then
                successfn()
                inst:RemoveTag("flawed_horn2hm")
                inst:AddTag("broken_horn2hm")
                return true
            end
            -- 失败: 角消失
            remove_one_horn2hm(inst)
            return true
        end
    else
        -- 普通犀牛角: 升级成功消耗 1 张
        successfn()
        remove_one_horn2hm(inst)
        return true
    end
end

-- 犀牛角状态名字
local function horn_displaynamefn(inst)
    if inst:HasTag("broken_horn2hm") then
        return TUNING.isCh2hm and "破损的犀牛角" or "Broken Guardian Horn"
    elseif inst:HasTag("flawed_horn2hm") then
        return TUNING.isCh2hm and "微瑕的犀牛角" or "Flawed Guardian Horn"
    end
end

-- 犀牛角状态持久化(退出重进/重启服务器保留)
local function horn_statesave(inst, data)
    if inst:HasTag("flawed_horn2hm") then data.horn_flawed2hm = true end
    if inst:HasTag("broken_horn2hm") then data.horn_broken2hm = true end
end
local function horn_stateload(inst, data)
    if data then
        if data.horn_flawed2hm then inst:AddTag("flawed_horn2hm") end
        if data.horn_broken2hm then inst:AddTag("broken_horn2hm") end
    end
end

-- 犀牛角: 对远古装备提供"附魔"动作(与懒人手杖附魔共用动作文字, 由 easy_items 合并)
STRINGS.ACTIONS.ACTION2HM.ENCHANT = TUNING.isCh2hm and "附魔" or "Enchant"
-- 新prefab名字与检查描述(显示名由displaynamefn覆盖为微瑕/破损)
STRINGS.NAMES.MINOTAURHORN_2 = TUNING.isCh2hm and "犀牛角" or "Guardian Horn"
if STRINGS.CHARACTERS then
    for _, data in pairs(STRINGS.CHARACTERS) do
        if data and data.DESCRIBE and data.DESCRIBE.MINOTAURHORN then
            data.DESCRIBE.MINOTAURHORN_2 = data.DESCRIBE.MINOTAURHORN
        end
    end
end

-- 普通角与变体角共用: 右键动作/状态名字/堆叠拦截/持久化
local function setup_horn_postinit(inst)
    inst.actionothercondition2hm = ancientenhance_condition2hm
    inst.actiontext2hm = "ENCHANT"
    -- 状态名字(客户端+服务端)
    inst.displaynamefn = horn_displaynamefn
    -- 不同状态(普通/微瑕/破损)的犀牛角禁止堆叠合并, 防止状态混在一起(原版CanStackWith钩子)
    inst.stackable_CanStackWithFn = function(inst, item)
        if item.prefab ~= inst.prefab then return true end
        local function hornstate(x)
            if x:HasTag("broken_horn2hm") then return 2
            elseif x:HasTag("flawed_horn2hm") then return 1
            else return 0 end
        end
        return hornstate(inst) == hornstate(item)
    end
    if not TheWorld.ismastersim then return end
    if not inst.components.action2hm then inst:AddComponent("action2hm") end
    inst.components.action2hm.actionfn = ancientenhance_actionfn2hm
    -- 犀牛角状态持久化(退出重进/重启服务器保留)
    SetOnSave(inst, horn_statesave)
    SetOnLoad(inst, horn_stateload)
end

AddPrefabPostInit("minotaurhorn", function(inst)
    setup_horn_postinit(inst)
    if not TheWorld.ismastersim then return end
    -- 旧档迁移: 旧方案(同prefab+tag)的变体角转为 minotaurhorn_2 (DoTaskInTime(0)确保OnLoad已恢复状态tag)
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() then return end
        if inst:HasTag("flawed_horn2hm") or inst:HasTag("broken_horn2hm") then
            convert_horn_to_variant2hm(inst, inst:HasTag("broken_horn2hm"))
        end
    end)
end)

AddPrefabPostInit("minotaurhorn_2", function(inst)
    setup_horn_postinit(inst)
end)

-- 镐斧强化: 稿力提升为1000%
local function enhance_multitool(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function()
        if inst:IsValid() and inst.components.tool then
            inst.components.tool:SetAction(ACTIONS.MINE, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY * 10)
        end
    end)
end

-- 铥头强化: 护盾(forcefield)期间挨打不掉耐久 + 装备期间每次挨打恢复1点生命
local function enhance_ruinshat(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.armor and not inst._ancient_hat_nodur_hooked then
        inst._ancient_hat_nodur_hooked = true
        local oldTakeDamage = inst.components.armor.TakeDamage
        inst.components.armor.TakeDamage = function(self, damage_amount)
            if inst:HasTag("forcefield") then
                -- 护盾期间不掉耐久, 保留伤害转理智与特效反馈
                damage_amount = damage_amount * (self.conditionlossmultipliers and self.conditionlossmultipliers:Get() or 1)
                if self.ontakedamage ~= nil then self.ontakedamage(self.inst, damage_amount) end
                self.inst:PushEvent("armordamaged", damage_amount)
                return
            end
            return oldTakeDamage(self, damage_amount)
        end
    end
    -- 装备事件维护监听；未装备的强化头盔不再周期检查持有者。
    if not inst._ancient_hat_heal_task then
        inst._ancient_hat_heal_task = true
        local function onhatattacked(owner, data)
            if owner and owner:IsValid() and owner.components.health and not owner.components.health:IsDead() and
                inst.components.equippable and inst.components.equippable:IsEquipped() then
                owner.components.health:DoDelta(1)
            end
        end
        inst._ancient_hat_onattacked = onhatattacked
        local function refreshowner(inst)
            local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
            if not (owner and owner:IsValid() and inst.components.equippable and inst.components.equippable:IsEquipped()) then owner = nil end
            if inst._ancient_hat_owner == owner then return end
            if inst._ancient_hat_owner then
                inst:RemoveEventCallback("attacked", onhatattacked, inst._ancient_hat_owner)
            end
            inst._ancient_hat_owner = owner
            -- The item owns this subscription, so removal also cleans it up.
            if owner then inst:ListenForEvent("attacked", onhatattacked, owner) end
        end
        inst:ListenForEvent("equipped", refreshowner)
        inst:ListenForEvent("unequipped", refreshowner)
        inst:ListenForEvent("onputininventory", refreshowner)
        inst:ListenForEvent("ondropped", refreshowner)
        refreshowner(inst)
        inst:DoTaskInTime(0, refreshowner) -- Saved equipment may be restored later.
    end
end

-- 铥棒强化: 攻击必定召唤暗影触手(原版为20%概率)
local function enhance_ruinsbat(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.weapon and not inst._ancient_bat_hooked then
        inst._ancient_bat_hooked = true
        local old_onattack = inst.components.weapon.onattack
        inst.components.weapon.onattack = function(inst, owner, target)
            if inst:HasTag(ANCIENT_ENHANCE_TAG) then
                local pt
                if target ~= nil and target:IsValid() then
                    pt = target:GetPosition()
                else
                    pt = owner:GetPosition()
                    target = nil
                end
                local offset = FindWalkableOffset(pt, math.random() * TWOPI, 2, 3, false, true, function(p) return not TheWorld.Map:IsPointNearHole(p) end, false, true, true)
                if offset ~= nil then
                    inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_1")
                    inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_2")
                    local tentacle = SpawnPrefab("shadowtentacle")
                    if tentacle ~= nil then
                        tentacle.owner = owner
                        tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
                        tentacle.components.combat:SetTarget(target)
                    end
                end
            elseif old_onattack then
                old_onattack(inst, owner, target)
            end
        end
    end
end

-- 铥甲强化: 免疫击飞硬直 + 完全无受击反馈(装备时给玩家_stunprotecter上modifier)
local function enhance_armorruins(inst)
    inst:AddTag("heavyarmor")
    if not TheWorld.ismastersim then return end
    if inst.armorruins_nostun2hm then return end
    inst.armorruins_nostun2hm = true
    inst:ListenForEvent("equipped", function(inst, data)
        local owner = data and data.owner
        if owner and owner._stunprotecter then
            owner._stunprotecter:SetModifier(inst, true)
        end
    end)
    inst:ListenForEvent("unequipped", function(inst, data)
        local owner = data and data.owner
        if owner and owner._stunprotecter then
            owner._stunprotecter:RemoveModifier(inst)
        end
    end)
    -- 重载/重进时已穿着: 立即补挂(equipped事件可能已错过)
    if inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.inventoryitem.owner._stunprotecter then
        inst.components.inventoryitem.owner._stunprotecter:SetModifier(inst, true)
    end
end

-- 玩家霸体组件: _stunprotecter 为布尔modifier, 穿戴强化铥甲时置真
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst._stunprotecter == nil then
        inst._stunprotecter = SourceModifierList(inst, false, SourceModifierList.boolean)
    end
end)

-- 霸体生效: 受击时当前状态加nointerrupt标签, 玩家SG原处理遇nointerrupt只播音效不切hit(无受击反馈)
AddStategraphPostInit("wilson", function(sg)
    if sg.events and sg.events.attacked and sg.events.attacked.fn then
        local old_attacked = sg.events.attacked.fn
        sg.events.attacked.fn = function(inst, data)
            if inst._stunprotecter ~= nil and inst._stunprotecter:Get() then
                inst.sg:AddStateTag("nointerrupt")
            end
            old_attacked(inst, data)
        end
    end
end)

-- 魔光护符(yellowamulet)强化: 放背包也生效(照明+20%移速+回理智), 检查护符切换开关(与视野扩展器同款交互)
-- 开关默认开(nil视为开), 检查护符时在开/关间切换; 装备时仍用原版效果, 未装备(背包)时生效
local RefreshAncientMagi2hm
local function QueueAncientMagi2hm(inst)
    if inst._ancient_magi_refresh_task or not inst:IsValid() then return end
    inst._ancient_magi_refresh_task = inst:DoTaskInTime(0, function(inst)
        inst._ancient_magi_refresh_task = nil
        RefreshAncientMagi2hm(inst, false, true)
    end)
end

local function SetAncientMagiSpeed2hm(inst, owner)
    local previous = inst._ancient_magi_speed_owner
    if previous ~= owner then
        local sources = previous and previous._ancient_magi_sources2hm
        if sources then
            sources[inst] = nil
            if next(sources) == nil then
                if previous:IsValid() and previous.components.playerspeedmult then
                    previous.components.playerspeedmult:RemoveCappedPredictedSpeedMult("ancient_magi2hm")
                end
                previous._ancient_magi_sources2hm = nil
                previous._ancient_magi_speed_component2hm = nil
            end
        end
        inst._ancient_magi_speed_owner = owner
    end
    if owner then
        owner._ancient_magi_sources2hm = owner._ancient_magi_sources2hm or {}
        owner._ancient_magi_sources2hm[inst] = true
        local speed = owner.components.playerspeedmult
        if speed and owner._ancient_magi_speed_component2hm ~= speed then
            speed:SetCappedPredictedSpeedMult("ancient_magi2hm", 1.2)
            owner._ancient_magi_speed_component2hm = speed
        end
    end
end

local function ClearAncientMagi2hm(inst)
    if inst._ancient_magi_light and inst._ancient_magi_light:IsValid() then inst._ancient_magi_light:Remove() end
    inst._ancient_magi_light = nil
    inst._ancient_magi_light_owner = nil
    SetAncientMagiSpeed2hm(inst, nil)
end

local ANCIENT_MAGI_OWNER_EVENTS2HM = {"onputininventory", "ondropped", "onremove", "death", "ms_respawnedfromghost"}
local function WatchAncientMagiOwners2hm(inst)
    for _, watch in ipairs(inst._ancient_magi_watches or {}) do
        inst:RemoveEventCallback(watch.event, watch.fn, watch.source)
    end
    local watches, seen = {}, {[inst] = true}
    inst._ancient_magi_watches = watches
    if not inst._ancient_magi_ownerchanged then
        inst._ancient_magi_ownerchanged = function() QueueAncientMagi2hm(inst) end
    end
    local child = inst
    local function watch(source, event, fn)
        watches[#watches + 1] = {source = source, event = event, fn = fn}
        inst:ListenForEvent(event, fn, source)
    end
    while child.components.inventoryitem do
        local owner = child.components.inventoryitem.owner
        if not owner or not owner:IsValid() or seen[owner] then break end
        seen[owner] = true
        local item = child
        local function moved(_, data)
            if data and (data.item == item or data.prev_item == item) then QueueAncientMagi2hm(inst) end
        end
        watch(owner, "itemget", moved)
        watch(owner, "itemlose", moved)
        for _, event in ipairs(ANCIENT_MAGI_OWNER_EVENTS2HM) do
            watch(owner, event, inst._ancient_magi_ownerchanged)
        end
        child = owner
    end
end

local function TickAncientMagi2hm(inst) RefreshAncientMagi2hm(inst, true) end

RefreshAncientMagi2hm = function(inst, tick, rebind)
    if not inst:IsValid() then return end
    if rebind then WatchAncientMagiOwners2hm(inst) end
    local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
    local equipped = inst.components.equippable and inst.components.equippable:IsEquipped()
    local fueled = inst.components.fueled
    local enhanced = inst:HasTag(ANCIENT_ENHANCE_TAG)
    local active = enhanced and inst._ancient_magi_on2hm ~= false and owner and owner:IsValid() and
        owner:HasTag("player") and not equipped and owner.components.health and not owner.components.health:IsDead() and
        not (fueled and fueled:IsEmpty())
    if active then
        if not inst._ancient_magi_light or not inst._ancient_magi_light:IsValid() or inst._ancient_magi_light_owner ~= owner then
            ClearAncientMagi2hm(inst)
            local light = SpawnPrefab("minerhatlight")
            if light then
                light.entity:SetParent(owner.entity)
                light.Light:SetRadius(4)
                light.Light:SetIntensity(0.7)
                light.Light:SetFalloff(0.5)
                light.Light:SetColour(0.65, 0.75, 1)
                light.Light:Enable(true)
                inst._ancient_magi_light = light
                inst._ancient_magi_light_owner = owner
            end
        end
        SetAncientMagiSpeed2hm(inst, owner)
        if tick and owner.components.sanity then owner.components.sanity:DoDelta(1 / 60) end
    else
        ClearAncientMagi2hm(inst)
    end
    if fueled and enhanced then
        local want = not equipped and active or false
        if equipped then want = nil end -- Native equip callbacks own fuel use.
        if inst._ancient_magi_fuel_state ~= want or (want ~= nil and fueled.consuming ~= want) then
            inst._ancient_magi_fuel_state = want
            if want == true then fueled:StartConsuming()
            elseif want == false then fueled:StopConsuming() end
        end
    end
    -- Ground/chest recharge is intentional too. Only idle, full or nighttime
    -- items can stop ticking; world/fuel/ownership events start them again.
    local solar = enhanced and fueled and not equipped and TheWorld.state.isday and not TheWorld:HasTag("cave") and fueled:GetPercent() < 1
    if tick and solar then fueled:DoDelta(0.5) end
    solar = solar and fueled:GetPercent() < 1
    if active or solar then
        if not inst._ancient_magi_task then inst._ancient_magi_task = inst:DoPeriodicTask(0.5, TickAncientMagi2hm) end
    elseif inst._ancient_magi_task then
        inst._ancient_magi_task:Cancel()
        inst._ancient_magi_task = nil
    end
end

local function enhance_yellowamulet(inst)
    if not TheWorld.ismastersim then return end
    if not inst._ancient_magi_inspect_hooked then
        inst._ancient_magi_inspect_hooked = true
        if not inst.components.inspectable then inst:AddComponent("inspectable") end
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, ...)
            local desc, filter_context, author = GetDescription(self, ...)
            if self.inst:HasTag(ANCIENT_ENHANCE_TAG) then
                self.inst._ancient_magi_on2hm = not self.inst._ancient_magi_on2hm
                local state = self.inst._ancient_magi_on2hm and (TUNING.isCh2hm and "开" or "ON") or (TUNING.isCh2hm and "关" or "OFF")
                desc = (desc or "") .. (TUNING.isCh2hm and ("\n" .. "魔光生效: " .. state) or ("\n" .. "Pocket active: " .. state))
                QueueAncientMagi2hm(inst)
            end
            return desc, filter_context, author
        end
        -- 护符删除时清理挂载的光源与移速
        inst:ListenForEvent("onremove", function()
            ClearAncientMagi2hm(inst)
            if inst._ancient_magi_task then inst._ancient_magi_task:Cancel(); inst._ancient_magi_task = nil end
            if inst._ancient_magi_refresh_task then inst._ancient_magi_refresh_task:Cancel(); inst._ancient_magi_refresh_task = nil end
        end)
        -- 保留上游耗尽行为（原生会移除护符）；兼容依赖_owner的其他回调。
        -- 有持有者补owner正常清理，无持有者只停消耗。
        if not inst._ancient_magi_depleted_hooked then
            inst._ancient_magi_depleted_hooked = true
            local fueled = inst.components.fueled
            if fueled and fueled.depleted then
                local old_depleted = fueled.depleted
                fueled.depleted = function(i)
                    if not i._owner then
                        i._owner = i.components.inventoryitem and i.components.inventoryitem:GetGrandOwner()
                    end
                    if not i._owner then
                        if fueled then fueled:StopConsuming() end
                        return
                    end
                    old_depleted(i)
                    -- 背包/落地场景: 补的临时owner用完清掉, 避免残留干扰后续onequip/onunequip
                    if not i.components.equippable or not i.components.equippable:IsEquipped() then i._owner = nil end
                end
            end
        end
    end
    if not inst._ancient_magi_task_started then
        inst._ancient_magi_task_started = true
        for _, event in ipairs({"onputininventory", "ondropped", "onownerputininventory", "onownerdropped", "equipped", "unequipped"}) do
            inst:ListenForEvent(event, QueueAncientMagi2hm)
        end
        inst:ListenForEvent("percentusedchange", function(inst, data)
            if not inst._ancient_magi_task or data and type(data.percent) == "number" and (data.percent <= 0 or data.percent >= 1) then
                QueueAncientMagi2hm(inst)
            end
        end)
        inst:WatchWorldState("isday", QueueAncientMagi2hm)
        QueueAncientMagi2hm(inst) -- Also covers enhancement while already held.
    end
end

-- 注册5件远古装备(仅犀牛难度加强档才挂载强化效果/改名/存档恢复; 未开启时即使装备带强化标记也无效)
if MINOTAUR_HARD_ENHANCE then
local ancient_equips = {
    { prefab = "multitool_axe_pickaxe", enhance = enhance_multitool },
    { prefab = "ruinshat", enhance = enhance_ruinshat },
    { prefab = "ruins_bat", enhance = enhance_ruinsbat },
    { prefab = "armorruins", enhance = enhance_armorruins },
    { prefab = "yellowamulet", enhance = enhance_yellowamulet },
}
-- 强化状态存档(与手杖附魔同款写法): 标记写入实体OnSave, 加载时恢复标记并重挂效果
-- 运行时AddTag不随存档保存, 上下洞穴(跨shard序列化)与进出服务器(存档重载)都会重新反序列化实体,
-- 组件方法/任务不序列化, 恢复后需通过 enhance 重新应用
local function AncientEnchantdatasave(inst, data)
    data.ancient_enhanced2hm = inst:HasTag(ANCIENT_ENHANCE_TAG)
    if inst.prefab == "yellowamulet" then
        data.ancient_magi_on2hm = inst._ancient_magi_on2hm or false
    end
end
local function AncientEnchantdataload(inst, data)
    if data and data.ancient_enhanced2hm then
        inst:AddTag(ANCIENT_ENHANCE_TAG)
        if inst.prefab == "yellowamulet" and data.ancient_magi_on2hm ~= nil then
            inst._ancient_magi_on2hm = data.ancient_magi_on2hm
        end
        if inst.ancient_enhance2hm then
            inst.ancient_enhance2hm(inst)
        end
    end
end

for i, v in ipairs(ancient_equips) do
    AddPrefabPostInit(v.prefab, function(inst)
        -- 客户端显示强化后的名字(物品栏/悬停)
        inst.displaynamefn = ancient_displaynamefn
        if not TheWorld.ismastersim then return end
        inst.ancient_enhance2hm = v.enhance
        -- 强化状态持久化: 上下洞穴/进出服务器(反序列化)后恢复标记并重挂效果
        SetOnSave(inst, AncientEnchantdatasave)
        SetOnLoad(inst, AncientEnchantdataload)
        -- 已强化(从存档加载): 恢复强化效果
        if inst:HasTag(ANCIENT_ENHANCE_TAG) then
            v.enhance(inst)
        end
    end)
end
end
