local FADE_FRAMES = 26
local FADE_INTENSITY = .8
local FADE_FALLOFF = .5
local FADE_RADIUS = 1.5
local BLOOM_DECAY = 480

local function OnUpdateFade(inst)
    local k
    if inst._fade:value() <= FADE_FRAMES then
        inst._fade:set_local(math.min(inst._fade:value() + 1, FADE_FRAMES))
        k = inst._fade:value() / FADE_FRAMES
        k = k * k
    else
        inst._fade:set_local(math.min(inst._fade:value() + 1, FADE_FRAMES * 2 + 1))
        k = (FADE_FRAMES * 2 + 1 - inst._fade:value()) / FADE_FRAMES
    end

    inst.Light:SetIntensity(FADE_INTENSITY * k)
    inst.Light:SetRadius(FADE_RADIUS * k)
    inst.Light:SetFalloff(1 - (1 - FADE_FALLOFF) * k)

    if TheWorld.ismastersim then inst.Light:Enable(inst._fade:value() > 0 and inst._fade:value() <= FADE_FRAMES * 2) end

    if inst._fadetask and (inst._fade:value() == FADE_FRAMES or inst._fade:value() > FADE_FRAMES * 2) then
        inst._fadetask:Cancel()
        inst._fadetask = nil
    end
end

local function OnFadeDirty(inst)
    if inst._fadetask == nil then inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateFade) end
    OnUpdateFade(inst)
end

local function FadeOut(inst, instant)
    if instant then
        inst._fade:set(FADE_FRAMES * 2 + 1)
        OnFadeDirty(inst)
    elseif inst._fade:value() <= FADE_FRAMES then
        inst._fade:set(FADE_FRAMES * 2 + 1 - inst._fade:value())
        if inst._fadetask == nil then inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateFade) end
    end
end

local function KillPlant(inst)
    if inst._killtask ~= nil then
        inst._killtask:Cancel()
        inst._killtask = nil
    end
    inst.components.pickable.caninteractwith = false
    FadeOut(inst)
    inst:ListenForEvent("animover", inst.Remove)
    inst.AnimState:PlayAnimation(inst._moddata.killanim)
end

-- 诱惑玩家采集,3秒CD
local function onnear(inst, target)
    if target and target:HasTag("player") and not target:HasTag("playerghost") and inst.components.pickable.caninteractwith and
        not target.avoiddevilplanttask2hm and target.forcepickdevilplant2hm then
        target:forcepickdevilplant2hm(inst)
        target.avoiddevilplanttask2hm = target:DoTaskInTime(3, function() target.avoiddevilplanttask2hm = nil end)
    end
end

local function OnBloomed(inst)
    inst:RemoveEventCallback("animover", OnBloomed)
    inst.AnimState:PlayAnimation(inst._moddata.idleanim or "idle", true)
    inst.components.pickable.caninteractwith = true
    if not inst.components.playerprox2hm then
        inst:AddComponent("playerprox2hm")
        inst.components.playerprox2hm:SetTargetMode(inst.components.playerprox2hm.TargetModes.AllPlayers)
        inst:ListenForEvent("onnear2hm", onnear)
    end
    if not inst.preventkill then inst._killtask = inst:DoTaskInTime(BLOOM_DECAY, KillPlant) end
end

local function OnPicked(inst, picker, loot)
    if loot and picker then
        loot.lockowner2hm = picker
        loot.Transform:SetPosition(picker.Transform:GetWorldPosition())
    end
    if inst._killtask ~= nil then
        inst._killtask:Cancel()
        inst._killtask = nil
    end
    FadeOut(inst, true)
    inst:RemoveEventCallback("animover", OnBloomed)
    inst:ListenForEvent("animover", inst.Remove)
    inst.AnimState:PlayAnimation(inst._moddata.pickinganim)
end

