local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.WORLD_SPECIAL_EVENT = POPULATION_EVENT and SPECIAL_EVENTS.HALLOWED_NIGHTS or SPECIAL_EVENTS.NONE
G.WORLD_EXTRA_EVENTS[SPECIAL_EVENTS.HALLOWED_NIGHTS] = nil
G.TUNING.HN_MONSTER_CHANCE = 1
G.VaultAudit = {}
local houses = {mermhouse=true, mermhouse_crafted=true, mermwatchtower=true, pighouse=true}
local actors = {merm=true, mermguard=true, pigman=true}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
local function mark(e) return e.components.vaultauditmark end
local function origin(e)
    local m = mark(e)
    if m and m.token then return m.token end
    if e.swp2hm and e.swp2hm:IsValid() then return origin(e.swp2hm) end
end
AddPrefabPostInitAny(function(e)
    if not TheWorld.ismastersim or not (houses[e.prefab] or actors[e.prefab]) then return end
    e:AddComponent("vaultauditmark")
    if actors[e.prefab] then
        for _, event in ipairs({"death", "detachchild", "goinghome", "onremove"}) do
            e:ListenForEvent(event, function(_, data)
                local token=origin(e)
                if token then emit({kind="population_event",event=event,prefab=e.prefab,guid=e.GUID,token=token,
                    shadow=e:HasTag("swc2hm"),mummy=e.mummy or false,franken=e.franken or false}) end
            end)
        end
    end
end)
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind="ready"}) end) end)

local function Register()
    for _, e in pairs(Ents) do
        if actors[e.prefab] and e:IsValid() and e:HasTag("swc2hm") and e.swp2hm and e.swp2hm:IsValid() then
            mark(e).token=origin(e.swp2hm)
        elseif actors[e.prefab] and e:IsValid() then
            local home=e.components.homeseeker and e.components.homeseeker:GetHome()
            if home and mark(home) and mark(home).token then
                mark(e).token=mark(home).token
                e.entity:SetCanSleep(false)
                if e.brain then e.brain:Stop() end
            end
        end
    end
end

