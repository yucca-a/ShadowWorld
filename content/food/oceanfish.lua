local FISH_DATA = require("prefabs/oceanfishdef")
local easing = require("easing")

-- 季节海鱼珍惜化
local SCHOOL_WEIGHTS = FISH_DATA.school
local SCHOOL_VERY_COMMON = 4
local SCHOOL_COMMON = 2
local SCHOOL_UNCOMMON = 1
local SCHOOL_RARE = 0.25
SCHOOL_WEIGHTS[SEASONS.AUTUMN][GROUND.OCEAN_SWELL].oceanfish_small_6 = SCHOOL_RARE
SCHOOL_WEIGHTS[SEASONS.WINTER][GROUND.OCEAN_SWELL].oceanfish_medium_8 = SCHOOL_RARE
SCHOOL_WEIGHTS[SEASONS.SPRING][GROUND.OCEAN_COASTAL].oceanfish_small_7 = SCHOOL_RARE
SCHOOL_WEIGHTS[SEASONS.AUTUMN][GROUND.OCEAN_WATERLOG].oceanfish_small_6 = SCHOOL_UNCOMMON
SCHOOL_WEIGHTS[SEASONS.SPRING][GROUND.OCEAN_WATERLOG].oceanfish_small_7 = SCHOOL_UNCOMMON
SCHOOL_WEIGHTS[SEASONS.SUMMER][GROUND.OCEAN_SWELL].oceanfish_small_8 = SCHOOL_RARE

-- 海鱼掉落改动(当一个鱼肉出产且同时一个鱼消失时从而触发)
local fishchanceloot = {
    -- 泥鱼
    oceanfish_medium_1 = {{"purplegem", 0.03}},
    -- 斑鱼
    oceanfish_medium_2 = {{"purplegem", 0.03}}, -- deep bass
    -- 浮夸狮子鱼
    oceanfish_medium_3 = {{"purplegem", 0.03}, {"yellowgem", 0.001}}, -- dandy lionfish
    -- 黑鲶鱼
    oceanfish_medium_4 = {{"purplegem", 0.03}}, -- black catfish
    -- 玉米鳕鱼
    oceanfish_medium_5 = {{"yellowgem", 0.001}, {"greengem", 0.001}}, -- corn cod
    -- 花锦鲤
    oceanfish_medium_6 = {
        {"redgem", 0.02},
        {"bluegem", 0.02},
        {"purplegem", 0.01},
        {"orangegem", 0.003},
        {"yellowgem", 0.001},
        {"greengem", 0.001},
        {"opalpreciousgem", 0.0005}
    }, -- dappled koi
    -- 金锦鲤
    oceanfish_medium_7 = {
        {"redgem", 0.02},
        {"bluegem", 0.02},
        {"purplegem", 0.01},
        {"orangegem", 0.003},
        {"yellowgem", 0.001},
        {"greengem", 0.001},
        {"opalpreciousgem", 0.0005}
    }, -- golden koi
    -- 冰鲷鱼
    oceanfish_medium_8 = {{"bluegem", 0.1}, {"opalpreciousgem", 0.0002}}, -- ice bream
    -- 甜味鱼
    oceanfish_medium_9 = {{"redgem", 0.05}, {"yellowgem", 0.001}}, -- sweetish fish
    -- 小孔雀鱼
    oceanfish_small_1 = {
        {"redgem", 0.01},
        {"bluegem", 0.01},
        {"purplegem", 0.005},
        {"orangegem", 0.001},
        {"yellowgem", 0.0005},
        {"greengem", 0.0005},
        {"opalpreciousgem", 0.0002}
    }, -- runty guppy
    -- 针鼻喷墨鱼
    oceanfish_small_2 = {{"purplegem", 0.02}}, -- needlenosed squirt
    -- 小饵鱼
    oceanfish_small_3 = {}, -- bitty baitfish
    -- 三文鱼苗
    oceanfish_small_4 = {}, -- smolt fry
    -- 爆米花鱼
    oceanfish_small_5 = {{"yellowgem", 0.001}}, -- popperfish
    -- 落叶比目鱼
    oceanfish_small_6 = {{"redgem", 0.05}, {"bluegem", 0.05}, {"yellowgem", 0.01}}, -- fallounder
    -- 花朵金枪鱼
    oceanfish_small_7 = {{"redgem", 0.05}, {"bluegem", 0.05}, {"greengem", 0.01}}, -- bloomfin tuna
    -- 炽热太阳鱼
    oceanfish_small_8 = {{"redgem", 0.1}}, -- scorching sunfish
    -- 口水鱼
    oceanfish_small_9 = {{"bluegem", 0.02}} -- spittlefish
}
local function processlootchance(loot, chance)
    for i, v in ipairs(loot) do
        if v == "fishmeat" or v == "fishmeat_cooked" or v == "plantmeat" or v == "plantmeat_cooked" then
            chance = chance + 0.02
        elseif v == "fishmeat_small" or v == "fishmeat_small_cooked" or v == "corn" or v == "corn_cooked" then
            chance = chance + 0.01
        end
    end
    return chance
