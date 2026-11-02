-------------------------------------------------------------------------
---------------------- Attach and dettach functions ---------------------
-------------------------------------------------------------------------
local function fireabsorption_attach(inst, target)
    if target.components.health ~= nil then target.components.health.externalfiredamagemultipliers:SetModifier(inst, 0.1, "wormwoodfoodbuff2hm") end
    local fx = SpawnPrefab("battlesong_fireresistance_fx")
    if fx then
        fx.Transform:SetNoFaced()
        local xOffset = math.random(-1, 1) * (math.random() / 2)
        local yOffset = 1.2 + math.random() / 5
        local zOffset = math.random(-1, 1) * (math.random() / 2)
        if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
            yOffset = yOffset + 2.3
            xOffset = xOffset + 0.5
            zOffset = zOffset + 0.5
        end
        inst:AddChild(fx)
        fx.Transform:SetPosition(xOffset, yOffset, zOffset)
        fx.Transform:SetScale(0.4, 0.4, 0.4)
    end
end

local function fireabsorption_detach(inst, target)
    if target.components.health ~= nil then target.components.health.externalfiredamagemultipliers:RemoveModifier(inst, "wormwoodfoodbuff2hm") end
end

local function shadowdominance_attach(inst, target)
    target:AddTag("shadowdominance")
    local hasshadow = target:HasTag("shadow")
    if not hasshadow then target:AddTag("shadow") end
    local fx = SpawnPrefab("stalker_shield4")
    fx.entity:SetParent(target.entity)
    if target.components.combat then target.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.01, "HappyPatchMonster") end
    target:DoTaskInTime(0.5, function()
        if not hasshadow then target:RemoveTag("shadow") end
        if target.components.combat then target.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "HappyPatchMonster") end
    end)
end

local function shadowdominance_detach(inst, target) target:RemoveTag("shadowdominance") end

local function heavybody_attach(inst, target)
    target:AddTag("heavybody")
    target:AddTag("foodknockbackimmune")
    local fx = SpawnPrefab("battlesong_durability_fx")
    if fx then
        fx.Transform:SetNoFaced()
        local xOffset = math.random(-1, 1) * (math.random() / 2)
        local yOffset = 1.2 + math.random() / 5
        local zOffset = math.random(-1, 1) * (math.random() / 2)
        if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
            yOffset = yOffset + 2.3
            xOffset = xOffset + 0.5
            zOffset = zOffset + 0.5
        end
        inst:AddChild(fx)
        fx.Transform:SetPosition(xOffset, yOffset, zOffset)
        fx.Transform:SetScale(0.4, 0.4, 0.4)
    end
end

local function heavybody_detach(inst, target)
    target:RemoveTag("heavybody")
    target:RemoveTag("foodknockbackimmune")
end

local function sanitynegaura_attach(inst, target)
    if target.components.sanity ~= nil then target.components.sanity.neg_aura_modifiers:SetModifier(inst, 0.25, "wormwoodfoodbuff2hm") end
    local fx = SpawnPrefab("battlesong_sanityaura_fx")
    if fx then
        fx.Transform:SetNoFaced()
        local xOffset = math.random(-1, 1) * (math.random() / 2)
        local yOffset = 1.2 + math.random() / 5
        local zOffset = math.random(-1, 1) * (math.random() / 2)
        if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
            yOffset = yOffset + 2.3
            xOffset = xOffset + 0.5
            zOffset = zOffset + 0.5
        end
        inst:AddChild(fx)
        fx.Transform:SetPosition(xOffset, yOffset, zOffset)
        fx.Transform:SetScale(0.4, 0.4, 0.4)
    end
end

local function sanitynegaura_detach(inst, target)
    if target.components.sanity ~= nil then target.components.sanity.neg_aura_modifiers:RemoveModifier(inst, "wormwoodfoodbuff2hm") end
end

local function speedup_attach(inst, target)
    if target.components.locomotor ~= nil then target.components.locomotor:SetExternalSpeedMultiplier(inst, "wormwoodfoodbuff2hm", 1.5) end
    -- SpawnPrefab("cane_candy_fx").Transform:SetPosition(target:GetPosition():Get())
