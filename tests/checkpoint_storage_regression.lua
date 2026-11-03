local Store = worldexchangestore2hm
local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function originaldigest(data)
    local hash = 5381
    for i = 1, #data do hash = (hash * 33 + data:byte(i)) % 4294967296 end
    return tostring(#data) .. ":" .. string.format("%08x", hash)
end
local bytes = {}; for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
local binary = table.concat(bytes)
for size = 0, 260 do
    local value = (binary .. binary):sub(1, size)
    check(Store.Digest(value) == originaldigest(value), "digest preserves v2 bytes and remainder " .. size)
end
check(Store.Digest(string.rep(binary, 4096)) == originaldigest(string.rep(binary, 4096)), "digest agrees for large binary payload")

local function storage()
    local disk, io = {}, {}
    io.encode, io.decode = function(t) return DataDumper(t,nil,true) end, RunInSandboxSafe
    io.write = function(k,v,cb) disk[k] = v; cb(true) end
    io.read = function(k,cb) cb(disk[k] ~= nil,disk[k]) end
    io.erase = function(k) disk[k] = nil end
    local store = Store.new(io,"STORAGE"); store:Load(function(state) assert(state) end)
    return store,disk,io
end
local store,disk,io = storage()
local player = "return {prefab='wilson',data={inventory='item',worldexchange_maps2hm='explored'}}"
local function put(serial)
    store:PutCut({id="cut/"..serial,serial=serial,owners={u="1",gone="2"},players={u=player,gone=false}},
        "return {world="..serial.."}",function(ok,why)check(ok,"checkpoint body committed: "..tostring(why))end)
    store:Seal("cut/"..serial,function(ok)check(ok,"seal succeeds")end)
end
put(1)
local cut=store.state.cuts["cut/1"]
check(store.state.version==3 and not next(cut.players),"journal stores references instead of historical profiles")
check(disk[cut.playerfile] and cut.playerdigest==Store.Digest(disk[cut.playerfile]),"player body verified independently")
local function read(expected)
    store:ReadCut("cut/1",function(world,why,hydrated)
        if expected then
            check(world and hydrated.players.u==player and hydrated.players.gone==false,"lazy read restores exact profile and tombstone")
        else check(not world and why=="corrupt_player_checkpoint","bad player body fails closed") end
    end)
end
read(true)
check(not next(cut.players),"reading history does not turn metadata into a permanent profile cache")
local body=disk[cut.playerfile];disk[cut.playerfile]=nil;read(false)
disk[cut.playerfile]=body.."torn";read(false);disk[cut.playerfile]=body
store:Register("late","1","late-profile",function(ok)check(ok,"late registration commits")end)
store:ReadCut("cut/1",function(world,why,hydrated)
    check(world and hydrated.players.late=="late-profile" and hydrated.players.u==player,"late-join overlay merges without replacing captured player")
end)
local retiredworld,retiredplayers=cut.world,cut.playerfile
for serial=2,9 do put(serial) end
check(store.state.cuts["cut/1"]==nil and disk[retiredworld]==nil and disk[retiredplayers]==nil,"retention prunes retired world and player bodies together")
local total=0;for _ in pairs(store.state.cuts) do total=total+1 end
check(total==8,"all eight rollback checkpoints retained")

-- Construct an old inline journal and migrate it through the real loader.
local old,oldDisk,oldIO=storage()
local worldkey=old.prefix.."_world_1_legacy"
oldDisk[worldkey]="old-world"
old:Update(function(state)
    state.version=2;state.current="legacy/1";state.nextserial=1
    state.cuts["legacy/1"]={id="legacy/1",serial=1,world=worldkey,digest=Store.Digest("old-world"),
        players={u=player,gone=false},owners={u="1",gone="2"}}
end,function(ok)assert(ok)end)
local oldhead=oldDisk[old.prefix.."_head"]
local write=oldIO.write
oldIO.write=function(key,value,cb) if key:match("_players$") then cb(false) else write(key,value,cb) end end
local failed=Store.new(oldIO,"STORAGE")
failed:Load(function(state,why)check(not state and why=="player_checkpoint_write_failed","failed migration cannot load incomplete backup")end)
check(oldDisk[old.prefix.."_head"]==oldhead,"failed migration retains original committed pointer")
oldIO.write=write
local upgraded=Store.new(oldIO,"STORAGE")
upgraded:Load(function(state,why)check(state and state.version==3,"v2 journal upgrades safely: "..tostring(why))end)
check(not next(upgraded.state.cuts["legacy/1"].players),"migration releases inline profiles")
upgraded:ReadCut("legacy/1",function(world,why,hydrated)
    check(world=="old-world" and hydrated.players.u==player and hydrated.players.gone==false,"migration preserves world, map, inventory and tombstone bytes")
end)
local revision=upgraded.state.revision
Store.new(oldIO,"STORAGE"):Load(function(state)check(state and state.revision==revision,"subsequent loads do not rewrite migrated cuts")end)

-- A body that fails read-back verification must never enter the journal.
local broken,brokenDisk,brokenIO=storage()
local normal=brokenIO.read
brokenIO.read=function(key,cb)
    if key:match("_players$") then cb(true,"corrupt") else normal(key,cb) end
end
broken:PutCut({id="bad",serial=1,players={u=player},owners={u="1"}},"world",function(ok,why)
    check(not ok and why=="player_checkpoint_write_failed","read-back rejects corrupted player snapshot")
end)
check(not next(broken.state.cuts) and broken.pending==0,"failed body does not publish cut or keep pending-write flag")
print("Checkpoint storage checks:",checks)
