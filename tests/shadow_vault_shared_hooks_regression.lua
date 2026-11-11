-- Display-only items (including nested containers) must never escape as goods.
local before_add,before_world=AddComponentPostInit,TheWorld
local hooks={}
AddComponentPostInit=function(name,fn)hooks[name]=fn end
assert(loadfile(SHARED_HOOK_SOURCE))()
TheWorld={components={}}
local checks,calls=0,0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function original()calls=calls+1;return "native"end
local item={components={inventoryitem={}}}
local inst={shadowvault_preview2hm=true}
local c={inst=inst,slots={[1]=item},GetItemSlot=function()return 1 end,
    RemoveItem=original,RemoveItemBySlot=original,GiveItem=original,
    TakeActiveItemFromAllOfSlot=original,TakeActiveItemFromCountOfSlot=original,MoveItemFromCountOfSlot=original}
hooks.container(c)
check(c:RemoveItem(item)==nil and c:RemoveItemBySlot(1)==nil and c:GiveItem(item)==false and calls==0,
    "indirect operations cannot remove or deposit preview goods")
check(c:TakeActiveItemFromAllOfSlot(1)==nil and c:TakeActiveItemFromCountOfSlot(1,2)==nil and calls==0,
    "nested preview containers cannot be looted with native container RPCs")
c.worldexchange_internal2hm=true
check(c:RemoveItemBySlot(1)=="native"and calls==1,"internal cleanup can dispose of nested preview goods")
c.worldexchange_internal2hm=nil;inst.shadowvault_preview2hm=nil
check(c:RemoveItemBySlot(1)=="native"and calls==2,"ordinary native containers retain normal removal")
local inv={inst={},UseItemFromInvTile=original,DropItemFromInvTile=original,
    ControllerUseItemOnSelfFromInvTile=original,GetActiveItem=function()end}
hooks.inventory(inv)
local nested={shadowvault_preview2hm=true,components={inventoryitem={owner={}}}}
check(inv:UseItemFromInvTile(nested)==nil and inv:DropItemFromInvTile(nested)==nil and calls==2,
    "preview items cannot be eaten, equipped or dropped through inventory actions")
check(inv:ControllerUseItemOnSelfFromInvTile(nested)==nil and calls==2,"controller actions obey the same custody rule")
check(inv:UseItemFromInvTile(item)=="native"and calls==3,"ordinary inventory actions are unchanged")
inst.components={container=c};inst.shadowvault_page2hm="page"
item.components.inventoryitem.owner=inst
TheWorld.components.shadowvault2hm={reserved={page={[1]="remote_transfer"}}}
check(inv:ControllerUseItemOnSelfFromInvTile(item)==nil and calls==3,"a native controller cannot use an item reserved by a remote player")
check(c:RemoveItem(item)==nil and calls==3,"a reserved original cannot be removed through an indirect operation")
TheWorld.components.shadowvault2hm.reserved.page=nil
check(inv:ControllerUseItemOnSelfFromInvTile(item)=="native"and calls==4,"controller use resumes when the reservation is released")
AddComponentPostInit,TheWorld=before_add,before_world
print("Shared native custody hooks: "..checks.." checks passed")
