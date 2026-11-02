-- 田地削弱,农作物长好时0.1概率水土流失,刚耕的地也必定水土流失
local destoryentstag = { "farm_plant", "soil" }
local farmplanttags = { "farm_plant" }
if CONFIGS_LEGION then
    table.insert(destoryentstag, "crop_legion")
    table.insert(destoryentstag, "crop2_legion")
    table.insert(farmplanttags, "crop_legion")
    table.insert(farmplanttags, "crop2_legion")
end
local function OnIsWinter(inst, iswinter) if iswinter then inst:DoTaskInTime(0, inst.Remove) end end
-- 定时消耗养料,养料和水分不足则周围的农作物全部铲除视为干死,耕地铲除;等于一株杂草的消耗速率
local function ConsumeNutrients(inst, drink)
    if TheWorld.components.farming_manager then
        local x, y, z = inst.Transform:GetWorldPosition()
        if TheWorld.components.farming_manager:CycleNutrientsAtPoint(x, 0, z, {
                TUNING.FARM_PLANT_CONSUME_NUTRIENT_LOW / 4,
                TUNING.FARM_PLANT_CONSUME_NUTRIENT_LOW / 4,
                TUNING.FARM_PLANT_CONSUME_NUTRIENT_LOW / 4
            }) and TheWorld.state.issummer and inst.components.farmsoildrinker:CalcPercentTimeHydrated() < TUNING.FARM_PLANT_DROUGHT_TOLERANCE then
            local tileents = TheWorld.Map:GetEntitiesOnTileAtPoint(x, 0, z)
            local ents = TheSim:FindEntities(x, 0, z, 3, destoryentstag)
            for _, ent in ipairs(tileents) do
                if ent and ent:IsValid() and not table.contains(ents, ent) and ent:HasOneOfTags(destoryentstag) then
                    table.insert(ents, ent) end
            end
            for i, v in ipairs(ents) do
                if v and v:IsValid() and v ~= inst then
                    if v.components.workable then
                        v.components.workable:Destroy(inst)
                    elseif v:HasTag("soil") then
                        v:PushEvent("collapsesoil")
                    end
                end
            end
            if TheWorld.Map:IsFarmableSoilAtPoint(x, 0, z) then
                inst:AddComponent("terraformer")
                inst.components.terraformer:Terraform(Vector3(x, 0, z))
                inst:RemoveComponent("terraformer")
            end
        end
    end
end
local function GetDrinkRate(inst) return TUNING.FARM_PLANT_DRINK_HIGH end

-- 地皮成为耕地时启用裂隙
local function EnableFarmDock(inst)
    if inst.components.farmsoildrinker == nil then
        inst:AddComponent("farmsoildrinker")
    end
    inst.components.farmsoildrinker.getdrinkratefn = GetDrinkRate

    if inst.consumetask2hm == nil then
        inst.consumetask2hm =
            inst:DoPeriodicTask(240, ConsumeNutrients, math.random() * 180 + 60)
    end
end

-- 地皮不再是耕地时注销裂隙，但保留裂隙实体
local function DisableFarmDock(inst)
    if inst.consumetask2hm ~= nil then
        inst.consumetask2hm:Cancel()
        inst.consumetask2hm = nil
    end

    if inst.components.farmsoildrinker ~= nil then
        inst:RemoveComponent("farmsoildrinker")
    end
end

local function onsave(inst, data) data.pro2hm = inst.pro2hm end
local function onload(inst, data)
    inst.pro2hm = data and data.pro2hm
    if inst.pro2hm then
        if inst.components.repairable then inst:RemoveComponent("repairable") end
        inst.AnimState:SetMultColour(1, 0.7, 0.7, 1)
        inst:AddTag("farmdock2hm")
        inst:AddTag("farm_plant_killjoy")
        inst.Transform:SetRotation(math.random() * 360)
        inst.weed_def = {
            nutrient_consumption = { TUNING.FARM_PLANT_CONSUME_NUTRIENT_HIGH, TUNING.FARM_PLANT_CONSUME_NUTRIENT_HIGH, TUNING.FARM_PLANT_CONSUME_NUTRIENT_HIGH }
        }
        inst:WatchWorldState("iswinter", OnIsWinter)
        -- 定时消耗水分养料
        -- inst.consumetask2hm = inst:DoPeriodicTask(240, ConsumeNutrients, math.random() * 180 + 60)
        -- inst:AddComponent("farmsoildrinker")
        -- inst.components.farmsoildrinker.getdrinkratefn = GetDrinkRate
        local x, y, z = inst.Transform:GetWorldPosition()
        if TheWorld.Map:GetTileAtPoint(x, y, z) == WORLD_TILES.FARMING_SOIL then
            EnableFarmDock(inst)
        else
            DisableFarmDock(inst)
        end
    end
