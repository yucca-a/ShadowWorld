local Transfer = require("shadowbanktransfer2hm")
local Recovery = require("exchangexianyurecovery2hm")

local function playerbyid(uid)
    for _, player in ipairs(AllPlayers) do
        if player.userid == uid and player:IsValid() then return player end
    end
end

local function say(player, zh, en)
    if player and player.components.talker then player.components.talker:Say(TUNING.isCh2hm and zh or en) end
end

local function validbank(bank) return bank == 1 or bank == 2 or bank == 3 or bank == 4 end
local function istackle(bank) return bank == 3 or bank == 4 end

local ShadowBank = Class(function(self, inst)
    self.inst = inst
    self.enabled = TUNING.shadowbankclassic2hm == true
    self.epoch = tostring(os.time()) .. "/" .. tostring(math.random(1, 1073741823))
    self.mail, self.imports, self.viewers, self.remote = {}, {}, {}, {}
    self.transfer = self:NewTransfer()
    self.task = inst:DoPeriodicTask(1, function() self:Update() end)
end)

function ShadowBank:Recovering()
    return not self.enabled and self.savedversion and TUNING.EXCHANGE_MODE2HM=="classic"
end

function ShadowBank:ScheduleWork(bank)
    if not self.enabled then return end -- Recovery retries use Update, without remote UI work.
    if TheShard:IsMaster() and validbank(bank) then
        self.dirtybanks = self.dirtybanks or {}
        self.dirtybanks[bank] = true
    end
    if self.worktask then return end
    self.worktask = self.inst:DoTaskInTime(0, function()
        self.worktask = nil
        self.transfer:Tick(GetTime())
        self:DeliverMail()
        local dirty = self.dirtybanks
        self.dirtybanks = nil
        if dirty then
            for _, view in pairs(self.remote) do
                if dirty[view.bank] and GetTime() - view.time < 5 then
                    self:SendView(view.peer, view.uid, view.bank, view.session)
                end
            end
        end
        local now = GetTime()
        for key, message in pairs(self.transfer.pending) do
            local retry = self.transfer.retry[key]
            if Shard_IsWorldAvailable(message.peer) and (not retry or now >= retry) then
                self:ScheduleWork()
                break
            end
        end
    end)
end

function ShadowBank:NewTransfer(saved)
    return Transfer.new({boot = tostring(TheNet:GetSessionIdentifier()) .. "/" .. self.epoch,
        available = function(peer) return Shard_IsWorldAvailable(peer) end,
        send = function(peer, data) TUNING.util2hm.ShadowBankSend(peer, data) end,
        apply = function(peer, data)
            if data.kind == "take" then return self:Take(peer, data) end
            if data.kind == "sort" then
                if not self.enabled or not TheShard:IsMaster() then return true end
                local view = self.remote[tostring(peer) .. "/" .. tostring(data.uid)]
                local container = self:Bank(data.bank)
                if view and view.session == data.session and view.bank == data.bank and GetTime() - view.time < 5 and
                    container and TUNING.util2hm.ShadowBankSort then TUNING.util2hm.ShadowBankSort(container.inst) end
                return true
            end
            if data.kind == "item" then return self:ReceiveItem(peer, data) end
            return false
        end}, saved)
end

function ShadowBank:Bank(bank)
    if not TheShard:IsMaster() or not validbank(bank) then return end
    local inst
    if bank == 1 then inst = self.inst:GetPocketDimensionContainer("shadow")
    elseif bank == 2 then inst = self.inst.shadowbanksecond2hm
    elseif bank == 3 then inst = self.inst:GetPocketDimensionContainer("tacklestation2hm")
    else inst = self.inst.shadowbanktacklesecond2hm end
    return inst and inst:IsValid() and inst.components.container or nil
end

function ShadowBank:EnsureBanks()
    if self.enabled and TheShard:IsMaster() and not self.inst.shadowbanksecond2hm then SpawnPrefab("shadowbank_container2hm") end
    if self.enabled and TheShard:IsMaster() and self.inst:GetPocketDimensionContainer("tacklestation2hm") and
        not self.inst.shadowbanktacklesecond2hm then SpawnPrefab("shadowbank_tackle2hm") end
