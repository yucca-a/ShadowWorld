local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("notboss_attackspeed") or 1
if attackspeedup < 1.33 then TUNING.KNIGHT_ATTACK_PERIOD = TUNING.KNIGHT_ATTACK_PERIOD * 3 / 4 * attackspeedup end
TUNING.ROOK_HEALTH = TUNING.ROOK_HEALTH / 3 * 4
TUNING.YOTH_KNIGHT_DAMAGE_TAKEN_MULT = 1
local UpvalueHacker = require("upvaluehacker2hm")

-- 损坏发条自动修复
local changetime = GetModConfigData("chess") == -1 and TUNING.TOTAL_DAY_TIME * 35 or TUNING.TOTAL_DAY_TIME * 10
local function autorepairself(inst)
    if not inst:HasTag("swc2hm") and not inst.components.timer:TimerExists("mod_hardmode_timechange") then
        inst.components.timer:StartTimer("mod_hardmode_timechange", changetime + math.random(30))
    end
end

-- SetSharedLootTable2hm('knight', {{'gears', 1.0}})
-- SetSharedLootTable2hm('bishop', {{'gears', 1.0}, {'purplegem', 0.75}})
-- SetSharedLootTable2hm('rook', {{'gears', 1.0}})
-- 发条装置掉落适当变低
SetSharedLootTable2hm("chess_junk", {
    {"trinket_6", 1.00},
    {"trinket_6", 0.55},
    {"purplegem", 0.5},
    {"trinket_1", 0.25},
    {"gears", 0.25},
    {"redgem", 0.15},
    {"bluegem", 0.05},
    {"orangegem", 0.01},
    {"thulecite", 0.01},
    {"yellowgem", 0.005},
    {"greengem", 0.005}
})
SetSharedLootTable2hm("bishop", {{"gears", 1.0}, {"gears", 1.0}, {"purplegem", 0.5}})
SetSharedLootTable2hm("bishop_nightmare", {{"gears", 1.0}, {"purplegem", 0.5}, {"nightmarefuel", 0.6}, {"thulecite_pieces", 0.5}})

local function hasfollower(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end
-- 周围不定时生成月熠
local function SpawnSparks(inst)
    if #AllPlayers <= 0 or hasfollower(inst) then return end
    local pt = Vector3(inst.Transform:GetWorldPosition())
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 30, {"moonstorm_spark"}, {"INLIMBO"})
    if #ents < 3 then
        local pos = FindWalkableOffset(pt, math.random() * 2 * PI, 5 + math.random() * 20, 16, nil, nil, truefn, nil, nil)
        if pos then
            local spark = SpawnPrefab("moonstorm_spark")
            spark.Transform:SetPosition(pt.x + pos.x, 0, pt.z + pos.z)
            if inst:IsAsleep() then spark.components.perishable:SetPercent(0.35) end
        end
    end
end

-- 特效只在玩家靠近时出现
local function onnearrangemonster(inst)
    if inst.charged and inst.mod_electricchargedfxtask == nil and not inst:IsAsleep() then
        inst.mod_electricchargedfxtask = inst:DoPeriodicTask(1.5, function() SpawnPrefab("electricchargedfx"):SetTarget(inst) end, 0)
    end
end
local function onfarrangemonster(inst)
    if inst.mod_electricchargedfxtask ~= nil then
        inst.mod_electricchargedfxtask:Cancel()
        inst.mod_electricchargedfxtask = nil
    end
end

-- 带电状态减弱,解除带电状态
local function ReduceCharges(inst, chargeleft)
    if inst.chargeleft then
        inst.chargeleft = inst.chargeleft - (chargeleft or 1)
        if inst.chargeleft <= 0 then
            inst:RemoveTag("charged")
            inst.charged = false
            if inst.Light then inst.Light:Enable(false) end
            inst.chargeleft = nil
            if inst.mod_electricchargedfxtask ~= nil then
                inst.mod_electricchargedfxtask:Cancel()
                inst.mod_electricchargedfxtask = nil
            end
            if inst.mod_clearchargedtask then
                inst.mod_clearchargedtask:Cancel()
                inst.mod_clearchargedtask = nil
            end
        end
    end
end

local function leaderchange(inst)
    inst:RemoveTag("charged")
    inst.charged = false
    if inst.Light then inst.Light:Enable(false) end
    inst.chargeleft = nil
    if inst.mod_electricchargedfxtask ~= nil then
        inst.mod_electricchargedfxtask:Cancel()
        inst.mod_electricchargedfxtask = nil
    end
    if inst.mod_clearchargedtask then
        inst.mod_clearchargedtask:Cancel()
        inst.mod_clearchargedtask = nil
    end
