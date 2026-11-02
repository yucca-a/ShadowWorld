-- 星象探测仪无视月亮风暴
local allresonators2hm = {} -- 注册在地图某位置的探测仪
local allmarkers2hm = {} -- 注册在地图某位置的风暴

local function useresonator(inst)
    if not inst.components.finiteuses or not inst.hasmarker2hm then return end
    if not inst.components.persistent2hm.data.cyclesrecord2hm or TheWorld.state.cycles > inst.components.persistent2hm.data.cyclesrecord2hm then
        inst.components.persistent2hm.data.cyclesrecord2hm = TheWorld.state.cycles
        inst.components.finiteuses:Use(0.1)
    end
end
local function disablemarker(inst) if inst:IsValid() and inst.MiniMapEntity then inst.MiniMapEntity:SetEnabled(false) end end
local function enablemarker(inst) if inst:IsValid() and inst.MiniMapEntity then inst.MiniMapEntity:SetEnabled(true) end end
local function addnearnode(inst, node_index)
    local node_edges = TheWorld.topology and TheWorld.topology.nodes and TheWorld.topology.nodes[node_index] and TheWorld.topology.nodes[node_index].validedges
    if node_edges then
        for _, edge_index in ipairs(node_edges) do
            local edge_nodes = TheWorld.topology and TheWorld.topology.edgeToNodes and TheWorld.topology.edgeToNodes[edge_index]
            local other_node_index = edge_nodes and (edge_nodes[1] ~= node_index and edge_nodes[1] or edge_nodes[2])
            if other_node_index and other_node_index ~= 0 and not table.contains(inst.node_indexs2hm, other_node_index) then
                table.insert(inst.node_indexs2hm, other_node_index)
            end
        end
    end
end
-- 地图某位置有新的探测仪,附近有风暴则被禁用且探测仪开始消耗耐久
local function registerresonator(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z)
    inst.node_indexs2hm = inst.node_indexs2hm or {}
    if not (node_index and node_index ~= 0) then return end
    table.insert(inst.node_indexs2hm, node_index)
    local node_edges = TheWorld.topology and TheWorld.topology.nodes and TheWorld.topology.nodes[node_index] and TheWorld.topology.nodes[node_index].validedges
    if node_edges then
        for _, edge_index in ipairs(node_edges) do
            local edge_nodes = TheWorld.topology and TheWorld.topology.edgeToNodes and TheWorld.topology.edgeToNodes[edge_index]
            local other_node_index = edge_nodes and (edge_nodes[1] ~= node_index and edge_nodes[1] or edge_nodes[2])
            if other_node_index and other_node_index ~= 0 and not table.contains(inst.node_indexs2hm, other_node_index) then
                table.insert(inst.node_indexs2hm, other_node_index)
                addnearnode(inst, other_node_index)
            end
        end
    end
    for index, node_index in ipairs(inst.node_indexs2hm) do
        if node_index and node_index ~= 0 then
            allresonators2hm[node_index] = allresonators2hm[node_index] or {}
            table.insert(allresonators2hm[node_index], inst)
            if allmarkers2hm[node_index] then
                if not inst.hasmarker2hm then
                    inst.hasmarker2hm = true
                    useresonator(inst)
                end
                for _, marker in ipairs(allmarkers2hm[node_index]) do disablemarker(marker) end
            end
        end
    end
end
-- 探测仪消失了,地图某位置如果没有其他探测仪,附近的风暴重新启用
local function unregisterresonator(inst)
    if inst.node_indexs2hm then
        for index, node_index in ipairs(inst.node_indexs2hm) do
            local resonators = allresonators2hm[node_index]
            if resonators then
                for i = #resonators, 1, -1 do if resonators[i] == inst then table.remove(resonators, i) end end
                if #resonators == 0 then
                    allresonators2hm[node_index] = nil
                    if allmarkers2hm[node_index] then for _, marker in ipairs(allmarkers2hm[node_index]) do enablemarker(inst) end end
                end
            end
        end
    end
end

local function copyparams(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            copyparams(dest[k], v)
        else
            dest[k] = v
        end
    end
end

local function beginfade(inst)
    copyparams(inst._startlight, inst._currentlight)
    inst._currentlight.time = 0
    inst._startlight.time = 0

    if inst._lighttask == nil then
        inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, FRAMES)
    end