end

function ShadowBank:CanUse(player, view)
    if view and istackle(view.bank) then
        local anchor = view.anchor
        local proxy = anchor and anchor:IsValid() and anchor.components.container_proxy
        return self.enabled and player and player:IsValid() and proxy and proxy:GetMaster() == view.display and proxy:IsOpenedBy(player)
    end
    local magician = player and player:IsValid() and player.components.magician
    return self.enabled and magician and magician.item and magician.item:IsValid() and
        magician.item.components.magiciantool and magician.item.components.magiciantool.user == player
end

function ShadowBank:Token(item)
    return self.epoch .. "/" .. item.GUID .. "/" .. (item.components.stackable and item.components.stackable:StackSize() or 1)
end

function ShadowBank:Snapshot(bank)
    local container = self:Bank(bank)
    if not container then return end
    local data = {bank = bank, size = container.numslots, items = {}, frost = istackle(bank) and container.inst:HasTag("frostcore2hm") or nil}
    for slot, item in pairs(container.slots) do
        local replica = item.replica.inventoryitem
        if replica then
            local spoilage = item:HasTag("show_spoilage")
            for _, foodtype in pairs(FOODTYPE) do spoilage = spoilage or item:HasTag("edible_" .. foodtype) end
            data.items[slot] = {image = replica:GetImage(), atlas = replica:GetAtlas(), name = item:GetDisplayName(),
                prefab = item.prefab, stackable = item.components.stackable ~= nil,
                spoilage = spoilage and item.components.perishable ~= nil,
                percent = item.components.armor and item.components.armor:GetPercent() or
                    item.components.perishable and item.components.perishable:GetPercent() or
                    item.components.finiteuses and item.components.finiteuses:GetPercent() or
                    item.components.fueled and item.components.fueled:GetPercent() or nil,
                count = item.components.stackable and item.components.stackable:StackSize() or 1, token = self:Token(item)}
        end
    end
    return data
end

function ShadowBank:RemoteOpen(player, bank, anchor)
    if not istackle(bank) and not self:CanUse(player) then return end
    if istackle(bank) and (not self.enabled or not player or not player:IsValid() or not anchor or not anchor:IsValid()) then return end
    bank = validbank(bank) and bank or 2
    local previous = self.viewers[player.userid]
    if previous and (istackle(previous.bank) ~= istackle(bank) or istackle(bank) and previous.anchor ~= anchor) then return end
    local display = previous and previous.display
    if not display or not display:IsValid() then
        display = SpawnPrefab(istackle(bank) and "shadowbank_tackleremote2hm" or "shadowbank_remote2hm")
        if not display then return end
        display.Network:SetClassifiedTarget(player)
    end
    if istackle(bank) then player.shadowbanktacklenumber2hm = bank - 2 else player.shadowbanknumber2hm = bank end
    local session = self.epoch .. "/" .. player.GUID .. "/" .. tostring(GetTime())
    self.viewers[player.userid] = {player = player, bank = bank, session = session, display = display, anchor = anchor}
    TUNING.util2hm.ShadowBankClient(player.userid, {kind = "open", bank = bank, session = session})
    self:Poll(player.userid)
    return display
end

function ShadowBank:RemoteClose(player)
    local view = self.viewers[player.userid]
    self.viewers[player.userid] = nil
    TUNING.util2hm.ShadowBankClient(player.userid, {kind = "close", session = view and view.session})
    if view and view.display and view.display:IsValid() then view.display:Remove() end
    local legacy = self.inst:GetPocketDimensionContainer(view and istackle(view.bank) and "tacklestation2hm" or "shadow")
    if legacy and legacy.components.container:IsOpenedBy(player) then
        legacy.components.container:Close(player)
        player:PushEvent("closecontainer", {container = legacy})
    end
end

function ShadowBank:Poll(uid)
    local view = self.viewers[uid]
    if view then
        TUNING.util2hm.ShadowBankSend(SHARDID.MASTER,
            {kind = "view", uid = uid, bank = view.bank, session = view.session})
    end
