----------------------------[物品(非建筑、非装备，可放入物品栏)]--------------------------------
---------------------------------------------------------------------------------
local hardmode = TUNING.hardmode2hm

-- 钓具箱/超级钓具箱存放角色专属道具
if GetModConfigData("Tackle Box Can Hold Role's Item") then
    local function disabledroponopen(inst, self) if self.droponopen then self.droponopen = nil end end
    AddComponentPostInit("container", function(self)
        -- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
        if self.inst:HasTag("wx78_special_container") then return end
        
        if self.inst:HasTag("portablestorage") then
		self.inst:AddTag("portablestoragePG")
		self.inst:RemoveTag("portablestorage") end
        self.inst:DoTaskInTime(0, disabledroponopen, self)
    end)
    -- TUNING.SEEDPOUCH_PRESERVER_RATE = 0
    local function perish_rate_multiplier(inst, item) return item and (item:HasTag("spider") or item:HasTag("spore")) and 0 or 1 end
    local function TackleBoxCanHoldRolesItem(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.preserver == nil then
            inst:AddComponent("preserver")
            inst.components.preserver:SetPerishRateMultiplier(perish_rate_multiplier)
        end
    end
    AddPrefabPostInit("tacklecontainer", TackleBoxCanHoldRolesItem)
    AddPrefabPostInit("supertacklecontainer", TackleBoxCanHoldRolesItem)
    local containers = require("containers")
    local specialitems = {"lucy", "ghostflower", "scandata", "spear_wathgrithr_lightning_charged"}
    if containers and containers.params and containers.params.tacklecontainer and containers.params.supertacklecontainer then
        local olditemtestfn = containers.params.tacklecontainer.itemtestfn
        local newitemtestfn = function(container, item, slot)
            return item.prefab ~= nil and
                       ((AllRecipes[item.prefab] ~= nil and AllRecipes[item.prefab].builder_tag ~= nil) or
                           table.contains(CRAFTING_FILTERS.CHARACTER.recipes, item.prefab) or item:HasTag("spider") or item:HasTag("spore") or
                           table.contains(specialitems, item.prefab) or item.dryveggies2hm or item.dryseeds2hm) and (container.containeritem2hm or not (item.replica and item.replica.container))
        end
        containers.params.tacklecontainer.itemtestfn = function(container, item, slot)
            return olditemtestfn == nil or olditemtestfn(container, item, slot) or newitemtestfn(container, item, slot)
        end
        containers.params.supertacklecontainer.itemtestfn = containers.params.tacklecontainer.itemtestfn
    end
    AddComponentPostInit("pocketwatch_dismantler", function(self)
        local oldDismantle = self.Dismantle
        self.Dismantle = function(self, target, doer, ...)
            local owner = target.components.inventoryitem:GetGrandOwner()
            if owner == nil then return end
            return oldDismantle(self, target, doer, ...)
        end
    end)
    -- local function oninspirationdelta(inst)
    --     local owner = inst.owner2hm
    --     if owner and owner:IsValid() and owner:HasTag("player") and owner.components.singinginspiration and
    --         owner.components.singinginspiration:CanAddSong(inst.songdata) then
    --         inst.components.inventoryitem:ChangeImageName(inst.prefab)
    --     else
    --         inst.components.inventoryitem:ChangeImageName(inst.prefab .. "_unavaliable")
    --     end
    -- end
    -- local function ondropped(inst)
    --     local owner = inst.owner2hm
    --     if owner and owner:IsValid() and owner:HasTag("player") and owner.components.singinginspiration and inst.oninspirationdelta2hm then
    --         inst:RemoveEventCallback("inspirationdelta", inst.oninspirationdelta2hm, owner)
    --         inst.owner2hm = nil
    --     end
    --     oninspirationdelta(inst)
    -- end
    -- local function onputininventory(inst)
    --     local owner = inst.components.inventoryitem:GetGrandOwner()
    --     if inst.owner2hm == owner then return end
    --     ondropped(inst)
    --     if owner and owner:IsValid() and owner:HasTag("player") and owner.components.singinginspiration and inst.oninspirationdelta2hm then
    --         inst.owner2hm = owner
    --         inst:ListenForEvent("inspirationdelta", inst.oninspirationdelta2hm, owner)
    --     end
    --     oninspirationdelta(inst)
    -- end
    -- local function processsong(inst)
    --     if not TheWorld.ismastersim then return end
    --     inst.oninspirationdelta2hm = function(owner) inst:DoTaskInTime(0, oninspirationdelta) end
    --     inst:ListenForEvent("onputininventory", onputininventory)
    --     inst:ListenForEvent("ondropped", ondropped)
    -- end
    -- local song_tunings = require("prefabs/battlesongdefs").song_defs
    -- for k, v in pairs(song_tunings) do AddPrefabPostInit(k, processsong) end
end

-- 作祟救赎的心复活
if GetModConfigData("Haunt Telltale Heart To Revive") then
    local function OnHauntFn(inst, haunter)
        inst:Hide()
        inst.persists = false
        inst:DoTaskInTime(5, inst.Remove)
        return true
    end
    AddPrefabPostInit("reviver", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.hauntable then inst:AddComponent("hauntable") end
        inst.components.hauntable:SetOnHauntFn(OnHauntFn)
        inst.components.hauntable:SetOnUnHauntFn(inst.Remove)
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)
    end)
    -- 2025.7.25 melon:双尾心   可作祟复活，去除新鲜度，制作扣10血
    AddPrefabPostInit("wortox_reviver", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.hauntable then inst:AddComponent("hauntable") end
        inst.components.hauntable:SetOnHauntFn(OnHauntFn)
        inst.components.hauntable:SetOnUnHauntFn(inst.Remove)
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)
        if inst.components.perishable then inst:RemoveComponent("perishable") end -- 去除新鲜度
    end)
    if hardmode then -- 2025.7.25 melon:双尾心困难模式制作增加10血
        Recipe2("wortox_reviver",{Ingredient("wortox_soul", 10), Ingredient(CHARACTER_INGREDIENT.HEALTH, 10)},TECH.NONE,{builder_skill="wortox_lifebringer_1"})
    end
    AddComponentPostInit("hauntable", function(self)
        local DoHaunt = self.DoHaunt
        self.DoHaunt = function(self, doer, ...)
            if self.inst:IsValid() and self.inst.components.container then
                local item = self.inst.components.container:FindItem(function(item)
                    return item and item:IsValid() and item.components.hauntable and item.components.hauntable.hauntvalue == TUNING.HAUNT_INSTANT_REZ
                end)
                if item then
                    self.inst.components.container:DropItem(item)
                    return DoHaunt(self, doer, ...)
                end
            end
            DoHaunt(self, doer, ...)
        end
    end)
    local ex_fns = require "prefabs/player_common_extensions"
    local OnRespawnFromGhost = ex_fns.OnRespawnFromGhost
    ex_fns.OnRespawnFromGhost = function(inst, data, ...)
        OnRespawnFromGhost(inst, data, ...)
        if data then inst.rezsource2hm = (data.user and data.user:GetDisplayName()) or (data.source and data.source:GetBasicDisplayName()) end
    end
    require "widgets/eventannouncer"
    local GetNewRezAnnouncementString = GLOBAL.GetNewRezAnnouncementString
    GLOBAL.GetNewRezAnnouncementString = function(theRezzed, source, ...)
        if theRezzed and (source == STRINGS.NAMES.SHENANIGANS or source == nil) and theRezzed.rezsource2hm then source = theRezzed.rezsource2hm end
        theRezzed.rezsource2hm = nil
        return GetNewRezAnnouncementString(theRezzed, source, ...)
    end
    local function processskeleton(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.lootdropper then
            inst.components.lootdropper.min_speed = 2.5
            inst.components.lootdropper.max_speed = 4
        end
    end
    AddPrefabPostInit("skeleton", processskeleton)
    AddPrefabPostInit("skeleton_player", processskeleton)
end

-- 自动航行的暗影船
if GetModConfigData("boat use shadowheart upgrade") then
    -- 客户端暗影船血量显示
    AddClassPostConstruct("widgets/boatmeter", function(self)
        local RefreshHealth = self.RefreshHealth
        self.RefreshHealth = function(self, ...)
            if self.boat and self.boat:IsValid() and self.boat:HasTag("shadowboathealth2hm") and self.boat.components.healthsyncer and
                not self.boat.components.healthsyncer.processd2hm then
                self.boat.components.healthsyncer.processd2hm = true
                self.boat.components.healthsyncer.max_health = self.boat.components.healthsyncer.max_health * 4
            end
            RefreshHealth(self, ...)
        end
    end)
    -- 暗影船自动修漏洞
    local function delayrepairleak(leak)
        if leak and leak:IsValid() and leak:HasTag("boat_leak") and leak.components.boatleak then
            if leak.components.boatleak.current_state == "med_leak" then
                leak.components.boatleak:SetState("small_leak")
                leak:DoTaskInTime(10, delayrepairleak)
            else
                leak.AnimState:SetMultColour(0.75, 0.75, 0.75, 0.75)
                leak.components.boatleak:SetState("repaired_treegrowth")
            end
        end
    end
    local function tryinstrepairleak(inst)
        if inst.components.boatleak and inst.components.boatleak.boat and inst.components.boatleak.boat:IsValid() and
            inst.components.boatleak.boat:HasTag("shadowboat2hm") and not inst.repair2hm then
            inst.repair2hm = true
            inst:DoTaskInTime(10, delayrepairleak)
        end
    end
    AddPrefabPostInit("boat_leak", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.boatleak then inst:DoTaskInTime(0, tryinstrepairleak) end
    end)
    local function onspawnnewboatleak(inst, data)
        if inst.prefab == "boat_grass" and data and data.leak_size then
            local damage = TUNING.BOAT.GRASSBOAT_LEAK_DAMAGE[data.leak_size]
            if damage ~= nil then inst.components.health:DoDelta(damage / 2) end
        elseif inst.components.hullhealth then
            for index, leak in pairs(inst.components.hullhealth.leak_indicators) do
                if leak and leak:IsValid() and not leak.repair2hm then
                    leak.repair2hm = true
                    leak:DoTaskInTime(10, delayrepairleak)
                end
            end
            for index, leak in pairs(inst.components.hullhealth.leak_indicators_dynamic) do
                if leak and leak:IsValid() and not leak.repair2hm then
                    leak.repair2hm = true
                    leak:DoTaskInTime(10, delayrepairleak)
                end
            end
        end
    end
    local function delayonspawnnewboatleak(inst, data) inst:DoTaskInTime(0, onspawnnewboatleak, data) end
    -- 升级后自动修甲板和漏洞,并定位暗影舵
    local function repairandfindsteeringwheel(inst)
        if inst.components.hullhealth then
            for index, leak in pairs(inst.components.hullhealth.leak_indicators) do
                if leak and leak:IsValid() and not leak.repair2hm then
                    leak.repair2hm = true
                    leak:DoTaskInTime(10, delayrepairleak)
                end
            end
            for index, leak in pairs(inst.components.hullhealth.leak_indicators_dynamic) do
                if leak and leak:IsValid() and not leak.repair2hm then
                    leak.repair2hm = true
                    leak:DoTaskInTime(10, delayrepairleak)
                end
            end
        end
        -- 暗影舵
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 4, {"steeringwheel"})
        if ents and #ents > 0 then
            for i, ent in ipairs(ents) do
                if ent and ent:IsValid() and ent.components.steeringwheel and ent:GetCurrentPlatform() == inst and not ent.isshadowsail2hm then
                    ent.isshadowsail2hm = true
                    ent.AnimState:SetMultColour(0.75, 0.75, 0.75, 1)
                end
            end
        end
        -- 暗影船甲板保护自动修理
        if inst.components.boatring then
            for index, boatbumper in ipairs(inst.components.boatring.boatbumpers) do
                if boatbumper and not boatbumper.prefab == "boat_bumper_crabking" and boatbumper:IsValid() and boatbumper.components.health and not boatbumper.components.health:IsDead() then
                    boatbumper.components.health:StartRegen(1, 20)
                end
            end
        end
    end
    -- 把船变成暗影船,血量提高,开始自愈
    local function makeboatshadowsail(inst)
        inst.AnimState:SetMultColour(0.75, 0.75, 0.75, 0.75)
        inst:AddTag("shadowboat2hm")
        if inst.components.health then
            local max = inst.components.health.maxhealth
            if max == TUNING.BOAT.HEALTH or (TUNING.BOAT.ANCIENT_BOAT and max == TUNING.BOAT.ANCIENT_BOAT.HEALTH) then
                inst:AddTag("shadowboathealth2hm")
                inst.components.health.maxhealth = max * 4
                if inst.components.healthsyncer then inst.components.healthsyncer.max_health = inst.components.health.maxhealth end
                inst.components.health:DoDelta(max * 3)
            end
            inst.components.health:StartRegen(1, 10)
        end
        -- 草船不再持续损坏
        if inst.components.hullhealth then inst.components.hullhealth:SetSelfDegrading(0) end
        -- 甲板添加时自动自愈
        if inst.components.boatring then
            local AddBumper = inst.components.boatring.AddBumper
            inst.components.boatring.AddBumper = function(self, bumper, ...)
                AddBumper(self, bumper, ...)
                if bumper and bumper:IsValid() and bumper.components.health and not bumper.components.health:IsDead() then
                    bumper.components.health:StartRegen(1, 20)
                end
            end
        end
        -- 漏洞出现时自动修复
        inst:ListenForEvent("spawnnewboatleak", delayonspawnnewboatleak)
        if inst.sinkloot then
            local oldsinkloot = inst.sinkloot
            inst.sinkloot = function(...)
                oldsinkloot(...)
                local x, y, z = inst.Transform:GetWorldPosition()
                local heart = SpawnPrefab("shadowheart")
                heart.Transform:SetPosition(x, y, z)
                heart.disableupgrade2hm = true
                heart:DoTaskInTime(240, function() if heart.disableupgrade2hm then heart.disableupgrade2hm = nil end end)
            end
        end
        inst:DoTaskInTime(0, repairandfindsteeringwheel)
    end
    -- 加载暗影船
    local function processpersistent(inst, data) if data and data.shadowsail then makeboatshadowsail(inst) end end
    local boats = {"boat", "boat_grass", "boat_pirate", "dragonboat_body", "boat_ancient", "boat_otterden"}
    for _, boat in ipairs(boats) do
        AddPrefabPostInit(boat, function(inst)
            if not TheWorld.ismastersim then return end
            if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
            inst.onload2hm = processpersistent
        end)
    end
    -- 黑心落到船上后,会升级船为暗影船,并产生升级特效
    local function processplatform(inst)
        if inst and inst:IsValid() and not inst.disableupgrade2hm then
            local platform = inst:GetCurrentPlatform()
            if platform and platform:IsValid() and platform.components.health and not platform.components.health:IsDead() and
                table.contains(boats, platform.prefab) and not platform:HasTag("shadowboat2hm") and not platform.components.vanish_on_sleep then
                platform.components.persistent2hm.data.shadowsail = true
                makeboatshadowsail(platform)
                inst:Remove()
                TUNING.disablepillarreticuleonce2hm = true
                local spell = SpawnPrefab("mod_hardmode_shadow_pillar_spell")
                TUNING.disablepillarreticuleonce2hm = nil
                spell.caster = platform
                spell.disablepillar = true
                local x, y, z = platform.Transform:GetWorldPosition()
                spell.entity:SetParent(platform.entity)
                spell.Transform:SetPosition(platform.entity:WorldToLocalSpace(x, y, z))
            end
        end
    end
    local function ondropped(inst) inst:DoTaskInTime(0, processplatform) end
    AddPrefabPostInit("shadowheart", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("ondropped", ondropped)
    end)
    -- 暗影船自动航行,玩家下船后解除自动航行
    local function autoshadowsail(inst)
        if not (inst.components.boatphysics and inst.shadowsailor2hm and not inst.shadowsailor2hm:HasTag("playerghost") and
            inst.shadowsailor2hm:GetCurrentPlatform() == inst) then
            if inst.shadowsailor2hm and inst.shadowsailor2hm:IsValid() and inst.shadowsailor2hm.components.talker and
                not inst.shadowsailor2hm:HasTag("playerghost") then
                inst.shadowsailor2hm.components.talker:Say((TUNING.isCh2hm and "我似乎失去了什么" or "I seem to have lost something"))
            end
            inst.shadowsailor2hm = nil
            if inst.shadowwalktask2hm then
                inst.shadowwalktask2hm:Cancel()
                inst.shadowwalktask2hm = nil
            end
            return
        end
        if inst.components.boatphysics.steering_rotate then return end
        local pos = Vector3(inst.Transform:GetWorldPosition())
        local doer_x, doer_y, doer_z = inst.shadowsailor2hm.Transform:GetWorldPosition()
        local row_dir_x, row_dir_z = doer_x - pos.x, doer_z - pos.z
        if math.abs(row_dir_x) < 0.8 and math.abs(row_dir_z) < 0.8 then return end
        local character_force_mult = inst.shadowsailor2hm.components.expertsailor ~= nil and
                                         inst.shadowsailor2hm.components.expertsailor:GetRowForceMultiplier() or 1
        local character_extra_max_velocity = inst.shadowsailor2hm.components.expertsailor ~= nil and
                                                 inst.shadowsailor2hm.components.expertsailor:GetRowExtraMaxVelocity() or 0
        inst.components.boatphysics:ApplyRowForce(row_dir_x, row_dir_z, 0.3 * character_force_mult, 2 + character_extra_max_velocity)
        inst.components.boatphysics:SetTargetRudderDirection(row_dir_x, row_dir_z)
    end
    -- 首次操作船舵时会获得船只权限,拥有权限的人在船上走动会操控舵的坐标,再次操作则会失去权限
    local function resetboatsailor(inst, platform, sailor)
        if inst.components.steeringwheel.sailor ~= sailor then return end
        platform.shadowsailor2hm = sailor
        inst.components.steeringwheel:StopSteering()
        sailor.components.steeringwheeluser:SetSteeringWheel(nil)
        sailor:PushEvent("stop_steering_boat")
        if sailor.sg then sailor.sg:GoToState("changeoutsidewardrobe") end
        if not platform.shadowwalktask2hm then platform.shadowwalktask2hm = platform:DoPeriodicTask(0.25, autoshadowsail) end
    end
    -- 暗影船上的船舵有特殊特效,可以通过船舵激活自动航行或关闭自动航行
    local function checksteeringwheel(inst, self)
        if not inst:IsValid() then return end
        if not inst.isshadowsail2hm then
            local platform = inst:GetCurrentPlatform()
            if platform and platform:HasTag("shadowboat2hm") then
                inst.isshadowsail2hm = true
                inst.AnimState:SetMultColour(0.75, 0.75, 0.75, 1)
            end
        end
        local oldonstartfn = self.onstartfn
        self.onstartfn = function(inst, sailor, ...)
            oldonstartfn(inst, sailor, ...)
            local platform = inst:GetCurrentPlatform()
            if inst.isshadowsail2hm and platform and platform:HasTag("shadowboat2hm") and sailor and sailor:HasTag("player") then
                if platform.shadowsailor2hm ~= sailor then
                    inst:DoTaskInTime(0, resetboatsailor, platform, sailor)
                elseif platform.shadowsailor2hm == sailor then
                    platform.shadowsailor2hm = nil
                    if sailor and sailor.components.talker then
                        sailor.components.talker:Say((TUNING.isCh2hm and "我似乎失去了什么" or "I seem to have lost something"))
                    end
                end
            end
        end
    end
    AddComponentPostInit("steeringwheel", function(self) self.inst:DoTaskInTime(0, checksteeringwheel, self) end)
    -- -- 隐藏船只,船只上的单位一并隐藏
    -- local function hideboat(inst)
    --     if inst.components.persistent2hm.data.platformfollowers then return end
    --     inst.components.persistent2hm.data.platformfollowers = {}
    --     if inst.components.walkableplatform then inst.components.walkableplatform:SetEntitiesOnPlatform() end
    --     if inst.platformfollowers then
    --         local shore_pt
    --         for k, v in pairs(inst.platformfollowers) do
    --             if k and k:IsValid() and k.GUID and k ~= inst then
    --                 if k:HasTag("ignorewalkableplatformdrowning") or k:HasTag("player") then
    --                     if k.components.drownable ~= nil then
    --                         if shore_pt == nil then
    --                             shore_pt = Vector3(FindRandomPointOnShoreFromOcean(inst.Transform:GetWorldPosition()))
    --                         end
    --                         k:PushEvent("onsink", {boat = inst, shore_pt = shore_pt})
    --                     else
    --                         k:PushEvent("onsink", {boat = inst})
    --                     end
    --                     inst:RemovePlatformFollower(k)
    --                 else
    --                     k:RemoveFromScene()
    --                     inst:RemovePlatformFollower(k)
    --                     table.insert(inst.components.persistent2hm.data.platformfollowers, k.GUID)
    --                 end
    --             end
    --         end
    --     end
    --     if inst.components.walkableplatform then inst.components.walkableplatform:StopUpdating() end
    --     if inst.components.boatphysics then inst.components.boatphysics:StopUpdating() end
    --     if inst.OnPhysicsSleep then inst:OnPhysicsSleep() end
    --     if inst.stopupdatingtask then
    --         inst.stopupdatingtask:Cancel()
    --         inst.stopupdatingtask = nil
    --     end
    --     inst:RemoveFromScene()
    -- end
