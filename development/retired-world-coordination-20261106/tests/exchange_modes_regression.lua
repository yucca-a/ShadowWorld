local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function execute(source, env)
    local fn = assert(loadstring(source)); setfenv(fn, env); return fn()
end
local function environment(values) return setmetatable(values or {}, {__index = _G}) end

for _, locale in ipairs({"zh", "en"}) do
    local env = environment({locale = locale})
    execute(info_source, env)
    local config, shards, names = nil, nil, {}
    for _, option in ipairs(env.configuration_options) do
        if option.name == "World Exchange" then config = option end
        if option.name == "World Exchange Shards" then shards = option end
        if option.name ~= "" then check(not names[option.name], "unique config " .. option.name); names[option.name] = true end
    end
    check(config and config.default == "hosted", "exchange defaults to master-owned spaces")
    check(#config.options == 2 and config.options[1].data == "off" and
        config.options[2].data == "hosted", "unsafe whole-chest modes no longer selectable")
    check(config.hover:find(locale == "zh" and "主世界" or "master",1,true), "settings explain master ownership")
    check(not shards, "automatic discovery removes the manual shard count setting")
end

-- Run the actual early mode selection and world-component installation.
for _, mode in ipairs({false, "traditional", "coordinated", "missing", "classic", "off"}) do
    for _, buttons in ipairs({false, true}) do
        local engine, hook = {}, nil
        local env = environment({require = function() return engine end,
            GetModConfigData = function(key)
                if key == "World Exchange" then if mode == "missing" then return nil end; return mode end
                return buttons
            end,
            AddPrefabPostInit = function(_, fn) hook = fn end})
        execute(mode_source, env)
        local canExchange, traditional = execute(container_mode_source, env)
        check(canExchange == (mode ~= "off") and traditional == nil,
            "container buttons migrate old settings and respect new explicit selections")
        local enabled = false
        check(engine.enabled == enabled, "mode and existing button gates")
        execute(install_source, env)
        for _, saved in ipairs({false, "loaded", "legacy"}) do
            engine.boot = saved and {[saved] = true} or nil
            local world = {ismastersim = true, components = {}, AddComponent = function(self) self.added = true end}
            hook(world)
            check((world.added == true) == (enabled or saved ~= false), "existing checkpoint recovery survives mode changes")
        end
    end
end

local function hostedExit()
    local shutdowns, restarts, requests = 0, 0, 0
    local serverRPC, clientRPC, token, timer, coordinated
    local handlers, queued = {MOD_HARDMODE={}}, {}
    local env = environment({TheWorld={ismastersim=false}, TheGlobalInstance={
        DoStaticTaskInTime=function(_,delay,fn)
            timer={delay=delay,run=fn,Cancel=function(self)self.cancelled=true end}; return timer
        end}, TheNet={GetIsHosting=function()return true end, GetClientTableForUser=function(_,userid)
            if userid=="host" then return {admin=true} end
            if userid=="guest" then return {admin=false} end
        end},
        handlers=handlers, queued=queued, GetModRPCHandler=function()return serverRPC end,
        Engine={EXIT_TIMEOUT=20}, engine=function()return coordinated end,
        AddModRPCHandler=function(namespace,_,fn)serverRPC=fn;handlers[namespace][1]=fn end,
        AddClientModRPCHandler=function(_,_,fn)clientRPC=fn end,
        GetModRPC=function()return 'request'end, GetClientModRPC=function()return 'ack'end,
        SendModRPCToServer=function(_,id)requests=requests+1;token=id end,
        SendModRPCToClient=function(_,_,id)clientRPC(id)end,
        AddSimPostInit=function()end})
    execute(native_exit_rpc_source,env)
    env.GLOBAL={RequestShutdown=function()shutdowns=shutdowns+1 end,DoRestart=function()restarts=restarts+1 end,
        MarkUserIDRPC=env.MarkUserIDRPC}
    execute(exit_source,env)
    local function send(sender)
        env.HandleModRPC(sender,1,"MOD_HARDMODE",1,token)
        local call=table.remove(queued,1)
        check(call~=nil,"native dispatch accepts an authenticated user before character spawn")
        call[1](call[2],call[3])
    end
    local host={userid='host'}
    env.GLOBAL.RequestShutdown()
    send('host')
    check(shutdowns==1,'host in the character lobby receives an ACK with no player entity')
    check(timer.cancelled,'ACK cancels the exit timer')
    env.GLOBAL.DoRestart(true);env.GLOBAL.DoRestart(true)
    check(requests==2 and restarts==0,'repeated exit clicks share one pending request')
    env.TheWorld=nil
    timer.run();send(host)
    check(restarts==1,'missing ACK falls back to native restart once')
    env.TheWorld={ismastersim=false}
    local saved
    env.GLOBAL.RequestShutdown()
    coordinated={Exit=function(_,cb)saved=cb end}
    send(host)
    check(shutdowns==1 and saved,'coordinated server waits for the checkpoint')
    saved()
    check(shutdowns==2,'normal shutdown follows the coordinated ACK')
    saved=nil
    send("guest");send("disconnected")
    check(saved==nil,'non-admin or disconnected senders cannot initiate a checkpoint')
