require("stategraphs/commonstates")
local attackrunmonsters = {bat = false, frog = true, worm = false, slurtle = false, lightninggoat = true}
if TUNING.DSTU then attackrunmonsters.alpha_lightninggoat = true end
for monster, _ in pairs(attackrunmonsters) do
    AddStategraphPostInit(monster, function(sg)
        local oldonenterattack = sg.states.attack.onenter
        sg.states.attack.onenter = function(inst, ...)
            oldonenterattack(inst, ...)
            if inst.components.locomotor and not inst:HasTag("swc2hm") then inst.components.locomotor:WalkForward() end
        end
    end)
end

-- 蛞蝓龟窝攻击反伤，蛞蝓龟死亡时黏住周围敌人
local function Onslurtleholeattacked(inst, data)
    if inst._cdtask2hm == nil and not (data ~= nil and (data.redirected or (data.attacker and data.attacker:IsValid() and data.attacker:HasTag("cavedweller")))) then
        inst._cdtask2hm = inst:DoTaskInTime(.3, function() inst._cdtask2hm = nil end)
        SpawnPrefab("bramblefx_armor"):SetFXOwner(inst)
        if inst.SoundEmitter ~= nil then inst.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus") end
    end
end
AddPrefabPostInit("slurtlehole", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then inst.components.health:SetMaxHealth(1000) end
    inst:ListenForEvent("attacked", Onslurtleholeattacked)
    inst:ListenForEvent("onignite", Onslurtleholeattacked)
end)
local function snurtleOnBlocked(inst, data)
    if data and data.attacker and data.attacker:IsValid() and not data.attacker:HasTag("cavedweller") then
        local x, y, z = inst.Transform:GetWorldPosition()
        local holes = TheSim:FindEntities(x, y, z, 40, {"cavedweller"})
        for index, hole in ipairs(holes) do
            if hole and hole:IsValid() and hole.prefab == "slurtlehole" and hole.components.childspawner then
                hole.components.childspawner:SpawnChild(data.attacker)
            end
        end
    end
end
local function slurtleondeath(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRangeSq(x, y, z, 16, true)
    if #players > 0 and math.random() < #players * 0.25 then
        for index, target in ipairs(players) do
            local proj = SpawnPrefab("spat_bomb")
            if proj ~= nil and proj.components.complexprojectile ~= nil then
                proj.Transform:SetPosition(x, y, z)
                proj.components.complexprojectile:Launch(target:GetPosition(), inst)
                proj.components.complexprojectile.owningweapon = nil
            end
        end
    end
end
local function slurtleonattackother(inst, data)
    local target = data and data.target
    local owner = inst
    local pt
    if target ~= nil and target:IsValid() then
        pt = target:GetPosition()
    else
        pt = owner:GetPosition()
        target = nil
    end
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 2, 3, false, true, NoHoles2hm, false, true)
    if offset ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_1")
        inst.SoundEmitter:PlaySound("dontstarve/common/shadowTentacleAttack_2")
        local tentacle = SpawnPrefab("shadowtentacle")
        if tentacle ~= nil then
            tentacle.owner = owner
            tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
            tentacle.components.combat:SetTarget(target)
        end
    end
end
local function slurtleonkilled(inst, data)
    if data and data.victim and data.victim.prefab == "tentacle" then
        if data.victim.components.lootdropper then
            data.victim.components.lootdropper:SetLoot()
            data.victim.components.lootdropper:SetChanceLootTable()
            data.victim.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            data.victim.components.lootdropper.GenerateLoot = emptytablefn
            data.victim.components.lootdropper.DropLoot = emptytablefn
        end
        inst:ListenForEvent("onattackother", slurtleonattackother)
    end
end
AddPrefabPostInit("slurtle", function(inst)
    inst:AddTag("bramble_resistant")
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", snurtleOnBlocked)
    inst:ListenForEvent("death", slurtleondeath)
    inst:ListenForEvent("killed", slurtleonkilled)
end)
AddPrefabPostInit("snurtle", function(inst)
    inst:AddTag("bramble_resistant")
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", snurtleOnBlocked)
    inst:ListenForEvent("death", slurtleondeath)
end)

