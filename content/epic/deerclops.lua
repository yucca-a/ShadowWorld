local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1
local deerclopsmode = GetModConfigData("deerclops")
-- TUNING.DEERCLOPS_HEALTH = TUNING.DEERCLOPS_HEALTH * 2
if attackspeedup < 1.33 then TUNING.DEERCLOPS_ATTACK_PERIOD = TUNING.DEERCLOPS_ATTACK_PERIOD * 3 / 4 * attackspeedup end

-- 队友之间互相解冻机制
AddComponentAction("SCENE", "freezable", function(inst, doer, actions)
    if not doer:HasTag("busy") and inst:HasTag("player") and (inst:HasTag("thawing") or inst:HasTag("frozen")) and inst ~= doer then
        table.insert(actions, ACTIONS.UNPIN)
    end
end)
local oldUNPINfn = ACTIONS.UNPIN.fn
ACTIONS.UNPIN.fn = function(act, ...)
    if act.doer ~= act.target and act.target.components.freezable and act.target.components.freezable:IsFrozen() and act.doer.components.freezable then
        act.doer.components.freezable:AddColdness(act.doer.components.freezable:ResolveResistance() / 2)
        act.target.components.freezable:Unfreeze()
        return true
    end
    oldUNPINfn(act, ...)
end
-- 猪人帮助解控
local function GetLeader(inst) return inst.components.follower and inst.components.follower.leader end
AddBrainPostInit("pigbrain", function(self)
    if self.bt.root.children and self.bt.root.children then
        for index, child in ipairs(self.bt.root.children) do
            if child and child.chatlines == "PIG_TALK_RESCUE" and child.children and child.children[1] and child.children[1].children and
                child.children[1].children[1] and child.children[1].children[1].fn then
                local fn = child.children[1].children[1].fn
                child.children[1].children[1].fn = function(...)
                    return fn(...) or
                               (GetLeader(self.inst) and GetLeader(self.inst).components.freezable and GetLeader(self.inst).components.freezable:IsFrozen())
                end
                break
            end
        end
    end
end)
-- 修复客户端制作解控BUG
AddComponentPostInit("builder", function(self)
    local oldMakeRecipe = self.MakeRecipe
    self.MakeRecipe = function(self, recipe, ...)
        if recipe ~= nil and (not (self.inst.components.inventory and self.inst.components.inventory.isvisible) or self.inst.sg:HasStateTag("busy")) then
            return false
        end
        return oldMakeRecipe(self, recipe, ...)
    end
end)

-- 巨鹿间歇携带帝王蟹的雪阵且移速增加，最后附带一次冰封,且期间多次受击则反向冰冻敌人
local function onfreeze(inst, target)
    if not target:IsValid() then
        return
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.components.combat ~= nil and inst and inst:IsValid() then
        target.components.combat:SuggestTarget(inst)
    end

    if target.sg ~= nil and not target.sg:HasStateTag("frozen") and inst and inst:IsValid() then
        target:PushEvent("attacked", { attacker = inst, damage = 0, weapon = inst })
    end

    if target.components.freezable ~= nil and target:IsValid() then -- NOTES(JBK): We need to check if ent is still valid for freezable:AddColdness after being attacked.
        target.components.freezable:AddColdness(10)
        target.components.freezable:SpawnShatterFX()
    end
end
local function dofreezefz(inst)
    if inst.freezetaskPG then
        inst.freezetaskPG:Cancel()
        inst.freezetaskPG = nil
    end
    local time = 0.1
    inst.freezetaskPG = inst:DoTaskInTime(time,function() inst.freezefxPG(inst) end)
end

local function freezefx(inst)
    local function spawnfx()
        local MAXRADIUS = TUNING.CRABKING_FREEZE_RANGE * 0.75
        local x,y,z = inst.Transform:GetWorldPosition()
        local theta = math.random()*TWOPI
        local radius = 4+ math.pow(math.random(),0.8)* MAXRADIUS
        local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
        local fx = SpawnPrefab("crab_king_icefx")
        fx.Transform:SetPosition(x+offset.x,y+offset.y,z+offset.z)
    end
    for i=1,5 do
        if math.random()<0.2 then
            spawnfx()
        end
    end

    dofreezefz(inst)
