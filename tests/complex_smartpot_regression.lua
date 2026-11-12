local n=0
local function check(ok, label) n=n+1;assert(ok,label) end
local function copy(t)local c={};for k,v in pairs(t)do c[k]=type(v)=='table' and copy(v)or v end;return c end
package.preload['config/config_manager']=function()return {GetCacheMax=function()return 100 end}end
package.preload['data/combo_matcher']=function()return {}end
package.preload['debug/logger']=function()return {}end
local cooking={ingredients={meat={tags={meat=.75}},berries={tags={fruit=.25}}},recipes={}}
package.preload.cooking=function()return cooking end
local raw={meat={tags={meat=1}},berries={tags={fruit=.5}}}
function cooking.WithCookerRules2hm(name, fn, ...)
    local old=cooking.ingredients
    if name=='dragonflyfurnace' then cooking.ingredients=raw end
    local function finish(ok,...)
        cooking.ingredients=old
        if not ok then error((...),0)end
        return ...
    end
    return finish(pcall(fn,...))
end
local function recipe(priority,test)return {priority=priority,test=test}end
cooking.recipes.cookpot={
 meatballs=recipe(-1,function(_,_,t)return (t.meat or 0)>0 end),
 bonestew=recipe(0,function(_,_,t)return (t.meat or 0)>=3 end)}
cooking.recipes.portablecookpot=copy(cooking.recipes.cookpot)
cooking.recipes.portablecookpot.chef=recipe(10,function(c,names)return c=='portablecookpot'and names.berries==5 end)
local registered,ctor
package.preload['container/container_detector']=function()return {RegisterDevice=function(def)registered=def end}end
local api={isModuleAvailable=function()return true end,AddClassPostConstruct=function(path,fn)ctor=fn end}
require('complexsmartpot2hm').Install(cooking,api)
check(registered and ctor,'optional complex detector and panel installed')
local function inst(prefab,slots)
 local c={GetNumSlots=function()return slots end,AcceptsStacks=function()return true end,GetItemInSlot=function()end}
 return {prefab=prefab,HasTag=function()return true end,replica={container=c}}
end
for _,name in ipairs({'cookpot','portablecookpot','medal_cookpot'})do
 check(registered.test(inst(name,5)),'five-slot cooker recognized: '..name)
 check(not registered.test(inst(name,4)),'native detector retains four-slot cooker')
end
check(not registered.test(inst('treasurechest',5)),'non-cooker excluded')
local panel=copy(NativePanel)
panel.data={GetMatchingRecipes=function()error('full cooking must use current cookbook')end}
panel.SetCooker=function(self,name)self._cooker=name;self._cooker_recipes=cooking.recipes[name]end
panel.RefreshDisplay=function(self)self.refreshes=(self.refreshes or 0)+1 end
panel._player_inst={HasTag=function()return true end}
ctor(panel)
local five={'meat','meat','meat','berries','berries'}
panel:SetCooker('cookpot');panel:SetAcceptsStacksFromContainer(inst('cookpot',5))
panel:SetPotIngredients(five,inst('cookpot',5))
check(panel._max_slots==5 and panel._highlighted_recipes.meatballs and not panel._highlighted_recipes.bonestew,'five inputs use reduced tags')
panel:SetCooker('dragonflyfurnace');panel:SetAcceptsStacksFromContainer(inst('dragonflyfurnace',9))
check(panel._max_slots==4 and not panel._accepts_stacks,'furnace has four cooking inputs')
panel:SetPotIngredients({'meat','meat','meat','berries'},inst('dragonflyfurnace',9))
check(panel._highlighted_recipes.bonestew and not panel._highlighted_recipes.meatballs,'furnace restores original ingredient tags')
check(cooking.ingredients.meat.tags.meat==.75,'furnace context restored')
panel:SetCooker('portablecookpot');panel:SetAcceptsStacksFromContainer(inst('portablecookpot',5))
panel:SetPotIngredients({'berries','berries','berries','berries','berries'},inst('portablecookpot',5))
check(panel._highlighted_recipes.chef,'recipe receives real cooker name, not container entity')
local old=ctor;api.isModuleAvailable=function()return false end
require('complexsmartpot2hm').Install(cooking,api)
check(ctor==old,'absent optional modules are not required')

