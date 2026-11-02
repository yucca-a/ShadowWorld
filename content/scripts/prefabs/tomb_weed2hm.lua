local WEED_DEFS = require("prefabs/weed_defs").WEED_DEFS

local function GetGrowTime(inst, stage_num, stage_data)
    local grow_time = inst.weed_def.grow_time[stage_data.name]
    if grow_time ~= nil then
        return GetRandomMinMax(grow_time[1], grow_time[2])
    end
end

local function MakePickable(inst, enable, product)
    if inst.tomb then
        inst.tomb:MakePickable_weed(enable, product)
    else
        inst.makePickable_weed = enable
    end
end

local function PlayStageAnim(inst, anim, custom_pre)
    if POPULATING or inst:IsAsleep() then
        inst.AnimState:PlayAnimation("crop_"..anim, true)
        local num_frames = inst.AnimState:GetCurrentAnimationNumFrames()
        if num_frames > 0 then
            inst.AnimState:SetFrame(math.random(num_frames) - 1)
        end
    elseif custom_pre ~= nil then
        inst.AnimState:PlayAnimation(custom_pre, false)
        inst.AnimState:PushAnimation("crop_"..anim, true)
    else
        inst.AnimState:PlayAnimation("grow_"..anim, false)
        inst.AnimState:PushAnimation("crop_"..anim, true)
    end
end

local GROWTH_STAGES =
{
    {
        name = "small",
        time = GetGrowTime,
        fn = function(inst, stage, stage_data)
            MakePickable(inst, false)
            if inst.mature then
                PlayStageAnim(inst, "picked")
            else
                PlayStageAnim(inst, "small")
            end
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
    },
    {
        name = "med",
        time = GetGrowTime,
        fn = function(inst, stage, stage_data)
            MakePickable(inst, false)
            PlayStageAnim(inst, "med", inst.mature and "picked_to_med" or nil)
        end,
        dig_fx = "dirt_puff",
        inspect_str = "GROWING",
    },
    {
        name = "full",
        time = GetGrowTime,
        fn = function(inst, stage, stage_data)
            MakePickable(inst, true)
            PlayStageAnim(inst, "full")
            inst.mature = true
        end,
        dig_fx = "dirt_puff",
        inspect_str = "FULL_WEED",
    },
    {
        name = "bolting",
        fn = function(inst, stage, stage_data)
            MakePickable(inst, true)
            inst.components.growable:StopGrowing()
            PlayStageAnim(inst, "bloomed")
            inst.mature = true
        end,
        dig_fx = "dirt_puff",
        inspect_str = "FULL_WEED",
    },
}

local GROWTH_STAGES_NO_BOLTING = { GROWTH_STAGES[1], GROWTH_STAGES[2], GROWTH_STAGES[3] }
local BLOOMING_BANKS = { weed_forgetmelots = true }

local function OnSave(inst, data)
    data.from_seed = inst.from_seed
    data.mature = inst.mature
end

local function OnPreLoad(inst, data)
    if data ~= nil then
        inst.from_seed = data.from_seed
        inst.mature = data.mature
    end
end

local function OnLoad(inst, data)
end

local function GetStatus(inst)
    local stage_data = inst.components.growable:GetCurrentStageData()
    return stage_data ~= nil and stage_data.inspect_str or nil
end

local function CanGetFlower(inst)
    return false
end

local function AddFlower(inst)
end

local function MakeWeed(weed, weed_def)
    local assets =
    {
        Asset("ANIM", "anim/"..weed_def.bank..".zip"),
        Asset("ANIM", "anim/"..weed_def.build..".zip"),
        Asset("ANIM", "anim/farm_soil.zip"),
        Asset("SCRIPT", "scripts/prefabs/weed_defs.lua"),
    }

    local prefabs =
    {
        "farm_plant_happy",
    }
    if weed_def.product then
        table.insert(prefabs, weed_def.product)
    end

    for k, v in pairs(GROWTH_STAGES) do
        if v.dig_fx ~= nil then
            table.insert(prefabs, v.dig_fx)
        end
    end

    if weed_def.prefab_deps ~= nil then
        for _, v in ipairs(weed_def.prefab_deps) do
            table.insert(prefabs, v)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst.AnimState:SetBank(weed_def.bank)
        inst.AnimState:SetBuild(weed_def.build)
        inst.AnimState:PlayAnimation("crop_small")
        inst.AnimState:OverrideSymbol("soil01", "farm_soil", "soil01")

        inst:AddTag("NOCLICK")
        inst:AddTag("NOBLOCK")
        inst:AddTag("farm_plant")

        inst.weed_def = weed_def

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.nameoverride = weed_def.prefab
        inst:AddComponent("growable")
        inst.components.growable.growoffscreen = true
        inst.components.growable.stages = BLOOMING_BANKS[weed_def.bank] and GROWTH_STAGES or GROWTH_STAGES_NO_BOLTING
        inst.components.growable:SetStage(1)
        inst.components.growable:StartGrowing()

        inst.OnSave = OnSave
        inst.OnPreLoad = OnPreLoad
        inst.OnLoad = OnLoad
        inst.GetStatus = GetStatus
        inst.CanGetFlower = CanGetFlower
        inst.AddFlower = AddFlower

        return inst
    end

    return Prefab("tomb_weed2hm_" .. weed, fn, assets, prefabs)
end


local plant_prefabs = {}
for weed, weed_def in pairs(WEED_DEFS) do
    if not weed_def.data_only then --allow mods to skip our prefab constructor.
        table.insert(plant_prefabs, MakeWeed(weed, weed_def))
        TUNING.Plants[weed_def.prefab] = "tomb_weed2hm_" .. weed
    end
end

return unpack(plant_prefabs)
