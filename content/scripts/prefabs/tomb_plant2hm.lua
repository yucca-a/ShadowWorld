local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS

local grow_sounds =
{
    grow_oversized = "farming/common/farm/grow_oversized",
    grow_full = "farming/common/farm/grow_full",
    grow_rot = "farming/common/farm/rot",
}

local function PlaySound(inst, sound)
    local sounds = inst.plant_def.sounds
    if sounds ~= nil and sounds[sound] ~= nil then
        inst.SoundEmitter:PlaySound(sounds[sound])
    end
end

local function GetGerminationTime(inst, stage_num, stage_data)
    local is_good_season = inst.plant_def.good_seasons[TheWorld.state.season]
    local grow_time = inst.plant_def.grow_time.seed
    local time = GetRandomMinMax(grow_time[1], grow_time[2]) * (is_good_season and 0.5 or 1)
    -- print("GetGerminationTime " .. stage_num .. " " .. (time))
    return time
end

local function CalcGrowTime(step, num_steps, min_time, max_time)
    local max_var = max_time - min_time
    local var_per_point = max_var / num_steps
    return min_time + step * var_per_point + math.random()*var_per_point
end

local function GetGrowTime(inst, stage_num, stage_data)
    local grow_time = inst.plant_def.grow_time[stage_data.name]
    local is_good_season = inst.plant_def.good_seasons[TheWorld.state.season]

    if grow_time ~= nil then
        -- print("GetGrowTime " .. stage_num .. " " .. CalcGrowTime(2, 6, grow_time[1], grow_time[2]) * (is_good_season and 0.5 or 1))
        return CalcGrowTime(2, 6, grow_time[1], grow_time[2]) * (is_good_season and 0.5 or 1)
    end
end

local function GetSpoilTime(inst)
    -- print("GetSpoilTime " .. (inst.is_oversized and inst.plant_def.grow_time.oversized or inst.plant_def.grow_time.full))
    return (inst.is_oversized and inst.plant_def.grow_time.oversized or inst.plant_def.grow_time.full)
end

local function GetSelfRegrowTime(inst)
    -- print("GetSelfRegrowTime " .. (not inst.is_oversized and GetRandomMinMax(inst.plant_def.grow_time.regrow[1], inst.plant_def.grow_time.regrow[2]) or nil))
    return not inst.is_oversized and GetRandomMinMax(inst.plant_def.grow_time.regrow[1], inst.plant_def.grow_time.regrow[2]) or nil
end

local function PlaySowAnim(inst)
    if POPULATING or inst:IsAsleep() then
        inst.AnimState:PlayAnimation("sow_idle", true)
    else
        inst.AnimState:PlayAnimation("sow", false)
        inst.AnimState:PushAnimation("sow_idle", true)

        PlaySound(inst, "sow")
    end
end

local function ReplaceWithPlant(inst)
    local plant_prefab = TUNING.Plants["weed_forgetmelots"]
    local plant
    if plant_prefab then
        plant = SpawnPrefab(plant_prefab)
        if plant then
            plant.Transform:SetPosition(inst.Transform:GetWorldPosition())

            if plant.plant_def ~= nil then
                plant.components.growable:DoGrowth()
                plant.AnimState:OverrideSymbol("veggie_seed", "farm_soil", "seed")
            end

            inst.grew_into = plant -- so the caller can get the new plant that replaced this object
            inst.tomb:ReplaceWithPlant(plant)
        end
    else
        inst:Remove()
    end
end

local function PlayStageAnim(inst, anim, pre_override)
    if POPULATING or inst:IsAsleep() then
        inst.AnimState:PlayAnimation("crop_"..anim, true)
        inst.AnimState:SetTime(10 + math.random() * 2)
    else
        local grow_anim = pre_override or ("grow_"..anim)
        inst.AnimState:PlayAnimation(grow_anim, false)
        inst.AnimState:PushAnimation("crop_"..anim, true)

        PlaySound(inst, grow_anim)
    end

    local scale = inst.scale or 1
    inst.Transform:SetScale(scale, scale, scale)
end

local function MakePickable(inst, enable, product)
    if inst.tomb then
        inst.tomb:MakePickable_farm(enable, product)
    else
        inst.makePickable_farm = enable
    end
end

local function RemoveDirt(inst)
    if inst.dirt then
        if inst.dirt:IsValid() then
            inst.dirt:Remove()
        end
        inst.dirt = nil
    end
end

local function CheckCanAddFlower(inst)
end