end
local function onoceanfishremove(inst)
    if not (TheWorld and TheWorld.fishcheck2hmtask) or inst:HasTag("swc2hm") then return end
    local loots = {}
    if inst.fish_def and inst.fish_def.loot then
        local chance = processlootchance(inst.fish_def.loot, 0.01)
        if inst.fish_def.heavy_loot and inst.components.weighable ~= nil and inst.components.weighable:GetWeightPercent() >=
            TUNING.WEIGHABLE_HEAVY_LOOT_WEIGHT_PERCENT then
            if math.random() < chance * 2 then table.insert(loots, "messagebottle") end
            chance = processlootchance(inst.fish_def.heavy_loot, chance)
        end
        if math.random() < chance then table.insert(loots, "cursed_monkey_token") end
    else
        return
    end
    if inst.fish_def and inst.fish_def.prefab and fishchanceloot[inst.fish_def.prefab] then
        local chanceloot = fishchanceloot[inst.fish_def.prefab]
        for k, v in ipairs(chanceloot) do
            if v and v[1] and v[2] then
                if v[2] >= 1.0 then
                    table.insert(loots, v[1])
                elseif math.random() < v[2] then
                    table.insert(loots, v[1])
                end
            end
        end
    end
    local pt = inst:GetPosition()
    if inst.components.inventoryitem and inst.components.inventoryitem.owner then
        local owner = inst.components.inventoryitem:GetGrandOwner()
        if owner and owner:IsValid() then pt = owner:GetPosition() end
    end
    if pt.x <= 0.1 and pt.z <= 0.1 and TheWorld.scsource2hm and TheWorld.scsource2hm:IsValid() and TheWorld.scsource2hm.components.container and
        inst.prevcontainer and inst.prevcontainer.inst and inst.prevcontainer.inst:IsValid() then pt = inst.prevcontainer.inst:GetPosition() end
    if inst.components.lootdropper then
        for _, v in ipairs(loots) do inst.components.lootdropper:SpawnLootPrefab(v, pt) end
    else
        for _, v in ipairs(loots) do
            local item = SpawnPrefab(v)
            if item then
                if item.Transform then
                    item.Transform:SetPosition(pt:Get())
                elseif item.Physics then
                    item.Physics:Teleport(pt:Get())
                else
                    item:Remove()
                end
            end
        end
    end
end
local function onfishmeatchecktaskend(inst)
    if TheWorld and TheWorld.fishcheck2hmtask then
        TheWorld.fishcheck2hmtask = nil
        TheWorld.scsource2hm = nil
    end
end
local function whenmeatfish(inst)
    if TheWorld.ismastersim and not POPULATING and not TheWorld.fishcheck2hmtask then
        TheWorld.fishcheck2hmtask = TheWorld:DoTaskInTime(0, onfishmeatchecktaskend)
        TheWorld.scsource2hm = inst
    end
end
local meats = {"fishmeat_small", "fishmeat_small_cooked", "fishmeat", "fishmeat_cooked", "corn", "corn_cooked", "plantmeat", "plantmeat_cooked"}
for index, value in ipairs(meats) do AddPrefabPostInit(value, whenmeatfish) end

