-- 简单模式少召唤一些影怪,仅此而已
local noshadowworld = not GetModConfigData("Shadow World")
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1
local notdisappear = GetModConfigData("shadowchesspieces") ~= -1

if speedup < 1.45 then TUNING.SHADOW_KNIGHT.SPEED[1] = TUNING.SHADOW_KNIGHT.SPEED[2] * 1.45 / speedup end
if speedup < 1.33 then TUNING.SHADOW_KNIGHT.SPEED[2] = TUNING.SHADOW_KNIGHT.SPEED[2] * 1.33 / speedup end
if speedup < 1.25 then TUNING.SHADOW_KNIGHT.SPEED[3] = TUNING.SHADOW_KNIGHT.SPEED[3] * 1.25 / speedup end
if speedup < 2 then TUNING.SHADOW_BISHOP.SPEED = TUNING.SHADOW_BISHOP.SPEED * 2 / speedup end
if speedup < 1.45 then TUNING.SHADOW_ROOK.SPEED = TUNING.SHADOW_ROOK.SPEED * 1.45 / speedup end

if attackspeedup < 1.33 then
    TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[1] = TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[1] * 3 / 4 * attackspeedup
    TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[2] = TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[2] * 3 / 4 * attackspeedup
    TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[3] = TUNING.SHADOW_KNIGHT.ATTACK_PERIOD[3] * 3 / 4 * attackspeedup
    TUNING.SHADOW_BISHOP.ATTACK_PERIOD[1] = TUNING.SHADOW_BISHOP.ATTACK_PERIOD[1] * 3 / 4 * attackspeedup
    TUNING.SHADOW_BISHOP.ATTACK_PERIOD[2] = TUNING.SHADOW_BISHOP.ATTACK_PERIOD[2] * 3 / 4 * attackspeedup
    TUNING.SHADOW_BISHOP.ATTACK_PERIOD[3] = TUNING.SHADOW_BISHOP.ATTACK_PERIOD[3] * 3 / 4 * attackspeedup
    TUNING.SHADOW_ROOK.ATTACK_PERIOD[1] = TUNING.SHADOW_ROOK.ATTACK_PERIOD[1] * 3 / 4 * attackspeedup
    TUNING.SHADOW_ROOK.ATTACK_PERIOD[2] = TUNING.SHADOW_ROOK.ATTACK_PERIOD[2] * 3 / 4 * attackspeedup
    TUNING.SHADOW_ROOK.ATTACK_PERIOD[3] = TUNING.SHADOW_ROOK.ATTACK_PERIOD[3] * 3 / 4 * attackspeedup
end

TUNING.SHADOW_KNIGHT.HEALTH[1] = TUNING.SHADOW_KNIGHT.HEALTH[1] * 2
TUNING.SHADOW_KNIGHT.HEALTH[2] = TUNING.SHADOW_KNIGHT.HEALTH[2] * 1.5
TUNING.SHADOW_KNIGHT.HEALTH[3] = TUNING.SHADOW_KNIGHT.HEALTH[3] * 1.25
TUNING.SHADOW_BISHOP.HEALTH[1] = TUNING.SHADOW_BISHOP.HEALTH[1] * 2
TUNING.SHADOW_BISHOP.HEALTH[2] = TUNING.SHADOW_BISHOP.HEALTH[2] * 1.5
TUNING.SHADOW_BISHOP.HEALTH[3] = TUNING.SHADOW_BISHOP.HEALTH[3] * 1.25
TUNING.SHADOW_ROOK.HEALTH[1] = TUNING.SHADOW_ROOK.HEALTH[1] * 2
TUNING.SHADOW_ROOK.HEALTH[2] = TUNING.SHADOW_ROOK.HEALTH[2] * 1.5
TUNING.SHADOW_ROOK.HEALTH[3] = TUNING.SHADOW_ROOK.HEALTH[3] * 1.25

