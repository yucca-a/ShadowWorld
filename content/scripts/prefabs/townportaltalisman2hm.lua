local assets = {Asset("ANIM", "anim/townportaltalisman.zip")}

local function SplashOceanItem(item)
    if item.components.inventoryitem and not item.components.inventoryitem:IsHeld() then
        local x, y, z = item.Transform:GetWorldPosition()
        if not item:IsOnValidGround() or TheWorld.Map:IsPointNearHole(Vector3(x, 0, z)) then
            SpawnPrefab("splash_ocean").Transform:SetPosition(x, y, z)
            item:Remove()
        end
    end
end

local function SpawnItem(inst, owner, target)
    local item = SpawnPrefab("townportaltalisman")
    item.SoundEmitter:PlaySound("dontstarve/creatures/monkey/itemsplat")
    if target ~= nil and target:IsValid() then
        LaunchAt(item, inst, target)
    else
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if item:IsAsleep() then
            SplashOceanItem(item)
        else
            item:DoTaskInTime(8 * FRAMES, SplashOceanItem)
        end
    end
end

local function SpawnInventoryItem(inst) if inst.enablespawn then SpawnItem(inst, inst.owner2hm or inst, inst.target2hm or inst) end end

local function onthrown(inst, owner, target, attacker)
    inst.owner2hm = owner
    inst.target2hm = target
    inst.attacker2hm = attacker
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeProjectilePhysics(inst)

    inst.AnimState:SetBank("townportaltalisman")
    inst.AnimState:SetBuild("townportaltalisman")
    inst.AnimState:PlayAnimation("active_loop", true)

    inst:AddTag("projectile")

    inst:SetPrefabNameOverride("townportaltalisman")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end
    
    inst.persists = false

    inst:AddComponent("inspectable")

    inst:AddComponent("projectile")
    inst.components.projectile:SetRange(TUNING.WALRUS_ATTACK_DIST * 2)
    inst.components.projectile:SetSpeed(15)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetOnHitFn(inst.Remove)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(onthrown)

    -- inst:DoTaskInTime(10, inst.Remove)
    inst:ListenForEvent("onremove", SpawnInventoryItem)

    return inst
end

return Prefab("townportaltalisman2hm", fn, assets)
