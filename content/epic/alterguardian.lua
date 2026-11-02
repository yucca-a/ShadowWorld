local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
local alterguardianmode = GetModConfigData("alterguardian")
local old_alterguardian = GetModConfigData("old_alterguardian") -- 旧版本天体英雄
local banicetiles = GetModConfigData("banicetiles")
local NEWCONSTANT2HM = ModManager:GetMod("workshop-3191348907") or ModManager:GetMod("workshop-3645180511")-- 2025.10.24 melon:判断新界是否开启
if alterguardianmode == true then alterguardianmode = -3 end

if speedup < 2 then
    TUNING.ALTERGUARDIAN_PHASE1_WALK_SPEED = TUNING.ALTERGUARDIAN_PHASE1_WALK_SPEED * 2 / speedup
    TUNING.ALTERGUARDIAN_PHASE2_WALK_SPEED = TUNING.ALTERGUARDIAN_PHASE2_WALK_SPEED * 2 / speedup
    TUNING.ALTERGUARDIAN_PHASE3_WALK_SPEED = TUNING.ALTERGUARDIAN_PHASE3_WALK_SPEED * 2 / speedup
end
if attackspeedup < 2 then
    TUNING.ALTERGUARDIAN_PHASE1_ATTACK_PERIOD = TUNING.ALTERGUARDIAN_PHASE1_ATTACK_PERIOD / 2 * attackspeedup
    TUNING.ALTERGUARDIAN_PHASE2_ATTACK_PERIOD = TUNING.ALTERGUARDIAN_PHASE2_ATTACK_PERIOD / 2 * attackspeedup
    TUNING.ALTERGUARDIAN_PHASE3_ATTACK_PERIOD = TUNING.ALTERGUARDIAN_PHASE3_ATTACK_PERIOD / 2 * attackspeedup
end
if alterguardianmode ~= -4 then
    TUNING.ALTERGUARDIAN_PHASE1_HEALTH = TUNING.ALTERGUARDIAN_PHASE1_HEALTH * 2
    TUNING.ALTERGUARDIAN_PHASE1_ROLLCOOLDOWN = TUNING.ALTERGUARDIAN_PHASE1_ROLLCOOLDOWN / 2
    TUNING.ALTERGUARDIAN_PHASE1_SUMMONCOOLDOWN = TUNING.ALTERGUARDIAN_PHASE1_SUMMONCOOLDOWN / 2

    TUNING.ALTERGUARDIAN_PHASE2_MAXHEALTH = TUNING.ALTERGUARDIAN_PHASE2_MAXHEALTH * 2
    TUNING.ALTERGUARDIAN_PHASE2_STARTHEALTH = TUNING.ALTERGUARDIAN_PHASE2_STARTHEALTH * 2
    TUNING.ALTERGUARDIAN_PHASE2_SPINCD = TUNING.ALTERGUARDIAN_PHASE2_SPINCD / 2
    TUNING.ALTERGUARDIAN_PHASE2_SPIKECOOLDOWN = TUNING.ALTERGUARDIAN_PHASE2_SPIKECOOLDOWN / 2
    TUNING.ALTERGUARDIAN_PHASE2_SUMMONCOOLDOWN = TUNING.ALTERGUARDIAN_PHASE2_SUMMONCOOLDOWN / 2

    TUNING.ALTERGUARDIAN_PHASE3_MAXHEALTH = TUNING.ALTERGUARDIAN_PHASE3_MAXHEALTH * 2
    TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH = TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH * 2
    TUNING.ALTERGUARDIAN_PHASE3_TRAP_CD = TUNING.ALTERGUARDIAN_PHASE3_TRAP_CD / 2
    -- TUNING.ALTERGUARDIAN_PHASE3_SUMMONCOOLDOWN = TUNING.ALTERGUARDIAN_PHASE3_SUMMONCOOLDOWN / 2
end
TUNING.ALTERGUARDIAN_PHASE1_MINROLLCOUNT = TUNING.ALTERGUARDIAN_PHASE1_MINROLLCOUNT * 2
TUNING.ALTERGUARDIAN_PHASE2_SPIN_SPEED = TUNING.ALTERGUARDIAN_PHASE2_SPIN_SPEED * 2
TUNING.ALTERGUARDIAN_PHASE2_SPIKE_LIFETIME = TUNING.ALTERGUARDIAN_PHASE2_SPIKE_LIFETIME * 2
TUNING.ALTERGUARDIAN_PHASE3_TRAP_LT = TUNING.ALTERGUARDIAN_PHASE3_TRAP_LT * 2
TUNING.ALTERGUARDIAN_PHASE3_TRAP_WORKS = TUNING.ALTERGUARDIAN_PHASE3_TRAP_WORKS * 2
TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE = TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE * 2
TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ = TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ + 225
TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST = TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST * 2

-- 可选启用
if alterguardianmode >= -1 then return end

-- 暂时禁用天体的暗影世界影子(仅启用时停版本的天体:掉天体洋葱的难度;其他难度档走原版,暗影世界通用影子照常)
if alterguardianmode == -5 then
    for _, shadowprefab in ipairs({ "alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3" }) do
        AddPrefabPostInit(shadowprefab, function(inst) inst.disablesw2hm = true end)
    end
end
require "physics"
require "behaviours/follow"

-- 可疑的石头需要高级敲矿
AddPrefabPostInit("rock_moon_shell", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.workable then inst.components.workable:SetRequiresToughWork(true) end
end)

-- 天体添加月亮科技和地图图标
local function addminimapicon(inst)
    if not inst.MiniMapEntity and not inst.icon2hm then
        local icon = SpawnPrefab("shadowchessicon2hm")
        if icon then
            icon:TrackEntity(inst)
            inst.icon2hm = icon
        end
    end
end
local function addprototyper(inst)
    if not inst.components.prototyper then
        inst:AddComponent("prototyper")
        inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.MOONORB_UPGRADED
    end
end
PROTOTYPER_DEFS.alterguardian_phase1 = PROTOTYPER_DEFS.moon_altar
PROTOTYPER_DEFS.alterguardian_phase2 = PROTOTYPER_DEFS.moon_altar
PROTOTYPER_DEFS.alterguardian_phase3 = PROTOTYPER_DEFS.moon_altar
PROTOTYPER_DEFS.alterguardian_phase3deadorb = PROTOTYPER_DEFS.moon_altar
PROTOTYPER_DEFS.alterguardian_phase3dead = PROTOTYPER_DEFS.moon_altar

-- 天体各阶段携带月亮风暴作战
local canusemoonstorm = GetModConfigData("moonisland")
local function processmoonstormnode(inst)
    if inst:HasTag("swc2hm") or not canusemoonstorm then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    -- 优先用 areaaware.current_area:它与 FindVisualNodeAtPoint 返回的 node_index 同源(areaaware 内部调的就是同一接口),
    -- 但自带“移动4格以上才更新”的缓存。避免天体每次攻击回待机都做几十次tile查询,
    -- 以及移动中节点抖动导致月亮风暴节点被反复新增(SpawnPrefab+全量网络同步+全玩家事件)
    local areaaware = inst.components.areaaware
    local node_index = areaaware ~= nil and areaaware.current_area or nil
    if node_index == nil or node_index <= 0 then node_index = select(2, TheWorld.Map:FindVisualNodeAtPoint(x, 0, z)) end
    if TheWorld.net.components.moonstorms2hm then TheWorld.net.components.moonstorms2hm:AddNewMoonstormNode(node_index, x, y, z) end
end

-- 天体各阶段锁定季节,必须月亮风暴生效时才能锁定
-- alterguardianseason2hm代表锁定的季节,0为不锁定,1夏天2春天3冬天4秋天
-- 测试代码生效月亮风暴 TheWorld:PushEvent("ms_stormchanged",{stormtype=STORM_TYPES.MOONSTORM, setting=true})
TUNING.alterguardianseason2hm = 0
local function SetWorldSeason(season)
    TheWorld:PushEvent("ms_setseason", season)
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_setseason_update"), nil, season)
end
local phaseseasons = {"summer", "spring", "winter", "autumn"}
local SW
for i,mod in ipairs(ModManager.mods) do
    local modinfo = KnownModIndex:GetModInfo(mod.modname)
    if modinfo.ia_shipwrecked then
        SW = true
        break
    end
end
-- 岛屿冒险兼容
if SW then phaseseasons = {"dry", "green", "wet", "mild"} end
local phaseprecipitations = {false, true, true}
local phasemoonstormlevels = {0.7, 0.8, 0.9}
local function trylockseason(inst)
    if not inst.alterguardianseason2hm or inst:HasTag("swc2hm") or (inst.alterguardianseason2hm < 4 and not TheWorld.state.isalterawake) or
        TUNING.alterguardianseason2hm > inst.alterguardianseason2hm or (inst.components.health and inst.components.health:IsDead()) or
        (inst.components.workable and inst.components.workable.workleft <= 0) then return end
    if TUNING.alterguardianseason2hm < inst.alterguardianseason2hm then TheWorld:PushEvent("delayrefreshseason2hm") end
    TUNING.alterguardianseason2hm = inst.alterguardianseason2hm
    local season = phaseseasons[TUNING.alterguardianseason2hm]
    if season and TheWorld.state.season ~= season then SetWorldSeason(season) end
    local precipitation = phaseprecipitations[TUNING.alterguardianseason2hm]
    if precipitation ~= nil and ((precipitation and TheWorld.state.precipitation == "none") or (not precipitation and TheWorld.state.precipitation ~= "none")) then
        TheWorld:PushEvent("ms_forceprecipitation", precipitation)
    end
    TUNING.moonstorm2hmlevel = phasemoonstormlevels[TUNING.alterguardianseason2hm]
    if TUNING.alterguardianseason2hm > 0 and TUNING.alterguardianseason2hm < 4 then processmoonstormnode(inst) end
end
local function addseasonlock(inst, idx, try)
    local canenbale = inst.alterguardianseason2hm == nil
    inst.alterguardianseason2hm = idx
    TUNING.alterguardianseason2hm = math.max(inst.alterguardianseason2hm, TUNING.alterguardianseason2hm)
    if canenbale then inst:WatchWorldState("cycles", trylockseason) end
    trylockseason(inst)
end

-----------------------------------------------------------------------------------------------------

-- 第一阶段地震流星,世界变成夏季-----------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
AddPrefabPostInit("alterguardian_phase1", function(inst)
    inst:AddTag("alterguardian2hm")
    inst:AddTag("toughworker")
    if not TheWorld.ismastersim then return end
    if inst.components.burnable then inst:RemoveComponent("burnable") end
    addminimapicon(inst)
    addprototyper(inst)
    addseasonlock(inst, 1)
    if not inst.components.meteorshower then inst:AddComponent("meteorshower") end
    -- if not TUNING.noalterguardianhat2hm and inst.components.lootdropper then inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00) end
    -- inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.75, "alterguardian2hm_phase1")
    -- inst.components.health:SetMaxDamageTakenPerHit(100)
end)
-- 天体仇灵兼容
AddPrefabPostInit("alterguardian_phase1_lunarrift", function(inst)
    inst:AddTag("toughworker")
    if not TheWorld.ismastersim then return end
    if inst.components.burnable then inst:RemoveComponent("burnable") end
    if not inst.components.meteorshower then inst:AddComponent("meteorshower") end
    -- if not TUNING.noalterguardianhat2hm and inst.components.lootdropper then inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00) end
    -- inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.75, "alterguardian2hm_phase1")
    -- inst.components.health:SetMaxDamageTakenPerHit(100)
end)
-- 风滚草攻击
local function makefiretumbleweeds(inst)
    if (inst:HasTag("swc2hm") and not inst.forcealterguardian2hm) or TheWorld.state.season ~= "summer" then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, 30, true)
    local rangesq = math.huge
    for i, v in ipairs(players) do
        local distsq = v:GetDistanceSqToPoint(x, y, z)
        if distsq < rangesq and inst.components.combat:CanTarget(v) and v.userid then
            local newtumbleweed = SpawnPrefab("mod_hardmode_tumbleweed")
            if not newtumbleweed then return end
            local px, py, pz = v.Transform:GetWorldPosition()
            newtumbleweed.Transform:SetPosition(px - math.cos(newtumbleweed.angle) * 36, py, pz + math.sin(newtumbleweed.angle) * 36)
        end
    end
end
-- 环绕地震攻击
local function sinkholedelaychange(inst)
    -- 陷坑非持久且使用自定义的消失方式来消失，从而节约性能
    local eyeofterror_sinkhole = SpawnPrefab("eyeofterror_sinkhole")
    eyeofterror_sinkhole.Transform:SetPosition(inst.Transform:GetWorldPosition())
    eyeofterror_sinkhole:PushEvent("docollapse")
    eyeofterror_sinkhole.components.timer:SetTimeLeft("repair", 360)
    inst:Remove()
end
local SINKHOLD_BLOCKER_TAGS = {"antlion_sinkhole_blocker"}
local IsValidSinkholePosition_x, IsValidSinkholePosition_z
local function IsValidSinkholePosition(offset)
    local x1, z1 = IsValidSinkholePosition_x + offset.x, IsValidSinkholePosition_z + offset.z
    if #TheSim:FindEntities(x1, 0, z1, TUNING.ANTLION_SINKHOLE.RADIUS / 2 * 1.9, SINKHOLD_BLOCKER_TAGS) > 0 then return false end
    for dx = -1, 1 do
        for dz = -1, 1 do
            if not TheWorld.Map:IsPassableAtPoint(x1 + dx * TUNING.ANTLION_SINKHOLE.RADIUS / 2, 0, z1 + dz * TUNING.ANTLION_SINKHOLE.RADIUS / 2, false, true) then
                return false
            end
        end
    end
    return true
end
local function SpawnSinkhole(spawnpt)
    local x = GetRandomWithVariance(spawnpt.x, TUNING.ANTLION_SINKHOLE.RADIUS / 2)
    local z = GetRandomWithVariance(spawnpt.z, TUNING.ANTLION_SINKHOLE.RADIUS / 2)
    IsValidSinkholePosition_x = x
    IsValidSinkholePosition_z = z
    local offset = FindValidPositionByFan(math.random() * 2 * PI, TUNING.ANTLION_SINKHOLE.RADIUS / 2 * 1.8 + math.random(), 9, IsValidSinkholePosition) or
                       FindValidPositionByFan(math.random() * 2 * PI, TUNING.ANTLION_SINKHOLE.RADIUS / 2 * 2.9 + math.random(), 17, IsValidSinkholePosition) or
                       FindValidPositionByFan(math.random() * 2 * PI, TUNING.ANTLION_SINKHOLE.RADIUS / 2 * 3.9 + math.random(), 17, IsValidSinkholePosition) or
                       nil
    if offset ~= nil then
        local antlion_sinkhole = SpawnPrefab("antlion_sinkhole")
        antlion_sinkhole.persists = false
        antlion_sinkhole.Transform:SetPosition(x + offset.x, 0, z + offset.z)
        antlion_sinkhole:PushEvent("startcollapse")
        antlion_sinkhole:DoTaskInTime(3 + math.random(), sinkholedelaychange)
    end
end
local function dosinkholesattack(inst)
    if inst.components.combat.target then
        local pt = inst.components.combat.target:GetPosition()
        SpawnSinkhole(pt)
    end
end
local function doCircularsinkholesattack(inst, segments, radius, angle)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.components.dockmanager ~= nil then TheWorld.components.dockmanager:DamageDockAtPoint(x, y, z, 1000) end
    local segmentangle = (segments > 0 and 360 / segments or 360)
    local start = angle or math.random(0, 360)
    for midangle = -start, 360 - start, segmentangle do
        local offset = Vector3(radius * math.cos(midangle), 0, -radius * math.sin(midangle))
        SpawnSinkhole(Vector3(x + offset.x, 0, z + offset.z))
    end
    dosinkholesattack(inst)
end
-- 流星攻击
local function doshadowmeteorattack(inst)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, 30, true)
    local rangesq = math.huge
    for i, v in ipairs(players) do
        local distsq = v:GetDistanceSqToPoint(x, y, z)
        if distsq < rangesq and inst.components.combat:CanTarget(v) then
            local meteor = SpawnPrefab("shadowmeteor")
            meteor.Transform:SetPosition(v.Transform:GetWorldPosition())
            meteor:SetSize("large", 1)
            meteor:SetPeripheral(false)
        end
    end
