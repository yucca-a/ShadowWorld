local disguise = GetModConfigData("cave_entrance") == true
-- 被堵住的洞口也会刷新蝙蝠了
local function ReturnChildren(inst)
    if inst.components.childspawner then
        for k, child in pairs(inst.components.childspawner.childrenoutside) do
            if child.components.homeseeker ~= nil then child.components.homeseeker:GoHome() end
            child:PushEvent("gohome")
        end
    end
end
-- 召唤直接从天上飞下来的蝙蝠
local function resetbathome(bat, inst) if inst and inst:IsValid() and bat and bat:IsValid() then bat.components.homeseeker:SetHome(inst) end end
local function summerflybats(inst, index, target, radius)
    local self = inst.components.childspawner
    if self.childreninside < index then self.childreninside = index end
    for i = 1, index, 1 do
        local child = self:DoSpawnChild(target, nil, radius or 5)
        if child then
            self.childreninside = self.childreninside - 1
            self:TakeOwnership(child)
            if child.components.homeseeker then
                child.components.homeseeker:SetHome(nil)
                child:DoTaskInTime(10, resetbathome, inst)
            end
            child:PushEvent("fly_back")
        end
    end
    if self.childreninside == 0 and self.onvacate ~= nil then self.onvacate(self.inst) end
end
-- 控制黄昏是是否刷出蝙蝠,现在伪装后夜间必定会飞出来蝙蝠了
local function OnIsDay(inst, isday)
    if not inst.components.childspawner then return end
    if isday then
        if inst.prefab == "cave_entrance" then
            inst.components.childspawner:StartRegen()
            inst.components.childspawner:StopSpawning()
            ReturnChildren(inst)
        end
    elseif disguise and inst:IsInLimbo() then
        local num = math.random(2, 3) - inst.components.childspawner.numchildrenoutside
        if num > 0 then summerflybats(inst, num, nil, math.random(7, 20)) end
    end
end
local function OnPreLoad(inst, data)
    WorldSettings_ChildSpawner_PreLoad(inst, data, TUNING.CAVE_ENTRANCE_BATS_SPAWN_PERIOD, TUNING.CAVE_ENTRANCE_BATS_REGEN_PERIOD)
end
local function DoSpooked(inst, source)
    local oldSay = inst.components.talker.Say
    inst:DoTaskInTime(19 * FRAMES, function() inst.components.talker.Say = nilfn end)
    inst:PushEvent("spooked", {source = source})
    inst:DoTaskInTime(21 * FRAMES, function() inst.components.talker.Say = oldSay end)
end
local function batfx(inst, worker)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("battreefx")
    fx.Transform:SetPosition(x, -.1, z)
    if fx.SetViewerAndAnim ~= nil then fx:SetViewerAndAnim(worker, "evergreen_old") end
    if worker and worker:HasTag("player") and worker.components.talker then worker:DoTaskInTime(10 * FRAMES, DoSpooked, inst) end
end
local function cave_entrance_worked(inst, data)
    if not (data and data.workleft and data.workleft > 0 and data.worker and data.worker:IsValid()) then return end
    if inst.components.childspawner.childreninside > 1 then batfx(inst, data.worker) end
    summerflybats(inst, math.clamp(inst.components.childspawner.childreninside, 1, 3), data.worker, math.random(3, 6))
end
local function cave_entrance_workfinished(inst, data)
    if inst.components.worldmigrator and inst.components.worldmigrator.id and TheWorld.components.persistent2hm and
        TheWorld.components.persistent2hm.data.unlockShardPortals then
        table.insert(TheWorld.components.persistent2hm.data.unlockShardPortals, inst.components.worldmigrator.id)
    end
