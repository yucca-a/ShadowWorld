local boatfirepit = GetModConfigData("oceanlife") ~= -1
if boatfirepit then
    local function checkwildfire(boat, ent, txt)
        if ent:IsValid() and ent.components.burnable and ent.components.burnable:IsSmoldering() then
            local txt = TUNING.isCh2hm and "危险!火坑引燃了我的船~~~" or "Danger!Firepit's fire burns my boat~~~"
            for index, player in ipairs(AllPlayers) do
                if player and player:IsValid() and not player:HasTag("playerghost") and player:GetCurrentPlatform() == boat and player.components.talker then
                    player.components.talker:Say(txt)
                end
            end
        end
    end
    local function smolderboat(inst, boat, fueled)
        local x, y, z = inst.parent.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 4, {"NOBLOCK", "NOCLICK", "ignorewalkableplatforms"})
        local locators = {}
        for index, ent in ipairs(ents) do
            if ent:IsValid() and ent.prefab == "burnable_locator_medium" and ent.components.burnable and not ent.components.burnable:IsSmoldering() and
                not ent.components.burnable:IsBurning() then
                table.insert(locators, ent)
                break
            end
        end
        local locator = locators[2] or locators[1]
        if locator and locator:IsValid() then
            if TheWorld.state.issummer then
                locator.components.burnable:StartWildfire()
                boat:DoTaskInTime(1, checkwildfire, locator)
            elseif math.random() < 0.33 then
                boat:PushEvent("spawnnewboatleak", {pt = inst.parent:GetPosition(), leak_size = "small_leak", playsoundfx = true})
                fueled:SetPercent(0)
                local txt = TUNING.isCh2hm and "危险!火坑烧漏了我的船~~~" or "Danger!Firepit's fire leaks my boat~~~"
                for index, player in ipairs(AllPlayers) do
                    if player and player:IsValid() and not player:HasTag("playerghost") and player:GetCurrentPlatform() == boat and player.components.talker then
                        player.components.talker:Say(txt)
                    end
                end
            end
        end
    end
    -- 
    -- 海南防风火炉不会引燃船只
    local specialcampfires = {"chiminea"}
    -- 船上点燃三级或四级火后引燃船只
    AddPrefabPostInit("campfirefire", function(inst)
        if not TheWorld.ismastersim or not inst.components.firefx then return end
        local SetLevel = inst.components.firefx.SetLevel
        inst.components.firefx.SetLevel = function(self, level, ...)
            if not POPULATING and level and level >= 3 and self.level and self.level > level and inst.parent and inst.parent:IsValid() and
                inst.parent.components.fueled and not table.contains(specialcampfires, inst.parent.prefab) and not inst.parent:IsInLimbo() then
                local boat = inst.parent:GetCurrentPlatform()
                if boat and boat:IsValid() and boat:HasTag("boat") and boat.components.hull and (GetTime() - self.inst.spawntime) >= 30 and
                    (self.level >= 5 or math.random() < 0.5) then smolderboat(inst, boat, inst.parent.components.fueled) end
            end
            return SetLevel(self, level, ...)
        end
    end)
end

