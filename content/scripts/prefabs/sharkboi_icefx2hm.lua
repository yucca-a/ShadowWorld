local ASSETS_FX = {Asset("ANIM", "anim/sharkboi_icefx2hm.zip"),}

local function FX_OnKillTask(inst)
    inst.AnimState:PlayAnimation("pst")
    inst._killtask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, inst.Remove)
end

local function FX_Kill(inst)
    if inst._killtask == nil then
        local time = inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime()
        inst._killtask = inst:DoTaskInTime(time, inst.OnKillTask)
    end
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    inst.AnimState:SetBank("sharkboi_icefx2hm")
    inst.AnimState:SetBuild("sharkboi_icefx2hm")
    inst.AnimState:PlayAnimation("loop")
    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:SetLightOverride(0.7)

    inst.AnimState:SetScale(2.6, 2.6)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst._killtask = nil
    inst._opentask = nil

    inst.Kill = FX_Kill
    inst.OnKillTask = FX_OnKillTask

    inst.SoundEmitter:PlaySound("rifts4/mimic/item_become_poof", "sharkboi_icefx2hm")
    inst.SoundEmitter:SetVolume("sharkboi_icefx2hm", 4)

    inst:DoTaskInTime(1, function() inst.Kill(inst) end)

    return inst
end

return Prefab("sharkboi_icefx2hm", fxfn, ASSETS_FX )
