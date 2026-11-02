require("stategraphs/commonstates")

local DAMAGE_RADIUS_PADDING = .5
local COLLAPSIBLE_TAGS = {"_combat"}
local NON_COLLAPSIBLE_TAGS = {"flying", "shadow", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "INLIMBO", "tree", "leif", "plant"}
local function saplingattack(sapling, inst, pos)
    sapling.AnimState:SetMultColour(1, 1, 1, 1)
    local x, y, z = pos:Get()
    local ents = TheSim:FindEntities(x, 0, z, 0.4 + DAMAGE_RADIUS_PADDING, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)
    for i, v in ipairs(ents) do
        if v:IsValid() then
            if v.components.combat and v.components.health and not v.components.health:IsDead() then
                v.components.combat:GetAttacked_Internal(inst, TUNING.GHOSTLYELIXIR_RETALIATION_DAMAGE)
            end
        end
    end
end
local function SpawnSapling(inst, pos)
    if not pos then return end
    local sapling = SpawnPrefab(inst.sapling2hm)
    if sapling then
        if sapling.StartGrowing then sapling:StartGrowing() end
        sapling.AnimState:SetMultColour(0, 0, 0, 0.3)
        sapling.Transform:SetPosition(pos:Get())
        sapling:DoTaskInTime(0.5, saplingattack, inst, pos)
        sapling.SoundEmitter:PlaySound("dontstarve/wilson/plant_tree")
    end
end
local function CanSpawnSaplingAt(pos)
    if not pos then return end
    if not TheWorld.Map:IsAboveGroundAtPoint(pos.x, 0, pos.z, false) then return false end
    local radius = 0.4
    for i, v in ipairs(TheSim:FindEntities(pos.x, 0, pos.z, radius + 1.5, nil, nil, {"plant", "tree", "leif"})) do
        if v.Physics == nil then return false end
        local spacing = radius + v:GetPhysicsRadius(0)
        if v:GetDistanceSqToPoint(pos) < spacing * spacing then return false end
    end
    return true
end
local function SpawnSaplings(inst, pos, count)
    if not inst.sapling2hm then inst.sapling2hm = inst.prefab == "leif" and "pinecone_sapling" or "lumpy_sapling" end
    local currentcount = count
    if CanSpawnSaplingAt(pos) then
        SpawnSapling(inst, pos)
        currentcount = currentcount - 1
    end
    if currentcount > 0 then
        local dtheta = PI * 2 / currentcount
        for theta = math.random() * dtheta, PI * 2, dtheta do
            local offset = FindWalkableOffset(pos, theta, 2, 3, false, true, CanSpawnSaplingAt, false, false)
            if offset ~= nil then
                SpawnSapling(inst, pos + offset)
                currentcount = currentcount - 1
            end
        end
    end
    if currentcount > count / 2 and inst.saplingattacktask2hm then
        inst.saplingattacktask2hm:Cancel()
        inst.saplingattacktask2hm = nil
    end
end
local function cancelattack(inst)
    inst.saplingattack2hm = nil
    inst.saplingattacktarget2hm = nil
    if inst.saplingattacktask2hm then
        inst.saplingattacktask2hm:Cancel()
        inst.saplingattacktask2hm = nil
    end
end
local function attack4(inst)
    if inst.saplingattack2hm and inst.saplingattackpos2hm then
        SpawnPrefab("collapse_big").Transform:SetPosition(inst.saplingattackpos2hm:Get())
        SpawnPrefab("petrified_tree_fx_old").Transform:SetPosition(inst.saplingattackpos2hm:Get())
        inst.saplingattack2hm = nil
        inst.saplingattackpos2hm = nil
        inst.saplingattacktarget2hm = nil
    end
end
local function attack3(inst)
    if inst.saplingattack2hm and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and
        inst.saplingattacktarget2hm == inst.components.combat.target then
        inst.saplingattackpos2hm = inst.saplingattacktarget2hm:GetPosition()
        SpawnPrefab("petrified_tree_fx_tall").Transform:SetPosition(inst.saplingattackpos2hm:Get())
        SpawnSaplings(inst, inst.saplingattackpos2hm, inst.prefab == "leif" and math.random(4, 7) or math.random(4, 5))
        inst:DoTaskInTime(15 * FRAMES, attack4)
    else
        cancelattack(inst)
    end
end
local function attack2(inst)
    if inst.saplingattack2hm and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and
        inst.saplingattacktarget2hm == inst.components.combat.target then
        SpawnPrefab("petrified_tree_fx_normal").Transform:SetPosition(inst.saplingattacktarget2hm:GetPosition():Get())
        inst:DoTaskInTime(10 * FRAMES, attack3)
    else
        cancelattack(inst)
    end
