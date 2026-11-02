local plant_change = GetModConfigData("plant_change")
if plant_change == false then return end
local changeIndex = (plant_change == -1 or plant_change == true) and 3 or plant_change
local epicchangeindex = (changeIndex - 1) * 3 / 14 + 1
local else_changeIndex = math.max(changeIndex / 2, 1)

TUNING.PINECONE_GROWTIME.base = TUNING.PINECONE_GROWTIME.base * plant_change
TUNING.PINECONE_GROWTIME.random = TUNING.PINECONE_GROWTIME.random * plant_change
TUNING.GRASSGEKKO_REGROW_TIME = TUNING.GRASSGEKKO_REGROW_TIME * plant_change
TUNING.GRASSGATOR_SHEDTIME_SET = TUNING.GRASSGATOR_SHEDTIME_SET * plant_change
TUNING.GRASSGATOR_SHEDTIME_VAR = TUNING.GRASSGATOR_SHEDTIME_VAR * plant_change

local function isNeedPlant(inst)
    return not inst:HasTag("animal") and not inst:HasTag("spiderden") and not inst:HasTag("farm_plant") and inst.prefab ~= "oceantree" and
               not (inst.TransferPlantData and (inst.type == "gem" or inst.type == "nightvision"))
end

-- 生长变慢
local function processgrowablestages(self)
    if self.stages then
        for index, stage in ipairs(self.stages) do
            if stage.processd2hm then break end
            stage.processd2hm = true
            if stage.time and type(stage.time) == "function" then
                local oldtime = stage.time
                stage.time = function(...)
                    local time = oldtime(...)
                    return time and time * changeIndex
                end
            end
        end
    end
end
AddComponentPostInit("growable", function(self)
    local oldStartGrowing = self.StartGrowing
    self.StartGrowing = function(self, time, ...)
        if isNeedPlant(self.inst) then
            if time and time > 0 and not (self.stages and self.stages[self.stage] and self.stages[self.stage].time) then time = time * changeIndex end
            processgrowablestages(self)
        end
        oldStartGrowing(self, time, ...)
    end
end)

local function processpickable(inst, self)-- 2025.8.17 melon:增加and self.getregentimefn(inst)
    if self.getregentimefn and self.getregentimefn(inst) and type(self.getregentimefn) == "function" then
        local old = self.getregentimefn
        self.getregentimefn = function(inst, ...) return old(inst, ...) * changeIndex end
    end
end
AddComponentPostInit("pickable", function(self)
    local oldSetUp = self.SetUp
    self.SetUp = function(self, product, regen, number, ...)
        if regen and regen > 0 then regen = regen * changeIndex end
        oldSetUp(self, product, regen, number, ...)
    end
    self.inst:DoTaskInTime(0, processpickable, self)
end)

AddComponentPostInit("harvestable", function(self)
    local oldSetGrowTime = self.SetGrowTime
    self.SetGrowTime = function(self, time, ...)
        if time and time > 0 then time = time * changeIndex end
        oldSetGrowTime(self, time, ...)
    end
    local oldStartGrowing = self.StartGrowing
    self.StartGrowing = function(self, time, ...)
        if not POPULATING and time and time > 0 then time = time * changeIndex end
        oldStartGrowing(self, time, ...)
    end
end)

AddComponentPostInit("crop", function(self)
    self.rate = self.rate / changeIndex
    local oldStartGrowing = self.StartGrowing
    self.StartGrowing = function(self, prod, time, ...)
        if time and time > 0 then time = time * changeIndex end
        oldStartGrowing(self, prod, time, ...)
    end
end)

if CONFIGS_LEGION then
    AddComponentPostInit("perennialcrop2", function(self)
        local oldGetGrowTime = self.GetGrowTime
        self.GetGrowTime = function(self, ...)
            local time = oldGetGrowTime(self, ...)
            return time and time * changeIndex
        end
    end)
end