local function AddDirt(inst)
    if not inst.dirt then
        inst.dirt = SpawnPrefab("dirt2hm")
        local x, y, z = inst.Transform:GetWorldPosition()
        inst.dirt.Transform:SetPosition(x, y + 0.01, z)
    end
end

local GROWTH_STAGES_RANDOMSEED =
{
    {
        name = "seed",
        time = GetGerminationTime,
        fn = function(inst, stage, stage_data)
            PlaySowAnim(inst)
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "SEED",
        tendable = false,
    },
    {
        name = "sprout",
        time = GetGrowTime,
        fn = function(inst, stage)
            ReplaceWithPlant(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
    },
}

local GROWTH_STAGES =
{
    {
        name = "seed",
        time = GetGerminationTime,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, false)
            PlayStageAnim(inst, "seed")
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "SEED",
        canAddFlower = true,
    },
    {
        name = "sprout",
        time = GetGrowTime,
        pregrowfn = function(inst)
            RemoveDirt(inst)
        end,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, false)
            PlayStageAnim(inst, "sprout", inst._grow_from_rotten and "rot_to_sprout" or nil)
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
        canAddFlower = true,
    },
    {
        name = "small",
        time = GetGrowTime,
        pregrowfn = function(inst)
            RemoveDirt(inst)
        end,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, false)
            PlayStageAnim(inst, "small")
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
        canAddFlower = true,
    },
    {
        name = "med",
        time = GetGrowTime,
        pregrowfn = function(inst)
            RemoveDirt(inst)
        end,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, false)
            PlayStageAnim(inst, "med")
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
        canAddFlower = true,
    },
    {
        name = "full",
        time = GetSpoilTime,
        pregrowfn = function(inst)
            RemoveDirt(inst)
            inst.is_oversized = inst.force_oversized or inst.flowerStage >= 4
        end,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, true)
            PlayStageAnim(inst, inst.is_oversized and "oversized" or "full")
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "FULL",
        night_grow = true,
    },
    {
        name = "rotten",
        time = GetSelfRegrowTime,
        fn = function(inst, stage, stage_data)
            -- print(stage_data.name .. " stage")
            MakePickable(inst, true)
            inst.is_rotten = true
            if inst.is_oversized then
                -- oversized plants will not self-sow after rotting
                inst.components.growable:StopGrowing()
            else
                -- normal sized plants will self-sow after rotting, but the new plant will never be achieve oversized veggies
                inst.no_oversized = true
                inst._grow_from_rotten = true -- this is not saved so be careful if you want to use it
            end
            PlayStageAnim(inst, inst.is_oversized and "rot_oversized" or "rot")
            CheckCanAddFlower(inst)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "ROTTEN",
    },
}

local function GetDisplayName(inst)
    local seed_name = "KNOWN_"..string.upper(inst.plant_def.seed)
    return subfmt(STRINGS.NAMES.FARM_PLANT_SEED, {seed = STRINGS.NAMES[seed_name]})
end

local CANGROW_TAGS = { "daylight", "lightsource" }
local function IsTooDarkToGrow(inst)
    if TheWorld.state.isnight and not inst.components.growable:GetCurrentStageData().night_grow then
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, 0, z, TUNING.DAYLIGHT_SEARCH_RANGE, CANGROW_TAGS)) do
            local lightrad = v.Light:GetCalculatedRadius() * .7
            if v:GetDistanceSqToPoint(x, y, z) < lightrad * lightrad then
                return false
            end
        end
        return true
    end
    return false
end

local function UpdateGrowing(inst)
    if inst.components.growable ~= nil and not IsTooDarkToGrow(inst) then
        inst.components.growable:Resume()
    else
        inst.components.growable:Pause()
    end
end

local function OnIsDark(inst)
    UpdateGrowing(inst)
    if TheWorld.state.isnight then
        if inst.nighttask == nil then
            inst.nighttask = inst:DoPeriodicTask(5, UpdateGrowing, math.random() * 5)
        end
    else
        if inst.nighttask ~= nil then
            inst.nighttask:Cancel()
            inst.nighttask = nil
        end
    end
end

local function OnLootPrefabSpawned(inst, data)
    local loot = data.loot
    if loot then
        loot.from_plant = true
    end
end

local function OnSave(inst, data)
    data.is_oversized = inst.is_oversized
    data.no_oversized = inst.no_oversized
    data.scale = inst.scale
    data.is_rotten = inst.is_rotten
    data.flowerStage = inst.flowerStage
end

local function OnPreLoad(inst, data)
    if data ~= nil then
        inst.is_oversized = data.is_oversized
        inst.no_oversized = data.no_oversized
        inst.scale = data.scale
        inst.is_rotten = data.is_rotten
        inst.flowerStage = data.flowerStage or inst.flowerStage
    end