local function PillarsSpellFn(inst, pos)
    local spell = SpawnPrefab("mod_hardmode_shadow_pillar_spell")
    spell.caster = inst
    local platform = TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
    if platform ~= nil then
        spell.entity:SetParent(platform.entity)
        spell.Transform:SetPosition(platform.entity:WorldToLocalSpace(pos:Get()))
    else
        spell.Transform:SetPosition(pos:Get())
    end
    return spell
end

local function TrapSpellFn(inst, pos, force)
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 3, {"shadowtrap2hm"})
    if #ents > 0 then for index, ent in ipairs(ents) do if ent.TriggerTrap then ent:TriggerTrap() end end end
    local trap = SpawnPrefab("mod_hardmode_shadow_trap")
    trap.Transform:SetPosition(pos:Get())
    if TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z) ~= nil then trap:RemoveTag("ignorewalkableplatforms") end
    return trap
end

local function getTarget(inst)
    if inst.components.combat and inst.components.combat.target then return inst.components.combat.target end
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TUNING.SHADOWCREATURE_TARGET_DIST, true)
    if #players > 0 then return players[math.random(#players)] end
    local ents = TheSim:FindEntities(x, y, z, 25, {"shadowchesspiece"})
    if #ents > 0 then return ents[math.random(#ents)] end
end

local effectsymbols = {shadow_knight = "face", shadow_bishop = "head", shadow_rook = "bottom_head"}

local function delaypillar(inst, hasshadow)
    if inst.delayspell2hm then
        inst:RemoveEventCallback("newstate", inst.delayspell2hm)
        inst.delayspell2hm = nil
    end
    if not hasshadow then inst:RemoveTag("shadow") end
    inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "shadowchess2hm")
    if inst.prefab == "shadow_knight" and (inst.level or 1) < 3 then return end
    local target = getTarget(inst)
    if target and target:IsValid() then
        local pos = target:GetPosition()
        PillarsSpellFn(inst, pos)
        if inst.prefab == "shadow_rook" and (inst.level or 1) >= 2 then
            if inst.changepillarpos2hm then
                inst.changepillarpos2hm = nil
                local theta = target:GetRotation() * DEGREES
                local radius = 6
                local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
                PillarsSpellFn(inst, inst:GetPosition() + offset)
            else
                PillarsSpellFn(inst, inst:GetPosition())
            end
        end
        if inst.prefab ~= "shadow_knight" and (inst.level or 1) >= 3 then
            PillarsSpellFn(inst, Vector3(pos.x + math.random(20) - 10, pos.y, pos.z + math.random(20) - 10))
        end
    end
end
local function delaytrap(inst)
    if inst.delayspell2hm then
        inst:RemoveEventCallback("newstate", inst.delayspell2hm)
        inst.delayspell2hm = nil
    end
    local target = getTarget(inst)
    if target and target:IsValid() then
        local pos = target:GetPosition()
        TrapSpellFn(inst, pos)
        if (inst.level or 1) < 2 then
            if inst.prefab == "shadow_bishop" then TrapSpellFn(inst, inst:GetPosition(), true) end
            return
        end
        local moretrap = (inst.level or 1) == 3 and 3 or 1
        if inst.prefab == "shadow_knight" then moretrap = moretrap - 1 end
        if moretrap > 0 then for _ = 1, moretrap do TrapSpellFn(inst, Vector3(pos.x + math.random(20) - 10, pos.y, pos.z + math.random(20) - 10)) end end
        if inst.prefab == "shadow_bishop" then TrapSpellFn(inst, inst:GetPosition(), true) end
    end
end
local function delayspell(inst, spell)
    if inst.delayspell2hm then
        inst:RemoveEventCallback("newstate", inst.delayspell2hm)
        inst.delayspell2hm = nil
    end
    inst.delayspell2hm = spell
    inst:ListenForEvent("newstate", spell)
