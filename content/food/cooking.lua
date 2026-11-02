local cooking = require("cooking")
local cookingchange = GetModConfigData("cooking_change")

local function OnAddFuel(inst) if inst.SoundEmitter then inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/machine_fuel") end end

local function OnFuelEmpty(inst)
    if inst.SoundEmitter then inst.SoundEmitter:PlaySound("dontstarve/common/together/battery/down") end
    if inst.components.fueled and inst.components.fueled.done and inst.Light then inst.Light:Enable(false) end
end

local function OnFuelSectionChange(new, old, inst) if inst.fueledlevel2hm then inst.fueledlevel2hm:set(new) end end

AddClassPostConstruct("widgets/containerwidget", function(self)
    local oldOpen = self.Open
    self.Open = function(self, container, doer, ...)
        local result = oldOpen(self, container, doer, ...)
        if container and container:HasTag("fueledpot2hm") and container.fueledlevel2hm then
            local level = doer:HasTag("masterchef") and 4 or container.fueledlevel2hm:value()
            for k, v in pairs(self.inv) do
                if k + level > 4 then
                    v:SetBGImage2(resolvefilepath(CRAFTING_ICONS_ATLAS), "filter_fire.tex", {1, 1, 1, 0.25})
                    local w, h = v.bgimage:GetSize()
                    v.bgimage2:SetSize(w, h)
                end
            end
        end
        return result
    end
end)

local oldCOOKfn = ACTIONS.COOK.fn
ACTIONS.COOK.fn = function(act, ...)
    if act.doer and act.doer:HasTag("masterchef") and act.target then act.target.warlycook2hm = true end
    local success, resson = oldCOOKfn(act, ...)
    if act.target and act.target.warlycook2hm then act.target.warlycook2hm = nil end
    if not success and not resson and act.doer and act.doer.components.talker and act.target.components.stewer ~= nil and
        not act.target.components.stewer:CanCook() then act.doer.components.talker:Say(STRINGS.CHARACTERS.WINONA.DESCRIBE.FIRESUPPRESSOR.LOWFUEL) end
    return success, resson
end

local function updatebyfurnace(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 18, {"HASHEATER", "structure", "wildfireprotected"})
    for index, ent in ipairs(ents) do
        if ent and ent.prefab == "dragonflyfurnace" and inst.components.fueled then
            inst.components.fueled:SetPercent(1)
            inst.components.fueled.currentfuel = inst.components.fueled.maxfuel
            inst.components.fueled:StopConsuming()
            break
        end
    end
end
local function needfuel(inst)
    -- if not inst:HasTag("stewer") or inst:HasTag("spicer") then return end
    inst.fueledlevel2hm = net_byte(inst.GUID, "cookpot.hardmodefueled")
    inst.fueledlevel2hm:set(0)
    if not TheWorld.ismastersim then return end
    if inst.components.burnable then inst:RemoveComponent("burnable") end
    if inst.components.fueled then return end
    inst:DoTaskInTime(0, updatebyfurnace)
    inst:AddTag("fueledpot2hm")
    inst:AddComponent("fueled")
    inst.components.fueled.maxfuel = TUNING.CAMPFIRE_FUEL_MAX
    inst.components.fueled.accepting = true
    inst.components.fueled:SetTakeFuelFn(OnAddFuel)
    inst.components.fueled:SetDepletedFn(OnFuelEmpty)
    inst.components.fueled:SetSections(4)
    inst.components.fueled:SetSectionCallback(OnFuelSectionChange)
    inst.components.fueled:InitializeFuelLevel(TUNING.CAMPFIRE_FUEL_MAX * 0.01)
    inst.components.fueled:StopConsuming()
    inst:ListenForEvent("onburnt", function() inst:RemoveComponent("fueled") end)
    local self = inst.components.stewer
    local oldCanCook = self.CanCook
    self.CanCook = function(self, ...)
        if oldCanCook(self, ...) then
            if self.inst.warlycook2hm or self.inst.components.fueled.currentfuel >= self.inst.components.fueled.maxfuel then return true end
            if self.inst.components.fueled:IsEmpty() then return false end
            local ingredient_prefabs = {}
            for k, v in pairs(self.inst.components.container.slots) do table.insert(ingredient_prefabs, v.prefab) end
            local product, cooktime = cooking.CalculateRecipe(self.inst.prefab, ingredient_prefabs)
            return self.inst.components.fueled.currentfuel >= cooktime * 20
        end
        return false
    end
    local oldStartCooking = self.StartCooking
    self.StartCooking = function(self, doer, ...)
        self.inst.components.fueled:StartConsuming()
        updatebyfurnace(self.inst)
        local cooktimemult = self.cooktimemult
        if self.inst.prefab == "cookpot" then self.cooktimemult = self.cooktimemult * (1 - self.inst.components.fueled:GetPercent() / 5) end
        local result = oldStartCooking(self, doer, ...)
        self.cooktimemult = cooktimemult
        return result
    end
    local olddonecookfn = self.ondonecooking
    self.ondonecooking = function(inst, ...)
        local result = olddonecookfn(inst, ...)
        if inst.Light and not inst.components.fueled:IsEmpty() then inst.Light:Enable(true) end
        return result
    end
    local oldHarvest = self.Harvest
    self.Harvest = function(self, ...)
        self.inst.components.fueled:StopConsuming()
        if self.inst.Light then self.inst.Light:Enable(false) end
        return oldHarvest(self, ...)
    end
    local oldOnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        if data.product ~= nil and data.remainingtime ~= nil then self.inst.components.fueled:StartConsuming() end
        oldOnLoad(self, data, ...)
    end
