local function OnDetach(inst, target)
    if inst.data and inst.data.removeWords and target then
        if inst.data.removeSould then
            target.SoundEmitter:PlaySound("dontstarve/pig/grunt")
        end
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
    inst.components.timer:StartTimer("gulumi_bless", inst.data.blessDuration)
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
end

local function OnExtended(inst, target, followsymbol, followoffset, data)
    if not data then
        return
    end
    inst.components.timer:StopTimer("gulumi_bless")
    inst.data = data
    inst.components.timer:StartTimer("gulumi_bless", inst.data.blessDuration)
end

local function OnTimerDone(inst, data)
    if data.name == "gulumi_bless" then
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

STRINGS.NAMES[string.upper("gulumi_bless2hm")] = "咕噜米的祝福"

return Prefab("gulumi_bless2hm", fn)
