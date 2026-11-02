local select_clockwork = GetModConfigData("clockwork_guard")
-- 2025.7.17 melon:选1时仅开局垃圾堆旁生成2个发条
select_clockwork = select_clockwork == true and 1 or select_clockwork

-- 月台守护-----------------------------------------------------
if select_clockwork == 2 then
    local children = {"knight", "bishop", "rook"}

    local function addspawnfader(inst) if not inst.components.spawnfader then inst:AddComponent("spawnfader") end end
    for _, monster in ipairs(children) do AddPrefabPostInit(monster, addspawnfader) end

    local function ReleaseAllChildren(inst)
        for index = 1, 3 do
            if inst.components.childspawner2hm.childreninside > 0 then inst.components.childspawner2hm:SpawnChild(nil, children[math.random(3)]) end
        end
    end

    local function onfullmoon(inst, isfullmoon)
        if isfullmoon then
            if inst.components.repairable and inst.components.repairable.onrepaired and inst.components.workable then
                inst.components.workable:SetWorkLeft(TUNING.MOONBASE_COMPLETE_WORK)
                inst.components.repairable.onrepaired(inst, inst)
            end
            for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
                if child and child:IsValid() and child.components.repairable then
                    if child:IsNear(inst, 20) then
                        if child.components.timer and child.components.timer:TimerExists("mod_hardmode_timechange") then
                            child.components.timer:SetTimeLeft("mod_hardmode_timechange", 0)
                        end
                    else
                        inst.components.childspawner2hm:OnChildKilled(child)
                        child:Remove()
                    end
                end
            end
            inst.components.childspawner2hm:DoRegen()
        end
    end

    local function onspawnchild(inst, child) if child.components.spawnfader then child.components.spawnfader:FadeIn() end end

    local changetime = GetModConfigData("chess") == -1 and TUNING.TOTAL_DAY_TIME * 35 or TUNING.TOTAL_DAY_TIME * 10
    AddPrefabPostInit("moonbase", function(inst)
        if not TheWorld.ismastersim then return end
        inst.listenforprefabsawp = true
        if not inst.components.childspawner2hm then inst:AddComponent("childspawner2hm") end
        inst.components.childspawner2hm.childname = "knight"
        inst.components.childspawner2hm.spawnradius = 4
        inst.components.childspawner2hm:SetMaxChildren(3)
        inst.components.childspawner2hm:SetRegenPeriod(changetime)
        inst.components.childspawner2hm:SetSpawnPeriod(120)
        inst.components.childspawner2hm:SetOnAddChildFn(ReleaseAllChildren)
        inst.components.childspawner2hm:SetSpawnedFn(onspawnchild)
        inst.components.childspawner2hm.childreninside = 1
        inst.components.childspawner2hm.cansave = true
        if not inst.components.playerprox2hm then inst:AddComponent("playerprox2hm") end
        inst.components.playerprox2hm:SetDist(30, 30) -- set specific values
        inst.components.playerprox2hm:SetOnPlayerNear(ReleaseAllChildren)
        inst:WatchWorldState("isfullmoon", onfullmoon)
        inst:DoTaskInTime(0, ReleaseAllChildren)
    end)
end
-- 垃圾堆守护 世界生成时垃圾堆附近生成2个发条--------------------------------------------
if select_clockwork == 1 then
    local function saveandloadtarget2hm(inst)
        local oldsave = inst.OnSave
        inst.OnSave = function(inst, data)
            if oldsave ~= nil then oldsave(inst, data) end
            data.spawnknight2hm = inst.spawnknight2hm -- 记录是否生成过
        end
        local oldload = inst.OnLoad
        inst.OnLoad = function(inst, data)
            if oldload ~= nil then oldload(inst, data) end
            inst.spawnknight2hm = data and data.spawnknight2hm -- 记录是否生成过
        end
    end
    -- 世界生成时垃圾堆附近生成2个发条knight/bishop
    local function StartSpawn2hm(inst)
        -- TheNet:SystemMessage("day   " .. tostring(TheWorld.state.cycles))
        if inst.spawnknight2hm or TheWorld.state.cycles >= 1 then return end -- 仅第1天生成
        inst.spawnknight2hm = true
        -- 第1个发条
        local theta = math.random(360) * DEGREES
        local pos = inst:GetPosition()
        pos.y = 0
        local offs = FindWalkableOffset(pos, theta, 35 + math.random(6), 8, false, true, NotBlocked, false, true)
        if offs ~= nil then
            pos.x = pos.x + offs.x
            pos.z = pos.z + offs.z
            SpawnPrefab("knight").Transform:SetPosition(pos:Get()) -- 骑士
        end
        -- 第2个发条
        theta = math.random(360) * DEGREES -- 重新随机方向
        pos = inst:GetPosition()
        offs = FindWalkableOffset(pos, theta, 35 + math.random(6), 8, false, true, NotBlocked, false, true)
        if offs ~= nil then
            pos.x = pos.x + offs.x
            pos.z = pos.z + offs.z
            -- SpawnPrefab("knight").Transform:SetPosition(pos:Get())
            SpawnPrefab("bishop").Transform:SetPosition(pos:Get()) -- 主教
        end
    end
    AddPrefabPostInit("junk_pile_big", function(inst)
        if not TheWorld.ismastersim then return end
        saveandloadtarget2hm(inst)
        inst.spawntask2hm = inst:DoTaskInTime(0, StartSpawn2hm)
    end)
end