end
AddPrefabPostInit("dock_damage", function(inst)
    if not TheWorld.ismastersim then return end
    SetOnSave(inst, onsave)
    SetOnLoad(inst, onload)
end)
local function spawnnewfarmdock(pos)
    if not pos then return end
    if #(TheSim:FindEntities(pos.x, 0, pos.z, TUNING.DAYLIGHT_SEARCH_RANGE, { "farmdockfix2hm" })) > 0 then return end
    local inst = SpawnPrefab("dock_damage")
    inst.persists = true
    inst.Transform:SetPosition(pos.x, 0, pos.z)
    onload(inst, { pro2hm = true })
end
local function losewaterandsoil(inst) if not TheWorld.state.iswinter and math.random() < 0.1 then spawnnewfarmdock(inst
        :GetPosition()) end end
local function clearfarmdock(inst, radius)
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, TUNING.DAYLIGHT_SEARCH_RANGE, { "farmdock2hm" })) do if v and v:IsValid() then
            v:Remove() end end
end
-- local function OnTerraform(inst, data, isloading)
--     if not isloading and data.tile == WORLD_TILES.FARMING_SOIL and not TheWorld.state.iswinter then
--         local pos = Vector3(inst.Map:GetTileCenterPoint(data.x, data.y))
--         pos.x = pos.x + math.random() * 3 - 1.5
--         pos.z = pos.z + math.random() * 3 - 1.5
--         spawnnewfarmdock(pos)
--     end
-- end
local function GetFarmDocksOnTile(map, tx, ty)
    local x, y, z = map:GetTileCenterPoint(tx, ty)
    local docks = {}

    for _, ent in ipairs(map:GetEntitiesOnTileAtPoint(x, y, z)) do
        if ent:IsValid() and ent:HasTag("farmdock2hm") then
            table.insert(docks, ent)
        end
    end

    return docks, x, y, z
end

local function OnTerraform(inst, data, isloading)
    if isloading or data == nil then
        return
    end

    local tx, ty = data.x, data.y
    local docks = GetFarmDocksOnTile(inst.Map, tx, ty)

    if data.tile ~= WORLD_TILES.FARMING_SOIL then
        for _, dock in ipairs(docks) do
            DisableFarmDock(dock)
        end
        return
    end

    if TheWorld.state.iswinter then
        return
    end

    -- 等 farming_manager 完成该格湿度初始化
    inst:DoTaskInTime(0, function()
        if inst.Map:GetTile(tx, ty) ~= WORLD_TILES.FARMING_SOIL then
            return
        end

        local currentdocks, x, y, z = GetFarmDocksOnTile(inst.Map, tx, ty)
        if #currentdocks > 0 then
            for _, dock in ipairs(currentdocks) do
                EnableFarmDock(dock)
            end
            return
        end

        local pos = Vector3(x, y, z)
        pos.x = pos.x + math.random() * 3 - 1.5
        pos.z = pos.z + math.random() * 3 - 1.5
        spawnnewfarmdock(pos)
    end)