end
local function TryUseSpell(inst)
    if (inst.prefab == "shadow_rook" or (inst.level or 1) >= 2) and not inst.mod_PillarsSpellFntask then
        inst.mod_PillarsSpellFntask = inst:DoTaskInTime((inst.prefab == "shadow_rook" and 65 or 75) - (inst.level or 1) * 15,
                                                        function() inst.mod_PillarsSpellFntask = nil end)
        if inst.prefab == "shadow_knight" then inst.recentPillarsSpell2hm = true end
        local hasshadow = inst:HasTag("shadow")
        if not hasshadow then inst:AddTag("shadow") end
        local fx = SpawnPrefab("stalker_shield" .. tostring(inst.level or 1))
        fx.entity:SetParent(inst.entity)
        if (inst.level or 1) < 3 then
            fx.AnimState:SetScale(-1.36, 1.36, 1.36)
        else
            fx.AnimState:SetScale(-2.36, 2.36, 2.36)
        end
        inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.01, "shadowchess2hm")
        if inst.sg.currentstate.name == "attack" then
            if inst.prefab == "shadow_rook" then inst.changepillarpos2hm = true end
            inst:DoTaskInTime(0, delayspell, delaypillar)
        else
            inst:DoTaskInTime(0.5, delaypillar)
        end
        return true
    elseif (inst.prefab == "shadow_bishop" or (inst.level or 1) >= 2) and not inst.mod_TrapSpellFntask then
        inst.mod_TrapSpellFntask = inst:DoTaskInTime((inst.prefab == "shadow_bishop" and 36 or 45) - (inst.level or 1) * 8,
                                                     function() inst.mod_TrapSpellFntask = nil end)
        if inst.prefab == "shadow_knight" then inst.recentTrapSpell2hm = true end
        inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/gem_place")
        local fx = SpawnPrefab("cointosscastfx")
        fx.entity:AddFollower()
        fx:SetUp({0, 0, 0})
        fx.Follower:FollowSymbol(inst.GUID, effectsymbols[inst.prefab], 0, 0, 0)
        if inst.sg.currentstate.name == "attack" then
            inst:DoTaskInTime(0, delayspell, delaytrap)
        else
            inst:DoTaskInTime(0.5, delaytrap)
        end
        return true
    end
end

local shadowchesspieces = {"shadow_knight", "shadow_bishop", "shadow_rook"}
local recordshadowchesspieces = {{}, {}, {}, {}, {}, {}}

local function cantdead(inst)
    if (inst.level or 1) < 3 and inst.components.health and inst.components.health:IsInvincible() then return true end
    if (inst.level or 1) < 3 and inst.components.health and not inst.components.health:IsDead() then
        -- 清除在场三基佬,保留三只最高级的
        local shadowlist = {shadow_bishop = false, shadow_rook = false, shadow_knight = false}
        shadowlist[inst.levelsummon2hm and inst.levelsummon2hm.prefab or inst.prefab] = true
        local pos = inst:GetPosition()
        local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 50, {"shadowchesspiece"})
        local shadowchess = {}
        table.insert(shadowchess, inst)
        for i, v in ipairs(ents) do
            if v.components.health and not v.components.health:IsDead() and (v.level or 1) == (inst.level or 1) then
                local vprefab = v.levelsummon2hm and v.levelsummon2hm.prefab or v.prefab
                if shadowlist[vprefab] == false then
                    shadowlist[vprefab] = true
                    table.insert(shadowchess, v)
                end
            end
        end
        if shadowlist.shadow_knight and shadowlist.shadow_bishop and shadowlist.shadow_rook and #shadowchess == 3 then
            for i, v in ipairs(shadowchess) do
                if v.sg then v.sg:AddStateTag("temp_invincible") end
                table.insert(v.levelupsource, "2hm" .. (v.level or 1))
                if v.levelsummon2hm then v.levelsummon2hm.minhealth = true end
                if v.sg and not v.sg:HasStateTag("busy") and v.WantsToLevelUp and v:WantsToLevelUp() then v.sg:GoToState("levelup") end
            end
            return true
        end
    end
end

