-- Disposable two-shard cluster only; synthetic players, no live clients.
local Engine = require('worldexchangeengine2hm')
local players, incoming, rounds, phase, clock = {}, 0, 0, 'boot', 0
local stagekey='sw_multiplayer_audit_rollback_v2'
local stage,previouscut,prepared
local function check(ok, label) assert(ok, 'MULTIPLAYER_AUDIT: '..label) end
local function spawnplayer(prefab,uid)
    local p=SpawnPrefab(prefab);p.userid=uid
    -- Native connected-player creation adds this before session resume.
    p:AddComponent('playercontroller')
    return p
end
local function service() return TheWorld.components.worldexchange2hm end
local function transmit(op, payload)
    SendModRPCToShard(GetShardModRPC('SW_MULTIPLAYER_AUDIT','packet'), service().engine.core.peer, op, payload or '')
end
AddShardModRPCHandler('SW_MULTIPLAYER_AUDIT','packet',function(peer,op,raw)
    if op=='player' then
        local ok, envelope=RunInSandboxSafe(raw);check(ok,'decode migrant')
        local data=envelope.record
        check(data.data.migration.worldexchange_token2hm,'native serialized migration token')
        check(data.data.worldexchange_maps2hm,'map record in migration')
        local p=spawnplayer(data.prefab,envelope.uid)
        players[p.userid]=p
        ResumeExistingUserSession(data,p.GUID)
        incoming=incoming+1
    elseif op=='prepare' then
        TheSim:SetPersistentString(stagekey,raw,false,function(ok)
            check(ok~=false,'persist cave rollback expectation');transmit('prepared')
        end)
    elseif op=='prepared' then prepared=true
    elseif op=='stop' then c_shutdown(false)
    end
end)
require('worldexchangerpc2hm').Install(GLOBAL,GetShardModRPC('SW_MULTIPLAYER_AUDIT','packet'),
    GetShardModRPCHandler('SW_MULTIPLAYER_AUDIT','packet'))
local function departall()
    local e=service().engine
    for uid,p in pairs(players)do
        check(e.core:CanMigrate(uid),'previous arrival acknowledged before departure')
        p.worldexchange_departure2hm=e.core:Depart(uid)
        p.migration={worldid=TheShard:GetShardId(),portalid=1,sessionid=TheWorld.meta.session_identifier}
        SerializeUserSession(p)
        e:ReadPlayer(uid,function(raw)
            local ok,data=RunInSandboxSafe(raw);check(ok,'native saved migrant')
            transmit('player',DataDumper({uid=uid,record=data},nil,true))
            p:Remove()
        end)
    end
    players={};incoming=0