CONTROL_SECONDARY=2;TUNING={isCh2hm=true};ThePlayer={}
local calls={}
local function collect(...)calls[#calls+1]={...}end
local function image()
 return {focus=true,shown=true,OnControl=function()return 'native' end,OnLoseFocus=function(self)self.focus=false end,
 GetTooltip=function(self)return self.tip end,SetTooltip=function(self,t)self.tip=t end,IsVisible=function(self)return self.shown end}
end
local m=require('cookingredientcollect2hm')
local i=image()
m.Bind(i,{key='monstermeat_cooked',istag=false},collect,function()return ThePlayer end,true)
check(i:OnControl(1,false)=='native','native left click retained')
i:OnControl(2,false);check(#calls==0,'release without press cannot collect')
i:OnControl(2,true);i:OnControl(2,false)
check(#calls==1 and calls[1][2]=='cookedmonstermeat'and calls[1][5]==true,'right-click alias uses player collection')
m.Bind(i,{key='meat',istag=true},collect,function()return ThePlayer end,true)
i:OnControl(2,true);i:OnControl(2,false)
check(#calls==2 and calls[2][2]=='meat'and calls[2][3],'pooled icon collects current tag')
i:OnControl(2,true);i:OnLoseFocus();i.focus=true;i:OnControl(2,false)
check(#calls==2,'focus loss cancels click')
m.Bind(i,nil,collect,function()return ThePlayer end,true)
i:OnControl(2,true);i:OnControl(2,false)
check(#calls==2,'cleared maximum/label pooled icon cannot collect')
m.Bind(i,{key='berries'},collect,function()return ThePlayer end,true);i.shown=false
i:OnControl(2,true);i:OnControl(2,false)
check(#calls==2,'hidden pooled icon cannot collect')
i.shown=true;i:OnControl(2,true)
m.Bind(i,{key='carrot'},collect,function()return ThePlayer end,true)
i:OnControl(2,false)
check(#calls==2,'pool refresh cancels press on the previous ingredient')
local req={Create=function()return {pool={},expand={icons={}}}end,UpdateEntries=function()return 7 end,ShowExpand=function()end}
local craft={Update=function(popup)
 popup._get_craftable_fn({})
 if popup.fail then error('render failure')end
 return 2
end}
package.preload['ui/recipe_popup_req_section']=function()return req end
package.preload['ui/recipe_popup_craft_section']=function()return craft end
require('config/config_manager').GetMaxRenderCombos=function()return 1 end
m.Install({isModuleAvailable=function(path)return path=='ui/recipe_popup_req_section'or path=='ui/recipe_popup_craft_section'end},collect)
local section=req.Create({},'min')
for k=1,4 do section.pool[k]={img=image(),hover=image()}end
req.UpdateEntries(section,{{type='group',members={{key='meat'},{key='smallmeat'}},display_amount='1'},{key='carrot'}})
check(section.pool[1].img.cookcollectspec2hm.key=='meat'and section.pool[2].img.cookcollectspec2hm.key=='smallmeat','group members collect their own ingredient')
check(not section.pool[3].img.cookcollectspec2hm and section.pool[4].img.cookcollectspec2hm.key=='carrot','group label does not shift the next collection target')
section.cookcollectminimum2hm=false
req.UpdateEntries(section,{{key='carrot'}})
check(not section.pool[1].img.cookcollectspec2hm,'maximum requirement has no collection action')
local queried=0
local get=function()queried=queried+1;return {{ingredients={'carrot','meat'}},{ingredients={'honey'}}}end
local popup={_get_craftable_fn=get}
local cs={slot_pool={{img=image(),IsVisible=function()return true end},{img=image(),IsVisible=function()return true end}}}
craft.Update(popup,cs,{})
check(queried==1 and popup._get_craftable_fn==get,'craft renderer computes combinations once and restores callback')
check(cs.slot_pool[1].img.cookcollectspec2hm.key=='carrot'and cs.slot_pool[2].img.cookcollectspec2hm.key=='meat','render limit prevents hidden combination from replacing visible targets')
popup.fail=true
check(not pcall(craft.Update,popup,cs,{})and popup._get_craftable_fn==get,'failed craft render restores original callback')

local route=require('fiveslotcookers2hm')
local function container()
 return {slots={},numslots=6,GetNumSlots=function()return 6 end,GetItemInSlot=function(self,k)return self.slots[k]end,
 IsReadOnlyContainer=function(self)return self.readonlycontainer end,CanTakeItemInSlot=function()return true end,
 AcceptsStacks=function()return false end,GiveItem=function(self,item,slot)
   if slot<1 or slot>self.numslots or self.slots[slot]then return false end
   self.slots[slot]=item;return true
 end}
end
local c,r=container(),container()
local pot={components={container=c},replica={container=r}}
route.RouteInputs(pot,{6,1,2,3,4})
for _,slot in ipairs({6,1,2,3,4})do
 check(c:GetSpecificSlotForItem({})==slot and r:GetSpecificSlotForItem({})==slot,'client and server use visible ingredient order')
 local item={components={},replica={}};check(c:GiveItem(item),'automatic ingredient insertion succeeds')
 r.slots[slot]=item
 for k,v in pairs(r.slots)do check(c.slots[k]==v,'existing ingredients do not shift')end
end
check(c.slots[5]==nil and not c:GiveItem({}),'full ingredients never spill into output')
check(c:GiveItem({},5),'native explicit product placement is preserved')
local before=c.GetSpecificSlotForItem;route.RouteInputs(pot,{1,2,3,4,5})
check(c.GetSpecificSlotForItem==before,'routing installation is idempotent')
local late,classified
route.InstallInputRouting({AddClassPostConstruct=function(_,fn)late=fn end,AddPrefabPostInit=function(_,fn)classified=fn end})
local lazy=container();lazy.inst={cookerinputorder2hm={6,1,2,3,4}}
late(lazy)
check(lazy:GetSpecificSlotForItem({})==6,'late-created replica inherits input routing')
local received=0
local network={_parent={replica={container=r}},ReceiveItem=function(_,_,_,slot)received=received+1;return slot end}
classified(network)
check(network:ReceiveItem({})==nil and received==0,'full replica refuses prediction before native slot indexing')
r.slots[6]=nil
check(network:ReceiveItem({})==6 and received==1,'native prediction receives the selected visible input')
check(network:ReceiveItem({},nil,5)==5,'explicit native output placement keeps its slot')
print('Complex Smart Pot and ingredient collection: '..n..' checks passed')
