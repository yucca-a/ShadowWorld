local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
local atriumstalkermode = GetModConfigData("atriumstalker")

if attackspeedup < 2 then TUNING.STALKER_ATRIUM_ATTACK_PERIOD = TUNING.STALKER_ATRIUM_ATTACK_PERIOD / 2 * attackspeedup end
if speedup < 2 then TUNING.STALKER_SPEED = TUNING.STALKER_SPEED * 2 / speedup end

if atriumstalkermode ~= -2 then
    TUNING.STALKER_ATRIUM_HEALTH = TUNING.STALKER_ATRIUM_HEALTH * 2
    TUNING.STALKER_ATRIUM_PHASE2_HEALTH = TUNING.STALKER_ATRIUM_PHASE2_HEALTH * 2 * (tonumber(GetModConfigData("boss_health")) or 1)
    TUNING.STALKER_ABILITY_RETRY_CD = TUNING.STALKER_ABILITY_RETRY_CD / 2
    TUNING.STALKER_SNARE_CD = TUNING.STALKER_SNARE_CD / 2
    TUNING.STALKER_FIRST_SNARE_CD = TUNING.STALKER_FIRST_SNARE_CD / 2
    TUNING.STALKER_SPIKES_CD = TUNING.STALKER_SPIKES_CD / 2
    TUNING.STALKER_FIRST_SPIKES_CD = TUNING.STALKER_FIRST_SPIKES_CD / 2
    TUNING.STALKER_CHANNELERS_CD = TUNING.STALKER_CHANNELERS_CD / 2
    TUNING.STALKER_FIRST_CHANNELERS_CD = TUNING.STALKER_FIRST_CHANNELERS_CD / 2
    TUNING.STALKER_MINIONS_CD = TUNING.STALKER_MINIONS_CD / 2
    TUNING.STALKER_FIRST_MINIONS_CD = TUNING.STALKER_FIRST_MINIONS_CD / 2
    TUNING.STALKER_MINDCONTROL_CD = TUNING.STALKER_MINDCONTROL_CD / 2
    TUNING.STALKER_FIRST_MINDCONTROL_CD = TUNING.STALKER_FIRST_MINDCONTROL_CD / 2
end
TUNING.STALKER_FEAST_HEALING = TUNING.STALKER_FEAST_HEALING * 2

local hasstalker
local stalkers = {}
local function registerstalker(inst)
    table.insert(stalkers, inst)
    hasstalker = true
end
local function unregisterstalker(inst)
    for index, v in ipairs(inst.stalkerswc2hms) do
        if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then v.components.health:Kill() end
    end
    for i = #stalkers, 1, -1 do
        if stalkers[i] == inst then
            table.remove(stalkers, i)
            break
        end
    end
    if #stalkers == 0 then hasstalker = nil end
end

-- 玩家脱战后释放回血技能；受到攻击时可以转化敌人的1名影分身为自己战斗，持续30秒每个单位限一次，可以转化
local function shadowprotectorattacked(inst)
    if not inst:HasDebuff("forcefield") and inst.components.health and not inst.components.health:IsDead() then
        if inst:AddDebuff("forcefield", "abigailforcefield") and inst.components.debuffable and inst.components.debuffable.debuffs and
            inst.components.debuffable.debuffs and inst.components.debuffable.debuffs.forcefield.inst then
            local fx = inst.components.debuffable.debuffs.forcefield.inst
            fx.AnimState:SetMultColour(0, 0, 0, 0.5)
        end
    end
