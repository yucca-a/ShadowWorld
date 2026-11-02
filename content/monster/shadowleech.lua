local leechlevel = GetModConfigData("shadowleech")
local hardmode = leechlevel ~= -1
local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1

-- 寄生暗影
TUNING.SHADOW_LEECH_HEALTH = TUNING.SHADOW_LEECH_HEALTH * 2
if speedup < 1.17 then TUNING.SHADOW_LEECH_RUNSPEED = TUNING.SHADOW_LEECH_RUNSPEED * 1.17 / speedup end

local function onkilledbyother(inst, attacker)
    if attacker ~= nil and attacker.components.sanity ~= nil then attacker.components.sanity:DoDelta(TUNING.SANITY_SMALL) end
end
local function killleech(leech)
    if not leech.regen2hm and leech.components.lootdropper then
        leech.components.lootdropper:SetLoot()
        leech.components.lootdropper:SetChanceLootTable()
        leech.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
        leech.components.lootdropper.GenerateLoot = emptytablefn
        leech.components.lootdropper.DropLoot = emptytablefn
    end
    if leech.regen2hm then leech.regen2hm = nil end
    if leech.components.health and not leech.components.health:IsDead() then leech.components.health:Kill() end
end
local function AttachLeech(inst, leech, noreact)
    if inst:HasTag("playerghost") then
        killleech(leech)
        inst.leechattachindex2hm = 0
        return
    end
    inst.leechattachindex2hm = inst.leechattachindex2hm + 1
    inst:PushEvent("regenleech2hm")
    if inst.components.health then inst.components.health:DoDelta(-math.random(3, 8), false, "shadow_leech") end
    if inst.components.sanity then inst.components.sanity:DoDelta(-math.random(2, 5)) end
    if inst.components.hunger then inst.components.hunger:DoDelta(-math.random(2, 5)) end
    if inst.leechattachindex2hm >= 6 then
        inst.leechattachindex2hm = 0
        inst:PushEvent("knockback", {
            knocker = leech,
            radius = 3,
            strengthmult = (inst.components.inventory ~= nil and inst.components.inventory:ArmorHasTag("heavyarmor") or inst:HasTag("heavybody")) and 0.35 or
                0.7,
            forcelanded = false
        })
    elseif inst.leechattachindex2hm % 2 == 1 then
        inst:PushEvent("attacked", {attacker = leech, damage = 0})
    end
    if not leech.regen2hm then
        leech.regen2hm = true
        if leech.components.lootdropper then
            leech.components.lootdropper:SetLoot()
            leech.components.lootdropper:SetChanceLootTable()
            leech.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            leech.components.lootdropper.GenerateLoot = emptytablefn
            leech.components.lootdropper.DropLoot = emptytablefn
        end
        if leech.components.combat then leech.components.combat.onkilledbyother = nil end
        if not leech.regenfx2hm then
            leech.regenfx2hm = SpawnPrefab("tophat_shadow_fx")
            leech.regenfx2hm.entity:SetParent(leech.entity)
        end
    end
    return true
end
local function onleechremove(leech)
    local inst = leech.target2hm
    if not (inst and inst:IsValid()) then return end
    for i = #inst.leechs2hm, 1, -1 do
        if inst.leechs2hm[i] == leech then
            table.remove(inst.leechs2hm, i)
            break
        end
    end
    if leech.regen2hm then inst:PushEvent("regenleech2hm") end
end
local function locktarget(inst)
    if inst.target2hm and inst.target2hm:IsValid() and inst.components.combat then inst.components.combat:SetTarget(inst.target2hm) end
end
local function LeechShareTargetFn(dude) return dude.prefab ~= "shadow_leech" and dude:HasTag("shadowcreature") and not dude.components.health:IsDead() end
local function OnLeechAttacked(inst, data)
    if data and data.attacker then inst.components.combat:ShareTarget(data.attacker, 30, LeechShareTargetFn, 1) end
    locktarget(inst)
end
local function teleportleech(leech)
    local pos = leech.target2hm:GetPosition()
    local theta = math.random() * TWOPI
    local x, z = pos.x, pos.z
    for r = 16, 8, -1 do
        local offset = FindWalkableOffset(pos, theta, r + math.random(), 4, false, true)
        if offset ~= nil then
            x = x + offset.x
            z = z + offset.z
            break
        end
    end
    leech.Transform:SetPosition(x, 0, z)
    locktarget(leech)
end
local function onleechwake(leech)
    if leech.teleporttask2hm then
        leech.teleporttask2hm:Cancel()
        leech.teleporttask2hm = nil
    end
end
local function onleechsleep(leech)
    if leech.target2hm and leech.target2hm:IsValid() and not leech.teleporttask2hm then leech.teleporttask2hm = leech:DoTaskInTime(7, teleportleech) end
end
-- 2025.8.2 melon:附近有boss时不生成3小只
local function nearboss(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 20, {"epic"}, nil, nil)
    return #ents > 0
end
local function canspawnleech(inst)
    return
        inst.components.sanity:IsInsane() and not inst.components.health:IsDead() and not inst:HasOneOfTags({"sleeping", "shadowdominance", "playerghost"}) and
            #inst.leechs2hm < (inst.maxleech2hm or 3) and inst:GetCurrentPlatform() == nil and not nearboss(inst)
