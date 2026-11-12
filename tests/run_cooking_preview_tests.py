"""Actual classic/refresh Craft Pot prediction methods with cooker rules."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path = str(ROOT/'content/scripts/?.lua').replace('\\','/')+';'+lua.globals().package.path
load=lua.eval('function(s,n)return assert(loadstring(s,n))end')
base=ROOT/'work/smartpot-workshop-audit/steamapps/workshop/content/322330'
classic=(base/'727774324/scripts/widgets/foodcrafting.lua').read_text(encoding='utf-8-sig')
for marker in ['function FoodCrafting:_UpdateFoodStats(', 'function FoodCrafting:_GetIngredientValues(', 'function FoodCrafting:_GetEntityIngredients(']:
 a=classic.index(marker)
 lua.globals()['native_'+('stats' if '_UpdateFoodStats' in marker else 'entities' if '_GetEntityIngredients' in marker else 'values')]=classic[a:classic.index('\nend',a)+4]
source=(ROOT/'content/common/food_util.lua').read_text(encoding='utf-8-sig')
lua.globals().rules_source=source[source.index('function TUNING.util2hm.InstallCookingRules2hm(cooking, api)'):]
lua.globals().refresh_source=(base/'3822775840/scripts/craftpot/cp_recipes.lua').read_text(encoding='utf-8-sig')
lua.execute(r'''
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
function deepcopy(t)local c={};for k,v in pairs(t)do c[k]=type(v)=='table'and deepcopy(v)or v end;return c end
local recipes={meatballs={name='meatballs',priority=-1,test=function(_,_,t)return(t.meat or 0)>0 end},
 bonestew={name='bonestew',priority=0,test=function(_,_,t)return(t.meat or 0)>=3 end},
 beefalofeed={name='beefalofeed',priority=-5,test=function()return false end}}
local ingredients={meat={tags={meat=1}},berries={tags={fruit=.5}},carrot={tags={veggie=1}}}
local cooking={recipes={cookpot=recipes,portablecookpot={}},ingredients=ingredients}
cooking.CalculateRecipe=function(cooker,names)
 local tags={};for _,name in ipairs(names)do for key,v in pairs(ingredients[name].tags)do tags[key]=(tags[key]or 0)+v end end
 local best;for _,r in pairs(recipes)do if r.test(cooker,{},tags)and(not best or r.priority>best.priority)then best=r end end
 return best.name
end
package.preload.cooking=function()return cooking end
local ctors={}
local api={isModuleAvailable=function()return false end,AddClassPostConstruct=function(path,fn)ctors[path]=fn end}
TUNING={util2hm={}};assert(loadstring(rules_source))();TUNING.util2hm.InstallCookingRules2hm(cooking,api)
for _,v in pairs(ingredients)do for tag,value in pairs(v.tags)do v.tags[tag]=value-.25 end end
local reduced=ingredients.meat.tags
check(cooking.CalculateRecipe('cookpot',{'meat','meat','meat','berries','carrot'})=='meatballs','five-slot pot uses reduced tags')
check(cooking.CalculateRecipe('dragonflyfurnace',{'meat','meat','meat','berries'})=='bonestew','four-slot furnace uses raw tags')
check(ingredients.meat.tags==reduced,'tag identity restored')
local ok=pcall(cooking.WithCookerRules2hm,'dragonflyfurnace',function()error('injected')end)
check(not ok and ingredients.meat.tags==reduced,'errors restore global tag view')
FoodCrafting={};assert(loadstring(native_stats))();assert(loadstring(native_values))();assert(loadstring(native_entities))()
for _,furnace in ipairs({false,true})do
 local slots=furnace and 4 or 5
 local inst={prefab=furnace and 'dragonflyfurnace'or'cookpot',replica={container={GetNumSlots=function()return slots end}}}
 local view={_cooker={inst=inst},_cookerName='cookpot',_ingredients=ingredients,_aliases={},allfoods={},
 _UpdateFoodStats=FoodCrafting._UpdateFoodStats,_GetIngredientValues=FoodCrafting._GetIngredientValues,
 knownfoods={UpdateRecipe=function(_,r,data)r.reqsmatch=recipes[r.name].test('cookpot',data.names,data.tags);r.reqsmismatch=not r.reqsmatch end}}
 for _,r in pairs(recipes)do view.allfoods[#view.allfoods+1]={recipe={name=r.name,priority=r.priority,supportedCookers={cookpot=true},minlist={}}}end
 local items={{name='meat',amt=1},{name='meat',amt=1},{name='meat',amt=1},{name='berries',amt=1}}
 if not furnace then items[5]={name='carrot',amt=1}end
 view.SortFoods=function(self)self:_UpdateFoodStats(self:_GetIngredientValues(items),#items,{})end
 ctors['screens/playerhud']({controls={foodcrafting=view}});view:SortFoods()
 check(view.cookingrules2hm,'actual HUD interface patched without classic module path')
 local patched=view.SortFoods
 ctors['screens/playerhud']({controls={foodcrafting=view}})
 check(view.SortFoods==patched,'repeated HUD installation is idempotent')
 for _,food in ipairs(view.allfoods)do check(food.recipe.readytocook==(food.recipe.name==(furnace and'bonestew'or'meatballs')),'classic full prediction matches cooker')end
 if not furnace then
  items[5]=nil;view:SortFoods()
  for _,food in ipairs(view.allfoods)do check(not food.recipe.readytocook,'four of five must not be ready')end
 end
end
-- Real container events must refresh a late-created preview and release callbacks on close.
local controls={}
local player={HUD={controls=controls}}
local callbacks,tasks={},{}
local host={
 ListenForEvent=function(_,event,fn,source)callbacks[event]={fn=fn,source=source}end,
 RemoveEventCallback=function(_,event,fn,source)
  check(callbacks[event].fn==fn and callbacks[event].source==source,'remove own container listener')
  callbacks[event]=nil
 end,
 DoStaticTaskInTime=function(_,_,fn)
  local task={fn=fn,Cancel=function(t)t.cancelled=true end};tasks[#tasks+1]=task;return task
 end}
local widget={inst=host,Open=function(self)self.isopen=true end,Close=function(self)self.isopen=false end}
ctors['widgets/containerwidget'](widget)
local inst={prefab='cookpot',replica={container={GetNumSlots=function()return 5 end}}}
inst.replica.container.inst=inst
local calls=0
local preview={allfoods={},knownfoods={},_UpdateFoodStats=function()end,
 SortFoods=function()calls=calls+1 end,
 Open=function(self,c)self._cooker=c end,Close=function(self)self._cooker=nil end}
controls.foodcrafting=preview
widget:Open(inst,player)
check(preview.cookingrules2hm and preview._cooker==inst.replica.container,'late-created five-slot preview opens')
callbacks.itemget.fn();callbacks.itemlose.fn();callbacks.refresh.fn()
check(#tasks==1,'network event burst schedules one refresh')
tasks[1].fn()
check(calls==1,'queued update refreshes preview')
callbacks.itemget.fn();widget:Close()
check(tasks[2].cancelled and not preview._cooker and not next(callbacks),'close cancels update and releases preview')
tasks[2].fn()
check(calls==1,'stale update after close cannot refresh preview')
-- Moon cookers have independent ingredient rows and permanent output slots.
cooking.recipes.portablecookpot=recipes
local slots={}
local function item(name,amount)return {prefab=name,components={stackable={stacksize=amount or 1}}}end
for i,name in ipairs({'meat','meat','meat','berries'})do slots[i]=item(name,99)end
slots[21]=item('carrot',99);slots[5]=item('meat',999)
for i=16,19 do slots[i]=item('meat',99)end;slots[24]=item('meat',99)
local moon={prefab='simmeredmoonlight_inf',fiveslotrows2hm=4,replica={container={
 GetNumSlots=function()return 24 end,GetItemInSlot=function(_,slot)return slots[slot]end}}}
local view={allfoods={},knownfoods={UpdateRecipe=function(_,r,data)
 r.reqsmatch=recipes[r.name].test('portablecookpot',data.names,data.tags);r.reqsmismatch=not r.reqsmatch
end},_ingredients=ingredients,_aliases={},_UpdateFoodStats=FoodCrafting._UpdateFoodStats,
 _GetEntityIngredients=FoodCrafting._GetEntityIngredients,_GetIngredientValues=FoodCrafting._GetIngredientValues,
 SortFoods=function(self)
  local list=self:_GetEntityIngredients(self._cooker)
  self:_UpdateFoodStats(self:_GetIngredientValues(list),#list,{})
 end,
 Open=function(self,c)self._cooker=c;self._cookerName=c.prefab;self:SortFoods()end,
 Close=function(self)self._cooker=nil end}
for _,r in pairs(recipes)do view.allfoods[#view.allfoods+1]={recipe={name=r.name,priority=r.priority,supportedCookers={portablecookpot=true},minlist={}}}end
controls.foodcrafting=view;widget.inv={}
local focused=0
local gain=function()focused=focused+1 end
for i=1,24 do widget.inv[i]={OnGainFocus=gain}end
widget:Open(moon,player)
local function ready(name)
 for _,food in ipairs(view.allfoods)do if food.recipe.name==name then return food.recipe.readytocook end end
end
check(view._cooker:GetNumSlots()==5,'moon preview counts five input slots instead of all 24')
check(ready('meatballs')and not ready('bonestew'),'moon preview excludes output, other rows and stack quantities')
view:Close({prefab='cookpot'})
check(view._cooker~=nil,'delayed close from a different cooker cannot hide the moon preview')
widget.inv[16]:OnGainFocus();tasks[#tasks].fn()
check(focused==1 and ready('bonestew'),'focusing another row switches preview and preserves native focus')
slots[24]=nil;callbacks.itemlose.fn(nil,{slot=24});tasks[#tasks].fn()
check(not ready('bonestew')and not ready('meatballs'),'four of five in selected row must not use other full rows')
slots[24]=item('meat');callbacks.itemget.fn(nil,{slot=24});tasks[#tasks].fn()
check(ready('bonestew'),'refilling selected fifth input restores prediction')
widget:Close()
check(widget.inv[16].OnGainFocus==gain and not view._cooker,'moon close restores slot focus and releases preview')
local refresh=assert(loadstring(refresh_source))();refresh.Init()
local five={{prefab='meat'},{prefab='meat'},{prefab='meat'},{prefab='berries'},{prefab='carrot'}}
local result=refresh.Refresh('cookpot',five,5)
check(#result==1 and result[1].name=='meatballs'and result[1].ready,'refresh actual five-slot prediction')
five[5]=nil
result=cooking.WithCookerRules2hm('dragonflyfurnace',refresh.Refresh,'cookpot',five,4)
check(#result==1 and result[1].name=='bonestew'and result[1].ready,'refresh actual furnace prediction')
check(ingredients.meat.tags==reduced,'preview does not leak furnace tags')
package.loaded['craftpot/cp_recipes']=refresh
local nativeupdate=function()error('native update must not read all moon slots')end
local panel={Update=nativeupdate,RefreshSlots=function()end,
 Open=function(self,inst,w)self.container=inst;self.containerwidget=w;self.isopen=true;self:Update()end,
 CloseFor=function(self,w)if self.containerwidget==w then self.isopen=false;self.container=nil end end}
controls.foodcrafting=nil;controls.craftpot=panel
widget:Open(moon,player)
check(panel.visible[1].name=='meatballs'and panel.visible[1].ready,'refresh panel opens with selected five-input row')
callbacks.refresh.fn(nil,{slot=24});tasks[#tasks].fn()
check(panel.visible[1].name=='bonestew'and panel.visible[1].ready,'refresh panel switches to another row')
widget:Close()
check(panel.Update==nativeupdate and not panel.isopen,'refresh close restores native update method')
print('Cooker rules and actual Craft Pot methods: '..n..' checks passed')
''')
