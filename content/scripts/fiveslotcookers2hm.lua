-- Extend the supported cookers without replacing their recipes or cooking engines.
local M = {}
local moonrows = {simmeredmoonlight=1, simmeredmoonlight_pro=1,
    simmeredmoonlight_inf=4, simmeredmoonlight_pro_inf=4}

local function Extra(rows, row) return rows * 5 + row end
local function RowSlots(rows, row)
    local first = (row - 1) * 5
    return {first + 1, first + 2, first + 3, first + 4, Extra(rows, row)}
end

function M.Install(api, cooking, needfuel, refuel)
    if cooking.fiveslotcookers2hm then return end
    cooking.fiveslotcookers2hm = true
    local containers = require("containers")
    local function BuildRow(items, rows, row)
        local ingredients, names, dishes, spices = {}, {}, {}, {}
        local full = true
        for _, slot in ipairs(RowSlots(rows, row)) do
            local item = items[slot]
            if item and item:IsValid() then
                if item:HasTag("spice") then spices[#spices + 1] = item end
                if item:HasTag("preparedfood") and not item:HasTag("spicedfood") then dishes[#dishes + 1] = item end
                if cooking.IsCookingIngredient(item.prefab) and not item:HasTag("spice") then
                    ingredients[#ingredients + 1], names[#names + 1] = item, item.prefab
                else full = false end
            else full = false end
        end
        if full and #ingredients == 5 then return {items=ingredients, names=names} end
        if #dishes > 0 and #spices > 0 then return {items=dishes, names={}, spice=spices} end
    end
    local function PatchLayout(name, rows)
        local original = containers.params[name]
        if not original then return end
        local data = api.deepcopy(original)
        containers.params[name] = data
        local widget = data.widget
        for row=1,rows do
            local first = widget.slotpos[(row - 1) * 5 + 1]
            widget.slotpos[Extra(rows, row)] = api.Vector3(first.x - 75, first.y, first.z)
        end
        widget.side_align_tip = (widget.side_align_tip or 160) + 75
        widget.buttoninfo.validfn = function(inst)
            local container = inst.replica and inst.replica.container
            local items = container and container:GetItems()
            if not items then return false end
            for row=1,rows do if BuildRow(items, rows, row) then return true end end
            return false
        end
        for key, button in pairs(widget.btns_legion or {}) do
            local row = tonumber(key:match("^clearrow(%d+)$"))
            if row then
                button.position = api.Vector3(button.position.x - 75, button.position.y, button.position.z)
                local valid = button.validfn
                button.validfn = function(inst)
                    local c = inst.replica and inst.replica.container
                    return valid(inst) or (c and c:GetItemInSlot(Extra(rows, row)) ~= nil) or false
                end
            elseif key == "roast" then
                local valid = button.validfn
                button.validfn = function(inst)
                    if valid(inst) then return true end
                    local c = inst.replica and inst.replica.container
                    for row=1,rows do if c and c:GetItemInSlot(Extra(rows, row)) then return true end end
                    return false
                end
            end
        end
        containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, #widget.slotpos)
    end
    PatchLayout("simmeredmoonlight", 1)
    PatchLayout("simmeredmoonlight_inf", 4)
    if containers.params.medal_cookpot then
        local data = api.deepcopy(containers.params.medal_cookpot)
        data.widget.slotpos = api.deepcopy(containers.params.cookpot.widget.slotpos)
        data.widget.animbank = containers.params.cookpot.widget.animbank
        data.widget.animbuild = containers.params.cookpot.widget.animbuild
        data.widget.buttoninfo.position = api.Vector3(0, 0, 0)
        containers.params.medal_cookpot = data
    end
    api.AddPrefabPostInit("medal_cookpot", needfuel)

    local function PatchMoon(self)
        local rows = moonrows[self.inst.prefab]
        if not rows or self.fiveslotrules2hm then return end
        self.fiveslotrules2hm = true
        local setdata, slotfix, clear = self.SetCookData, self.SlotFix, self.BtnClear
        local function HasFuel()
            local fuel = self.inst.components.fueled
            return not fuel or not fuel:IsEmpty() or (self.chef and self.chef:HasTag("masterchef"))
        end
        function self:SetCookData(row, lines)
            local c = self.inst.components.container
            local line = c and BuildRow(c.slots, rows, row)
            lines[row] = line
            if not line then return end
            setdata(self, row, lines) -- native recipe, freshness, food skins and cook time
            line = lines[row]
            local fuel = self.inst.components.fueled
            if self.checkingfuel2hm and line and fuel and not (self.chef and self.chef:HasTag("masterchef")) and
                fuel:GetPercent() < 1 and fuel.currentfuel < (line.time or 0) then lines[row] = nil end
        end
        function self:TryCooking(doer)
            if doer then self:SetChef(doer) end
            local c = self.inst.components.container
            if not c then return end
            local checking = self.checkingfuel2hm
            self.checkingfuel2hm = true
            refuel(self.inst)
            local lines, first = {}, nil
            local ok, err = pcall(function()
                for row=1,rows do
                    self:SetCookData(row, lines)
                    first = first or lines[row]
                end
            end)
            self.checkingfuel2hm = checking
            if not ok then error(err, 0) end
            if first then
                self.todos, self.todokey = lines, 1
                self:ShowOn(first.recipe, first.skins)
                self:StartSimmering()
            else
                self:ShowOff()
            end
            self:SetFx(first ~= nil, false)
        end
        function self:SlotFix(slot)
            if slot > rows * 5 then slot = (slot - rows * 5 - 1) * 5 + 1 end
            local previous = self.task_slotfix
            local result = slotfix(self, slot)
            if self.task_slotfix and self.task_slotfix ~= previous then
                self.task_slotfix:Cancel()
                self.task_slotfix = self.inst:DoTaskInTime(0, function()
                    self.task_slotfix = nil
                    if self.todokey or not self.opener then return end
                    local row = math.floor(((self.lastslot or 1) - 1) / 5) + 1
                    self.lastslot = nil
                    local lines = {}
                    self:SetCookData(row, lines)
                    local line = lines[row]
                    if line and line.recipe then self:ShowOn(line.recipe, line.skins) else self:ShowOff() end
                end)
            end
            return result
        end
        local onopen = self.OnBoxOpen
        function self:OnBoxOpen(...)
            local result = onopen(self, ...)
            if not self.todokey and self.opener then
                local row = 1
                local c = self.inst.components.container
                for index=1,rows do
                    if c and BuildRow(c.slots, rows, index) then row=index;break end
                end
                self:SlotFix((row - 1) * 5 + 1)
            end
            return result
        end
        function self:BtnClear(...)
            local command = self.inst.legion_cleardd
            if command and command.idx1 then
                local expanded = {}
                for slot=command.idx1,command.idx2 do expanded[#expanded + 1] = slot end
                for row=1,rows do
                    if command.idx1 <= (row - 1) * 5 + 1 and command.idx2 >= row * 5 then
                        expanded[#expanded + 1] = Extra(rows, row)
                    end
                end
                self.inst.legion_cleardd = expanded
            end
            local function Finish(ok, ...)
                self.inst.legion_cleardd = command
                if not ok then error((...), 0) end
                return ...
            end
            return Finish(pcall(clear, self, ...))
        end
        local start, pause, stop, docook = self.StartSimmering, self.PauseSimmering, self.StopSimmering, self.DoCooking
        function self:StartSimmering(...)
            refuel(self.inst)
            if self.todokey == 1 and not HasFuel() then return end
            local result = start(self, ...)
            local fuel = self.inst.components.fueled
            if fuel and self.task_simmer and self.todokey == 1 then fuel:StartConsuming() end
            return result
        end
        function self:PauseSimmering(...)
            local result = pause(self, ...)
            if self.inst.components.fueled then self.inst.components.fueled:StopConsuming() end
            return result
        end
        function self:StopSimmering(...)
            local result = stop(self, ...)
            if self.inst.components.fueled then self.inst.components.fueled:StopConsuming() end
            return result
        end
        function self:DoCooking(...)
            if not HasFuel() then return self:PauseSimmering() end
            return docook(self, ...)
        end
    end

    -- Scope transfer routing to the synchronous upgrade/deploy callback. Do not
    -- renumber saved output slots or intercept the global SpawnPrefab function.
    local transfer
    local function RouteResult(inst)
        local state = transfer
        if not state or inst.prefab ~= state.expected then return end
        state.target = inst
        local fuel = inst.components.fueled
        if fuel and state.fuel then fuel:SetPercent(state.fuel) else inst.fiveslotfuel2hm = state.fuel end
        local c = inst.components.container
        if c and state.items then
            local give = c.GiveItem
            c.GiveItem = function(container, item, slot, ...)
                return give(container, item, state.items[item] or slot, ...)
            end
            state.restore = function() c.GiveItem = give end
        end
    end
    local function WithTransfer(source, expected, items, fn, ...)
        local previous = transfer
        local fuel = source.components.fueled
        local state = {expected=expected, items=items, fuel=fuel and fuel:GetPercent() or source.fiveslotfuel2hm}
        transfer = state
        local function Finish(ok, ...)
            if state.restore then state.restore() end
            if state.target and state.target.boxitems_l and moonrows[source.prefab:gsub("_item$", "")] == 1 and
                expected:find("_inf", 1, true) then
                local items = state.target.boxitems_l
                items[21], items[6] = items[6], nil
            end
            transfer = previous
            if not ok then error((...), 0) end
            return ...
        end
        return Finish(pcall(fn, ...))
    end
    local function PatchTransfers(inst)
        local rows = moonrows[inst.prefab]
        if rows then
            inst.fiveslotrows2hm = rows
            needfuel(inst)
        end
        if not api.TheWorld.ismastersim then return end
        if rows and inst.components.moonsimmered then PatchMoon(inst.components.moonsimmered) end
        RouteResult(inst)
        local upgrade = inst.legionfn_chestupgrade
        if upgrade then
            inst.legionfn_chestupgrade = function(source, item, doer)
                local expected = rows and source.prefab.."_inf" or source.prefab:gsub("_item$", "_inf_item")
                local items = {}
                for slot, item in pairs(source.components.container and source.components.container.slots or {}) do
                    items[item] = rows == 1 and slot == 6 and 21 or slot
                end
                return WithTransfer(source, expected, items, upgrade, source, item, doer)
            end
        end
        local portable = inst.components.portablestructure
        if portable and portable.ondismantlefn then
            local dismantle = portable.ondismantlefn
            portable.ondismantlefn = function(source, ...)
                return WithTransfer(source, source.prefab.."_item", nil, dismantle, source, ...)
            end
        end
        local deployable = inst.components.deployable
        if deployable and deployable.ondeploy then
            local deploy = deployable.ondeploy
            deployable.ondeploy = function(source, ...)
                return WithTransfer(source, source.prefab:gsub("_item$", ""), nil, deploy, source, ...)
            end
            local save, load = inst.OnSave, inst.OnLoad
            inst.OnSave = function(source, data, ...)
                data.fiveslotfuel2hm = source.fiveslotfuel2hm
                if save then return save(source, data, ...) end
            end
            inst.OnLoad = function(source, data, ...)
                source.fiveslotfuel2hm = data and data.fiveslotfuel2hm
                if load then return load(source, data, ...) end
            end
        end
        if rows then
            local fuel = inst.components.fueled
            local take = fuel and fuel.ontakefuelfn
            if fuel then fuel:SetTakeFuelFn(function(source, ...)
                if take then take(source, ...) end
                local moon = source.components.moonsimmered
                if moon and moon.todokey == 1 and not moon.opener and not moon.task_simmer then moon:StartSimmering() end
            end) end
        end
    end
    for prefab in pairs(moonrows) do api.AddPrefabPostInit(prefab, PatchTransfers) end
    for _, prefab in ipairs({"simmeredmoonlight_pro_item", "simmeredmoonlight_pro_inf_item"}) do
        api.AddPrefabPostInit(prefab, PatchTransfers)
    end
    api.AddPrefabPostInit("simmeredmoonlight_item", function(inst)
        local kit = inst.components.upgradekit
        if not kit or not kit.data then return end
        local data = api.deepcopy(kit.data)
        for _, entry in pairs(data) do
            local upgrade = entry.onupgradefn
            if upgrade then entry.onupgradefn = function(item, doer, target, result)
                local items = {}
                local c = target.components.container
                local s = target.components.stewer
                for slot, food in pairs(c and c.slots or {}) do items[food] = slot == 5 and 6 or slot end
                -- During cooking the native upgrade recreates ingredients. Its fifth
                -- insertion also needs routing; a finished meal remains in output 5.
                local give = result.components.container and result.components.container.GiveItem
                local function Upgrade(...)
                    RouteResult(result)
                    local container = result.components.container
                    local routed = container and container.GiveItem
                    if routed then container.GiveItem = function(c, food, slot, ...)
                        if slot == 5 and not (s and s.done) then slot = 6 end
                        return give(c, food, items[food] or slot, ...)
                    end end
                    return upgrade(...)
                end
                return WithTransfer(target, result.prefab, items, Upgrade, item, doer, target, result)
            end end
        end
        kit:SetData(data)
    end)
end

return M
