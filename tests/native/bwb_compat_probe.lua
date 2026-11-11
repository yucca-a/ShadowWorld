local G = GLOBAL
G.setmetatable(env, {__index=function(_, key) return G.rawget(G,key) end})
local A = {}
GLOBAL.BWBCompatAudit = A
local json = require("json")
local function emit(row) print("[VAUDIT] " .. json.encode(row)) end
local function seasons()
    return TheWorld.components.seasons or TheWorld.net and TheWorld.net.components.seasons
end
local function clock()
    return TheWorld.components.clock or TheWorld.net and TheWorld.net.components.clock
end
local function hungerstate(h)
    return {own=h.penalty2hm or 0, foreign=h.penalty or 0, current=h.current, maximum=h.max,
        ownnet=h.inst.player_classified.hungerpenalty2hm:value()/200,
        foreignnet=h.inst.player_classified.hungerpenalty and h.inst.player_classified.hungerpenalty:value()/200 or 0}
end
function A.state()
    local s=seasons()
    local data=s and s:OnSave() or {}
    local gems=0
    for _,v in ipairs(A.sockets or {}) do if v:IsValid() and v.gem then gems=gems+1 end end
    emit({kind="bwb_state",shard=TheShard:GetShardId(),season=TheWorld.state.season,
        current_clock=s and s.current_clock,default_season=data.season,cave_season=data.seasoncave,
        cave_clock=s and s.clocks and s.clocks.cave or false,gems=gems,
        powered=TheWorld.components.archivemanager and TheWorld.components.archivemanager:GetPowerSetting()})
end
function A.cave_clock()
    assert(seasons() and seasons().clocks and seasons().clocks.cave,"BWB cave clock missing")
    clock():SetClock("cave")
    seasons():SetSeasons("cave")
    TheWorld.topology.bwb_worldgen_version = TheWorld.topology.bwb_worldgen_version or 1
    TheWorld.topology.overrides = TheWorld.topology.overrides or {}
    TheWorld.topology.overrides.clocktype = "cave"
    TheWorld:DoTaskInTime(1,A.state)
end
function A.force_seasons()
    assert(TheWorld.ismastershard)
    TheWorld:PushEvent("ms_setseason","summer")
    TheWorld:PushEvent("ms_setseason","umbral")
    TheWorld:DoTaskInTime(1,A.state)
end
function A.hunger()
    local p=SpawnPrefab("wilson")
    p.components.health:SetInvincible(false)
    p.components.hunger:SetCurrent(100)
    TheWorld:DoTaskInTime(1,function()
        local h=p.components.hunger
        local rows={}
        p:PushEvent("death",{cause="bwb_compat_audit"})
        rows.death=hungerstate(h)
        local food=SpawnPrefab("smallmeat_dried")
        assert(p.components.eater:Eat(food),"native eater rejected dried meat")
        rows.food=hungerstate(h)
        h:DeltaPenalty2hm(.2)
        rows.before_unified=hungerstate(h)
        if h.ReduceUnifiedPenalty then h:ReduceUnifiedPenalty(-.1) else h:DeltaPenalty2hm(-.1) end
        rows.unified=hungerstate(h)
        local saved=h:OnSave()
        h:DeltaPenalty2hm(.2)
        h:OnLoad(saved)
        rows.loaded=hungerstate(h)
        local needle=SpawnPrefab("lifeinjector")
        rows.injector_result=needle.components.maxhealer:Heal(p)
        rows.injector=hungerstate(h)
        emit({kind="bwb_hunger",rows=rows})
        p:Remove()
    end)
end
function A.real_death()
    local p=SpawnPrefab("wilson")
    p.entity:SetCanSleep(false)
    p.components.hunger:SetCurrent(100)
    p.components.health:SetInvincible(false)
    p.components.health:Kill()
    TheWorld:DoTaskInTime(3,function()
        local ghost=p:HasTag("playerghost")
        local dead=hungerstate(p.components.hunger)
        p:PushEvent("respawnfromghost")
        TheWorld:DoTaskInTime(4,function()
            local revived=not p:HasTag("playerghost")
            local before=hungerstate(p.components.hunger)
            local food=SpawnPrefab("smallmeat_dried")
            local ate=p.components.eater:Eat(food)
            emit({kind="bwb_real_death",ghost=ghost,revived=revived,ate=ate,
                dead=dead,before=before,after=hungerstate(p.components.hunger)})
            p:Remove()
        end)
    end)
end
function A.prepare_sockets()
    assert(TheWorld:HasTag("cave"),"archive probe belongs in caves")
    assert(TheWorld.components.archivemanager,"native archive manager missing")
    A.player=SpawnPrefab("wilson")
    A.player.entity:SetCanSleep(false)
    A.sockets={}
    for i=1,3 do
        local inst=SpawnPrefab("archive_switch")
        inst.Transform:SetPosition(2000+(i-2)*2,0,2000)
        A.sockets[i]=inst
    end
    TheWorld:DoTaskInTime(2,function()emit({kind="bwb_sockets_ready"})end)
end
function A.give_gems()
    for _,inst in ipairs(A.sockets) do
        local gem=SpawnPrefab("opalpreciousgem")
        assert(inst.components.trader:AcceptGift(A.player,gem),"native archive gem gift rejected")
    end
    TheWorld:DoTaskInTime(3,A.state)
end
function A.load_sockets()
    A.sockets=TheSim:FindEntities(2000,0,2000,6,{"gemsocket","archive_switch"})
    TheWorld:DoTaskInTime(3,A.state)
end
-- Native activation finishes on animover. Keep these isolated test sockets
-- awake, as they are during a player's visit, including after a server reload.
AddPrefabPostInit("archive_switch",function(inst)
    if TheWorld.ismastersim then inst.entity:SetCanSleep(false) end
end)
AddSimPostInit(function()
    if TheWorld.ismastersim then TheWorld:DoTaskInTime(2,function()emit({kind="ready"})end) end
end)
