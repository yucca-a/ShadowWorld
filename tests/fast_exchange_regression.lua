local Store, Core, Fast = worldexchangestore2hm, worldexchangecheckpoint2hm, worldexchangeinstant2hm
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end
local function encode(t) return DataDumper(t, nil, true) end
local function simulation()
    local s = {now = 0, queue = {}, wire = {}, nodes = {}, saves = 0, boots = 0}
    function s:defer(fn) table.insert(self.queue, fn) end
    function s:node(id, disk, loaded, requested)
        self.boots = self.boots + 1
        local n = {id = id, disk = disk or {}, boot = tostring(self.boots), items = id == "1" and "gold" or "rocks", savecount = 0}
        self.nodes[id] = n
        n.store = Store.new({
            read = function(k,cb) self:defer(function() cb(n.disk[k] ~= nil,n.disk[k]) end) end,
            write = function(k,v,cb) self:defer(function() n.disk[k]=v; cb(true) end) end,
            erase = function(k) n.disk[k] = nil end, encode=encode, decode=RunInSandboxSafe,
        }, "SESSION" .. id)
        n.store:Load(function(state, err)
            assert(state,err)
            if loaded == true then loaded = state.forced or state.current end
            if loaded then
                local cut = state.cuts[loaded]
                n.items = n.disk[cut.world]
            end
            n.core = Core.new({
                id=id, boot=n.boot, master=id=="1", now=function() return self.now end,
                bootready=function() return true end,
                connected=function(peer,boot) return self.nodes[peer] and self.nodes[peer].boot==boot and not self.disconnected and
                    not (self.stopped and self.stopped[peer]) end,
                send=function(peer,m) table.insert(self.wire,{from=id,to=peer,target=self.nodes[peer].boot,m=Store.Copy(m)}) end,
                idle=function() return not n.protocol.active end,
                log=function(msg) n.error=msg end,
                restart=function() n.restart=true end,
                save=function(cut,owners)
                    self.saves=self.saves+1; n.savecount=n.savecount+1
                    local players = {}
                    for uid in pairs(owners) do players[uid] = false end
                    self:defer(function() n.core:Saved({id=cut.id,serial=cut.serial,owners=Store.Copy(owners),players=players},n.items) end)
                end,
            },n.store,loaded,requested)
            n.protocol = Fast.new({
                id=id,session="SESSION"..id,boot=n.boot,now=function() return self.now end,
                peer_session=function(peer) return "SESSION"..peer end,
                send=function(peer,m) table.insert(self.wire,{from=id,to=peer,target=self.nodes[peer].boot,m=Store.Copy(m)}) end,
                lock=function() n.lock=true; return true end, unlock=function() n.lock=false end,
                snapshot=function() return {items=n.items} end, validate=function() return true end,
                apply=function(_,data) n.items=data.items; return true end,
                checkpoint=function() error("per-trade save") end,notify=function() end,log=function() end,
            },nil,n.core)
        end)
        return n
    end
    function s:step()
        self.now=self.now+.05
        local queue=self.queue; self.queue={}; for _,fn in ipairs(queue) do fn() end
        if self.observe then self:observe() end
        for id,n in pairs(self.nodes) do
            if n.core and not self.disconnected and not (self.stopped and self.stopped[id]) then
                for peer,p in pairs(self.nodes) do
                    if peer~=id and p.core and not (self.stopped and self.stopped[peer]) and
                        (n.core.peers[peer]~=p.boot or n.core.offline[peer]) then
                        n.core:Connected(p.id,p.boot)
                    end
                end
                n.core:Tick(); n.protocol:Tick()
            end
        end
        local wire=self.wire; self.wire={}
        if self.shape then wire = self:shape(wire) end
        for _,packet in ipairs(wire) do
            if self.nodes[packet.to].core and packet.target==self.nodes[packet.to].boot and not self.disconnected and
                not (self.stopped and self.stopped[packet.to]) and (not self.filter or self.filter(packet)) then
                local n=self.nodes[packet.to]
                if packet.m.v==3 then n.core:Receive(packet.from,packet.m)
                else n.protocol:Receive(packet.from,packet.m) end
            end
        end
    end
    function s:until_(test,label,steps)
        for _=1,steps or 1000 do self:step(); if test() then return end end
        error(label.." timed out: "..tostring(self.nodes["1"].core.phase).." / "..tostring(self.nodes["2"].core.phase))
    end
    function s:ready() return self.nodes["1"].core and self.nodes["2"].core and self.nodes["1"].core:IsReady() and self.nodes["2"].core:IsReady() end
    function s:start()
        self:node("1");self:node("2");self:until_(function() return self:ready() end,"initial connection")
        self.nodes["1"].core:Request()
        self:until_(function() return self:ready() and self.nodes["1"].core.generation ~= nil end,"initial cut")
    end
    function s:trade()
        check(self.nodes["1"].protocol:Start("chest","2","u"),"fast start")
        self:until_(function() return not self.nodes["1"].protocol.active and not self.nodes["2"].protocol.active end,"trade")
    end
    return s
end

-- Fresh/regenerated sessions wait without saving or disabling movement.
-- A lost initial INFO must not strand the secondary after the master is ready.
local fresh=simulation();fresh:node("1");fresh:node("2")
local lostinfo=false
fresh.filter=function(p)
    if p.from=="1" and p.m.op=="INFO" and not lostinfo then lostinfo=true;return false end
    return true
