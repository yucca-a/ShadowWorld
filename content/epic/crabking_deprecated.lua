----------------------------------------------------------------------
--             旧版本帝王蟹(已弃用)
----------------------------------------------------------------------
AddPrefabPostInit("crabking_spawner", function(inst)
    if inst.components and inst.components.childspawner then
        inst.components.childspawner.childname = "crabking2hm"
    end
end)
-- 简单模式下深海呼吸和海蚀柱技能CD是正常的1.5倍
local noshadowworld = not GetModConfigData("Shadow World")
local sharkboi = GetModConfigData("sharkboi")
AddPrefabPostInit("crabking2hm", function(inst)
    if not TheWorld.ismastersim then return end
    inst.noshadowworld = noshadowworld
    inst.components.lootdropper:SetChanceLootTable("crabking")
end)
-- TUNING.CRABKING_CLAW_RESPAWN_DELAY = TUNING.CRABKING_CLAW_RESPAWN_DELAY * 2 / 3
TUNING.CRABKING_BASE_CLAWS = TUNING.CRABKING_BASE_CLAWS + 1
TUNING.CRABKING_CLAW_THRESHOLD = 0.96

STRINGS.NAMES.CRABKING2HM = "帝王蟹"--名称
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CRABKING2HM = "帝王蟹"--描述
STRINGS.RECIPE_DESC.CRABKING2HM = "帝王蟹" --制造描述

STRINGS.NAMES.CRABKING2HM_CLAW = "帝王蟹钳子"--名称
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CRABKING2HM_CLAW = "帝王蟹钳子"--描述
STRINGS.RECIPE_DESC.CRABKING2HM_CLAW = "帝王蟹钳子" --制造描述dwx_claw

