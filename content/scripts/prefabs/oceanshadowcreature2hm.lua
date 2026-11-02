local assets = {Asset("ANIM", "anim/shadow_oceanhorror.zip")}

local prefabs = {"nightmarefuel", "oceanhorror_ripples"}

local sounds = {
    attack = "dontstarve/sanity/creature1/attack",
    attack_grunt = "dontstarve/sanity/creature1/attack_grunt",
    death = "dontstarve/sanity/creature1/die",
    idle = "dontstarve/sanity/creature1/idle",
    taunt = "dontstarve/sanity/creature1/taunt",
    appear = "dontstarve/sanity/creature1/appear",
    disappear = "dontstarve/sanity/creature1/dissappear"
}

local brain = require("brains/nightmarecreaturebrain2hm")

local function retargetfn(inst)
    local maxrangesq = TUNING.SHADOWCREATURE_TARGET_DIST * TUNING.SHADOWCREATURE_TARGET_DIST
    local rangesq, rangesq1, rangesq2 = maxrangesq, math.huge, math.huge
    local target1, target2 = nil, nil
    for i, v in ipairs(AllPlayers) do
        if --[[v.components.sanity:IsCrazy() and]] not v:HasTag("playerghost") then
            local distsq = v:GetDistanceSqToInst(inst)
            if distsq < rangesq then
                if inst.components.shadowsubmissive:TargetHasDominance(v) then
                    if distsq < rangesq1 and inst.components.combat:CanTarget(v) then
                        target1 = v
                        rangesq1 = distsq
                        rangesq = math.max(rangesq1, rangesq2)
                    end
                elseif distsq < rangesq2 and inst.components.combat:CanTarget(v) then
                    target2 = v
                    rangesq2 = distsq
                    rangesq = math.max(rangesq1, rangesq2)
                end
            end
        end
    end

    if target1 ~= nil and rangesq1 <= math.max(rangesq2, maxrangesq * .25) then
        -- Targets with shadow dominance have higher priority within half targeting range
        -- Force target switch if current target does not have shadow dominance
        return target1, not inst.components.shadowsubmissive:TargetHasDominance(inst.components.combat.target)
    end
    return target2
end

local function CanShareTargetWith(dude) return dude:HasTag("nightmarecreature") and not dude.components.health:IsDead() end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        inst.components.combat:SetTarget(data.attacker)
        inst.components.combat:ShareTarget(data.attacker, 30, CanShareTargetWith, 1)
    end
end

local function OnDeath(inst, data)
    if data ~= nil and data.afflicter ~= nil and data.afflicter:HasTag("crazy") and inst.components.lootdropper.loot == nil then
        -- max one nightmarefuel if killed by a crazy NPC (e.g. Bernie)
        inst.components.lootdropper:SetLoot({"nightmarefuel"})
        inst.components.lootdropper:SetChanceLootTable()
    end
end

local function ScheduleCleanup(inst)
    inst:DoTaskInTime(math.random() * TUNING.NIGHTMARE_SEGS.DAWN * TUNING.SEG_TIME, function()
        if inst.components.lootdropper then
            inst.components.lootdropper:SetLoot()
            inst.components.lootdropper:SetChanceLootTable()
        end
        if inst.components.health then inst.components.health:Kill() end
    end)
end

local function OnNightmareDawn(inst, dawn) if dawn then ScheduleCleanup(inst) end end

local function CLIENT_ShadowSubmissive_HostileToPlayerTest(inst, player)
    if player:HasTag("shadowdominance") then return false end
    local combat = inst.replica.combat
    if combat ~= nil and combat:GetTarget() == player then return true end
    local sanity = player.replica.sanity
    if sanity ~= nil and sanity:IsCrazy() then return true end
    return false
end