end
local light_params_idle = {
    radius = 1,
    intensity = .4,
    falloff = .6,
    colour = {237/255, 237/255, 209/255},
    time = 0.2,
}
AddPrefabPostInit("archive_resonator", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:DoTaskInTime(0, registerresonator)
    inst:ListenForEvent("onremove", unregisterresonator)
    inst:DoTaskInTime(FRAMES, useresonator)
    inst:WatchWorldState("cycles", useresonator)
    inst:DoTaskInTime(1, function()
        if inst.task2 then
            local oldfn = inst.task2.fn
            inst.task2.fn = function(inst)
                local ent = FindEntity(inst, 9999, nil, {"alterguardian2hm"})
                if ent then
                    inst.task3 = inst:DoTaskInTime(4, function()
                        inst.SoundEmitter:KillSound("locating")
                        inst.AnimState:PlayAnimation("idle_pre")
                        copyparams(inst._endlight, light_params_idle)
                        beginfade(inst)
                        inst.AnimState:PushAnimation("idle_loop",true)
                        inst.components.finiteuses:Use(1)
                    end)
                else
                    oldfn(inst)
                end
            end
        end
    end)
end)
AddRecipePostInit("archive_resonator_item", function(inst)
    for _, ingredient in ipairs(inst.ingredients) do
        if ingredient and ingredient.type == "moonrocknugget" and ingredient.amount then
            ingredient.amount = ingredient.amount + 2
            break
        end
    end
end)
-- 地图某位置有新的风暴,附近有探测仪则该风暴被禁用且探测仪开始消耗耐久
local function registermarker(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z)
    if node_index and node_index ~= 0 then
        allmarkers2hm[node_index] = allmarkers2hm[node_index] or {}
        table.insert(allmarkers2hm[node_index], inst)
        inst.node_index2hm = node_index
        if allresonators2hm[node_index] then
            disablemarker(inst)
            for _, resonator in ipairs(allresonators2hm[node_index]) do
                if resonator and resonator:IsValid() and not resonator.hasmarker2hm then
                    resonator.hasmarker2hm = true
                    useresonator(resonator)
                end
            end
        end
    end
end
-- 风暴消失了,地图某位置如果没有其他风暴,附近的探测仪不再消耗耐久
local function unregistermarker(inst)
    if inst.node_index2hm then
        local node_index = inst.node_index2hm
        local markers = allmarkers2hm[node_index]
        if markers then
            for i = #markers, 1, -1 do if markers[i] == inst then table.remove(markers, i) end end
            if #markers == 0 then
                allmarkers2hm[node_index] = nil
                if allresonators2hm[node_index] then
                    for _, resonator in ipairs(allresonators2hm[node_index]) do
                        if resonator and resonator:IsValid() and resonator.hasmarker2hm then
                            if inst.node_indexs2hm then
                                local hasmarker
                                for index, node_index in ipairs(inst.node_indexs2hm) do
                                    if allmarkers2hm[node_index] then
                                        hasmarker = true
                                        break
                                    end
                                end
                                if not hasmarker then resonator.hasmarker2hm = nil end
                            end
                        end
                    end
                end

            end
        end
    end
end
local function initmarker(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, registermarker)
    inst:ListenForEvent("onremove", unregistermarker)
end
local markers = {"moonstormmarker2hm", "moonstormmarker_big"}
for index, marker in ipairs(markers) do AddPrefabPostInit(marker, initmarker) end

