local sessions={}
local function qty(item) return item.components.stackable and item.components.stackable:StackSize() or 1 end
local function giftcheck(gift)
    local items=gift and gift.prefab=="gift" and gift.components.unwrappable.itemdata
    assert(items and items[1].prefab=="berries" and items[1].data.stackable.stack==3 and items[2].prefab=="rocks","gift contents")
end
AddClientModRPCHandler("NexusPlayAudit","state",function(raw,container)
    local state=require("json").decode(raw)
    ThePlayer._nexus_state=state
    ThePlayer._nexus_container=container
end)
AddModRPCHandler("NexusPlayAudit","query",function(p)
    local v=TheWorld.components.shadowvault2hm
    local view=v.views[p.userid]
    local c=view and view.native and view.anchor.components.container_proxy:GetMaster()
    SendModRPCToClient(GetClientModRPC("NexusPlayAudit","state"),p.userid,
        require("json").encode({page=view and view.page,error=v.error or v.journal.error,native=v.native~=nil,
            item12=c and c.components.container.slots[12] and c.components.container.slots[12].prefab,
            held=p.components.inventory:GetActiveItem() and p.components.inventory:GetActiveItem().prefab,
            revision=v.journal.store.state.revision}),c)
end)
AddModRPCHandler("NexusPlayAudit","step",function(p,action,step)
    local v=TheWorld.components.shadowvault2hm
    local rec=sessions[p.userid]
    print("[NEXUS PLAY] STEP",step,action)
    if action=="start" then
        assert(v.native and v.journal.ready and not v.error,"native vault ready")
        rec={};sessions[p.userid]=rec
        for _,prefab in ipairs({"magician_chest","tacklestation","chester"}) do
            local e=assert(SpawnPrefab(prefab))
            e.Transform:SetPosition(p.Transform:GetWorldPosition())
            rec[prefab]=e
        end
        rec.chester:StopBrain()
        rec.magician_chest.components.container_proxy:SetMaster(v.base)
        rec.tacklestation.components.container_proxy:SetMaster(v.tackle)
        local light=SpawnPrefab("minerhat");p.components.inventory:Equip(light)
        p.components.playervision:ForceNightVision(true)
        p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
    elseif action=="shadow" or action=="tackle" then
        local anchor=rec[action=="shadow" and "magician_chest" or "tacklestation"]
        anchor.Transform:SetPosition(p.Transform:GetWorldPosition())
        assert(anchor.components.container_proxy:Open(p),"native proxy request")
    elseif action=="close" then
        local view=v.views[p.userid]
        if view then view.anchor.components.container_proxy:Close(p) end
    elseif action=="chester" then
        rec.chester.Transform:SetPosition(p.Transform:GetWorldPosition())
        rec.chester.components.container:Open(p)
        assert(rec.chester.components.container:IsOpenedBy(p),"Chester opens")
        assert(not rec.magician_chest.components.container_proxy:IsOpenedBy(p),"native mutual exclusion")
    elseif action=="gift" then
        assert(not p.components.inventory:GetActiveItem())
        local gift=SpawnPrefab("gift");local berries=SpawnPrefab("berries")
        berries.components.stackable:SetStackSize(3)
        gift.components.unwrappable:WrapItems({berries,"rocks"},p);berries:Remove()
        giftcheck(gift);p.components.inventory:GiveActiveItem(gift)
    elseif action=="verify" then
        local gift=p.components.inventory:GetActiveItem();giftcheck(gift);gift:Remove()
    elseif action=="gold" then
        local item=SpawnPrefab("goldnugget");item.components.stackable:SetStackSize(18)
        local inv=p.components.inventory
        for i=1,inv.maxslots do if not inv:GetItemInSlot(i) then assert(inv:GiveItem(item,i));break end end
    elseif action=="swap" then
        assert(not p.components.inventory:GetActiveItem())
        local axe=SpawnPrefab("axe");axe.components.finiteuses:SetUses(31)
        p.components.inventory:GiveActiveItem(axe)
    elseif action=="seeds" then
        local seeds=SpawnPrefab("seeds");seeds.components.stackable:SetStackSize(6)
        p.components.inventory:GiveActiveItem(seeds)
    elseif action=="clear_seeds" then
        local item=p.components.inventory:GetActiveItem();assert(item.prefab=="seeds" and qty(item)==6);item:Remove()
    elseif action=="hat" then
        if not p.components.magician then p:AddComponent("magician") end
        rec.hat=SpawnPrefab("tophat");rec.hat:ConvertToMagician();rec.hat:AddTag("magicianupgraded2hm")
        assert(p.components.magician:StartUsingTool(rec.hat))
    elseif action=="leave_private" then
        local c=assert(p.magicianprivatecontainer2hm).components.container
        assert(c:IsOpenedBy(p) and not v.views[p.userid],"private native switch")
        c:Close(p);p.components.magician:StopUsing()
    elseif action=="finish" then
        assert(not v.error and not v.journal.error,"native state healthy")
        local inv=p.components.inventory;local gold,axe
        for _,item in pairs(inv.itemslots) do
            if item.prefab=="goldnugget" and qty(item)==18 then gold=item
            elseif item.prefab=="axe" and item.components.finiteuses:GetUses()==31 then axe=item end
        end
        assert(gold and axe,"exact items and durability")
        gold:Remove();axe:Remove()
        local hat=inv:GetEquippedItem(EQUIPSLOTS.HEAD);if hat and hat.prefab=="minerhat" then hat:Remove() end
        print("[NEXUS PLAY] SERVER PASS "..step)
        if step<__ROUNDS__ then
            p._nexus_step=step+1
            TheWorld:PushEvent("ms_playerdespawnandmigrate",{player=p,worldid=TheShard:IsMaster() and "2" or "1",x=0,y=0,z=0})
        end
    end
end)
AddPlayerPostInit(function(p)
    if not TheWorld.ismastersim then return end
    local save,load=p.OnSave,p.OnLoad
    p.OnSave=function(inst,data,...)local refs=save and save(inst,data,...);data.nexus_play_step=inst._nexus_step;return refs end
    p.OnLoad=function(inst,data,...)if load then load(inst,data,...)end;inst._nexus_step=data and data.nexus_play_step end
end)
AddClientModRPCHandler("NexusPlayAudit","ready",function(step)ThePlayer._nexus_play_step=step end)
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    TheWorld:ListenForEvent("ms_playerjoined",function(_,p)
        p:DoStaticTaskInTime(3,function()
            assert(p.components.playercontroller:IsEnabled() and not p._despawning)
            SendModRPCToClient(GetClientModRPC("NexusPlayAudit","ready"),p.userid,p._nexus_step or 1)
        end)
    end)
end)
