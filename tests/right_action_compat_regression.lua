-- Native Lua picker, native RMB dispatch and actual medal blink callback;
-- engine entities, netvars, rendering and action execution are headless substitutes.
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end
local noop = function() end
local map = {IsPassableAtPoint=function() return true end, IsGroundTargetBlocked=function() return false end,
    IsPointInWagPunkArenaAndBarrierIsUp=function() return false end, IsOceanAtPoint=function() return false end}
TheWorld = {ismastersim=false, Map=map}
FRAMES=1/30
EQUIPSLOTS={HANDS="hands"}
CONTROL_FORCE_STACK=1; CONTROL_SECONDARY=2
EntityScript={}
Vector3=Class(function(self,x,y,z) self.x=x or 0;self.y=y or 0;self.z=z or 0 end)
function Vector3:Get() return self.x,self.y,self.z end
local pos=Vector3(5,0,5)
function DynamicPosition(pt) return {local_pt=pt} end
local hud,mouse_target
TheInput={GetHUDEntityUnderMouse=function() return hud end,GetWorldPosition=function() return pos end,
    GetWorldEntityUnderMouse=function() return mouse_target end}
function CanEntitySeePoint() return true end
function CanEntitySeeTarget() return true end
function GetTime() return 100 end
function net_bool()
    return {set=function(self,v) self.v=v end, value=function(self) return self.v end}
end
net_byte=net_bool
function BufferedAction(doer,target,action,item,pt)
    return {doer=doer,target=target,action=action,invobject=item,pos=pt and DynamicPosition(pt),options={}}
end
function OrderByPriority(a,b) return (a.priority or 0)>(b.priority or 0) end
local Picker=assert(loadstring(picker_source))()
local Targeting=assert(loadstring(targeting_source))()
local Charging=assert(loadstring(charging_source))()
PlayerController={}
assert(loadstring(click_source))()
assert(loadstring(spellbook_source))()
local MedalBlink=assert(loadstring(medal_source))()
local actions={}
for _,name in ipairs({"BLINK","CASTAOE","CASTSPELL","LOOKAT","DROP","CLOSESPELLBOOK","WOBY_COMMAND","CUSTOM_SKILL"}) do
    actions[name]={id=name,priority=1}
end
ACTIONS=actions

local function setup(config)
    local hooks={}
    local env=setmetatable({TUNING={isCh2hm=true}, ACTIONS=setmetatable({}, {__index=actions}),STRINGS={ACTIONS={}},
        GetModConfigData=function(key) return config[key] end,State=function(t) return t end,
        EventHandler=function(...) return {...} end,TimeEvent=function(...) return {...} end,
        AddStategraphState=noop,AddStategraphPostInit=noop}, {__index=_G})
    env.AddAction=function(name,_,fn) env.ACTIONS[name]={id=name,fn=fn,priority=1} end
    env.AddComponentPostInit=function(name,fn) hooks[name]=fn end
    setfenv(assert(loadstring(right_source)),env)()
    return env,hooks
