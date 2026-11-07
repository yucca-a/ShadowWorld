local Protocol = require("worldexchangeprotocol2hm")
local Adapter = require("shadowvaultitems2hm")
local Transport = require("shadowvaulttransport2hm")
local Config = require("shadowvaultconfig2hm")
local Journal = require("shadowvaultjournal2hm")
local Courier = require("shadowvaultcourier2hm")
local json = require("json")

local function valid(inst) return inst and inst:IsValid() end
local function count(item) return item.components.stackable and item.components.stackable:StackSize() or 1 end
local function slot_take(op) return op=="H" or op=="T" or op=="J" end
local function quick_store(op) return op=="Q" or op=="K" end
local function compound(op) return slot_take(op) or op=="P" or op=="S" or quick_store(op) end
local function playerfor(uid)
    for _, player in ipairs(AllPlayers) do if player.userid == uid then return player end end
end
local function inside(item, owner)
    local seen = {}
    while item and not seen[item] do
        if item == owner then return true end
        seen[item] = true
        item = item.components.inventoryitem and item.components.inventoryitem.owner
    end
    return false
end
local function take(c, slot)
    c:EnableReadOnlyContainer(false)
    c.worldexchange_internal2hm = true
    local item = c:RemoveItemBySlot(slot, true)
    c.worldexchange_internal2hm = nil
    c:EnableReadOnlyContainer(true)
    return item
end
local function put(c, item, slot)
    c:EnableReadOnlyContainer(false)
    c.worldexchange_internal2hm = true
    local previous = c.ignoreoverstacked
    c.ignoreoverstacked = true
    local ok = c:GiveItem(item, slot, nil, false)
    c.ignoreoverstacked = previous
    c.worldexchange_internal2hm = nil
    c:EnableReadOnlyContainer(true)
    return ok and c.slots[slot] == item
end

local Vault = Class(function(self, inst)
    self.inst = inst
    self.status = "initializing"
    self.registry, self.pages, self.rows, self.reserved, self.views = {}, {}, {}, {}, {}
    self.import_errors = {}
    self.sequence = 0
    self.view_sequence = 0
    self.native_ready = inst.ismastershard
    inst:ListenForEvent("secondary_autosaverupdate", function(_, data)
        if self.journal then return end
        if data and type(data.snapshot) == "number" and data.snapshot > 0 then
            if data.snapshot < TheNet:GetCurrentSnapshot()-1 then self.native_ready=false end
            inst:DoStaticTaskInTime(2, function()
                if TheWorld == inst and TheNet:GetCurrentSnapshot() >= data.snapshot then self.native_ready = true end
            end)
        end
    end)
    self.task = inst:DoStaticPeriodicTask(.1, function() self:Update() end)
end)

function Vault:Say(uid, zh, en)
    local player = playerfor(uid)
    if player and player.components.talker then player.components.talker:Say(TUNING.isCh2hm and zh or en) end
end
function Vault:Fail(reason)
    self.error = reason
    print("[ShadowVault2hm] protected", self.id, reason)
end
function Vault:Activate()
    if self.status=="active" then return true end
    local variants=self.inst.components.exchangevariants2hm
    if not TUNING.SHADOWVAULT_ENABLED2HM and not (variants and variants.migrating) then return false end
    self.status="active"
    return true
end
function Vault:Initialize()
    local variants=self.inst.components.exchangevariants2hm
    if not TUNING.SHADOWVAULT_ENABLED2HM and not (variants and variants.migrating) then return end
    if variants and not variants.ready and not variants.migrating then return end
    if self.protocol or self.error or not self.inst.meta or not self.inst.meta.session_identifier then return end
    if not self:Activate() then return end
    self.id, self.session = tostring(TheShard:GetShardId()), self.inst.meta.session_identifier
    self.master = self.inst.ismastershard
    self.native_bases=self.native_bases or {}
    for family,entity in pairs(self.inst.PocketDimensionContainers or {}) do
        if valid(entity) and Config.Manageable(family,entity) then
            Config.ProtectPreserver(entity)
            if not self.native_bases[family] then self.native_bases[family]=entity end
        end
    end
    self.base = self.inst:GetPocketDimensionContainer("shadow")
    if not valid(self.base) then return end
    self.tackle = self.inst:GetPocketDimensionContainer("tacklestation2hm")
    local legacy=self.inst.components.worldexchange2hm
    if legacy and legacy.saved and legacy.saved.active then
        self.base.components.container:EnableReadOnlyContainer(true)
        self:Fail("legacy_exchange_pending")
        return
    end
    self.transport = Transport.new(self.inst, {
        receive=function(peer,m) self:Receive(peer,m) end,
        fail=function(why) self:Fail(why) end,
        hello=function(peer,info,previous)
            local t=self.protocol and self.protocol.active
            if t and t.peer==peer then
                local expected=t.coordinator==self.id and t.participant_session or t.coordinator_session
                if expected~=info.session then self.protocol:Fail("snapshot_mismatch") end
            end
            if self.protocol and (not previous or previous.boot ~= info.boot) then
                self.protocol.peer_phase, self.protocol.peer_durable = nil, nil
                self.protocol.retry = 0
            end
            if self.master then self:Register(peer) end
        end,
        disconnected=function(peer)
            if self.remoteviews then self.remoteviews[peer]=nil end
            if self.protocol and self.protocol.active and self.protocol.active.peer == peer then
                self.protocol.peer_phase,self.protocol.peer_durable=nil,nil
            end
        end,
    })
    self.protocol = Protocol.new({id=self.id, session=self.session, boot=self.transport.boot,
        now=function() return GetStaticTime() end,
        peer_session=function(peer) return self.transport.peers[peer] and self.transport.peers[peer].session end,
        send=function(peer,m) self.transport:Send(peer,m) end,
        lock=function(name,payload) return self:Lock(name,payload) end,
        unlock=function(name) self:Unlock(name) end,
        snapshot=function(name)
            if self.native and (self.native:IsTransfer(name) or self.rows[name] and self.rows[name].op=="I") then
                return self.native:Snapshot(name)
            end
            return Adapter.Snapshot(self,name)
        end,
        validate=function(name,payload) return self:ValidateIncoming(name,payload) end,
        apply=function(name,payload)
            local ok,why=self:ValidateIncoming(name,payload)
            if not ok then return false,why end
            if self.native and (self.native:IsTransfer(name) or self.rows[name] and self.rows[name].op=="I") and
                not require("shadowvaultnative2hm").RestoreMetadata(self:Container(name),payload) then
                return false,"invalid_items"
            end
            return Adapter.Apply(self,name,payload)
        end,
        checkpoint=function() self:Checkpoint() end,
        notify=function(uid,why) self:Notify(uid,why) end,
        log=function(why,id) print("[ShadowVault2hm] transaction",why,id) end,
    }, self.saved_protocol)
    self.catalog_epoch=self.transport.boot:gsub("[^%w_%-]","_")
    self.saved_protocol = nil
    self:BindFinalization()
    if self.master then
        if not self.registry[self.id] then self.registry[self.id]={name="Master",imported=true} end
        if not self.pages[self.id] then self.pages[self.id] = self.base end
        if valid(self.tackle) then
            local page=Config.TacklePage(self.id)
            self.registry[page]=self.registry[page] or {name=self.registry[self.id].name,imported=true}
            self.pages[page]=self.pages[page] or self.tackle
        end
        for id, page in pairs(self.pages) do self:GuardPage(id,page) end
    else
        self.base.components.container:EnableReadOnlyContainer(true)
        self.base.dcs2hm = true
        if valid(self.tackle) then
            self.tackle.components.container:EnableReadOnlyContainer(true)
            self.tackle.dcs2hm = true
        end
    end
    for name,row in pairs(self.rows) do
        if not valid(row.escrow) then self:Fail("missing_transfer_container");return end
        row.escrow.components.container:EnableReadOnlyContainer(true)
        if self.master and row.state == "active" then self:Reserve(name,row) end
    end
    if self.protocol.active and not self.rows[self.protocol.active.name] then self:Fail("missing_transfer_record") end
    Journal.Attach(self)
