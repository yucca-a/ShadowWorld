local assets = {
    Asset("PKGREF", "anim/ui_chester_shadow_3x4.zip"), -- switched to portal version
    Asset("ANIM", "anim/ui_portal_shadow_3x4.zip"),
    Asset("ANIM", "anim/shadow_breath.zip"),
    Asset("ANIM", "anim/tophat_fx.zip"),
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
    Asset("ANIM", "anim/hutch.zip"),
    Asset("ANIM", "anim/hutch_build.zip"),
    Asset("ANIM", "anim/hutch_musicbox_build.zip"),
    Asset("ANIM", "anim/hutch_pufferfish_build.zip"),
    Asset("SOUND", "sound/chester.fsb"),
    Asset("SOUND", "sound/together.fsb"),
    Asset("MINIMAP_IMAGE", "hutch"),
    Asset("MINIMAP_IMAGE", "hutch_musicbox"),
    Asset("MINIMAP_IMAGE", "hutch_pufferfish")
}

local assets_swirl = {Asset("ANIM", "anim/chester.zip"), Asset("ANIM", "anim/tophat_fx.zip")}

local prefabs = {
    "chesterlight",
    "chester_transform_fx",
    "globalmapiconunderfog",
    "frostbreath",
    "shadow_chester_swirl_fx",
    "hutch_fishbowl",
    "hutch_music_light_fx",
    "hutch_move_fx",
    "chester_transform_fx",
    "impact",
    "globalmapiconunderfog"
}

local brain = require "brains/chesterbrain"

local ChesterStateNames = {"NORMAL", "SNOW", "SHADOW"}
local ChesterState = table.invert(ChesterStateNames)

local sounds = {
    sleep = "dontstarve/creatures/together/hutch/sleep",
    hurt = "dontstarve/creatures/together/hutch/hit",
    pant = "dontstarve/creatures/together/hutch/pant",
    death = "dontstarve/creatures/together/hutch/death",
    open = "dontstarve/creatures/together/hutch/open",
    close = "dontstarve/creatures/together/hutch/close",
    pop = "dontstarve/creatures/together/hutch/pop",
    lick = "dontstarve/creatures/together/hutch/lick",
    boing = "dontstarve/creatures/together/hutch/land_hit",
    land = "dontstarve/creatures/together/hutch/land",
    musicbox = "dontstarve/creatures/together/hutch/one_man_band"
}

local WAKE_TO_FOLLOW_DISTANCE = 14
local SLEEP_NEAR_LEADER_DISTANCE = 7

local function ShouldWakeUp(inst) return DefaultWakeTest(inst) or not inst.components.follower:IsNearLeader(WAKE_TO_FOLLOW_DISTANCE) end

local function ShouldSleep(inst)
    return DefaultSleepTest(inst) and not inst.sg:HasStateTag("open") and inst.components.follower:IsNearLeader(SLEEP_NEAR_LEADER_DISTANCE) and
               not TheWorld.state.isfullmoon
end

local function ShouldKeepTarget()
    return false -- chester can't attack, and won't sleep if he has a target
end

local function OnOpen(inst) if not inst.components.health:IsDead() then inst.sg:GoToState("open") end end

local function OnClose(inst)
    if not inst.components.health:IsDead() and inst.sg.currentstate.name ~= "transition" then
        inst.sg.statemem.closing = true
        inst.sg:GoToState("close")
    end
end

-- eye bone was killed/destroyed
local function OnStopFollowing(inst) inst:RemoveTag("companion") end

local function OnStartFollowing(inst) inst:AddTag("companion") end

