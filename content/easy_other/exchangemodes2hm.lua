TUNING.EXCHANGE_MODE2HM=require("exchangemode2hm").Normalize(GetModConfigData("World Exchange"))
PrefabFiles[#PrefabFiles+1]="shadowbank_container2hm"
PrefabFiles[#PrefabFiles+1]="shadowbank_remote2hm"
PrefabFiles[#PrefabFiles+1]="shadowbank_tackle2hm"
PrefabFiles[#PrefabFiles+1]="shadowbank_tackleremote2hm"
AddPrefabPostInit("world",function(inst)
    if inst.ismastersim then inst:AddComponent("exchangevariants2hm") end
end)
modimport("easy_other/exchangeclassic2hm.lua")
modimport("easy_other/shadowbank2hm.lua")

-- Open migrated inventories only after the native world image has been saved.
local serialize=GLOBAL.SerializeWorldSession
GLOBAL.SerializeWorldSession=function(data,session,callback,...)
    local variants=TheWorld and TheWorld.components.exchangevariants2hm
    local migration=variants and variants.migrating and variants.migration
    local committing=migration and migration.phase=="committed"
    return serialize(data,session,function(...)
        if committing then migration:Saved() end
        if callback then callback(...)end
    end,...)
end
AddComponentPostInit("container",function(c)
    local open=c.Open
    c.Open=function(self,player,...)
        local variants=TheWorld and TheWorld.components.exchangevariants2hm
        if variants and not variants.ready and self.inst:HasTag("pocketdimension_container") and
            not (type(self.inst.userid)=="string" and self.inst.userid~="") then
            if player and player.components.talker then
                player.components.talker:Say(TUNING.isCh2hm and "正在恢复并迁移旧空间，请稍候。" or "Restoring and migrating old storage. Please wait.")
            end
            return false
        end
        return open(self,player,...)
    end
end)