function G.VaultAudit.population_setup()
    local pos=Vector3(0,0,0)
    for _,e in pairs(Ents) do if e:HasTag("multiplayer_portal") then pos=e:GetPosition();break end end
    local specs={{"mermhouse","normal"},{"mermhouse","mummy"},{"mermhouse_crafted","normal"},{"mermwatchtower","normal"},{"pighouse","normal"},{"pighouse","franken"}}
    for i,spec in ipairs(specs) do
        local house=assert(SpawnPrefab(spec[1]))
        house.Transform:SetPosition(pos.x+(i-3)*8,0,pos.z+12)
        house.entity:SetCanSleep(false)
        mark(house).token="population_"..i.."_"..spec[2]
        if house.components.childspawner then
            house.ismummyhouse=POPULATION_EVENT and spec[2]=="mummy" or false
            local spawn=house.components.childspawner.onspawned
            house.components.childspawner:SetSpawnedFn(function(h,child)
                if spawn then spawn(h,child) end
                mark(child).token=mark(h).token
                child.entity:SetCanSleep(false)
                child:DoTaskInTime(2*FRAMES,function(e)if e.brain then e.brain:Stop() end end)
            end)
        else
            local pig=assert(SpawnPrefab("pigman"))
            pig._frankeninitialized=true
            if POPULATION_EVENT and spec[2]=="franken" then pig:MakeFrankenPig() end
            mark(pig).token=mark(house).token
            house.components.spawner:TakeOwnership(pig)
            house.components.spawner:GoHome(pig)
        end
    end
    TheWorld:DoTaskInTime(.3,function()Register();emit({kind="population_setup",houses=#specs,event=IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS)})end)
end

function G.VaultAudit.population_sample(label)
    Register()
    local rows={}
    for _,house in pairs(Ents) do
        if houses[house.prefab] and mark(house) and mark(house).token then
            local s=house.components.childspawner or house.components.spawner
            local row={token=mark(house).token,prefab=house.prefab,guid=house.GUID,mummyhouse=house.ismummyhouse or false,
                max=s.maxchildren or 1,inside=s.childreninside,outside=s.numchildrenoutside,emergency=s.numemergencychildrenoutside,
                real=0,shadow=0,mummy=0,normal=0,franken=0,untracked=0,wronghome=0,clonespawner=0,shadowstate={},shadowmummy=0,shadowfranken=0,shadowtracked=0,
                formmismatch=0,shadowpersist=0}
            for _,e in pairs(Ents) do
                if actors[e.prefab] and e:IsValid() and origin(e)==row.token and not e.components.health:IsDead() then
                    if e:HasTag("swc2hm") then
                        row.shadow=row.shadow+1
                        if e.mummy then row.shadowmummy=row.shadowmummy+1 end
                        if e.franken then row.shadowfranken=row.shadowfranken+1 end
                        if e.persists then row.shadowpersist=row.shadowpersist+1 end
                        local parent=e.swp2hm
                        if parent and parent:IsValid() and ((not not e.mummy)~=(not not parent.mummy) or (not not e.franken)~=(not not parent.franken)) then
                            row.formmismatch=row.formmismatch+1
                        end
                        if s.child==e or s.childrenoutside and s.childrenoutside[e] then row.shadowtracked=row.shadowtracked+1 end
                        if e.components.childspawner2hm then row.clonespawner=row.clonespawner+1 end
                    else
                        row.real=row.real+1
                        local ss=e.components.childspawner2hm
                        if ss then row.shadowstate[#row.shadowstate+1]={guid=e.GUID,inside=ss.childreninside,outside=ss.numchildrenoutside,can=ss:CanSpawn(),awake=not e:IsAsleep()} end
                        if e.mummy then row.mummy=row.mummy+1 elseif e.franken then row.franken=row.franken+1 else row.normal=row.normal+1 end
                        local tracked=s.child==e or s.childrenoutside and (s.childrenoutside[e] or s.emergencychildrenoutside[e])
                        if not tracked then row.untracked=row.untracked+1 end
                        local home=e.components.homeseeker and e.components.homeseeker:GetHome()
                        if e.parent~=house and home~=house then row.wronghome=row.wronghome+1 end
                    end
                end
            end
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b)return a.token<b.token end)
    emit({kind="population_sample",label=label,rows=rows,lifecyclecleanup=G.VaultAudit.population_lastcleanup})
end

function G.VaultAudit.population_exercise(label)
    Register()
    for _,phase in ipairs({"night","day","dusk","night"}) do
        TheWorld:PushEvent("ms_setphase",phase)
        for _,house in pairs(Ents) do
            if houses[house.prefab] and mark(house) and mark(house).token then
                local s=house.components.childspawner
                if s then
                    -- No player is connected to this controlled-capacity fixture.
                    s.spawnoffscreen=true
                    s:StartRegen()
                    for i=1,12 do s:DoRegen();s:ReleaseAllChildren() end
                else
                    house.components.spawner:SetQueueSpawning(nil)
                    for i=1,12 do house.components.spawner:ReleaseChild() end
                end
            end
        end
    end
    Register()
    TheWorld:DoTaskInTime(.2,function()
        Register()
        local parents={}
        for _,e in pairs(Ents) do
            if actors[e.prefab] and mark(e) and mark(e).token and e.components.childspawner2hm and not e:HasTag("swc2hm") then parents[#parents+1]=e end
        end
        for _,e in ipairs(parents) do
            e.components.childspawner2hm.spawnoffscreen=true
            e.components.childspawner2hm:StartRegen()
            e.components.childspawner2hm:DoRegen()
            e.components.childspawner2hm:ReleaseAllChildren()
        end
        TheWorld:DoTaskInTime(.3,function()G.VaultAudit.population_sample(label)end)
    end)
end

function G.VaultAudit.population_lifecycle(label)
    Register()
    local shadows, residents={},{}
    for _,e in pairs(Ents) do
        if actors[e.prefab] and mark(e) and mark(e).token then
            if e:HasTag("swc2hm") then shadows[#shadows+1]=e
            elseif not e.mummy then residents[#residents+1]=e end
        end
    end
    -- Ordinary residents go home with their shadows alive. Mummies stay outside
    -- in the native game, so exercise lethal-hit cleanup for their shadows.
    for _,e in ipairs(shadows) do
        if e.swp2hm and e.swp2hm.mummy then e.components.health:Kill() end
    end
    for _,e in ipairs(residents) do
        local home=e.components.homeseeker and e.components.homeseeker:GetHome()
        if home then
            if home.components.childspawner then home.components.childspawner:GoHome(e)
            elseif home.components.spawner then home.components.spawner:GoHome(e) end
        end
    end
    TheWorld:DoTaskInTime(2,function()
        local remaining=0
        for _,e in ipairs(shadows) do if e:IsValid() then remaining=remaining+1 end end
        G.VaultAudit.population_lastcleanup={attempted=#shadows,remaining=remaining}
        G.VaultAudit.population_exercise(label)
    end)
end

function G.VaultAudit.population_cleanup(label)
    Register()
    local shadows={}
    for _,e in pairs(Ents) do
        if actors[e.prefab] and origin(e) and e:HasTag("swc2hm") then
            shadows[#shadows+1]=e
            e.components.health:Kill()
        end
    end
    TheWorld:DoTaskInTime(2,function()
        local remaining=0
        for _,e in ipairs(shadows) do if e:IsValid() then remaining=remaining+1 end end
        emit({kind="population_cleanup",label=label,attempted=#shadows,remaining=remaining})
    end)
end
