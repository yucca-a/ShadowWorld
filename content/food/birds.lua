TUNING.MUTANT_BIRD_HEALTH = 100
TUNING.BIRD_HEALTH = 100
local function SetTrapData(inst) return {healthpercent = inst.components.health and inst.components.health:GetPercent()} end
local function RestoreDataFromTrap(inst, data)
    if data ~= nil and data.healthpercent ~= nil and inst.components.health then inst.components.health:SetPercent(data.healthpercent) end
end
AddPrefabPostInitAny(function(inst)
    if not inst:HasTag("bird") then return end
    if not TheWorld.ismastersim then return end
    if inst.components.inventoryitem ~= nil and inst.components.inventoryitem.trappable and not inst.restoredatafromtrap and not inst.settrapdata then
        inst.restoredatafromtrap = RestoreDataFromTrap
        inst.settrapdata = SetTrapData
    end
end)
-- 鸟笼削弱，现在鸟笼的鸟会受食物的生命值影响了
local errortext = TUNING.isCh2hm and "这只鸟感觉到了这种食物的危险" or "The bird can't eat it now"
local function talkerror(inst) if inst.components.talker then inst.components.talker:Say(errortext) end end
local function ProcessFood(inst, item, giver)
    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then inst.components.sleeper:WakeUp() end
    if item.components.edible ~= nil and item.components.edible.healthvalue and item.components.edible.healthvalue ~= 0 then
        local healthvalue = item.components.edible.healthvalue
        local bird = inst.components.occupiable and inst.components.occupiable:GetOccupant() or nil
        if bird and bird:IsValid() and bird.components.health and bird.components.perishable and not bird.components.health:IsDead() then
            if bird.components.health.currenthealth + healthvalue <= 0 then
                if item and item:IsValid() and giver and giver:IsValid() and giver.components.inventory then
                    giver.components.inventory:GiveItem(item, nil, inst:GetPosition())
                end
                if giver and giver:IsValid() then giver:DoTaskInTime(0, talkerror) end
                return false
            else
                if healthvalue < 0 then bird:PushEvent("attacked", {attacker = giver, damage = 0}) end
                bird.components.health:DoDelta(healthvalue > 0 and healthvalue * 4 or healthvalue)
                -- ForceShowHealthBar2hm(bird, inst)
            end
        end
    end
    return true
end
local function AcceptGift(self, giver, item, count)
    if not self:AbleToAccept(item, giver) then return false end
    if self:WantsToAccept(item, giver) then
        count = count or 1
        if item.components.stackable ~= nil and item.components.stackable.stacksize > count then
            item = item.components.stackable:Get(count)
        else
            item.components.inventoryitem:RemoveFromOwner(true)
        end
        if ProcessFood(self.inst, item, giver) then
            if self.deleteitemonaccept then
                item:Remove()
            elseif self.inst.components.inventory ~= nil then
                item.prevslot = nil
                item.prevcontainer = nil
                self.inst.components.inventory:GiveItem(item, nil, giver ~= nil and giver:GetPosition() or nil)
            end
            if self.onaccept ~= nil then self.onaccept(self.inst, giver, item) end
            self.inst:PushEvent("trade", {giver = giver, item = item})
            return true
        end
    end
    if self.onrefuse ~= nil then self.onrefuse(self.inst, giver, item) end
    return false
end
AddPrefabPostInit("birdcage", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.trader then inst.components.trader.AcceptGift = AcceptGift end
end)

-- 乌鸦黑血
local function birdcd(inst) inst.birdattackedtask2hm = nil end
local function penalty_onblockedorattacked(inst, data)
    if not inst:HasTag("swc2hm") and data and data.attacker and data.attacker.components.health and not data.attacker.components.health:IsDead() and
        not data.attacker:HasTag("catcoon") and not inst.birdattackedtask2hm then
        inst.birdattackedtask2hm = inst:DoTaskInTime(0.25, birdcd)
        if data.attacker:HasTag("player") and data.attacker.sg and data.attacker.sg.currentstate and
            (data.attacker.sg.currentstate.name == "give" or data.attacker.sg.currentstate.name == "idle") then
            data.attacker.sg:GoToState("hit_darkness")
        end
        local playerpenalty = data.attacker:HasTag("player") and not data.attacker.components.health.disable_penalty
        data.attacker.components.health:DoDelta(-(playerpenalty and 5 or 15), false, inst.prefab)
        if playerpenalty then data.attacker.components.health:DeltaPenalty(0.05) end
    end
end
AddPrefabPostInit("crow", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", penalty_onblockedorattacked)
end)