-- 蝙蝠正常苏醒,飞下来时无敌,直接飞回家
TUNING.BAT_HEALTH = TUNING.BAT_HEALTH * 2
AddStategraphEvent("bat", CommonHandlers.OnWakeEx())
AddStategraphPostInit("bat", function(sg) sg.states.flyback.tags.temp_invincible = true end)
local function attackedinalseep(inst, notwakeupother)
    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
        if notwakeupother then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 15, {"bat"})
        for k, v in pairs(ents) do if v.components.sleeper and v.components.sleeper:IsAsleep() then v:DoTaskInTime(0.25, attackedinalseep, true) end end
    end
end
local function canquickhome(inst) inst.canquickhome2hm = true end
AddPrefabPostInit("bat", function(inst)
    -- if inst.Transform then
    --     local scale = 0.75 * 0.7
    --     inst.Transform:SetScale(scale, scale, scale)
    -- end
    if inst.DynamicShadow then inst.DynamicShadow:SetSize(1, 0.5) end
    if not TheWorld.ismastersim then return end
    -- if inst.components.combat then inst.components.combat.attackrange = inst.components.combat.attackrange * 0.5 end
    inst:ListenForEvent("attacked", attackedinalseep)
    inst:DoTaskInTime(30, canquickhome)
    if inst.components.locomotor then
        local PushAction = inst.components.locomotor.PushAction
        inst.components.locomotor.PushAction = function(self, action, ...)
            if inst.canquickhome2hm and action and action.action == ACTIONS.GOHOME and action.target and action.target:HasTag("sinkhole") and
                TheWorld.state.isday then action.distance = 15 end
            PushAction(self, action, ...)
        end
    end
end)

-- 伏特羊
local SPARK_CANT_TAGS = {"playerghost", "fx", "INLIMBO", "wall", "structure", "lightninggoat"}
local function lightningfxonremove(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TheWorld.state.israining and 4 or 3, nil, SPARK_CANT_TAGS)
    local src = inst.src
    if not (src and src:IsValid()) then src = inst end
    for i, ent in ipairs(ents) do
        if ent ~= inst.src and ent.components.combat ~= nil and (ent.components.inventory == nil or not ent.components.inventory:IsInsulated()) then
            ent.components.combat:GetAttacked_Internal(src, TheWorld.state.israining and 20 or 10, nil, "electric")
        end
    end
end
local function processlightninggoatsg(sg)
    AddStateTimeEvent2hm(sg.states.attack, 15 * FRAMES, function(inst)
        if not inst:HasTag("swc2hm") and ((inst.charged and math.random() < (TheWorld.state.israining and 1 or 0.5)) or
            (inst.components.health and math.random() < ((TheWorld.state.israining and 1.35 or 1) - inst.components.health:GetPercent()))) then
            local fx = SpawnPrefab("moonstorm_ground_lightning_fx2hm")
            local rot = inst.Transform:GetRotation()
            local x, y, z = inst.Transform:GetWorldPosition()
            fx.Transform:SetRotation(rot - 90)
            local angle = rot * DEGREES
            local radius = 6
            fx.Transform:SetPosition(x + math.cos(angle) * radius, 0, z - math.sin(angle) * radius)
            fx:DoTaskInTime(15 * FRAMES, lightningfxonremove)
            if not inst.charged and inst.setcharged then
                inst:setcharged()
                if inst.components.health and not inst.components.health:IsDead() then
                    inst.components.health:SetPercent(inst.components.health:GetPercent() + 0.5)
                end
            end
            fx.src = inst
        end
    end)
end
AddStategraphPostInit("lightninggoat", processlightninggoatsg)
if TUNING.DSTU then AddStategraphPostInit("alpha_lightninggoat", processlightninggoatsg) end