local function SetBuild(inst)
    -- local skin_build = inst:GetSkinBuild()
    local chester_state = inst._chesterstate:value()
    -- if skin_build ~= nil then
    --     local state =
    --         (chester_state == ChesterState.SHADOW and "_shadow") or (chester_state == ChesterState.SNOW and "_snow") or
    --         ""

    --     inst.AnimState:OverrideItemSkinSymbol(
    --         "chester_body",
    --         skin_build,
    --         "chester_body" .. state,
    --         inst.GUID,
    --         "chester_build"
    --     )
    --     inst.AnimState:OverrideItemSkinSymbol(
    --         "chester_foot",
    --         skin_build,
    --         "chester_foot" .. state,
    --         inst.GUID,
    --         "chester_build"
    --     )
    --     inst.AnimState:OverrideItemSkinSymbol(
    --         "chester_lid",
    --         skin_build,
    --         "chester_lid" .. state,
    --         inst.GUID,
    --         "chester_build"
    --     )
    --     inst.AnimState:OverrideItemSkinSymbol(
    --         "chester_tongue",
    --         skin_build,
    --         "chester_tongue" .. state,
    --         inst.GUID,
    --         "chester_build"
    --     )
    -- else
    --     inst.AnimState:ClearAllOverrideSymbols()

    --     inst.AnimState:SetBuild(
    --         (chester_state == ChesterState.SHADOW and "chester_shadow_build") or
    --             (chester_state == ChesterState.SNOW and "chester_snow_build") or
    --             "chester_build"
    --     )
    -- end
    if chester_state == ChesterState.SHADOW then
        inst.AnimState:AddOverrideBuild("tophat_fx")
        inst.AnimState:SetSymbolMultColour("fx_float", 1, 1, 1, .5)
    else
        inst.AnimState:ClearOverrideBuild("tophat_fx")
        inst.AnimState:SetSymbolMultColour("fx_float", 1, 1, 1, 1)
    end
end

--------------------------------------------------------------------------
-- Frost breath

local DOWN_FACING_ANIMS = {"open", "idle_loop_open", "closed", "hit", "sleep_pre", "sleep_loop", "sleep_pst", "death", "transition"}

local SIDE_FACING_ANIMS = {"chomp", "lick"}

local function GetBreathAnimFacing(inst)
    for i, v in ipairs(DOWN_FACING_ANIMS) do if inst.AnimState:IsCurrentAnimation(v) then return FACING_DOWN end end
    for i, v in ipairs(SIDE_FACING_ANIMS) do if inst.AnimState:IsCurrentAnimation(v) then return FACING_RIGHT end end
    return inst.AnimState:GetCurrentFacing()
end

local function EmitFrost(inst, frostbreath)
    if frostbreath.refreshsortorder then
        local facing = GetBreathAnimFacing(inst)
        if facing == FACING_DOWN then
            frostbreath.fx.VFXEffect:SetSortOrder(0, 1)
            frostbreath.fx2.VFXEffect:SetSortOrder(0, 1)
        elseif facing == FACING_UP then
            frostbreath.fx.VFXEffect:SetSortOrder(0, -1)
            frostbreath.fx2.VFXEffect:SetSortOrder(0, -1)
        else
            frostbreath.fx.VFXEffect:SetSortOrder(0, -1)
            frostbreath.fx2.VFXEffect:SetSortOrder(0, 1)
        end
        frostbreath.refreshsortorder = false
    end
    frostbreath.fx.Follower:SetOffset(math.random() * 20 - 10, math.random() * 15 - 10, 0)
    frostbreath.fx2.Follower:SetOffset(math.random() * 20 - 10, math.random() * 15 - 10, 0)
    frostbreath.fx:Emit()
    frostbreath.fx2:Emit()
    if frostbreath.count > 1 then
        frostbreath.count = frostbreath.count - 1
    else
        frostbreath.count = 0
        frostbreath.task:Cancel()
        frostbreath.task = nil
    end
end

local function DoFrostBreath(inst)
    local frostbreath = inst.frostbreath
    local delay = (inst.AnimState:IsCurrentAnimation("idle_loop") and math.random() + 2) or
                      (inst.AnimState:IsCurrentAnimation("idle_loop_open") and math.random() * .5 + .25) or 0

    if delay > 0 then
        local t = GetTime()
        if frostbreath.lasttime ~= nil and t < frostbreath.lasttime + delay then return end
        frostbreath.lasttime = t
    else
        frostbreath.lasttime = nil
    end

    if frostbreath.task ~= nil then frostbreath.task:Cancel() end
    if inst:HasTag("moving") then
        frostbreath.count = math.random(2, 3)
    else
        frostbreath.count = 1
    end
    frostbreath.refreshsortorder = true
    frostbreath.task = inst:DoPeriodicTask(math.random(4, 5) * FRAMES, EmitFrost, 0, frostbreath)
end

local function PushFrostBreathTrigger(inst) inst._frostbreathtrigger:push() end

local function TriggerAndDoFrostBreath(inst)
    inst._frostbreathtrigger:push()
    DoFrostBreath(inst)