end

local function loseleader(inst, data)
    if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
        for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
            if v and v:IsValid() and not v.changeswp2hm then
                if v.components.follower then v.components.follower:StopFollowing() end
            end
        end
    end
end

-- 进入带电状态
local function setcharged(inst, chargeleft)
    if hasfollower(inst) then return end
    if not inst.charged then
        inst.charged = true
        inst:AddTag("charged")
        if inst.Light then inst.Light:Enable(true) end
        if not inst.mod_clearchargedtask then inst.mod_clearchargedtask = inst:DoPeriodicTask(225 + math.random(30), ReduceCharges) end
        if not inst:IsAsleep() and inst.mod_electricchargedfxtask == nil then
            inst.mod_electricchargedfxtask = inst:DoPeriodicTask(1.5, function() SpawnPrefab("electricchargedfx"):SetTarget(inst) end, 0)
        end
    end
    if chargeleft then
        inst.chargeleft = math.min((inst.chargeleft or 0) + (chargeleft or 3), 7)
        if inst.components.health ~= nil and not inst.components.health:IsDead() then
            inst.components.health:DoDelta(TUNING.LIGHTNING_GOAT_DAMAGE * (chargeleft + 1), false, "lightning")
        end
    end
end

-- 带电反击
local function electrichit(inst, data, target)
    if target and target:IsValid() and inst.mod_electric_cdtask2hm == nil and not target:HasTag("chess") and target.components.combat ~= nil and
        (target.components.health ~= nil and not target.components.health:IsDead()) and not (data and data.attacker and data.weapon and
        (data.weapon.components.projectile or (data.weapon.components.weapon and data.weapon.components.weapon.projectile))) then
        if (target.components.inventory == nil or not target.components.inventory:IsInsulated()) then
            inst.mod_electric_cdtask2hm = inst:DoTaskInTime(0.3, function(inst) inst.mod_electric_cdtask2hm = nil end)
            SpawnPrefab("electrichitsparks"):AlignToTarget(target, inst, true)
            local damage_mult = 1
            if not target:HasTag("electricdamageimmune") then
                damage_mult = TUNING.ELECTRIC_DAMAGE_MULT
                local wetness_mult = (target.components.moisture ~= nil and target.components.moisture:GetMoisturePercent()) or (target:GetIsWet() and 1) or 0
                damage_mult = damage_mult + wetness_mult
            end
            if target:HasTag("epic") then damage_mult = damage_mult / 2 end
            target.components.combat:GetAttacked_Internal(inst, damage_mult * TUNING.WX78_TASERDAMAGE, nil, "electric")
            if data and data.attacker and inst.components.health ~= nil and not inst.components.health:IsDead() then
                inst.components.health:DoDelta(target:HasTag("epic") and TUNING.LIGHTNING_GOAT_DAMAGE / 2 or TUNING.LIGHTNING_GOAT_DAMAGE)
            end
        elseif target.components.inventory and target.components.inventory.equipslots then
            for _, v in pairs(target.components.inventory.equipslots) do
                if v and v.components.equippable:IsInsulated() then
                    if v.components.fueled then v.components.fueled:DoDelta(-60, inst) end
                    if v.components.finiteuses then v.components.finiteuses:Use(1) end
                    if v.components.armor then v.components.armor:TakeDamage(10) end
                    break
                end
            end
        end
    end
end

-- 月熠技能
local function ChanceSpawnSparks(inst)
    if not inst.charged and not inst.mod_SpawnSparkstask and not hasfollower(inst) then
        local chance = (inst.mod_nightmare and 0.35 or 0) + 1 - (inst.components.health and inst.components.health:GetPercent() or 1)
        if math.random() < chance then
            inst.mod_SpawnSparkstask = inst:DoTaskInTime(120, function() inst.mod_SpawnSparkstask = nil end)
            local pt = Vector3(inst.Transform:GetWorldPosition())
            inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/gem_place")
            local shinefx = SpawnPrefab("crab_king_shine")
            shinefx.entity:AddFollower()
            -- shinefx.entity:SetParent(inst)
            shinefx.Follower:FollowSymbol(inst.GUID, inst.components.combat.hiteffectsymbol, 0, 0, 0)
            local spark = SpawnPrefab("moonstorm_spark")
            spark.Transform:SetPosition(pt.x + math.random() * 5 - 2.5, 0, pt.z + math.random() * 5 - 2.5)
            local fn = spark.sparktask and spark.sparktask.fn
            if fn and not inst:IsInLimbo() then
                spark.sparktask:Cancel()
                spark:DoTaskInTime(0.75, fn)
            end
        end
    end