-- 帝王蟹的举石头钳子和蟹钳会接住炮弹了
-- local function unprotectshadowself(inst) if not inst.components.health:IsDead() then inst.components.health:SetInvincible(false) end end
-- local function proxycomplexprojectile(inst, prefab, rot, far)
--     if inst.components.health:IsDead() then
--         SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
--         return
--     end
--     local x, y, z = inst.Transform:GetWorldPosition()
--     local ents = TheSim:FindEntities(x, 0, z, 1.5, nil, nil, {"crabking_claw", "crabking"})
--     for i, v in ipairs(ents) do
--         if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then
--             v.components.health:SetInvincible(true)
--             if v.protesttask2hm then
--                 v.protesttask2hm:Cancel()
--                 v.protesttask2hm = nil
--             end
--             v.protesttask2hm = v:DoTaskInTime(0.25, unprotectshadowself)
--         end
--     end
--     local projectile = SpawnPrefab(prefab)
--     if projectile == nil then return end
--     if not projectile.components.complexprojectile then
--         projectile:Remove()
--         return
--     end
--     if far then projectile.components.complexprojectile.horizontalSpeed = projectile.components.complexprojectile.horizontalSpeed * 1.35 end
--     projectile.disablecrab2hm = true
--     local x, y, z = inst.Transform:GetWorldPosition()
--     local theta = rot * DEGREES
--     local radius = 0.5
--     local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
--     projectile.Transform:SetPosition(x + offset.x, y + TUNING.BOAT.BOATCANNON.PROJECTILE_INITIAL_HEIGHT, z + offset.z)
--     projectile.shooter = inst
--     local angle = -rot * DEGREES
--     local range = TUNING.BOAT.BOATCANNON.RANGE
--     local targetpos = Vector3(x + math.cos(angle) * range, y, z + math.sin(angle) * range)
--     projectile.components.complexprojectile:Launch(targetpos, inst, inst)
-- end
-- local function clawdelayproxycomplexprojectile(inst, prefab, rot)
--     inst.sg:Start()
--     if inst.components.health:IsDead() then
--         SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
--         inst.sg:GoToState("death")
--     else
--         inst.sg:GoToState("emerge")
--         local time = math.min(inst.AnimState:GetCurrentAnimationLength(), 0.5)
--         inst:DoTaskInTime(time, proxycomplexprojectile, prefab, rot)
--     end
-- end
-- local function processcomplexprojectile(inst, v)
--     -- 无伤接炮弹太奇怪了，但也不会受到太高伤害直接导致死亡
--     if v.components.health:IsInvincible() or v.components.health.currenthealth > TUNING.CANNONBALL_DAMAGE then
--         if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
--             v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
--         end
--         SpawnPrefab("crab_king_shine").Transform:SetPosition(inst.Transform:GetWorldPosition())
--         local target = inst.shooter or inst.components.complexprojectile.attacker
--         local rot
--         if target and target:IsValid() then
--             rot = v:GetAngleToPoint(target:GetPosition():Get())
--         else
--             rot = v:GetAngleToPoint(inst:GetPosition():Get())
--         end
--         -- 反弹炮弹
--         if v.prefab == "crabking" then
--             v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.25, 1), proxycomplexprojectile, inst.prefab, rot, true)
--         else
--             v.sg:Stop()
--             v.AnimState:PlayAnimation("clamp_pre")
--             if v.boat and v.boat.prefab == "crabking" and v.releaseclamp then v:releaseclamp() end
--             v.Transform:SetRotation(rot - 180)
--             local time = v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.5, 1), clawdelayproxycomplexprojectile, inst.prefab, rot)
--         end
--     else
--         -- 牺牲来格挡炮弹
--         SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
--         if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
--             v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
--         end
--     end
--     inst.components.complexprojectile:Cancel()
--     inst:DoTaskInTime(0, inst.Remove)
-- end
-- local function onclawGetAttacked_Internal2hm(inst, data)
--     if data and data.attacker then
--         if data.attacker.disablecrab2hm then
--             inst.oncemiss2hm = true
--         elseif data.attacker.components.complexprojectile and not data.attacker.disablecrab2hm and inst.components.health and
--             not inst.components.health:IsDead() and inst.sg and
--             (inst.sg:HasStateTag("idle") or inst.sg:HasStateTag("moving") or (inst.boat and inst.boat.prefab == "crabking")) and
--             (data.attacker:HasTag("activeprojectile") or data.attacker:IsNear(inst, 0.75)) and GetTime() - inst.spawntime > 0.5 then
--             processcomplexprojectile(data.attacker, inst)
--             data.attacker.disablecrab2hm = true
--             inst.oncemiss2hm = true
--         end
--     end
-- end
-- AddPrefabPostInit("crabking_claw", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst:ListenForEvent("GetAttacked_Internal2hm", onclawGetAttacked_Internal2hm)
-- end)

-- 帝王蟹的守护蟹钳攻击反伤,和举起石头回复时的炮弹反弹
-- local function OnReflectDamage(inst, data)
--     if data.attacker ~= nil and data.attacker:IsValid() then
--         local impactfx = SpawnPrefab("impact")
--         if impactfx ~= nil then
--             impactfx.Transform:SetPosition(data.attacker.Transform:GetWorldPosition())
--             impactfx:FacePoint(inst.Transform:GetWorldPosition())
--         end
--     end
-- end
-- local function GetAttacked_Internal2hm(inst, data)
--     if data and data.attacker and data.attacker:IsValid() then
--         if data.attacker.disablecrab2hm then
--             inst.oncemiss2hm = true
--         elseif data.attacker.components.complexprojectile and not data.attacker.disablecrab2hm and not inst.components.health:IsDead() and inst.sg and
--             inst.sg:HasStateTag("fixing") then
--             if inst.lastfixloop then
--                 processcomplexprojectile(data.attacker, inst)
--                 data.attacker.disablecrab2hm = true
--                 inst.oncemiss2hm = true
--             else
--                 inst.fixhits = (inst.fixhits or 0) - 1
--             end
--             if inst.components.damagereflect then inst.components.damagereflect:SetDefaultDamage(0) end
--         elseif data.attacker ~= inst and data.attacker.prefab ~= "crabking" and data.attacker.prefab ~= "crabking_claw" and data.attacker.components.health and
--             not data.attacker.components.health:IsDead() then
--             if not inst.components.damagereflect then
--                 inst:AddComponent("damagereflect")
--                 inst:ListenForEvent("onreflectdamage", OnReflectDamage)
--             end
--             inst.components.damagereflect:SetDefaultDamage(inst:counthelpclaw2hm() * 10)
--         elseif inst.components.damagereflect then
--             inst.components.damagereflect:SetDefaultDamage(0)
--         end
--     end
-- end
-- -- 帝王蟹的守护蟹钳计算
-- local function counthelpclaw2hm(inst)
--     local count = 0
--     if inst.arms then
--         for i, arm in ipairs(inst.arms) do if arm.prefab and arm:IsValid() and arm.boat and arm.boat.prefab == "crabking" then count = count + 1 end end
--     end
--     return count
-- end
-- -- 帝王蟹战斗时的守护蟹钳回血
-- local function tryhealself(inst)
--     local count = inst:counthelpclaw2hm()
--     if count > 0 and inst.components.combat then
--         inst.components.health.externalabsorbmodifiers:SetModifier(inst, 0.1 * count, "crabkingclaw2hm")
--     else
--         inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "crabkingclaw2hm")
--     end
--     if count > 0 and not inst.components.health:IsDead() then inst.components.health:DoDelta(count * 70, nil, nil, true) end
-- end
-- local function oncrabkingactivata(inst)
--     if inst.healselftask2hm then inst.healselftask2hm:Cancel() end
--     inst.healselftask2hm = inst:DoPeriodicTask(1, tryhealself)
-- end

