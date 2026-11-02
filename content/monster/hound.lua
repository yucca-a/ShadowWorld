local hardmodeindex = GetModConfigData("warg")
if hardmodeindex == true then hardmodeindex = -2 end

-- 为爽附身座狼改动
-- 附身座狼喷火时被月亮武器连续攻击2次就会疲惫
local TARGETS_MUST = {"_combat"}
local TARGETS_CANT = {"INLIMBO", "flight", "invisible", "playerghost", "lunar_aligned"}
local FLAME_MUST = {"willow_shadow_flame"}
local function newshadowflamesettarget(inst, _, life, source)
    if life > 0 and source:IsValid() and not (source.components.health ~= nil and source.components.health:IsDead()) and source.components.combat then
        inst.shadowfire_task = inst:DoTaskInTime(0.05, function()
            local pos = Vector3(inst.Transform:GetWorldPosition())
            local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 1, TARGETS_MUST, TARGETS_CANT)
            if inst.targets2hm == nil then inst.targets2hm = {} end
            local targets = inst.targets2hm
            if #ents > 0 then
                source.components.combat.ignorehitrange = true
                source.components.combat.ignoredamagereflect = true
                for i, ent in ipairs(ents) do
                    if not targets[ent] and ent:IsValid() and not ent:IsInLimbo() and not (ent.components.health ~= nil and ent.components.health:IsDead()) then
                        SpawnPrefab("willow_shadow_fire_explode").Transform:SetPosition(ent.Transform:GetWorldPosition())
                        source.components.combat:DoAttack(ent)
                        targets[ent] = true
                    end
                end
                source.components.combat.ignorehitrange = false
                source.components.combat.ignoredamagereflect = false
            end
            local fire = SpawnPrefab("willow_shadow_flame")
            fire.burst2hm = inst.burst2hm
            local angle
            if inst.theta2hm > PI / 4 then
                angle = -1
            elseif inst.theta2hm < -PI / 4 then
                angle = 1
            else
                angle = (math.random() * 2) - 1
            end
            fire.startangle2hm = inst.startangle2hm
            fire.theta2hm = inst.theta2hm + PI * angle / 6
            local theta = fire.startangle2hm + fire.theta2hm
            local offset = Vector3(math.cos(theta), 0, -math.sin(theta))
            local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
            fire.Transform:SetRotation(theta / DEGREES)
            fire.Transform:SetPosition(newpos.x, newpos.y, newpos.z)
            fire.targets2hm = inst.targets2hm or {}
            fire.settarget = newshadowflamesettarget
            fire:settarget(nil, life - 1, source)
            if source.currentfire2hm then source.currentfire2hm[fire.burst2hm] = fire end
        end)
    end
end
local function onmutatedwargattackedwhenhowl(inst, data)
    if not inst.components.health:IsDead() and data ~= nil and data.spdamage ~= nil and data.spdamage.planar ~= nil then
        if not inst.sg.mem.dostagger then
            inst.sg.mem.dostagger = true
            inst.sg.statemem.staggertime = GetTime() + 0.2
        elseif GetTime() > inst.sg.statemem.staggertime and inst.sg.currentstate and inst.sg.currentstate.name == "howl" then
            inst.sg:GoToState("hit")
        end
    end
end
local function teleportshadowwarg(inst)
    if inst.currentfire2hm then
        if inst.components.health and not inst.components.health:IsDead() and inst.components.combat and inst.components.combat.target and
            inst.components.combat.target:IsValid() then
            local ents = {inst}
            local burst = 3
            for i = 1, burst do
                if inst.currentfire2hm and inst.currentfire2hm[i] and inst.currentfire2hm[i]:IsValid() then
                    table.insert(ents, inst.currentfire2hm[i])
                end
            end
            if #ents > 1 then
                table.sort(ents, function(a, b)
                    return math.abs(a:GetDistanceSqToInst(inst.components.combat.target)) < math.abs(b:GetDistanceSqToInst(inst.components.combat.target))
                end)
            end
            if ents[1] and ents[1]:IsValid() then inst.Transform:SetPosition(ents[1].Transform:GetWorldPosition()) end
        end
        inst.currentfire2hm = nil
    end