-- 鲸鱼直接吃鱼
AddPrefabPostInit("gnarwail", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.TossItem then
        local TossItem = inst.TossItem
        inst.TossItem = function(inst, item, ...)
            if item:HasTag("oceanfish") then
                item:Remove()
                return
            end
            TossItem(inst, item, ...)
        end
    end
end)

-- AddComponentPostInit("stewer", function(self)
--     local oldStartCooking = self.StartCooking
--     self.StartCooking = function(self, ...)
--         whenmeatfish(self.inst)
--         return oldStartCooking(self, ...)
--     end
-- end)
-- AddComponentPostInit("container", function(self)
--     local DestroyContents = self.DestroyContents
--     self.DestroyContents = function(self, ...)
--         whenmeatfish(self.inst)
--         DestroyContents(self, ...)
--     end
-- end)

-- 海鱼保温能力削弱
local function newheatfn_oceanfish(inst, observer, ...)
    local percent = math.max(inst.components.perishable:GetPercent() / 2, 0.25)
    return (inst.oldheatfn2hm and inst.oldheatfn2hm(inst, observer, ...) or inst.components.heater.heat) * percent + TheWorld.state.temperature * (1 - percent)
end
local function newcarriedheatfn_oceanfish(inst, observer, ...)
    local percent = math.max(inst.components.perishable:GetPercent(), 0.35)
    return (inst.oldheatfn2hm and inst.oldheatfn2hm(inst, observer, ...) or inst.components.heater.heat) * percent + TheWorld.state.temperature * (1 - percent)
end
local heateroceanfishs = {"oceanfish_small_8_inv", "oceanfish_medium_8_inv"}
for index, oceanfish in ipairs(heateroceanfishs) do
    AddPrefabPostInit(oceanfish, function(inst)
        if not TheWorld.ismastersim or not inst.components.heater or not inst.components.perishable then return inst end
        inst.oldheatfn2hm = inst.components.heater.heatfn
        inst.components.heater.heatfn = newheatfn_oceanfish
        inst.oldcarriedheatfn2hm = inst.components.heater.carriedheatfn
        inst.components.heater.carriedheatfn = newcarriedheatfn_oceanfish
    end)
end

-- 海鱼落地上后会蹦跶到周围的海里
local function flopsoundcheck(inst)
    if inst.AnimState:IsCurrentAnimation("flop_loop") then inst.SoundEmitter:PlaySound("dontstarve/common/fishingpole_fishland") end
end
local function Flop(inst)
    if inst.flopsnd1 then
        inst.flopsnd1:Cancel()
        inst.flopsnd1 = nil
    end
    if inst.flopsnd2 then
        inst.flopsnd2:Cancel()
        inst.flopsnd2 = nil
    end
    if inst.flopsnd3 then
        inst.flopsnd3:Cancel()
        inst.flopsnd3 = nil
    end
    if inst.flopsnd4 then
        inst.flopsnd4:Cancel()
        inst.flopsnd4 = nil
    end
    inst.AnimState:PlayAnimation("flop_pre", false)
    local num = math.random(3)
    inst.AnimState:PushAnimation("flop_loop", false)
    for i = 1, num do inst.AnimState:PushAnimation("flop_loop", false) end
    inst.AnimState:PushAnimation("flop_pst", false)
    inst.flopsnd1 = inst:DoTaskInTime((5 + 9) * FRAMES, function() flopsoundcheck(inst) end)
    inst.flopsnd2 = inst:DoTaskInTime((5 + 9 + 13) * FRAMES, function() flopsoundcheck(inst) end)
    inst.flopsnd3 = inst:DoTaskInTime((5 + 9 + 26) * FRAMES, function() flopsoundcheck(inst) end)
    inst.flopsnd4 = inst:DoTaskInTime((5 + 9 + 39) * FRAMES, function() flopsoundcheck(inst) end)
    inst.flop_task = inst:DoTaskInTime(math.random() + 2 + 0.5 * num, Flop)
