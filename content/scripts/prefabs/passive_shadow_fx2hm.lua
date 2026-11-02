--[[
Copyright (C) 2018 Forged Forge

This file is part of Forged Forge.

The source code of this program is shared under the RECEX
SHARED SOURCE LICENSE (version 1.0).
The source code is shared for referrence and academic purposes
with the hope that people can read and learn from it. This is not
Free and Open Source software, and code is not redistributable
without permission of the author. Read the RECEX SHARED
SOURCE LICENSE for details
The source codes does not come with any warranty including
the implied warranty of merchandise.
You should have received a copy of the RECEX SHARED SOURCE
LICENSE in the form of a LICENSE file in the root of the source
directory. If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>
]]
local assets = {
    Asset("ANIM", "anim/lavaarena_shadow_lunge.zip"),
    Asset("ANIM", "anim/waxwell_shadow_mod.zip"),
    Asset("ANIM", "anim/swap_nightmaresword_shadow.zip"),
	Asset("ANIM", "anim/waxwell_minion_idle.zip"),
    -- 亮茄剑升级影人可手持的随机武器动画(客户端需声明才能显示)
    Asset("ANIM", "anim/swap_spear.zip"),
    Asset("ANIM", "anim/swap_spike.zip"),
    Asset("ANIM", "anim/swap_ham_bat.zip"),
    Asset("ANIM", "anim/swap_nightmaresword.zip"),
    Asset("ANIM", "anim/swap_glasscutter.zip"),
    Asset("ANIM", "anim/swap_ruins_bat.zip"),
    Asset("ANIM", "anim/swap_eye_shield.zip"),
    Asset("ANIM", "anim/sword_lunarplant.zip"),
}
local prefabs = {
    "statue_transition_2",
    "shadowstrike_slash_fx",
    "shadowstrike_slash2_fx",
    "weaponsparks_thrusting_fx",
}
--------------------------------------------------------------------------
local function StartShadows(inst) -- TODO possibly make a stategraph for shadows?
	SpawnPrefab("statue_transition_2").Transform:SetPosition(inst.Transform:GetWorldPosition())
	inst.AnimState:PlayAnimation("lunge_pre")
	inst.AnimState:PushAnimation("lunge_lag")
	inst.AnimState:PushAnimation("lunge_pst")

	inst:DoTaskInTime(12*FRAMES, function(inst)
		inst.Physics:SetMotorVel(30, 0, 0)
	end)
	inst:DoTaskInTime(15*FRAMES, function(inst)
		inst.components.combat:DoAttack(inst.target, nil, nil, "strong")--"shadow")
	end)
	inst:DoTaskInTime(22*FRAMES, function(inst)
		inst.Physics:ClearMotorVelOverride()
	end)
	inst:DoTaskInTime(35*FRAMES, function(inst)
		inst:Remove()
	end)
end

local maxvalue = 5
local duration = 12
local shadow_erosionnum = 0.03
local function adddebufftarget(inst, target)
	if target and target:IsValid() and target.components.combat then
		local value = target.shadow_erosion2hm or 0
		target.shadow_erosion2hm = math.min(value + 1, maxvalue)
		if target.components.combat then
			target.components.combat.externaldamagetakenmultipliers:SetModifier(target, 1 + shadow_erosionnum * target.shadow_erosion2hm, "shadow_erosion2hm")
		end
		if target.cancelshadowerosiontask2hm then
			target.cancelshadowerosiontask2hm:Cancel()
		end
		target.cancelshadowerosiontask2hm = target:DoTaskInTime(math.random(duration, duration + 2), function(_target)
			if _target.components.combat then
				_target.components.combat.externaldamagetakenmultipliers:RemoveModifier(_target, "shadow_erosion2hm")
			end
			target.shadow_erosion2hm = nil
			target.cancelshadowerosiontask2hm = nil
		end)
	end