end

-- 闪电技能
local function ChanceLightningStrike(inst)
    if not inst.mod_LightningStriketask and not hasfollower(inst) then
        local pt = Vector3(inst.Transform:GetWorldPosition())
        local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 15, {"moonstorm_spark"}, {"INLIMBO"})
        if math.random() < (inst.charged and 0.1 or 0) + 0.1 * #ents then
            inst.mod_LightningStriketask = inst:DoTaskInTime(120, function() inst.mod_LightningStriketask = nil end)
            inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/gem_place")
            local shinefx = SpawnPrefab("crab_king_shine")
            shinefx.entity:AddFollower()
            -- shinefx.entity:SetParent(inst)
            shinefx.Follower:FollowSymbol(inst.GUID, inst.components.combat.hiteffectsymbol, 0, 0, 0)
            inst:DoTaskInTime(math.random() + 0.5, function(inst)
                local target = nil
                local i = math.random(3)
                if i == 1 then
                    target = inst
                elseif i == 2 then
                    target = inst.components.combat and inst.components.combat.target or inst
                else
                    target = #ents > 0 and ents[math.random(#ents)] or inst
                end
                if target then
                    local pos = target:GetPosition()
                    TheWorld:PushEvent("ms_sendlightningstrike", pos)
                end
            end)
        end
    end
end

-- 攻击时概率周围生成月熠
local function onhitother(inst, data)
    ChanceSpawnSparks(inst)
    ChanceLightningStrike(inst)
    if inst.mod_bishop and data ~= nil then electrichit(inst, data, data.target) end
end

-- 被非发条外单位的带电攻击命中后进入带电状态;小概率周围生成月熠;带电状态下反击带电
local function OnAttacked(inst, data)
    if inst:HasTag("swp2hm") then
        if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and not v.changeswp2hm then
                    if hasfollower(inst) == nil and v.components.followermemory then
                        v.components.followermemory:ForgetLeader()
                    end
                end
            end
        end
    end
    if hasfollower(inst) then return end
    if data and data.attacker and data.attacker.prefab == "moonstorm_spark" then return setcharged(inst, 1) end
    if not inst.charged then if math.random() < 0.5 then inst:DoTaskInTime(0.5, ChanceSpawnSparks) end end
    if inst.charged and data ~= nil and data.attacker ~= nil and not data.redirected then electrichit(inst, data, data.attacker) end
end

-- 带电状态持久化存储
local function onsave(inst, data)
    if inst.charged then
        data.charged = inst.charged
        data.chargeleft = inst.chargeleft
    end
end
local function onload(inst, data)
    if data and data.charged and data.chargeleft then
        inst.chargeleft = data.chargeleft
        setcharged(inst)
    end
end
local function onkilled(inst, data)
    if data and data.victim and (data.victim:HasTag("shadowcreature") or data.victim:HasTag("nightmarecreature")) and
        data.victim.components.lootdropper then
        data.victim.components.lootdropper:SetLoot()
        data.victim.components.lootdropper:SetChanceLootTable()
        data.victim.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
        data.victim.components.lootdropper.GenerateLoot = emptytablefn
        data.victim.components.lootdropper.DropLoot = emptytablefn
    end
end

local function CustomCombatDamage(inst, target) return target:HasTag("chess") and 0.5 or 1 end