end
local function attractleechs(inst)
    inst.attractleechstask2hm = nil
    if not canspawnleech(inst) then return end
    local pos = inst:GetPosition()
    local theta = math.random() * TWOPI
    local x, z = pos.x, pos.z
    for i = 1, (inst.maxleech2hm or 3) - #inst.leechs2hm do
        local leech = SpawnPrefab("shadow_leech")
        leech.target2hm = inst
        leech:AddTag("attachplayer2hm")
        leech:AddTag("notaunt")
        leech.AnimState:SetMultColour(1, 1, 1, 0.25)
        leech.persists = false
        leech.OnEntitySleep = onleechsleep
        leech.OnEntityWake = onleechwake
        if leech.components.combat then
            leech.components.combat.onkilledbyother = onkilledbyother
            leech.components.combat:SetTarget(inst)
        end
        for r = 4, 2, -1 do
            local offset = FindWalkableOffset(pos, theta, r + math.random() * 0.5, 4, false, true)
            if offset ~= nil then
                x = x + offset.x
                z = z + offset.z
                break
            end
        end
        leech.Transform:SetPosition(x, 0, z)
        leech:OnSpawnFor(inst, 0.4 + i * 0.3 + math.random() * 0.2)
        theta = theta + TWOPI / 3
        table.insert(inst.leechs2hm, leech)
        leech:ListenForEvent("attacked", OnLeechAttacked)
        leech:ListenForEvent("jump", locktarget)
        leech:ListenForEvent("newcombattarget", locktarget)
        leech:ListenForEvent("onremove", onleechremove)
    end
end

-- 条件生成三小只
local function regenleech(inst)
    if inst.attractleechstask2hm then inst.attractleechstask2hm:Cancel() end
    attractleechs(inst)
end
local function inducedinsanity(inst, val)
    if not inst:HasTag("shadowdominance") and not inst.attractleechstask2hm and val and canspawnleech(inst) and math.random() <
        (TheWorld:HasTag("cave") and 0.35 or 0.175) then inst.attractleechstask2hm = inst:DoTaskInTime(math.random(3, 10), attractleechs) end
end
local function atinsane(inst)
    if inst.leechs2hm and not inst:HasTag("shadowdominance") and not inst.attractleechstask2hm and canspawnleech(inst) and math.random() <
        (TheWorld:HasTag("cave") and 0.025 or 0.013) then inst.attractleechstask2hm = inst:DoTaskInTime(math.random(3, 10), attractleechs) end
end
local function goinsane(inst)
    if inst.components.inventory then
        for k, v in pairs(EQUIPSLOTS) do
            local equip = inst.components.inventory:GetEquippedItem(v)
            if equip and equip:IsValid() and equip.prefab == "skeletonhat" then return end
        end
    end
    if inst and math.random() < (TheWorld:HasTag("cave") and 0.1 or 0.05) and canspawnleech(inst) and not inst.attractleechstask2hm then
        inst.attractleechstask2hm = inst:DoTaskInTime(math.random(3, 10), attractleechs)
    end
end
AddComponentPostInit("shadowcreaturespawner", function(self)
    local oldSpawnShadowCreature = self.SpawnShadowCreature
    self.SpawnShadowCreature = function(self, player, params, ...)
        atinsane(player)
        return oldSpawnShadowCreature(self, player, params, ...)
    end
end)

-- 条件移除三小只
local function removeleechs(inst) for index, leech in ipairs(inst.leechs2hm) do killleech(leech) end end
local function sanitymodechanged(inst, data) if data and data.mode == SANITY_MODE_LUNACY then removeleechs(inst) end end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.AttachLeech then return end
    inst.leechs2hm = {}
    inst.leechattachindex2hm = 0
    inst.AttachLeech = AttachLeech
    inst:ListenForEvent("regenleech2hm", regenleech)
    if hardmode then
        inst:ListenForEvent("inducedinsanity", inducedinsanity)
        inst:ListenForEvent("goinsane", goinsane)
    end
    inst:ListenForEvent("death", removeleechs)
    inst:ListenForEvent("ms_becameghost", removeleechs)
    inst:ListenForEvent("onremove", removeleechs)
    inst:ListenForEvent("sanitymodechanged", sanitymodechanged)
end)

-- 三小只现在是理智影怪
local function CLIENT_ShadowLeech_HostileToPlayerTest(inst, player)
    local combat = inst.replica.combat
    if combat ~= nil and combat:GetTarget() == player then return true end
    local sanity = player.replica.sanity
    if sanity ~= nil and sanity:IsCrazy() then return true end
    return false
end
local function updateleech(inst)
    if inst:HasTag("attachplayer2hm") and not inst.HostileToPlayerTest then
        inst.HostileToPlayerTest = CLIENT_ShadowLeech_HostileToPlayerTest
        if inst.components.transparentonsanity then
            inst.components.transparentonsanity.most_alpha = .4
            inst.components.transparentonsanity.osc_amp = .25
            inst.components.transparentonsanity:ForceUpdate()
        end
    end
end
AddPrefabPostInit("shadow_leech", function(inst)
    if TheWorld.has_ocean then
        inst.Physics:ClearCollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.GROUND)
    end
    inst:DoTaskInTime(0, updateleech)
end)
