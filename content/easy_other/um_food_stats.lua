-- 保留各锅具的原生烹饪与收获流程。只接管妥协动态料理模块的属性计算和存档。
if TUNING.umfoodstatscompat2hm then return end
local function FindUMHook(hooks)
    for index, fn in ipairs(hooks or {}) do
        local source = debug.getinfo(fn, "S").source:gsub("\\", "/")
        if source:match("/init/init_food/init_food_stats%.lua$") then return index end
    end
end

local component_hooks, stewer_hook, edible_hook
for _, mod in ipairs(ModManager.mods) do
    local hooks = mod.postinitfns and mod.postinitfns.ComponentPostInit
    if hooks then
        local stewer, edible = FindUMHook(hooks.stewer), FindUMHook(hooks.edible)
        if stewer and edible then
            component_hooks, stewer_hook, edible_hook = hooks, stewer, edible
            break
        end
    end
end
if not component_hooks then return end
table.remove(component_hooks.stewer, stewer_hook)
table.remove(component_hooks.edible, edible_hook)
TUNING.umfoodstatscompat2hm = true

local fields = {"hunger", "health", "sanity"}
local scales = {hunger = 200, health = 80, sanity = 33}
local rich_prefix = {hunger = "FILLING", health = "HEALTHY", sanity = "SOOTHING"}
local poor_prefix = {hunger = "MEAGER", health = "UNHEALTHY", sanity = "RANCID"}

local function GetBaseStats(inst)
    local edible = inst.components.edible
    return inst.original_stats or {hunger = edible.hungervalue, health = edible.healthvalue, sanity = edible.sanityvalue}
end

local function ReadDynamicStats(inst)
    local edible = inst and inst.components.edible
    if edible and (edible.cookstat_hunger ~= nil or edible.cookstat_health ~= nil or edible.cookstat_sanity ~= nil) then
        return {hunger = edible.hungervalue, health = edible.healthvalue, sanity = edible.sanityvalue}
    end
end

local function UpdatePrefix(inst)
    local edible, base = inst.components.edible, inst.original_stats
    local rich, first_rich, first_poor = 0
    for _, field in ipairs(fields) do
        local initial, current = base[field] or 0, edible[field .. "value"] or 0
        if initial ~= 0 and current / initial > 2 then
            rich = rich + 1
            first_rich = first_rich or rich_prefix[field]
        end
        if current < initial - 25 then first_poor = first_poor or poor_prefix[field] end
    end
    inst.food_prefix = rich >= 2 and "BALANCED" or first_rich or first_poor
    if inst.net_food_prefix then inst.net_food_prefix:set(inst.food_prefix or "") end
end

local function ApplyStats(inst, values, base)
    local edible = inst.components.edible
    if not edible or not values then return end
    inst.original_stats = base or GetBaseStats(inst)
    for _, field in ipairs(fields) do
        if type(values[field]) == "number" then
            edible[field .. "value"] = values[field]
            edible["cookstat_" .. field] = values[field]
        end
    end
    UpdatePrefix(inst)
end

local function GetIngredientStats(item)
    local edible = item.components.edible
    local cookable = item.components.cookable
    local cooked
    if edible and (edible.foodtype == FOODTYPE.MEAT or edible.foodtype == FOODTYPE.VEGGIE)
        and not item:HasTag("mushroom") and cookable and type(cookable.product) == "string" and Prefabs[cookable.product] then
        cooked = SpawnPrefab(cookable.product)
    end
    local ingredient = cooked and cooked.components.edible and cooked or item
    edible = ingredient.components.edible
    local row = {}
    for _, field in ipairs(fields) do
        local value = edible and edible[field .. "value"] or 0
        if edible and edible.foodtype == FOODTYPE.VEGGIE and not ingredient:HasTag("mushroom") then value = math.abs(value) end
        if edible and edible.foodtype == FOODTYPE.ROUGHAGE then value = 0 end
        row[field] = value + (ingredient.potstats and ingredient.potstats[field] or 0)
    end
    if cooked then cooked:Remove() end
    return row
end

local function CollectStats(items, gem_slot)
    local stats = {}
    for slot, item in pairs(items) do
        if slot ~= gem_slot and item:IsValid() then
            table.insert(stats, GetIngredientStats(item))
        end
    end
    return next(stats) and stats or nil
end

local function CalculateStats(inst, stats)
    local edible = inst.components.edible
    if not edible or edible.foodtype == FOODTYPE.ROUGHAGE then return end
    if stats.inherited then return stats.inherited end
    local base, result = GetBaseStats(inst), {}
    for _, field in ipairs(fields) do
        local sum = 0
        for slot, row in pairs(stats) do
            if type(slot) == "number" and type(row) == "table" then sum = sum + math.max(0, row[field] or 0) end
        end
        result[field] = sum * (1 + (base[field] or 0) / scales[field])
    end
    return result
end

local function BlendStats(inst, incoming, old_size, added)
    local edible = inst.components.edible
    local values = {}
    for _, field in ipairs(fields) do
        local current = edible[field .. "value"] or 0
        values[field] = (old_size * current + added * (incoming[field] or current)) / (old_size + added)
    end
    ApplyStats(inst, values)
end

-- 收获期间在成品进入物品栏或堆叠前应用属性，沿用各锅自己的产量、事件与计时。
local output_context
local function WithOutput(product, stats, fn, ...)
    local previous = output_context
    output_context = product and stats and {product = product, stats = stats} or nil
    local function Finish(ok, ...)
        output_context = previous
        if not ok then error((...), 0) end
        return ...
    end
    return Finish(pcall(fn, ...))
end

