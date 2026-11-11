-- Upgrade-boundary and repeated native rollback regressions from the real save.
local Store, Engine = worldexchangestore2hm, worldexchangeengine2hm
local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function memory()
    local disk, io = {}, {}
    io.encode, io.decode = function(t) return DataDumper(t, nil, true) end, RunInSandboxSafe
    io.read = function(k, cb) cb(disk[k] ~= nil, disk[k]) end
    io.write = function(k, v, cb) disk[k] = v; cb(true) end
    return disk, io
end
local function journal(io)
    local store = Store.new(io, "ROLLBACK")
    store:Load(function(state) assert(state) end)
    store:Update(function(state)
        state.current, state.nextserial = "old/2", 2
        state.cuts = {["old/1"] = {serial=1}, ["old/2"] = {serial=2}}
        state.registry.u, state.baselines.u = true, {raw="player",owner="1"}
    end, function(ok) assert(ok) end)
    return store
end
local disk, io = memory()
local store = journal(io)
local before = io.encode(store.state)
store:RebaseNative({snapshot=13,token="timeline-A"}, function(ok) check(ok,"native rollback committed") end)
check(not next(store.state.cuts) and not next(store.state.registry) and not next(store.state.baselines),"old player ownership cannot leak into native rollback")
check(store.state.timeline == "timeline-A" and store.state.rebase.snapshot == 13 and store.state.nextserial == 2,"timeline records native target and retains serial monotonicity")
local archive, hash = next(store.state.archives)
check(disk[archive] == before and Store.Digest(disk[archive]) == hash,"complete old journal archived before reset")

local badDisk, badIO = memory()
local badStore = journal(badIO)
local badBefore = badIO.encode(badStore.state)
local read = badIO.read
badIO.read = function(k,cb) if k:find("_archive_",1,true) then cb(true,"torn") else read(k,cb) end end
badStore:RebaseNative({snapshot=13,token="timeline-B"},function(ok,why)
    check(not ok and why == "rollback_archive_failed","unverified archive rejects reset")
end)
check(badIO.encode(badStore.state)==badBefore,"failed archival retains all current cuts and profiles")

-- The reported native file is v1/applied, while the independent journal is v2.
local native={meta={session_identifier="ROLLBACK"},map={persistdata={worldexchange2hm={version=1,active={phase="applied"}}}}}
local index={GetSession=function()return "ROLLBACK"end}
local originalIO=Engine.IO
local _, masterIO=memory();journal(masterIO)
Engine.IO=function()return masterIO end
TheNet={GetIsServer=function()return true end,IsDedicated=function()return true end,
    GetWorldSessionFile=function()return "session/ROLLBACK/0000000013"end}
TheShard={IsMaster=function()return true end}
local loaded
Engine.Bootstrap(index,native,function(data)loaded=data end)
check(loaded==native and Engine.boot.legacy,"pre-install rollback loads actual native world without assertion")
check(Engine.boot.rebasing and Engine.boot.store.state.rebase.snapshot==13,"master initiates native paired recovery")
local _, secondaryIO=memory();journal(secondaryIO)
Engine.IO=function()return secondaryIO end
TheShard.IsMaster=function()return false end
loaded=nil
Engine.Bootstrap(index,native,function(data)loaded=data end)
check(loaded==native and Engine.boot.rollback_request==13,"secondary requests the same native rollback instead of advancing")
check(Engine.boot.store.state.current=="old/2","secondary waits for authoritative master timeline before discarding cuts")
local pendingStore = Engine.boot.store
pendingStore:RebaseNative({snapshot=13,token="pending-timeline"},function(ok)assert(ok)end)
secondaryIO.write("session/ROLLBACK/0000000013",secondaryIO.encode(native),function()end)
TheNet.GetWorldSessionFile=function()return "session/ROLLBACK/0000000018"end
local resumed
TheNet.TruncateSnapshots=function(_,session,snapshot)resumed=snapshot end
Engine.Bootstrap(index,{meta={session_identifier="ROLLBACK"},map={persistdata={worldexchange2hm={version=2,checkpoint="old/2"}}}},function(data)loaded=data end)
check(resumed==13 and loaded.map.persistdata.worldexchange2hm.version==1,"crash after rebase commit resumes old native target")
check(Engine.boot.legacy and Engine.boot.native_snapshot==13,"resumed rollback retains legacy transaction recovery")
check(Engine.boot.store.state.rebase_applied=="pending-timeline","verified rollback is marked applied")
local newest={meta={session_identifier="ROLLBACK"}}
resumed=nil
Engine.Bootstrap(index,newest,function(data)loaded=data end)
check(loaded==newest and not resumed and not Engine.boot.native_only,"later native saves do not repeat an applied rollback")

