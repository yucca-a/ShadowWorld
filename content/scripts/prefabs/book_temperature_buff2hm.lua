-- 控温书buff:阅读控温书(book_temperature)后,范围内玩家锁定体温 + 100%防水,持续一段时间
-- 移植自 modpart_7(另一版本为爽)的同名 buff
local BUFF_TEMPERATURE2HM = 35 -- 锁定的体温
local BUFF_DURATION2HM = 240 -- 持续时间(秒)

local function OnTick(inst, target)
    if target and target:IsValid() and target.components.temperature and target.components.moisture then
        if target.components.temperature:GetCurrent() ~= BUFF_TEMPERATURE2HM then
            target.components.temperature:SetTemperature(BUFF_TEMPERATURE2HM)
        end
    else
        inst.components.debuff:Stop()
    end
end

local function OnDetach(inst, target)
    if target and target:IsValid() and target.components.moisture then
        target.components.moisture.waterproofnessmodifiers:RemoveModifier(inst)
    end
    inst:Remove()
end

local function OnAttached(inst, target)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)

    if target.components.temperature then
        target.components.temperature:SetTemperature(BUFF_TEMPERATURE2HM)
    end
    if target.components.moisture then
        target.components.moisture.waterproofnessmodifiers:SetModifier(inst, 1.0) -- 100%防水
        target.components.moisture:SetMoistureLevel(0)
    end

    inst.task = inst:DoPeriodicTask(1, OnTick, nil, target)

    inst.components.timer:StartTimer("buffover", BUFF_DURATION2HM)

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
end

local function OnExtended(inst, target)
    inst.components.timer:StopTimer("buffover")
    inst.components.timer:StartTimer("buffover", BUFF_DURATION2HM)
end

local function OnTimerDone(inst, data)
    if data.name == "buffover" then
        inst.components.debuff:Stop()
    end
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
    inst.components.debuff:SetDetachedFn(OnDetach)
    inst.components.debuff:SetExtendedFn(OnExtended)
    inst.components.debuff.keepondespawn = true

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    return inst
end

STRINGS.NAMES[string.upper("book_temperature_buff2hm")] = "控温学"

return Prefab("book_temperature_buff2hm", fn)