end
local function findoceanandjump(inst)
    if not (TheWorld.has_ocean and inst and inst:IsValid()) then return end
    if inst.components.inventoryitem and inst.components.inventoryitem.owner then return end
    if inst.movetask2hm or not inst.Transform then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsPassableAtPoint(x, y, z) then
        local pt = Point(x, y, z)
        local radius = 15
        local dest = FindNearbyOcean(pt, radius)
        if dest ~= nil then
            inst:ForceFacePoint(dest.x, 0, dest.z)
            local origin = inst:GetPosition()
            local targetpos = Vector3(dest.x, 0, dest.z)
            local targetangle = inst:GetAngleToPoint(targetpos) * DEGREES
            local dist_to_cover = math.sqrt(distsq(origin, targetpos))
            local time = dist_to_cover / 0.15
            local vector = Vector3(math.cos(targetangle) * dist_to_cover, 0, -math.sin(targetangle) * dist_to_cover)
            if vector and origin then
                local step = -60
                inst.movetask2hm = inst:DoPeriodicTask(1 * FRAMES, function(inst)
                    if inst.components.inventoryitem and inst.components.inventoryitem.owner then
                        if inst.movetask2hm then
                            inst.movetask2hm:Cancel()
                            inst.movetask2hm = nil
                        end
                        return
                    end
                    step = step + 1
                    if step >= (time + 1) and inst.movetask2hm then
                        inst.movetask2hm:Cancel()
                        inst.movetask2hm = nil
                        return
                    end
                    if step < 1 then return end
                    if inst.AnimState and not (inst.AnimState:IsCurrentAnimation("flop_loop") or inst.AnimState:IsCurrentAnimation("flop_pre")) then
                        if inst.flop_task then inst.flop_task:Cancel() end
                        Flop(inst)
                    end
                    local x_dist = easing.inQuad(step, 0, vector.x, time)
                    local z_dist = easing.inQuad(step, 0, vector.z, time)
                    local _, y, _ = inst.Transform:GetWorldPosition()
                    inst.Transform:SetPosition(origin.x + x_dist, y, origin.z + z_dist)
                    local _x, _y, _z = inst.Transform:GetWorldPosition()
                    if not TheWorld.Map:IsPassableAtPoint(_x, _y, _z) then
                        inst:PushEvent("on_landed")
                        if inst.movetask2hm then
                            inst.movetask2hm:Cancel()
                            inst.movetask2hm = nil
                        end
                    end
                end)
            end
        end
    end
end
-- -- 海鱼反季节不能保鲜
-- local fishseasons = {}
-- for season, grounddata in pairs(SCHOOL_WEIGHTS) do
--     for ground, fishdata in pairs(grounddata) do
--         for fish, school in pairs(fishdata) do
--             if not fishseasons[fish] then fishseasons[fish] = {} end
--             table.insert(fishseasons[fish], season)
--         end
--     end
-- end
-- 四季鱼免疫捕鱼网
local angryfishs = {"oceanfish_small_6", "oceanfish_small_7", "oceanfish_small_8", "oceanfish_medium_8"}
local angryitems = {"oceanfish_small_6_inv", "oceanfish_small_7_inv", "oceanfish_small_8_inv", "oceanfish_medium_8_inv"}
local function resetfishdef(inst, fishprefab) if inst.fish_def then inst.fish_def.prefab = fishprefab end end
local function onprenet(inst, net)
    if inst.fish_def and inst.fish_def.prefab then
        inst:DoTaskInTime(0, resetfishdef, inst.fish_def.prefab)
        inst.fish_def.prefab = nil
    end
    if inst.components.timer and not inst.components.timer:TimerExists("angryfish2hm") then
        inst.components.timer:StartTimer("angryfish2hm", 240)
        if inst.prefab == "oceanfish_small_8" then
            local spell = SpawnPrefab("deer_fire_circle")
            spell.Transform:SetPosition(inst.Transform:GetWorldPosition())
            spell:DoTaskInTime(4, spell.KillFX)
        elseif inst.prefab == "oceanfish_medium_8" then
            local spell = SpawnPrefab("deer_ice_circle")
            spell.Transform:SetPosition(inst.Transform:GetWorldPosition())
            if spell.TriggerFX then spell:DoTaskInTime(3, spell.TriggerFX) end
            spell:DoTaskInTime(6, spell.KillFX)
        else
            SpawnPrefab("sporecloud").Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
    end
    if not inst.leaving then inst.leaving = true end
    if inst.sg and not inst.sg:HasStateTag("busy") then
        inst:ClearBufferedAction()
        inst.sg:GoToState("eat")
    end