end
AddPrefabPostInit("cookpot", needfuel)
-- if TUNING.NDNR_ACTIVE then AddPrefabPostInit("archive_cookpot", needfuel) end
AddPrefabPostInit("portablecookpot", needfuel)

local function updatestewers(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 18, {"fueledpot2hm"})
    for index, ent in ipairs(ents) do
        if ent and ent.components.fueled then
            ent.components.fueled:SetPercent(1)
            ent.components.fueled.currentfuel = ent.components.fueled.maxfuel
            ent.components.fueled:StopConsuming()
        end
    end
end
local monstermeats = {cookedmonstermeat = "cookedmeat", cookedmonstersmallmeat = "cookedsmallmeat", um_monsteregg_cooked = "bird_egg_cooked"}
local function updatecookitem(inst, chance)
    if inst.components.cooker then
        local CookItem = inst.components.cooker.CookItem
        inst.components.cooker.CookItem = function(self, item, chef, ...)
            if item and item:IsValid() and item.components.cookable and item.components.cookable.product and monstermeats[item.components.cookable.product] and
                math.random() < chance then
                item.oldproduct2hm = item.components.cookable.product
                item.components.cookable.product = monstermeats[item.components.cookable.product]
            end
            local result = CookItem(self, item, chef, ...)
            if item and item:IsValid() and item.components.cookable and item.oldproduct2hm then
                item.components.cookable.product = item.oldproduct2hm
                item.oldproduct2hm = nil
            end
            return result
        end
    end
end
AddPrefabPostInit("dragonflyfurnace", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, updatestewers)
    updatecookitem(inst, 0.15)
    inst.updatecookitem2hm = updatecookitem
end)
AddPrefabPostInit("cotl_tabernacle_level3", function(inst)
    if not TheWorld.ismastersim then return end
    updatecookitem(inst, 0.15)
end)
AddPrefabPostInit("cotl_tabernacle_level2", function(inst)
    if not TheWorld.ismastersim then return end
    updatecookitem(inst, 0.1)
end)

AddPrefabPostInit("cotl_tabernacle_level1", function(inst)
    if not TheWorld.ismastersim then return end
    updatecookitem(inst, 0.05)
end)

AddRecipePostInit("portablecookpot_item", function(inst) table.insert(inst.ingredients, Ingredient("redgem", 1)) end)
AddRecipePostInit("portableblender_item", function(inst) table.insert(inst.ingredients, Ingredient("redgem", 1)) end)
AddRecipePostInit("portablespicer_item", function(inst) table.insert(inst.ingredients, Ingredient("redgem", 1)) end)

if cookingchange == -2 or cookingchange == -3 then -- 2025.7.9 melon:-3也减
    -- 食材拥有食材度除怪物肉度不可食用度外都减少0.25
    local function ProcessFoodTags(tags)
        for tag, tagval in pairs(tags) do
            if tag ~= "precook" and tag ~= "dried" and tag ~= "monster" and tag ~= "inedible" and tagval and type(tagval) == "number" then
                tags[tag] = math.max((tagval or 0) - 0.25, 0)
                if tags[tag] == 0 then tags[tag] = nil end
            end
        end
    end
    for _, tagstable in pairs(cooking.ingredients) do if tagstable.tags and type(tagstable.tags) == "table" then ProcessFoodTags(tagstable.tags) end end
    local oldAddIngredientValues = env.AddIngredientValues
    env.AddIngredientValues = function(names, tags, cancook, candry, ...)
        if tags and type(tags) == "table" then ProcessFoodTags(tags) end
        oldAddIngredientValues(names, tags, cancook, candry, ...)
    end
end