end

local function EnableFrostBreath(inst, enable)
    if enable then
        if inst.frostbreath == nil then
            if TheNet:IsDedicated() then
                inst.frostbreath = true
                -- push the net event, but don't need to show the fx locally
                inst:ListenForEvent("animover", PushFrostBreathTrigger)
            else
                inst.frostbreath = {fx = SpawnPrefab("frostbreath"), fx2 = SpawnPrefab("frostbreath")}
                inst.frostbreath.fx.entity:SetParent(inst.entity)
                inst.frostbreath.fx.entity:AddFollower()
                inst.frostbreath.fx.Follower:FollowSymbol(inst.GUID, "hutch_lure", 0, 0, 0)
                inst.frostbreath.fx2.entity:SetParent(inst.entity)
                inst.frostbreath.fx2.entity:AddFollower()
                inst.frostbreath.fx2.Follower:FollowSymbol(inst.GUID, "hutch_tail", 0, 0, 0)
                if TheWorld.ismastersim then
                    -- push the net event and also show the fx locally
                    inst:ListenForEvent("animover", TriggerAndDoFrostBreath)
                else
                    -- listen for net event because client does not receive
                    -- animover events for server owned networked entities.
                    inst:ListenForEvent("chester._frostbreathtrigger", DoFrostBreath)
                end
            end
        end
    elseif inst.frostbreath ~= nil then
        if inst.frostbreath == true then
            inst:RemoveEventCallback("animover", PushFrostBreathTrigger)
        else
            inst.frostbreath.fx:Remove()
            inst.frostbreath.fx2:Remove()
            if inst.frostbreath.task ~= nil then inst.frostbreath.task:Cancel() end
            if TheWorld.ismastersim then
                inst:RemoveEventCallback("animover", TriggerAndDoFrostBreath)
            else
                inst:RemoveEventCallback("chester._frostbreathtrigger", DoFrostBreath)
            end
        end
        inst.frostbreath = nil
    end
end

--------------------------------------------------------------------------
-- Shadow breath

local function OnShadowBreathAnimOver(inst)
    if inst.pool.invalid then
        inst:Remove()
    else
        inst:Hide()
        table.insert(inst.pool, inst)
    end
end

local function CreateShadowBreath(pool)
    local inst
    if #pool > 0 then
        inst = table.remove(pool)
        inst:Show()
    else
        inst = CreateEntity()

        inst:AddTag("NOCLICK")
        inst:AddTag("FX")
        --[[Non-networked entity]]
        inst.persists = false

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddFollower()

        inst.AnimState:SetBank("shadow_breath")
        inst.AnimState:SetBuild("shadow_breath")
        inst.AnimState:SetMultColour(1, 1, 1, .5)

        inst.pool = pool
        inst:ListenForEvent("animover", OnShadowBreathAnimOver)
    end

    inst.AnimState:PlayAnimation("idle" .. tostring(math.random(3)))
    if math.random() < .5 then inst.AnimState:SetScale(-1, 1) end

    return inst
end

local function ReleaseShadowBreath(fx) fx.Follower:StopFollowing() end

local function EmitShadow(inst, isleft, taskname)
    local facing = GetBreathAnimFacing(inst)
    local fx = CreateShadowBreath(inst.shadowbreath.pool)
    if isleft then
        fx.Follower:FollowSymbol(inst.GUID, "hutch_lure", math.random() * 20 - 10, math.random() * 15 - 10, 0)
        fx.AnimState:SetFinalOffset(facing == FACING_DOWN and 1 or -1)
    else
        fx.Follower:FollowSymbol(inst.GUID, "hutch_tail", math.random() * 20 - 10, math.random() * 15 - 10, 0)
        fx.AnimState:SetFinalOffset(facing == FACING_UP and -1 or 1)
    end
    fx:DoTaskInTime(0, ReleaseShadowBreath)

    local health = inst.replica.health
    inst.shadowbreath[taskname] = not (health ~= nil and health:IsDead()) and inst:DoTaskInTime(.35 + math.random() * .6, EmitShadow, isleft, taskname) or nil
end