end
local function setbatsentrance(inst)
    if not inst.components.workable or inst.components.childspawner then return end
    inst:AddComponent("childspawner")
    inst.components.childspawner:SetRegenPeriod(TUNING.CAVE_ENTRANCE_BATS_REGEN_PERIOD)
    inst.components.childspawner:SetSpawnPeriod(TUNING.CAVE_ENTRANCE_BATS_SPAWN_PERIOD)
    inst.components.childspawner:SetMaxChildren(TUNING.CAVE_ENTRANCE_BATS_MAX_CHILDREN)
    WorldSettings_ChildSpawner_SpawnPeriod(inst, TUNING.CAVE_ENTRANCE_BATS_SPAWN_PERIOD, true)
    WorldSettings_ChildSpawner_RegenPeriod(inst, TUNING.CAVE_ENTRANCE_BATS_REGEN_PERIOD, true)
    inst.components.childspawner.childname = "bat"
    inst:ListenForEvent("worked", cave_entrance_worked)
    inst:ListenForEvent("workfinished", cave_entrance_workfinished)
    local oldonwork = inst.components.workable.onwork
    inst.components.workable:SetOnWorkCallback(function(inst, worker, ...) oldonwork(inst, worker, ...) end)
    inst:DoTaskInTime(0, OnIsDay, TheWorld.state.isday)
    inst:WatchWorldState("isday", OnIsDay)
    SetOnPreLoad(inst, OnPreLoad)
end
-- 洞口伪装
local situational_disguises = {
    -- 青草地
    {name = "grass", tile = WORLD_TILES.GRASS, proxy = "evergreen"},
    {name = "deciduoustree", tile = WORLD_TILES.GRASS},
    {name = "evergreen", tile = WORLD_TILES.GRASS},
    -- 森林
    {name = "grass", tile = WORLD_TILES.FOREST, proxy = "evergreen"},
    {name = "evergreen_sparse", tile = WORLD_TILES.FOREST},
    {name = "evergreen", tile = WORLD_TILES.FOREST},
    -- 桦树林
    {name = "deciduoustree", tile = WORLD_TILES.DECIDUOUS},
    -- 草原
    {name = "grass", tile = WORLD_TILES.SAVANNA, proxy = "spiderden"},
    -- 矿区/坟地
    {name = "rock_moon", tile = WORLD_TILES.FOREST, proxy = "rock1"},
    {name = "rock_moon", tile = WORLD_TILES.ROCKY, proxy = "rock1"},
    {name = "rock2", tile = WORLD_TILES.ROCKY},
    {name = "rock1", tile = WORLD_TILES.ROCKY},
    {name = "rock_moon", tile = WORLD_TILES.DIRT, proxy = "rock1"},
    {name = "rock2", tile = WORLD_TILES.DIRT},
    {name = "rock1", tile = WORLD_TILES.DIRT},
    -- 沙漠
    {name = "oasis_cactus", tile = WORLD_TILES.DIRT, proxy = "rock_flintless"},
    {name = "cactus", tile = WORLD_TILES.DIRT, proxy = "rock_flintless"},
    {name = "marsh_tree", tile = WORLD_TILES.DIRT},
    {name = "rock_flintless", tile = WORLD_TILES.DIRT},
    {name = "marsh_bush", tile = WORLD_TILES.DIRT, proxy = "rock_flintless"},
    {name = "oasis_cactus", tile = WORLD_TILES.DESERT_DIRT, proxy = "rock_flintless"},
    {name = "cactus", tile = WORLD_TILES.DESERT_DIRT, proxy = "rock_flintless"},
    {name = "marsh_tree", tile = WORLD_TILES.DESERT_DIRT},
    {name = "rock_flintless", tile = WORLD_TILES.DESERT_DIRT},
    {name = "marsh_bush", tile = WORLD_TILES.DESERT_DIRT, proxy = "rock_flintless"},
    -- 沼泽
    {name = "marsh_bush", tile = WORLD_TILES.MARSH, proxy = "marsh_tree"},
    {name = "marsh_tree", tile = WORLD_TILES.MARSH},
    {name = "reeds", tile = WORLD_TILES.MARSH, proxy = "marsh_tree"}
}
-- 洞口现在会伪装起来难以发现了
local function onentityremove(inst)
    inst.components.persistent2hm.data.isdisguised = nil
    inst.components.persistent2hm.data.disguisecycles = TheWorld.state.cycles + math.random(30, 40)
    inst:ReturnToScene()
    if inst.prefab == "cave_entrance_open" and inst.components.childspawner and not TheWorld.state.isday then
        inst.components.childspawner:StopRegen()
        inst.components.childspawner:StartSpawning()
    end
    if inst.prefab == "cave_entrance_open" and inst:HasTag("sinkhole") and inst.components.worldmigrator and inst.components.worldmigrator.enabled then
        inst:RemoveTag("sinkhole")
    end