-- 月岛月圆那几天会有月亮风暴
AddPrefabPostInit("world", function(inst)
    if inst:HasTag("cave") then return end
    if not inst.ismastersim then return inst end
    inst:AddComponent("moonstormmanager2hm")
end)
AddPrefabPostInit("forest_network", function(inst)
    inst:AddComponent("moonstorms2hm")
    if inst.components.moonstorms then
        local self = inst.components.moonstorms
        local self2hm = inst.components.moonstorms2hm
        local oldCalcMoonstormLevel = self.CalcMoonstormLevel
        self.CalcMoonstormLevel = function(self, ...)
            local level = oldCalcMoonstormLevel(self, ...)
            return level == 0 and self2hm:CalcMoonstormLevel(...) or level
        end
        -- 地图某位置有新的探测仪,附近的风暴被禁用
        local oldIsInMoonstorm = self.IsInMoonstorm
        self.IsInMoonstorm = function(self, ent, ...)
            return not (ent.components.areaaware and ent.components.areaaware.current_area and allresonators2hm[ent.components.areaaware.current_area]) and
                       (not self.inst:HasTag("playerghost") and self2hm:IsInMoonstorm(ent, ...) or oldIsInMoonstorm(self, ent, ...))
        end
        -- local oldIsPointInMoonstorm = self.IsPointInMoonstorm
        -- self.IsPointInMoonstorm = function(self, ...)
        --     return oldIsPointInMoonstorm(self, ...) or self2hm:IsPointInMoonstorm(...)
        -- end
        local oldGetMoonstormLevel = self.GetMoonstormLevel
        self.GetMoonstormLevel = function(self, ...)
            local level = oldGetMoonstormLevel(self, ...)
            return level == 0 and self2hm:GetMoonstormLevel(...) or level
        end
        local oldStopMoonstorm = self.StopMoonstorm
        self.StopMoonstorm = function(self, ...)
            oldStopMoonstorm(self, ...)
            if TheWorld.components.moonstormmanager2hm and TheWorld.components.moonstormmanager2hm.moonstorm_spark_task then
                TheWorld:PushEvent("moonislandstormchanged", {stormtype = STORM_TYPES.MOONSTORM, setting = true})
            end
        end
    end
end)
AddComponentPostInit("moonstormwatcher", function(self)
    if TheWorld.net.components.moonstorms2hm ~= nil then
        self.inst:ListenForEvent("moonislandstormchanged", function(src, data) self:ToggleMoonstorms(data) end, TheWorld)
        -- self:ToggleMoonstorms(TheWorld.components.moonstorms:IsMoonstormActive())
        self:ToggleMoonstorms({setting = false})
    end
end)
AddComponentPostInit("stormwatcher", function(self)
    self.inst:ListenForEvent("moonislandstormchanged", function(src, data) self:UpdateStorms(data) end, TheWorld)
    if TheWorld.net.components.moonstorms2hm ~= nil and next(TheWorld.net.components.moonstorms2hm:GetMoonstormNodes()) then
        self:UpdateStorms({stormtype = STORM_TYPES.MOONSTORM, setting = true})
    end
    local oldGetCurrentStorm = self.GetCurrentStorm
    self.GetCurrentStorm = function(self, inst)
        local currentstorm = STORM_TYPES.NONE
        if TheWorld.components.sandstorms ~= nil then
            if TheWorld.components.sandstorms:IsInSandstorm(self.inst) then currentstorm = STORM_TYPES.SANDSTORM end
        end
        if TheWorld.net.components.moonstorms ~= nil then
            if TheWorld.net.components.moonstorms:IsInMoonstorm(self.inst) then currentstorm = STORM_TYPES.MOONSTORM end
        end
        if currentstorm then return currentstorm end
        return oldGetCurrentStorm(self, inst)
    end
end)