end
fresh:until_(function()return fresh:ready()end,"fresh discovery after lost INFO")
for _=1,200 do fresh:step()end
check(lostinfo and fresh.saves==0,"new world entry does not add a full paired save")
local fa,fb=fresh.nodes["1"],fresh.nodes["2"]
check(not fa.core.generation and not fb.core.generation,"discovery does not invent a shared checkpoint")
check(not fa.protocol:Start("chest","2","u"),"exchange still requires a durable first cut")
fa.protocol:Receive("2",{v=2,kind="PREPARE",checkpoint=nil})
check(not fa.protocol.active,"nil checkpoint packets cannot bypass first-cut protection")
fresh.disconnected=true;fa.core:Disconnected("2");fb.core:Disconnected("1")
check(not fa.core:IsReady() and not fb.core:IsReady(),"disconnect still blocks cross-world operations")
fresh.disconnected=false
fresh:until_(function()return fresh:ready()end,"fresh reconnect")
fresh:node("2")
fresh:until_(function()return fresh:ready()end,"fresh peer reboot")
fb=fresh.nodes["2"]
check(fresh.saves==0,"peer startup does not impose a new checkpoint")
fa.core:Register("early-traveller","1",false)
fresh:until_(function()return not fa.core.regbusy end,"new player before first cut")
check(fa.core:CanMigrate("early-traveller"),"native cave travel need not wait for a first exchange")
local earlytoken=fa.core:Depart("early-traveller")
fb.core:Register("early-traveller","2",false,function()fb.core:Arrived("early-traveller",earlytoken,"1")end)
fresh:until_(function()return not fa.core.outbound["early-traveller"] and not fb.core.inbound["early-traveller"]end,"arrival before first cut")
check(fa.core.owners["early-traveller"]=="2" and fb.core.owners["early-traveller"]=="2" and fresh.saves==0,
    "early cave travel reconciles ownership before the first requested save")
local requested=0
fb.core:Request(function()requested=requested+1 end)
fresh:until_(function()return fresh:ready() and requested==1 end,"secondary requests first cut")
check(fresh.saves==2 and fa.core.generation==fb.core.generation,"first real request commits one matching pair")
fresh:trade()
check(fresh.saves==2,"first use keeps subsequent exchanges save-free")
local failedfresh=simulation();failedfresh:node("1");failedfresh:node("2")
failedfresh:until_(function()return failedfresh:ready()end,"fresh failure test")
local ff=failedfresh.nodes["1"]
ff.core:Fail("injected_registration_failure")
ff.core:Disconnected("2");ff.core:Connected("2","rebooted")
check(not ff.core:IsReady() and ff.core.phase=="error","reconnect never bypasses a storage failure")

local s=simulation();s:start()
check(s.saves==2,"one initial paired cut")
for _=1,20 do s:trade() end
check(s.saves==2,"twenty exchanges cause zero saves")
check(s.nodes["1"].items=="gold" and s.nodes["2"].items=="rocks","items conserved")
local completed=false
s.nodes["2"].core:Request(function() completed=true end)
s:until_(function() return completed and s:ready() end,"normal save")
check(s.saves==4,"manual/automatic request saves both once")

-- Drop the first occurrence of each message. Suppress all CAPTURED messages
-- to verify that an older secondary's PREPARED still advances the save.
for _,op in ipairs({"INFO","FREEZE","DRAINED","CAPTURE","CAPTURED","PREPARED","SEAL","SEALED","ACTIVATE","ACTIVE","OPEN","REQUEST"}) do
    local t=simulation();local dropped=false
    t.filter=function(p)
        if p.m.op==op and (not dropped or op=="CAPTURED") then dropped=true;return false end
        if p.m.v==3 then t.nodes[p.to].core:Receive(p.from,p.m) end
        return true
    end
    t:start();local done=false;t.nodes["2"].core:Request(function() done=true end)
    t:until_(function() return done and t:ready() end,"lost "..op)
    check(dropped,"exercised "..op);check(t.saves==4,"no duplicate save "..op)
end

-- A normal checkpoint must drain an exchange already in flight.
local t=simulation();t:start();t.nodes["1"].protocol:Start("chest","2","u")
t.nodes["1"].core:Request();t:until_(function() return t.saves==4 and t:ready() end,"drain")
check(t.nodes["1"].items=="rocks" and t.nodes["2"].items=="gold","cut contains completed trade")

-- A transient disconnection resumes without rollback; a new peer process does not.
t:trade();local a,b=t.nodes["1"],t.nodes["2"]
t.disconnected=true;a.core:Disconnected("2");b.core:Disconnected("1")
check(not a.core:CanExchange("2") and not b.core:CanExchange("1"),"disconnect gates exchanges on both shards")
t.disconnected=false;t:until_(function() return t:ready() end,"same boot reconnect")
check(not a.restart and not b.restart,"reconnect does not restart")
t:node("2",b.disk,true)
t:until_(function() return a.restart end,"live peer forced recovery")
check(a.store.state.forced~=nil,"recovery decision durable before restart")
t:node("1",a.disk,true);t:until_(function() return t:ready() end,"paired restore")
check(t.nodes["1"].items=="rocks" and t.nodes["2"].items=="gold","both worlds restored to exact common cut")
local fresh=t.nodes["1"]
fresh.items="crafted after checkpoint" -- no new fast exchange at all
t:node("2",t.nodes["2"].disk,true)
t:until_(function()return fresh.restart end,"ordinary gameplay also rolls back with restarted peer")
check(fresh.restart,"live world is not mistaken for its loaded snapshot")

