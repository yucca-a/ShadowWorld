AddComponentPostInit("sleepingbaguser", function(self)
    local SleepTick = self.SleepTick
    self.SleepTick = function(self, ...)
        local oldhealth, oldhunger, oldsanity
        if self.inst.components.sanity and self.inst.components.health then
            local health = 0.5
            local sanity = 0.5
            local sleepout = true
            local upgrade
            if self.bed and self.bed:IsValid() then
                if self.bed.components.persistent2hm and self.bed.components.persistent2hm.data.upgrade then
                    upgrade = true
                    health = 1
                    sanity = 1
                elseif not (self.bed.components.inventoryitem and self.bed.components.inventoryitem.owner) then
                    sleepout = false
                end
            end
            if upgrade then
                if self.inst.components.health:GetPercentWithPenalty() >= 1 or
                    (self.inst.components.oldager and self.bed and self.bed:IsValid() and not self.inst.components.oldager.valid_healing_causes[self.bed.prefab]) then
                    oldhealth = self.health_bonus_mult
                    self.health_bonus_mult = 0
                end
                if self.inst.components.sanity:GetPercentWithPenalty() >= 1 then
                    oldsanity = self.sanity_bonus_mult
                    self.sanity_bonus_mult = 0
                end
            else
                if self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) and
                    self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD):HasTag("good_sleep_aid") then
                    health = health + (sleepout and -0.1 or 0.1)
                    sanity = sanity + (sleepout and -0.1 or 0.1)
                end
                if sleepout then
                    health = health - 0.05
                    sanity = sanity - 0.05
                    if self.inst.components.health:GetPercent() < health or self.inst.components.health:GetPercentWithPenalty() >= 1 or
                        (self.inst.components.oldager and self.bed and self.bed:IsValid() and
                            not self.inst.components.oldager.valid_healing_causes[self.bed.prefab]) then
                        oldhealth = self.health_bonus_mult
                        self.health_bonus_mult = 0
                    end
                    if self.inst.components.sanity:GetPercent() < sanity or self.inst.components.sanity:GetPercentWithPenalty() >= 1 then
                        oldsanity = self.sanity_bonus_mult
                        self.sanity_bonus_mult = 0
                    end
                else
                    if self.inst.components.health:GetPercent() > health or self.inst.components.health:GetPercentWithPenalty() >= 1 or
                        (self.inst.components.oldager and self.bed and self.bed:IsValid() and
                            not self.inst.components.oldager.valid_healing_causes[self.bed.prefab]) then
                        oldhealth = self.health_bonus_mult
                        self.health_bonus_mult = 0
                    end
                    if self.inst.components.sanity:GetPercent() > sanity or self.inst.components.sanity:GetPercentWithPenalty() >= 1 then
                        oldsanity = self.sanity_bonus_mult
                        self.sanity_bonus_mult = 0
                    end
                end
            end
            if oldhealth and oldsanity then
                oldhunger = self.hunger_bonus_mult
                self.hunger_bonus_mult = 0.1
            elseif oldhealth then
                oldsanity = self.sanity_bonus_mult
                self.sanity_bonus_mult = self.sanity_bonus_mult * 2
            elseif oldsanity then
                oldhealth = self.health_bonus_mult
                self.health_bonus_mult = self.health_bonus_mult * 2
            end
        end
        local result = SleepTick(self, ...)
        if oldhunger then self.hunger_bonus_mult = oldhunger end
        if oldsanity then self.sanity_bonus_mult = oldsanity end
        if oldhealth then self.health_bonus_mult = oldhealth end
        return result
    end
end)
