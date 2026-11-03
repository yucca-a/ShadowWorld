local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function execute(source, env)
    local fn = assert(loadstring(source)); setfenv(fn, env); return fn()
end
local function environment(values) return setmetatable(values or {}, {__index = _G}) end

for _, locale in ipairs({"zh", "en"}) do
    local env = environment({locale = locale})
    execute(info_source, env)
    local config, names = nil, {}
    for _, option in ipairs(env.configuration_options) do
        if option.name == "World Exchange" then config = option end
        if option.name ~= "" then check(not names[option.name], "unique config " .. option.name); names[option.name] = true end
    end
    check(config and config.default == "coordinated", "new mode defaults to coordinated")
    check(#config.options == 3 and config.options[1].data == false and
        config.options[2].data == "traditional" and config.options[3].data == "coordinated", "three selectable tiers")
    if locale == "zh" then check(config.options[2].description == "传统", "traditional tier named as requested") end
end

-- Run the actual early mode selection and world-component installation.
for _, mode in ipairs({false, "traditional", "coordinated", "missing"}) do
    for _, buttons in ipairs({false, true}) do
        local engine, hook = {}, nil
        local env = environment({require = function() return engine end,
            GetModConfigData = function(key)
                if key == "World Exchange" then if mode == "missing" then return nil end; return mode end
                return buttons
            end,
            AddPrefabPostInit = function(_, fn) hook = fn end})
        execute(mode_source, env)
        local enabled = buttons and (mode == "coordinated" or mode == "missing")
        check(engine.enabled == enabled, "mode and existing button gates")
        execute(install_source, env)
        for _, saved in ipairs({false, "loaded", "legacy"}) do
            engine.boot = saved and {[saved] = true} or nil
            local world = {ismastersim = true, components = {}, AddComponent = function(self) self.added = true end}
            hook(world)
            check((world.added == true) == (enabled or saved ~= false), "existing checkpoint recovery survives mode changes")
        end
    end
end