end

-- 橙宝石升级牛铃铛
if GetModConfigData("beef_bell use orangegem upgrade") then
    local function resetbeefaloskin(inst, clothingdata, player)
        if inst.components.skinner_beefalo and player and player:IsValid() and clothingdata then
            -- inst.components.skinner_beefalo:reloadclothing(clothingdata) 
            local newdata = deepcopy(clothingdata)
            inst.components.skinner_beefalo:ApplyTargetSkins(newdata, player)
        end
    end
    local function processnewsummonbeefalo(inst, beefalo, record)
        -- 2025.10.15 melon:复活仅10%血
        if inst.components.persistent2hm.data.beefalo_has_dead and beefalo.components.health then -- 刚死过才执行
            beefalo.components.health:SetPercent(0.1)
            inst.components.persistent2hm.data.beefalo_has_dead = nil
        end
        -- 
        if beefalo.components.lootdropper then
            beefalo.components.lootdropper:SetLoot()
            beefalo.components.lootdropper:SetChanceLootTable()
            beefalo.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            beefalo.components.lootdropper.GenerateLoot = emptytablefn
            beefalo.components.lootdropper.DropLoot = emptytablefn
        end
        if beefalo.components.writeable then beefalo.components.writeable:SetOnWritingEndedFn() end
        if inst and record then
            beefalo.Transform:SetPosition(inst.Transform:GetWorldPosition())
            local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
            if not inst.initskin2hm and owner and owner:IsValid() and owner:HasTag("player") then
                inst.initskin2hm = true
                if record.clothing and beefalo.components.skinner_beefalo then beefalo:DoTaskInTime(0, resetbeefaloskin, record.clothing, owner) end
            end
        end
    end
    local function relivebeefalo(inst)
        inst.relivetask2hm = nil
        if not inst:GetBeefalo() and inst.components.persistent2hm.data.beefalo then
            inst.tmpenable2hm = true
            inst:OnLoad(inst.components.persistent2hm.data.beefalo)
            if inst:GetBeefalo() then
                inst:AddTag("hasbeefalo2hm")
                local beefalo = inst:GetBeefalo()
                inst.components.persistent2hm.data.beefalo_has_dead = true -- 2025.10.15 melon:标记刚死过
                processnewsummonbeefalo(inst, beefalo, inst.components.persistent2hm.data.beefalo)
            end
            inst.tmpenable2hm = nil
        end
    end
    local function killbeefalo(inst, beefalo)
        if beefalo and beefalo:IsValid() and beefalo.components.health and not beefalo.components.health:IsDead() then beefalo.components.health:Kill() end
    end
    local function on_beef_disappeared(inst, beefalo)
        inst:RemoveTag("hasbeefalo2hm")
        -- 牛被拐走了,被拐走的牛直接杀掉
        if not inst.components.persistent2hm.data.beefalotmp and beefalo and beefalo:IsValid() and beefalo.components.health and
            not beefalo.components.health:IsDead() then inst:DoTaskInTime(0, killbeefalo, beefalo) end
        if not inst.components.persistent2hm.data.beefalotmp and not inst.relivetask2hm then inst.relivetask2hm = inst:DoTaskInTime(240, relivebeefalo) end
    end
    local function on_used_on_beefalo(inst, target, user)
        if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
        if inst.tmpenable2hm then return inst.oldon_used_on_beefalo2hm(inst, target, user) end
        return false, "BEEF_BELL_HAS_BEEF_ALREADY"
    end
    local function on_stop_use(inst)
        if inst:GetBeefalo() then
            -- 已有牛则召回牛
            local beefalo = inst:GetBeefalo()
            if beefalo.components.rideable.rider then beefalo.components.rideable.rider.components.rider:ActualDismount() end
            inst.components.persistent2hm.data.beefalotmp = nil
            local data = {}
            inst:OnSave(data)
            inst.components.persistent2hm.data.beefalotmp = data
            if inst:HasTag("hasbeefalo2hm") then
                inst:PushEvent("player_despawn")
                inst:RemoveTag("hasbeefalo2hm")
            end
        elseif inst.components.persistent2hm.data.beefalotmp and not inst.relivetask2hm then
            -- 没有牛但有召回存档则召唤牛
            inst.tmpenable2hm = true
            inst:OnLoad(inst.components.persistent2hm.data.beefalotmp)
            if inst:GetBeefalo() then
                inst:AddTag("hasbeefalo2hm")
                local beefalo = inst:GetBeefalo()
                processnewsummonbeefalo(inst, beefalo, inst.components.persistent2hm.data.beefalotmp)
            end
            inst.components.persistent2hm.data.beefalotmp = nil
            inst.tmpenable2hm = nil
        elseif not inst.components.persistent2hm.data.beefalotmp and not inst.relivetask2hm then
            -- 没有牛没有召回存档则复活牛
            local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
            if owner and owner.components.talker then
                owner.components.talker:Say(TUNING.isCh2hm and "牛牛还在墓地里" or "it is waiting god's help")
            end
            inst.relivetask2hm = inst:DoTaskInTime(240, relivebeefalo)
        else
            local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
            if owner and owner.components.talker then
                owner.components.talker:Say(TUNING.isCh2hm and "牛牛还在墓地里" or "it is waiting god's help")
            end
        end
        if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
    end
    -- 升级后改造牛铃铛和牛
    local function upgradebeef_bell(inst)
        inst:AddTag("bell_upgrade2hm")
        if inst.components.useabletargeteditem then
            inst.oldon_used_on_beefalo2hm = inst.components.useabletargeteditem.onusefn
            inst.components.useabletargeteditem:SetOnUseFn(on_used_on_beefalo)
            inst.components.useabletargeteditem:SetOnStopUseFn(on_stop_use)
        end
        if inst.components.leader then inst.components.leader.onremovefollower = on_beef_disappeared end
        if inst:GetBeefalo() then
            -- 升级时有牛,则改造牛
            inst:AddTag("hasbeefalo2hm")
            local beefalo = inst:GetBeefalo()
            processnewsummonbeefalo(inst, beefalo)
        elseif not inst.components.persistent2hm.data.beefalotmp then
            -- 开局升级时没有牛,则要么牛死亡中,要么牛召回了
            on_beef_disappeared(inst)
        end
        if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
    end
    local function ItemTradeTest(inst, item, giver)
        return inst:GetBeefalo() and item and
                   ((item.prefab == "orangegem" and not inst:HasTag("bell_upgrade2hm")) or (item.prefab == "horn" and inst:HasTag("bell_upgrade2hm")) or
                       (item.prefab == "beefalowool" and inst:HasTag("bell_upgrade2hm")))
    end
    -- 首次改造牛铃铛时,牛回满血掉落牛鞍,然后永久存档牛的数据
    local function OnAccept(inst, giver, item)
        if item and item.prefab == "orangegem" and not inst:HasTag("bell_upgrade2hm") and inst:GetBeefalo() then
            inst.components.persistent2hm.data.bell_upgrade = true
            local beefalo = inst:GetBeefalo()
            if beefalo.components.health then beefalo.components.health:SetPercent(1) end
            if beefalo.components.rideable then
                if beefalo.components.rideable.rider then beefalo.components.rideable.rider.components.rider:ActualDismount() end
                beefalo.components.rideable:SetSaddle(nil, nil)
            end
            if beefalo.components.container then beefalo.components.container:DropEverything() end
            if beefalo.components.inventory then beefalo.components.inventory:DropEverything(false) end
            inst.components.persistent2hm.data.beefalo = nil
            inst.components.persistent2hm.data.beefalotmp = nil
            local data = {}
            inst:OnSave(data)
            inst.components.persistent2hm.data.beefalo = data
            upgradebeef_bell(inst)
        elseif item and item.prefab == "horn" and inst:HasTag("bell_upgrade2hm") and inst:GetBeefalo() then
            local beefalo = inst:GetBeefalo()
            if beefalo.components.health then beefalo.components.health:SetPercent(1) end
            if beefalo.components.rideable then
                if beefalo.components.rideable.rider then beefalo.components.rideable.rider.components.rider:ActualDismount() end
                beefalo.components.rideable:SetSaddle(nil, nil)
            end
            if beefalo.components.container then beefalo.components.container:DropEverything() end
            if beefalo.components.inventory then beefalo.components.inventory:DropEverything(false) end
            inst.components.persistent2hm.data.beefalo = nil
            inst.components.persistent2hm.data.beefalotmp = nil
            local data = {}
            inst:OnSave(data)
            inst.components.persistent2hm.data.beefalo = data
        elseif giver and item and item.prefab == "beefalowool" and inst:HasTag("bell_upgrade2hm") and inst:GetBeefalo() then
            local beefalo = inst:GetBeefalo()
            if beefalo.components.writeable then
                beefalo.components.writeable:SetOnWritingEndedFn(nil)
                beefalo.components.writeable:BeginWriting(giver)
            end
        end
    end
    local function processpersistent(inst)
        if inst.components.persistent2hm.data.bell_upgrade then
            upgradebeef_bell(inst)
            inst.components.inventoryitem:ChangeImageName("beef_bell_linked")
            inst.AnimState:PlayAnimation("idle2", true)
            inst:AddTag("nobundling")
        end
    end
    STRINGS.ACTIONS.STOPUSINGITEM.SHOWBEEF2HM = TUNING.isCh2hm and "召唤" or "Out"
    STRINGS.ACTIONS.STOPUSINGITEM.HIDEBEEF2HM = TUNING.isCh2hm and "召回" or "In"
    local oldSTOPUSINGITEMstrfn = ACTIONS.STOPUSINGITEM.strfn
    ACTIONS.STOPUSINGITEM.strfn = function(act)
        local res = oldSTOPUSINGITEMstrfn(act)
        if res == "BEEF_BELL" and act.invobject and act.invobject.prefab == "beef_bell" and act.invobject:HasTag("bell_upgrade2hm") then
            return act.invobject:HasTag("hasbeefalo2hm") and "HIDEBEEF2HM" or "SHOWBEEF2HM"
        end
        return res
    end
    AddPrefabPostInit("beef_bell", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then return end
        inst:AddComponent("trader")
        inst.components.trader:SetAbleToAcceptTest(ItemTradeTest)
        inst.components.trader.onaccept = OnAccept
        inst.components.trader.acceptnontradable = true
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst:DoTaskInTime(0, processpersistent)
    end)
    -- 覆盖不妥协测试版(3193922031)的牛铃铛右键召唤动作UM_CALL_BEEF:
    -- 不妥协给牛铃铛新增了右键"Call Beefalo"(牛跑过来跟随5秒,priority=10会抢走右键),与本模组橙宝石牛铃的收牛/召唤/复活冲突。
    -- 本模组后加载(priority -11110 晚于不妥协 -10),在这里把该动作从右键菜单过滤掉并使其fn无效,保留本模组功能。
    AddSimPostInit(function()
        if ACTIONS and ACTIONS.UM_CALL_BEEF then
            ACTIONS.UM_CALL_BEEF.fn = function() return false end -- 即使残留入口也禁止执行
            -- 不妥协先加载已通过包装CollectActions的INVENTORY["useabletargeteditem"]插入UM_CALL_BEEF,这里再包一层把该动作从列表移除
            local COMPONENT_ACTIONS = UpvalueHacker.GetUpvalue(EntityScript.CollectActions, "COMPONENT_ACTIONS")
            if COMPONENT_ACTIONS and COMPONENT_ACTIONS.INVENTORY then
                local INVENTORY = COMPONENT_ACTIONS.INVENTORY
                local _useabletargeteditem = INVENTORY["useabletargeteditem"]
                if _useabletargeteditem then
                    INVENTORY["useabletargeteditem"] = function(inst, doer, actions, right, ...)
                        local res = _useabletargeteditem(inst, doer, actions, right, ...)
                        if actions then
                            for i = #actions, 1, -1 do
                                if actions[i] == ACTIONS.UM_CALL_BEEF then
                                    table.remove(actions, i)
                                end
                            end
                        end
                        return res
                    end
                end
            end
        end
    end)
    local function heardhorn(follower, musician) follower.sg:PushEvent("heardhorn", {musician = musician}) end
    -- AddPrefabPostInit("horn", function(inst)
    --     if not TheWorld.ismastersim then return end
    --     if inst.components.instrument then
    --         local onheard = inst.components.instrument.onheard
    --         inst.components.instrument:SetOnHeardFn(function(v, musician, inst, ...)
    --             if v and v.prefab == "beefalo" and v.components.follower and v.components.follower.leader and v.components.follower.leader.prefab == "beef_bell" then
    --                 if v.components.combat ~= nil and v.components.combat:TargetIs(musician) then v.components.combat:SetTarget(nil) end
    --                 v:DoTaskInTime(math.random(), heardhorn, musician)
    --                 return
    --             end
    --             return onheard(v, musician, inst, ...)
    --         end)
    --     end
    -- end)
    -- 2025.10.24 melon:去除绑定牛铃不能在物品栏放多个的限制。(为了修复重进游戏时物品栏多个升级牛铃会消失去000点的问题)
    AddPrefabPostInit("beef_bell", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.inventoryitem then
            inst.components.inventoryitem.onputininventoryfn = function(...) end
        end
    end)
