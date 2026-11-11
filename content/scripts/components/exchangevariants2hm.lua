-- Keep physical inventories referenced; Xianyu -> original also restores goods.
local Config=require("shadowvaultconfig2hm")
local Mode=require("exchangemode2hm")
local function valid(e)return e and e:IsValid()end
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
    if self.probing then return end
    if not self.inst:GetPocketDimensionContainer("shadow") then return end
    local saved=data and data.exchangevariants2hm or self.saved
    -- An older world image may predate its independent Nexus journal (as in
    -- the reported locked archive). Detect that ownership before giving its
    -- original physical inventory to a different mechanism.
    if not saved and not self.probed and ShardGameIndex and self.inst.meta and self.inst.meta.session_identifier then
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
    local function resolve(records)
        local result={}
        for family,guid in pairs(records or {})do
            local row=newents and newents[guid]
            if not row or not valid(row.entity) then self.error="missing_mechanism_container";return end
            result[family]=row.entity
        end
        return result
    end
    if saved then
        for mode,records in pairs(saved.banks or {})do
            self.banks[mode]=resolve(records)
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
    self.ready=true;self.saved=nil
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
    if not self.ready and not self.migrating then return self.saved end
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
