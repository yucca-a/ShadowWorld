local assets = {Asset("ANIM", "anim/reticuleline.zip")}

local FADE_FRAMES = 10

local function OnUpdateTargetFade(inst, r, g, b, a)
    local k
    if inst._fade:value() <= FADE_FRAMES then
        inst._fade:set_local(math.min(inst._fade:value() + 1, FADE_FRAMES))
        k = inst._fade:value() / FADE_FRAMES
    else
        inst._fade:set_local(math.min(inst._fade:value() + 1, FADE_FRAMES * 2 + 1))
        k = (FADE_FRAMES * 2 + 1 - inst._fade:value()) / FADE_FRAMES
    end

    inst.AnimState:OverrideMultColour(r, g, b, a * k)

    if inst._fade:value() == FADE_FRAMES then
        inst._fadetask:Cancel()
        inst._fadetask = nil
    elseif inst._fade:value() > FADE_FRAMES * 2 then
        inst:Remove()
    end
end

local function MakeTarget(name, prefab, fixedorientation, colour)
    local function OnTargetFadeDirty(inst)
        if inst._fadetask == nil then inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateTargetFade, nil, unpack(colour)) end
        OnUpdateTargetFade(inst, unpack(colour))
    end

    local function KillTarget(inst)
        if inst._fade:value() <= FADE_FRAMES then
            inst._fade:set(FADE_FRAMES * 2 + 1 - inst._fade:value())
            if inst._fadetask == nil then inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateTargetFade, nil, unpack(colour)) end
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")

        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")
        inst.AnimState:SetOrientation(fixedorientation and ANIM_ORIENTATION.OnGroundFixed or ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3) -- 1) --was 1 in forge
        inst.AnimState:OverrideMultColour(1, 1, 1, 0)

        inst._fade = net_smallbyte(inst.GUID, name .. "._fade", "fadedirty")
        inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateTargetFade, nil, unpack(colour))

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            inst:ListenForEvent("fadedirty", OnTargetFadeDirty)

            return inst
        end

        inst.persists = false

        inst.KillFX = KillTarget

        return inst
    end

    return Prefab(prefab, fn, assets)
end

return MakeTarget("reticuleline", "reticulelineshadow2hm", false, {.1, .1, .1, 0.5})
