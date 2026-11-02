local SPEED_MAX2HM = 25
local SPEED_TURN2HM = 30
local TURN_PERIOD2HM = 15
local ACC_PERIOD2HM = 3
local HIT_RANGE2HM = 0.9
local BURN_TIME2HM = 10
local SEE_RANGE2HM = 200
local LIFE_TIME2HM = 6

local Setup2hm

local assets = {Asset("ANIM", "anim/torch.zip"), Asset("ANIM", "anim/swap_torch.zip")}

local prefabs = {"character_fire", "torchfire_shadow"}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("torch")
    inst.AnimState:SetBuild("swap_torch")
    inst.AnimState:PlayAnimation("land")
    inst.AnimState:SetMultColour(0, 0, 0, 0)

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst:AddTag("ringfire2hm")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst.persists = false

    inst:AddComponent("burnable")
    inst.components.burnable:SetFXLevel(2)
    inst.components.burnable.canlight = false
    inst.components.burnable:SetBurnTime(BURN_TIME2HM)
    inst.components.burnable:AddBurnFX("character_fire", Vector3(0, 0, 0), "swap_torch")
    inst.components.burnable:Ignite(true, inst)

    local fx = SpawnPrefab("torchfire_shadow")
    if fx ~= nil then
        fx.entity:SetParent(inst.entity)
        fx.entity:AddFollower()
        fx.Follower:FollowSymbol(inst.GUID, "swap_torch", fx.fx_offset_x or 0, fx.fx_offset, 0)
        fx:AttachLightTo(inst)
        if fx.AssignSkinData ~= nil then fx:AssignSkinData(inst) end
        inst.fx = fx
    end

    inst.Setup2hm = Setup2hm

    return inst
end

local function FindNearestPlayer2hm(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, SEE_RANGE2HM, {"player"})
    local best, bestd = nil, nil
    for i = 1, #ents do
        local v = ents[i]
        if v:IsValid() and not v:HasTag("playerghost") and v.components.health ~= nil and not v.components.health:IsDead() then
            local d = inst:GetDistanceSqToInst(v)
            if bestd == nil or d < bestd then
                best, bestd = v, d
            end
        end
    end
    return best
end

local function FindTarget2hm(inst)
    local t = FindNearestPlayer2hm(inst)
    if t == nil and inst.owner2hm ~= nil and inst.owner2hm:IsValid() then
        t = FindNearestPlayer2hm(inst.owner2hm)
    end
    return t
end

local function HitPlayer2hm(inst, v)
    local owner = inst.owner2hm
    if v.components.combat ~= nil then
        v.components.combat:GetAttacked_Internal(owner, inst.damage2hm or 0, inst)
    end
    if v.components.burnable ~= nil then
        v.components.burnable:SetBurnTime(BURN_TIME2HM)
        v.components.burnable:Ignite(true, owner)
    end
    inst:Remove()
end

Setup2hm = function(inst, owner, angle, damage)
    inst.owner2hm = owner
    inst.damage2hm = damage
    inst.speed2hm = 0
    inst.angle2hm = angle
    inst.target2hm = FindTarget2hm(inst)

    local elapsed = 0
    local accframes = 0
    local turnframes = 0

    inst:DoPeriodicTask(FRAMES, function(i)
        if not i:IsValid() then return end

        elapsed = elapsed + FRAMES

        if elapsed >= LIFE_TIME2HM then
            i:Remove()
            return
        end

        local add = elapsed < 1 and 0.5 or elapsed < 2 and 1 or 2
        i.speed2hm = math.min(SPEED_MAX2HM, i.speed2hm + add / ACC_PERIOD2HM)

        local period = elapsed < 1 and 3 or elapsed < 2 and 6 or 10
        local maxdeg = elapsed < 1 and 18 or elapsed < 2 and 9 or 3
        turnframes = turnframes + 1
        if turnframes >= period then
            turnframes = 0
            local target = FindTarget2hm(i)
            if target ~= nil then
                local x, y, z = i.Transform:GetWorldPosition()
                local tx, ty, tz = target.Transform:GetWorldPosition()
                local want = math.atan2(tz - z, tx - x)
                local diff = (want - i.angle2hm + math.pi) % (math.pi * 2) - math.pi
                local maxstep = math.rad(maxdeg)
                if diff > maxstep then
                    diff = maxstep
                elseif diff < -maxstep then
                    diff = -maxstep
                end
                i.angle2hm = i.angle2hm + diff
            end
        end

        local x, y, z = i.Transform:GetWorldPosition()
        local nx = x + i.speed2hm * math.cos(i.angle2hm) * FRAMES
        local nz = z + i.speed2hm * math.sin(i.angle2hm) * FRAMES
        i.Transform:SetPosition(nx, 0, nz)

        local ents = TheSim:FindEntities(nx, 0, nz, HIT_RANGE2HM, {"player"})
        for k = 1, #ents do
            local v = ents[k]
            if v:IsValid() and not v:HasTag("playerghost") and v.components.health ~= nil and not v.components.health:IsDead() then
                HitPlayer2hm(i, v)
                return
            end
        end
    end)
end

return Prefab("dragonfly_ringfire2hm", fn, assets, prefabs)