end
hostedExit()

local function nativeDeparture()
    local ready, distance, moves, notices = false, 0, 0, 0
    local reject, outbound = false, {}
    local player={userid="voyager",Transform={GetWorldPosition=function()return 0,0,0 end},
        HasTag=function(_,tag)return tag=="player" end,GetDistanceSqToPoint=function()return distance end}
    local timer
    player.DoStaticPeriodicTask=function(_,_,fn)
        timer={tick=fn,Cancel=function(self)self.cancelled=true end};return timer
    end
    local world={ismastersim=true,PushEvent=function(_,_,data)
        moves=moves+1
        check(data.worldid=="4" and player.worldexchange_departure2hm=="departure","native migration retains its route and token")
        if not reject then player._despawning=true end
    end}
    local portal={Activate=function()
        world:PushEvent("ms_playerdespawnandmigrate",{player=player,worldid="4"})
        return true
    end}
    local e={core={outbound=outbound,CanMigrate=function()return ready end,IsReady=function()return false end,
        Depart=function(_,uid)outbound[uid]="departure";return outbound[uid] end},RegisterPlayer=function()end,
        service={Now=function()return 0 end,Notify=function()notices=notices+1 end}}
    execute(migration_source,environment({engine=function()return e end,
        AddPrefabPostInit=function(_,fn)fn(world)end,AddComponentPostInit=function(_,fn)fn(portal)end,
        Shard_IsWorldAvailable=function()return true end}))
    check(portal:Activate(player) and moves==0 and notices==1,"box exchange readiness never vetoes a native player portal action")
    ready=true;timer.tick()
    check(timer.cancelled and moves==1,"deferred native migration resumes once safe")
    check(outbound[player.userid]=="departure","a native despawn retains its departure")
    player._despawning=nil
    outbound[player.userid]=nil
    ready=false
    portal:Activate(player)
    distance=25;ready=true;timer.tick()
    check(timer.cancelled and moves==1,"walking away cancels an outstanding native departure")
    reject=true
    portal:Activate(player)
    check(moves==2 and not outbound[player.userid] and not player.worldexchange_departure2hm,
        "a mod-rejected native event leaves no pending departure")
    reject=false
    portal:Activate(player)
    check(moves==3 and outbound[player.userid]=="departure","the next permitted departure can proceed")
end
nativeDeparture()