end
function Vault:LocalBase(page)
    local family=Config.Family(page)
    if page~=Config.Page(self.id,family) then return end
    return self.native_bases and self.native_bases[family] or
        (family=="shadow" and self.base or family=="tacklestation2hm" and self.tackle)
end
function Vault:IsImported(page)
    local family=Config.Family(page)
    if family=="shadow" then return self.imported end
    if family=="tacklestation2hm" then return self.tackle_imported end
    return self.extra_imported and self.extra_imported[family]
end
function Vault:BindFinalization()
    local finish = self.protocol.Finish
    self.protocol.Finish = function(core,outcome)
        local t = core.active
        local ok,why = self:Finalize(t.name,outcome == "done")
        if not ok then core:Fail(why or "apply_failed");return end
        finish(core,outcome)
    end
end
function Vault:Register(id, pageid)
    pageid=pageid or id
    if self.registry[pageid] then return end
    local peers = Shard_GetConnectedShards and Shard_GetConnectedShards() or {}
    local page = Config.SpawnPage(pageid)
    if not page then self:Fail("page_spawn_failed");return end
    self.registry[pageid] = {name=peers[id] and peers[id].shard_name or id, imported=false}
    self.pages[pageid] = page
    page.components.container:EnableReadOnlyContainer(true)
    self:GuardPage(pageid,page)
    if self.journal then self.journal:Flush() end
end
function Vault:GuardPage(id,page)
    if page.shadowvault_guarded2hm then return end
    page.shadowvault_guarded2hm = true
    local c = page.components.container
    local test = c.CanTakeItemInSlot
    c.CanTakeItemInSlot = function(container,item,slot)
        if self.retired then return test(container,item,slot) end
        if self.native and self.native.localonly and self.native.localonly[id] then return test(container,item,slot) end
        if slot and self.reserved[id] and self.reserved[id][slot] and not self.internal then return false end
        if not test(container,item,slot) then return false end
        if not self.internal and not container.worldexchange_internal2hm and item and
            (not item.components.inventoryitem or item.components.inventoryitem.owner~=page) then
            local allowed=Adapter.CheckItem(item)
            if not allowed then
                local inv=item.components.inventoryitem
                local owner=inv and inv.GetGrandOwner and inv:GetGrandOwner()
                if owner and owner.userid then self:Notify(owner.userid,"unsupported") end
                return false
            end
        end
        return true
    end
end
function Vault:Reserve(name,row)
    local page = self.pages[row.page]
    if not valid(page) then return false end
    self.reserved[row.page] = self.reserved[row.page] or {}
    if row.op ~= "I" then self.reserved[row.page][row.slot] = name end
    local item=compound(row.op) and page.components.container.slots[row.slot]
    if item and self.native and self.native.shared then
        if row.restore_nocrafting==nil then row.restore_nocrafting=not item:HasTag("nocrafting")end
        row.nocrafting_guid=item.GUID
        if row.restore_nocrafting then item:AddTag("nocrafting")end
    end
    local perish=item and item.components.perishable
    if perish and perish:IsPerishing() then
        row.resume_perishing=true
        perish:StopPerishing()
    end
    page.dcs2hm = true
    if row.op == "I" then page.components.container:EnableReadOnlyContainer(true) end
    return true
end
function Vault:Unreserve(row)
    local reservations = self.reserved[row.page]
    if reservations then reservations[row.slot] = nil end
    local page = self.pages[row.page]
    local item=valid(page)and page.components.container.slots[row.slot]
    if item and row.restore_nocrafting and item.GUID==row.nocrafting_guid then item:RemoveTag("nocrafting")end
    if valid(page) and (not reservations or not next(reservations)) then page.dcs2hm = nil end
end
function Vault:Container(name) return self.rows[name] and self.rows[name].escrow end
function Vault:SlotToken(pageid,slot)
    local page=self.pages[pageid]
    local item=valid(page) and page.components.container.slots[slot]
    return self.catalog_epoch.."_"..(item and (tostring(item.GUID).."_"..tostring(count(item))) or "empty")
end
function Vault:PlanSlot(row, target, incoming)
    local item=target.slots[row.slot]
    local stack=item and item.components.stackable
    row.before=item and {prefab=item.prefab,skin=item.skinname,count=count(item)} or nil
    if slot_take(row.op) then
        if not item or item.components.inventoryitem.islockedinslot and
            not (row.op~="T" and stack and stack:IsStack()) then
            return false,"stale"
        end
        local size=stack and stack:IsOverStacked() and (stack.originalmaxsize or stack.maxsize) or count(item)
        row.plan,row.amount="take",row.op=="J" and 1 or row.op=="H" and math.max(1,math.floor(size/2)) or size
        if row.requested_count then row.amount=math.min(size,row.requested_count)end
        return true
    end

    local readonly=target.readonlycontainer
    target:EnableReadOnlyContainer(false)
    local ok,accepted=pcall(target.CanTakeItemInSlot,target,incoming,row.slot)
    target:EnableReadOnlyContainer(readonly)
    if not ok or not accepted then return false,"unsupported" end
    local accepts=target:AcceptsStacks()
    if row.paired and (not item or stack and incoming.components.stackable and stack:CanStackWith(incoming))then return false,"stale"end
    local amount=row.op=="S" and 1 or row.op=="K" and math.max(1,math.floor(count(incoming)/2)) or count(incoming)
    if row.requested_count then amount=math.min(amount,row.requested_count)end
    if stack and incoming.components.stackable and accepts and stack:CanStackWith(incoming) then
        row.plan,row.amount="merge",math.min(amount,stack:RoomLeft())
        if row.amount<=0 then return false,"full" end
    elseif item then
        if quick_store(row.op) then return false,"stale" end
        if stack and stack:IsOverStacked() or not accepts and count(incoming)>1 and not row.paired then return false,"unsupported" end
        if row.paired then
            if not incoming.components.stackable or not incoming.components.stackable:IsStack()then return false,"stale"end
            row.plan,row.amount="swapone",1
        else row.plan,row.amount="swap",count(incoming)end
    else
        row.plan,row.amount="place",accepts and amount or 1
    end
    return true
end

