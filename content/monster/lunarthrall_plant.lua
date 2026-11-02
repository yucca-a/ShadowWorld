-- 亮茄更多藤蔓
TUNING.LUNARTHRALL_PLANT_VINE_LIMIT = math.max(TUNING.LUNARTHRALL_PLANT_VINE_LIMIT, 3)
-- 亮茄血量阈值后转换位置
local function spawnreplacedself(inst, target)
    if TheWorld.components.lunarthrall_plantspawner then
        target.lunarthrall2hmhealth = inst.components.health:GetPercent()
        if target.lunarthrall2hmhealthtask then target.lunarthrall2hmhealthtask:Cancel() end
        target.lunarthrall2hmhealthtask = target:DoTaskInTime(45, function()
            target.lunarthrall2hmhealthtask = nil
            if target.lunarthrall2hmhealth then target.lunarthrall2hmhealth = nil end
        end)
        local thrall = SpawnPrefab("lunarthrall_plant_gestalt")
        thrall.plant_target = target
        thrall.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if inst.components.lootdropper then inst.components.lootdropper:SetLoot(nil) end
        inst.components.health:Kill()
    end
end
local function onhealthtrigger(inst)
    if inst:IsValid() and inst.components.health and not inst.components.health:IsDead() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.LEIF_MAXSPAWNDIST, {"lunarplant_target"}, {"burnt", "fire", "NOCLICK", "isdead"})
        if #ents > 0 then
            for _, v in ipairs(ents) do
                if v.prefab == "lureplant" and not v.lunarthrall2hmhealthtask then
                    spawnreplacedself(inst, v)
                    return
                end
            end
            local ent = ents[math.random(#ents)]
            spawnreplacedself(inst, ent)
        elseif inst.target2hm and inst.target2hm:IsValid() then
            spawnreplacedself(inst, inst.target2hm)
        end
    end
end
local function sethealthtrigger(inst)
    if not inst.target2hm then
        inst.vinelimit = 5
    elseif inst.components.health then
        local percent = inst.components.health:GetPercent()
        if percent > 0.7 then
            inst.vinelimit = 1
        elseif percent > 0.4 then
            inst.vinelimit = 3
        else
            inst.vinelimit = 5
        end
    end
    if inst.components.healthtrigger then
        inst.components.healthtrigger:AddTrigger(0.66731, onhealthtrigger)
        inst.components.healthtrigger:AddTrigger(0.33331, onhealthtrigger)
    end
end
-- 亮茄反弹远程伤害
local function lunarthrallGetAttacked_Internal(inst, data)
    if not inst.tired and data and ((data.weapon and data.weapon:IsValid() and
        (not data.weapon:IsNear(inst, 3.75) or data.weapon.components.projectile or (data.weapon.components.weapon and data.weapon.components.weapon.projectile))) or
        (data.attacker and data.attacker:IsValid() and not data.attacker:IsNear(inst, 3.75))) and not inst:HasDebuff("forcefield") then
        inst:AddDebuff("forcefield", "abigailforcefieldretaliation")
    end
end
local function onlunarthrallattacked(inst, data)
    if not inst.tired and inst:HasDebuff("forcefield") and data and data.attacker and data.attacker.components.combat then
        local retaliation = SpawnPrefab("abigail_retaliation")
        retaliation:SetRetaliationTarget(data.attacker)
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/on")
    end
end
-- 显示错误状态来欺骗玩家,正常状态可以假装成疲劳状态恢复血量和三维
local function OnWakeTask(inst)
    inst.waketask2hm2hm = nil
    if not inst.components.health:IsDead() and inst.sg.laststate and inst.sg.laststate.name == "idle" and inst.showtired2hm then
        inst.vinelimit = TUNING.LUNARTHRALL_PLANT_VINE_LIMIT - #inst.vines
        inst.showtiredpst2hm = true
        inst.showtired2hm = nil
    end
end
AddStategraphPostInit("lunarthrall_plant", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if idle then idle(inst, ...) end
        if inst.showidle2hm then inst.showidle2hm = nil end
        if inst.showtiredpre2hm then
            -- 伪装之假装准备疲惫
            inst.showtiredpre2hm = nil
            if inst.sg.laststate and inst.sg.laststate.name == "idle" then
                inst.showtired2hm = true
                inst:customPlayAnimation("tired_pre_" .. inst.targetsize)
                inst.SoundEmitter:PlaySound("rifts/lunarthrall/tired_pre")
            end
        elseif inst.showtired2hm then
            -- 伪装之假装疲惫,且会开始恢复藤曼状态
            if inst.sg.laststate and inst.sg.laststate.name == "idle" then
                if not inst.waketask2hm2hm then
                    inst.waketask2hm2hm = inst:DoTaskInTime(TUNING.LUNARTHRALL_PLANT_WAKE_TIME + TUNING.LUNARTHRALL_PLANT_REST_TIME, OnWakeTask)
                end
                inst:customPlayAnimation("tired_loop_" .. inst.targetsize)
            else
                inst.showtired2hm = nil
                if inst.waketask2hm2hm then
                    inst.waketask2hm2hm:Cancel()
                    inst.waketask2hm2hm = nil
                end
            end
        elseif inst.showtiredpst2hm then
            -- 伪装之藤曼状态恢复完成,解除伪装
            if inst.sg.laststate and inst.sg.laststate.name == "idle" then
                inst.showtiredpst2hm = nil
                inst:customPlayAnimation("tired_pst_" .. inst.targetsize)
            else
                inst.showtiredpst2hm = nil
            end
        elseif (#inst.vines + inst.vinelimit) < TUNING.LUNARTHRALL_PLANT_VINE_LIMIT then
            -- 丢失藤曼后,开始伪装
            inst.showtiredpre2hm = math.random() < 0.45
            inst.showtired2hm = nil
        end
    end
    local tired_pre = sg.states.tired_pre.onenter
    sg.states.tired_pre.onenter = function(inst, ...)
        if tired_pre then tired_pre(inst, ...) end
        if inst.showidle2hm then inst.showidle2hm = nil end
        if inst.showtiredpre2hm then inst.showtiredpre2hm = nil end
        if inst.showtired2hm then inst.showtired2hm = nil end
        if inst.showtiredpst2hm then inst.showtiredpst2hm = nil end
        if inst.waketask2hm2hm then
            inst.waketask2hm2hm:Cancel()
            inst.waketask2hm2hm = nil
        end
        if inst.showtired2hm and inst.sg.laststate and inst.sg.laststate.name == "idle" then inst.sg:GoToState("tired") end
    end
    local tired = sg.states.tired.onenter
    sg.states.tired.onenter = function(inst, ...)
        if tired then tired(inst, ...) end
        if inst.showtiredpst2hm then
            inst.showtiredpst2hm = nil
            inst.showidle2hm = true
            inst:customPlayAnimation("tired_pst_" .. inst.targetsize)
        elseif inst.showidle2hm then
            inst:customPlayAnimation("idle_" .. inst.targetsize)
        elseif not inst.sg.laststate or inst.sg.laststate.name ~= "tired" then
            inst.showtiredpst2hm = math.random() < 0.45
            inst.showidle2hm = nil
        end
    end
end)
-- 亮茄血量越低,藤蔓越多,且寄生食人花会改变其再生速率,令其防火
AddPrefabPostInit("lunarthrall_plant", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.healthtrigger then
        inst:AddComponent("healthtrigger")
        inst:DoTaskInTime(0, sethealthtrigger)
    end
    inst:ListenForEvent("attacked", onlunarthrallattacked)
    inst:ListenForEvent("GetAttacked_Internal2hm", lunarthrallGetAttacked_Internal)
    local oldinfest = inst.infest
    inst.infest = function(inst, target, ...)
        inst.target2hm = target
        oldinfest(inst, target, ...)
        if target.lunarthrall2hmhealth and inst.components.health then
            inst.components.health:SetPercent(target.lunarthrall2hmhealth)
            target.lunarthrall2hmhealth = nil
        end
        local percent = inst.components.health:GetPercent()
        if percent > 0.8 then
            inst.vinelimit = 1
        elseif percent > 0.5 then
            inst.vinelimit = 3
        else
            inst.vinelimit = 5
        end
        if target and target:IsValid() and target.prefab == "lureplant" then
            target:AddTag("noattack")
            target:AddTag("notarget")
            target:AddTag("fireimmune")
            if target.components.health then
                target.components.health:StartRegen(50, 1)
                target.luredeath2hm = nil
            end
            if target.components.minionspawner then
                local self = target.components.minionspawner
                self.minionspawntime = {min = 0.5, max = 1}
                self.LongUpdate = nilfn
                self.minionpositions = nil
                self.shouldspawn = true
                if self.spawninprogress then self.spawninprogress = false end
                if self.task ~= nil then
                    self.task:Cancel()
                    self.task = nil
                end
                self:StartNextSpawn()
            end
        end
    end
    local olddeinfest = inst.deinfest
    inst.deinfest = function(inst, ...)
        local target = inst.target2hm
        inst.target2hm = nil
        olddeinfest(inst, ...)
        if target and target:IsValid() and target.prefab == "lureplant" then
            target:RemoveTag("noattack")
            target:RemoveTag("notarget")
            target:RemoveTag("fireimmune")
            if target.components.health then
                target.components.health:StartRegen(-10, 1)
                target.luredeath2hm = true
            end
        end
        inst.vinelimit = 5
    end
end)
-- 包括食人花在内的更多植物建筑可被寄生
local lureplantstoinfest = {}
local function checkpos(inst)
    if not inst:IsOnValidGround() then
        inst:RemoveTag("lunarplant_target")
        if inst.components.herdmember and inst.components.herdmember.herdprefab == "domesticplantherd" then
            inst.components.herdmember:Enable(false)
            inst:RemoveComponent("herdmember")
        end
    elseif inst.prefab == "lureplant" and not inst:HasTag("NOCLICK") and not table.contains(lureplantstoinfest, inst) then
        table.insert(lureplantstoinfest, inst)
    end
end
local lunarplant_targetplants = {"lureplant", "rock_avocado_bush", "bananabush", "monkeytail", "beebox", "mushroom_farm"}
for index, plant in ipairs(lunarplant_targetplants) do
    AddPrefabPostInit(plant, function(inst)
        inst:AddTag("lunarplant_target")
        if not TheWorld.ismastersim then return end
        if not inst.components.herdmember then
            inst:AddComponent("herdmember")
            inst.components.herdmember:SetHerdPrefab("domesticplantherd")
        end
        inst:DoTaskInTime(0, checkpos)
    end)
end
AddPrefabPostInit("farm_plant_dragonfruit", function(inst) inst:RemoveTag("lunarplant_target") end)
-- 春天裂隙刷新时,强制出现亮茄食人花
local function GetSpawnPointNearPlayer(minradius, maxradius)
    if #AllPlayers <= 0 then return end
    local groundplayers = {}
    for index, player in ipairs(AllPlayers) do if player and player:IsValid() and player:IsOnValidGround() then table.insert(groundplayers, player) end end
    if #groundplayers <= 0 then return end
    minradius = minradius or 24
    maxradius = maxradius or 36
    local player = groundplayers[math.random(#groundplayers)]
    if player and player:IsValid() then
        local pt = player:GetPosition()
        for i = 1, 10, 1 do
            local theta = math.random() * 2 * PI
            local radius = math.random() * (maxradius - minradius) + minradius
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local testpt = pt + offset
            if TheWorld.Map:IsVisualGroundAtPoint(testpt.x, testpt.y, testpt.z) then return testpt end
        end
    end
end
AddComponentPostInit("lunarthrall_plantspawner", function(self)
    local FindHerd = self.FindHerd
    self.FindHerd = function(self, ...)
        for i = #lureplantstoinfest, 1, -1 do
            local lureplant = lureplantstoinfest[i]
            if not (lureplant and lureplant:IsValid() and not lureplant:HasTag("NOCLICK") and lureplant.components.herdmember and lureplant.components.health and
                not lureplant.components.health:IsDead()) then table.remove(lureplantstoinfest, i) end
        end
        if math.random() < (TheWorld.state.isspring and 0.35 or 0.025) then
            for i = 1, 10, 1 do
                if #lureplantstoinfest > 2 then break end
                local pt = GetSpawnPointNearPlayer()
                if pt then
                    local plant = SpawnPrefab("lureplant")
                    if plant and plant:IsValid() then
                        plant.Physics:Teleport(pt:Get())
                        if plant.components.minionspawner and not plant.components.minionspawner:CheckTileCompatibility(TheWorld.Map:GetTileAtPoint(pt:Get())) then
                            plant:Remove()
                            return
                        end
                        plant.sg:GoToState("spawn")
                        table.insert(lureplantstoinfest, plant)
                    end
                end
            end
            local plant = lureplantstoinfest[1]
            if plant and plant:IsValid() then
                local herd = SpawnPrefab("domesticplantherd")
                if herd and herd:IsValid() then
                    herd.Transform:SetPosition(plant.Transform:GetWorldPosition())
                    for i = #lureplantstoinfest, 1, -1 do
                        local lureplant = lureplantstoinfest[i]
                        if lureplant and lureplant:IsValid() and not lureplant:HasTag("NOCLICK") and lureplant.components.herdmember and
                            lureplant.components.health and not lureplant.components.health:IsDead() then
                            lureplant.components.herdmember:Leave()
                            herd.components.herd:AddMember(lureplant)
                        end
                    end
                    return herd
                end
            end
        end
        return FindHerd(self, ...)
    end
end)
-- 亮茄寄生食人花产生的眼球草无地形限制
AddComponentPostInit("minionspawner", function(self)
    local CheckTileCompatibility = self.CheckTileCompatibility
    self.CheckTileCompatibility = function(self, ...)
        return self.inst.lunarthrall_plant and self.inst.lunarthrall_plant:IsValid() or CheckTileCompatibility(self, ...)
    end
end)
-- 非野生食人花初始只有1点血，野生食人花会直接长好眼球草
local function trygrowlureplant(inst)
    if inst:HasTag("planted") then
        if inst.components.health then inst.components.health:SetVal(1) end
    elseif inst.hibernatetask and inst.hibernatetask.fn and not TheWorld.state.iswinter then
        local fn = inst.hibernatetask.fn
        inst.hibernatetask:Cancel()
        inst:DoTaskInTime(0, function(inst) if not inst:HasTag("NOCLICK") then fn(inst) end end)
    end
end
AddStategraphPostInit("lureplant", function(sg)
    local spawn = sg.states.spawn.onexit
    sg.states.spawn.onexit = function(inst, ...)
        if spawn then spawn(inst, ...) end
        inst:DoTaskInTime(0, trygrowlureplant)
    end
    -- 有眼球草种植也会变野生，平时缓慢回血，收缩诱饵时快速回血
    local showbait = sg.states.showbait.onexit
    sg.states.showbait.onexit = function(inst, ...)
        if showbait then showbait(inst, ...) end
        if inst:HasTag("planted") and inst.components.minionspawner and inst.components.minionspawner.numminions > 0 then inst:RemoveTag("planted") end
        KillOffSnares(inst)
        if not inst.luredeath2hm then inst.components.health:StartRegen(1, TUNING.LUREPLANT_HIBERNATE_TIME / 300) end
        if inst.cloud2hm and not inst.cloud2hm:IsValid() then inst.cloud2hm = nil end
    end
    local hidebait = sg.states.hidebait.onexit
    sg.states.hidebait.onexit = function(inst, ...)
        if hidebait then hidebait(inst, ...) end
        if inst:HasTag("planted") and inst.components.minionspawner and inst.components.minionspawner.numminions > 0 then inst:RemoveTag("planted") end
        if not inst:HasTag("planted") and not inst.luredeath2hm and inst.components.shelf and inst.components.shelf.itemonshelf and
            inst.components.shelf.itemonshelf:IsValid() then inst.components.health:StartRegen(50, 1) end
    end
    -- 野生被采摘会快速掉血
    local picked = sg.states.picked.onexit
    sg.states.picked.onexit = function(inst, ...)
        if picked then picked(inst, ...) end
        if not inst.luredeath2hm and not inst:HasTag("planted") then
            inst.luredeath2hm = true
            inst.components.health:StartRegen(-50, 1)
        end
    end
end)
-- 毒雾不再伤害植物和蔬菜了
AddPrefabPostInit("sporecloud", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.aura and inst.components.aura.auraexcludetags then
        table.insert(inst.components.aura.auraexcludetags, "plant")
        table.insert(inst.components.aura.auraexcludetags, "veggie")
    end
end)
-- 食人花不在船上被采摘,野生被高伤害攻击或残血时释放毒雾和荆棘
local function onlureplantattacked(inst, data)
    if not inst:HasTag("planted") and inst.components.shelf and
        (data and (data.force or (data.damage and data.damage > 50 and inst.components.shelf.itemonshelf and inst.components.shelf.itemonshelf:IsValid())) or
            inst.components.health:GetPercent() < 0.35 and inst.components.shelf.itemonshelf and inst.components.shelf.itemonshelf:IsValid()) and
        not (inst.cloud2hm and inst.cloud2hm:IsValid()) then
        inst.cloud2hm = SpawnPrefab("sporecloud")
        inst.cloud2hm.Transform:SetPosition(inst.Transform:GetWorldPosition())
        SpawnDefendIvyPlant(inst, inst, true, 24, TUNING.TOADSTOOL_SPORECLOUD_RADIUS + 0.5)
    end
end
-- 食人花默认会慢速回血
AddPrefabPostInit("lureplant", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then inst.components.health:StartRegen(1, TUNING.LUREPLANT_HIBERNATE_TIME / 300) end
    inst:ListenForEvent("attacked", onlureplantattacked)
    local ontakeitemfn = inst.components.shelf.ontakeitemfn
    inst.components.shelf.ontakeitemfn = function(inst, ...)
        ontakeitemfn(inst, ...)
        local boat = inst:GetCurrentPlatform()
        if not (boat and boat:IsValid() and boat:HasTag("boat")) then onlureplantattacked(inst, {damage = 60, force = true}) end
    end
end)
-- 眼球草不再内斗,血量提高
local RETARGET_MUST_TAGS = {"_combat", "_health"}
local RETARGET_CANT_TAGS = {"magicgrowth", "INLIMBO", "plantkin", "plant", "veggie"}
local RETARGET_ONEOF_TAGS = {"character", "monster", "animal", "prey"}
local function retargetfn(inst)
    return FindEntity(inst, TUNING.EYEPLANT_ATTACK_DIST, function(guy) return not guy.components.health:IsDead() end, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS,
                      RETARGET_ONEOF_TAGS)
end
TUNING.EYEPLANT_HEALTH = TUNING.EYEPLANT_HEALTH * 10 / 3
AddPrefabPostInit("eyeplant", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat and inst.components.combat.targetfn then inst.components.combat:SetRetargetFunction(0.5, retargetfn) end
end)

-- 天体裂隙周围有月亮风暴
if GetModConfigData("moonisland") then
    local function processmoonstormnode(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z)
        if TheWorld.net.components.moonstorms2hm and node_index then TheWorld.net.components.moonstorms2hm:AddNewMoonstormNode(node_index, x, y, z) end
    end
    local function delaymoonstorm(inst) inst:DoTaskInTime(0, processmoonstormnode) end
    local function returnriftspawner(inst) if TheWorld.components.riftspawner then TheWorld.components.riftspawner:AddRiftToPool(inst, inst.prefab) end end
    AddPrefabPostInit("lunarrift_portal", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, returnriftspawner)
        inst:DoTaskInTime(0, processmoonstormnode)
        inst:WatchWorldState("moonphase", delaymoonstorm)
        inst:WatchWorldState("cycles", delaymoonstorm)
    end)
    AddPrefabPostInit("lunarrift_crystal_big", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, processmoonstormnode)
        inst:WatchWorldState("moonphase", delaymoonstorm)
        inst:WatchWorldState("cycles", delaymoonstorm)
    end)
end

-- local TileManager = require("tilemanager")
-- local _AddTile = TileManager.AddTile
-- TileManager.AddTile = function(tile_name, tile_range, tile_data, ground_tile_def, ...)
--     if tile_name == "RIFT_MOON" and ground_tile_def and ground_tile_def.cannotbedug then ground_tile_def.cannotbedug = false end
--     return _AddTile(tile_name, tile_range, tile_data, ground_tile_def, ...)
-- end
-- local function getrifts() return TheWorld.components.riftspawner and TheWorld.components.riftspawner:GetRiftsOfPrefab("lunarrift_portal") or nil end

-- AddComponentPostInit("terraformer", function(self)
--     if TheWorld and not TheWorld.components.riftspawner then return end
--     local Terraform = self.Terraform
--     self.Terraform = function(self, pt, doer, ...)
--         local rifts = getrifts()
--         if rifts then for _, rift in ipairs(rifts) do if rift and rift:IsValid() and rift:GetDistanceSqToPoint(pt) < 1000 then return false end end end
--         return Terraform(self, pt, doer, ...)
--     end
-- end)

-- TheWorld.components.lunarthrall_plantspawner:SpawnPlant(c_spawn("lureplant"))

-- AddPrefabPostInit("domesticplantherd", function(inst)
--     if not TheWorld.ismastersim then return end
--     if inst.components.herd and not inst.components.herd.addmember then inst.components.herd.addmember:SetAddMemberFn() end
-- end)

-- 新三王加强