local rollback=simulation();rollback:start()
local oldest=rollback.nodes["1"].core.generation
rollback:trade();rollback.nodes["1"].core:Request()
rollback:until_(function()return rollback:ready() and rollback.saves==4 end,"second retained cut")
local olddisk,newdisk=rollback.nodes["1"].disk,rollback.nodes["2"].disk
rollback=simulation();rollback:node("1",olddisk,true,oldest);rollback:node("2",newdisk,true)
for _=1,1000 do
    rollback:step()
    for id,n in pairs(rollback.nodes) do if n.restart then rollback:node(id,n.disk,true) end end
    if rollback:ready() then break end
end
check(rollback:ready() and rollback.nodes["1"].core.generation==oldest and rollback.nodes["2"].core.generation==oldest,"manual rollback coordinates both worlds")
check(rollback.nodes["1"].items=="gold" and rollback.nodes["2"].items=="rocks","manual rollback restores matching items")

-- New UID records are durable locally and remotely before migration is permitted.
local u=simulation();u:start();local left,right=u.nodes["1"],u.nodes["2"]
u.disconnected=true
left.core:Disconnected("2")
local registered=false;left.core:Register("NEW","1","BEFORE",function() registered=true end)
local secondCallback=false
left.core:Register("NEW","1","BEFORE",function() secondCallback=true end)
check(not registered and not secondCallback,"spawn waits for the local before-image to be durable")
check(not left.core:CanMigrate("NEW"),"registration gates migration")
u:until_(function() return registered and secondCallback end,"local registration without a peer")
for _,cut in pairs(left.store.state.cuts) do check(cut.players.NEW=="BEFORE","owner before-image") end
check(left.core.regbusy and not left.core:CanMigrate("NEW") and not left.core:CanExchange("2"),
    "local registration releases login while leaving cross-shard gates closed")
u.disconnected=false
u:until_(function() return left.core:CanMigrate("NEW") end,"registration acknowledged on the peer")
for _,cut in pairs(right.store.state.cuts) do check(cut.players.NEW==false,"peer tombstone") end
left.core.io.bootready=function()return false end
check(not left.core:CanExchange("2") and not left.core:CanReceive("2") and not left.core:CanMigrate("NEW"),
    "local rollback preparation closes all cross-shard gates even with an established peer")
left.core.io.bootready=function()return true end
left.core:Begin()
check(left.core:CanMigrate("NEW") and not left.core:CanExchange("2"),
    "player travel can start while the checkpoint is draining and box exchange is closed")
local migration = left.core:Depart("NEW")
for _=1,20 do u:step() end
check(u.saves==2,"pending migration blocks checkpoint")
check(not right.core:CanMigrate("NEW"),"a shard that finalized its owner map cannot start another migration")
right.core:Arrived("NEW",migration,"1");u:until_(function() return u.saves==4 and u:ready() end,"migration drain")
check(left.core.owners.NEW=="2" and right.core.owners.NEW=="2","migration owns one side")
local returning = right.core:Depart("NEW")
left.core:Arrived("NEW",returning,"2")
u:until_(function() return not next(left.core.inbound) and not next(right.core.outbound) end,"return migration")
left.core:Receive("2",{v=3,kind="CHECKPOINT",op="ARRIVED",uid="NEW",token=migration})
check(left.core.owners.NEW=="1" and right.core.owners.NEW=="1","late migration message cannot reverse ownership")
local cancelled = left.core:Depart("NEW")
left.core:Arrived("NEW",cancelled,"1")
check(not next(left.core.outbound),"failed native migration may return to source")

-- Pause native capture, then pause only the backup. The return trip should
-- proceed while the same checkpoint is still being written.
local travel=simulation();travel:start()
local surface,cave=travel.nodes["1"],travel.nodes["2"]
local traveller="CAVE_TRAVELLER"
surface.core:Register(traveller,"1",false)
travel:until_(function() return surface.core:CanMigrate(traveller) end,"register cave traveller")
cave.core:Arrived(traveller,surface.core:Depart(traveller),"1")
travel:until_(function() return cave.core:CanMigrate(traveller) end,"initial cave arrival")
local capture, verify
local putCut=cave.store.PutCut
cave.store.PutCut=function(self,...)
    local args={...}
    verify=function()putCut(self,unpack(args))end
end
local nativeSave=cave.core.io.save
cave.core.io.save=function(cut,owners)
    capture=function()nativeSave(cut,owners)end
end
surface.core:Request()
travel:until_(function() return capture~=nil end,"cave capture requested")
check(not cave.core:CanMigrate(traveller,"1"),"travel waits for uncaptured cave snapshot")
surface.core:Receive("2",{v=3,kind="CHECKPOINT",op="TRAVEL_OPEN",id=surface.core.pending.id})
check(not surface.core:CanMigrate(traveller,"2"),"a secondary cannot reopen travel")
capture()
local dropped=false
travel.filter=function(packet)
    if packet.m.op=="TRAVEL_OPEN" and not dropped then dropped=true;return false end
    return true
end
travel:until_(function() return verify and cave.core:CanMigrate(traveller,"1") end,"native cave exit while backup verifies")
check(dropped and cave.core.phase=="saving" and not cave.core:CanExchange("1"),
    "retried travel release opens migration while exchange is still locked")
