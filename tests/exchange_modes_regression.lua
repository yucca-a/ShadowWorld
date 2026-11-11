local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function env(t)return setmetatable(t or {},{__index=_G})end
local function execute(source,e)local fn=assert(loadstring(source));setfenv(fn,e);return fn()end
for _,locale in ipairs({"zh","en"})do
    local e=env({locale=locale});execute(info_source,e)
    local config,names=nil,{}
    for _,option in ipairs(e.configuration_options)do
        if option.name~="" then check(not names[option.name],"unique config key");names[option.name]=true end
        if option.name=="World Exchange"then config=option end
    end
    check(config.default=="hosted","Shadow Nexus remains the default")
    check(config.label==(locale=="zh" and "暗影枢纽" or "Shadow Nexus"),"new feature name in both locales")
    check(#config.options==2 and config.options[1].data=="off" and config.options[2].data=="hosted","only off and the new mechanism are offered")
    check(not names["World Exchange Shards"],"no retired shard-count option")
end
check(not main_source:find('modimport("easy_other/worldexchange.lua")',1,true),"retired runtime is not imported")
check(main_source:find('modimport("easy_other/shadowvault.lua")',1,true),"new runtime is integrated in the mod")
for _,mode in ipairs({"hosted","coordinated","classic","traditional","off",false})do
    for _,buttons in ipairs({true,false})do
        check(Config.Enabled(mode,buttons)==(mode~="off" and buttons),"legacy setting resolves to the new mechanism and respects disabled buttons")
    end
end
check(Config.Enabled(nil,true),"missing old setting uses new default")
for _,mode in ipairs({"hosted","coordinated","classic","off"})do
    local hooks,shards,server,client,imports={},{},{},{},{}
    local originals={SaveGame=function()end,RequestShutdown=function()end,DoRestart=function()end,
        ResumeExistingUserSession=function()end,SerializeUserSession=function()end,WorldRollbackFromSim=function()end}
    local globals={};for k,v in pairs(originals)do globals[k]=v end
    local e=env({GLOBAL=globals,TUNING={},PrefabFiles={},
        GetModConfigData=function(key)return key=="World Exchange" and mode or true end,
        require=function(name)
            if name=="shadowvaultconfig2hm"then return Config end
            if name=="containers"then return {params={shadow_container={}}}end
            if name=="worldexchangerpc2hm"then return {Install=function()end}end
            if name=="shadowvaultcourier2hm"then return {}end
            error("unexpected runtime dependency "..name)
        end,
        AddPrefabPostInit=function(name,fn)hooks[name]=fn end,
        AddComponentPostInit=function()end,AddPlayerPostInit=function()end,
        AddShardModRPCHandler=function(_,name,fn)shards[name]=fn end,
        AddModRPCHandler=function(_,name,fn)server[name]=fn end,
        AddClientModRPCHandler=function(_,name,fn)client[name]=fn end,
        GetShardModRPC=function(_,name)return name end,GetShardModRPCHandler=function()return function()end end,
        modimport=function(path)imports[path]=true end})
    execute(entry_source,e);execute(player_source,e)
    local world={ismastersim=true,added={},AddComponent=function(self,name)self.added[name]=true end}
    hooks.world(world)
    check(world.added.shadowvault2hm and world.added.worldexchange2hm,"new vault plus passive old-save reader installed")
    check(shards.shadowvault_v1 and not shards.shadowvault_migrate and not shards.worldexchange_v1,"no old exchange or cutover RPC")
    check(not server.worldexchange_exit and not client.worldexchange_exit,"no coordinated exit permission RPC")
    check(imports["easy_other/shadowvaultplayer.lua"],"native player receipts observer is installed")
    for k,v in pairs(originals)do check(globals[k]==v,"native "..k.." remains unchanged")end
end
local Legacy=execute(legacy_source,env())
local reads,locked=0,false
local world={GetPocketDimensionContainer=function(_,name)reads=reads+1;check(name=="shadow","original container name");return {components={container={EnableReadOnlyContainer=function(_,value)locked=value end}}}end}
local legacy=Legacy(world);legacy:OnLoad({active={name="shadow",phase="intent",own={items={gold=17}}}});legacy:LoadPostPass()
check(locked and reads==1 and legacy:OnSave().active.own.items.gold==17,"unfinished legacy records preserve custody")
check(not legacy.Update and not legacy.Request and not legacy.Packet and not legacy.task,"compatibility reader cannot run coordinated exchange")
legacy=Legacy(world);legacy:OnLoad({closed={old={seq=1}}})
check(legacy:OnSave()==nil,"completed legacy save needs no coordinator state")
print("Shadow Nexus integration: "..checks.." checks passed")
