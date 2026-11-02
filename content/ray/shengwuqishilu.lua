local exclude_tags = {"player", "wall", "structure", "boat"}

local healthrate = GetModConfigData("shengwuqishilu")
local damagerate = GetModConfigData("shengwuqishilu2")
local healthabsorb = GetModConfigData("shengwuqishilu3")

local updateprefab

local cyclesdamagerate = {}
local function updatedamagerate(inst)
    if inst.components.combat then
        if not cyclesdamagerate[TheWorld.state.cycles] then cyclesdamagerate[TheWorld.state.cycles] = 1 + TheWorld.state.cycles / damagerate end
        inst.components.combat.externaldamagemultipliers:SetModifier(inst, cyclesdamagerate[TheWorld.state.cycles], "shengwuqishilu")
    end
end
if damagerate then
    AddComponentPostInit("combat", function(self)
        if self.inst:HasOneOfTags(exclude_tags) then return end
        updatedamagerate(self.inst)
        if not self.inst.cyclesupdate2hm and updateprefab then
            self.inst.cyclesupdate2hm = true
            self.inst:WatchWorldState("cycles", updateprefab)
        end
    end)
end

local cycleshealthabsorb = {}
local cycleshealthrate = {}
local function updatehealth(inst)
    if inst.updatehealthtask2hm then inst.updatehealthtask2hm = nil end
    if inst.components.health and not inst.components.health:IsDead() then
        if inst.newhealth2hm and inst.newhealth2hm ~= inst.components.health.maxhealth then
            inst.oldhealth2hm = nil
            inst.newhealth2hm = nil
        end
        if not cycleshealthrate[TheWorld.state.cycles] then cycleshealthrate[TheWorld.state.cycles] = 1 + TheWorld.state.cycles / healthrate end
        local currenthealth = inst.components.health.currenthealth
        local changehealth = inst.components.health.maxhealth ~= inst.components.health.currenthealth
        inst.oldhealth2hm = inst.oldhealth2hm or inst.components.health.maxhealth
        inst.newhealth2hm = math.max(inst.oldhealth2hm * cycleshealthrate[TheWorld.state.cycles], inst.components.health.maxhealth)
        inst.components.health.maxhealth = inst.newhealth2hm
        inst.components.health.currenthealth = changehealth and currenthealth or inst.newhealth2hm
        inst.components.health:ForceUpdateHUD(true)
        if inst.components.healthsyncer then inst.components.healthsyncer.max_health = inst.newhealth2hm end
    elseif inst.oldhealth2hm then
        inst.oldhealth2hm = nil
        inst.newhealth2hm = nil
    end
end
local function delayupdatehealth(inst) if not inst.updatehealthtask2hm then inst.updatehealthtask2hm = inst:DoTaskInTime(0, updatehealth) end end
if healthrate or healthabsorb then
    AddComponentPostInit("health", function(self)
        if self.inst:HasOneOfTags(exclude_tags) then return end
        if healthrate then
            local SetMaxHealth = self.SetMaxHealth
            self.SetMaxHealth = function(self, ...)
                SetMaxHealth(self, ...)
                delayupdatehealth(self.inst)
            end
            local OnSave = self.OnSave
            self.OnSave = function(self, ...)
                local data = OnSave(self, ...)
                if self.save_maxhealth then
                    data.newhealth2hm = self.inst.newhealth2hm
                    data.oldhealth2hm = self.inst.oldhealth2hm
                end
                return data
            end
            local OnLoad = self.OnLoad
            self.OnLoad = function(self, data, ...)
                if data.maxhealth ~= nil then
                    self.inst.newhealth2hm = data.newhealth2hm
                    self.inst.oldhealth2hm = data.oldhealth2hm
                    delayupdatehealth(self.inst)
                end
                OnLoad(self, data, ...)
            end
            if not self.inst.cyclesupdate2hm and updateprefab then
                self.inst.cyclesupdate2hm = true
                self.inst:WatchWorldState("cycles", updateprefab)
            end
        end
        if healthabsorb then
            local oldDoDelta = self.DoDelta
            self.DoDelta = function(self, amount, ...)
                if not cycleshealthabsorb[TheWorld.state.cycles] then
                    cycleshealthabsorb[TheWorld.state.cycles] = math.clamp(1000 / (1000 + TheWorld.state.cycles * 1000 / healthabsorb), 0.05, 1)
                end
                return oldDoDelta(self,
                                  amount and amount < 0 and not self._ignore_maxdamagetakenperhit and amount * cycleshealthabsorb[TheWorld.state.cycles] or
                                      amount, ...)
            end
        end
    end)
end

updateprefab = function(inst)
    if healthrate then updatehealth(inst) end
    if damagerate then updatedamagerate(inst) end
end