local missingDisk, missingIO=memory()
local missing=journal(missingIO)
missing:RebaseNative({snapshot=196,token="old-rebase"},function(ok)assert(ok)end)
local headKey=missing.prefix.."_head"
local priorHead=missingDisk[headKey]
Engine.IO=function()return missingIO end
TheNet.GetWorldSessionFile=function()return "session/ROLLBACK/0000000209"end
Engine.Bootstrap(index,newest,function(data)loaded=data end)
check(loaded==newest and Engine.boot.native_only and not resumed,"a missing 196 opens native 209 without coordinated exchange")
check(missingDisk[headKey]==priorHead,"native fallback does not rewrite the recovery journal")
local marked={meta={session_identifier="ROLLBACK"},map={persistdata={worldexchange2hm={version=2,checkpoint="old/2"}}}}
local ok=pcall(Engine.Bootstrap,index,marked,function()error("unexpected native load")end)
check(not ok and not resumed and not Engine.boot.native_only,"a missing target does not bypass a checkpoint marker")
local _, multiIO=memory()
local multi=Store.new(multiIO,"ROLLBACK")
multi:Load(function(state)assert(state)end)
for serial=1,2 do
    local id="multi/"..serial
    local raw=multiIO.encode({meta={session_identifier="ROLLBACK"},map={persistdata={worldexchange2hm={version=2,checkpoint=id}}}})
    multi:PutCut({id=id,serial=serial,native_snapshot=17+serial,owners={},players={},
        members={['1']=true,['2']=true,['3']=true}},raw,function(ok)assert(ok)end)
    multi:Seal(id,function(ok)assert(ok)end)
end
Engine.IO=function()return multiIO end
Engine.Bootstrap(index,native,function(data)loaded=data end)
check(loaded.map.persistdata.worldexchange2hm.checkpoint=="multi/1" and Engine.boot.requested=="multi/1",
    "rollback before multishard checkpoints requests an exact retained shared cut")
check(not Engine.boot.rollback_request and Engine.boot.store.state.current=="multi/2",
    "multishard rollback retains history until the master verifies the common cut")
Engine.IO=originalIO

-- Stale pre-restart shard announcements must not unlock the old timeline.
local connected, requested=0,nil
local peerEngine=setmetatable({store={state={timeline="timeline-A"}},service={legacy=true,session="ROLLBACK"},
    timeline_wait=true,core={Connected=function()connected=connected+1 end}},Engine)
peerEngine.RebaseNative=function(_,r)requested=r end
peerEngine:PeerHello("1",{fast=2,boot="old"})
check(connected==0 and peerEngine.timeline_wait,"different timeline stays blocked")
peerEngine:PeerHello("1",{fast=2,boot="new",timeline="timeline-B",rebase={token="timeline-B",snapshot=13}})
check(requested and requested.snapshot==13 and connected==0,"secondary follows master's explicit native target")
peerEngine:PeerHello("1",{fast=2,boot="new",timeline="timeline-A"})
check(connected==1 and not peerEngine.timeline_wait,"matching native timeline releases legacy completion")
peerEngine.rollback_request=13
peerEngine:PeerHello("1",{fast=2,boot="new",timeline="timeline-A"})
check(connected==1 and not peerEngine:CanAdvance(),"pending local native rollback cannot run exchanges")

-- Future physical native files may still refer to discarded fast cut IDs.
local _, aliasIO=memory();local aliases=journal(aliasIO)
aliases:Select("old/1",true,function(ok)assert(ok)end)
aliases.state.forced=nil
check(Engine.ResolveCut(aliases.state,{checkpoint="old/2"})=="old/1","abandoned native markers redirect to selected ancestor")
aliases.state.redirects["future/3"]="old/2"
check(Engine.ResolveCut(aliases.state,{checkpoint="future/3"})=="old/1","repeated rollback redirect chain resolves")
aliases.state.redirects={}
check(Engine.ResolveCut(aliases.state,{checkpoint="old/2",checkpoint_serial=2})=="old/1","earlier builds' abandoned native marker recovers without redirect")

-- Pair alignment must truncate to the native index belonging to the selected
-- cut, before reload. Otherwise the next c_rollback walks abandoned history.
local restoreDisk, restoreIO=memory();local restoreStore=Store.new(restoreIO,"ROLLBACK")
restoreStore:Load(function()end)
local nativeRaw="return {test=13,world_network={persistdata={clock={cycles=2}}}}"
restoreStore:PutCut({id="cut/3",serial=3,native_snapshot=13,owners={},players={}},nativeRaw,function(ok)assert(ok)end)
local truncated,restarted
TheNet.TruncateSnapshots=function(_,session,snapshot)
    check(restoreDisk["session/ROLLBACK/0000000013"]==nativeRaw,"world verified before native truncation")
    local ok, meta=RunInSandboxSafe(restoreDisk["session/ROLLBACK/0000000013.meta"])
    check(ok and meta.clock.cycles==2,"native snapshot metadata restored before truncation")
    truncated=snapshot
