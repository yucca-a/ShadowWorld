--- Spawns and tracks child entities in the world
-- For setup the following params should be set
-- @param childname The prefab name of the default child to be spawned. This can be overridden in the SpawnChild method
-- @param delay The time between spawning children when the spawner is actively spawning. If nil, only manual spawning works.
-- @param newchilddelay The time it takes for a killed/captured child to be regenerated in the childspawner. If nil, dead children aren't regenerated.
-- It's also a good idea to call SetMaxChildren as part of the childspawner setup.
local function AddChildOutside(self, child)
    if self.childrenoutside[child] ~= nil then return end

    self.childrenoutside[child] = child
    self.numchildrenoutside = GetTableSize(self.childrenoutside)
end

local function RemoveChildOutside(self, child)
    if self.childrenoutside[child] == nil then return end

    self.childrenoutside[child] = nil
    self.numchildrenoutside = GetTableSize(self.childrenoutside)
end

local function AddEmergencyChildOutside(self, child)
    self.emergencychildrenoutside[child] = child
    self.numemergencychildrenoutside = GetTableSize(self.emergencychildrenoutside)
end

local function RemoveEmergencyChildOutside(self, child)
    self.emergencychildrenoutside[child] = nil
    self.numemergencychildrenoutside = GetTableSize(self.emergencychildrenoutside)
end

local function AddChildListeners(self, child)
    self.inst:ListenForEvent("ontrapped", self._onchildkilled, child)
    self.inst:ListenForEvent("death", self._onchildkilled, child)
    self.inst:ListenForEvent("onremove", self._onchildkilled, child)
    self.inst:ListenForEvent("detachchild", self._onchildkilled, child)
end

local function RemoveChildListeners(self, child)
    self.inst:RemoveEventCallback("ontrapped", self._onchildkilled, child)
    self.inst:RemoveEventCallback("death", self._onchildkilled, child)
    self.inst:RemoveEventCallback("onremove", self._onchildkilled, child)
    self.inst:RemoveEventCallback("detachchild", self._onchildkilled, child)
end

local ChildSpawner = Class(function(self, inst)
    self.inst = inst
    self.childrenoutside = {}
    self.childreninside = 1
    self.numchildrenoutside = 0
    self.maxchildren = 0

    self.childname = ""
    self.queuedchildren = nil
    self.queuedidx = 0
    -- self.queuedlimit = nil
    self.rarechild = nil
    self.rarechildchance = 0.1

    self.onvacate = nil
    self.onoccupied = nil
    self.onspawned = nil
    self.ontakeownership = nil
    self.ongohome = nil

    self.spawning = false
    self.queued_spawn = false
    self.timetonextspawn = 0
    self.spawnperiod = self.inst.shadowcantout2hm and 2 or 20
    self.spawnvariance = self.inst.shadowcantout2hm and 1 or 2
    -- self.spawnradius = nil

    self.regening = true
    self.timetonextregen = 0
    self.regenperiod = 20
    self.regenvariance = 2
    self.spawnoffscreen = false

    self.task = nil

    -- "Emergency" children, for when multiple players are around
    -- This is almost like a second spawner running alongside the first
    self.emergencychildname = nil
    self.emergencychildrenperplayer = 1
    self.maxemergencychildren = 0
    self.maxemergencycommit = 0
    self.emergencydetectionradius = 10

    self.emergencychildreninside = 0
    self.emergencychildrenoutside = {}
    self.numemergencychildrenoutside = 0

    self._doqueuedspawn = function() self:DoQueuedSpawn() end
    self._onchildkilled = function(child) self:OnChildKilled(child) end

    self.useexternaltimer = false
    -- self.regentimerstart = nil
    -- self.regentimerstop = nil
    -- self.spawntimerstart = nil
    -- self.spawntimerstop = nil
    -- self.spawntimerset = nil
end)

function ChildSpawner:GetTimeToNextSpawn() return self.spawnperiod + (math.random() * 2 - 1) * self.spawnvariance end

function ChildSpawner:GetTimeToNextRegen() return self.regenperiod + (math.random() * 2 - 1) * self.regenvariance end

