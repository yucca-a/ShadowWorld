local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("walter")
local skilltreedefs = require "prefabs/skilltree_defs"

-- 沃尔特受伤害时不再损失理智
if GetModConfigData("Walter No Damage Lose Sanity") then
    TUNING.WALTER_HUNGER = TUNING.WILSON_HUNGER
    TUNING.WALTER_SANITY_DAMAGE_RATE = 0
    TUNING.WALTER_SANITY_DAMAGE_OVERTIME_RATE = 0
end

-- 沃尔特正常领养宠物
if GetModConfigData("Walter Has Other Pet") then
    AddPrefabPostInit("walter", function(inst)
        inst:RemoveTag("allergictobees")
        if not TheWorld.ismastersim then return end
        inst.components.petleash:SetMaxPets(1)
    end)
    if TUNING.DSTU then
        local function makewobyeatmore(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.eater then inst.components.eater:SetDiet({FOODTYPE.MONSTER, FOODTYPE.MEAT}, {FOODTYPE.MONSTER, FOODTYPE.MEAT}) end
        end
        AddPrefabPostInit("wobysmall", makewobyeatmore)
        AddPrefabPostInit("wobybig", makewobyeatmore)
    end
end

-- 沃尔特收回沃比
if GetModConfigData("Walter Hide Woby") then
    require("actions")
    ACTIONS.WHISTLE.priority = -1
    local function showwoby(woby, inst)
        inst.components.persistent2hm.data.hidewoby = nil
        inst:RemoveTag("hidewoby2hm")
        inst:RemoveChild(woby)
        woby:ReturnToScene()
        woby.Transform:SetPosition(inst.Transform:GetWorldPosition())
        woby.Transform:SetRotation(inst.Transform:GetRotation())
        if woby.components.brain ~= nil and BrainManager then BrainManager:Wake(woby) end
        if woby.sg and not (woby.components.health and woby.components.health:IsDead()) then woby.sg:GoToState("idle") end
        if woby.components.hunger then woby.components.hunger:Resume() end
        if woby.hungerrefreshtask2hm then
            woby.hungerrefreshtask2hm:Cancel()
            woby.hungerrefreshtask2hm = nil
        end
    end
    local function hungerrefresh(woby)
        woby.components.hunger:DoDelta(0)
        woby.hungerrefreshtaskidx2hm = woby.hungerrefreshtaskidx2hm + 1
        if woby.hungerrefreshtaskidx2hm > 10 and woby.hungerrefreshtask2hm then
            woby.hungerrefreshtask2hm:Cancel()
            woby.hungerrefreshtask2hm = nil
        end
    end
    local function hidewoby(woby, inst, refreshhunger)
        inst.components.persistent2hm.data.hidewoby = true
        inst:AddTag("hidewoby2hm")
        inst:AddChild(woby)
        woby.Transform:SetPosition(0, 0, 0) -- make sure we're centered, so poop lands in the right spot!
        woby.Transform:SetRotation(0)
        woby:RemoveFromScene()
        if woby.components.brain ~= nil and BrainManager then BrainManager:Hibernate(woby) end
        if woby.SoundEmitter ~= nil then woby.SoundEmitter:KillAllSounds() end
        if woby.components.hunger then woby.components.hunger:Pause() end
        if TUNING.DSTU and refreshhunger then
            woby.hungerrefreshtaskidx2hm = 0
            woby.hungerrefreshtask2hm = woby:DoPeriodicTask(1, hungerrefresh)
        end
    end
    AddRightSelfAction("walter", 1, "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "walter" and act.doer.woby and act.doer.woby:IsValid() and act.doer.components.persistent2hm then
            if act.doer.woby:IsInLimbo() then
                if not act.doer.components.persistent2hm.data.hidewoby then return false end
                local fx = SpawnPrefab(act.doer.woby.prefab == "wobysmall" and "spawn_fx_small" or "spawn_fx_medium")
                fx.Transform:SetPosition(act.doer.Transform:GetWorldPosition())
                if act.doer.woby.components.colourtweener then
                    act.doer.woby.components.colourtweener:StartTween({1, 1, 1, 1}, 13 * FRAMES, function() showwoby(act.doer.woby, act.doer) end)
                else
                    showwoby(act.doer.woby, act.doer)
                end
                return true
            elseif act.doer.components.persistent2hm.data.hidewoby ~= true and
                not (act.doer.woby.components.health and act.doer.woby.components.health:IsDead()) then
                local fx = SpawnPrefab(act.doer.woby.prefab == "wobysmall" and "spawn_fx_small" or "spawn_fx_medium")
                fx.Transform:SetPosition(act.doer.woby.Transform:GetWorldPosition())
                if act.doer.woby.components.colourtweener then
                    act.doer.woby.components.colourtweener:StartTween({0, 0, 0, 1}, 13 * FRAMES, function() hidewoby(act.doer.woby, act.doer) end)
                else
                    hidewoby(act.doer.woby, act.doer)
                end
                return true
            end
        end
    end, STRINGS.NAMES.WOBYSMALL, nil, nil, function(inst)
		if inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) then
			return true
		end
		return false
	end)
    local function fixwoby(inst)
        if not TheWorld.ismastersim then return end
        local LinkToPlayer = inst.LinkToPlayer
        inst.LinkToPlayer = function(inst, player, ...)
            LinkToPlayer(inst, player, ...)
            if player and player:IsValid() and player.prefab == "walter" and player.components.persistent2hm and player.components.persistent2hm.data.hidewoby then
                inst:DoTaskInTime(0, hidewoby, player, true)
            end
        end
        local FinishTransformation = inst.FinishTransformation
        inst.FinishTransformation = function(inst, ...)
            local player = inst._playerlink
            if inst:IsInLimbo() and player and player:IsValid() and player.prefab == "walter" and player.components.persistent2hm and
                player.components.persistent2hm.data.hidewoby then showwoby(inst, player) end
            FinishTransformation(inst, ...)
        end
    end
    AddPrefabPostInit("wobysmall", fixwoby)
    AddPrefabPostInit("wobybig", fixwoby)
    -- 限制隐藏时沃尔特的右键动作
    if TUNING.DSTU then
        local function OnSetOwner(inst)
            if inst.components.playeractionpicker ~= nil then
                local rightclickoverride = inst.components.playeractionpicker.rightclickoverride
                if rightclickoverride and ACTIONS.WOBY_COMMAND then
                    inst.components.playeractionpicker.rightclickoverride = function(inst, ...)
                        local actions, usedefault = rightclickoverride(inst, ...)
                        if actions and actions[1] and actions[1].action == ACTIONS.WOBY_COMMAND and inst:HasTag("hidewoby2hm") then
                            table.remove(actions, 1)
                            usedefault = true
                        end
                        return actions, usedefault
                    end
                end
                local pointspecialactionsfn = inst.components.playeractionpicker.pointspecialactionsfn
                if pointspecialactionsfn and ACTIONS.WOBY_HERE and ACTIONS.WOBY_STAY then
                    inst.components.playeractionpicker.pointspecialactionsfn = function(inst, ...)
                        local actions, pos2 = pointspecialactionsfn(inst, ...)
                        if actions and (actions[1] == ACTIONS.WOBY_HERE or actions[1] == ACTIONS.WOBY_STAY) and inst:HasTag("hidewoby2hm") then
                            table.remove(actions, 1)
                        end
                        return actions, pos2
                    end
                end
            end
        end
        AddPrefabPostInit("walter", function(inst) inst:ListenForEvent("setowner", OnSetOwner) end)
    end