end
local function oncaveremove(inst)
    local entity = inst.components.entitytracker and inst.components.entitytracker:GetEntity("disguise2hm")
    if entity and entity:IsValid() then entity:Remove() end
end
local function linkentity(inst, entity)
    inst:RemoveFromScene()
    inst:ListenForEvent("onremove", function() onentityremove(inst) end, entity)
    inst:ListenForEvent("onremove", oncaveremove)
    if not inst:HasTag("sinkhole") then inst:AddTag("sinkhole") end
end
local function generatedisguiseentity(inst, prefab, x, y, z)
    local entity = SpawnPrefab(prefab)
    if not entity then return end
    entity.Transform:SetPosition(x, y, z)
    inst.components.entitytracker:TrackEntity("disguise2hm", entity)
    linkentity(inst, entity)
end
local function processdisguisestatus(inst)
    if not inst.components.persistent2hm.data.disguisecycles then
        inst.components.persistent2hm.data.disguisecycles = inst.prefab == "cave_entrance" and TheWorld.state.cycles or (TheWorld.state.cycles + 70)
    end
    if not inst.components.persistent2hm.data.isdisguised then
        if TheWorld.state.cycles < inst.components.persistent2hm.data.disguisecycles or not (TheWorld.state.cycles == 0 or inst:IsAsleep()) then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        if inst.components.persistent2hm.data.prefab_hastile then
            generatedisguiseentity(inst, inst.components.persistent2hm.data.prefab_hastile, x, y, z)
            inst.components.persistent2hm.data.isdisguised = true
            return
        end
        if not not TheWorld.Map:IsOceanAtPoint(x, y, z) then return end
        local ents = TheSim:FindEntities(x, y, z, 30, nil, {"INLIMBO"}, {"plant", "boulder"})
        local tile = inst:GetCurrentTileType()
        local checkprefabs = {}
        local prefab_hastile
        for _, v in ipairs(situational_disguises) do
            if tile == v.tile then
                checkprefabs[v.name] = v.proxy or v.name
                prefab_hastile = v.proxy or v.name
            end
        end
        if prefab_hastile then
            -- 在检测地皮上,查找附近实体并进行变化
            for _, ent in ipairs(ents) do
                if checkprefabs[ent.prefab] then
                    inst.components.persistent2hm.data.prefab_hastile = checkprefabs[ent.prefab]
                    generatedisguiseentity(inst, checkprefabs[ent.prefab], x, y, z)
                    inst.components.persistent2hm.data.isdisguised = true
                    return
                end
            end
            -- 找不到实体就随机变化一个
            inst.components.persistent2hm.data.prefab_hastile = prefab_hastile
            generatedisguiseentity(inst, prefab_hastile, x, y, z)
            inst.components.persistent2hm.data.isdisguised = true
        else
            -- 不在检测地皮上的话,查找附近实体并检测其的地皮
            for _, ent in ipairs(ents) do
                for _, v in ipairs(situational_disguises) do
                    if v.name == ent.prefab then
                        if not ent.tmptile2hm then ent.tmptile2hm = ent:GetCurrentTileType() end
                        if v.tile == ent.tmptile2hm then
                            inst.components.persistent2hm.data.prefab_hastile = v.proxy or v.name
                            generatedisguiseentity(inst, v.proxy or v.name, x, y, z)
                            inst.components.persistent2hm.data.isdisguised = true
                            ent.tmptile2hm = nil
                            return
                        end
                    end
                end
                if ent.tmptile2hm then ent.tmptile2hm = nil end
            end
            inst.components.persistent2hm.data.prefab_hastile = "evergreen"
            generatedisguiseentity(inst, "evergreen", x, y, z)
            inst.components.persistent2hm.data.isdisguised = true
        end
    else
        local entity = inst.components.entitytracker:GetEntity("disguise2hm")
        if entity and entity:IsValid() then
            linkentity(inst, entity)
        else
            inst.components.entitytracker:ForgetEntity("disguise2hm")
            inst.components.persistent2hm.data.isdisguised = nil
        end
    end
end
local function setdisguiseentrance(inst)
    if not inst.components.workable then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if not inst.components.entitytracker then inst:AddComponent("entitytracker") end
    inst:DoTaskInTime(0, processdisguisestatus)
    inst:WatchWorldState("cycles", processdisguisestatus)