end

-- 2025.5.3 melon:飞翼风帆快速升起，但制作需要邪天翁喙------------------
-- 存在问题：导致帆反复开关bug
if GetModConfigData("quick mast_malbatross") then
    -- 快速动作
    AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.LOWER_SAIL_BOOST, function(inst, action)
        local furl_target = inst.bufferedaction.target or inst.sg.mem.furl_target
        if furl_target and furl_target.prefab == "mast_malbatross" and furl_target.components.mast and furl_target.AnimState:IsCurrentAnimation("closed") then -- 鸟帆  2025.9.10 melon:加动画判断 尝试修复反复开关
            furl_target.components.mast:SailFurled() -- 升起?
            return "doshortaction"
        else -- 普通帆
            inst.sg.statemem.not_interrupted = true
            return "furl_boost"
        end
    end))
    AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.LOWER_SAIL_BOOST, function(inst, action)
        local furl_target = inst.bufferedaction.target or inst.sg.mem.furl_target
        if furl_target and furl_target.prefab == "mast_malbatross" and furl_target.components.mast then -- 鸟帆
            return "doshortaction"
        else -- 普通帆
            return "furl_boost"
        end
    end))
    -- 困难模式制作增加鸟毛----------------------------------
    if hardmode then
        AddRecipePostInit("mast_malbatross_item",function(inst) -- 更改飞翼风帆(鸟帆)配方
            table.insert(inst.ingredients, Ingredient("malbatross_feather", 2)) -- 2025.7.9 melon:改成插入
        end)
    end