-- 帝王蟹的水柱在叠加触发后可以震飞船上的玩家,且可以把玩家震出船外(大理石甲可以防御),且击飞玩家手里的武器
local lastwaterspout
local boathealthdelta
local function cancelwaterspouttask2hm(inst)
    inst.waterspoutidx2hm = nil
    inst.waterspouttask2hm = nil
    if inst.crabking2hm and inst.crabking2hm:IsValid() and inst.crabking2hm.listenboats2hm then
        for i = #inst.crabking2hm.listenboats2hm, 1, -1 do
            if inst.crabking2hm.listenboats2hm[i] == inst then
                inst:RemoveEventCallback("healthdelta", boathealthdelta)
                table.remove(inst.crabking2hm.listenboats2hm, i)
            end
        end
    end
end
boathealthdelta = function(inst, data)
    if lastwaterspout and lastwaterspout:IsValid() and inst:IsNear(lastwaterspout, 4.5) and GetTime() - lastwaterspout.spawntime < 0.1 and data and
        data.newpercent and data.oldpercent and data.newpercent > 0 and data.newpercent < data.oldpercent then
        local x, y, z = inst.Transform:GetWorldPosition()
        local players = FindPlayersInRangeSq(x, y, z, 16, true)
        for index, player in ipairs(players) do
            if player:GetCurrentPlatform() == inst and player.sg and player.sg.currentstate and not player.components.health:IsDead() then
                inst.waterspoutidx2hm = (inst.waterspoutidx2hm or 0) + 1
                if inst.waterspouttask2hm then inst.waterspouttask2hm:Cancel() end
                inst.waterspouttask2hm = inst:DoTaskInTime(0.75, cancelwaterspouttask2hm)
                if inst.waterspoutidx2hm >= 5 then
                    player.sg:GoToState("knockback", {
                        knocker = lastwaterspout,
                        radius = inst.waterspoutidx2hm,
                        forcelanded = false,
                        propsmashed = true,
                        disableworldcollision2hm = true
                    })
                else
                    player:PushEvent("knockback", {
                        knocker = lastwaterspout,
                        radius = inst.waterspoutidx2hm,
                        forcelanded = false,
                        propsmashed = true,
                        disableworldcollision2hm = true
                    })
                end
            end
        end
    end
end
local function oncrabkingsleep(inst)
    if inst.healselftask2hm then
        inst.healselftask2hm:Cancel()
        inst.healselftask2hm = nil
    end
    if inst.listenboats2hm then
        for index, boat in ipairs(inst.listenboats2hm) do
            if boat and boat:IsValid() then
                boat.crabking2hm = nil
                boat:RemoveEventCallback("healthdelta", boathealthdelta)
            end
        end
        inst.listenboats2hm = nil
    end
