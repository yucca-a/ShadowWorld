require("stategraphs/commonstates")
AddPrefabPostInit("glommer", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then inst.components.health:SetMaxHealth(TUNING.CHESTER_HEALTH) end
end)
-- 格罗姆会消除附近的昆虫,蜜蜂杀人蜂蝴蝶月娥蚊子球状光虫蚜虫若虫,蝴蝶翅膀,
local foodlist = {
    "bee",
    "butterfly",
    "butterflywings",
    "moonbutterfly",
    "killerbee",
    "mosquito",
    "aphid",
    "nymph",
    "moonstorm_spark",
    "lightflier",
    "wormwood_lightflier",
    "fruitfly",
    "sport_small",
    "spore_tall",
    "spore_medium",
    "leechswarm",
    "stalker_minion",
    "stalker_minion1",
    "stalker_minion2"
}
local SEE_DIST = 15

local FINDFOOD_CANT_TAGS = {"player", "outofreach", "INLIMBO", "NOCLICK", "INLIMBO", "invisible", "hidden", "FX", "noattack", "notarget"}
local function checkfood(item) return item and item:IsValid() and table.contains(foodlist, item.prefab) end
local function FindFoodToEat(inst)
    if inst.sg:HasStateTag("busy") then return end
    if inst.food2hm and inst.food2hm:IsValid() and not inst.food2hm:HasOneOfTags(FINDFOOD_CANT_TAGS) and
        inst.food2hm:IsNear(inst.components.follower and inst.components.follower.leader, SEE_DIST) then
        return BufferedAction(inst, inst.food2hm, ACTIONS.ACTION2HM)
    else
        inst.food2hm = FindEntity(inst.components.follower and inst.components.follower.leader or inst, SEE_DIST, checkfood, nil, FINDFOOD_CANT_TAGS)
        if inst.food2hm then return BufferedAction(inst, inst.food2hm, ACTIONS.ACTION2HM) end
    end
end
local function FindFoodBrain(self)
    local findfoodaction = DoAction(self.inst, FindFoodToEat, "Eat Food", true)
    table.insert(self.bt.root.children, 3, findfoodaction)
end
AddBrainPostInit("glommerbrain", FindFoodBrain)

AddStategraphActionHandler("glommer", ActionHandler(ACTIONS.ACTION2HM, "eat2hm"))

local function StartFlap(inst)
    if inst.FlapTask then return end
    inst.FlapTask = inst:DoPeriodicTask(4 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/flap") end)
end

AddStategraphState("glommer", State {
    name = "eat2hm",
    tags = {"busy", "attack"},
    onenter = function(inst)
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("bored")
        StartFlap(inst)
        inst:ClearBufferedAction()
    end,
    timeline = {
        TimeEvent(4 * FRAMES, function(inst)
            if inst.food2hm and inst.food2hm:IsValid() and inst.food2hm:HasTag("flying") and not inst.food2hm:HasOneOfTags(FINDFOOD_CANT_TAGS) and
                inst.food2hm:IsNear(inst, 2.5) then
                inst.food2hm:Remove()
                inst.food2hm = nil
                if inst.components.health then inst.components.health:SetPercent(1) end
                if inst.components.periodicspawner then inst.components.periodicspawner:LongUpdate(45) end
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/vomit_liquid")
            end
        end),
        TimeEvent(6 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_voice") end),
        TimeEvent(10 * FRAMES, function(inst)
            if inst.food2hm and inst.food2hm:IsValid() and not inst.food2hm:HasTag("flying") and not inst.food2hm:HasOneOfTags(FINDFOOD_CANT_TAGS) and
                inst.food2hm:IsNear(inst, 2.5) then
                inst.food2hm:Remove()
                inst.food2hm = nil
                if inst.components.health then inst.components.health:SetPercent(1) end
                if inst.components.periodicspawner then inst.components.periodicspawner:LongUpdate(45) end
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/vomit_liquid")
            end
        end),
        TimeEvent(11 * FRAMES, LandFlyingCreature),
        TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_ground") end),
        TimeEvent(18 * FRAMES, function(inst)
            RaiseFlyingCreature(inst)
            if not inst.food2hm then inst.sg:GoToState("idle") end
        end),
        TimeEvent(25 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_voice") end),
        TimeEvent(33 * FRAMES, LandFlyingCreature),
        TimeEvent(34 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_ground") end),
        TimeEvent(38 * FRAMES, RaiseFlyingCreature),
        TimeEvent(45 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_voice") end),
        TimeEvent(54 * FRAMES, LandFlyingCreature),
        TimeEvent(55 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/glommer/bounce_ground") end),
        TimeEvent(60 * FRAMES, RaiseFlyingCreature)
    },
    events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)},
    onexit = RaiseFlyingCreature
})
