-- 四季鱼汤buff:16分钟 60%移速+免疫潮湿+温度保护
local SPEED2HM = 1.6 -- 60%移速（设计起来是刚刚好打天体不用切手杖了）
local PROTECT2HM = 1920 -- 保暖隔热值
local HOT_LIMIT2HM = 40 -- 体温高于40给隔热
local COLD_LIMIT2HM = 30 -- 体温低于30给保暖
local WARM_ACTIVE2HM = 20 -- 体温低于20开始主动升温
local COOL_ACTIVE2HM = 50 -- 体温高于50开始主动降温
local WARM_GOAL2HM = 30 -- 主动升温目标
local COOL_GOAL2HM = 45 -- 主动降温目标
local DURATION2HM = 960 -- 16分钟

local function ApplyEffect2hm(inst, target)
    if target.components.locomotor ~= nil then
        target.components.locomotor:SetExternalSpeedMultiplier(inst, "tropicalfishbuff2hm", SPEED2HM)
    end
    if target.components.moistureimmunity == nil then
        target:AddComponent("moistureimmunity")
    end
    target.components.moistureimmunity:AddSource(inst)
end

-- 根据玩家体温动态保护
local function RefreshInsulation2hm(inst, target)
    if target == nil or not target:IsValid() or target.components.temperature == nil then
        return
    end
    local temp = target.components.temperature
    temp:RemoveInsulationModifier(SEASONS.SUMMER, inst, "tropicalfishbuff2hm")
    temp:RemoveInsulationModifier(SEASONS.WINTER, inst, "tropicalfishbuff2hm")
    local cur = temp:GetCurrent()
    if cur > HOT_LIMIT2HM then
        temp:SetInsulationModifier(SEASONS.SUMMER, inst, PROTECT2HM, "tropicalfishbuff2hm")
    elseif cur < COLD_LIMIT2HM then
        temp:SetInsulationModifier(SEASONS.WINTER, inst, PROTECT2HM, "tropicalfishbuff2hm")
    end
end

-- 主动调温
local function AdjustTemperature2hm(inst, target)
    if target == nil or not target:IsValid() or target.components.temperature == nil then
        return
    end
    local temp = target.components.temperature
    local cur = temp:GetCurrent()
    if cur < WARM_ACTIVE2HM then
        temp:SetTemperature(math.clamp(cur + (WARM_GOAL2HM - cur) / 3, 0, 60))
    elseif cur > COOL_ACTIVE2HM then
        temp:SetTemperature(math.clamp(cur - (cur - COOL_GOAL2HM) / 3, 0, 60))
    end
end

local function RemoveEffect2hm(inst, target)
    if target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(inst, "tropicalfishbuff2hm")
    end
    if target.components.moistureimmunity ~= nil then
        target.components.moistureimmunity:RemoveSource(inst)
    end
    if target.components.temperature ~= nil then
        target.components.temperature:RemoveInsulationModifier(SEASONS.SUMMER, inst, "tropicalfishbuff2hm")
        target.components.temperature:RemoveInsulationModifier(SEASONS.WINTER, inst, "tropicalfishbuff2hm")
    end
    if inst._season_task2hm ~= nil then
        inst._season_task2hm:Cancel()
        inst._season_task2hm = nil
    end
    -- 身上的微光
    if inst._fishlight2hm ~= nil then
        if inst._fishlight2hm:IsValid() then inst._fishlight2hm:Remove() end
        inst._fishlight2hm = nil
    end
end

local function OnTimerDone(inst, data)
    if data.name == "tropicalover2hm" then
        inst.components.debuff:Stop()
    end
end

local function OnAttached(inst, target, followsymbol, followoffset, data)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)
    inst.data = data
    ApplyEffect2hm(inst, target)
    -- 发光:身上挂6距离微光
    if not (inst._fishlight2hm and inst._fishlight2hm:IsValid()) then
        inst._fishlight2hm = SpawnPrefab("deathcurselight2hm")
    end
    if inst._fishlight2hm ~= nil then
        inst._fishlight2hm.entity:SetParent(target.entity)
        inst._fishlight2hm.Light:SetFalloff(0.5)
        inst._fishlight2hm.Light:SetIntensity(0.8)
        inst._fishlight2hm.Light:SetRadius(6)
        inst._fishlight2hm.Light:SetColour(180 / 255, 195 / 255, 225 / 255)
        inst._fishlight2hm.Light:Enable(true)
    end
    RefreshInsulation2hm(inst, target)
    -- buff 持续期间每1秒刷新
    inst._season_task2hm = inst:DoPeriodicTask(1, function()
        if target == nil or not target:IsValid() then
            if inst.components.debuff ~= nil then
                inst.components.debuff:Stop()
            end
            return
        end
        RefreshInsulation2hm(inst, target)
        AdjustTemperature2hm(inst, target)
    end)
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
end

local function OnExtended(inst, target, followsymbol, followoffset, data)
    inst.data = data
    inst.components.timer:StopTimer("tropicalover2hm")
    inst.components.timer:StartTimer("tropicalover2hm", DURATION2HM)
end

local function OnDetached(inst, target)
    RemoveEffect2hm(inst, target)
    -- buff 到期时的台词
    if inst.data ~= nil and inst.data.removeWords ~= nil and target ~= nil and target:IsValid() and target.components.talker ~= nil then
        target.components.talker:Say(inst.data.removeWords)
    end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    inst.entity:Hide()
    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetached)
    inst.components.debuff:SetExtendedFn(OnExtended)
    inst.components.debuff.keepondespawn = true

    inst:AddComponent("timer")
    inst.components.timer:StartTimer("tropicalover2hm", DURATION2HM)
    inst:ListenForEvent("timerdone", OnTimerDone)

    return inst
end

return Prefab("tropicalfishbuff2hm", fn)