function ChildSpawner:OnRemoveFromEntity()
    for k, v in pairs(self.childrenoutside) do RemoveChildListeners(self, v) end
    for k, v in pairs(self.emergencychildrenoutside) do RemoveChildListeners(self, v) end
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function ChildSpawner:StartRegen()
    self.regening = true

    if not (self:IsFull() and self:IsEmergencyFull()) then
        self.timetonextregen = self:GetTimeToNextRegen()
        self:StartUpdate()
    end
end

function ChildSpawner:SetRareChild(childname, chance)
    self.rarechild = childname
    self.rarechildchance = chance
end

function ChildSpawner:SetQueuedChildren(queuedchildren, queuedlimit)
    self.queuedchildren = queuedchildren
    self.queuedlimit = queuedlimit
end

function ChildSpawner:StopRegen()
    self.regening = false
    self:TryStopUpdate()
end

function ChildSpawner:SetSpawnPeriod(period, variance)
    self.spawnperiod = self.inst.shadowcantout2hm and 2 or period
    self.spawnvariance = (self.inst.shadowcantout2hm and 1 or variance) or period * 0.1
    self.timetonextspawn = self:GetTimeToNextSpawn()
end

function ChildSpawner:SetRegenPeriod(period, variance)
    self.regenperiod = period
    self.regenvariance = variance or period * 0.1
    self.timetonextregen = self:GetTimeToNextRegen()
end

function ChildSpawner:SetEmergencyRadius(rad) self.emergencydetectionradius = rad end

function ChildSpawner:IsFull() return self:NumChildren() >= self.maxchildren end

function ChildSpawner:NumChildren() return self.numchildrenoutside + self.childreninside end

function ChildSpawner:IsEmergencyFull() return self:NumEmergencyChildren() >= self.maxemergencychildren end

function ChildSpawner:NumEmergencyChildren() return self.numemergencychildrenoutside + self.emergencychildreninside end

function ChildSpawner:DoRegen()
    if self.regening then
        if not self:IsFull() then self:AddChildrenInside(1) end
        if not self:IsEmergencyFull() then self:AddEmergencyChildrenInside(1) end
    end
end

function ChildSpawner:OnUpdate(dt)
    if not self.useexternaltimer and self.regening then
        if not (self:IsFull() and self:IsEmergencyFull()) then
            self.timetonextregen = self.timetonextregen - dt
            if self.timetonextregen < 0 then
                self.timetonextregen = self:GetTimeToNextRegen()
                self:DoRegen()
            end
        end
    end

    if not self.useexternaltimer and self.spawning and not self.queued_spawn then
        if self.childreninside > 0 then
            self.timetonextspawn = self.timetonextspawn - dt
            if self.timetonextspawn < 0 then
                self.timetonextspawn = self:GetTimeToNextSpawn()
                if self:CanSpawnOffscreenOrAwake() then
                    self:SpawnChild()
                else
                    self:QueueSpawnChild()
                end
            end
        else
            self.timetonextspawn = 0
        end
    end

    self:TryStopUpdate()
end

local function _OnUpdate(inst, self, dt) self:OnUpdate(dt) end

function ChildSpawner:ShouldUpdate()
    return (self.spawning and not self.queued_spawn and self.childreninside > 0) or (self.regening and not (self:IsFull() and self:IsEmergencyFull()))
end

function ChildSpawner:StartUpdate()
    if self.useexternaltimer then
        if self.spawning and not self.queued_spawn and self.childreninside > 0 then self.spawntimerstart(self.inst) end
        if self.regening and not (self:IsFull() and self:IsEmergencyFull()) then self.regentimerstart(self.inst) end
    elseif self.task == nil and self:ShouldUpdate() then
        local dt = 5 + math.random() * 5
        self.task = self.inst:DoPeriodicTask(dt, _OnUpdate, nil, self, dt)
    end
end

function ChildSpawner:TryStopUpdate()
    if self.useexternaltimer then
        if not (self.spawning and self.childreninside > 0) then self.spawntimerstop(self.inst) end
        if not (self.regening and not (self:IsFull() and self:IsEmergencyFull())) then self.regentimerstop(self.inst) end
    elseif self.task and not self:ShouldUpdate() then
        self.task:Cancel()
        self.task = nil
    end
end

function ChildSpawner:StartSpawning()
    self.spawning = true
    self.timetonextspawn = 0
    self:StartUpdate()
    if self.useexternaltimer then self.spawntimerset(self.inst, 0) end
end

function ChildSpawner:StopSpawning()
    self.spawning = false
    self:TryStopUpdate()
