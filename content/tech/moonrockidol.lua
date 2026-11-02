-- 天体科技削弱
AddRecipePostInit("moonrockidol", function(inst)
    -- table.insert(inst.ingredients, Ingredient("shadowheart", 1))
    table.insert(inst.ingredients, Ingredient("opalpreciousgem", 1))
end)

local monsters = {"crawlingnightmare", "nightmarebeak", "oceanhorror2hm", "ruinsnightmare"}
local function CallTeamMonster(inst, doer)
    local x, y, z = inst.Transform:GetWorldPosition()
    for index, monster in ipairs(monsters) do
        local shadow = SpawnPrefab(monster)
                if monster == "ruinsnightmare" then shadow.spawnbyepic2hm = true end
        shadow.Transform:SetPosition(x, y, z)
    end
end

local function resetfrommoonphase(inst, moonphase, disablesg)
    if moonphase == "new" and not inst.components.persistent2hm.data.hasshadowheart then
        inst.AnimState:SetMultColour(0, 0, 0, 0.5)
        inst:AddTag("shadowdoor2hm")
        inst:RemoveComponent("hauntable")
        inst:RemoveTag("resurrector")
        if not disablesg then inst.sg:GoToState("spawn_pre", true) end
    elseif moonphase ~= "new" and inst:HasTag("shadowdoor2hm") then
        inst.AnimState:SetMultColour(1, 1, 1, 1)
        inst:RemoveTag("shadowdoor2hm")
        if not inst.components.hauntable and GetPortalRez() then
            inst:AddComponent("hauntable")
            inst.components.hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)
            inst:AddTag("resurrector")
        end
        if not disablesg then inst.sg:GoToState("spawn_pre", true) end
    end
end

local function onrepairedmultiplayer(inst, v, doer, item)
    if inst.components.persistent2hm.data.hasshadowheart or not inst:HasTag("shadowdoor2hm") then return false end
    inst.components.persistent2hm.data.hasshadowheart = true
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst:RemoveTag("shadowdoor2hm")
    if not inst.components.hauntable and GetPortalRez() then
        inst:AddComponent("hauntable")
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)
        inst:AddTag("resurrector")
    end
    inst:RemoveComponent("repairable2hm")
    CallTeamMonster(inst, doer)
    inst.sg:GoToState("spawn_pre", true)
    if item and item:IsValid() and item.components.stackable then item.components.stackable:Get(1):Remove() end
    return true
end

local function processpersistentmultiplayer(inst)
    if not inst.components.persistent2hm.data.hasshadowheart then
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.customrepair = onrepairedmultiplayer
        if TheWorld:HasTag("cave") then
            inst.AnimState:SetMultColour(0, 0, 0, 0.5)
            inst:AddTag("shadowdoor2hm")
            inst:RemoveComponent("hauntable")
            inst:RemoveTag("resurrector")
        else
            inst:WatchWorldState("moonphase", resetfrommoonphase)
            resetfrommoonphase(inst, TheWorld.state.moonphase, true)
        end
        if inst.components.moontrader then
            local oldcanaccept = inst.components.moontrader.canaccept
            inst.components.moontrader:SetCanAcceptFn(function(inst, ...)
                if inst:HasTag("shadowdoor2hm") then return false, "NOMOON" end
                return oldcanaccept(inst, ...)
            end)
        end
    end
end

AddPrefabPostInit("multiplayer_portal", function(inst)
    inst.repairtext2hm = "PURIFY"
    inst.repairmaterials2hm = {opalpreciousgem = 0}
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:DoTaskInTime(0, processpersistentmultiplayer)
end)
AddComponentPostInit("constructionplans", function(self)
    local oldStartConstruction = self.StartConstruction
    self.StartConstruction = function(self, target, ...)
        if target and target.prefab == "multiplayer_portal" and
            not (target.components and target.components.persistent2hm and target.components.persistent2hm.data.hasshadowheart) then
            if not target:HasTag("shadowdoor2hm") then
                target.AnimState:SetMultColour(0, 0, 0, 0.5)
                target:AddTag("shadowdoor2hm")
                target:RemoveComponent("hauntable")
                target:RemoveTag("resurrector")
                target.sg:GoToState("spawn_pre", true)
            end
            return nil, "MISMATCH"
        end
        return oldStartConstruction(self, target, ...)
    end
end)

-- 猴岛修理
local function onrepairedmonkeyisland(inst, v, doer, item)
    if inst.components.persistent2hm.data.hasshadowheart then return false end
    inst.components.persistent2hm.data.hasshadowheart = true
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst:RemoveTag("shadowdoor2hm")
    inst:RemoveComponent("repairable2hm")
    CallTeamMonster(inst, doer)
    return true
end

local function processpersistentmonkeyisland(inst)
    if not inst.components.persistent2hm.data.hasshadowheart then
        inst:AddComponent("repairable2hm")
        inst.components.repairable2hm.onrepaired = onrepairedmonkeyisland
        inst.AnimState:SetMultColour(0, 0, 0, 0.5)
        inst:AddTag("shadowdoor2hm")
        if inst.components.trader then
            local oldabletoaccepttest = inst.components.trader.abletoaccepttest
            inst.components.trader:SetAbleToAcceptTest(function(inst, ...)
                if inst:HasTag("shadowdoor2hm") then return false, "BUSY" end
                return oldabletoaccepttest(inst, ...)
            end)
        end
    end
end

AddPrefabPostInit("monkeyisland_portal", function(inst)
    inst.repairtext2hm = "PURIFY"
    inst.repairmaterials2hm = {opalpreciousgem = 0}
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:DoTaskInTime(0, processpersistentmonkeyisland)
end)
STRINGS.ACTIONS.REPAIR2HM.PURIFY = TUNING.isCh2hm and "净化" or "purify"

AddRecipePostInit("bernie_inactive", function(inst) table.insert(inst.ingredients, Ingredient("opalpreciousgem", 1)) end)
AddRecipePostInit("waxwelljournal", function(inst) table.insert(inst.ingredients, Ingredient("opalpreciousgem", 1)) end)
AddPrefabPostInit("waxwelljournal", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.fuel then inst:RemoveComponent("fuel") end
    if inst.components.burnable then inst:RemoveComponent("burnable") end
end)
if GetModConfigData("moonrockidol") ~= -1 then
    local ex_fns = require "prefabs/player_common_extensions"
    local GivePlayerStartingItems = ex_fns.GivePlayerStartingItems
    local function delayGive(inst, items, starting_item_skins, ...)
        if inst.userid and inst.prefab and TheWorld then
            TheWorld.components.persistent2hm.data.startinvusers = TheWorld.components.persistent2hm.data.startinvusers or {}
            TheWorld.components.persistent2hm.data.startinvusers[inst.userid] = TheWorld.components.persistent2hm.data.startinvusers[inst.userid] or {}
            if not TheWorld.components.persistent2hm.data.startinvusers[inst.userid][inst.prefab] then
                TheWorld.components.persistent2hm.data.startinvusers[inst.userid][inst.prefab] = true
                if GetModConfigData("enter gift 2") then
                    require("entergift2hm")(inst)
                end
                GivePlayerStartingItems(inst, items, starting_item_skins, ...)
            end
        end
    end
    ex_fns.GivePlayerStartingItems = function(inst, items, starting_item_skins, ...)
        if inst.starting_inventory == items then
            inst:DoTaskInTime(0, delayGive, items, starting_item_skins, ...)
        else
            GivePlayerStartingItems(inst, items, starting_item_skins, ...)
        end
    end
end