surface.core:Arrived(traveller,cave.core:Depart(traveller),"2")
travel:until_(function() return not surface.core.inbound[traveller] end,"arrive before backup completes")
verify()
travel:until_(function() return travel:ready() end,"complete checkpoint after cave exit")
for _,node in pairs(travel.nodes) do
    check(node.store.state.cuts[node.core.generation].owners[traveller]=="2","backup retains pre-travel owner")
    check(node.core.owners[traveller]=="1","live owner remains at the destination")
end

-- Reloading either side during each checkpoint stage selects a common complete
-- cut. Replayed/truncated stages never release one world's newer items alone.
for _,stage in ipairs({"draining","frozen","saving","prepared","sealing","sealed","activating","ready"}) do
    local f=simulation();f:start();f:trade();local old=f.nodes["1"].core.generation
    local da,db
    f.observe=function()
        if not da and f.nodes["1"].core.phase==stage and (stage~="ready" or f.nodes["1"].core.generation~=old) then
            da,db=Store.Copy(f.nodes["1"].disk),Store.Copy(f.nodes["2"].disk)
        end
    end
    f.nodes["1"].core:Begin();f:observe()
    f:until_(function() f:observe();return da~=nil end,"reach "..stage)
    -- Flush no callbacks after power loss. A torn first commit is allowed to
    -- stop safely; existing committed records must still verify.
    local reboot=simulation();reboot:node("1",da,true);reboot:node("2",db,true)
    for _=1,1000 do
        reboot:step()
        for id,n in pairs(reboot.nodes) do
            if n.restart then reboot:node(id,n.disk,true) end
        end
        if reboot:ready() then break end
    end
    check(reboot:ready(),"recover interrupted "..stage)
    local x,y=reboot.nodes["1"].items,reboot.nodes["2"].items
    check((x=="gold" and y=="rocks") or (x=="rocks" and y=="gold"),"paired conservation "..stage)
    check(reboot.nodes["1"].core.generation==reboot.nodes["2"].core.generation,"same generation "..stage)
end

-- Interrupted committed journal never falls back to stale player inventories.
local disk=Store.Copy(left.disk);local prefix=left.store.prefix
disk[prefix.."_bank"..(left.store.state.revision%2)]="torn"
local broken=Store.new({read=function(k,cb)cb(disk[k]~=nil,disk[k])end,decode=RunInSandboxSafe},"SESSION1")
local failure;broken:Load(function(state,reason)failure=reason;check(state==nil,"corrupt committed bank rejected")end)
check(failure=="corrupt_committed_journal","explicit corruption reason")
disk[prefix.."_head"]=nil;broken:Load(function(state,reason)check(not state and reason=="missing_commit_pointer","missing head fails closed")end)

-- Exact native-world assembly, including per-prefab entity sections.
local Engine=worldexchangeengine2hm
local cuts={current="c/2",nextserial=2,cuts={["c/1"]={serial=1},["c/2"]={serial=2}}}
check(Engine.ResolveCut(cuts,{checkpoint="c/3",checkpoint_serial=3})=="c/2","native save before backup commit recovers previous committed cut")
check(Engine.ResolveCut(cuts,{checkpoint="c/0",checkpoint_serial=0})==nil,"missing historical cut is not guessed")
local selected,reason,manual=Engine.ResolveCut(cuts,{checkpoint="c/1",checkpoint_serial=1})
check(selected=="c/1" and manual and not reason,"native older marker supplies manual cap")
local sections={meta=encode({session_identifier="TEST"}),map=encode({persistdata={checkpoint="cut"}}),ents={goldnugget=encode({{data={stackable={stack=9}}}})}}
local ok,world=RunInSandboxSafe(Engine.AssembleWorld(sections))
check(ok and world.ents.goldnugget[1].data.stackable.stack==9,"world sections round-trip")

-- Native player writes may occur while asynchronous offline reads/copy writes
-- are pending. They may not change a cut after its world was serialized.
local capture={players={},owners={}}
local e=setmetatable({service={id="1"},revisions={},capture=capture},Engine)
e.RegisterPlayer=function(_,uid,baseline,cb) cb() end
local written
TheNet={SerializeUserSession=function(_,uid,raw)written=raw end,DeleteUserSession=function()end}
e:PlayerWrite("u","before",false,nil,"meta")
e:WorldSerialized(sections)
e:PlayerWrite("u","after",false,nil,"meta")
check(capture.players.u=="before" and written=="after","later player write cannot mutate completed checkpoint")
check(e.live==nil,"ordinary writes do not retain every past user's full profile")

-- A logout/new save can finish while Capture waits for an offline read. The
-- existing snapshot is the only necessary race buffer, including tombstones.
local oldSave=Engine.nativeSave
for _,deleting in ipairs({false,true}) do
    local pending,complete
    local racing=setmetatable({service={id="1"},revisions={},core={Saved=function(_,snapshot)complete=snapshot end}},Engine)
    racing.ReadPlayer=function(_,uid,cb)pending=cb end
    racing.RegisterPlayer=function(_,uid,raw,cb)cb()end
    TheNet.GetCurrentSnapshot=function()return 3 end
    Engine.nativeSave=function(_,cb)racing:WorldSerialized(sections);cb()end
    racing:Capture({id="race",serial=3},{u="1"})
    local latest=not deleting and "latest" or false
    racing:PlayerWrite("u",latest,false,nil,nil,deleting)
    pending("stale-read")
    check(complete and complete.players.u==latest,"in-flight write wins over stale offline read")
    check(not racing.live and not racing.capture,"completed capture retains no extra live-profile cache")