local function EnableShadowBreath(inst, enable)
    if enable then
        if inst.shadowbreath == nil and not TheNet:IsDedicated() then
            inst.shadowbreath = {
                pool = {},
                task = inst:DoTaskInTime(math.random() * .6, EmitShadow, true, "task"),
                task2 = inst:DoTaskInTime(math.random() * .6, EmitShadow, false, "task2")
            }
        end
    elseif inst.shadowbreath ~= nil then
        inst.shadowbreath.task:Cancel()
        inst.shadowbreath.task2:Cancel()
        for i, v in ipairs(inst.shadowbreath.pool) do v:Remove() end
        inst.shadowbreath.pool.invalid = true
        inst.shadowbreath = nil
    end
end

--------------------------------------------------------------------------

local function ToggleBreath(inst)
    local state = inst._chesterstate:value()
    EnableFrostBreath(inst, state == ChesterState.SNOW)
    EnableShadowBreath(inst, state == ChesterState.SHADOW)
end

local function AttachShadowContainer(inst) inst.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer("shadow")) end

local function SwitchToContainer(inst)
    if inst.components.container == nil then
        inst:AddComponent("container")
        inst.components.container:WidgetSetup("chester")
        inst.components.container.onopenfn = OnOpen
        inst.components.container.onclosefn = OnClose
        inst.components.container.skipclosesnd = true
        inst.components.container.skipopensnd = true
    end

    inst.components.container_proxy:Close()
    inst.components.container_proxy:SetCanBeOpened(false)
    inst.components.container_proxy:SetMaster(nil)
end

local function SwitchToShadowContainerProxy(inst)
    inst.components.container_proxy:SetOnOpenFn(OnOpen)
    inst.components.container_proxy:SetOnCloseFn(OnClose)
    inst.components.container_proxy:SetCanBeOpened(true)

    -- NOTE: don't check POPULATING here; it's checked before this entire function is called
    AttachShadowContainer(inst)

    local x, y, z = inst.Transform:GetWorldPosition()
    local container = inst.components.container
    if container ~= nil then
        local shadowcontainer = inst.components.container_proxy:GetMaster().components.container
        for i = 1, container:GetNumSlots() do
            local item = container:RemoveItemBySlot(i)
            if item ~= nil then
                item.prevcontainer = nil
                item.prevslot = nil

                if not shadowcontainer:GiveItem(item, i, nil, false) then
                    item.Transform:SetPosition(x, y, z)
                    if item.components.inventoryitem ~= nil then item.components.inventoryitem:OnDropped(true) end
                end
            end
        end
        inst:RemoveComponent("container")
    end
end

local function MorphShadowChester(inst)
    inst:RemoveTag("fridge")
    inst:AddTag("spoiler")
    -- inst.MiniMapEntity:SetIcon("chestershadow.png")
    -- inst.components.maprevealable:SetIcon("chestershadow.png")

    if POPULATING then
        -- For loading legacy save data
        inst.components.container:WidgetSetup("shadowchester")
    else
        SwitchToShadowContainerProxy(inst)
    end

    -- local leader = inst.components.follower.leader
    -- if leader ~= nil then
    --     inst.components.follower.leader:MorphShadowEyebone()
    -- end

    inst.sg.mem.isshadow = true
    inst._chesterstate:set(ChesterState.SHADOW)
    SetBuild(inst)
    ToggleBreath(inst)
end

local function MorphSnowChester(inst)
    inst:RemoveTag("spoiler")
    inst:AddTag("fridge")
    -- inst.MiniMapEntity:SetIcon("chestersnow.png")
    -- inst.components.maprevealable:SetIcon("chestersnow.png")

    SwitchToContainer(inst)

    -- local leader = inst.components.follower.leader
    -- if leader ~= nil then
    --     inst.components.follower.leader:MorphSnowEyebone()
    -- end

    inst.sg.mem.isshadow = nil
    inst._chesterstate:set(ChesterState.SNOW)
    SetBuild(inst)
    ToggleBreath(inst)
end

local function MorphNormalChester(inst)
    inst:RemoveTag("fridge")
    inst:RemoveTag("spoiler")
    -- inst.MiniMapEntity:SetIcon("chester.png")
    -- inst.components.maprevealable:SetIcon("chester.png")

    SwitchToContainer(inst)

    -- local leader = inst.components.follower.leader
    -- if leader ~= nil then
    --     inst.components.follower.leader:MorphNormalEyebone()
    -- end

    inst.sg.mem.isshadow = nil
    inst._chesterstate:set(ChesterState.NORMAL)
    SetBuild(inst)
    ToggleBreath(inst)