end
local function item(kind,enabled)
    local t={components={},replica={inventoryitem={IsWeapon=function() return true end}}}
    t.ListenForEvent=noop
    function t:IsValid() return true end
    function t:HasTag() return false end
    function t:CollectActions(_,_,_,list,right)
        if right and self.pointaction and (not self.components.aoetargeting or self.components.aoetargeting:IsEnabled()) then
            list[#list+1]=self.pointaction
        end
    end
    if kind then
        t.components[kind]=(kind=="aoecharging" and Charging or Targeting)(t)
        t.components[kind].enabled:set(enabled)
        t.components[kind].allowriding=false
    end
    return t
end
local function player(env,hooks,ability,prefab,extra,after)
    local p={prefab=prefab or "winona",GUID=1,components={},replica={},tags={shadowlunge2hm=true},events={}}
    function p:HasTag(tag) return self.tags[tag] or false end
    function p:AddTag(tag) self.tags[tag]=true end
    function p:GetCurrentPlatform() return self.platform end
    function p:ListenForEvent(name,fn) self.events[name]=fn end
    function p:DoTaskInTime(_,fn) fn(self) end
    p.Transform={GetWorldPosition=function() return 0,0,0 end}
    p.replica.inventory={GetEquippedItem=function() return p.tool end,GetActiveItem=function() return p.active end,
        Has=function() return p.souls end,ReturnActiveItem=noop}
    p.mount={HasTag=function(_,tag) return p.woby and tag=="woby" end}
    p.replica.rider={IsRiding=function() return p.riding end,GetMount=function() return p.riding and p.mount end}
    local pc={inst=p,remote_controls={},ismastersim=true,handler={}}
    p.components.playercontroller=pc
    function pc:IsControlPressed() return p.ctrl end
    pc.GetActiveSpellBook=PlayerController.GetActiveSpellBook
    function pc:IsAOETargeting() return self.reticule~=nil end
    function pc:GetAOETargetingPos() return pos end
    function pc:UsingMouse() return true end
    function pc:IsEnabled() return true end
    function pc:CancelAOETargeting() self.reticule=nil;self.cancelled=true end
    function pc:ClearActionHold() end
    function pc:GetRightMouseAction() return self.RMBaction end
    function pc:GetMapTarget() end
    function pc:DoAction(act) self.performed=act end
    function pc:TryAOETargeting() self.started=true;return true end
    pc.OnRightClick=PlayerController.OnRightClick
    local picker=Picker(p)
    p.components.playeractionpicker=picker
    picker.GetSteeringActions=function() end
    picker.GetCannonAimActions=function() end
    picker.GetGolfAimActions=function() end
    picker.GetLeftClickActions=function() return {} end
    picker.GetEquippedItemActions=function(self,target,tool,right) return self:GetPointActions(pos,tool,right,target) end
    picker.GetSceneActions=function() return {} end
    local function install_extra()
        p.medal_old_pointspecialactionsfn=picker.pointspecialactionsfn
        picker.pointspecialactionsfn=extra
    end
    if extra and not after then install_extra() end
    hooks.playeractionpicker(picker); hooks.playercontroller(pc)
    env[ability](p)
    if ability=="AddLungeAbility" then p.last_rightaction2hm_time=0;p.rightaction2hm_cooldown=2 end
    if p.last_rightaction2hm_time~=nil then p.last_rightaction2hm_time=0 end
    p.events.setowner(p)
    if extra and after then install_extra() end
    p.tool=item()
    return p,picker,pc
end
local roles={
    {"AddRotateAbility","winona","ROTATE_WINONA2HM"},
    {"AddDodgeAbility","wilson","DODGE_WALTER"},
    {"AddDodgeAbility","wes","DODGE_WALTER"},
    {"AddDodgeAbility","walter","DODGE_WALTER"},
    {"AddDodgeAbility","wathgrithr","DODGE_WALTER"},
    {"AddDodgeAbility","woodie","DODGE_WALTER"},
    {"AddWrapFrontAbility","wanda","WARPFRONT_WANDA"},
    {"AddWrapAbility","wanda","WARPBACK_WANDA"},
    {"AddWrapAbility","waxwell","WARPBACK_WANDA"},
    {"AddLungeAbility","waxwell","Lunge_WAXWELL2HM"},
}
for _,name in ipairs({"wilson","willow","wolfgang","wendy","wx78","wickerbottom","woodie","wes","waxwell",
    "wathgrithr","webber","winona","warly","wortox","wormwood","wurt","walter","wanda","wonkey"}) do
    roles[#roles+1]={"AddDodgeAbility",name,"DODGE_WALTER",true}
end
local function ready(p,r)
    if r and r[4] then p.rightaction2hm_both=true end
    if p.prefab=="walter" or (p.prefab=="wathgrithr" and not (r and r[4])) then
        p.riding=true;p.rightaction2hm_beefalo=true
    end
end
local function unavailable(p)
    p.tags.rotate_weapon2hm=nil;p.tags.shadowlunge2hm=nil
    p.last_rightaction2hm_time=100;p.tags.doubledodge2hm=nil
end
for _,low in ipairs({false,true}) do
    local env,hooks=setup({["ctrl disable right"]=low})
    for _,r in ipairs(roles) do
        local p,picker,pc=player(env,hooks,r[1],r[2]);ready(p,r)
        local expected=env.ACTIONS[r[3]]
        local function pick() local _,right=picker:DoGetMouseActions();return right and right.action end
        for _,kind in ipairs({"aoetargeting","aoecharging"}) do
            p.tool=item(kind,false)
            check(pick()==expected,r[2].." locked/uncharged "..kind.." does not block own ability")
            p.tool.components[kind].enabled:set(true)
            p.tool.components[kind].allowriding=p.riding
            check(pick()==nil,r[2].." enabled item gets normal RMB for targeting/charging")
            p.ctrl=true
            check(pick()==expected,r[2].." Ctrl selects own ability over enabled "..kind)
            p.ctrl=false
        end
        -- Ordinary item point spells and unknown mod weapons need no prefab entry.
        p.tool=item();p.tool.pointaction=actions.CUSTOM_SKILL
        check(pick()==actions.CUSTOM_SKILL,r[2].." custom item skill preserved")
        p.ctrl=true
        check(pick()==expected,r[2].." Ctrl selects own ability over custom item skill")
        unavailable(p)
        check(pick()==actions.CUSTOM_SKILL,r[2].." unavailable own ability preserves item action")
        p,picker,pc=player(env,hooks,r[1],r[2]);ready(p,r)
        p.ctrl=true;p.active=item();p.active.pointaction=actions.CUSTOM_SKILL
        check(pick()==actions.CUSTOM_SKILL,r[2].." cursor item not intercepted")
        p.active=nil;p.tool.pointaction=actions.CASTSPELL;p.book=p.tool;pc.reticule={inst=p.tool};p.tool.components.spellbook={}
        check(pick()==actions.CASTSPELL,r[2].." active spellbook not intercepted")
        p.book=nil;pc.reticule=nil;p.tool.components.spellbook=nil;picker.disable_right_click=true
        check(pick()==nil,r[2].." disabled picker not bypassed")
        picker.disable_right_click=nil
        picker.actionfilter=function(_,a) return a~=expected end
        check(pick()==actions.CASTSPELL,r[2].." filtered own skill preserves native item action")
        picker.actionfilter=nil
        p.tool.pointaction=nil;p.tags.playerghost=true
        check(pick()==nil,r[2].." ghost cannot gain character skill")
        p.tags.playerghost=nil;p.ingym2hm=true
        check(pick()==nil,r[2].." gym interaction not intercepted")
        p.ingym2hm=nil;p.weremode={value=function() return 1 end}
        check(pick()==nil,r[2].." transformed state not intercepted")
        p.weremode=nil;p.ctrl=false
        picker.rightclickoverride=function()
            return {BufferedAction(p,nil,actions.CUSTOM_SKILL,nil,pos)},false
        end
        check(pick()==actions.CUSTOM_SKILL,r[2].." custom rightclickoverride keeps normal RMB")
        p.ctrl=true
        check(pick()==expected,r[2].." Ctrl selects own ability over custom point override")
        -- Actual medal callback before AND after our setowner registration.
        for _,after in ipairs({false,true}) do
            p,picker,pc=player(env,hooks,r[1],r[2],MedalBlink,after);ready(p,r)
            -- Medal blink forbids riding; mounted-only Walter remains ineligible.
            if not p.riding then
                p.tags.medal_blinker=true;p.souls=true
                check(pick()==actions.BLINK,r[2].." soul medal keeps plain RMB, after="..tostring(after))
                p.ctrl=true
                check(pick()==expected,r[2].." Ctrl selects own ability, after="..tostring(after))
                picker.actionfilter=function(_,a) return a~=expected end
                check(pick()==actions.BLINK,r[2].." action filter preserves medal blink")
                picker.actionfilter=nil
                unavailable(p)
                check(pick()==actions.BLINK,r[2].." own cooldown preserves medal blink")
                p.ctrl=false;p.souls=false
                check(pick()==nil,r[2].." no soul and own cooldown produces no invalid action")
                p.tags.rotate_weapon2hm=true;p.tags.shadowlunge2hm=true;p.last_rightaction2hm_time=0
                check(pick()==expected,r[2].." no soul leaves ordinary own ability available")
            end
        end
    end
end
-- Native targeting-mode RMB dispatch would otherwise only cancel aiming.
do
    local env,hooks=setup({})
    local p,picker,pc=player(env,hooks,"AddRotateAbility")
    p.tool=item("aoetargeting",true);pc.reticule={inst=p.tool};p.ctrl=true
    pc:OnRightClick(true)
    check(pc.cancelled and pc.performed and pc.performed.action==env.ACTIONS.ROTATE_WINONA2HM,
        "native aimed Ctrl+RMB cancels item aim and dispatches own action")
    pc.cancelled=nil;pc.performed=nil;pc.reticule={inst=p.tool};p.ctrl=false
    pc:OnRightClick(true)
    check(pc.cancelled and not pc.performed,"plain RMB still cancels native targeting")
    pc.cancelled=nil;pc.reticule={inst=item("aoetargeting",true)};p.ctrl=true
    pc:OnRightClick(true)
    check(pc.cancelled and not pc.performed,"foreign spellbook reticule only uses native cancellation")
    pc.cancelled=nil;pc.reticule={inst=p.tool};p.tags.rotate_weapon2hm=nil
    pc:OnRightClick(true)
    check(pc.cancelled and not pc.performed,"own cooldown keeps native RMB cancellation")
end
do
    local env,hooks=setup({})
    local specialpos=Vector3(20,0,20)
    local p,picker=player(env,hooks,"AddRotateAbility","winona",function() return {actions.BLINK},specialpos end)
    local picked=picker:GetPointSpecialActions(pos,nil,true,true)
    check(picked[1].action==actions.BLINK and picked[1].pos.local_pt==specialpos,"native callback reticule position preserved")
    p.ctrl=true
    picked=picker:GetPointSpecialActions(pos,nil,true)
    check(picked[1].action==env.ACTIONS.ROTATE_WINONA2HM and picked[1].pos.local_pt==pos,"Ctrl ability uses its requested point")
end
-- Existing explicit Ctrl requirements remain per ability, not global.
for _,r in ipairs({roles[7],roles[8],roles[10]}) do
    local env,hooks=setup({["right Wrapback need ctrl"]=true,["right Lunge need ctrl"]=true})
    local p,picker=player(env,hooks,r[1],r[2])
    check(#picker:GetPointSpecialActions(pos,nil,true)==0,"explicit Ctrl gate preserved")
    p.ctrl=true
    check(picker:GetPointSpecialActions(pos,nil,true)[1].action==env.ACTIONS[r[3]],"explicit Ctrl ability available")
end
print("Right-action item/medal compatibility: "..n.." checks passed")