local function MakeDevilPlants(data)
    local assets = data.assets or {Asset("ANIM", "anim/" .. (data.asset or data.name) .. ".zip")}

    -- 采集果实
    local prefabs = {data.product}

    local function fn()
        local inst = CreateEntity()

        inst._moddata = data

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddLight()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.Light:SetFalloff(FADE_FALLOFF)
        inst.Light:SetIntensity(FADE_INTENSITY)
        inst.Light:SetRadius(FADE_RADIUS)
        inst.Light:SetColour(1, 1, 1)
        inst.Light:Enable(false)
        inst.Light:EnableClientModulation(true)

        MakeInventoryPhysics(inst, nil, 0.1)

        inst.AnimState:SetBank(data.bank or data.asset or data.name)
        inst.AnimState:SetBuild(data.build or data.asset or data.name)
        inst.AnimState:PlayAnimation(data.growinganim or "grow")
        inst.AnimState:SetMultColour(0.75, 0.75, 0.75, 0.75)

        inst:AddTag("devil_plant2hm")

        inst._fade = net_smallbyte(inst.GUID, "stalker_berry._fade", "fadedirty")
        inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateFade)

        inst:SetPrefabNameOverride(data.nameoverride or data.name)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            inst:ListenForEvent("fadedirty", OnFadeDirty)
            return inst
        end

        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/flowergrow")

        inst:AddComponent("pickable")
        inst.components.pickable.picksound = "dontstarve/wilson/pickup_reeds" or data.picksound
        inst.components.pickable.onpickedfn = OnPicked
        inst.components.pickable.caninteractwith = false
        inst.components.pickable:SetUp(data.product, 1000000)
        inst.components.pickable:Pause()

        inst:AddComponent("inspectable")
        inst:AddComponent("lootdropper")

        inst:ListenForEvent("animover", OnBloomed)

        inst.KillPlant = KillPlant

        ---------------------
        MakeMediumBurnable(inst)
        MakeSmallPropagator(inst)
        -- Clear default handlers so we don't stomp our .persists flag
        inst.components.burnable:SetOnIgniteFn(nil)
        inst.components.burnable:SetOnExtinguishFn(nil)
        ---------------------

        MakeHauntableIgnite(inst)

        -- inst.persists = false
        return inst
    end
    return Prefab(data.prefabname, fn, assets, prefabs)
end

