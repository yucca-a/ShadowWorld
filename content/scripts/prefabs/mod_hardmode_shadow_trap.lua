local assets = {Asset("ANIM", "anim/shadow_trap.zip"), Asset("ANIM", "anim/mushroombomb_base.zip")}

local assets_fx = {Asset("ANIM", "anim/shadow_trap_debuff.zip")}

local prefabs = {
    "shadow_despawn",
    "shadow_glob_fx",
    "reticuleaoeshadowtarget_6",
    "ocean_splash_small1",
    "ocean_splash_small2",
    "shadow_pillar_base_fx",
    "shadow_trap_debuff_fx"
}

local function EnableTargetFX(inst, enable)
    if enable then
        if inst.targetfx == nil then
            inst.targetfx = SpawnPrefab("reticuleaoeshadowtarget_6")
            inst.targetfx.entity:SetParent(inst.entity)
        end
    elseif inst.targetfx ~= nil then
        inst.targetfx:KillFX()
        inst.targetfx = nil
    end
end

--------------------------------------------------------------------------

local DETECT_RADIUS = 3
local DETECT_MUST_TAGS = {"locomotor"}
local DETECT_NO_TAGS = {
    "epic",
    "notraptrigger",
    "stalkerminion",
    "stalker",
    "ghost",
    "playerghost",
    "INLIMBO",
    "flight",
    "invisible",
    "notarget",
    "noattack",
    "bird",
    "butterfly",
    "flying"
}
local DETECT_ONE_OF_TAGS = {"monster", "character", "animal", "smallcreature", "player"}

local TARGET_RADIUS = 6
local TARGET_MUST_TAGS = nil
local TARGET_NO_TAGS = {"epic", "stalkerminion", "stalker", "shadowchesspiece", "notraptrigger", "ghost", "INLIMBO", "flight", "invisible", "notarget"}
local TARGET_ONE_OF_TAGS = DETECT_ONE_OF_TAGS

local function CanPanic(target)
    if target.components.hauntable ~= nil and target.components.hauntable.panicable or target.has_nightmare_state then return true end
    if target:HasTag("player") or target:HasTag("companion") or
        (target.components.follower and target.components.follower.leader and target.components.follower.leader:HasTag("player")) then return true end
end

local function EndSpeedMult(target)
    target._shadow_trap_task = nil
    target._shadow_trap_fx:KillFX()
    target._shadow_trap_fx = nil
    if target.components.locomotor ~= nil then target.components.locomotor:RemoveExternalSpeedMultiplier(target, "shadow_trap") end
end

