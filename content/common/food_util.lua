local foods = require("foodsdata2hm")

for _, recipe in pairs (foods) do
    if recipe.warlyOnly then
        AddCookerRecipe("portablecookpot", recipe)
    else
        AddCookerRecipe("cookpot", recipe)
        AddCookerRecipe("portablecookpot", recipe)
        AddCookerRecipe("archive_cookpot", recipe)
    end

    if recipe.card_def then
        AddRecipeCard("cookpot", recipe)
    end

    RegisterInventoryItemAtlas(recipe.atlasname, recipe.name .. ".tex")
end

local spicedfoods = {}
GenerateSpicedFoods(foods)

local spices = require("spicedfoods")

local spicers = {
    "portablespicer"
}

for k, data in pairs(spices) do
    for name, v in pairs(foods) do
        if data.basename == name then
            spicedfoods[k] = data
        end
    end
end

for i, v in pairs(spicers) do
    for n, b in pairs(spicedfoods) do
        AddCookerRecipe(v, b)
    end
end
-- 五格锅与毕业火炉共用的配方/预告规则。复用现有食物工具入口。
function TUNING.util2hm.InstallCookingRules2hm(cooking, api)
    if cooking.WithCookerRules2hm then return end
    local raw, recipes = {}, {}
    local function Remember(name, data)
        if data and data.tags then raw[data] = deepcopy(data.tags) end
    end
    for name, data in pairs(cooking.ingredients) do Remember(name, data) end
    for _, entry in ipairs({{"cookpot","beefalofeed"},{"cookpot","bunnystew"},{"portablecookpot","gazpacho"}}) do
        local recipe = cooking.recipes[entry[1]] and cooking.recipes[entry[1]][entry[2]]
        if recipe then recipes[recipe] = {test=recipe.test,priority=recipe.priority} end
    end
    function cooking.WithCookerRules2hm(cooker, fn, ...)
        if cooker ~= "dragonflyfurnace" then return fn(...) end
        local tags, rules = {}, {}
        for data, original in pairs(raw) do tags[data]=data.tags;data.tags=original end
        for recipe, original in pairs(recipes) do
            rules[recipe]={test=recipe.test,priority=recipe.priority}
            recipe.test,recipe.priority=original.test,original.priority
        end
        local function Finish(ok, ...)
            for data, previous in pairs(tags) do data.tags=previous end
            for recipe, previous in pairs(rules) do recipe.test,recipe.priority=previous.test,previous.priority end
            if not ok then error((...),0) end
            return ...
        end
        return Finish(pcall(fn,...))
    end
    local calculate = cooking.CalculateRecipe
    cooking.CalculateRecipe = function(cooker,...)
        return cooking.WithCookerRules2hm(cooker,calculate,cooker,...)
    end
    -- 在实际 HUD 上按接口识别，兼容独立版及修改过模块路径的内置版。
    -- 专服只需要上面的配方规则，不加载客户端控件。
    if api.TheNet and api.TheNet:IsDedicated() then return end
    require("complexsmartpot2hm").Install(cooking, api)
    local function PatchPreview(self)
        if not self or self.cookingrules2hm or type(self._UpdateFoodStats) ~= "function" or
            type(self.SortFoods) ~= "function" or type(self.allfoods) ~= "table" then return end
        self.cookingrules2hm = true
        local update, sort = self._UpdateFoodStats,self.SortFoods
        if update then
            self._UpdateFoodStats=function(self,data,count,...)
                local cooker=self._cooker
                local inst=cooker and (cooker.inst or cooker)
                local container=inst and inst.replica and inst.replica.container
                local slots=inst and inst.prefab=="dragonflyfurnace" and 4 or
                    (cooker and cooker.GetNumSlots and cooker:GetNumSlots()) or (container and container:GetNumSlots() or 4)
                -- 经典智能锅将4写死为“已填满”；只转换其状态参数，食材数据仍完整保留。
                local state=count>=slots and 4 or math.min(count,3)
                for _, food in ipairs(self.allfoods) do food.recipe.readytocook=false end
                local result=update(self,data,state,...)
                if count>=slots then
                    -- 使用当前锅具的实际配方，不能沿用智能锅缓存的四格配方优先级。
                    local book=cooking.recipes[self._cookerName] or cooking.recipes.cookpot
                    local best
                    for _, food in ipairs(self.allfoods) do
                        local r=book[food.recipe.name or food.name]
                        if r and r.test(self._cookerName,data.names,data.tags) then
                            best=math.max(best or -math.huge,r.priority or 0)
                        end
                    end
                    for _,food in ipairs(self.allfoods) do
                        local r=book[food.recipe.name or food.name]
                        food.recipe.readytocook=r~=nil and (r.priority or 0)==best and
                            not not r.test(self._cookerName,data.names,data.tags)
                        food.recipe.hide=not food.recipe.readytocook
                    end
                end
                return result
            end
        end
        if sort then
            self.SortFoods=function(self,...)
                local cooker=self._cooker
                local inst=cooker and (cooker.inst or cooker)
                return cooking.WithCookerRules2hm(inst and inst.prefab,sort,self,...)
            end
        end
        local close = self.Close
        if type(close) == "function" then
            self.Close = function(view, inst, ...)
                local owner = view._cooker
                local closing = type(inst) == "table" and (inst.inst or inst) or inst
                if view.cookingpreviewowner2hm and owner and closing and (owner.inst or owner) ~= closing then return end
                return close(view, inst, ...)
            end
        end
        return true
    end
    local function PatchControls(controls)
        if controls then
            PatchPreview(controls.foodcrafting)
            PatchPreview(controls.craftpot)
            if controls.foodcrafting and controls.foodcrafting.cookingrules2hm then return controls.foodcrafting end
            if controls.craftpot and controls.craftpot.cookingrules2hm then return controls.craftpot end
            local preview = controls.craftpot
            local recipes = package.loaded["craftpot/cp_recipes"]
            if preview and recipes and type(recipes.Refresh) == "function" and type(preview.Open) == "function" and
                type(preview.Update) == "function" and type(preview.CloseFor) == "function" and
                type(preview.RefreshSlots) == "function" then return preview, recipes end
        end
    end
    api.AddClassPostConstruct("screens/playerhud", function(hud) PatchControls(hud.controls) end)
    api.AddClassPostConstruct("widgets/containerwidget", function(widget)
        local open, close = widget.Open, widget.Close
        local function Clear(self)
            local state = self.cookingpreview2hm
            if not state then return end
            self.cookingpreview2hm = nil
            if state.layout then state.layout:Detach() end
            if state.preview.cookingpreviewowner2hm == state then state.preview.cookingpreviewowner2hm = nil end
            if state.task then state.task:Cancel() end
            for _, event in ipairs({"itemget", "itemlose", "refresh"}) do
                self.inst:RemoveEventCallback(event, state.queue, state.inst)
            end
            for _, hook in ipairs(state.focus or {}) do
                if hook.slot.OnGainFocus == hook.wrapper then hook.slot.OnGainFocus = hook.original end
            end
            if state.recipes then
                state.preview:CloseFor(self)
                if state.preview.Update == state.update then state.preview.Update = state.originalUpdate end
                return
            end
            local cooker = state.preview._cooker
            if cooker and (cooker.inst or cooker) == state.inst then state.preview:Close(state.inst) end
        end
        widget.Open = function(self, inst, doer, ...)
            Clear(self)
            -- 控件也可能由其他模组在 HUD 构造结束后才创建。
            local preview, recipes = PatchControls(doer and doer.HUD and doer.HUD.controls)
            local result = open(self, inst, doer, ...)
            local container = inst and inst.replica and inst.replica.container
            local rows = inst and inst.fiveslotrows2hm
            local ordinary = container and container:GetNumSlots() == 5 and
                (inst.prefab == "cookpot" or inst.prefab == "portablecookpot" or inst.prefab == "medal_cookpot") and
                preview and preview.knownfoods and
                type(preview.Open) == "function" and type(preview.Close) == "function"
            if self.isopen and container and preview and (ordinary or rows) then
                -- 内置智能锅可能只为四格容器注册 Open/Close；使用其原有预告面板接入五格锅。
                local state = {inst=inst, preview=preview, row=1, recipes=recipes, focus={}}
                local function RowOfSlot(slot)
                    if not rows or type(slot) ~= "number" then return end
                    local row = slot > rows * 5 and slot - rows * 5 or math.floor((slot - 1) / 5) + 1
                    return row >= 1 and row <= rows and row or nil
                end
                local function Items()
                    local items = {}
                    local first = (state.row - 1) * 5
                    for column=1,5 do
                        local slot = column == 5 and rows * 5 + state.row or first + column
                        local item = container:GetItemInSlot(slot)
                        -- 每格是一份原料，堆叠数量只影响批次数；不读取成品格。
                        if item then items[column] = {prefab=item.prefab, components={}} end
                    end
                    return items
                end
                if rows then
                    local first, full
                    for row=1,rows do
                        state.row = row
                        local count = 0
                        for _ in pairs(Items()) do count = count + 1 end
                        if count > 0 and not first then first = row end
                        if count == 5 and not full then full = row end
                    end
                    state.row = full or first or 1
                    state.cooker = {inst=inst, prefab="portablecookpot", GetNumSlots=function() return 5 end, GetItems=Items}
                end
                local function Refresh()
                    state.task = nil
                    if self.cookingpreview2hm ~= state then return end
                    if state.recipes then
                        if preview.container == inst then preview:Update() end
                        if state.layout then state.layout:Update() end
                        return
                    end
                    local cooker = preview._cooker
                    if cooker and (cooker.inst or cooker) == inst then
                        preview:SortFoods()
                        if state.layout then state.layout:Update() end
                    end
                end
                state.queue = function(_, data)
                    local row = data and RowOfSlot(data.slot)
                    if row then state.row = row end
                    if not state.task then state.task = self.inst:DoStaticTaskInTime(0, Refresh) end
                end
                self.cookingpreview2hm = state
                for _, event in ipairs({"itemget", "itemlose", "refresh"}) do
                    self.inst:ListenForEvent(event, state.queue, inst)
                end
                if rows then
                    for index, slot in ipairs(self.inv or {}) do
                        local original = slot.OnGainFocus
                        if type(original) == "function" then
                            local function GainFocus(slot, ...)
                                if self.cookingpreview2hm == state then state.queue(nil, {slot=index}) end
                                return original(slot, ...)
                            end
                            state.focus[#state.focus+1] = {slot=slot, original=original, wrapper=GainFocus}
                            slot.OnGainFocus = GainFocus
                        end
                    end
                end
                if recipes then
                    state.originalUpdate = preview.Update
                    state.update = function(view, ...)
                        if view.container ~= inst then return state.originalUpdate(view, ...) end
                        if not view.isopen then return end
                        view.cooker = "portablecookpot"
                        view.visible = recipes.Refresh("portablecookpot", Items(), 5)
                        view:RefreshSlots()
                    end
                    preview.Update = state.update
                    preview:Open(inst, self)
                else
                    preview.cookingpreviewowner2hm = state
                    preview:Open(state.cooker or container)
                end
                if rows and type(self.GetWorldPosition) == "function" then
                    state.layout = require("cookpreviewlayout2hm").Attach(self, preview)
                end
            end
            return result
        end
        widget.Close = function(self, ...)
            Clear(self)
            return close(self, ...)
        end
    end)
end