end

local FREEZE_CANT_TAGS = { "deerclops", "shadow", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "INLIMBO" }
local function dofreeze(inst)
    local interval = 0.2
    local pos = Vector3(inst.Transform:GetWorldPosition())
    local range = TUNING.CRABKING_FREEZE_RANGE * 0.75
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, range, nil, FREEZE_CANT_TAGS)
    for i,v in pairs(ents)do
        if v.components.temperature then
            local rate = 1
            if v.components.moisture then
                rate = rate * Remap(v.components.moisture:GetMoisture(),0,v.components.moisture.maxmoisture,1,3)
            end

            local mintemp = v.components.temperature.mintemp
            local curtemp = v.components.temperature:GetCurrent()
            if mintemp < curtemp then
                v.components.temperature:DoDelta(math.max(-rate, mintemp - curtemp))
            end
        end
    end
	-- 降温速率不要太快
    local time = 1
    inst.lowertemptaskPG = inst:DoTaskInTime(time,function() inst.dofreezePG(inst) end)
end
local function endfreeze(inst)
    if inst.freezetaskPG then
        inst.freezetaskPG:Cancel()
        inst.freezetaskPG = nil
    end

    if inst.lowertemptaskPG then
        inst.lowertemptaskPG:Cancel()
        inst.lowertemptaskPG = nil
    end
	if inst.components.health and not inst.components.health:IsDead() then
		local pos = Vector3(inst.Transform:GetWorldPosition())
		local range = TUNING.CRABKING_FREEZE_RANGE * 0.75
		local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, range, nil, FREEZE_CANT_TAGS)
		for i,v in pairs(ents)do
			onfreeze(inst, v)
		end
		SpawnPrefab("crabking_ring_fx").Transform:SetPosition(pos.x,pos.y,pos.z)
	end
	inst.snowfx2hm = nil
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "speedup2hm")
    inst.freezableparry2hm = 0.5
	inst.processspellPG = nil
end
local cd = 20.5
local function refreshfx(inst)
    if inst and inst:IsValid() and not inst:IsAsleep() and inst.components.locomotor then
        if (inst.feezeindex2hm or 0) <= 0 and not inst.snowfx2hm then
			if not inst.dofreezePG then inst.dofreezePG = dofreeze end
			if not inst.freezefxPG then inst.freezefxPG = freezefx end
            if inst.sg and
                (not inst.sg:HasStateTag("busy") or (not inst:HasTag("lunar_aligned") and inst.sg.currentstate and inst.sg.currentstate.name == "hit")) then
                inst.sg:GoToState("taunt")
            end
            if deerclopsmode ~= -1 then
                if TheWorld.state.precipitation == "none" and TUNING.alterguardianseason2hm ~= 1 then
                    TheWorld:PushEvent("ms_forceprecipitation", true)
                end
                if TheWorld.components.waterstreakrain2hm then TheWorld.components.waterstreakrain2hm:Enable(true) end
            end
			if inst.components.health and inst.components.health:IsDead() then return end
			inst:DoTaskInTime(0,function()
				inst.processspellPG = true
				dofreezefz(inst)
				dofreeze(inst)
			end)
			inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/ice_attack")
            inst.snowfx2hm = true
            inst.freezableparry2hm = 1.75
            inst:ListenForEvent("death", function()
				if inst.processspellPG == true then
					endfreeze(inst) 
				end
			end)
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "speedup2hm", 2)
            inst.feezeindex2hm = cd

			inst:DoTaskInTime(TUNING.CRABKING_CAST_TIME+2,function()
				endfreeze(inst)
			end)
        elseif inst.feezeindex2hm <= cd then
            inst.feezeindex2hm = inst.feezeindex2hm - 1
        end
    end
