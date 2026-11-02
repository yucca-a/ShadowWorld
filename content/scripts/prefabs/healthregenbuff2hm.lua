local function CheckEnd(inst)
    if not inst.task1 and not inst.task2 then
        inst.components.debuff:Stop()
    end
end

local function OnTick1(inst, target)
    if target.components.health then
        local nowTime = GetTime()
        local tickTime = math.min(nowTime - inst.lastTickTime1, inst.data.healthTime)
        target.components.health:DoDelta(tickTime / inst.data.healthTimer * inst.data.healthTick)
        inst.data.healthTime = inst.data.healthTime - tickTime
        -- print("回血", inst.lastTickTime1, nowTime, tickTime, tickTime / inst.data.healthTimer * inst.data.healthTick)
        inst.lastTickTime1 = nowTime
        if inst.data.healthTime <= 0 then
            inst.task1:Cancel()
            inst.task1 = nil
            CheckEnd(inst)
        end
    else
        inst.task1:Cancel()
        inst.task1 = nil
        CheckEnd(inst)
    end
end

local function OnTick2(inst, target)
    if target.components.sanity then
        local nowTime = GetTime()
        local tickTime = math.min(nowTime - inst.lastTickTime2, inst.data.sanityTime)
        target.components.sanity:DoDelta(tickTime / inst.data.sanityTimer * inst.data.sanityTick)
        inst.data.sanityTime = inst.data.sanityTime - tickTime
        -- print("回san", inst.lastTickTime2, nowTime, tickTime, tickTime / inst.data.sanityTimer * inst.data.sanityTick)
        inst.lastTickTime2 = nowTime
        if inst.data.sanityTime <= 0 then
            inst.task2:Cancel()
            inst.task2 = nil
            CheckEnd(inst)
        end
    else
        inst.task2:Cancel()
        inst.task2 = nil
        CheckEnd(inst)
    end
end

local function DoTask(inst, target)
    inst.lastTickTime1 = GetTime()
    inst.task1 = inst:DoPeriodicTask(inst.data.healthTimer, OnTick1, nil, target)
    inst.lastTickTime2 = GetTime()
    inst.task2 = inst:DoPeriodicTask(inst.data.sanityTimer, OnTick2, nil, target)
    inst.components.timer:StartTimer("regenover", math.max(inst.data.healthTime, inst.data.sanityTime))
end

local function OnDetach(inst, target)
    if inst.task1 then
        OnTick1(inst, target)
    end
    if inst.task2 then
        OnTick2(inst, target)
    end
    -- print("OnDetach", inst.data and inst.data.removeWords)
    if inst.data and inst.data.removeWords and target then
        if target.components.talker then
            target.components.talker:Say(inst.data.removeWords)
        end
    end
    inst:Remove()
end

local function OnAttached(inst, target, followsymbol, followoffset, data)
    if not data then
        inst:DoTaskInTime(0, function()
            inst.components.debuff:Stop()
        end)
        return
    end
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    inst.data = data
    DoTask(inst, target)
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
    if data.removeOnHit then
        inst:ListenForEvent("attacked", function()
            inst.components.debuff:Stop()
        end, target)
    end
end

local function OnExtended(inst, target, followsymbol, followoffset, data)
    if not data then
        return
    end
    if inst.task1 then
        inst.task1:Cancel()
    end
    if inst.task2 then
        inst.task2:Cancel()
    end
    inst.components.timer:StopTimer("regenover")
    inst.data = data
    DoTask(inst, target)
end

local function OnTimerDone(inst, data)
    if data.name == "regenover" then
        inst.components.debuff:Stop()
    end
end

local function fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)

        return inst
    end

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    --inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetach)
    inst.components.debuff:SetExtendedFn(OnExtended)
    inst.components.debuff.keepondespawn = false

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    return inst
end

STRINGS.NAMES[string.upper("healthregenbuff2hm")] = "糖豆之力"

return Prefab("healthregenbuff2hm", fn)