local messagebottletreasures = require("messagebottletreasures")
require("stategraphs/commonstates")
-- 沉底宝箱额外掉落
local loots = {
    -- 6种手部装备
    "compass",
    "goldenshovel",
    "bullkelp_root",
    "compass",
    "goldenshovel",
    "bullkelp_root",
    "glasscutter",
    "telestaff",
    "trident",
    -- 6种头盔
    "kelphat",
    "footballhat",
    "mermhat",
    "kelphat",
    "footballhat",
    "mermhat",
    "spiderhat",
    "hivehat",
    "alterguardianhat",
    -- 6种护甲
    "backpack",
    "armorwood",
    "raincoat",
    "backpack",
    "armorwood",
    "raincoat",
    "armor_sanity",
    "icepack",
    "armordragonfly"
}
-- AddPrefabPostInit("sunkenchest", function(inst)
--     inst:RemoveTag("chest")
--     if not TheWorld.ismastersim then return end
--     if not inst.components.workable then return end
--     local oldonfinish = inst.components.workable.onfinish or nilfn
--     inst.components.workable:SetOnFinishCallback(function(...)
--         if math.random() < 0.2 then
--             local prefab = loots[math.random(#loots)]
--             if not (TUNING.noalterguardianhat2hm and prefab == "alterguardianhat") then
--                 local loot = SpawnPrefab(prefab)
--                 if loot then loot.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
--             end
--         end
--         oldonfinish(...)
--     end)
-- end)
local removeitem =
{
    "scrapbook_page",
    "cookingrecipecard",
	"trinket_3",
	"trinket_4",
	"trinket_5",
	"trinket_6",
	"trinket_7",
	"trinket_8",
	"trinket_9",
	"trinket_17",
	"trinket_22",
	"trinket_27",
}
if messagebottletreasures.GenerateTreasure then
    local oldfn = messagebottletreasures.GenerateTreasure
    messagebottletreasures.GenerateTreasure = function(pt, overrideprefab, spawn_as_empty, postfn, ...)
        local treasure = oldfn(pt, overrideprefab, spawn_as_empty, postfn, ...)
        local _container = treasure.components.container or treasure.components.inventory
        if _container ~= nil and math.random() < 0.2 then
            local prefab = loots[math.random(#loots)]
            if _container:IsFull() then
                local item = _container:FindItem(function(item) return table.contains(removeitem, item.prefab) end)
                if item then _container:RemoveItem(item, true) end
                _container:GiveItem(SpawnPrefab(prefab))
            else
                _container:GiveItem(SpawnPrefab(prefab))
            end
        end
        return treasure
    end
end
-- 瓶中信开不出来寄居蟹隐士岛屿;第一次见到寄居蟹隐士时，玩家必定被海贼船袭击;打捞贝壳堆任务完毕时必定被袭击，不再重复完成了
-- 2025.9.19 melon:夹夹绞盘蓝图兑换需要6点好感度(仿照重制版)
AddRecipePostInit("hermitshop_winch_blueprint", function(inst)
    inst.level = TECH.HERMITCRABSHOP_FIVE
end)
local SPAWNPOINT_1_ONEOF_TAGS = {"player"}
local SPAWNPOINT_2_ONEOF_TAGS = {"INLIMBO", "fx"}
local RANGE = 40
local SHORTRANGE = 5
-- local function resetsettarget(inst, self, target) if self.target == nil and target and target:IsValid() then self.target = target end end
local function spawnPiratesForPlayer(inst, enablecannon)
    if inst and inst:IsValid() and not inst:HasTag("playerghost") and TheWorld.components.piratespawner and TheWorld.has_ocean then
        local pt = Vector3(inst.Transform:GetWorldPosition())
        local function TestSpawnPoint(offset)
            local spawnpoint_x, spawnpoint_y, spawnpoint_z = (pt + offset):Get()
            return TheWorld.Map:IsSurroundedByWater(spawnpoint_x, spawnpoint_y, spawnpoint_z, TUNING.MAX_WALKABLE_PLATFORM_RADIUS) and
                       #TheSim:FindEntities(spawnpoint_x, spawnpoint_y, spawnpoint_z, RANGE - SHORTRANGE, nil, nil, SPAWNPOINT_1_ONEOF_TAGS) <= 0 and
                       #TheSim:FindEntities(spawnpoint_x, spawnpoint_y, spawnpoint_z, SHORTRANGE, nil, SPAWNPOINT_2_ONEOF_TAGS) <= 0
        end
        local theta = math.random() * 2 * PI
        local radius = RANGE
        local resultoffset = FindValidPositionByFan(theta, radius, 12, TestSpawnPoint)
        if resultoffset == nil then return end
        pt = pt + resultoffset
        TheWorld.components.piratespawner:SpawnPirates(pt)
        local ship = TheWorld.components.piratespawner.shipdatas[#TheWorld.components.piratespawner.shipdatas]
        if ship and ship.boat and ship.boat:IsValid() and ship.boat.components.boatcrew and ship.captain and ship.captain:IsValid() then
            if enablecannon ~= false and math.random() < (0.25 + math.clamp(TheWorld.state.cycles * 0.001, 0, 0.25)) then
                local x, y, z = ship.boat.Transform:GetWorldPosition()
                local cannon = SpawnPrefab("boat_cannon")
                cannon.Transform:SetPosition(x - 1.5, y, z - 1.5)
            end
            local platform = inst:GetCurrentPlatform()
            if platform then ship.boat.components.boatcrew:SetTarget(platform or inst) end
            ship.captain:PushEvent("command")
            for i, v in ipairs(AllPlayers) do
                local pirates_near = false
                if v:GetDistanceSqToInst(ship.captain) < 1600 then pirates_near = true end
                if pirates_near and not v.piratesnear then
                    v.piratesnear = true
                    v._piratemusicstate:set(true)
                end
            end
        end
        return true
    end
end
local function TaskSpawnPiratesForPlayer(inst)
    if (inst:HasTag("playerghost") or (inst:GetCurrentPlatform() and spawnPiratesForPlayer(inst))) and inst.SpawnPiratesForPlayerTask2hm then
        inst.SpawnPiratesForPlayerTask2hm:Cancel()
        inst.SpawnPiratesForPlayerTask2hm = nil
        if inst.components.persistent2hm then inst.components.persistent2hm.data.pirateattack = nil end
    elseif inst.components.persistent2hm and inst.SpawnPiratesForPlayerTask2hm and inst.SpawnPiratesForPlayerTask2hm.limit <= 1 then
        inst.components.persistent2hm.data.pirateattack = nil
    end
end
local function readyspawnPiratesForPlayer(player, limit)
    if player.components.persistent2hm then player.components.persistent2hm.data.pirateattack = true end
    if player:HasTag("playerghost") or (player:GetCurrentPlatform() and spawnPiratesForPlayer(player)) then
        if player.components.persistent2hm then player.components.persistent2hm.data.pirateattack = nil end
        return
    elseif player.SpawnPiratesForPlayerTask2hm then
        player.SpawnPiratesForPlayerTask2hm:Cancel()
    end
    player.SpawnPiratesForPlayerTask2hm = player:DoPeriodicTask(1, TaskSpawnPiratesForPlayer)
    player.SpawnPiratesForPlayerTask2hm.limit = limit or 480
end
local function checkpirateattack(inst)
    if inst.components.persistent2hm and inst.components.persistent2hm.data.pirateattack then readyspawnPiratesForPlayer(inst) end
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, checkpirateattack)
end)
-- 首次见到寄居蟹隐士时，上船会被海盗船袭击
AddComponentPostInit("messagebottlemanager", function(self)
    -- 2025.9.19 melon:注释掉(瓶子就能开奶奶岛了)
    -- local oldUseMessageBottle = self.UseMessageBottle
    -- self.UseMessageBottle = function(self, bottle, doer, is_not_from_hermit, ...)
    --     if not (self.hermit_has_been_found_by and next(self.hermit_has_been_found_by) ~= nil) then is_not_from_hermit = true end
    --     return oldUseMessageBottle(self, bottle, doer, is_not_from_hermit, ...)
    -- end
    local oldSetPlayerHasFoundHermit = self.SetPlayerHasFoundHermit
    self.SetPlayerHasFoundHermit = function(self, player, ...)
        if player and player:IsValid() and player.userid and not (self.hermit_has_been_found_by and self.hermit_has_been_found_by[player.userid]) then
            readyspawnPiratesForPlayer(player)
        end
        return oldSetPlayerHasFoundHermit(self, player, ...)
    end
end)
local function spawnPiratesForNearestPlayer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRangeSq(x, y, z, 900, true)
    if players and players[1] and players[1]:IsValid() then return spawnPiratesForPlayer(players[1]) end
end
-- 打捞沉底宝箱时概率来海盗船
local winch
local function onCHEVO_heavyobject_winched(world, data)
    winch = data and data.target
    if winch and winch:IsValid() and winch.components.shelf and winch.components.shelf.itemonshelf and winch.components.shelf.itemonshelf.prefab ==
        "sunkenchest" and not winch.disablePirate2hmtask and math.random() < 0.025 then
        winch.disablePirate2hmtask = winch:DoTaskInTime(480, function() winch.disablePirate2hmtask = nil end)
        spawnPiratesForNearestPlayer(winch)
    end
end
-- 首次完成打捞贝壳堆的任务时，会被海贼船袭击
AddComponentPostInit("friendlevels", function(self)
    self.inst:ListenForEvent("CHEVO_heavyobject_winched", onCHEVO_heavyobject_winched, TheWorld)
    local oldCompleteTask = self.CompleteTask
    self.CompleteTask = function(self, task, doer, ...)
        -- 禁止重复完成打捞贝壳堆的任务
        if self.inst == "hermitcrab" and task == 5 and self.friendlytasks[task] and self.friendlytasks[task].complete then return end
        oldCompleteTask(self, task, doer, ...)
        if self.inst == "hermitcrab" and task == 5 and self.friendlytasks[task] and self.friendlytasks[task].complete and self.level >= 2 and self.level < 10 then
            if winch and winch:IsValid() then spawnPiratesForNearestPlayer(winch) end
        end
    end
end)
local function megaflare_on_ignite_over(inst)
    local fx, fy, fz = inst.Transform:GetWorldPosition()
    local random_angle = math.pi * 2 * math.random()
    local random_radius = -(TUNING.MINIFLARE.OFFSHOOT_RADIUS) + (math.random() * 2 * TUNING.MINIFLARE.OFFSHOOT_RADIUS)
    fx = fx + (random_radius * math.cos(random_angle))
    fz = fz + (random_radius * math.sin(random_angle))
    -- Create an entity to cover the close-up minimap icon; the 'globalmapicon' doesn't cover this.
    local minimap = SpawnPrefab("megaflare_minimap")
    minimap.Transform:SetPosition(fx + 10, fy, fz)
    minimap.color_r = 1
    minimap.color_g = 0.6
    minimap.color_b = 0.6
    minimap:DoTaskInTime(TUNING.MINIFLARE.TIME, function() minimap:Remove() end)
    local minimap = SpawnPrefab("megaflare_minimap")
    minimap.Transform:SetPosition(fx, fy, fz + 10)
    minimap:DoTaskInTime(TUNING.MINIFLARE.TIME, function() minimap:Remove() end)
    local minimap = SpawnPrefab("megaflare_minimap")
    minimap.Transform:SetPosition(fx - 5, fy, fz - 5)
    minimap:DoTaskInTime(TUNING.MINIFLARE.TIME, function() minimap:Remove() end)
end
-- 正常海盗袭击时概率多来一或两个海盗船
AddComponentPostInit("piratespawner", function(self)
    local oldOnUpdate = self.OnUpdate
    self.OnUpdate = function(self, dt, ...)
        local oldships = #self.shipdatas
        oldOnUpdate(self, dt, ...)
        local newships = #self.shipdatas
        if newships > oldships then
            if math.random() < (TheWorld.state.cycles * 0.001 + 0.5) then
                for i, v in ipairs(AllPlayers) do
                    if v:IsValid() and not v.components.health:IsDead() and v.entity:IsVisible() and v.piratesnear and v:GetCurrentPlatform() then
                        spawnPiratesForPlayer(v, false)
                        if v.components.age and v.components.age:GetAgeInDays() > 100 and math.random() < 0.5 then
                            spawnPiratesForPlayer(v, false)
                        end
                        break
                    end
                end
            else
                local ship = self.shipdatas[#self.shipdatas]
                if ship and ship.boat and ship.boat:IsValid() and ship.boat.components.boatcrew and ship.boat.components.boatcrew.status ~= "delivery" and ship.captain and ship.captain:IsValid() then
                    if math.random() < (0.25 + math.clamp(TheWorld.state.cycles * 0.001, 0, 0.25)) then
                        local x, y, z = ship.boat.Transform:GetWorldPosition()
                        local cannon = SpawnPrefab("boat_cannon")
                        cannon.Transform:SetPosition(x - 1.5, y, z - 1.5)
                    end
                end
            end
        end
    end
end)
-- 猴子死亡时概率信号弹或摧毁烧毁猴子小屋都概率出现海盗
local function onworkfinished(inst, data)
    if data and data.worker and data.worker:HasTag("player") and math.random() < 0.5 then spawnPiratesForPlayer(data.worker) end
end
local function onburntup(inst) if not inst:IsAsleep() and math.random() < 0.25 and spawnPiratesForNearestPlayer(inst) then megaflare_on_ignite_over(inst) end end
AddPrefabPostInit("monkeyhut", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("burntup", onburntup)
    inst:ListenForEvent("workfinished", onworkfinished)
end)
local function monkeymegaflaretaskcd2hm(inst) inst.monkeymegaflaretask2hm = nil end
local function onpowder_monkeydeath(inst)
    if not TheWorld.monkeymegaflaretask2hm and not inst:IsAsleep() and inst:GetCurrentPlatform() and math.random() < 0.01 and spawnPiratesForNearestPlayer(inst) then
        TheWorld.monkeymegaflaretask2hm = TheWorld:DoTaskInTime(15, monkeymegaflaretaskcd2hm)
        megaflare_on_ignite_over(inst)
    elseif not TheWorld.monkeymegaflaretask2hm and not inst:IsAsleep() and TheWorld.components.piratespawner and TheWorld.components.piratespawner.queen and
        inst:IsNear(TheWorld.components.piratespawner.queen, 40) and math.random() < 0.1 and spawnPiratesForNearestPlayer(inst) then
        TheWorld.monkeymegaflaretask2hm = TheWorld:DoTaskInTime(15, monkeymegaflaretaskcd2hm)
        megaflare_on_ignite_over(inst)
    end
end
-- local function onentitysleep(inst)
-- if TheWorld.components.piratespawner and not inst:GetCurrentPlatform() and
--     not (TheWorld.components.piratespawner.queen and inst:IsNear(TheWorld.components.piratespawner.queen, 50)) then
--     TheWorld.components.piratespawner:StashLoot(inst)
-- end
-- end
AddPrefabPostInit("powder_monkey", function(inst)
    inst:AddTag("stronggrip")
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("death", onpowder_monkeydeath)
    -- inst:ListenForEvent("entitysleep", onentitysleep)
end)
local function onprime_mateattacked(inst)
    if not inst:IsAsleep() and inst:GetCurrentPlatform() and not TheWorld.monkeymegaflaretask2hm and not inst.summonboat2hm and math.random() < 0.01 and
        spawnPiratesForNearestPlayer(inst) then
        inst.summonboat2hm = true
        TheWorld.monkeymegaflaretask2hm = TheWorld:DoTaskInTime(15, monkeymegaflaretaskcd2hm)
        megaflare_on_ignite_over(inst)
    end
end
local function onprime_matedeath(inst)
    if not inst:IsAsleep() and inst:GetCurrentPlatform() and not TheWorld.monkeymegaflaretask2hm and math.random() < (inst.summonboat2hm and 0.01 or 0.15) and
        spawnPiratesForNearestPlayer(inst) then
        TheWorld.monkeymegaflaretask2hm = TheWorld:DoTaskInTime(15, monkeymegaflaretaskcd2hm)
        megaflare_on_ignite_over(inst)
    end
end
AddPrefabPostInit("prime_mate", function(inst)
    inst:AddTag("stronggrip")
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", onprime_mateattacked)
    inst:ListenForEvent("death", onprime_matedeath)
    -- inst:ListenForEvent("entitysleep", onentitysleep)
end)
-- 海贼猴不再溺水
local states = {}
CommonStates.AddSinkAndWashAsoreStates(states)
for index, state in ipairs(states) do
    AddStategraphState("primemate", state)
    AddStategraphState("powdermonkey", state)
end
local function onsink(inst, data)
    if (inst.components.health == nil or not inst.components.health:IsDead()) and not inst.sg:HasStateTag("drowning") and
        (inst.components.drownable ~= nil and inst.components.drownable:ShouldDrown()) then
        if inst:HasTag("swc2hm") then
            SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst:Remove()
        else
            inst.sg:GoToState("sink", data)
        end
    end
end
local function ondive(inst, ...)
    if TheWorld.Map:IsVisualGroundAtPoint(inst.Transform:GetWorldPosition()) or inst:GetCurrentPlatform() then
        inst.sg:GoToState("dive_pst_land")
    elseif inst:HasTag("swc2hm") then
        SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst:Remove()
    else
        inst.sg:GoToState("sink")
    end
end
AddStategraphPostInit("primemate", function(sg)
    sg.events.onsink.fn = onsink
    sg.states.dive.events.animover.fn = ondive
end)
AddStategraphPostInit("powdermonkey", function(sg)
    sg.events.onsink.fn = onsink
    sg.states.dive.events.animover.fn = ondive
end)
-- 全新X宝藏
TUNING.PRIME_MATE_HEALTH = TUNING.PRIME_MATE_HEALTH * 2
TUNING.POWDER_MONKEY_HEALTH = TUNING.POWDER_MONKEY_HEALTH * 1.5
TUNING.PIRATESPAWNER_BASEPIRATECHANCE = TUNING.PIRATESPAWNER_BASEPIRATECHANCE * 4 / 5
local function additemintostash(stash, name)
    local item = SpawnPrefab(name)
    stash:stashloot(item)
end
local function generaterandomloot(stash)
    local lootlist = {}
    for i = 1, math.random(1, 3) do table.insert(lootlist, "palmcone_scale") end
    for i = 1, math.random(1, 3) do table.insert(lootlist, "cave_banana") end
    if math.random() < 0.75 then for i = 1, math.random(2, 5) do table.insert(lootlist, "goldnugget") end end
    if math.random() < 0.5 then for i = 1, math.random(2, 5) do if math.random() < 0.3 then table.insert(lootlist, "meat_dried") end end end
    if math.random() < 0.35 then table.insert(lootlist, "bananajuice") end
    if math.random() < 0.15 then table.insert(lootlist, "treegrowthsolution") end
    if math.random() < 0.05 then table.insert(lootlist, "pirate_flag_pole_blueprint") end
    if math.random() < 0.05 then table.insert(lootlist, "polly_rogershat_blueprint") end
    if math.random() < 0.15 then
        local treasure = messagebottletreasures.GenerateTreasure(Vector3(0, 0, 0))
        if treasure then
            if treasure.components.container then
                for i = 1, treasure.components.container.numslots do
                    local item = treasure.components.container.slots[i]
                    if item ~= nil then
                        treasure.components.container:RemoveItem(item)
                        stash:stashloot(item)
                    end
                end
            end
            treasure:Remove()
        end
    end
    if math.random() < 0.15 and TheWorld.components.klaussackloot then
        local data = TheWorld.components.klaussackloot:OnSave()
        TheWorld.components.klaussackloot:RollKlausLoot()
        if TheWorld.components.klaussackloot.loot then
            local items = TheWorld.components.klaussackloot.loot[math.random(#TheWorld.components.klaussackloot.loot)]
            local _items = {}
            for i, v in ipairs(items) do
                if type(v) == "string" then
                    _items[i] = SpawnPrefab(v)
                else
                    _items[i] = SpawnPrefab(v[1])
                    _items[i].components.stackable.stacksize = v[2]
                end
            end
            local bundle = SpawnPrefab(math.random() < 0.75 and "gift" or "bundle")
            bundle.components.unwrappable:WrapItems(_items)
            stash:stashloot(bundle)
        end
        TheWorld.components.klaussackloot:OnLoad(data)
    end
    if math.random() < 0.01 then table.insert(lootlist, loots[math.random(#loots)]) end
    for i, loot in ipairs(lootlist) do additemintostash(stash, loot) end
end
-- 海盗船在猴岛附近时就不会消失
AddComponentPostInit("vanish_on_sleep", function(self)
    local oldOnEntitySleep = self.OnEntitySleep
    self.OnEntitySleep = function(self, ...)
        if TheWorld.components.piratespawner and TheWorld.components.piratespawner.queen and self.inst:IsNear(TheWorld.components.piratespawner.queen, 175) then
            return
        end
        oldOnEntitySleep(self, ...)
    end
end)
-- 海盗船在猴岛附近时不会逃跑，水手猴会一直出去打架；此外水手猴在船长的船上有敌人时会返回回来帮助船长
AddComponentPostInit("boatcrew", function(self)
    local oldOnUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        oldOnUpdate(self, ...)
        local doattack = self.captain and self.captain:IsValid() and self.captain.components.combat and self.captain.components.combat.target and
                             self.captain.components.combat.target:IsValid() and self.captain.components.combat.target:GetCurrentPlatform() ==
                             self.captain:GetCurrentPlatform()
        if doattack then
            for k, v in pairs(self.members) do
                if k and k:IsValid() and k.components.combat and k.components.combat.target ~= self.captain.components.combat.target then
                    k.components.combat:SetTarget(self.captain.components.combat.target)
                end
            end
        end
        if self.status == "retreat" and TheWorld.components.piratespawner and TheWorld.components.piratespawner.queen and
            self.inst:IsNear(TheWorld.components.piratespawner.queen, 175) and (not doattack or self:areAllCrewOnBoat()) then
            self.status = "assault"
            self.flee = nil
        end
    end
end)
-- 妥协船体碰撞BUG修复
local errorvalues = {"nan", "-nan", "inf", "-inf", "-1.#IND", "1.#QNAN", "1.#INF", "-1.#INF"}
local function iserrordata(value)
    if value then
        local str = tostring(value)
        return table.contains(errorvalues, str)
    end
end
AddComponentPostInit("boatphysics", function(self)
    local oldOnSave = self.OnSave
    self.OnSave = function(self, ...)
        if iserrordata(self.velocity_x) then self.velocity_x = 0 end
        if iserrordata(self.velocity_z) then self.velocity_z = 0 end
        return oldOnSave(self, ...)
    end
end)
-- 猴岛女王解除诅咒
local nextcursevalue
local giveprefab
AddStategraphPostInit("monkeyqueen", function(sg)
    local onenter = sg.states.getitem.onenter
    sg.states.getitem.onenter = function(inst, data, ...)
        giveprefab = data and data.item and data.item.prefab
        if giveprefab == "stash_map" then
            nextcursevalue = 4 * (data.item.components.stackable and data.item.components.stackable.stacksize or 1)
        elseif giveprefab == "cave_banana" or giveprefab == "cave_banana_cooked" then
            nextcursevalue = data.item.components.stackable and data.item.components.stackable.stacksize or 1
        elseif giveprefab then
            giveprefab = nil
            nextcursevalue = nil
        else
            nextcursevalue = nil
        end
        onenter(inst, data, ...)
    end
    local oldfn = sg.states.getitem.events.animover.fn
    sg.states.getitem.events.animover.fn = function(inst, ...)
        local takemonkeycurse = false
        if inst.sg.statemem.giver then
            if inst.sg.statemem.giver.components.inventory and inst.sg.statemem.giver.components.cursable then
                local num_found = 0
                for k, v in pairs(inst.sg.statemem.giver.components.inventory.itemslots) do
                    if v and v.prefab == "cursed_monkey_token" then
                        if v.components.stackable ~= nil then
                            num_found = num_found + v.components.stackable:StackSize()
                        else
                            num_found = num_found + 1
                        end
                    end
                end
                inst.sg.statemem.giver.components.cursable.curses.MONKEY = num_found
            end
            if inst.sg.statemem.giver.components.cursable and (inst.sg.statemem.giver.components.cursable.curses.MONKEY or 0) > 0 then
                takemonkeycurse = true
            elseif inst.sg.statemem.giver:HasTag("wonkey") then
                takemonkeycurse = true
            end
        end
        if not takemonkeycurse and giveprefab ~= "stash_map" then
            local giver = inst.sg.statemem.giver
            if giver and giver:IsValid() then
                inst.right_of_passage = true
                if inst.components.timer:TimerExists("right_of_passage") then
                    inst.components.timer:SetTimeLeft("right_of_passage", TUNING.MONKEY_QUEEN_GRACE_TIME)
                else
                    inst.components.timer:StartTimer("right_of_passage", TUNING.MONKEY_QUEEN_GRACE_TIME)
                end
            end
            inst.sg:GoToState("happy", {say = "MONKEY_QUEEN_HAPPY"})
            return
        end
        oldfn(inst, ...)
    end
end)
AddPrefabPostInit("monkeyqueen", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.trader then return end
    local oldAcceptGift = inst.components.trader.AcceptGift
    inst.components.trader.AcceptGift = function(inst, giver, item, count, ...)
        if item.prefab == "cave_banana" then
            count = math.max(giver.components.cursable and giver.components.cursable.curses.MONKEY or 0, 1)
        elseif item.prefab == "stash_map" then
            count = math.ceil(math.max(giver.components.cursable and giver.components.cursable.curses.MONKEY or 0, 1) / 4)
        end
        return oldAcceptGift(inst, giver, item, count, ...)
    end
end)
AddComponentPostInit("cursable", function(self)
    local oldRemoveCurse = self.RemoveCurse
    self.RemoveCurse = function(self, curse, numofitems, ...)
        if curse == "MONKEY" and numofitems == 4 and nextcursevalue and giveprefab then
            numofitems = nextcursevalue
            nextcursevalue = nil
            giveprefab = nil
        end
        return oldRemoveCurse(self, curse, numofitems, ...)
    end
end)
-- 海盗地图在原版X宝藏已存在时会开出来沉底宝箱和新的X宝藏(新的X宝藏不会在月岛上)
AddPrefabPostInit("stash_map", function(inst)
    inst:AddTag("monkeyqueenbribe")
    if not TheWorld.ismastersim then return end
    if inst.components.mapspotrevealer then
        local old = inst.components.mapspotrevealer.gettargetfn
        inst.components.mapspotrevealer:SetGetTargetFn(function(inst, doer, ...)
            if TheWorld.components.piratespawner then
                local data, ents = TheWorld.components.piratespawner:OnSave()
                if not (data and data.currentstash) then return old(inst, doer, ...) end
            end
            if doer and doer:HasTag("player") and doer.userid then
                local chance = math.random()
                if chance < 0.2 and TheWorld.components.messagebottlemanager and TheWorld.components.messagebottlemanager.active_treasure_hunt_markers and
                    GetTableSize(TheWorld.components.messagebottlemanager.active_treasure_hunt_markers) < 3 then
                    local pos, reason = TheWorld.components.messagebottlemanager:UseMessageBottle(inst, doer, true)
                    if pos then return pos, reason end
                elseif chance < 0.8 and TheWorld.components.piratespawner then
                    for i = 1, 3, 1 do
                        local pt = TheWorld.components.piratespawner:FindStashLocation()
                        if pt then
                            local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(pt.x, 0, pt.z)
                            if node and node.tags and not table.contains(node.tags, "lunacyarea") then
                                local newstash = SpawnPrefab("pirate_stash2hm")
                                newstash.Transform:SetPosition(pt.x, 0, pt.z)
                                generaterandomloot(newstash)
                                return Vector3(newstash.Transform:GetWorldPosition())
                            end
                        end
                    end
                end
            end
            return old(inst, doer, ...)
        end)
    end
end)
-- 海盗头巾可以制图桌概率擦出海盗地图,木头短剑做燃料后概率给一个藏宝图
AddPrefabPostInit("monkey_smallhat", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.erasablepaper then
        inst:AddComponent("erasablepaper")
        inst.components.erasablepaper.erased_prefab2hm = "stash_map"
        inst.components.erasablepaper.erased_chance2hm = 0.25
    end
end)
AddPrefabPostInit("blackflag", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.erasablepaper then
        inst:AddComponent("erasablepaper")
        inst.components.erasablepaper.erased_prefab = "papyrus"
    end
end)
AddPrefabPostInit("monkey_mediumhat", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.erasablepaper then
        inst:AddComponent("erasablepaper")
        inst.components.erasablepaper.erased_prefab = "blackflag"
    end
end)
-- AddPrefabPostInit("polly_rogershat", function(inst)
--     if not TheWorld.ismastersim then return end
--     if not inst.components.erasablepaper then
--         inst:AddComponent("erasablepaper")
--         inst.components.erasablepaper.erased_prefab2hm = "stash_map"
--         inst.components.erasablepaper.erased_chance2hm = 0.25
--     end
-- end)
local function ontakenfuel(inst, data)
    if data and data.taker and data.taker.components.lootdropper and math.random() < 0.15 then data.taker.components.lootdropper:SpawnLootPrefab("stash_map") end
end
AddPrefabPostInit("cutless", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("fueltaken", ontakenfuel)
end)
AddComponentPostInit("erasablepaper", function(self)
    local oldDoErase = self.DoErase
    self.DoErase = function(self, eraser, doer, ...)
        if self.erased_prefab2hm and self.erased_chance2hm then
            self.erased_prefab = math.random() < self.erased_chance2hm and self.erased_prefab2hm or "papyrus"
        end
        return oldDoErase(self, eraser, doer, ...)
    end
end)
-- 打捞物品防止位于大树干附近
local COCOON_HOME_TAGS = {"cocoon_home"}
local function checksunkenchestpos(inst)
    local c_pos = inst:GetPosition()
    local nearby_trees = TheSim:FindEntities(c_pos.x, 0, c_pos.z, 8, COCOON_HOME_TAGS)
    if #nearby_trees > 0 then
        local tree = nearby_trees[1]
        if tree and tree:IsValid() and tree.prefab == "watertree_pillar" then
            local theta = math.random() * 2 * PI
            local offset = Vector3(10 * math.cos(theta), 0, -10 * math.sin(theta))
            local pt = tree:GetPosition() + offset
            inst.Transform:SetPosition(pt.x, pt.y, pt.z)
        end
    end
end
AddPrefabPostInit("underwater_salvageable", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, checksunkenchestpos)
end)
-- -- 猴岛非自然传送门周围的陆地会再生2~3个猴子建筑
-- local function OnDespawn(inst)
--     inst._despawnhut2hmtask = nil
--     if inst:IsAsleep() then end
-- end
-- local function newportalOnEntitySleep(inst)
--     if inst._despawnhut2hmtask ~= nil then inst._despawnhut2hmtask:Cancel() end
--     inst._despawnhut2hmtask = inst:DoTaskInTime(240, OnDespawn)
-- end
-- AddPrefabPostInit("monkeyisland_portal", function(inst)
--     if not TheWorld.ismastersim then return end
--     local old = inst.OnEntitySleep
--     inst.OnEntitySleep = function(...)
--         old(...)
--         newportalOnEntitySleep(...)
--     end
-- end)
