-- AddPrefabPostInit(
--     "wormwood",
--     function(inst)
--         -- body
--     end
-- )
-- table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WORMWOOD, "farm_plow_item")
-- local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS
-- for veggie, data in pairs(PLANT_DEFS) do
--     if data.seed then
--         AddPrefabPostInit(data.seed, function(inst)
--             local old = inst._custom_candeploy_fn
--             inst._custom_candeploy_fn = function(inst, pt, mouseover, deployer, ...)
--                 return TheWorld.Map:GetTileAtPoint(pt.x, 0, pt.z) == WORLD_TILES.FARMING_SOIL and (old == nil or old(inst, pt, mouseover, deployer, ...))
--             end
--         end)
--     end
-- end
-- local function resetplantkin(inst)
--     if inst.components.deployable.restrictedtag == ""
-- end

-- AddComponentPostInit(
--     "deployable",
--     function(self)
--         if inst:HasTag("deployedfarmplant") then
--             inst:DoTaskInTime(0,resetplantkin)
--         end
--     end
-- )

AddPrefabPostInit("armor_bramble", function(inst)
    if not TheWorld.ismastersim then return end
    local _onblocked = inst._onblocked
    inst._onblocked = function(...)
        if inst.components.armor then
            local percent = inst.components.armor:GetPercent()
            if not inst.percentblocked2hm or math.abs(inst.percentblocked2hm - percent) >= 0.05 then
                inst.percentblocked2hm = percent
                return _onblocked(...)
            end
        end
    end
end)

-- local straightactioncondition2hm = function(inst, doer, actions, right)
--     print("straightactioncondition2hm", inst, doer, inst.replica.action2hm and inst.replica.action2hm.action2hmtag:value())
--     return doer and doer.prefab == "wormwood" and inst.replica.action2hm and inst.replica.action2hm.action2hmtag:value() == "true"
-- end

-- local actionfn = function(inst, doer, target, pos, act)
--     print("actionfn", inst, doer, target, pos, act)
--     if doer and doer.prefab == "wormwood" then
--         if target and target.prefab == "player_tomb2hm" and target.plant and target.plant:IsValid() and target.plant:CanGetFlower() then
--             if doer.components.health and doer.components.health.currenthealth > 25 then
--                 doer.components.health:SetVal(doer.components.health.currenthealth - 25)
--                 target.plant:AddFlower()
--                 return true
--             end
--         end
--     end
-- end

-- AddPrefabPostInit("player_tomb2hm", function(inst)
--     inst.actiontext2hm = "CULTIVATE"
--     inst.actionstate2hm = "form_ghostflower2hm"
--     inst.action2hmdistance = 1
--     inst.straightactioncondition2hm = straightactioncondition2hm
--     inst.onaction2hmtagdirty = function(inst, tag)
--         print("onaction2hmtagdirty2", inst, tag)
--     end
--     if not TheWorld.ismastersim then return end
--     inst:AddComponent("action2hm")
--     inst.components.action2hm.actionfn = actionfn
--     inst.components.action2hm.tag = (inst.plant and inst.plant:CanGetFlower()) and "true" or "false"
-- end)

-- STRINGS.ACTIONS.ACTION2HM.CULTIVATE = TUNING.isCh2hm and "培养" or "cultivate"

-- local interactTomb2hm = Action({})
-- interactTomb2hm.id = "INTERACTTOMB2HM"
-- interactTomb2hm.priority = 10
-- interactTomb2hm.strfn = function(act) return "INTERACTTOMB2HM" end
-- interactTomb2hm.fn = function(act)
--     if act.doer and act.doer.prefab == "wormwood" then
--         if act.target and act.target.prefab == "player_tomb2hm" and act.target.plant and act.target.plant:IsValid() and act.target.plant:CanGetFlower() then
--             if act.doer and act.doer.components.health and act.doer.components.health.currenthealth > 25 then
--                 act.doer.components.health:SetVal(act.doer.components.health.currenthealth - 25)
--                 act.target.plant:AddFlower()
--                 return true
--             end
--         end
--     end
-- end
-- STRINGS.ACTIONS.INTERACTTOMB2HM = TUNING.isCh2hm and "培养" or "cultivate"
-- AddAction(interactTomb2hm)
-- AddComponentAction("SCENE", "action2hm", function(inst, doer, actions, right)
--     if inst.straightactioncondition2hm and inst.straightactioncondition2hm(inst, doer, actions, right) then
--         resetactionconf(inst, doer, actions, right)
--         table.insert(actions, ACTIONS.ACTION2HM)
--     end
-- end)
-- local interactTombActionHandler = ActionHandler(ACTIONS.INTERACTTOMB2HM, function(inst, action)
--     return "form_ghostflower2hm"
-- end)
-- AddStategraphActionHandler("wilson", interactTombActionHandler)
-- AddStategraphActionHandler("wilson_client", interactTombActionHandler)