end

local function DoMorph(inst, fn) fn(inst) end

local function OnSave(inst, data) data.ChesterState = ChesterStateNames[inst._chesterstate:value()] end

local function OnPreLoad(inst, data)
    local chester_state = data ~= nil and ChesterState[data.ChesterState] or nil
    if chester_state == ChesterState.SHADOW then
        DoMorph(inst, MorphShadowChester)
    elseif chester_state == ChesterState.SNOW then
        DoMorph(inst, MorphSnowChester)
    end
end

local function OnLoadPostPass(inst) if inst._chesterstate:value() == ChesterState.SHADOW then SwitchToShadowContainerProxy(inst) end end

local function OnClientChesterStateDirty(inst) ToggleBreath(inst) end

local function OnHaunt(inst)
    if math.random() <= TUNING.HAUNT_CHANCE_ALWAYS then
        inst.components.hauntable.panic = true
        inst.components.hauntable.panictimer = TUNING.HAUNT_PANIC_TIME_SMALL
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_SMALL
        return true
    end
    return false
end

local function create_chester()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 75, .5)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)

    inst:AddTag("companion")
    inst:AddTag("character")
    inst:AddTag("scarytoprey")
    inst:AddTag("hutch")
    inst:AddTag("notraptrigger")
    inst:AddTag("noauradamage")

    inst.MiniMapEntity:SetIcon("hutch.png")
    inst.MiniMapEntity:SetCanUseCache(false)

    inst.AnimState:SetBank("hutch")
    inst.AnimState:SetBuild("hutch_build")
    inst.AnimState:Hide("fx_lure_light")

    inst.DynamicShadow:SetSize(2, 1.5)

    inst.Transform:SetFourFaced()

    inst._chesterstate = net_tinybyte(inst.GUID, "chester._chesterstate", "chesterstatedirty")
    inst._chesterstate:set(ChesterState.NORMAL)

    inst._frostbreathtrigger = net_event(inst.GUID, "chester._frostbreathtrigger")

    inst:AddComponent("container_proxy")
    inst.components.container_proxy:SetCanBeOpened(false)

    inst:SetPrefabNameOverride("hutch")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("chesterstatedirty", OnClientChesterStateDirty)
        return inst
    end

    ------------------------------------------
    inst:AddComponent("maprevealable")
    inst.components.maprevealable:SetIconPrefab("globalmapiconunderfog")

    inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "chester_body"
    inst.components.combat:SetKeepTargetFunction(ShouldKeepTarget)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.CHESTER_HEALTH)
    inst.components.health:StartRegen(TUNING.CHESTER_HEALTH_REGEN_AMOUNT, TUNING.CHESTER_HEALTH_REGEN_PERIOD)

    inst:AddComponent("inspectable")
    inst.components.inspectable:RecordViews()

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 3
    inst.components.locomotor.runspeed = 7
    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("embarker")
    inst:AddComponent("drownable")

    inst:AddComponent("follower")
    inst:ListenForEvent("stopfollowing", OnStopFollowing)
    inst:ListenForEvent("startfollowing", OnStartFollowing)

    inst:AddComponent("knownlocations")

    MakeSmallBurnableCharacter(inst, "chester_body")

    SwitchToContainer(inst)

    inst:AddComponent("sleeper")
    inst.components.sleeper.watchlight = true
    inst.components.sleeper:SetResistance(3)
    inst.components.sleeper.testperiod = GetRandomWithVariance(6, 2)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    MakeHauntableDropFirstItem(inst)
    AddHauntableCustomReaction(inst, OnHaunt, false, false, true)

    inst.sounds = sounds

    inst:SetStateGraph("SGchester")
    inst.sg:GoToState("idle")

    inst:SetBrain(brain)

    inst.OnSave = OnSave
    inst.OnPreLoad = OnPreLoad
    inst.OnLoadPostPass = OnLoadPostPass
    inst.SetBuild = SetBuild -- NOTES(JBK): This is for skins.

    return inst
end

STRINGS.NAMES.SHADOWHUTCH2HM = STRINGS.NAMES.HUTCH

return Prefab("shadowhutch2hm", create_chester, assets, prefabs)
