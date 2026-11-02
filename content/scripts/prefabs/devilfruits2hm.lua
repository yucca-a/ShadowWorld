local function OnDroppedDelay(inst, owner)
    if owner and owner:IsValid() then
        if owner.components.playercontroller and not owner.components.playercontroller:IsEnabled() then return end
        if owner.components.inventory then
            for k = 1, owner.components.inventory.maxslots do
                local item = owner.components.inventory.itemslots[k]
                if item == nil or not item:HasTag("cursed") then
                    owner.components.inventory:DropItem(item, true, true)
                    owner.components.inventory:GiveItem(inst, k)
                    return
                end
            end
            if owner.components.eater then owner.components.eater:Eat(inst, owner) end
        end
    end
end

local function perishfn(inst)
    inst:DoTaskInTime(0, inst.Remove)
    if not inst.lockowner2hm and inst.components.inventoryitem.owner then inst.lockowner2hm = inst.components.inventoryitem.owner end
    if inst.lockowner2hm and inst.lockowner2hm.components.eater and not inst.lockowner2hm:HasTag("playerghost") and
        inst.lockowner2hm.components.eater:PrefersToEat(inst) then
        local oldeatwholestack = inst.lockowner2hm.components.eater.eatwholestack
        inst.lockowner2hm.components.eater.eatwholestack = true
        inst.lockowner2hm.components.eater:Eat(inst)
        inst.lockowner2hm.components.eater.eatwholestack = oldeatwholestack
    end
end

local function OnDropped(inst) inst:DoTaskInTime(0, OnDroppedDelay, inst.lockowner2hm or inst.components.inventoryitem.owner) end

local function init(inst, owner)
    if not inst.lockowner2hm and inst.components.inventoryitem.owner then inst.lockowner2hm = inst.components.inventoryitem.owner end
end

local function mooncap_oneaten(inst, eater)
    -- 吃恶魔果实: 额外掉30精神上限, 480秒后恢复(每次吃独立key独立计时, 可叠加)
    if eater and eater:IsValid() and eater.components.sanity then
        local sanity = eater.components.sanity
        local max = sanity.max
        if max and max > 0 then
            local idx = (eater._devil_fruit_sanity_idx or 0) + 1
            eater._devil_fruit_sanity_idx = idx
            local key = "devilfruit2hm_" .. idx
            sanity:AddSanityPenalty(key, math.min(30 / max, 1 - 30 / max))
            -- 480秒后只恢复本次扣除的这30点上限,不影响其他次(CD独立)
            eater:DoTaskInTime(480, function(v, k)
                if v:IsValid() and v.components.sanity then
                    v.components.sanity:RemoveSanityPenalty(k)
                end
            end, key)
        end
    end
    eater:DoTaskInTime(0.5, function()
        if eater:IsValid() and not (eater.components.freezable ~= nil and eater.components.freezable:IsFrozen()) and
            not (eater.components.pinnable ~= nil and eater.components.pinnable:IsStuck()) and
            not (eater.components.fossilizable ~= nil and eater.components.fossilizable:IsFossilized()) then
            local sleeptime = TUNING.MOON_MUSHROOM_SLEEPTIME
            local mount = eater.components.rider ~= nil and eater.components.rider:GetMount() or nil
            if mount ~= nil then mount:PushEvent("ridersleep", {sleepiness = 4, sleeptime = sleeptime}) end
            if eater.components.sleeper ~= nil then
                eater.components.sleeper:AddSleepiness(4, sleeptime)
            elseif eater.components.grogginess ~= nil then
                eater.components.grogginess:AddGrogginess(2, sleeptime)
            else
                eater:PushEvent("knockedout")
            end
        end
    end)
end