end

-- 沃尔特弹弓移动攻击
local slingshotmode = GetModConfigData("Walter Throw Slingshot First Attack")
if slingshotmode then
    if slingshotmode == -1 then modimport("easy_role/attackaction.lua") end
    AddPrefabPostInit("walter", function(inst)
        if slingshotmode == -1 then inst:AddTag("slingshot_gym2hm") end
        if TUNING.DSTU and TUNING.WIXIE_HEALTH then
            if not TheWorld.ismastersim then return end
            if inst.starting_inventory and not table.contains(inst.starting_inventory, "slingshot") then
                table.insert(inst.starting_inventory, "slingshot")
            end
            if inst.starting_inventory and not table.contains(inst.starting_inventory, "slingshotammo_rock") then
                for index = 1, 10 do table.insert(inst.starting_inventory, "slingshotammo_rock") end
            end
        end
    end)
    if TUNING.DSTU and TUNING.WIXIE_HEALTH then
        -- 蓄力攻击时如果有简易血条，血条位置下移，从而显示蓄力进度
        local function dychealthbarfix2hm(userid)
            for index, player in ipairs(AllPlayers) do
                if player and player:IsValid() and player.userid == userid then
                    if player.dychealthbar and player.dychealthbar:IsValid() and not player.dychealthbar.changepos2hm then
                        player.dychealthbar.changepos2hm = true
                        local x, y, z = player.dychealthbar.Transform:GetWorldPosition()
                        player.dychealthbar.Transform:SetPosition(x, 0, z)
                        player.dychealthbar.dychbheight = 0
                        player.dychealthbar.dychbheightconst = 0
                        if player.dychealthbar.SetHBHeight then player.dychealthbar:SetHBHeight(0x0) end
                        if player.dychealthbar.graphicHealthbar and player.dychealthbar.graphicHealthbar.SetYOffSet then
                            player.dychealthbar.graphicHealthbar:SetYOffSet(-0x2d, true)
                        end
                    end
                    break
                end
            end
        end
        AddClientModRPCHandler("MOD_HARDMODE", "dychealthbarfix2hm", dychealthbarfix2hm)
        -- wixie只有空手攻击才能击退敌人了,弹弓攻击不再击退敌人了(已注释,恢复原版击退)
        local function processslingshotsg(sg)
            -- local attack = sg.actionhandlers[ACTIONS.ATTACK].deststate
            -- sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
            --     if inst:HasTag("troublemaker") and (inst.prefab ~= "wixie" or (inst.replica.combat ~= nil and inst.replica.combat:GetWeapon() ~= nil)) then
            --         inst:RemoveTag("troublemaker")
            --         local result = attack(inst, action, ...)
            --         inst:AddTag("troublemaker")
            --         return result
            --     end
            --     return attack(inst, action, ...)
            -- end
            if sg.states.slingshot_charge then
                local onenter = sg.states.slingshot_charge.onenter
                sg.states.slingshot_charge.onenter = function(inst, ...)
                    if onenter then onenter(inst, ...) end
                    if inst.dychealthbar and inst.dychealthbar:IsValid() and not inst.dychealthbar.changepos2hm then
                        inst.dychealthbar.changepos2hm = true
                        if inst.userid and TheWorld.ismastersim and TheNet:IsDedicated() then
                            SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "dychealthbarfix2hm"), nil, inst.userid)
                        else
                            local x, y, z = inst.dychealthbar.Transform:GetWorldPosition();
                            inst.dychealthbar.Transform:SetPosition(x, 0, z);
                            inst.dychealthbar.dychbheight = 0;
                            inst.dychealthbar.dychbheightconst = 0;
                            if inst.dychealthbar.SetHBHeight then inst.dychealthbar:SetHBHeight(0x0) end
                            if inst.dychealthbar.graphicHealthbar and inst.dychealthbar.graphicHealthbar.SetYOffSet then
                                inst.dychealthbar.graphicHealthbar:SetYOffSet(-0x2d, true)
                            end
                        end
                    end
                end
            end
        end
        AddStategraphPostInit("wilson", processslingshotsg)
        AddStategraphPostInit("wilson_client", processslingshotsg)
        -- 弹弓可以同时进行原版攻击和妥协攻击了,帮助勋章兼容妥协，帮助妥协兼容勋章
        -- 三种弹弓上限效果和伤害，为爽未改动前，原始弹弓第34帧起单发2倍伤害，gnasher弹弓第24帧起单发2倍伤害,matilda弹弓第28帧三连发每发1.75倍伤害
        -- 为爽困难模式把三连发每发伤害削弱伤害到0.85倍伤害
        local _umsendmedal, _simplesendum
        local function cancelslingshotdmgfix2hm(inst)
            inst.slingshotdmgfixtask2hm = nil
            inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "slingshotdmgfix2hm")
        end
        local function matildadelaydoattack(owner, target, inst)
            if target and target:IsValid() and inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.weapon and
                inst.components.weapon.projectile then
                local owner = inst.components.inventoryitem.owner
                if owner:IsValid() and owner:HasTag("player") and owner.components.combat and owner == doer then
                    _umsendmedal = true
                    owner.components.combat:DoAttack(target)
                    _umsendmedal = nil
                end
            end
        end
        AddPrefabPostInitAny(function(inst)
            if not TheWorld.ismastersim then return end
            -- wixie的弹弓(wixie_weapon)不参与改造,保持原版贴脸击退
            if inst:HasTag("slingshot") and not inst:HasTag("wixie_weapon") and inst.components.weapon and inst.components.spellcaster and -- and inst.components.spellcaster.spell2hm
            inst.components.spellcaster.spell then
                inst.components.weapon:SetDamage(0)
                inst.components.weapon:SetRange(math.max(TUNING.SLINGSHOT_DISTANCE, 10), math.max(TUNING.SLINGSHOT_DISTANCE_MAX, 14))
                local spell = inst.components.spellcaster.spell
                local newspell = function(inst, target, pos, doer, ...)
                    if doer and doer:IsValid() and doer.slingshotdmgfixtask2hm then
                        doer.slingshotdmgfixtask2hm:Cancel()
                        doer.slingshotdmgfixtask2hm = nil
                        doer.components.combat.externaldamagemultipliers:RemoveModifier(doer, "slingshotdmgfix2hm")
                    end
                    if not _simplesendum then
                        -- 妥协蓄力攻击尝试发射勋章子弹 _umsendmedal
						local ammo = inst.components.weapon and inst.components.weapon.projectile and inst.components.weapon.projectile .. "_secondary"
                        if (ammo == nil or (GLOBAL.Prefabs and not GLOBAL.Prefabs[ammo])) and not inst.prefab == "slingshot_matilda" then
                            if target and target:IsValid() and inst.components.inventoryitem and inst.components.inventoryitem.owner then
                                local owner = inst.components.inventoryitem.owner
                                if owner:IsValid() and owner:HasTag("player") and owner.components.combat and owner == doer then
                                    for i = 1, inst.slingshot_amount do
                                        owner:DoTaskInTime((i / 10) - 0.1, matildadelaydoattack, target, inst)
                                    end
                                    if inst.powerlevel and not doer.slingshotdmgfixtask2hm and doer.components.combat and
                                        doer.components.combat.externaldamagemultipliers then
                                        doer.components.combat.externaldamagemultipliers:SetModifier(doer, hardmode and inst.slingshot_amount and
                                                                                                         inst.slingshot_amount > 1 and 0.85 or
                                                                                                         (1 + (inst.powerlevel / 2)), "slingshotdmgfix2hm")
                                        doer.slingshotdmgfixtask2hm = doer:DoTaskInTime(1.25, cancelslingshotdmgfix2hm)
                                    end
                                end
                            end
                            return
                        end
                    end
                    spell(inst, target, pos, doer, ...)
                    if hardmode and doer and doer:IsValid() and doer.components.combat then doer.components.combat:RestartCooldown() end
                    -- 连发子弹,则每发伤害削弱到0.85倍;普攻发射妥协专属子弹时，每发伤害削弱到1倍
                    if (hardmode and inst.slingshot_amount and inst.slingshot_amount > 1 or _simplesendum) and inst.powerlevel and doer and doer:IsValid() and
                        not doer.slingshotdmgfixtask2hm and doer.components.combat and doer.components.combat.externaldamagemultipliers then
                        doer.components.combat.externaldamagemultipliers:SetModifier(doer, (_simplesendum and 1 or 0.85) / (1 + (inst.powerlevel / 2)),
                                                                                     "slingshotdmgfix2hm")
                        doer.slingshotdmgfixtask2hm = doer:DoTaskInTime(1.25, cancelslingshotdmgfix2hm)
                    end
                end
                inst.components.spellcaster.spell = newspell
                local onprojectilelaunched = inst.components.weapon.onprojectilelaunched
                inst.components.weapon:SetOnProjectileLaunched(function(inst, attacker, target, proj, ...)
                    if proj == nil and spell then
                        -- 原版普攻尝试发射妥协专属子弹 _simplesendum
                        if not _umsendmedal and target and target:IsValid() and attacker ~= nil and target ~= attacker and inst.components.inventoryitem and
                            attacker == inst.components.inventoryitem.owner then
                            inst.powerlevel = 1
                            inst.slingshot_amount = 1
                            local pos = target:GetPosition()
                            attacker.wixiepointx = pos.x
                            attacker.wixiepointy = pos.y
                            attacker.wixiepointz = pos.z
                            _simplesendum = true
                            newspell(inst, target, pos, attacker)
                            _simplesendum = nil
                        end
                    elseif proj ~= nil and onprojectilelaunched then
                        onprojectilelaunched(inst, attacker, target, proj, ...)
                        if not _umsendmedal and attacker and attacker:IsValid() and attacker.slingshotdmgfixtask2hm then
                            attacker.slingshotdmgfixtask2hm:Cancel()
                            attacker.slingshotdmgfixtask2hm = nil
                            attacker.components.combat.externaldamagemultipliers:RemoveModifier(attacker, "slingshotdmgfix2hm")
                        end
                    end
                end)
            end
        end)
		-- 兼容妥协沃尔特可制作技能树子弹
		-- AddRecipePostInit("slingshotammo_stinger", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "wixie_slingshot_ammo_stinger"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_dreadstone", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "wixie_slingshot_ammo_dreadstone"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_scrapfeather", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "wixie_slingshot_ammo_scrapfeather"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_gunpowder", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "wixie_slingshot_ammo_gunpowder"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_purebrilliance", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "skill_wixie_allegiance_lunar"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_lunarplanthusk", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "skill_wixie_allegiance_lunar"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_horrorfuel", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "skill_wixie_allegiance_shadow"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_gelblob", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "skill_wixie_allegiance_shadow"
		-- 	end
		-- end)
		-- AddRecipePostInit("slingshotammo_container", function(inst)
		-- 	if inst.builder_skill then
		-- 		inst.builder_skill = nil
		-- 		inst.builder_tag = "wixie_ammo_bag"
		-- 	end
		-- end)
		-- 兼容妥协wixie启用后沃尔特可制作技能树子弹
		AddPrefabPostInit("walter", function(inst)
			-- if not TheWorld.ismastersim then return end
			if inst.components and inst.components.skilltreeupdater then
				local oldActivateSkill = inst.components.skilltreeupdater.ActivateSkill_Server
				inst.components.skilltreeupdater.ActivateSkill_Server = function(self, skill, ...)
					local characterprefabPG = self.inst.prefab
					local onactivateWX
					local onactivateWX2
					-- if skill == "walter_ammo_bag" then onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_ammo_bag"].onactivate end
					-- if skill == "walter_ammo_shattershots" then onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_slingshot_ammo_stinger"].onactivate end
					-- if skill == "walter_ammo_utility" then onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_slingshot_ammo_scrapfeather"].onactivate end
					-- if skill == "walter_ammo_shadow" then onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_allegiance_shadow"].onactivate end
					-- if skill == "walter_ammo_lunar" then onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_allegiance_lunar"].onactivate end
					-- if skill == "walter_ammo_lucky" then 
					-- 	onactivateWX2 = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_slingshot_ammo_gunpowder"].onactivate
					-- 	onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_slingshot_ammo_dreadstone"].onactivate
					-- end
					if skill == "walter_ammo_efficiency" then 
						onactivateWX2 = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_ammocraft_1"].onactivate
						-- onactivateWX = skilltreedefs.SKILLTREE_DEFS["wixie"]["wixie_ammocraft_3"].onactivate
					end
					if onactivateWX then onactivateWX(self.inst) end
					if onactivateWX2 then onactivateWX2(self.inst) end
					oldActivateSkill(self, skill, ...)
				end
				local oldDeActivateSkill = inst.components.skilltreeupdater.DeactivateSkill_Server
				inst.components.skilltreeupdater.DeactivateSkill_Server = function(self, skill, ...)
					local characterprefabPG = self.inst.prefab
					local ondeactivateWX
					local ondeactivateWX2
					-- if skill == "walter_ammo_bag" then ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("wixie_ammo_bag")
					-- 	end 
					-- end
					-- if skill == "walter_ammo_shattershots" then ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("wixie_slingshot_ammo_stinger")
					-- 	end 
					-- end
					-- if skill == "walter_ammo_utility" then ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("wixie_slingshot_ammo_scrapfeather")
					-- 	end 
					-- end
					-- if skill == "walter_ammo_shadow" then ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("skill_wixie_allegiance_shadow")
					-- 	end 
					-- end
					-- if skill == "walter_ammo_lunar" then ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("skill_wixie_allegiance_lunar")
					-- 	end 
					-- end
					-- if skill == "walter_ammo_lucky" then 
					-- 	ondeactivateWX2 = function(inst, fromload)
					-- 		inst:RemoveTag("wixie_slingshot_ammo_dreadstone")
					-- 	end 
					-- 	ondeactivateWX = function(inst, fromload)
					-- 		inst:RemoveTag("wixie_slingshot_ammo_gunpowder")
					-- 	end 
					-- end
					if skill == "walter_ammo_efficiency" then 
						ondeactivateWX2 = function(inst, fromload)
							inst:RemoveTag("wixie_ammocraft_1")
						end 
					end
					if ondeactivateWX then ondeactivateWX(self.inst) end
					if ondeactivateWX2 then ondeactivateWX2(self.inst) end
					oldDeActivateSkill(self, skill, ...)
				end
                local oldIsActivated = inst.components.skilltreeupdater.IsActivated
                inst.components.skilltreeupdater.IsActivated = function(self, skill, ...)
                    if skill == "wixie_ammo_bag" then
                        return oldIsActivated(self, "walter_ammo_bag", ...)

                    elseif skill == "wixie_slingshot_ammo_stinger" then
                        return oldIsActivated(self, "walter_ammo_shattershots", ...)

                    elseif skill == "wixie_slingshot_ammo_scrapfeather" then
                        return oldIsActivated(self, "walter_ammo_utility", ...)

                    elseif skill == "wixie_allegiance_shadow" then
                        return oldIsActivated(self, "walter_ammo_shadow", ...)

                    elseif skill == "wixie_allegiance_lunar" then
                        return oldIsActivated(self, "walter_ammo_lunar", ...)

                    elseif skill == "wixie_slingshot_ammo_gunpowder" or skill == "wixie_slingshot_ammo_dreadstone" then
                        return oldIsActivated(self, "walter_ammo_lucky", ...)
                    end
                    return oldIsActivated(self, skill, ...)
                end
			end
		end)
        local AllRecipes = GLOBAL.AllRecipes
        if AllRecipes then
            local ammos_basic = {
            "slingshotammo_rock",
            "slingshotammo_gold",
            "slingshotammo_marble",
            "slingshotammo_poop",
            "slingshotammo_stinger",
            "slingshotammo_gunpowder",
            "slingshotammo_firecrackers",
            "slingshotammo_honey",
            "slingshotammo_rubber",
            "slingshotammo_moonrock",
            "slingshotammo_slime",
            }
            local function calc_slingshotammo_numtogive_basic(recipe, doer)
                return doer.components.skilltreeupdater
                    and doer.components.skilltreeupdater:IsActivated("walter_ammo_efficiency")
                    and recipe.numtogive + 5
                    or nil
            end
        
            for i, v in pairs(ammos_basic) do
                local oldfn = AllRecipes[v].override_numtogive_fn
                if oldfn then 
                    AllRecipes[v].override_numtogive_fn = function(recipe, doer, ...)
                        return oldfn(recipe, doer, ...) or calc_slingshotammo_numtogive_basic(recipe, doer)
                    end
                end
            end

            local ammos_special = {
            "slingshotammo_freeze",
            "slingshotammo_slow",
            "slingshotammo_thulecite",
            "slingshotammo_dreadstone",
            "slingshotammo_scrapfeather",
            "slingshotammo_lunarplanthusk",
            "slingshotammo_purebrilliance",
            "slingshotammo_gelblob",
            "slingshotammo_horrorfuel",
            "slingshotammo_tremor",
            "slingshotammo_moonglass",
            "slingshotammo_salt",
            "slingshotammo_goop",
            "slingshotammo_flare",
            "slingshotammo_lazy",
            "slingshotammo_tar",
            "slingshotammo_obsidian",
            "slingshotammo_shadow",
            }

            local function calc_slingshotammo_numtogive_special(recipe, doer)
                return doer.components.skilltreeupdater
                    and doer.components.skilltreeupdater:IsActivated("walter_ammo_efficiency")
                    and recipe.numtogive + 5
                    or nil
            end

             for i, v in pairs(ammos_special) do
                local oldfn = AllRecipes[v].override_numtogive_fn
                if oldfn then 
                    AllRecipes[v].override_numtogive_fn = function(recipe, doer, ...)
                        return oldfn(recipe, doer, ...) or calc_slingshotammo_numtogive_special(recipe, doer)
                    end
                end
            end
        end
		-- 妥协弹弓发射逻辑相关函数
		local easing = require("easing")
		local function LaunchSpit(inst, caster, target, shadow)
			if caster ~= nil then
				local x, y, z = caster.Transform:GetWorldPosition()
				local ammo = shadow ~= nil and "slingshotammo_shadow_proj_secondary" or inst.components.weapon.projectile .. "_secondary"

				if ammo ~= nil then
					if ammo == "slingshotammo_spread_proj_secondary" and inst.powerlevel >= 2 then --spread ammo is not a thing, im just removing the spread from rock ammo
						for i = 1, 5 do
							local targetpos = target:GetPosition()
							targetpos.x = targetpos.x + math.random(-2.2, 2.2)
							targetpos.y = 0.5
							targetpos.z = targetpos.z + math.random(-2.2, 2.2)

							local projectile = SpawnPrefab("slingshotammo_spread_proj_secondary")
							projectile.Transform:SetPosition(x, y, z)
							projectile.powerlevel = inst.powerlevel / 4
							projectile.Transform:SetScale(0.7, 0.7, 0.7)
							projectile.Physics:SetCapsule(0.6, 0.6)

							projectile.components.projectile:SetSpeed(60 * projectile.powerlevel)
							projectile.components.projectile:Throw(caster, target, caster)
							projectile:DoTaskInTime(1, projectile.Remove)
							SpawnPrefab("slingshotammo_hitfx_rocks").Transform:SetPosition(x, y, z)
						end
					else
						local targetpos = target:GetPosition()
						targetpos.y = 0.5

						local projectile = SpawnPrefab(ammo)
						projectile.Transform:SetPosition(x, y, z)

						projectile.powerlevel = inst.powerlevel

						if projectile.components.complexprojectile ~= nil then
							local theta = caster.Transform:GetRotation()
							theta = theta * DEGREES

							local dx = targetpos.x - x
							local dz = targetpos.z - z

							--local rangesq = (dx * dx + dz * dz) / 1.2
							local rangesq = dx * dx + dz * dz
							local maxrange = TUNING.FIRE_DETECTOR_RANGE * 2
							--local speed = easing.linear(rangesq, 15, 3, maxrange * maxrange)
							local speed = easing.linear(rangesq, maxrange, 1, maxrange * maxrange)
							projectile.caster = caster
							projectile.components.complexprojectile.usehigharc = true
							projectile.components.complexprojectile:SetHorizontalSpeed(speed)
							projectile.components.complexprojectile:SetGravity(-45)
							projectile.components.complexprojectile:Launch(targetpos, caster, caster)
							projectile.components.complexprojectile:SetLaunchOffset(Vector3(1.5, 1.5, 0))
						else
							if ammo == "slingshotammo_moonglass_proj_secondary" then
								projectile.components.projectile:SetSpeed(20)
							else
								projectile.components.projectile:SetSpeed(10 + 10 * projectile.powerlevel)
							end

							projectile.components.projectile:Throw(caster, target, caster)
						end
					end
				end
			end
		end
		local function UnloadAmmo(inst)
			if inst.components.container ~= nil then
				local ammo_stack = inst.components.container:GetItemInSlot(inst.overrideammoslot or 1)
				local item = inst.components.container:RemoveItem(ammo_stack, false)
				if item ~= nil then
					if item == ammo_stack then
						item:PushEvent("ammounloaded", { slingshot = inst })
					end

					item:Remove()
				end
			end
		end
		local function createlight(inst, target, pos)
			--if caster.sg.currentstate.name == "slingshot_cast" then
			local ammo = inst.components.weapon.projectile and inst.components.weapon.projectile .. "_secondary"
			local owner = inst.components.inventoryitem.owner

			if owner ~= nil and owner.wixiepointx ~= nil then
				if ammo ~= nil then
					if ammo == "slingshotammo_shadow_proj_secondary" then
						local xmod = owner.wixiepointx
						local zmod = owner.wixiepointz

						local pattern = false

						if math.random() > 0.5 then
							pattern = true
						end

						for i = 1, 2 * inst.powerlevel + 1 do
							inst:DoTaskInTime(0.03 * i, function()
								local caster = inst.components.inventoryitem.owner
								local spittarget = SpawnPrefab("slingshot_target")

								local multipl = (pattern and -100 or 100) / (inst.powerlevel * 2)

								local maxangle = multipl / 2

								local varangle = maxangle - multipl

								maxangle = maxangle - (varangle / 2)

								local theta = (inst:GetAngleToPoint(owner.wixiepointx, 0.5, owner.wixiepointz) + (maxangle + (varangle * (i - 1)))) * DEGREES

								xmod = owner.wixiepointx + 15 * math.cos(theta)
								zmod = owner.wixiepointz - 15 * math.sin(theta)

								spittarget.Transform:SetPosition(xmod, 0.5, zmod)
								LaunchSpit(inst, caster, spittarget, true)
								spittarget:DoTaskInTime(.1, spittarget.Remove)
							end)
						end
					else
						local caster = inst.components.inventoryitem.owner
						local spittarget = SpawnPrefab("slingshot_target")

						--local pos = TheInput:GetWorldPosition()

						spittarget.Transform:SetPosition(owner.wixiepointx, 0.5, owner.wixiepointz)
						LaunchSpit(inst, caster, spittarget)
						spittarget:DoTaskInTime(0, spittarget.Remove)
					end

					UnloadAmmo(inst)
				end
			end
		end
		local function CreateTarget()
			local inst = CreateEntity()

			inst:AddTag("CLASSIFIED")
			--[[Non-networked entity]]
			inst.persists = false

			inst.entity:AddTransform()

			inst:DoTaskInTime(3, inst.Remove)

			return inst
		end
		local TARGET_RANGE = 30
		-- 改装弹弓普攻发射妥协专属子弹
		local function newUMProjectileLaunched(inst)
			if not TheWorld.ismastersim then return end
			if inst.components.weapon then
				local onprojectilelaunched = inst.components.weapon.onprojectilelaunched
				inst.components.weapon:SetOnProjectileLaunched(function(inst, attacker, target, proj, ...)
					if proj == nil then
						if  target and target:IsValid() and attacker ~= nil and target ~= attacker and inst.components.inventoryitem and
							attacker == inst.components.inventoryitem.owner then
							inst.powerlevel = 1
							inst.slingshot_amount = 1
							local pos = target:GetPosition()
							attacker.wixiepointx = pos.x
							attacker.wixiepointy = pos.y
							attacker.wixiepointz = pos.z
							createlight(inst, target, pos, attacker)
						end
					elseif proj ~= nil and onprojectilelaunched then
						onprojectilelaunched(inst, attacker, target, proj, ...)
					end
				end)
			end
		end
		AddPrefabPostInit("slingshotex", newUMProjectileLaunched)
		AddPrefabPostInit("slingshot999ex", newUMProjectileLaunched)
		AddPrefabPostInit("slingshot2", newUMProjectileLaunched)
		AddPrefabPostInit("slingshot2ex", newUMProjectileLaunched)
    end
