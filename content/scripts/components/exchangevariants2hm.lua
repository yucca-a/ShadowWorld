-- Keep physical inventories referenced; Xianyu -> original also restores goods.
local Config=require("shadowvaultconfig2hm")
local Mode=require("exchangemode2hm")
local function valid(e)return e and e:IsValid()end
local function container(e,base)
    return valid(e) and e.components.container and (not base or e.prefab==base.prefab)
end
local Variants=Class(function(self,inst)
    self.inst=inst
    self.mode=Mode.Storage(TUNING.EXCHANGE_MODE2HM)
    self.banks={}
    self.task=inst:DoStaticPeriodicTask(.1,function()
        if not self.ready and not self.error then self:Restore(nil,nil) end
    end)
end)
function Variants:Capture()
    local banks=self.banks[self.mode] or {};self.banks[self.mode]=banks
    for family,e in pairs(self.inst.PocketDimensionContainers or {})do
        if valid(e) and Config.Manageable(family,e) then banks[family]=e end
    end
    if self.mode=="xianyu" and valid(self.inst.shadowbanksecond2hm) then self.second=self.inst.shadowbanksecond2hm end
    if self.mode=="xianyu" and valid(self.inst.shadowbanktacklesecond2hm) then self.tacklesecond=self.inst.shadowbanktacklesecond2hm end
end
function Variants:Freeze(e,on)
    if not valid(e) or not e.components.container then return end
    e.exchange_inactive2hm=on or nil
    Config.ProtectPreserver(e)
    e.components.container:EnableReadOnlyContainer(on)
end
function Variants:Restore(newents,data)
    if self.ready or self.error then return end
    if newents then
        -- A save can occur while the asynchronous journal probe is pending.
        -- Preserve current entity references instead of writing last boot's IDs.
        self.pending_entities={}
        for guid,row in pairs(newents)do
            if container(row.entity) then self.pending_entities[guid]=row.entity end
        end
    end
    if self.probing then return end
    if not self.inst:GetPocketDimensionContainer("shadow") then return end
    local saved=data and data.exchangevariants2hm or self.saved
    -- An older world image may predate its independent Nexus journal (as in
    -- the reported locked archive). Detect that ownership before giving its
    -- original physical inventory to a different mechanism.
    local pending=saved and saved.active=="hosted" and saved.migration_pending and not saved.migrated
        and self.mode=="classic"
    if (not saved or pending) and not self.probed and ShardGameIndex and self.inst.meta and self.inst.meta.session_identifier then
        self.probing=true
        local io=require("shadowvaultio2hm").New(ShardGameIndex)
        local remaining,found=3,false
        local prefix="sv4_"..self.inst.meta.session_identifier
        for _,suffix in ipairs({"_head","_bank0","_bank1"})do
            io.read(prefix..suffix,function(exists)
                found=found or exists;remaining=remaining-1
                if remaining==0 then
                    self.probing=nil;self.probed=true;self.journal_legacy=found
                    self:Restore(newents,data)
                end
            end)
        end
        return
    end
    local previous=saved and saved.active
    if saved and not newents then return end
    local journal_source=pending and self.journal_legacy and data and data.shadowvault2hm and
        data.shadowvault2hm.status=="active" and data.shadowvault2hm.journal_version==4
    local function resolve(records,mode)
        local result={}
        for family,guid in pairs(records or {})do
            local row=newents and newents[guid]
            local base=self.inst:GetPocketDimensionContainer(family)
            if row and container(row.entity,base) and Config.Manageable(family,row.entity) then result[family]=row.entity
            elseif journal_source and mode=="hosted" then
                -- These GUIDs can belong to a previous process after a blocked
                -- load was saved again. Only the unfinished journal-owned bank
                -- may be reconstructed; dormant independent banks stay strict.
                self.journal_recovery=true
                if container(base) then result[family]=base end
            else
                self.error="missing_mechanism_container"
                print("[ExchangeMigration2hm] protected",self.error,mode,family,tostring(guid))
                return
            end
        end
        return result
    end
    if saved then
        for mode,records in pairs(saved.banks or {})do
            self.banks[mode]=resolve(records,mode)
            if self.error then return end
        end
        if saved.second then
            local row=newents[saved.second]
            if not row or not valid(row.entity) then self.error="missing_xianyu_second_space";return end
            self.second=row.entity
        end
        if saved.tacklesecond then
            local row=newents[saved.tacklesecond]
            if not row or not valid(row.entity) then self.error="missing_xianyu_tackle_space";return end
            self.tacklesecond=row.entity
        end
    elseif self.journal_legacy or data and data.shadowvault2hm and data.shadowvault2hm.status=="active" then
        previous="hosted"
        self.banks.hosted=resolve(data and data.shadowvault2hm and data.shadowvault2hm.native_bases)
        if self.error then return end
    elseif data and data.shadowbank2hm and data.shadowbank2hm.version then
        previous="xianyu"
        self.second=self.inst.shadowbanksecond2hm
        self.tacklesecond=self.inst.shadowbanktacklesecond2hm
    end
    if self.journal_recovery then
        self.journal_recovery_sources={}
        local independent={}
        for mode,banks in pairs(self.banks)do
            if mode~="hosted" then for _,e in pairs(banks)do independent[e]=true end end
        end
        for _,row in pairs(newents or {})do
            local e=row.entity
            if container(e) and not independent[e] then
                for family,base in pairs(self.inst.PocketDimensionContainers or {})do
                    if Config.Manageable(family,base) and Config.Manageable(family,e) and container(e,base) then
                        self.journal_recovery_sources[e]=family
                        self:Freeze(e,true)
                        break
                    end
                end
            end
        end
        print("[ExchangeMigration2hm] recovering stale container references from journal")
    end
    previous=previous or self.mode
    self.xianyu_restore=self.mode~="xianyu" and (saved and saved.xianyu_restore or
        self.mode=="classic" and (previous=="xianyu" or saved and
            (saved.banks and saved.banks.xianyu or saved.second or saved.tacklesecond))) and true or nil
    local old=self.banks[previous] or {};self.banks[previous]=old
    for family,e in pairs(self.inst.PocketDimensionContainers or {})do
        if valid(e) and Config.Manageable(family,e) and not old[family] then old[family]=e end
    end
    self.migrated=saved and saved.migrated
    if previous=="hosted" and self.mode=="classic" and not self.migrated and
        (not saved or saved.migration_pending) then
        -- Recover the old journal before any original container can expose its
        -- contents. The migration returns authoritative pages to their homes.
        for family,e in pairs(old)do self.inst:SetPocketDimensionContainer(family,e)end
        self.migrating=true
        self.pending_entities=nil
        self.migration=require("exchangeoriginalmigration2hm").new(self)
        if self.task then self.task:Cancel();self.task=nil end
        return
    end
    local active=self.banks[self.mode] or {};self.banks[self.mode]=active
    for family,base in pairs(old)do
        if not valid(active[family]) then
            local reuse=self.mode==previous or previous=="xianyu" and self.mode=="classic"
            active[family]=reuse and base or Config.SpawnPage(Config.Page(tostring(TheShard:GetShardId()),family))
            if not valid(active[family]) then self.error="mechanism_container_spawn_failed";return end
            if reuse and self.mode~=previous then old[family]=nil end
        end
    end
    for mode,banks in pairs(self.banks)do
        for _,e in pairs(banks)do self:Freeze(e,mode~=self.mode) end
    end
    for family,e in pairs(active)do self.inst:SetPocketDimensionContainer(family,e) end
    if self.second then self.inst.shadowbanksecond2hm=self.second;self:Freeze(self.second,self.mode~="xianyu") end
    if self.tacklesecond then self.inst.shadowbanktacklesecond2hm=self.tacklesecond;self:Freeze(self.tacklesecond,self.mode~="xianyu") end
    -- Saved entrances must never continue to expose a dormant mechanism's base.
    for _,e in pairs(Ents)do
        local proxy=e.components.container_proxy
        if proxy then
            local master=proxy:GetMaster()
            if self.mode=="classic" and self.xianyu_restore then
                if self.second and master==self.second then proxy:SetMaster(active.shadow)
                elseif self.tacklesecond and master==self.tacklesecond then proxy:SetMaster(active.tacklestation2hm) end
            end
            for family,base in pairs(old)do
                if master==base and active[family]~=base then proxy:SetMaster(active[family]);break end
            end
        end
    end
    self.ready=true;self.saved=nil;self.pending_entities=nil
    if self.xianyu_restore and self.mode=="classic" then
        local recovery=require("exchangexianyurecovery2hm")
        recovery.Drain(self)
        -- Full original spaces remain usable. Overflow stays frozen and is
        -- retried after players free space, including after another restart.
        self.recoverytask=self.inst:DoPeriodicTask(1,function()recovery.Drain(self)end)
    end
    if self.task then self.task:Cancel();self.task=nil end