end
-- AddStategraphState("alterguardian_phase1",GiveJumpState())
AddStategraphPostInit("alterguardian_phase1", function(sg)
    local OnEnteridle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        OnEnteridle(inst, ...)
        trylockseason(inst)
    end
    -- 滚动开始和结束时产生火焰风滚草
    if sg.states.roll_start then
        local OnEnterroll_start = sg.states.roll_start.onenter
        sg.states.roll_start.onenter = function(inst, ...)
            makefiretumbleweeds(inst)
            OnEnterroll_start(inst, ...)
        end
    end
    -- 滚动更远更持久,海上时必定滚向最近的存活玩家
    local OnEnterroll = sg.states.roll.onenter
    sg.states.roll.onenter = function(inst, ...)
        if inst.components.combat and inst.components.combat.target then
            local tx, ty, tz = inst.components.combat.target.Transform:GetWorldPosition()
            inst.Transform:SetRotation(inst:GetAngleToPoint(tx, ty, tz))
        elseif inst:IsOnOcean() then
            local target = FindClosestPlayerToInst(inst, 10000, true)
            if target and target:IsValid() then
                local tx, ty, tz = target.Transform:GetWorldPosition()
                inst.Transform:SetRotation(inst:GetAngleToPoint(tx, ty, tz))
            end
        end
        OnEnterroll(inst, ...)
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        local current_speed, y, z = inst.Physics:GetMotorVel()
        inst.Physics:SetMotorVelOverride(current_speed * 1.5, y, z)
        if inst.sg.mem._num_rolls > 4 and math.random() < 0.35 and inst.sg.mem._num_rolls then inst.sg.mem._num_rolls = inst.sg.mem._num_rolls + 1 end
    end
    -- 首次攻击到玩家也不会停下
    local rolltimout = sg.states.roll.ontimeout
    sg.states.roll.ontimeout = function(inst, ...)
        if (not inst:HasTag("swc2hm") or inst.forcealterguardian2hm) and inst.sg.statemem.hitplayer and inst.sg.mem._num_rolls > 0 then
            inst.sg.statemem.hitplayer = nil
            inst.sg.mem._num_rolls = math.min(inst.sg.mem._num_rolls - 2, 4)
        end
        rolltimout(inst, ...)
    end
    local OnEnterroll_stop = sg.states.roll_stop.onenter
    sg.states.roll_stop.onenter = function(inst, ...)
        makefiretumbleweeds(inst)
        OnEnterroll_stop(inst, ...)
    end
    -- 砸地，产生环形AOE地震
    -- local OnEntertantrum_pre = sg.states.tantrum_pre.onenter
    -- sg.states.tantrum_pre.onenter = function(inst, ...) OnEntertantrum_pre(inst, ...) end
    local OnEntertantrum = sg.states.tantrum.onenter
    sg.states.tantrum.onenter = function(inst, ...)
        if inst.sg.mem.aoes_remaining == nil or inst.sg.mem.aoes_remaining == 0 then inst.aoessinkhole2hm = false end
        OnEntertantrum(inst, ...)
        if (inst:HasTag("swc2hm") or inst.prefab == "alterguardian_phase1_lunarrift") and not inst.forcealterguardian2hm then return end
        if inst.aoessinkhole2hm == false and inst.sg.mem.aoes_remaining then inst.aoessinkhole2hm = inst.sg.mem.aoes_remaining + 1 end
        -- if inst.aoessinkhole2hm and inst.sg.mem.aoes_remaining and (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining) % 2 == 1 then
        --     inst:DoTaskInTime(7 * FRAMES, doCircularsinkholesattack, 4 + (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining),
        --                       (4 + (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining)) * TUNING.ANTLION_SINKHOLE.RADIUS)
        -- end
    end
    AddStateTimeEvent2hm(sg.states.tantrum, 7 * FRAMES, function(inst)
        if (inst:HasTag("swc2hm") or inst.prefab == "alterguardian_phase1_lunarrift") and not inst.forcealterguardian2hm then return end
        if inst.aoessinkhole2hm and inst.sg.mem.aoes_remaining and (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining) % 2 == 1 then
            doCircularsinkholesattack(inst, 4 + (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining),
                                      (4 + (inst.aoessinkhole2hm - inst.sg.mem.aoes_remaining)) * TUNING.ANTLION_SINKHOLE.RADIUS)
        end
    end)
    -- local OnEntertantrum_pst = sg.states.tantrum_pst.onenter
    -- sg.states.tantrum_pst.onenter = function(inst, ...)
    --     OnEntertantrum_pst(inst, ...)
    -- end
    -- 护盾,流星雨
    local OnEntershield_pre = sg.states.shield_pre.onenter
    sg.states.shield_pre.onenter = function(inst, ...)
        OnEntershield_pre(inst, ...)
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        inst.components.meteorshower:StopShower()
        inst.components.meteorshower:StartShower()
    end
    -- 进行一次定点流星砸击
    local OnEntershield_end = sg.states.shield_end.onenter
    sg.states.shield_end.onenter = function(inst, ...)
        OnEntershield_end(inst, ...)
        doshadowmeteorattack(inst)
    end
end)

-----------------------------------------------------------------------------------------------------

-- 第二阶段风雨雷电,世界变成春季-----------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------

-- 碰撞障碍攻击
local function ClearRecentlyCharged(inst, other) inst.recentlycharged[other] = nil end
local function OnDestroyOther(inst, other)
    if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() and other.components.workable.action ~= ACTIONS.NET and
        not inst.recentlycharged[other] then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)
        if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
            inst.recentlycharged[other] = true
            inst:DoTaskInTime(3, ClearRecentlyCharged, other)
        end
    end
end
local function OnPhase2Collide(inst, other)
    if other and other:IsValid() and other.prefab == "riceplant" and TUNING.DSTU and other.components.pickable and not inst.recentlycharged[other] then
        other.components.lootdropper:SpawnLootPrefab("rice")
        other.components.pickable:Pick()
        if other:IsValid() then
            inst.recentlycharged[other] = true
            inst:DoTaskInTime(3, ClearRecentlyCharged, other)
        end
        return
    end
    if other ~= nil and other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() and other.components.workable.action ~=
        ACTIONS.NET and not inst.recentlycharged[other] then inst:DoTaskInTime(2 * FRAMES, OnDestroyOther, other) end
end
local function onphase2spawnothershadow(inst, child)
    child.forcealterguardian2hm = true
    child:AddTag("electricdamageimmune")
end
local function phase2addphase1shadow(inst)
    if inst:HasTag("swp2hm") and inst.components.childspawner2hm then
        inst.components.childspawner2hm:SetQueuedChildren({"alterguardian_phase1"}, true)
        inst.components.childspawner2hm:SetMaxChildren(inst.components.childspawner2hm.maxchildren + 1)
        inst.components.childspawner2hm:SetQueueSpawnedFn(onphase2spawnothershadow)
    end
end
local SPIKE_DSQ = TUNING.ALTERGUARDIAN_PHASE2_SPIKE_RANGE * TUNING.ALTERGUARDIAN_PHASE2_SPIKE_RANGE
local spawn_spike_with_target
local phase2spiketrailtmptarget
AddPrefabPostInit("alterguardian_phase2", function(inst)
    inst:AddTag("alterguardian2hm")
    inst:AddTag("toughworker")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("tornado_nosucky")
    if not TheWorld.ismastersim then return end
    addminimapicon(inst)
    addprototyper(inst)
    addseasonlock(inst, 2)
    -- if not TUNING.noalterguardianhat2hm and inst.components.lootdropper then inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00) end
    -- inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.75, "alterguardian2hm_phase1")
    -- inst.components.health:SetMaxDamageTakenPerHit(150)
    if inst.GUID and not PhysicsCollisionCallbacks[inst.GUID] then
        inst.recentlycharged = {}
        inst.Physics:SetCollisionCallback(OnPhase2Collide)
    end
    if alterguardianmode >= -3 and TUNING.shadowworld2hm then inst.swp2hmfn = phase2addphase1shadow end
    if inst.DoSpikeAttack then
        if not spawn_spike_with_target then spawn_spike_with_target = getupvalue2hm(inst.DoSpikeAttack, "spawn_spike_with_target") end
        if spawn_spike_with_target then
            local DoSpikeAttack = inst.DoSpikeAttack
            inst.DoSpikeAttack = function(inst, ...)
                if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return DoSpikeAttack(inst, ...) end
                local targets = {}
                local ipos = inst:GetPosition()
                for _, p in ipairs(AllPlayers) do
                    if not p:HasTag("playerghost") and p.entity:IsVisible() and (p.components.health ~= nil and not p.components.health:IsDead()) and
                        p:GetDistanceSqToPoint(ipos:Get()) < SPIKE_DSQ then table.insert(targets, p) end
                end
                if IsTableEmpty(targets) then return DoSpikeAttack(inst, ...) end
                local DoTaskInTime = inst.DoTaskInTime
                inst.DoTaskInTime = function(inst, time, fn, ...)
                    if fn == spawn_spike_with_target and not IsTableEmpty(targets) then
                        local length = #targets
                        local target = table.remove(targets, length)
                        if target and target:IsValid() then
                            return DoTaskInTime(inst, time, function(...)
                                phase2spiketrailtmptarget = target
                                fn(...)
                                phase2spiketrailtmptarget = nil
                            end, ...)
                        end
                    end
                    return DoTaskInTime(inst, time, fn, ...)
                end
                DoSpikeAttack(inst, ...)
                inst.DoTaskInTime = DoTaskInTime
                inst.DoTaskInTime2hm = nil
            end
        end
    end
end)
-- 旋风攻击
local function gettornadospawnlocation(inst, target)
    local x1, y1, z1 = inst.Transform:GetWorldPosition()
    local x2, y2, z2 = target.Transform:GetWorldPosition()
    return x1 + .15 * (x2 - x1), 0, z1 + .15 * (z2 - z1)
end
local function dotornadoattack(inst)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    if inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() then
        local v = inst.components.combat.target
        local x, y, z = inst.Transform:GetWorldPosition()
        local distsq = v:GetDistanceSqToPoint(x, y, z)
        if distsq < 45 * 45 and inst.components.combat:CanTarget(v) then
            local tornado = SpawnPrefab("tornado")
            tornado.WINDSTAFF_CASTER = inst.swp2hm or inst
            tornado.Transform:SetPosition(gettornadospawnlocation(inst, v))
            tornado.components.knownlocations:RememberLocation("target", v:GetPosition())
        end
    end
end
-- 玻璃刺围困攻击
local spikerotlist = {65, 90, 180}
local spiketimes = {0.75, 0.33, 0.33}
local function dospikesattack(inst)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    local target = inst.components.combat.target
    if not target or not target:IsValid() or not target:IsNear(inst, 6) then return end
    if inst.components.timer then
        if inst.components.timer:TimerExists("spike_cd") then
            inst.components.timer:SetTimeLeft("spike_cd", TUNING.ALTERGUARDIAN_PHASE2_SPIKECOOLDOWN)
        else
            inst.components.timer:StartTimer("spike_cd", TUNING.ALTERGUARDIAN_PHASE2_SPIKECOOLDOWN)
        end
    end
    inst.spikeattacktype2hm = math.random() < 0.7 and 1 or math.random(2, 3)
    -- inst.spikeattacktype2hm 1 半包围 2 双竖线 3 双横线
    local rotoffset = spikerotlist[inst.spikeattacktype2hm] or 65
    local time = spiketimes[inst.spikeattacktype2hm] or 0.33
    local angle = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
    local postarget = inst.spikeattacktype2hm ~= 1 and target or inst
    if not postarget then return end
    local x, y, z = postarget.Transform:GetWorldPosition()
    if TheWorld.components.dockmanager ~= nil then TheWorld.components.dockmanager:DamageDockAtPoint(x, y, z, 1000) end
    if inst.spikeattacktype2hm ~= 2 then
        local spike0 = SpawnPrefab("alterguardian_phase2spiketrail")
        spike0.Transform:SetPosition(x, 0, z)
        spike0.Transform:SetRotation(angle)
        spike0:SetOwner(inst)
        if spike0._emerge_task and spike0._emerge_task.fn then
            local emerge = spike0._emerge_task.fn
            spike0._emerge_task:Cancel()
            spike0._emerge_task = spike0:DoTaskInTime(inst.spikeattacktype2hm == 1 and 1 or time, emerge)
        end
    end
    local spike1 = SpawnPrefab("alterguardian_phase2spiketrail")
    spike1.Transform:SetPosition(x, 0, z)
    spike1.Transform:SetRotation(angle - rotoffset)
    spike1:SetOwner(inst)
    if spike1._emerge_task and spike1._emerge_task.fn then
        local emerge = spike1._emerge_task.fn
        spike1._emerge_task:Cancel()
        spike1._emerge_task = spike1:DoTaskInTime(time, emerge)
    end
    if inst.spikeattacktype2hm ~= 3 then
        local spike2 = SpawnPrefab("alterguardian_phase2spiketrail")
        spike2.Transform:SetPosition(x, 0, z)
        spike2.Transform:SetRotation(angle + rotoffset)
        spike2:SetOwner(inst)
        if spike2._emerge_task and spike2._emerge_task.fn then
            local emerge = spike2._emerge_task.fn
            spike2._emerge_task:Cancel()
            spike2._emerge_task = spike2:DoTaskInTime(time, emerge)
        end
    end
end
-- 月亮风暴闪电攻击
local function spawnmoonstormlighting(inst, x, y, z)
    local spark = SpawnPrefab("moonstorm_lightning")
    spark.Transform:SetPosition(x, 0, z)
end
local function dolightingattack(inst)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    local target = inst.components.combat.target
    if not (target and target:IsValid()) then return end
    local dist = math.clamp(inst:GetDistanceSqToInst(target), 1, 12)
    if dist > 900 then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    for i = 1, 10, 1 do
        local radius = 1 + i * 5
        if not (target and target:IsValid()) then return end
        local angle = inst:GetAngleToPoint(target.Transform:GetWorldPosition()) * DEGREES
        local offset = Vector3(radius * math.cos(angle), 0, radius * -math.sin(angle))
        inst:DoTaskInTime(5 * FRAMES * i, spawnmoonstormlighting, x + offset.x, y, z + offset.z)
    end
end
local _lightningexcludetags = {"playerghost", "INLIMBO", "lightningblocker"}
local function moonstormsendlighting(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 3, nil, _lightningexcludetags)
    for _, v in pairs(ents) do
        if v and v:IsValid() and v.prefab ~= "alterguardian_phase2" then
            v:PushEvent("lightningstrike")
            if v.components.playerlightningtarget then v.components.playerlightningtarget:DoStrike() end
        end
    end
end
local phase2islighting
AddPrefabPostInit("moonstorm_lightning", function(inst)
    if not TheWorld.ismastersim then return end
    if phase2islighting then inst:DoTaskInTime(0, moonstormsendlighting) end
end)
AddPrefabPostInit("moonstorm_glass", function(inst)
    if not TheWorld.ismastersim then return end
    if phase2islighting then
        if inst.components.lootdropper then inst.components.lootdropper:SetChanceLootTable() end
        if inst.components.timer and inst.components.timer:TimerExists("defusetime") then inst.components.timer:SetTimeLeft("defusetime", 1.5) end
    end
end)
-- 尖刺围墙会优先命中玩家
AddPrefabPostInit("alterguardian_phase2spiketrail", function(inst)
    if not TheWorld.ismastersim then return end
    local emerge
    if inst._emerge_task and inst._emerge_task.fn then
        emerge = inst._emerge_task.fn
        if phase2islighting then
            inst._emerge_task:Cancel()
            inst._emerge_task = inst:DoTaskInTime(2, emerge)
        end
    end
    if emerge and phase2spiketrailtmptarget and phase2spiketrailtmptarget:IsValid() then
        inst.target2hm = phase2spiketrailtmptarget
        if inst._watertest_task and inst._watertest_task.fn then
            local fn = inst._watertest_task.fn
            inst._watertest_task.fn = function(inst, ...)
                if not inst.startpos2hm then inst.startpos2hm = inst:GetPosition() end
                if inst.target2hm and inst.target2hm:IsValid() and
                    math.abs(
                        inst.target2hm:GetDistanceSqToPoint(inst.startpos2hm.x, 0, inst.startpos2hm.z) -
                            inst:GetDistanceSqToPoint(inst.startpos2hm.x, 0, inst.startpos2hm.z)) <= 2 then
                    emerge(inst)
                    if inst._watertest_task ~= nil then
                        inst._watertest_task:Cancel()
                        inst._watertest_task = nil
                    end
                    return
                end
                fn(inst, ...)
            end
        end
    end
end)
-- 妥协旋风攻击
local Advance_Full
local function umtornadoAdvance_Full(inst)
    if inst.Advance_Task ~= nil then inst.Advance_Task:Cancel() end
    inst.Advance_Task = nil
    inst.startmoving = true
    inst.AnimState:PlayAnimation("tornado_loop", true)
end
local function umtornadoInit(inst)
    inst.SoundEmitter:PlaySound("UCSounds/um_tornado/um_tornado_loop", "spinLoop")
    if not inst.is_full then
        inst.AnimState:PlayAnimation("tornado_pre")
        inst.Advance_Task = inst:ListenForEvent("animover", umtornadoAdvance_Full)
        inst.is_full = true
    else
        umtornadoAdvance_Full(inst)
    end