local devil_plant_pickable = {
    -- 香蕉丛
    bananabush = {
        product = "cave_banana",
        growinganim = "grow_medium_to_big",
        idleanim = "idle_big",
        pickinganim = "idle_to_dead",
        killanim = "dead",
        picksound = "dontstarve/wilson/harvest_berries"
    },
    -- 浆果丛
    berrybush = {
        product = "berries",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "idle_to_dead",
        killanim = "idle_to_dead",
        picksound = "dontstarve/wilson/harvest_berries"
    },
    berrybush2 = {
        product = "berries",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "idle_to_dead",
        killanim = "idle_to_dead",
        picksound = "dontstarve/wilson/harvest_berries"
    },
    berrybush_juicy = {
        product = "berries_juicy",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "idle_to_dead",
        killanim = "idle_to_dead",
        picksound = "dontstarve/wilson/harvest_berries"
    },
    -- 海带
    bullkelp_plant = {
        asset = "bullkelp_underwater",
        bank = "bullkelp",
        build = "bullkelp",
        product = "kelp",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "picking",
        killanim = "picked",
        picksound = "turnoftides/common/together/water/harvest_plant"
    },
    -- 仙人掌
    cactus = {
        product = "cactus_meat",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "picked",
        killanim = "empty",
        picksound = "dontstarve/wilson/harvest_sticks"
    },
    oasis_cactus = {
        product = "cactus_meat",
        growinganim = "grow",
        idleanim = "idle",
        pickinganim = "picked",
        killanim = "empty",
        picksound = "dontstarve/wilson/harvest_sticks",
        nameoverride = "cactus"
    },
    -- 胡萝卜
    -- carrot_planted = {
    --     asset = "carrot",
    --     bank = "carrot",
    --     build = "carrot",
    --     product = "carrot",
    --     growinganim = "planted",
    --     idleanim = "planted",
    --     pickinganim = "planted",
    --     killanim = "planted",
    --     picksound = "dontstarve/wilson/pickup_plants"
    -- },
    -- -- 洞穴香蕉树
    -- cave_banana_tree = {
    --     product = "cave_banana",
    --     growinganim = "grow",
    --     idleanim = "idle_loop",
    --     pickinganim = "pick",
    --     killanim = "planted",
    --     picksound = "dontstarve/wilson/pickup_reeds"
    -- },
    -- -- 苔藓
    -- lichen = {
    --     asset = "algae_bush",
    --     bank = "algae_bush",
    --     build = "algae_bush",
    --     product = "cutlichen",
    --     growinganim = "grow",
    --     idleanim = "idle",
    --     pickinganim = "picking",
    --     killanim = "picked",
    --     picksound = "dontstarve/wilson/pickup_lichen"
    -- },
    -- -- 荧光花
    -- flower_cave = {
    --     asset = "bulb_plant_single",
    --     bank = "bulb_plant_single",
    --     build = "bulb_plant_single",
    --     product = "lightbulb",
    --     growinganim = "grow",
    --     idleanim = "idle",
    --     pickinganim = "picking",
    --     killanim = "picked",
    --     picksound = "dontstarve/wilson/pickup_lightbulb"
    -- },
    -- flower_cave_double = {
    --     asset = "bulb_plant_double",
    --     bank = "bulb_plant_double",
    --     build = "bulb_plant_double",
    --     product = "lightbulb",
    --     growinganim = "grow",
    --     idleanim = "idle",
    --     pickinganim = "picking",
    --     killanim = "picked",
    --     picksound = "dontstarve/wilson/pickup_lightbulb",
    --     nameoverride = "flower_cave"
    -- },
    -- flower_cave_triple = {
    --     asset = "bulb_plant_triple",
    --     bank = "bulb_plant_triple",
    --     build = "bulb_plant_triple",
    --     product = "lightbulb",
    --     growinganim = "grow",
    --     idleanim = "idle",
    --     pickinganim = "picking",
    --     killanim = "picked",
    --     picksound = "dontstarve/wilson/pickup_lightbulb",
    --     nameoverride = "flower_cave"
    -- },
    -- 蘑菇
    red_mushroom = {
        asset = "mushrooms",
        bank = "mushrooms",
        build = "mushrooms",
        product = "red_cap",
        growinganim = "red_cap",
        idleanim = "red",
        pickinganim = "picked",
        killanim = "inground",
        picksound = "dontstarve/common/mushroom_down"
    },
    green_mushroom = {
        asset = "mushrooms",
        bank = "mushrooms",
        build = "mushrooms",
        product = "green_cap",
        growinganim = "green_cap",
        idleanim = "green",
        pickinganim = "picked",
        killanim = "inground",
        picksound = "dontstarve/common/mushroom_down"
    },
    blue_mushroom = {
        asset = "mushrooms",
        bank = "mushrooms",
        build = "mushrooms",
        product = "blue_cap",
        growinganim = "blue_cap",
        idleanim = "blue",
        pickinganim = "picked",
        killanim = "inground",
        picksound = "dontstarve/common/mushroom_down"
    },
    -- 无花果
    oceanvine = {
        product = "fig",
        growinganim = "spawn",
        idleanim = "idle_fruit",
        pickinganim = "harvest",
        killanim = "idle_nofruit",
        picksound = "dontstarve/wilson/harvest_berries"
    },
    -- 神秘植物
    wormlight_plant = {
        asset = "worm",
        bank = "worm",
        build = "worm",
        product = "wormlight_lesser",
        growinganim = "grow",
        idleanim = "berry_idle",
        pickinganim = "picking",
        killanim = "picked",
        picksound = "dontstarve/wilson/pickup_reeds"
    },
    -- 石果灌木丛
    rock_avocado_bush = {
        assets = {Asset("ANIM", "anim/rock_avocado.zip"), Asset("ANIM", "anim/rock_avocado_build.zip")},
        bank = "rock_avocado",
        build = "rock_avocado_build",
        product = "rock_avocado_fruit_ripe",
        growinganim = "grow2",
        idleanim = "idle4",
        pickinganim = "idle1_to_dead1",
        killanim = "idle1_to_dead1",
        picksound = "dontstarve/wilson/harvest_berries"
    }
}

local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS
local plants = {
    "asparagus",
    "garlic",
    "pumpkin",
    "corn",
    "onion",
    "potato",
    "dragonfruit",
    "pomegranate",
    "eggplant",
    "tomato",
    "watermelon",
    "pepper",
    "durian",
    "carrot"
}
for _, plant in ipairs(plants) do
    local farmplant = "farm_plant_" .. plant
    if not devil_plant_pickable[farmplant] then
        local plantdata = PLANT_DEFS[plant]
        devil_plant_pickable[farmplant] = {
            assets = {Asset("ANIM", "anim/" .. plantdata.bank .. ".zip"), Asset("ANIM", "anim/" .. plantdata.build .. ".zip")},
            bank = plantdata.bank,
            build = plantdata.build,
            product = plant,
            growinganim = "grow_full",
            idleanim = "crop_full",
            pickinganim = "grow_seed",
            killanim = "grow_rot",
            picksound = "dontstarve/wilson/pickup_plants",
            nameoverride = farmplant
        }
    end
end

local prefabs = {}
local prefabnames = {}
for name, data in pairs(devil_plant_pickable) do
    data.name = name
    data.prefabname = "devil_plant2hm_" .. data.name
    data.product = "devil_fruit2hm_" .. data.product
    table.insert(prefabnames, data.prefabname)
    table.insert(prefabs, MakeDevilPlants(data))
end
TUNING.DEVILPLANTS2HM = prefabnames
return unpack(prefabs)
