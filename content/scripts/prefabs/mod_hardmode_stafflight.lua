local function kill_sound(inst) inst.SoundEmitter:KillSound("staff_star_loop") end

local function kill_light(inst)
    inst.AnimState:PlayAnimation("disappear")
    inst:ListenForEvent("animover", kill_sound)
    inst:DoTaskInTime(1, inst.Remove) -- originally 0.6, padded for network
    inst.persists = false
    inst._killed = true
end

local function ontimer(inst, data) if data.name == "extinguish" then kill_light(inst) end end

local function findotherheaterorfire(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
    local heater = FindEntity(inst, 5, function(guy)
        return guy.components.heater and not guy.components.inventoryitem and not guy:HasTag("player") and
                   ((inst.is_hot and guy.components.heater:IsEndothermic()) or (not inst.is_hot and guy.components.heater:IsExothermic()))
    end, {"HASHEATER"})
    local fire = FindEntity(inst, 5, function(guy)
        return guy.components.burnable and not guy.components.inventoryitem and not guy:HasTag("player") and
                   ((inst.is_hot and inst:HasTag("blueflame")) or (not inst.is_hot and not inst:HasTag("blueflame")))
    end, {"fire"})
		----------------       热源启迪头消除矮星加强          ---------------------------------------------------------------
	local players = TheSim:FindEntities(x, y, z, 5, {"player"})
    local alterguardianhat
    if players and next(players) ~= nil then
        for _, player in ipairs(players) do
            if player.components.inventory then
                local hashat = player.components.inventory:FindItems(function(item) return item.prefab == "alterguardianhat" and item:HasTag("HASHEATER") end)
                if hashat and next(hashat) ~= nil then alterguardianhat = true break end
            end
        end
    end
    
	local alterguardianhatonground = FindEntity(inst,5,function(guy)  --  检测热源启迪头是否在地面上
	    return guy:HasTag("HASHEATER") and guy.prefab == "alterguardianhat" 
	end,{"HASHEATER"})

    if heater or fire or (alterguardianhat or alterguardianhatonground) then
        kill_light(inst)
        return
    end
    local player = FindEntity(inst, 15, function(guy) return not guy:HasTag("playerghost") end, nil, nil, {"epic", "player"})
    if player then
        local x, y, z = player.Transform:GetWorldPosition()
        inst.Transform:SetPosition(x + math.random() * 5 - 2.5, y, z + math.random() * 5 - 2.5)
    end
end

local function onhaunt(inst)
    if inst.components.timer:TimerExists("extinguish") then
        inst.components.timer:StopTimer("extinguish")
        kill_light(inst)
    end
    return true
end

local function makestafflight(name, overridename, is_hot, anim, colour, idles, is_fx)
    local assets = {Asset("ANIM", "anim/" .. anim .. ".zip")}

    local PlayRandomStarIdle = #idles > 1 and function(inst)
        -- Don't if we're extinguished
        if not inst._killed then inst.AnimState:PlayAnimation(idles[math.random(#idles)]) end
    end or nil

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.is_hot = is_hot

        inst.AnimState:SetBank(anim)
        inst.AnimState:SetBuild(anim)
        inst.AnimState:PlayAnimation("appear")
        if #idles == 1 then inst.AnimState:PushAnimation(idles[1], true) end
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

        -- HASHEATER (from heater component) added to pristine state for optimization
        inst:AddTag("HASHEATER")

        inst:AddTag("ignorewalkableplatforms")
        inst:SetPhysicsRadiusOverride(.5)
        inst.no_wet_prefix = true

        if is_hot then
            inst.SoundEmitter:PlaySound("dontstarve/common/staff_star_LP", "staff_star_loop", nil, not TheWorld.ismastersim)
            inst.AnimState:SetMultColour(1, 0.75, 0.75, 0.25)
        else
            inst.SoundEmitter:PlaySound("dontstarve/common/staff_coldlight_LP", "staff_star_loop", nil, not TheWorld.ismastersim)
            inst.AnimState:SetMultColour(0.75, 0.75, 1, 0.5)
        end

        inst:SetPrefabNameOverride(overridename)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst:DoTaskInTime(math.random() * 2 + 0.25, function() inst:DoPeriodicTask(2.25, findotherheaterorfire) end)

        inst:AddComponent("heater")
        if is_hot then
            inst.components.heater.heat = 100
        else
            inst.components.heater.heat = -100
            inst.components.heater:SetThermics(false, true)
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("hauntable")
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_SMALL)
        inst.components.hauntable:SetOnHauntFn(onhaunt)

        inst:AddComponent("timer")
        inst.components.timer:StartTimer("extinguish", is_hot and TUNING.YELLOWSTAFF_STAR_DURATION / 8 or TUNING.OPALSTAFF_STAR_DURATION / 4)
        inst:ListenForEvent("timerdone", ontimer)

        inst.SoundEmitter:PlaySound("dontstarve/common/staff_star_create")

        if #idles > 1 then inst:ListenForEvent("animover", PlayRandomStarIdle) end

        return inst
    end

    return Prefab(name, fn, assets)
end

local idles = {"idle_loop", "idle_loop2", "idle_loop3"}
local function PlayRandomStarIdle(inst) if not inst._killed then inst.AnimState:PlayAnimation(idles[math.random(#idles)]) end end
local FIRE_CANT_TAGS = {"INLIMBO", "lighter"}
local FIRE_ONEOF_TAGS = {"fire", "smolder"}
local function deericefx(inst)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    local time = inst.name2hm == "WELLFED" and 2.25 or 1.5
    local spell = SpawnPrefab("deer_ice_circle")
    if spell.TriggerFX then spell:DoTaskInTime(0.75, spell.TriggerFX) end
    local x, y, z = inst.Transform:GetWorldPosition()
    spell.Transform:SetPosition(x, y, z)
    spell:DoTaskInTime(time, spell.KillFX or spell.Remove)
    if inst.deathindex2hm then
        SpawnPrefab("crab_king_shine").Transform:SetPosition(inst.Transform:GetWorldPosition())
        local fires = TheSim:FindEntities(x, y, z, TUNING.BOOK_FIRE_RADIUS / 2, nil, FIRE_CANT_TAGS, FIRE_ONEOF_TAGS)
        if #fires > 0 then for i, fire in ipairs(fires) do if fire.components.burnable then fire.components.burnable:Extinguish(true, 0) end end end
    end
    if inst.deathindex2hm and inst.deathindex2hm >= (inst.deathmax2hm or 4) and inst.boss2hm and inst.boss2hm:IsValid() and inst.boss2hm.coldlightdeath2hm then
        kill_light(inst)
        if inst.boss2hm.components.health and not inst.boss2hm.components.health:IsDead() then
            inst.boss2hm.components.health:DoDelta(inst.boss2hm.components.health.maxhealth * 0.1)
        end
        inst.boss2hm.coldlightdeath2hm = nil
        local fx = SpawnPrefab("spider_heal_target_fx")
        fx.Transform:SetNoFaced()
        fx.Transform:SetPosition(x, y, z)
        local x, y, z = inst.boss2hm.Transform:GetWorldPosition()
        fx = SpawnPrefab("spider_heal_target_fx")
        fx.Transform:SetNoFaced()
        fx.Transform:SetPosition(x, y, z)
        fx.Transform:SetScale(3, 3, 3)
    end
end
local function iceboss(inst)
    inst.index2hm = ((inst.index2hm or 0) + 1) % 4
    if inst.boss2hm and inst.boss2hm:IsValid() and inst.boss2hm.Transform and inst.boss2hm.components and inst.boss2hm.components.health and
        not inst.boss2hm.components.health:IsDead() then
        if inst.disappear2hm then inst.disappear2hm = nil end
        -- 这次闪烁是否要发动自杀式攻击，自杀式攻击会贴近敌人
        local percent = inst.boss2hm.components.health:GetPercent()
        if percent < 0.35 and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target and
            (inst.deathindex2hm or not inst.boss2hm.coldlightdeath2hm) and inst.boss2hm.components.combat.target.Transform and
            inst.boss2hm.components.combat.target.components and inst.boss2hm.components.combat.target.components.freezable and
            not inst.boss2hm.components.combat.target.components.freezable:IsFrozen() and inst.boss2hm:IsNear(inst.boss2hm.components.combat.target, 20) then
            inst.deathindex2hm = (inst.deathindex2hm or 0) + 1
            inst.boss2hm.coldlightdeath2hm = true
            if percent < 0.1 then
                inst.deathmax2hm = 1
            elseif percent < 0.15 then
                inst.deathmax2hm = 2
            elseif percent < 0.25 then
                inst.deathmax2hm = 3
            elseif inst.deathmax2hm then
                inst.deathmax2hm = nil
            end
            local x, y, z = inst.boss2hm.components.combat.target.Transform:GetWorldPosition()
            if inst.name2hm ~= "CRAFTY" then x, z = x + math.random() * 4 - 2, z + math.random() * 4 - 2 end
            if inst:IsNear(inst.boss2hm, 100) then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", 8)
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil, Vector3(x, y, z)))
            else
                inst.Transform:SetPosition(x, y, z)
            end
        else
            -- 其他情况则随便位置闪烁
            if inst:IsNear(inst.boss2hm, 100) then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                if inst.boss2hm.components and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", (inst.index2hm == 0 or inst.deathindex2hm) and 4 or 2)
                else
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "2hm")
                end
                local x, y, z = inst.boss2hm.Transform:GetWorldPosition()
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                    Vector3(x + math.random() * 16 - 8, y, z + math.random() * 16 - 8)))
            else
                inst.Transform:SetPosition(inst.boss2hm.Transform:GetWorldPosition())
            end
        end
        -- 战斗中每第四次闪烁会延迟发动冰阵
        if inst.boss2hm.components and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target then
            if not inst.battle2hm then inst.battle2hm = true end
            if inst.index2hm == 0 or inst.deathindex2hm then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
            else
                inst.AnimState:SetMultColour(1, 1, 1, 0.25 * inst.index2hm)
            end
            if inst.deathindex2hm then
                local shinefx = SpawnPrefab("crab_king_shine")
                shinefx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            end
            if inst.index2hm == 0 or (inst.deathindex2hm and inst.deathmax2hm and inst.deathindex2hm >= inst.deathmax2hm) then
                local time = 1.5
                if inst.deathindex2hm then time = time - inst.deathindex2hm * 0.25 end
                if inst.name2hm == "PLAYFUL" then time = time - 0.25 end
                inst:DoTaskInTime(time, deericefx)
                local fx = SpawnPrefab("deer_ice_flakes")
                fx.entity:SetParent(inst.entity)
                fx:DoTaskInTime(time, fx.KillFX or fx.Remove)
                local stafffx = SpawnPrefab("staffcastfx")
                stafffx.entity:SetParent(inst.entity)
                stafffx:SetUp({64 / 255, 64 / 255, 208 / 255})
            end
        else
            if inst.battle2hm then
                inst.battle2hm = nil
                inst.AnimState:SetMultColour(1, 1, 1, 0.25)
            end
            if inst.deathindex2hm then inst.deathindex2hm = nil end
            if inst.boss2hm.coldlightdeath2hm then inst.boss2hm.coldlightdeath2hm = nil end
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "2hm")
        inst.deathindex2hm = nil
        local boss = FindEntity(inst, 35, nil, {"deerclops"}, {"swc2hm"})
        if boss and boss:IsValid() and boss.Transform and boss.components.health and not boss.components.health:IsDead() then
            inst.boss2hm = boss
            local x, y, z = boss.Transform:GetWorldPosition()
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                Vector3(x + math.random() * 16 - 8, y, z + math.random() * 16 - 8)))
            inst.AnimState:SetMultColour(1, 1, 1, 0.25)
        else
            if not inst.disappear2hm then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
                inst.disappear2hm = 0
            end
            inst.disappear2hm = inst.disappear2hm + 1
            if inst.disappear2hm >= 10 then
                kill_light(inst)
                return
            end
            local player = FindEntity(inst, 15, function(guy) return not guy:HasTag("playerghost") end, {"player"})
            if player then
                local x, y, z = player.Transform:GetWorldPosition()
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                    Vector3(x + math.random() * 5 - 2.5, y, z + math.random() * 5 - 2.5)))
            end
        end
    end
