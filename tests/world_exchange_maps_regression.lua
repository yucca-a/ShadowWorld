local checks=0
local function check(ok,msg)checks=checks+1;assert(ok,msg)end
local MapHooks=worldexchangemaps2hm
local tasks={}
local current={Master='explored-ground',Caves='explored-caves'}
local explorer={RecordAllMaps=function()return worldexchangestore2hm.Copy(current)end,
    LearnAllMaps=function(_,maps)for k,v in pairs(maps)do current[k]=v end end}
local p={player_classified={MapExplorer=explorer},IsValid=function()return true end,
    DoStaticTaskInTime=function(_,_,fn)tasks[#tasks+1]=fn end,
    OnSave=function(_,data)data.inventory='original';return {'ref'}end,
    OnLoad=function(_,data)check(data.inventory=='original','native player data passed through')end}
MapHooks.Install(p)
local data={};local refs=p:OnSave(data)
check(refs[1]=='ref' and data.inventory=='original','map hook preserves original save and references')
check(data.worldexchange_maps2hm.Caves=='explored-caves','both shard maps are in Lua checkpoint record')
current={};p:OnLoad(data)
local immediate={};p:OnSave(immediate)
check(immediate.worldexchange_maps2hm.Master=='explored-ground','save before deferred restore cannot overwrite maps with empty explorer')
for _,fn in ipairs(tasks)do fn()end
check(current.Master=='explored-ground' and current.Caves=='explored-caves','native-load completion merges recorded maps')
check(not p.worldexchange_pendingmaps2hm,'temporary map restore released')
tasks={};p:OnLoad({inventory='original'})
check(#tasks==0,'old save without extension is left to native map loader')

local Engine=worldexchangeengine2hm
local raw="return {prefab='wilson',data={inventory='same'}}"
local writes=0
TheWorld={ismastersim=true}
TheNet={TruncateSnapshots=function()end,GetUserSessionFile=function()return 'user-file'end,
 DeserializeUserSession=function(_,_,cb)cb(true,raw)end,
 SerializeUserSession=function()writes=writes+1 end}
Engine.boot={session='map-test',players={u=raw},ready=false}
Engine.RestorePlayers()
check(writes==0 and Engine.boot.ready,'matching native user record retains its external map data without rewrite')
print('World exchange map checks:',checks)