end

function ShadowBank:SendView(peer, uid, bank, session)
    local snapshot = self:Snapshot(bank)
    if snapshot then
        snapshot.kind, snapshot.uid, snapshot.session = "view", uid, session
        TUNING.util2hm.ShadowBankSend(peer, snapshot)
    end
end

function ShadowBank:Packet(peer, data)
    if type(data) ~= "table" then return end
    local variants=self.inst.components.exchangevariants2hm
    if not (self.enabled or self:Recovering()) or variants and not variants.ready then return end
    if data.kind == "transfer" or data.kind == "ack" then
        self.transfer:Receive(peer, data)
        self:ScheduleWork(type(data.payload) == "table" and data.payload.bank)
        return
    end
    if not self.enabled then return end
    if TheShard:IsMaster() then
        if data.kind ~= "view" or not validbank(data.bank) or type(data.uid) ~= "string" or #data.uid > 100 or
            type(data.session) ~= "string" or #data.session > 160 then return end
        local key = tostring(peer) .. "/" .. data.uid
        self.remote[key] = {peer = peer, uid = data.uid, bank = data.bank, session = data.session, time = GetTime()}
        self:SendView(peer, data.uid, data.bank, data.session)
    elseif tostring(peer) == tostring(SHARDID.MASTER) then
        local view = self.viewers[data.uid]
        if data.kind == "view" and view and view.bank == data.bank and view.session == data.session then
            view.snapshot = data
            if istackle(view.bank) and view.display and view.display:IsValid() then
                if data.frost then view.display:AddTag("frostcore2hm") else view.display:RemoveTag("frostcore2hm") end
            end
            local legacy = self.inst:GetPocketDimensionContainer(istackle(view.bank) and "tacklestation2hm" or "shadow")
            data.legacy = legacy and next(legacy.components.container.slots) ~= nil or false
            TUNING.util2hm.ShadowBankClient(data.uid, data)
        end
    end
end

function ShadowBank:CanTransfer(item, player)
    local record, refs = item:GetSaveRecord()
    if not record then return false end
    if refs and next(refs) then
        say(player, "这件物品关联了世界实体，请带回主世界存放。", "This item references world entities; deposit it on the surface.")
        return false
    end
    if #DataDumper(record, nil, true) > 180000 then
        say(player, "这件物品的数据太大，请带回主世界存放。", "This item is too large to transfer; deposit it on the surface.")
        return false
    end
    return record ~= nil
end

function ShadowBank:SendItem(peer, item, kind, uid, bank, options)
    local record = item:GetSaveRecord()
    local key = self.transfer:Queue(peer, {kind = "item", record = record, purpose = kind, uid = uid, bank = bank,
        slot = options and options.slot, targettoken = options and options.targettoken, active = options and options.active})
    if not key then return false end
    local inventoryitem = item.components.inventoryitem
    if inventoryitem.owner then
        local owner = inventoryitem.owner.components.container or inventoryitem.owner.components.inventory
        local ignore = owner and owner.ignoreoverstacked
        if owner then owner.ignoreoverstacked = true end
        local removed = inventoryitem:RemoveFromOwner(true, false)
        if owner then owner.ignoreoverstacked = ignore end
        if removed ~= item then self.transfer:Cancel(key); return false end
    end
    item:Remove()
    self:ScheduleWork(bank)
    return true
end

