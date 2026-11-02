-- 采集或挖浆果丛概率出现火鸡,火鸡会主动攻击了;采集草会概率出现草蜥蜴,攻击了;采集或铲石果会概率出现沙拉蝾螈,主动攻击;海带采集或移植时出现触手袭击
local function OnPerdAttacked(inst, data) inst.components.combat:SetTarget(data.attacker) end
AddPrefabPostInit("perd", function(inst)
    -- if inst.Transform then inst.Transform:SetScale(0.7, 0.7, 0.7) end
    if not TheWorld.ismastersim then return end
    -- if inst.components.combat then inst.components.combat.attackrange = inst.components.combat.attackrange * 0.5 end
    if inst.components.health and inst.components.health.maxhealth < 200 then inst.components.health:SetMaxHealth(200) end
    inst:ListenForEvent("attacked", OnPerdAttacked)
end)

require("behaviours/chaseandattack")
AddBrainPostInit("perdbrain", function(self)
    local Attack = ChaseAndAttack(self.inst, 10)
    table.insert(self.bt.root.children, 4, Attack)
end)

local danger_plants = {
    reeds = {pickable = {merm = 0.01, tentacle = 0.1}},
    berrybush = {pickable = {perd = 0.01}, workable = {perd = 0.05}},
    berrybush2 = {pickable = {perd = 0.01}, workable = {perd = 0.05}},
    berrybush_juicy = {pickable = {perd = 0.01}, workable = {perd = 0.05}},
    skeleton = {workable = {ghost = 0.45}},
    skeleton_player = {workable = {ghost = 0.25}},
    dead_sea_bones = {workable = {ghost = 0.25}},
    driftwood_small1 = {workable = {slurtle = 0.15}},
    driftwood_small2 = {workable = {slurtle = 0.15}},
    bananabush = {pickable = {powder_monkey = 0.01}, workable = {powder_monkey = 0.1}},
    monkeytail = {pickable = {powder_monkey = 0.01}, workable = {powder_monkey = 0.1}},
    rock_avocado_bush = {pickable = {fruitdragon = 1, gestalt = 0.05, lunar_grazer = 0.001}, workable = {fruitdragon = 1, gestalt = 0.05, lunar_grazer = 0.01}},
    bullkelp_plant = {pickable = {tentacle = 0.01}},
    bullkelp_beachedroot = {pickable = {tentacle = 0.35}},
    evergreen = {
        -- 海狸啃不出来蝙蝠
        validfn = function(inst, doer)
            return (not TheWorld.state.isday or TheWorld:HasTag("cave")) and inst.components.growable and inst.components.growable.stage >= 3 and
                       not (doer.weremode and doer.weremode:value() == 1)
        end,
        workable = {bat = 0.1}
    },
    evergreen_sparse = {
        validfn = function(inst, doer)
            return (not TheWorld.state.isday or TheWorld:HasTag("cave")) and inst.components.growable and inst.components.growable.stage >= 3 and
                       not (doer.weremode and doer.weremode:value() == 1)
        end,
        workable = {bat = 0.1}
    },
    moonglass_rock = {workable = {moon_fissure = 0.05, gestalt = 0.45}},
    deciduoustree = {
        validfn = function(inst, doer)
            return inst.components.growable and inst.components.growable.stage >= 3 and not (doer.weremode and doer.weremode:value() == 1)
        end,
        workable = {birchnutdrake = 0.1}
    }
}

local monsters_pre = {
    lunar_grazer = function(inst, target)
        local grazer = SpawnPrefab("lunar_grazer")
        grazer.Transform:SetPosition(inst.Transform:GetWorldPosition())
        grazer:OnSpawnedBy(inst, 1)
        grazer.components.combat:SetTarget(target)
        grazer.persists = false
        grazer:DoTaskInTime(3600, grazer.Remove)
    end,
    tentacle = function(inst, target)
        local monster = SpawnPrefab("tentacle")
        if monster then
            monster.Transform:SetPosition(inst.Transform:GetWorldPosition())
            monster.components.combat:SetTarget(target)
            monster.components.combat:TryAttack()
            monster.sg:GoToState("attack_pre")
        end
    end,
    merm = function(inst, target)
        if target and target.prefab == "wurt" then return end
        local monster = SpawnMonster2hm(target, "prefab", 20, false)
        if monster and monster.components.combat then monster.components.combat:SetTarget(target) end
    end,
    fruitdragon = function(inst, target)
        if target and target.components.sanity and target.components.sanity.mode == SANITY_MODE_LUNACY then
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, TUNING.FRUITDRAGON.CHALLENGE_DIST * 2, {"fruitdragon"})
            for index, ent in ipairs(ents) do if ent and ent.components.combat then ent.components.combat:SetTarget(target) end end
        end
    end,
    moon_fissure = function(inst, target)
        local moon_fissure = SpawnPrefab("moon_fissure")
        if moon_fissure and moon_fissure.Transform then moon_fissure.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
    end
}

local monsters_instpos = {"perd", "bat", "ghost", "slurtle", "gestalt", "moon_fissure", "birchnutdrake"}

