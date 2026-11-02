local assertions = 0
local function equal(a, b, label)
    assertions = assertions + 1
    assert(a == b, (label or "mismatch") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function near(a, b, label)
    assertions = assertions + 1
    assert(math.abs(a-b) < 1e-6, (label or "mismatch") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
function math.clamp(x, a, b) return math.max(a, math.min(b, x)) end
FOODGROUP = {OMNI = "omni"}
TUNING = {OLDAGE_HEALTH_SCALE=.4, POCKETWATCH_HEAL_HEALING=20, POCKETWATCH_HEAL_COOLDOWN=120, BOOK_TEMPERATURE_AMOUNT=30}
TheWorld = {ismastersim=true}
function GetTime() return 0 end
function SpawnPrefab()
    return {entity={SetParent=function() end}, Transform={SetPosition=function() end}, SetUp=function() end, Remove=function() end}
end
local OldAger = assert(loadstring(oldager_source))()
local Eater = assert(loadstring(eater_source))()
Health = {}; assert(loadstring(health_source))()
local cast = assert(loadstring(watch_source))()
local usecracked = assert(loadstring(cracked_source))()
local hooks, players, prefabs, config
function AddComponentPostInit(name, fn) hooks[name]=hooks[name] or {}; table.insert(hooks[name],fn) end
function AddPlayerPostInit(fn) players[#players+1]=fn end
function AddPrefabPostInit(name, fn) prefabs[name]=prefabs[name] or {}; table.insert(prefabs[name],fn) end
function GetModConfigData(name) return config[name] end
local function apply(name, inst) for _,fn in ipairs(hooks[name] or {}) do fn(inst) end end
local function install(battle, old, stop, strength)
    hooks, players, prefabs = {}, {}, {}
    config={role_battle=battle, ["Wanda Don't Auto Drop Age"]=stop}
    assert(loadstring(old and old_regen_source or regen_source))()
    if battle then assert(loadstring(role_source))() end
    assert(loadstring(stop_source))()
    if strength then assert(loadstring(strength_source))() end
end
local function entity()
    local inst={prefab="wanda",components={},tags={player=true},tasks={},events={},clock=0,entity={},sg={statemem={}}}
    function inst:AddTag(t)self.tags[t]=true end
    function inst:RemoveTag(t)self.tags[t]=nil end
    function inst:HasTag(t)return self.tags[t] or false end
    function inst:IsValid()return true end
    function inst:StartUpdatingComponent()end
    function inst:ListenForEvent(e, fn)self.events[e]=self.events[e] or {};table.insert(self.events[e],fn)end
    function inst:PushEvent(e,data)for _,fn in ipairs(self.events[e] or {})do fn(self,data)end end
    function inst:DoTaskInTime(t,fn,...)
        local task={at=self.clock+t,fn=fn,args={...}}
        function task:Cancel()self.cancelled=true end
        self.tasks[#self.tasks+1]=task;return task
    end
    function inst:DoPeriodicTask(t,fn,initial)
        local task=self:DoTaskInTime(initial or t,fn);task.period=t;return task
    end
    function inst:RunTasks(dt)
        self.clock=self.clock+dt
        for _,task in ipairs(self.tasks)do
            while not task.cancelled and task.at<=self.clock+1e-9 do
                if task.period then task.at=task.at+task.period else task.cancelled=true end
                task.fn(self,unpack(task.args))
            end
        end
    end
    inst.Transform={GetWorldPosition=function()return 0,0,0 end}
    inst.SoundEmitter={PlaySound=function()end}
    inst.components.temperature={current=20,SetTemperature=function(self,n)self.current=n end}
    return inst
end
local function addage(inst)
    local o=OldAger(inst);inst.components.oldager=o;apply("oldager",o)
    o:AddValidHealingCause("pocketwatch_heal");o:AddValidHealingCause("debug_key")
    return o
end
local function player(age, initialized)
    local inst=entity()
    local h={inst=inst,currenthealth=20,maxhealth=60,nonlethal_pct=0,absorb=0,playerabsorb=0,DoDelta=Health.DoDelta}
    function h:GetPercent()return self.currenthealth/self.maxhealth end
    function h:IsInvincible()return false end
    function h:IsDead()return self.currenthealth<=0 end
    function h:GetMaxWithPenalty()return self.maxhealth end
    function h:SetVal(v)self.currenthealth=math.clamp(v,0,self.maxhealth)end
    h.externalabsorbmodifiers={Get=function()return 0 end};h.externalreductionmodifiers=h.externalabsorbmodifiers
    h.redirect=function(owner,...)return owner.components.oldager and owner.components.oldager:OnTakeDamage(...)end
    inst.components.health=h;apply("health",h)
    inst.components.sanity={current=40,DoDelta=function(self,n)self.current=self.current+n end}
    inst.components.hunger={current=40,DoDelta=function(self,n)self.current=self.current+n end}
    local eater=Eater(inst);inst.components.eater=eater;apply("eater",eater)
    if age then addage(inst) end -- Actual Wanda adds oldager after eater.
    for _,fn in ipairs(prefabs.wanda or {})do fn(inst)end
    for _,fn in ipairs(players)do fn(inst)end
    if initialized~=false then inst:RunTasks(0) end
    return inst
end
local function wound(inst)
    inst:PushEvent("attacked",{attacker={components={combat={}}}})
end
local function flush(inst)
    local o=inst.components.oldager
    for _=1,10000 do
        if o.damage_remaining==0 then return end
        -- Exact binary frame steps avoid vanilla floor(year_timer) rounding noise.
        o:OnUpdate(1/64)
    end
    error("aging fixture did not settle")
end
local function watch(inst, amount, cracked)
    TUNING.POCKETWATCH_HEAL_HEALING=amount
    local tool={prefab="pocketwatch_heal",components={rechargeable={Discharge=function(self,t)self.cooldown=t end}}}
    if cracked then
        tool.healthDoDelta2hm=25;tool.sanityDoDelta2hm=2;tool.repairspeed2hm=3.6
        tool.components.finiteuses={uses=3,GetUses=function(self)return self.uses end,Use=function(self,n)self.uses=self.uses-n end}
        function tool:DoPeriodicTask()return {Cancel=function()end}end
        equal(usecracked(tool,inst),true,"real cracked watch used")
        equal(tool.components.finiteuses.uses,2,"cracked durability unchanged")
        equal(inst.allmiss2hm,true,"cracked invulnerability retained")
        near(inst.components.sanity.current,42,"cracked sanity retained")
    else
        equal(cast(tool,inst),true,"real watch cast")
        equal(tool.components.rechargeable.cooldown,120,"watch cooldown unchanged")
    end
    return tool
end
local function food(h,s,hunger)
    local f={prefab="fixturefood",components={}}
    function f:HasTag(tag)return tag=="edible_omni"end
    f.components.edible={healthvalue=h,sanityvalue=s,GetHealth=function()return h end,GetSanity=function()return s end,GetHunger=function()return hunger end,
        OnEaten=function(_,inst)inst.eatenfx=(inst.eatenfx or 0)+1 end,HandleEatRemove=function()f.removed=true end}
    return f
end

-- Reproduce the old bug, using the exact backed-up wrapper and real age/health code.
for _,battle in ipairs({false,-1})do
    install(battle,true)
    local inst=player(true);inst.components.oldager.base_rate=0;wound(inst);watch(inst,25)
    flush(inst);near(inst.components.health.currenthealth-20,battle and 2 or 2.5,"old double-half reproduced")
    print("Before fix: watch25 battle="..tostring(battle).." wounded=true rejuvenation="..(inst.components.health.currenthealth-20))
end

-- Native and enhanced watches, plus the actual cracked-watch use function.
for _,battle in ipairs({false,-1,-2})do
    for _,case in ipairs({{20,false},{25,false},{25,true}})do
        for _,hurt in ipairs({false,true})do
            install(battle)
            local inst=player(true);inst.components.oldager.base_rate=0
            if hurt then wound(inst)end
            watch(inst,case[1],case[2])
            local factor=battle==-1 and .8 or battle==-2 and .67 or 1
            near(inst.components.oldager.damage_remaining,-case[1]*.4*(hurt and .5 or 1),"only external request reduced")
            flush(inst)
            near(inst.components.health.currenthealth-20,case[1]*.4*(hurt and .5 or 1)*factor,"multi-frame settlement applies each independent factor once")
            if case[1]==25 and not case[2] then
                print("After fix: watch25 battle="..tostring(battle).." wounded="..tostring(hurt).." rejuvenation="..(inst.components.health.currenthealth-20))
            end
        end
    end
end

install(false)
local inst=player(true);inst.components.oldager.base_rate=0;wound(inst);watch(inst,25)
inst:RunTasks(10);equal(inst:HasTag("woundedregen2hm"),false,"wound expires")
flush(inst);near(inst.components.health.currenthealth-20,5,"expiry does not change accepted healing")
inst=player(true);inst.components.oldager.base_rate=0;watch(inst,25);wound(inst);flush(inst)
near(inst.components.health.currenthealth-20,10,"new wound does not tax prior request")
inst=player(true);inst.components.oldager.base_rate=0;watch(inst,25)
inst.components.health:DoDelta(-10,nil,"attack")
near(inst.components.oldager.damage_remaining,4,"native damage interrupts pending healing")
watch(inst,25);near(inst.components.oldager.damage_remaining,-10,"watch cancels pending damage before healing")
inst=player(true);inst.components.oldager:OnUpdate(40)
equal(inst:HasTag("woundedregen2hm"),false,"natural aging does not wound")
equal(inst.woundtask2hm,nil,"aging does not create wound timer")
wound(inst);inst.components.oldager:OnUpdate(40);inst:RunTasks(10)
equal(inst:HasTag("woundedregen2hm"),false,"aging does not perpetually refresh wound")

-- Food HP follows native Eater exactly once, while sanity still uses the mod queue.
for _,health in ipairs({20,-10})do
    install(false)
    inst=player(true);inst.components.oldager.base_rate=0
    inst.components.eater:SetAbsorptionModifiers(.5,1.5,.25)
    local f=food(health,8,10);equal(inst.components.eater:Eat(f),true,"native Eat succeeds")
    equal(inst.eatenfx,1,"food callbacks once");equal(f.removed,true,"food consumption retained")
    near(inst.components.hunger.current,55,"hunger native absorption retained")
    equal(inst._regen2hm_queue.health,nil,"oldager creates no food HP queue")
    near(inst.components.sanity.current,40,"positive sanity initially delayed")
    near(inst.components.oldager.damage_remaining,health<0 and 2 or 0,"positive HP ignored; negative HP applies once at original absorption")
    inst:RunTasks(20);near(inst.components.sanity.current,42,"sanity queue total retained")
end
install(false)
inst=player(true);inst.components.oldager:AddValidHealingCause("fixturefood")
inst.components.eater:SetAbsorptionModifiers(.5,1,1);inst.components.eater:Eat(food(20,0,0))
near(inst.components.oldager.damage_remaining,-4,"third-party legitimate food cause kept native, not duplicated")
equal(inst._regen2hm_queue,nil,"legitimate native food creates no queue")
inst=player(true);inst.components.eater:SetAbsorptionModifiers(0,1,0)
inst.components.eater:Eat(food(-10,8,5))
near(inst.components.oldager.damage_remaining,0,"explicit zero health absorption stays zero at Eat")
near(inst.components.sanity.current,40,"explicit zero sanity absorption preserved")
equal(inst._regen2hm_queue,nil,"zero absorption does not queue anything")
inst=player(true)
inst.components.eater.custom_stats_mod_fn=function(_,hp,hunger,sanity)
    return hp==0 and -3 or hp,hunger,sanity
end
inst.components.eater:Eat(food(-10,8,0))
near(inst.components.oldager.damage_remaining,4,"custom stats recomputation does not submit a second HP delta")
inst=player(false);addage(inst);inst.components.oldager.base_rate=0 -- Added after init, not just after eater constructor.
inst.components.eater:Eat(food(-10,0,0));near(inst.components.oldager.damage_remaining,4,"runtime oldager addition preserves negative HP")
inst=player(true);inst.components.eater:Eat(food(0,-8,10))
near(inst.components.sanity.current,32,"negative sanity immediate")
equal(inst._regen2hm_queue,nil,"no invalid HP task")
inst.components.health:DoDelta(10,nil,"shadow_battleaxe")
near(inst.components.oldager.damage_remaining,0,"lifesteal still unauthorized")

-- Ordinary character food and wound behavior remains unchanged.
inst=player(false);wound(inst);inst.components.eater:Eat(food(20,10,5))
near(inst.components.health.currenthealth,20,"ordinary positive HP delayed")
near(inst.components.hunger.current,45,"ordinary hunger immediate")
inst:RunTasks(2);near(inst.components.health.currenthealth,21,"ordinary wounded first tick halves")
near(inst.components.sanity.current,41,"ordinary sanity first tick")
inst=player(false);inst.components.eater:Eat(food(-10,-8,5))
near(inst.components.health.currenthealth,10,"ordinary negative HP once, immediate")
near(inst.components.sanity.current,32,"ordinary negative sanity once")
inst=player(false);inst.components.eater:Eat(food(20,10,5));inst:RunTasks(20)
near(inst.components.health.currenthealth,40,"ordinary full delayed HP total")
near(inst.components.sanity.current,50,"ordinary full delayed sanity total")

for _,stop in ipairs({false,true})do
    for _,strength in ipairs({false,true})do
        install(false,false,stop,strength);inst=player(true)
        near(inst.components.oldager.base_rate,stop and 0 or strength and .02 or 1/40,"explicit stop-aging priority")
    end
end
print("PASS: "..assertions.." assertions (Lua 5.1; real oldager, health, eater, watch/cracked-watch callbacks and mod wrappers).")
