if GetModConfigData("sandstorm") or GetModConfigData("moonisland") then
    AddComponentPostInit("moonstormwatcher", function(self)
        local oldGetMoonStormLevel = self.GetMoonStormLevel
        self.GetMoonStormLevel = function(self, ...) return oldGetMoonStormLevel(self, ...) or 0 end
    end)

    AddComponentPostInit("sandstormwatcher", function(self)
        local oldGetSandstormLevel = self.GetSandstormLevel
        self.GetSandstormLevel = function(self, ...) return oldGetSandstormLevel(self, ...) or 0 end
    end)
end

AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return inst end
    if not inst:HasTag("cave") and not TUNING.sporecloud2hm then
        TUNING.sporecloud2hm = true
        TUNING.TOADSTOOL_SPORECLOUD_LIFETIME = TUNING.TOADSTOOL_SPORECLOUD_LIFETIME / 2
    end
end)