end

-- 弹性空间制造器可升级移动容器
if GetModConfigData("elastispacer upgrade") then
	-- 简易制作配方
	AddRecipePostInit("chestupgrade_stacksize", function(inst)
		inst.ingredients = {Ingredient("wagpunk_bits", 4),
							Ingredient("moonglass", 6),
							Ingredient("moonstorm_spark", 2)
						}
	end)
    if CONSTRUCTION_PLANS and CONSTRUCTION_PLANS["collapsed_treasurechest"] then
        table.remove(CONSTRUCTION_PLANS["collapsed_treasurechest"], 2)
        table.insert(CONSTRUCTION_PLANS["collapsed_treasurechest"],Ingredient("chestupgrade_stacksize", 1))
    end
    if CONSTRUCTION_PLANS and CONSTRUCTION_PLANS["collapsed_dragonflychest"] then
        table.remove(CONSTRUCTION_PLANS["collapsed_dragonflychest"], 4)
        table.insert(CONSTRUCTION_PLANS["collapsed_dragonflychest"],Ingredient("chestupgrade_stacksize", 1))
    end
    -- 妥协船收纳套件禁止生成启迪碎片
    if TUNING.DSTU then
        AddPrefabPostInit("um_boatbottle", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.deployable then
                local oldondeploy = inst.components.deployable.ondeploy
                inst.components.deployable.ondeploy = function(...)
                    local _SpawnPrefab = GLOBAL.SpawnPrefab
                    GLOBAL.SpawnPrefab = function(name, ...)
                        if name == "alterguardianhatshard" then name = "chestupgrade_stacksize" end
                        return _SpawnPrefab(name, ...)
                    end
                    local boat = oldondeploy(...)
                    GLOBAL.SpawnPrefab = _SpawnPrefab
                    return boat
                end
            end
            if inst.components.complexprojectile then
                local oldonhitfn = inst.components.complexprojectile.onhitfn
                inst.components.complexprojectile.onhitfn = function(...)
                    local _SpawnPrefab = GLOBAL.SpawnPrefab
                    GLOBAL.SpawnPrefab = function(name, ...)
                        if name == "alterguardianhatshard" then name = "chestupgrade_stacksize" end
                        return _SpawnPrefab(name, ...)
                    end
                    oldonhitfn(...)
                    GLOBAL.SpawnPrefab = _SpawnPrefab
                end
            end
        end)
    end
	-- 敲拆烧别再掉启迪碎片了
    AddPrefabPostInit("dragonflychest", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.upgradeable ~= nil then
            local onupgradefn2hm = inst.components.upgradeable.onupgradefn
            inst.components.upgradeable.onupgradefn = function(inst,...)
                onupgradefn2hm(inst,...)
                if inst.components.upgradeable.numupgrades > 0 and inst.components.lootdropper ~= nil then inst.components.lootdropper:SetLoot({"chestupgrade_stacksize"}) end
            end
        end
		if inst.components.lootdropper then
			local oldspawnlootprefab = inst.components.lootdropper.SpawnLootPrefab
			inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, pt, linked_skinname, skin_id, userid, ...)
				if lootprefab == "alterguardianhatshard" then lootprefab = "chestupgrade_stacksize" end
				oldspawnlootprefab(self, lootprefab, pt, linked_skinname, skin_id, userid, ...)
			end
		end
    end)
	 AddPrefabPostInit("treasurechest", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.upgradeable ~= nil then
            local onupgradefn2hm = inst.components.upgradeable.onupgradefn
            inst.components.upgradeable.onupgradefn = function(inst,...)
                onupgradefn2hm(inst,...)
                if inst.components.upgradeable.numupgrades > 0 and inst.components.lootdropper ~= nil then inst.components.lootdropper:SetLoot({"chestupgrade_stacksize"}) end
            end
        end
		if inst.components.lootdropper then
			local oldspawnlootprefab = inst.components.lootdropper.SpawnLootPrefab
			inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, pt, linked_skinname, skin_id, userid, ...)
				if lootprefab == "alterguardianhatshard" then lootprefab = "chestupgrade_stacksize" end
				oldspawnlootprefab(self, lootprefab, pt, linked_skinname, skin_id, userid, ...)
			end
		end
    end)
	-- 可升级便携式容器 ------------------------------------------
	local function onupgrade(inst)
		if not inst:HasTag("superportablestoragePG") then inst:AddTag("superportablestoragePG") end
		if inst.components.container then
			inst.components.container:Close()
			inst.components.container:EnableInfiniteStackSize(true)
		end
		if inst.components.burnable then
			inst:RemoveComponent("burnable")
		end
	end
    -- 2025.7.25 melon:可升级部分特殊容器
    local PREFABS_UP = {"houndstooth_blowpipe"} -- 嚎弹炮
	local function isportablestorage(inst)
		--print(not inst:HasTag("superportablestoragePG"), "临时标签")
		--print(inst:HasTag("portablestorage"), "标签")
		--print(inst.components.container, "容器组件")
		--print(inst.components.inventoryitem, "物品栏物品组件")
		if not inst:HasTag("superportablestoragePG") and (inst:HasTag("portablestoragePG") or inst:HasTag("portablestorage")) or table.contains(PREFABS_UP, inst.prefab) then -- 2025.7.25 melon:增加
			return true
		end
		return false
	end
	-- 添加升级动作
	local action = Action({})
	action.priority = 1
	action.id = "UPGRADECONTAINER2HM"
	action.str = TUNING.isCh2hm and "升级" or "upgrader"
	action.fn = function(act)
		if act.target and act.target.components.container then
			act.doer.SoundEmitter:PlaySound("qol1/chest_upgrade/poof")
			onupgrade(act.target)
			act.invobject:Remove()
			return true
		else
			return false
		end
	end
	AddAction(action)
	AddComponentAction("USEITEM", "upgrader", function(inst, doer, target, actions)
		if inst.prefab ~= "chestupgrade_stacksize" then return end
		if target and isportablestorage(target) then
			table.insert(actions, ACTIONS.UPGRADECONTAINER2HM)
		end
	end)
	local handler = ActionHandler(ACTIONS.UPGRADECONTAINER2HM, function(inst, action) return "dolongaction" end)
	AddStategraphActionHandler("wilson", handler)
	AddStategraphActionHandler("wilson_client", handler)
	-- 升级容器的数据保存
	AddComponentPostInit("container", function(self)
		-- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
		if self.inst:HasTag("wx78_special_container") then return end
		
        local _onsave = self.OnSave
		self.OnSave = function(self, ...)
			local data, references = _onsave(self, ...)
			if _onsave then _onsave(self, ...) end
			if self.inst:HasTag("superportablestoragePG") then
				data.superportablestoragePG = true
			end
			return data, references
		end
		local _onload = self.OnLoad
		self.OnLoad = function(self, data, newents, ...)
			if _onload then _onload(self, data, newents, ...) end
			if data and data.superportablestoragePG then
				onupgrade(self.inst)
			end
		end
    end)
    -- 升级后容器改名
    AddPrefabPostInitAny(function(inst)
        if inst:HasTag("portablestoragePG") or inst:HasTag("portablestorage") or table.contains(PREFABS_UP, inst.prefab) then -- 2025.7.25 melon:增加
            local olddisplaynamefn = inst.displaynamefn
            inst.displaynamefn = function(inst)
                local name = STRINGS.NAMES[string.upper(inst.prefab)] or (TUNING.isCh2hm and "容器" or "Container")
                local extra 
                if inst:HasTag("superportablestoragePG") then
                    extra = (TUNING.isCh2hm and "无限- " or "Infinite- ")
                    if olddisplaynamefn then
                        _name = olddisplaynamefn(inst)
                        if _name ~= nil then 
                            name = _name
                            extra = (TUNING.isCh2hm and "无限/" or "Infinite/")
                        end
                    end
                end
                return (extra or "") .. name
            end
        end
    end)