local chesspieces_monster = {shadow_knight = "nightmarebeak", shadow_bishop = "crawlingnightmare", shadow_rook = "oceanhorror2hm"}
local monsters = {"crawlingnightmare", "nightmarebeak", "oceanhorror2hm", "ruinsnightmare"} -- 2025.8.2 melon:增加潜伏暗影
local monsterstime = {crawlingnightmare = 60, nightmarebeak = 30, oceanhorror2hm = 90, ruinsnightmare = 30}
local function killshadowcreature(inst)
    if inst.components.health then
        if inst.components.lootdropper then
            inst.components.lootdropper:SetLoot()
            inst.components.lootdropper:SetChanceLootTable()
            inst.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            inst.components.lootdropper.GenerateLoot = emptytablefn
            inst.components.lootdropper.DropLoot = emptytablefn
        end
        inst.components.health:Kill()
    end
end
local function removeshadowcreature(inst)
    inst.wantstodespawn = true
    inst:DoTaskInTime(3, killshadowcreature)
end
local function CallRandomMonster(inst, number)
    -- for index = 1, number or inst.level or 1 do
    for index = 1, number or 1 do -- 2025.8.2 melon:仅召1个
        local shadow = SpawnMonster2hm(inst.components.combat.target or inst, monsters[math.random(4)], nil, nil, true)
        if shadow then
            shadow.disableexchange2hm = true
            shadow:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
        end
    end
end
local function CallSelfMonster(inst, number)
    if noshadowworld then return end
    -- for index = 1, number or inst.level or 1 do
    for index = 1, number or 1 do -- 2025.8.2 melon:仅召1个
        local shadow = SpawnMonster2hm(inst.components.combat.target or inst, chesspieces_monster[inst.prefab] or "nightmarebeak", nil, nil, true)
        if shadow then
            shadow.disableexchange2hm = true
            shadow:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
        end
    end
end
local function CallTeamMonster(inst)
    local shadow = SpawnMonster2hm(inst.components.combat.target or inst, "crawlingnightmare", nil, nil, true)
    if shadow then
        shadow.disableexchange2hm = true
        shadow:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
    end
    local shadow2 = SpawnMonster2hm(inst.components.combat.target or inst, "nightmarebeak", nil, nil, true)
    if shadow2 then
        shadow2.disableexchange2hm = true
        shadow2:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
    end
    local shadow3 = SpawnMonster2hm(inst.components.combat.target or inst, "oceanhorror2hm", nil, nil, true)
    if shadow3 then
        shadow3.disableexchange2hm = true
        shadow3:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
    end
    -- 2025.8.2 melon:增加潜伏暗影
    local shadow4 = SpawnMonster2hm(inst.components.combat.target or inst, "ruinsnightmare", nil, nil, true)
    if shadow4 then
        shadow4.disableexchange2hm = true
        shadow4:DoTaskInTime(monsterstime[shadow.prefab] or 30, removeshadowcreature)
    end
end
-- 因此召唤数目依次为3/3,4/5/6,6/7/8/9或3/2,2/3/4,3/4/5/6
-- 3级召唤3次,这次6只
local function on75percenthealth(inst)
    if (inst.level or 1) >= 3 and not inst.levelsummon2hm.percent75_3 then
        inst.levelsummon2hm.percent75_3 = true
        if not inst.components.health:IsDead() and inst.components.health:GetPercent() > 0.501 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallRandomMonster(inst)
            CallSelfMonster(inst)
            if not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = nil
                inst.sg:GoToState("exchange2hm")
            end
        end
    end
end
-- 2级召唤2次,这次4只
local function on66percenthealth(inst)
    if (inst.level or 1) == 2 and not inst.levelsummon2hm.percent66_2 then
        inst.levelsummon2hm.percent66_2 = true
        if not inst.components.health:IsDead() and inst.components.health:GetPercent() > 0.335 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallRandomMonster(inst)
            CallSelfMonster(inst)
            if TUNING.DSTU and inst.persists == false then
                inst.components.health:Kill()
            elseif not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = nil
                inst.sg:GoToState("exchange2hm")
            end
        end
    end