end
local function doboatplayerattack(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRangeSq(x, y, z, 6400, true)
    inst.listenboats2hm = inst.listenboats2hm or {}
    for index, player in ipairs(players) do
        local boat = player:GetCurrentPlatform()
        if boat and boat:IsValid() and boat.components.health and not boat.components.health:IsDead() and not table.contains(boats, boat) then
            table.insert(inst.listenboats2hm, boat)
            boat.crabking2hm = inst
            boat:ListenForEvent("healthdelta", boathealthdelta)
        end
    end
end

local function clearlastwaterspout(inst) if lastwaterspout and lastwaterspout == inst then lastwaterspout = nil end end
AddPrefabPostInit("crab_king_waterspout", function(inst)
    if not TheWorld.ismastersim then return end
    lastwaterspout = inst
    inst:DoTaskInTime(0, clearlastwaterspout)
end)
if not sharkboi then 
    AddStategraphPostInit("wilson", function(sg)
        local knockback = sg.states.knockback.onenter
        sg.states.knockback.onenter = function(inst, data, ...)
            knockback(inst, data, ...)
            if inst.sg.currentstate and inst.sg.currentstate.name == "knockback" and data and data.disableworldcollision2hm and TheWorld.has_ocean then
                inst.sg.statemem.disableworldcollision2hm = true
                inst.Physics:ClearCollidesWith(COLLISION.WORLD)
                inst.Physics:CollidesWith(COLLISION.GROUND)
                inst.sg.statemem.safepos = nil
                if inst:HasTag("wereplayer") then inst.AnimState:PlayAnimation("idle_loop", true) end
            end
        end
        local knockbackonexit = sg.states.knockback.onexit
        sg.states.knockback.onexit = function(inst, ...)
            knockbackonexit(inst, ...)
            if inst.sg.statemem.disableworldcollision2hm then
                inst.Physics:ClearCollidesWith(COLLISION.GROUND)
                inst.Physics:CollidesWith(COLLISION.WORLD)
                local x, y, z = inst.Transform:GetWorldPosition()
                inst.Physics:Teleport(x, 0.1, z)
                inst.Physics:Stop()
            end
        end
    end)
end

-- 帝王蟹驱散附近的蒸腾海域
local function clearboilingwater(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 16, {"CLASSIFIED"})
    for index, ent in ipairs(ents) do if ent and ent:IsValid() and ent.prefab == "boiling_water_spawner" then ent:DoTaskInTime(0, ent.Remove) end end
end

-- -- 帝王蟹现在有守护蟹钳防卫
AddPrefabPostInit("crabking2hm", function(inst)
--     if not TheWorld.ismastersim then return end
--     inst.counthelpclaw2hm = counthelpclaw2hm
--     local oldcountgems = inst.countgems
--     inst.countgems = function(inst)
--         local gems = oldcountgems(inst)
--         local specialarmsNum = math.ceil(inst:counthelpclaw2hm() / 3)
--         gems.green = gems.green + specialarmsNum
--         gems.yellow = gems.yellow + specialarmsNum
--         gems.orange = gems.orange + specialarmsNum
--         gems.red = gems.red + specialarmsNum
--         gems.blue = gems.blue + specialarmsNum
--         gems.purple = gems.purple + specialarmsNum
--         return gems
--     end
--     inst:ListenForEvent("GetAttacked_Internal2hm", GetAttacked_Internal2hm)
--     local finishfixing = inst.finishfixing
--     inst.finishfixing = function(inst, ...)
--         finishfixing(inst, ...)
--         if inst.components.freezable then inst.components.freezable:Unfreeze() end
--     end
    -- if TUNING.DSTU then
        -- local startcastspell = inst.startcastspell
        -- inst.startcastspell = function(inst, freeze, ...)
        --     startcastspell(inst, freeze, ...)
        --     if freeze then clearboilingwater(inst) end
        -- end
        local endcastspell = inst.endcastspell
        inst.endcastspell = function(inst, freeze, ...)
            endcastspell(inst, freeze, ...)
            -- if freeze then clearboilingwater(inst) end
            doboatplayerattack(inst)
        end
    -- end
--     inst:ListenForEvent("activate", oncrabkingactivata)
--     inst:ListenForEvent("entitysleep", oncrabkingsleep)
--     if inst.components.health and not inst.components.health.avoidKill2hm then
--         inst.components.health.avoidKill2hm = true
--         local Kill = inst.components.health.Kill
--         inst.components.health.Kill = nilfn
--     end
--     if inst.components.trader and inst.components.trader.onaccept then
--         -- 镶嵌6种宝石会升级为彩虹宝石，最后1个宝石不触发
--         local onaccept = inst.components.trader.onaccept
--         inst.components.trader.onaccept = function(inst, giver, item, ...)
--             onaccept(inst, giver, item, ...)
--             if inst:HasTag("hostile") or #inst.socketed < 6 then return end
--             local gems = {redgem = 0, bluegem = 0, purplegem = 0, orangegem = 0, yellowgem = 0, greengem = 0}
--             for i, socket in ipairs(inst.socketed) do if socket.itemprefab and gems[socket.itemprefab] then gems[socket.itemprefab] = 1 end end
--             for itemprefab, value in pairs(gems) do if value == 0 then return end end
--             local realgems = {}
--             for i, socket in ipairs(inst.socketed) do
--                 if gems[socket.itemprefab] == 1 then
--                     gems[socket.itemprefab] = 0
--                 else
--                     table.insert(realgems, SpawnPrefab(socket.itemprefab))
--                 end
--             end
--             table.insert(realgems, SpawnPrefab("opalpreciousgem"))
--             inst.socketed = {}
--             inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
--             inst.AnimState:ClearOverrideSymbol("gems_blue")
--             for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
--             for i, gem in ipairs(realgems) do
--                 onaccept(inst, giver, gem, ...)
--                 if gem:IsValid() then gem:Remove() end
--             end
--         end
--         -- 非战败，只掉落最后一颗宝石
--         local dropgems = inst.dropgems
--         inst.dropgems = function(inst, ...)
--             if inst.components.health and inst.components.health:IsDead() then return dropgems(inst, ...) end
--             local drop = math.random(7, 8)
--             if #inst.socketed < drop then return end
--             local realgems = {}
--             for i, socket in ipairs(inst.socketed) do
--                 if i < drop then
--                     table.insert(realgems, SpawnPrefab(socket.itemprefab))
--                 else
--                     local gem = SpawnPrefab(socket.itemprefab)
--                     inst.components.lootdropper:FlingItem(gem)
--                 end
--             end
--             inst.socketed = {}
--             inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
--             inst.AnimState:ClearOverrideSymbol("gems_blue")
--             for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
--             for i, gem in ipairs(realgems) do
--                 onaccept(inst, inst, gem, ...)
--                 if gem:IsValid() then gem:Remove() end
--             end
--         end
--     end
end)

-- -- 蟹钳现在会在帝王蟹半血后守护蟹钳
-- require "brains/crabkingclawbrain"
-- local function ShouldClampCrabking(inst)
--     if inst:HasTag("swc2hm") then return end
--     if inst:IsValid() and not inst.sg:HasStateTag("busy") then
--         local x, y, z = inst.Transform:GetWorldPosition()
--         if inst.tofindcrab2hm and inst.crabking2hm and inst.crabking2hm:IsValid() and inst:IsNear(inst.crabking2hm, 2.5) then
--             inst:PushEvent("clamp", {target = inst.crabking2hm})
--             return
--         end
--         local ents = TheSim:FindEntities(x, y, z, 4.5, {"boat"})
--         if #ents > 0 then for i = #ents, 1, -1 do if not ents[i]:IsValid() or ents[i].components.health:IsDead() then table.remove(ents, i) end end end
--         if #ents > 0 then inst:PushEvent("clamp", {target = ents[1]}) end
--     end
-- end
-- local function findcrabkingtoclamp(inst)
--     if inst:HasTag("swc2hm") then return end
--     if not inst.tofindcrab2hm then
--         local x, y, z = inst.Transform:GetWorldPosition()
--         local ents = TheSim:FindEntities(x, y, z, TUNING.crabkinghide2hm and 20 or 10, {"boat"})
--         if #ents > 0 then
--             return Vector3(ents[1].Transform:GetWorldPosition())
--         else
--             inst.tofindcrab2hm = true
--         end
--     end
--     if inst.tofindcrab2hm then
--         local x, y, z = inst.Transform:GetWorldPosition()
--         if not (inst.crabking2hm and inst.crabking2hm:IsValid()) then
--             local ents = TheSim:FindEntities(x, y, z, 10, {"crabking", "epic"})
--             if #ents > 0 and ents[1] and ents[1]:IsValid() then inst.crabking2hm = ents[1] end
--         end
--         if inst.crabking2hm and inst.crabking2hm:IsValid() and inst.crabking2hm.components.health and not inst.crabking2hm.components.health:IsDead() and
--             inst.crabking2hm.components.health:GetPercent() < 0.35 and inst.crabking2hm.arms and inst.armpos and inst.crabking2hm.arms[inst.armpos] == inst then
--             if inst.components.locomotor ~= nil then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "crabkingclaw2hm", 2) end
--             return Vector3(inst.crabking2hm.Transform:GetWorldPosition())
--         else
--             if inst.components.locomotor ~= nil then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "crabkingclaw2hm", 0) end
--             inst.tofindcrab2hm = nil
--         end
--     end
-- end
-- AddBrainPostInit("crabkingclawbrain", function(self)
--     if self.inst:HasTag("swc2hm") then return end
--     if self.bt.root.children and self.bt.root.children[1] and self.bt.root.children[1].children and self.bt.root.children[1].children[2] and
--         self.bt.root.children[1].children[2].children then
--         local newaction = DoAction(self.inst, ShouldClampCrabking, "clamp!")
--         table.insert(self.bt.root.children[1].children[2].children, 2, newaction)
--         local newleash = Leash(self.inst, function() return findcrabkingtoclamp(self.inst) end, 0, 0, false)
--         table.insert(self.bt.root.children[1].children[2].children, 3, newleash)
--     end
-- end)