end
AddStategraphPostInit("alterguardian_phase2", function(sg)
    -- 海上优先使用旋转攻击
    local doattackfn = sg.events.doattack.fn
    sg.events.doattack.fn = function(inst, data, ...)
        if (not inst:IsOnValidGround() or not data.target:IsOnValidGround()) and not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) and data.target ~= nil and data.target:IsValid() then
            local dsq_to_target = inst:GetDistanceSqToInst(data.target)
            local attack_state = (not inst.components.timer:TimerExists("spin_cd") and dsq_to_target < TUNING.ALTERGUARDIAN_PHASE2_SPIN_RANGE *
                                     TUNING.ALTERGUARDIAN_PHASE2_SPIN_RANGE * 2 and "spin_pre") or
                                     (not inst.components.timer:TimerExists("summon_cd") and "atk_summon") or
                                     (dsq_to_target < TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE * TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE and "atk_chop") or nil
            if attack_state ~= nil then
                inst.sg:GoToState(attack_state, data.target)
                return
            end
        end
        return doattackfn(inst, data, ...)
    end
    local OnEnteridle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        inst.spinattackindex2hm = 0 -- 旋转计次
        OnEnteridle(inst, ...)
        trylockseason(inst) -- 季节锁定
    end
    -- 连环闪电攻击
    local OnEnteratk_spike = sg.states.atk_spike.onenter
    sg.states.atk_spike.onenter = function(inst, ...)
        -- if not inst:HasTag("swc2hm") or inst.forcealterguardian2hm then
        --     phase2islighting = true
        --     inst:DoTaskInTime(32 * FRAMES, dolightingattack)
        -- end
        OnEnteratk_spike(inst, ...)
        local x, y, z = inst.Transform:GetWorldPosition()
        if TheWorld.components.dockmanager ~= nil then TheWorld.components.dockmanager:DamageDockAtPoint(x, y, z, 1000) end
    end
    AddStateTimeEvent2hm(sg.states.atk_spike, 32 * FRAMES, function(inst)
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        phase2islighting = true
        dolightingattack(inst)
    end)
    local OnEnteratk_spike_pst = sg.states.atk_spike_pst.onenter
    sg.states.atk_spike_pst.onenter = function(inst, ...) OnEnteratk_spike_pst(inst, ...) end
    -- 连续旋转攻击，旋转后刷新某些技能的CD，旋转速度固定为22.5
    local OnEnterspin_pre = sg.states.spin_pre.onenter
    sg.states.spin_pre.onenter = function(inst, ...)
        OnEnterspin_pre(inst, ...)
        if not inst.umstormready2hm and TUNING.DSTU and TUNING.DSTU.STORMS and TheWorld.components.um_stormspawner and TheWorld.state.isspring and
            not NEWCONSTANT2HM and -- 2025.8.31 melon:加新界时不生成龙卷风
            not inst:HasTag("swc2hm") and (inst.umstorm2hm == nil or not inst.umstorm2hm:IsValid() or not inst:IsNear(inst.umstorm2hm, 100)) and math.random() <
            0.075 then
            inst.umstormready2hm = true
            if inst.components.rooted == nil then inst:AddComponent("rooted") end
            inst.components.rooted:AddSource(inst)
            inst.umstorm2hm = nil
        end
    end
    local OnEnterspin_loop = sg.states.spin_loop.onenter
    sg.states.spin_loop.onenter = function(inst, data, ...)
        if data and data.speed <= 30 then data.speed = math.max(data.speed, 15) * (2 - inst.components.health:GetPercent()) end
        -- if inst.umstormready2hm then data.speed = 0 end
        OnEnterspin_loop(inst, data, ...)
    end
    -- 旋转结束后生成玻璃刺围墙
    local OnEnterspin_pst = sg.states.spin_pst.onenter
    sg.states.spin_pst.onenter = function(inst, ...)
        if not inst:HasTag("swc2hm") or inst.forcealterguardian2hm then phase2islighting = nil end
        OnEnterspin_pst(inst, ...)
        -- 旋转结束后概率继续旋转，且必定释放一次三联旋转
        if inst.umstormready2hm and (inst.umstorm2hm == nil or not inst.umstorm2hm:IsValid() or not inst:IsNear(inst.umstorm2hm, 100)) then
            -- 召唤妥协旋风？
            local tornado = TheSim:FindFirstEntityWithTag("um_tornado")
            local force
            if tornado == nil then
                TheWorld:PushEvent("forcetornado")
                tornado = TheSim:FindFirstEntityWithTag("um_tornado")
                force = true
            end
            if tornado ~= nil and tornado:IsValid() and tornado.persists and (force or FindClosestPlayerToInst(tornado, 36, false) == nil) then
                tornado.Transform:SetPosition(inst.Transform:GetWorldPosition())
                if tornado.startmoving and tornado.is_full then
                    tornado.is_full = false
                    umtornadoInit(tornado)
                end
                inst.umstorm2hm = tornado
            end
        else
            inst.spinattackindex2hm = (inst.spinattackindex2hm or 0) + 1
            if inst.spinattackthree2hm and inst.spinattackdouble2hm and math.random() < 0.033 then
                inst.spinattackdouble2hm = nil
                inst.spinattackthree2hm = nil
                if inst.components.timer and inst.components.timer:TimerExists("spin_cd") then inst.components.timer:StopTimer("spin_cd") end
            elseif not inst.spinattackthree2hm and inst.spinattackdouble2hm and inst.spinattackindex2hm < 3 then
                inst.spinattackthree2hm = true
                if inst.components.timer and inst.components.timer:TimerExists("spin_cd") then inst.components.timer:StopTimer("spin_cd") end
            elseif not inst.spinattackdouble2hm and math.random() > inst.components.health:GetPercent() and inst.spinattackindex2hm < 3 then
                inst.spinattackdouble2hm = true
                if inst.components.timer and inst.components.timer:TimerExists("spin_cd") then inst.components.timer:StopTimer("spin_cd") end
            elseif inst.components.timer then
                if inst.components.timer:TimerExists("spin_cd") and math.random() < 0.25 then
                    inst.components.timer:StopTimer("spin_cd")
                elseif inst.components.timer:TimerExists("summon_cd") then
                    inst.components.timer:StopTimer("summon_cd")
                end
            end
        end
    end
    AddStateTimeEvent2hm(sg.states.spin_pst, 11 * FRAMES, function(inst)
        if inst.umstormready2hm then
            inst.umstormready2hm = nil
            if inst.components.rooted then inst.components.rooted:RemoveSource(inst) end
        end
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        dospikesattack(inst)
    end)
    -- 召唤月影,旋风攻击
    local OnEnteratk_summon = sg.states.atk_summon.onenter
    sg.states.atk_summon.onenter = function(inst, ...)
        -- inst:DoTaskInTime(22 * FRAMES, dotornadoattack)
        OnEnteratk_summon(inst, ...)
        if inst.sg.mem.num_summons <= 0 and inst.components.timer and inst.components.timer:TimerExists("spike_cd") then
            inst.components.timer:StopTimer("spike_cd")
        end
    end
    AddStateTimeEvent2hm(sg.states.atk_summon, 22 * FRAMES, function(inst) dotornadoattack(inst) end)
end)

-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- 第三阶段冰雪激光,世界变成冬季-----------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------

-- 影子始终进攻模式
if old_alterguardian then
    AddBrainPostInit("alterguardian_phase3brain", function(self)
        table.insert(self.bt.root.children, 2, Follow(self.inst, function()
            local target = self.inst.components.combat.target or
                            (self.inst.swp2hm and self.inst.swp2hm:IsValid() and self.inst.swp2hm.components.combat and self.inst.swp2hm.components.combat.target)
            if target and target:IsValid() and
                (self.inst:HasTag("swc2hm") or (self.inst.components.health and self.inst.components.health:GetPercent() >= 0.35 and not TheWorld.state.isday) or
                    target:IsNear(self.inst, TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST)) then return target end
        end, math.max(6, TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE - 6), math.max(TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE - 2, 12),
                                                    math.max(14, TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE)))
    end)
else
    AddBrainPostInit("alterguardian_phase3brain", function(self)
        table.insert(self.bt.root.children, 2, Follow(self.inst, function()
            if self.inst:HasTag("swc2hm") then
                local target = self.inst.components.combat.target or
                                (self.inst.swp2hm and self.inst.swp2hm:IsValid() and self.inst.swp2hm.components.combat and
                                    self.inst.swp2hm.components.combat.target)
                if target and target:IsValid() and target:IsNear(self.inst, TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST) then return target end
            end
        end, math.max(6, TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE - 6), math.max(TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE - 2, 12),
                                                    math.max(14, TUNING.ALTERGUARDIAN_PHASE3_ATTACK_RANGE)))
    end)
end
-- local function phase3processswc(inst) if inst:HasTag("swc2hm") and inst.components.knownlocations then inst.components.knownlocations.GetLocation = nilfn end end
-- 保护罩防御
local function cancelforcefieldcdtask(inst) inst.forcefieldcdtask2hm = nil end
AddPrefabPostInit("abigailforcefieldbuffed", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.debuff then
        local onattachedfn = inst.components.debuff.onattachedfn
        inst.components.debuff:SetAttachedFn(function(inst, target, ...)
            if onattachedfn then onattachedfn(inst, target, ...) end
            if inst.components.debuff.target and inst.components.debuff.target.prefab == "alterguardian_phase3" then
                inst.AnimState:SetScale(2, 2, 2)
                inst.AnimState:SetMultColour(1, 1, 1, 0.1)
            end
        end)
    end
end)
local function phase3ondeath(inst)
    addseasonlock(inst, 4, true)
    if TheWorld.state.precipitation ~= "none" then TheWorld:PushEvent("ms_forceprecipitation", false) end
    for _, v in ipairs(AllPlayers) do if v and v:HasTag("gestalt_possessable") then v:RemoveTag("gestalt_possessable") end end
end
local function onphase3spawnothershadow(inst, child)
    child.forcealterguardian2hm = true
    if child.components.freezable then child:RemoveComponent("freezable") end
end
-- 斥力场，击退敌人
local function cancelmoonpulsefxcd2hmtask(inst) inst.moonpulsefxcd2hmtask = nil end
local function cancelmoonpulsefx2hmtask(inst)
    inst.moonpulsefxcd2hmtask = inst:DoTaskInTime(2.5, cancelmoonpulsefxcd2hmtask)
    inst.moonpulsefx2hmtask = nil