local function worthyVoyage(outcome)
    local clock, ready, finishCount, cancelCount, registered, notice = 0, false, 0, 0, 0, 0
    local player={userid="voyager",IsValid=function()return true end}
    local portal={linkedWorld="4",enabled=true,SetEnabled=function(self,value)self.enabled=value end}
    local component={voyager=player,inst={components={worldmigrator=portal}},
        FinishVoyage=function(self) check(portal.enabled,"destination is still enabled for native migration")
            finishCount=finishCount+1;portal:SetEnabled(false) end,
        CancelVoyage=function(self) cancelCount=cancelCount+1;self.voyager=nil end}
    player.sg={statemem={portal=component.inst},currentstate={},timeout=6,
        SetTimeout=function(self,value) self.timeout=value end}
    local timer
    component.inst.DoStaticPeriodicTask=function(_,_,fn)
        timer={tick=fn,Cancel=function(self)self.cancelled=true end};return timer
    end
    local e={core={registrations={},outbound={},inbound={},CanMigrate=function()return ready end},service={Now=function()return clock end,
        Notify=function(_,_,code) if code=="checkpoint_pending" then notice=notice+1 end end},
        RegisterPlayer=function()registered=registered+1 end}
    execute(worthy_source,environment({MIGRATION_TIMEOUT=20,engine=function()return e end,
        AddComponentPostInit=function(name,fn)check(name=="worthyportal");fn(component)end,
        Shard_IsWorldAvailable=function()return outcome~="disconnect" end}))
    component:FinishVoyage(player)
    component:FinishVoyage(player)
    check(registered==1 and finishCount==0 and portal.enabled,"one pending voyage retains its selected destination")
    if outcome=="cancel" then component:CancelVoyage(player)
    else
        if outcome=="ready" then
            timer.tick()
            check(player.sg.timeout>10,"voyage stays active through a longer four-shard save")
            clock,ready=12,true
        end
        if outcome=="timeout" then clock=21 end
        timer.tick()
    end
    check(timer.cancelled and not portal.enabled,"completed or cancelled voyage clears its timer and disables the portal")
    check(finishCount==(outcome=="ready" and 1 or 0),"only a ready voyage invokes native migration")
    check(cancelCount==(outcome~="ready" and 1 or 0),"failed or cancelled voyage exits normally")
    check(notice==((outcome=="timeout" or outcome=="disconnect") and 1 or 0),"blocked voyage tells the player to retry")
end
for _,outcome in ipairs({"ready","cancel","disconnect","timeout"}) do worthyVoyage(outcome) end

-- The retained button invokes the vault; it never destroys or swaps local goods.
for _, enabled in ipairs({false,true}) do
    local calls,status=0,0
    local player={IsValid=function()return true end}
    local box={prefab="shadow_container",IsValid=function()return true end,
        HasTag=function()return false end,components={container={openlist={[player]=true}}}}
    local handlers={}
    local world={ismastersim=true,components={shadowvault2hm={
        Request=function(_,p,c)check(p==player and c==box,"exact button target");calls=calls+1 end,
        Status=function()status=status+1 end}}}
    execute(exchange_source,environment({worldexchangecfg=enabled,TheWorld=world,
        AddModRPCHandler=function(_,name,fn)handlers[name]=fn end}))
    handlers.exchangebtn2hm(player,box)
    handlers.exchangestatus2hm(player,box)
    check(calls==(enabled and 1 or 0) and status==calls,"vault buttons respect disable option")
    box.components.container.openlist={}
    handlers.exchangebtn2hm(player,box)
    check(calls==(enabled and 1 or 0),"closed container cannot switch pages")
    box.components.container.openlist[player]=true;box.prefab="rabbitkinghorn_container"
    handlers.exchangebtn2hm(player,box)
    check(calls==(enabled and 1 or 0),"non-shadow pocket container is not rerouted")
    check(handlers.pausebtn2hm==nil,"old server pause RPC removed")
end

-- Checkpoint draining must wait for all upstream exchange timer stages.
local Engine = {}
execute(idle_source, environment({Engine = Engine, AllPlayers = {}}))
local e = setmetatable({service = {protocol = {}, inst = {components = {}, PocketDimensionContainers = {shadow = {}}}},
    Writing = function() return false end}, {__index = Engine})
for _, field in ipairs({"containersendtask2hm", "containerreceivetask2hm", "exchangeconfirmtask2hm"}) do
    e.service.inst.PocketDimensionContainers.shadow[field] = {}
    check(not e:Idle(), "cannot checkpoint temporary contents during " .. field)
    e.service.inst.PocketDimensionContainers.shadow[field] = nil
end
check(e:Idle(), "checkpoint can proceed after legacy completion or timeout")
print("Exchange mode checks: " .. checks .. " (Lua 5.1; native serializer; simulated shards/timers)")
