local words = {
    ["timer_attack"] = {
        ch = "你将滋养我的愤怒",
        en = "my anger grows",
    },
    ["timer_attack_2"] = {
        ch = "你所做的一切都是徒劳!",
        en = "you can do nothing!",
    },
}

local function GetWord(prefab, key)
    if TUNING.isCh2hm then
        if words[key] then
            if words[key][prefab] then
                return words[key][prefab].ch or words[key].ch
            else
                return words[key].ch
            end
        end
    else
        if words[key] then
            if words[key][prefab] then
                return words[key][prefab].en or words[key].en
            else
                return words[key].en
            end
        end
    end
end

local function DoInterval(inst, key, intervalTime)
    if intervalTime then
        local nowTime = GetTime()
        local time = inst.epicarmor2hm.intervalTimes[key]
        if not time or nowTime - time > intervalTime then
            inst.epicarmor2hm.intervalTimes[key] = nowTime
            return true
        else
            return false
        end
    end
    return true
end

local function PlaySound(inst, intervalTime, sound)
    if not DoInterval(inst, "sound_" .. sound, intervalTime) then return end
    if sound and inst.SoundEmitter ~= nil and not inst:IsInLimbo() then
        inst.SoundEmitter:PlaySound(sound)
    end
end

local function SayWord(inst, key, intervalTime)
    if not DoInterval(inst, "word_" .. key, intervalTime) then return end
    local words = GetWord(inst.prefab, key)
    if words and inst.components.talker then
        inst.components.talker:Say(words)
    end
end

local modifyCombat = function(inst)
    if inst.components.combat then
        local oldGetAttacked_Internal = inst.components.combat.GetAttacked_Internal
        inst.components.combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage)
            if inst:IsAsleep() or attacker and attacker.prefab == "shadowmeteor2hm" then
                return true
            else
                return oldGetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage)
            end
        end
    end
end

local epic_armor_rate = GetModConfigData("epic_armor_5")

local epic_level = {
    [1] = {baseRate = 0.4, floatRate = 0, timerRate = 0.1, maxTime = 10, fadeTime = 30, energyTime = 1, recoverRate = 0, ingoreTag = {"epic"}, disablelaunchMeteor = true},
    [2] = {baseRate = 0.4, floatRate = 0.02, timerRate = 0.1, maxTime = 25, fadeTime = 60, energyTime = 2, recoverRate = 0, ingoreTag = {"epic"}, disablelaunchMeteor = true},
    [3] = {baseRate = 0.3, floatRate = 0.05, timerRate = 0.2, maxTime = 45, fadeTime = 100, energyTime = 3, recoverRate = 0.05, ingoreTag = {}, size = "super"},
    [4] = {baseRate = 0.3, floatRate = 0.05, timerRate = 0.3, maxTime = 120, fadeTime = 120, energyTime = 5, recoverRate = 0.2, ingoreTag = {}, size = "super"},
    [5] = {baseRate = 0.15, floatRate = 0.05, timerRate = 1, maxTime = 480, fadeTime = 1000000, energyTime = 10, recoverRate = 1, ingoreTag = {}, size = "super"},
}

local epic_data = epic_armor_rate and epic_level[math.clamp(epic_armor_rate, 1, 5)] or nil

local HIT_BY_EXPLOSION_MUST_TAGS = {"player"}
local HIT_BY_EXPLOSION_CANT_TAGS = {"DECOR", "FX", "flight", "INLIMBO", "invisible", "lunar_aligned", "noattack", "NOCLICK", "notarget", "playerghost"}
local HIT_BY_EXPLOSION_ONEOF_TAGS = {"animal", "character", "monster", "structure"}
local WORK_BY_EXPLOSION_ONEOF_TAGS = {"CHOP_workable", "DIG_workable", "HAMMER_workable", "MINE_workable"}

local launchMeteor = function(target, x, y, z)
    if target and target:IsValid() and target.Transform then
        x, y, z = target.Transform:GetWorldPosition()
    end
    local met = SpawnPrefab("shadowmeteor2hm")
    met:SetSize(epic_data.size or "medium", 1)
    met.loot = {}
    met.Transform:SetPosition(x, y, z)
end