end
local function wargshadowflame(inst)
    if not inst.currentfire2hm and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name == "howl" and inst.components.combat and
        inst.components.combat.target and inst.components.combat.target:IsValid() then
        local pos = inst.components.combat.target:GetPosition()
        local startangle = inst:GetAngleToPoint(pos.x, pos.y, pos.z) * DEGREES
        inst.currentfire2hm = {}
        inst:ListenForEvent("attacked", onmutatedwargattackedwhenhowl)
        for i = 1, 3 do
            local fire = SpawnPrefab("willow_shadow_flame")
            fire.burst2hm = i
            fire.startangle2hm = startangle
            fire.theta2hm = PI / 6 * i - PI / 3
            local theta = startangle + fire.theta2hm
            local radius = 2
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
            fire.Transform:SetRotation(theta / DEGREES)
            fire.Transform:SetPosition(newpos.x, newpos.y, newpos.z)
            fire.settarget = newshadowflamesettarget
            fire:settarget(nil, 50, inst)
        end
        inst.components.timer:StopTimer("flamethrower_cd")
        inst.components.timer:StartTimer("flamethrower_cd", TUNING.MUTATED_WARG_FLAMETHROWER_CD + math.random() * 2)
    end
end
-- 分身是影火座狼,分身也会创造疲惫机会了
AddStategraphPostInit("warg", function(sg)
    -- local flamethrower_loop = sg.states.flamethrower_loop.onexit
    -- sg.states.flamethrower_loop.onexit = function(inst, ...)
    --     if flamethrower_loop then flamethrower_loop(inst, ...) end
    --     -- 座狼喷火时被月亮武器连续攻击2次就会疲惫
    --     if inst:HasTag("lunar_aligned") and not inst.sg.mem.dostagger then recovermutated(inst) end
    -- end
    local flamethrower_pre = sg.states.flamethrower_pre.onenter
    sg.states.flamethrower_pre.onenter = function(inst, ...)
        -- 分身替换月火为影火
        if inst:HasTag("lunar_aligned") and math.random() < (inst:HasTag("swc2hm") and 0.75 or 0.25) -- (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 and math.random() < 0.2 or
        --     (inst:HasTag("swc2hm") and math.random() < 0.8)) 
        and inst.components.timer and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() then
            inst.sg:GoToState("howl")
            inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() / 3, wargshadowflame)
            return
        end
        flamethrower_pre(inst, ...)
    end
    local howl = sg.states.howl.onexit
    sg.states.howl.onexit = function(inst, ...)
        if howl then howl(inst, ...) end
        if inst:HasTag("lunar_aligned") and inst.currentfire2hm then
            inst:RemoveEventCallback("attacked", onmutatedwargattackedwhenhowl)
            if not inst.sg.mem.dostagger then
                inst:DoTaskInTime(20 * FRAMES, teleportshadowwarg)
            else
                inst.currentfire2hm = nil
                -- recovermutated(inst)
            end
        end
    end
    local oldonenterattack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        oldonenterattack(inst, ...)
        if inst.components.locomotor then inst.components.locomotor:RunForward() end
    end
end)
-- 技能CD结束时如果正在追人,则释放影火
local function onflamethrowertimer(inst, data)
    if not inst:IsAsleep() and inst.components.timer and (data and data.name == "flamethrower_cd" or not inst.components.timer:TimerExists("flamethrower_cd")) and
        inst.components.combat and inst.components.health and not inst.components.health:IsDead() and inst.sg and inst.sg:HasStateTag("running") and
        inst.components.combat.target and inst.components.combat.target:IsValid() and not inst:IsNear(inst.components.combat.target, 8) then
        wargshadowflame(inst)
    end
end
AddPrefabPostInit("mutatedwarg", function(inst)
    if not TheWorld.ismastersim then return end
    -- if not inst.StartMutation then inst.StartMutation = StartMutation_mutated end
    inst.killedhound2hm = 0
    inst:ListenForEvent("timerdone", onflamethrowertimer)
    if TUNING.shadowworld2hm and EnableExchangeWitheSwc2hm then EnableExchangeWitheSwc2hm(inst, {0.65031, 0.30031}) end
    inst:DoPeriodicTask(60, onflamethrowertimer)
end)

