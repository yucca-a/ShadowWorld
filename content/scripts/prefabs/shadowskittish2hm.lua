local assets = {Asset("ANIM", "anim/shadow_skittish.zip")}

local function Disappear(inst)
    if inst.deathtask ~= nil then
        inst.deathtask:Cancel()
        inst.deathtask = nil
        inst.AnimState:PlayAnimation("disappear")
        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function PlayerNear(inst)
    if inst.master2hm and inst.master2hm:IsValid() and not inst.master2hm.skittishnear2hm then inst.master2hm.skittishnear2hm = true end
    Disappear(inst)
end

local function transparentonsanityfn(inst, player)
    local minvalue = inst:HasTag("nightmarecreaturefx2hm") and 0.75 or 0.2
    if player == nil then return minvalue end
    local sanity = player.replica.sanity
    if sanity ~= nil then return math.clamp(1 - sanity:GetPercent(), minvalue, 1) end
    return minvalue
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("shadowcreatures")
    inst.AnimState:SetBuild("shadow_skittish")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetMultColour(1, 1, 1, 0)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    if not TheNet:IsDedicated() then
        -- this is purely view related
        inst:AddComponent("transparentonsanity")
        inst.components.transparentonsanity.calc_percent_fn = transparentonsanityfn
        inst.components.transparentonsanity:ForceUpdate()
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("playerprox")
    local self = inst.components.playerprox
    self:SetDist(5, 8)
    self:SetOnPlayerNear(PlayerNear)
    self:Stop()
    self.task = inst:DoPeriodicTask(self.period, self.targetmode, 1, self)

    inst.deathtask = inst:DoTaskInTime(3 + math.random(), Disappear)

    inst.persists = false

    return inst
end

return Prefab("shadowskittish2hm", fn, assets)
