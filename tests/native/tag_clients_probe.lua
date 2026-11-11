local G=GLOBAL
G.setmetatable(env,{__index=function(_,k)return G.rawget(G,k)end})
local json=require("json")
local A={players={},snapshots={}}
G.TagClientAudit=A
local function emit(row)print("[TAG AUDIT] "..json.encode(row))end
local function tags(p)
    if not p or not p:IsValid()then return {}end
    local s=p.entity:GetDebugString():match("Tags: (.+)\nPrefab:")or""
    local out={};for tag in s:gmatch("%S+")do out[#out+1]=tag end
    table.sort(out);return out
end
local function source(fn)
    if type(fn)~="function"then return type(fn)end
    local i=debug.getinfo(fn,"S");return i.source..":"..i.linedefined
end
local recipes={"spear","armorwood","goldenshovel","researchlab2","nightmarefuel","book_birds","slingshot","transistor"}
local function recipeindex(p)
    local builder=p.components.builder or p.replica.builder
    local result={}
    for name,recipe in pairs(AllRecipes)do
        result[name]={rpc_id=recipe.rpc_id,product=recipe.product,known=not not builder:KnowsRecipe(recipe)}
    end
    return result
end
local function state(p)
    local r={userid=p.userid,prefab=p.prefab,tags=tags(p),extra=tags(p.mt_tagentity),has_source=source(p.HasTag),add_source=source(p.AddTag),
        mt_count=p.mt_tagcount,mt_ref=p.mt_net_tagentity and p.mt_net_tagentity:value()and true or false,
        mt_cached=p.mt_tagentity and p.mt_tagentity:IsValid()or false,knows={}}
    r.proxies={}
    for _,ref in ipairs(p.tagsentities or {})do
        local proxy=ref:value()
        r.proxies[#r.proxies+1]=tags(proxy)
    end
    r.pressure={}
    for i=1,PRESSURE_TAGS do r.pressure[i]=not not p:HasTag("tagpressure2hm_"..i)end
    local builder=p.components.builder or p.replica.builder
    r.builder_source=builder and source(builder.KnowsRecipe)
    if G.TAG_NET_TRACE then
        r.body_schema_count=G.TAG_NET_TRACE[p.GUID] and #G.TAG_NET_TRACE[p.GUID]
        local classified=p.player_classified or (p.replica.builder and p.replica.builder.classified)
        r.classified_schema_count=classified and G.TAG_NET_TRACE[classified.GUID] and #G.TAG_NET_TRACE[classified.GUID] or nil
    end
    if builder then for _,name in ipairs(recipes)do r.knows[name]=not not builder:KnowsRecipe(AllRecipes[name])end end
    return r
end
local function invcount(p,name)
    local _,n=p.components.inventory:Has(name,1,true);return n
end
local function serverstate()
    local all={}
    for _,p in ipairs(AllPlayers)do all[#all+1]=state(p)end
    return all
end
AddModRPCHandler("TagClientAudit","query",function(p,index,phase)
    local held=p.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local recipe=AllRecipes.spear
    local ingredients={};for _,i in ipairs(recipe.ingredients)do ingredients[#ingredients+1]={name=i.type,need=i.amount,carried=invcount(p,i.type)}end
    local data={index=index,phase=phase,players=serverstate(),gold=invcount(p,"goldnugget"),spears=invcount(p,"spear"),
        held=held and held.prefab,builds=p.tag_audit_builds or 0,canbuild=p.components.builder:CanBuild("spear"),ingredients=ingredients}
    emit({kind="server_snapshot",index=index,phase=phase,players=#data.players,gold=data.gold,spears=data.spears})
    SendModRPCToClient(GetClientModRPC("TagClientAudit","snapshot"),p.userid,json.encode(data))
    if G.TAG_NET_TRACE and phase==1 then
        TheSim:SetPersistentString("tag_schema_server_"..p.userid,json.encode({body=G.TAG_NET_TRACE[p.GUID],
            classified=p.player_classified and G.TAG_NET_TRACE[p.player_classified.GUID]}),false)
    end
    if phase==4 then
        TheSim:SetPersistentString("tag_recipes_server_"..p.userid,json.encode(recipeindex(p)),false)
    end
end)
AddClientModRPCHandler("TagClientAudit","snapshot",function(raw)A.received=json.decode(raw)end)
AddModRPCHandler("TagClientAudit","ready",function(p,index)
    emit({kind="network_client_ready",index=index,userid=p.userid,players=#AllPlayers})
    A.seen=A.seen or {}
    if index==3 and A.seen[p.userid]then
        for _,other in ipairs(AllPlayers)do
            if other~=p then SendModRPCToClient(GetClientModRPC("TagClientAudit","resume"),other.userid)end
        end
    end
    A.seen[p.userid]=true
end)
AddClientModRPCHandler("TagClientAudit","resume",function()A.started=false end)
AddModRPCHandler("TagClientAudit","gc",function()collectgarbage("collect")end)
AddSimPostInit(function()
    if TheNet:IsDedicated()then
        TheWorld:DoTaskInTime(1,function()print('[VAUDIT] {"kind":"ready"}')end)
        TheWorld:ListenForEvent("ms_playerjoined",function(_,p)
            p:DoTaskInTime(2,function()
                p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
                local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
                local index=#AllPlayers
                p.Transform:SetPosition(x+index*6,0,z)
                local chest=SpawnPrefab("treasurechest");chest.Transform:SetPosition(x+index*6+2,0,z)
                local gold=SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(7);chest.components.container:GiveItem(gold)
                for _,name in ipairs({"twigs","flint","rope"})do
                    local item=SpawnPrefab(name);item.components.stackable:SetStackSize(12);p.components.inventory:GiveItem(item)
                end
                local lab=SpawnPrefab("researchlab2");lab.Transform:SetPosition(x+index*6+1,0,z+1)
                p.components.builder:EvaluateTechTrees()
                p.components.builder:UnlockRecipe("spear")
                p:ListenForEvent("builditem",function(_,data)
                    p.tag_audit_builds=(p.tag_audit_builds or 0)+1
                    emit({kind="built_item",userid=p.userid,prefab=data.item and data.item.prefab})
                end)
                for i=1,PRESSURE_TAGS do p:AddTag("tagpressure2hm_"..i)end
                emit({kind="server_player_prepared",userid=p.userid,players=#AllPlayers,state=state(p)})
            end)
        end)
        return
    end
    TheWorld:DoStaticPeriodicTask(.5,function()
        local p=ThePlayer
        if not p or not p.HUD or A.started then return end
        A.started=true
        p:StartThread(function()
            Sleep(5)
            local index=G.TAG_CLIENT_INDEX or 0
            emit({kind="client_ready",index=index,userid=p.userid})
            SendModRPCToServer(GetModRPC("TagClientAudit","ready"),index)
            local stable=0
            for phase=1,100 do
                A.received=nil
                SendModRPCToServer(GetModRPC("TagClientAudit","query"),index,phase)
                local deadline=GetStaticTime()+10
                repeat Sleep(.1)until A.received or GetStaticTime()>deadline
                assert(A.received,"snapshot RPC")
                local expected=A.received
                if phase==4 then
                    TheSim:SetPersistentString("tag_recipes_client_"..p.userid,json.encode(recipeindex(p)),false)
                end
                local observed={};local mismatches={}
                for _,s in ipairs(expected.players)do
                    local q
                    for _,e in ipairs(AllPlayers)do if e.userid==s.userid then q=e;break end end
                    if q then
                        local r=state(q);observed[#observed+1]=r
                        for _,tag in ipairs(s.tags)do
                            if tag~="FROMNUM" and not q:HasTag(tag)then mismatches[#mismatches+1]={userid=s.userid,tag=tag,where="body"}end
                        end
                        for _,tag in ipairs(s.extra)do
                            if tag~="FROMNUM" and not q:HasTag(tag)then mismatches[#mismatches+1]={userid=s.userid,tag=tag,where="extra"}end
                        end
                        for _,proxy in ipairs(s.proxies or {})do
                            for _,tag in ipairs(proxy)do
                                if tag~="FROMNUM" and tag~="DECOR" and tag~="NOCLICK" and not q:HasTag(tag)then
                                    mismatches[#mismatches+1]={userid=s.userid,tag=tag,where="internal_proxy"}
                                end
                            end
                        end
                        for i,present in ipairs(s.pressure or {})do
                            if present~=r.pressure[i]then mismatches[#mismatches+1]={userid=s.userid,tag="tagpressure2hm_"..i,where="pressure"}end
                        end
                        if q==p then
                            for name,known in pairs(s.knows)do
                                if known~=r.knows[name]then mismatches[#mismatches+1]={userid=s.userid,recipe=name,server=known,client=r.knows[name]}end
                            end
                        end
                    else mismatches[#mismatches+1]={userid=s.userid,missing_player=true}end
                end
                local compact={}
                for _,r in ipairs(observed)do compact[#compact+1]={userid=r.userid,prefab=r.prefab,
                    tags=#r.tags,extra=#r.extra,mt_ref=r.mt_ref,knows=r.userid==p.userid and r.knows or nil}end
                emit({kind="client_snapshot",index=index,phase=phase,players=#expected.players,
                    stable=stable,
                    gold=expected.gold,spears=expected.spears,held=expected.held,builds=expected.builds,
                    canbuild=expected.canbuild,ingredients=expected.ingredients,observed=compact,mismatches=mismatches})
                TheSim:SetPersistentString("tag_audit_"..index.."_"..phase,
                    json.encode({server=expected,observed=observed,mismatches=mismatches}),false)
                if #expected.players >= EXPECTED_CLIENTS then stable=stable+1 end
                if stable==2 then
                    SendModRPCToServer(GetModRPC("MOD_HARDMODE","collectrecipetypebtn2hm"),"goldnugget",3)
                elseif stable==3 then
                    p.replica.builder:MakeRecipeFromMenu(AllRecipes.spear)
                elseif stable==4 then
                    SendModRPCToServer(GetModRPC("TagClientAudit","gc"))
                    collectgarbage("collect")
                    if G.TAG_NET_TRACE then
                        local classified=p.player_classified or (p.replica.builder and p.replica.builder.classified)
                        TheSim:SetPersistentString("tag_schema_client_"..p.userid,json.encode({body=G.TAG_NET_TRACE[p.GUID],
                            classified=classified and G.TAG_NET_TRACE[classified.GUID]}),false)
                    end
                elseif stable==5 then
                    local gold
                    for _,item in pairs(p.replica.inventory:GetItems())do if item.prefab=="goldnugget"then gold=item;break end end
                    if gold then
                        local pc=p.components.playercontroller
                        local pressed=TheInput.IsControlPressed
                        TheInput.IsControlPressed=function(self,control)
                            if control==CONTROL_FORCE_STACK then return true end
                            if control==CONTROL_FORCE_INSPECT or control==CONTROL_FORCE_TRADE then return false end
                            return pressed(self,control)
                        end
                        local ok,err=pcall(function()
                            local actions=p.components.playeractionpicker:GetInventoryActions(gold,true)
                            emit({kind="store_selected",index=index,action=actions[1]and actions[1].action.id})
                            assert(actions[1]and actions[1].action==ACTIONS.STORE2HM,"Ctrl-right-click store action missing")
                            pc:RemoteUseItemFromInvTile(actions[1],gold)
                        end)
                        TheInput.IsControlPressed=pressed
                        assert(ok,err)
                    end
                elseif stable==6 then
                    SendModRPCToServer(GetModRPC("MOD_HARDMODE","collectrecipetypebtn2hm"),"goldnugget",3)
                end
                if stable>=8 then break end
                Sleep(3)
            end
            emit({kind="client_finished",index=index,userid=p.userid,players=A.received and #A.received.players,
                gold=A.received and A.received.gold,spears=A.received and A.received.spears,
                held=A.received and A.received.held,builds=A.received and A.received.builds})
        end)
    end)
end)