end

-- 帝王蟹保险杠缓慢回血、摧毁死亡时破损脱落
if GetModConfigData("boat_bumper_crabking") then
    TUNING.BOAT.BUMPERS.CRABKING.HEALTH = TUNING.BOAT.BUMPERS.CRABKING.HEALTH * (ModManager:GetMod("workshop-2039181790") and 1.33 or 2)
    AddPrefabPostInit("boat_bumper_crabking", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.health then
            inst.components.health:StartRegen(10, 20)
        end
        if inst.components.lootdropper then
            local oldfn = inst.components.lootdropper.SpawnLootPrefab
            inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, ...)
                if lootprefab == "rocks" then return end
                oldfn(self, lootprefab, ...)
            end
        end
        if inst.components.workable then
            local oldfn = inst.components.workable.onfinish
            inst.components.workable.onfinish = function(inst, ...)
                oldfn(inst, ...)
                local x,y,z = inst.Transform:GetWorldPosition()
                local newbumper = SpawnPrefab("crabking_kit2hm")
                newbumper.components.rechargeable:Discharge(math.max(5,(math.ceil(inst.components.health ~= nil and inst.components.health.maxhealth * 2) or 300) * (1 - (inst.components.health ~= nil and inst.components.health:GetPercent()))))
                newbumper.Transform:SetPosition(x, 1, z)
            end
        end
        inst:ListenForEvent("death", function(inst)
            local x,y,z = inst.Transform:GetWorldPosition()
            local newbumper = SpawnPrefab("crabking_kit2hm")
            newbumper.components.rechargeable:Discharge(math.ceil(inst.components.health ~= nil and inst.components.health.maxhealth * 2) or 300)
            newbumper.Transform:SetPosition(x, 1, z)
        end)
    end)
