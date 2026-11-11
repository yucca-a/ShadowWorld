"""Check centralized UM routing and single-install dynamic food compatibility."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
load=lua.eval('function(s,n)return assert(loadstring(s,n))end')
for path in (ROOT/"content").rglob("*.lua"):load(path.read_text(encoding="utf-8-sig"),str(path))
source=(ROOT/"content/easy_other/um_patch.lua").read_text(encoding="utf-8-sig")
lua.globals().entry_source=source[:source.index('--[[修改列表:')]
lua.globals().adapter_source=(ROOT/"content/easy_other/um_food_stats.lua").read_text(encoding="utf-8-sig")
source=(ROOT/"content/food/cooking.lua").read_text(encoding="utf-8-sig")
start=source.index('AddClassPostConstruct("widgets/containerwidget"')
lua.globals().widget_source=source[start:source.index('\nlocal oldCOOKfn',start)]
lua.execute(r'''
local count=0
local function check(value,why) count=count+1; assert(value,why) end
for _,um in ipairs({false,true})do
 for _,dynamic in ipairs({false,true})do
  for _,optional in ipairs({false,true})do
   for _,hard in ipairs({false,true})do
    for _,food in ipairs({false,true})do
     for _,mode in ipairs({false,-1,-2,-3})do
      local calls=0
      local scope=setmetatable({TUNING={DSTU=um,hardmode2hm=hard},UM_CONFIG={FOOD_STATS=dynamic},
        require=function(name)
            if name=='umperformance2hm'then return {Install=function()end}end
            return {}
        end,
        GetModConfigData=function(key)return ({um_patch=optional,food_change=food,cooking_change=mode})[key]end,
        modimport=function(path)check(path=='easy_other/um_food_stats.lua','shared adapter only');calls=calls+1 end}, {__index=_G})
      setfenv(assert(loadstring(entry_source)),scope)()
      local expected=um and dynamic and (optional or (hard and food and mode==-3))
      check(calls==(expected and 1 or 0),'compatibility router respects active combination')
     end
    end
   end
  end
 end
end
-- Keep other mods' component hooks, remove only the two UM implementations,
-- and ensure repeated installation never wraps output/serialization twice.
local umfn=assert(loadstring('return function()end','@mods/workshop-3193922031/init/init_food/init_food_stats.lua'))()
local other=function()end
local hooks={stewer={other,umfn},edible={umfn,other}}
local registrations=0
local scope=setmetatable({TUNING={},ModManager={mods={{postinitfns={ComponentPostInit=hooks}}}},
    AddComponentPostInit=function()registrations=registrations+1 end,
    AddPrefabPostInit=function()registrations=registrations+1 end,
    AddPrefabPostInitAny=function()registrations=registrations+1 end}, {__index=_G})
local function install()setfenv(assert(loadstring(adapter_source)),scope)()end
install()
check(scope.TUNING.umfoodstatscompat2hm,'successful installation marked')
check(#hooks.stewer==1 and hooks.stewer[1]==other,'other stewer hook preserved')
check(#hooks.edible==1 and hooks.edible[1]==other,'other edible hook preserved')
local first=registrations;install()
check(registrations==first,'adapter is installed exactly once')
scope.TUNING={};scope.ModManager={mods={}}
install();check(not scope.TUNING.umfoodstatscompat2hm and registrations==first,'no UM hook means no adapter')
local constructor
local ui=setmetatable({AddClassPostConstruct=function(_,fn)constructor=fn end,
    resolvefilepath=function(value)return value end,CRAFTING_ICONS_ATLAS='test'}, {__index=_G})
setfenv(assert(loadstring(widget_source)),ui)()
for _,size in ipairs({4,5})do
 for level=0,4 do
  for _,chef in ipairs({false,true})do
   local widget={inv={},Open=function()return 'native_open_result'end}
   for i=1,size do
    widget.inv[i]={SetBGImage2=function(self)self.flame=true end,
      bgimage={GetSize=function()return 1,1 end},bgimage2={SetSize=function()end}}
   end
   constructor(widget)
   local box={HasTag=function()return true end,fueledlevel2hm={value=function()return level end}}
   check(widget:Open(box,{HasTag=function()return chef end})=='native_open_result','native UI return preserved')
   local count=0;for _,slot in ipairs(widget.inv)do if slot.flame then count=count+1 end end
   check(count==(chef and size or math.ceil(level*size/4)),'fuel background scales to actual slot count')
  end
 end
end
print('Five-slot UM routing and reuse: '..count..' checks passed')
''')
print('All content Lua 5.1 syntax checks passed')