end
for _, fish_def in pairs(FISH_DATA.fish) do
    AddPrefabPostInit(fish_def.prefab, function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onremove", onoceanfishremove)
        if table.contains(angryfishs, inst.prefab) then
            if inst.components.fishschool then
                -- local OnPreNet = inst.components.fishschool.OnPreNet
                inst.components.fishschool.OnPreNet = function(self, net, ...) onprenet(self.inst, net) end
            else
                inst:ListenForEvent("on_pre_net", onprenet)
            end
        end
    end)
    AddPrefabPostInit(fish_def.prefab .. "_inv", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onremove", onoceanfishremove)
        inst:ListenForEvent("on_landed", findoceanandjump)
        -- inst.perishableseasons2hm = fishseasons[fish_def.prefab] or {}
        if table.contains(angryitems, inst.prefab) and not inst.components.timer then inst:AddComponent("timer") end
    end)
end
-- -- 海鱼新鲜度反季节禁止回鲜
-- AddComponentPostInit("perishable", function(self)
--     if self.inst.fish_def and self.inst:HasTag("oceanfish") and self.inst:HasTag("HASHEATER") then
--         local LongUpdate = self.LongUpdate
--         self.LongUpdate = function(self, ...)
--             if self.updatetask and self.inst.perishableseasons2hm then
--                 local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner or nil
--                 if not owner and self.inst.components.occupier then owner = self.inst.components.occupier:GetOwner() end
--                 if owner and owner.components.preserver and owner.components.preserver:GetPerishRateMultiplier(self.inst) < 0 and
--                     not table.contains(self.inst.perishableseasons2hm, TheWorld.state.season) then
--                     self.localPerishMultiplyer2hm = self.localPerishMultiplyer
--                     self.localPerishMultiplyer = 0
--                 end
--             end
--             LongUpdate(self, ...)
--             if self.localPerishMultiplyer2hm then
--                 self.localPerishMultiplyer = self.localPerishMultiplyer2hm
--                 self.localPerishMultiplyer2hm = nil
--             end
--         end
--     end
-- end)

-- 鱼拿手上概率掉落，四季海鱼必定施法反击;沃特(wurt)豁免不触发
local function dropandhit(inst, self, item)
    self:DropActiveItem()
    inst:PushEvent("blocked", {attacker = item})