-- 猎犬丘加强
TUNING.HOUNDMOUND_HOUNDS_MIN = TUNING.HOUNDMOUND_HOUNDS_MIN * 2
TUNING.HOUNDMOUND_HOUNDS_MAX = TUNING.HOUNDMOUND_HOUNDS_MAX * 2
AddPrefabPostInit("houndmound", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then inst.components.health:SetMaxHealth(900) end
end)

-- -- 猎犬袭击警告缩短
-- AddComponentPostInit("hounded", function(self)
--     local oldDoWarningSound = self.DoWarningSound
--     self.DoWarningSound = function(self, ...)
--         oldDoWarningSound(self, ...)
--         self.inst:DoTaskInTime(0, function() self:OnUpdate(math.clamp(3, TheWorld.state.cycles * 0.03 + 3), 15) end)
--     end
-- end)

-- 非迷你猎犬血量调整
if hardmodeindex == -4 then TUNING.HOUND_HEALTH = TUNING.HOUND_HEALTH * 5 / 3 end
TUNING.ICEHOUND_HEALTH = TUNING.HOUND_HEALTH
TUNING.FIREHOUND_HEALTH = TUNING.HOUND_HEALTH
TUNING.MUTATEDHOUND_HEALTH = TUNING.HOUND_HEALTH
TUNING.HEDGEHOUND_HEALTH = TUNING.HEDGEHOUND_HEALTH * 6
if hardmodeindex >= -3 then
    -- 迷你猎犬
    local hounds = {
        "hound",
        "firehound",
        "icehound",
        "moonhound",
        "houndcorpse",
        "mutatedhound",
        "lightninghound",
        -- "glacialhound",
        -- "magmahound",
        -- "sporehound",
        "rnehound",
        "haul_hound",
        "gargoyle_hound",
        "gargoyle_houndatk",
        "gargoyle_hounddeath"
    }
    for index, hound in ipairs(hounds) do
        AddPrefabPostInit(hound, function(inst)
            if not TheWorld.ismastersim then return end
            if inst.Transform then inst.Transform:SetScale(0.7, 0.7, 0.7) end
            if inst.components.combat then inst.components.combat.attackrange = inst.components.combat.attackrange * 0.5 end
        end)
    end
    local specialhounds = {"glacialhound", "magmahound", "sporehound", "clayhound"}
    for index, hound in pairs(specialhounds) do
        AddPrefabPostInit(hound, function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.health then
                inst.components.health.maxhealth = inst.components.health.maxhealth * ((inst.prefab == "sporehound" or inst.prefab == "clayhound") and 2 or 2/3)
                inst.components.health.currenthealth = inst.components.health.maxhealth
            end
        end)
    end
end

-- 难度2 座狼加强
-- 青年座狼攻击时移动
if hardmodeindex >= -1 then return end
local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("notboss_attackspeed") or 1
if speedup < 2 then TUNING.WARG_RUNSPEED = TUNING.WARG_RUNSPEED * 2 / speedup end
if attackspeedup < 1.33 then TUNING.WARG_ATTACKPERIOD = TUNING.WARG_ATTACKPERIOD * 3 / 4 * attackspeedup end

TUNING.WARGLET_HEALTH = TUNING.WARGLET_HEALTH * 1.5
TUNING.WARG_NEARBY_PLAYERS_DIST = TUNING.WARG_NEARBY_PLAYERS_DIST * 1.5

-- 座狼攻击时移动
-- AddStategraphPostInit("warg", function(sg)
--     local oldonenterattack = sg.states.attack.onenter
--     sg.states.attack.onenter = function(inst, ...)
--         oldonenterattack(inst, ...)
--         if inst.components.locomotor then inst.components.locomotor:RunForward() end
--     end
-- end)
AddStategraphPostInit("hound", function(sg)
    local oldonenterattack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        oldonenterattack(inst, ...)
        if (hardmodeindex == -3 or inst.prefab == "warglet" or inst.prefab == "lightninghound") and inst.components.locomotor then
            inst.components.locomotor:RunForward()
        end
    end
end)