end
local function phase3Vac2hm(inst)
    if not inst.moonpulsefxcd2hmtask then
        for index, player in ipairs(AllPlayers) do
            if not IsEntityDeadOrGhost(player) and not (player.sg and player.sg:HasStateTag("knockout")) and inst:GetDistanceSqToInst(player) <= 25 and
                Vector3(player.Physics:GetVelocity()):LengthSq() > (alterguardianmode == -5 and 100 or 63) then -- 弹飞阈值:仅时停版本天体用100(10格/秒),其他档用原版63
                if not inst.moonpulsefx2hmtask then
                    inst.moonpulsefx2hmtask = inst:DoTaskInTime(1.5, cancelmoonpulsefx2hmtask)
                    SpawnPrefab("moonpulse_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                player:PushEvent("knockback", {knocker = inst, radius = 5, forcelanded = false, propsmashed = true})
            end
        end
    end
end
local function phase3GetAttacked_Internal(inst, data)
    -- 攻击自己的敌人会被施加被虚影攻击的标记
    if data and data.target and not data.target:HasTag("gestalt_possessable") then data.target:AddTag("gestalt_possessable") end
    -- 远程攻击免疫防护罩
    if data and data.weapon and (data.weapon.components.projectile or (data.weapon.components.weapon and data.weapon.components.weapon.projectile)) and
        not inst.forcefieldcdtask2hm and not inst:HasDebuff("forcefield") and inst.components.combat and
        (not inst.components.combat.target or not inst:IsNear(inst.components.combat.target, 19.5)) then
        inst.forcefieldcdtask2hm = inst:DoTaskInTime(3, cancelforcefieldcdtask)
        inst:AddDebuff("forcefield", "abigailforcefieldbuffed")
    end
    -- -- 回血计数，需要足够多地攻击频率打断
    -- local currtime = GetTime()
    -- if not inst.dlidxcd2hm or currtime - inst.dlidxcd2hm >= TUNING.WILSON_ATTACK_PERIOD then
    --     inst.dlidxcd2hm = currtime
    --     inst.daylightidx2hm = math.max((inst.daylightidx2hm or 0) - 1, -10)
    -- end
end
-- 月灵不再攻击玩家鬼魂
AddPrefabPostInit("gestalt_guard", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat then
        local oldtargetfn = inst.components.combat.targetfn
        inst.components.combat.targetfn = function(inst)
            local target1, target2 = oldtargetfn(inst)
            if target1 and target1:HasTag("player") and (target1:HasTag("playerghost") or target1.components.health and target1.components.health:IsDead())  then
                target1 = nil
            end
            return target1, target2
        end
    end
end)
local function phase3onentitysleep(inst)
    if inst.vactask2hm then
        inst.vactask2hm:Cancel()
        inst.vactask2hm = nil
    end
end
local function phase3onentitywake(inst) if not old_alterguardian and not inst.vactask2hm and not inst:HasTag("swc2hm") then inst.vactask2hm = inst:DoPeriodicTask(FRAMES, phase3Vac2hm) end end
local function swp2hmfn(inst)
    if not old_alterguardian and alterguardianmode >= -3 and inst.components.childspawner2hm then
        inst.components.childspawner2hm:SetQueuedChildren({"alterguardian_phase2", "alterguardian_phase1"}, true)
        inst.components.childspawner2hm:SetMaxChildren(inst.components.childspawner2hm.maxchildren + 2)
        inst.components.childspawner2hm:SetQueueSpawnedFn(onphase3spawnothershadow)
    end
    inst:ListenForEvent("entitysleep", phase3onentitysleep)
    inst:ListenForEvent("entitywake", phase3onentitywake)
    if not inst:IsAsleep() and not old_alterguardian then phase3onentitywake(inst) end
    if inst.components.combat and inst.components.combat.targetfn and inst.components.knownlocations then
        local targetfn = inst.components.combat.targetfn
        inst.components.combat:SetRetargetFunction(inst.components.combat.retargetperiod or 3, function(inst, ...)
            local GetLocation = inst.components.knownlocations.GetLocation
            inst.components.knownlocations.GetLocation = nilfn
            local target, f = targetfn(inst, ...)
            inst.components.knownlocations.GetLocation = GetLocation
            return target, f
        end)
    end
end
local function phase3KeepTarget(inst, target)
    if inst.components.combat:CanTarget(target) then
        if not old_alterguardian and inst:HasTag("swc2hm") then return true end
        local x, y, z = inst.Transform:GetWorldPosition()
        if target:GetDistanceSqToPoint(x, y, z) < TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ then
            local newtarget = FindClosestPlayerInRange(x, y, z, 12, true)
            if newtarget == nil or newtarget == target then return true end
        end
    end
end
-- 冰岛地皮破坏时不生成冰块冰船也不删除特殊单位
local disableboaticetileremove
local function FastDestroyIceTiles(inst)
    if inst.destroyicetilestask2hm then
        inst.destroyicetilestask2hm:Cancel()
        inst.destroyicetilestask2hm = nil
    end
    local data = inst.components.persistent2hm.data.icetiles or {}
    disableboaticetileremove = true
    for i, pos in ipairs(data) do
        if pos and pos.x and pos.y then TheWorld.components.oceanicemanager:DamageIceAtTile(pos.x, pos.y, TUNING.OCEAN_ICE_HEALTH) end
    end
    disableboaticetileremove = nil
    inst.components.persistent2hm.data.icetiles = nil
end
local function DestroyIceTiles(inst, radius)
    if inst.destroyicetilestask2hm then
        inst.destroyicetilestask2hm:Cancel()
        inst.destroyicetilestask2hm = nil
    end
    local data = inst.components.persistent2hm.data.icetiles or {}
    if not IsTableEmpty(data) then
        radius = radius or 45
        local radiussq = radius * radius
        disableboaticetileremove = true
        for i, pos in ipairs(data) do
            if pos and pos.x and pos.y and inst:GetDistanceSqToPoint(TheWorld.Map:GetTileCenterPoint(pos.x, pos.y)) >= radiussq then
                TheWorld.components.oceanicemanager:DamageIceAtTile(pos.x, pos.y, TUNING.OCEAN_ICE_HEALTH)
            end
        end
        disableboaticetileremove = nil
        inst.destroyicetilestask2hm = inst:DoTaskInTime(1, DestroyIceTiles, radius - 5)
    end
end
local function delayremoveiceboat(inst)
    inst.components.boatphysics = nil
    inst.components.walkableplatform = nil
    inst:Remove()
end
AddComponentPostInit("oceanicemanager", function(self)
    local QueueDestroyForIceAtPoint = self.QueueDestroyForIceAtPoint
    local destroy_ice_at_point = getupvalue2hm(self.QueueDestroyForIceAtPoint, "destroy_ice_at_point")
    if destroy_ice_at_point ~= nil then
        self.QueueDestroyForIceAtPoint = function(self, x, y, z, data, ...)
            local DoTaskInTime = TheWorld.DoTaskInTime
            if disableboaticetileremove then
                data = data or {}
                data.silent = true
                TheWorld.DoTaskInTime = function(inst, time, fn, ...)
                    if fn == destroy_ice_at_point then
                        return DoTaskInTime(inst, time, function(world, dx, dz, oceanicemanager, ...)
                            local _DestroyEntity = GLOBAL.DestroyEntity
                            GLOBAL.DestroyEntity = nilfn
                            local _SpawnPrefab = GLOBAL.SpawnPrefab
                            GLOBAL.SpawnPrefab = function(prefab, ...)
                                if prefab == "boat_ice" then
                                    local entity = _SpawnPrefab("ice")
                                    entity.components.boatphysics = {ApplyRowForce = nilfn}
                                    entity.components.walkableplatform = {platform_radius = 0}
                                    entity:DoTaskInTime(0, delayremoveiceboat)
                                    return entity
                                elseif prefab == "ice" or prefab == "degrade_fx_ice" then
                                    local entity = _SpawnPrefab(prefab)
                                    entity:DoTaskInTime(0, entity.Remove)
                                    return entity
                                end
                                return _SpawnPrefab(prefab, ...)
                            end
                            oceanicemanager:DestroyIceAtPoint(dx, 0, dz)
                            GLOBAL.SpawnPrefab = _SpawnPrefab
                            GLOBAL.DestroyEntity = _DestroyEntity
                        end, ...)
                    end
                    return DoTaskInTime(inst, time, fn, ...)
                end
            end
            QueueDestroyForIceAtPoint(self, x, y, z, data, ...)
            TheWorld.DoTaskInTime = DoTaskInTime
        end
    end
end)
local function clearicetilescd2hmtask(inst) inst.icetilescd2hmtask = nil end

-- 旧靴子免疫滑倒
if not GetModConfigData("sharkboi") then
    local function bootlegcancel(inst)
        local oldowner = inst.oldowner2hm
        inst.oldowner2hm = nil
        if oldowner and oldowner:IsValid() and oldowner.bootlegs2hm then
            for i = #oldowner.bootlegs2hm, 1, -1 do
                local bootleg = oldowner.bootlegs2hm[i]
                if bootleg == inst then
                    table.remove(oldowner.bootlegs2hm, i)
                    break
                end
            end
            if IsTableEmpty(oldowner.bootlegs2hm) and not oldowner:HasTag("playerghost") and not oldowner.components.slipperyfeet then
                oldowner:AddComponent("slipperyfeet")
                oldowner.bootlegs2hm = nil
            end
        end
    end
    local function bootlegupdate(inst)
        local owner = inst.components.inventoryitem:GetGrandOwner()
        if owner == inst.oldowner2hm then return end
        bootlegcancel(inst)
        if owner and owner:IsValid() and owner:HasTag("player") and owner.components.slipperyfeet then
            inst.oldowner2hm = owner
            inst.oldowner2hm:RemoveComponent("slipperyfeet")
            owner.bootlegs2hm = owner.bootlegs2hm or {}
            table.insert(owner.bootlegs2hm, inst)
        end
    end
    local function delaybootlegupdate(inst) inst:DoTaskInTime(0, bootlegupdate) end

    AddPrefabPostInit("bootleg", function(inst)
        if inst:HasTag("cantslipperyfeet2hm") then return end
        inst.displaynamefn = function(inst)
            local name = STRINGS.NAMES[string.upper(inst.prefab)]
            return (inst:HasTag("cantslipperyfeet2hm") and (TUNING.isCh2hm and "防滑- " or "No slip- ") or "") .. name
        end
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onputininventory", delaybootlegupdate)
        inst:ListenForEvent("ondropped", delaybootlegupdate)
        inst:ListenForEvent("onremove", bootlegcancel)
    end)
end

-- 时停同步给客户端:客户端要自己禁用操作,否则它继续预测移动会被服务端每帧拉回(表现就是闪出去又瞬移回来)
local function SetTimestopSpeed2hm(inst, stop)
    local locomotor = inst.components.locomotor
    if locomotor == nil then return end
    if stop then
        locomotor:SetExternalSpeedMultiplier(inst, "alterguardian_timestop2hm", 0)
    else
        locomotor:RemoveExternalSpeedMultiplier(inst, "alterguardian_timestop2hm")
    end
end
local function RefreshTimestopNet2hm(player)
    if player == nil or not player:IsValid() or player._timestopnet2hm == nil then return end
    local stop = (player._alterguardian_timestop2hm or player._alterguardian_cursetimestop2hm) and true or false
    player._timestopnet2hm:set(stop)
    SetTimestopSpeed2hm(player, stop) -- 服务端也要定身,否则它继续走、客户端只是把坐标同步过来(表现就是滑行)
end
local function OntimestopNetDirty2hm(inst)
    if inst ~= ThePlayer or inst.components.playercontroller == nil then return end
    local stop = inst._timestopnet2hm:value()
    inst.components.playercontroller:Enable(not stop)
    SetTimestopSpeed2hm(inst, stop)
    if stop then
        if inst.components.locomotor then inst.components.locomotor:Stop() end
        if inst.Physics then inst.Physics:Stop() end
        -- 兜底:服务端万一没清标记,12秒后自行解除,避免操作被永久禁用
        if inst._timestopnetguard2hm then inst._timestopnetguard2hm:Cancel() end
        inst._timestopnetguard2hm = inst:DoTaskInTime(12, function(pl)
            pl._timestopnetguard2hm = nil
            SetTimestopSpeed2hm(pl, false)
            if pl._timestopnet2hm and pl._timestopnet2hm:value() and pl.components.playercontroller then
                pl.components.playercontroller:Enable(true)
            end
        end)
    elseif inst._timestopnetguard2hm then
        inst._timestopnetguard2hm:Cancel()
        inst._timestopnetguard2hm = nil
    end
end
AddPlayerPostInit(function(inst)
    inst._timestopnet2hm = net_bool(inst.GUID, "alterguardian.timestop2hm", "timestopnetdirty2hm")
    inst:ListenForEvent("timestopnetdirty2hm", OntimestopNetDirty2hm)
end)

-- 三阶段攻击累计触时停
local CURSE_DURATION2HM = 10
local CURSE_STACK2HM = 10
local CURSE_DECAY2HM = 1
local CURSE_THRESHOLD2HM = 120
local CURSE_TIMESTOP2HM = 10      -- 时停时长
local function CurseTimestopPlayer2hm(inst, player)
    if not player or not player:IsValid() or player:HasTag("playerghost") then return end
    if player._alterguardian_cursetimestop2hm then return end
    player._alterguardian_cursetimestop2hm = true
    RefreshTimestopNet2hm(player)
    if player._alterguardian_cursetask2hm then player._alterguardian_cursetask2hm:Cancel(); player._alterguardian_cursetask2hm = nil end
    player:RemoveTag("alterguardian_curse2hm")
    -- 玩家脚下旺达钟表标记（就是借用下旺达的那个贴图）
    local marker = SpawnPrefab("pocketwatch_recall_marker")
    if marker then
        local mx, my, mz = player.Transform:GetWorldPosition()
        marker.Transform:SetPosition(mx, 0, mz)
        marker.Transform:SetScale(2, 2, 2)
        player._alterguardian_cursetimestop_marker = marker
        marker:DoTaskInTime(CURSE_TIMESTOP2HM + 1, function(m)
            if m and m:IsValid() then m:Remove() end
        end)
    end
    if player._alterguardian_timestop_holdtask then player._alterguardian_timestop_holdtask:Cancel(); player._alterguardian_timestop_holdtask = nil end
    player._alterguardian_timestop_anchor = nil
    player._alterguardian_timestop_vel = nil
    player._alterguardian_timestop2hm = nil
    player:RemoveTag("_alterguardian_timestop")
    if player.AnimState then player.AnimState:Pause() end
    if player.Physics then
        player._alterguardian_cursetimestop_vel = { player.Physics:GetVelocity() }
        player.Physics:Stop()
    end
    if player.components.locomotor then player.components.locomotor:Stop() end
    player:AddTag("_alterguardian_cursetimestop")
    local anchor = player:GetPosition()
    player._alterguardian_cursetimestop_anchor = anchor
    player._alterguardian_cursetimestop_holdtask = player:DoPeriodicTask(0, function(pl)
        if not pl:IsValid() or not pl._alterguardian_cursetimestop2hm then return end
        if pl.Physics then pl.Physics:Stop() end
        if pl.components.locomotor then pl.components.locomotor:Stop() end
        pl:ClearBufferedAction()
        if pl.sg ~= nil and pl.sg:HasStateTag("moving") then pl.sg:GoToState("idle") end
    end)
    player:DoTaskInTime(CURSE_TIMESTOP2HM, function(pl)
        if pl:IsValid() then
            -- 清理旺达钟表标记
            if pl._alterguardian_cursetimestop_marker then
                if pl._alterguardian_cursetimestop_marker:IsValid() then
                    pl._alterguardian_cursetimestop_marker:Remove()
                end
                pl._alterguardian_cursetimestop_marker = nil
            end
            if pl._alterguardian_cursetimestop_holdtask then
                pl._alterguardian_cursetimestop_holdtask:Cancel()
                pl._alterguardian_cursetimestop_holdtask = nil
            end
            pl._alterguardian_cursetimestop_anchor = nil
            pl._alterguardian_cursetimestop2hm = nil
            pl:RemoveTag("_alterguardian_cursetimestop")
            RefreshTimestopNet2hm(pl)
            if pl.AnimState then pl.AnimState:Resume() end
            if pl.Physics then
                pl.Physics:Stop()
                if pl._alterguardian_cursetimestop_vel then
                    local v = pl._alterguardian_cursetimestop_vel
                    pl._alterguardian_cursetimestop_vel = nil
                    pl.Physics:SetVel(v[1], v[2], v[3])
                end
            end
            if pl.components.locomotor then pl.components.locomotor:Stop() end
        end
    end)
end
-- 每次天体打中玩家(含铥矿皇冠挡伤):获得10层诅咒并累计,达120层触发10秒时停(结束后清零重新累计)
local function ApplyCurse2hm(inst, player)
    if not player or not player:IsValid() or player:HasTag("playerghost") then return end
    if player.components.health and player.components.health:IsDead() then return end
    if player._alterguardian_cursetimestop2hm then return end -- 时停期间被命中:不重置时停时间,也不累计诅咒
    -- 去重
    local now = GetTime()
    if player._alterguardian_curse_lasthit2hm and now - player._alterguardian_curse_lasthit2hm < 1 then return end
    player._alterguardian_curse_lasthit2hm = now
    if player._alterguardian_cursetask2hm then player._alterguardian_cursetask2hm:Cancel() end
    player:AddTag("alterguardian_curse2hm")
    player._alterguardian_cursetask2hm = player:DoTaskInTime(CURSE_DURATION2HM, function(pl)
        if pl:IsValid() then
            pl._alterguardian_cursetask2hm = nil
            pl:RemoveTag("alterguardian_curse2hm")
        end
    end)
    -- 每次命中累计+10层诅咒;每秒自动消除1层(诅咒随时间消散)
    player._alterguardian_curse_total2hm = (player._alterguardian_curse_total2hm or 0) + CURSE_STACK2HM
    if player._alterguardian_curse_decaytask2hm == nil then
        player._alterguardian_curse_decaytask2hm = player:DoPeriodicTask(1, function(pl)
            if not pl:IsValid() then return end
            local t = pl._alterguardian_curse_total2hm or 0
            if t > 0 then
                t = t - CURSE_DECAY2HM
                if t <= 0 then
                    t = 0
                    pl._alterguardian_curse_decaytask2hm:Cancel()
                    pl._alterguardian_curse_decaytask2hm = nil
                end
                pl._alterguardian_curse_total2hm = t
            end
        end)
    end
    -- 达到120层触发10秒时停(结束后清零重新累计)
    if player._alterguardian_curse_total2hm >= CURSE_THRESHOLD2HM then
        player._alterguardian_curse_total2hm = 0
        if player._alterguardian_curse_decaytask2hm then
            player._alterguardian_curse_decaytask2hm:Cancel()
            player._alterguardian_curse_decaytask2hm = nil
        end
        CurseTimestopPlayer2hm(inst, player)
    end
end
-- 仅三阶段本体
local function IsAlterGuardianAttacker2hm(attacker)
    if not attacker or not attacker:IsValid() then return false end
    return attacker.prefab == "alterguardian_phase3"
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", function(inst, data)
        if alterguardianmode ~= -5 then return end -- 诅咒机制仅时停版本天体
        if not IsAlterGuardianAttacker2hm(data and data.attacker) then return end
        ApplyCurse2hm(data.attacker, inst)
    end)
end)

-- 三阶段加强
AddPrefabPostInit("alterguardian_phase3", function(inst)
    inst:AddTag("alterguardian2hm")
    inst:AddTag("toughworker")
    if not TheWorld.ismastersim then return end
    if inst.components.freezable then inst:RemoveComponent("freezable") end
    addminimapicon(inst)
    addprototyper(inst)
    addseasonlock(inst, 3)
    inst:ListenForEvent("GetAttacked_Internal2hm", phase3GetAttacked_Internal)
    inst:ListenForEvent("death", phase3ondeath)
    -- inst.swc2hmfn = phase3processswc
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if TUNING.shadowworld2hm then
        inst.swp2hmfn = swp2hmfn
    else
        swp2hmfn(inst)
    end
    if old_alterguardian and not inst:HasTag("swc2hm") and inst.components.knownlocations then inst.components.knownlocations.GetLocation = nilfn end
    -- 单束冰激光(冰火轮流)会铺冰面,恢复清理机制
    inst:ListenForEvent("onremove", FastDestroyIceTiles)
    inst:ListenForEvent("death", FastDestroyIceTiles)
    inst.destroyicetilestask2hm = inst:DoTaskInTime(30, DestroyIceTiles)
    inst.icetilescd2hmtask = inst:DoTaskInTime(60, clearicetilescd2hmtask)
    if inst.components.combat then inst.components.combat:SetKeepTargetFunction(phase3KeepTarget) end
    if not TUNING.noalterguardianhat2hm and inst.components.lootdropper then
        inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00)
        inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00)
    end
    if alterguardianmode == -5 and inst.components.lootdropper then
        inst.components.lootdropper:AddChanceLoot("onion_celestial2hm", 1.00) -- 天体洋葱:仅时停版本天体必掉
    end
    -- 远程/爆炸减伤:爆炸物90%减伤;远程攻击按玩家与天体距离递减
    if alterguardianmode == -5 and not inst._rangedreduce2hm and inst.components.combat then
        inst._rangedreduce2hm = true
        local combat = inst.components.combat
        local orig_GetAttacked_Internal = combat.GetAttacked_Internal
        if orig_GetAttacked_Internal then
            combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage)
                local mult = 1
                if attacker and attacker:IsValid() and attacker:HasTag("explosive") then
                    mult = mult * 0.1 -- 爆炸减伤90%
                elseif attacker and attacker:IsValid() and weapon and weapon.components and
                    (weapon.components.projectile or (weapon.components.weapon and weapon.components.weapon.attackrange and weapon.components.weapon.attackrange > 4)) then
                    -- 远程攻击(投射物/远攻武器):按玩家与天体距离,≤4格无减伤,每多1格+10%,14格起100%
                    local distsq = attacker:GetDistanceSqToInst(inst) -- DST无GetDistanceToInst,用平方距离计算
                    if distsq > 16 then -- 距离>4格
                        local dist = math.sqrt(distsq)
                        local pct = math.min(1, (dist - 4) * 0.1)
                        mult = mult * (1 - pct)
                    end
                end
                if mult < 1 and damage then
                    damage = damage * mult
                end
                return orig_GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage)
            end
        end
    end
    --达120层触发10秒时停
    if alterguardianmode == -5 and not inst._cursehook2hm then
        inst._cursehook2hm = true
        inst:ListenForEvent("onhitother", function(inst, data)
            local weapon = data and data.weapon
            if weapon and weapon.prefab == "alterguardian_laser" then return end
            local target = data and data.target
            if target and target:IsValid() and target:HasTag("player") and not target:HasTag("playerghost") then
                ApplyCurse2hm(inst, target)
            end
        end)
    end