-- 2025.7.9 melon:5格锅、减食物度、加料理所需食物度、食物新鲜度在50%~70%时属性降低为3/4、限制不可食用度
if cookingchange == -3 and not ModManager:GetMod("workshop-3193922031") then
    -- 5格锅-----------------------------------------------------------------------------
    local containers = require("containers")
    -- 烹饪锅
    containers.params.cookpot.widget.slotpos =
    {
        Vector3(0, 64 + 32 + 12 + 250, 0),
        Vector3(0, 32 + 2 + 250, 0),
        Vector3(0, -(32 + 8) + 250, 0),
        Vector3(0, -(64 + 32 + 18) + 250, 0),
        Vector3(0, -(64 + 64 + 32 + 28) + 250, 0),
    }
    containers.params.cookpot.widget.animbank = "ui_alterguardianhat_1x6"
    containers.params.cookpot.widget.animbuild = "ui_alterguardianhat_1x6"
    -- containers.params.cookpot.widget.pos = Vector3(0, 150, 0)
    containers.params.cookpot.widget.buttoninfo.position = Vector3(0, 0, 0)
    -- 便携锅
    containers.params.portablecookpot = containers.params.cookpot
    -- 龙鳞火炉
    -- 食物新鲜度在50%~70%时属性降低为3/4-----------------------------------------------------
    -- [[ 考虑到做菜不如烤了吃的问题，此部分改动可以改成只影响非料理(还没这么改) ]]
    -- 改回原本的  食物改动fooddata_change中改高了，这里改回来
    TUNING.WICKERBOTTOM_SPOILED_FOOD_HUNGER = 0.167 -- 0.167
    TUNING.WICKERBOTTOM_STALE_FOOD_HUNGER = 0.333 -- 0.333
    TUNING.SPOILED_FOOD_HUNGER = .5 -- .5
    TUNING.STALE_FOOD_HUNGER = .667 -- .667
    -- 增加新的一级50%~70% 为蓝色(但不会改颜色) 绿(1)/蓝(3/4)/黄(2/3)/红(1/2)
    TUNING.PERISH_OLD2HM = 0.7 -- 低于0.7变蓝
    TUNING.OLD_FOOD_HUNGER2HM = 0.75 -- 蓝色属性*0.75
    AddComponentPostInit("edible", function(self)
        local _GetHunger = self.GetHunger
        self.GetHunger = function(self, eater) -- 饥饿
            local _hungervalue = _GetHunger(self, eater)
            local multiplier = 1
            local ignore_spoilage = not self.degrades_with_spoilage or self.hungervalue < 0 or (eater ~= nil and eater.components.eater ~= nil and eater.components.eater.ignoresspoilage)
            if not ignore_spoilage and self.inst.components.perishable ~= nil then
                if self.inst.components.perishable:IsFresh() 
                and self.inst.components.perishable:GetPercent() < TUNING.PERISH_OLD2HM then -- 新鲜低于0.7
                    multiplier = eater ~= nil and eater.components.eater ~= nil and eater.components.eater.stale_hunger or TUNING.OLD_FOOD_HUNGER2HM -- * 0.75
                end
            end
            return multiplier * _hungervalue -- * 0.75
        end
    end)
    -- 名字前缀  放久的   英文用 Old 还是 Past its best
    local _GetAdjective = EntityScript.GetAdjective
    EntityScript.GetAdjective = function(self)
        if self.displayadjectivefn == nil and not self:HasTag("critter") 
        and not self:HasTag("small_livestock") and self:HasTag("fresh")
        and self.components and self.components.perishable -- 上面为原来的判断
        and self.components.perishable:GetPercent() < TUNING.PERISH_OLD2HM
        and self.components.perishable:GetPercent() > TUNING.PERISH_FRESH then
            return TUNING.isCh2hm and "放久的" or "Old"
        end
        return _GetAdjective(self)
    end
    -- 限制不可食用度   增加一个惩罚料理  不可食用度>1.5  属性5,5,5   优先级不能太高-------------
    -- 改蒸树枝  条件改为不可食用度>2就出  优先级11
    local recipes = cooking.recipes.cookpot
    recipes.beefalofeed.priority = 11 -- 原本-5
    recipes.beefalofeed.test = function(cooker, names, tags) -- 不可食用>2 或 装饰度 >2 或冰>2  或加起来>3
        return (tags.inedible or 0) + (tags.decoration or 0) + (tags.frozen or 0) > 3 or (tags.inedible or 0) > 2 or (tags.decoration or 0) > 2 or (tags.frozen or 0) > 2
    end
    -- 2025.9.10 melon:芦笋冷汤/炖兔子的冰需求改为1.5   大厨料理要访问portablecookpot
    cooking.recipes.portablecookpot.gazpacho.test = function(cooker, names, tags) return ((names.asparagus and names.asparagus >= 2) or (names.asparagus_cooked and names.asparagus_cooked >= 2) or (names.asparagus and names.asparagus_cooked)) and (tags.frozen and tags.frozen >= 1.5) end
    if TUNING.DSTU then -- 兼容妥协
        recipes.bunnystew.test = function(cooker, names, tags) return (names.rabbit) and (tags.frozen and tags.frozen > 1.5) and (not tags.inedible) and (not tags.foliage) end
    else
        recipes.bunnystew.test = function(cooker, names, tags) return (tags.meat and tags.meat < 1) and (tags.frozen and tags.frozen >= 1.5) and (not tags.inedible) end
    end
    -- 2025.9.10 melon:钓具容器保鲜时间翻倍------------------------
    if GetModConfigData("Tackle Receptacle Use Fish Redeem") then
        AddPrefabPostInit("tacklestation2hm", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.preserver then
                local _GetPerishRateMultiplier = inst.components.preserver.GetPerishRateMultiplier
                inst.components.preserver.GetPerishRateMultiplier = function(self, item, ...)
                    local rate = _GetPerishRateMultiplier(self, item, ...)
                    return rate == 1 and 1 or rate / 2
                end
            end
        end)
    end
end -- 2025.7.9 end