end

-- 制作食谱卡片
if GetModConfigData("Make Cooking Recipe Card") then
    AddPrefabPostInit("cookingrecipecard", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.inspectable then
            local getdesc = inst.components.inspectable.getspecialdescription
            inst.components.inspectable.getspecialdescription = function(inst, viewer, ...)
                if inst.ingredients2hm then
                    local ing_str = subfmt(STRINGS.COOKINGRECIPECARD_DESC.INGREDIENTS_FIRST, {
                        num = inst.ingredients2hm[1][2],
                        ing = STRINGS.NAMES[string.upper(inst.ingredients2hm[1][1])] or inst.ingredients2hm[1][1]
                    })
                    for i = 2, #inst.ingredients2hm do
                        ing_str = ing_str .. subfmt(STRINGS.COOKINGRECIPECARD_DESC.INGREDIENTS_MORE, {
                            num = inst.ingredients2hm[i][2],
                            ing = STRINGS.NAMES[string.upper(inst.ingredients2hm[i][1])] or inst.ingredients2hm[i][1]
                        })
                    end
                    return subfmt(STRINGS.COOKINGRECIPECARD_DESC.BASE,
                                  {name = STRINGS.NAMES[string.upper(inst.recipe_name)] or inst.recipe_name, ingredients = ing_str})
                end
                return getdesc(inst, viewer, ...)
            end
        end
        SetOnSave(inst, function(inst, data) data.i2hm = inst.ingredients2hm end)
        SetOnLoad(inst, function(inst, data) if data and data.i2hm then inst.ingredients2hm = data.i2hm end end)
    end)
    local function spawnfoodcard(recipe_name, cooker_name, ingredient_prefabs)
        local ingredients = {}
        for index, ingredientprefab in ipairs(ingredient_prefabs) do
            if not STRINGS.NAMES[string.upper(ingredientprefab)] then return end
            ingredients[ingredientprefab] = (ingredients[ingredientprefab] or 0) + 1
        end
        local card = SpawnPrefab("cookingrecipecard")
        if card then
            card.recipe_name = recipe_name
            card.cooker_name = cooker_name
            if card.components.named then
                card.components.named:SetName(subfmt(STRINGS.NAMES.COOKINGRECIPECARD, {item = STRINGS.NAMES[string.upper(recipe_name)] or recipe_name}))
            end
            card.ingredients2hm = {}
            for ingredientprefab, v in pairs(ingredients) do table.insert(card.ingredients2hm, {ingredientprefab, v}) end
            return card
        end
    end
    local function papyrusUSEITEM(inst, doer, actions, right, target) return target:HasTag("stewer") end
    local function papyrusUSEITEMdoaction(inst, doer, target, pos, act)
        if target.components.stewer and doer and doer.components.inventory then
            local stewer = target.components.stewer
            if stewer:IsDone() and stewer.chef_id and stewer.chef_id == doer.userid and stewer.product and STRINGS.NAMES[string.upper(stewer.product)] and
                stewer.product and stewer.ingredient_prefabs then
                local card = spawnfoodcard(stewer.product, target.prefab, stewer.ingredient_prefabs)
                if card then
                    local item = inst.components.stackable and inst.components.stackable:Get() or inst
                    item:Remove()
                    doer.components.inventory:GiveItem(card, nil, target:GetPosition())
                    return true
                end
            end
        end
    end
    STRINGS.ACTIONS.ACTION2HM.PAPYRUS = TUNING.isCh2hm and "制作食谱卡" or "Recipe Card"
    AddPrefabPostInit("papyrus", function(inst)
        inst.actionothercondition2hm = papyrusUSEITEM
        if not TheWorld.ismastersim then return end
        inst:AddComponent("action2hm")
        inst.components.action2hm.actionfn = papyrusUSEITEMdoaction
    end)
end

-- 2025.5.31 melon:陷阱加耐久,5秒自动重置,不打随从-------------------------------------------------
if GetModConfigData("trap_teeth") then
    TUNING.TRAP_TEETH_USES = 20
    TUNING.TRAP_BRAMBLE_USES = 20
    local function reset_trap(inst)
        if inst:IsValid() and inst:HasTag("minesprung") and not inst:HasTag("mine_not_reusable") then
            inst.components.mine:Reset()
        end
    end
    -- 犬牙陷阱
    AddPrefabPostInit("trap_teeth", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.mine then
            -- 5秒重置
            local _onexplode = inst.components.mine.onexplode
            inst.components.mine.onexplode = function(inst, target)
                if _onexplode ~= nil then _onexplode(inst, target) end
                inst.resettask2hm = inst:DoTaskInTime(5, reset_trap) -- 5秒重置
            end
            -- 不会以随从为目标(不打随从)
            local _Explode = inst.components.mine.Explode
            inst.components.mine.Explode = function(self, target)
                -- 是随从不触发
                if target.components.follower ~= nil and target.components.follower:GetLeader() then return end
                if _Explode ~= nil then _Explode(self, target) end
            end
        end
    end)
    -- 荆棘陷阱--------------------------------------
    local function DoThorns(inst, pos)
        local thorns = SpawnPrefab("bramblefx_trap")
        thorns.Transform:SetPosition(pos:Get())
        thorns.canhitplayers = false -- TheNet:GetPVPEnabled() -- 把这里改成false, 就不打随从了
    end
    local function OnExplode2hm(inst)
        inst.AnimState:PlayAnimation("trap")
        inst.SoundEmitter:PlaySound("dontstarve/characters/wormwood/bramble_trap/trigger")
        inst:DoTaskInTime(11 * FRAMES, DoThorns, inst:GetPosition())
        if inst.components.finiteuses ~= nil then inst.components.finiteuses:Use(1) end
        -- 新增
        inst.resettask2hm = inst:DoTaskInTime(5, reset_trap) -- 5秒重置
    end
    AddPrefabPostInit("trap_bramble", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.mine then
            inst.components.mine:SetOnExplodeFn(OnExplode2hm)
            -- 不会以随从为目标(不打随从)
            local _Explode = inst.components.mine.Explode
            inst.components.mine.Explode = function(self, target)
                -- 是随从不触发   且主人是玩家
                if target.components.follower ~= nil and target.components.follower:GetLeader() and target.components.follower:GetLeader():HasTag("player") then return end
                if _Explode ~= nil then _Explode(self, target) end
            end
        end
    end)
end

