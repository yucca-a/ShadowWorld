local Snapshot=require("shadowvaultsnapshot2hm")
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local oldtime,oldshard=GetStaticTime,SHARDID
local enabled=TUNING.SHADOWVAULT_ENABLED2HM
TUNING.SHADOWVAULT_ENABLED2HM=false
local native={map={persistdata={}}}
local passed
Snapshot.Bootstrap(nil,native,function(data)passed=data end)
check(passed==native,"disabled vault must not create or restore a recovery image for an unrelated world")
TUNING.SHADOWVAULT_ENABLED2HM=enabled
SHARDID={MASTER="1"}
local now=0
GetStaticTime=function()return now end
-- Player serialization is synchronous even while local registry persistence is pending.
local callbacks,writes={},0
local writing=setmetatable({v={id="2",transport={boot="boot"},rows={}},revisions={},departed={},
    core={Dirty=function()end},Register=function(_,uid,baseline,fn) callbacks[#callbacks+1]=fn or true end},Snapshot)
local p={userid="user",migration={},_shadowvault_destination="1"}
writing:PlayerWrite(p,false,function() writes=writes+1 end)
check(writes==1 and #callbacks==1,"native player serialization cannot wait for local registration or a remote grant")
check(p._shadowvault_movement.destination=="1" and writing.departed.user,"native removal records the actual destination")
writing:PlayerWrite(p,false,function() writes=writes+1 end)
check(p._shadowvault_movement.sequence==1 and writes==2,"repeated serialization does not create a second departure")
writing:Arrived("user",{stream="1/other/2",source="1",destination="2",sequence=1})
check(not writing.departed.user and writing.v.movements.incoming["1/other/2"].count==1,"arrival clears local departure and records the native carried receipt")
-- Native rollback metadata is taken from world_network, not map.persistdata.
local Engine=require("worldexchangeengine2hm")
local oldfile,oldnet,oldindex,oldnext,oldreset=Engine.NativeFile,TheNet,ShardGameIndex,StartNextInstance,RESET_ACTION
local written,restarted={},false
Engine.NativeFile=function()return "session/test/0000000010"end
TheNet={TruncateSnapshots=function()end}
ShardGameIndex={GetSlot=function()return 1 end,GetShard=function()return "Caves"end}
RESET_ACTION={LOAD_SLOT="LOAD_SLOT"}
StartNextInstance=function()restarted=true end
local restore=setmetatable({v={session="test"},core={Fail=function(_,why)error(why)end},store={
    ReadCut=function(_,key,cb)cb(DataDumper({map={persistdata={clock={cycles=99}}},
        world_network={persistdata={clock={cycles=12},seasons={season="winter"}}}},nil,true),nil,{native_snapshot=5})end,
    Update=function(_,change,cb)change({});cb(true)end,
    Write=function(_,file,raw,cb)written[file]=raw;cb(true)end,
}},Snapshot)
restore:RestartTo("selected")
local ok,metadata=RunInSandboxSafe(written["session/test/0000000005.meta"])
check(restarted and ok and metadata.clock.cycles==12 and metadata.seasons.season=="winter",
    "restored snapshot has the native date/season metadata before restarting")
Engine.NativeFile,TheNet,ShardGameIndex,StartNextInstance,RESET_ACTION=oldfile,oldnet,oldindex,oldnext,oldreset
GetStaticTime,SHARDID=oldtime,oldshard
print("Vault travel interruption: "..checks.." checks passed")
