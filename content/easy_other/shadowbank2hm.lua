-- Adapted from the user-provided test.zip; transfer and UI semantics retained.
TUNING.shadowbankclassic2hm = TUNING.EXCHANGE_MODE2HM == "xianyu"
local CHUNK, LIMIT = 6500, 32
local sequence, inbox = 0, {}
local transportid = tostring(os.time()) .. "/" .. tostring(math.random(1, 1073741823))

local function sendchunks(send, data)
    local raw = DataDumper(data, nil, true)
    if #raw > CHUNK * LIMIT then return end
    sequence = sequence + 1
    local total = math.max(1, math.ceil(#raw / CHUNK))
    for part = 1, total do send(transportid .. "/" .. sequence, part, total, raw:sub((part - 1) * CHUNK + 1, part * CHUNK)) end
end

local function receive(peer, id, part, total, raw, apply)
    if type(id) ~= "string" or #id > 150 or type(part) ~= "number" or type(total) ~= "number" or type(raw) ~= "string" or
        total < 1 or total > LIMIT or part < 1 or part > total or part % 1 ~= 0 or total % 1 ~= 0 or #raw > CHUNK then return end
    local now = GetTime()
    for key, entry in pairs(inbox) do if now - entry.time > 8 then inbox[key] = nil end end
    local key = tostring(peer) .. "/" .. id
    local entry = inbox[key]
    if not entry then entry = {time = now, total = total, count = 0, parts = {}}; inbox[key] = entry end
    if entry.total ~= total then return end
    if not entry.parts[part] then entry.parts[part] = raw; entry.count = entry.count + 1 end
    if entry.count == total then
        inbox[key] = nil
        local ok, data = RunInSandboxSafe(table.concat(entry.parts))
        if ok and type(data) == "table" then apply(data) end
    end
end

TUNING.util2hm.ShadowBankSend = function(peer, data)
    sendchunks(function(...)
        SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "shadowbank2hm"), tostring(peer), ...)
    end, data)
end

TUNING.util2hm.ShadowBankClient = function(uid, data)
    sendchunks(function(...)
        SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "shadowbank2hm"), uid, ...)
    end, data)
end

AddShardModRPCHandler("MOD_HARDMODE", "shadowbank2hm", function(peer, id, part, total, raw)
    receive(peer, id, part, total, raw, function(data)
        local service = TheWorld and TheWorld.components.shadowbank2hm
        if service and service.enabled then service:Packet(peer, data) end
    end)
end)

AddClientModRPCHandler("MOD_HARDMODE", "shadowbank2hm", function(id, part, total, raw)
    if not TUNING.shadowbankclassic2hm then return end
    receive("client", id, part, total, raw, function(data)
        local current = TUNING.util2hm.shadowbankview2hm
        local changed = false
        if data.kind == "close" then
            if not current or not data.session or current.session == data.session then
                TUNING.util2hm.shadowbankview2hm = nil
                changed = true
            end
        elseif data.kind == "open" or (data.kind == "view" and current and current.session == data.session) then
            TUNING.util2hm.shadowbankview2hm = data
            changed = true
        end
        if changed and TheWorld then TheWorld:PushEvent("shadowbankviewdirty2hm") end
    end)
end)

AddModRPCHandler("MOD_HARDMODE", "shadowbankaction2hm", function(player, action, slot, token, mode, session, source)
    local Guard=require("rpcguard2hm")
    if not Guard.IsEntity(player) or type(action)~="string" or source~=nil and not Guard.IsEntity(source) then return end
    local service = TheWorld and TheWorld.components.shadowbank2hm
    if service and type(session) == "string" then service:Action(player, action, slot, token, mode, session, source) end
end)

AddPrefabPostInit("world", function(inst)
    if inst.ismastersim then inst:AddComponent("shadowbank2hm") end
end)

if not TUNING.shadowbankclassic2hm then return end

require("shadowbankview2hm")(AddClassPostConstruct)

AddPrefabPostInit("tacklestation", function(inst)
    if not TheWorld.ismastersim then return end
    local proxy = inst.components.container_proxy
    if not proxy then return end
    local open, onclose = proxy.Open, proxy.onclosefn
    proxy.Open = function(self, player, ...)
        if not TheShard:IsMaster() then
            if self.opencount > 0 then
                if player and player.components.talker then player.components.talker:Say(TUNING.isCh2hm and "请等其他玩家关闭钓具容器。" or "Wait for the other player to close the tackle station.") end
                return
            end
            local service = TheWorld.components.shadowbank2hm
            local remote = service and service:RemoteOpen(player, 4, inst)
            if not remote then return end
            self:SetMaster(remote)
            open(self, player, ...)
            if not self:IsOpenedBy(player) then
                self:SetMaster(TheWorld:GetPocketDimensionContainer("tacklestation2hm"))
                service:RemoteClose(player)
            end
        else
            return open(self, player, ...)
        end
    end
    proxy.onclosefn = function(station)
        if onclose then onclose(station) end
        local service = TheWorld.components.shadowbank2hm
        local owner
        if not TheShard:IsMaster() and service then
            for _, view in pairs(service.viewers) do
                if view.anchor == inst then owner = view.player; break end
            end
        end
        proxy:SetMaster(TheWorld:GetPocketDimensionContainer("tacklestation2hm"))
        if owner then service:RemoteClose(owner) end
    end
end)

AddComponentPostInit("magiciantool", function(tool)
    if not TheWorld.ismastersim then return end
    local setstart, setstop = tool.SetOnStartUsingFn, tool.SetOnStopUsingFn
    tool.SetOnStartUsingFn = function(self, start)
        setstart(self, function(hat, player)
            if hat.prefab ~= "tophat" then return start and start(hat, player) end
            local service = TheWorld.components.shadowbank2hm
            if TheShard:IsMaster() then
                if start then start(hat, player) end
                if player.shadowbanknumber2hm == 2 and hat.container then
                    service:Switch(player, hat.container.components.container_proxy:GetMaster())
                end
            else
                local remote = service:RemoteOpen(player, 2)
                if not remote then return end
                if not hat.container then
                    hat.container = SpawnPrefab("tophat_container")
                    hat.container.Network:SetClassifiedTarget(player)
                    hat.container.tophat = hat
                    hat.container.components.container_proxy:SetOnCloseFn(function()
                        hat.components.magiciantool:StopUsing()
                    end)
                end
                hat.container.components.container_proxy:SetMaster(remote)
                if start then start(hat, player) end
            end
        end)
    end
    tool.SetOnStopUsingFn = function(self, stop)
        setstop(self, function(hat, player)
            if stop then stop(hat, player) end
            if hat.prefab == "tophat" and not TheShard:IsMaster() then TheWorld.components.shadowbank2hm:RemoteClose(player) end
        end)
    end
end)

