local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local function load(s)return assert(loadstring(s))()end
local function entity()
 local inst={components={},replica={},events={},tasks={}}
 function inst:HasTag(tag)return tag=='playerghost'and self.ghost or false end
 function inst:ListenForEvent(name,fn,source)
  source=source or self;source.events[name]=source.events[name]or {};table.insert(source.events[name],{self,fn})
 end
 function inst:PushEvent(name,data)
  for _,cb in ipairs(self.events[name]or {})do cb[2](cb[1],data)end
 end
 function inst:DoTaskInTime(_,fn,...)
  table.insert(self.tasks,{fn,{...}})
 end
 function inst:RunTasks()
  local tasks=self.tasks;self.tasks={};for _,t in ipairs(tasks)do t[1](self,unpack(t[2]))end
 end
 return inst
end
STORM_TYPES={NONE=0,MOONSTORM=1,SANDSTORM=2};EQUIPSLOTS={HEAD='head'};SEASONS={WINTER='winter',SUMMER='summer'}
TUNING={MOONSTORM_SPEED_MOD=.3,SANDSTORM_FULL_LEVEL=.7,isCh2hm=true}
TheFrontEnd={GetFadeLevel=function()return 0 end}
local Vision=load(vision_source)
local Watcher=load(watcher_source)
local nativeoverlay=load(overlay_source)
for _,mode in ipairs({'server','client'})do
 local hooks,players,widgets,prefabs={},{},{},{}
 TheWorld={ismastersim=mode=='server',net={components={}},state={}}
 TheNet={IsDedicated=function()return mode=='server'end}
 GetModConfigData=function()return true end
 AddComponentPostInit=function(name,fn)hooks[name]=fn end
 AddPlayerPostInit=function(fn)players[#players+1]=fn end
 AddClassPostConstruct=function(path,fn)widgets[path]=fn end
 AddPrefabPostInit=function(name,fn)prefabs[name]=fn end
 load(patch_source)
 local p=entity();local storm=STORM_TYPES.NONE;local head
 local inventory={GetEquippedItem=function()return head end,Unequip=function()error('moonstorm must not unequip the hat')end,
 GiveItem=function()error('moonstorm must not transfer the hat')end,
 EquipHasTag=function(_,tag)return head and head.tags[tag]or false end}
 p.replica.inventory=inventory;p.components.inventory=inventory
 p.GetStormLevel=function(_,kind)return storm==kind and 1 or 0 end
 if mode=='server'then p.components.stormwatcher={GetCurrentStorm=function()return storm end,GetStormLevel=function(_,kind)return p:GetStormLevel(kind)end}end
 p.components.rider={IsRiding=function()return p.riding end}
 p.components.locomotor={SetExternalSpeedMultiplier=function(_,_,_,v)p.speed=v end,RemoveExternalSpeedMultiplier=function()p.speed=nil end}
 local v=Vision(p);p.components.playervision=v;hooks.playervision(v)
 local w=Watcher(p);p.components.moonstormwatcher=w;hooks.moonstormwatcher(w)
 for _,fn in ipairs(players)do fn(p)end
 p:RunTasks()
 local overlay
 if mode=='client'then
  overlay={inst=entity(),BlindTo=function(self,x)self.blind=x end,FadeTo=function()end,
    dust={SetEffect=function(self,e)self.effect=e end},UpdateAlphaRangeShaderUniforms=function()end}
  nativeoverlay(overlay,p);widgets['widgets/moonstormover'](overlay,p)
 end
 local function equip(tags,prefab)
  head={prefab=prefab or 'antlionhat',tags=tags,components={},tool={}}
  function head:AddTag(tag)self.tags[tag]=true end
  if prefabs[head.prefab]then prefabs[head.prefab](head)end
  p:PushEvent('equip');p:RunTasks()
 end
 local function refresh()
  p:PushEvent('stormlevel',{stormtype=storm,level=storm==STORM_TYPES.NONE and 0 or 1})
  p:PushEvent('moonstormlevel',{level=storm==STORM_TYPES.MOONSTORM and 1 or 0})
  p:RunTasks();w:UpdateMoonstormWalkSpeed_Internal(storm==STORM_TYPES.MOONSTORM and 1 or 0)
 end
 equip({goggles=true});check(v:HasGoggleVision(),'ordinary goggles work outside moonstorm')
 local kept=head;storm=STORM_TYPES.MOONSTORM;refresh()
 check(head==kept and head.tool~=nil,'entering moonstorm keeps the helm and tool')
 check(not v:HasGoggleVision()and v.gogglevision,'only effective protection is suppressed; raw equipment vision stays intact')
 check(p.speed==.3,'ordinary goggles do not cancel native moonstorm slowing')
 if overlay then check(overlay.blind==1 and overlay.dust.effect=='shaders/moonstorm.ksh','entering updates native blind/shader despite raw goggles')end
 equip({goggles=true});refresh();check(head~=nil and not v:HasGoggleVision(),'equipping ordinary goggles inside the storm is allowed')
 if overlay then check(overlay.blind==1,'raw equip event cannot enable moon goggles overlay')end
 equip({goggles=true,moonstormgoggles=true})
 if mode=='server'then check(p.speed==nil,'switching between goggles refreshes speed without a storm-level change')end
 if overlay then check(overlay.blind==0,'switching between goggles refreshes overlay without a raw vision event')end
 refresh()
 check(v:HasGoggleVision()and p.speed==nil,'dedicated and upgraded moon goggles still protect')
 if overlay then check(overlay.blind==0 and overlay.dust.effect=='shaders/moonstorm_goggles.ksh','moon goggles enable native protection shader')end
 equip({goggles=true},'lunarplanthat')
 check(head.tags.moonstormgoggles and head.tags.goggles and v.gogglevision,'brightshade combines native goggles with moonstorm tag hook')
 check(v:HasGoggleVision(),'brightshade helm protects inside moonstorm')
 if mode=='server'then check(p.speed==nil,'brightshade equip clears moonstorm slowing')end
 if overlay then check(overlay.blind==0 and overlay.dust.effect=='shaders/moonstorm_goggles.ksh','brightshade equip enables moonstorm protection overlay')end
 storm=STORM_TYPES.NONE;refresh();check(v:HasGoggleVision(),'brightshade retains native goggles outside moonstorms')
 storm=STORM_TYPES.MOONSTORM;refresh()
 check(v:HasGoggleVision()and p.speed==nil,'entering moonstorm in brightshade restores protection')
 head=nil;p:PushEvent('unequip');p:RunTasks();refresh()
 check(not v:HasGoggleVision()and p.speed==.3,'removing brightshade restores moonstorm penalty')
 if overlay then check(overlay.blind==1 and overlay.dust.effect=='shaders/moonstorm.ksh','removing brightshade restores moonstorm overlay')end
 equip({goggles=true})
 if mode=='server'then check(p.speed==.3,'switching back to ordinary goggles immediately restores storm penalty')end
 if overlay then check(overlay.blind==1,'switching back to ordinary goggles immediately restores native blind')end
 refresh();storm=STORM_TYPES.NONE;refresh()
 check(v:HasGoggleVision(),'leaving restores ordinary goggles without re-equipping')
 storm=STORM_TYPES.SANDSTORM
 check(v:HasGoggleVision(),'other storm protection query is unchanged')
 storm=STORM_TYPES.MOONSTORM;v:ForceGoggleVision(true);refresh()
 check(v:HasGoggleVision()and p.speed==nil,'explicit forced vision retains original behavior')
 v:ForceGoggleVision(false);v.ghostvision=true;refresh();check(p.speed==nil,'native ghost vision exemption remains independent')
 v.ghostvision=false;p.riding=true;refresh();check(p.speed==nil,'native riding exemption remains independent')
end
local installed=false
GetModConfigData=function()return -1 end
AddComponentPostInit=function()installed=true end;AddClassPostConstruct=function()installed=true end;AddPlayerPostInit=function()installed=true end
load(patch_source)
check(not installed,'disabled goggles-type option retains original game behavior')
print('Moonstorm goggles/native vision, speed and overlay: '..n..' checks passed')
