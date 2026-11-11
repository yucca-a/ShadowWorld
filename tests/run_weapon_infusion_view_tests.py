"""Infusion state changes must never mutate item ownership or equipment."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().source=(ROOT/'content/scripts/weaponinfusionview2hm.lua').read_text(encoding='utf-8')
lua.execute('''
local n=0
local function check(ok,msg)n=n+1;assert(ok,msg)end
local view=assert(loadstring(source))()
net_bool=function()return {set=function(self,v)self.current=v end,value=function(self)return self.current end}end
local item={GUID=1,components={perishable={}},replica={}}
function item:IsValid()return true end
function item:Remove()error("UI cannot destroy item")end
function item:RemoveFromScene()error("UI cannot hide real entity")end
local usage,events=0,0
item.replica.inventoryitem={classified={},SerializeUsage=function()usage=usage+1 end}
function item:PushEvent()events=events+1 end
view.Install(item)
local function widget()
 return {SetClickable=function()end,MoveToBack=function()end,
 GetAnimState=function()return {SetBank=function()end,SetBuild=function()end,AnimateWhilePaused=function()end}end}
end
package.preload["widgets/image"]=function()return widget end
package.preload["widgets/uianim"]=function()return widget end
local tile={item=item,inst={ListenForEvent=function(self,event,fn)self.listener=fn end},
 AddChild=function(self,child)return child end,
 ShowSpoilage=function(self)self.shown=true end,HideSpoilage=function(self)self.shown=false end,
 Refresh=function(self)self.refreshed=true end,SetPercent=function(self,p)self.percent=p end}
item.components.finiteuses={GetPercent=function()return .37 end}
view.AttachTile(tile)
check(tile.shown and tile.bg and tile.spoilage and tile.percent==.37,"native meter and durability coexist")
for _,owner in ipairs({"inventory","equipped","cursor","readonly_escrow","native_page","mirror","nested_bag"})do
 item.owner=owner
 for i=1,3 do
  item.components.perishable=nil;view.Refresh(item);tile.inst.listener()
  check(not tile.shown and not tile.hasspoilage and item.owner==owner,"expiry retains custody")
  item.components.perishable={};view.Refresh(item);tile.inst.listener()
  check(tile.shown and tile.hasspoilage and tile.percent==.37 and item.owner==owner,"infusion retains custody")
 end
end
check(usage==42 and events==42,"every refresh serializes native usage and notifies local tile")
print("Weapon infusion view: "..n.." checks passed")
''')