end
local function processspersistent2hm(inst)
     if inst.components.persistent2hm.data.freezable then
         inst.checkfreezable2hm = true
         inst.freezableparry2hm = 0.5
         inst:DoPeriodicTask(1, refreshfx, 0.25)
         inst.Physics:ClearCollidesWith(COLLISION.GIANTS)
     end
end
--
-- 冰甲
local function OnAttacked(inst, data)
    if inst:HasTag("swc2hm") then return end
	 if inst.checkfreezable2hm and not inst.freezableparry2hm and inst.components.health:GetPercent() >= 0.4 then inst.checkfreezable2hm = nil end
	 if not inst.checkfreezable2hm and inst.components.health:GetPercent() <= 0.35 and math.random() < 0.35 then
		 inst.components.persistent2hm.data.freezable = true
		 inst.checkfreezable2hm = true
		 processspersistent2hm(inst)
	 end
	 if inst.checkfreezable2hm and inst.freezableparry2hm and inst.freezableparry2hm > 0 then
		 inst.SoundEmitter:PlaySound("dontstarve/wilson/hit_scalemail")
		 if data and data.attacker and data.attacker.components.freezable then
			 data.attacker.components.freezable:AddColdness(inst.freezableparry2hm)
			 if inst.freezableparry2hm > 1 then data.attacker.components.freezable:SpawnShatterFX() end
		 end
	 end
end
-------------------------------------------------------------------------------------------------------------------
-- 守护极光
local function generatecoldstar(inst)
    if inst:HasTag("swc2hm") then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 25, {"staffcoldlight2hm"})
    if #ents < 4 then
        for i = 1, 3 - #ents, 1 do
            local star = SpawnPrefab("staffcoldlight2hm")
            star.Transform:SetPosition(x, y, z)
            star.index2hm = i
            star.boss2hm = inst
        end
    end
end
local function OnKilledOther(inst, data)
    if data ~= nil and data.victim ~= nil then
        if data.victim:HasTag("player") or data.victim:HasTag("epic") or math.random() < 0.05 then
            local star = SpawnPrefab("staffcoldlight2hm")
            local x, y, z = inst.Transform:GetWorldPosition()
            star.Transform:SetPosition(x, y, z)
            star.index2hm = math.random(3)
            star.boss2hm = inst
        end
    end
end
-- 雪球雪
local function beginsnow(inst)
    if inst:HasTag("swc2hm") then return end
    if TheWorld.state.precipitation == "none" and TUNING.alterguardianseason2hm ~= 1 then TheWorld:PushEvent("ms_forceprecipitation", true) end
    if TheWorld.components.waterstreakrain2hm then TheWorld.components.waterstreakrain2hm:Enable(true) end