end

local function OnLoad(inst, data)
    if inst.flowerStage == inst.components.growable:GetStage() then
        AddDirt(inst)
    end
end

local function OnLoadPostPass(inst)
    if inst.components.growable ~= nil then
        inst.components.growable:Pause()
    end
end

local function GetStatus(inst, viewer)
    local stage_data = inst.components.growable:GetCurrentStageData()
    local str = stage_data ~= nil and stage_data.inspect_str or nil
    if inst.is_oversized then
        str = str.."_OVERSIZED"
    end
    return str
end

local function CanGetFlower(inst)
    if inst.plant_def.is_randomseed then return false end
    local stage_data = inst.components.growable:GetCurrentStageData()
    return inst.components.growable:GetStage() == inst.flowerStage + 1 and stage_data.canAddFlower
end

local function AddFlower(inst)
    inst.flowerStage = inst.flowerStage + 1
    AddDirt(inst)
    if inst.components.growable:IsGrowing() then
        inst.components.growable:StartGrowing((inst.components.growable.targettime - GetTime()) * 0.7)
    else
        if inst.components.growable.pausedremaining then
            inst.components.growable.pausedremaining = inst.components.growable.pausedremaining * 0.7
        end
    end
    SpawnPrefab("halloween_firepuff_cold_3").Transform:SetPosition(inst.Transform:GetWorldPosition())
end

local function OnRemoveEntity(inst)
    RemoveDirt(inst)
end

local function MakePlant(veggie, plant_def)
    local assets =
    {
        Asset("ANIM", "anim/"..plant_def.bank..".zip"),
        Asset("ANIM", "anim/"..plant_def.build..".zip"),
        Asset("ANIM", "anim/farm_soil.zip"),
        Asset("SCRIPT", "scripts/prefabs/farm_plant_defs.lua"),
        Asset("SCRIPT", "scripts/prefabs/weed_defs.lua"),
    }

    local prefabs =
    {
        "spoiled_food",
        "farm_plant_happy",
        "farm_plant_unhappy",
    }
    if plant_def.product ~= nil then             table.insert(prefabs, plant_def.product) end
    if plant_def.product_oversized ~= nil then   table.insert(prefabs, plant_def.product_oversized) end
    if plant_def.seed ~= nil then                table.insert(prefabs, plant_def.seed) end
    for k, v in pairs(GROWTH_STAGES) do
        if v.dig_fx ~= nil then
            table.insert(prefabs, v.dig_fx)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.AnimState:SetBank(plant_def.bank)
        inst.AnimState:SetBuild(plant_def.build)
        inst.AnimState:OverrideSymbol("soil01", "farm_soil", "soil01")

        inst:AddTag("NOCLICK")
        inst:AddTag("NOBLOCK")
        inst:AddTag("farm_plant")

        inst.displaynamefn = GetDisplayName

        inst.plant_def = plant_def

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.OnSave = OnSave
        inst.OnPreLoad = OnPreLoad
        inst.OnLoad = OnLoad
        inst.OnLoadPostPass = OnLoadPostPass
        inst.GetStatus = GetStatus
        inst.CanGetFlower = CanGetFlower
        inst.AddFlower = AddFlower
        inst.OnRemoveEntity = OnRemoveEntity

        inst.scale = 0.75
        inst.flowerStage = 0
        inst.nameoverride = plant_def.prefab
        inst:AddComponent("growable")
        inst.components.growable.growoffscreen = true
        inst.components.growable.stages = plant_def.is_randomseed and GROWTH_STAGES_RANDOMSEED or GROWTH_STAGES
        inst.components.growable:SetStage(1)
        inst.components.growable.loopstages = true
        inst.components.growable.loopstages_start = 2
        inst.components.growable:StartGrowing()
        inst.components.growable:Pause()


        inst:WatchWorldState("isnight", OnIsDark)
        inst:DoTaskInTime(0, OnIsDark)

        inst:ListenForEvent("loot_prefab_spawned", OnLootPrefabSpawned)

        return inst
    end

    return Prefab("tomb_plant2hm_" .. veggie, fn, assets, prefabs)
end

local plant_prefabs = {}
for veggie, plant_def in pairs(PLANT_DEFS) do
    if not plant_def.data_only then --allow mods to skip our prefab constructor.
        table.insert(plant_prefabs, MakePlant(veggie, plant_def))
        TUNING.Plants[plant_def.prefab] = "tomb_plant2hm_" .. veggie
    end
end

return unpack(plant_prefabs)