AddPrefabPostInitAny(function(inst)
    local context = output_context
    if TheWorld.ismastersim and context and inst.prefab == context.product then
        ApplyStats(inst, CalculateStats(inst, context.stats))
    end
end)

local function PatchStewer(self)
    local StartCooking, Harvest = self.StartCooking, self.Harvest
    local OnSave, OnLoad = self.OnSave, self.OnLoad
    function self:StartCooking(doer, ...)
        local container = self.inst.components.container
        if self.targettime ~= nil or not container then return StartCooking(self, doer, ...) end
        local stats
        if self.inst:HasTag("spicer") then
            local inherited = ReadDynamicStats(container:GetItemInSlot(1))
            stats = inherited and {inherited = inherited} or nil
        else
            local gem_slot = self.inst.prefab == "dragonflyfurnace" and self.multi2hm and 1 or nil
            stats = CollectStats(container.slots, gem_slot)
        end
        local result = StartCooking(self, doer, ...)
        if self.product and self.targettime ~= nil then self.food_stats = stats end
        return result
    end
    function self:Harvest(...)
        if not self.done then return Harvest(self, ...) end
        local stats = self.product ~= self.spoiledproduct and self.food_stats or nil
        local result = WithOutput(self.product, stats, Harvest, self, ...)
        if result then self.food_stats = nil end
        return result
    end
    function self:OnSave(...)
        local data, references = OnSave(self, ...)
        if data and self.food_stats then
            -- 保持旧动态料理读档代码认识的四个食材条目。
            local stats = {{}, {}, {}, {}}
            for key, value in pairs(self.food_stats) do stats[key] = value end
            data.food_stats = stats
        end
        return data, references
    end
    function self:OnLoad(data, ...)
        self.food_stats = data and data.food_stats
        return OnLoad(self, data, ...)
    end
end
AddComponentPostInit("stewer", PatchStewer)
AddComponentPostInit("stewer_wagstaff", PatchStewer)

AddComponentPostInit("edible", function(self)
    local OnSave, OnLoad, DiluteChill = self.OnSave, self.OnLoad, self.DiluteChill
    function self:OnSave(...)
        local data, references = OnSave(self, ...)
        if ReadDynamicStats(self.inst) then
            data = data or {}
            for _, field in ipairs(fields) do data["cookstat_" .. field] = self["cookstat_" .. field] end
            data.original_stats = self.inst.original_stats
            data.food_prefix = self.inst.food_prefix
        end
        return data, references
    end
    function self:OnLoad(data, ...)
        local result = OnLoad(self, data, ...)
        if data and (data.cookstat_hunger ~= nil or data.cookstat_health ~= nil or data.cookstat_sanity ~= nil) then
            ApplyStats(self.inst, {hunger = data.cookstat_hunger, health = data.cookstat_health, sanity = data.cookstat_sanity},
                data.original_stats)
        end
        return result
    end
    function self:DiluteChill(item, count)
        DiluteChill(self, item, count)
        if count > 0 and item.components.edible and (ReadDynamicStats(self.inst) or ReadDynamicStats(item)) then
            local edible = item.components.edible
            BlendStats(self.inst, {hunger = edible.hungervalue, health = edible.healthvalue, sanity = edible.sanityvalue},
                self.inst.components.stackable:StackSize(), count)
        end
    end
end)

AddComponentPostInit("stackable", function(self)
    local Get = self.Get
    function self:Get(...)
        local split = Get(self, ...)
        if split and split ~= self.inst then ApplyStats(split, ReadDynamicStats(self.inst), self.inst.original_stats) end
        return split
    end
end)

AddComponentPostInit("moonsimmered", function(self)
    local ComputAndCost, SpawnProduct = self.ComputAndCost, self.SpawnProduct
    function self:ComputAndCost(times, items, index)
        local line = self.todos and self.todos[index]
        if not line or not line.product then return ComputAndCost(self, times, items, index) end
        local stats
        if line.spice then
            local inherited = ReadDynamicStats(items[1])
            stats = inherited and {inherited = inherited} or nil
        else
            stats = CollectStats(items)
        end
        return WithOutput(line.product, stats, ComputAndCost, self, times, items, index)
    end
    function self:SpawnProduct(product, perishpercent, count, slot, ...)
        -- 棱镜会在产出格直接加堆叠，绕过原版 Stackable:Put。
        local context = output_context
        local container = self.inst.components.container
        local item = slot and container and container:GetItemInSlot(slot)
        local stack = item and item.prefab == product and item.components.stackable
        if not context or context.product ~= product or not stack or stack:IsFull() then
            return SpawnProduct(self, product, perishpercent, count, slot, ...)
        end
        local values = CalculateStats(item, context.stats)
        if values then BlendStats(item, values, stack:StackSize(), math.min(count, stack:RoomLeft())) end
        return SpawnProduct(self, product, perishpercent, count, slot, ...)
    end
end)

AddPrefabPostInit("simmeredmoonlight_item", function(inst)
    local kit = inst.components.upgradekit
    if not kit or not kit.data then return end
    local data = {}
    for prefab, entry in pairs(kit.data) do
        local settings = {}
        for key, value in pairs(entry) do settings[key] = value end
        local OnUpgrade = entry.onupgradefn
        if OnUpgrade then
            settings.onupgradefn = function(item, doer, target, result)
                local stewer = target.components.stewer
                if stewer and stewer.done and stewer.product ~= stewer.spoiledproduct then
                    return WithOutput(stewer.product, stewer.food_stats, OnUpgrade, item, doer, target, result)
                end
                return OnUpgrade(item, doer, target, result)
            end
        end
        data[prefab] = settings
    end
    kit:SetData(data)
end)