end
TheNet.GetWorldSessionFile=function()return "session/ROLLBACK/0000000018"end
ShardGameIndex=index
local restartEngine=setmetatable({store=restoreStore,service={session="ROLLBACK"},core={Fail=function(_,why)error(why)end}},Engine)
restartEngine.Restart=function()check(truncated==13,"truncate before restart");restarted=true end
restartEngine:RestartToCut("cut/3")
check(restarted and truncated==13,"paired restore follows native snapshot index")

-- Native tick queues are shared with unrelated shard traffic. Our messages
-- retain native decoding and connection checks, without waiting for sim ticks.
local calls, forwarded, deliveries = 0, 0, 0
local rpcGlobals = {HandleShardModRPC=function()forwarded=forwarded+1 end,
    Shard_IsWorldAvailable=function(id)return id=="2"end,
    TheNet={CallShardRPC=function(_,fn,sender,data)calls=calls+1;fn(sender,data)end}}
worldexchangerpc2hm.Install(rpcGlobals,{namespace="TEST",id=7},function(sender,data)
    check(sender=="2" and data=="encoded","native shard decoder preserves data");deliveries=deliveries+1
end)
rpcGlobals.HandleShardModRPC("2",1000,"test",7,"encoded")
check(calls==1 and deliveries==1 and forwarded==0,"recovery dispatch does not wait on paused native tick queue")
rpcGlobals.HandleShardModRPC("3",1000,"test",7,"encoded")
check(calls==1 and forwarded==0,"unavailable shard cannot dispatch recovery packets")
rpcGlobals.HandleShardModRPC("2",1000,"test",8,"encoded")
rpcGlobals.HandleShardModRPC("2",1000,"other",7,"encoded")
check(forwarded==2 and calls==1,"unrelated mod RPCs retain vanilla handling")

-- A rollback announcement can arrive while a checkpoint body is still being
-- written, before its journal mutation starts. Do not truncate beneath it.
local delayedDisk, delayedIO=memory()
local delayed=Store.new(delayedIO,"ROLLBACK");delayed:Load(function()end)
local normalWrite, release=delayedIO.write
delayedIO.write=function(k,v,cb)
    if k:find("_world_",1,true) then release=function()normalWrite(k,v,cb)end else normalWrite(k,v,cb)end
end
delayed:PutCut({id="cut/1",serial=1,players={},owners={}},"world",function(ok)assert(ok)end)
local recovering=setmetatable({store=delayed,service={session="ROLLBACK"},core={Fail=function(_,why)error(why)end}},Engine)
recovering:RebaseNative({snapshot=13,token="delayed-timeline"})
check(recovering.pending_rebase and not delayed.state.rebase,"in-flight body write delays native rebase")
release()
check(recovering:Writing() and not delayed.state.cuts["cut/1"],"player body also finishes before checkpoint commit")
release()
check(not recovering:Writing() and delayed.state.cuts["cut/1"],"pending body and journal finish before recovery")
local invoked, wakes=0,0
local draining=setmetatable({store={busy=true,queue={}},service={session="DRAIN",Wake=function()wakes=wakes+1 end}},Engine)
draining:Rollback(function()invoked=invoked+1 end)
draining:Rollback(function()error("duplicate rollback")end)
draining:Update()
check(invoked==0 and wakes==1 and not draining:CanAdvance(),
    "native rollback waits for pending writes and gates protocol work")
draining.store.busy=false;draining:Update()
check(invoked==1,"native rollback starts once after writes drain")

local hinted,flushed,resets=0,false,0
local notice=setmetatable({store={state={current="c/2",nextserial=2,cuts={["c/1"]={serial=1},["c/2"]={serial=2}}},
    io={read=function(path,cb)
        check(path=="session/ROLLBACK/0000000015","hint reads native-selected snapshot after truncation")
        cb(true,"return {map={persistdata={worldexchange2hm={checkpoint='c/1',checkpoint_serial=1}}}}")
    end}},service={session="ROLLBACK",peers={["2"]={fast=2}},Now=function()return 10 end,
    Send=function(_,peer,m)check(peer=="2" and m.op=="ROLLBACK_HINT" and m.id=="c/1" and m.serial==1,"hint preserves exact selected cut");hinted=hinted+1 end,
    Flush=function()flushed=true end}},Engine)
TheNet={IsDedicated=function()return true end,GetWorldSessionFile=function()return "session/ROLLBACK/0000000015"end}
Shard_IsWorldAvailable=function()return true end
notice:BeforeRollbackRestart(function()resets=resets+1 end)
check(hinted==1 and flushed and resets==0 and notice.exits[1].at==10.1,"hint leaves before master restart without a fixed long delay")
notice.exits[1].callback();check(resets==1,"original restart resumes after notice")

AllPlayers={}
print("Production native rollback checks:",checks)