-- 发条带电状态下发光;吸引闪电;定时生成月熠
local chessmonsters = {"knight", "knight_nightmare", "bishop", "bishop_nightmare", "rook", "rook_nightmare"}
for _, monster in ipairs(chessmonsters) do
    AddPrefabPostInit(monster, function(inst)
        if not inst.Light then inst.entity:AddLight() end
        inst.Light:Enable(false)
        inst.Light:SetRadius(.85)
        inst.Light:SetFalloff(0.5)
        inst.Light:SetIntensity(.75)
        inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
        -- inst:AddTag("electricdamageimmune")
        inst:AddTag("lightningrod")
        if not TheWorld.ismastersim then return end
        inst.electrocute_delay = {min = 15 , max = 30}
        inst:DoPeriodicTask(TUNING.SPARK_PERISH_TIME + math.random(30), SpawnSparks)
        inst.mod_bishop = string.find(inst.prefab, "bishop")
        inst.mod_nightmare = string.find(inst.prefab, "nightmare")
        inst:ListenForEvent("lightningstrike", function(inst) setcharged(inst, 3) end)
        inst:ListenForEvent("onhitother", onhitother)
        inst:ListenForEvent("attacked", OnAttacked)
        if inst.TryBefriendChess then
            local oldTryBefriendChess = inst.TryBefriendChess
                inst.TryBefriendChess = function(_inst, doer, ...)
                    local result = oldTryBefriendChess(_inst, doer, ...)
                    if result == true then
                        if hasfollower(_inst) then leaderchange(_inst) end
                        _inst:DoTaskInTime(0, function()
                            if _inst:HasTag("swp2hm") then
                                if _inst.components.childspawner2hm and _inst.components.childspawner2hm.numchildrenoutside > 0 then
                                    for k, v in pairs(_inst.components.childspawner2hm.childrenoutside) do
                                        if v and v:IsValid() and not v.changeswp2hm then
                                            if hasfollower(_inst) then 
                                                v:TryBefriendChess(doer) 
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                        return result
                    else
                        return result
                    end
                end
        end
        -- inst:DoTaskInTime(0.5, function()
        --     if inst:HasTag("swp2hm") then inst:ListenForEvent("startleashing", leaderchange) end
        --     -- if inst:HasTag("swp2hm") then inst:ListenForEvent("stopfollowing", loseleader) end
        -- end)
        inst.components.combat.customdamagemultfn = CustomCombatDamage
        inst.components.combat:AddNoAggroTag("minotaur")
        inst.components.combat:AddNoAggroTag("minotaur2hm")
        SetOnSave(inst, function(...)
            onsave(...)
        end)
        SetOnLoad(inst, function(...)
            onload(...)
        end)
        if TUNING.shadowworld2hm then inst:ListenForEvent("killed", onkilled) end
    end)
end

-- 完整骑士死亡变损坏骑士
local fullchessmonsters = {"knight", "bishop", "rook"}
for _, monster in ipairs(fullchessmonsters) do
    local isrook = monster == "rook"
    AddPrefabPostInit(monster, function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, onnearrangemonster)
        inst:ListenForEvent("entitywake", onnearrangemonster)
        inst:ListenForEvent("entitysleep", onfarrangemonster)
        inst:ListenForEvent("death", function(inst)
            if not inst.deatheve2hm then
                inst.deatheve2hm = true
                local leader = hasfollower(inst)
                local newchess = SpawnPrefab(inst.prefab .. "_nightmare")
                if newchess then
                    newchess.components.knownlocations:RememberLocation("home", inst.components.knownlocations:GetLocation("home") or inst:GetPosition())
                    newchess.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    inst:PushEvent("onprefabswaped", {newobj = newchess})
                    if leader then newchess:TryBefriendChess(leader) end
                    if inst.charged then setcharged(newchess, inst.chargeleft) end
                end
            end
        end)
    end)
end

-- 损坏骑士慢慢自动修复为完整骑士;死亡变损坏装置
local nightmarechessmonsters = {knight_nightmare = "chessjunk1", bishop_nightmare = "chessjunk2", rook_nightmare = "chessjunk3"}
local nightmarechessmonsters_change = {knight_nightmare = "knight", bishop_nightmare = "bishop", rook_nightmare = "rook"}
for monster, junk in pairs(nightmarechessmonsters) do
    local isrook = monster == "rook_nightmare"
    AddPrefabPostInit(monster, function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, onnearrangemonster)
        inst:ListenForEvent("entitywake", onnearrangemonster)
        inst:ListenForEvent("entitysleep", onfarrangemonster)
        if not inst.components.timer then inst:AddComponent("timer") end
        inst:DoTaskInTime(0, autorepairself)
        inst:ListenForEvent("timerdone", function(inst, data)
            if data and data.name == "mod_hardmode_timechange" and not inst:HasTag("swc2hm") then
                local newchess = SpawnPrefab(nightmarechessmonsters_change[inst.prefab])
                if newchess then
                    newchess.components.knownlocations:RememberLocation("home", inst.components.knownlocations:GetLocation("home") or inst:GetPosition())
                    newchess.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    inst:DoTaskInTime(0.1, inst.Remove)
                    inst:PushEvent("onprefabswaped", {newobj = newchess})
                    if inst.charged then setcharged(newchess, inst.chargeleft) end
                end
            end
        end)
        inst:ListenForEvent("death", function(inst)
            if not inst.deatheve2hm then
                inst.deatheve2hm = true
                local junk = SpawnPrefab(junk)
                if junk then
                    junk.components.knownlocations:RememberLocation("home", inst.components.knownlocations:GetLocation("home") or inst:GetPosition())
                    junk.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    inst:PushEvent("onprefabswaped", {newobj = junk})
                    if inst.charged then setcharged(junk, inst.chargeleft) end
                end
            end
        end)
    end)
