-- Recovery images are captured only in response to normal native save requests.
-- No transfer may invoke Capture or nativeSave. Each image includes world and
-- player records; restoring a warehouse alone would duplicate dropped/crafted goods.
local Store=require("worldexchangestore2hm")
local Engine=require("worldexchangeengine2hm")
local Core=require("shadowvaultsnapshotcore2hm")
local Movement=require("shadowvaultmovement2hm")
local Courier=require("shadowvaultcourier2hm")
local Snapshot={}
Snapshot.__index=Snapshot
local function record(world)
    return world and world.map and world.map.persistdata and world.map.persistdata.shadowvault2hm
end
local function newstore(index,session)
    local store=Store.new(Engine.IO(index),session)
    store.prefix="sv3_"..session
    return store
end
local function readplayer(session,uid,cb)
    local file=TheNet:GetUserSessionFile(session,uid)
    if not file then cb(false);return end
    TheNet:DeserializeUserSession(file,function(ok,raw)
        if ok and (not raw or raw=="") then cb(false);return end
        local parsed,data=false,nil
        if ok then parsed,data=RunInSandboxSafe(raw) end
        if parsed and type(data)=="table" and not data.prefab then cb(false);return end
        assert(parsed and type(data)=="table" and type(data.prefab)=="string","Vault snapshot: invalid player profile "..uid)
        cb(raw)
    end)