end
local function attack1(inst)
    if inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and inst.saplingattacktarget2hm ==
        inst.components.combat.target then
        SpawnPrefab("petrified_tree_fx_short").Transform:SetPosition(inst.saplingattacktarget2hm:GetPosition():Get())
        inst:DoTaskInTime(10 * FRAMES, attack2)
    else
        cancelattack(inst)
    end
end
local function doSaplingsattack(inst)
    if inst.saplingattack2hm then return end
    if inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() then
        inst.saplingattack2hm = true
        inst:DoTaskInTime(10 * FRAMES, attack1)
        inst.saplingattacktarget2hm = inst.components.combat.target
    end
end

-- 转换
local needtreebuild = "normal"
local function find_leif_spawn_target(tree)
    return
        tree:HasTag("evergreens") and not tree.noleif and tree.components.growable and tree.components.growable.stage >= 2 and tree.components.growable.stage <=
            3 and tree.build == needtreebuild
end
local function becometree(inst)
    local newtree = SpawnPrefab(inst.prefab == "leif" and "evergreen" or "evergreen_sparse")
    newtree.Transform:SetPosition(inst.Transform:GetWorldPosition())
    newtree.components.growable:SetStage(3)
    if inst.topetrify2hm and newtree.components.petrifiable and newtree.components.petrifiable.onPetrifiedFn then
        newtree.components.petrifiable.onPetrifiedFn(newtree)
    end
    inst:Hide()
    inst.persists = false
    inst:DoTaskInTime(0, inst.Remove)
end
local LEIFTARGET_MUST_TAGS = {"evergreens", "tree"}
local LEIFTARGET_CANT_TAGS = {"leif", "fire", "stump", "burnt", "monster", "FX", "NOCLICK", "DECOR", "INLIMBO"}
local function callteammate(inst)
    local num_spawns = 2
    needtreebuild = inst.prefab == "leif" and "normal" or "sparse"
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.LEIF_IDOL_SPAWN_RADIUS * 2, LEIFTARGET_MUST_TAGS, LEIFTARGET_CANT_TAGS)
    for i, ent in ipairs(ents) do
        if find_leif_spawn_target(ent) then
            if ent.TransformIntoLeif ~= nil then
                ent:TransformIntoLeif(inst.components.combat.target)
                num_spawns = num_spawns - 1
                if num_spawns <= 0 then break end
            end
        end
    end
end
local function spawnreplacedleif(inst, tree)
    local leif = SpawnPrefab(inst.prefab or "leif")
    local data = inst:GetPersistData()
    leif:SetPersistData(data)
    if leif.components.health and inst.components.health then
        leif.components.health:SetPercent(inst.components.health:GetPercent() +
                                              ((tree.components.growable and tree.components.growable.stage == 2) and 0.2 or 0.3))
    end
    leif.Transform:SetPosition(tree.Transform:GetWorldPosition())
    if inst.components.combat and inst.components.combat.target and leif.components.combat then
        leif.components.combat:SetTarget(inst.components.combat.target)
        leif.sg:GoToState("wake")
    else
        leif.sg:GoToState("spawn")
    end
    tree:Remove()
    becometree(inst)
    callteammate(leif)
end
local function findothertree(inst)
    if inst.prefab ~= "leif" and inst.prefab ~= "leif_sparse" then return end
    needtreebuild = inst.prefab == "leif" and "normal" or "sparse"
    return FindEntity(inst, TUNING.LEIF_MAXSPAWNDIST, find_leif_spawn_target, LEIFTARGET_MUST_TAGS, LEIFTARGET_CANT_TAGS)
