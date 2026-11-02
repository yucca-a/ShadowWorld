local easing = require("easing")

local ANGLE_VARIANCE = 10

local assets = {Asset("ANIM", "anim/tumbleweed.zip")}

local prefabs = {"splash_sink", "tumbleweedbreakfx"}

local function onplayerprox(inst, player)
    if not inst.last_prox_sfx_time or (GetTime() - inst.last_prox_sfx_time > 5) then
        inst.last_prox_sfx_time = GetTime()
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tumbleweed_choir")
    end
    if inst:IsOnValidGround() and not (player.components.sheltered and player.components.sheltered.sheltered and
        (player.components.sheltered.level2hm or player.components.sheltered.sheltered_level) > 1) then inst.components.burnable:StartWildfire() end
end

local function DoDirectionChange(inst, data)
    if inst.entity:IsAwake() and data and data.angle and data.velocity and inst.components.blowinwind then
        if inst.angle == nil then
            inst.angle = math.clamp(GetRandomWithVariance(data.angle, ANGLE_VARIANCE), 0, 360)
            inst.components.blowinwind:Start(inst.angle, data.velocity)
        else
            inst.angle = math.clamp(GetRandomWithVariance(data.angle, ANGLE_VARIANCE), 0, 360)
            inst.components.blowinwind:ChangeDirection(inst.angle, data.velocity)
        end
    end
end

local function CancelRunningTasks(inst)
    if inst.bouncepretask then
        inst.bouncepretask:Cancel()
        inst.bouncepretask = nil
    end
    if inst.bouncetask then
        inst.bouncetask:Cancel()
        inst.bouncetask = nil
    end
end

local function OnEntityWake(inst)
    inst.AnimState:PlayAnimation("move_loop", true)
    inst.bouncepretask = inst:DoTaskInTime(10 * FRAMES, function(inst)
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tumbleweed_bounce")
        inst.bouncetask = inst:DoPeriodicTask(24 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tumbleweed_bounce") end)
    end)
end

local function onissummer(inst, issummer) if not issummer then inst:Remove() end end

local function onburnt(inst)
    if not inst.persists then return end
    inst.persists = false
    inst:PushEvent("detachchild")
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("tumbleweedbreakfx")
    fx.Transform:SetPosition(x, y, z)
    fx.AnimState:SetMultColour(1, 0, 0, 1)
    local spell = SpawnPrefab("deer_fire_circle")
    spell.Transform:SetPosition(x, y, z)
    spell:DoTaskInTime(4, spell.KillFX)
    local ash = SpawnPrefab("ash")
    ash.Transform:SetPosition(x, y, z)
    inst:DoTaskInTime(0, inst.Remove)
end
local function onignite(inst) inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", 0.05) end
local function onsmoldering(inst) end

local function OnCollide(inst, other)
    if other and other:IsValid() and other:HasTag("player") and not other:HasTag("playerghost") and not (other.sg and other.sg:HasStateTag("sleeping")) and
        not inst.delayremove2hm then
        inst.delayremove2hm = true
        inst.Physics:Stop()
        inst.components.blowinwind:Stop()
        inst.AnimState:PlayAnimation("move_pst")
        inst:DoTaskInTime(4 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tumbleweed_bounce") end)
        inst:DoTaskInTime(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tumbleweed_bounce") end)
        inst.AnimState:PushAnimation("idle", true)
        if other.components.burnable then other.components.burnable:StartWildfire() end
        if inst.components.burnable.burning then
            onburnt(inst)
        elseif inst.components.burnable.smoldering then
            inst.components.burnable:StopSmoldering()
            inst.components.burnable:Ignite()
        else
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", 0.35)
            inst.components.propagator.flashpoint = 2
            inst.components.burnable:StartWildfire()
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.Transform:SetFourFaced()
    inst.DynamicShadow:SetSize(1.7, .8)

    inst.AnimState:SetBuild("tumbleweed")
    inst.AnimState:SetBank("tumbleweed")
    inst.AnimState:PlayAnimation("move_loop", true)

    local phys = inst.entity:AddPhysics()
    phys:SetMass(1)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.CHARACTERS)
    phys:ClearCollisionMask()
    phys:CollidesWith(COLLISION.GROUND)
    phys:CollidesWith(COLLISION.OBSTACLES)
    phys:CollidesWith(COLLISION.SMALLOBSTACLES)
    phys:CollidesWith(COLLISION.CHARACTERS)
    phys:CollidesWith(COLLISION.GIANTS)
    phys:SetCapsule(0.5, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst.Physics:SetCollisionCallback(OnCollide)

    inst:AddComponent("inspectable")

    inst:AddComponent("locomotor")
    inst.components.locomotor:SetTriggersCreep(false)

    inst:AddComponent("heater")
    inst.components.heater.heat = 250

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_SMALL

    inst:AddComponent("blowinwind")
    inst.components.blowinwind.soundPath = "dontstarve_DLC001/common/tumbleweed_roll"
    inst.components.blowinwind.soundName = "tumbleweed_roll"
    inst.components.blowinwind.soundParameter = "speed"
    inst.angle = TheWorld.components.worldwind and TheWorld.components.worldwind:GetWindAngle()
    inst:ListenForEvent("windchange", function(world, data) DoDirectionChange(inst, data) end, TheWorld)
    if inst.angle ~= nil then
        inst.angle = math.clamp(GetRandomWithVariance(inst.angle, ANGLE_VARIANCE), 0, 360)
        inst.components.blowinwind:Start(inst.angle)
    else
        inst.components.blowinwind:StartSoundLoop()
    end

    inst.AnimState:SetMultColour(1, 0, 0, 1)

    inst:AddComponent("playerprox2hm")
    inst.components.playerprox2hm:SetOnPlayerNear(onplayerprox)
    inst.components.playerprox2hm:SetDist(5, 10)

    inst:WatchWorldState("issummer", onissummer)

    inst:DoTaskInTime(30, inst.Remove)

    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = CancelRunningTasks

    MakeSmallPropagator(inst)
    inst.components.propagator.flashpoint = 100

    inst:AddComponent("burnable")
    inst.components.burnable:SetFXLevel(2)
    inst.components.burnable:AddBurnFX("character_fire", Vector3(.1, 0, .1), "swap_fire")
    inst.components.burnable.canlight = true
    inst.components.burnable:SetOnSmolderingFn(onsmoldering)
    inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnBurntFn(onburnt)
    inst.components.burnable:SetBurnTime(1)
    inst.components.burnable:SetOnExtinguishFn(onburnt)
    inst.components.burnable:SetOnStopSmolderingFn(onburnt)

    return inst
end

return Prefab("mod_hardmode_tumbleweed", fn, assets, prefabs)
