----------------------------[生物(动物、植物)]------------------------------------
---------------------------------------------------------------------------------
local hardmode = TUNING.hardmode2hm

-- melon:和帽子戏法有关，不知道什么作用
AddComponentPostInit("epicscare", function(self)
    table.insert(self.scareexcludetags, "noscare2hm" )
end)
AddComponentPostInit("hauntable", function(self)
    local oldPanic = self.Panic
    function self:Panic(...)
        if self.inst:HasTag("noscare2hm") then
            return
        else
            return oldPanic(self, ...)
        end
    end
end)

-- 多枝树可采集树枝
if GetModConfigData("Twiggy Tree Can Pickable") then
    local function OnPick(inst)
        -- local twiggy_short = SpawnPrefab("twiggy_short")
        -- twiggy_short.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if inst.components.growable then inst.components.growable:SetStage(1) end
    end
    local stageprods = {0, 1, 3}

    local function resetproduct(inst)
        if not inst.components.growable then
            inst.components.pickable:SetUp(nil)
            inst.components.pickable.canbepicked = false
            return
        end
        inst.components.pickable.canbepicked = (inst.components.growable.stage == 3 or inst.components.growable.stage == 2) and not inst:HasTag("burnt") and
                                                   not inst:HasTag("stump")
        local prods = stageprods[inst.components.growable.stage]
        if prods and prods ~= 0 then
            inst.components.pickable:SetUp("twigs", 10, prods)
        else
            inst.components.pickable:SetUp(nil)
            inst.components.pickable.canbepicked = false
        end
    end

    AddPrefabPostInit("twiggytree", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.pickable then return end
        inst:AddComponent("pickable")
        inst.components.pickable.picksound = "dontstarve/wilson/harvest_sticks"
        inst.components.pickable:SetOnPickedFn(OnPick)
        inst.components.pickable.droppicked = true
        inst.components.pickable.dropheight = 3.5

        inst:DoTaskInTime(0, resetproduct)

        if inst.components.growable then
            local oldSetStage = inst.components.growable.SetStage
            inst.components.growable.SetStage = function(self, stage)
                oldSetStage(self, stage)
                resetproduct(self.inst)
            end
        end
        inst:ListenForEvent("workfinished", function(inst) inst.components.pickable.canbepicked = false end)
        inst:ListenForEvent("onburnt", function(inst) inst.components.pickable.canbepicked = false end)
    end)
end

-- 草根变成草蜥蜴时再生草根
if GetModConfigData("Grass Gekko Regrow Grass") then
    AddPrefabPostInit("grasspartfx", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, function()
            local depleted_grass = SpawnPrefab("grass")
            depleted_grass.Transform:SetPosition(inst.Transform:GetWorldPosition())
            depleted_grass.components.pickable:MakeBarren()
        end)
    end)
end

-- 杂草种植
if GetModConfigData("Weed Product Can Plant") then
    local data = {tillweed = "weed_tillweed", forgetmelots = "weed_forgetmelots", firenettles = "weed_firenettle"}
    local function pickfarmplant(inst) return data[inst.prefab] or "weed_forgetmelots" end
    local function OnDeploy(inst, pt, deployer) -- , rot)
        local plant = SpawnPrefab(pickfarmplant(inst))
        plant.Transform:SetPosition(pt.x, 0, pt.z)
        plant:PushEvent("on_planted", {in_soil = false, doer = deployer, seed = inst})
        TheWorld.Map:CollapseSoilAtPoint(pt.x, 0, pt.z)
        -- plant.SoundEmitter:PlaySound("dontstarve/wilson/plant_seeds")
        inst:Remove()
    end
    local function can_plant_seed(inst, pt, mouseover, deployer)
        local x, z = pt.x, pt.z
        return TheWorld.Map:CanTillSoilAtPoint(x, 0, z, true)
    end
    local function WeedProductCanPlant(inst)
        inst:AddTag("deployedplant")
        inst:AddTag("deployedfarmplant")
        inst._custom_candeploy_fn = can_plant_seed
        if not TheWorld.ismastersim then return end
        if not inst.components.farmplantable and not inst.components.deployable then
            inst:AddComponent("farmplantable")
            inst.components.farmplantable.plant = pickfarmplant -- "farm_plant_watermelon"
            inst:AddComponent("deployable")
            inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM) -- use inst._custom_candeploy_fn
            inst.components.deployable.restrictedtag = "plantkin"
            inst.components.deployable.ondeploy = OnDeploy
        end
    end
    AddPrefabPostInit("tillweed", WeedProductCanPlant)
    AddPrefabPostInit("forgetmelots", WeedProductCanPlant)
    AddPrefabPostInit("firenettles", WeedProductCanPlant)
    local function RefreshStatus(inst)
        if inst.components.growable and inst.components.growable:GetStage() == 4 then
            inst.components.growable:SetStage(1)
            inst.components.growable:StartGrowing()
        end
    end
    AddPrefabPostInit("weed_forgetmelots", function(inst)
        if not TheWorld.ismastersim then return end
        inst:WatchWorldState("startspring", RefreshStatus)
        inst:WatchWorldState("startautumn", RefreshStatus)
    end)
end

-- 格罗姆吃周围的昆虫
if GetModConfigData("Glommer Eat Near Insects") then modimport("food/glommer.lua") end


-- 无开关-------------------------------------------------------------------------------
-- 2025.8.12 melon:电击改动----------------------
-- 亮茄被电不烧
local burn_prefab = {"lunarthrall_plant", "lunarthrall_plant_vine", "lunarthrall_plant_vine_end", "lordfruitfly",}
for _, prefab in ipairs(burn_prefab) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim then return end
        inst.noelectrocutetask2hm = inst:DoTaskInTime(0, function(inst)
            if inst.sg and inst.sg.mem then inst.sg.mem.burn_on_electrocute = false end
        end)
    end)
end

-- 2025.8.22 melon:增加牛角/触手皮/羊角掉率   改用插入方式-------------------------------
local function addloot(name, loot, p) if LootTables[name] then table.insert(LootTables[name], {loot, p}) end end
AddSimPostInit(function() -- 2025.10.22 加判空
    addloot('beefalo', 'horn', 0.15) -- 牛+牛角
    addloot('tentacle', 'tentaclespots', 0.1) -- 触手+皮
    addloot('tentacle_pillar', 'tentaclespots', 0.1) -- 大触手+皮
    addloot('lightninggoat', 'lightninggoathorn',0.2) -- 电羊+角
    addloot('chargedlightninggoat', 'lightninggoathorn', 0.3) -- 带电电羊+角
    -- if LootTables['beefalo'] then table.insert(LootTables['beefalo'], {'horn',0.15}) end
    -- if LootTables['tentacle'] then table.insert(LootTables['tentacle'], {'tentaclespots',0.1}) end
    -- if LootTables['tentacle_pillar'] then table.insert(LootTables['tentacle_pillar'], {'tentaclespots',0.1}) end
    -- if LootTables['lightninggoat'] then table.insert(LootTables['lightninggoat'], {'lightninggoathorn',0.2}) end
    -- if LootTables['chargedlightninggoat'] then table.insert(LootTables['chargedlightninggoat'], {'lightninggoathorn',0.3}) end -- 电羊+角
end)

