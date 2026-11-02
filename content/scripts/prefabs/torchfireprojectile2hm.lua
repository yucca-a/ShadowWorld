local assets = {Asset("ANIM", "anim/torch.zip"), Asset("ANIM", "anim/swap_torch.zip"), Asset("SOUND", "sound/common.fsb")}

local prefabs = {"torchfire_shadow"}

-- local function OnCollide(inst, other)
--     if other and other:IsValid() then
--         if other.components.workable and inst.attacker2hm then
--             local attacker = inst.attacker2hm
--             inst.components.projectile.target = other
--             other.components.workable:Destroy(attacker)
--             if inst.fx then
--                 inst.fx:Remove()
--                 inst.fx = nil
--             end
--             SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
--             inst.components.projectile:Miss(other)
--         elseif other.components.health and not other.components.health:IsDead() and not other:HasTag("lavae") and not other:HasTag("dragonfly") then
--             inst.components.projectile.target = other
--             if inst.fx then
--                 inst.fx:Remove()
--                 inst.fx = nil
--             end
--             SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
--             inst.components.projectile:Hit(other)
--         end
--     end
-- end

-- local function HasCollide(inst)
--     local phys = inst.Physics or inst.entity:AddPhysics()
--     phys:SetMass(1)
--     phys:SetFriction(0)
--     phys:SetDamping(5)
--     phys:SetCollisionGroup(COLLISION.CHARACTERS)
--     phys:ClearCollisionMask()
--     phys:CollidesWith((TheWorld.has_ocean and COLLISION.GROUND) or COLLISION.WORLD)
--     -- phys:CollidesWith(COLLISION.GROUND)
--     phys:CollidesWith(COLLISION.OBSTACLES)
--     phys:CollidesWith(COLLISION.SMALLOBSTACLES)
--     phys:CollidesWith(COLLISION.CHARACTERS)
--     phys:CollidesWith(COLLISION.GIANTS)
--     phys:SetCapsule(0.5, 1)
--     inst.Physics:SetCollisionCallback(OnCollide)
-- end

local function onthrown(inst, owner, target, attacker)
    inst.attacker2hm = attacker
    -- inst:DoTaskInTime(0.1, HasCollide)
end

local function onhit(inst, owner, other)
    if other ~= nil and other:IsValid() and other.components.burnable ~= nil and other.components.fueled == nil then
        other.components.burnable:Ignite(true, owner or inst.attacker2hm or inst)
    end
    if inst.fx then
        inst.fx:Remove()
        inst.fx = nil
    end
    SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

local function onmiss(inst)
    if inst.fx then
        inst.fx:Remove()
        inst.fx = nil
    end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeProjectilePhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("torch")
    inst.AnimState:SetBuild("swap_torch")
    inst.AnimState:PlayAnimation("land")
    inst.AnimState:SetMultColour(0, 0, 0, 0)

    -- projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst.persists = false

    inst:AddComponent("projectile")
    inst.components.projectile:SetRange(TUNING.WALRUS_ATTACK_DIST * 2)
    inst.components.projectile:SetSpeed(20)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetOnHitFn(onhit)
    inst.components.projectile:SetOnMissFn(onmiss)
    inst.components.projectile:SetOnThrownFn(onthrown)

    inst:AddComponent("burnable")
    inst.components.burnable:SetFXLevel(2)
    inst.components.burnable.canlight = false
    inst.components.burnable:SetBurnTime(8)
    inst.components.burnable:AddBurnFX("character_fire", Vector3(0, 0, 0), "swap_torch")
    inst.components.burnable:Ignite(true, inst)

    local fx = SpawnPrefab("torchfire_shadow")
    if fx then
        fx.entity:SetParent(inst.entity)
        fx.entity:AddFollower()
        fx.Follower:FollowSymbol(inst.GUID, "swap_torch", fx.fx_offset_x or 0, fx.fx_offset, 0)
        fx:AttachLightTo(inst)
        if fx.AssignSkinData ~= nil then fx:AssignSkinData(inst) end
        inst.fx = fx
    end

    inst:DoTaskInTime(10, inst.Remove)

    return inst
end

return Prefab("torchfireprojectile2hm", fn, assets, prefabs)
