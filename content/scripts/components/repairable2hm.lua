local Repairable = Class(function(self, inst)
    self.inst = inst
    self.repairmaterials = self.inst.repairmaterials2hm
    self.needgreenamulet = self.inst.needgreenamulet2hm
    -- if self.inst.extramaterials2hm then
    --     for key, value in pairs(self.inst.extramaterials2hm) do
    --         self.extramaterials = key
    --         self.extramaterialsnumber = value
    --     end
    -- end
    -- self.ignoremax = nil
    -- self.customrepair = nil
    -- self.onrepaired = nil
    self.inst:AddTag("repairable2hm")
end)

local PICKUPSOUNDS = {
    ["wood"] = "aqol/new_test/wood",
    ["gem"] = "aqol/new_test/gem",
    ["cloth"] = "aqol/new_test/cloth",
    ["metal"] = "aqol/new_test/metal",
    ["rock"] = "aqol/new_test/rock",
    ["vegetation_firm"] = "aqol/new_test/vegetation_firm",
    ["vegetation_grassy"] = "aqol/new_test/vegetation_grassy",
    ["DEFAULT_FALLBACK"] = "dontstarve/HUD/collect_resource"
}

function Repairable:Repair(doer, repair_item)
    if not (self.repairmaterials and repair_item and repair_item:IsValid() and self.repairmaterials[repair_item.prefab]) then return false end
    local greenamulet
    if self.needgreenamulet or (self.inst.prefab == "glasscutter" and repair_item.prefab == "moonglass") then
        if not (doer and doer.components.inventory) then return end
        for k, v in pairs(doer.components.inventory.equipslots) do
            if v and v:IsValid() and v.prefab == "greenamulet" and v.components.finiteuses then
                greenamulet = v.components.finiteuses
                break
            end
        end
        if not greenamulet then
            local items = doer.components.inventory:GetItemByName("greenamulet", 1, true)
            local item = items and next(items)
            if not (item and item:IsValid() and item.components.finiteuses) then return end
            greenamulet = item.components.finiteuses
        end
    end
    local useitems = 1
    local repairuse = self.repairmaterials[repair_item.prefab]
    if self.customrepair then
        local result = self.customrepair(self.inst, repairuse, doer, repair_item)
        if result ~= -1 then return result end
    end
    if self.inst.components.finiteuses then
        local oldpercent = self.inst.components.finiteuses:GetPercent()
        if oldpercent >= 1 and not self.ignoremax then return false end
        if repair_item.components and repair_item.components.stackable then
            local needs = math.max(math.floor((self.inst.components.finiteuses.total - self.inst.components.finiteuses.current) / repairuse), 1)
            local stacksize = repair_item.components.stackable.stacksize
            if needs and needs > 0 and stacksize and stacksize > 0 then
                useitems = math.min(needs, stacksize)
                self.inst.components.finiteuses:Repair(useitems * repairuse)
            end
        else
            self.inst.components.finiteuses:Repair(repairuse)
        end
        local newpercent = self.inst.components.finiteuses:GetPercent()
        if oldpercent and newpercent and greenamulet then greenamulet:SetPercent(greenamulet:GetPercent() - (newpercent - oldpercent) / 20) end
    elseif self.inst.components.armor then
        local oldpercent = self.inst.components.armor:GetPercent()
        if oldpercent >= 1 and not self.ignoremax then return false end
        if repair_item.components and repair_item.components.stackable then
            local needs = math.max(math.floor((self.inst.components.armor.maxcondition - self.inst.components.armor.condition) / repairuse), 1)
            local stacksize = repair_item.components.stackable.stacksize
            if needs and needs > 0 and stacksize and stacksize > 0 then
                useitems = math.min(needs, stacksize)
                self.inst.components.armor:Repair(useitems * repairuse)
            end
        else
            self.inst.components.armor:Repair(repairuse)
        end
        local newpercent = self.inst.components.armor:GetPercent()
        if oldpercent and newpercent and greenamulet then greenamulet:SetPercent(greenamulet:GetPercent() - (newpercent - oldpercent) / 20) end
    elseif self.inst.components.fueled then
        local oldpercent = self.inst.components.fueled:GetPercent()
        if oldpercent >= 1 and not self.ignoremax then return false end
        local dorepair
        if repair_item.components and repair_item.components.stackable then
            local needs = math.max(math.floor((self.inst.components.fueled.maxfuel - self.inst.components.fueled.currentfuel) / repairuse), 1)
            local stacksize = repair_item.components.stackable.stacksize
            if needs and needs > 0 and stacksize and stacksize > 0 then
                useitems = math.min(needs, stacksize)
                dorepair = useitems * repairuse
                self.inst.components.fueled:DoDelta(dorepair, doer)
            end
        else
            self.inst.components.fueled:DoDelta(repairuse, doer)
            dorepair = repairuse
        end
        if dorepair then
            if self.inst.components.fueled.ontakefuelfn ~= nil then self.inst.components.fueled.ontakefuelfn(self.inst, dorepair) end
            self.inst:PushEvent("takefuel", {fuelvalue = dorepair})
        end
        local newpercent = self.inst.components.fueled:GetPercent()
        if oldpercent and newpercent and greenamulet then greenamulet:SetPercent(greenamulet:GetPercent() - (newpercent - oldpercent) / 20) end
    elseif self.inst.components.perishable then
        local oldpercent = self.inst.components.perishable:GetPercent()
        if oldpercent >= 1 and not self.ignoremax then return false end
        local forceperishable
        if not self.inst.components.perishable:IsPerishing() then
            forceperishable = true
            self.inst.components.perishable:StartPerishing()
        end
        if repair_item.components and repair_item.components.stackable then
            local needs =
                math.max(math.floor((self.inst.components.perishable.perishtime - self.inst.components.perishable.perishremainingtime) / repairuse), 1)
            local stacksize = repair_item.components.stackable.stacksize
            if needs and needs > 0 and stacksize and stacksize > 0 then
                useitems = math.min(needs, stacksize)
                self.inst.components.perishable:AddTime(useitems * repairuse)
            end
        else
            self.inst.components.perishable:AddTime(repairuse)
        end
        if forceperishable then self.inst.components.perishable:StopPerishing() end
        local newpercent = self.inst.components.perishable:GetPercent()
        if oldpercent and newpercent and greenamulet then greenamulet:SetPercent(greenamulet:GetPercent() - (newpercent - oldpercent) / 20) end
    elseif self.inst.components.rechargeable then
        if self.inst.components.rechargeable:IsCharged() then return false end
        local oldpercent = self.inst.components.rechargeable:GetPercent()
        local chargetime = self.inst.components.rechargeable:GetTimeToCharge()
        local reducetime = repairuse
        if repair_item.components and repair_item.components.stackable then
            local needs =
                math.max(math.floor(chargetime / reducetime), 1)
            local stacksize = repair_item.components.stackable.stacksize
            if needs and needs > 0 and stacksize and stacksize > 0 then
                useitems = math.min(needs, stacksize)
                self.inst.components.rechargeable:OnUpdate(useitems * reducetime)
            end
        else
            self.inst.components.rechargeable:OnUpdate(reducetime)
        end
        local newpercent = self.inst.components.rechargeable:GetPercent()
        if oldpercent and newpercent and greenamulet then greenamulet:SetPercent(greenamulet:GetPercent() - (newpercent - oldpercent) / 20) end
    end
    if doer and doer.SoundEmitter then
        if repair_item.pickupsound and PICKUPSOUNDS[repair_item.pickupsound] or
            (repair_item.components and repair_item.components.repairer and repair_item.components.repairer.boatrepairsound) then
            doer.SoundEmitter:PlaySound(repair_item.pickupsound and PICKUPSOUNDS[repair_item.pickupsound] or repair_item.components.repairer.boatrepairsound)
        else
            doer.SoundEmitter:PlaySound(repair_item.pickupsound and PICKUPSOUNDS[repair_item.pickupsound] or "turnoftides/common/together/boat/repair_with_wood")
        end
    end
    if self.onrepaired then self.onrepaired(self.inst, repairuse, doer, repair_item, useitems) end
    if repair_item.components and repair_item.components.stackable then
        repair_item.components.stackable:Get(useitems):Remove()
    else
        repair_item:Remove()
    end

    return true
end

return Repairable