local function processmonster(name, inst, target)
    local monster
    if monsters_pre[name] then
        monster = monsters_pre[name](inst, target)
    elseif table.contains(monsters_instpos, name) then
        monster = SpawnPrefab(name)
        if monster then
            -- monster.persists = false
            if monster.Transform then monster.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
            if monster.components.combat then
                monster.components.combat:SetTarget(target)
                monster.components.combat:TryAttack()
            end
        end
    else
        monster = SpawnMonster2hm(target, name, 20, false)
        if monster and monster.components.combat then
            -- monster.persists = false
            monster.components.combat:SetTarget(target)
        end
    end
end

local function onpicked(inst, data)
    local dangerdata = danger_plants[inst.prefab]
    if data and data.picker and data.picker:HasTag("character") and dangerdata and dangerdata.pickable and
        (dangerdata.validfn == nil or dangerdata.validfn(inst, data.picker)) then
        for monster, chance in pairs(dangerdata.pickable) do
            if math.random() < chance then
                processmonster(monster, inst, data.picker)
                break
            end
        end
    end
end

-- 海带兼容
local function onpickup(inst, data)
    local dangerdata = danger_plants[inst.prefab]
    if data and data.owner and data.owner:HasTag("character") and dangerdata and dangerdata.pickable and
        (dangerdata.validfn == nil or dangerdata.validfn(inst, data.owner)) then
        for monster, chance in pairs(dangerdata.pickable) do
            if math.random() < chance then
                processmonster(monster, inst, data.owner)
                break
            end
        end
    end
end

local function onworkable(inst, data)
    local dangerdata = danger_plants[inst.prefab]
    if data and data.worker and data.worker:HasTag("character") and dangerdata and dangerdata.workable and
        (dangerdata.validfn == nil or dangerdata.validfn(inst, data.worker)) then
        for monster, chance in pairs(dangerdata.workable) do
            if math.random() < chance then
                processmonster(monster, inst, data.worker)
                break
            end
        end
    end
end

for plant, _ in pairs(danger_plants) do
    AddPrefabPostInit(plant, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.pickable and danger_plants[plant].pickable then
            inst:ListenForEvent("picked", onpicked)
        elseif inst.components.inventoryitem and danger_plants[plant].pickable then
            inst:ListenForEvent("onpickup", onpickup)
        end
        -- inst:ListenForEvent("workfinished", onworkable)
        if inst.components.workable and danger_plants[plant].workable then
            local oldonfinish = inst.components.workable.onfinish
            inst.components.workable.onfinish = function(inst, worker, ...)
                onworkable(inst, {worker = worker})
                if oldonfinish then oldonfinish(inst, worker, ...) end
            end
        end
    end)
end

-- 狡兔三窟
-- local function rabbitgetattack(inst, data)
--     if not inst:HasTag("swc2hm") and math.random() < (1 - (inst.dodgelevel2hm or 0) * 0.2) then
--         inst.oncemiss2hm = true
--         inst.dodgelevel2hm = math.max((inst.dodgelevel2hm or 0) + 1, 3)
--         inst:PushEvent("attacked", {attacker = data and data.attacker, damage = 0})
--     end
-- end
TUNING.RABBIT_HEALTH = TUNING.BEE_HEALTH
TUNING.MOLE_HEALTH = TUNING.BEE_HEALTH
local function removerabbit(inst)
    if inst and inst:IsValid() and not inst:IsInLimbo() and inst:IsAsleep() and inst.components.knownlocations and
        inst.components.knownlocations:GetLocation("home") == nil then inst:Remove() end
end
local function delayremoverabbit(inst)
    if inst and inst:IsValid() and not inst:IsInLimbo() and not inst:HasTag("swc2hm") then inst:DoTaskInTime(10, removerabbit) end
end
AddPrefabPostInit("rabbit", function(inst)
    if not TheWorld.ismastersim then return end
    -- inst:ListenForEvent("GetAttacked_Internal2hm", rabbitgetattack)
    inst:ListenForEvent("entitysleep", delayremoverabbit)
end)

-- local function delayflyaway(inst, rot)
--     inst:PushEvent("flyaway")
--     if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ~= "flyaway" then
--         if inst and inst.components.health and not inst.components.health:IsDead() and inst.components.locomotor and inst.sg then
--             if rot then inst.Transform:SetRotation(rot) end
--             inst:StopBrain()
--             inst.components.locomotor:SetExternalSpeedMultiplier(inst, "rabbit2hm", 3)
--             if inst.endspeeduptask2hm then inst.endspeeduptask2hm:Cancel() end
--             inst.endspeeduptask2hm = inst:DoTaskInTime(0.25, endspeedup)
--             inst.components.locomotor:RunForward()
--         end
--     end
-- end

-- local function birdflyaway(inst, data)
--     if not inst:HasTag("swc2hm") and math.random() < (0.5 - (inst.dodgelevel2hm or 0) * 0.1) then
--         inst.oncemiss2hm = true
--         inst.dodgelevel2hm = math.max((inst.dodgelevel2hm or 0) + 1, 3)
--         local rot = data and data.attacker and data.attacker:IsValid() and (inst:GetAngleToPoint(data.attacker.Transform:GetWorldPosition()) - 180)
--         inst:DoTaskInTime(0, delayflyaway, rot)
--     end
-- end
-- AddPrefabPostInitAny(function(inst)
--     if not TheWorld.ismastersim then return end
--     if inst:HasTag("bird") and inst:HasTag("smallcreature") and inst.components.locomotor then inst:ListenForEvent("GetAttacked_Internal2hm", birdflyaway) end
-- end)
