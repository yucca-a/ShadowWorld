local Config = {}
local TACKLE_PREFIX = "tackle_"
-- PocketDimensionContainers also includes per-player offline-drop storage.
-- Registration as a pocket container does not make it a shared world space.
function Config.Manageable(family, entity)
    return type(family)=="string" and not family:match("^legacycontainer_") and
        entity~=nil and not (type(entity.userid)=="string" and entity.userid~="")
end
function Config.ProtectPreserver(entity)
    local c=entity.components and entity.components.container
    local p=entity.components and entity.components.preserver
    if not c or not p or p.shadowvault_guarded2hm then return end
    p.shadowvault_guarded2hm=true
    -- Native read-only containers freeze contents only when they add their own
    -- preserver. Keep existing mod preservers, but freeze during page handoff
    -- too, so an item cannot rot into/out of a locked native container.
    local perish,temperature=p.GetPerishRateMultiplier,p.GetTemperatureRateMultiplier
    function p:GetPerishRateMultiplier(item)
        return c.readonlycontainer and 0 or perish(self,item)
    end
    function p:GetTemperatureRateMultiplier(item)
        return c.readonlycontainer and 0 or temperature(self,item)
    end
end
local function unhex(value)
    return (value:gsub("%x%x",function(pair)return string.char(tonumber(pair,16))end))
end
function Config.Page(shard,family)
    if family=="shadow" then return tostring(shard) end
    if family=="tacklestation2hm" then return TACKLE_PREFIX..shard end
    local hex=family:gsub(".",function(char)return string.format("%02x",char:byte())end)
    return "pocket_"..hex.."_"..shard
end
function Config.Family(page)
    local hex=page:match("^pocket_([%x]+)_[%w_%-]+$")
    if hex then return unhex(hex) end
    return Config.IsTacklePage(page) and "tacklestation2hm" or "shadow"
end
function Config.Concurrent(page)
    local family=Config.Family(page)
    -- Dynamic mod containers retain their native capacity/upgrade manager and
    -- whole-page handoff. Shared item coordination is enabled for these two.
    return family=="shadow"or family=="tacklestation2hm"
end
function Config.Definition(family)
    for _,definition in ipairs(require("prefabs/pocketdimensioncontainer_defs").POCKETDIMENSIONCONTAINER_DEFS) do
        if definition.name==family then return definition end
    end
    local base=TheWorld and TheWorld.PocketDimensionContainers and TheWorld.PocketDimensionContainers[family]
    if base and base:IsValid() and base.components.container then
        return {name=family,prefab=base.prefab}
    end
end
function Config.SpawnPage(page)
    local family=Config.Family(page)
    local definition=Config.Definition(family)
    if not definition then return end
    local world=TheWorld
    local setter=world.SetPocketDimensionContainer
    local original=world.PocketDimensionContainers and world.PocketDimensionContainers[family]
    -- Native constructors register their singleton. A second real container
    -- must retain the original singleton and its existing entrance bindings.
    world.SetPocketDimensionContainer=function(inst,name,entity)
        if name~=family then return setter(inst,name,entity) end
    end
    local ok,entity=pcall(SpawnPrefab,definition.prefab)
    world.SetPocketDimensionContainer=setter
    if world.PocketDimensionContainers then world.PocketDimensionContainers[family]=original end
    if not ok then print("[ShadowVault2hm] native page spawn",entity);return end
    if entity then Config.ProtectPreserver(entity) end
    return entity
end
function Config.TacklePage(shard)
    return TACKLE_PREFIX .. shard