end

local function OnSave(inst, data) data.index2hm = inst.index2hm end
local function OnLoad(inst, data) if data then inst.index2hm = data.index2hm or math.random(1, 4) end end

-- 好斗的温度更低，丰满的喷发更久,活泼的喷发更快,灵巧的位置更精准
local namelist = {"COMBAT", "WELLFED", "PLAYFUL", "CRAFTY", "COMBAT", "PLAYFUL", "CRAFTY"}
local function DisplayNameFn(inst) return (STRINGS.UI.HUD.CRITTER_TRAITS[inst.name2hm] or "") .. STRINGS.NAMES[string.upper(inst.nameoverride)] end

local coldassets = {Asset("ANIM", "anim/star_cold.zip")}
local function staffcoldlight2hm()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, .5)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("star_cold")
    inst.AnimState:SetBuild("star_cold")
    inst.AnimState:PlayAnimation("appear")
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    -- HASHEATER (from heater component) added to pristine state for optimization
    inst:AddTag("HASHEATER")
    inst:AddTag("staffcoldlight2hm")
    inst:AddTag("ignorewalkableplatforms")
    inst:SetPhysicsRadiusOverride(.5)
    inst.no_wet_prefix = true

    inst.SoundEmitter:PlaySound("dontstarve/common/staff_coldlight_LP", "staff_star_loop", nil, not TheWorld.ismastersim)
    inst.AnimState:SetMultColour(1, 1, 1, 0.25)
    if inst.name2hm == "WELLFED" then inst.AnimState:SetScale(1.25, 1.25) end

    inst:SetPrefabNameOverride("staffcoldlight")
    inst.name2hm = namelist[math.random(#namelist)]
    inst.displaynamefn = DisplayNameFn
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:DoPeriodicTask(2.5, iceboss)

    inst:AddComponent("heater")
    inst.components.heater.heat = inst.name2hm == "COMBAT" and -225 or -150
    inst.components.heater:SetThermics(false, true)

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 10
    inst.components.locomotor.directdrive = true
    inst.components.locomotor.slowmultiplier = 1
    inst.components.locomotor.fastmultiplier = 1
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = {ignorecreep = true}

    inst:AddComponent("inspectable")

    inst.SoundEmitter:PlaySound("dontstarve/common/staff_star_create")

    inst:ListenForEvent("animover", PlayRandomStarIdle)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

local function deerfirefx(inst)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    local time = inst.name2hm == "WELLFED" and 2.25 or 1.5
    local spell = SpawnPrefab("deer_fire_circle")
    if spell.TriggerFX then spell:DoTaskInTime(0.75, spell.TriggerFX) end
    local x, y, z = inst.Transform:GetWorldPosition()
    spell.Transform:SetPosition(x, y, z)
    spell:DoTaskInTime(time, spell.KillFX or spell.Remove)
    if inst.deathindex2hm then
        local shinefx = SpawnPrefab("crab_king_shine")
        shinefx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    if inst.deathindex2hm and inst.deathindex2hm >= 3 and inst.boss2hm and inst.boss2hm:IsValid() and inst.boss2hm.coldlightdeath2hm then
        kill_light(inst)
        if inst.boss2hm.components.health and not inst.boss2hm.components.health:IsDead() then
            inst.boss2hm.components.health:DoDelta(inst.boss2hm.components.health.maxhealth * 0.1)
        end
        inst.boss2hm.coldlightdeath2hm = nil
        local fx = SpawnPrefab("spider_heal_target_fx")
        fx.Transform:SetNoFaced()
        fx.Transform:SetPosition(x, y, z)
        local x, y, z = inst.boss2hm.Transform:GetWorldPosition()
        fx = SpawnPrefab("spider_heal_target_fx")
        fx.Transform:SetNoFaced()
        fx.Transform:SetPosition(x, y, z)
        fx.Transform:SetScale(3, 3, 3)
    end
end
local function fireboss(inst)
    inst.index2hm = ((inst.index2hm or 0) + 1) % 3
    if inst.boss2hm and inst.boss2hm:IsValid() and inst.boss2hm.Transform and inst.boss2hm.components and inst.boss2hm.components.health and
        not inst.boss2hm.components.health:IsDead() then
        if inst.disappear2hm then inst.disappear2hm = nil end
        -- 这次闪烁是否要发动自杀式攻击，自杀式攻击会贴近敌人
        if inst.boss2hm.components.health:GetPercent() < 0.35 and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target and
            (inst.deathindex2hm or not inst.boss2hm.coldlightdeath2hm) and inst.boss2hm.components.combat.target.Transform and
            inst.boss2hm.components.combat.target.components and inst.boss2hm.components.combat.target.components.freezable and
            not inst.boss2hm.components.combat.target.components.freezable:IsFrozen() and inst.boss2hm:IsNear(inst.boss2hm.components.combat.target, 20) then
            inst.deathindex2hm = (inst.deathindex2hm or 0) + 1
            inst.boss2hm.coldlightdeath2hm = true
            local x, y, z = inst.boss2hm.components.combat.target.Transform:GetWorldPosition()
            if inst.name2hm ~= "CRAFTY" then x, z = x + math.random() * 6 - 3, z + math.random() * 6 - 3 end
            if inst:IsNear(inst.boss2hm, 100) then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", 8)
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil, Vector3(x, y, z)))
            else
                inst.Transform:SetPosition(x, y, z)
            end
        else
            if inst.boss2hm.components.health and inst.boss2hm.components.health:GetPercent() >= 0.9 then
                inst:Remove()
                return
            end
            -- 其他情况则随便位置闪烁
            if inst:IsNear(inst.boss2hm, 100) then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                if inst.boss2hm.components and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "2hm", (inst.index2hm == 0 or inst.deathindex2hm) and 6 or 1.5)
                else
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "2hm")
                end
                local x, y, z = inst.boss2hm.Transform:GetWorldPosition()
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                    Vector3(x + math.random() * 18 - 9, y, z + math.random() * 18 - 9)))
            else
                inst.Transform:SetPosition(inst.boss2hm.Transform:GetWorldPosition())
            end
        end
        -- 战斗中每第三次闪烁会延迟发动火阵
        if inst.boss2hm.components and inst.boss2hm.components.combat and inst.boss2hm.components.combat.target then
            if not inst.battle2hm then inst.battle2hm = true end
            if inst.index2hm == 0 or inst.deathindex2hm then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
            else
                inst.AnimState:SetMultColour(1, 1, 1, 0.35 * inst.index2hm)
            end
            if inst.index2hm == 0 then
                local time = 1.5
                if inst.deathindex2hm then time = time - inst.deathindex2hm * 0.25 end
                if inst.name2hm == "PLAYFUL" then time = time - 0.25 end
                inst:DoTaskInTime(time, deerfirefx)
                local fx = SpawnPrefab("deer_fire_flakes")
                fx.entity:SetParent(inst.entity)
                fx:DoTaskInTime(time, fx.KillFX or fx.Remove)
                local stafffx = SpawnPrefab("staffcastfx")
                stafffx.entity:SetParent(inst.entity)
                stafffx:SetUp({223 / 255, 208 / 255, 69 / 255})
            end
        else
            if inst.battle2hm then
                inst.battle2hm = nil
                inst.AnimState:SetMultColour(1, 1, 1, 0.25)
            end
            if inst.deathindex2hm then inst.deathindex2hm = nil end
            if inst.boss2hm.coldlightdeath2hm then inst.boss2hm.coldlightdeath2hm = nil end
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "2hm")
        inst.deathindex2hm = nil
        local boss = FindEntity(inst, 35, nil, {"dragonfly"}, {"swc2hm"})
        if boss and boss:IsValid() and boss.Transform and boss.components.health and not boss.components.health:IsDead() then
            inst.boss2hm = boss
            if inst.boss2hm.components.health and inst.boss2hm.components.health:GetPercent() >= 0.9 then
                inst:Remove()
                return
            end
            local x, y, z = boss.Transform:GetWorldPosition()
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                Vector3(x + math.random() * 18 - 9, y, z + math.random() * 18 - 9)))
            inst.AnimState:SetMultColour(1, 1, 1, 0.25)
        else
            if not inst.disappear2hm then
                inst.AnimState:SetMultColour(1, 1, 1, 1)
                inst.disappear2hm = 0
            end
            inst.disappear2hm = inst.disappear2hm + 1
            if inst.disappear2hm >= 10 then
                kill_light(inst)
                return
            end
            local player = FindEntity(inst, 15, function(guy) return not guy:HasTag("playerghost") end, {"player"})
            if player then
                local x, y, z = player.Transform:GetWorldPosition()
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                inst.components.locomotor:PushAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil,
                                                                    Vector3(x + math.random() * 5 - 2.5, y, z + math.random() * 5 - 2.5)))
            end
        end
    end