function ShadowBank:Action(player, action, slot, token, mode, session, source)
    local view = self.viewers[player.userid]
    if not self:CanUse(player, view) or TheShard:IsMaster() then return end
    if not view or (session and session ~= view.session) or (view.nextaction and GetTime() < view.nextaction) then return end
    view.nextaction = GetTime() + .2
    if action == "switch" then
        return self:RemoteOpen(player, istackle(view.bank) and (view.bank == 3 and 4 or 3) or (view.bank == 1 and 2 or 1), view.anchor)
    end
    if action == "refresh" then return self:Poll(player.userid) end
    if action == "sort" then
        local key = self.transfer:Queue(SHARDID.MASTER, {kind = "sort", uid = player.userid, bank = view.bank, session = view.session})
        if key then self:ScheduleWork() end
        return key
    end
    if action == "private" then
        if TUNING.util2hm.OpenMagicianPrivate2hm and TUNING.util2hm.CanUseMagicianPrivate2hm and
            TUNING.util2hm.CanUseMagicianPrivate2hm(player) then
            TUNING.util2hm.OpenMagicianPrivate2hm(nil, player)
            TUNING.util2hm.ShadowBankClient(player.userid, {kind = "suspend", session = view.session})
        end
        return
    end
    if action == "legacy" then
        local legacy = self.inst:GetPocketDimensionContainer(istackle(view.bank) and "tacklestation2hm" or "shadow")
        if legacy and next(legacy.components.container.slots) then
            player:PushEvent("opencontainer", {container = legacy})
            legacy.components.container:Open(player)
            TUNING.util2hm.ShadowBankClient(player.userid, {kind = "suspend", session = view.session})
        end
        return
    end
    if not Shard_IsWorldAvailable(SHARDID.MASTER) then
        return say(player, "主世界暂未连接，请稍后重试。", "The surface is disconnected. Please retry later.")
    end
    if action == "deposit" or action == "depositinventory" then
        local inventory = player.components.inventory
        local item = inventory and inventory:GetActiveItem()
        if action == "depositinventory" then
            local owner = source and source:IsValid() and source.components.inventoryitem and source.components.inventoryitem.owner
            local container = owner and (owner.components.inventory or owner.components.container)
            if not container or not container:IsOpenedBy(player) then return end
            item = source
        end
        if not item then return say(player, "请先用鼠标拿起要存入的物品。", "Pick up the item with your cursor first.") end
        if source and item ~= source then return end
        if slot ~= nil and (type(slot) ~= "number" or slot % 1 ~= 0 or not view.snapshot or slot < 1 or slot > view.snapshot.size) then return end
        if not self:CanTransfer(item, player) then return end
        if not self.transfer:CanQueue() then return end
        if (mode == "one" or mode == "half") and item.components.stackable and item.components.stackable:StackSize() > 1 then
            item = item.components.stackable:Get(mode == "one" and 1 or math.ceil(item.components.stackable:StackSize() / 2))
        end
        if not self:SendItem(SHARDID.MASTER, item, "deposit", player.userid, view.bank, {slot = slot, targettoken = slot and (token or "")}) then
            say(player, "还有物品在传送中，请稍后再存。", "Transfers are still pending. Please retry later.")
        end
    elseif action == "take" and type(slot) == "number" and slot % 1 == 0 and type(token) == "string" then
        local snapshot = view.snapshot
        local entry = snapshot and snapshot.items and snapshot.items[slot]
        if not entry or entry.token ~= token then return end
        self.transfer:Queue(SHARDID.MASTER,
            {kind = "take", uid = player.userid, bank = view.bank, session = view.session, slot = slot, token = token,
                mode = mode, active = mode ~= "inventory"})
        self:ScheduleWork()
    end
end

function ShadowBank:Take(peer, data)
    if not TheShard:IsMaster() then return true end
    local view = self.remote[tostring(peer) .. "/" .. tostring(data.uid)]
    if not self.enabled or not view or GetTime() - view.time > 5 or view.bank ~= data.bank or
        view.session ~= data.session then return true end
    local container = self:Bank(data.bank)
    if not container then return false end
    local item = container:GetItemInSlot(data.slot)
    if not item or self:Token(item) ~= data.token or container.readonlycontainer or container.inst.dcs2hm then return true end
    if not self:CanTransfer(item) then return true end
    if not self.transfer:CanQueue() then return false end
    if item.components.stackable and item.components.stackable:StackSize() > 1 and (data.mode == "half" or data.mode == "one") then
        local amount = data.mode == "one" and 1 or math.ceil(item.components.stackable:StackSize() / 2)
        item = item.components.stackable:Get(amount)
    end
    return self:SendItem(peer, item, "withdraw", data.uid, data.bank, {active = data.active})