end
Engine.nativeSave=oldSave

-- Native tombstones are empty files; truncate future snapshots before verifying
-- them. Failed verification stays closed without a SimPostInit mod-disable throw.
local truncated=false
Engine.boot={session="TEST",players={new=false,old="return {prefab='wilson'}"}}
TheWorld={ismastersim=true}
TheNet={TruncateSnapshots=function()truncated=true end,DeleteUserSession=function()check(truncated,"truncate before tombstone")end,
    SerializeUserSession=function()check(truncated,"truncate before restore")end,GetUserSessionFile=function(_,session,uid)return uid end,
    DeserializeUserSession=function(_,uid,cb)cb(true,uid=="old" and Engine.boot.players.old or "")end}
Engine.RestorePlayers()
check(Engine.boot.ready,"verified native player boot")
check(Engine.boot.players == nil,"verified boot releases cached player/map records")
Engine.boot={session="TEST",players={new=false,old="return {prefab='wilson'}"}}
TheNet.DeserializeUserSession=function(_,uid,cb)cb(true,"return {prefab='wrong'}")end
Engine.RestorePlayers()
check(not Engine.boot.ready and Engine.boot.error,"failed restore remains blocked")

-- Exit callers may stop the master immediately; a secondary that has already
-- received ACTIVATE knows the shared cut is durable even if OPEN is lost.
local leaving=simulation();leaving:start()
local exits={}
leaving.filter=function(p) return p.m.op~="OPEN" end
leaving.nodes["1"].core:Request(function()exits[1]=true end,true)
leaving.nodes["2"].core:Request(function()exits[2]=true end,true)
leaving:until_(function()return exits[1]end,"master exit")
check(exits[2],"secondary exit completes with committed proof even if OPEN is lost and no disconnect is delivered")
check(leaving.nodes["1"].store.state.current==leaving.nodes["2"].store.state.current,"exit uses same durable cut")
local clusterExit=simulation()
for i=1,4 do clusterExit:node(tostring(i)) end
clusterExit:until_(function()
    for _,n in pairs(clusterExit.nodes) do if not n.core or not n.core:IsReady() then return false end end
    return true
end,"four-shard exit setup")
local completed, missed = {}, false
clusterExit.filter=function(p)
    if p.to=="4" and p.m.op=="ACTIVATE" and not missed then missed=true; return false end
    return p.m.op~="OPEN"
end
for id,n in pairs(clusterExit.nodes) do n.core:Request(function() completed[id]=true end,true) end
clusterExit:until_(function()return missed and completed["2"] end,"one secondary receives committed proof")
clusterExit.stopped={["2"]=true}
check(not completed["1"] and not completed["4"],"master cannot quit before online peers receive committed proof")
clusterExit:until_(function()return completed["1"] and completed["3"] and completed["4"]end,
    "master retries activation after a secondary has already quit")
local extraSaves=0
Engine.nativeSave=function()extraSaves=extraSaves+1 end
local ended=false
local exitEngine=setmetatable({core={generation="saved"}},Engine)
exitEngine:SaveRequested(true,function()ended=true end)
check(ended and extraSaves==0,"post-despawn shutdown does not take another world snapshot")
local lateExit=setmetatable({service={Now=function()return 0 end},core={generation="cut",exitready=true,Request=function()error("second exit must reuse the shared cut")end}},Engine)
local lateEnded=false;lateExit:Exit(function()lateEnded=true end)
check(not lateEnded and lateExit.exits[1].at==.5,"exit lets final acknowledgements leave")
lateExit.exits[1].callback();check(lateEnded,"second exit reuses already sealed pair")

-- Deleted/offline players remain tombstones when the next cut is captured.
local tombstoneEngine=setmetatable({service={session="TEST"},core={Fail=function()error("tombstone misread")end}},Engine)
TheNet={GetUserSessionFile=function()return "deleted"end,DeserializeUserSession=function(_,path,cb)cb(true,"")end}
local tombstone;tombstoneEngine:ReadPlayer("deleted",function(raw)tombstone=raw end)
check(tombstone==false,"native empty session means deleted player")

local exitClock,exitCount,acknowledge=0,0,nil
AllPlayers={}
local offlineExit=setmetatable({service={Now=function()return exitClock end},store={state={registry={}},queue={}},
    core={generation="cut",opened=true,suspended=true,Request=function(_,cb)acknowledge=cb end,
        Tick=function()end,IsReady=function()return false end}},Engine)
offlineExit:Exit(function()exitCount=exitCount+1 end)
offlineExit:Update();exitClock=1;offlineExit:Update()
check(exitCount==1,"offline peer does not trap normal exit")
acknowledge();exitClock=2;offlineExit:Update()
check(exitCount==1,"late checkpoint callback cannot exit twice")
local stuckExited=false
local stuck=setmetatable({service={Now=function()return exitClock end},store={state={registry={},cuts={cut={}}},queue={}},
    timeline_wait=true,core={generation="cut",phase="joining",io={},AllPeers=function()return true end,Request=function()end}},Engine)
