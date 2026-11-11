-- A restored page may replace an entity while an entrance still holds it.
-- Rebind only to an existing canonical container; never create empty storage.
local Config=require("shadowvaultconfig2hm")
local Proxy={}
local function valid(e)return e and e:IsValid()end
local function ready(e)
    return valid(e) and e.components.container and e.replica and e.replica.container and
        valid(e.replica.container.classified)
end
Proxy.Ready=ready
function Proxy.Family(entity,v)
    if not entity or not Config.Manageable("",entity) then return end
    if entity.prefab=="shadowbank_container2hm" then return "shadow" end
    if entity.prefab=="shadowbank_tackle2hm" then return "tacklestation2hm" end
    if entity.shadowvault_page2hm then return Config.Family(entity.shadowvault_page2hm) end
    for family,base in pairs(v and v.native_bases or {})do
        if base==entity and Config.Manageable(family,base) then return family end
    end
    for family,base in pairs(TheWorld.PocketDimensionContainers or {})do
        if base==entity and Config.Manageable(family,base) then return family end
    end
    -- Vanilla pocket prefabs have distinct names, including our tackle pocket.
    for _,def in ipairs(require("prefabs/pocketdimensioncontainer_defs").POCKETDIMENSIONCONTAINER_DEFS)do
        if def.prefab==entity.prefab then return def.name end
    end
end
function Proxy.DetachStale(self)
    local hadopen=self.opencount>0
    for player,opener in pairs(self.openlist)do
        if valid(opener) then opener:Remove() end
        if valid(player) and player.components.inventory then
            player.components.inventory.opencontainerproxies[self.inst]=nil
        end
        self.openlist[player]=nil
    end
    self.opencount=0
    self.inst:StopUpdatingComponent(self)
    if hadopen and self.onclosefn and valid(self.inst) then self.onclosefn(self.inst) end
end
function Proxy.Ensure(self,v)
    local master=self.master
    if ready(master) and not master.exchange_inactive2hm then return true end
    -- An entity whose networking is not ready must wait, not be replaced.
    if valid(master) and not master.exchange_inactive2hm then return false end
    local family=Proxy.Family(master,v) or self.shadowvault_family2hm
    local selected=TUNING.SHADOWVAULT_ENABLED2HM
    local replacement=selected and family and v and v.native_bases and v.native_bases[family]
    if selected and not ready(replacement) and family and v and v.id then
        replacement=v.pages and v.pages[Config.Page(v.id,family)]
    end
    if not ready(replacement) then replacement=family and TheWorld:GetPocketDimensionContainer(family) end
    Proxy.DetachStale(self)
    self:SetMaster(ready(replacement) and replacement or nil)
    if family then self.shadowvault_family2hm=family end
    return ready(self.master) and true or false
end
return Proxy