local function TryTrapTarget(inst, targets)
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, TARGET_RADIUS, TARGET_MUST_TAGS, TARGET_NO_TAGS, TARGET_ONE_OF_TAGS)) do
        if not targets[v] and CanPanic(v) and not (v.components.health ~= nil and v.components.health:IsDead()) and v.entity:IsVisible() then
            targets[v] = true
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            local fx = SpawnPrefab("shadow_despawn")
            if fx then
                fx.AnimState:SetMultColour(1, 1, 1, 0.5)
                local platform = v:GetCurrentPlatform()
                if platform ~= nil then
                    fx.entity:SetParent(platform.entity)
                    fx.Transform:SetPosition(platform.entity:WorldToLocalSpace(x1, y1, z1))
                    fx:ListenForEvent("onremove", function()
                        fx.Transform:SetPosition(fx.Transform:GetWorldPosition())
                        fx.entity:SetParent(nil)
                    end, platform)
                else
                    fx.Transform:SetPosition(x1, y1, z1)
                end
            end
            if v:HasTag("player") then
                v:PushEvent("knockback", {
                    knocker = inst,
                    radius = 3,
                    strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and 2.1 or 3,
                    forcelanded = false
                })
            elseif not (v.sg ~= nil and v.sg:HasStateTag("noattack")) then
                v:PushEvent("attacked", {attacker = inst, damage = 0})
            end
            if v:HasTag("player") or v:HasTag("companion") or
                (v.components.follower and v.components.follower.leader and v.components.follower.leader:HasTag("player")) then
                if TheWorld:HasTag("cave") and not inst.mod_hardmode_oceanhorror then
                    inst.mod_hardmode_oceanhorror = true
                    SpawnPrefab("oceanhorror2hm").Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                if v.components.locomotor ~= nil then
                    if v._shadow_trap_task ~= nil then
                        v._shadow_trap_task:Cancel()
                    else
                        v._shadow_trap_fx = SpawnPrefab("shadow_trap_debuff_fx")
                        v._shadow_trap_fx.entity:SetParent(v.entity)
                        v._shadow_trap_fx:OnSetTarget(v)
                    end
                    v._shadow_trap_task = v:DoTaskInTime(TUNING.SHADOW_TRAP_PANIC_TIME, EndSpeedMult)
                    v.components.locomotor:SetExternalSpeedMultiplier(v, "shadow_trap", 0.5)
                end
            else
                if v.has_nightmare_state then
                    v:PushEvent("ms_forcenightmarestate", {duration = TUNING.SHADOW_TRAP_NIGHTMARE_TIME + math.random()})
                end

                if not v.has_nightmare_state and v.components.hauntable ~= nil and v.components.hauntable.panicable then
                    v.components.hauntable:Panic(TUNING.SHADOW_TRAP_PANIC_TIME)
                    if v.components.locomotor ~= nil then
                        if v._shadow_trap_task ~= nil then
                            v._shadow_trap_task:Cancel()
                        else
                            v._shadow_trap_fx = SpawnPrefab("shadow_trap_debuff_fx")
                            v._shadow_trap_fx.entity:SetParent(v.entity)
                            v._shadow_trap_fx:OnSetTarget(v)
                        end
                        v._shadow_trap_task = v:DoTaskInTime(TUNING.SHADOW_TRAP_PANIC_TIME, EndSpeedMult)
                        v.components.locomotor:SetExternalSpeedMultiplier(v, "shadow_trap", TUNING.SHADOW_TRAP_SPEED_MULT)
                    end
                end
            end
        end
    end
end

local function StopTask(inst, task) task:Cancel() end

local function TriggerTrap(inst)
    if not inst.persists then
        return
    elseif not inst.sg:HasStateTag("activated") then
        if inst.task ~= nil then
            inst.task:Cancel()
            inst.task = nil
        end
        inst.sg:GoToState("activate")
        return
    end
    inst.persists = false
    inst:AddTag("NOBLOCK")
    local task = inst:DoPeriodicTask(.2, TryTrapTarget, 0, {})
    inst:DoTaskInTime(.75, StopTask, task)
    inst:DoTaskInTime(1.2 + 10 * FRAMES, inst.Remove) -- wait for target fx fadeout
end

local function DispellTrap(inst, collidewithboat)
    if not inst.persists then
        return
    elseif not inst.sg:HasStateTag("activated") then
        if inst:IsAsleep() then
            inst:Remove()
            return
        elseif inst.task ~= nil then
            inst.task:Cancel()
            inst.task = nil
        end
        inst.sg:GoToState("dispell", collidewithboat)
        inst.persists = false
        inst:AddTag("NOBLOCK")
    end
end