end)
-- 冰岛领域
local ICE_AOE_TARGET_TAGS = {"_combat"}
local ICE_AOE_TARGET_CANT_TAGS = {"INLIMBO", "flight", "invisible", "playerghost", "lunar_aligned"}
local min_distance_from_entities = ((TILE_SCALE / 2) + 1.0) * 1.4142
local CUSTOM_DEPLOY_IGNORE_TAGS = {
    "NOBLOCK",
    "player",
    "FX",
    "INLIMBO",
    "DECOR",
    "ignorewalkableplatforms",
    "ignorewalkableplatformdrowning",
    "activeprojectile",
    "flying",
    "kelp",
    "_inventoryitem",
    "_health",
    "moonglass"
}
-- ==================== 激光命中玩家时停 ====================
-- 天体英雄所有激光(单束冰/火/三连/×形/环形/横扫)打中玩家后,玩家被时停1秒
local TIMESTOP_DURATION2HM = 1
local TIMESTOP_CD2HM = 1 -- 秒
local function TimestopPlayer2hm(inst, player)
    if not inst or not inst:IsValid() or not player or not player:IsValid() then return end
    if player.components.health and player.components.health:IsDead() then return end
    if player._alterguardian_cursetimestop2hm then return end -- 240层诅咒触发10秒时停期间:激光命中不再重置时停时间
    if player._alterguardian_timestop2hm then return end -- 不叠加
    local now = GetTime()
    if inst._alterguardian_timestopcd2hm and now - inst._alterguardian_timestopcd2hm < TIMESTOP_CD2HM then return end
    inst._alterguardian_timestopcd2hm = now
    player._alterguardian_timestop2hm = true
    RefreshTimestopNet2hm(player)
    -- 动画冻结
    if player.AnimState then
        player.AnimState:Pause()
    end
    -- 物理停止(移动拦截由physics组件全局包装处理)
    if player.Physics then
        player._alterguardian_timestop_vel = { player.Physics:GetVelocity() }
        player.Physics:Stop()
    end
    if player.components.locomotor then
        player.components.locomotor:Stop()
    end
    player:AddTag("_alterguardian_timestop")
    -- 每帧强制Stop(不回拉位置,否则传送/位移后会被拽回原位)
    player._alterguardian_timestop_anchor = player:GetPosition()
    player._alterguardian_timestop_holdtask = player:DoPeriodicTask(0, function(pl)
        if not pl:IsValid() or not pl:HasTag("_alterguardian_timestop") then return end
        if pl.Physics then pl.Physics:Stop() end
        if pl.components.locomotor then pl.components.locomotor:Stop() end
        pl:ClearBufferedAction()
        if pl.sg ~= nil and pl.sg:HasStateTag("moving") then pl.sg:GoToState("idle") end
    end)
    -- 1秒后恢复
    player:DoTaskInTime(TIMESTOP_DURATION2HM, function(pl)
        if pl:IsValid() then
            if pl._alterguardian_cursetimestop2hm then return end -- 10秒诅咒时停期间由诅咒时停统一恢复
            if pl._alterguardian_timestop_holdtask then
                pl._alterguardian_timestop_holdtask:Cancel()
                pl._alterguardian_timestop_holdtask = nil
            end
            pl._alterguardian_timestop_anchor = nil
            pl._alterguardian_timestop2hm = nil
            pl:RemoveTag("_alterguardian_timestop")
            RefreshTimestopNet2hm(pl)
            if pl.AnimState then pl.AnimState:Resume() end
            if pl.Physics then
                pl.Physics:Stop()
                if pl._alterguardian_timestop_vel then
                    local v = pl._alterguardian_timestop_vel
                    pl._alterguardian_timestop_vel = nil
                    pl.Physics:SetVel(v[1], v[2], v[3])
                end
            end
            if pl.components.locomotor then pl.components.locomotor:Stop() end
        end
    end)
end
-- 激光打中玩家后,马上生成月灵攻击玩家
local GESTALT_DAMAGE2HM = 42.5
local GESTALT_CD2HM = 3 -- 秒:一次激光多个命中点只触发一个月灵
local function SpawnMoonSpiritAttackPlayer2hm(inst, player)
    if not inst or not inst:IsValid() or not player or not player:IsValid() then return end
    if player.components.health and player.components.health:IsDead() then return end
    local now = GetTime()
    if inst._lasergestaltcd2hm and now - inst._lasergestaltcd2hm < GESTALT_CD2HM then return end
    inst._lasergestaltcd2hm = now
    local x, y, z = player.Transform:GetWorldPosition()
    local gestalt = SpawnPrefab("alterguardianhat_projectile")
    if gestalt then
        local r = GetRandomMinMax(3, 5)
        local delta_angle = GetRandomMinMax(-90, 90)
        local angle = (inst:GetAngleToPoint(x, y, z) + delta_angle) * DEGREES
        gestalt.Transform:SetPosition(x + r * math.cos(angle), y, z + r * -math.sin(angle))
        gestalt:ForceFacePoint(x, y, z)
        if gestalt.SetTargetPosition then
            gestalt:SetTargetPosition(Vector3(x, y, z))
        end
        if gestalt.components.follower then
            gestalt.components.follower:SetLeader(inst)
        end
        if gestalt.components.combat then
            gestalt.components.combat:SetDefaultDamage(GESTALT_DAMAGE2HM)
        end
    end
end
-- ==================== 激光命中百分比掉血debuff ====================
local LASER_PCT_DURATION2HM = 7      -- 普通流血持续:秒(命中刷新)
local LASER_PCT_RATE2HM = 0.01       -- 普通流血每秒掉血:最大生命值比例
local LASER_PCT_ACCUM2HM = 30        -- 连续流血累计秒数,达到触发强流血
local LASER_PCT_STRONG_DUR2HM = 7    -- 强流血持续:秒
local LASER_PCT_STRONG_EXT2HM = 3    -- 强流血期间再被命中:增加秒数
local LASER_PCT_STRONG_RATE2HM = 0.10 -- 强流血每秒掉血:最大生命值比例
local function ApplyLaserPercentDebuff2hm(caster, player)
    if not player or not player:IsValid() or not player.components.health or player:HasTag("playerghost") then return end
    if player._laserpct_strong2hm then
        -- 强流血已激活:再次被激光打中,强流血时间直接+3秒
        player._laserbleedleft2hm = (player._laserbleedleft2hm or 0) + LASER_PCT_STRONG_EXT2HM
        return
    end
    -- 普通流血:刷新7秒(重置剩余时间);已有任务在跑则只刷新时间
    player._laserbleedleft2hm = LASER_PCT_DURATION2HM
    if player._laserpcttask2hm then return end
    player._laserpcttask2hm = player:DoPeriodicTask(1, function(self)
        if not self:IsValid() or not self.components.health or self.components.health:IsDead() then
            self._laserbleedleft2hm = nil
            self._laserpct_strong2hm = nil
            self._laserpct_accum2hm = nil
            if self._laserpcttask2hm then self._laserpcttask2hm:Cancel(); self._laserpcttask2hm = nil end
            return
        end
        local left = self._laserbleedleft2hm or 0
        if left <= 0 then
            -- 流血中断:任务结束,连续流血累计清零
            self._laserbleedleft2hm = nil
            self._laserpct_strong2hm = nil
            self._laserpct_accum2hm = nil
            if self._laserpcttask2hm then self._laserpcttask2hm:Cancel(); self._laserpcttask2hm = nil end
            return
        end
        local maxhp = self.components.health.maxhealth or 1
        local bleeder = (caster and caster:IsValid()) and caster or nil
        if self._laserpct_strong2hm then
            -- 强流血:每秒掉10%最大生命值(普通流血期间不生效)
            self.components.health:DoDelta(-maxhp * LASER_PCT_STRONG_RATE2HM, nil, "alterguardian_phase3", nil, bleeder)
        else
            -- 普通流血:每秒掉1%最大生命值,并累计连续流血秒数
            self.components.health:DoDelta(-maxhp * LASER_PCT_RATE2HM, nil, "alterguardian_phase3", nil, bleeder)
            self._laserpct_accum2hm = (self._laserpct_accum2hm or 0) + 1
            if self._laserpct_accum2hm >= LASER_PCT_ACCUM2HM then
                -- 连续流血30秒:升级为强流血(7秒),累计清零
                self._laserpct_strong2hm = true
                self._laserpct_accum2hm = nil
                self._laserbleedleft2hm = LASER_PCT_STRONG_DUR2HM
                return
            end
        end
        self._laserbleedleft2hm = left - 1
    end)
end
-- ==================== 低血量激光附加月火 ====================
-- 天体血量<20%后:每个激光打中玩家,玩家脚下额外生成月火,持续25帧,每8帧一次伤害判定(0/8/16/24帧共4次),50普通+10位面
local LOWHP_MOONFIRE_FRAMES2HM = 25          -- 月火持续:帧
local LOWHP_MOONFIRE_PERIOD2HM = 8 * FRAMES  -- 伤害判定间隔:帧
local LOWHP_MOONFIRE_RANGE2HM = 1.5          -- 灼烧半径:格(跑出范围不再受伤)
local LOWHP_MOONFIRE_DMG2HM = 20             -- 普通伤害
local LOWHP_MOONFIRE_PLANAR2HM = 5           -- 位面伤害
local function SpawnLowHealthMoonfire2hm(inst, player)
    if not TheWorld.ismastersim then return end
    if not player or not player:IsValid() or player:HasTag("playerghost") then return end
    if player.components.health and player.components.health:IsDead() then return end
    if player._lowhpmoonfire2hm then return end -- 脚下已有月火不叠加(三连15束同时命中只留1个,防叠加秒杀)
    player._lowhpmoonfire2hm = true
    local px, py, pz = player.Transform:GetWorldPosition()
    local flame = SpawnPrefab("warg_mutated_breath_fx")
    if flame then
        local scale = 1.2 + 0.3 * math.random()
        flame.Transform:SetPosition(px, 0, pz)
        flame:RestartFX(scale, "nofade", {})
        if flame.spawn_embers_task then flame.spawn_embers_task:Cancel() end -- 性能:取消余烬
        if flame.kill_fx_task then flame.kill_fx_task:Cancel() end
        flame.kill_fx_task = flame:DoTaskInTime(LOWHP_MOONFIRE_FRAMES2HM * FRAMES, function(f)
            if f:IsValid() then
                if f.AnimState then f.AnimState:PlayAnimation("flame" .. tostring(math.random(3)) .. "_pst") end
                f:DoTaskInTime(1, function(f2) if f2:IsValid() then f2:Remove() end end)
            end
        end)
    end
    -- 伤害载体(纯服务端逻辑,无Network):50普通+10位面;combat:DoAttack会自动附加planardamage(SpDamageUtil.CollectSpDamage)
    local dmg = CreateEntity()
    dmg.entity:AddTransform()
    dmg.Transform:SetPosition(px, 0, pz)
    dmg:AddComponent("combat")
    dmg.components.combat:SetDefaultDamage(LOWHP_MOONFIRE_DMG2HM)
    dmg:AddComponent("planardamage")
    dmg.components.planardamage:SetBaseDamage(LOWHP_MOONFIRE_PLANAR2HM)
    dmg.persists = false
    dmg.displaynamefn = function() return "月火" end -- 防GetDisplayName崩溃(死亡播报会读afflicter名字,CreateEntity无prefab时name=nil)
    dmg.nameoverride = "alterguardian_phase3" -- 死亡原因显示天体英雄:CreateEntity无prefab名,combat结算时cause.prefab=nil→"NIL"→死于黑暗
    local tick = 0
    local function tickattack()
        tick = tick + 1
        if tick > 4 then return false end -- 0/8/16/24帧共4次
        if not player:IsValid() or (player.components.health and player.components.health:IsDead()) then return false end
        if player:GetDistanceSqToPoint(px, 0, pz) <= LOWHP_MOONFIRE_RANGE2HM * LOWHP_MOONFIRE_RANGE2HM then
            dmg.components.combat:DoAttack(player)
        end
        return true
    end
    if tickattack() then -- 生成瞬间立即判定一次
        dmg.dmgtask = dmg:DoPeriodicTask(LOWHP_MOONFIRE_PERIOD2HM, function()
            if not tickattack() then
                dmg.dmgtask:Cancel()
                if dmg:IsValid() then dmg:Remove() end
            end
        end)
    else
        if dmg:IsValid() then dmg:Remove() end
        return
    end
    -- 保险:25帧后强制清理
    dmg:DoTaskInTime((LOWHP_MOONFIRE_FRAMES2HM + 2) * FRAMES, function()
        if dmg.dmgtask then dmg.dmgtask:Cancel() end
        if dmg:IsValid() then dmg:Remove() end
        if player:IsValid() then player._lowhpmoonfire2hm = nil end -- 清除标记,下个激光可再生成
    end)
end
-- 三连(15束)/×形/环形/横扫扇形激光(alterguardian_laser)命中表含玩家时触发月灵
AddPrefabPostInit("alterguardian_laser", function(fx)
    if not TheWorld.ismastersim then return end
    if alterguardianmode ~= -5 then return end -- 激光命中特效(时停/百分比掉血/回血/低血量月火/月灵/点燃)仅时停版本天体,其他档走原版
    fx.nameoverride = "alterguardian_phase3" -- caster失效时原版DoDamage走fx自身combat,死亡原因也记录为天体英雄(否则显示"恶作剧")
    local oldtrigger = fx.Trigger
    if not oldtrigger then return end
    fx.Trigger = function(self, ...)
        local _, targets = ...
        oldtrigger(self, ...)
        local caster = fx.caster
        if caster and caster:IsValid() and caster.prefab == "alterguardian_phase3" and targets then
            for v in pairs(targets) do
                if v and v:IsValid() and v:HasTag("player") and not v:HasTag("playerghost") then
                    ApplyCurse2hm(caster, v) -- 诅咒累计:每次激光命中+10层(先结算,触发长时停后下方1秒时停会被拦截不覆盖)
                    TimestopPlayer2hm(caster, v)
                    ApplyLaserPercentDebuff2hm(caster, v) -- 流血:每秒1%最大生命持续7秒;连续流血30秒升级为强流血(每秒10%,再命中+3秒)
                    if caster.components.health then
                        caster.components.health:DoDelta(34) -- 每个激光打中玩家,天体恢复34生命值(防铥矿皇冠无敌盾站攒)
                    end
                    if caster.components.health and caster.components.health:GetPercent() < 0.2 then
                        SpawnLowHealthMoonfire2hm(caster, v) -- 天体血量<20%:玩家脚下额外月火
                    end
                    if fx.firelaser2hm then
                        -- 火激光:命中玩家后点燃10秒(原版燃烧伤害,不叠加额外掉血)
                        if v.components.burnable then
                            v.components.burnable:SetBurnTime(10)
                            v.components.burnable:Ignite(true, caster)
                        end
                    else
                        -- 普通激光:月灵反击
                        SpawnMoonSpiritAttackPlayer2hm(caster, v)
                    end
                    break
                end
            end
        end
    end
end)
local function createareaicetiles(inst, straight)
    if inst:HasTag("swc2hm") then return end
    if TheWorld.components.oceanicemanager and inst.components.persistent2hm and not (inst.components.health and inst.components.health:IsDead()) then
        if inst.destroyicetilestask2hm then inst.destroyicetilestask2hm:Cancel() end
        inst.destroyicetilestask2hm = inst:DoTaskInTime(60, DestroyIceTiles)
        local data = inst.components.persistent2hm.data.icetiles or {}
        inst.components.persistent2hm.data.icetiles = data
        local _x, _y, _z = inst.Transform:GetWorldPosition()
        local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(_x, 0, _z)
        _x, _y, _z = TheWorld.Map:GetTileCenterPoint(tx, ty)
        local radius = 25
        for i = 0, radius, 4 do
            local function processice()
                for j = -i, i, 4 do
                    for k = -i, i, 4 do
                        if j * j + k * k <= 625 then
                            local x = _x + j
                            local z = _z + k
                            local tile_x, tile_y = TheWorld.Map:GetTileCoordsAtPoint(x, 0, z)
                            local tile = TheWorld.Map:GetTileAtPoint(x, 0, z)
                            local canicetile
                            if tile == WORLD_TILES.OCEAN_ICE then
                                canicetile = false
                            elseif IsLandTile(tile) then
                                canicetile = true
                            else
                                canicetile = true
                                local center_pt = Vector3(TheWorld.Map:GetTileCenterPoint(tile_x, tile_y))
                                if not IsTableEmpty(TheSim:FindEntities(center_pt.x, 0, center_pt.z, min_distance_from_entities, nil, CUSTOM_DEPLOY_IGNORE_TAGS)) then
                                    canicetile = false
                                end
                            end
                            if canicetile then
                                table.insert(data, {x = tile_x, y = tile_y})
                                TheWorld.components.oceanicemanager:CreateIceAtTile(tile_x, tile_y)
                            end
                        end
                    end
                end
            end
            if straight then
                processice()
            else
                inst:DoTaskInTime(i * 5 * FRAMES, processice)
            end
        end
    end