end
local function GetAttacked_Internal(inst, data)
    if not inst:HasTag("swc2hm") and inst.components.health and not inst.components.health:IsDead() and inst.components.timer and inst.components.combat then
        if not inst.hasshield and atriumstalkermode ~= true and data and data.attacker and data.attacker:IsValid() and data.attacker.GUID then
            if not inst.swchangeswp2hms[data.attacker.GUID] then
                if data.attacker.prefab == inst.prefab then
                    inst.oncemiss2hm = true
                    return
                elseif data.attacker:HasTag("player") then
                    -- 受到玩家的攻击则召唤一个影分身攻击玩家
                    inst.swchangeswp2hms[data.attacker.GUID] = true
                    data.attacker:DoTaskInTime(240, function() if inst:IsValid() then inst.swchangeswp2hms[data.attacker.GUID] = nil end end)
                    local pet = SpawnPrefab("shadowprotector", nil, nil, data.attacker.userid)
                    if pet ~= nil then
                        pet.Physics:Teleport(data.attacker.Transform:GetWorldPosition())
                        if pet.components.skinner and not (data.attacker.components.health:IsDead() or data.attacker:HasTag("playerghost")) then
                            pet.components.skinner:CopySkinsFromPlayer(data.attacker)
                        end
                        if pet.components.timer then
                            pet.components.timer:StopTimer("obliviate")
                            pet.components.timer:StartTimer("obliviate", 240)
                        end
                        if pet.components.health then
                            pet.components.health:SetMaxHealth(data.attacker.components.health.maxhealth * 4)
                            pet:ListenForEvent("attacked", shadowprotectorattacked)
                        end
                        if pet.components.follower then pet.components.follower:SetLeader(inst) end
                        if pet.components.knownlocations then
                            pet.components.knownlocations:RememberLocation("spawn", (inst.components.entitytracker and
                                                                               inst.components.entitytracker:GetEntity("stargate") or pet):GetPosition(), true)
                        end
                        if pet.components.combat then
                            pet.components.combat:SetTarget(data.attacker)
                            pet.components.combat:SetRetargetFunction()
                            pet.components.combat:SetKeepTargetFunction()
                        end
                        pet.persists = false
                        pet.swp2hm = inst
                        table.insert(inst.stalkerswc2hms, pet)
                    end
                elseif data.attacker:HasTag("shadowminion") then
                    -- 受到老麦随从的攻击则概率招降则随从
                    inst.swchangeswp2hms[data.attacker.GUID] = true
                    if data.attacker.components.follower and data.attacker.components.combat and data.attacker.swp2hm == nil then
                        local leader = data.attacker.components.follower.leader
                        if leader and leader:IsValid() and math.random() < 0.5 then
                            data.attacker.components.follower:SetLeader(inst)
                            data.attacker.components.combat:SetTarget(leader)
                            data.attacker.components.combat:SetRetargetFunction()
                            data.attacker.components.combat:SetKeepTargetFunction()
                            data.attacker:PushEvent("transfercombattarget", leader)
                            data.attacker.swp2hm = inst
                            table.insert(inst.stalkerswc2hms, data.attacker)
                            inst.oncemiss2hm = true
                            SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(data.attacker.Transform:GetWorldPosition())
                        end
                    end
                elseif data.attacker:HasTag("swc2hm") then
                    -- 受到影分身的攻击则概率招降此影分身
                    if data.attacker.swp2hm and data.attacker.swp2hm:IsValid() then
                        inst.swchangeswp2hms[data.attacker.GUID] = true
                        if math.random() < 0.5 then
                            if data.attacker.components.combat then
                                data.attacker.components.combat:SetTarget(data.attacker.swp2hm)
                                data.attacker.components.combat:SetRetargetFunction()
                                data.attacker.components.combat:SetKeepTargetFunction()
                                data.attacker:PushEvent("transfercombattarget", data.attacker.swp2hm)
                            end
                            data.attacker.changeswp2hm = data.attacker.swp2hm
                            data.attacker.swp2hm = inst
                            table.insert(inst.stalkerswc2hms, data.attacker)
                            inst.oncemiss2hm = true
                            if data.attacker.prefab == "bernie_big" and data.attacker._taunttask then
                                data.attacker._taunttask:Cancel()
                            elseif data.attacker.prefab == "abigail" and not data.attacker.is_defensive and data.attacker.BecomeAggressive then
                                data.attacker:BecomeAggressive()
                            end
                            SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(data.attacker.Transform:GetWorldPosition())
                        end
                    end
                elseif data.attacker:HasTag("swp2hm") and data.attacker.components.childspawner2hm and
                    data.attacker.components.childspawner2hm.numchildrenoutside > 0 then
                    -- 受到有影分身本体的攻击则概率招降其的一个影分身
                    inst.swchangeswp2hms[data.attacker.GUID] = true
                    if math.random() < 0.25 then
                        for k, v in pairs(data.attacker.components.childspawner2hm.childrenoutside) do
                            if v:IsValid() and v.swp2hm and v.swp2hm == data.attacker and not v.isdead2hm and not v.changeswp2hm and
                                not inst.swchangeswp2hms[v.GUID] then
                                inst.swchangeswp2hms[v.GUID] = true
                                if v.components.combat then
                                    v.components.combat:SetTarget(data.attacker)
                                    v.components.combat:SetRetargetFunction()
                                    v.components.combat:SetKeepTargetFunction()
                                    v:PushEvent("transfercombattarget", data.attacker)
                                end
                                v.changeswp2hm = data.attacker
                                v.swp2hm = inst
                                table.insert(inst.stalkerswc2hms, v)
                                if v.prefab == "bernie_big" and v._taunttask then
                                    v._taunttask:Cancel()
                                elseif v.prefab == "abigail" and not v.is_defensive and v.BecomeAggressive then
                                    v:BecomeAggressive()
                                end
                                SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(v.Transform:GetWorldPosition())
                                break
                            end
                        end
                    end
                end
            end
            if not inst.oncemiss2hm then
                for i = #inst.stalkerswc2hms, 1, -1 do
                    local v = inst.stalkerswc2hms[i]
                    if not v:IsValid() then
                        table.remove(inst.stalkerswc2hms, i)
                    elseif v.components.combat then
                        v.components.combat:SuggestTarget(data.attacker)
                    end
                end
            end
        end
        inst.getunknownattackedindex2hm = inst.components.combat.target and 0 or (inst.getunknownattackedindex2hm or 0) + 1
        if (inst.returntogate or (inst.getunknownattackedindex2hm or 0) >= 3) and inst.sg and not inst.sg:HasStateTag("busy") then
            inst.getunknownattackedindex2hm = 0
            if not inst.miniontask and not inst.minionpoints then
                inst.components.timer:StopTimer("minions_cd")
                inst.sg:GoToState("summon_minions_pre")
            elseif not inst.hasshield then
                inst.components.timer:StopTimer("channelers_cd")
                inst.sg:GoToState("summon_channelers_pre")
            end
        end
    end
