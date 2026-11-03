-- A visual flame with target-only fire damage. No burnable, heater, propagator
-- or "fire" tag: it cannot heat/ignite buildings, loot, plants or other creatures.
local assets = {Asset("ANIM", "anim/fire.zip")}
local DURATION, PERIOD, DAMAGE_PER_SECOND = 8, 0.5, 5

local function ClearTarget(inst)
    if inst.target ~= nil and inst.target.eyeturretsafefire2hm == inst then
        inst.target.eyeturretsafefire2hm = nil
    end
end

local function Refresh(inst, attacker)
    inst.attacker = attacker
    if inst.expiretask ~= nil then inst.expiretask:Cancel() end
    inst.expiretask = inst:DoTaskInTime(DURATION, inst.Remove)
end

local function OnTick(inst)
    local target = inst.target
    if target == nil or not target:IsValid() or target:IsInLimbo() or target.components.health == nil or
        target.components.health:IsDead() or target:HasOneOfTags({"fireimmune", "player", "structure", "wall"}) then
        inst:Remove()
        return
    end
    local attacker = inst.attacker ~= nil and inst.attacker:IsValid() and inst.attacker or nil
    target.components.health:DoFireDamage(DAMAGE_PER_SECOND * PERIOD, attacker, true)
end

local function Attach(inst, target, attacker)
    inst.target = target
    target.eyeturretsafefire2hm = inst
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)
    local scale = math.max(0.5, math.min(2, target:GetPhysicsRadius(0.5)))
    inst.Transform:SetScale(scale, scale, scale)
    inst:ListenForEvent("death", inst.Remove, target)
    inst:ListenForEvent("onremove", inst.Remove, target)
    inst:ListenForEvent("onextinguish", inst.Remove, target)
    Refresh(inst, attacker)
    inst:DoPeriodicTask(PERIOD, OnTick)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetBank("fire")
    inst.AnimState:SetBuild("fire")
    inst.AnimState:PlayAnimation("level2", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetFinalOffset(3)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.Attach = Attach
    inst.Refresh = Refresh
    inst:ListenForEvent("onremove", ClearTarget)
    -- Also clean up if another caller spawns the effect without attaching it.
    inst.expiretask = inst:DoTaskInTime(DURATION, inst.Remove)
    return inst
end

return Prefab("eyeturret_safefire2hm", fn, assets)