stuck:Exit(function()stuckExited=true end)
stuck:Update()
check(not stuckExited,"exit allows time for a healthy recovery to finish")
exitClock=exitClock+Engine.EXIT_TIMEOUT;stuck:Update()
exitClock=exitClock+1;stuck:Update()
check(stuckExited and stuck.store.state.cuts.cut,"a stalled handshake cannot block exit or discard the last cut")
for _,ackReceived in ipairs({false,true}) do
    local count, complete=0,nil
    local paused=setmetatable({service={Now=function()return 0 end},
        core={generation="cut",Request=function(_,cb)complete=cb end}},Engine)
    paused:Exit(function()count=count+1 end)
    if ackReceived then complete() end
    paused.core.suspended=true
    paused:PeerDisconnected()
    complete()
    paused:PeerDisconnected()
    check(count==1,"disconnect finishes a requested shutdown even without any later static updates")
end

-- Early rollback notice starts the live cave reload before the master exits.
local early=simulation();early:start()
local target=early.nodes["1"].core.generation
early:trade();early.nodes["1"].core:Request()
early:until_(function()return early:ready() and early.saves==4 end,"early rollback second cut")
local primary,cave=early.nodes["1"],early.nodes["2"]
local function hint(core,peer,id,serial)core:Receive(peer,{v=3,kind="CHECKPOINT",op="ROLLBACK_HINT",id=id,serial=serial})end
hint(cave.core,"wrong",target,1)
check(not cave.restart and cave.core:IsReady(),"unrelated shard cannot request early rollback")
hint(primary.core,"2",target,1)
check(not primary.restart and primary.core:IsReady(),"secondary cannot rewind master with a hint")
hint(cave.core,"1","missing",1);hint(cave.core,"1",target,999)
check(not cave.restart and cave.core:IsReady(),"unknown or mismatched target hint is ignored")
hint(cave.core,"1",target,1)
check(not cave.core:IsReady(),"valid hint closes cross-shard operations before loading target")
early:until_(function()return cave.restart end,"cave starts early rollback")
check(cave.store.state.forced==target and cave.core.requested==target,"early target durable before restart")
hint(cave.core,"1",target,1)
check(cave.store.state.forced==target,"duplicate hint cannot reverse selection")
early:node("1",primary.disk,target,target);early:node("2",cave.disk,true)
early:until_(function()return early:ready()end,"early paired recovery")
check(early.nodes["1"].core.generation==target and early.nodes["2"].core.generation==target,"early notice still requires paired verification")
check(early.nodes["1"].items=="gold" and early.nodes["2"].items=="rocks","early rollback conserves target inventories")

-- Multiplayer round trips must not race an unacknowledged arrival. Hold only
-- that player's next migration, while unrelated players can keep moving.
local mp=simulation();mp:start()
local ma,mb=mp.nodes['1'],mp.nodes['2']
for _,uid in ipairs({'A','B','C'}) do
    ma.core:Register(uid,'1','before-'..uid)
end
mp:until_(function()return not ma.core.regbusy and not mb.core.regbusy end,'multiplayer registration')
for round=1,12 do
    local uid=({'A','B','C'})[(round-1)%3+1]
    local from=ma.core.owners[uid]=='1' and ma or mb
    local to=from==ma and mb or ma
    local token=from.core:Depart(uid)
    to.core:Arrived(uid,token,from.id)
    local drops=0
    mp.filter=function(p)
        if p.m.op=='ARRIVED_ACK' and drops<3 then drops=drops+1;return false end
        return true
    end
    check(not to.core:CanMigrate(uid),'arrival pending blocks only a second departure for same player')
    check(not from.core:CanMigrate(uid),'source cannot overlap its pending departure')
    local other=uid=='A' and 'B' or 'A'
    local otherowner=ma.core.owners[other]=='1' and ma or mb
    check(otherowner.core:CanMigrate(other),'pending arrival does not block an unrelated player')
    mp:until_(function()return not from.core.outbound[uid] and not to.core.inbound[uid]end,'lost migration ACK')
    check(from.core.owners[uid]==to.id and to.core.owners[uid]==to.id,'both owners converge after lost ACK')
    mp.filter=nil
    ma.core:Request()
    mp:until_(function()return mp:ready() and not ma.core.want end,'checkpoint after multiplayer migration')
    mp:trade()
end
-- A stale owner map must still allow unrelated arrival/registration retries.
local sent={}
local stale=setmetatable({io={id='1',master=true,now=function()return 10 end,connected=function()return true end,
    send=function(_,m)sent[m.op]=true end},peer='2',peerboot='b',phase='frozen',pending={id='c'},
    peers={['2']='b'},offline={},members={['1']=true,['2']=true},peerdrained={['2']={A='2'}},owners={A='1'},lastsend=-100,
    registrations={B={localdone=true,owner='1'}},inbound={C='token'}},Core)
stale:Tick()
check(sent.REGISTER and sent.ARRIVED and sent.FREEZE,'owner disagreement cannot starve control retries')
check(stale.phase=='frozen','owner disagreement must not save inconsistent player ownership')

local writes,wakes=0,0
local already=setmetatable({io={idle=function()return true end,wake=function()wakes=wakes+1 end,
    send=function()end},peer='2',loaded='c',phase='joining',
    store={state={current='c',cuts={c={}}},Seal=function(_,_,cb)writes=writes+1;cb(true)end}},Core)
already:Select('c',false)
check(writes==0 and wakes==1 and already.phase=='activating' and already.lastsend==-100,
    'verified current checkpoint activates without rewriting its journal or waiting for resend timer')