function Vault:PrepareSlot(name,row,target,payload)
    -- The original slot stays in place until commit. Only the preview of
    -- the outgoing item is offered to the other shard.
    local escrow=row.escrow.components.container
    local incoming
    if not slot_take(row.op) then
        local items=type(payload)=="table" and payload.items
        if type(items)~="table" or not items[1] or next(items,1) or not Adapter.Apply(self,name,payload) then
            return false,"invalid_items"
        end
        incoming=take(escrow,1)
        if not incoming then return false,"invalid_items" end
    end
    local ok,why=self:PlanSlot(row,target,incoming)
    if ok and (row.plan=="take" or row.plan=="swap" or row.plan=="swapone") then
        local original=target.slots[row.slot]
        local preview=setmetatable({slots={[1]=original}},{__index=escrow})
        local outgoing=Journal.Payload(self,{components={container=preview}})
        ok=outgoing and Adapter.Apply(self,name,outgoing)
        if ok and row.plan=="take" and row.amount<count(original) then
            local copy=take(escrow,1)
            local half=copy.components.stackable:Get(row.amount)
            copy:Remove()
            ok=put(escrow,half,1)
            if not ok then half:Remove() end
        end
        if ok and row.plan=="swapone" then
            incoming.components.stackable:SetStackSize(count(incoming)-1)
            ok=put(escrow,incoming,2)
            if ok then incoming=nil end
        end
        why="unsupported"
    elseif ok and row.amount<count(incoming) then
        incoming.components.stackable:SetStackSize(count(incoming)-row.amount)
        ok=put(escrow,incoming,1)
        if ok then incoming=nil end
        why="unsupported"
    end
    if valid(incoming) then incoming:Remove() end
    return ok,why
end

function Vault:ApplySlot(row,target,return_locally)
    local escrow=row.escrow.components.container
    local item=target.slots[row.slot]
    local before=row.before
    if (item~=nil)~=(before~=nil) or item and
        (item.prefab~=before.prefab or item.skinname~=before.skin or count(item)~=before.count) then return false end
    local outgoing
    if row.plan=="take" then
        if row.amount<count(item) then
            outgoing=item.components.stackable:Get(row.amount)
        else
            outgoing=take(target,row.slot)
        end
    elseif row.plan=="swapone" then
        local incoming=take(escrow,1)
        if not incoming or count(incoming)<2 then return false end
        local single=incoming.components.stackable:Get(1)
        incoming:Remove()
        outgoing=take(target,row.slot)
        if not put(target,single,row.slot)then return false end
    else
        local incoming=escrow.slots[1]
        if not incoming then return false end
        -- Recheck the actual items before touching either inventory. A changed
        -- slot or an item rejection keeps both sides in their recorded custody.
        local check={op=row.op,slot=row.slot,requested_count=row.requested_count,paired=row.paired}
        if not self:PlanSlot(check,target,incoming) or check.plan~=row.plan or check.amount~=row.amount then return false end
        incoming=take(escrow,1)
        local added=incoming
        local whole_merge=row.plan=="merge" and (row.op=="P" or row.op=="Q") and not row.requested_count
        if row.amount<count(incoming) and not whole_merge then
            added=incoming.components.stackable:Get(row.amount)
            outgoing=incoming
        end
        if row.plan=="merge" then
            local leftover=item.components.stackable:Put(added)
            if count(item)~=before.count+row.amount or not whole_merge and leftover then
                if leftover and outgoing then
                    outgoing.components.stackable:Put(leftover)
                elseif leftover then
                    outgoing=leftover
                end
                if outgoing then put(escrow,outgoing,1) end
                return false
            end
            if whole_merge then outgoing=leftover end
        else
            if row.plan=="swap" then outgoing=take(target,row.slot) end
            if not put(target,added,row.slot) then
                if row.plan=="swap" and outgoing then put(target,outgoing,row.slot) end
                if added~=incoming and valid(added) then incoming.components.stackable:Put(added) end
                if valid(incoming) then put(escrow,incoming,1) end
                return false
            end
        end
        if added:IsValid() and added.components.shadowvaultticket2hm then added:RemoveComponent("shadowvaultticket2hm") end
    end
    if row.resume_perishing and item and target.slots[row.slot]==item and item.components.perishable then
        item.components.perishable:StartPerishing()
    end
    if outgoing then
        if return_locally then return put(escrow,outgoing,1) end
        outgoing:Remove() -- the other shard already has the durable copy
    end
    return true
end

function Vault:Lock(name,payload)
    if self.native and self.native:IsTransfer(name) then return self.native:Lock(name,payload) end
    local row = self.rows[name]
    if row then
        if not valid(row.escrow) then return false,"container_missing" end
        row.escrow.components.container:EnableReadOnlyContainer(true)
        return true
    end
    if not self.master or not self.receiving_peer then return false,"invalid_items" end
    row = Config.Parse(name)
    if row and row.op=="I" and Config.Definition(Config.Family(row.page)) and
        row.page==Config.Page(self.receiving_peer,Config.Family(row.page)) then
        self:Register(self.receiving_peer,row.page)
    end
    if not row or not self.registry[row.page] then return false,"container_missing" end
    local page = self.pages[row.page]
    if not valid(page) then return false,"container_missing" end
    local c = page.components.container
    row.peer,row.state = self.receiving_peer,"active"
    if row.op == "I" then
        if row.page ~= Config.Page(row.peer,Config.Family(row.page)) or self.registry[row.page].imported or next(c.slots) then
            return false,"snapshot_mismatch"
        end
        row.escrow = Config.SpawnPage(row.page)
    else
        -- Existing saved rows above remain recoverable, including the previous
        -- name format. New requests must carry the player's view and item stamp.
        local view=self.remoteviews and self.remoteviews[row.peer] and self.remoteviews[row.peer][row.userid]
        if self.native and self.native.shared then view=self.native.shared:GetRemote(row.peer,row.userid,row.session)or view end
        if not row.token or not view or view.session~=row.session or view.page~=row.page or
            GetStaticTime()-view.time>10 or row.token~=self:SlotToken(row.page,row.slot) then return false,"stale" end
        if not self.registry[row.page].imported or row.slot < 1 or row.slot > c.numslots or
            (self.reserved[row.page] and self.reserved[row.page][row.slot]) then return false,"busy" end
        local item=c.slots[row.slot]
        if row.op=="D" and item or (row.op=="W" or slot_take(row.op) or row.op=="P") and not item then return false,"busy" end
        row.escrow = SpawnPrefab(row.paired and "shadowvaultpair2hm"or"shadowvaulttransfer2hm")
    end
    if not row.escrow then return false,"apply_failed" end
    self.rows[name] = row
    if compound(row.op) then
        local ok,why=self:PrepareSlot(name,row,c,payload)
        if not ok then
            for _,item in pairs(row.escrow.components.container.slots) do item:Remove() end
            row.escrow:Remove()
            self.rows[name]=nil
            return false,why
        end
    end
    self:Reserve(name,row)
    if row.op == "W" then
        local item = take(c,row.slot)
        if not item or not put(row.escrow.components.container,item,1) then self:Fail("withdraw_reservation_failed");return false,"apply_failed" end
    end
    row.escrow.components.container:EnableReadOnlyContainer(true)
    return true
end
function Vault:Validate(name,payload) return Adapter.Validate(self,name,payload) end
function Vault:ValidateIncoming(name,payload)
    if self.native and self.native:IsTransfer(name) then return self.native:Validate(name,payload) end
    local ok,why=Adapter.Validate(self,name,payload)
    if not ok then return false,why end
    local row=self.rows[name]
    if not row then return false,"invalid_items" end
    local nonempty=next(payload.items)~=nil
    local taking=row.op=="W" or slot_take(row.op)
    local wantsitem=self.master and not taking or not self.master and taking
    if not self.master and compound(row.op) and not taking then wantsitem=nonempty end
    local extra=false
    for slot in pairs(payload.items)do if slot~=1 and (not row.paired or slot~=2)then extra=true;break end end
    if row.op~="I" and (nonempty~=wantsitem or (nonempty and (not payload.items[1] or extra))) then
        return false,"invalid_items"
    end
    if row.op=="I" and not self.master and nonempty then return false,"invalid_items" end
    return true