end
-- 冰火攻击，同时制造一条线的冰岛地皮
local function CreateIceTileAtPoint(inst, i, x, z, data, rot, targets)
    local fx = SpawnPrefab("warg_mutated_breath_fx")
    fx.Transform:SetPosition(x, 0, z)
    if i % 4 ~= 0 then return end
    -- 冰岛地皮
    if not banicetiles then
        local tile_x, tile_y = TheWorld.Map:GetTileCoordsAtPoint(x, 0, z)
        local tile = TheWorld.Map:GetTileAtPoint(x, 0, z)
        local canicetile
        if tile == WORLD_TILES.OCEAN_ICE then
            canicetile = false
        elseif IsLandTile(tile) then
            canicetile = true
        else
            canicetile = true
            local center_pt = Vector3(TheWorld.Map:GetTileCenterPoint(tile_x, tile_y))
            if not IsTableEmpty(TheSim:FindEntities(center_pt.x, 0, center_pt.z, min_distance_from_entities, nil, CUSTOM_DEPLOY_IGNORE_TAGS)) then
                canicetile = false
            end
        end
        if canicetile then
            table.insert(data, {x = tile_x, y = tile_y})
            TheWorld.components.oceanicemanager:CreateIceAtTile(tile_x, tile_y)
        end
    end
    -- 冰火伤害
    inst.components.combat.ignorehitrange = true
    inst.components.combat.ignoredamagereflect = true
    local ents = TheSim:FindEntities(x, 0, z, 3, ICE_AOE_TARGET_TAGS, ICE_AOE_TARGET_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v:IsValid() and v ~= inst and not targets[v] and not v:IsInLimbo() and not (v.components.health ~= nil and v.components.health:IsDead()) then
            targets[v] = true
            -- 冰激光命中玩家→时停0.3秒
            if v:HasTag("player") then
                TimestopPlayer2hm(inst, v)
            end
            -- Supercool
            if v.components.temperature ~= nil then
                local newtemp = math.max(v.components.temperature.mintemp, TUNING.MUTATED_WARG_COLDFIRE_TEMPERATURE)
                if newtemp < v.components.temperature:GetCurrent() then v.components.temperature:SetTemperature(newtemp) end
            end
            -- Hit
            if inst.components.combat:CanTarget(v) then inst.components.combat:DoAttack(v) end
            -- Freeze
            if v.components.freezable ~= nil then
                v.components.freezable:AddColdness(4)
                v.components.freezable:SpawnShatterFX()
            end
        end
    end
    inst.components.combat.ignorehitrange = false
    inst.components.combat.ignoredamagereflect = false
end
local function doiceattack(inst, rot)
    if inst:HasTag("swc2hm") then return end
    if TheWorld.components.oceanicemanager and inst.components.persistent2hm and not inst.icetilescd2hmtask then
        local data = inst.components.persistent2hm.data.icetiles or {}
        inst.components.persistent2hm.data.icetiles = data
        local radius = 50
        local targets = {}
        local x, y, z = inst.Transform:GetWorldPosition()
        local cosrot = math.cos(rot)
        local sinrot = math.sin(rot)
        for i = 0, radius, 2 do inst:DoTaskInTime(i * FRAMES / 2, CreateIceTileAtPoint, i, x + i * cosrot, z - i * sinrot, data, rot, targets) end
        if not banicetiles then
            if inst.destroyicetilestask2hm then inst.destroyicetilestask2hm:Cancel() end
            inst.destroyicetilestask2hm = inst:DoTaskInTime(60, DestroyIceTiles)
        end
        inst.icetilescd2hmtask = inst:DoTaskInTime(50, clearicetilescd2hmtask)
    end
end
-- 火激光攻击:单束激光快速扫过,命中造成150伤害+点燃,地面留下火魔法阵
local FIRELASER2HM_DAMAGE = 150
local SINGLELASER_CD2HM = 60 -- 单束激光(冰/火轮流)CD:60秒一个冰,再60秒一个火;CD就绪时普通激光攻击直接替换为单束激光(100%,不用概率,消除连续两次释放)
local function ApplyFireLaserBurn2hm(v, inst)
    -- 点燃
    if v.components.burnable then
        v.components.burnable:Ignite(true, inst)
    end
end
local function CreateFireLaserPoint2hm(inst, x, z, targets)
    -- 地面火魔法阵
    local spell = SpawnPrefab("deer_fire_circle")
    if spell then
        spell.Transform:SetPosition(x, 0, z)
        spell:DoTaskInTime(4, spell.KillFX)
    end
    -- 火焰伤害+点燃
    inst.components.combat.ignorehitrange = true
    inst.components.combat.ignoredamagereflect = true
    local ents = TheSim:FindEntities(x, 0, z, 3, ICE_AOE_TARGET_TAGS, ICE_AOE_TARGET_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v:IsValid() and v ~= inst and not targets[v] and not v:IsInLimbo() and not (v.components.health ~= nil and v.components.health:IsDead()) then
            targets[v] = true
            -- 火激光命中玩家→时停0.3秒
            if v:HasTag("player") then
                TimestopPlayer2hm(inst, v)
            end
            -- 150伤害
            if v.components.combat and inst.components.combat then
                local olddmg = inst.components.combat.defaultdamage
                inst.components.combat.defaultdamage = FIRELASER2HM_DAMAGE
                inst.components.combat:DoAttack(v)
                inst.components.combat.defaultdamage = olddmg
            end
            -- 点燃
            ApplyFireLaserBurn2hm(v, inst)
        end
    end
    inst.components.combat.ignorehitrange = false
    inst.components.combat.ignoredamagereflect = false
end
local function dofirelaserattack2hm(inst, rot)
    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    local radius = 50
    local targets = {}
    local skiptoss = {}
    local x, y, z = inst.Transform:GetWorldPosition()
    local cosrot = math.cos(rot)
    local sinrot = math.sin(rot)
    -- 真正的单束火激光:沿路径每2格生成alterguardian_laser(激光束视觉+150伤害走护甲结算),每10格留火魔法阵
    -- 命中玩家→时停1秒+点燃(不出月灵,月灵只属于三连/横扫等大范围激光)
    for i = 0, radius, 2 do
        inst:DoTaskInTime(i * FRAMES / 2, function(inst2)
            local px = x + i * cosrot
            local pz = z - i * sinrot
            local fx = SpawnPrefab("alterguardian_laser")
            if fx then
                fx.firelaser2hm = true -- 标记:命中玩家时点燃但不触发月灵
                fx.caster = inst2
                fx.Transform:SetPosition(px, 0, pz)
                fx:OverrideDamage(FIRELASER2HM_DAMAGE)
                fx:Trigger(0, targets, skiptoss, true)
            end
            -- 火魔法阵:缩小66%,沿路径每2格一个紧密排列(圈外缘相切)
            local spell = SpawnPrefab("deer_fire_circle")
            if spell then
                spell.Transform:SetPosition(px, 0, pz)
                spell.Transform:SetScale(0.66, 0.66, 0.66)
                spell:DoTaskInTime(4, spell.KillFX)
            end
        end)
    end
end
-- ==================== 喷月火===================
local MOONFIRE_PERIOD2HM = 3 * FRAMES
local MOONFIRE_DMG2HM = 200
local MOONFIRE_PLANAR2HM = 50
local MOONFIRE_SPINSPEED2HM = 90 -- 固定角速度:度/秒
local MOONFIRE_SPINOFFSET2HM = 60 -- 起始方向偏移:玩家左/右60度
local MOONFIRE_FLAMETIME2HM = 8 * FRAMES
local MOONFIRE_DISTS2HM = {0, 1, 2, 3, 4, 5, 6, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34, 37}
local ERASER_FLAME_CD2HM = 120
local function KillFlame2hm(flame)
    if flame == nil or not flame:IsValid() then return end
    if flame.AnimState then
        flame.AnimState:PlayAnimation("flame" .. tostring(math.random(3)) .. "_pst")
    end
    flame.fadeoption = nil
    if flame.embers ~= nil then
        if flame.embers:IsValid() then
            flame.embers:KillFX()
        end
        flame.embers = nil
    end
    flame.kill_fx_task = nil
end
local function SpawnMoonfireThrower2hm(inst, start_angle, spin_dir)
    if not TheWorld.ismastersim then return end
    local fx = CreateEntity()
    fx.entity:AddTransform()
    fx.entity:AddSoundEmitter()
    fx:AddTag("CLASSIFIED")
    fx.flame_pool = {}
    fx.angle_start = start_angle or 0
    fx.spin_dir = spin_dir or 1
    fx.start_time = GetTime()
    local function SpawnBreathFX(fx_inst, dist, targets)
        if type(dist) ~= "number" then
            fx_inst, dist, targets = dist, targets, nil
        end
        fx_inst.angle = fx_inst.angle_start + fx_inst.spin_dir * MOONFIRE_SPINSPEED2HM * DEGREES * (GetTime() - fx_inst.start_time)
        if not fx_inst.SoundEmitter:PlayingSound("loop") then
            fx_inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
            fx_inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "loop")
        end
        local flame = table.remove(fx_inst.flame_pool)
        if flame == nil then
            flame = SpawnPrefab("warg_mutated_breath_fx")
            flame:SetFXOwner(fx_inst, inst)
        end
        local x, y, z = inst.Transform:GetWorldPosition()
        local a = fx_inst.angle
        local px = x + math.cos(a) * dist
        local pz = z - math.sin(a) * dist
        local jitter = dist / 20
        local ja = math.random() * PI2
        px = px + math.cos(ja) * jitter
        pz = pz - math.sin(ja) * jitter
        local scale = 1.5 + 0.5 * math.random()
        if dist < 12 then
            scale = scale * 1.1
        elseif dist < 24 then
            scale = scale * 1.3
        else
            scale = scale * 1.5
        end
        local fadeoption = (dist < 12 and "nofade") or (dist <= 24 and "latefade") or nil
        flame.Transform:SetPosition(px, 0, pz)
        flame:RestartFX(scale, fadeoption, targets)
        if flame.kill_fx_task then flame.kill_fx_task:Cancel() end
        flame.kill_fx_task = flame:DoTaskInTime(MOONFIRE_FLAMETIME2HM, KillFlame2hm)
        if flame.spawn_embers_task then flame.spawn_embers_task:Cancel() end
    end
    local targets = {}
    local offsets = {0, FRAMES, 2 * FRAMES, 3 * FRAMES, 4 * FRAMES, 5 * FRAMES, 6 * FRAMES, 7 * FRAMES, 8 * FRAMES, 9 * FRAMES, 10 * FRAMES, 11 * FRAMES, 12 * FRAMES, 13 * FRAMES, 14 * FRAMES, 15 * FRAMES, 16 * FRAMES, 17 * FRAMES}
    fx.tasks = {}
    for i, dist in ipairs(MOONFIRE_DISTS2HM) do
        fx.tasks[#fx.tasks + 1] = fx:DoPeriodicTask(MOONFIRE_PERIOD2HM, SpawnBreathFX, offsets[i], dist, targets)
    end
    fx:AddComponent("weapon")
    fx.components.weapon:SetDamage(MOONFIRE_DMG2HM)
    fx:AddComponent("planardamage")
    fx.components.planardamage:SetBaseDamage(MOONFIRE_PLANAR2HM)
    fx.KillFX = function(self)
        for _, t in ipairs(self.tasks) do
            t:Cancel()
        end
        if self.flame_pool ~= nil then
            for _, v in ipairs(self.flame_pool) do
                v:Remove()
            end
            self.flame_pool = nil
        end
        self.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pst")
        self:DoTaskInTime(1, self.Remove)
    end
    fx.persists = false
    inst.eraserflame_fx2hm = fx
end
-- 旋转月火
AddStategraphState("alterguardian_phase3", State{
    name = "eraserflame2hm",
    tags = {"attacking", "busy", "canrotate"},
    onenter = function(inst, target)
        inst.Transform:SetEightFaced()
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("idle")
        inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_beam")
        if inst.components.combat and inst.components.combat:TargetIs(target) then
            inst.components.combat:StartAttack()
        end
        if inst.components.timer then inst.components.timer:StartTimer("eraser_cd2hm", ERASER_FLAME_CD2HM) end
        if target and target.Transform then inst:ForceFacePoint(target.Transform:GetWorldPosition()) end
        inst.sg.statemem.target = target
        local base_angle
        if target and target:IsValid() and target.Transform then
            base_angle = inst:GetAngleToPoint(target.Transform:GetWorldPosition()) * DEGREES
        else
            base_angle = inst.Transform:GetRotation() * DEGREES
        end
        if math.random() < 0.5 then
            inst.sg.statemem.moonfire_angle = base_angle + MOONFIRE_SPINOFFSET2HM * DEGREES
            inst.sg.statemem.moonfire_spin = -1
        else
            inst.sg.statemem.moonfire_angle = base_angle - MOONFIRE_SPINOFFSET2HM * DEGREES
            inst.sg.statemem.moonfire_spin = 1
        end
        inst.sg:SetTimeout(8)
        -- 月火期间(8秒):天体获得90%减伤
        if inst.components.combat and inst.components.combat.externaldamagetakenmultipliers then
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.1, "moonfireprotect2hm") -- 承伤10%=减伤90%(字段在combat不在health)
        end
    end,
    timeline = {
        TimeEvent(20 * FRAMES, function(inst)
            inst.Transform:SetFourFaced()
            inst.AnimState:PlayAnimation("attk_swipe")
            if not TheWorld.ismastersim then return end
            if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
            SpawnMoonfireThrower2hm(inst, inst.sg.statemem.moonfire_angle, inst.sg.statemem.moonfire_spin)
        end),
    },
    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,
    onexit = function(inst)
        if inst.eraserflame_fx2hm ~= nil then
            inst.eraserflame_fx2hm:KillFX()
            inst.eraserflame_fx2hm = nil
        end
        if inst.components.combat and inst.components.combat.externaldamagetakenmultipliers then
            inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "moonfireprotect2hm")
        end
        inst.Transform:SetSixFaced()
    end,
})
-- 爪形激光中间束追踪
local function SpawnClawTrackingBeam2hm(inst, target, pos, dir)
    if not TheWorld.ismastersim then return end
    if not (target and target:IsValid() and not (target.components.health and target.components.health:IsDead())) then
        target = FindClosestPlayerToInst(inst, 99, true)
    end
    local turns = 0
    local traveled = 0
    local fx = CreateEntity()
    fx.entity:AddTransform()
    fx:AddTag("CLASSIFIED")
    fx.persists = false
    local step = 20 / 15 -- 速度20格/秒(每2帧前进4/3格,每2帧生成一个点位)
    fx.periodictask = fx:DoPeriodicTask(2 * FRAMES, function()
        pos = pos + dir * step
        traveled = traveled + step
        local beam = SpawnPrefab("alterguardian_laser")
        if beam then
            beam.caster = inst
            beam.Transform:SetPosition(pos.x, 0, pos.z)
            beam:OverrideDamage(100)
            beam:Trigger(0, {}, {}, true)
        end
        if traveled >= 30 then -- 每移动30格转向
            turns = turns + 1
            if turns > 3 then -- 最多转向3次
                fx.periodictask:Cancel()
                fx:Remove()
                return
            end
            traveled = 0
            local tp
            if target and target:IsValid() and not (target.components.health and target.components.health:IsDead()) then
                tp = target:GetPosition()
                if math.random() < 0.5 and target.Physics then -- 50%概率预判玩家0.5秒后位置
                    local vx, vy, vz = target.Physics:GetVelocity()
                    tp = tp + Vector3(vx, 0, vz) * 0.5
                end
            end
            if tp then
                local newdir = tp - pos
                local len = newdir:Length()
                if len > 0.01 then dir = newdir * (1 / len) end
            end
        end
    end)
end

-- 大虚影攻击(同时在场上限,防止越打越多卡顿);数量上限改这里
local GESTALTGUARDMAX2HM = 2
local gestaltguards2hm = {}
local function killgestalt(inst) inst.components.health:Kill() end
local function countgestaltguard2hm()
    local num = 0
    for k in pairs(gestaltguards2hm) do
        if k:IsValid() then
            num = num + 1
        else
            gestaltguards2hm[k] = nil
        end
    end
    return num
end
local function ongestaltattack(inst)
    inst.attacktimes = (inst.attacktimes or 0) + 1
    if inst.attacktimes >= 2 then inst:DoTaskInTime(30 * FRAMES, killgestalt) end
end
local function dogestaltattack(inst)
    if inst._stop_task and TUNING.alterguardianseason2hm == 3 and TheWorld.state.isalterawake and
        countgestaltguard2hm() < GESTALTGUARDMAX2HM then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ent = SpawnPrefab("gestalt_guard")
        gestaltguards2hm[ent] = true
        ent.AnimState:SetAddColour(5 / 255, 87 / 255, 255 / 255, 0.8)
        ent.Transform:SetPosition(x, 0, z)
        ent.persists = false
        ent.entity:SetCanSleep(false)
        ent:ListenForEvent("doattack", ongestaltattack)
        ent:DoTaskInTime(math.random(15, 45), killgestalt)
        if inst.find_attack_victim then
            local attack_target = inst:find_attack_victim()
            if attack_target ~= nil then ent.components.combat:SetTarget(attack_target) end
        end
    end
end
local function ongestaltprojanimover(inst)
    if TUNING.alterguardianseason2hm == 3 and TheWorld.state.isalterawake and
        (inst.AnimState:IsCurrentAnimation("emerge") or inst.AnimState:IsCurrentAnimation("attack")) then inst:DoTaskInTime(24 * FRAMES, dogestaltattack) end