end
-- 巨鹿机制增强
local function updatedeerclops(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.freezable then
        inst.components.freezable.AddColdness = nilfn
        inst.components.freezable.Freeze = nilfn
    end
    inst:DoTaskInTime(0.25, generatecoldstar)
    inst:ListenForEvent("killed", OnKilledOther)
	inst:ListenForEvent("blocked", OnAttacked)
	inst:ListenForEvent("attacked", OnAttacked)
	inst:DoTaskInTime(0.25, OnAttacked)
    if inst.components.locomotor.runspeed and speedup < 1.67 then inst.components.locomotor.runspeed = inst.components.locomotor.runspeed * 1.67 / speedup end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    -- inst:DoTaskInTime(0, processspersistent2hm)
    if not POPULATING and deerclopsmode ~= -1 then inst:DoTaskInTime(0, beginsnow) end
end
AddPrefabPostInit("deerclops", updatedeerclops)
-- 普通巨鹿血量翻倍
AddComponentPostInit("health", function(self)
    if self.inst:HasTag("deerclops") then
        local oldSetMaxHealth = self.SetMaxHealth
        self.SetMaxHealth = function(self, amount, ...) return oldSetMaxHealth(self, amount * 2, ...) end
    end
end)
-- 妥协冰墙碾碎
AddPrefabPostInit("deerclops_barrier", function(inst) inst:AddTag("boulder") end)
-- 妥协蜘蛛茧别吸引巨鹿了
AddPrefabPostInit("webbedcreature", MakeOnlyPlayerTarget)

-- 为爽晶体独眼巨鹿改动
-- 晶体独眼巨鹿倒地起身后会疯狂一段时间直到过期且血量掉落20%;疯狂时间段外的长冰动作可以长出来眼球冰,眼球冰在疲惫时消失;当两根冰刺都用完还有眼球冰且被点燃时,开始挣扎
-- 冰墙爆落的冰块数量削减,会自动破坏掉了
SetSharedLootTable2hm("sharkboi_icespike", {{"ice", 0.15}})
SetSharedLootTable2hm("sharkboi_icespike_low", {{"ice", 0.05}})
local function workicespike(inst)
    if inst.components.workable then
        if inst.components.lootdropper then
            inst.components.lootdropper:SetLoot()
            inst.components.lootdropper:SetChanceLootTable()
            inst.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
            inst.components.lootdropper.GenerateLoot = emptytablefn
            inst.components.lootdropper.DropLoot = emptytablefn
        end
        inst.components.workable:WorkedBy_Internal(inst, 1000)
    end
end
local function onicetunnelremove(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local spikes = TheSim:FindEntities(x, y, z, 100, {"frozen", "groundspike"}, {"INLIMBO"})
    for index, spike in ipairs(spikes) do
        if spike and spike.prefab == "sharkboi_icespike" then
            spike.persists = false
            spike:DoTaskInTime(360, workicespike)
        end
    end
end
AddPrefabPostInit("sharkboi_icetunnel_fx", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", onicetunnelremove)
end)
-- 冰墙拦截敌人
local lastteleport = true
local function generateicewall(inst)
    if inst.components.timer and not inst.components.timer:TimerExists("icetunnel_cd") and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ==
        "icelance" and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and
        inst.components.combat.target:HasTag("player") then
        inst.components.timer:StartTimer("icetunnel_cd", 180 + math.random(60))
        local x, y, z = inst.Transform:GetWorldPosition()
        local rot = inst.Transform:GetRotation()
        local theta = rot * DEGREES
        x = x + math.cos(theta)
        z = z - math.sin(theta)
        local fx = SpawnPrefab("sharkboi_icetunnel_fx")
        fx.Transform:SetPosition(x, 0, z)
        fx.Transform:SetRotation(rot)
        local toteleport = lastteleport == nil and math.random() < 0.35 or lastteleport == false
        lastteleport = toteleport
        if toteleport then inst.toteleport2hm = {x = x + 24 * math.cos(theta), y = y, z = z - 24 * math.sin(theta)} end
        local targets = {}
        local perptheta = (rot + 90) * DEGREES
        local dist = toteleport and 3 or 19
        for i = 1, 2 do
            local spike = SpawnPrefab("sharkboi_icespike")
            local perpdist = i == 1 and -1 or 1
            spike.Transform:SetPosition(x + dist * math.cos(theta) + perpdist * math.cos(perptheta), y,
                                        z - dist * math.sin(theta) - perpdist * math.sin(perptheta))
            spike.Transform:SetRotation(rot + (i == 1 and -70 or 70))
            spike.targets = targets
            spike:SetVariation(4)
            spike.SoundEmitter:PlaySound("meta3/sharkboi/ice_spike")
        end
    end
end
-- local function onicegrowdelay(inst)
--     if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name == "icegrow" and inst.sg.mem.noice ~= 1 and not inst.sg.mem.noeyeice and
--         inst.components.burnable and not inst.components.burnable:IsBurning() then recovermutated(inst) end
-- end
AddStategraphPostInit("deerclops", function(sg)
    -- 某些模组不存在这两个API的补丁
    local idleonexit = sg.states.idle.onexit
    sg.states.idle.onexit = function(inst, ...)
        if not inst.SwitchToFourFaced then inst.SwitchToFourFaced = nilfn end
        if not inst.SwitchToEightFaced then inst.SwitchToEightFaced = nilfn end
        if idleonexit then idleonexit(inst, ...) end
    end
    -- 挣扎会逐渐熄灭火焰了
    local struggle_pre = sg.states.struggle_pre.onenter
    sg.states.struggle_pre.onenter = function(inst, ...)
        struggle_pre(inst, ...)
        if inst:HasTag("lunar_aligned") and inst.components.burnable and inst.components.burnable:IsBurning() then
            inst.components.burnable:Extinguish()
            inst.components.burnable:StartWildfire()
            -- 便于后续继续挣扎
            inst.components.burnable.swIsBurning2hm = inst.components.burnable.IsBurning
            inst.components.burnable.IsBurning = function(self, ...) return self:IsSmoldering() or self:swIsBurning2hm(...) end
        end
    end
    -- 挣扎结束时
    local struggle_preonexit = sg.states.struggle_pre.onexit
    sg.states.struggle_pre.onexit = function(inst, ...)
        if inst.components.burnable and inst.components.burnable.swIsBurning2hm then
            inst.components.burnable.IsBurning = inst.components.burnable.swIsBurning2hm
            inst.components.burnable.swIsBurning2hm = nil
        end
        if struggle_preonexit then struggle_preonexit(inst, ...) end
    end
    -- local struggle_pst = sg.states.struggle_pst.onenter
    -- sg.states.struggle_pst.onenter = function(inst, ...)
    --     struggle_pst(inst, ...)
    --     if inst:HasTag("lunar_aligned") and inst.sg.laststate and inst.sg.laststate.name == "struggle_loop" then recovermutated(inst) end
    -- end
    -- local icegrow = sg.states.icegrow.onenter
    -- sg.states.icegrow.onenter = function(inst, ...)
    --     icegrow(inst, ...)
    --     if inst:HasTag("lunar_aligned") and inst.sg.mem.noice == 1 and not inst.sg.mem.noeyeice and inst.components.burnable and
    --         not inst.components.burnable:IsBurning() then inst:DoTaskInTime(11 * FRAMES, onicegrowdelay) end
    -- end
    -- 冰刺攻击
    -- local icelance = sg.states.icelance.onenter
    -- sg.states.icelance.onenter = function(inst, ...)
    --     icelance(inst, ...)
    --     if inst:HasTag("lunar_aligned") -- and (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or inst:HasTag("swc2hm")) 
    --     then inst:DoTaskInTime(1, generateicewall) end
    -- end
    AddStateTimeEvent2hm(sg.states.icelance, 1, function(inst) if inst:HasTag("lunar_aligned") then generateicewall(inst) end end)
    -- 冰墙传送拦截攻击
    local onexit = sg.states.icelance.onexit
    sg.states.icelance.onexit = function(inst, ...)
        onexit(inst, ...)
        if inst:HasTag("lunar_aligned") and inst.toteleport2hm then
            inst.Transform:SetPosition(inst.toteleport2hm.x, 0, inst.toteleport2hm.z)
            inst.toteleport2hm = nil
        end
    end
end)
-- 冰晶独眼巨鹿具有普通巨鹿一样的机制
AddPrefabPostInit("mutateddeerclops", function(inst)
    if not TheWorld.ismastersim then return end
	if inst.components.freezable then
        inst.components.freezable.AddColdness = nilfn
        inst.components.freezable.Freeze = nilfn
    end
    inst:DoTaskInTime(0.25, generatecoldstar)
    inst:ListenForEvent("killed", OnKilledOther)
	if inst.components.locomotor.runspeed and speedup < 1.67 then inst.components.locomotor.runspeed = inst.components.locomotor.runspeed * 1.67 / speedup end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if not POPULATING and deerclopsmode ~= -1 then inst:DoTaskInTime(0, beginsnow) end
    -- if not inst.StartMutation then inst.StartMutation = StartMutation_mutated end
    if inst.components.timer then inst.components.timer:StartTimer("icetunnel_cd", 60 + math.random(30)) end
    if TUNING.shadowworld2hm and EnableExchangeWitheSwc2hm then EnableExchangeWitheSwc2hm(inst, {0.65031, 0.30031}) end
end)
