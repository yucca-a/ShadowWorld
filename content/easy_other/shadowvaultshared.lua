-- Route native container gestures at a secondary view to authoritative storage.
-- No InventoryBar, InvSlot, ItemTile or ContainerWidget is replaced.
local gestures={
    TakeActiveItemFromAllOfSlot={"quicktake",2,"cursor"},
    TakeActiveItemFromHalfOfSlot={"takehalf",2,"cursor"},
    PutAllOfActiveItemInSlot={"put",2},PutOneOfActiveItemInSlot={"placeone",2},
    AddAllOfActiveItemToSlot={"place",2},AddOneOfActiveItemToSlot={"placeone",2},
    SwapActiveItemWithSlot={"place",2},
    SwapOneOfActiveItemWithSlot={"swapone",2},
    MoveItemFromAllOfSlot={"quicktake",3},MoveItemFromHalfOfSlot={"takehalf",3},
}
local function service()return TheWorld and TheWorld.components.shadowvault2hm end
local function reserved(c,slot)
    local v=service();local page=c.inst.shadowvault_page2hm
    return v and page and v.reserved[page]and v.reserved[page][slot] and
        not v.internal and not c.worldexchange_internal2hm
end
AddComponentPostInit("container",function(c)
    for name,info in pairs(gestures)do
        local original=c[name]
        if original then c[name]=function(self,slot,...)
            local args={...};local player=args[info[2]-1]
            local mirror=self.inst.shadowvault_mirror2hm
            if self.inst.shadowvault_preview2hm then return end
            if mirror then
                if not player or not player.components.inventory then return end
                local action=info[1]
                local item
                if action=="put" or action=="place" or action=="placeone" or action=="swapone"then
                    item=player.components.inventory:GetActiveItem()
                    if not item then return end
                    if action=="put" then action=self.slots[slot]and"place"or"deposit"end
                end
                return mirror:Enqueue(player,self,action,slot,item,info[3])
            end
            local v=service();local page=self.inst.shadowvault_page2hm
            if v and page and v.reserved[page] and v.reserved[page][slot]then return end
            return original(self,slot,...)
        end end
    end
    local counttake,countmove=c.TakeActiveItemFromCountOfSlot,c.MoveItemFromCountOfSlot
    function c:TakeActiveItemFromCountOfSlot(slot,count,player)
        if self.inst.shadowvault_preview2hm then return end
        local mirror=self.inst.shadowvault_mirror2hm
        if mirror then return mirror:Enqueue(player,self,"quicktake",slot,nil,"cursor",count)end
        local v=service();local page=self.inst.shadowvault_page2hm
        if v and page and v.reserved[page] and v.reserved[page][slot]then return end
        return counttake(self,slot,count,player)
    end
    function c:MoveItemFromCountOfSlot(slot,destination,count,player)
        if self.inst.shadowvault_preview2hm then return end
        local mirror=self.inst.shadowvault_mirror2hm
        if mirror then return mirror:Enqueue(player,self,"quicktake",slot,nil,nil,count)end
        return countmove(self,slot,destination,count,player)
    end
    -- Render copies must never escape through indirect game/mod operations.
    local remove,give,removeitem=c.RemoveItemBySlot,c.GiveItem,c.RemoveItem
    function c:RemoveItem(...)
        if (self.inst.shadowvault_mirror2hm or self.inst.shadowvault_preview2hm)and not self.worldexchange_internal2hm then return end
        local item=select(1,...)
        if item and reserved(self,self:GetItemSlot(item))then return end
        return removeitem(self,...)
    end
    function c:RemoveItemBySlot(...)
        if (self.inst.shadowvault_mirror2hm or self.inst.shadowvault_preview2hm)and not self.worldexchange_internal2hm then return end
        if reserved(self,select(1,...))then return end
        return remove(self,...)
    end
    function c:GiveItem(...)
        if (self.inst.shadowvault_mirror2hm or self.inst.shadowvault_preview2hm)and not self.worldexchange_internal2hm then return false end
        return give(self,...)
    end
end)
AddComponentPostInit("inventory",function(inventory)
    for name,half in pairs({MoveItemFromAllOfSlot=false,MoveItemFromHalfOfSlot=true})do
        local original=inventory[name]
        if original then inventory[name]=function(self,slot,destination,...)
            local mirror=destination and destination.shadowvault_mirror2hm
            if mirror then
                local item=self:GetItemInSlot(slot)
                if item then return mirror:QuickStore(self.inst,item,half,nil,destination)end
                return
            end
            return original(self,slot,destination,...)
        end end
    end
    local movecount=inventory.MoveItemFromCountOfSlot
    function inventory:MoveItemFromCountOfSlot(slot,destination,count,...)
        local mirror=destination and destination.shadowvault_mirror2hm
        if mirror then
            local item=self:GetItemInSlot(slot)
            if item then return mirror:QuickStore(self.inst,item,false,count,destination)end
            return
        end
        return movecount(self,slot,destination,count,...)
    end
    for name,action in pairs({UseItemFromInvTile="use",DropItemFromInvTile="drop"})do
        local original=inventory[name]
        if original then inventory[name]=function(self,item,...)
            local owner=item and item.components.inventoryitem and item.components.inventoryitem.owner
            local mirror=owner and owner.shadowvault_mirror2hm
            if item and item.shadowvault_preview2hm and not mirror then return end
            if mirror then
                local c=owner.components.container
                local active=action=="use" and self:GetActiveItem()or nil
                local which=action=="drop" and select(1,...)==true and "dropone"or action
                return mirror:Enqueue(self.inst,c,which,c:GetItemSlot(item),active)
            end
            if owner and owner.components.container and reserved(owner.components.container,owner.components.container:GetItemSlot(item))then return end
            return original(self,item,...)
        end end
    end
    for _,name in ipairs({"ControllerUseItemOnSelfFromInvTile","ControllerUseItemOnItemFromInvTile",
        "ControllerUseItemOnSceneFromInvTile"})do
        local original=inventory[name]
        if original then inventory[name]=function(self,item,...)
            local owner=item and item.components.inventoryitem and item.components.inventoryitem.owner
            local mirror=owner and owner.shadowvault_mirror2hm
            if item and item.shadowvault_preview2hm and not mirror then return end
            if mirror then
                local c=owner.components.container
                return mirror:Enqueue(self.inst,c,"use",c:GetItemSlot(item),self:GetActiveItem())
            end
            if owner and owner.components.container and reserved(owner.components.container,owner.components.container:GetItemSlot(item))then return end
            return original(self,item,...)
        end end
    end
end)