end
AddComponentPostInit("inventory", function(self)
    if not TheWorld.ismastersim then return end
    local oldSetActiveItem = self.SetActiveItem
    self.SetActiveItem = function(self, item, ...)
        if self.inst and self.inst:HasTag("player") and item and item:IsValid() and item:HasTag("fish") and self.inst.prefab ~= "wurt" then
            if table.contains(angryitems, item.prefab) and item.components.timer and not item.components.timer:TimerExists("angryfish2hm") then
                item.components.timer:StartTimer("angryfish2hm", 240)
                if item.prefab == "oceanfish_small_8_inv" then
                    local spell = SpawnPrefab("deer_fire_circle")
                    spell.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                    spell:DoTaskInTime(4, spell.KillFX)
                elseif item.prefab == "oceanfish_medium_8_inv" then
                    local spell = SpawnPrefab("deer_ice_circle")
                    spell.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                    if spell.TriggerFX then spell:DoTaskInTime(3, spell.TriggerFX) end
                    spell:DoTaskInTime(6, spell.KillFX)
                else
                    SpawnPrefab("sporecloud").Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                end
                if not self.inst:HasTag("stronggrip") and math.random() < (item.prefab == "oceanfish_small_6_inv" and 1 or 0.25) then
                    self.inst:DoTaskInTime(0, dropandhit, self, item)
                end
                if item.components.perishable and item.components.perishable.perishremainingtime then
                    item.components.perishable.perishremainingtime = item.components.perishable.perishremainingtime - 120
                    -- item:DoTaskInTime(0, perishchange, item.components.perishable)
                end
            elseif not self.inst:HasTag("stronggrip") and math.random() < 0.1 then
                self.inst:DoTaskInTime(0, dropandhit, self, item)
            end
        end
        oldSetActiveItem(self, item, ...)
    end
end)
-- 捕鱼器稍微削弱
AddComponentPostInit("oceantrawler", function(self)
    self.sleepcatchfishchance = self.sleepcatchfishchance / 4
    self.overflowescapepercent = self.overflowescapepercent * 1.5
end)
-- 钓鱼,近距离不再有吸引力
if GetModConfigData("oceanfish_change") ~= -1 then
    AddComponentPostInit("oceanfishinghook", function(self)
        local UpdateInterestForFishable = self.UpdateInterestForFishable
        self.UpdateInterestForFishable = function(self, fish, ...)
            if self.inst and self.inst:IsValid() and self.inst.components.oceanfishable and self.inst.components.oceanfishable.rod and
                self.inst.components.oceanfishable.rod:IsValid() then
                local rod = self.inst.components.oceanfishable.rod
                if rod.components.oceanfishingrod and rod.components.oceanfishingrod.fisher and rod.components.oceanfishingrod.fisher:IsValid() then
                    local fisher = rod.components.oceanfishingrod.fisher
                    if self.inst:IsNear(fisher, TUNING.BOAT.RADIUS) then return 0 end
                end
            end
            return UpdateInterestForFishable(self, fish, ...)
        end
    end)
    local function setrodfar(inst)
        inst.rodfar2hm = true
        inst.rodfartask2hm = nil
    end
    AddComponentPostInit("oceanfishable", function(self)
        local OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, ...)
            OnUpdate(self, ...)
            if self.inst and self.inst:IsValid() and self.stamina_def and self.inst:HasTag("oceachfishing_catchable") and not self.inst.rodfar2hm then
                if not self.inst.rodfartask2hm then
                    if self.inst.components.herdmember and self.inst.components.herdmember.herd and self.inst.components.herdmember.herd:IsValid() then
                        local herd = self.inst.components.herdmember.herd
                        if herd and herd.components.timer and herd.components.timer:TimerExists("lifetime") then
                            herd.components.timer:SetTimeLeft("lifetime", herd.components.timer:GetTimeLeft("lifetime") / 2)
                        end
                    end
                    self.inst.rodfartask2hm = self.inst:DoTaskInTime(2, setrodfar)
                    self.pending_is_struggling_state = true
                    self.is_struggling_state = true
                    self.stamina = math.max(math.random(), 0.3)
                    self.struggling_state_timer = self:CalcStruggleDuration()
                end
                self.inst:RemoveTag("oceachfishing_catchable")
            end
        end
        local SetRod = self.SetRod
        self.SetRod = function(self, rod, ...)
            if self.stamina_def and self.rod and rod == nil and not self.inst.leaving then self.inst.leaving = true end
            return SetRod(self, rod, ...)
        end
    end)
end
-- 饼干切割机影子优化
AddStategraphPostInit("cookiecutter", function(sg)
    local jump_pre = sg.states.jump_pre.onenter
    sg.states.jump_pre.onenter = function(inst, ...)
        jump_pre(inst, ...)
        if inst:HasTag("swp2hm") and inst.components.childspawner2hm then inst.components.childspawner2hm:ReleaseAllChildren() end
    end
    local jumping = sg.states.jumping.onenter
    sg.states.jumping.onenter = function(inst, motor_speed, ...)
        if motor_speed then motor_speed = motor_speed * (1 + math.random()) end
        jumping(inst, motor_speed, ...)
    end
end)