end

function ChildSpawner:SetOccupiedFn(fn) self.onoccupied = fn end

function ChildSpawner:SetSpawnedFn(fn) self.onspawned = fn end

function ChildSpawner:SetQueueSpawnedFn(fn) self.onqueuespawned = fn end

function ChildSpawner:SetOnTakeOwnershipFn(fn) self.ontakeownership = fn end

function ChildSpawner:SetGoHomeFn(fn) self.ongohome = fn end

function ChildSpawner:SetVacateFn(fn) self.onvacate = fn end

function ChildSpawner:SetOnChildKilledFn(fn) self.onchildkilledfn = fn end

function ChildSpawner:SetOnAddChildFn(fn) self.onaddchild = fn end

function ChildSpawner:CountChildrenOutside(fn)
    local vacantchildren = 0
    for k, v in pairs(self.childrenoutside) do if v and v:IsValid() and (not fn or fn(v)) then vacantchildren = vacantchildren + 1 end end
    return vacantchildren
end

function ChildSpawner:SetMaxChildren(max)
    self.childreninside = max - self:CountChildrenOutside()
    self.maxchildren = max
    if self.childreninside < 0 then self.childreninside = 0 end
    self:TryStopUpdate() -- try to stop updating incase maxchildren decreased and now regening has finished.
    self:StartUpdate() -- try to start updating incase maxchildren increased and now regening should start. also childreniniside can now be > 0 and therefore spawning could start.
end

function ChildSpawner:SetMaxEmergencyChildren(max)
    self.emergencychildreninside = max - self.numemergencychildrenoutside
    self.emergencychildreninside = math.max(0, self.emergencychildreninside)
    self.maxemergencychildren = max
    if self.emergencychildreninside < 0 then self.emergencychildreninside = 0 end
    self:TryStopUpdate() -- try to stop updating incase maxchildren decreased and now regening has finished.
    self:StartUpdate() -- try to start updating incase maxchildren increased and now regening should start.
end

function ChildSpawner:OnSave()
    if self.cansave then
        local data = {}
        local references = {}

        for k, v in pairs(self.childrenoutside) do
            if data.childrenoutside == nil then
                data.childrenoutside = {v.GUID}
            else
                table.insert(data.childrenoutside, v.GUID)
            end

            table.insert(references, v.GUID)
        end
        data.childreninside = self.childreninside

        for k, v in pairs(self.emergencychildrenoutside) do
            if data.emergencychildrenoutside == nil then
                data.emergencychildrenoutside = {v.GUID}
            else
                table.insert(data.emergencychildrenoutside, v.GUID)
            end

            table.insert(references, v.GUID)
        end
        data.emergencychildreninside = self.emergencychildreninside

        data.spawning = self.spawning
        data.regening = self.regening
        data.queued_spawn = self.queued_spawn
        data.timetonextregen = math.floor(self.timetonextregen)
        data.timetonextspawn = math.floor(self.timetonextspawn)

        return data, references
    elseif self.inst:HasTag("swp2hm") and self.inst:HasTag("epic") and self.numchildrenoutside > 0 then
        local data = {}
        data.add_component_if_missing = true
        data.prefabposlist = {}
        for k, v in pairs(self.childrenoutside) do
            if v and v:IsValid() and v.prefab then
                data.prefabposlist[v.prefab] = data.prefabposlist[v.prefab] or {}
                local x, y, z = v.Transform:GetWorldPosition()
                table.insert(data.prefabposlist[v.prefab], {x = x, y = y, z = z})
            end
        end
        return data
    end
end

function ChildSpawner:GetDebugString()
    local str = string.format("%s: %d in, %d out", self.childname, self.childreninside, self.numchildrenoutside)

    local num_children = self.numchildrenoutside + self.childreninside
    if num_children < self.maxchildren and self.regening then str = str .. string.format(" Regen in %2.2f ", self.timetonextregen) end

    if self.childreninside > 0 and self.spawning then str = str .. string.format(" Spawn in %2.2f ", self.timetonextspawn) end

    if self.spawning then str = str .. " : Spawning " end

    if self.regening then str = str .. " : Regening :" end

    if self.maxemergencychildren > 0 then
        str = str ..
                  string.format(" emgergency: %d in %d out (commit %d/%d)", self.emergencychildreninside, self.numemergencychildrenoutside,
                                self.maxemergencycommit, self.maxemergencychildren)
    end

    return str
