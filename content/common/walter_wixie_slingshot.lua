-- Equipment permission has its own switch. It must not depend on the easy
-- mode, Walter master switch, or the separate attack-animation option.
if not (TUNING.DSTU and TUNING.WIXIE_HEALTH and GetModConfigData("Walter Use Wixie Slingshot")) then return end

AddPrefabPostInit("walter", function(inst)
    -- UM also changes the original slingshot to require troublemaker.
    -- These tags are needed on both the server and the predicting client.
    inst:AddTag("pebblemaker")
    inst:AddTag("slingshot_sharpshooter")
    inst:AddTag("troublemaker")
end)

-- UM routes troublemakers to Wixie's wardrobe on a fresh spawn. Walter should
-- retain his own spawn path even when he is allowed to use Wixie's weapons.
AddComponentPostInit("playerspawner", function(self)
    local SpawnAtLocation = self.SpawnAtLocation
    self.SpawnAtLocation = function(self, inst, player, ...)
        local restore = player ~= nil and player:IsValid() and player.prefab == "walter" and player:HasTag("troublemaker")
        if restore then player:RemoveTag("troublemaker") end
        local result = SpawnAtLocation(self, inst, player, ...)
        if restore then player:AddTag("troublemaker") end
        return result
    end
end)
