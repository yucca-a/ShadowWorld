-- Shadow Nexus receipts travel inside native saves. These observers never gate a
-- migration, an exit, a world save, or the player's controller.
local Courier=require("shadowvaultcourier2hm")
local function vault()
    local v=TheWorld and TheWorld.ismastersim and TheWorld.components.shadowvault2hm
    return v and not v.retired and v or nil
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    local save,load,despawn=inst.OnSave,inst.OnLoad,inst.OnDespawn
    inst.OnSave=function(player,data,...)
        local refs=save and save(player,data,...)
        data.shadowvault_receipts2hm=deepcopy(player.shadowvault_receipts2hm)
        return refs
    end
    inst.OnLoad=function(player,data,...)
        if load then load(player,data,...) end
        player.shadowvault_receipts2hm=data and data.shadowvault_receipts2hm or {}
        player._shadowvault_reconcile=true
        local v=vault()
        if v then Courier.Here(v,player.userid) end
    end
    inst.OnDespawn=function(player,migration,...)
        local v=vault()
        if v and migration and migration.worldid then
            Courier.Departing(v,player.userid,migration.worldid)
            if v.journal then v.journal:Departing(player.userid);v.journal:Flush() end
        end
        if despawn then return despawn(player,migration,...) end
    end
end)