end

function ChildSpawner:OnLoad(data)
    if self.cansave then
        -- convert previous data
        if data.occupied then data.childreninside = 1 end
        if data.childid ~= nil then data.childrenoutside = {data.childid} end

        if data.childreninside ~= nil then
            self.childreninside = 0
            self:AddChildrenInside(data.childreninside)
            if self.childreninside > 0 and self.onoccupied ~= nil then
                self.onoccupied(self.inst)
            elseif self.childreninside == 0 and self.onvacate ~= nil then
                self.onvacate(self.inst)
            end
        end

        self.spawning = data.spawning or self.spawning
        self.regening = data.regening or self.regening
        self.queued_spawn = data.queued_spawn or self.queued_spawn
        self.timetonextregen = data.timetonextregen or self.timetonextregen
        self.timetonextspawn = data.timetonextspawn or self.timetonextspawn

        if data.emergencychildreninside ~= nil then
            self.emergencychildreninside = 0
            self:AddEmergencyChildrenInside(data.emergencychildreninside)
        end
        self.maxemergencycommit = data.maxemergencycommit or 0
    elseif POPULATING and data.add_component_if_missing and data.prefabposlist and TUNING.shadowworld2hm then
        self.tmpprefabposlist = data.prefabposlist
    end
end

function ChildSpawner:DoTakeOwnership(child)
    AddChildListeners(self, child)
    if self.ontakeownership ~= nil then self.ontakeownership(self.inst, child) end
end

function ChildSpawner:TakeOwnership(child)
    self:DoTakeOwnership(child)
    AddChildOutside(self, child)
    self:TryStopUpdate()
end

function ChildSpawner:TakeEmergencyOwnership(child)
    self:DoTakeOwnership(child)
    AddEmergencyChildOutside(self, child)
    self:TryStopUpdate()
end

function ChildSpawner:LoadPostPass(newents, savedata)
    if savedata.childrenoutside ~= nil then
        for i, v in ipairs(savedata.childrenoutside) do
            local child = newents[v]
            if child ~= nil then self:TakeOwnership(child.entity) end
        end
    end
    if savedata.emergencychildrenoutside ~= nil then
        for i, v in ipairs(savedata.emergencychildrenoutside) do
            local child = newents[v]
            if child ~= nil then self:TakeEmergencyOwnership(child.entity) end
        end
    end
    self:StartUpdate()
    self:TryStopUpdate()
end

local function NoHoles(pt) return not TheWorld.Map:IsPointNearHole(pt) end