end
AddStategraphState("leif", State {
    name = "transform2hm",
    tags = {"sleeping", "busy", "noattack","noelectrocute"},
    onenter = function(inst, data)
        inst.components.health:SetInvincible(true)
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("transform_tree", false)
        inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/transform_VO")
        if data and data.tree then inst.sg.statemem.tree2hm = data.tree end
    end,
    events = {
        EventHandler("animover", function(inst)
            if inst.sg.statemem.tree2hm then
                if inst.sg.statemem.tree2hm:IsValid() and not inst.sg.statemem.tree2hm:HasTag("stump") then
                    spawnreplacedleif(inst, inst.sg.statemem.tree2hm)
                else
                    inst.sg.statemem.tree2hm = findothertree(inst)
                    if inst.sg.statemem.tree2hm and inst.sg.statemem.tree2hm:IsValid() then
                        spawnreplacedleif(inst, inst.sg.statemem.tree2hm)
                    else
                        inst.sg:GoToState("wake")
                    end
                end
            else
                becometree(inst)
            end
        end)
    },
    timeline = {
        TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        TimeEvent(25 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end)
    },
    onexit = function(inst) if inst:IsValid() and inst.sg:HasStateTag("noattack") then inst.components.health:SetInvincible(false) end end
})
AddStategraphPostInit("leif", function(sg)
    local oldhitonenter = sg.states.hit.onenter
    sg.states.hit.onenter = function(inst, ...)
        if not inst:HasTag("swc2hm") and inst.components.health and not inst.components.health:IsDead() and inst.components.health:GetPercent() <= 0.3 then
            local tree = findothertree(inst)
            if tree then
                inst.topetrify2hm = true
                inst.sg:GoToState("transform2hm", {tree = tree})
                return
            elseif not FindEntity(inst, TUNING.LEIF_MAXSPAWNDIST * 2, function(v) return v ~= inst end, {"leif"}, {"swc2hm"}) then
                inst.topetrify2hm = true
                inst.sg:GoToState("transform2hm")
                return
            end
        end
        return oldhitonenter(inst, ...)
    end
    local oldattackonenter = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        if not inst:HasTag("swc2hm") and not inst.saplingattack2hm and not inst.saplingattacktask2hm and inst.components.combat and
            inst.components.combat.target and inst.components.combat.target:IsValid() then
            local x, _, z = inst.components.combat.target.Transform:GetWorldPosition()
            if TheWorld.Map:IsAboveGroundAtPoint(x, 0, z, false) then
                inst.saplingattacktask2hm = inst:DoTaskInTime(23, function() inst.saplingattacktask2hm = nil end)
                doSaplingsattack(inst)
            end
        end
        return oldattackonenter(inst, ...)
    end
end)

-- 树精统一阵亡了
local function removeleif(inst, data)
    if not POPULATING and inst:IsValid() and not inst:HasTag("swc2hm") and inst ~= (data and data.leif) and inst.sg and
        (data == nil or inst.prefab == (data and data.leif and data.leif.prefab)) and inst.components.health and not inst.components.health:IsDead() then
        inst.persists = false
        if inst.components.lootdropper then
            inst.components.lootdropper:SetLoot()
            inst.components.lootdropper:SetChanceLootTable()
            inst.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            inst.components.lootdropper.GenerateLoot = emptytablefn
            inst.components.lootdropper.DropLoot = emptytablefn
        end
        if inst:IsAsleep() then
            becometree(inst)
        else
            inst.sg:GoToState("transform2hm")
        end
    end
end
local function onleifdeath(inst) TheWorld:PushEvent("leifdeath2hm", {leif = inst}) end
local function initleif(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("death", onleifdeath)
    inst.onotherleifdeath2hm = function(world, data) removeleif(inst, data) end
    inst:ListenForEvent("leifdeath2hm", inst.onotherleifdeath2hm, TheWorld)
    inst:ListenForEvent("bosshide", inst.onotherleifdeath2hm)
end
AddPrefabPostInit("leif", initleif)
AddPrefabPostInit("leif_sparse", initleif)

TUNING.MUSHGNOME_HEALTH = TUNING.MUSHGNOME_HEALTH * 1.5
TUNING.MUSHSPORE_MAX_DENSITY = TUNING.MUSHSPORE_MAX_DENSITY * 2
AddStategraphPostInit("moonspore", function(sg)
    local oldfn = sg.states.pop.events.animover.fn
    sg.states.pop.events.animover.fn = function(inst, ...)
        if inst._alwaysinstantpops then
            oldfn(inst, ...)
            return
        end
        if not inst.max2hm then inst.max2hm = math.random(0, 4) end
        if (inst.index2hm or 0) < inst.max2hm then
            inst.index2hm = (inst.index2hm or 0) + 1
            inst.Light:Enable(true)
            inst.DynamicShadow:Enable(true)
            inst.sg:GoToState("pop")
        else
            oldfn(inst, ...)
        end
    end
end)

-- TUNING.DECIDUOUS_CHOPS_MONSTER = TUNING.DECIDUOUS_CHOPS_MONSTER * 2
-- 桦树精转换
AddComponentPostInit("deciduoustreeupdater", function(self)
    if self.inst.components.workable then
        self.inst.components.workable:SetShouldRecoilFn(function(inst, worker, tool, ...)
            if worker ~= nil and worker:HasTag("epic") then return false, 1 end
            local nottough = not inst.components.workable.tough and not inst:HasTag("stump")
            local nottoughworker = not (worker ~= nil and worker:HasTag("toughworker")) and
                                       not (tool ~= nil and tool.components.tool ~= nil and tool.components.tool:CanDoToughWork())
            if nottough ~= nottoughworker then return true, 0 end
            inst.components.workable.tough = not inst.components.workable.tough
            return false, 1
        end)
    end
end)