end
function Snapshot.Bootstrap(index,native,callback)
    local saved=record(native)
    if not native or (not TUNING.SHADOWVAULT_ENABLED2HM and not (saved and saved.status=="active")) then
        callback(native);return
    end
    if not TheNet:GetIsServer() then callback(native);return end
    -- Older coordinated saves first finish their own existing recovery loader.
    local legacy=Engine.boot
    if legacy and not legacy.native_only and (legacy.loaded or legacy.legacy) then callback(native);return end
    local session=native.meta and native.meta.session_identifier
    if not session then callback(native);return end
    local store=newstore(index,session)
    store:Load(function(state,why)
        assert(state,"Vault snapshot journal: "..tostring(why))
        local function load(id)
            local cut=assert(store.state.cuts[id],"Vault snapshot: required recovery image missing")
            store:ReadCut(id,function(raw,failure,hydrated)
                assert(raw,"Vault snapshot: "..tostring(failure))
                local ok,world=RunInSandboxSafe(raw)
                assert(ok and type(world)=="table" and world.meta.session_identifier==session,"Vault snapshot: wrong world image")
                local players=hydrated.players
                for uid,base in pairs(store.state.baselines or {}) do
                    if players[uid]==nil then players[uid]=base.raw end
                end
                Snapshot.boot={store=store,session=session,loaded=id,players=players,ready=false,
                    recovery_parent=store.state.forced and store.state.recovery_parent,
                    recovery_cut=store.state.forced and id,
                    native_snapshot=hydrated.native_snapshot}
                if store.state.forced then
                    store:Update(function(s) s.forced=nil;s.recovery_parent=nil;s.current=id;s.cuts[id].committed=true end,function(written,error)
                        assert(written,"Vault recovery selection: "..tostring(error));callback(world)
                    end)
                else callback(world) end
            end)
        end
        if state.current then
            local id=state.forced or (saved and saved.snapshotcut) or state.baseline
            local cut=id and state.cuts[id]
            if not cut or not cut.committed then
                id=cut and cut.parent or saved and saved.snapshotparent or state.baseline
                assert(id and state.cuts[id] and state.cuts[id].committed,"Vault snapshot: uncommitted image has no verified parent")
            end
            -- A secondary may load a prepared image only by explicit master
            -- selection, never merely because its native file is newer.
            if state.forced then id=state.forced end
            load(id);return
        end
        -- One-time baseline: reuse the existing native bytes without saving the
        -- running world. New-world generation already writes its initial image.
        local file=Engine.NativeFile(index,session)
        local n=file and tonumber(file:match("/(%d+)$")) or 1
        local id="base_"..session.."_"..n
        local cut={id=id,serial=1,players={},owners={},native_snapshot=n,committed=true,
            refs={[tostring(TheShard:GetShardId())]={session=session,id=id}}}
        local uids={}
        for _,uid in ipairs(native.snapshot and native.snapshot.players or {}) do uids[uid]=true end
        for _,row in pairs(saved and saved.rows or {}) do if row.userid and row.userid~="_" then uids[row.userid]=true end end
        local list={};for uid in pairs(uids) do list[#list+1]=uid end
        local function nextplayer()
            local uid=table.remove(list)
            if uid then
                readplayer(session,uid,function(raw)
                    cut.players[uid]=raw;cut.owners[uid]=tostring(TheShard:GetShardId());nextplayer()
                end)
            else
                local raw=DataDumper(native,nil,true)
                store:PutCut(cut,raw,function(ok,reason)
                    assert(ok,"Vault baseline: "..tostring(reason))
                    store:Update(function(s) s.current=id;s.baseline=id end,function(written,error)
                        assert(written,"Vault baseline commit: "..tostring(error));load(id)
                    end)
                end)
            end
        end
        nextplayer()
    end)
end
function Snapshot.RestorePlayers()
    local boot=Snapshot.boot
    if not boot or not TheWorld or not TheWorld.ismastersim then return end
    TheNet:TruncateSnapshots(boot.session)
    local waiting,failed=1,false
    local function done(ok)
        failed=failed or not ok;waiting=waiting-1
        if waiting==0 then
            boot.ready=not failed
            if failed then boot.error="player_snapshot_restore_failed" else boot.players=nil end
        end
    end
    for uid,raw in pairs(boot.players or {}) do
        if raw==false then
            waiting=waiting+1
            TheNet:DeleteUserSession(uid)
            local file=TheNet:GetUserSessionFile(boot.session,uid)
            if not file then done(true)
            else TheNet:DeserializeUserSession(file,function(found,text)
                if not found or not text or text=="" then done(true);return end
                local ok,data=RunInSandboxSafe(text)
                done(ok and (data==nil or type(data)=="table" and not data.prefab))
            end) end
        else
            waiting=waiting+1
            local ok,data=RunInSandboxSafe(raw)
            assert(ok and type(data)=="table" and data.prefab,"Vault snapshot: invalid saved player")
            local function restore()
                TheNet:SerializeUserSession(uid,raw,false,nil,DataDumper({character=data.prefab},nil,true))
                local file=TheNet:GetUserSessionFile(boot.session,uid)
                if not file then done(false);return end
                TheNet:DeserializeUserSession(file,function(found,text) done(found and text==raw) end)
            end
            local file=TheNet:GetUserSessionFile(boot.session,uid)
            if file then TheNet:DeserializeUserSession(file,function(found,text) if found and text==raw then done(true) else restore() end end)
            else restore() end
        end
    end
    done(true)
end
function Snapshot.Attach(v)
    local boot=Snapshot.boot
    if not boot and not Snapshot.loading and ShardGameIndex and Engine.IO then
        local file=Engine.NativeFile(ShardGameIndex,v.session)
        if file then
            Snapshot.loading=true
            Engine.IO(ShardGameIndex).read(file,function(found,raw)
                local ok,data=false,nil
                if found then ok,data=RunInSandboxSafe(raw) end
                if not ok then Snapshot.loading=nil;v:Fail("initial_native_snapshot_unreadable");return end
                Snapshot.Bootstrap(ShardGameIndex,data,function()
                    Snapshot.loading=nil
                    if Snapshot.boot then
                        -- This is the already-running newly generated world;
                        -- do not overwrite its current live player sessions.
                        Snapshot.boot.ready=true;Snapshot.boot.players=nil
                        Snapshot.Attach(v)
                    end
                end)
            end)
        end
        return
    end
    if not boot or boot.session~=v.session then return end
    local self=setmetatable({v=v,store=boot.store,boot=boot,revisions={},registrations={},
        departed=deepcopy(boot.store.state.cuts[boot.loaded].departed or {})},Snapshot)
    self.store.io.defer=function(cb) v.inst:DoStaticTaskInTime(0,cb) end
    self.core=Core.new({id=v.id,master=v.master,masterid=tostring(SHARDID.MASTER),session=v.session,boot=v.transport.boot,
        now=GetStaticTime,connected=function(peer,epoch)
            local p=v.transport.peers[peer]
            return p and p.boot==epoch and Shard_IsWorldAvailable(peer)
        end,
        send=function(peer,m) v.transport:Send(peer,m) end,
        fail=function(why) v:Fail(why) end,
        idle=function() return self:Idle() end,
        movement_revision=function() return self.v.movements and self.v.movements.revision or 0 end,
        nativepeers=function()
            local peers={}
            for peer in pairs(ShardList or {}) do if Shard_IsWorldAvailable(peer) then peers[tostring(peer)]=true end end
            return peers
        end,
        capture=function(cut,cb) self:Capture(cut,cb) end,
        historylimit=function() return self:RetentionLimit() end,
        restart=function(id,parent) self:RestartTo(id,parent) end,
    },self.store,boot.loaded)
    v.snapshot=self
    if boot.error then self.core:Fail(boot.error) end
    return self
end
function Snapshot:Idle()
    if not self.boot.ready or self.capture or self.store.busy or next(self.registrations) or self.v.protocol.active or
        self.restarting then return false end
    for _,p in ipairs(AllPlayers) do if p._despawning then return false end end
    local native=self.v.inst.components.shardtransactionsteps
    for _,transactions in pairs(native and native.transactions or {}) do
        for _,t in pairs(transactions) do
            if type(t)=="table" and t.status and t.status<SHARDTRANSACTIONSTEPS.FINALIZED then return false end
        end
    end
    return true
end
function Snapshot:Register(uid,baseline,cb)
    if self.store.state.registry[uid] then if cb then cb() end;return end
    if self.registrations[uid] then
        if cb then table.insert(self.registrations[uid],cb) end
        return
    end
    self.registrations[uid]=cb and {cb} or {}
    local function write(raw)
        self.store:Register(uid,self.v.id,raw,function(ok,why)
            if not ok then self.core:Fail(why);return end
            local callbacks=self.registrations[uid];self.registrations[uid]=nil
            for _,fn in ipairs(callbacks) do fn() end
        end)
    end
    if baseline~=nil then write(baseline) else readplayer(self.v.session,uid,write) end
end
function Snapshot:PlayerWrite(player,isnew,original)
    local uid=player.userid
    -- Resume/spawn hooks register a pre-existing profile before gameplay. An
    -- unregistered new identity has no player at the previous recovery point.
    -- Registration is background metadata; native serialization never waits.
    self:Register(uid,false)
    if player.migration and player._shadowvault_destination and not player._shadowvault_movement then
        player._shadowvault_movement=self:Depart(player._shadowvault_destination)
        player._shadowvault_travel=Movement.Token(player._shadowvault_movement)
        self.departed[uid]=true
        Courier.Departing(self.v,uid,player._shadowvault_destination)
    end
    self.revisions[uid]=(self.revisions[uid] or 0)+1
    if self.capture and not self.capture.serialized then
        self.capture.players[uid]=not self.departed[uid] and DataDumper(player:GetSaveRecord(),nil,true) or false
    end
    return original(player,isnew)
end
function Snapshot:Capture(cut,callback)
    local capture={id=cut.id,serial=cut.serial,parent=cut.parent,players={},owners={},refs=deepcopy(cut.refs),
        departed=deepcopy(self.departed),historylimit=cut.historylimit,native_snapshot=TheNet:GetCurrentSnapshot()}
    self.capture=capture
    local uids={};for uid in pairs(self.store.state.registry) do uids[#uids+1]=uid end
    local function nextplayer()
        local uid=table.remove(uids)
        if uid then
            local revision=self.revisions[uid]
            readplayer(self.v.session,uid,function(raw)
                if revision==self.revisions[uid] then capture.players[uid]=not self.departed[uid] and raw or false end
                capture.owners[uid]=self.v.id;nextplayer()
            end)
            return
        end
        Snapshot.nativeSave(self.core.shutdown==true,function()
            self.capture=nil
            if not capture.raw then callback(false,"missing_native_serialization");return end
            local raw=capture.raw;capture.raw=nil
            self.store:PutCut(capture,raw,callback)
        end)
    end
    nextplayer()
end
function Snapshot:WorldSerialized(data)
    if self.capture then
        self.capture.raw=Engine.AssembleWorld(data)
        self.capture.movements=deepcopy(self.v.movements or Movement.Empty())
        self.capture.departed=deepcopy(self.departed)
        self.capture.players=deepcopy(self.capture.players)
        self.capture.serialized=true
    end
end
function Snapshot:SaveRequested(shutdown,callback)
    if self.exit_saved then if callback then callback() end;return end
    self.core:Request(callback,shutdown)
end
function Snapshot:Exit(callback)
    if self.exit_saved then callback();return end
    if self.exit_waiting then return end
    self.exit_waiting=true
    local done=false
    local function finish()
        if done then return end
        done=true;self.exit_saved=true;callback()
    end
    self.core:Request(finish)
    self.v.inst:DoStaticTaskInTime(20,function()
        if not done then
            print("[ShadowVault2hm] Exit could not commit a coherent save; recovery retains the previous verified snapshot.")
            finish()
        end
    end)
end
function Snapshot:Depart(destination)
    self.v.movements=self.v.movements or Movement.Empty()
    local movement=Movement.Send(self.v.movements,self.v.id,tostring(destination),self.v.transport.boot)
    self.core:Dirty(tostring(destination))
    return movement
end
function Snapshot:Arrived(uid,movement)
    self.departed[uid]=nil
    self.v.movements=self.v.movements or Movement.Empty()
    if Movement.Receive(self.v.movements,self.v.id,movement) then self.core:Dirty(movement.source) end
end
function Snapshot:Tick()
    local now=GetStaticTime()
    self.core:Tick()
    if self.receipt_cut~=self.core.loaded then
        self.receipt_cut=self.core.loaded;self.nextprune=0
    end
    if self.last_pruned~=self.core.loaded and now>=(self.nextprune or 0) then
        self.nextprune=now+5
        self:Prune()
    end
end
function Snapshot:RetentionLimit()
    local index=ShardGameIndex
    local ok,infos,more=pcall(function()
        if not TheNet:IsDedicated() and index:GetSlot()~=nil and not index:GetServerData().use_legacy_session_path then
            return TheNet:ListSnapshotsInClusterSlot(index:GetSlot(),index:GetShard() or "Master",self.v.session,TheNet:IsOnlineMode(),10000)
        end
        return TheNet:ListSnapshots(self.v.session,TheNet:IsOnlineMode(),10000)
    end)
    if not ok or type(infos)~="table" or more or #infos==0 then return end
    return #infos+2
end
function Snapshot:Prune()
    if self.pruning or self.core.phase~="ready" or self.capture or self.restarting then return end
    local id=self.core.loaded
    local current=self.store.state.cuts[id]
    local limit=self:RetentionLimit()
    if not current or not limit or not current.committed then return end
    limit=math.max(limit,current.historylimit or 0)
    local keep={[self.store.state.baseline]=true}
    local cursor=id
    for _=1,limit do
        local cut=cursor and self.store.state.cuts[cursor]
        if not cut then break end
        keep[cursor]=true;cursor=cut.parent
    end
    -- A prepared, undecided image may still be selected by the master after
    -- reconnect. Never prune it merely because the local current pointer lags.
    for key,cut in pairs(self.store.state.cuts) do
        if not cut.committed and not self.core.discarded[key] then keep[key]=true end
    end
    if self.store.state.forced then keep[self.store.state.forced]=true end
    local retired={}
    for key,cut in pairs(self.store.state.cuts) do
        if not keep[key] then retired[key]=cut end
    end
    self.last_pruned=id
    if not next(retired) then return end
    self.pruning=true
    self.store:Update(function(state)
        for key in pairs(retired) do state.cuts[key]=nil end
    end,function(ok,why)
        self.pruning=nil
        if not ok then self.core:Fail(why);return end
        for key,cut in pairs(retired) do
            self.core.discarded[key]=nil
            if cut.world and cut.world:sub(1,#self.store.prefix+7)==self.store.prefix.."_world_" then
                self.store.io.erase(cut.world)
                if cut.playerfile==cut.world.."_players" then self.store.io.erase(cut.playerfile) end
            end
        end
    end)
end
function Snapshot:RestartTo(id,parent)
    if self.restarting then return end
    self.restarting=true
    self.store:ReadCut(id,function(raw,why,cut)
        if not raw then self.core:Fail(why);return end
        local parsed,world=RunInSandboxSafe(raw)
        if not parsed or type(world)~="table" then self.core:Fail("invalid_recovery_world");return end
        local persist=world.world_network and world.world_network.persistdata or {}
        local metadata=DataDumper({clock=persist.clock,seasons=persist.seasons},nil,true)
        self.store:Update(function(state) state.forced=id;state.recovery_parent=parent end,function(ok,error)
            if not ok then self.core:Fail(error);return end
            local file=Engine.NativeFile(ShardGameIndex,self.v.session)
            if not file then self.core:Fail("native_snapshot_path_missing");return end
            local target=file:gsub("/%d+$","/"..string.format("%010d",cut.native_snapshot))
            self.store:Write(target,raw,function(written)
                if not written then self.core:Fail("native_snapshot_restore_failed");return end
                self.store:Write(target..".meta",metadata,function(saved)
                    if not saved then self.core:Fail("native_snapshot_metadata_failed");return end
                    TheNet:TruncateSnapshots(self.v.session,cut.native_snapshot)
                    StartNextInstance({reset_action=RESET_ACTION.LOAD_SLOT,save_slot=ShardGameIndex:GetSlot(),save_shard=ShardGameIndex:GetShard()})
                end)
            end)
        end)
    end)
end
return Snapshot