local launchRandomMeteor = function(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local met = SpawnPrefab("shadowmeteor2hm")
    met:SetSize(epic_data.size or "medium", 1)
    met.loot = {}
    local offset = 5 + math.random() * 10
    local theta = math.random() * TWOPI
    met.Transform:SetPosition(x + math.cos(theta) * offset, 0, z + math.sin(theta) * offset)
end

local makeInvEffect = function(inst)
    if not inst.epicarmor2hm._fx or inst.epicarmor2hm._fx:IsValid() then
        inst.epicarmor2hm._fx = SpawnPrefab("forcefieldfx")
        local range = inst:GetPhysicsRadius(0.2) + 1
        if inst.components.weapon then
            range = range + (inst.components.weapon:GetAttackRange() or 0)
        end
        inst.epicarmor2hm._fx.entity:SetParent(inst.entity)
        inst.epicarmor2hm._fx:AddTag("NOCLICK")
        inst.epicarmor2hm._fx:AddTag("FX")
        inst.epicarmor2hm._fx.Transform:SetPosition(0, range + 0.2, 0)
        inst.epicarmor2hm._fx.Transform:SetScale(range, range, range)
    end
end

local doDeltaList = function(inst, delta, afflicter)
    if afflicter and type(afflicter) == "table" then
    else
        return
    end
    if afflicter:HasAnyTag(epic_data.ingoreTag) then
        return
    end
    local spawnmeteor = true
    if afflicter.prefab == "shadowmeteor2hm" or afflicter:HasTag("epic") then
        spawnmeteor = false
    end
    inst.epicarmor2hm.totalDelta = inst.epicarmor2hm.totalDelta + delta
    local time = GetTime()
    table.insert(inst.epicarmor2hm.deltaList, {delta = delta, time = time})
    while #inst.epicarmor2hm.deltaList > 0 do
        if time - inst.epicarmor2hm.deltaList[1].time > epic_data.fadeTime then
            inst.epicarmor2hm.totalDelta = inst.epicarmor2hm.totalDelta - inst.epicarmor2hm.deltaList[1].delta
            table.remove(inst.epicarmor2hm.deltaList, 1)
        else
            break
        end
    end
    if inst.components.health then
        if inst.epicarmor2hm.timer then
            inst.epicarmor2hm.overDelta = inst.epicarmor2hm.overDelta + delta
            -- SayWord(inst, "timer_attack", 2)
            if not epic_data.disablelaunchMeteor and afflicter.Transform and spawnmeteor and DoInterval(inst, "spawnmeteor1", 1) then
                for i = 1, 1 + math.random(2) do
                    if afflicter:IsValid() and afflicter.Transform then
                        local x, y, z = afflicter.Transform:GetWorldPosition()
                        inst:DoTaskInTime(math.random() * 1 + i, function()
                            launchMeteor(afflicter, x, y, z)
                        end)
                    end
                end
            end
            PlaySound(inst, 3, "dontstarve/common/together/atrium_gate/shadow_pulse")
        elseif inst.components.timer:TimerExists("invincible2hm") then
            -- SayWord(inst, "timer_attack_2", 2)
            -- if spawnmeteor then
            if not epic_data.disablelaunchMeteor and DoInterval(inst, "spawnmeteor2", 1) then
                for i = 1, 1 + math.random(2) do
                    inst:DoTaskInTime(math.random() * 1 + i, function()
                        launchRandomMeteor(inst)
                    end)
                end
            end
            --end
            if epic_data.recoverRate > 0 then
                PlaySound(inst, 5, "dontstarve/common/rebirth_amulet_raise")
            end
        else
            local keyValue = inst.components.health.maxhealth * (math.min(epic_data.baseRate, inst.prefab == "crabking" and 0.3 or 0.5) + inst.epicarmor2hm.randomExRate)
            if inst.epicarmor2hm.totalDelta >= keyValue then
                if inst.epicarmor2hm.dmgTaken < keyValue and inst.epicarmor2hm.dmgTaken + delta >= keyValue then
                    inst.epicarmor2hm.mustDmg = keyValue - inst.epicarmor2hm.dmgTaken
                end
                inst.epicarmor2hm.overDelta = math.max(inst.epicarmor2hm.totalDelta - keyValue, 10 / epic_data.timerRate)
                PlaySound(inst, 3, "dontstarve/common/together/atrium_gate/shadow_pulse")
                inst.epicarmor2hm.timer = inst:DoTaskInTime(epic_data.energyTime, function()
                    inst.epicarmor2hm.timer = nil
                    local invTime = math.min(inst.epicarmor2hm.overDelta * epic_data.timerRate, epic_data.maxTime)
                    if inst.components.timer:TimerExists("invincible2hm") then
                        inst.components.timer:SetTimeLeft("invincible2hm", invTime)
                    else
                        if inst.prefab == "crabking" and inst:HasTag("icewall") and not inst.epic_armor2hm then
                            local iceEndTime
                            local time = math.max(3, Remap(inst.gemcount.blue, 0, 11, 25, 3 ))
                            if inst.firstwallbreaktime2hm and type(inst.firstwallbreaktime2hm) == "number" then
                                iceEndTime = time - (GetTime() - inst.firstwallbreaktime2hm)
                            end
                            if iceEndTime ~= nil then
                                invTime = math.max(invTime, iceEndTime)
                                inst.epic_armor2hm = true
                            end
                        end
                        inst.components.timer:StartTimer("invincible2hm", invTime)
                    end
                    makeInvEffect(inst)
                    if epic_data.disablelaunchMeteor then return end
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local ents = TheSim:FindEntities(x, y, z, 20, HIT_BY_EXPLOSION_MUST_TAGS, HIT_BY_EXPLOSION_CANT_TAGS, HIT_BY_EXPLOSION_ONEOF_TAGS)
                    local entNum = 5
                    for _, ent in pairs(ents) do
                        entNum = entNum - 1
                        if entNum == 0 then break end
                        for i = 1, 3 do
                            if ent and ent:IsValid() and ent.Transform then
                                local x, y, z = ent.Transform:GetWorldPosition()
                                inst:DoTaskInTime(math.random() * 3 + i * 3, function()
                                    launchMeteor(ent, x, y, z)
                                end)
                            end
                        end
                    end
                    local ents = TheSim:FindEntities(x, y, z, 20, nil, HIT_BY_EXPLOSION_CANT_TAGS, WORK_BY_EXPLOSION_ONEOF_TAGS)
                    local entNum = 5
                    for _, ent in pairs(ents) do
                        entNum = entNum - 1
                        if entNum == 0 then break end
                        for i = 1, 2 do
                            if ent and ent:IsValid() and ent.Transform then
                                local x, y, z = ent.Transform:GetWorldPosition()
                                inst:DoTaskInTime(math.random() * 3 + i * 3, function()
                                    launchMeteor(ent, x, y, z)
                                end)
                            end
                        end
                    end
                    for i = 1, 10 do
                        inst:DoTaskInTime(math.random() * 1 + i, function()
                            launchRandomMeteor(inst)
                        end)
                    end
                end)
            else
                inst.epicarmor2hm.dmgTaken = inst.epicarmor2hm.dmgTaken + delta
            end
        end
    end
end

local modifyHealth = function(inst)
    inst.epicarmor2hm = {}
    inst.epicarmor2hm.intervalTimes = {}
    inst.epicarmor2hm.deltaList = {}
    inst.epicarmor2hm.dmgTaken = 0
    inst.epicarmor2hm.totalDelta = 0
    inst.epicarmor2hm.overDelta = 0
    inst.epicarmor2hm.randomExRate = (math.random() - 0.5) * epic_data.floatRate
    if inst.components.health then
        local oldSetVal = inst.components.health.SetVal
        inst.components.health.SetVal = function(self, val, cause, afflicter)
            local delta = self.currenthealth - val
            if delta > 0 then
                doDeltaList(inst, delta, afflicter)
                if inst.epicarmor2hm.timer then
                    if inst.epicarmor2hm.mustDmg then
                        local mustDmg = inst.epicarmor2hm.mustDmg
                        inst.epicarmor2hm.mustDmg = nil
                        return oldSetVal(self, self.currenthealth - mustDmg, cause, afflicter)
                    else
                        return oldSetVal(self, self.currenthealth, cause, afflicter)
                    end
                elseif inst.components.timer:TimerExists("invincible2hm") then
                    return oldSetVal(self, self.currenthealth + delta * epic_data.recoverRate, cause, afflicter)
                else
                    return oldSetVal(self, val, cause, afflicter)
                end
            else
                return oldSetVal(self, val, cause, afflicter)
            end
        end
    end
end

local onTimeDone = function(inst, data)
    if data and data.name == "invincible2hm" then
        inst.epicarmor2hm.deltaList = {}
        inst.epicarmor2hm.totalDelta = 0
        inst.epicarmor2hm.dmgTaken = 0
        inst.epicarmor2hm.overDelta = 0
        inst.epicarmor2hm.randomExRate = (math.random() - 0.5) * epic_data.floatRate
        if inst.epicarmor2hm._fx then
            if inst.epicarmor2hm._fx:IsValid() then
                inst.epicarmor2hm._fx:Remove()
            end
            inst.epicarmor2hm._fx = nil
        end
    end
end

local whitelist = {"crabking"}
for i, v in pairs(whitelist) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.timer then
            inst:AddComponent("timer")
        end
        inst:DoTaskInTime(0, function()
            modifyCombat(inst)
            if inst:HasTag("swc2hm") then return end
            if epic_data then
                inst:ListenForEvent("timerdone", onTimeDone)
                modifyHealth(inst)
                if inst.components.timer and inst.components.timer:TimerExists("invincible2hm") then
                    makeInvEffect(inst)
                end
            end
        end)
    end)
end

local ignoreBossList = {
    ["lordfruitfly"] = true,
    ["antlion"] = true,
}

AddPrefabPostInitAny(function(inst)
    if not inst:HasTag("epic") then return end
    if not TheWorld.ismastersim then return end
    if not inst.components.timer then
        inst:AddComponent("timer")
    end
    inst:DoTaskInTime(0, function()
        modifyCombat(inst)
        if ignoreBossList[inst.prefab] then return end
        if inst:HasTag("swc2hm") then return end
        if epic_data then
            inst:ListenForEvent("timerdone", onTimeDone)
            modifyHealth(inst)
            if inst.components.timer and inst.components.timer:TimerExists("invincible2hm") then
                makeInvEffect(inst)
            end
        end
    end)
end)