end
function Variants:OnSave()
    if not self.ready and not self.migrating then
        local data,refs=deepcopy(self.saved),{}
        if not data then return end
        for _,records in pairs(data.banks or {})do
            for family,guid in pairs(records)do
                local e=self.pending_entities and self.pending_entities[guid]
                if container(e,self.inst:GetPocketDimensionContainer(family)) and Config.Manageable(family,e) then
                    records[family]=e.GUID;refs[#refs+1]=e.GUID
                end
            end
        end
        for _,key in ipairs({"second","tacklesecond"})do
            local e=self.pending_entities and self.pending_entities[data[key]]
            if container(e) then data[key]=e.GUID;refs[#refs+1]=e.GUID end
        end
        return data,refs
    end
    if not self.migrating or self.migrated then self:Capture() end
    local active=self.migrating and not self.migrated and "hosted" or self.mode
    local data,refs={version=1,active=active,banks={},migrated=self.migrated,xianyu_restore=self.xianyu_restore,
        migration_pending=self.migrating and not self.migrated or nil},{}
    for mode,banks in pairs(self.banks)do
        data.banks[mode]={}
        for family,e in pairs(banks)do
            if valid(e) then data.banks[mode][family]=e.GUID;refs[#refs+1]=e.GUID end
        end
    end
    if valid(self.second) then data.second=self.second.GUID;refs[#refs+1]=self.second.GUID end
    if valid(self.tacklesecond) then data.tacklesecond=self.tacklesecond.GUID;refs[#refs+1]=self.tacklesecond.GUID end
    return data,refs
end
function Variants:OnLoad(data)self.saved=data end
function Variants:OnRemoveFromEntity()
    if self.task then self.task:Cancel()end
    if self.recoverytask then self.recoverytask:Cancel()end
end
Variants.OnRemoveEntity=Variants.OnRemoveFromEntity
return Variants