-- 犀牛角可以附魔手杖装备获得冲锋能力
if GetModConfigData("Minotaurhorn Enchant") then
    -- 附魔装备: 三种手杖始终可附魔(0/1档直接消耗1角, 2档概率消耗); 远古装备强化仅2档(easy_equipments门控)
    local minotaur_hard_enchant = GetModConfigData("minotaur") == 2 or GetModConfigData("minotaur") == true
    local equip = {
        "orangestaff",
        "cane",
        "the_real_charles_t_horse",
    }
    local GALLOP_HIT_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" , "player", "structure", "wall"}
    -- 冲锋阶段平滑加速较慢，减速阶段平滑减速较快
    local step = 5
    local removestep = 2 * step

    -- 三秒内逐渐减速为正常水准
    local function removespeed(doer, level)
        if doer.horn_run2hm then
            local value = 0.1 * level / removestep
            doer.horn_run2hm = doer.horn_run2hm - value
            doer.horn_run2hm = math.max(doer.horn_run2hm, 1)
            if doer.horn_run2hm > 1 then
                if doer.components.playerspeedmult then
                    doer.components.playerspeedmult:SetCappedPredictedSpeedMult("horn_run2hm", doer.horn_run2hm)
                end
            elseif doer.horn_run2hm <= 1 then
                doer.horn_run2hm = nil
                if doer.components.playerspeedmult then
                    doer.components.playerspeedmult:RemoveCappedPredictedSpeedMult("horn_run2hm")
                end
                if doer.removespeedmult2hm then 
                    doer.removespeedmult2hm:Cancel()
                    doer.removespeedmult2hm = nil
                end
            end
            if doer.horn_run2hmfx then
                doer.horn_run2hmfx:Remove()
                doer.horn_run2hmfx = nil
            end
        else
            doer.components.playerspeedmult:RemoveCappedPredictedSpeedMult("horn_run2hm")
            if doer.horn_run2hmfx then
                doer.horn_run2hmfx:Remove()
                doer.horn_run2hmfx = nil
            end
            if doer.removespeedmult2hm then 
                doer.removespeedmult2hm:Cancel()
                doer.removespeedmult2hm = nil
            end
        end
    end

    -- 死亡和碰撞后立刻移除
    local function removespeedmult(doer, immediate, level)
        if not doer then return end
        if doer.components.playerspeedmult then
            if immediate or not level then 
                doer.components.playerspeedmult:RemoveCappedPredictedSpeedMult("horn_run2hm")
                doer.horn_run2hm = nil
                if doer.horn_run2hmfx then
                    doer.horn_run2hmfx:Remove()
                    doer.horn_run2hmfx = nil
                end
                if doer.addspeedmult2hm then 
                    doer.addspeedmult2hm:Cancel()
                    doer.addspeedmult2hm = nil
                end
            elseif not doer.removespeedmult2hm then
                if doer.addspeedmult2hm then 
                    doer.addspeedmult2hm:Cancel()
                    doer.addspeedmult2hm = nil
                end
                doer.removespeedmult2hm = doer:DoPeriodicTask(3 / removestep, removespeed, 3 / removestep, level)
            end
        end
        if doer.components.hunger then doer.components.hunger.burnratemodifiers:RemoveModifier(doer, "horn_run2hm") end
    end

    -- 碰撞检测
    local function TryGallopCollideUpdate(inst)
        local rot = inst.Transform:GetRotation()
        local x, y, z = inst.Transform:GetWorldPosition()
        local angle = rot * DEGREES
        local x1 = x + math.cos(angle) * .5--* self.distance
        local z1 = z - math.sin(angle) * .5--* self.distance
        local radius = inst:GetPhysicsRadius(0.5)
        local collision_group = inst.Physics:GetCollisionGroup()
        local mass = inst.Physics:GetMass()

        local target = nil
        local targetdist = math.huge
        for i, v in ipairs(TheSim:FindEntities(x1, 0, z1, radius + MAX_PHYSICS_RADIUS, {"_combat"}, GALLOP_HIT_CANT_TAGS)) do
            if v ~= inst and v.Physics and checkbit(v.Physics:GetCollisionMask(), collision_group) then
                local x2, y2, z2 = v.Transform:GetWorldPosition()
                local r = v:GetPhysicsRadius(0)
                local d = radius + r
                if distsq(x1, z1, x2, z2) < d * d then
                    d = math.sqrt(distsq(x, z, x2, z2)) - r
                    if d < targetdist then
                        target = v
                        targetdist = d
                    end
                end
            end
        end

        -- Do collision effects
        if target ~= nil then
            if target.components.follower then
                local leader = target.components.follower:GetLeader()
                if leader and (leader:HasTag("player") or leader.components.inventoryitem) then return end
            end
            removespeedmult(inst, true)
            inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/bite")
            local gallop_speedboost = inst.components.locomotor:GetRunSpeed() - TUNING.WILSON_RUN_SPEED
            target.components.combat:GetAttacked_Internal(inst, TUNING.MINOTAUR_DAMAGE)
            target:PushEventImmediate("knockback", {
                knocker = inst,
                forcelanded = true,
                radius = targetdist,
                strengthmult = 0.15 + (gallop_speedboost / (TUNING.WILSON_RUN_SPEED * 2)),
            })
            if not target:HasTag("smallcreature") then
                inst:PushEventImmediate("knockback", {
                    knocker = target,
                    forcelanded = true,
                    radius = targetdist, --data ~= nil and data.radius or physradius + 1,
                    strengthmult = 0.25 + (gallop_speedboost / (TUNING.WILSON_RUN_SPEED * 0.5)),
                })
            end

            return true
        end

        return false
    end

    -- 加速检测
    local function addspeedmult(doer, inst)
        if doer and doer:IsValid() and not (doer.components.health and doer.components.health:IsDead()) and inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value() > 0 then
            local value = 0.1 * (inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value())
            doer.horn_run2hm = (doer.horn_run2hm or 1) + value / step
            doer.horn_run2hm = math.min(doer.horn_run2hm, value + 1)
            if doer.components.playerspeedmult then doer.components.playerspeedmult:SetCappedPredictedSpeedMult("horn_run2hm", doer.horn_run2hm) end
            if doer.horn_run2hm >= value + 1 then
                if not doer.horn_run2hmfx then
                    doer.horn_run2hmfx = SpawnPrefab("tophat_shadow_fx")
                    doer.horn_run2hmfx.entity:SetParent(doer.entity)
                    doer.horn_run2hmfx.Transform:SetScale(2, 2, 2)
                end
                if inst.chargemode2hm == 1 then
                    doer.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/taunt")
                    if doer.addspeedmult2hm then
                        doer.addspeedmult2hm:Cancel()
                        doer.addspeedmult2hm = doer:DoPeriodicTask(FRAMES, TryGallopCollideUpdate)
                    end
                else
                    if doer.addspeedmult2hm then
                        doer.addspeedmult2hm:Cancel()
                        doer.addspeedmult2hm = nil
                    end
                end
                if doer.components.hunger then doer.components.hunger.burnratemodifiers:SetModifier(doer, 1.33, "horn_run2hm") end
            end
        elseif doer.components.health and doer.components.health:IsDead() then
            removespeedmult(doer, true)
        end
    end

    local function doerriding(doer)
        return doer and doer.components.rider and doer.components.rider:IsRiding()
    end

    local function changespeedmult2hm(inst, doer)
        if doer and doer:IsValid() then
            if not doer.addspeedmult2hm and not doerriding(doer) and not (doer.components.health and doer.components.health:IsDead()) and doer.sg and doer.sg:HasStateTag("moving") then
                if doer.removespeedmult2hm then 
                    doer.removespeedmult2hm:Cancel()
                    doer.removespeedmult2hm = nil
                end
                doer.addspeedmult2hm = doer:DoPeriodicTask((4 - (inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value())) / step, addspeedmult, (4 - (inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value())) / step, inst)
            elseif doer.components.health and doer.components.health:IsDead() or doerriding(doer) then
                removespeedmult(doer, true)
            elseif doer.sg and not doer.sg:HasStateTag("moving") then
                removespeedmult(doer, nil, inst.minotaurhornenchant2hm:value())
            end
        end
    end

    local function equipevent(_inst, data)
        local owner = data and data.owner
        if _inst:HasTag("horn_enchant2hm") and owner and owner:HasTag("player") then _inst:ListenForEvent("locomote", _inst.changespeedmult2hm, owner) end
    end

    local function unequipevent(_inst, data)
        local owner = data and data.owner
        if  owner and owner:HasTag("player") then
            if owner.components.health and owner.components.health:IsDead() then
                removespeedmult(owner, true)
            else
                removespeedmult(owner, nil, _inst.minotaurhornenchant2hm:value())
            end
            _inst:RemoveEventCallback("locomote", _inst.changespeedmult2hm, owner)
        end
    end

    local function Enchantfn(inst, doer, target, pos, act)
        if target ~= nil and target:HasTag("horn_enchant2hm") then return false end
        local function doenchant()
            target:AddTag("horn_enchant2hm")
            target.minotaurhornenchant2hm:set(math.min(1, (target.minotaurhornenchant2hm and target.minotaurhornenchant2hm:value() or 0) + 1))
            if not target.changespeedmult2hm then target.changespeedmult2hm = function(_doer, data) changespeedmult2hm(target, _doer) end end
            if target.components.equippable then
                target:RemoveEventCallback("equipped", equipevent)
                target:RemoveEventCallback("unequipped", unequipevent)
                target:ListenForEvent("equipped", equipevent)
                target:ListenForEvent("unequipped", unequipevent)
            end
        end
        doenchant()
        if inst.components.stackable then
            inst.components.stackable:Get(1):Remove()
        else
            inst:Remove()
        end
        return true
    end

    local function groundpoundring_fx(inst, pos, doer)
        local fx = SpawnPrefab("groundpoundring_fx")
        local hitradius = 4.65
        local fxscale = math.sqrt(hitradius / 12) --art radius is 12; sqrt coz of transform scale bug
        doer.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/groundpound")
        fx.Transform:SetScale(fxscale, fxscale, fxscale)
        if fx.FastForward ~= nil then fx:FastForward() end
        fx.Transform:SetPosition(pos.x, 0, pos.z)
        local ents = TheSim:FindEntities(pos.x, 0, pos.z, hitradius, {"_combat"}, { "FX", "NOCLICK", "DECOR", "INLIMBO", "groundpound_immune", "player", "wall"})
        for i, v in ipairs(ents) do
            if v ~= inst and v:IsValid() and v.components.health ~= nil and
            not v.components.health:IsDead() and doer.components.combat:CanTarget(v) then
                local leader = v.components.follower and v.components.follower:GetLeader()
                if not (leader and (leader:HasTag("player") or leader.components.inventoryitem)) then
                    v.components.combat:GetAttacked_Internal(inst, TUNING.MINOTAUR_DAMAGE, inst)
                end
            end
        end
    end

    local function Enchantdatasave(inst, data)
        if inst:HasTag("horn_enchant2hm") then 
            data.horn_enchant2hm = true
            data.minotaurhornenchant2hm = inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value()
        end
    end
    local function Enchantdataload(inst, data)
        if data and data.horn_enchant2hm and data.minotaurhornenchant2hm then
            inst:AddTag("horn_enchant2hm")
            inst.minotaurhornenchant2hm:set(data.minotaurhornenchant2hm)
            inst.changespeedmult2hm = function(doer) changespeedmult2hm(inst, doer) end
            if inst.components.equippable then
                inst:ListenForEvent("equipped", equipevent)
                inst:ListenForEvent("unequipped", unequipevent)
            end
        end
    end

    local function DisplayNameFn(inst)
        if not inst:HasTag("horn_enchant2hm") then
            return STRINGS.NAMES[string.upper(inst.prefab)]
        end
        
        local level = 0
        if inst.minotaurhornenchant2hm then
            level = inst.minotaurhornenchant2hm:value()
        end
        
        local level_text = tostring(level)
        local max = level >= 3 and "Max" or ""
        local prefix = TUNING.isCh2hm and "附魔 Lv" or "Enchanted Lv"
        local item_name = STRINGS.NAMES[string.upper(inst.prefab)]
        
        return prefix .. level_text .. " " .. max .. " " .. item_name
    end

    local function itemtilefn(inst, self)
        local result = inst.minotaurhornenchant2hm and inst.minotaurhornenchant2hm:value()
        if result > 0 then
            if not inst.bgimage2hm then
                inst.bgimage2hm = "minotaurhorn.tex"
                inst.bgaltas2hm = GetInventoryItemAtlas(inst.bgimage2hm)
            end
        elseif inst.bgimage2hm then
            inst.bgimage2hm = nil
            inst.bgaltas2hm = nil
        end

        return "upgrade2hmdirty", nil, inst.bgaltas2hm, inst.bgimage2hm, true
    end

    for i, v in pairs(equip) do
        AddPrefabPostInit(v, function(inst)
            inst.displaynamefn = DisplayNameFn
            inst.itemtilefn2hm = itemtilefn
            inst.minotaurhornenchant2hm = net_smallbyte(inst.GUID, "minotaurhornenchant2hm", "enchanted2hmdirty")
            inst.minotaurhornenchant2hm:set(0)
            if not TheWorld.ismastersim then return end
            inst.chargemode2hm = 0
            if v == "orangestaff" then
                if inst.components.blinkstaff then
                    local oldfn = inst.components.blinkstaff.onblinkfn
                    inst.components.blinkstaff.onblinkfn = function(_inst, pos, doer, ...)
                        if oldfn then oldfn(_inst, pos, doer, ...) end
                        if pos and _inst:HasTag("horn_enchant2hm") then
                            _inst:DoTaskInTime(0.5, groundpoundring_fx, pos, doer)
                        end
                    end
                end
            end

            if inst.components.inspectable then
                local GetDescription = inst.components.inspectable.GetDescription
                inst.components.inspectable.GetDescription = function(self, ...)
                    local desc, filter_context, author = GetDescription(self, ...)
                    if self.inst:HasTag("horn_enchant2hm") then
                        if self.inst.chargemode2hm == 0 then
                            self.inst.chargemode2hm = 1
                            desc = (desc or "") .. (TUNING.isCh2hm and "\n" .. "开启撞击模式" or "\n" .. "Activate collision mode")
                        elseif self.inst.chargemode2hm == 1 then
                            self.inst.chargemode2hm = 0
                            desc = (desc or "") .. (TUNING.isCh2hm and "\n" .. "关闭撞击模式" or "\n" .. "Turn off collision mode")
                        end
                    end
                    return  desc, filter_context, author
                end
            end
            -- 拆解手杖不再返还犀牛角(2026.8.7): 升级是概率消耗(可能失败消失), 拆解返还角会绕过消耗凭空刷角
            -- 犀牛角为一次性升级材料, 拆解不回收; 原版拆解仍返配方材料(thulecite等)
            SetOnLoad(inst, Enchantdataload)
            SetOnSave(inst, Enchantdatasave)
        end)
    end

    STRINGS.ACTIONS.ACTION2HM.ENCHANT = TUNING.isCh2hm and "附魔" or "Enchant"
    -- 普通角与变体角(minotaurhorn_2 微瑕/破损)共用懒人手杖附魔动作
    for _, hornprefab in ipairs({"minotaurhorn", "minotaurhorn_2"}) do
        AddPrefabPostInit(hornprefab, function(inst)
            -- 合并: 犀牛角还可强化远古装备(强化动作由 easy_equipments 定义)
            local oldcondition = inst.actionothercondition2hm
            inst.actionothercondition2hm = function(inst, doer, actions, right, target)
                if oldcondition and oldcondition(inst, doer, actions, right, target) then return true end
                if target and target.minotaurhornenchant2hm and target.minotaurhornenchant2hm:value() < 3 and table.contains(equip, target.prefab) then
                    return true
                end
                return false
            end
            inst.actiontext2hm = "ENCHANT"
            if not TheWorld.ismastersim then return end
            if not inst.components.action2hm then inst:AddComponent("action2hm") end
            inst.components.action2hm.actionfn = function(inst, doer, target, pos, act)
                if ancientenhance_condition2hm(inst, doer, nil, false, target) then
                    return ancientenhance_actionfn2hm(inst, doer, target, pos, act)
                end
                return Enchantfn(inst, doer, target, pos, act)
            end
        end)
    end
