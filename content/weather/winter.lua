-- 冬季玩家附近生成冷源
local function onphasechange(inst)
    if not inst:HasTag("playerghost") and TheWorld.state.iswinter and (TheWorld.state.isdusk or TheWorld.state.isnight or TheWorld:HasTag("cave")) and
        not inst.winterstafflighttask2hm then
        inst.winterstafflighttask2hm = inst:DoTaskInTime(math.random(10) + 1, function()
            inst.winterstafflighttask2hm = nil
            local x, y, z = inst.Transform:GetWorldPosition()
            local staff2 = SpawnPrefab("mod_hardmode_staffcoldlight")
            staff2.Transform:SetPosition(x + (math.random(2) - 1.5) * 40, y, z + (math.random(2) - 1.5) * 40)
        end)
    end
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:WatchWorldState("phase", onphasechange)
    inst:WatchWorldState("cavephase", onphasechange)
end)

if GetModConfigData("winter_change") ~= -1 then
    AddPrefabPostInit("world", function(inst)
        if not inst.ismastersim then return inst end
        if not inst.components.waterstreakrain2hm then inst:AddComponent("waterstreakrain2hm") end
        inst.components.waterstreakrain2hm.enablesnow = true
    end)
    local function checkDynamicShadow(inst) if inst.DynamicShadow then inst.DynamicShadow:Enable(inst:HasTag("DynamicShadow2hm")) end end
    AddPrefabPostInit("snowball", function(inst)
        if not inst.DynamicShadow then
            inst.entity:AddDynamicShadow()
            inst.DynamicShadow:SetSize(2.5, 1.5)
            inst:DoTaskInTime(0, checkDynamicShadow)
            inst.DynamicShadow:Enable(false)
        end
    end)
    -- 2025.10.7 melon:雪球雪仅扑灭火堆33%燃料，根据玩家保暖值加冰冻层数和降温------------------------
    local function ApplyProtectionToEntity2hm(self, ent, noextinguish)
        if ent.components.burnable ~= nil then
            if self.witherprotectiontime > 0 and ent.components.witherable ~= nil then
                ent.components.witherable:Protect(self.witherprotectiontime)
            end
        end
        -- 修改部分
        if ent:HasTag("campfire") then
            ent.components.fueled:SetPercent(ent.components.fueled:GetPercent() - 0.33)
        elseif ent:HasTag("player") then
            local insulation = ent.components.temperature:GetInsulation() -- 获取玩家保暖值
            if self.addcoldness > 0 and ent.components.freezable ~= nil and ent.components.freezable.redirectfn and not ent.components.freezable.redirectfn(ent, self.addcoldness) then
                local coldness = insulation < 240 and self.addcoldness or insulation < 360 and self.addcoldness / 2 or 0
                -- print2hm("coldness", coldness, "insulation", insulation)
                ent.components.freezable:AddColdness(self.addcoldness)
            end
            if self.temperaturereduction > 0 and ent.components.temperature ~= nil then
                local dt = insulation < 240 and self.temperaturereduction or insulation < 360 and self.temperaturereduction / 2 or 0
                -- print2hm("dt", dt, "insulation", insulation)
                ent.components.temperature:SetTemperature(ent.components.temperature:GetCurrent() - dt)
            end
        end
        --
        if self.addwetness > 0 then
            if ent.components.moisture ~= nil then
                local waterproofness = ent.components.moisture:GetWaterproofness()
                ent.components.moisture:DoDelta(self.addwetness * (1 - waterproofness))
            elseif self.applywetnesstoitems and ent.components.inventoryitem ~= nil then
                ent.components.inventoryitem:AddMoisture(self.addwetness)
            end
        end
    end
    AddPrefabPostInit("snowball", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.wateryprotection then
            local _ApplyProtectionToEntity = inst.components.wateryprotection.ApplyProtectionToEntity
            inst.components.wateryprotection.ApplyProtectionToEntity = function(self, ent, noextinguish, ...)
                if ent:HasTag("notarget") then return end
                if true and (
                -- if self.inst:HasTag("DynamicShadow2hm") and ( -- 雪球雪才执行
                    ent:HasTag("player") and (self.addcoldness > 0 or self.temperaturereduction > 0) and ent.components.temperature or
                    ent:HasTag("campfire") and ent.components.burnable ~= nil and not noextinguish and self.extinguish and ent.components.fueled ~= nil and ent.components.fueled:GetPercent() > 0.33
                ) then
                    ApplyProtectionToEntity2hm(self, ent, noextinguish, ...)
                else
                    _ApplyProtectionToEntity(self, ent, noextinguish, ...)
                end
            end
        end
    end)
end

-- 地热喷孔冬季失效
AddPrefabPostInit("cave_vent_rock", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.heater then
        local oldfn = inst.components.heater.heatfn
        inst.components.heater.heatfn = function(inst, ...)
            if TheWorld.state.iswinter then 
                return TUNING.CAVE_VENTS.HEAT.COLD_ACTIVE
            else
                return oldfn(inst, ...)
            end
        end
    end
end)