end
function Vault:Finalize(name,success)
    if self.native and self.native:IsTransfer(name) then return self.native:Finalize(name,success) end
    local row=self.rows[name]
    if not row then return false,"missing_transfer_record" end
    if row.state~="active" then return true end
    local c=row.escrow.components.container
    if self.master then
        local page=self.pages[row.page]
        if not valid(page) then return false,"container_missing" end
        local target=page.components.container
        if row.op=="I" and success then
            local t=self.protocol.active
            if t and t.incoming and not require("shadowvaultnative2hm").RestoreMetadata(page,t.incoming) then
                return false,"invalid_items"
            end
        end
        if compound(row.op) then
            if success then
                self.internal=true
                local ok=self:ApplySlot(row,target,row.localonly)
                self.internal=nil
                if not ok then return false,"apply_failed" end
                if self.native and self.native.shared then self.native.shared:Changed(row.page)end
            elseif row.resume_perishing then
                local item=target.slots[row.slot]
                if item and item.components.perishable then item.components.perishable:StartPerishing() end
            end
            self:Unreserve(row)
            if row.localonly and next(c.slots) then
                row.state="delivery"
            else
                for _,item in pairs(c.slots) do item:Remove() end
                row.escrow:Remove()
                self.rows[name]=nil
            end
            self:BroadcastCatalog()
            return true
        end
        local deliver=success and (row.op=="D" or row.op=="I") or not success and row.op=="W"
        if deliver then
            for slot,item in pairs(c.slots) do
                local destination=row.op=="I" and slot or row.slot
                if target.slots[destination] then return false,"destination_changed" end
            end
            self.internal=true
            local slots={};for slot in pairs(c.slots) do slots[#slots+1]=slot end
            for _,slot in ipairs(slots) do
                local item=take(c,slot)
                if item and item.components.shadowvaultticket2hm then item:RemoveComponent("shadowvaultticket2hm") end
                local destination=row.op=="I" and slot or row.slot
                if not item or not put(target,item,destination) then self.internal=nil;return false,"apply_failed" end
            end
            self.internal=nil
        elseif next(c.slots) then return false,"unexpected_transfer_contents" end
        if row.op=="I" and success then self.registry[row.page].imported=true end
        if row.op=="D" and success and self.native and self.native.shared then self.native.shared:Changed(row.page)end
        self:Unreserve(row)
        target:EnableReadOnlyContainer(self.journal~=nil or not self.registry[row.page].imported)
        row.escrow:Remove()
        self.rows[name]=nil
        self:BroadcastCatalog()
    else
        if row.op=="I" then
            if success then
                if next(c.slots) then return false,"import_not_empty" end
                local family=Config.Family(row.page)
                if family=="tacklestation2hm" then self.tackle_imported=true
                elseif family=="shadow" then self.imported=true
                else self.extra_imported=self.extra_imported or {};self.extra_imported[family]=true end
                self.import_errors[row.page]=nil
            else
                self.import_errors[row.page]="migration_rejected"
            end
            self.rows[name]=nil
            c:EnableReadOnlyContainer(success)
            row.escrow.dcs2hm=success and true or nil
        elseif next(c.slots) then
            if row.paired and c.slots[2]then
                local remainder=take(c,2)
                local escrow=SpawnPrefab("shadowvaulttransfer2hm")
                if not escrow or not put(escrow.components.container,remainder,1)then return false,"apply_failed"end
                self.rows[name.."_rest"]={userid=row.userid,page=row.page,state="delivery",escrow=escrow,
                    cursor_session=row.cursor_session}
                row.cursor_session=nil
            end
            row.state="delivery"
        else
            row.escrow:Remove();self.rows[name]=nil
        end
    end
    return true
end
function Vault:Unlock(name)
    local row=self.rows[name]
    if row and row.state=="active" then
        local ok,why=self:Finalize(name,false)
        if not ok then self:Fail(why) end
    end
end
function Vault:Notify(uid,why)
    if not uid then return end
    local mode=(why=="snapshot_mismatch" or why=="apply_failed") and "recovery" or
        (why=="timeout" or why=="connecting") and "cancelled" or why
    local view=self.views[uid]
    if view then view.notice,view.notice_until=mode,GetStaticTime()+4 end
    local state=self:ClientState(uid,mode)
    local text=Config.StatusText(state,TUNING.isCh2hm)
    local player=playerfor(uid)
    if mode~="done" and mode~="preparing" and mode~="finishing" and player and text~="" and
        (not player._shadowvault_notice or GetStaticTime()>=player._shadowvault_notice) then
        player._shadowvault_notice=GetStaticTime()+1
        self:Say(uid,Config.StatusText(state,true),Config.StatusText(state,false))
    end
    if view then
        self:ToClient(uid,{status_only=true,session=view.session,page=view.page,status=state})
        if mode=="stale" then self:Refresh(uid) end
    end
end
function Vault:PendingDelivery(uid)
    for _,row in pairs(self.rows) do
        if row.userid==uid and (row.state=="delivery" or row.state=="issuing" or row.state=="uncertain") then return row end
    end
end
function Vault:ClientState(uid,fallback)
    local t=self.protocol and self.protocol.active
    if self.error or t and t.error then return {mode="recovery"} end
    for _,parcel in pairs(self.travel_inbox or {}) do if parcel.userid==uid then return {mode="recovery"} end end
    local row=self:PendingDelivery(uid)
    if row then
        if row.state=="uncertain" or row.state=="issuing" then return {mode="recovery"} end
        local item=valid(row.escrow) and row.escrow.components.container.slots[1]
        local info=self.registry[row.page]
        return {mode="delivery",page=row.page,page_name=info and info.name,
            name=item and item:GetBasicDisplayName(),count=item and count(item)}
    end
    if t and t.requester==uid and (not fallback or fallback=="preparing" or fallback=="busy" or fallback=="finishing") then
        return {mode=t.phase=="release" and "finishing" or "preparing"}
    end
    if not self.master and not Shard_IsWorldAvailable(tostring(SHARDID.MASTER)) then return {mode="offline"} end
    local view=self.views[uid]
    return {mode=fallback or (view and view.notice_until and GetStaticTime()<view.notice_until and view.notice) or "ready"}
end
function Vault:Checkpoint()
    -- Durability belongs to the independent journal; never request ms_save.
end
function Vault:SortPage(pageid)
    local journal=self.journal
    local sort=TUNING.util2hm and TUNING.util2hm.SortShadowVaultPage2hm
    local page=self.pages[pageid]
    if not sort or not valid(page) or not self.registry[pageid].imported or self.protocol.active or
        not journal or not journal.ready or journal.busy or journal.staging or
        self.reserved[pageid] and next(self.reserved[pageid]) then return false end
    local container=page.components.container
    container:EnableReadOnlyContainer(false)
    sort(page)
    container:EnableReadOnlyContainer(true)
    journal:Flush(function(ok) if ok then self:BroadcastCatalog() end end)
    return true
end
function Vault:Receive(peer,m)
    if not self.protocol or self.error or type(m)~="table" then return end
    -- Native autosaver may reload this secondary before it joins the master's
    -- timeline. Never release a saved escrow from that abandoned world instance.
    if not self.master and not self.native_ready then return end
    local variants=self.inst.components.exchangevariants2hm
    if m.vault==8 then
        if variants and variants.migrating then variants.migration:Receive(self,peer,m) end
        return
    end
    if self.retired then return end
    if variants and variants.migrating and (m.vault==7 or m.vault==1) then return end
    if m.vault==7 then
        if self.native and self.native.shared then self.native.shared:Receive(peer,m) end
        return
    end
    if m.vault==6 then
        if self.native then self.native:Receive(peer,m) end
        return
    end
    if m.vault==4 then
        if self.journal then self.journal:Receive(peer,m) end
        return
    end
    if m.vault==1 then
        if self.master and m.kind=="VIEW" then
            if type(m.userid)~="string" or #m.userid>80 or type(m.page)~="string" or not Config.ValidStamp(m.session) then return end
            self.remoteviews=self.remoteviews or {}
            self.remoteviews[peer]=self.remoteviews[peer] or {}
            self.remoteviews[peer][m.userid]={page=m.page,time=GetStaticTime(),session=m.session}
            self:SendCatalog(peer,m.userid,m.page,m.session)
        elseif self.master and m.kind=="SORT" then
            local views=self.remoteviews and self.remoteviews[peer]
            local view=views and type(m.userid)=="string" and views[m.userid]
            if view and view.session==m.session and view.page==m.page and GetStaticTime()-view.time<=10 then
                self:SortPage(view.page)
            end
        elseif not self.master and peer==tostring(SHARDID.MASTER) and m.kind=="CATALOG" and type(m.catalog)=="table" and
            type(m.catalog.items)=="table" and type(m.catalog.registry)=="table" and Config.ValidStamp(m.catalog.emptytoken) then
            local view=self.views[m.userid]
            if view and view.page==m.catalog.page and view.session==m.catalog.session and self:AccessAllowed(m.userid) then
                self.registry=m.catalog.registry or self.registry
                self:ShowCatalog(m.userid,view,deepcopy(m.catalog))
            end
        end
        return
    end
    if not self.master and peer~=tostring(SHARDID.MASTER) then return end
    self.receiving_peer=peer
    self.protocol:Receive(peer,m)
    self.receiving_peer=nil
end
function Vault:MakeName(op,page,slot,uid,token,session)
    self.sequence=self.sequence+1
    local name=op..":"..page..":"..slot..":"..uid..":"..os.time().."_"..math.random(1,1073741823).."_"..self.sequence
    return token and name..":"..token..":"..session or name
end
function Vault:StartImport(page)
    page=page or self.id
    local base=self:LocalBase(page)
    if base and not Config.Manageable(Config.Family(page),base) then return end
    if self.master or self:IsImported(page) or not valid(base) or self.protocol.active or not self.native_ready or
        not self.transport.peers[tostring(SHARDID.MASTER)] then return end
    if base.components.container.opencount>0 then return end
    if self.journal and (not self.journal.ready or self.journal.busy or self.journal.staging) then return end
    self.nextimport=self.nextimport or {}
    if self.nextimport[page] and GetStaticTime()<self.nextimport[page] then return end
    self.nextimport[page]=GetStaticTime()+5
    -- Inspect before creating a transaction row: an unsupported native item
    -- must not turn an optional page import into a vault-wide journal failure.
    if self.native and not self.native:PrepareAdoption(page,base) then return end
    local name=self:MakeName("I",page,0,"_")
    self.rows[name]={op="I",page=page,slot=0,userid="_",escrow=base,state="active"}
    local ok,why=self.protocol:Start(name,tostring(SHARDID.MASTER))
    if not ok then
        self.rows[name]=nil
        self.import_errors[page]=why
        base.components.container:EnableReadOnlyContainer(false)
        base.dcs2hm=nil
        print("[ShadowVault2hm] import waiting",self.id,why)
    else self.import_errors[page]=nil end
end
function Vault:AccessAllowed(uid)
    local player,view=playerfor(uid),self.views[uid]
    if not player or not view or not valid(view.anchor) or player._despawning then return false end
    -- The native hat opener has no Transform. Tie its view to the tool
    -- that the player is actually using instead of a distance check.
    if view.anchor.prefab=="tophat_container" then
        local hat=view.anchor.tophat
        local magician=player.components.magician
        return valid(hat) and hat.container==view.anchor and magician~=nil and magician.item==hat
    end
    if inside(view.anchor,player) then return true end
    return view.anchor.Transform and player:GetDistanceSqToInst(view.anchor)<=25
end
function Vault:SayTravel(uid,page)
    local shard=Config.PageShard(page)
    self:Say(uid,"成功穿越世界"..shard.."啦","SUCCESS to exchange with world "..shard.."~")
end
function Vault:GetContainerType(page)
    local base=Config.IsTacklePage(page) and self.tackle or self.base
    return valid(base) and base.components.container.type
end
function Vault:Open(player,anchor,pageid)
    self:Initialize()
    if self.native then return self.native:Open(player,anchor,pageid) end
    if not self.protocol or self.error or not valid(anchor) then return false end
    local uid=player.userid
    if not uid then return false end
    pageid=pageid or self.id
    self:Close(uid)
    self.view_sequence=self.view_sequence+1
    self.views[uid]={anchor=anchor,page=pageid,session=self.catalog_epoch.."_"..self.view_sequence}
    if not self:AccessAllowed(uid) then self.views[uid]=nil;return false end
    if self.master and not self.journal then
        local page=self.pages[pageid]
        if not valid(page) or not self.registry[pageid].imported then
            self:Say(uid,"这个空间尚未完成物品迁入。","This space is awaiting its initial import.");return false
        end
        local access=SpawnPrefab("shadowvaultaccess2hm")
        if not access then self.views[uid]=nil;return false end
        self.views[uid].proxy=access
        access.Transform:SetPosition((anchor.Transform or player.Transform):GetWorldPosition())
        access.components.container_proxy:SetMaster(page)
        access.components.container_proxy:Open(player)
    else
        local localpage=Config.IsTacklePage(pageid) and Config.TacklePage(self.id) or self.id
        if not self.master and (not self:IsImported(localpage) or not self.native_ready or not Shard_IsWorldAvailable(tostring(SHARDID.MASTER))) then
            self.views[uid]=nil
            self:Say(uid,"正在连接主世界或迁入原箱物品。","Waiting for the master shard or initial item import.");return false
        end
        -- Catalog views have no native opener. Apply the same-type close rule.
        local inventory=player.components.inventory
        local kind=self:GetContainerType(pageid)
        for inst in pairs(inventory and inventory.opencontainers or {}) do
            local container=inst.components.container
            if kind and container and container.type==kind then container:Close(player) end
        end
        self:Refresh(uid)
    end
    return true
end
function Vault:Close(uid,keep_hat)
    local player=playerfor(uid)
    if self.native and player and self.views[uid] and self.views[uid].native then
        return self.native:Close(player,keep_hat)
    end
    local view=self.views[uid]
    self.views[uid]=nil
    if view and view.release then view.release(keep_hat) end
    if view and valid(view.proxy) then view.proxy:Remove() end
    if view then self:ToClient(uid,{close=true,session=view.session}) end
end
function Vault:Request(player,inst)
    if self.native then return self.native:Request(player,inst) end
    local uid=player.userid
    local view=self.views[uid]
    if not view then
        for proxy in pairs(player.components.inventory.opencontainerproxies or {}) do
            if proxy.components.container_proxy and proxy.components.container_proxy:GetMaster()==inst then
                return self:Open(player,proxy,self.id)
            end
        end
        return
    end
    local ids=Config.Order(self.registry,view.page)
    local index=1
    for i,id in ipairs(ids) do if id==view.page then index=i%#ids+1;break end end
    if ids[index] and ids[index]~=view.page then
        if view.proxy then
            if self:Open(player,view.anchor,ids[index]) then self:SayTravel(uid,ids[index]) end
        else self:Travel(uid,view,ids[index]) end
    end
end
function Vault:Catalog(pageid)
    local page,info=self.pages[pageid],self.registry[pageid]
    if not valid(page) or not info then return end
    local catalog={page=pageid,registry=deepcopy(self.registry),slots=page.components.container.numslots,items={},ready=info.imported,
        emptytoken=self.catalog_epoch.."_empty"}
    for slot,item in pairs(page.components.container.slots) do
        local inv=item.components.inventoryitem
        local image=inv and inv.imagename
        if type(image)=="string" and image:sub(-4)~=".tex" then image=image..".tex" end
        catalog.items[tostring(slot)]={prefab=item.prefab,name=item:GetBasicDisplayName(),count=count(item),token=self:SlotToken(pageid,slot),
            image=image,atlas=inv and inv.atlasname,skin=item.skinname,
            room=item.components.stackable and item.components.stackable:RoomLeft() or nil}
    end
    catalog.pending={}
    for slot in pairs(self.reserved[pageid] or {}) do catalog.pending[tostring(slot)]=true end
    return catalog
end
function Vault:SendCatalog(peer,uid,pageid,session)
    local views=self.remoteviews and self.remoteviews[peer]
    if self.native and self.native.shared and views and views[uid] and views[uid].shared then
        return self.native.shared:Send(peer,uid,pageid,session)
    end
    local catalog=self:Catalog(pageid)
    if catalog then catalog.session=session;self.transport:Send(peer,{vault=1,kind="CATALOG",userid=uid,catalog=catalog}) end
end
function Vault:BroadcastCatalog()
    for peer,views in pairs(self.remoteviews or {}) do
        for uid,view in pairs(views) do
            if GetStaticTime()-view.time>10 then views[uid]=nil
            else self:SendCatalog(peer,uid,view.page,view.session) end
        end
    end
end
function Vault:ToClient(uid,data)
    if self.native then return end
    local raw=json.encode(data)
    if #raw>60000 then self:Say(uid,"空间信息过大，请查看服务器日志。","Space catalog is too large.");return end
    SendModRPCToClient(GetClientModRPC("MOD_HARDMODE","shadowvault_ui"),uid,raw)
end
function Vault:ShowCatalog(uid,view,catalog)
    view.catalog=catalog
    catalog.viahat=view.anchor and view.anchor.prefab=="tophat_container" or nil
    catalog.status=self:ClientState(uid)
    self:ToClient(uid,catalog)
    if view.travel_to==catalog.page and catalog.ready then
        view.travel_to=nil
        self:SayTravel(uid,catalog.page)
    end
end
function Vault:Travel(uid,view,page)
    view.page,view.catalog,view.travel_to=page,nil,page
    self:Refresh(uid)
end
function Vault:Refresh(uid)
    if self.native then return end
    local view=self.views[uid]
    if not view or not self:AccessAllowed(uid) then self:Close(uid);return end
    if self.master then
        local catalog=self:Catalog(view.page)
        if catalog then
            catalog.session=view.session
            self:ShowCatalog(uid,view,catalog)
        end
    else self.transport:Send(tostring(SHARDID.MASTER),{vault=1,kind="VIEW",userid=uid,page=view.page,session=view.session}) end
end
function Vault:QuickStore(player,item)
    if self.native then return self.native.shared and self.native.shared:QuickStore(player,item) or false end
    local uid=player.userid
    local view=self.views[uid]
    local catalog=view and view.catalog
    if not catalog or not catalog.ready or not self:AccessAllowed(uid) then return false end
    local private=player.magicianprivatecontainer2hm
    if valid(private) and private.components.container:IsOpenedBy(player) then return false end
    local inventory=player.components.inventory
    local owner=item.components.inventoryitem.owner
    local overflow=inventory:GetOverflowContainer()
    if not item.components.inventoryitem.cangoincontainer or inventory:GetActiveItem()==item or
        (owner~=player and (not overflow or owner~=overflow.inst)) then return false end
    local slot=Config.QuickStoreSlot(catalog,item.prefab,item.skinname)
    if not slot then return false end
    local page=self.master and self.pages[view.page] or self:LocalBase(Config.IsTacklePage(view.page) and Config.TacklePage(self.id) or self.id)
    local target=valid(page) and page.components.container
    if not target or target.itemtestfn and not target:itemtestfn(item,slot) then return false end
    local entry=catalog.items[tostring(slot)]
    self:Action(player,"quickstore",view.page,slot,entry and entry.token or catalog.emptytoken,view.session,item,count(item))
    return true
end
function Vault:Action(player,action,pageid,slot,token,session,expecteditem,expectedcount)
    local uid=player.userid
    local view=self.views[uid]
    if (self.master and not self.journal) or not view or not self:AccessAllowed(uid) then return end
    if action=="close" and session==view.session then self:Close(uid);return end
    local now=GetStaticTime()
    if player._shadowvault_nextaction and now<player._shadowvault_nextaction then return end
    player._shadowvault_nextaction=now+.25
    if session~=view.session then self:Notify(uid,"stale");return end
    local localpage=Config.IsTacklePage(view.page) and Config.TacklePage(self.id) or self.id
    if (not self.master and not self:IsImported(localpage)) or not self.native_ready or self.error then return self:Notify(uid,"recovery") end
    if action=="page" then
        if type(pageid)=="string" and pageid~=view.page and self.registry[pageid] and Config.SameSpace(view.page,pageid) and
            (TUNING.SHADOWVAULT_ENABLED2HM or pageid==localpage) then
            self:Travel(uid,view,pageid)
        end
        return
    end
    if action=="refresh" then self:Refresh(uid);return end
    if not self.master and (not Shard_IsWorldAvailable(tostring(SHARDID.MASTER)) or not self.transport.peers[tostring(SHARDID.MASTER)]) then return self:Notify(uid,"offline") end
    if self:PendingDelivery(uid) then return self:Notify(uid,"delivery") end
    if self.protocol.active then return self:Notify(uid,"busy") end
    if self.journal and (not self.journal.ready or self.journal.busy or self.journal.staging) then return self:Notify(uid,"busy") end
    if action=="sort" and pageid==view.page then
        if self.master then self:SortPage(pageid)
        else self.transport:Send(tostring(SHARDID.MASTER),{vault=1,kind="SORT",userid=uid,page=pageid,session=session}) end
        return
    end
    if action=="upgrade" and pageid==view.page and Config.IsTacklePage(pageid) then
        local upgrade=TUNING.util2hm and TUNING.util2hm.UpgradeShadowVaultTackle2hm
        if upgrade and valid(self.tackle) then upgrade(player,self.tackle) end
        return
    end
    if pageid~=view.page or not self.registry[pageid] or type(slot)~="number" or slot%1~=0 or slot<1 or slot>1000 then return end
    local op=action=="deposit" and "D" or action=="withdraw" and (expectedcount=="cursor" and "T" or "W") or
        action=="takehalf" and "H" or action=="place" and "P" or (action=="placeone" or action=="swapone") and "S" or
        action=="quickstore" and "Q" or action=="quickstorehalf" and "K" or
        action=="quicktake" and "T" or action=="use" and "T" or action=="drop" and "T" or action=="dropone" and "J" or nil
    if not op and action~="inspect" then return end
    local taking=op=="W" or slot_take(op)
    local catalog=view.catalog
    local entry=catalog and catalog.items[tostring(slot)]
    if not Config.ValidStamp(token) or not catalog or catalog.page~=pageid or
        token~=(entry and entry.token or catalog.emptytoken) or ((taking or op=="P" or action=="inspect") and not entry) or (op=="D" and entry) then
        self:Notify(uid,"stale");return
    end
    if action=="inspect" then
        local page=self.master and self.pages[pageid]
        local target=valid(page) and token==self:SlotToken(pageid,slot) and page.components.container.slots[slot]
        if target then
            ACTIONS.LOOKAT.fn(BufferedAction(player,nil,ACTIONS.LOOKAT,target))
        elseif not self.master and player.components.talker then
            local ok,line=pcall(GetDescription,player,{prefab=entry.prefab,components={inspectable={}}})
            if not ok or not line then line=GetString(player,"DESCRIBE",entry.prefab,true) end
            if line then player.components.talker:Say(line) end
        end
        return
    end
    local pending=0;for _ in pairs(self.rows) do pending=pending+1 end
    if pending>=32 then return self:Notify(uid,"limit") end
    local inventory=player.components.inventory
    local active=inventory:GetActiveItem()
    local item=not taking and active or nil
    local source,source_slot
    if quick_store(op) then
        item=type(expecteditem)=="table" and Ents[expecteditem.GUID]==expecteditem and expecteditem or nil
        local owner=item and item.components.inventoryitem and item.components.inventoryitem.owner
        local overflow=inventory:GetOverflowContainer()
        source=owner==player and inventory or overflow and owner==overflow.inst and overflow or nil
        source_slot=source and source:GetItemSlot(item)
        if not source_slot or item.components.inventoryitem.islockedinslot or
            item.components.stackable and item.components.stackable:IsOverStacked() then return self:Notify(uid,"cursor") end
    end
    if not taking and (not valid(item) or not item.components.inventoryitem or inside(view.anchor,item)) then return self:Notify(uid,"cursor") end
    if not taking and (item~=expecteditem or count(item)~=expectedcount) then return self:Notify(uid,"cursor") end
    if slot_take(op) and expectedcount=="cursor" and active then return self:Notify(uid,"cursor") end
    if not taking and Config.IsTacklePage(pageid) then
        local c=valid(self.tackle) and self.tackle.components.container
        if not c or c.itemtestfn and not c:itemtestfn(item,slot) then return self:Notify(uid,"unsupported") end
    end
    local escrow=SpawnPrefab(action=="swapone"and"shadowvaultpair2hm"or"shadowvaulttransfer2hm")
    if not escrow then return end
    local name=self:MakeName(op,pageid,slot,uid,token,session)
    local row={op=op,page=pageid,slot=slot,userid=uid,state="active",escrow=escrow,localonly=self.master or nil,token=token}
    if action=="swapone"then
        local parsed=Config.Parse(name)
        name=name:gsub(":"..parsed.nonce..":",":"..parsed.nonce.."_s1:",1)
        row.paired=true
    end
    local requested=player._shadowvault_requested_count2hm
    if view.shared and type(requested)=="number" and requested%1==0 and requested>=1 and requested<=1000000000 then
        local parsed=Config.Parse(name)
        name=name:gsub(":"..parsed.nonce..":",":"..parsed.nonce.."_n"..requested..":",1)
        row.requested_count=requested
    end
    if expectedcount=="cursor" or op=="P" or op=="S" or view.shared and op=="D" then row.cursor_session=view.session end
    if action=="use" or action=="drop" or action=="dropone" then
        if action=="use" and expecteditem~=active then escrow:Remove();return self:Notify(uid,"cursor") end
        row.after_delivery=action
        row.delivery_session=view.session
        row.active_guid=active and active.GUID
    end
    if self.master then
        local page=self.pages[pageid]
        if not valid(page) or not self.registry[pageid].imported or slot>page.components.container.numslots or
            (self.reserved[pageid] and self.reserved[pageid][slot]) or token~=self:SlotToken(pageid,slot) then
            escrow:Remove();return self:Notify(uid,"stale")
        end
        if action=="use" then
            local target=page.components.container.slots[slot]
            local picker=player.components.playeractionpicker
            local actions=picker and not player.sg:HasStateTag("busy") and
                (active and picker:GetUseItemActions(target,active,true) or picker:GetInventoryActions(target))
            if not actions or not actions[1] then escrow:Remove();return end
        end
    end
    if self.journal and item then
        self.journal:StageDeposit(name,row,item,player,source,source_slot)
        return
    end
    if item and not Journal.CanStageDeposit(escrow.components.container,item) then
        escrow:Remove();return self:Notify(uid,"unsupported")
    end
    self.rows[name]=row
    if self.master then
        local target=self.pages[pageid].components.container
        if slot_take(op) then
            local ok,why=self:PlanSlot(row,target)
            if not ok then self.rows[name]=nil;escrow:Remove();return self:Notify(uid,why) end
            self:Reserve(name,row)
            local done,error_reason=self:Finalize(name,true)
            if not done then self:Fail(error_reason);return end
            self.journal:Flush();self:Refresh(uid);return
        end
        self:Reserve(name,row)
        local removed=take(target,slot)
        if not removed or not put(escrow.components.container,removed,1) then self:Fail("withdraw_reservation_failed");return end
        row.state="delivery";self:Unreserve(row)
        self.journal:Flush();self:Refresh(uid);return
    end
    if item then
        item=player.components.inventory:RemoveItem(item,true,nil,true)
        if not item or not put(escrow.components.container,item,1) then self:Fail("deposit_reservation_failed");return end
    end
    local ok,why=self.protocol:Start(name,tostring(SHARDID.MASTER),uid)
    if not ok then self:Unlock(name);self:Notify(uid,why) end
end
function Vault:Deliver()
    if self.journal then
        for name,row in pairs(self.rows) do
            local player=playerfor(row.userid)
            if player and not player._despawning then self.journal:Deliver(name,row,player) end
        end
        return
    end
    for name,row in pairs(self.rows) do
        if row.state=="delivery" then
            local player=playerfor(row.userid)
            local c=row.escrow.components.container
            local item=c.slots[1]
            if not item then self:Fail("empty_delivery");return end
            if player and not player._despawning and player.components.inventory:CanAcceptCount(item,count(item))>=count(item) then
                item=take(c,1)
                item.prevcontainer=nil;item.prevslot=nil
                player.components.inventory:GiveItem(item)
                if valid(item) and not inside(item,player) then
                    put(c,item,1);self:Fail("delivery_rejected");return
                end
                row.escrow:Remove();self.rows[name]=nil
                self:Notify(row.userid,"done")
                self:Refresh(row.userid)
            end
        end
    end
end
function Vault:Status(player)
    if self.native then
        local view=self.views[player.userid]
        if self.protocol.active then self:Say(player.userid,"空间正在交接。","A space is moving between shards.")
        elseif view then self:Say(player.userid,"当前是世界"..Config.PageShard(view.page).."的空间。",
            "Current space belongs to shard "..Config.PageShard(view.page)..".")
        else self:Say(player.userid,"当前没有打开空间。","No space is open.") end
        return
    end
    local t=self.protocol and self.protocol.active
    if self.error or t and t.error then self:Say(player.userid,"存取记录已保留待恢复，请查看服务器日志。","Transfer held for recovery; check the server log.")
    elseif self:PendingDelivery(player.userid) then self:Notify(player.userid,"delivery")
    elseif t then self:Say(player.userid,"存取正在确认；断线后会继续处理。","Transfer awaiting confirmation; it resumes after reconnection.")
    else self:Say(player.userid,"主世界保管各空间，目标层离线不影响地面访问。","The master holds all spaces; their shards may be offline.") end
    if self.protocol then self.protocol.retry=0 end
end
function Vault:Update()
    self:Initialize()
    if self.error and self.journal then self.journal:TryRecover() end
    if not self.protocol or self.error then return end
    local variants=self.inst.components.exchangevariants2hm
    if self.retired and not (variants and variants.migrating) then return end
    self.transport:Update()
    if self.retired then variants.migration:Tick(self);return end
    if self.journal then
        if not self.journal.ready or self.journal.error then return end
        self.native_ready=true
        for _,player in ipairs(AllPlayers) do
            if player._shadowvault_reconcile then
                self.journal:ReconcilePlayer(player);player._shadowvault_reconcile=nil
            end
        end
    end
    if not self.master and not self.native_ready then return end
    self.protocol:Tick()
    if self.journal then self.journal:RefreshIssued();self.journal:ResumeDeposits() end
    if not self.master and not (variants and variants.migrating) then
        self:StartImport()
        self:StartImport(Config.TacklePage(self.id))
        for family in pairs(self.native_bases or {}) do
            if family~="shadow" and family~="tacklestation2hm" then self:StartImport(Config.Page(self.id,family)) end
        end
    end
    if self.journal then self.journal:Forward() else Courier.Receive(self);Courier.Forward(self) end
    self:Deliver()
    if variants and variants.migrating then variants.migration:Tick(self);return end
    if self.native then self.native:Update() end
    for uid,view in pairs(self.views) do
        if view.native then
            -- Native container_proxy owns its opener, animation and close checks.
        elseif not self:AccessAllowed(uid) then self:Close(uid)
        elseif valid(view.proxy) then
            local player=playerfor(uid)
            view.proxy.Transform:SetPosition((view.anchor.Transform or player.Transform):GetWorldPosition())
            if not view.proxy.components.container_proxy:IsOpenedBy(player) then self:Close(uid) end
        end
    end
    if not self.nextrefresh or GetStaticTime()>=self.nextrefresh then
        self.nextrefresh=GetStaticTime()+2
        if self.master then self:BroadcastCatalog() end
        for uid in pairs(self.views) do self:Refresh(uid) end
    end
end
function Vault:OnSave()
    if self.retired then return {version=1,status="retired",journal_namespace=self.journal_namespace} end
    if self.status~="active" then return {version=1,status=self.status,journal_namespace=self.journal_namespace} end
    if self.native and self.native.shared and self.master then self.native.checkpoint_epochs={}end
    if self.journal and self.journal.ready then self.journal:Flush() end
    local data={version=1,status=self.status,registry=deepcopy(self.registry),pages={},rows={},imported=self.imported,tackle_imported=self.tackle_imported,error=self.error,
        protocol=self.protocol and self.protocol:Save() or self.saved_protocol}
    data.journal_version=self.journal and 4 or self.journal_version
    data.journal_namespace=self.journal_namespace
    data.native=self.native and self.native:Save() or self.saved_native_world
    data.extra_imported=deepcopy(self.extra_imported)
    data.native_bases={}
    data.travel_receipts=deepcopy(self.travel_receipts)
    data.travel_inbox=deepcopy(self.travel_inbox)
    data.delivery_routes=deepcopy(self.delivery_routes)
    local refs={}
    for family,base in pairs(self.native_bases or {}) do
        if valid(base) then data.native_bases[family]=base.GUID;refs[#refs+1]=base.GUID end
    end
    -- Keep damaged reference records visible for recovery. Never overwrite a
    -- partly readable vault with an apparently valid set of empty spaces.
    for id,guid in pairs(self.unresolved_pages or {}) do data.pages[id]=guid end
    for name,row in pairs(self.unresolved_rows or {}) do data.rows[name]=deepcopy(row) end
    for id,page in pairs(self.pages) do
        if valid(page) then data.pages[id]=page.GUID;refs[#refs+1]=page.GUID end
    end
    for name,row in pairs(self.rows) do
        local saved={}
        for k,v in pairs(row) do if k~="escrow" then saved[k]=v end end
        if valid(row.escrow) then saved.escrow=row.escrow.GUID;refs[#refs+1]=row.escrow.GUID end
        data.rows[name]=saved
    end
    return data,refs
end
function Vault:OnLoad(data)
    if not data or data.version~=1 then return end
    self.status=data.status or self.status
    self.journal_namespace=data.journal_namespace
    -- A deliberate later selection of Nexus starts a fresh journal. It must
    -- never replay the old contents already handed to original containers.
    if self.status=="retired" then self.status="initializing";return end
    self.registry=data.registry or {}
    self.imported,self.error=data.imported,data.journal_version~=4 and data.error or nil
    self.tackle_imported=data.tackle_imported
    self.journal_version=data.journal_version
    self.saved_protocol=data.protocol
    self.saved_native_world=data.native
    self.extra_imported=data.extra_imported or {}
    self.travel_receipts=data.travel_receipts or {}
    self.travel_inbox=data.travel_inbox or {}
    self.delivery_routes=data.delivery_routes or {}
    self.load_data=data
end
function Vault:RestoreNativeBases(newents,data)
    if not data then return end
    self.native_bases={}
    for family,guid in pairs(data.native_bases or {}) do
        local entry=newents[guid]
        if entry and entry.entity then
            self.native_bases[family]=entry.entity
            if TUNING.SHADOWVAULT_ENABLED2HM then self.inst:SetPocketDimensionContainer(family,entry.entity) end
        else self:Fail("missing_native_base");return end
    end
end
function Vault:LoadPostPass(newents,data)
    data=data or self.load_data
    if not data then return end
    self.unresolved_pages,self.unresolved_rows={},{}
    self:RestoreNativeBases(newents,data)
    if self.error then return end
    for id,guid in pairs(data.pages or {}) do
        local entry=newents[guid]
        if not entry or not entry.entity then
            self.unresolved_pages[id]=guid
            if data.journal_version~=4 then self:Fail("missing_saved_page") end
        else
            self.pages[id]=entry.entity
            if not TUNING.SHADOWVAULT_ENABLED2HM then
                Config.ProtectPreserver(entry.entity)
                entry.entity.components.container:EnableReadOnlyContainer(true)
                entry.entity.exchange_inactive2hm=true
            end
        end
    end
    for name,saved in pairs(data.rows or {}) do
        local entry=newents[saved.escrow]
        if not entry or not entry.entity then
            self.unresolved_rows[name]=deepcopy(saved)
            if data.journal_version~=4 then self:Fail("missing_saved_transfer") end
        else
            local row={};for k,v in pairs(saved) do row[k]=v end
            row.escrow=entry.entity;self.rows[name]=row
        end
    end
    self.load_data=nil
end
function Vault:OnRemoveFromEntity()
    if self.task then self.task:Cancel() end
    if self.transport then self.transport:Close() end
    for uid in pairs(self.views) do self:Close(uid) end
end
Vault.OnRemoveEntity=Vault.OnRemoveFromEntity
return Vault
