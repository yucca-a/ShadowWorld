local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require('json')
local function emit(data)print('[VAUDIT] '..json.encode(data))end
G.VaultAudit={}
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind='ready'})end)end)
-- These replacement entities are spawned by native corruption, outside spawn().
-- With no player in the isolated server they would otherwise sleep mid-animation.
for _,name in ipairs({'rocky_boss_shadow','bat_boss_shadow','worm_boss_shadow','worm_boss_shadow_head'})do
    AddPrefabPostInit(name,function(inst)
        if TheWorld.ismastersim then
            inst.entity:SetCanSleep(false);inst:StopBrain()
            if name=='worm_boss_shadow_head'then
                inst:ListenForEvent('newstate',function(head,data)
                    local state=data and data.statename or head.sg.currentstate.name
                    if head.worm and head._auditlaststate=='stalker_corruption_pst' and state~='stalker_corruption_pst'then
                        head.worm._auditcorruptioncomplete=true
                    end
                    head._auditlaststate=state
                end)
            end
        end
    end)
end

function G.VaultAudit.shadow_transform()
    local queue,index,total,failures={},0,0,0
    local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
    local owned,errors,checks,active={},{},0,false
    local nextcase,finish
    local function check(ok,msg)
        checks=checks+1;total=total+1
        if not ok then errors[#errors+1]=msg end
    end
    local function safe(fn)
        local ok,err=pcall(fn)
        if not ok then errors[#errors+1]=tostring(err);finish()end
    end
    local function later(delay,fn)TheWorld:DoTaskInTime(delay,function()if active then safe(fn)end end)end
    local function spawn(name)
        local inst=assert(SpawnPrefab(name),name)
        owned[#owned+1]=inst
        inst.Transform:SetPosition(x,y,z)
        inst.entity:SetCanSleep(false);inst:StopBrain()
        return inst
    end
    local function nearby(name)
        local result={}
        for _,inst in ipairs(TheSim:FindEntities(x,y,z,20))do
            if inst.prefab==name then result[#result+1]=inst end
        end
        return result
    end
    local function stop(inst)
        if inst.components.childspawner2hm then
            inst.components.childspawner2hm:StopSpawning();inst.components.childspawner2hm:StopRegen()
        end
        if inst.components.playerprox2hm then inst.components.playerprox2hm:Stop()end
    end
    local function clone(parent,name)
        local spawner=assert(parent.components.childspawner2hm,'real shadow spawner: '..parent.prefab)
        stop(parent);spawner.childreninside=1
        local child=assert(spawner:SpawnChild(nil,name),'real shadow spawn')
        owned[#owned+1]=child
        child.Transform:SetPosition(x+3,y,z);child.entity:SetCanSleep(false);child:StopBrain();stop(child)
        check(child:HasTag('swc2hm') and not child.persists,'shadow initialized')
        return child
    end
    finish=function()
        if not active then return end
        active=false
        if #errors>0 then failures=failures+1 end
        emit({kind='shadow_transform_case',name=queue[index].name,passed=#errors==0,checks=checks,errors=errors})
        -- Cleanup bypasses only world-changing retirement; tested paths above use native callbacks.
        for _,inst in ipairs(owned)do if inst:IsValid()then inst._EndFight=nil;inst:StopBrain();inst:Remove()end end
        for _,name in ipairs({'shyerrycore','rocky_boss_shadow','bat_boss_shadow','worm_boss_shadow'})do
            for _,inst in ipairs(nearby(name))do inst:Remove()end
        end
        TheWorld:DoTaskInTime(.3,nextcase)
    end
    nextcase=function()
        index=index+1
        if index>#queue then emit({kind='shadow_transform',passed=failures==0,cases=#queue,checks=total,failures=failures});return end
        owned,errors,checks,active={},{},0,true
        safe(queue[index].fn)
    end
    local function add(name,fn)queue[#queue+1]={name=name,fn=fn}end

    for _,prefab in ipairs({'shyerrycored','shyerrycored_lunar'})do
        for _,mode in ipairs({'parent_death','child_lethal','child_remove','original_retire'})do
            add('tree_'..prefab..'_'..mode,function()
                local parent=spawn(prefab)
                later(.3,function()
                    local child=clone(parent,prefab)
                    check(type(parent._EndFight)=='function' and type(child._EndFight)=='function','native retirement available')
                    if mode=='parent_death'then parent.components.health:Kill()
                    elseif mode=='child_lethal'then child.components.health:SetVal(0,'shadow_transform_test')
                    elseif mode=='child_remove'then child:Remove()
                    else
                        parent._EndFight(parent,false,false)
                        parent._EndFight(parent,true,false)
                        child:Remove()
                    end
                    later(4,function()
                        local trees=nearby('shyerrycore')
                        local expected=(mode=='parent_death' or mode=='original_retire')and 1 or 0
                        check(#trees==expected,'expected '..expected..' persistent tree(s), got '..#trees)
                        check(not child:IsValid(),'shadow removed')
                        if mode=='child_lethal' or mode=='child_remove'then
                            check(parent:IsValid() and not parent.components.health:IsDead(),'original boss remains alive')
                        end
                        if #trees==1 and expected==1 then
                            check(trees[1].persists,'original tree persists')
                            check(trees[1].components.shyerrygrow.stage==(mode=='parent_death' and 2 or 3),'native growth stage preserved')
                        end
                        finish()
                    end)
                end)
            end)
        end
    end

    for _,prefab in ipairs({'rocky_boss','bat_boss','worm_boss'})do
        for _,pair in ipairs({false,true})do
            add((pair and 'pair_'or'single_')..prefab,function()
                TheWorld.components.stalkermanager:SetData('performed_corrupt_once',true)
                local npc=spawn('stalker_npc')
                npc.Transform:SetPosition(x+10,y,z)
                local boss=spawn(prefab)
                local target=boss
                if prefab=='worm_boss'then
                    local util=require('prefabs/worm_boss_util')
                    -- Vanilla deliberately omits a lone chunk from OnSave.
                    -- Build a complete preceding chunk so native corruption
                    -- actually migrates the body and the visible head.
                    local first=util.CreateNewChunk(boss,Vector3(x-12,y,z),true)
                    first.groundpoint_end=Vector3(x-4,y,z)
                    util.SpawnDirt(boss,first,first.groundpoint_end,false,true)
                    first.head_added=true;first.state=util.CHUNK_STATE.IDLE
                    local chunk=util.CreateNewChunk(boss,Vector3(x,y,z),true)
                    util.EmergeHead(boss,chunk,true)
                    target=assert(boss.head,'native worm head')
                    target.entity:SetCanSleep(false);target:StopBrain()
                end
                local stuns=0
                target:ListenForEvent('stalker_corruption_stun',function()stuns=stuns+1 end)
                later(.3,function()
                    stop(npc);stop(boss)
                    local child=clone(npc,'stalker_npc')
                    child.Transform:SetPosition(x+12,y,z)
                    check(npc.cancorrupt and IsStalkerCorruptable(target,npc),'original NPC and boss retain corruption')
                    if pair then
                        check(not child.cancorrupt,'shadow AI cannot choose corruption')
                        child.sg:GoToState('idle')
                        child:PushEventImmediate('perform_corrupt',{target=target})
                        check(stuns==0,'shadow event does not stun boss')
                        child.sg:GoToState('idle');target.sg:GoToState('idle')
                        child.sg:GoToState('perform_corrupt_loop',{target=target,skiprandomchatter=true})
                        check(child.sg.currentstate.name=='idle','direct shadow loop rejected')
                        child.sg:GoToState('idle')
                    end
                    stuns=0
                    npc.sg:GoToState('idle')
                    npc:PushEventImmediate('perform_corrupt',{target=target})
                    check(target.sg:HasStateTag('stalkercorruptingstun'),'original NPC starts native ritual')
                    if pair then
                        -- Repeated stale/direct requests must not reset the real ritual.
                        for i=1,10 do later(i*.2,function()
                            if child:IsValid() and target:IsValid()then
                                child.sg:GoToState('idle')
                                child:PushEventImmediate('perform_corrupt',{target=target})
                            end
                        end)end
                    end
                    later(10,function()
                        check(not boss:IsValid(),'original boss replaced after ritual')
                        local replacements=nearby(prefab..'_shadow')
                        check(#replacements==1,'exactly one native corrupted boss')
                        check(stuns==1,'single ritual stun; observed '..stuns)
                        if #replacements==1 then
                            local result=replacements[1]
                            local sg=result.sg
                            if prefab=='worm_boss'then
                                check(result._auditcorruptioncomplete and not result.components.health:IsInvincible(),'worm exits corruption before normal burrowing')
                            else
                                check(sg and not sg:HasAnyStateTag('stalkercorrupting','stalkercorruptingstun'),'corrupted boss exits transformation: '..tostring(sg and sg.currentstate.name))
                            end
                            check(result.components.health and not result.components.health:IsDead(),'corrupted boss remains playable')
                        end
                        check(child:IsValid() and not child.sg.currentstate.name:find('perform_corrupt'),'shadow not stuck in ritual')
                        finish()
                    end)
                end)
            end)
        end
    end
    if SHADOW_TRANSFORM_FILTER then
        local filtered={}
        for _,case in ipairs(queue)do
            if case.name:find(SHADOW_TRANSFORM_FILTER,1,true)then filtered[#filtered+1]=case end
        end
        queue=filtered
    end
    nextcase()
end