end

function ShadowBank:ReceiveItem(peer, data)
    if not data.record then return true end
    if data.purpose == "deposit" or data.purpose == "import" then
        if not TheShard:IsMaster() or not validbank(data.bank) then return false end
        if self:Recovering() then
            -- Replay through the original stream/sequence receipt. Do not
            -- reconstruct outgoing records: their peer may already own them.
            table.insert(self.imports,{bank=data.bank,record=data.record})
            return true
        end
        self:EnsureBanks()
        local container = self:Bank(data.bank)
        if not container then return false end
        if data.purpose == "import" then
            table.insert(self.imports, {bank = data.bank, record = data.record})
            return true
        end
        if not self.transfer:CanQueue(2) then return false end
        local item = SpawnSaveRecord(data.record)
        if not item then return false end
        local other = data.slot and container:GetItemInSlot(data.slot)
        if data.targettoken and (other and self:Token(other) or "") ~= data.targettoken then
            return self:SendItem(peer, item, "return", data.uid, data.bank, {active = true})
        end
        if other and not (item.components.stackable and other.components.stackable and item.components.stackable:CanStackWith(other)) then
            if not container:CanTakeItemInSlot(item, data.slot) or not self:CanTransfer(other) or
                not self:SendItem(peer, other, "withdraw", data.uid, data.bank, {active = true}) then
                return self:SendItem(peer, item, "return", data.uid, data.bank, {active = true})
            end
        end
        if not container:GiveItem(item, data.slot, nil, false) and item:IsValid() then
            self:SendItem(peer, item, "return", data.uid, data.bank, {active = true})
        end
    else
        if type(data.uid) ~= "string" then return false end
        table.insert(self.mail, {uid = data.uid, record = data.record, returned = data.purpose == "return", active = data.active})
    end
    return true
end

function ShadowBank:Switch(player, inst)
    if not self.enabled then return end
    if not TheShard:IsMaster() then
        local view = self.viewers[player.userid]
        if not self:CanUse(player, view) then return end
        if view and inst == view.display and inst.components.container:IsOpenedBy(player) then
            self:Action(player, "switch")
            local number = istackle(view.bank) and player.shadowbanktacklenumber2hm or player.shadowbanknumber2hm
            say(player, "当前是" .. number .. "号" .. (istackle(view.bank) and "钓具" or "帽子") .. "空间。", "Space " .. number .. " is open.")
        end
        return
    end
    local tacklefirst, tacklesecond = self:Bank(3), self:Bank(4)
    local tackle = tacklefirst and inst == tacklefirst.inst or tacklesecond and inst == tacklesecond.inst
    if not tackle and not self:CanUse(player) then return end
    local first, second = self:Bank(tackle and 3 or 1), self:Bank(tackle and 4 or 2)
    if not first or not second or (inst ~= first.inst and inst ~= second.inst) or not inst.components.container:IsOpenedBy(player) then return end
    if first.readonlycontainer or second.readonlycontainer or first.inst.dcs2hm or second.inst.dcs2hm then return end
    local proxy
    if tackle then
        for anchor in pairs(player.components.inventory.opencontainerproxies or {}) do
            local candidate = anchor.components.container_proxy
            if anchor.prefab == "tacklestation" and candidate and candidate:GetMaster() == inst and candidate:IsOpenedBy(player) then proxy = candidate; break end
        end
    else
        local hat = player.components.magician.item
        proxy = hat.container and hat.container.components.container_proxy
    end
    if not proxy or proxy:GetMaster() ~= inst then return end
    if tackle and proxy.opencount > 1 then
        return say(player, "请等其他玩家关闭这个钓具容器后再穿越。", "Wait for other players to close this tackle station.")
    end
    local target = inst == first.inst and second.inst or first.inst
    local onclose = proxy.onclosefn
    proxy.onclosefn = nil
    proxy:Close(player)
    player:PushEvent("closecontainer", {container = inst})
    proxy:SetMaster(target)
    player:PushEvent("opencontainer", {container = target})
    proxy:Open(player)
    proxy.onclosefn = onclose
    local number = target == first.inst and 1 or 2
    if tackle then player.shadowbanktacklenumber2hm = number else player.shadowbanknumber2hm = number end
    say(player, "当前是" .. number .. "号" .. (tackle and "钓具" or "帽子") .. "空间。", "Space " .. number .. " is open.")
