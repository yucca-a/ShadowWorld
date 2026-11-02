local function usesnarecontrolother(inst, data)
    if not inst.snaredefendtask and data and data.target and not (inst.snares ~= nil and #inst.snares > 0) and data.target ~= inst then
        SpawnDefendIvyPlant(inst, data.target)
        inst.snaredefendtask = inst:DoTaskInTime(12, function() inst.snaredefendtask = nil end)
    end
end

local function rootareahitcheck(ent, inst) return ent and ent ~= inst.mod_spawnparent and not ent:HasTag("epic") end

local targdist = TUNING.DECID_MONSTER_TARGET_DIST
local function spawn_root_attack(inst, target)
    if target ~= nil then
        local root = SpawnPrefab("deciduous_root")
        root.mod_spawnparent = inst
        root:ListenForEvent("onhitother", function(inst, data)
            if inst.mod_spawnparent and inst.mod_spawnparent:IsValid() then usesnarecontrolother(inst.mod_spawnparent, data) end
        end)
        root.components.combat.areahitcheck = rootareahitcheck
        if inst.prefab == "bigshadowtentacle" then
            root.AnimState:SetMultColour(0, 0, 0, 0.5)
        else
            root.AnimState:SetMultColour(180 / 255, 102 / 255, 222 / 255, 1)
        end
        local x, y, z = inst.Transform:GetWorldPosition()
        local mx, my, mz = target.Transform:GetWorldPosition()
        local rootpos = Vector3(mx, 0, mz)
        local angle = inst:GetAngleToPoint(rootpos) * DEGREES
        local mdistsq = distsq(x, z, mx, mz)
        local targdistsq = targdist * targdist
        if mdistsq > targdistsq then
            rootpos.x = x + math.cos(angle) * targdist
            rootpos.z = z - math.sin(angle) * targdist
        elseif mdistsq <= TUNING.DECID_MONSTER_ROOT_ATTACK_RADIUS * TUNING.DECID_MONSTER_ROOT_ATTACK_RADIUS then
            rootpos.x = rootpos.x + math.cos(angle) * TUNING.DECID_MONSTER_ROOT_ATTACK_RADIUS
            rootpos.z = rootpos.z - math.sin(angle) * TUNING.DECID_MONSTER_ROOT_ATTACK_RADIUS
        end
        root.Transform:SetPosition(x + 1.75 * math.cos(angle), 0, z - 1.75 * math.sin(angle))
        root:PushEvent("givetarget", {target = target, targetpos = rootpos, targetangle = angle, owner = inst})
    end
end

local function userootattackother(inst, data)
    if not inst.rootdefendtask and data and (data.attacker or data.target) then
        spawn_root_attack(inst, data.attacker or data.target)
        inst.rootdefendtask = inst:DoTaskInTime(inst.prefab == "bigshadowtentacle" and 0.5 or 12, function() inst.rootdefendtask = nil end)
    end
end

local function tentacleonkilled(inst, data)
    if data and data.victim and (data.victim.prefab == "slurtle" or data.victim.prefab == "snurtle") then
        if data.victim.components.lootdropper then
            data.victim.components.lootdropper:SetLoot()
            data.victim.components.lootdropper:SetChanceLootTable()
            data.victim.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            data.victim.components.lootdropper.GenerateLoot = emptytablefn
            data.victim.components.lootdropper.DropLoot = emptytablefn
        end
        if not inst.components.health.regen then inst.components.health:StartRegen(25, 1) end
    end
end
AddPrefabPostInit("tentacle", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", KillOffSnares)
    inst:ListenForEvent("onhitother", usesnarecontrolother)
    inst:ListenForEvent("blocked", userootattackother)
    inst:ListenForEvent("attacked", userootattackother)
    inst:ListenForEvent("killed", tentacleonkilled)
end)

AddPrefabPostInit("bigshadowtentacle", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onhitother", usesnarecontrolother)
    inst:ListenForEvent("doattack", userootattackother)
end)

local function usesnarecontrolotherdelay(inst, data)
    if not inst.snaredefendtask and data and data.attacker and not (inst.snares ~= nil and #inst.snares > 0) then
        local attacker = data.attacker
        inst:DoTaskInTime(0.5, SpawnDefendIvyPlant, attacker)
        inst.snaredefendtask = inst:DoTaskInTime(12, function() inst.snaredefendtask = nil end)
    end
end

AddPrefabPostInit("tentacle_pillar", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", KillOffSnares)
    inst:ListenForEvent("blocked", usesnarecontrolotherdelay)
    inst:ListenForEvent("attacked", usesnarecontrolotherdelay)
    inst:ListenForEvent("killed", tentacleonkilled)
end)