already.phase='joining';already.store.state.forced='c'
already:Select('c',false)
check(writes==1,'forced recovery still seals its journal before activation')

local four=simulation()
local forest,caves,islands=four:node("1"),four:node("2"),four:node("3")
four:until_(function()return forest.core end,"read initial journal")
forest.core:Discover("4")
for _=1,60 do four:step() end
check(not forest.core:IsReady() and four.saves==0,"three online shards cannot start a four-shard timeline")
local cold=simulation()
local coldForest=cold:node("1",forest.disk)
cold:node("2",caves.disk);cold:node("3",islands.disk)
for _=1,100 do cold:step() end
check(coldForest.core.members["4"] and not coldForest.core:IsReady() and cold.saves==0,
    "remembered shard remains required after a cold restart before the first checkpoint")
local localSaved=false
local incomplete=setmetatable({core=forest.core,store=forest.store},Engine)
local nativeSave=Engine.nativeSave
Engine.nativeSave=function(_,done)done()end
incomplete:SaveRequested(false,function()localSaved=true end)
Engine.nativeSave=nativeSave
check(localSaved,"incomplete fresh cluster can still take local native saves")
local volcano=four:node("4")
local shards={forest,caves,islands,volcano}
local function fourready()
    for _,node in ipairs(shards) do if not node.core or not node.core:IsReady() then return false end end
    return true
end

-- The next save may start while one shard is still waiting for a lost OPEN.
local overlap=simulation()
overlap:node("1");overlap:node("2");overlap:node("3");overlap:node("4")
local function overlapReady()
    for _, node in pairs(overlap.nodes) do
        if not node.core or not node.core:IsReady() then return false end
    end
    return true
end
overlap:until_(overlapReady,"overlapping save setup")
local primary=overlap.nodes["1"]
local droppedOpen
overlap.filter=function(p)
    if p.to=="4" and p.m.op=="OPEN" and not droppedOpen then droppedOpen=true; return false end
    return true