local function Detect(inst, map)
    if inst.sg:HasStateTag("activated") then
        inst.task:Cancel()
        inst.task = nil
    elseif inst.sg:HasStateTag("canactivate") and FindEntity(inst, DETECT_RADIUS, CanPanic, DETECT_MUST_TAGS, DETECT_NO_TAGS, DETECT_ONE_OF_TAGS) ~= nil then
        inst.task:Cancel()
        inst.task = nil
        inst.sg:GoToState("activate")
    elseif inst:HasTag("ignorewalkableplatforms") and map:GetPlatformAtPoint(inst.Transform:GetWorldPosition()) ~= nil then
        DispellTrap(inst, true)
    elseif inst.sg:HasStateTag("candetect") then
        if FindEntity(inst, TARGET_RADIUS, CanPanic, DETECT_MUST_TAGS, DETECT_NO_TAGS, DETECT_ONE_OF_TAGS) ~= nil then
            if not inst.sg:HasStateTag("near") then inst.sg:GoToState("near_idle_pre") end
        elseif inst.sg:HasStateTag("near") then
            inst.sg:GoToState("near_idle_pst")
        end
    end
end

local function OnTimerDone(inst, data) if data ~= nil and data.name == "lifetime" then DispellTrap(inst) end end

local function OnWake(inst)
    inst:DoTaskInTime(0.3, function()
        if inst.task == nil and not inst.sg:HasStateTag("activated") then inst.task = inst:DoPeriodicTask(.1, Detect, math.random() * .1, TheWorld.Map) end
    end)
end

local function OnSleep(inst)
    if inst.task ~= nil then
        inst.task:Cancel()
        inst.task = nil
    end
end

local function OnLoad(inst)
    inst.sg:GoToState("idle", true) -- true to randomize
    inst.base.Transform:SetRotation(math.random() * 360)
    inst.base.AnimState:PlayAnimation("idle", true)
    inst.base.AnimState:SetFrame(math.random(inst.base.AnimState:GetCurrentAnimationNumFrames()) - 1)
end

local function OnShockwave(inst)
    local fx = CreateEntity()

    fx:AddTag("FX")
    --[[Non-networked entity]]
    -- fx.entity:SetCanSleep(false)
    fx.persists = false

    fx.entity:AddTransform()
    fx.entity:AddAnimState()

    fx.AnimState:SetBank("mushroombomb_base")
    fx.AnimState:SetBuild("mushroombomb_base")
    fx.AnimState:PlayAnimation("idle")
    fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    fx.AnimState:SetLayer(LAYER_BACKGROUND)
    fx.AnimState:SetSortOrder(3)
    fx.AnimState:SetFinalOffset(3)
    fx.AnimState:SetScale(1.9, 1.9)
    fx.AnimState:SetMultColour(0, 0, 0, .5)

    fx:ListenForEvent("animover", fx.Remove)

    fx.entity:SetParent(inst.entity)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("shadowtrap2hm")
    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("ignorewalkableplatformdrowning")

    inst.AnimState:SetBank("shadow_trap")
    inst.AnimState:SetBuild("shadow_trap")
    inst.AnimState:PlayAnimation("spawn")
    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.shockwave = net_event(inst.GUID, "shadow_trap.shockwave")

    -- Dedicated server does not need to spawn the local fx
    if not TheNet:IsDedicated() then inst:ListenForEvent("shadow_trap.shockwave", OnShockwave) end

    inst:SetPrefabNameOverride("shadow_trap")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst.base = SpawnPrefab("shadow_pillar_base_fx")
    inst.base.entity:SetParent(inst.entity)
    inst.base.Transform:SetScale(.7, .7, .7)
    inst.base.Transform:SetRotation(math.random() * 360)
    inst.base.AnimState:SetMultColour(1, 1, 1, 0.4)

    inst:AddComponent("timer")
    inst.components.timer:StartTimer("lifetime", TUNING.SHADOW_TRAP_LIFETIME / 3)

    inst:ListenForEvent("timerdone", OnTimerDone)
    inst:ListenForEvent("onsink", DispellTrap)

    inst:SetStateGraph("SGshadow_trap")

    inst.EnableGroundFX = function() end
    inst.EnableTargetFX = EnableTargetFX
    inst.TriggerTrap = TriggerTrap

    inst.OnEntitySleep = OnSleep
    inst.OnEntityWake = OnWake
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("mod_hardmode_shadow_trap", fn, assets, prefabs)
