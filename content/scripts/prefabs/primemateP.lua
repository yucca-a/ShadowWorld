local assets =
{
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    Asset("ANIM", "anim/ds_pig_elite.zip"),
    Asset("ANIM", "anim/ds_pig_boat_jump.zip"),
    Asset("ANIM", "anim/ds_pig_monkey.zip"),
    Asset("ANIM", "anim/monkeymen_build.zip"),

    --for water fx build overrides
    Asset("ANIM", "anim/slide_puff.zip"),
    Asset("ANIM", "anim/splash_water_rot.zip"),

    Asset("SOUND", "sound/monkey.fsb"),
}

local prefabs =
{
    "poop",
    "monkeyprojectile",
    "smallmeat",
    "cave_banana",
    "pirate_stash",
    "monkey_mediumhat",
    "stash_map",
    "cursed_monkey_token",
	"oar_monkey",
}

local brain = require "brains/primematebrainP"

local SLEEP_DIST_FROMHOME = 1
local SLEEP_DIST_FROMTHREAT = 20
local MAX_CHASEAWAY_DIST = 80
local MAX_TARGET_SHARES = 5
local SHARE_TARGET_DIST = 40


local function _ForgetTarget(inst)
    inst.components.combat:SetTarget(nil)
end

local MONKEY_TAGS = { "monkey" }
local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    if inst.task ~= nil then
        inst.task:Cancel()
    end
    inst.task = inst:DoTaskInTime(math.random(55, 65), _ForgetTarget) --Forget about target after a minute

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 30, MONKEY_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and v.components.combat then
            v.components.combat:SuggestTarget(data.attacker)
            if v.task ~= nil then
                v.task:Cancel()
            end
            v.task = v:DoTaskInTime(math.random(55, 65), _ForgetTarget) --Forget about target after a minute
        end
    end
end

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "playerghost", "player" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }
local function retargetfn(inst)
    return FindEntity(
                inst,
                20,
                function(guy)
                    if guy:HasTag("monkey") then
                        return nil
                    end
                    return inst.components.combat:CanTarget(guy) and inst:GetCurrentPlatform() and inst:GetCurrentPlatform() == guy:GetCurrentPlatform() 
                end,
                RETARGET_MUST_TAGS, --see entityreplica.lua
                RETARGET_CANT_TAGS,
                RETARGET_ONEOF_TAGS
            )
        or nil
end

local function shouldKeepTarget(inst)
    --[[if inst:HasTag("nightmare") then
        return true
    end]]
    return true
end

local function OnPickup(inst, data)
	local item = data ~= nil and data.item or nil
    if item ~= nil and
        item.components.equippable ~= nil and
        item.components.equippable.equipslot == EQUIPSLOTS.HEAD and
        not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) then
        --Ugly special case for how the PICKUP action works.
        --Need to wait until PICKUP has called "GiveItem" before equipping item.
        inst:DoTaskInTime(0, function()
            if item:IsValid() and
                item.components.inventoryitem ~= nil and
                item.components.inventoryitem.owner == inst then
                inst.components.inventory:Equip(item)
            end
        end)
    end
end

local function OnDropItem(inst, data)
	if data ~= nil and data.item ~= nil then
		data.item:RemoveTag("personal_possession")
	end
	if data ~= nil and data.item ~= nil and data.item.prefab == "oar_monkey" then
		data.item:Remove()
	end
end

local function OnSave(inst, data)
	if inst.components.inventory then
		local personal_item = {}
		for k, v in pairs(inst.components.inventory.itemslots) do
			if v.persists and v:HasTag("personal_possession") then
				personal_item[k] = v.prefab
			end
		end
		local personal_equip = {}
		for k, v in pairs(inst.components.inventory.equipslots) do
			if v.persists and v:HasTag("personal_possession") then
				personal_equip[k] = v.prefab
			end
		end
		data.personal_item = next(personal_item) ~= nil and personal_item or nil
		data.personal_equip = next(personal_equip) ~= nil and personal_equip or nil
	end
	-------------------------------------------------------------
	if inst.components.follower and inst.components.follower.leader then
		local leader = inst.components.follower.leader
		if leader:IsValid() then
			data.leader_guid = leader.GUID 
			data.leader_prefab = leader.prefab  
		end
	end
end

local function OnLoad(inst, data)
	if data ~= nil then
		if data.personal_item ~= nil then
			for k, v in pairs(data.personal_item) do
				local item = inst.components.inventory:GetItemInSlot(k)
				if item ~= nil and item.prefab == v then
					item:AddTag("personal_possession")
				end
			end
		end
		if data.personal_equip ~= nil then
			for k, v in pairs(data.personal_equip) do
				local item = inst.components.inventory:GetEquippedItem(k)
				if item ~= nil and item.prefab == v then
					item:AddTag("personal_possession")
				end
			end
		end
		if data.leader_guid then
			local leader = Ents[data.leader_guid]  -- 通过全局实体表查找
		elseif data.leader_prefab then
			-- 如果 GUID 失效，尝试通过 prefab 找回（如玩家角色）
			local leader = FindEntityByPrefab(data.leader_prefab)
		end
	end
end

local function getboattargetscore(inst,boat)
    local score = 0
    for k in pairs(boat.components.walkableplatform:GetEntitiesOnPlatform()) do
        if k:HasTag("player") then
            score = score + 10
        end
        if k:HasTag("inventoryitem") then
            score = score + 1
        end
    end
    return score