end
function Config.IsTacklePage(page)
    return page:sub(1, #TACKLE_PREFIX) == TACKLE_PREFIX
end
function Config.PageShard(page)
    local shard=page:match("^pocket_[%x]+_([%w_%-]+)$")
    if shard then return shard end
    return Config.IsTacklePage(page) and page:sub(#TACKLE_PREFIX+1) or page
end
function Config.PagePrefab(page)
    local definition=Config.Definition(Config.Family(page))
    if definition then return definition.prefab end
    return Config.IsTacklePage(page) and "shadowvaulttacklepage2hm" or "shadowvaultpage2hm"
end
function Config.SameSpace(a, b)
    return Config.Family(a) == Config.Family(b)
end
function Config.Enabled(mode, buttons)
    return require("exchangemode2hm").Normalize(mode)=="hosted" and buttons and true or false
end
function Config.ActiveSave(native)
    local data = native and native.map and native.map.persistdata and native.map.persistdata.shadowvault2hm
    return type(data) == "table" and data.version == 1 and data.status == "active"
end
function Config.Parse(name)
    if type(name) ~= "string" or #name > 512 then return end
    local op, page, slot, uid, nonce, token, session = name:match("^([DWIHJTPSQK]):([%w_%-]+):(%d+):([%w_%-]+):([%w_%-]+):([%w_%-]+):([%w_%-]+)$")
    if not op then op, page, slot, uid, nonce = name:match("^([DWI]):([%w_%-]+):(%d+):([%w_%-]+):([%w_%-]+)$") end
    slot = tonumber(slot)
    if not op or not slot or slot > 1000 or (token and (not Config.ValidStamp(token) or not Config.ValidStamp(session))) then return end
    local requested_count=tonumber(nonce:match("_n(%d+)$"))
    if requested_count and (requested_count<1 or requested_count>1000000000)then return end
    return {op=op, page=page, slot=slot, userid=uid, nonce=nonce, token=token, session=session,
        requested_count=requested_count,paired=nonce:match("_s1$")and true or nil}
end
function Config.ValidStamp(value)
    return type(value)=="string" and #value>0 and #value<=120 and value:match("^[%w_%-]+$")~=nil
end
function Config.QuickStoreSlot(catalog,prefab,skin)
    local empty
    for slot=1,catalog.slots do
        local key=tostring(slot)
        if not catalog.pending or not catalog.pending[key] then
            local entry=catalog.items[key]
            if not entry then empty=empty or slot
            elseif entry.prefab==prefab and entry.skin==skin and entry.room and entry.room>0 then return slot end
        end
    end
    return empty
end
function Config.StatusText(state,zh)
    local mode=state and state.mode
    if mode=="delivery" then
        local item=(state.name or "?").." ×"..tostring(state.count or 1)
        return zh and (item.."（来自"..(state.page_name or state.page or "?").."）已暂存；腾出背包位置后自动领取。") or
            (item.." from "..(state.page_name or state.page or "?").." is held for you. Free inventory space to receive it.")
    end
    local messages={
        preparing={"正在确认存取，请稍候。","Confirming transfer. Please wait."},
        finishing={"传输已确认，正在完成交付。","Transfer confirmed; completing delivery."},
        busy={"已有存取正在处理，请稍后重试。","A transfer is in progress. Please retry shortly."},
        stale={"空间内容已变化，已刷新；请重新选择物品。","The space changed. Refreshed; select the item again."},
        cursor={"手持物品已变化，请重新确认要存入的物品。","Your held item changed. Select the item to deposit again."},
        holditem={"请先拿起要存入的物品。","Pick up the item you want to deposit first."},
        unsupported={"这件物品暂不支持安全存入空间，已保留在原处。","This item cannot be stored safely in this space; it remains where it was."},
        full={"这叠物品已满。","This stack is full."},
        done={"存取已完成。","Transfer complete."},
        cancelled={"本次存取未完成，物品已保留。","Transfer not completed; items retained."},
        offline={"主世界暂未连接，物品保持原位。","The master is disconnected; items remain in place."},
        recovery={"物品已保留待恢复，请查看服务器日志。","Items held for recovery; check the server log."},
        limit={"待交付物品较多，请先腾出背包位置。","Too many pending deliveries. Free inventory space first."},
    }
    local message=messages[mode]
    return message and message[zh and 1 or 2] or ""
end
function Config.Order(registry, page)
    local ids = {}
    for id in pairs(registry) do
        if not page or Config.SameSpace(id, page) then ids[#ids+1] = id end
    end
    table.sort(ids, function(a,b)
        local x,y=tonumber(Config.PageShard(a)),tonumber(Config.PageShard(b))
        if x and y then return x<y end
        return a<b
    end)
    return ids
end
return Config