end

local function speedup_detach(inst, target)
    if target.components.locomotor ~= nil then target.components.locomotor:SetExternalSpeedMultiplier(inst, "wormwoodfoodbuff2hm", 0) end
end

-------------------------------------------------------------------------
----------------------- Prefab building functions -----------------------
-------------------------------------------------------------------------

local function OnTimerDone(inst, data) if data.name == "buffover" then inst.components.debuff:Stop() end end

local function MakeBuff(name, onattachedfn, onextendedfn, ondetachedfn, duration, priority, prefabs)
    local function OnAttached(inst, target)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0) -- in case of loading
        inst:ListenForEvent("death", function() inst.components.debuff:Stop() end, target)

        -- target:PushEvent(
        --     "foodbuffattached",
        --     {buff = "ANNOUNCE_ATTACH_BUFF_" .. string.upper(name), priority = priority}
        -- )
        if onattachedfn ~= nil then onattachedfn(inst, target) end
    end

    local function OnExtended(inst, target)
        inst.components.timer:StopTimer("buffover")
        inst.components.timer:StartTimer("buffover", duration)

        -- target:PushEvent(
        --     "foodbuffattached",
        --     {buff = "ANNOUNCE_ATTACH_BUFF_" .. string.upper(name), priority = priority}
        -- )
        if onextendedfn ~= nil then onextendedfn(inst, target) end
    end

    local function OnDetached(inst, target)
        if ondetachedfn ~= nil then ondetachedfn(inst, target) end

        -- target:PushEvent(
        --     "foodbuffdetached",
        --     {buff = "ANNOUNCE_DETACH_BUFF_" .. string.upper(name), priority = priority}
        -- )
        inst:Remove()
    end

    local function fn()
        local inst = CreateEntity()

        if not TheWorld.ismastersim then
            -- Not meant for client!
            inst:DoTaskInTime(0, inst.Remove)
            return inst
        end

        inst.entity:AddTransform()

        --[[Non-networked entity]]
        -- inst.entity:SetCanSleep(false)
        inst.entity:Hide()
        inst.persists = false

        inst:AddTag("CLASSIFIED")

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(OnAttached)
        inst.components.debuff:SetDetachedFn(OnDetached)
        inst.components.debuff:SetExtendedFn(OnExtended)
        inst.components.debuff.keepondespawn = true

        inst:AddComponent("timer")
        inst.components.timer:StartTimer("buffover", duration)
        inst:ListenForEvent("timerdone", OnTimerDone)

        return inst
    end

    return Prefab("buff_" .. name, fn, nil, prefabs)
end

STRINGS.NAMES.BUFF_SHADOWDOMINANCE2HM = STRINGS.NAMES.SKELETONHAT
STRINGS.NAMES.BUFF_HEAVYBODY2HM = STRINGS.NAMES.ARMORMARBLE
STRINGS.NAMES.BUFF_FIREABSORPTION2HM = STRINGS.NAMES.BATTLESONG_FIRERESISTANCE
STRINGS.NAMES.BUFF_SANITYNEGAURA2HM = STRINGS.NAMES.BATTLESONG_SANITYAURA
STRINGS.NAMES.BUFF_SHORTSPEEDUP2HM = STRINGS.NAMES.FLOWERHAT

return MakeBuff("shadowdominance2hm", shadowdominance_attach, shadowdominance_attach, shadowdominance_detach, 240, 1),
       MakeBuff("heavybody2hm", heavybody_attach, heavybody_attach, heavybody_detach, 60, 1),
       MakeBuff("fireabsorption2hm", fireabsorption_attach, fireabsorption_attach, fireabsorption_detach, 60, 1),
       MakeBuff("sanitynegaura2hm", sanitynegaura_attach, sanitynegaura_attach, sanitynegaura_detach, 30, 1),
       MakeBuff("shortspeedup2hm", speedup_attach, speedup_attach, speedup_detach, 30, 1)