-- 月岛陨石
local moon_altar_rocks = {"moon_altar_rock_idol", "moon_altar_rock_glass", "moon_altar_rock_seed"}
local function onremoverock(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if x and y and z then
        local meteorspawner = SpawnPrefab("meteorspawner")
        meteorspawner.Transform:SetPosition(x, y, z)
    end
end
for _, rock in ipairs(moon_altar_rocks) do
    AddPrefabPostInit(rock, function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.meteorshower then inst:AddComponent("meteorshower") end
        inst:ListenForEvent("onremove", onremoverock)
    end)
end

TUNING.LUNARHAIL_DEBRIS_KEEP_CHANCE = TUNING.LUNARHAIL_DEBRIS_KEEP_CHANCE / 2

-- 月亮风暴专属护目镜
if GetModConfigData("moonisland") ~= -1 then
    AddPrefabPostInit("moonstorm_goggleshat", function(inst) inst:AddTag("moonstormgoggles") end)
    AddPrefabPostInit("lunarplanthat", function(inst) inst:AddTag("moonstormgoggles") end)
    -- 月亮风暴会掉落非月亮风暴的护目镜
    local stormvisiontext = {
        TUNING.isCh2hm and "太多光晕了" or "Many Halo",
        TUNING.isCh2hm and "太多沙尘了" or "Many Sand",
        TUNING.isCh2hm and "太多雪花了" or "Many Snow"
    }
    local function ongogglevision(inst, data)
        local say
        if not inst:HasTag("playerghost") and data and data.enabled and inst.components.stormwatcher and inst.components.inventory then
            if inst.components.stormwatcher:GetCurrentStorm() == STORM_TYPES.MOONSTORM then
                local v = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                if v and v:HasTag("goggles") and not v:HasTag("moonstormgoggles") then
                    inst.components.inventory:Unequip(EQUIPSLOTS.HEAD)
                    inst.components.inventory:GiveItem(v)
                    say = 1
                end
            elseif inst.components.stormwatcher:GetCurrentStorm() == STORM_TYPES.SANDSTORM then
                local v = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
				if v and v.prefab == "scrap_monoclehat" and v:HasTag("goggles") and not v:HasTag("sandstormgoggles") then
					inst.components.inventory:Unequip(EQUIPSLOTS.HEAD)
                    inst.components.inventory:GiveItem(v)
                    say = 2
                elseif v and v.prefab ~= "scrap_monoclehat" and v:HasTag("goggles") and v.prefab ~= "alterguardianhat" and
                    ((v.components.insulator and v.components.insulator.type == SEASONS.WINTER) or v:HasTag("moonstormgoggles")) then
                    inst.components.inventory:Unequip(EQUIPSLOTS.HEAD)
                    inst.components.inventory:GiveItem(v)
                    say = 2
                end
            elseif TUNING.DSTU and inst.components.snowstormwatcher and
                (TheWorld.state.iswinter and ((TheWorld.net ~= nil and TheWorld.net:HasTag("snowstormstartnet")) or TheWorld:HasTag("snowstormstart"))) then
                local v = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
				if v and v.prefab == "scrap_monoclehat" and v:HasTag("goggles") and not v:HasTag("snowstormgoggles") then
					inst.components.inventory:Unequip(EQUIPSLOTS.HEAD)
                    inst.components.inventory:GiveItem(v)
                    say = 3
                elseif v and v.prefab ~= "scrap_monoclehat" and v:HasTag("goggles") and v.prefab ~= "alterguardianhat" and
                    ((v.components.insulator and v.components.insulator.type == SEASONS.SUMMER) or v:HasTag("moonstormgoggles")) then
                    inst.components.inventory:Unequip(EQUIPSLOTS.HEAD)
                    inst.components.inventory:GiveItem(v)
                    say = 3
                end
            end
        end
        if say and inst.components.talker then inst.components.talker:Say(stormvisiontext[say]) end
    end
    local function delayongogglevision(inst, data) inst:DoTaskInTime(0, ongogglevision, data) end
    local function OnStormLevelDirty(inst, data)
        if not inst:HasTag("playerghost") and data and data.level and data.level > 0 and inst.components.playervision and
            inst.components.playervision.gogglevision then ongogglevision(inst, {enabled = true}) end
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("gogglevision", delayongogglevision)
        inst:ListenForEvent("sandstormlevel", OnStormLevelDirty)
        inst:ListenForEvent("moonstormlevel", OnStormLevelDirty)
    end)
end

-- 
local function moonstormsparkonsave(inst, data) if inst.islarge2hm then data.islarge2hm = true end end
local function moonstormsparkonload(inst, data)
    if not inst:IsInLimbo() and (data and data.islarge2hm or
        (data == nil and
            (TheWorld:HasTag("cave") or (TheWorld.net.components.moonstorms and TheWorld.net.components.moonstorms:IsPointInMoonstorm(inst:GetPosition()))) and
            math.random() < 0.15)) then
        inst.AnimState:SetScale(2, 2, 2)
        inst:AddTag("notarget")
        if inst.components.workable then inst.components.workable:SetWorkAction() end
        inst.islarge2hm = true
        if inst.components.locomotor then inst.components.locomotor.walkspeed = inst.components.locomotor.walkspeed * 2 end
        if not inst.components.damagetypebonus then inst:AddComponent("damagetypebonus") end
        inst.components.damagetypebonus:AddBonus("_health", inst, 2)
    end
end
AddPrefabPostInit("moonstorm_spark", function(inst)
    if not TheWorld.ismastersim then return end
    SetOnSave(inst, moonstormsparkonsave)
    if POPULATING then
        SetOnLoad(inst, moonstormsparkonload)
    else
        inst:DoTaskInTime(0, moonstormsparkonload)
    end
end)