-- 帝王蟹释放冰冻
local function startfeeze(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("dwx_feeze")
    fx.crab = inst
    fx.Transform:SetPosition(x, y, z)
    local scale = 0.75 + Remap(inst.countgems(inst).blue, 0, 9, 0, 1.55)
    fx.Transform:SetScale(scale, scale, scale)
    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/magic_LP", "crabmagic")
    clearboilingwater(inst)
end
-- 蒸腾海域会被海浪吹走,帝王蟹检测到就会释放冰霜领域
local function checkcrabkingfreeze(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 16, nil, nil, {"crabking_spellgenerator", "CLASSIFIED", "crabking"})
    for index, ent in ipairs(ents) do
        if ent and ent:IsValid() then
            if ent.prefab == "dwx_feeze" or (ent.prefab == "boiling_water_spawner" and ent ~= inst) then
                inst:Remove()
            elseif ent.prefab == "crabking2hm" and ent:HasTag("hostile") and not ent.components.timer:TimerExists("casting_timer2hm") then
                ent.components.timer:StartTimer("casting_timer2hm", (TUNING.CRABKING_CAST_TIME_FREEZE - math.floor(ent.countgems(ent).yellow / 2)) * 2)
                startfeeze(ent)
            end
        end
    end
end
AddPrefabPostInit("boiling_water_spawner", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.inventoryitem then
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.canbepickedup = false
        inst.components.inventoryitem.pushlandedevents = false
    end
    inst:DoTaskInTime(0, checkcrabkingfreeze)
end)
-- -- 帝王蟹生成海浪
-- local function spawnwaves(inst, numWaves, totalAngle, waveSpeed, wavePrefab, initialOffset, idleTime, instantActivate, random_angle)
--     SpawnAttackWaves(inst:GetPosition(), (not random_angle and inst.Transform:GetRotation()) or nil,
--                      initialOffset or (inst.Physics and inst.Physics:GetRadius() + 1) or nil, numWaves, totalAngle, waveSpeed, wavePrefab, idleTime,
--                      instantActivate)
-- end

-- -- 帝王蟹下沉;下沉时释放海蚀柱技能,持续释放冰霜技能,下沉12秒后持续释放气泡技能,20秒后上升,释放气泡/冰霜/海浪技能
-- local disappearstate = State {
--     name = "disappear2hm",
--     tags = {"idle", "canrotate", "noattack", "inert", "canwxscan"},
--     onenter = function(inst)
--         inst.AnimState:PlayAnimation("disappear")
--         inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/disappear")
--         ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, 40)
--         inst.sg:SetTimeout(20)
--         inst.hide2hm = true
--         TUNING.crabkinghide2hm = true
--         spawnwaves(inst, 8, 360, 4, nil, nil, 1.5, true, true) -- 2 1
--     end,
--     events = {
--         EventHandler("animover", function(inst)
--             inst.Physics:SetActive(false)
--             inst:Hide()
--             inst.sg:AddStateTag("temp_invincible")
--             -- 下沉时做些事情吧
--             if not inst.components.timer:TimerExists("spawnstacks2hm") then
--                 local pos = Vector3(inst.Transform:GetWorldPosition())
--                 local cdchange = math.max(0, TUNING.CRABKING_STACKS - #TheSim:FindEntities(pos.x, 0, pos.z, 20, SEASTACK_TAGS))
--                 inst.components.timer:StartTimer("spawnstacks2hm", (noshadowworld and 6 or 4) * cdchange)
--                 inst.spawnstacks(inst)
--             end
--             inst.regenarm(inst)
--             startfeeze(inst)
--         end)
--     },
--     onupdate = function(inst)
--         -- 下沉后做些事情吧
--         if not inst.startcastspell2hm and inst.sg.timeinstate > 12 then
--             inst.startcastspell2hm = true
--             inst.startcastspell(inst, false)
--         end
--     end,
--     ontimeout = function(inst)
--         inst.startcastspell2hm = nil
--         inst.sg:GoToState("reappear2hm")
--     end
-- }

-- local reappearstate = State {
--     name = "reappear2hm",
--     tags = {"idle", "canrotate", "noattack", "inert", "canwxscan"},
--     onenter = function(inst)
--         inst.hide2hm = nil
--         inst.Physics:SetActive(true)
--         inst:Show()
--         inst.AnimState:PlayAnimation("reappear")
--         inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/appear")
--         ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, 40)
--         -- 上升时做些事情吧
--         local x, y, z = inst.Transform:GetWorldPosition()
--         local ents = TheSim:FindEntities(x, y, z, 8, {"boat"})
--         if #ents > 0 then for index, ent in ipairs(ents) do if ent.components.health then ent.components.health:Kill() end end end
--         inst.endcastspell(inst, false)
--         inst.components.timer:StopTimer("heal_cooldown")
--         spawnwaves(inst, 8, 360, 4, nil, nil, 1.5, true, true) -- 2 1
--         TUNING.crabkinghide2hm = nil
--     end,
--     events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
-- }

