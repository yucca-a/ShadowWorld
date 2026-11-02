local function replacetumbleweed(inst)
    if TheWorld.state.season == "summer" then
        local x, y, z = inst.Transform:GetWorldPosition()
        local newtumbleweed = SpawnPrefab("mod_hardmode_tumbleweed")
        newtumbleweed.Transform:SetPosition(x, y, z)
        inst:Remove()
    end
end
local function delayreplacetumbleweed(inst) inst:DoTaskInTime(0, replacetumbleweed) end
AddPrefabPostInit("tumbleweed", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, replacetumbleweed)
    inst:WatchWorldState("issummer", delayreplacetumbleweed)
end)

AddComponentPostInit("sandstorms", function(self)
    local IsInSandstorm = self.IsInSandstorm
    self.IsInSandstorm = function(self, ...) return IsInSandstorm(self, ...) or TUNING.worldsand2hm end
    local GetSandstormLevel = self.GetSandstormLevel
    self.GetSandstormLevel = function(self, ...)
        return math.clamp(GetSandstormLevel(self, ...) + (TUNING.worldsand2hm and TUNING.SANDSTORM_FULL_LEVEL or 0), 0, 1)
    end
end)

AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return inst end
    if not inst.components.waterstreakrain2hm then inst:AddComponent("waterstreakrain2hm") end
    if not TheWorld:HasTag("cave") then inst.components.waterstreakrain2hm.enablesand = true end
end)

-- local targdist = 30
-- local function OnStaffTime(inst, isday)
--     if TheWorld.state.issummer and isday and not inst.mod_hardmode_tumbleweedtask then
--         local index = 0
--         inst.mod_hardmode_tumbleweedtask = inst:DoPeriodicTask(math.random(30) + 60, function()
--             index = index + 1
--             if index >= 3 then
--                 inst.mod_hardmode_tumbleweedtask:Cancel()
--                 inst.mod_hardmode_tumbleweedtask = nil
--             end
--             local x, y, z = inst.Transform:GetWorldPosition()
--             local newtumbleweed = SpawnPrefab("mod_hardmode_tumbleweed")
--             newtumbleweed.Transform:SetPosition(x - math.cos(newtumbleweed.angle) * targdist, y, z + math.sin(newtumbleweed.angle) * targdist)
--         end)
--     end
-- end
-- AddPlayerPostInit(function(inst)
--     if not TheWorld.ismastersim or TheWorld:HasTag("cave") then return inst end
--     inst:WatchWorldState("isday", OnStaffTime)
-- end)