end


local function speech_override_fn(inst, speech)
    if not ThePlayer or ThePlayer:HasTag("wonkey") then
        return speech
    else
        return CraftMonkeySpeech()
    end 
end

local function battlecry(combatcmp, target)
    local strtbl = nil
    
    if target ~= nil then
        if target:HasTag("monkey") ~= nil then
            strtbl = "MONKEY_MONKEY_BATTLECRY"
        elseif target.components.inventory ~= nil and target.components.inventory:NumItems() > 0 then
            strtbl = "MONKEY_STUFF_BATTLECRY"
        else
            strtbl = "MONKEY_BATTLECRY"
        end

        return strtbl, math.random(#STRINGS[strtbl])
    end
end

local function onmonkeychange(inst, data)
    if data and data.player then
        if inst.components.combat and inst.components.combat.target and inst.components.combat.target == data.player then
            inst.components.combat:DropTarget()
        end
    end
end

local function ontalk(inst, script)
    inst.SoundEmitter:PlaySound("monkeyisland/primemate/speak")
end

local function OnGetItemFromPlayer(inst, giver, item)
	if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
	local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		if current ~= nil then
			inst.components.inventory:DropItem(current)
		end
		inst.components.inventory:Equip(item)
		inst.AnimState:Show("hat")
	end
end

local function ShouldAcceptItem(inst, item)
	if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
		return true
	end
end

local SCRAPBOOK_HIDE_SYMBOLS = { "hat", "ARM_carry_up" }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(2, 1.25)

    inst.Transform:SetFourFaced()

    MakeCharacterPhysics(inst, 10, 0.25)

    inst.AnimState:SetBank("pigman")
    inst.AnimState:SetBuild("monkeymen_build")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.Transform:SetScale(1.2,1.2,1.2)

    inst.AnimState:Hide("ARM_carry_up")

    inst.AnimState:OverrideSymbol("fx_slidepuff01", "slide_puff", "fx_slidepuff01")
    inst.AnimState:OverrideSymbol("splash_water_rot", "splash_water_rot", "splash_water_rot")
    inst.AnimState:OverrideSymbol("fx_water_spot", "splash_water_rot", "fx_water_spot")
    inst.AnimState:OverrideSymbol("fx_splash_wide", "splash_water_rot", "fx_splash_wide")
    inst.AnimState:OverrideSymbol("fx_water_spray", "splash_water_rot", "fx_water_spray")

    inst:AddTag("character")
    inst:AddTag("monkey")
	inst:AddTag("scarytoprey")
    inst:AddTag("pirate")

    inst:AddComponent("talker")
    inst.components.talker.fontsize = 35
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.offset = Vector3(0, -400, 0)
    inst.components.talker:MakeChatter()
    inst.components.talker.ontalk = ontalk    

    inst.speech_override_fn = speech_override_fn

    inst.entity:SetPristine()

	inst.displaynamefn = function() 
        return (TUNING.isCh2hm and "大副") or "Prime Mate"
    end

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_hide = SCRAPBOOK_HIDE_SYMBOLS

    inst.soundtype = ""

    MakeMediumBurnableCharacter(inst,"pig_torso")
    MakeMediumFreezableCharacter(inst)

    inst:AddComponent("bloomer")

    inst:AddComponent("inventory")

    inst:AddComponent("inspectable")
	inst:SetPrefabNameOverride("prime_mate")

    inst:AddComponent("thief")

    inst:AddComponent("workmultiplier")
    inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP, 0.25, "hard2hm")
    inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE, 0.1, "hard2hm")
	
	inst:AddComponent("follower") -- 添加跟随者组件
	inst.components.follower.keepdeadleader = true -- 誓死追随玩家
	
	inst:AddComponent("trader") -- 可以给头部装备
	inst.components.trader:SetAcceptTest(ShouldAcceptItem)
	inst.components.trader.onaccept = OnGetItemFromPlayer
	inst.components.trader.deleteitemonaccept = false

    inst:AddComponent("locomotor")
    inst.components.locomotor:SetSlowMultiplier( 1 )
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = { ignorecreep = false }
    inst.components.locomotor.walkspeed = TUNING.MONKEY_MOVE_SPEED * 0.75

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.PRIME_MATE_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.PRIME_MATE_ATTACK_PERIOD)
    inst.components.combat:SetRange(TUNING.MONKEY_MELEE_RANGE)
    inst.components.combat:SetRetargetFunction(1, retargetfn)
    inst.components.combat:AddNoAggroTag("player")
    inst.components.combat.GetBattleCryString = battlecry

    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)
    inst.components.combat:SetDefaultDamage(51)  --This doesn't matter, monkey uses weapon damage

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.PRIME_MATE_HEALTH)

    inst:AddComponent("timer")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable(nil)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })

    inst:AddComponent("sleeper")
    inst.components.sleeper.sleeptestfn = onmonkeychange
    inst.components.sleeper.waketestfn = DefaultWakeTest

    inst:AddComponent("drownable")

    inst:SetBrain(brain)
    inst:SetStateGraph("SGprimemate")

    inst:AddComponent("knownlocations")

    inst:ListenForEvent("onpickupitem", OnPickup)
	inst:ListenForEvent("dropitem", OnDropItem)
    inst:ListenForEvent("attacked", OnAttacked)

    MakeHauntablePanic(inst)

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad


    return inst
end

return Prefab("prime_mate_p", fn, assets, prefabs)