end

-- 损坏装置慢慢自动修复为损坏骑士;更难锤碎
local junks = {chessjunk = "", chessjunk1 = "knight_nightmare", chessjunk2 = "bishop_nightmare", chessjunk3 = "rook_nightmare"}
local MAXHITS = 6
local function RememberKnownLocation(inst) inst.components.knownlocations:RememberLocation("home", inst:GetPosition()) end
for junk, monster in pairs(junks) do
    AddPrefabPostInit(junk, function(inst)
        if not inst.Light then inst.entity:AddLight() end
        inst.Light:Enable(false)
        inst.Light:SetRadius(.85)
        inst.Light:SetFalloff(0.5)
        inst.Light:SetIntensity(.75)
        inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
        inst:AddTag("lightningrod")
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("lightningstrike", function(inst) setcharged(inst, 3) end)
        inst:DoTaskInTime(0, onnearrangemonster)
        inst:ListenForEvent("entitywake", onnearrangemonster)
        inst:ListenForEvent("entitysleep", onfarrangemonster)
        if not inst.components.knownlocations then inst:AddComponent("knownlocations") end
        inst:DoTaskInTime(0, RememberKnownLocation)
        if not inst.components.timer then inst:AddComponent("timer") end
        inst:DoTaskInTime(0, autorepairself)
        inst:ListenForEvent("timerdone", function(inst, data)
            if data and data.name == "mod_hardmode_timechange" then
                local newchessprefab = (inst.style == 1 and (math.random() < .5 and "bishop_nightmare" or "knight_nightmare")) or
                                           (inst.style == 2 and (math.random() < .3 and "rook_nightmare" or "knight_nightmare")) or
                                           (math.random() < .3 and "rook_nightmare" or "bishop_nightmare")
                local chess = SpawnPrefab(newchessprefab)
                if chess then
                    chess.components.knownlocations:RememberLocation("home", inst.components.knownlocations:GetLocation("home") or inst:GetPosition())
                    chess.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    inst:DoTaskInTime(0.1, inst.Remove)
                    inst:PushEvent("onprefabswaped", {newobj = chess})
                    if inst.charged then setcharged(chess, inst.chargeleft) end
                end
            end
        end)
        if inst.components.workable then
            local oldonwork = inst.components.workable.onwork
            inst.components.workable:SetOnWorkCallback(function(inst, worker, workleft, numworks, ...)
                if oldonwork then oldonwork(inst, worker, workleft, numworks, ...) end
                if inst.charged then electrichit(inst, nil, worker) end
                if worker and worker:IsValid() and not TheWorld:HasTag("cave") and math.random() <= 0.1 then
                    TheWorld:PushEvent("ms_sendlightningstrike", worker:GetPosition())
                end
                if inst.components.workable.workleft <= 0 and
                    not (worker and
                        ((worker.components.explosive and worker.components.explosive.explosivedamage > 0) or worker:HasTag("epic") or math.random() <
                            (worker.prefab == "winona" and 0.15 or 0.025))) then inst.components.workable:SetWorkLeft(1) end
            end)
            -- local oldonfinish = inst.components.workable.onfinish
            -- inst.components.workable:SetOnFinishCallback(function(inst, worker, ...) if oldonfinish then oldonfinish(inst, worker, ...) end end)
            if inst.components.repairable and inst.components.lootdropper then
                local oldonrepaired = inst.components.repairable.onrepaired
                inst.components.repairable.onrepaired = function(inst, doer, ...)
                    if inst.charged and inst.chargeleft and inst.chargeleft > 0 then
                        electrichit(inst, nil, doer)
                        ReduceCharges(inst, 2)
                        inst.components.workable.workleft = math.max(inst.components.workable.workleft - 1, 1)
                    end
                    if inst.components.workable.workleft >= MAXHITS then
                        inst.components.lootdropper:SetLoot()
                        inst.components.lootdropper:SetChanceLootTable()
                        inst.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
                        inst.components.lootdropper.GenerateLoot = emptytablefn
                        inst.components.lootdropper.DropLoot = emptytablefn
                    end
                    if oldonrepaired then oldonrepaired(inst, doer, ...) end
                end
            end
        end
        SetOnSave(inst, function(...)
            onsave(...)
        end)
        SetOnLoad(inst, function(...)
            onload(...)
        end)
    end)