end
AddPrefabPostInit("gestalt_alterguardian_projectile", function(inst)
    if not TheWorld.ismastersim then return end
    if TUNING.alterguardianseason2hm == 3 and TheWorld.state.isalterawake and math.random() < 0.5 then inst:ListenForEvent("animover", ongestaltprojanimover) end
end)
-- 环绕启迪陷阱攻击
SetSharedLootTable2hm("moonglass_trap", {{"moonglass", 0.05}})
local function spawnprotecttrap(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local trap = SpawnPrefab("alterguardian_phase3trap")
    trap.persists = false
    trap.components.lootdropper:SetChanceLootTable()
    trap.Transform:SetPosition(ix, iy, iz)
    trap.AnimState:SetScale(0.6, 0.6)
    inst:Remove()
end
local function dotrapattack(inst)
    if inst:HasTag("swc2hm") then return end
    local POINTS_ANGLEDIFF = PI / 18
    local RADIUS = math.sqrt(TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ)
    local ix, _, iz = inst.Transform:GetWorldPosition()
    local angle = 0
    while angle < 2 * PI do
        local x = ix + RADIUS * math.cos(angle)
        local z = iz + RADIUS * math.sin(angle)
        local projectile = SpawnPrefab("alterguardian_phase3trapprojectile")
        projectile.Transform:SetPosition(x, 0, z)
        projectile.AnimState:SetScale(0.6, 0.6)
        projectile:SetGuardian(inst)
        angle = angle + POINTS_ANGLEDIFF
        if projectile.event_listeners and projectile.event_listeners.animover then
            for k, value in pairs(projectile.event_listeners.animover) do
                for index, fn in pairs(value) do
                    value[index] = spawnprotecttrap
                    break
                end
            end
        end
    end
end
local function onphase3trapprojectileremove(inst)
    if inst.components.lootdropper and inst.components.lootdropper.chanceloottable then
        local spell = SpawnPrefab("deer_ice_circle")
        if spell.TriggerFX then spell:DoTaskInTime(2, spell.TriggerFX) end
        spell.Transform:SetPosition(inst.Transform:GetWorldPosition())
        spell:DoTaskInTime(4, spell.KillFX)
        local x, y, z = inst.Transform:GetWorldPosition()
        if TheWorld.components.dockmanager ~= nil then TheWorld.components.dockmanager:DamageDockAtPoint(x, y, z, 1000) end
    end
end
AddPrefabPostInit("alterguardian_phase3trap", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", onphase3trapprojectileremove)
end)
-- 激光攻击
local function laserattack(inst, enable, targets, skiptoss, skipscorch, x, z, first, target_pos)
    if enable then
        if first or not IsTableEmpty(FindPlayersInRangeSq(x, 0, z, 25, true)) then
            local fx = SpawnPrefab(first and "alterguardian_laserempty" or "alterguardian_laser")
            fx.caster = inst
            fx.Transform:SetPosition(x, 0, z)
            fx:Trigger(0, targets, skiptoss, skipscorch)
            if first then ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30) end
        end
    else
        SpawnPrefab("alterguardian_laserscorch").Transform:SetPosition(x, 0, z)
    end
end
-- ×形激光攻击
local Laser_NUM_STEPS = 10
local SECOND_BLAST_TIME = 22 * FRAMES
local function SpawnNewBeam(inst, target_pos, angleoffset)
    local BEGIN_STEP = Laser_NUM_STEPS / 2
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local angle = math.atan2(iz - target_pos.z, ix - target_pos.x)
    if angleoffset then angle = angle + angleoffset * DEGREES end
    local gx, gy, gz = target_pos:Get()
    gx = gx + BEGIN_STEP * math.cos(angle)
    gz = gz + BEGIN_STEP * math.sin(angle)
    local targets, skiptoss = {}, {}
    local sbtargets, sbskiptoss = {}, {}
    local x, z = nil, nil
    local delay = nil
    local i = -1
    while i < Laser_NUM_STEPS do
        i = i + 1
        delay = math.max(0, i - 1) * FRAMES
        x = gx - i * math.cos(angle)
        z = gz - i * math.sin(angle)
        local first = i == 0
        local x1, z1 = x, z
        inst:DoTaskInTime(delay, laserattack, nil, nil, nil, nil, x1, z1, first, target_pos)
        inst:DoTaskInTime(delay + SECOND_BLAST_TIME, laserattack, true, sbtargets, sbskiptoss, nil, x1, z1, first, target_pos)
        inst:DoTaskInTime(delay + SECOND_BLAST_TIME * 2, laserattack, true, targets, skiptoss, true, x1, z1, first, target_pos)
    end
    inst:DoTaskInTime(i * FRAMES, laserattack, nil, nil, nil, nil, x, z, nil, nil)
    inst:DoTaskInTime((i + 1) * FRAMES, laserattack, nil, nil, nil, nil, x, z, nil, nil)
end
local function dobeamlaserattack(inst)
    if inst:HasTag("swc2hm") then return end
    local target = inst.components.combat.target or FindClosestPlayerToInst(inst, 125, true)
    if target and target:IsValid() then
        local target_pos = target:GetPosition()
        if inst.components.health and inst.components.health:GetPercent() > 0.6 then
            -- 血量>60%:叉形激光(玩家方向±45°两束交叉)
            SpawnNewBeam(inst, target_pos, 45)
            SpawnNewBeam(inst, target_pos, -45)
        else
            -- 血量≤60%:米字激光(玩家方向±45°/0°/90°共四束)
            SpawnNewBeam(inst, target_pos, 45)
            SpawnNewBeam(inst, target_pos, -45)
            SpawnNewBeam(inst, target_pos, 0)
            SpawnNewBeam(inst, target_pos, 90)
        end
    end
end
-- 初代固定叉形激光(其他非时停版本保留):不区分血量,始终向玩家方向±45°两束交叉
local function dobeamlaserattack_old2hm(inst)
    if inst:HasTag("swc2hm") then return end
    local target = inst.components.combat.target or FindClosestPlayerToInst(inst, 125, true)
    if target and target:IsValid() then
        local target_pos = target:GetPosition()
        SpawnNewBeam(inst, target_pos, 45)
        SpawnNewBeam(inst, target_pos, -45)
    end
end
-- 环形激光攻击
local function SpawnNewSweep(inst, target_pos, instposoverride)
    local SWEEP_ANGULAR_LENGTH = 360
    local BASE_SWEEP_DISTANCE = 8
    local gx, gy, gz = inst.Transform:GetWorldPosition()
    if instposoverride then
        gx = instposoverride.x
        gy = instposoverride.y
        gz = instposoverride.z
    end
    local angle = nil
    local dist = nil
    local angle_step_dir = (math.random() < 0.5 and 1 or -1)
    local x_dir = 1
    if target_pos == nil then
        angle = DEGREES * (inst.Transform:GetRotation() + (SWEEP_ANGULAR_LENGTH / 4))
        dist = BASE_SWEEP_DISTANCE
        x_dir = -1
    else
        angle = math.atan2(gz - target_pos.z, gx - target_pos.x) - (SWEEP_ANGULAR_LENGTH * DEGREES / 4)
        dist = math.max(math.sqrt(inst:GetDistanceSqToPoint(target_pos:Get())), 3)
    end
    local num_angle_steps = 40 + RoundBiasedDown((math.abs(dist) - BASE_SWEEP_DISTANCE) / 2) * 4
    local angle_step = (SWEEP_ANGULAR_LENGTH / num_angle_steps) * DEGREES
    local targets, skiptoss = {}, {}
    local sbtargets, sbskiptoss = {}, {}
    local x, z = nil, nil
    local delay = nil
    local i = -1
    while i < num_angle_steps do
        i = i + 1
        delay = math.max(0, i - 1) * FRAMES / 4
        x = gx - (x_dir * dist * math.cos(angle))
        z = gz - dist * math.sin(angle)
        angle = angle + (angle_step_dir * angle_step)
        local first = i == 0
        local x1, z1 = x, z
        inst:DoTaskInTime(delay, laserattack, nil, nil, nil, nil, x1, z1, first, target_pos)
        inst:DoTaskInTime(delay + SECOND_BLAST_TIME, laserattack, true, sbtargets, sbskiptoss, nil, x1, z1, first, target_pos)
        inst:DoTaskInTime(delay + SECOND_BLAST_TIME * 2, laserattack, true, targets, skiptoss, true, x1, z1, first, target_pos)
    end
    inst:DoTaskInTime(i * FRAMES, laserattack, nil, nil, nil, nil, x, z, nil, nil)
    inst:DoTaskInTime((i + 1) * FRAMES, laserattack, nil, nil, nil, nil, x, z, nil, nil)
end
local function dosweeplaserattack(inst)
    if inst:HasTag("swc2hm") then return end
    -- 一道到三道环形激光
    local target = inst.components.combat.target or FindClosestPlayerToInst(inst, 45, true)
    if target and target:IsValid() then
        local target_pos = target:GetPosition()
        SpawnNewSweep(inst, target_pos)
        local itot = target_pos - inst:GetPosition()
        if itot:LengthSq() > 0 then
            local itot_dir, itot_len = itot:GetNormalizedAndLength()
            SpawnNewSweep(inst, target_pos + (itot_dir * 4.5))
            if itot_len > 9 then SpawnNewSweep(inst, target_pos - (itot_dir * 4.5)) end
        end
    end
end
-- -- 回血攻击
-- local function dodaylightattack(inst)
--     if inst.components.health:IsDead() then return end
--     local x, y, z = inst.Transform:GetWorldPosition()
--     SpawnPrefab("moonpulse_fx").Transform:SetPosition(x, y, z)
--     local lights = TheSim:FindEntities(x, y, z, 8, {"daylight"})
--     for _, light in ipairs(lights) do
--         if light and light:IsValid() and light.prefab == "booklight" then
--             light:DoTaskInTime(0, light.Remove)
--             inst.components.health:SetPercent(inst.components.health:GetPercent() + 0.05)
--             return
--         end
--     end
--     local light = SpawnPrefab("booklight")
--     light.persists = false
--     light.Transform:SetPosition(x, y, z)
--     light:SetDuration(TUNING.TOTAL_DAY_TIME / 2)
--     local fx = SpawnPrefab("hotcold_fx")
--     fx.Transform:SetScale(2, 2, 2)
--     fx.AnimState:PlayAnimation("idle3")
--     fx.Transform:SetPosition(x, 0, z)
--     fx:ListenForEvent("animover", fx.Remove)
--     fx:DoTaskInTime(3, fx.Remove)
-- end
AddStategraphPostInit("alterguardian_phase3", function(sg)
    local _doattack3 = sg.events["doattack"].fn
    sg.events["doattack"].fn = function(inst, data, ...)
        if not TheWorld.ismastersim then return _doattack3(inst, data, ...) end
        if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy"))
                and (data.target ~= nil and data.target:IsValid())
                and not (inst:HasTag("swc2hm") and not inst.forcealterguardian2hm)
                and inst:GetDistanceSqToInst(data.target) < TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ then
            if alterguardianmode == -5 and not inst.components.timer:TimerExists("eraser_cd2hm")
                    and inst.components.health:GetPercent() < 0.6 then
                inst.sg:GoToState("eraserflame2hm", data.target)
                return
            end
            if alterguardianmode == -5 and not old_alterguardian and not inst.components.timer:TimerExists("singlelaser_cd2hm") then
                inst.readydosinglelaser2hm = true
                inst.singlelaser_ice2hm = not inst.singlelaser_ice2hm
                inst.components.timer:StartTimer("singlelaser_cd2hm", SINGLELASER_CD2HM)
                inst.sg:GoToState("atk_beam", data.target)
                return
            end
        end
        return _doattack3(inst, data, ...)
    end
    local OnEnteridle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        OnEnteridle(inst, ...)
        trylockseason(inst)
        for _, v in ipairs(AllPlayers) do if v and not v:HasTag("gestalt_possessable") then v:AddTag("gestalt_possessable") end end
    end
    local OnEnteratk_beam = sg.states.atk_beam.onenter
    sg.states.atk_beam.onenter = function(inst, ...)
        OnEnteratk_beam(inst, ...)
        if not TheWorld.ismastersim then return end -- 客户端不执行服务端攻击逻辑
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        if alterguardianmode == -5 then
            -- 单束激光
            if not old_alterguardian and not inst.readydosinglelaser2hm and not inst.components.timer:TimerExists("singlelaser_cd2hm") then
                SpawnPrefab("moonpulse_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
                inst.readydosinglelaser2hm = true
                inst.singlelaser_ice2hm = not inst.singlelaser_ice2hm -- 轮流:这次冰下次火
                inst.components.timer:StartTimer("singlelaser_cd2hm", SINGLELASER_CD2HM)
            end
        else
            if not old_alterguardian and not inst.icetilescd2hmtask and inst.sg.statemem.target ~= nil and math.random() < 0.25 then
                SpawnPrefab("moonpulse_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
                inst.readydoiceattack2hm = true
            end
        end
    end
    AddStateTimeEvent2hm(sg.states.atk_beam, 34 * FRAMES, function(inst)
        if not TheWorld.ismastersim then return end -- 客户端不执行服务端攻击逻辑
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        if alterguardianmode == -5 then
            if inst.readydosinglelaser2hm then
                inst.readydosinglelaser2hm = nil
                local targetpos = inst.sg.statemem.target_pos
                if targetpos == nil then
                    local player = FindClosestPlayerToInst(inst, 36, true)
                    targetpos = player and player:GetPosition()
                end
                local rot = (targetpos and inst:GetAngleToPoint(targetpos) or inst:GetRotation()) * DEGREES
                local can_ice = TheWorld.components.oceanicemanager ~= nil and inst.components.persistent2hm ~= nil and inst.icetilescd2hmtask == nil
                if inst.singlelaser_ice2hm and can_ice then
                    doiceattack(inst, rot) -- 冰激光
                else
                    dofirelaserattack2hm(inst, rot) -- 火激光
                end
                inst.sg:GoToState("idle", true)
            end
        else
            if inst.readydoiceattack2hm then
                inst.readydoiceattack2hm = nil
                local targetpos = inst.sg.statemem.target_pos
                if targetpos == nil then
                    local player = FindClosestPlayerToInst(inst, 36, true)
                    targetpos = player and player:GetPosition()
                end
                doiceattack(inst, (targetpos and inst:GetAngleToPoint(targetpos) or inst:GetRotation()) * DEGREES)
                inst.sg:GoToState("idle", true)
            end
        end
    end)
    local function SpawnStraightBeamPhase3_2hm(inst, target_pos)
        if target_pos == nil then return end
        local ix, iy, iz = inst.Transform:GetWorldPosition()
        local angle = nil
        local gx, gy, gz = nil, 0, nil
        if inst:GetDistanceSqToPoint(target_pos:Get()) < 4 then
            angle = math.atan2(iz - target_pos.z, ix - target_pos.x)
            gx, gy, gz = inst.Transform:GetWorldPosition()
            gx = gx + (2 * math.cos(angle))
            gz = gz + (2 * math.sin(angle))
        else
            angle = math.atan2(iz - target_pos.z, ix - target_pos.x)
            gx, gy, gz = target_pos:Get()
            gx = gx + (4 * 1.0 * math.cos(angle))
            gz = gz + (4 * 1.0 * math.sin(angle))
        end
        local targets, skiptoss = {}, {}
        local sbtargets, sbskiptoss = {}, {}
        local x, z = nil, nil
        local i = -1
        while i < 10 do
            i = i + 1
            x = gx - i * 1.0 * math.cos(angle)
            z = gz - i * 1.0 * math.sin(angle)
            local first = (i == 0)
            local prefab = (i > 0 and "alterguardian_laser") or "alterguardian_laserempty"
            local x1, z1 = x, z
            local trigger_time = math.max(0, i - 1) * FRAMES
            inst:DoTaskInTime(trigger_time, function(inst2)
                local fx = SpawnPrefab(prefab)
                fx.caster = inst2
                fx.Transform:SetPosition(x1, 0, z1)
                fx:Trigger(0, targets, skiptoss)
                if first then ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30) end
            end)
            inst:DoTaskInTime(trigger_time + 22 * FRAMES, function(inst2)
                local fx = SpawnPrefab(prefab)
                fx.caster = inst2
                fx.Transform:SetPosition(x1, 0, z1)
                fx:Trigger(0, sbtargets, sbskiptoss, true)
                if first then ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30) end
            end)
        end
        inst:DoTaskInTime(i * FRAMES, function(inst2)
            local fx = SpawnPrefab("alterguardian_laser")
            fx.Transform:SetPosition(x, 0, z)
            fx:Trigger(0, targets, skiptoss)
        end)
        inst:DoTaskInTime((i + 1) * FRAMES, function(inst2)
            local fx = SpawnPrefab("alterguardian_laser")
            fx.Transform:SetPosition(x, 0, z)
            fx:Trigger(0, targets, skiptoss)
        end)
    end
    if sg.states.atk_beam and sg.states.atk_beam.timeline then
        for i, te in ipairs(sg.states.atk_beam.timeline) do
            if math.abs(te.time - 35 * FRAMES) < 0.001 then
                local origfn = te.fn
                te.fn = function(inst)
                    if not TheWorld.ismastersim then return end
                    if alterguardianmode ~= -5 then return origfn(inst) end
                    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return origfn(inst) end
                    local ipos = inst:GetPosition()
                    local target_pos = inst.sg.statemem.target_pos
                    if target_pos == nil then
                        local angle = inst.Transform:GetRotation() * DEGREES
                        target_pos = ipos + Vector3(2 * math.cos(angle), 0, -2 * math.sin(angle))
                    end
                    local i_to_target = target_pos - ipos
                    if i_to_target:LengthSq() > 0.01 then
                        local TRIBEAM_ANGLEOFF = PI / 5
                        local offpos1 = Vector3(
                            (i_to_target.x * math.cos(TRIBEAM_ANGLEOFF) - i_to_target.z * math.sin(TRIBEAM_ANGLEOFF)) + ipos.x,
                            0,
                            (i_to_target.x * math.sin(TRIBEAM_ANGLEOFF) + i_to_target.z * math.cos(TRIBEAM_ANGLEOFF)) + ipos.z
                        )
                        local offpos2 = Vector3(
                            (i_to_target.x * math.cos(-TRIBEAM_ANGLEOFF) - i_to_target.z * math.sin(-TRIBEAM_ANGLEOFF)) + ipos.x,
                            0,
                            (i_to_target.x * math.sin(-TRIBEAM_ANGLEOFF) + i_to_target.z * math.cos(-TRIBEAM_ANGLEOFF)) + ipos.z
                        )
                        SpawnStraightBeamPhase3_2hm(inst, target_pos)
                        if inst.components.health and inst.components.health:GetPercent() < 0.6 and math.random() < 0.3 then
                            SpawnClawTrackingBeam2hm(inst, inst.sg.statemem.target, ipos, i_to_target:GetNormalized())
                        end
                        SpawnStraightBeamPhase3_2hm(inst, offpos1) -- 左束
                        SpawnStraightBeamPhase3_2hm(inst, offpos2) -- 右束
                    end
                end
                break
            end
        end
    end
    local function SpawnSweepArcPhase3_2hm(inst, center_target)
        local gx, gy, gz = inst.Transform:GetWorldPosition()
        local dist = 8
        local base_angle
        if center_target ~= nil then
            dist = math.max(math.sqrt(inst:GetDistanceSqToPoint(center_target:Get())), 3)
            base_angle = math.atan2(center_target.z - gz, center_target.x - gx) -- boss→目标方向
        else
            base_angle = inst.Transform:GetRotation() * DEGREES
        end
        local SWEEP = 75 * DEGREES
        local STEP = 5 * DEGREES
        local targets, skiptoss = {}, {}
        local sbtargets, sbskiptoss = {}, {}
        local idx = 0
        local start_a = base_angle - SWEEP / 2
        local count = math.floor(SWEEP / STEP)
        for i = 0, count do
            local a = start_a + i * STEP
            local px = gx + dist * math.cos(a)
            local pz = gz + dist * math.sin(a)
            idx = idx + 1
            local delay = idx * FRAMES
            inst:DoTaskInTime(delay, function(inst2)
                local fx = SpawnPrefab("alterguardian_laser")
                fx.caster = inst2
                fx.Transform:SetPosition(px, 0, pz)
                fx:Trigger(0, targets, skiptoss)
            end)
            inst:DoTaskInTime(delay + 22 * FRAMES, function(inst2)
                local fx = SpawnPrefab("alterguardian_laser")
                fx.caster = inst2
                fx.Transform:SetPosition(px, 0, pz)
                fx:Trigger(0, sbtargets, sbskiptoss, true)
            end)
        end
    end
    if sg.states.atk_sweep and sg.states.atk_sweep.timeline then
        for i, te in ipairs(sg.states.atk_sweep.timeline) do
            if math.abs(te.time - 37 * FRAMES) < 0.001 then
                local origfn = te.fn
                te.fn = function(inst)
                    if not TheWorld.ismastersim then return end
                    if alterguardianmode ~= -5 then return origfn(inst) end
                    if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return origfn(inst) end
                    origfn(inst)
                    local target_pos = inst.sg.statemem.target_pos
                    if target_pos ~= nil then
                        local itot = target_pos - inst:GetPosition()
                        if itot:LengthSq() > 0 then
                            local itot_dir = itot:GetNormalized()
                            SpawnSweepArcPhase3_2hm(inst, inst:GetPosition() - (itot_dir * 5))
                        end
                        SpawnStraightBeamPhase3_2hm(inst, target_pos)
                    end
                end
                break
            end
        end
    end
    local OnEnteratk_summon_pre = sg.states.atk_summon_pre.onenter
    sg.states.atk_summon_pre.onenter = function(inst, ...)
        OnEnteratk_summon_pre(inst, ...)
        if inst.candeerice2hm then
            onphase3trapprojectileremove(inst)
        else
            inst.candeerice2hm = true
        end
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        -- 冰面技能暂时注释(有点卡):atk_summon_pre 不再铺冰面
        -- if not (old_alterguardian or banicetiles) then createareaicetiles(inst) end
        -- 环形激光攻击，这个攻击似乎很卡顿，考虑删除
        -- if inst:HasTag("swc2hm") then return end
        -- inst:DoTaskInTime(35 * FRAMES, dosweeplaserattack)
    end
    local OnExitatk_summon_pre = sg.states.atk_summon_pre.onexit
    sg.states.atk_summon_pre.onexit = function(inst, ...)
        if OnExitatk_summon_pre then OnExitatk_summon_pre(inst, ...) end
        if not TheWorld.ismastersim then return end -- 客户端不执行服务端攻击逻辑
        if not inst.sg.statemem.loop_exit or (inst:HasTag("swc2hm") and not inst.forcealterguardian2hm) then return end
        dosweeplaserattack(inst)
    end
    -- AddStateTimeEvent2hm(sg.states.atk_summon_pre, 35 * FRAMES, function(inst)
    --     if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
    --     dosweeplaserattack(inst)
    -- end)
    -- local onenter_atk_summon_loop = sg.states.atk_summon_loop.onenter
    -- sg.states.atk_summon_loop.onenter = function(inst, ...)
    --     onenter_atk_summon_loop(inst, ...)
    --     if inst:HasTag("swc2hm") then return end
    --     if inst.sg.mem.summon_loops == 0 then dodaylightattack(inst) end
    --     inst.daylightidx2hm = (inst.daylightidx2hm or 0) + (inst.sg.mem.summon_loops == 0 and 5 or 1)
    --     if inst.daylightidx2hm >= 5 then
    --         inst.daylightidx2hm = inst.daylightidx2hm - 5
    --         dodaylightattack(inst)
    --     end
    -- end
    -- local OnEnteratk_summon_pst = sg.states.atk_summon_pst.onenter
    -- sg.states.atk_summon_pst.onenter = function(inst, ...)
    --     OnEnteratk_summon_pst(inst, ...)
    -- end
    -- local OnEnteratk_traps = sg.states.atk_traps.onenter
    -- sg.states.atk_traps.onenter = function(inst, ...)
    --     OnEnteratk_traps(inst, ...)
    --     if inst:HasTag("swc2hm") then
    --         inst:DoTaskInTime(35 * FRAMES, dobeamlaserattack)
    --     else
    --         inst:DoTaskInTime(69 * FRAMES, dotrapattack)
    --     end
    -- end
    AddStateTimeEvent2hm(sg.states.atk_traps, 35 * FRAMES, function(inst) if not TheWorld.ismastersim then return end if inst:HasTag("swc2hm") then dobeamlaserattack(inst) end end)
    AddStateTimeEvent2hm(sg.states.atk_traps, 69 * FRAMES, function(inst)
        if not TheWorld.ismastersim then return end -- 客户端不执行服务端攻击逻辑
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        dotrapattack(inst)
    end)
    local OnEnteratk_stab = sg.states.atk_stab.onenter
    sg.states.atk_stab.onenter = function(inst, ...)
        OnEnteratk_stab(inst, ...)
        if inst.candeerice2hm then
            inst.candeerice2hm = nil
            onphase3trapprojectileremove(inst)
        end
        -- if inst:HasTag("swc2hm") then return end
        -- inst:DoTaskInTime(35 * FRAMES, dobeamlaserattack)
    end
    AddStateTimeEvent2hm(sg.states.atk_stab, 35 * FRAMES, function(inst)
        if not TheWorld.ismastersim then return end -- 客户端不执行服务端攻击逻辑
        if inst:HasTag("swc2hm") and not inst.forcealterguardian2hm then return end
        if alterguardianmode == -5 then
            dobeamlaserattack(inst) -- 时停版本天体:血量>60%叉形/≤60%米字
        else
            dobeamlaserattack_old2hm(inst) -- 其他档:初代固定叉形(±45°两束)
        end
    end)
end)