end
AddPrefabPostInit("cave_entrance", function(inst)
    inst:AddTag("sinkhole")
    if not TheWorld.ismastersim then return end
    setbatsentrance(inst)
    if disguise and not TheWorld:HasTag("cave") then
        setdisguiseentrance(inst)
        inst:DoTaskInTime(0, OnIsDay, TheWorld.state.isday)
        inst:WatchWorldState("isday", OnIsDay)
    end
end)
-- 已打开的洞口被本模组堵住时可以被火药打开
local function onworkcave_entrance_open(inst, worker)
    if worker and worker:IsValid() and (worker.components.explosive and worker.components.explosive.explosivedamage > 0) and not inst:HasTag("migrator") and
        inst:HasTag("disbaledmigrator2hm") then
        if worker.components.stackable and worker.components.stackable.stacksize > 1 and not inst.workleft2hm then inst.workleft2hm = 1 end
        if inst.workleft2hm == nil then
            inst.components.workable:SetWorkLeft(1)
            inst.workleft2hm = 1
            if inst.components.childspawner then summerflybats(inst, math.max(inst.components.childspawner.childreninside, 1)) end
        elseif inst.workleft2hm == 1 then
            inst.components.workable:SetWorkLeft(10)
            inst.workleft2hm = nil
            if inst.components.worldmigrator then
                inst.components.worldmigrator:SetEnabled(true)
                if inst.components.worldmigrator.id and TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data.unlockShardPortals then
                    table.insert(TheWorld.components.persistent2hm.data.unlockShardPortals, inst.components.worldmigrator.id)
                end
            end
            if inst.components.childspawner then inst.components.childspawner:StartSpawning() end
        end
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .025, 1.25, inst, 40)
    end
end
local function setgunpowderopen(inst)
    if not inst.components.workable then
        inst:AddComponent("workable")
        inst.components.workable.action = nil
        inst.components.workable:SetOnWorkCallback(onworkcave_entrance_open)
    end
end
AddPrefabPostInit("cave_entrance_open", function(inst)
    if not TheWorld.ismastersim then return end
    setgunpowderopen(inst)
    if disguise and not TheWorld:HasTag("cave") then setdisguiseentrance(inst) end
end)
-- 世界定时堵住楼梯和洞口这两种出入口
-- 洞口白名单
local whitelist_prefabs = {
    "oceanwhirlbigportal", -- 大漩涡
    "cave_entrance_open_moon", -- 妥协月岛洞口
    "cave_exit_moon", -- 妥协地下月岛楼梯
}

-- 月圆强制开放
local function forceopen(inst)
    for i, exit in ipairs(ShardPortals) do
        exit.components.worldmigrator:SetEnabled(true)
    end
end