end

local hotassets = {Asset("ANIM", "anim/star_hot.zip")}
local function staffhotlight2hm()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, .5)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("star_hot")
    inst.AnimState:SetBuild("star_hot")
    inst.AnimState:PlayAnimation("appear")
    inst.AnimState:PushAnimation("idle_loop", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    -- HASHEATER (from heater component) added to pristine state for optimization
    inst:AddTag("HASHEATER")
    inst:AddTag("staffhotlight2hm")
    inst:AddTag("ignorewalkableplatforms")
    inst:SetPhysicsRadiusOverride(.5)
    inst.no_wet_prefix = true

    inst.SoundEmitter:PlaySound("dontstarve/common/staff_star_LP", "staff_star_loop", nil, not TheWorld.ismastersim)
    inst.AnimState:SetMultColour(1, 1, 1, 0.25)
    if inst.name2hm == "WELLFED" then inst.AnimState:SetScale(1.25, 1.25) end

    inst:SetPrefabNameOverride("stafflight")
    inst.name2hm = namelist[math.random(#namelist)]
    inst.displaynamefn = DisplayNameFn
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:DoPeriodicTask(3.333, fireboss)

    inst:AddComponent("heater")
    inst.components.heater.heat = inst.name2hm == "COMBAT" and 225 or 150

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 10
    inst.components.locomotor.directdrive = true
    inst.components.locomotor.slowmultiplier = 1
    inst.components.locomotor.fastmultiplier = 1
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = {ignorecreep = true}

    inst:AddComponent("inspectable")

    inst.SoundEmitter:PlaySound("dontstarve/common/staff_star_create")

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return makestafflight("mod_hardmode_stafflight", "staffcoldlight", true, "star_hot", {223 / 255, 208 / 255, 69 / 255}, {"idle_loop"}, false),
       makestafflight("mod_hardmode_staffcoldlight", "stafflight", false, "star_cold", {64 / 255, 64 / 255, 208 / 255},
                      {"idle_loop", "idle_loop2", "idle_loop3"}, false), Prefab("staffcoldlight2hm", staffcoldlight2hm, coldassets),
       Prefab("staffhotlight2hm", staffhotlight2hm, hotassets)