local now, queue, nodes = 0, {}, {}
local function schedule(node, delay, fn, inst, ...)
    local args = {...}
    local task = {at = now + delay, Cancel = function(self) self.cancelled = true end}
    task.run = function() fn(inst, unpack(args)) end
    queue[#queue + 1] = task
    return task
end
local function advance(seconds)
    local untiltime = now + seconds
    while true do
        local idx
        for i, task in ipairs(queue) do
            if task.at <= untiltime and (not idx or task.at < queue[idx].at) then idx = i end
        end
        if not idx then break end
        local task = table.remove(queue, idx); now = task.at
        if not task.cancelled then task.run() end
    end
    now = untiltime
end
local function node(id, mode, contents)
    local n = {id = id, rpc = {}, shardrpc = {}, pauses = 0, modern = 0, tags = {pocketdimension_container = true}}
    local box = {tags = n.tags, components = {}, replica = {}, IsValid = function() return true end}
    function box:HasTag(tag) return self.tags[tag] end
    function box:AddTag(tag) self.tags[tag] = true end
    function box:RemoveTag(tag) self.tags[tag] = nil end
    function box:DoTaskInTime(delay, fn, ...) return schedule(n, delay, fn, self, ...) end
    box.DoStaticTaskInTime = box.DoTaskInTime
    n.box = box
    n.player = {name = id, IsValid = function() return true end, components = {talker = {Say = function(_, s) n.said = s end}}}
    local container = {numslots = 0, slots = {}, contents = contents, openlist = {[n.player] = true}}
    function container:OnSave() return {contents = self.contents} end
    function container:OnLoad(data) self.contents = data.contents end
    function container:DestroyContents() self.contents = nil end
    box.components.container = container
    n.world = {ismastersim = true, components = {}, PocketDimensionContainers = {shadow = box},
        GetPocketDimensionContainer = function(_, name) if name == "shadow" then return box end end}
    n.env = environment({worldexchangecfg = mode ~= false, traditionalexchange = mode == "traditional",
        TheWorld = n.world, TheShard = {GetShardId = function() return id end},
        ShardList = {["1"] = true, ["2"] = true}, Shard_IsWorldAvailable = function() return true end,
        TUNING = {isCh2hm = true}, FRAMES = 1 / 30,
        AddModRPCHandler = function(_, name, fn) check(not n.rpc[name], "single client RPC registration"); n.rpc[name] = fn end,
        AddShardModRPCHandler = function(_, name, fn) check(not n.shardrpc[name], "single shard RPC registration"); n.shardrpc[name] = fn end,
        GetShardModRPC = function(_, name) return name end,
        SendModRPCToShard = function(name, _, target, ...)
            local args = {...}
            if n.drop == name then return end
            local peer = nodes[tostring(target)]
            if peer then schedule(peer, 0, function() peer.shardrpc[name](id, target, unpack(args)) end) end
        end,
        SetServerPaused = function() n.paused = true; n.pauses = n.pauses + 1 end,
        TheNet = {IsServerPaused = function() return n.paused end,
            SetServerPaused = function(_, paused) n.paused = paused end, Announce = function() end}})
    execute(exchange_source, n.env)
    nodes[id] = n
    return n
end
local function pair(mode1, mode2)
    now, queue, nodes = 0, {}, {}
    return node("1", mode1, "gold:17"), node("2", mode2, "spear:2")
end
local function request(n) n.rpc.exchangebtn2hm(n.player, n.box) end
local function contents(n) return n.box.components.container.contents end
local function service(n, ready)
    local core = {CanExchange = function() return ready end, IsReady = function() return ready end}
    local s = {Initialize = function() end, protocol = {}, engine = {core = core},
        Request = function() n.modern = n.modern + 1 end}
    n.world.components.worldexchange2hm = s
    return s
end

local a, b = pair("traditional", "traditional")
service(a, true); service(b, true)
request(a); advance(4)
check(contents(a) == "spear:2" and contents(b) == "gold:17", "traditional handshake swaps exact contents")
check(a.modern == 0 and b.modern == 0, "traditional never starts coordinated transaction")
check(not a.box:HasTag("exchangeloading2hm") and not b.box:HasTag("exchangeloading2hm"), "traditional completion clears busy tags")
request(b); advance(4)
check(contents(a) == "gold:17" and contents(b) == "spear:2", "reverse-direction exchange works")

a, b = pair("traditional", "traditional")
a.drop = "exchangesenddata2hm"
request(a); advance(4)
check(contents(a) == "gold:17" and contents(b) == "spear:2", "lost initial message restores source contents")
check(not a.box.containersendtask2hm and not a.box:HasTag("exchangeloading2hm"), "timeout removes traditional busy state")
a.drop = nil
a.rpc.pausebtn2hm(a.player, a.box)
check(a.paused, "traditional exposes original optional pause")
advance(31); check(not a.paused, "traditional pause expires after 30 seconds")

for _, mode in ipairs({false, "coordinated"}) do
    a, b = pair("traditional", mode)
    request(a); advance(4)
    check(contents(a) == "gold:17" and contents(b) == "spear:2", "different mode ignores legacy packets and source restores")
    b.rpc.pausebtn2hm(b.player, b.box)
    check(b.pauses == 0, "legacy pause RPC cannot bypass chosen mode")
    service(b, true); request(b)
    check(b.modern == (mode == "coordinated" and 1 or 0), "new requests respect configured mode")
end

a, b = pair("traditional", "traditional")
a.box.components.container.openlist = {}
request(a); a.rpc.pausebtn2hm(a.player, a.box)
check(contents(a) == "gold:17" and #queue == 0 and a.pauses == 0, "closed container rejects exchange and pause")
a.box.components.container.openlist[a.player] = true
service(a, false); request(a); a.rpc.pausebtn2hm(a.player, a.box)
check(contents(a) == "gold:17" and #queue == 0 and a.pauses == 0, "checkpoint recovery blocks new traditional requests")
service(a, true); service(b, false); request(a); advance(4)
check(contents(a) == "gold:17" and contents(b) == "spear:2", "recovering recipient rejects traditional transfer")
local s = service(a, true); s.protocol.active = {name = "shadow"}
request(a); check(contents(a) == "gold:17", "unfinished saved transaction blocks traditional exchange")
s.protocol.active = nil; a.box.components.container.readonlycontainer = true
request(a); check(contents(a) == "gold:17", "read-only source is protected")

-- Checkpoint draining must wait for all upstream exchange timer stages.
local Engine = {}
execute(idle_source, environment({Engine = Engine, AllPlayers = {}}))
local e = setmetatable({service = {protocol = {}, inst = {components = {}, PocketDimensionContainers = {shadow = {}}}},
    Writing = function() return false end}, {__index = Engine})
for _, field in ipairs({"containersendtask2hm", "containerreceivetask2hm", "exchangeconfirmtask2hm"}) do
    e.service.inst.PocketDimensionContainers.shadow[field] = {}
    check(not e:Idle(), "cannot checkpoint temporary contents during " .. field)
    e.service.inst.PocketDimensionContainers.shadow[field] = nil
end
check(e:Idle(), "checkpoint can proceed after legacy completion or timeout")
print("Exchange mode checks: " .. checks .. " (Lua 5.1; native serializer; simulated shards/timers)")