end
--------------------------------------------------------------------------
local function fn()
    local inst = CreateEntity()
	inst.entity:AddTransform()
	------------------------------------------
	inst.entity:AddAnimState()
	inst.AnimState:SetBank("wilson")
	inst.AnimState:SetBuild("waxwell")
	------------------------------------------
	inst.entity:AddNetwork()
	------------------------------------------
	inst.entity:AddSoundEmitter()
	inst.entity:AddPhysics()
	------------------------------------------
	inst.Transform:SetFourFaced(inst)
	------------------------------------------
	inst.AnimState:AddOverrideBuild("lavaarena_shadow_lunge")
	inst.AnimState:SetMultColour(0, 0, 0, .5)
	inst.AnimState:OverrideSymbol("swap_object", "swap_nightmaresword_shadow", "swap_nightmaresword_shadow")
	inst.AnimState:Hide("HAT")
	inst.AnimState:Hide("HAIR_HAT")
	------------------------------------------
	-- 可换武器: 亮茄剑升级影人用(net同步到客户端显示), 值格式 "build|symbol|sym"(sym为玩家身上要覆盖的symbol,默认swap_object;盾牌为lantern_overlay)
	inst._shadow_weaponbuild2hm = net_string(inst.GUID, "passiveshadow.weaponbuild2hm", "weaponbuilddirty2hm")
	inst:ListenForEvent("weaponbuilddirty2hm", function()
		local w = inst._shadow_weaponbuild2hm:value()
		if w ~= nil and w ~= "" then
			local wb, ws, wsym = w:match("([^|]+)|([^|]+)|([^|]+)")
			if wb then
				if wsym and wsym ~= "swap_object" then
					inst.AnimState:HideSymbol("swap_object") -- 盾牌类不显示武器槽
				else
					inst.AnimState:ShowSymbol("swap_object")
				end
				inst.AnimState:OverrideSymbol(wsym or "swap_object", wb, ws or wb)
			end
		end
	end)
	------------------------------------------
	inst.Physics:SetMass(1)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(5)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:ClearCollisionMask()
	inst.Physics:CollidesWith(COLLISION.GROUND)
	inst.Physics:SetCapsule(.5, 1)
	------------------------------------------
	inst:AddTag("scarytoprey")
	inst:AddTag("NOBLOCK")
	inst:AddTag("FX")
	------------------------------------------
    if not TheWorld.ismastersim then
        return inst
    end
	------------------------------------------
	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(11)
	------------------------------------------
	inst:AddComponent("skinner")
	inst.components.skinner:SetupNonPlayerData()
	-- inst.SetOwner = function(inst, owner)
	-- 	inst.owner = owner
	-- 	if owner and owner.components.combat then
	-- 		owner.components.combat:CopyBuffsTo(inst)
	-- 	end
	-- end
	------------------------------------------
	inst.SetDamage = function(inst, value) inst.components.combat:SetDefaultDamage(value or 17) end
	-- 亮茄剑升级影人: 指定手持武器的build|symbol|sym(客户端同步显示)
	inst.SetShadowWeapon2hm = function(inst, build, symbol, sym)
		inst._shadow_weaponbuild2hm:set(build .. "|" .. (symbol or build) .. "|" .. (sym or "swap_object"))
	end
	-- 亮茄剑升级影人: 记录主人(附加效果用)+复制玩家角色外观与皮肤(同附魔暗影刀,skinner网络同步客户端显示)
	inst.SetShadowOwner2hm = function(inst, player)
		inst._shadow_owner2hm = player
		if player and player:HasTag("player") and inst.components.skinner then
			inst.components.skinner:CopySkinsFromPlayer(player)
		end
	end
	inst.SetShadowEffect2hm = function(inst, effectfn)
		inst._shadow_effect2hm = effectfn
	end
    inst.SetTarget = function(inst, target, offset)
		inst.target = target
		inst.offset = offset or {x = 0, y = 0, z = 0}
        if inst.target then
    		local target_pos = target:GetPosition()
    		inst.Transform:SetPosition((target_pos + offset):Get())
    		inst:FacePoint(target_pos)
    		StartShadows(inst)
        else -- Remove if no target
            inst:Remove()
        end
	end
	------------------------------------------
	inst:ListenForEvent("onhitother", function(inst, data)
		-- Spawn Hit FX
		local fx = SpawnPrefab(math.random(1,2) == 1 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx") -- TODO check these, are they client side?
		fx.Transform:SetPosition(data.target:GetPosition():Get())
		fx.Transform:SetRotation(inst.Transform:GetRotation())

		local spark_offset_mult = 0.25
		local spark = SpawnPrefab("weaponsparks_thrusting")
		spark.Transform:SetPosition((data.target:GetPosition() + inst.offset * spark_offset_mult):Get())
		spark.Transform:SetRotation(spark:GetAngleToPoint(data.target:GetPosition():Get()) + 90)
		if inst.shouldcostsanity then
			adddebufftarget(inst, data.target)
		end
		-- 亮茄剑升级影人: 命中后触发武器专属附加效果(流血/回三维/易伤/辉煌标记/触手/减伤/boss百分比)
		if inst._shadow_effect2hm and inst._shadow_owner2hm then
			inst._shadow_effect2hm(inst._shadow_owner2hm, data.target)
		end
        -- COMMON_FNS.CreateFX("weaponsparks_thrusting_fx", data.target, inst)
	end)
	inst.persists = false
	------------------------------------------
    return inst
end
--------------------------------------------------------------------------
return Prefab("passive_shadow_fx2hm", fn, assets, prefabs)