end

-- 无开关-------------------------------------------------------------------------------
-- 2025.5.31 melon:活动料理也能放进钓具容器----------------------------------------------
local food_prefabs = {
    "yotp_food1", "yotp_food2", "yotp_food3",  -- 猪年
    "yotr_food1", "yotr_food2", "yotr_food3", "yotr_food4", -- 兔年
}
for _,prefab in ipairs(food_prefabs) do
    AddPrefabPostInit(prefab, function(inst) inst:AddTag("preparedfood") end)
end

-- 2025.9.25 melon:留声机不能敲
AddPrefabPostInit("phonograph", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.workable then inst.components.workable:SetWorkable(nil) end
end)

-- 普通陷阱必中：复用原生捕获流程，在合拢开始时结算。
local guaranteedtrap = GetModConfigData("Trap Guaranteed Catch")
if guaranteedtrap then
    AddStategraphPostInit("trap", function(sg)
        local onenter = sg.states.sprung.onenter
        sg.states.sprung.onenter = function(inst, ...)
            onenter(inst, ...)
            if inst.trapguaranteed2hm then inst.components.trap:DoSpring() end
        end
    end)
end

local function guaranteetrapcatch(inst)
    local trap = inst.components.trap
    if not trap then return end
    inst.trapguaranteed2hm = true
    local DoSpring = trap.DoSpring
    trap.DoSpring = function(self, ...)
        -- Native animover still closes the trap, but must not settle a second
        -- time and erase its loot. Keep the upstream shadow immunity wrapper.
        if self.issprung then return end
        return DoSpring(self, ...)
    end
    local Harvest = trap.Harvest
    trap.Harvest = function(self, ...)
        -- Another player/auto-collector may harvest before the animation ends.
        -- Finish the native close state immediately before Harvest rearms it;
        -- PushEvent alone queues the event and is too late for this ordering.
        if self.issprung and inst.sg and inst.sg.currentstate.name == "sprung" then
            inst.sg:HandleEvent("animover")
        end
        return Harvest(self, ...)
    end
end

-- 陷阱可以直接右键丢弃
local function dropactionfn2hm(inst, doer, target, pos, act)
    if act.invobject ~= nil and
        act.invobject.components.equippable ~= nil and
        act.invobject.components.equippable:IsEquipped() and
        act.invobject.components.equippable:ShouldPreventUnequipping() then
        return false
    end

    return act.doer.components.inventory ~= nil
    and act.doer.components.inventory:DropItem(
            act.invobject,
            act.options.wholestack and
            not (act.invobject ~= nil and
                act.invobject.components.stackable ~= nil and
                act.invobject.components.stackable.forcedropsingle),
            (act.invobject.components.inventoryitem ~= nil
                and act.invobject.components.inventoryitem.droprandomdir)
            or act.doer.components.inventory:IsFloaterHeld(),
            act:GetActionPoint(),
            true -- <--keepoverstacked
        )
    or false
end

STRINGS.ACTIONS.ACTION2HM.SETTRAP = TUNING.isCh2hm and "设置陷阱" or "setrap"
AddPrefabPostInit("trap", function(inst)
    inst.itemstraightactioncondition2hm = function(inst, doer, actions, right)
        local inventoryitem = inst.replica.inventoryitem
        local equippable = inst.replica.equippable
        local isequipped = equippable ~= nil and equippable:IsEquipped()
        if not (isequipped and equippable:ShouldPreventUnequipping()) then
            local inventory = doer.replica.inventory
            if inventory and
                (not inventoryitem:IsLockedInSlot() or isequipped or inventory:GetActiveItem() == inst) and
                not inventory:IsFloaterHeld()
            then
                return true
            end
        end
        return false
    end
    inst.actionstate2hm = "doshortaction"
    inst.actiontext2hm = "SETTRAP"
    if not TheWorld.ismastersim then return end
    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = dropactionfn2hm
    if guaranteedtrap then guaranteetrapcatch(inst) end
end)

-- 瓶中信配方:橙色宝石 + 海盗地图 + 绳子
STRINGS.RECIPE_DESC.MESSAGEBOTTLE = TUNING.isCh2hm
    and "把一张海盗地图装进瓶子"
    or "Seal a pirate map in a bottle to reveal a hidden treasure."
AddRecipe2("messagebottle",
    { Ingredient("orangegem", 1), Ingredient("stash_map", 1), Ingredient("rope", 1) },
    TECH.SEAFARING_ONE,
    { image = "messagebottle.tex" },
    { "SEAFARING" })