-- This should only be called internally
function ChildSpawner:DoSpawnChild(target, prefab, radius)
    local childprefab = prefab or self.childname
    local childidx
    if self.rarechild ~= nil and math.random() < self.rarechildchance then
        childprefab = self.rarechild
    elseif self.queuedchildren and not IsTableEmpty(self.queuedchildren) then
        local total = #self.queuedchildren
        if self.queuedlimit and self.numchildrenoutside > 0 then
            -- 仅考虑存在数目，每种子体都需要生成且限制生成一种，默认种类则不限制数目
            local queuedidx = self.queuedidx
            for i = 1, #self.queuedchildren + 1, 1 do
                self.queuedidx = self.queuedidx + 1
                if self.queuedidx > total then self.queuedidx = 0 end
                childidx = self.queuedidx
                childprefab = self.queuedchildren[self.queuedidx] or prefab or self.childname
                local empty = true
                for i, v in pairs(self.childrenoutside) do
                    if v and v:IsValid() and childidx == (v.childidx2hm or 0) then
                        empty = false
                        break
                    end
                end
                if empty then break end
            end
            -- 都遍历一遍后，发现还是这个次序，说明每种子体都已存在，则生成默认种类
            if self.queuedidx == queuedidx then
                self.queuedidx = 0
                childidx = 0
                childprefab = prefab or self.childname
            end
        else
            -- 仅考虑生成顺序，循环生成每种子体，queuedidx是上次生成的字体次序
            self.queuedidx = self.queuedidx + 1
            if self.queuedidx > total then self.queuedidx = 0 end
            childidx = self.queuedidx
            childprefab = self.queuedchildren[self.queuedidx] or prefab or self.childname
        end
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local pos
    if self.tmpprefabposlist and self.tmpprefabposlist[childprefab] then
        local length = #self.tmpprefabposlist[childprefab]
        pos = self.tmpprefabposlist[childprefab][length] or Vector3(x, y, z)
        if length == 1 then
            self.tmpprefabposlist[childprefab] = nil
            if IsTableEmpty(self.tmpprefabposlist) then self.tmpprefabposlist = nil end
        else
            table.remove(self.tmpprefabposlist[childprefab], length)
        end
    else
        local offset
        local spawn_radius = radius
        if spawn_radius == nil then
            if self.spawnradius ~= nil then
                if type(self.spawnradius) == "table" then
                    spawn_radius = Lerp(self.spawnradius.min, self.spawnradius.max, math.sqrt(math.random()))
                else
                    spawn_radius = self.spawnradius
                end
            else
                spawn_radius = 0.5
            end
        end
        if self.overridespawnlocation then
            offset = self.overridespawnlocation(self.inst)
        elseif self.wateronly then
            offset = FindSwimmableOffset(Vector3(x, 0, z), math.random() * PI * 2, spawn_radius + self.inst:GetPhysicsRadius(0), 8, false, true, NoHoles)
        else
            offset = FindWalkableOffset(Vector3(x, 0, z), math.random() * PI * 2, spawn_radius + self.inst:GetPhysicsRadius(0), 8, false, true, NoHoles,
                                        self.allowwater, self.allowboats)
        end
        if offset == nil then return end
        pos = Vector3(x + offset.x, self.spawn_height or 0, z + offset.z)
    end

    local child = SpawnPrefab(childprefab, self.inst.skinname, self.inst.skin_id)
    if child ~= nil then
        if self.inst.alt_skin_ids then child.alt_skin_ids = self.inst.alt_skin_ids end
        child.Transform:SetPosition(pos.x, pos.y, pos.z)
        child.childidx2hm = childidx
        if child.components.inventoryitem ~= nil then child.components.inventoryitem:InheritMoisture(TheWorld.state.wetness, TheWorld.state.iswet) end
        if target ~= nil and child.components.combat ~= nil then child.components.combat:SetTarget(target) end
        if self.onspawned ~= nil then self.onspawned(self.inst, child) end
        if child.childidx2hm and child.childidx2hm ~= 0 and self.onqueuespawned ~= nil then self.onqueuespawned(self.inst, child) end
    end
    return child
end

function ChildSpawner:QueueSpawnChild()
    self.queued_spawn = true
    self:TryStopUpdate()
end

function ChildSpawner:OnEntityWake() if self.queued_spawn then self.inst:DoTaskInTime(0, self._doqueuedspawn) end end

function ChildSpawner:DoQueuedSpawn()
    self.queued_spawn = false
    if self.spawning then self:SpawnChild() end
    self:StartUpdate()
end

function ChildSpawner:SpawnChild(target, prefab, radius)
    if not self:CanSpawn() then return nil end

    local child = self:DoSpawnChild(target, prefab or self.childname, radius)
    if child ~= nil then
        self.childreninside = self.childreninside - 1
        self:TakeOwnership(child)
        if self.childreninside == 0 and self.onvacate ~= nil then self.onvacate(self.inst) end
    end
    return child
end

function ChildSpawner:SpawnEmergencyChild(target, prefab, radius)
    if not self:CanEmergencySpawn() then return end

    local child = self:DoSpawnChild(target, prefab or self.emergencychildname, radius)
    if child ~= nil then
        self.emergencychildreninside = self.emergencychildreninside - 1
        self:TakeEmergencyOwnership(child)
    end
    return child
end

local EMERGENCYCOMMIT_MUST_TAGS = {"player"}
local EMERGENCYCOMMIT_CANT_TAGS = {"playerghost"}