local function MakeDevilFruits(data)
    local assets = data.assets or {Asset("ANIM", "anim/" .. (data.asset or data.name) .. ".zip"), Asset("INV_IMAGE", data.imagename or data.name)}

    local function fn()
        local inst = CreateEntity()

        inst._moddata = data

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(data.bank or data.asset or data.name)
        inst.AnimState:SetBuild(data.build or data.asset or data.name)
        inst.AnimState:PlayAnimation(data.idleanim or "idle")
        inst.AnimState:SetMultColour(0.75, 0.75, 0.75, 0.75)
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

        -- inst.Light:SetFalloff(0.7)
        -- inst.Light:SetIntensity(.5)
        -- inst.Light:SetRadius(1)
        -- inst.Light:SetColour(237 / 255, 237 / 255, 209 / 255)
        -- inst.Light:Enable(true)

        inst:AddTag("devil_fruit2hm")
        inst:AddTag("pre-preparedfood")
        inst:AddTag("curse2hm")
        -- inst:AddTag("maxstacksize2hm")
        inst:AddTag("cattoy")
        inst:AddTag("nosteal")
        inst:AddTag("cursed")

        MakeInventoryFloatable(inst, "small", 0.07, 0.73)

        inst:SetPrefabNameOverride(data.name)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        MakeHauntableLaunchAndIgnite(inst)

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = data.imagename or data.name
        inst.components.inventoryitem.keepondeath = true
        inst.components.inventoryitem.keepondrown = true
        inst.components.inventoryitem.canonlygoinpocket = true
        inst:ListenForEvent("ondropped", OnDropped)

        inst:AddComponent("edible")
        inst.components.edible.healthvalue = TUNING.HEALING_TINY
        inst.components.edible.hungervalue = 0
        inst.components.edible.sanityvalue = -TUNING.SANITY_HUGE
        inst.components.edible.foodtype = FOODTYPE.GOODIES
        inst.components.edible:SetOnEatenFn(mooncap_oneaten)

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM
        -- inst.components.stackable.maxsize = 9999

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_ONE_DAY)
        inst.components.perishable:StartPerishing()
        -- inst.components.perishable:SetOnPerishFn(perishfn)
        inst:ListenForEvent("perished", perishfn)
        -- inst.components.perishable.onperishreplacement = "spoiled_food"

        inst:AddComponent("curseditem")
        inst.components.curseditem.curse = "MOD_HARDMODE_DEVIL"

        inst.DoCurse2hm = OnDropped
        inst.EndCurse2hm = perishfn

        inst:DoTaskInTime(0, init)
        inst:ListenForEvent("onputininventory", init)

        return inst
    end

    return Prefab(data.prefabname, fn, assets)
end

local devil_fruits_edible = {
    cave_banana = {},
    berries = {},
    berries_juicy = {},
    kelp = {},
    cactus_meat = {},
    cutlichen = {asset = "algae"},
    lightbulb = {asset = "bulb"},
    red_cap = {asset = "mushrooms", idleanim = "red_cap"},
    green_cap = {asset = "mushrooms", idleanim = "green_cap"},
    blue_cap = {asset = "mushrooms", idleanim = "blue_cap"},
    fig = {},
    wormlight_lesser = {asset = "worm_light_lesser"},
    rock_avocado_fruit_ripe = {asset = "rock_avocado_fruit", bank = "rock_avo_fruit_master", build = "rock_avocado_fruit_build", idleanim = "idle_split_open"},
    asparagus = {},
    garlic = {},
    pumpkin = {},
    corn = {},
    onion = {imagename = "quagmire_onion"},
    potato = {},
    dragonfruit = {},
    pomegranate = {},
    eggplant = {},
    tomato = {imagename = "quagmire_tomato"},
    watermelon = {},
    pepper = {},
    durian = {},
    carrot = {}
}

local prefabs = {}
for name, data in pairs(devil_fruits_edible) do
    data.name = name
    data.prefabname = "devil_fruit2hm_" .. data.name
    table.insert(prefabs, MakeDevilFruits(data))
end
return unpack(prefabs)