end

function ShadowBank:Status(player)
    say(player, "两套帽子物资均由主世界保存；当前" .. tostring(player.shadowbanknumber2hm or 1) .. "号。待安置旧物资：" .. #self.imports .. "组。",
        "Both hat spaces are stored on the surface. Current: " .. tostring(player.shadowbanknumber2hm or 1) .. ". Pending legacy stacks: " .. #self.imports)
end

function ShadowBank:DeliverMail()
    for index = #self.mail, 1, -1 do
        local entry = self.mail[index]
        local player = playerbyid(entry.uid)
        if player and player.components.inventory then
            local item = SpawnSaveRecord(entry.record)
            if item then
                table.remove(self.mail, index)
                if entry.active and not player.components.inventory:GetActiveItem() then
                    player.components.inventory:GiveActiveItem(item)
                else player.components.inventory:GiveItem(item, nil, player:GetPosition()) end
                if entry.returned then say(player, "空间无法放入该物品，已退回。", "The item could not be stored and was returned.") end
            end
        end
    end
end

function ShadowBank:Update()
    if not self.enabled and not self:Recovering() then return end
    local variants=self.inst.components.exchangevariants2hm
    if variants and not variants.ready then return end
    if self:Recovering() then
        self.transfer:Tick(GetTime())
        Recovery.Imports(self)
        self:DeliverMail()
        return
    end
    self:EnsureBanks()
    self.transfer:Tick(GetTime())
    for uid, view in pairs(self.viewers) do
        if self:CanUse(view.player, view) then self:Poll(uid) else self:RemoteClose(view.player) end
    end
    for key, view in pairs(self.remote) do if GetTime() - view.time > 10 then self.remote[key] = nil end end
    self:DeliverMail()
    if not self.enabled then return end
    if TheShard:IsMaster() then
        for index = #self.imports, 1, -1 do
            local entry = self.imports[index]
            local container = self:Bank(entry.bank or 2)
            local item = container and SpawnSaveRecord(entry.record or entry)
            if item then
                if container:GiveItem(item, nil, nil, false) then table.remove(self.imports, index)
                elseif item:IsValid() then self.imports[index] = {bank = entry.bank or 2, record = item:GetSaveRecord()}; item:Remove() end
            end
        end
    elseif Shard_IsWorldAvailable(SHARDID.MASTER) then
        local legacy = self.inst:GetPocketDimensionContainer("shadow")
        local container = legacy and legacy.components.container
        if container and container.opencount == 0 and not container.readonlycontainer then
            for _, item in pairs(container.slots) do
                if self:CanTransfer(item) then
                    self:SendItem(SHARDID.MASTER, item, "import", nil, 2)
                    break
                end
            end
        end
        local tackle = self.inst:GetPocketDimensionContainer("tacklestation2hm")
        local storage = tackle and tackle.components.container
        if storage and storage.opencount == 0 and not storage.readonlycontainer then
            for _, item in pairs(storage.slots) do
                if self:CanTransfer(item) then self:SendItem(SHARDID.MASTER, item, "import", nil, 4); break end
            end
        end
    end
end

function ShadowBank:OnSave()
    return {version = (self.enabled or self.savedversion) and 1 or nil, mail = self.mail, imports = self.imports, transfer = self.transfer:Save()}
end

function ShadowBank:OnLoad(data)
    if data then
        self.savedversion=data.version
        self.mail, self.imports = data.mail or {}, data.imports or {}
        self.transfer = self:NewTransfer(data.transfer)
    end
end

function ShadowBank:OnRemoveFromEntity()
    if self.task then self.task:Cancel() end
    if self.worktask then self.worktask:Cancel() end
end
ShadowBank.OnRemoveEntity = ShadowBank.OnRemoveFromEntity

return ShadowBank