end

-- 沃尔特右键连续冲刺
if GetModConfigData("Walter Right Dodge Longer") then
    AddPrefabPostInit("walter", function(inst)
        inst.rightaction2hm_double = true
        AddDodgeAbility(inst)
        inst.rightaction2hm_cooldown = GetModConfigData("Walter Right Dodge Longer") + 1
        inst.rightaction2hm_beefalo = true
    end)
end

-- 沃比自动冲刺
if GetModConfigData("Walter Right Dodge Longer") then
    TUNING.WOBY_SMALL_HUNGER = TUNING.BEEFALO_HUNGER
    TUNING.WOBY_BIG_HUNGER = TUNING.BEEFALO_HUNGER
    local newwobytransformpercent = math.clamp(100 / TUNING.BEEFALO_HUNGER, TUNING.DSTU and 0.3 or 0, 0.95)
    local hungersource = "scripts/prefabs/wobysmall.lua"
    AddPrefabPostInit("wobysmall", function(inst)
        if not TheWorld.ismastersim then return end
        local _hungerdelta
        local index = 1
        for i, func in ipairs(inst.event_listening["hungerdelta"][inst]) do
            if GLOBAL.debug.getinfo(func, "S").source == hungersource then
                index = i
                break
            end
        end
        _hungerdelta = inst.event_listening["hungerdelta"][inst][index]
        if _hungerdelta then
            inst:RemoveEventCallback("hungerdelta", _hungerdelta)
            -- 原版100点饥饿时变大,妥协则是30%饥饿以上变大
            inst:ListenForEvent("hungerdelta", function(inst, data, ...)
                if data and data.newpercent >= newwobytransformpercent then
                    data.newpercent = 0.95
                    _hungerdelta(inst, data, ...)
                end
            end)
        end
        -- 变成大沃比,大沃比继承饥饿值
        local FinishTransformation = inst.FinishTransformation
        inst.FinishTransformation = function(inst, ...)
            local hungervalue = inst.components.hunger and inst.components.hunger.current
            local player = inst._playerlink
            FinishTransformation(inst, ...)
            if hungervalue and player ~= nil and player.woby and player.woby:IsValid() and player.woby.prefab == "wobybig" and player.woby.components.hunger then
                player.woby.components.hunger.current = hungervalue
            end
        end
    end)
    if TUNING.DSTU then
        AddPrefabPostInit("wobybig", function(inst)
            if not TheWorld.ismastersim then return end
            -- 变成小沃比,小沃比继承饥饿值
            local FinishTransformation = inst.FinishTransformation
            inst.FinishTransformation = function(inst, ...)
                local hungervalue = inst.components.hunger and inst.components.hunger.current
                local player = inst._playerlink
                FinishTransformation(inst, ...)
                if hungervalue and player ~= nil and player.woby and player.woby:IsValid() and player.woby.prefab == "wobysmall" and
                    player.woby.components.hunger then player.woby.components.hunger.current = math.max(hungervalue, 1) end
            end
        end)
        AddClassPostConstruct("widgets/statusdisplays", function(self)
            if self.WobyHungerDisplay and not self.WobyHungerDisplay.update2hm then
                self.WobyHungerDisplay.update2hm = true
                local UpdateHunger = self.WobyHungerDisplay.UpdateHunger
                self.WobyHungerDisplay.UpdateHunger = function(self, hunger, ...)
                    if self.bg then
                        local percentage = hunger / TUNING.WOBY_BIG_HUNGER
                        self.bg.hunger2hm = hunger
                        self.bg:SetPercent(percentage)
                    elseif UpdateHunger then
                        UpdateHunger(self, hunger, ...)
                    end
                end
                if self.WobyHungerDisplay and self.WobyHungerDisplay.bg then
                    local SetPercent = self.WobyHungerDisplay.bg.SetPercent
                    self.WobyHungerDisplay.bg.SetPercent = function(self, val, ...)
                        SetPercent(self, val, ...)
                        if self.hunger2hm and self.num then self.num:SetString(tostring(math.ceil(self.hunger2hm))) end
                        if self.CombinedStatusUpdateNumbers then self:CombinedStatusUpdateNumbers(TUNING.WOBY_BIG_HUNGER) end
                    end
                    if self.WobyHungerDisplay.bg.CombinedStatusUpdateNumbers then
                        self.WobyHungerDisplay.bg:CombinedStatusUpdateNumbers(TUNING.WOBY_BIG_HUNGER)
                    end
                end
            end
        end)
    end
    local function OnAttacked(inst, data)
        if inst.components.rider:IsRiding() and not inst.allmiss2hm and data and data.attacker and data.attacker:IsValid() and
            not inst.components.timer:TimerExists("wobydodge2hm") then
            local mount = inst.components.rider:GetMount()
            if mount:HasTag("woby") and inst.components.health and not inst.components.health:IsDead() and not inst:HasTag("playerghost") and
                not (inst.components.freezable and inst.components.freezable:IsFrozen()) and
                not (inst.components.sleeper and inst.components.sleeper:IsAsleep()) then
                local x, y, z = inst.Transform:GetWorldPosition()
                local angle = data.attacker:GetAngleToPoint(x, y, z) * DEGREES
                inst.sg:GoToState("dodge2hm", {pos = DynamicPosition(Vector3(x + 6 * math.cos(angle), 0, z - 6 * math.sin(angle)))})
                inst.components.timer:StartTimer("wobydodge2hm", TUNING.WALTER_WOBYBUCK_DECAY_TIME * 2)
                if mount.components.hunger then mount.components.hunger:DoDelta(-10, nil, true) end
            end
        end
    end
    AddPrefabPostInit("walter", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("GetAttacked_Internal2hm", OnAttacked)
    end)
    local function redirectdamagefn(inst, attacker, ...)
        if inst.woby and inst.woby:IsValid() and inst.woby.components.combat and not (inst.woby.components.health and inst.woby.components.health:IsDead()) then
            return inst.woby
        end
    end
    AddStategraphPostInit("wilson", function(sg)
        local bucked = sg.states.bucked.onenter
        sg.states.bucked.onenter = function(inst, ...)
            bucked(inst, ...)
            if inst.prefab == "walter" and inst.woby and inst.woby:IsValid() and inst.components.rider:IsRiding() then
                local mount = inst.components.rider:GetMount()
                if mount:HasTag("woby") and mount == inst.woby and inst.components.health and not inst.components.health:IsDead() and
                    not (inst.woby.components.health and inst.woby.components.health:IsDead()) then
                    inst.wobyprotect2hm = true
                elseif inst.wobyprotect2hm then
                    inst.wobyprotect2hm = nil
                end
            elseif inst.wobyprotect2hm then
                inst.wobyprotect2hm = nil
            end
            if inst.wobyprotect2hm then
                inst.sg:AddStateTag("temp_invincible")
                if not inst.components.combat.redirectdamagefn then inst.components.combat.redirectdamagefn = redirectdamagefn end
            end
        end
        local onexit = sg.states.bucked.onexit
        sg.states.bucked.onexit = function(inst, ...)
            onexit(inst, ...)
            if inst.wobyprotect2hm and inst.components.combat.redirectdamagefn == redirectdamagefn then inst.components.combat.redirectdamagefn = nil end
        end
        local bucked_post = sg.states.bucked_post.onenter
        sg.states.bucked_post.onenter = function(inst, ...)
            bucked_post(inst, ...)
            if inst.wobyprotect2hm then
                if inst.woby and inst.woby:IsValid() and not (inst.woby.components.health and inst.woby.components.health:IsDead()) then
                    inst.sg:AddStateTag("temp_invincible")
                    inst.woby.sg:GoToState("actual_cower")
                    inst.woby.sg:RemoveStateTag("idle")
                    inst.woby.sg:AddStateTag("busy")
                    if not inst.components.combat.redirectdamagefn then inst.components.combat.redirectdamagefn = redirectdamagefn end
                else
                    inst.wobyprotect2hm = nil
                end
            end
        end
        local onexit2 = sg.states.bucked_post.onexit
        sg.states.bucked_post.onexit = function(inst, ...)
            if onexit2 then onexit2(inst, ...) end
            if inst.wobyprotect2hm and inst.components.combat.redirectdamagefn == redirectdamagefn then
                inst.components.combat.redirectdamagefn = nil
                inst.wobyprotect2hm = nil
            end
            if inst.woby and inst.woby:IsValid() and inst.woby.sg.currentstate.name == "actual_cower" and
                not (inst.woby.components.health and inst.woby.components.health:IsDead()) then inst.woby.sg:GoToState("idle", true) end
        end
    end)
	-- 沃尔特双线技能树兼容加速效果
	AddStategraphPostInit("wilson", function(sg)
		if not sg.states.dash_woby_pst then return end
		local oldonenter = sg.states.dash_woby_pst.onenter
		sg.states.dash_woby_pst.onenter = function(inst, isshadow, ...)
			if oldonenter then oldonenter(inst, isshadow, ...) end
			if inst.sg.statemem.ridingwoby then
				inst.AnimState:PlayAnimation("sprint_woby_pst")
				if inst.sg.statemem.normalriding and inst.components.skilltreeupdater:IsActivated("walter_woby_lunar") then
					inst.sg:AddStateTag("force_sprint_woby")
					inst:AddTag("force_sprint_woby")
				end
			end
		end
	end)
end