function ChildSpawner:UpdateMaxEmergencyCommit()
    if self.emergencydetectionradius == 0 then
        self.maxemergencycommit = 0
        return
    end
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, self.emergencydetectionradius, EMERGENCYCOMMIT_MUST_TAGS, EMERGENCYCOMMIT_CANT_TAGS)
    self.maxemergencycommit = RoundBiasedDown(#ents * self.emergencychildrenperplayer)
end

function ChildSpawner:TrySpawnEmergencyChild()
    self:UpdateMaxEmergencyCommit()
    return self:SpawnEmergencyChild()
end

function ChildSpawner:GoHome(child)
    if self.gohomevalidatefn then if not self.gohomevalidatefn(self.inst) then return false end end
    if self.childrenoutside[child] then
        self.inst:PushEvent("childgoinghome", {child = child})
        child:PushEvent("goinghome", {home = self.inst})
        if self.ongohome then self.ongohome(self.inst, child) end
        RemoveChildOutside(self, child)
        child:Remove()
        self:AddChildrenInside(1)
        return true
    end
    if self.emergencychildrenoutside[child] then
        self.inst:PushEvent("childgoinghome", {child = child})
        child:PushEvent("goinghome", {home = self.inst})
        if self.ongohome ~= nil then self.ongohome(self.inst, child) end
        RemoveEmergencyChildOutside(self, child)
        child:Remove()
        self:AddEmergencyChildrenInside(1)
        return true
    end
end

function ChildSpawner:AllGoHome()
    for k, v in pairs(self.childrenoutside) do if v and v:IsValid() then self:GoHome(v) end end
    for k, v in pairs(self.emergencychildrenoutside) do if v and v:IsValid() then self:GoHome(v) end end
end

function ChildSpawner:CanSpawnOffscreenOrAwake() return self.spawnoffscreen or not self.inst:IsAsleep() end

function ChildSpawner:CanSpawn()
    return self.inst:IsValid() -- V2C: This valid check probably hid a lot of bugs that we could've caught and fixed =(
    and self.childreninside > 0 and (self:CanSpawnOffscreenOrAwake()) and (self.inst.components.health == nil or not self.inst.components.health:IsDead()) and
               (self.canspawnfn == nil or self.canspawnfn(self.inst))
end

function ChildSpawner:CanEmergencySpawn()
    return self.inst:IsValid() -- V2C: This valid check probably hid a lot of bugs that we could've caught and fixed =(
    and self.canemergencyspawn and self.emergencychildreninside > 0 -- the num inside means 'comitted' is both outside and dead
    and self.maxemergencychildren - self.emergencychildreninside < self.maxemergencycommit and (self:CanSpawnOffscreenOrAwake()) and
               (self.inst.components.health == nil or not self.inst.components.health:IsDead())
end

function ChildSpawner:OnChildKilled(child)
    RemoveChildListeners(self, child)

    if self.childrenoutside[child] then
        RemoveChildOutside(self, child)

        if self.onchildkilledfn ~= nil then self.onchildkilledfn(self.inst, child) end

        self:StartUpdate()
    end
    if self.emergencychildrenoutside[child] then
        RemoveEmergencyChildOutside(self, child)

        self:StartUpdate()
    end
end

function ChildSpawner:ReleaseAllChildren(target, prefab, radius)
    local failures = 0 -- prevent infinate loops when SpawnChild fails to spawn its child
    local children_released = {}

    while self:CanSpawn() and failures < 3 do
        local new_child = self:SpawnChild(target, prefab, radius)

        if new_child == nil then
            failures = failures + 1
        else
            failures = 0
            table.insert(children_released, new_child)
        end
    end

    failures = 0
    self:UpdateMaxEmergencyCommit()
    while self:CanEmergencySpawn() and failures < 3 do
        local new_child = self:SpawnEmergencyChild(target, prefab, radius)
        if new_child == nil then
            failures = failures + 1
        else
            table.insert(children_released, new_child)
            failures = 0
        end
    end

    return children_released
end

function ChildSpawner:AddChildrenInside(count)
    if self.childreninside == 0 and self.onoccupied then self.onoccupied(self.inst) end
    self.childreninside = self.childreninside + count
    if self.maxchildren ~= nil then self.childreninside = math.min(self.maxchildren, self.childreninside) end
    if self.onaddchild ~= nil then self.onaddchild(self.inst, count) end

    self:TryStopUpdate() -- try to stop the update because regening conditions might be invalid now.
    self:StartUpdate() -- try to start the update because spawning conditions might be valid now.
end

function ChildSpawner:AddEmergencyChildrenInside(count)
    self.emergencychildreninside = self.emergencychildreninside + count
    if self.maxemergencychildren then self.emergencychildreninside = math.min(self.maxemergencychildren, self.emergencychildreninside) end
    self:TryStopUpdate()
end

function ChildSpawner:LongUpdate(dt) self:OnUpdate(dt) end

return ChildSpawner