end
primary.core:Request()
overlap:until_(function()return droppedOpen and primary.core:IsReady()end,"one shard misses OPEN")
check(not overlap.nodes["4"].core:IsReady(),"fourth shard is still waiting for confirmation")
primary.core:Request()
overlap:until_(function()return overlapReady() and overlap.saves==8 end,"second save after lost OPEN")
primary.core:Connected("4","restarted")
overlap.wire={}
primary.core:Receive("4",{v=3,kind="CHECKPOINT",op="ACTIVE",id=primary.core.generation})
check(#overlap.wire==0,"a stale acknowledgement cannot reopen a shard while reconciling a restart")
four:until_(fourready,"four shards discover one another")
local order={}
local overlappedVerification=false
for _,node in ipairs(shards) do
    local save=node.core.io.save
    node.core.io.save=function(cut,owners)
        local capturing,saving=0,0
        for _,participant in ipairs(shards) do
            local core=participant.core
            if core.phase=="saving" then
                saving=saving+1
                if core.captured~=core.pending.id then capturing=capturing+1 end
            end
        end
        assert(capturing==1,"only one shard serializes at a time")
        assert(saving<=2,"at most two native captures and backup checks overlap")
        if saving>1 then overlappedVerification=true end
        order[#order+1]=node.id
        save(cut,owners)
    end
end
four.filter=function(packet)
    if packet.m.op=="SEAL" then
        for _,node in ipairs(shards) do
            assert(node.store.state.cuts[packet.m.id],"all backups are durable before sealing")
        end
    end
    return true
end
volcano.core:Request()
four:until_(function()return fourready() and four.saves==4 end,"first four-shard checkpoint")
check(table.concat(order,",")=="1,2,3,4","four native saves are staggered")
check(overlappedVerification,"backup verification overlaps the next native capture")
local idlePackets=0
four.filter=function(p)if p.m.v==3 then idlePackets=idlePackets+1 end;return true end
for _=1,50 do four:step() end
four.filter=nil
check(idlePackets==0,"healthy idle shards do not repeatedly broadcast checkpoint state")
local anchor=forest.core.generation
for _,node in ipairs(shards) do
    check(node.core.generation==anchor and node.store.state.cuts[anchor].members["4"],"four participants seal one cut")
end
local uid="ISLAND_PLAYER"
islands.core:Register(uid,"3","starting profile")
four:until_(function()return islands.core:CanMigrate(uid) end,"all shards record player before-image")
local oldtoken=islands.core:Depart(uid)
volcano.core:Arrived(uid,oldtoken,"3")
four:until_(function()return volcano.core:CanMigrate(uid) end,"islands-to-volcano travel")
caves.core:Arrived(uid,volcano.core:Depart(uid),"4")
four:until_(function()return caves.core:CanMigrate(uid) end,"volcano-to-caves travel")
forest.core:Receive("4",{v=3,kind="CHECKPOINT",op="ARRIVED",uid=uid,token=oldtoken})
for _,node in ipairs(shards) do check(node.core.owners[uid]=="2","late arrival cannot reverse four-shard ownership") end
check(caves.protocol:Start("chest","4","test"),"two secondary shards can exchange")
four:until_(function()return not caves.protocol.active and not volcano.protocol.active end,"secondary exchange")
check(four.saves==4,"four-shard exchange does not save the worlds")
forest.core:Request()
four:until_(function()return fourready() and four.saves==8 end,"second four-shard checkpoint")

four.stopped={["4"]=true}
caves.core.io.migrationready=function(peer, generation)
    return peer=="3" and generation==islands.core.generation and islands.core.phase=="ready"
end
four:step()
check(not caves.core:IsReady() and not caves.core:CanExchange("3"),"a stopped fourth shard still blocks shared operations")
check(not caves.core:CanMigrate(uid,"4") and not caves.core:CanMigrate(uid,"1"),"offline or unverified destination stays blocked")
check(caves.core:CanMigrate(uid,"3"),"established player can travel between live peers on the same cut")
islands.core:Arrived(uid,caves.core:Depart(uid),"2")
four:until_(function()return caves.core.outbound[uid]==nil and forest.core.owners[uid]=="3" end,"notify live peers of arrival during suspension")
check(not islands.core:CanMigrate(uid,"2") and islands.core.inbound[uid],"unacknowledged ownership cannot be overwritten by another migration")
four.stopped=nil
four:until_(function()return fourready() and not islands.core.inbound[uid] end,"resend arrival to returning shard")
check(volcano.core.owners[uid]=="3","returning shard records the latest owner before reopening")

local recovered=simulation()
for i,node in ipairs(shards) do
    shards[i]=recovered:node(node.id,node.disk,true,i==1 and anchor or nil)
end
recovered:until_(function()
    for i,node in ipairs(shards) do
        if node.restart then shards[i]=recovered:node(node.id,node.disk,true) end
    end
    return fourready()
end,"all four shards restore selected common checkpoint")
for _,node in ipairs(shards) do check(node.core.generation==anchor,"four-shard rollback agrees on the selected cut") end
shards[1].core:Disconnected("4")
check(not shards[1].core:CanExchange("2") and not shards[1].core:IsReady(),"known missing shard gates even two available endpoints")

for count=5,7 do
    local many=simulation()
    local nodes={}
    for id=1,count do nodes[id]=many:node(tostring(id)) end
    local function allready()
        for _,node in ipairs(nodes) do if not node.core or not node.core:IsReady() then return false end end
        return true
    end
    many:until_(allready,"discover larger cluster")
    nodes[count].core:Request()
    many:until_(function()return allready() and many.saves==count end,"seal larger cluster")
    for _,node in ipairs(nodes) do
        check(node.core.generation==nodes[1].core.generation,"all configured shards seal the same cut")
    end
    check(nodes[count-1].protocol:Start("chest",tostring(count),"test"),"last two secondary shards can exchange")
    many:until_(function()return not nodes[count-1].protocol.active and not nodes[count].protocol.active end,"larger cluster trade")
    check(many.saves==count,"cross-shard exchange never requests a world save")
end

local faultRuns, faultRounds, faultSaves = 0, 0, 0
for _,count in ipairs({2,4,7}) do
    for seed=1,3 do
        local s=simulation()
        local randomState=count*100+seed
        local function random(max)
            randomState=randomState*48271%2147483647
            return randomState%max+1
        end
        local delayed={}
        function s:shape(wire)
            for _,p in ipairs(wire) do
                if random(100)>12 then
                    delayed[#delayed+1]={packet=p,at=self.now+random(5)*.05}
                    if random(100)<=20 then delayed[#delayed+1]={packet=p,at=self.now+random(10)*.05} end
                end
            end
            local due={}
            for i=#delayed,1,-1 do
                if delayed[i].at<=self.now then
                    due[#due+1]=delayed[i].packet
                    table.remove(delayed,i)
                end
            end
            return due
        end
        local nodes={}
        for i=1,count do nodes[i]=s:node(tostring(i));nodes[i].items="cargo-"..i end
        local function idle(requireCut)
            for _,n in ipairs(nodes) do
                if not n.core or not n.core:IsReady() or n.protocol.active or
                    (requireCut and (not n.core.generation or n.core.generation~=nodes[1].core.generation)) then return false end
            end
            return true
        end
        s:until_(function()return idle(false)end,"fault stress discovery")
        nodes[1].core:Request()
        s:until_(function()return idle(true)end,"fault stress first checkpoint")
        for round=1,80 do
            local from=random(count)
            local to=(from+random(count-1)-1)%count+1
            check(nodes[from].protocol:Start("chest",tostring(to),"stress"),"fault stress starts primary exchange")
            if round%3==0 then
                nodes[to].protocol:Start("chest",tostring(from),"simultaneous")
            end
            if count>=4 and round%4==0 then
                local other={}
                for i=1,count do if i~=from and i~=to then other[#other+1]=i end end
                check(nodes[other[1]].protocol:Start("chest",tostring(other[2]),"independent"),
                    "fault stress starts two independent exchanges in the same tick")
            end
            local saved
            if round%5==0 then nodes[random(count)].core:Request(function()saved=true end) end
            s:until_(function()return (round%5~=0 or saved) and idle(true) end,
                "fault stress settle "..count.."/"..seed.."/"..round,2500)
            local cargos={}
            for _,n in ipairs(nodes) do
                check(not n.lock and not cargos[n.items],"fault stress conserves every cargo and unlocks all containers")
                cargos[n.items]=true
            end
            for i=1,count do check(cargos["cargo-"..i],"fault stress retains the original cargo set") end
            faultRounds=faultRounds+1
        end
        faultSaves=faultSaves+s.saves
        faultRuns=faultRuns+1
    end
end
print("Fault stress runs/rounds/shard saves:",faultRuns,faultRounds,faultSaves)
print("Production fast/checkpoint checks:",checks)