-- 海鸥潮湿冰冻
local function moisture_onblockedorattacked(inst, data)
    if not inst:HasTag("swc2hm") and data and data.attacker and data.attacker.components.health and not data.attacker.components.health:IsDead() and
        not data.attacker:HasTag("catcoon") and not inst.birdattackedtask2hm then
        inst.birdattackedtask2hm = inst:DoTaskInTime(0.25, birdcd)
        if data.attacker.components.combat then data.attacker.components.combat:GetAttacked_Internal(inst, 5) end
        if data.attacker.components.freezable then
            data.attacker.components.freezable:AddColdness(1)
            data.attacker.components.freezable:SpawnShatterFX()
        end
        if data.attacker.components.moisture then data.attacker.components.moisture:DoDelta(15) end
    end
end
AddPrefabPostInit("puffin", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", moisture_onblockedorattacked)
end)

-- 火雀升温干燥
local function firenettle_onblockedorattacked(inst, data)
    if not inst:HasTag("swc2hm") and data and data.attacker and data.attacker.components.health and not data.attacker.components.health:IsDead() and
        not data.attacker:HasTag("catcoon") and not inst.birdattackedtask2hm then
        inst.birdattackedtask2hm = inst:DoTaskInTime(0.25, birdcd)
        if data.attacker.components.combat then data.attacker.components.combat:GetAttacked_Internal(inst, 5) end
        if data.attacker.components.temperature and data.attacker.components.temperature.current < 70 then
            data.attacker.components.temperature:DoDelta(15)
        end
        if data.attacker.components.moisture then data.attacker.components.moisture:DoDelta(-15) end
    end
end
AddPrefabPostInit("robin", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", firenettle_onblockedorattacked)
end)

-- 雪雀冰冻降温
local function freeze_onblockedorattacked(inst, data)
    if not inst:HasTag("swc2hm") and data and data.attacker and data.attacker.components.health and not data.attacker.components.health:IsDead() and
        not data.attacker:HasTag("catcoon") and not inst.birdattackedtask2hm then
        inst.birdattackedtask2hm = inst:DoTaskInTime(0.25, birdcd)
        if data.attacker.components.combat then data.attacker.components.combat:GetAttacked_Internal(inst, 5) end
        if data.attacker.components.temperature and data.attacker.components.temperature.current > 0 then
            data.attacker.components.temperature:DoDelta(-15)
        end
        if data.attacker.components.freezable then
            data.attacker.components.freezable:AddColdness(1)
            data.attacker.components.freezable:SpawnShatterFX()
        end
    end
end
AddPrefabPostInit("robin_winter", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", freeze_onblockedorattacked)
end)

-- 金丝雀电击
local function taser_onblockedorattacked(inst, data)
    if not inst:HasTag("swc2hm") and (data and data.attacker and not data.redirected) and data.attacker.components.health and
        not data.attacker.components.health:IsDead() and not data.attacker:HasTag("catcoon") and not inst.birdattackedtask2hm then
        inst.birdattackedtask2hm = inst:DoTaskInTime(0.25, birdcd)
        if data.attacker.components.combat and (data.attacker.components.health and not data.attacker.components.health:IsDead()) and
            (data.attacker.components.inventory == nil or not data.attacker.components.inventory:IsInsulated()) and
            (data.weapon == nil or
                (data.weapon.components.projectile == nil and (data.weapon.components.weapon == nil or data.weapon.components.weapon.projectile == nil))) then
            SpawnPrefab("electrichitsparks"):AlignToTarget(data.attacker, inst, true)
            local damage_mult = 1
            if not (data.attacker:HasTag("electricdamageimmune") or (data.attacker.components.inventory and data.attacker.components.inventory:IsInsulated())) then
                damage_mult = TUNING.ELECTRIC_DAMAGE_MULT
                local wetness_mult = (data.attacker.components.moisture and data.attacker.components.moisture:GetMoisturePercent()) or
                                         (data.attacker:GetIsWet() and 1) or 0
                damage_mult = damage_mult + wetness_mult
            end
            data.attacker.components.combat:GetAttacked_Internal(inst, damage_mult * 5, nil, "electric")
        elseif data.attacker.components.inventory and data.attacker.components.inventory.equipslots then
            for _, v in pairs(data.attacker.components.inventory.equipslots) do
                if v and v.components.equippable:IsInsulated() then
                    if v.components.fueled then v.components.fueled:DoDelta(-60, inst) end
                    if v.components.finiteuses then v.components.finiteuses:Use(1) end
                    if v.components.armor then v.components.armor:TakeDamage(10) end
                    break
                end
            end
        end
    end
end
AddPrefabPostInit("canary", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", taser_onblockedorattacked)
end)