end
AddStategraphPostInit("SGstalker", function(sg)
    local idle_gate = sg.states.idle_gate.onenter
    sg.states.idle_gate.onenter = function(inst, ...)
        if not inst:HasTag("swc2hm") and inst.components.health and not inst.components.health:IsDead() and inst.components.health:GetPercent() < 1 and
            inst.components.combat and not inst.components.combat.target and inst.components.timer then
            if not inst.miniontask and not inst.minionpoints then
                inst.components.timer:StopTimer("minions_cd")
                inst.sg:GoToState("summon_minions_pre")
                return
            elseif not inst.hasshield then
                inst.components.timer:StopTimer("channelers_cd")
                inst.sg:GoToState("summon_channelers_pre")
                return
            end
        end
        idle_gate(inst, ...)
    end
end)

-- 鬼手必须不同的击杀方式
local avoiddamageways = {}
local function OnSoldiersChanged(inst) if inst.components.commander and inst.components.commander:GetNumSoldiers() <= 0 then avoiddamageways = {} end end
local swp2hmSpawnSpikes
AddPrefabPostInit("stalker_atrium", function(inst)
    inst:AddTag("stageusher")
    inst:AddTag("toughworker")
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, registerstalker)
    inst:ListenForEvent("onremove", unregisterstalker)
    inst.swchangeswp2hms = {}
    inst.stalkerswc2hms = {}
    inst:ListenForEvent("GetAttacked_Internal2hm", GetAttacked_Internal)
    inst:ListenForEvent("soldierschanged", OnSoldiersChanged)
    local SpawnSpikes = inst.SpawnSpikes
    inst.SpawnSpikes = function(inst, ...)
        local GetEntity = inst.components.entitytracker and inst.components.entitytracker.GetEntity
        if inst.components.entitytracker and not inst:HasTag("swc2hm") then inst.components.entitytracker.GetEntity = nilfn end
        SpawnSpikes(inst, ...)
        if inst.components.entitytracker then inst.components.entitytracker.GetEntity = GetEntity end
    end
    local SpawnSnares = inst.SpawnSnares
    inst.SpawnSnares = function(inst, ...)
        swp2hmSpawnSpikes = not inst:HasTag("swc2hm")
        SpawnSnares(inst, ...)
    end
end)

-- 鬼手被同种玩家的同种武器攻击时触发无敌
local function onshadowchannelerGetAttacked_Internal2hm(inst, data)
    if not hasstalker then return end
    data = data or {}
    if avoiddamageways and data and not inst.oncemiss2hm then
        for i, v in ipairs(avoiddamageways) do
            if (v.attacker == data.attacker or
                (data.attacker and data.attacker:IsValid() and not data.attacker:HasTag("player") and v.attackerprefab == data.attacker.prefab)) and
                (v.weapon == data.weapon or (data.weapon and data.weapon:IsValid() and data.weapon.prefab == v.weaponprefab)) then
                inst.oncemiss2hm = true
                SpawnPrefab("shadow_shield" .. tostring(math.random(1, 3))).entity:SetParent(inst.entity)
                return
            end
        end
        local attackdata = {}
        if data.attacker and data.attacker:IsValid() then
            attackdata.attacker = data.attacker
            attackdata.attackerprefab = data.attacker.prefab
        end
        if data.weapon and data.weapon:IsValid() then
            attackdata.weapon = data.weapon
            attackdata.weaponprefab = data.weapon.prefab
        end
        table.insert(avoiddamageways, attackdata)
    end
