local animal_change = GetModConfigData("animal_change")
local changeIndex = (animal_change == -1 or animal_change == true) and 3 or animal_change

-- 肉食来源削弱，猪羊牛猫鸟蜘蛛食人花兔人鱼人蜜蜂青蛙淡水鱼
AddComponentPostInit("spawner", function(self)
    local Configure = self.Configure
    self.Configure = function(self, childname, delay, ...)
        if delay then delay = delay * changeIndex end
        Configure(self, childname, delay, ...)
    end
end)

-- 龙蝇蜂后黑寡妇
local epicchangeindex = (changeIndex - 1) * 3 / 14 + 1
TUNING.DRAGONFLY_RESPAWN_TIME = TUNING.DRAGONFLY_RESPAWN_TIME * epicchangeindex
TUNING.BEEQUEEN_RESPAWN_TIME = TUNING.BEEQUEEN_RESPAWN_TIME * epicchangeindex
-- 猪人
-- TUNING.PIGHOUSE_SPAWN_TIME = TUNING.PIGHOUSE_SPAWN_TIME * changeIndex
-- 伏特羊和阿尔法伏特羊
TUNING.LIGHTNING_GOAT_MATING_SEASON_BABYDELAY = TUNING.LIGHTNING_GOAT_MATING_SEASON_BABYDELAY * changeIndex
TUNING.LIGHTNING_GOAT_MATING_SEASON_BABYDELAY_VARIANCE = TUNING.LIGHTNING_GOAT_MATING_SEASON_BABYDELAY_VARIANCE * changeIndex
if TUNING.DSTU then
    local function slowspawn(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.timer and inst.components.timer.StartTimer then
            local StartTimer = inst.components.timer.StartTimer
            inst.components.timer.StartTimer = function(self, name, time, ...)
                if time and name == "spawn_alpha" then time = POPULATING and time or time * changeIndex end
                return StartTimer(self, name, time, ...)
            end
        end
    end
    AddPrefabPostInit("lightninggoatherd", slowspawn)
end
-- 皮弗娄牛
TUNING.BABYBEEFALO_GROW_TIME.base = TUNING.BABYBEEFALO_GROW_TIME.base * changeIndex
TUNING.BABYBEEFALO_GROW_TIME.random = TUNING.BABYBEEFALO_GROW_TIME.random * changeIndex
-- 兔人
-- TUNING.RABBITHOUSE_SPAWN_TIME = TUNING.RABBITHOUSE_SPAWN_TIME * changeIndex
-- 兔子
-- TUNING.RABBIT_RESPAWN_TIME = TUNING.RABBIT_RESPAWN_TIME * changeIndex
-- 鼹鼠
-- TUNING.MOLE_RESPAWN_TIME = TUNING.MOLE_RESPAWN_TIME * changeIndex
-- 浣猫
TUNING.CATCOONDEN_REGEN_TIME = TUNING.CATCOONDEN_REGEN_TIME * changeIndex
TUNING.CATCOONDEN_REPAIR_TIME = TUNING.CATCOONDEN_REPAIR_TIME * changeIndex
TUNING.CATCOONDEN_REPAIR_TIME_VAR = TUNING.CATCOONDEN_REPAIR_TIME_VAR * changeIndex
-- 高脚鸟
TUNING.TALLBIRD_LAY_EGG_TIME_MIN = TUNING.TALLBIRD_LAY_EGG_TIME_MIN * changeIndex
TUNING.TALLBIRD_LAY_EGG_TIME_VAR = TUNING.TALLBIRD_LAY_EGG_TIME_VAR * changeIndex
TUNING.MIN_SPRING_SMALL_BIRD_SPAWN_TIME = TUNING.MIN_SPRING_SMALL_BIRD_SPAWN_TIME * changeIndex
TUNING.MAX_SPRING_SMALL_BIRD_SPAWN_TIME = TUNING.MAX_SPRING_SMALL_BIRD_SPAWN_TIME * changeIndex
-- 蜘蛛
TUNING.SPIDERDEN_GROW_TIME[1] = TUNING.SPIDERDEN_GROW_TIME[1] * changeIndex
TUNING.SPIDERDEN_GROW_TIME[2] = TUNING.SPIDERDEN_GROW_TIME[2] * changeIndex
TUNING.SPIDERDEN_GROW_TIME[3] = TUNING.SPIDERDEN_GROW_TIME[3] * changeIndex
-- TUNING.SPIDERDEN_GROW_TIME_QUEEN = TUNING.SPIDERDEN_GROW_TIME_QUEEN * changeIndex
TUNING.SPIDERDEN_REGEN_TIME = TUNING.SPIDERDEN_REGEN_TIME * changeIndex
TUNING.DROPPERWEB_REGEN_TIME = TUNING.DROPPERWEB_REGEN_TIME * changeIndex
-- 食人花
TUNING.LUREPLANT_HIBERNATE_TIME = TUNING.LUREPLANT_HIBERNATE_TIME * changeIndex
-- TUNING.LUREPLANT_SPAWNTIME = TUNING.LUREPLANT_SPAWNTIME * changeIndex
-- TUNING.LUREPLANT_SPAWNTIME_VARIANCE = TUNING.LUREPLANT_SPAWNTIME_VARIANCE * changeIndex
-- 鱼人
TUNING.MERMHOUSE_REGEN_TIME = TUNING.MERMHOUSE_REGEN_TIME * changeIndex
TUNING.MERMWATCHTOWER_REGEN_TIME = TUNING.MERMWATCHTOWER_REGEN_TIME * changeIndex
-- 蜜蜂
TUNING.BEEHIVE_REGEN_TIME = TUNING.BEEHIVE_REGEN_TIME * changeIndex
TUNING.WASPHIVE_REGEN_TIME = TUNING.WASPHIVE_REGEN_TIME * changeIndex
-- TUNING.BEEBOX_HONEY_TIME = TUNING.BEEBOX_HONEY_TIME * changeIndex
TUNING.BEEBOX_REGEN_TIME = TUNING.BEEBOX_REGEN_TIME * changeIndex
-- 淡水鱼
TUNING.FISH_RESPAWN_TIME = TUNING.FISH_RESPAWN_TIME * changeIndex
-- 猎犬
TUNING.HOUNDMOUND_REGEN_TIME = TUNING.HOUNDMOUND_REGEN_TIME * changeIndex
-- 青蛙
TUNING.FROG_POND_REGEN_TIME = TUNING.FROG_POND_REGEN_TIME * changeIndex
TUNING.FROG_RAIN_DELAY.min = TUNING.FROG_RAIN_DELAY.min * math.max(changeIndex / 4, 1)
TUNING.FROG_RAIN_DELAY.max = TUNING.FROG_RAIN_DELAY.max * math.max(changeIndex / 4, 1)
-- 蚊子
TUNING.MOSQUITO_POND_REGEN_TIME = TUNING.MOSQUITO_POND_REGEN_TIME * changeIndex
-- 藤壶
-- TUNING.WATERPLANT.GROW_TIME = TUNING.WATERPLANT.GROW_TIME * changeIndex
-- TUNING.WATERPLANT.GROW_VARIANCE = TUNING.WATERPLANT.GROW_VARIANCE * changeIndex
-- 穴居猴
TUNING.MONKEYBARREL_REGEN_PERIOD = TUNING.MONKEYBARREL_REGEN_PERIOD * changeIndex
-- 饼干切割机
TUNING.COOKIECUTTER_SPAWNER_REGEN_TIME = TUNING.COOKIECUTTER_SPAWNER_REGEN_TIME * changeIndex
-- 龙虾
TUNING.WOBSTER_DEN_REGEN_PERIOD = TUNING.WOBSTER_DEN_REGEN_PERIOD * changeIndex
-- 草鳄鱼
TUNING.GRASSGATOR_REGEN_TIME = TUNING.GRASSGATOR_REGEN_TIME * changeIndex
-- 蜗牛龟
TUNING.SLURTLEHOLE_REGEN_PERIOD = TUNING.SLURTLEHOLE_REGEN_PERIOD * (changeIndex > 1 and changeIndex * 1.5 or 1)
-- 水獭
TUNING.OTTERDEN_REGEN_PERIOD = TUNING.OTTERDEN_REGEN_PERIOD * changeIndex
-- 蝴蝶死亡时花枯萎
local function onbutterflyremove(inst)
    if inst.components.homeseeker and not inst:HasTag("swc2hm") and math.random() < (TheWorld.state.isday and 0.125 or 0.25) then
        local flower = inst.components.homeseeker.home
        if flower and flower:IsValid() and (flower.prefab == "flower" or flower.prefab == "flower_evil") then
            local x, y, z = flower.Transform:GetWorldPosition()
            flower:DoTaskInTime(0, flower.Remove)
            SpawnPrefab("flower_withered").Transform:SetPosition(x, y, z)
        end
    end
end
AddPrefabPostInit("butterfly", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("death", onbutterflyremove)
    if inst.components.health then inst.components.health:SetMaxHealth(25) end
end)
AddPrefabPostInit("moonbutterfly", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then inst.components.health:SetMaxHealth(25) end
end)

AddPrefabPostInit("pigking_pigtorch", function(inst) inst:AddTag("haunted") end)
AddPrefabPostInit("pigtorch", function(inst) inst:AddTag("haunted") end)

-- 食人花种子腐烂
AddPrefabPostInit("lureplantbulb", function(inst)
    inst:AddTag("show_spoilage")
    if not TheWorld.ismastersim then return end
    if not inst.components.perishable then
        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_TWO_DAY)
        inst.components.perishable:StartPerishing()
        inst.components.perishable.onperishreplacement = "spoiled_food"
    end
end)

