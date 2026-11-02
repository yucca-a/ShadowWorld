local function PlaySound(inst, sound) inst.SoundEmitter:PlaySound(sound) end

local function MakeFx(t)
    local assets = {Asset("ANIM", "anim/" .. t.build .. ".zip")}

    local function reset(inst)
        inst.index2hm = inst.index2hm + 1
        if inst.index2hm >= 10 then
            inst:Remove()
            return
        end
        inst.AnimState:PlayAnimation(t.anim)
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        if not TheNet:IsDedicated() then
            if t.sound ~= nil then
                inst.entity:AddSoundEmitter()
                inst:DoTaskInTime(t.sounddelay or 0, PlaySound, t.sound)
            end
        end
        if t.twofaced then
            inst.Transform:SetTwoFaced()
        elseif t.eightfaced then
            inst.Transform:SetEightFaced()
        elseif t.sixfaced then
            inst.Transform:SetSixFaced()
        elseif not t.nofaced then
            inst.Transform:SetFourFaced()
        end

        inst.AnimState:SetBank(t.bank)
        inst.AnimState:SetBuild(t.build)
        inst.AnimState:PlayAnimation(t.anim)

        MakeObstaclePhysics(inst, 1)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst.entity:SetCanSleep(false)
        inst.persists = false

        inst.index2hm = 0
        inst.Reset2hm = reset
        inst:ListenForEvent("animover", inst.Reset2hm)
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("lootdropper")
        local workable = inst:AddComponent("workable")
        workable:SetWorkAction(ACTIONS.MINE)
        workable:SetWorkLeft(1)
        workable:SetOnWorkCallback(inst.Remove)
        return inst
    end

    return Prefab(t.name .. "2hm", fn, assets)
end

local prefs = {}
local fx = {
    {name = "icespike_fx_1", bank = "deerclops_icespike", build = "deerclops_icespike", anim = "spike1", sound = "dontstarve/creatures/deerclops/ice_small"},
    {name = "icespike_fx_2", bank = "deerclops_icespike", build = "deerclops_icespike", anim = "spike2", sound = "dontstarve/creatures/deerclops/ice_small"},
    {name = "icespike_fx_3", bank = "deerclops_icespike", build = "deerclops_icespike", anim = "spike3", sound = "dontstarve/creatures/deerclops/ice_small"},
    {name = "icespike_fx_4", bank = "deerclops_icespike", build = "deerclops_icespike", anim = "spike4", sound = "dontstarve/creatures/deerclops/ice_small"}
}

for k, v in pairs(fx) do table.insert(prefs, MakeFx(v)) end

return unpack(prefs)