local function changeWorldShardPortals(inst, change)
    if ShardPortals == nil or (#ShardPortals - #whitelist_prefabs) <= 2 then return end
    local _ShardPortals = {}
    for i, exit in pairs(ShardPortals) do
        if exit and not table.contains(whitelist_prefabs, exit.prefab) then table.insert(_ShardPortals, exit) end
    end
    if not inst.components.persistent2hm.data.unlockShardPortals or change then
        inst.components.persistent2hm.data.unlockShardPortals = {}
        local i = math.random(#_ShardPortals)
        table.insert(inst.components.persistent2hm.data.unlockShardPortals, _ShardPortals[i].components.worldmigrator.id)
        local i2 = nil
        if #_ShardPortals > 1 then
            i2 = math.random(#_ShardPortals)
            while i2 == i do i2 = math.random(#_ShardPortals) end
            table.insert(inst.components.persistent2hm.data.unlockShardPortals, _ShardPortals[i2].components.worldmigrator.id)
        end
        if i2 and #_ShardPortals > 5 then -- 2025.10.22 melon:多于5个再开第3个
            local i3 = math.random(#_ShardPortals)
            while i3 == i or i3 == i2 do i3 = math.random(#_ShardPortals) end
            table.insert(inst.components.persistent2hm.data.unlockShardPortals, _ShardPortals[i3].components.worldmigrator.id)
        end
    end
    -- print2hm("----------------------------------------------------------")
    for i, exit in ipairs(ShardPortals) do
        -- local worldmigrator = exit.components.worldmigrator
        -- print2hm(exit.prefab)
        if (exit.prefab == "cave_exit" or exit.prefab == "cave_entrance_open" or exit.enablelockworldmigrator2hm) and
            table.contains(inst.components.persistent2hm.data.unlockShardPortals, exit.components.worldmigrator.id) 
            or table.contains(whitelist_prefabs, exit.prefab) or inst.components.persistent2hm.data.forceopen2hm then
            exit.components.worldmigrator:SetEnabled(true)
            -- print2hm("开", TheWorld and TheWorld.state.moonphase)
        else
            exit.components.worldmigrator:SetEnabled(false)
            -- print2hm("关", TheWorld and TheWorld.state.moonphase)
        end
    end
end
local function onnewmoon(inst, moon)
    if moon == "full" then
        forceopen(inst)
        inst.components.persistent2hm.data.forceopen2hm = true
    elseif moon == "new" then
        changeWorldShardPortals(inst, true)
        inst.components.persistent2hm.data.forceopen2hm = nil
    else
        changeWorldShardPortals(inst)
        inst.components.persistent2hm.data.forceopen2hm = nil
    end
end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return inst end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    -- inst:WatchWorldState(inst:HasTag("cave") and "iscavenewmoon" or "isnewmoon", onnewmoon)
    inst:DoTaskInTime(1, changeWorldShardPortals)
    inst:WatchWorldState(inst:HasTag("cave") and "cavemoonphase" or "moonphase", onnewmoon)
end)
-- 世界的楼梯和洞口这两种出入口被本模组特殊禁用时,会显示特效;其他模组的出入口没有工作组件的话也会被堵住从而需要火药打开
local function initworldmigrator(inst)
    if inst.prefab == "cave_entrance" then return end
    if inst.prefab ~= "cave_exit" and inst.prefab ~= "cave_entrance_open" then
        if inst.components.workable then return end
        inst.enablelockworldmigrator2hm = true
        setgunpowderopen(inst)
    end
    local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
    fx.AnimState:SetMultColour(1, 1, 1, 0.5)
    fx.entity:SetParent(inst.entity)
    if inst.components.worldmigrator and inst.components.worldmigrator.enabled == false and Shard_IsWorldAvailable(inst.components.worldmigrator.linkedWorld) then
        inst:AddTag("disbaledmigrator2hm")
        fx:Show()
    else
        inst:RemoveTag("disbaledmigrator2hm")
        fx:Hide()
    end
    inst.worldmigratorfx2hm = fx
end
AddComponentPostInit("worldmigrator", function(self)
    self.inst:DoTaskInTime(0, initworldmigrator)
    local oldValidateAndPushEvents = self.ValidateAndPushEvents
    self.ValidateAndPushEvents = function(self, ...)
        oldValidateAndPushEvents(self, ...)
        if self.enabled == false and Shard_IsWorldAvailable(self.linkedWorld) then
            self.inst:AddTag("disbaledmigrator2hm")
            if self.inst.worldmigratorfx2hm then self.inst.worldmigratorfx2hm:Show() end
            if self.inst.prefab == "cave_entrance_open" and not self.inst:HasTag("sinkhole") then self.inst:AddTag("sinkhole") end
        elseif self.inst:HasTag("disbaledmigrator2hm") then
            self.inst:RemoveTag("disbaledmigrator2hm")
            if self.inst.worldmigratorfx2hm then self.inst.worldmigratorfx2hm:Hide() end
            if self.inst.prefab == "cave_entrance_open" and self.enabled and not self.inst:IsInLimbo() and self.inst:HasTag("sinkhole") then
                self.inst:RemoveTag("sinkhole")
            end
        end
    end
end)
-- 玩家灵魂直接通过堵住的楼梯
AddComponentAction("SCENE", "worldmigrator", function(inst, doer, actions)
    if doer and doer:HasTag("playerghost") and inst:HasTag("disbaledmigrator2hm") and TheWorld:HasTag("cave") and not inst:HasTag("migrator") then
        table.insert(actions, ACTIONS.MIGRATE)
    end
end)
-- 远古钥匙+懒人魔杖解除楼梯封堵(恶魔人不需要懒人魔杖),恶魔人用灵魂通过封堵的楼梯
local function atrium_keyUSEITEM(inst, doer, actions, right, target)
    return target and target:HasTag("disbaledmigrator2hm") and (TheWorld:HasTag("cave") or (inst.prefab == "wortox_soul" and doer.prefab == "wortox")) and
               not target:HasTag("migrator") and not inst:HasTag("disableoce2hm") and (doer.prefab == "wortox" or
               (doer.replica.inventory and doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) and
                   doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).prefab == "orangestaff"))
end
local function atrium_keyUSEITEMdoaction(inst, doer, target, pos, act)
    if target and target:HasTag("disbaledmigrator2hm") and (TheWorld:HasTag("cave") or (inst.prefab == "wortox_soul" and doer.prefab == "wortox")) and
        not target:HasTag("migrator") and target.components.worldmigrator and
        (inst.prefab == "atrium_key" or (inst.prefab == "wortox_soul" and doer.prefab == "wortox")) and
        (doer.prefab == "wortox" or (doer.components.inventory and doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) and
            doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).prefab == "orangestaff")) and not inst.disableoce2hmtask then
        if inst.prefab == "wortox_soul" and doer.prefab == "wortox" then
            if inst.components.stackable and inst.components.stackable.stacksize >= 1 then
                if inst.components.stackable.stacksize > 1 then
                    inst.components.stackable:SetStackSize(inst.components.stackable.stacksize - 1)
                else
                    inst:Remove()
                end
            end
            target.components.worldmigrator:Activate(doer)
        else
            if doer.prefab ~= "wortox" then
                local orangestaff = doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if orangestaff and orangestaff.components.finiteuses then orangestaff.components.finiteuses:Use(1) end
            end
            if target.components.worldmigrator then
                target.components.worldmigrator:SetEnabled(true)
                if TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data.unlockShardPortals then
                    table.insert(TheWorld.components.persistent2hm.data.unlockShardPortals, target.components.worldmigrator.id)
                end
                if TheWorld:HasTag("cave") then TheWorld:PushEvent("ms_miniquake", {rad = 3, num = 5, duration = 1.5, target = doer}) end
            end
            inst:AddTag("disableoce2hm")
            inst.disableoce2hmtask = inst:DoTaskInTime(10, function()
                inst:RemoveTag("disableoce2hm")
                inst.disableoce2hmtask = nil
            end)
        end
        return true
    end
end
STRINGS.ACTIONS.ACTION2HM.ATRIUM_KEY = TUNING.isCh2hm and "解除封堵" or "Unlock"
AddPrefabPostInit("atrium_key", function(inst)
    inst.actionothercondition2hm = atrium_keyUSEITEM
    if not TheWorld.ismastersim then return end
    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = atrium_keyUSEITEMdoaction
end)
STRINGS.ACTIONS.ACTION2HM.WORTOX_SOUL = TUNING.isCh2hm and "通过" or "Through"
AddPrefabPostInit("wortox_soul", function(inst)
    inst.actionothercondition2hm = atrium_keyUSEITEM
    if not TheWorld.ismastersim then return end
    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = atrium_keyUSEITEMdoaction
end)
-- 大理石堵住打开的洞口
local function marbleUSEITEM(inst, doer, actions, right, target) return target.prefab == "cave_entrance_open" and target:HasTag("migrator") end
local function marbleUSEITEMdoaction(inst, doer, target, pos, act)
    if inst.prefab == "marble" and inst.components.stackable and inst.components.stackable.stacksize >= 1 then
        if inst.components.stackable.stacksize > 1 then
            inst.components.stackable:SetStackSize(inst.components.stackable.stacksize - 1)
        else
            inst:Remove()
        end
    end
    if target.components.worldmigrator then
        target.components.worldmigrator:SetEnabled(false)
        if TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data.unlockShardPortals then
            for i = #TheWorld.components.persistent2hm.data.unlockShardPortals, 1, -1 do
                if TheWorld.components.persistent2hm.data.unlockShardPortals[i] == target.components.worldmigrator.id then
                    table.remove(TheWorld.components.persistent2hm.data.unlockShardPortals, i)
                    break
                end
            end
        end
    end
    return true
end
STRINGS.ACTIONS.ACTION2HM.MARBLE = TUNING.isCh2hm and "堵住" or "Lock"
AddPrefabPostInit("marble", function(inst)
    inst.actionothercondition2hm = marbleUSEITEM
    if not TheWorld.ismastersim then return end
    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = marbleUSEITEMdoaction
end)
