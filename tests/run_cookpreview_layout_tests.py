"""Screen-space separation invariants for cooker/recipe panels."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().layout_source = (ROOT/'content/scripts/cookpreviewlayout2hm.lua').read_text(encoding='utf-8')
lua.execute(r'''
local m=assert(loadstring(layout_source))()
local n=0
local function apart(a,b)
 return a.r<=b.l+.001 or b.r<=a.l+.001 or a.t<=b.b+.001 or b.t<=a.b+.001
end
for _,screen in ipairs({{800,600},{1280,720},{1920,1080},{3440,1440}})do
 local sw,sh=unpack(screen)
 for _,x in ipairs({0,.15,.5,.85,1})do
  for _,y in ipairs({.1,.5,.9})do
   for _,size in ipairs({{280,180},{460,360},{600,500}})do
    local block={l=sw*x-size[1]/2,r=sw*x+size[1]/2,b=sh*y-size[2]/2,t=sh*y+size[2]/2}
    for _,panel in ipairs({{50,420},{360,280}})do
     local p=m.Place(block,panel[1],panel[2],sw,sh,'right')
     n=n+1;assert(p and apart(p,block),'overlap')
     assert(p.l>=12-.001 and p.b>=12-.001 and p.r<=sw-12+.001 and p.t<=sh-12+.001,'outside viewport')
     assert(p.scale>0 and p.scale<=1,'invalid scale')
    end
   end
  end
 end
end
local node={GetWorldPosition=function()return{x=500,y=400}end,
 GetScale=function()return{x=-2,y=3}end,GetSize=function()return 80,40 end}
local r=m.Rect(node)
assert(r.l==420 and r.r==580 and r.b==340 and r.t==460,'negative and nonuniform scale')
-- Lifecycle uses the supported recursive GetScale API, never the engine's
-- unimplemented UITransform:GetWorldScale stub.
local function node(parent,x,y,w,h)
 local o={parent=parent,pos={x=x,y=y,z=0},scale={1,1,1},shown=true}
 function o:GetPosition()return self.pos end
 function o:SetPosition(x,y,z)self.pos=type(x)=='table' and {x=x.x,y=x.y,z=x.z}or{x=x,y=y,z=z or 0}end
 function o:GetLooseScale()return unpack(self.scale)end
 function o:SetScale(x,y,z)self.scale={x,y,z}end
 function o:GetScale()local s=self.parent and self.parent:GetScale()or{x=1,y=1,z=1};return{x=s.x*self.scale[1],y=s.y*self.scale[2],z=s.z*self.scale[3]}end
 function o:GetWorldPosition()local p=self.parent and self.parent:GetWorldPosition()or{x=0,y=0};local s=self.parent and self.parent:GetScale()or{x=1,y=1};return{x=p.x+self.pos.x*s.x,y=p.y+self.pos.y*s.y}end
 function o:GetSize()return w,h end
 function o:IsVisible()return self.shown end
 function o:Show()self.shown=true end
 return o
end
TheSim={GetScreenSize=function()return 1280,720 end}
local root=node(nil,0,0)
local cooker=node(root,640,360);cooker.isopen=true;cooker.bganim=node(cooker,0,0,460,260)
local cancelled=false
cooker.inst={DoStaticPeriodicTask=function(_,_,fn)return{Cancel=function()cancelled=true end}end}
local preview=node(root,280,0);preview:SetScale(.5,.5,.5);preview.bg=node(preview,0,0,80,600)
preview.popup=node(preview,-24,-8);preview.popup:SetScale(1.6,1.6,1.6);preview.popup.bg=node(preview.popup,210,16,400,300)
local badge=node(preview.popup,210,190,40,40)
preview.popup.children={[preview.popup.bg]=true,[badge]=true}
local show=preview.popup.Show
local layout=m.Attach(cooker,preview)
preview.popup:Show()
assert(apart(layout.last.bar,layout.last.container) and apart(layout.last.popup,layout.last.container) and apart(layout.last.popup,layout.last.bar),'attached popup overlaps')
assert(layout.last.popup.t>m.Rect(preview.popup.bg).t+20,'stat icons included outside background')
cooker:SetPosition(1150,500);cooker:SetScale(1.3,1.3,1.3);layout:Update()
assert(apart(layout.last.bar,layout.last.container) and apart(layout.last.popup,layout.last.container) and apart(layout.last.popup,layout.last.bar),'dragged popup overlaps')
layout:Detach()
assert(cancelled and not preview.cookpreviewlayout2hm and preview:GetPosition().x==280 and preview:GetLooseScale()==.5,'detach restores panel and cancels task')
assert(preview.popup.Show==show and preview.popup:GetPosition().x==-24 and preview.popup:GetLooseScale()==1.6,'detach restores popup')
local nextlayout=m.Attach(cooker,preview)
local newshow=preview.popup.Show
local newpos=preview:GetPosition()
layout:Detach()
assert(preview.popup.Show==newshow and preview:GetPosition().x==newpos.x and preview.cookpreviewlayout2hm==nextlayout,'late old close preserves new owner')
nextlayout:Detach()
print('Cooker layout separation: '..n..' viewport cases and scaled bounds passed')
''')