-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- 第四阶段安逸休闲,世界变成秋季-----------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------

local function onphase3deadworkfinished(inst)
    if TUNING.alterguardianseason2hm > 0 then TheWorld:PushEvent("delayrefreshseason2hm") end
    TUNING.alterguardianseason2hm = 0
end
AddPrefabPostInit("alterguardian_phase3deadorb", function(inst)
    inst:AddTag("alterguardian2hm")
    if not TheWorld.ismastersim then return end
    addminimapicon(inst)
    addprototyper(inst)
    inst:DoTaskInTime(0, addseasonlock, 4, true)
end)
AddPrefabPostInit("alterguardian_phase3dead", function(inst)
    inst:AddTag("alterguardian2hm")
    if not TheWorld.ismastersim then return end
    addminimapicon(inst)
    addprototyper(inst)
    inst:DoTaskInTime(0, addseasonlock, 4, true)
    if inst.components.workable then inst.components.workable:SetRequiresToughWork(true) end
    inst:ListenForEvent("onremove", onphase3deadworkfinished)
    if inst.components.lootdropper and TUNING.noalterguardianhat2hm then
        inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00)
        inst.components.lootdropper:AddChanceLoot("alterguardianhat", 1.00)
    end
end)

-- 天体洋葱配方:辉煌制作台(lunar_forge) 普通洋葱*4 + 亮茄壳*4
-- 洋葱图标
AddRecipe2("onion_celestial2hm",
    {Ingredient("onion", 4, nil, nil, "quagmire_onion.tex"), Ingredient("lunarplant_husk", 4)},
    TECH.LUNARFORGING_TWO,
    {nounlock = true, station_tag = "lunar_forge", image = "quagmire_onion.tex"})

-- ==================== 天体洋葱:永久获得buff ====================
-- 吃下天体洋葱后永久获得:叠层(每层3%减伤)召唤50位面伤害月灵
-- 死亡复活、重进游戏都保留(persistent2hm持久化)
local ONION_BUFF_KEY2HM = "onion_celestial2hm"

-- 月灵:50位面伤害
local function SpawnMoonSpiritsOnion2hm(owner, target, count)
    if not owner:IsValid() or not target:IsValid() then return end
    local tx, ty, tz = target.Transform:GetWorldPosition()
    for i = 1, count do
        owner:DoTaskInTime(0.05 * i, function()
            if not owner:IsValid() or not target:IsValid() then return end
            local gestalt = SpawnPrefab("alterguardianhat_projectile")
            if gestalt then
                local angle = math.random() * 2 * math.pi
                local r = math.random(3, 6)
                gestalt.Transform:SetPosition(tx + r * math.cos(angle), ty, tz + r * math.sin(angle))
                gestalt:ForceFacePoint(tx, ty, tz)
                if gestalt.SetTargetPosition then
                    gestalt:SetTargetPosition(Vector3(tx, ty, tz))
                end
                -- 50位面伤害:普通伤害归0,位面伤害50
                if gestalt.components.combat then
                    gestalt.components.combat:SetDefaultDamage(0)
                end
                if gestalt.components.planardamage == nil then
                    gestalt:AddComponent("planardamage")
                end
                if gestalt.components.planardamage then
                    gestalt.components.planardamage:SetBaseDamage(50)
                end
                if gestalt.components.follower then
                    gestalt.components.follower:SetLeader(owner)
                end
                -- 月灵命中目标额外造成0.1%最大生命值伤害(无视护甲,补偿叠层时间5秒→3秒,每个召唤的月灵都生效)
                gestalt:ListenForEvent("onattackother", function(inst, data)
                    local hit = data and data.target
                    if hit and hit:IsValid() and hit.components.health and not hit.components.health:IsDead() then
                        local bonus = hit.components.health.maxhealth * 0.001
                        if bonus > 0 then
                            hit.components.health:DoDelta(-bonus, nil, "alterguardian_phase3", nil, owner)
                        end
                    end
                end)
            end
        end)
    end
end

-- 每层3%百分比减伤(倍率=1-3%×层数,30层=90%减伤)
local function UpdateOnionMoonlightDR(inst)
    if not inst.components.health or not inst.components.health.externalabsorbmodifiers then return end
    local stacks = inst._onion_celestial_moonlight_stacks or 0
    if stacks > 0 then
        inst.components.health.externalabsorbmodifiers:SetModifier(inst, math.max(0.1, 1 - 0.03 * stacks), "onion_celestial2hm")
    else
        inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "onion_celestial2hm")
    end
end

-- 挨打反击数量:1-10层1个,11-20层2个,21-30层3个
local function GetOnionCounterCount(stacks)
    if stacks <= 10 then return 1
    elseif stacks <= 20 then return 2
    else return 3 end
end

-- 应用永久buff
function ApplyOnionCelestialBuff2hm(owner)
    if not owner or not owner:IsValid() or owner._onion_celestial_buff2hm then return end
    owner._onion_celestial_buff2hm = true

    -- 叠层:攻击Boss/怪物叠层(每层3%减伤),3秒不攻击清零,满30层召唤全部月灵;挨打按层数区间1/2/3反击，出个月灵反馈下是挨打了
    owner._onion_celestial_moonlight_stacks = 0
    owner._onion_celestial_moonlight_time = nil

    owner:ListenForEvent("onhitother", function(inst, data)
        if not inst._onion_celestial_buff2hm then return end
        if not data or not data.target or not data.target:IsValid() then return end
        local targ = data.target
        -- 只有攻击Boss(epic)或怪物(monster)才能叠层,打小动物不叠
        if not (targ:HasTag("epic") or targ:HasTag("monster")) then return end
        local now = GetTime()
        if inst._onion_stackcd2hm ~= nil and now - inst._onion_stackcd2hm < 6 * FRAMES then return end
        inst._onion_stackcd2hm = now
        if (inst._onion_celestial_moonlight_stacks or 0) >= 30 then
            local count = inst._onion_celestial_moonlight_stacks
            inst._onion_celestial_moonlight_stacks = 0
            inst._onion_celestial_moonlight_time = nil
            UpdateOnionMoonlightDR(inst)
            SpawnMoonSpiritsOnion2hm(inst, targ, count)
            return
        end
        inst._onion_celestial_moonlight_stacks = (inst._onion_celestial_moonlight_stacks or 0) + 1
        inst._onion_celestial_moonlight_time = GetTime() + 3
        UpdateOnionMoonlightDR(inst)
        if inst._onion_celestial_moonlight_task then
            inst._onion_celestial_moonlight_task:Cancel()
        end
        inst._onion_celestial_moonlight_task = inst:DoTaskInTime(3, function()
            if inst:IsValid() and inst._onion_celestial_buff2hm then
                inst._onion_celestial_moonlight_stacks = 0
                inst._onion_celestial_moonlight_time = nil
                UpdateOnionMoonlightDR(inst)
            end
        end)
    end)

    owner:ListenForEvent("attacked", function(inst, data)
        if not inst._onion_celestial_buff2hm then return end
        if not data or not data.attacker or not data.attacker:IsValid() then return end
        if not data.attacker.components.combat then return end -- 过滤DOT
        local stacks = inst._onion_celestial_moonlight_stacks or 0
        if stacks <= 0 then return end
        local count = GetOnionCounterCount(stacks)
        inst._onion_celestial_moonlight_stacks = 0
        inst._onion_celestial_moonlight_time = nil
        UpdateOnionMoonlightDR(inst)
        if inst._onion_celestial_moonlight_task then
            inst._onion_celestial_moonlight_task:Cancel()
        end
        if count > 0 then
            SpawnMoonSpiritsOnion2hm(inst, data.attacker, count)
        end
    end)
end

-- 吃下天体洋葱:打上永久标记并立即获得buff
AddPrefabPostInit("onion_celestial2hm", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.edible then return end
    local oldoneaten = inst.components.edible.oneaten
    inst.components.edible.oneaten = function(inst, eater, ...)
        if oldoneaten then oldoneaten(inst, eater, ...) end
        if eater and eater:IsValid() and eater:HasTag("player") then
            if not eater.components.persistent2hm then eater:AddComponent("persistent2hm") end
            eater.components.persistent2hm.data = eater.components.persistent2hm.data or {}
            eater.components.persistent2hm.data[ONION_BUFF_KEY2HM] = true
            ApplyOnionCelestialBuff2hm(eater)
        end
    end
end)

-- 重进游戏/复活后恢复永久buff
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    local function tryapply(inst)
        if inst.components.persistent2hm and inst.components.persistent2hm.data and inst.components.persistent2hm.data[ONION_BUFF_KEY2HM] then
            inst:DoTaskInTime(0, function()
                ApplyOnionCelestialBuff2hm(inst)
            end)
        end
    end
    tryapply(inst)
    SetOnLoad2hm(inst, function(inst, data)
        if data and data[ONION_BUFF_KEY2HM] then
            tryapply(inst)
        end
    end)
end)