-- AddStategraphState("crabking", disappearstate)
-- AddStategraphState("crabking", reappearstate)

-- AddStategraphPostInit("crabking", function(sg)
--     local oldOnEnteridle = sg.states.idle.onenter
--     sg.states.idle.onenter = function(inst, ...)
--         -- 自愈技能不在时使用下沉
--         if inst:HasTag("hostile") and inst.components.health:GetPercent() > 0.5 and inst.arms then
--             for i, arm in ipairs(inst.arms) do
--                 if arm.prefab and arm:IsValid() and arm.boat and arm.boat.prefab == "crabking" then arm:PushEvent("releaseclamp") end
--             end
--         end
--         if not inst.components.timer:TimerExists("disappeartimer2hm") and inst.components.health and inst.components.health:GetPercent() < 0.8 and
--             not inst.hide2hm then
--             inst.wantstocast = nil
--             inst.dofreezecast = nil
--             inst.components.timer:StartTimer("disappeartimer2hm", noshadowworld and 90 or 60)
--             inst.sg:GoToState("disappear2hm")
--             return
--         elseif inst.components.timer:TimerExists("disappeartimer2hm") and inst.components.health and inst.components.health:GetPercent() < 0.3 and
--             not inst.resethidetimer2hm and not inst.hide2hm then
--             inst.resethidetimer2hm = true
--             inst.wantstocast = nil
--             inst.dofreezecast = nil
--             inst.components.timer:SetTimeLeft("disappeartimer2hm", noshadowworld and 90 or 60)
--             inst.sg:GoToState("disappear2hm")
--             return
--         end
--         oldOnEnteridle(inst, ...)
--     end
--     -- 自愈时给自己附加减伤并施放海浪
--     local oldOnfix_preidle = sg.states.fix_pre.onenter
--     sg.states.fix_pre.onenter = function(inst, ...)
--         if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.75, "crabking2hm") end
--         spawnwaves(inst, 8, 360, 4, nil, nil, 1.5, true, true) -- 2 1
--         oldOnfix_preidle(inst, ...)
--     end
--     local oldOnfix_pstidle = sg.states.fix_pst.onenter
--     sg.states.fix_pst.onenter = function(inst, ...)
--         if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "crabking2hm") end
--         oldOnfix_pstidle(inst, ...)
--     end
--     -- 放魔法时额外放海蚀柱
--     local oldOncast_preidle = sg.states.cast_pre.onenter
--     sg.states.cast_pre.onenter = function(inst, ...)
--         if not inst.components.timer:TimerExists("spawnstacks2hm") then
--             local pos = Vector3(inst.Transform:GetWorldPosition())
--             local cdchange = math.max(0, TUNING.CRABKING_STACKS - #TheSim:FindEntities(pos.x, 0, pos.z, 20, SEASTACK_TAGS))
--             inst.components.timer:StartTimer("spawnstacks2hm", (noshadowworld and 6 or 4) * cdchange)
--             inst.spawnstacks(inst)
--         elseif inst.components.health and inst.components.health:GetPercent() < 0.3 and not inst.resetstacks2hm and
--             inst.components.timer:TimerExists("spawnstacks2hm") then
--             inst.resetstacks2hm = true
--             local pos = Vector3(inst.Transform:GetWorldPosition())
--             local cdchange = math.max(0, TUNING.CRABKING_STACKS - #TheSim:FindEntities(pos.x, 0, pos.z, 20, SEASTACK_TAGS))
--             inst.components.timer:SetTimeLeft("spawnstacks2hm", (noshadowworld and 6 or 4) * cdchange)
--             inst.spawnstacks(inst)
--         end
--         oldOncast_preidle(inst, ...)
--     end
-- end)

-- 海蚀柱消失时生成野生蟹钳
local function seastackhit(inst)
    if math.random() < 0.5 then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 30, {"crabking", "epic"})
    if #ents > 0 then
        local arm = SpawnPrefab("crabking2hm_claw")
        arm.Transform:SetPosition(x, y, z)
    end
end
AddPrefabPostInit("seastack", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", seastackhit)
end)

-- 三叉戟会让帝王蟹立即刷新技能
AddPrefabPostInit("trident", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.spellcaster then
        local oldspell = inst.components.spellcaster.spell
        inst.components.spellcaster.spell = function(inst, ...)
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 64, {"crabking", "epic"}, nil)
            if #ents > 0 then
                for i, ent in pairs(ents) do
                    if ent and ent.components.health and not ent.components.health:IsDead() and ent.sg and ent.sg.currentstate and
                        ((ent.sg.currentstate.name == "cast_loop" and ent.components.timer and ent.components.timer:TimerExists("casting_timer")) or
                            ent.sg.currentstate.name == "disappear2hm") then
                        local tmp = ent.isfreezecast
                        if ent.sg.currentstate.name == "disappear2hm" then tmp = false end
                        ent.startcastspell(ent, tmp)
                        ent.endcastspell(ent, tmp)
                        break
                    end
                end
            end
            return oldspell(inst, ...)
        end
    end
end)