end
-- 1级召唤1次,每次3只;3级召唤3次,这次7只
local function on50percenthealth(inst)
    if (inst.level or 1) <= 1 and not inst.levelsummon2hm.percent50_1 then
        inst.levelsummon2hm.percent50_1 = true
        if not inst.levelsummon2hm.prefab then inst.levelsummon2hm.prefab = inst.prefab end
        if not inst.components.health:IsDead() and inst.components.health.currenthealth > 1 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            -- CallTeamMonster(inst)
            CallRandomMonster(inst, 1) -- 2025.8.2 melon:1阶段改为只召1个
            if not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = nil
                inst.sg:GoToState("exchange2hm")
            end
        end
    elseif (inst.level or 1) >= 3 and not inst.levelsummon2hm.percent50_3 then
        inst.levelsummon2hm.percent50_3 = true
        if not inst.components.health:IsDead() and inst.components.health:GetPercent() > 0.251 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallRandomMonster(inst, 1)
            CallTeamMonster(inst)
            CallSelfMonster(inst)
            if not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = nil
                inst.sg:GoToState("exchange2hm")
            end
        end
    end
end
-- 2级召唤2次,这次5只
local function on33percenthealth(inst)
    if (inst.level or 1) == 2 and not inst.levelsummon2hm.percent33_2 then
        inst.levelsummon2hm.percent33_2 = true
        if not inst.components.health:IsDead() and inst.components.health.currenthealth > 1 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallTeamMonster(inst)
            CallSelfMonster(inst)
            if not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = inst.levelsummon2hm.prefab
                inst.sg:GoToState("exchange2hm")
            end
        end
    end
end
-- 3级召唤3次,这次8只
local function on25percenthealth(inst)
    if (inst.level or 1) >= 3 and not inst.levelsummon2hm.percent25_3 then
        inst.levelsummon2hm.percent25_3 = true
        if not inst.components.health:IsDead() and inst.components.health.currenthealth > 1 and not inst.disablelevelupexchange2hm then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallRandomMonster(inst, 2)
            CallTeamMonster(inst)
            CallSelfMonster(inst)
            if not inst.disableexchange2hm then
                inst.nextexchangeprefab2hm = inst.levelsummon2hm.prefab
                inst.sg:GoToState("exchange2hm")
            end
        end
    end
end
-- 死亡时召唤3/6/9只
local function onminhealth(inst, data)
    if inst.components.health.minhealth > 0 then
        local cause = data and data.cause
        local afflicter = data and data.afflicter
        if not inst.levelsummon2hm.minhealth then
            inst.levelsummon2hm.minhealth = true
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            CallRandomMonster(inst)
            -- CallRandomMonster(inst) -- 2025.8.2 melon:注释，仅召一次
            CallSelfMonster(inst)
            if not cantdead(inst) then
                inst.components.health.minhealth = 0
                inst.components.health:SetVal(0, cause, afflicter)
            end
        end
    else
        local pieces = recordshadowchesspieces[inst.level or 1]
        for i = #pieces, 1, -1 do if pieces[i] and (pieces[i] == inst or not pieces[i]:IsValid()) then table.remove(pieces, i) end end
    end
end
local function onshadowchesspiecesave(inst) inst.components.persistent2hm.data.levelsummon2hm = inst.levelsummon2hm end
local function onshadowchesspieceload(inst)
    if inst.components.persistent2hm.data.levelsummon2hm then inst.levelsummon2hm = inst.components.persistent2hm.data.levelsummon2hm end
end