if TUNING.NDNR_ACTIVE then
    AddComponentPostInit("ndnr_pluckable", function(self)
        local SetRespawnTime = self.SetRespawnTime
        self.SetRespawnTime = function(self, time, ...)
            if time and (self.inst.components.health or self.inst:HasTag("pond")) then
                time = time * (self.inst:HasTag("epic") and epicchangeindex or changeIndex)
            end
            SetRespawnTime(self, time, ...)
        end
    end)
end
if TUNING.DSTU then
    local function unempty(inst) if inst.components.childspawner ~= nil then inst.components.childspawner:SetMaxChildren(1) end end
    local function processtrapdoor(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.childspawner then
            local SetMaxChildren = inst.components.childspawner.SetMaxChildren
            inst.components.childspawner.SetMaxChildren = function(self, num, ...)
                if num == 1 and not POPULATING and math.random() > 1 / changeIndex then
                    num = 0
                    self.inst:DoTaskInTime(480 + math.random() * 3, unempty)
                end
                return SetMaxChildren(self, num, ...)
            end
        end
    end
    AddPrefabPostInit("trapdoor", processtrapdoor)
    AddPrefabPostInit("hoodedtrapdoor", processtrapdoor)
end

-- 冰岛冰洞
AddPrefabPostInit("icefishing_hole", function(inst)
    if not inst.components.talker then
        inst:AddComponent("talker")
        inst.components.talker.fontsize = 30
        inst.components.talker.font = TALKINGFONT
        inst.components.talker.colour = Vector3(163/255, 212/255, 158/255)
        inst.components.talker.offset = Vector3(0, 0, 0)
    end
    if not TheWorld.ismastersim then return end
    if not inst.components.fishable then
        inst:AddComponent("fishable")
        inst.components.fishable:SetRespawnTime(TUNING.FISH_RESPAWN_TIME)
        inst:RemoveTag("fishable")
        inst.components.fishable.HookFish = nilfn
    end
end)

local doAnnounce = function(self)
    local time = GetTime()
    if not self.lastAnounceTime2hm or time - self.lastAnounceTime2hm > 0.5 then
        self.lastAnounceTime2hm = time
        if self.arena and self.arena.fishinghole and self.arena.fishinghole:IsValid() and self.arena.fishinghole.components.fishable then
            if self.arena.fishinghole.components.talker then
                local fishleft = self.arena.fishinghole.components.fishable.fishleft
                local addStr = ""
                if self.arena.fishinghole.components.fishable.respawntask then
                    addStr = TUNING.util2hm.GetLanguage(', 下一条鱼 ', ', next fish in') .. TUNING.util2hm.GetTime(GetTaskRemaining(self.arena.fishinghole.components.fishable.respawntask))
                end
                if fishleft > 0 then
                    self.arena.fishinghole.components.talker:Say(TUNING.util2hm.GetLanguage("还剩" .. fishleft .. "条鱼", fishleft .. "fish in hold") .. addStr)
                else
                    self.arena.fishinghole.components.talker:Say(TUNING.util2hm.GetLanguage("没有鱼了", fishleft .. "no fish in hold") .. addStr)
                end
            end
        end
    end
end

AddComponentPostInit("sharkboimanager", function(self)
    if self.OnPlayerFishingTick and self.GetFishPrefab then
        local OnPlayerFishingTick = self.OnPlayerFishingTick
        self.OnPlayerFishingTick = function(...)
            doAnnounce(self)
            local doSwitch = false
            local mathrandom = math.random
            math.random = function(...)
                if self.arena and self.arena.fishinghole and self.arena.fishinghole:IsValid() and self.arena.fishinghole.components.fishable and
                    self.arena.fishinghole.components.fishable.fishleft > 0 then return mathrandom(...) end
                return 10
            end
            local GetFishPrefab = self.GetFishPrefab
            self.GetFishPrefab = function(self, ...)
                if self.arena and self.arena.fishinghole and self.arena.fishinghole:IsValid() and self.arena.fishinghole.components.fishable then
                    self.arena.fishinghole.components.fishable.fishleft = self.arena.fishinghole.components.fishable.fishleft - 1
                    if self.arena.fishinghole.components.fishable.respawntask == nil then
                        self.arena.fishinghole.components.fishable:RefreshFish()
                    end
                end
                self.lastAnounceTime2hm = nil
                doAnnounce(self)
                if not doSwitch then
                    math.random = mathrandom
                    doSwitch = true
                end
                return GetFishPrefab(self, ...)
            end
            OnPlayerFishingTick(...)
            self.GetFishPrefab = GetFishPrefab
            if not doSwitch then
                math.random = mathrandom
                doSwitch = true
            end
        end
    end
end)
