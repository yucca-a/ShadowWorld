-- Observation only, for disposable native servers. No production fixes.
local G=GLOBAL
G.setmetatable(env,{__index=function(_,k)return G.rawget(G,k)end})
local json=require("json")
local A={created={},removed={},animover={},owned={}}
G.VaultAudit=A
local watched={air_conditioner_smoke=true,air_conditioner_cloud=true,miasma_cloud=true,
    um_shadow_miasma_cloud=true,small_puff=true,magma_tile=true,um_pyre_nettles=true}
local function emit(row)row.time=GetTime();print("[VAUDIT] "..json.encode(row))end
local dump=G.DataDumper
G.DataDumper=function(value,...)
    local text=dump(value,...)
    if A.dumpstats then
        local s=A.dumpstats
        s.calls=s.calls+1;s.total_bytes=s.total_bytes+#text;s.max_bytes=math.max(s.max_bytes,#text)
        s.lua_peak_kb=math.max(s.lua_peak_kb,collectgarbage("count"))
    end
    return text
end
AddPrefabPostInitAny(function(e)
    if not TheWorld.ismastersim or not watched[e.prefab] then return end
    local name=e.prefab
    A.created[name]=(A.created[name] or 0)+1
    e:ListenForEvent("animover",function()A.animover[name]=(A.animover[name] or 0)+1 end)
    e:ListenForEvent("onremove",function()
        A.removed[name]=(A.removed[name] or 0)+1
        A.owned[e.GUID]=nil
    end)
end)
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
function A.sample(label)
    local natural=collectgarbage("count")
    collectgarbage("collect")
    local retained=collectgarbage("count")
    local counts,details,total,tasks,components={}, {},0,0,0
    for _,e in pairs(Ents)do
        total=total+1
        local name=e.prefab or "<none>"
        counts[name]=(counts[name] or 0)+1
        local nt=0
        for _ in pairs(e.pendingtasks or {})do nt=nt+1 end
        tasks=tasks+nt
        for _ in pairs(e.components or {})do components=components+1 end
        if watched[name]then
            local d=details[name] or {count=0,persistent=0,asleep=0,tasks=0,owned=0}
            details[name]=d;d.count=d.count+1;d.tasks=d.tasks+nt
            if e.persists then d.persistent=d.persistent+1 end
            if e:IsAsleep()then d.asleep=d.asleep+1 end
            if A.owned[e.GUID]then d.owned=d.owned+1 end
        end
    end
    local top={}
    for prefab,count in pairs(counts)do top[#top+1]={prefab=prefab,count=count}end
    table.sort(top,function(a,b)return a.count>b.count end)
    while #top>20 do table.remove(top)end
    emit({kind="memory_sample",label=label,lua_natural_kb=natural,lua_retained_kb=retained,
        entities=total,tasks=tasks,components=components,top=top,details=details,
        created=A.created,removed=A.removed,animover=A.animover})
end
local function pos()
    for _,e in pairs(Ents)do if e:HasTag("multiplayer_portal")then return e:GetPosition()end end
    return Vector3(0,0,0)
end
function A.batch(prefab,n,awake)
    local p=pos();local made=0;local first
    for i=1,n do
        local e=SpawnPrefab(prefab)
        if e then
            made=made+1;A.owned[e.GUID]=true
            if awake then e.entity:SetCanSleep(false)end
            if e.Transform then e.Transform:SetPosition(p.x+(i%8)*.5,0,p.z+math.floor(i/8)*.5)end
            if not first then
                first={prefab=e.prefab,persistent=e.persists or false,asleep=e:IsAsleep(),fx=e:HasTag("FX")}
                if e.AnimState then first.animation_length=e.AnimState:GetCurrentAnimationLength();first.loop=e.AnimState:IsCurrentAnimation("loop")end
            end
        end
    end
    emit({kind="memory_batch",prefab=prefab,requested=n,created=made,awake=awake,first=first})
end
function A.cleanup()
    local list={}
    for guid in pairs(A.owned)do local e=Ents[guid];if e then list[#list+1]=e end end
    for _,e in ipairs(list)do if e:IsValid()then e:Remove()end end
    emit({kind="memory_cleanup",removed=#list})
end
function A.wake_smoke()
    local n=0
    for _,e in pairs(Ents)do
        if e.prefab=="air_conditioner_smoke"then n=n+1;e.entity:SetCanSleep(false)end
    end
    emit({kind="memory_wake",count=n})
end
function A.save()
    local before=GetTime()
    A.dumpstats={calls=0,total_bytes=0,max_bytes=0,lua_peak_kb=collectgarbage("count")}
    SaveGame(false,function()
        local stats=A.dumpstats;A.dumpstats=nil
        emit({kind="memory_saved",elapsed_sim_seconds=GetTime()-before,dumps=stats})
    end)
end
function A.player()
    local p=pos();local e=assert(SpawnPrefab("wilson"))
    e.userid="KU_MEMORY_AUDIT";e.Transform:SetPosition(p.x,0,p.z)
    e.components.health:SetInvincible(true)
    if e.components.hunger then e.components.hunger:SetRate(0)end
    A.owned[e.GUID]=true;A.player_entity=e
    emit({kind="memory_player",guid=e.GUID})
end
function A.air(n)
    local p=pos();local device=assert(SpawnPrefab("air_conditioner"))
    device.Transform:SetPosition(p:Get());device.entity:SetCanSleep(false)
    A.owned[device.GUID]=true
    local actor=assert(SpawnPrefab("wilson"));actor.Transform:SetPosition(p.x+2,0,p.z)
    A.owned[actor.GUID]=true
    actor.components.health:SetInvincible(true)
    if actor.components.hunger then actor.components.hunger:SetRate(0)end
    local food=assert(SpawnPrefab("blue_mushed_room"))
    assert(device.components.container:GiveItem(food,1))
    for i=1,n do
        device:DoTaskInTime((i-1)*1.25,function()
            device.components.channelable:StartChanneling(actor)
        end)
    end
    emit({kind="memory_air",activations=n,duration=(n-1)*1.25,device=device.GUID})
end
function A.recursion(n)
    local logger=assert(TheWorld.components.um_tilelogger,"UM tile logger missing")
    local previous=logger.Hazardous
    local host=CreateEntity();host.entity:AddTransform()
    local component=require("components/um_ocupusappearinator")(host)
    local anchors={}
    local tiles={}
    for _,cx in ipairs({-260,260})do
        local e=CreateEntity();e.entity:AddTransform();e.Transform:SetPosition(cx,0,0)
        anchors[#anchors+1]=e;component:RegisterOcupus(e)
        for dx=-248,248,4 do
            for dz=-248,248,4 do
                if dx*dx+dz*dz<250*250 and #tiles<n then tiles[#tiles+1]={x=cx+dx,z=dz}end
            end
        end
    end
    assert(#tiles==n,"requested candidate count exceeds the two controlled areas")
    logger.Hazardous=tiles
    collectgarbage("collect");local before=collectgarbage("count")
    local ok,err=pcall(function()component:SpawnOcupi()end)
    local transient=collectgarbage("count")
    logger.Hazardous=previous
    for _,e in ipairs(anchors)do e:Remove()end
    host:Remove()
    emit({kind="memory_recursion",candidates=n,ok=ok,error=not ok and tostring(err)or nil,
        before_kb=before,transient_kb=transient,
        condition="Synthetic occupied candidate regions; real component and native entity distances, original world tile table restored"})
end