-- 附身座狼杀10只以上狗后不再有掉落
local function OnKilledOther(inst, data)
    if data ~= nil and data.victim ~= nil and data.victim:HasTag("hound") and data.victim.components.lootdropper and
        (inst:HasTag("swc2hm") or inst.killedhound2hm > 10) then
        inst.killedhound2hm = inst.killedhound2hm + 1
        data.victim.components.lootdropper:SetLoot()
        data.victim.components.lootdropper:SetChanceLootTable()
        data.victim.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
        data.victim.components.lootdropper.GenerateLoot = emptytablefn
        data.victim.components.lootdropper.DropLoot = emptytablefn
    end
end
AddPrefabPostInit("mutatedwarg", function(inst)
    if not TheWorld.ismastersim then return end
    inst.killedhound2hm = 0
    inst:ListenForEvent("killed", OnKilledOther)
end)

-- AddStategraphState("hound",function (inst)

-- end)

-- local function DestroyTraps(inst)
--     local x, y, z = inst.Transform:GetWorldPosition()
--     local ents = TheSim:FindEntities(x, y, z, 8, "trap")
--     for i, v in pairs(ents) do
--         if v.components.mine ~= nil and not v.components.mine.inactive then v.components.mine:Deactivate() end
--         if v.components.workable then v.components.workable:WorkedBy(inst, 1) end
--     end
-- end
-- -- 冰猎犬火猎犬死亡时破坏陷阱
-- AddPrefabPostInit("firehound", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:ListenForEvent("death", DestroyTraps)
-- end)
-- AddPrefabPostInit("icehound", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:ListenForEvent("death", DestroyTraps)
-- end)
-- -- 猎犬领地机制，概率发展成猎犬丘
-- local trees = {"evergreen", "evergreen_sparse", "deciduoustree", "twiggytree"}
-- local function generatehoundterritory2hm(inst)
--     local x, y, z = inst.Transform:GetWorldPosition()
--     local firstents = TheSim:FindEntities(x, y, z, 15, nil, nil, {"houndmound", "houndterritory2hm"})
--     if #firstents > 0 then return end
--     local water = SpawnPrefab("houndterritory2hm")
--     water.Transform:SetPosition(x, y, z)
--     if not water.components.timer:TimerExists("change2hm") then
--         water.components.timer:StartTimer("change2hm", math.random(TUNING.TOTAL_DAY_TIME, TUNING.TOTAL_DAY_TIME * 3))
--     end
--     local ents = TheSim:FindEntities(x, y, z, 15, {"tree"}, {"stump"})
--     local i = 0
--     if #ents > 0 then
--         for index, v in ipairs(ents) do
--             if v and v:IsValid() and table.contains(trees, v.prefab) and math.random() < math.max(2 / #ents, 0.33) then
--                 local newwater = SpawnPrefab("houndterritory2hm")
--                 water.Transform:SetPosition(newwater.Transform:GetWorldPosition())
--                 if not water.components.timer:TimerExists("other2hm") then
--                     water.components.timer:StartTimer("other2hm", math.random(TUNING.TOTAL_DAY_TIME, TUNING.TOTAL_DAY_TIME * 3))
--                 end
--                 i = i + 1
--                 if i >= 3 then return end
--             end
--         end
--     end
-- end
-- local function DayEnd(inst)
--     if inst:IsAsleep() and TheWorld.state.iswinter == false and math.random() < 0.001 and not inst:HasTag("stump") then generatehoundterritory2hm(inst) end
-- end
-- local function livingtreeDayEnd(inst)
--     if inst:IsAsleep() and TheWorld.state.iswinter == false and math.random() < 0.03 and not inst:HasTag("stump") then generatehoundterritory2hm(inst) end
-- end
-- for index, tree in ipairs(trees) do
--     AddPrefabPostInit(tree, function(inst)
--         if not TheWorld.ismastersim then return end
--         if not TheWorld:HasTag("cave") then inst:WatchWorldState("cycles", DayEnd) end
--     end)
-- end
-- AddPrefabPostInit("livingtree", function(inst)
--     if not TheWorld.ismastersim then return end
--     if not TheWorld:HasTag("cave") then inst:WatchWorldState("cycles", livingtreeDayEnd) end
-- end)