end
AddPrefabPostInit("shadowchanneler", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("GetAttacked_Internal2hm", onshadowchannelerGetAttacked_Internal2hm)
end)

-- 坠落之刺技能会在消失后生成固定刺,且会以织影者为中心绽放
local function onfossilspike2remove(inst)
    if POPULATING or inst.disablefossil2hm or not hasstalker then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local spike = SpawnPrefab("fossilspike")
    spike.disablefossil2hm = true
    spike.Transform:SetPosition(x, 0, z)
    spike:RestartSpike(0, 12)
end
AddPrefabPostInit("fossilspike2", function(inst)
    if not TheWorld.ismastersim then return end
    if swp2hmSpawnSpikes then inst:ListenForEvent("onremove", onfossilspike2remove) end
end)

-- 固定尖刺技能6个会有1个出现随机缺口
local delaytoggle = 1
local lasttoggle = math.random(6)
local function clearspikeindex(inst)
    delaytoggle = 1
    lasttoggle = math.random(6)
    inst.clearspiketask2hm = nil
end
AddPrefabPostInit("fossilspike", function(inst)
    if not TheWorld.ismastersim then return end
    local RestartSpike = inst.RestartSpike
    inst.RestartSpike = function(inst, ...)
        if POPULATING or inst.disablefossil2hm or not hasstalker then return RestartSpike(inst, ...) end
        local stalker = stalkers[1]
        if stalker and stalker:IsValid() and not stalker.clearspiketask2hm then stalker.clearspiketask2hm = stalker:DoTaskInTime(0, clearspikeindex) end
        delaytoggle = delaytoggle + 1
        if delaytoggle >= 7 then
            delaytoggle = 1
            lasttoggle = math.random(6)
        end
        if delaytoggle ~= lasttoggle then return RestartSpike(inst, ...) end
        local x, y, z = inst.Transform:GetWorldPosition()
        inst:Remove()
        local spike = SpawnPrefab("fossilspike2")
        spike.disablefossil2hm = true
        spike.Transform:SetPosition(x, y, z)
        spike:RestartSpike(0)
    end
end)

if TUNING.DSTU then
    local function disablePhysics(inst) if inst.Physics and not TheWorld:HasTag("cave") then RemovePhysicsColliders(inst) end end
    AddPrefabPostInit("stalker_minion", disablePhysics)
    AddPrefabPostInit("stalker_minion1", disablePhysics)
    AddPrefabPostInit("stalker_minion2", disablePhysics)
end

-- 远古之门
local function handcatch(inst)
    if inst:IsValid() and inst._owner and inst._owner:IsValid() and inst._target and inst._target:IsValid() and inst:IsNear(inst._target, 1) and inst.owner2hm and
        inst.owner2hm:IsValid() then
        inst._destination_steps = 0
        SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(inst._target.Transform:GetWorldPosition())
        inst._target:AddChild(SpawnPrefab("shadow_teleport_out2hm"))
        inst._target.Transform:SetPosition(inst.owner2hm.Transform:GetWorldPosition())
        inst._target:PushEvent("knockback", {
            knocker = inst._owner,
            radius = 3,
            strengthmult = (inst._target.components.inventory ~= nil and inst._target.components.inventory:ArmorHasTag("heavyarmor") or
                inst._target:HasTag("heavybody")) and 0.35 or 0.7,
            forcelanded = false
        })
    end