end

local ruinrespawnprefabs = {
    "knight_nightmare_ruinsrespawner_inst",
    "bishop_nightmare_ruinsrespawner_inst",
    "rook_nightmare_ruinsrespawner_inst",
    "chessjunk_ruinsrespawner_inst"
}
for _, respawnprefab in ipairs(ruinrespawnprefabs) do
    AddPrefabPostInit(respawnprefab, function(inst)
        if not TheWorld.ismastersim then return end
        inst.listenforprefabsawp = true
    end)
end

AddComponentPostInit("knownlocations", function(self)
    if not self.inst:HasTag("chess") then return end
    local oldRememberLocation = self.RememberLocation
    self.RememberLocation = function(self, name, pos, dont_overwrite, ...)
        if dont_overwrite == nil then dont_overwrite = true end
        return oldRememberLocation(self, name, pos, dont_overwrite, ...)
    end
end)

-- local CanEntityBeElectrocuted = GLOBAL.CanEntityBeElectrocuted
-- GLOBAL.CanEntityBeElectrocuted = function(inst, ...)
--     if inst:HasTag("chess") then return false end
--     return CanEntityBeElectrocuted(inst, ...)
-- end

local broken_chess = {"knight_nightmare","bishop_nightmare","rook_nightmare"}
AddPrefabPostInit("gears", function(inst)
    -- if inst.UseableTargetedItem_ValidTarget then
    --     local oldUseableTargetedItem_ValidTarget = inst.UseableTargetedItem_ValidTarget
    --     inst.UseableTargetedItem_ValidTarget = function(inst, target, ...)
    --         local num = inst.replica.stackable and inst.replica.stackable:StackSize() or 1
    --         if table.contains(fullchessmonsters,target.prefab) and num < 6 then return false end
    --         return oldUseableTargetedItem_ValidTarget(inst, target, ...)
    --     end
    -- end
    if not TheWorld.ismastersim then return end
    if inst.components.useabletargeteditem and inst.components.useabletargeteditem.onusefn then
        local oldonusefn = inst.components.useabletargeteditem.onusefn
        inst.components.useabletargeteditem.onusefn = function(inst, target, doer, ...)
            local num = inst.components.stackable and inst.components.stackable:StackSize() or 1
            if table.contains(fullchessmonsters,target.prefab) and num < 6 then
                if doer and doer.components.talker then
                    doer:DoTaskInTime(0, function()
                        doer.components.talker:Say((TUNING.isCh2hm and "需要6个齿轮雇佣" or "It needs 6 gears"))
                    end)
                end
                return false
            elseif table.contains(broken_chess,target.prefab) and num < 3 then
                if doer and doer.components.talker then
                    doer:DoTaskInTime(0, function()
                        doer.components.talker:Say((TUNING.isCh2hm and "需要3个齿轮雇佣" or "It needs 3 gears"))
                    end)
                end
                return false
            end
            local result = oldonusefn(inst, target, doer, ...)
            if result then
                if table.contains(broken_chess,target.prefab) then
                    inst.components.stackable:Get(2):Remove()
                elseif table.contains(fullchessmonsters,target.prefab) then
                    inst.components.stackable:Get(5):Remove()
                end
                return result
            else
                return result
            end
        end
    end
end)

local function CancelRegen(inst)
	if inst._regen then
		if inst._regen == true then
			inst.components.health:RemoveRegenSource(inst)
		else
			inst._regen:Cancel()
		end
		inst._regen = nil
	end
end

local clockwork_common = require "prefabs/clockwork_common"
if clockwork_common and clockwork_common.MakeHealthRegen then
    local oldOnHealthDelta = UpvalueHacker.GetUpvalue(clockwork_common.MakeHealthRegen, "TryRegenOnExitCombat", "OnHealthDelta")
    if oldOnHealthDelta then
        local newOnHealthDelta = function(inst, ...)
            oldOnHealthDelta(inst, ...)
            if hasfollower(inst) then CancelRegen(inst) end
        end
        UpvalueHacker.SetUpvalue(clockwork_common.MakeHealthRegen, newOnHealthDelta ,"TryRegenOnExitCombat", "OnHealthDelta")
    end
end