end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    inst:ListenForEvent("onterraform", OnTerraform)
end)
AddPrefabPostInit("staffcoldlight", function(inst)
    inst:AddTag("farmdockfix2hm")
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, clearfarmdock, TUNING.DAYLIGHT_SEARCH_RANGE)
end)
AddPrefabPostInit("staffcoldlightfx", function(inst)
    inst:AddTag("farmdockfix2hm")
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, clearfarmdock, TUNING.DAYLIGHT_SEARCH_RANGE)
end)
AddPrefabPostInit("deerclopseyeball_sentryward", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inventoryitemholder then
        local self = inst.components.inventoryitemholder
        local onitemgivenfn = self.onitemgivenfn
        self.onitemgivenfn = function(inst, ...)
            onitemgivenfn(inst, ...)
            inst:AddTag("farmdockfix2hm")
            if not POPULATING then clearfarmdock(inst, TUNING.DEERCLOPSEYEBALL_SENTRYWARD_RADIUS) end
        end
        local onitemtakenfn = self.onitemtakenfn
        self.onitemtakenfn = function(inst, ...)
            onitemtakenfn(inst, ...)
            inst:RemoveTag("farmdockfix2hm")
        end
    end
end)
-- 采集后会概率刷出农田杂物
AddComponentPostInit("pickable", function(self)
    if not self.inst:HasOneOfTags(farmplanttags) then return end
    if not POPULATING and self.inst:IsValid() then
        if not self.inst.notlosewaterandsoil then
            losewaterandsoil(self.inst)
        else
            self.inst.notlosewaterandsoil = false
        end
    end
    local oldPick = self.Pick
    self.Pick = function(self, picker, ...)
        if self.inst and self.remove_when_picked and picker and picker:IsValid() and picker.prefab ~= "wormwood" and math.random() < 0.35 then
            SpawnPrefab("farm_soil_debris").Transform:SetPosition(self.inst.Transform:GetWorldPosition())
        end
        return oldPick(self, picker, ...)
    end
end)
local function processworkable(_inst, self)
    if self and self.onfinish then
        local onfinish = self.onfinish
        self.onfinish = function(inst, ...)
            if math.random() < 0.35 then SpawnPrefab("farm_soil_debris").Transform:SetPosition(inst.Transform
                :GetWorldPosition()) end
            onfinish(inst, ...)
        end
    end
end
AddComponentPostInit("workable", function(self)
    if not self.inst:HasOneOfTags(farmplanttags) then return end
    self.inst:DoTaskInTime(0, processworkable, self)
end)

-- 留声机需要齿轮修理
local function phonographonfinished(inst)
    if inst.components.machine then
        if inst.components.machine:IsOn() then inst.components.machine:TurnOff() end
        inst.components.machine.enabled = false
    end
end
local phonographtime = TUNING.isCh2hm and "齿轮修理2hm" or "Gears Repair 2hm"
local function phonographontimerdone(inst, data)
    if data and data.name == phonographtime then
        inst.components.finiteuses:Use(1)
        if inst.components.machine.enabled and inst.components.machine:IsOn() then inst.components.timer:StartTimer(
            phonographtime, 480) end
    end
end
local function onrepaired(inst, repairuse, doer, repair_item, useitems) if inst.components.machine then inst.components.machine.enabled = true end end
AddPrefabPostInit("phonograph", function(inst)
    inst.repairmaterials2hm = { gears = 3 }
    if not TheWorld.ismastersim then return end
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.onrepaired = onrepaired
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", phonographontimerdone)
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(15)
    inst.components.finiteuses:SetUses(0)
    inst.components.finiteuses:SetDoesNotStartFull(true)
    inst.components.finiteuses:SetOnFinished(phonographonfinished)
    if inst.components.machine then
        local turnonfn = inst.components.machine.turnonfn
        inst.components.machine.turnonfn = function(inst, ...)
            if inst.components.finiteuses and inst.components.finiteuses:GetPercent() <= 0 then
                inst.components.machine.enabled = false
                return
            end
            turnonfn(inst, ...)
            if inst.components.machine.enabled then
                if not inst.components.timer:TimerExists(phonographtime) then
                    inst.components.timer:StartTimer(phonographtime, 480)
                else
                    inst.components.timer:ResumeTimer(phonographtime)
                end
            end
        end
        local turnofffn = inst.components.machine.turnofffn
        inst.components.machine.turnofffn = function(inst, ...)
            inst.components.timer:PauseTimer(phonographtime)
            turnofffn(inst, ...)
        end
    end
end)
