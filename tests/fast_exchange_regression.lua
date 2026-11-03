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
                connected=function(peer,boot) return self.nodes[peer] and self.nodes[peer].boot==boot and not self.disconnected end,
                send=function(peer,m) table.insert(self.wire,{from=id,to=peer,target=self.nodes[peer].boot,m=Store.Copy(m)}) end,
                idle=function() return not n.protocol.active end,
                hold=function(h) n.hold=h end, log=function(msg) n.error=msg end,
                restart=function() n.restart=true end,
                save=function(cut,owners)
                    self.saves=self.saves+1; n.savecount=n.savecount+1
                    self:defer(function() n.core:Saved({id=cut.id,serial=cut.serial,owners=Store.Copy(owners),players={}},n.items) end)
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
            local p=self.nodes[id=="1" and "2" or "1"]
            if n.core and p and p.core and not self.disconnected then
                if n.core.peerboot~=p.boot or n.core.suspended then n.core:Connected(p.id,p.boot) end
                n.core:Tick(); n.protocol:Tick()
            end
        end
        local wire=self.wire; self.wire={}
        for _,packet in ipairs(wire) do
            if self.nodes[packet.to].core and packet.target==self.nodes[packet.to].boot and not self.disconnected and (not self.filter or self.filter(packet)) then
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
        self:node("1");self:node("2");self:until_(function() return self:ready() end,"initial cut")
    end
    function s:trade()
        check(self.nodes["1"].protocol:Start("chest","2","u"),"fast start")
        self:until_(function() return not self.nodes["1"].protocol.active and not self.nodes["2"].protocol.active end,"trade")
    end
    return s
end

local s=simulation();s:start()
check(s.saves==2,"one initial paired cut")
for _=1,20 do s:trade() end
check(s.saves==2,"twenty exchanges cause zero saves")
check(s.nodes["1"].items=="gold" and s.nodes["2"].items=="rocks","items conserved")
local completed=false
s.nodes["2"].core:Request(function() completed=true end)
s:until_(function() return completed and s:ready() end,"normal save")
check(s.saves==4,"manual/automatic request saves both once")

-- Drop first occurrence of every control message, plus repeat each delivery.
for _,op in ipairs({"INFO","FREEZE","DRAINED","CAPTURE","PREPARED","SEAL","SEALED","ACTIVATE","ACTIVE","OPEN","REQUEST"}) do
    local t=simulation();local dropped=false
    t.filter=function(p)
        if p.m.op==op and not dropped then dropped=true;return false end
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
check(a.hold and b.hold,"disconnect holds both worlds")
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
local registered=false;left.core:Register("NEW","1","BEFORE",function() registered=true end)
check(not left.core:CanMigrate("NEW"),"registration gates migration")
u:until_(function() return registered end,"registration")
for _,cut in pairs(left.store.state.cuts) do check(cut.players.NEW=="BEFORE","owner before-image") end
for _,cut in pairs(right.store.state.cuts) do check(cut.players.NEW==false,"peer tombstone") end
local migration = left.core:Depart("NEW");left.core:Request();for _=1,20 do u:step() end
check(u.saves==2,"pending migration blocks checkpoint")
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
local e=setmetatable({service={id="1"},live={},revisions={},capture=capture},Engine)
e.RegisterPlayer=function(_,uid,baseline,cb) cb() end
local written
TheNet={SerializeUserSession=function(_,uid,raw)written=raw end,DeleteUserSession=function()end}
e:PlayerWrite("u","before",false,nil,"meta")
e:WorldSerialized(sections)
e:PlayerWrite("u","after",false,nil,"meta")
check(capture.players.u=="before" and written=="after","later player write cannot mutate completed checkpoint")

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
leaving.nodes["2"].core:Disconnected("1")
check(exits[2],"secondary exit completes after sealed peer closes")
check(leaving.nodes["1"].store.state.current==leaving.nodes["2"].store.state.current,"exit uses same durable cut")
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
local offlineExit=setmetatable({service={Now=function()return exitClock end},store={state={registry={}}},
    core={generation="cut",opened=true,suspended=true,Request=function(_,cb)acknowledge=cb end,
        Tick=function()end,IsReady=function()return false end}},Engine)
offlineExit:Exit(function()exitCount=exitCount+1 end)
offlineExit:Update();exitClock=1;offlineExit:Update()
check(exitCount==1,"offline peer does not trap normal exit")
acknowledge();exitClock=2;offlineExit:Update()
check(exitCount==1,"late checkpoint callback cannot exit twice")

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
check(cave.hold and not cave.core:IsReady(),"valid hint holds before loading target")
early:until_(function()return cave.restart end,"cave starts early rollback")
check(cave.store.state.forced==target and cave.core.requested==target,"early target durable before restart")
hint(cave.core,"1",target,1)
check(cave.store.state.forced==target,"duplicate hint cannot reverse selection")
early:node("1",primary.disk,target,target);early:node("2",cave.disk,true)
early:until_(function()return early:ready()end,"early paired recovery")
check(early.nodes["1"].core.generation==target and early.nodes["2"].core.generation==target,"early notice still requires paired verification")
check(early.nodes["1"].items=="gold" and early.nodes["2"].items=="rocks","early rollback conserves target inventories")

print("Production fast/checkpoint checks:",checks)