local function EquipWeapons(inst)
    if inst.components.inventory ~= nil and not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
        local thrower = CreateEntity()
        thrower.name = "Thrower"
        thrower.projectilespeed2hm = 20
        thrower.projectilecolor2hm = {0, 0, 0, 0.5}
        thrower.projectilehoming2hm = false
        thrower.projectilemissremove2hm = true
        thrower.projectileneedstartpos2hm = true
        thrower.entity:AddTransform()
        thrower:AddComponent("weapon")
        thrower.components.weapon:SetDamage(TUNING.OCEANHORROR.DAMAGE * 2 / 3)
        thrower.components.weapon:SetRange(TUNING.WALRUS_ATTACK_DIST, TUNING.WALRUS_ATTACK_DIST + 4)
        thrower.components.weapon:SetProjectile("blowdart_walrus")
        thrower:AddComponent("inventoryitem")
        thrower.persists = false
        thrower.components.inventoryitem:SetOnDroppedFn(thrower.Remove)
        thrower:AddComponent("equippable")
        thrower:AddTag("nosteal")
        inst.components.inventory:GiveItem(thrower)
        inst.weaponitems.thrower = thrower

        local hitter = CreateEntity()
        hitter.name = "Hitter"
        hitter.entity:AddTransform()
        hitter:AddComponent("weapon")
        hitter.components.weapon:SetDamage(TUNING.OCEANHORROR.DAMAGE)
        hitter.components.weapon:SetRange(0)
        hitter:AddComponent("inventoryitem")
        hitter.persists = false
        hitter.components.inventoryitem:SetOnDroppedFn(hitter.Remove)
        hitter:AddComponent("equippable")
        hitter:AddTag("nosteal")
        inst.components.inventory:GiveItem(hitter)
        inst.weaponitems.hitter = hitter
    end
end

local function onsave(inst, data) data.simple2hm = inst.simple2hm end

local function onload(inst, data) inst.simple2hm = data and data.simple2hm end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, 1.5)
    RemovePhysicsColliders(inst)
    inst.Physics:SetCollisionGroup(COLLISION.SANITY)
    inst.Physics:CollidesWith(COLLISION.SANITY)

    inst.Transform:SetFourFaced()

    inst:AddTag("nightmarecreature")
    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("shadow")
    inst:AddTag("notraptrigger")
    inst:AddTag("ignorewalkableplatforms")

    -- shadowsubmissive (from shadowsubmissive component) added to pristine state for optimization
    inst:AddTag("shadowsubmissive")

    inst.AnimState:SetBank("oceanhorror")
    inst.AnimState:SetBuild("shadow_oceanhorror")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetMultColour(1, 1, 1, .5)

    inst.HostileToPlayerTest = CLIENT_ShadowSubmissive_HostileToPlayerTest

    inst:SetPrefabNameOverride("oceanhorror")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst._ripples = SpawnPrefab("oceanhorror_ripples")
    inst._ripples.entity:SetParent(inst.entity)

    inst:AddComponent("locomotor")
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = {allowocean = true, ignorecreep = true}
    inst.components.locomotor.walkspeed = TUNING.OCEANHORROR.SPEED
    inst.sounds = sounds
    inst:SetStateGraph("SGshadowcreature")

    inst:SetBrain(brain)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.OCEANHORROR.HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.OCEANHORROR.DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.OCEANHORROR.ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(3, retargetfn)
    -- inst.components.combat:SetRange(TUNING.OCEANHORROR.ATTACK_RANGE)
    inst.components.combat:SetRange(TUNING.OCEANHORROR.ATTACK_RANGE)
    inst.multithrow2hm = 2
    inst.multithrow2hmtarget = true
    inst.multithrow2hmdelay = 0.2

    inst:AddComponent("shadowsubmissive")

    inst:AddComponent("inventory")
    inst.weaponitems = {}
    EquipWeapons(inst)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("nightmare_creature")

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("death", OnDeath)

    inst:WatchWorldState("isnightmaredawn", OnNightmareDawn)

    inst:AddComponent("knownlocations")

    if TUNING.enableoceanhorror2hm ~= true then inst:DoTaskInTime(0, inst.Remove) end

    inst:AddComponent("timer")

    inst.cantaunt2hm = true

    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("oceanhorror2hm", fn, assets, prefabs)