end
AddPrefabPostInit('world',function(inst)
    if not inst.ismastersim then return end
    check(TheNet:GetServerName()=='ShadowWorld isolated multiplayer audit','isolated server name required')
    inst:PushEvent('ms_setautosaveenabled',false)
    phase='loading'
    TheSim:GetPersistentString(stagekey,function(ok,raw)
        if ok and raw~='' then local valid,data=RunInSandboxSafe(raw);check(valid,'rollback expectation');stage=data end
        phase=stage and 'verifyrollback' or 'boot'
    end)
    local saved=false
    inst:DoStaticPeriodicTask(.1,function()
        clock=clock+.1
        if clock>150 then print('[MP_AUDIT] TIMEOUT',phase);c_shutdown(false);return end
        local s=service();local e=s and s.engine
        if not e or not e.core:IsReady() then return end
        if phase=='verifyrollback' then
            check(e.core.generation==stage.id,'native rollback selects expected common checkpoint')
            phase='verified'
            print('[MP_AUDIT] ROLLBACK_READY',TheShard:GetShardId(),clock)
            if TheShard:IsMaster() then
                local remaining=0
                for uid,expected in pairs(stage.players)do
                    remaining=remaining+1
                    e:ReadPlayer(uid,function(raw)
                        local ok,data=RunInSandboxSafe(raw);check(ok,'native rollback player readable')
                        local p=spawnplayer(data.prefab,uid)
                        ResumeExistingUserSession(data,p.GUID)
                        -- Native spawn fade holds input for 6 + 19 frames.
                        inst:DoStaticTaskInTime(1.1,function()
                            local maps=p.player_classified.MapExplorer:RecordAllMaps()
                            for session,map in pairs(expected)do check(maps[session]==map,'rollback retains native map bytes') end
                            check(p.components.playercontroller:IsEnabled(),'restored player can move after verification')
                            remaining=remaining-1
                            print('[MP_AUDIT] ROLLBACK_MAP_PASS',uid)
                            if remaining==0 then
                                print('[MP_AUDIT] ALL_PASS');transmit('stop')
                                inst:DoStaticTaskInTime(1,function()c_shutdown(false)end)
                            end
                        end)
                    end)
                end
                check(next(stage.players),'rollback fixture has players')
            end
        elseif phase=='boot' then
            phase='waiting'
            if TheShard:IsMaster() then
                for i=1,3 do
                    local p=spawnplayer('wilson','KU_MultiplayerAudit'..i)
                    p.Transform:SetPosition(0,0,0);players[p.userid]=p
                    p.player_classified.MapExplorer:EnableUpdate(true)
                    p.audit_map_before=DataDumper(p.player_classified.MapExplorer:RecordAllMaps(),nil,true)
                    p.player_classified.MapExplorer:RevealArea(0,0,0)
                    p.player_classified.MapExplorer:RevealArea(60,0,60)
                    for _,node in ipairs(TheWorld.topology.nodes) do
                        if node.x and node.y then p.player_classified.MapExplorer:RevealArea(node.x,0,node.y) end
                    end
                    e:Joined(p,false)
                end
                phase='registering'
            end
        elseif phase=='registering' and not e.core.regbusy then
            for uid,p in pairs(players)do
                local explorer=p.player_classified.MapExplorer
                local maps=explorer:RecordAllMaps()
                check(DataDumper(maps,nil,true)~=p.audit_map_before,'exploration changes native map record')
                local record=p:GetSaveRecord()
                check(record.data.worldexchange_maps2hm,'save hook captures actual native maps')
                local clone=SpawnPrefab('wilson');clone.userid=uid..'MapClone'
                clone:SetPersistData(record.data)
                inst:DoStaticTaskInTime(.1,function()
                    local restored=clone.player_classified.MapExplorer:RecordAllMaps()
                    for session,map in pairs(maps)do
                        check(restored[session]==map,'native map restore retains explored-map bytes')
                        print('[MP_AUDIT] MAP_ROUNDTRIP',session,#map,#restored[session])
                    end
                    clone:Remove()
                end)
            end
            phase='outgoing';departall()
        elseif phase=='waiting' and incoming==3 and not e.core.regbusy and not next(e.core.inbound) then
            phase='returning'
        elseif phase=='returning' and not next(e.core.inbound) then
            phase='waiting';departall()
        elseif phase=='outgoing' and incoming==3 and not next(e.core.inbound) and not next(e.core.outbound) then
            for uid in pairs(players)do check(e.core.owners[uid]==s.id,'returned ownership') end
            phase='saving';saved=false
            e.core:Request(function()saved=true end)
        elseif phase=='saving' and saved then
            phase='trading'
            local ok,reason=s.protocol:Start('shadow',e.core.peer,'audit')
            check(ok,'trade after multiplayer roundtrip: '..tostring(reason));s:Wake()
        elseif phase=='trading' and not s.protocol.active then
            rounds=rounds+1
            print('[MP_AUDIT] ROUND_PASS',rounds,e.core.generation)
            if rounds==3 then
                local expected={id=previouscut,players={}}
                for uid,raw in pairs(e.store.state.cuts[previouscut].players)do
                    if raw then local ok,data=RunInSandboxSafe(raw);check(ok,'checkpoint player');expected.players[uid]=data.data.worldexchange_maps2hm end
                end
                local raw=DataDumper(expected,nil,true)
                phase='prepare'
                TheSim:SetPersistentString(stagekey,raw,false,function(ok)
                    check(ok~=false,'persist rollback expectation');transmit('prepare',raw)
                end)
            else previouscut=e.core.generation;phase='outgoing';departall() end
        elseif phase=='prepare' and prepared then
            phase='rollback'
            print('[MP_AUDIT] CALL_ROLLBACK',previouscut)
            inst:DoStaticTaskInTime(.1,function()c_rollback(1)end)
        end
    end)
end)