if TUNING.NDNR_ACTIVE then
    AddComponentPostInit("ndnr_pluckable", function(self)
        local SetRespawnTime = self.SetRespawnTime
        self.SetRespawnTime = function(self, time, ...)
            if time and not self.inst.components.health and
                (self.inst.components.growable or self.inst.components.pickable or self.inst.components.crop or self.inst.components.harvestable) then
                time = time * changeIndex
            end
            SetRespawnTime(self, time, ...)
        end
    end)
end

-- 妥协巨树蓝莓恢复变慢,帮助金鱼草修BUG
if TUNING.DSTU then
    AddPrefabPostInit("diseasecure", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.timer then inst.components.timer:SetTimeLeft("disperse", TUNING.SLEEPBOMB_DURATION / 2) end
    end)
    local function slowgrow(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.timer and inst.components.timer.StartTimer then
            local StartTimer = inst.components.timer.StartTimer
            inst.components.timer.StartTimer = function(self, name, time, ...)
                if time and name == "regrow" then time = POPULATING and time or time * changeIndex end
                return StartTimer(self, name, time, ...)
            end
        end
    end
    AddPrefabPostInit("giant_tree", slowgrow)
    AddPrefabPostInit("blueberryplant", slowgrow)
    AddPrefabPostInit("whisperpod_normal_ground",
                      function(inst) SetOnSave(inst, function(inst, data) if inst.growing and not data.growing then data.growing = true end end) end)
end

-- 大理石灌木可以催生
AddPrefabPostInit("marbleshrub", function(inst)
    inst:AddTag("silviculture")
    if not TheWorld.ismastersim then return end
    inst.components.growable.magicgrowable = true
end)

-- 光茄生成速率减慢
if else_changeIndex > 1 then
    local function OnLunarRiftReachedMaxSize(source, rift)
        local self = TheWorld.components.lunarthrall_plantspawner
        if self.waves_to_release and self.waves_to_release > 0 then
            self.waves_to_release = math.max(math.ceil(self.waves_to_release / else_changeIndex), 1)
        end
        if self._nextspawn then
            local time = GetTaskRemaining(self._nextspawn)
            local SpawnThralls = self._nextspawn.fn
            if time and time > 0 and SpawnThralls then
                self._nextspawn:Cancel()
                self._nextspawn = nil
                self._nextspawn = self.inst:DoTaskInTime(time * else_changeIndex, SpawnThralls)
            end
        elseif self._spawntask and self._spawntask.fn then
            local setTimeForPoralRelease = self._spawntask.fn
            setTimeForPoralRelease()
        end
        if self._spawntask then
            local time = GetTaskRemaining(self._spawntask)
            local setTimeForPoralRelease = self._spawntask.fn
            if time and time > 0 and setTimeForPoralRelease then
                self._spawntask:Cancel()
                self._spawntask = nil
                self._spawntask = self.inst:DoTaskInTime(time * else_changeIndex, setTimeForPoralRelease)
            end
        end
    end
    local function DealyOnLunarRiftReachedMaxSize(inst, ...)
        if POPULATING then return end
        inst:DoTaskInTime(FRAMES, OnLunarRiftReachedMaxSize, ...)
    end
    AddComponentPostInit("lunarthrall_plantspawner", function(self) self.inst:ListenForEvent("ms_lunarrift_maxsize", DealyOnLunarRiftReachedMaxSize) end)
end

-- 森林织影者更慢生成植物
local function slowbloomtask(inst)
    if inst._bloomtask and inst._bloomtask.period and not inst._bloomtask.period2hm then
        inst._bloomtask.period2hm = true
        inst._bloomtask.period = inst._bloomtask.period * changeIndex * (GetModConfigData("Shadow World") and 2 or 1)
    end
end
AddPrefabPostInit("stalker_forest", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(FRAMES, slowbloomtask)
    local StartBlooming = inst.StartBlooming
    inst.StartBlooming = function(inst, ...)
        StartBlooming(inst, ...)
        inst:DoTaskInTime(FRAMES, slowbloomtask)
    end
    local OnEntityWake = inst.OnEntityWake
    inst.OnEntityWake = function(inst, ...)
        OnEntityWake(inst, ...)
        inst:DoTaskInTime(FRAMES, slowbloomtask)
    end
end)

-- 干浆果
local cooking = require("cooking")
local berriesVEGGIES = {"berries", "berries_juicy"}
local function onperished(inst)
    if inst.components.perishable and inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.inventoryitem.owner:IsValid() then
        if not (inst.components.inventoryitem.owner.components.container and inst.components.inventoryitem.owner.components.container.itemtestfn) then
            inst.components.perishable.onperishreplacement = inst.prefab .. "_dried2hm"
        end
    elseif inst.components.perishable and inst:IsAsleep() then
        inst.components.perishable.onperishreplacement = nil
        inst:DoTaskInTime(0, inst.Remove)
    end
end
local hungervalue = TUNING.DSTU and TUNING.DSTU.SEEDS and TUNING.DSTU.FOOD_SEEDS_HUNGER or TUNING.CALORIES_TINY / 2
local function veggiepostinit(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.perishable then inst:ListenForEvent("perished", onperished) end
end
for _, veggiename in ipairs(berriesVEGGIES) do
    AddIngredientValues({veggiename .. "_dried2hm"}, {fruit = .25})
    AddPrefabPostInit(veggiename, veggiepostinit)
end

-- 阴郁之棘、晶洞果
local ancienttree_defs = require("prefabs/ancienttree_defs")
local PLANT_DATA = ancienttree_defs.PLANT_DATA
PLANT_DATA.fruit_regen.max = PLANT_DATA.fruit_regen.max * changeIndex * 5 / 16
PLANT_DATA.fruit_regen.min = PLANT_DATA.fruit_regen.min * changeIndex * 25 / 48

-- 三色蘑菇
local mushroom = {"red_mushroom", "green_mushroom", "blue_mushroom"}
for i, v in pairs(mushroom) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.pickable and inst.components.pickable.onpickedfn then
            local oldpickedfn = inst.components.pickable.onpickedfn
            inst.components.pickable.onpickedfn = function(inst, ...)
                oldpickedfn(inst, ...)
                inst.rain = inst.rain * changeIndex
            end
        end
    end)
end

-- 石头树生长速度削弱，种植在远古区域需要铥矿施肥，最后一击需要强力开采
TUNING.TREE_ROCK.SAPLING_GROW_TIME.base = TUNING.TREE_ROCK.SAPLING_GROW_TIME.base * changeIndex
local Boulderbough = GetModConfigData("Boulderbough")
if Boulderbough then
    AddPrefabPostInit("tree_rock_sapling", function(inst)
        if not TheWorld.ismastersim then return end
        inst.been_fertilized2hm = nil
        if inst.components.timer then
            local oldStartTimer = inst.components.timer.StartTimer
            inst.components.timer.StartTimer = function(self, name, time, paused, ...)
                oldStartTimer(self, name, time, paused, ...)
                local x, y, z = inst.Transform:GetWorldPosition()
                local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z, "Nightmare")
                if name == "grow" and not self.inst.been_fertilized2hm and node ~= nil then
                    self:PauseTimer(name)
                end
            end
            inst:DoTaskInTime(0, function()
                local x, y, z = inst.Transform:GetWorldPosition()
                local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z, "Nightmare")
                if not inst.been_fertilized2hm and node ~= nil then inst.components.timer:PauseTimer("grow")end
            end)
        end
        local oldonsave = inst.OnSave
        inst.OnSave = function(inst, data)
            if oldonsave then oldonsave(inst, data) end
            if inst.been_fertilized2hm then
                data.been_fertilized2hm = true
            end
        end
        local oldonload = inst.OnLoad
        inst.OnLoad = function(inst, data)
            if oldonload then oldonload(inst, data) end
            if data and data.been_fertilized2hm then
                inst:AddTag("been_fertilized2hm")
                inst.been_fertilized2hm = true
                if inst.components.timer then
                    inst.components.timer:ResumeTimer("grow")
                end
            end
        end
        if not inst.components.inspectable then inst:AddComponent("inspectable") end
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, ...)
            local desc, filter_context, author = GetDescription(self, ...)
            if not inst:HasTag("been_fertilized2hm") then
                desc = (desc or "") .. (TUNING.isCh2hm and "\n" .. "需要1个铥矿或6个铥矿碎片施肥" or "\n" .. "Need 1 Thulecite or 6 Thulecite Pieces For Fertilization")
            end
            return  desc, filter_context, author
        end
    end)

    local function Fertilizationcondition(inst, doer, actions, right, target)
        if target.prefab == "tree_rock_sapling" then
            local x, y, z = target.Transform:GetWorldPosition()
            local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z, "Nightmare")
            if node ~= nil then
                if inst.prefab == "thulecite" and not target:HasTag("been_fertilized2hm") then
                    return true
                elseif inst.prefab == "thulecite_pieces" and not target:HasTag("been_fertilized2hm") 
                and doer and doer.replica.inventory and doer.replica.inventory:Has(inst.prefab, 6) then
                    return true
                end
                return false
            end
            return false
        end
        return false
    end

    local function Fertilization2hm(inst, doer, target, pos, act)
        if inst.prefab == "thulecite_pieces" and  target.prefab == "tree_rock_sapling" and not target.been_fertilized2hm and inst.components and inst.components.stackable then
            target:AddTag("been_fertilized2hm")
            target.been_fertilized2hm = true
            doer.SoundEmitter:PlaySound("aqol/new_test/rock")
            inst.components.stackable:Get(6):Remove()
            if target.components.timer then
                target.components.timer:ResumeTimer("grow")
            end
            return true
        elseif inst.prefab == "thulecite" and target.prefab == "tree_rock_sapling" and not target.been_fertilized2hm and inst.components and inst.components.stackable then
            target:AddTag("been_fertilized2hm")
            target.been_fertilized2hm = true
            doer.SoundEmitter:PlaySound("aqol/new_test/rock")
            inst.components.stackable:Get(1):Remove()
            if target.components.timer then
                target.components.timer:ResumeTimer("grow")
            end
            return true
        end
        return false
    end

    STRINGS.ACTIONS.ACTION2HM.FERTILIZATION = TUNING.isCh2hm and "施肥" or "FERTILIZATION"
    AddPrefabPostInit("thulecite_pieces", function(inst)
        inst.actionothercondition2hm = Fertilizationcondition
        inst.actiontext2hm = "FERTILIZATION"
        if not TheWorld.ismastersim then return end
        inst:AddComponent("action2hm")
        inst.components.action2hm.actionfn = Fertilization2hm
    end)

    AddPrefabPostInit("thulecite", function(inst)
        inst.actionothercondition2hm = Fertilizationcondition
        inst.actiontext2hm = "FERTILIZATION"
        if not TheWorld.ismastersim then return end
        inst:AddComponent("action2hm")
        inst.components.action2hm.actionfn = Fertilization2hm
    end)

    local tree_rock = {"tree_rock", "tree_rock2_normal", "tree_rock2_short", "tree_rock1_normal", "tree_rock1_short", "tree_rock2", "tree_rock1"}
    for i, v in pairs(tree_rock) do
        AddPrefabPostInit(v, function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.workable then
                local oldonwork = inst.components.workable.onwork
                inst.components.workable:SetOnWorkCallback(function(inst, worker, ...)
                    oldonwork(inst, worker, ...)
                    if inst.components.workable.workleft <= 0 and not inst.components.workable.tough then
                        inst.components.workable:SetWorkLeft(1)
                        inst.components.workable:SetRequiresToughWork(true)
                    end
                end)
            end
        end)
    end
end