end
local function ongatefar2hm(inst, target)
    local stalker = inst.components.entitytracker and inst.components.entitytracker:GetEntity("stalker")
    if stalker and stalker:IsValid() and stalker.components.health and not stalker.components.health:IsDead() and target and target:IsValid() and
        target.components.health and not target.components.health:IsDead() and not target:HasTag("playerghost") and
        not (inst.hand2hm and inst.hand2hm:IsValid()) then
        local ipos = inst:GetPosition()
        local tpos = target:GetPosition()
        local unit_target_vec = (tpos - ipos):GetNormalized()
        local hand = SpawnPrefab("stageusher_attackhand")
        hand.Physics:SetMotorVel(TUNING.STAGEUSHER_ATTACK_SPEED * 2, 0, 0)
        inst.hand2hm = hand
        hand.persists = false
        hand.Transform:SetPosition((ipos + unit_target_vec * 0.5):Get())
        hand:SetOwner(stalker)
        hand:SetCreepTarget(target)
        hand.owner2hm = inst
        if hand.components.updatelooper then hand.components.updatelooper:AddOnUpdateFn(handcatch) end
        if inst.on_hand_removed2hm == nil then inst.on_hand_removed2hm = function(hand) inst.hand2hm = nil end end
        inst:ListenForEvent("onremove", inst.on_hand_removed2hm, hand)
    end
end
AddPrefabPostInit("atrium_gate", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.playerprox2hm then inst:AddComponent("playerprox2hm") end
    inst.components.playerprox2hm:SetTargetMode(inst.components.playerprox2hm.TargetModes.AllPlayers)
    inst.components.playerprox2hm:SetDist(10, 18)
    inst:ListenForEvent("onfar2hm", ongatefar2hm)
end)

-- local function ongatetrade(inst) CreateMiasma2hm(inst, true) end
-- AddPrefabPostInit("atrium_gate", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:ListenForEvent("trade", ongatetrade)
-- end)
-- AddStategraphPostInit("SGstalker", function(sg)
--     local oldOnEnteridle = sg.states.idle.onenter
--     sg.states.idle.onenter = function(inst, ...)
--         oldOnEnteridle(inst, ...)
--         if inst:HasTag("swc2hm") then return end
--     end
--     -- -- 化石骨刺
--     -- local oldOnEnterspikes = sg.states.spikes.onenter
--     -- sg.states.spikes.onenter = function(inst, ...) oldOnEnterspikes(inst, ...) end
--     -- 化石笼子
--     local oldOnEntersnare = sg.states.snare.onenter
--     sg.states.snare.onenter = function(inst, ...)
--         oldOnEntersnare(inst, ...)
--         if inst.prefab == "stalker_atrium" and not inst:HasTag("swc2hm") and inst.sg.statemem.targets then
--             for i, v in ipairs(inst.sg.statemem.targets) do
--                 if v and v:IsValid() and v:IsNear(inst, TUNING.STALKER_SNARE_MAX_RANGE) then CreateMiasma2hm(v) end
--             end
--         end
--     end
--     -- -- 编织暗影
--     -- local oldOnEntersummon_minions_pre = sg.states.summon_minions_pre.onenter
--     -- sg.states.summon_minions_pre.onenter = function(inst, ...) oldOnEntersummon_minions_pre(inst, ...) end
--     -- -- 看不见的手
--     -- local oldOnEntersummon_channelers_pre = sg.states.summon_channelers_pre.onenter
--     -- sg.states.summon_channelers_pre.onenter = function(inst, ...) oldOnEntersummon_channelers_pre(inst, ...) end
-- end)
-- local function onstalker_minion(inst) CreateMiasma2hm(inst) end
-- AddPrefabPostInit("stalker_minion", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:DoTaskInTime(0, onstalker_minion)
--     inst:ListenForEvent("trade", onstalker_minion)
-- end)
-- local function newshadowchanneler(inst) CreateMiasma2hm(inst, true) end
-- AddPrefabPostInit("shadowchanneler", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:DoTaskInTime(0, newshadowchanneler)
-- end)

------------------------------------------------------------------------------------------------
-- ==================== 只因拟态梅 ====================
-- 吃下后永久获得"缓伤":受到伤害不直接掉血,而是存起来每0.3秒扣这次的10%(3秒内分10次扣完),

STRINGS.NAMES.DEVIL_HEART2HM = TUNING.isCh2hm and "只因拟态梅" or "Mimic Nightberry"
STRINGS.RECIPE_DESC.DEVIL_HEART2HM = TUNING.isCh2hm and "受到的伤害会缓慢结算,不再会被秒杀" or "Damage taken settles slowly. Never get one-shot again."


AddRecipe2("devil_heart2hm",
    {Ingredient("voidcloth", 4), Ingredient("ancientfruit_nightvision", 4)},
    TECH.SHADOWFORGING_TWO,
    {nounlock = true, station_tag = "shadow_forge", image = "ancientfruit_nightvision.tex"})


