-- Each open space is a real container on the player's shard.
local Config=require("shadowvaultconfig2hm")
local Proxy=require("shadowvaultproxy2hm")
local containers=require("containers")
containers.params.shadowvaultpage2hm=containers.params.shadow_container
containers.params.shadowvaulttransfer2hm={widget={numslots=1},type="chest"}
containers.params.shadowvaultpair2hm={widget={numslots=2},type="chest"}
if containers.params.magician_private2hm then
    containers.params.shadowvaulttacklepage2hm=containers.params.tacklestation2hm or
        {widget=containers.params.magician_private2hm.widget,type="chest"}
end
TUNING.SHADOWVAULT_ENABLED2HM=Config.Enabled(GetModConfigData("World Exchange"),
    GetModConfigData("Container Sort") or GetModConfigData("Items collect"))
PrefabFiles[#PrefabFiles+1]="shadowvault2hm"
AddPrefabPostInit("world",function(inst)
    if inst.ismastersim then
        inst:AddComponent("worldexchange2hm")
        inst:AddComponent("shadowvault2hm")
        require("shadowvaultnative2hm").ProtectUniqueCleanup(inst)
        local load=inst.LoadPostPass
        inst.LoadPostPass=function(world,newents,data,...)
            -- Constructors of saved extra pages also register a singleton.
            -- Restore canonical GUIDs before any world component uses them
            -- (e.g. Legion's cloud pine upgrade/contents migration).
            world.components.shadowvault2hm:RestoreNativeBases(newents,data and data.shadowvault2hm)
            world.components.exchangevariants2hm:Restore(newents,data)
            return load(world,newents,data,...)
        end
    end
end)
AddShardModRPCHandler("MOD_HARDMODE","shadowvault_v1",function(peer,...)
    local variants=TheWorld and TheWorld.components.exchangevariants2hm
    if not TUNING.SHADOWVAULT_ENABLED2HM and not (variants and variants.migrating) then return end
    local v=TheWorld and TheWorld.components.shadowvault2hm
    if v then v:Initialize();if v.transport then v.transport:Packet(tostring(peer),...) end end
end)
require("worldexchangerpc2hm").Install(GLOBAL,GetShardModRPC("MOD_HARDMODE","shadowvault_v1"),
    GetShardModRPCHandler("MOD_HARDMODE","shadowvault_v1"))

-- Old in-flight deliveries retain their server records. New item actions use
-- the game's normal container RPCs and the original Inventory/ItemTile widgets.
AddComponentPostInit("container",function(container)
    local open=container.Open
    function container:Open(doer)
        if not Proxy.Ready(self.inst) then return false end
        return open(self,doer)
    end
    container.inst:ListenForEvent("onopen",function(_,data)
        local player=data and data.doer
        local v=TheWorld.components.shadowvault2hm
        if v and v.native and player and container.inst==player.magicianprivatecontainer2hm then
            for anchor in pairs(player.components.inventory.opencontainerproxies) do
                if anchor.prefab=="tophat_container" then v.native:Close(player,true,anchor);break end
            end
        end
    end)
end)
AddComponentPostInit("container_proxy",function(self)
    if not self.ismastersim then return end
    local open,close,setmaster,update=self.Open,self.Close,self.SetMaster,self.OnUpdate
    function self:SetMaster(entity)
        local family=Proxy.Family(entity,TheWorld.components.shadowvault2hm)
        if family or entity~=nil then self.shadowvault_family2hm=family end
        return setmaster(self,entity)
    end
    function self:Open(doer)
        if not Proxy.Ensure(self,TheWorld.components.shadowvault2hm) then return false end
        if self.shadowvault_opening2hm then return open(self,doer) end
        local v=TheWorld.components.shadowvault2hm
        local master=self.master
        if TUNING.SHADOWVAULT_ENABLED2HM and v and doer and doer.userid and master and
            master:HasTag("pocketdimension_container") then
            v:Initialize()
            if v.error and v.journal then v.journal:TryRecover() end
            if v.error then
                v:Say(doer.userid,"空间记录需要恢复，请保留存档并检查日志。",
                    "Space records need recovery; keep the save and check the log.")
                return false
            end
            if v.native then
                if self:IsOpenedBy(doer) or not self:CanBeOpened() then return false end
                local family
                if master.shadowvault_page2hm then family=Config.Family(master.shadowvault_page2hm) end
                for name,base in pairs(v.native_bases or {}) do
                    if base==master or not family and base.prefab==master.prefab then family=name;break end
                end
                if not family then return open(self,doer) end
                local page=self.opencount>0 and master.shadowvault_page2hm or Config.Page(v.id,family)
                if v.native.localonly and v.native.localonly[page] then return open(self,doer) end
                return v.native:Open(doer,self.inst,page)
            end
        end
        return open(self,doer)
    end
    function self:Close(doer)
        if self.shadowvault_opening2hm then return close(self,doer) end
        local v=TheWorld.components.shadowvault2hm
        if v and v.native then
            if doer then
                local sharedpending=v.native.shared and v.native.shared.pending[doer.userid]
                if sharedpending and sharedpending.anchor==self.inst then v.native.shared.pending[doer.userid]=nil end
                local pending=v.native.pending[doer.userid]
                if pending and pending.anchor==self.inst then v.native.pending[doer.userid]=nil end
                local view=v.views[doer.userid]
                if view and view.native and view.anchor==self.inst then v.views[doer.userid]=nil end
            else
                for uid,pending in pairs(v.native.pending) do
                    if pending.anchor==self.inst then v.native.pending[uid]=nil end
                end
                for uid,view in pairs(v.views) do
                    if view.native and view.anchor==self.inst then v.views[uid]=nil end
                end
            end
        end
        local result
        if Proxy.Ready(self.master) then result=close(self,doer)
        else Proxy.DetachStale(self) end
        if v and v.native and v.native.shared then v.native.shared:Closed(doer,self.inst)end
        return result
    end
    function self:OnUpdate(dt)
        if Proxy.Ensure(self,TheWorld.components.shadowvault2hm) then return update(self,dt) end
    end
end)
local update=GLOBAL.Shard_UpdateWorldState
GLOBAL.Shard_UpdateWorldState=function(id,state,...)
    local result=update(id,state,...)
    local v=TheWorld and TheWorld.components.shadowvault2hm
    if v and v.transport then
        if state==REMOTESHARDSTATE.READY then v.transport.nexthello=0
        else v.transport:Disconnected(tostring(id)) end
    end
    return result
end
modimport("easy_other/shadowvaultplayer.lua")
modimport("easy_other/shadowvaultshared.lua")