local function ExchangeWith(inst)
    local sx, sy, sz = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("shadow_teleport_in2hm")
    fx.Transform:SetPosition(sx, sy, sz)
    fx.Transform:SetScale(1.25, 1.25, 1.25)
    local newPrefabs = {}
    for _, prefab in ipairs(shadowchesspieces) do if prefab ~= inst.prefab then table.insert(newPrefabs, prefab) end end
    local shadow = SpawnPrefab(inst.nextexchangeprefab2hm or newPrefabs[math.random(#newPrefabs)] or "shadow_knight")
    shadow.levelsummon2hm = inst.levelsummon2hm
    shadow:SetPersistData(inst.nextexchangeprefabdata2hm or inst:GetPersistData())
    if inst.nextexchangeprefabdata2hm then
        shadow.components.health:SetPercent(shadow.components.health:GetPercent() + 0.2)
    else
        shadow.components.health:SetPercent(inst.components.health:GetPercent())
    end
    shadow.Transform:SetPosition(sx, sy, sz)
    shadow.sg:GoToState("appear")
    shadow.disablelevelupexchange2hm = nil
    if inst.components.combat and inst.components.combat.target and shadow.components.combat then
        shadow.components.combat:SetTarget(inst.components.combat.target)
    end
end
-- 1级时不再转换别的形态
local exchangestate = State {
    name = "exchange2hm",
    tags = {"busy", "noattack", "teleporting"},
    onenter = function(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("shadow_teleport_out2hm")
        fx.Transform:SetPosition(x, y, z)
        local scale = 0.5 + (inst.level or 1) * 0.25
        fx.Transform:SetScale(scale, scale, scale)
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("taunt", false)
        inst.AnimState:PushAnimation("disappear", false)
    end,
    timeline = {
        TimeEvent(40 * FRAMES, function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            local fx = SpawnPrefab("shadow_teleport_out2hm")
            fx.Transform:SetPosition(x, y, z)
            local scale = 0.5 + (inst.level or 1) * 0.25
            fx.Transform:SetScale(scale, scale, scale)
        end)
    },
    events = {
        EventHandler("animqueueover", function(inst)
            if (inst.level or 1) <= 1 then
                local sx, sy, sz = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("shadow_teleport_in2hm")
                fx.Transform:SetPosition(sx, sy, sz)
                local scale = 0.5 + (inst.level or 1) * 0.25
                fx.Transform:SetScale(scale, scale, scale)
                inst.sg:GoToState("appear")
            else
                ExchangeWith(inst)
                inst:Remove()
            end
        end)
    }
}
-- 传送单位
local function teleportother(inst)
    local pieces = recordshadowchesspieces[inst.level or 1]
    if #pieces > 1 then
        local start = math.random()
        local monsters = {}
        for index, monster in ipairs(pieces) do
            if monster ~= inst and monster:IsValid() and (monster:IsAsleep() or not (monster.components.combat and monster.components.combat.target)) then
                table.insert(monsters, monster)
            end
        end
        local radius = (inst.level or 1) * 4
        for index, monster in ipairs(monsters) do
            local theta = (start + 1 / (#monsters - 1) * index) * 2 * PI
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local pt = inst:GetPosition() + offset
            monster.Transform:SetPosition(pt.x, pt.y, pt.z)
        end
    end
end
local function teleportinst(inst)
    local pieces = recordshadowchesspieces[inst.level or 1]
    if #pieces > 1 then
        local target
        for index, monster in ipairs(pieces) do
            if monster ~= inst and monster:IsValid() and not monster:IsAsleep() and monster.components.combat and monster.components.combat.target then
                target = monster
                break
            end
        end
        if target then
            local theta = math.random() * 2 * PI
            local radius = (inst.level or 1) * 4
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local pt = target:GetPosition() + offset
            inst.Transform:SetPosition(pt.x, pt.y, pt.z)
        else
            teleportother(inst)
        end
    end
end
TUNING.SHADOW_CHESSPIECE_DESPAWN_TIME = 100000000
local minimapprefabs = {shadow_knight = "knight", shadow_bishop = "bishop", shadow_rook = "rook"}
for _, shadowchesspiece in ipairs(shadowchesspieces) do
    -- 转换形态
    AddStategraphState(shadowchesspiece, exchangestate)
    -- 施法
    AddStategraphPostInit(shadowchesspiece, function(sg)
        local tauntonenter = sg.states.taunt.onenter
        sg.states.taunt.onenter = function(inst, ...)
            tauntonenter(inst, ...)
            TryUseSpell(inst)
        end
        if notdisappear then
            sg.events.despawn.fn = nilfn
            sg.states.despawn.onenter = function(inst, ...) inst.sg:GoToState("idle") end
        end
    end)
    AddPrefabPostInit(shadowchesspiece, function(inst)
        if TheWorld.has_ocean then RemovePhysicsColliders(inst) end
        if not TheWorld.ismastersim then return end
        if not inst.MiniMapEntity and not inst.icon then
            local icon = SpawnPrefab("shadowchessicon2hm")
            if icon then
                icon:TrackEntity(inst)
                icon:SetSculpturePrefab(minimapprefabs[shadowchesspiece] or "knight")
                inst.icon = icon
            end
        end
        if inst.OnEntitySleep and notdisappear then
            local OnEntitySleep = inst.OnEntitySleep
            inst.OnEntitySleep = function(inst, ...)
                OnEntitySleep(inst, ...)
                if inst._despawntask then
                    inst._despawntask:Cancel()
                    inst._despawntask = nil
                end
            end
        end
        if not inst.components.timer then inst:AddComponent("timer") end
        if not inst.components.healthtrigger then inst:AddComponent("healthtrigger") end
        inst.levelsummon2hm = {}
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst.onsave2hm = onshadowchesspiecesave
        inst.onload2hm = onshadowchesspieceload
        inst.continueattackindex2hm = 1
        inst.components.healthtrigger:AddTrigger(0.75031, on75percenthealth)
        inst.components.healthtrigger:AddTrigger(0.66731, on66percenthealth)
        inst.components.healthtrigger:AddTrigger(0.50031, on50percenthealth)
        inst.components.healthtrigger:AddTrigger(0.33331, on33percenthealth)
        inst.components.healthtrigger:AddTrigger(0.25031, on25percenthealth)
        inst.components.health.minhealth = 1
        inst:ListenForEvent("minhealth", onminhealth)
        -- 出现前1秒内升级都是继承数据升级，不处理
        inst.disablelevelupexchange2hm = true
        inst:DoTaskInTime(1, function()
            if not inst.levelsummon2hm.prefab then inst.levelsummon2hm.prefab = inst.prefab end
            inst.disablelevelupexchange2hm = nil
            inst.disableexchange2hm = inst.disableexchange2hm == true or inst.levelsummon2hm.disableexchange2hm == true
            inst.levelsummon2hm.disableexchange2hm = inst.disableexchange2hm
        end)
        inst.teleportother2hm = teleportother
        inst.teleportinst2hm = teleportinst
        recordshadowchesspieces[inst.level or 1] = recordshadowchesspieces[inst.level or 1] or {}
        table.insert(recordshadowchesspieces[inst.level or 1], inst)
        local oldLevelUp = inst.LevelUp
        inst.LevelUp = function(inst, ...)
            local pieces = recordshadowchesspieces[inst.level or 1]
            for i = #pieces, 1, -1 do
                for i = #pieces, 1, -1 do if pieces[i] and (pieces[i] == inst or not pieces[i]:IsValid()) then table.remove(pieces, i) end end
            end
            oldLevelUp(inst, ...)
            inst.components.health.minhealth = (inst.level or 1) < 3 and 1 or 0
            if inst.levelsummon2hm.minhealth then
                inst.levelsummon2hm.minhealth = nil
            elseif not POPULATING and not inst.disablelevelupexchange2hm then
                inst.disableexchange2hm = true
                inst.levelsummon2hm.disableexchange2hm = true
            end
            inst.continueattackindex2hm = 1
            recordshadowchesspieces[inst.level or 1] = recordshadowchesspieces[inst.level or 1] or {}
            table.insert(recordshadowchesspieces[inst.level or 1], inst)
        end
    end)
end

-- 暗影骑士攻击滑铲
AddStategraphPostInit("shadow_knight", function(sg)
    local attackonenter = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        attackonenter(inst, ...)
        if (inst.level or 1) >= 2 and inst.recentTrapSpell2hm then
            inst.recentTrapSpell2hm = nil
            inst.components.locomotor:RunForward()
            TrapSpellFn(inst, inst:GetPosition(), true):TriggerTrap()
        end
        if (inst.level or 1) >= 2 and inst.recentPillarsSpell2hm and inst.components.combat.target then
            inst.recentPillarsSpell2hm = nil
            local p1 = inst:GetPosition()
            local p2 = inst.components.combat.target:GetPosition()
            local offset = p2 - p1
            PillarsSpellFn(inst, p2 + offset)
        end
    end
end)

-- 暗影战车升级后可以连续攻击
AddStategraphPostInit("shadow_rook", function(sg)
    sg.states.attack_teleport.events.animqueueover.fn = function(inst, ...)
        if inst.AnimState:AnimDone() then
            if inst.continueattackindex2hm >= (inst.level or 1) or inst:WantsToLevelUp() then
                inst.continueattackindex2hm = 1
                inst.sg:GoToState("idle")
            else
                inst.continueattackindex2hm = inst.continueattackindex2hm + 1
                inst.sg:GoToState("attack", inst.sg.statemem.target)
            end
        end
    end
    local attackonenter = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        attackonenter(inst, ...)
        if TryUseSpell(inst) and (inst.level or 1) == 3 and recordshadowchesspieces[3] and #recordshadowchesspieces[3] >= 2 and inst.continueattackindex2hm == 3 then
            inst.summon2hm = true
        end
    end
    local attackteleportonenter = sg.states.attack_teleport.onenter
    sg.states.attack_teleport.onenter = function(inst, ...)
        attackteleportonenter(inst, ...)
        if inst.summon2hm then
            inst.summon2hm = nil
            if not inst.teleportother2hm then inst.teleportother2hm = teleportother end
            inst:teleportother2hm()
        end
    end
end)

-- 暗影主教攻击后会落到附近的陷阱上
AddStategraphPostInit("shadow_bishop", function(sg)
    local attackpstenter = sg.states.attack_pst.onenter
    sg.states.attack_pst.onenter = function(inst, ...)
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, (inst.level or 1) * 20, {"shadowtrap2hm"})
        if #ents > 0 then
            local pos = ents[1]:GetPosition()
            inst.Physics:Teleport(pos.x, 0, pos.z)
            inst.longwait2hm = true
        else
            inst.longwait2hm = nil
        end
        attackpstenter(inst, ...)
        inst.lastattacktime2hm = GetTime() - 3
    end
end)
local ShadowChess = require("stategraphs/SGshadow_chesspieces")
local newtauntstate = State {
    name = "taunt",
    tags = {"taunt", "busy"},
    onenter = function(inst, remaining)
        inst.sg.statemem.total_taunt = math.random(inst.level, 3) + (inst.longwait2hm and 2 or 0)
        inst.sg.statemem.remaining = (remaining or inst.sg.statemem.total_taunt) - 1 -- can taunt one more time!
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("taunt")
        if inst.sg.statemem.remaining == 0 then
            local x, y, z = inst.Transform:GetWorldPosition()
            local players = shuffleArray(FindPlayersInRange(x, y, z, TUNING.SHADOWCREATURE_TARGET_DIST, true))
            for i, v in ipairs(players) do
                if v ~= inst.components.combat.target and inst.components.combat:CanTarget(v) then
                    inst.components.combat:SetTarget(v)
                    break
                end
            end
        end
    end,
    timeline = {
        ShadowChess.Functions.ExtendedSoundTimelineEvent(3.5 * FRAMES, "taunt"),
        TimeEvent(30 * FRAMES, function(inst)
            ShadowChess.Functions.AwakenNearbyStatues(inst)
            ShadowChess.Functions.TriggerEpicScare(inst)
        end)
    },
    events = {
        EventHandler("animover", function(inst)
            inst.sg:RemoveStateTag("busy")
            if inst.AnimState:AnimDone() then
                if inst:WantsToLevelUp() then inst.sg.statemem.remaining = 0 end
                inst.sg:GoToState(inst.sg.statemem.remaining > 0 and "taunt" or "idle", inst.sg.statemem.remaining)
            end
        end)
    }
}
if TUNING.DSTU then AddStategraphState("shadow_bishop", newtauntstate) end