AddPrefabPostInit("stalker_atrium", function(inst)
    if not TheWorld.ismastersim then return end
    local lootdropper = inst.components.lootdropper
    if lootdropper == nil then return end
    local oldsetupfn = lootdropper.lootsetupfn
    lootdropper.lootsetupfn = function(ld)
        if oldsetupfn ~= nil then oldsetupfn(ld) end
        if ld.inst == nil or not ld.inst.atriumdecay then
            ld:AddChanceLoot("devil_heart2hm", 1)
        end
    end
end)

local DEVILHEART_KEY2HM = "devil_heart2hm"
local DEVILHEART_TICK2HM = 0.3 -- 每0.3秒结算一次
local DEVILHEART_RATE2HM = 0.1 -- 每次结算本次伤害的10%
local DEVILHEART_COUNT2HM = 10 -- 共10次


local function StartDevilHeartSlowDamage2hm(owner, total, cause)
    if total <= 0 or total ~= total or total == math.huge then return end
    local per = total * DEVILHEART_RATE2HM
    local ticks = 0
    local task
    task = owner:DoPeriodicTask(DEVILHEART_TICK2HM, function()
        if owner == nil or not owner:IsValid() or owner.components.health == nil then
            if task ~= nil then task:Cancel() end
            return
        end
        ticks = ticks + 1
        local chunk
        if ticks < DEVILHEART_COUNT2HM then
            chunk = per
        else
            chunk = total - per * (DEVILHEART_COUNT2HM - 1) 
        end
        if chunk > 0 then
            owner._devilheart_ticking2hm = true
            owner.components.health:DoDelta(-chunk, nil, cause or DEVILHEART_KEY2HM, nil, nil, true)
            owner._devilheart_ticking2hm = false
        end
        if ticks >= DEVILHEART_COUNT2HM and task ~= nil then
            task:Cancel()
        end
    end)
end


AddComponentPostInit("health", function(self)
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        local owner = self.inst
        if owner ~= nil and owner._devilheart_buff2hm and type(amount) == "number" and amount < 0
            and amount ~= -math.huge then
            if not owner._devilheart_ticking2hm -- 缓伤自己的扣血放行
                and cause ~= "builder"
                and cause ~= "oldager_component" -- 旺达的伤害走衰老结算,拦了血量会被年龄锁死
                and (ignore_invincible or (not self:IsInvincible() and not owner.is_teleporting))
                and not self:IsDead() then
                if self.redirect ~= nil and self.redirect(owner, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb) then
                    return 0
                end
                if not ignore_absorb then
                    amount = amount * math.clamp(1 - (self.playerabsorb ~= 0 and afflicter ~= nil and afflicter:HasTag("player") and self.playerabsorb + self.absorb or self.absorb), 0, 1) * math.max(1 - self.externalabsorbmodifiers:Get(), 0)
                    amount = afflicter ~= nil and math.min(0, amount + self.externalreductionmodifiers:Get()) or amount
                end
                if self.deltamodifierfn ~= nil then
                    amount = self.deltamodifierfn(owner, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
                end
                if self.maxdamagetakenperhit ~= nil and amount < self.maxdamagetakenperhit and not self._ignore_maxdamagetakenperhit then
                    amount = self.maxdamagetakenperhit
                end
                if amount < 0 then
                    StartDevilHeartSlowDamage2hm(owner, -amount, cause)
                end
                return 0
            end
        end
        return oldDoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
end)

AddPrefabPostInit("devil_heart2hm", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.edible then return end
    local oldoneaten = inst.components.edible.oneaten
    inst.components.edible.oneaten = function(inst, eater, ...)
        if oldoneaten then oldoneaten(inst, eater, ...) end
        if eater and eater:IsValid() and eater:HasTag("player") then
            if not eater.components.persistent2hm then eater:AddComponent("persistent2hm") end
            eater.components.persistent2hm.data = eater.components.persistent2hm.data or {}
            eater.components.persistent2hm.data[DEVILHEART_KEY2HM] = true
            eater._devilheart_buff2hm = true
        end
    end
end)

-- 重进游戏/复活后恢复永久buff
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    local function tryapply(p)
        if p.components.persistent2hm and p.components.persistent2hm.data and p.components.persistent2hm.data[DEVILHEART_KEY2HM] then
            p._devilheart_buff2hm = true
        end
    end
    tryapply(inst)
    SetOnLoad2hm(inst, function(p, data)
        if data and data[DEVILHEART_KEY2HM] then
            tryapply(p)
        end
    end)
end)

