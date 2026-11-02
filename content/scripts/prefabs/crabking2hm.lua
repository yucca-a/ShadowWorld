local brain = require "brains/crabking2hmbrain"

-- red gem  -- MAX HEALTH
-- blue gem -- FREEZE TIME
-- purple gem -- GEYSERS
-- yellow gem -- CAST DELAY
-- green gem -- CLAWS
-- orange gem -- REGEN BUFF

local assets =
{
    Asset("ANIM", "anim/crab_king_basic.zip"),
    Asset("ANIM", "anim/crab_king_actions.zip"),
    Asset("ANIM", "anim/crab_king_build.zip"),
}

local chipassets =
{
    Asset("ANIM", "anim/crabking_rockchip.zip"),
}

local prefabs =
{
    "dwx_geyserspawner",
    "dwx_claw",
    "crab_king_shine",
    "crabking_feeze2hm",
    "crabking_ring_fx",
    "dwx_chip_high",
    "dwx_chip_med",
    "dwx_chip_low",
    "moon_altar_cosmic",
    "moon_altar_crown",
    "hermit_cracked_pearl",
    "chesspiece_crabking_sketch",
    "trident_blueprint",
    "meat",
    "singingshell_octave5",
    "singingshell_octave4",
    "singingshell_octave3",
    "barnacle",
	"winter_ornament_boss_crabking",
	"winter_ornament_boss_crabkingpearl",
}

local geyserprefabs =
{
    "crab_king_bubble1",
    "crab_king_bubble2",
    "crab_king_bubble3",
    "crab_king_waterspout",
}

local freezeprefabs =
{
    "mushroomsprout_glow",
    "crab_king_icefx",
}

local TARGET_DIST = 15

local CRABKING_HEAL_DELAYS = 40

local CRABKING_CLAW_REGEN_DELAYS = 2

local CRABKING_BASE_FREEZE_AMOUNTS = 15

local CRABKING_CAST_TIME_FREEZES = 5

local CRABKING_CLAW_RESPAWN_DELAYS = 30 * 2 / 3

local MAX_SOCKETS = 9

local ARMTIME = {
    0,
    0.25,
    0.1,
    0.2,
    0.15,
    0.3,
}

local function spawnwaves(inst, numWaves, totalAngle, waveSpeed, wavePrefab, initialOffset, idleTime, instantActivate,
						  random_angle)
	SpawnAttackWaves(
		inst:GetPosition(),
		(not random_angle and inst.Transform:GetRotation()) or nil,
		initialOffset or (inst.Physics and inst.Physics:GetRadius()) or nil,
		numWaves,
		totalAngle,
		waveSpeed,
		wavePrefab,
		idleTime,
		instantActivate
	)
end

local function spawnwave(inst, time)
	spawnwaves(inst, 12, 360, Lerp(2, 6, inst.countgems(inst).blue / 10), nil, 2.5, time or 2, true, true)

	--need to manually push boats without being the waves, as the waves can try spawning on the boat itself, and then not moving it.
	local x, y, z = inst.Transform:GetWorldPosition()
	local boats = TheSim:FindEntities(x, y, z, 12, nil, nil, { "boat" })
	for k, v in ipairs(boats) do
		local bx, by, bz = v.Transform:GetWorldPosition()
		local push_dir_x, push_dir_z = VecUtil_Normalize(bx - x, bz - z)
		v.components.boatphysics:ApplyForce(push_dir_x, push_dir_z, Lerp(2, 6, inst.countgems(inst).blue / 10))
	end
end

local function OnCollide(inst, data)
    local boat_physics = data.other.components.boatphysics

    if (math.abs(boat_physics:GetVelocity() * data.hit_dot_velocity)) < 1.2 then
        return
    end

    if boat_physics ~= nil then
        if inst.components.health ~= nil then
            inst.components.health:DoDelta((-2000 * math.abs(boat_physics:GetVelocity() * data.hit_dot_velocity)) *
                0.33)
        end
    end

    inst.finishfixing(inst)

    if inst.attack_count <= 2 then
        inst:DoTaskInTime(3, function(inst)
            if inst.components.timer:TimerExists("claw_regen_timer") then
                inst.components.timer:StopTimer("claw_regen_timer")
            end
            inst.regenarm(inst)
        end)
    end
    spawnwave(inst)

    if inst.vulnerable_shine_task ~= nil then
        inst.vulnerable_shine_task:Cancel()
        inst.vulnerable_shine_task = nil

        inst.wantstocast = true
        inst.attack_count = 0

        if inst.long_cd ~= nil then
            inst.long_cd:Cancel()
            inst.long_cd = nil
        end
    else
        inst.attack_count = math.clamp(inst.attack_count - 1, 0, 10)
    end
end

local function removecrab(inst)
	inst.crab = nil
	inst:Remove()
end

local CRABKING_SPELLGENERATOR_TAGS = { "crabking_spellgenerator" }

--I LOVE MATH!!!
--I almost went down a Bézier curve rabbithole.

local function DoLineAttack(inst, rand_start)
	local ck_x, ck_y, ck_z = inst.Transform:GetWorldPosition()
	local target = #inst.all_targets > 1 and inst.all_targets[math.random(#inst.all_targets)] or
		inst.components.combat ~= nil and inst.components.combat.target

	if target == nil then
		local boats = TheSim:FindEntities(ck_x, ck_y, ck_z, 25, { "boat" })
		if #boats > 0 then
			target = boats[math.random(#boats)]
		end
	end

	if target ~= nil then
		local tar_x, tar_y, tar_z = target.Transform:GetWorldPosition()

		local variance_x, variance_z = math.random(-24, 24), math.random(-24, 24)

		if variance_x > 0 then --wonder if there's anything I could do to make this better
			variance_x = math.clamp(variance_x, 16, 24)
		else
			variance_x = math.clamp(variance_x, -16, -24)
		end

		if variance_z > 0 then
			variance_z = math.clamp(variance_z, 16, 24)
		else
			variance_z = math.clamp(variance_z, -16, -24)
		end
		local start_x, start_y, start_z

		if rand_start then
			start_x, start_y, start_z = tar_x + variance_x, tar_y, tar_z + variance_z
		else
			start_x, start_y, start_z = ck_x, ck_y, ck_z
			tar_x, tar_z = tar_x + variance_x * 0.1, tar_z + variance_z * 0.1
		end

		local deg = math.atan2(start_z - tar_z, tar_x - start_x) / DEGREES

		local rad = math.rad(deg)

		local velx = math.cos(rad) * 2.5
		local velz = -math.sin(rad) * 2.5

		local dist = distsq(start_x, start_z, tar_x, tar_z)

		dist = math.sqrt(dist)

		if not rand_start then
			dist = dist + 8
		end

		for i = 1, math.clamp(dist, 0, 24) do
			inst:DoTaskInTime(FRAMES * i, function()
				local dx, dy, dz = (start_x + (i * velx)) + math.random(-1, 1), 0,
					(start_z + (i * velz)) + math.random(-1, 1)

				local fx = SpawnPrefab("dwx_geyserspawner")
				fx.Transform:SetPosition(dx, dy, dz)
				fx.chain_time = i
				fx.crab = inst
				fx.fisher_prefab = inst.prefab
				fx:ListenForEvent("onremove", function() removecrab(fx) end, inst)
				fx.dogeyserburbletask(fx)
			end)
		end
	end
end

local function DoSeekingAttack(inst)
	local ck_x, ck_y, ck_z = inst.Transform:GetWorldPosition()
	local target = #inst.all_targets > 1 and inst.all_targets[math.random(#inst.all_targets)] or
		inst.components.combat ~= nil and inst.components.combat.target

	if target == nil then
		local boats = TheSim:FindEntities(ck_x, ck_y, ck_z, 25, { "boat" })
		if #boats > 0 then
			target = boats[math.random(#boats)]
		end
	end

	if target ~= nil then
		local ix, iy, iz = inst.Transform:GetWorldPosition()
		local targetfocus = target

		local px, py, pz = targetfocus.Transform:GetWorldPosition()

		local dist = math.sqrt(distsq(ix, iz, px, pz)) + 24

		for i = 1, math.clamp(dist, 0, 48) do
			--local px, py, pz = targetfocus.Transform:GetWorldPosition()
			inst:DoTaskInTime((FRAMES * i) * Lerp(0, 1, dist / 10), function()
				if targetfocus == nil then
					return
				end
				px, py, pz = targetfocus.Transform:GetWorldPosition()
				if px == nil or pz == nil then
					return
				end
				local deg = math.atan2(iz - pz, px - ix) / DEGREES

				local rad = math.rad(deg)

				local velx = math.cos(rad)
				local velz = -math.sin(rad)

				local dx, dy, dz = ix + (i * velx), 0, iz + (i * velz)

				if targetfocus ~= nil then
					local fx = SpawnPrefab("dwx_geyserspawner")
					fx.Transform:SetPosition(dx, dy, dz)
					fx.chain_time = i
					fx.crab = inst
					fx.fisher_prefab = inst.prefab
					fx:ListenForEvent("onremove", function() removecrab(fx) end, inst)
					fx.dogeyserburbletask(fx)
				end
			end)
		end
	end
end

-- 帝王蟹驱散附近的蒸腾海域
local function clearboilingwater(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 16, {"CLASSIFIED"})
    for index, ent in ipairs(ents) do if ent and ent:IsValid() and ent.prefab == "boiling_water_spawner" then ent:DoTaskInTime(0, ent.Remove) end end
end

-- 帝王蟹战斗时的守护蟹钳回血
local function tryhealself(inst)
    local count = inst:counthelpclaw2hm()
    if count > 0 and inst.components.combat then
        inst.components.health.externalabsorbmodifiers:SetModifier(inst, 0.1 * count, "crabkingclaw2hm")
    else
        inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "crabkingclaw2hm")
    end
    if count > 0 and not inst.components.health:IsDead() then inst.components.health:DoDelta(count * 70, nil, nil, true) end
end
local function oncrabkingactivata(inst)
    if inst.healselftask2hm then inst.healselftask2hm:Cancel() end
    inst.healselftask2hm = inst:DoPeriodicTask(1, tryhealself)
    inst:DoTaskInTime(5, function()
        inst.wantstocast = true
        inst.attack_count = 0
        if inst.vulnerable_shine_task ~= nil then
            inst.vulnerable_shine_task:Cancel()
            inst.vulnerable_shine_task = nil
        end
        TheWorld.crabking_active = true
    end)
    inst:ListenForEvent("on_collide", OnCollide)
end

-- -- 帝王蟹的水柱在叠加触发后可以震飞船上的玩家,且可以把玩家震出船外(大理石甲可以防御),且击飞玩家手里的武器
-- local lastwaterspout
-- local boathealthdelta
-- local function cancelwaterspouttask2hm(inst)
--     inst.waterspoutidx2hm = nil
--     inst.waterspouttask2hm = nil
--     if inst.crabking2hm and inst.crabking2hm:IsValid() and inst.crabking2hm.listenboats2hm then
--         for i = #inst.crabking2hm.listenboats2hm, 1, -1 do
--             if inst.crabking2hm.listenboats2hm[i] == inst then
--                 inst:RemoveEventCallback("healthdelta", boathealthdelta)
--                 table.remove(inst.crabking2hm.listenboats2hm, i)
--             end
--         end
--     end
-- end
-- boathealthdelta = function(inst, data)
--     if lastwaterspout and lastwaterspout:IsValid() and inst:IsNear(lastwaterspout, 4.5) and GetTime() - lastwaterspout.spawntime < 0.1 and data and
--         data.newpercent and data.oldpercent and data.newpercent > 0 and data.newpercent < data.oldpercent then
--         local x, y, z = inst.Transform:GetWorldPosition()
--         local players = FindPlayersInRangeSq(x, y, z, 16, true)
--         for index, player in ipairs(players) do
--             if player:GetCurrentPlatform() == inst and player.sg and player.sg.currentstate and not player.components.health:IsDead() then
--                 inst.waterspoutidx2hm = (inst.waterspoutidx2hm or 0) + 1
--                 if inst.waterspouttask2hm then inst.waterspouttask2hm:Cancel() end
--                 inst.waterspouttask2hm = inst:DoTaskInTime(0.75, cancelwaterspouttask2hm)
--                 if inst.waterspoutidx2hm >= 5 then
--                     player.sg:GoToState("knockback", {
--                         knocker = lastwaterspout,
--                         radius = inst.waterspoutidx2hm,
--                         forcelanded = false,
--                         propsmashed = true,
--                         disableworldcollision2hm = true
--                     })
--                 else
--                     player:PushEvent("knockback", {
--                         knocker = lastwaterspout,
--                         radius = inst.waterspoutidx2hm,
--                         forcelanded = false,
--                         propsmashed = true,
--                         disableworldcollision2hm = true
--                     })
--                 end
--             end
--         end
--     end
-- end
local function oncrabkingsleep(inst)
    if inst.healselftask2hm then
        inst.healselftask2hm:Cancel()
        inst.healselftask2hm = nil
    end
    inst:RemoveEventCallback("on_collide", OnCollide)
    TheWorld.crabking_active = false
    -- if inst.listenboats2hm then
    --     for index, boat in ipairs(inst.listenboats2hm) do
    --         if boat and boat:IsValid() then
    --             boat.crabking2hm = nil
    --             boat:RemoveEventCallback("healthdelta", boathealthdelta)
    --         end
    --     end
    --     inst.listenboats2hm = nil
    -- end
end
-- local function doboatplayerattack(inst)
--     local x, y, z = inst.Transform:GetWorldPosition()
--     local players = FindPlayersInRangeSq(x, y, z, 6400, true)
--     inst.listenboats2hm = inst.listenboats2hm or {}
--     for index, player in ipairs(players) do
--         local boat = player:GetCurrentPlatform()
--         if boat and boat:IsValid() and boat.components.health and not boat.components.health:IsDead() and not table.contains(inst.listenboats2hm, boat) then
--             table.insert(inst.listenboats2hm, boat)
--             boat.crabking2hm = inst
--             boat:ListenForEvent("healthdelta", boathealthdelta)
--         end
--     end
-- end

local function getfreezerange(inst)
    return TUNING.CRABKING_FREEZE_RANGE * (0.75 + Remap(inst.countgems(inst).blue,0,9,0,2.25)) / 2
end

local function removecrab(inst)
    inst.crab = nil
    inst:Remove()
end

local function RemoveDecor(inst, data)
    inst.AnimState:ClearOverrideSymbol("gems_blue")
end

local function AddDecor(inst, data)
    if data == nil or data.slot == nil or data.itemprefab == nil then
        return
    end
    local symbol = "gems_blue"
    if data.itemprefab == "redgem" then
        symbol = "gems_red"
    elseif data.itemprefab == "purplegem" then
        symbol = "gems_purple"
    elseif data.itemprefab == "orangegem" then
        symbol = "gems_orange"
    elseif data.itemprefab == "yellowgem" then
        symbol = "gems_yellow"
    elseif data.itemprefab == "greengem" then
        symbol = "gems_green"
    elseif data.itemprefab == "opalpreciousgem" then
        symbol = "gems_opal"
    elseif data.itemprefab == "hermit_pearl" then
        symbol = "hermit_pearl"
    end

    inst.AnimState:OverrideSymbol("gem"..data.slot, "crab_king_build", symbol)
    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/gem_place")
    inst.shinefx = SpawnPrefab("crab_king_shine")
    inst.shinefx.entity:AddFollower()
    --inst.shinefx.entity:SetParent(inst)
    inst.shinefx.Follower:FollowSymbol(inst.GUID, "gem"..data.slot, 0, 0, 0)
    inst:PushEvent("socket")
end

local function clearsocketart(inst)
    inst.AnimState:ClearOverrideSymbol("gems_blue")
    for i=1,9 do
        inst.AnimState:ClearOverrideSymbol("gem"..i)
    end
end

local function socketitem(inst,item,socketnum)
    -- find open slot
    if socketnum then
        for i = #inst.socketlist, 1, -1 do
            if inst.socketlist[i] == socketnum then
                table.remove(inst.socketlist, i)
                break
            end
        end
    else
        if #inst.socketlist <=0 or item.prefab == "hermit_pearl" then
            socketnum = 5
        else
            local idx = math.random(1,#inst.socketlist)
            socketnum = inst.socketlist[idx]
            table.remove(inst.socketlist,idx)
        end
    end
    local data = {slot = socketnum, itemprefab = item.prefab}
    table.insert(inst.socketed,data)
    AddDecor(inst, data)
    item:RemoveTag("irreplaceable")
    item:Remove()

    if #inst.socketed >= MAX_SOCKETS then
        inst.components.health:SetMaxHealth(20000 + (math.floor(inst.countgems(inst).red/2) * math.floor(inst.countgems(inst).red/2) *TUNING.CRABKING_HEALTH_BONUS ))
        inst.components.health.currenthealth = inst.components.health.maxhealth

        MakeLargeBurnableCharacter(inst, "body")
        MakeHugeFreezableCharacter(inst, "body")

        inst.components.freezable:SetResistance(3 + inst.countgems(inst).blue)

        inst:AddTag("epic")
        inst:AddTag("animal")
        inst:AddTag("scarytoprey")
        inst:AddTag("hostile")

        inst:PushEvent("activate")
    end
end

local function doshine(inst,slot)
    inst.shinefx = SpawnPrefab("crab_king_shine")
    inst.shinefx.entity:AddFollower()
    --inst.shinefx.entity:SetParent(inst)
    inst.shinefx.Follower:FollowSymbol(inst.GUID, "gem"..slot, 0, 0, 0)
end

local function gemshine(inst,color)
    if inst.socketed then
        local t = 0
        for i,data in ipairs(inst.socketed)do

            if (data.itemprefab == "bluegem" and color == "blue") or
               (data.itemprefab == "redgem" and color == "red") or
               (data.itemprefab == "purplegem" and color == "purple") or
               (data.itemprefab == "orangegem" and color == "orange") or
               (data.itemprefab == "yellowgem" and color == "yellow") or
               (data.itemprefab == "greengem" and color == "green") or
               (data.itemprefab == "opalpreciousgem" or data.itemprefab == "hermit_pearl") then
                inst:DoTaskInTime( t*0.15 ,function()
                    doshine(inst,data.slot)
                end)
                t = t+1
            end

        end
    end
end

local RETARGET_MUST_TAGS = { "_combat"}
local RETARGET_CANT_TAGS = { "wall", "INLIMBO", "prey", "bird", "crab" }

local function RetargetFn(inst)
    local range = inst:GetPhysicsRadius(0) + 8
	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, TARGET_DIST, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS)
	inst.all_targets = {}

	for k, v in ipairs(ents) do
		if inst.components.combat:CanTarget(v)
			and (v.components.combat:TargetIs(inst) or v:IsNear(inst, range)) then
			table.insert(inst.all_targets, v)
		end
	end

	return FindEntity(
		inst,
		TARGET_DIST,
		function(guy)
			return inst.components.combat:CanTarget(guy)
				and (guy.components.combat:TargetIs(inst) or
					guy:IsNear(inst, range)
				)
		end,
		RETARGET_MUST_TAGS,
		RETARGET_CANT_TAGS
	)
end

local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
end

local function OnNewTarget(inst, data)

end

local function ShouldAcceptItem(inst, item)
    return item:HasTag("gem") and #inst.socketed < MAX_SOCKETS
end

local function OnGetItemFromPlayer(inst, giver, item)
    socketitem(inst,item)
    if inst:HasTag("hostile") or #inst.socketed < 6 then return end
    local gems = {redgem = 0, bluegem = 0, purplegem = 0, orangegem = 0, yellowgem = 0, greengem = 0}
    for i, socket in ipairs(inst.socketed) do if socket.itemprefab and gems[socket.itemprefab] then gems[socket.itemprefab] = 1 end end
    for itemprefab, value in pairs(gems) do if value == 0 then return end end
    local realgems = {}
    for i, socket in ipairs(inst.socketed) do
        if gems[socket.itemprefab] == 1 then
            gems[socket.itemprefab] = 0
        else
            table.insert(realgems, SpawnPrefab(socket.itemprefab))
        end
    end
    table.insert(realgems, SpawnPrefab("opalpreciousgem"))
    inst.socketed = {}
    inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
    inst.AnimState:ClearOverrideSymbol("gems_blue")
    for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
    for i, gem in ipairs(realgems) do
        inst.components.trader.onaccept(inst, giver, gem)
        if gem:IsValid() then gem:Remove() end
    end
end

local function OnRefuseItem(inst, item)

end

local function OnAttacked(inst, data)
    if data.attacker then
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, y1, z1 = data.attacker.Transform:GetWorldPosition()
        local r = data.attacker:GetPhysicsRadius(.5)
        r = r / (r + 1)
        SpawnPrefab("mining_fx").Transform:SetPosition(x1 + (x - x1) * r, 0, z1 + (z - z1) * r)
    end
end

local function OnRemove(inst)

end

local function OnDead(inst)
    if inst.arms then
        for i,arm in pairs(inst.arms)do
            if arm.prefab then
                arm:DoTaskInTime(math.random()*0.3, function(inst) arm.components.health:Kill() end)
            end
        end
    end
end

local function OnEntitySleep(inst)
    inst.components.health:DoDelta(inst.components.health.maxhealth - inst.components.health.currenthealth)
    if not inst.sg:HasStateTag("inert") then
        inst.components.health:SetMaxHealth(200000)
        inst.components.health.currenthealth = inst.components.health.maxhealth
        inst.spawnstacks(inst)
        inst.dropgems(inst)
        inst.sg:GoToState("inert")
        if inst.arms then
            for i,arm in pairs(inst.arms)do
                if arm.prefab then
                    arm:Remove()
                end
            end
        end
        inst.arms = nil
        inst:RemoveTag("epic")
        inst:RemoveTag("animal")
        inst:RemoveTag("scarytoprey")
        inst:RemoveTag("hostile")

        inst:RemoveComponent("freezable")
        inst:RemoveComponent("burnable")
   end
end

local function OnEntityWake(inst)

end

local function OnTimerDone(inst, data)
    if data.name == "claw_regen_timer" then
        inst.regenarm(inst)
    end
    if data.name == "fix_timer" then
        inst.wantstoheal = nil
    end
end

local function OnSave(inst, data)
    local ents = {}
    data.socketlist = inst.socketlist

    data.socketed = {}
    data.socketedslot = {}
    if #inst.socketed > 0 then
        for k,v in ipairs(inst.socketed)do
            table.insert(data.socketed,v.itemprefab)
            table.insert(data.socketedslot,v.slot)
        end
    end

    if inst.arms then
        data.arms = {}
        for i,arm in pairs(inst.arms)do
            if arm.prefab then
                data.arms[i] = arm.GUID
                table.insert(ents, arm.GUID)
            end
        end
    end

    data.healthpercent = inst.components.health:GetPercent()

    return ents
end

local function OnLoad(inst, data)

end

local function OnLoadPostPass(inst, newents, data)
    clearsocketart(inst)
    -- reset sockets
    if data then
        inst.socketlist = data.socketlist
        if data.socketed then
            for k,v in ipairs(data.socketed) do
                local gem = SpawnPrefab(v)
                socketitem(inst,gem,data.socketedslot[k])
            end
        end
        if data.arms and #data.arms > 0 then
            inst.arms = {}
            for i,arm in pairs(data.arms) do
                if newents[arm] then
                    inst.arms[i] = newents[arm].entity
                    inst.arms[i].armpos = i
                end
            end
        end
        if data.healthpercent then
            inst.components.health:SetPercent(data.healthpercent)
        end
    end

    --retrofit crabking spawner
    if not TheSim:FindFirstEntityWithTag("crabking_spawner") then
        local spawner = SpawnPrefab("crabking_spawner")
        local x, y, z = inst.Transform:GetWorldPosition()
        spawner.Transform:SetPosition(x, y, z)
        spawner.components.childspawner.childreninside = 0
        spawner.components.childspawner:TakeOwnership(inst)
    end
end

local BOAT_TAGS = {"boat"}
local CRABKING_SPELLGENERATOR_TAGS = {"crabking_spellgenerator"}
local SEASTACK_TAGS = {"seastack"}
local REPAIRED_PATCH_TAGS = {"boat_repaired_patch"}

local function startcastspell(inst, freeze)
    for i = 1, math.clamp(3 + (#inst.all_targets - 1), 1, 10) do
        if math.random() >= 0.25 then
            if math.random() >= 0.66 then
                inst:DoTaskInTime(i * GetRandomWithVariance(0.5, 0.75), function()
                    DoLineAttack(inst, true)
                end)
            else
                inst:DoTaskInTime(i * GetRandomWithVariance(0.5, 0.75), function()
                    DoLineAttack(inst, false)
                end)
                --_startcastspell(inst, false)
            end
        else
            DoSeekingAttack(inst)
        end
    end
    if TUNING.DSTU then clearboilingwater(inst) end
end

local gems =
{
	"blue",
	"red",
	"purple",
	"orange",
	"yellow",
	"green",
}
local function endcastspell(inst, lastwasfreeze)
    if inst.components.timer:TimerExists("spell_cooldown") then
        inst.components.timer:StopTimer("spell_cooldown")
    end
    inst.components.timer:StartTimer("spell_cooldown",TUNING.CRABKING_CAST_DELAY)

    inst.dofreezecast = nil
    inst.wantstocast = nil

    local range = getfreezerange(inst)

    if inst.components.health:GetPercent() < TUNING.CRABKING_FREEZE_THRESHOLD and inst:IsNearPlayer(range) then
        inst.dofreezecast = true
    end

    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 25, nil, nil, CRABKING_SPELLGENERATOR_TAGS)
    if #ents > 0 then
        for i,ent in pairs(ents)do
            if (not inst.components.freezable or not inst.components.freezable:IsFrozen()) and not inst.components.health:IsDead() then
                ent:PushEvent("endspell")
            else
                ent:Remove()
            end
        end
    end
    if lastwasfreeze then
        inst.dofreezecast = nil
        local x,y,z = inst.Transform:GetWorldPosition()
        local boatents = TheSim:FindEntities(x,y,z, 25, BOAT_TAGS)
        if #boatents > 0 then
            inst.wantstocast = true
        end
        inst.gemshine(inst,"blue")
        if TUNING.DSTU then clearboilingwater(inst) end
    else
        inst.gemshine(inst,"purple")
    end

    local atk_cd = (TUNING.CRABKING_CAST_TIME - math.floor(inst.countgems(inst).yellow * 0.75)) * 0.2

    if inst.components.timer:TimerExists("spell_cooldown") then
        inst.components.timer:StopTimer("spell_cooldown")
    end

    inst.dofreezecast = nil -- NO FREEZE, BAD!

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 64, nil, nil, CRABKING_SPELLGENERATOR_TAGS)
    if #ents > 0 then
        for i, ent in pairs(ents) do
            if (not inst.components.freezable or not inst.components.freezable:IsFrozen()) and not inst.components.health:IsDead() then
                ent:PushEvent("endspell")
            else
                ent:Remove()
            end
        end
    end

    inst.attack_count = math.clamp(inst.attack_count + 1, 0, 10)

    if inst.attack_count > math.random(2, 4) then
        inst.components.timer:StartTimer("spell_cooldown", 30 - inst.countgems(inst).yellow)

        inst.vulnerable_shine_task = inst:DoPeriodicTask(2, function()
            for k, v in ipairs(gems) do
                inst.gemshine(inst, v)
            end
            inst.wantstocast = false --keep it that way!!!
        end)

        inst.long_cd = inst:DoTaskInTime(30 - inst.countgems(inst).yellow, function()
            inst.wantstocast = true
            inst.attack_count = 0
            if inst.vulnerable_shine_task ~= nil then
                inst.vulnerable_shine_task:Cancel()
                inst.vulnerable_shine_task = nil
            end
            spawnwave(inst)
        end)
    else
        inst.components.timer:StartTimer("spell_cooldown", atk_cd)
        inst:DoTaskInTime(atk_cd, function()
            inst.wantstocast = true
        end)
    end
    -- doboatplayerattack(inst)
end

local function oncrabfreeze(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 25, nil, nil, CRABKING_SPELLGENERATOR_TAGS)
    if #ents > 0 then
        for i,ent in pairs(ents)do
            ent:Remove()
        end
    end
end

local function spawnstacks(inst)
    local pos = Vector3(inst.Transform:GetWorldPosition())
    local stacks =  math.max(0,TUNING.CRABKING_STACKS - #TheSim:FindEntities(pos.x,0,pos.z, 20, SEASTACK_TAGS))
    local pos = Vector3(inst.Transform:GetWorldPosition())
    if stacks > 0 then
        for i=1,stacks do
            local theta = math.random()*2*PI
            local radius = 9+ (math.pow(math.random(),0.8)* (17-9) )
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
            if not TheWorld.Map:GetPlatformAtPoint(pos.x+offset.x, pos.z+offset.z) and #TheSim:FindEntities(pos.x+offset.x,0,pos.z+offset.z, 3, SEASTACK_TAGS) <= 0 then
                inst:DoTaskInTime(math.random()*0.5,function()
                    local stack = SpawnPrefab("seastack")
                    stack.Transform:SetPosition(pos.x+offset.x,0,pos.z+offset.z)
                    stack.AnimState:PlayAnimation(stack.stackid.."_emerge")
                    stack.AnimState:PushAnimation(stack.stackid.."_full")
                    SpawnPrefab("splash_green_large").Transform:SetPosition(pos.x+offset.x,0,pos.z+offset.z)
                end)
            end
        end
    end
end

local function removearm(inst,armpos)
    inst.components.timer:StartTimer("claw_regen_delay"..armpos,CRABKING_CLAW_RESPAWN_DELAYS)
end

local function spawnarm(inst,armpos, fx)
    if inst.arms == nil then -- This happens when the Crab King goes into entity sleep we should not continue spawning arms.
        return
    end

    local clawsnum = TUNING.CRABKING_BASE_CLAWS + (math.floor(inst.countgems(inst).green/2))

    local theta = armpos*(2*PI/clawsnum )
    local radius = 8
    local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

    local pos = Vector3(inst.Transform:GetWorldPosition()) + offset
    local boat =  TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
    local tries = 0
    while boat and tries < 5 do

        if boat then
            pos = Vector3(boat.Transform:GetWorldPosition())
            local theta = math.random()*2*PI
            local radius = 5
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
            pos = pos + offset
        end
        boat =  TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
        tries = tries + 1
    end
    if not boat then
        local arm = SpawnPrefab("crabking2hm_claw")
        arm.Transform:SetPosition(pos.x, 0, pos.z)
        arm.armpos = armpos
        inst.arms[armpos] = arm
        local health = TUNING.CRABKING_CLAW_HEALTH + (math.ceil(inst.countgems(inst).green/2)* TUNING.CRABKING_CLAW_HEALTH_BOOST )
        arm.components.health:SetMaxHealth(health)
        arm.components.health:SetCurrentHealth(health)
        arm:PushEvent("emerge")

        local function death_event()
            removearm(inst, armpos)
            inst:RemoveEventCallback("death", death_event, arm)
        end
        inst:ListenForEvent("death", death_event, arm)
    end
    if fx then
        inst.gemshine(inst,"green")
    end
end

local function spawnarms(inst)

    local clawsnum = TUNING.CRABKING_BASE_CLAWS + (math.floor(inst.countgems(inst).green/2))


    if not inst.arms then
        inst.arms = {}
    end

    for i=1,clawsnum do
        if not inst.arms[i] or not inst.arms[i].prefab or not inst.arms[i]:IsValid() then
            inst:DoTaskInTime(ARMTIME[i%#ARMTIME+1],function() inst.spawnarm(inst,i)end)
        end
    end
end

local function regenarm(inst)
    if inst.arms then
        for i, arm in ipairs(inst.arms) do
            if not arm.prefab or not arm:IsValid() and not inst.components.timer:TimerExists("claw_regen_delay"..i) then
                inst.spawnarm(inst,i,true)
                break
            end
        end
        inst.components.timer:StartTimer("claw_regen_timer",CRABKING_CLAW_REGEN_DELAYS)
    end
end

local function finishfixing(inst)
    inst.wantstoheal = nil
    inst.components.timer:StartTimer("heal_cooldown",CRABKING_HEAL_DELAYS)
    if inst.components.timer:TimerExists("claw_regen_timer") then
        inst.components.timer:StartTimer("claw_regen_timer")
    end
    if inst.components.freezable then inst.components.freezable:Unfreeze() end
end

local function dropgems(inst)
    for i, socket in ipairs (inst.socketed) do
        local gem = SpawnPrefab(socket.itemprefab)
        inst.components.lootdropper:FlingItem(gem)
    end
    inst.socketed = {}
    inst.socketlist = {1,2,3,4,6,7,8,9}

    clearsocketart(inst)
    if inst.components.health and inst.components.health:IsDead() then return end
    local drop = math.random(7, 8)
    if #inst.socketed < drop then return end
    local realgems = {}
    for i, socket in ipairs(inst.socketed) do
        if i < drop then
            table.insert(realgems, SpawnPrefab(socket.itemprefab))
        else
            local gem = SpawnPrefab(socket.itemprefab)
            inst.components.lootdropper:FlingItem(gem)
        end
    end
    inst.socketed = {}
    inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
    inst.AnimState:ClearOverrideSymbol("gems_blue")
    for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
    for i, gem in ipairs(realgems) do
        inst.components.trader.onaccept(inst, inst, gem)
        if gem:IsValid() then gem:Remove() end
    end
end

local function removegem(inst,gemname)
    for i=#inst.socketed,1, -1 do
        if inst.socketed[i].itemprefab == gemname then
            table.remove(inst.socketed,i)
        end
    end
end
local function addgem(inst,gemname)
    table.insert(inst.socketed,{itemprefab = gemname})
end

local function countgems(inst)

    local gems = {
        red = 0,
        blue = 0,
        purple = 0,
        orange = 0,
        yellow = 0,
        green = 0,
        pearl = 0,
		opal = 0,
    }

    if inst.socketed then
        for i,data in ipairs(inst.socketed)do
            if data.itemprefab == "bluegem" then
                gems.blue = gems.blue + 1
            elseif data.itemprefab == "redgem" then
                gems.red = gems.red + 1
            elseif data.itemprefab == "purplegem" then
                gems.purple = gems.purple + 1
            elseif data.itemprefab == "orangegem" then
                gems.orange = gems.orange + 1
            elseif data.itemprefab == "yellowgem" then
                gems.yellow = gems.yellow + 1
            elseif data.itemprefab == "greengem" then
                gems.green = gems.green + 1
            elseif data.itemprefab == "opalpreciousgem" then
                gems.green =  gems.green + 1
                gems.yellow = gems.yellow + 1
                gems.orange = gems.orange + 1
                gems.red =    gems.red + 1
                gems.blue =   gems.blue + 1
                gems.purple = gems.purple + 1
                gems.opal =   gems.opal + 1
            elseif data.itemprefab == "hermit_pearl" then
                gems.green =  gems.green + 3
                gems.yellow = gems.yellow + 3
                gems.orange = gems.orange + 3
                gems.red =    gems.red + 3
                gems.blue =   gems.blue + 3
                gems.purple = gems.purple + 3
                gems.pearl = gems.pearl +1
            end
        end
    end

    local specialarmsNum = math.ceil(inst:counthelpclaw2hm() / 3)
    gems.green = gems.green + specialarmsNum
    gems.yellow = gems.yellow + specialarmsNum
    gems.orange = gems.orange + specialarmsNum
    gems.red = gems.red + specialarmsNum
    gems.blue = gems.blue + specialarmsNum
    gems.purple = gems.purple + specialarmsNum
    return gems
end

local function countarms(inst)
    local count = 0
    if inst.arms then
        for i,arm in ipairs(inst.arms)do
            if arm.prefab and arm:IsValid() then
                count = count+1
            end
        end
    end
    return count
end

local function spawnchunk(inst,prefab,pos)
    local chip = SpawnPrefab(prefab)
    if chip and pos then
        local pos = Vector3(inst.Transform:GetWorldPosition())
        chip.Transform:SetPosition(pos.x,0,pos.z)
    end
    return chip
end

local function setdamageart(inst)
    local index = math.random(1,#inst.nondamagedsymbollist)
    local art = inst.nondamagedsymbollist[index]
    table.remove(inst.nondamagedsymbollist,index)
    table.insert(inst.damagedsymbollist,art)

    local fx = SpawnPrefab("round_puff_fx_lg")
    fx.entity:AddFollower()
    fx.entity:SetParent(inst.entity)
    fx.Follower:FollowSymbol(inst.GUID, "damage"..art, 0, 0, 0)

    local pos = Vector3(inst.AnimState:GetSymbolPosition("damage"..art,0,0,0))
    if art == 7 or art == 8 then
       inst.spawnchunk(inst,"dwx_chip_high",pos)
    elseif art == 1 or art == 3 or art == 5 or art == 6 or art == 9 or art == 10 then
        inst.spawnchunk(inst,"dwx_chip_med",pos)
    elseif art == 2 or art == 4 then
        inst.spawnchunk(inst,"dwx_chip_low",pos)
    end
    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/rock_hit")
    inst.AnimState:OverrideSymbol("damage"..art, "crab_king_build", "nil")
end

local function setrepairedart(inst)
    local index = math.random(1,#inst.damagedsymbollist)
    local art = inst.damagedsymbollist[index]
    table.remove(inst.damagedsymbollist,index)
    table.insert(inst.nondamagedsymbollist,art)
    inst.AnimState:OverrideSymbol("damage"..art, "crab_king_build", "damage"..art)
end

local function onHealthChange(inst,data)
    local current = data.oldpercent

    local done = nil
    while data.newpercent and not done do
        if data.oldpercent > data.newpercent then
            current = math.max(current - 0.1,data.newpercent)
        else
            current = math.min(current + 0.1,data.newpercent)
        end
        if (current <= 0.9 and current > 0.8 and #inst.nondamagedsymbollist >= 10) or
           (current <= 0.8 and current > 0.7 and #inst.nondamagedsymbollist >= 9) or
           (current <= 0.7 and current > 0.6 and #inst.nondamagedsymbollist >= 8) or
           (current <= 0.6 and current > 0.5 and #inst.nondamagedsymbollist >= 7) or
           (current <= 0.5 and current > 0.4 and #inst.nondamagedsymbollist >= 6) or
           (current <= 0.4 and current > 0.3 and #inst.nondamagedsymbollist >= 5) or
           (current <= 0.3 and current > 0.2 and #inst.nondamagedsymbollist >= 4) or
           (current <= 0.2 and current > 0.1 and #inst.nondamagedsymbollist >= 3) or
           (current <= 0.1 and current > 0.0 and #inst.nondamagedsymbollist >= 2) or
           (current <= 0.0                   and #inst.nondamagedsymbollist >= 1) then

            setdamageart(inst)
        end

        if (current >= 1.0                   and #inst.nondamagedsymbollist < 10) or
           (current >= 0.9 and current < 1.0 and #inst.nondamagedsymbollist < 9) or
           (current >= 0.8 and current < 0.9 and #inst.nondamagedsymbollist < 8) or
           (current >= 0.7 and current < 0.8 and #inst.nondamagedsymbollist < 7) or
           (current >= 0.6 and current < 0.7 and #inst.nondamagedsymbollist < 6) or
           (current >= 0.5 and current < 0.6 and #inst.nondamagedsymbollist < 5) or
           (current >= 0.4 and current < 0.5 and #inst.nondamagedsymbollist < 4) or
           (current >= 0.3 and current < 0.4 and #inst.nondamagedsymbollist < 3) or
           (current >= 0.2 and current < 0.3 and #inst.nondamagedsymbollist < 2) or
           (current >= 0.1 and current < 0.2 and #inst.nondamagedsymbollist < 1) then

            setrepairedart(inst)
        end
        if current == data.newpercent then
            done = true
        end
    end
end

-- SetSharedLootTable( 'dwx',
-- {
--     {"chesspiece_crabking_sketch",          1.00},
--     {"trident_blueprint",                   1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {'meat',                                1.00},
--     {"singingshell_octave5",                1.00},
--     {"singingshell_octave5",                1.00},
--     {"singingshell_octave5",                1.00},
--     {"singingshell_octave5",                1.00},
--     {"singingshell_octave5",                0.50},
--     {"singingshell_octave5",                0.25},
--     {"singingshell_octave4",                1.00},
--     {"singingshell_octave4",                1.00},
--     {"singingshell_octave4",                1.00},
--     {"singingshell_octave4",                0.50},
--     {"singingshell_octave4",                0.25},
--     {"singingshell_octave3",                1.00},
--     {"singingshell_octave3",                1.00},
--     {"singingshell_octave3",                0.50},
--     {"barnacle",                            1.00},
--     {"barnacle",                            1.00},
--     {"barnacle",                            1.00},
--     {"barnacle",                            0.25},
--     {"barnacle",                            0.25},
--     {"barnacle",                            0.25},
--     {"barnacle",                            0.25},
-- })

local function GetWintersFeastOrnaments(inst)
	local gems = inst:countgems()
	local is_pearled = gems.pearl > 0
	if not is_pearled and gems.opal >= 3 then
		local hermit = TheWorld.components.messagebottlemanager ~= nil and TheWorld.components.messagebottlemanager:GetHermitCrab()
		is_pearled = hermit and hermit.pearlgiven
	end

	return is_pearled and {basic = 2, special = "winter_ornament_boss_crabkingpearl"} or {basic = 1, special = "winter_ornament_boss_crabking"}
end

local function PushMusic(inst)
    if ThePlayer == nil or not inst:HasTag("epic") then
        inst._playingmusic = false
    elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
        inst._playingmusic = true
        ThePlayer:PushEvent("triggeredevent", { name = "crabking" })
    elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
        inst._playingmusic = false
    end
end

local function getstatus(inst)
    return inst.sg and inst.sg:HasStateTag("inert") and "INERT"
end

-- 帝王蟹的举石头钳子和蟹钳会接住炮弹了
local function unprotectshadowself(inst) if not inst.components.health:IsDead() then inst.components.health:SetInvincible(false) end end
local function proxycomplexprojectile(inst, prefab, rot, far)
    if inst.components.health:IsDead() then
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, 1.5, nil, nil, {"crabking_claw", "crabking"})
    for i, v in ipairs(ents) do
        if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then
            v.components.health:SetInvincible(true)
            if v.protesttask2hm then
                v.protesttask2hm:Cancel()
                v.protesttask2hm = nil
            end
            v.protesttask2hm = v:DoTaskInTime(0.25, unprotectshadowself)
        end
    end
    local projectile = SpawnPrefab(prefab)
    if projectile == nil then return end
    if not projectile.components.complexprojectile then
        projectile:Remove()
        return
    end
    if far then projectile.components.complexprojectile.horizontalSpeed = projectile.components.complexprojectile.horizontalSpeed * 1.35 end
    projectile.disablecrab2hm = true
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = rot * DEGREES
    local radius = 0.5
    local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
    projectile.Transform:SetPosition(x + offset.x, y + TUNING.BOAT.BOATCANNON.PROJECTILE_INITIAL_HEIGHT, z + offset.z)
    projectile.shooter = inst
    local angle = -rot * DEGREES
    local range = TUNING.BOAT.BOATCANNON.RANGE
    local targetpos = Vector3(x + math.cos(angle) * range, y, z + math.sin(angle) * range)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
end
local function clawdelayproxycomplexprojectile(inst, prefab, rot)
    inst.sg:Start()
    if inst.components.health:IsDead() then
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.sg:GoToState("death")
    else
        inst.sg:GoToState("emerge")
        local time = math.min(inst.AnimState:GetCurrentAnimationLength(), 0.5)
        inst:DoTaskInTime(time, proxycomplexprojectile, prefab, rot)
    end
end

local function processcomplexprojectile(inst, v)
    -- 无伤接炮弹太奇怪了，但也不会受到太高伤害直接导致死亡
    if v.components.health:IsInvincible() or v.components.health.currenthealth > TUNING.CANNONBALL_DAMAGE then
        if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
            v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
        end
        SpawnPrefab("crab_king_shine").Transform:SetPosition(inst.Transform:GetWorldPosition())
        local target = inst.shooter or inst.components.complexprojectile.attacker
        local rot
        if target and target:IsValid() then
            rot = v:GetAngleToPoint(target:GetPosition():Get())
        else
            rot = v:GetAngleToPoint(inst:GetPosition():Get())
        end
        -- 反弹炮弹
        if v.prefab == "crabking2hm" then
            v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.25, 1), proxycomplexprojectile, inst.prefab, rot, true)
        else
            v.sg:Stop()
            v.AnimState:PlayAnimation("clamp_pre")
            if v.boat and v.boat.prefab == "crabking2hm" and v.releaseclamp then v:releaseclamp() end
            v.Transform:SetRotation(rot - 180)
            local time = v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.5, 1), clawdelayproxycomplexprojectile, inst.prefab, rot)
        end
    else
        -- 牺牲来格挡炮弹
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
            v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
        end
    end
    inst.components.complexprojectile:Cancel()
    inst:DoTaskInTime(0, inst.Remove)
end
-- 帝王蟹的守护蟹钳计算
local function counthelpclaw2hm(inst)
    local count = 0
    if inst.arms then
        for i, arm in ipairs(inst.arms) do if arm.prefab and arm:IsValid() and arm.boat and arm.boat.prefab == "crabking2hm" then count = count + 1 end end
    end
    return count
end

-- 帝王蟹的守护蟹钳攻击反伤,和举起石头回复时的炮弹反弹
local function OnReflectDamage(inst, data)
    if data.attacker ~= nil and data.attacker:IsValid() then
        local impactfx = SpawnPrefab("impact")
        if impactfx ~= nil then
            impactfx.Transform:SetPosition(data.attacker.Transform:GetWorldPosition())
            impactfx:FacePoint(inst.Transform:GetWorldPosition())
        end
    end
end

local function GetAttacked_Internal2hm(inst, data)
    if data and data.attacker and data.attacker:IsValid() then
        if data.attacker.disablecrab2hm then
            inst.oncemiss2hm = true
        elseif data.attacker.components.complexprojectile and not data.attacker.disablecrab2hm and not inst.components.health:IsDead() and inst.sg and
            inst.sg:HasStateTag("fixing") then
            inst.finishfixing(inst)
            if inst.lastfixloop then
                processcomplexprojectile(data.attacker, inst)
                data.attacker.disablecrab2hm = true
                inst.oncemiss2hm = true
            else
                inst.fixhits = (inst.fixhits or 0) - 1
            end
            if inst.components.damagereflect then inst.components.damagereflect:SetDefaultDamage(0) end
        elseif data.attacker ~= inst and data.attacker.prefab ~= "crabking2hm" and data.attacker.prefab ~= "crabking2hm_claw" and data.attacker.components.health and
            not data.attacker.components.health:IsDead() then
            if not inst.components.damagereflect then
                inst:AddComponent("damagereflect")
                inst:ListenForEvent("onreflectdamage", OnReflectDamage)
            end
            inst.components.damagereflect:SetDefaultDamage(inst:counthelpclaw2hm() * 10)
        elseif inst.components.damagereflect then
            inst.components.damagereflect:SetDefaultDamage(0)
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:SetPhysicsRadiusOverride(3.4) --2.5

    MakeWaterObstaclePhysics(inst, 1.7, 2, 0.1)

    inst.MiniMapEntity:SetIcon("crabking.png")

    local s  = 0.7
    inst.Transform:SetScale(s, s, s)

    inst.AnimState:SetBank("king_crab")
    inst.AnimState:SetBuild("crab_king_build")

    inst:AddTag("ignorewalkableplatforms") -- added so the crab king will not get attached to a moving boat when it is past entity-sleep range
    inst:AddTag("crabking")
    inst:AddTag("largecreature")
    inst:AddTag("gemsocket")
    inst:AddTag("birdblocker")
    inst:AddTag("lunar_aligned")
    inst:AddTag("crab")

    inst.AnimState:PlayAnimation("inert", true)

    inst.entity:SetPristine()

    inst.scrapbook_removedeps = { "moon_altar_cosmic" }

    inst.spawnchunk = spawnchunk

    if not TheNet:IsDedicated() then
        inst._playingmusic = false
        inst:DoPeriodicTask(1, PushMusic, 0)
    end

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_maxhealth = { TUNING.CRABKING_HEALTH, TUNING.CRABKING_HEALTH + (35 * TUNING.CRABKING_HEALTH_BONUS) }
    inst.scrapbook_damage = 0

    ------------------------------------------

    inst:SetStateGraph("SGcrabking2hm")

    ------------------

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(200000)--TUNING.CRABKING_HEALTH)
    inst.components.health.destroytime = 5

    ------------------

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.CRABKING_DAMAGE)
    inst.components.combat.playerdamagepercent = TUNING.CRABKING_DAMAGE_PLAYER_PERCENT
    inst.components.combat:SetRange(TUNING.CRABKING_ATTACK_RANGE)
    inst.components.combat:SetAreaDamage(TUNING.CRABKING_AOE_RANGE, TUNING.CRABKING_AOE_SCALE)
    inst.components.combat.hiteffectsymbol = "body"
    inst.components.combat:SetAttackPeriod(TUNING.CRABKING_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat.conditionexternaldamagetakenmultipliers = {
        function(_inst, _attacker, _weapon)
            if _attacker and _attacker.prefab == "cannonball_rock" and _attacker:IsValid() then return 4 end
        end,
    }

    ------------------------------------------

    inst:AddComponent("inventory")

    ------------------------------------------

    inst:AddComponent("explosiveresist")

    ------------------------------------------

    inst:AddComponent("lootdropper")
    -- inst.components.lootdropper:SetChanceLootTable('dwx')
	-- inst.components.lootdropper.GetWintersFeastOrnaments = GetWintersFeastOrnaments

    ------------------------------------------

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus
    inst.components.inspectable:RecordViews()

    ------------------------------------------

    inst:AddComponent("timer")

    ------------------------------------------

    inst:AddComponent("knownlocations")

    ------------------------------------------

    inst:AddComponent("entitytracker")

    ------------------------------------------

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(ShouldAcceptItem)
    inst.components.trader.onaccept = OnGetItemFromPlayer
    inst.components.trader.onrefuse = OnRefuseItem
    inst.components.trader.deleteitemonaccept = false

    ------------------------------------------

    inst:SetBrain(brain)

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("death", OnDead)
    inst:ListenForEvent("onremove", OnRemove)
    inst:ListenForEvent("newcombattarget", OnNewTarget)
    inst:ListenForEvent("entitysleep", OnEntitySleep)
    inst:ListenForEvent("entitywake", OnEntityWake)
    inst:ListenForEvent("timerdone", OnTimerDone)
    inst:ListenForEvent("healthdelta", onHealthChange)
    inst:ListenForEvent("freeze", oncrabfreeze)
    inst:ListenForEvent("GetAttacked_Internal2hm", GetAttacked_Internal2hm)
    inst:ListenForEvent("activate", oncrabkingactivata)
    inst:ListenForEvent("entitysleep", oncrabkingsleep)
	inst:ListenForEvent("unfreeze", function()
		inst.attack_count = math.clamp(inst.attack_count + -2, 0, 10)
		inst.gemshine(inst, "blue")
		local x, y, z = inst.Transform:GetWorldPosition()
		local fx = SpawnPrefab("dwx_feeze")
		fx.crab = inst
		fx:ListenForEvent("onremove", function() removecrab(fx) end, inst)
		fx.Transform:SetPosition(x, y, z)
		local scale = 0.75 + Remap(inst.countgems(inst).blue, 0, 9, 0, 1.55)
		fx.Transform:SetScale(scale, scale, scale)
	end)

    clearsocketart(inst)
    inst.attack_count = 0
    inst.wantstocast = true
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    inst.socketlist = {1,2,3,4,6,7,8,9}
    inst.damagedsymbollist = {}
    inst.nondamagedsymbollist = {1,2,3,4,5,6,7,8,9,10}
    inst.socketed = {}
    inst.startcastspell = startcastspell
    inst.endcastspell = endcastspell
    inst.spawnarms = spawnarms
    inst.regenarm = regenarm
    inst.spawnarm = spawnarm
    inst.spawnstacks = spawnstacks
    inst.countarms = countarms
    inst.countgems = countgems
    inst.dropgems = dropgems
    inst.finishfixing = finishfixing
    inst.gemshine = gemshine
    inst.spawnchunk = spawnchunk
    inst.removegem = removegem
    inst.addgem = addgem
    inst.getfreezerange = getfreezerange
    inst.counthelpclaw2hm = counthelpclaw2hm

    return inst
end

local function dogeyserburbletask(inst)
    if inst.burbletask then
        inst.burbletask:Cancel()
        inst.burbletask = nil
    end
    local totalcasttime = (TUNING.CRABKING_CAST_TIME -
        (inst.crab and inst.crab:IsValid() and math.floor(inst.crab.countgems(inst.crab).yellow / 2 or 0)))
    local time = Remap(inst.components.age:GetAge(), 0, totalcasttime, 0.2, 0.01)
    inst.burbletask = inst:DoTaskInTime(time + 1, function() inst.burble(inst) end) -- 0.01+ math.random()*0.1
end

local function burble(inst)
    local MAXRADIUS = 1
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = math.random() * 2 * PI
    local radius = math.pow(math.random(), 0.8) * MAXRADIUS
    local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
    local prefab = "crab_king_bubble" .. math.random(1, 3)

    if TheWorld.Map:IsOceanAtPoint(x + offset.x, 0, z + offset.z) then
        local fx = SpawnPrefab(prefab)
        fx.Transform:SetPosition(x + offset.x, y + offset.y, z + offset.z)
    else
        local boat = TheWorld.Map:GetPlatformAtPoint(x + offset.x, z + offset.z)
        if boat then
            ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.1, 0.01, 0.3, boat, boat:GetPhysicsRadius(4))
        end
    end

    dogeyserburbletask(inst)
end

local function endgeyser(inst)
    inst:DoTaskInTime(2.4, function()
        if inst.burbletask then
            inst.burbletask:Cancel()
            inst.burbletask = nil
        end
    end)

    inst:DoTaskInTime( --[[(math.random() * 0.4)+]] (inst.chain_time * 0.025), function()
        local MAXRADIUS = 1.25
        local x, y, z = inst.Transform:GetWorldPosition()
        local theta = math.random() * 2 * PI
        local radius = math.pow(math.random(), 0.8) * MAXRADIUS
        local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
        local prefab = "crab_king_waterspout"
        if TheWorld.Map:IsOceanAtPoint(x + offset.x, 0, z + offset.z) then
            local fx = SpawnPrefab(prefab)
            fx.Transform:SetPosition(x + offset.x, y + offset.y, z + offset.z)

            local INITIAL_LAUNCH_HEIGHT = 0.1
            local SPEED = 8
            local CANT_HAVE_TAGS = { "INLIMBO", "outofreach", "DECOR" }
            local function launch_away(inst, position)
                local ix, iy, iz = inst.Transform:GetWorldPosition()
                inst.Physics:Teleport(ix, iy + INITIAL_LAUNCH_HEIGHT, iz)

                local px, py, pz = position:Get()
                local angle = (180 - inst:GetAngleToPoint(px, py, pz)) * DEGREES
                local sina, cosa = math.sin(angle), math.cos(angle)
                inst.Physics:SetVel(SPEED * cosa, 4 + SPEED, SPEED * sina)
            end
            local affected_entities = TheSim:FindEntities(x + offset.x, y + offset.y, z + offset.z, 2, nil,
                CANT_HAVE_TAGS)
            for _, v in ipairs(affected_entities) do
                if v.components.oceanfishable ~= nil then
                    -- Launch fishable things because why not.

                    local projectile = v.components.oceanfishable:MakeProjectile()
                    if projectile.components.weighable ~= nil then
                        projectile.components.weighable.prefab_override_owner = inst.fisher_prefab
                    end
                    local position = Vector3(x + offset.x, y + offset.y, z + offset.z)
                    if projectile.components.complexprojectile then
                        projectile.components.complexprojectile:SetHorizontalSpeed(16)
                        projectile.components.complexprojectile:SetGravity(-30)
                        projectile.components.complexprojectile:SetLaunchOffset(Vector3(0, 0.5, 0))
                        projectile.components.complexprojectile:SetTargetOffset(Vector3(0, 0.5, 0))

                        local v_position = v:GetPosition()
                        local launch_position = v_position + (v_position - position):Normalize() * SPEED
                        projectile.components.complexprojectile:Launch(launch_position, projectile)
                    else
                        launch_away(projectile, position)
                    end
                end
                if v.components.health ~= nil and v.components.combat ~= nil and not v:HasTag("boat") and v.prefab ~= "crabking2hm_claw" and v.prefab ~= "crabking2hm" then
                    v.components.combat:GetAttacked_Internal(inst.crab, 34 + inst.crab.countgems(inst.crab).purple * 2)
                end
            end
        else
            local boat = TheWorld.Map:GetPlatformAtPoint(x + offset.x, z + offset.z)
            if boat then
                local pt = Vector3(x + offset.x, 0, z + offset.z)

                local x, y, z = inst.Transform:GetWorldPosition()
                local ents = TheSim:FindEntities(x, y, z, 4)
                local mult = 1
                -- look for the pirate hat
                if ents and #ents > 0 then
                    for i, ent in ipairs(ents) do
                        if ent:GetCurrentPlatform() and ent:GetCurrentPlatform() == inst then
                            if ent:HasTag("boat_health_buffer") then
                                mult = 0.33
                            end
                        end
                    end
                end

                boat.components.health:DoDelta((-2 - math.floor(inst.crab.countgems(inst.crab).purple * 0.5)) * mult)
                boat.SoundEmitter:PlaySoundWithParams("turnoftides/common/together/boat/damage",
                    { intensity = .6 })

                -- look for patches
                --[[local nearpatch = TheSim:FindEntities(pt.x, 0, pt.z, 2, REPAIRED_PATCH_TAGS)
                for i, patch in pairs(nearpatch) do
                    pt = Vector3(patch.Transform:GetWorldPosition())
                    patch:Remove()
                    break
                end]]
                --boat:PushEvent("spawnnewboatleak", { pt = pt, leak_size = "small_leak", playsoundfx = true })
            end
        end
    end)

    inst:DoTaskInTime(5, function() inst:Remove() end)
end

local function geyserfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("fx")
    inst:AddTag("crabking_spellgenerator")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("age")

    inst.persists = false

    inst.burble = burble
    inst.dogeyserburbletask = dogeyserburbletask

    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/bubble_LP", "burble")
    inst.SoundEmitter:SetParameter("burble", "intensity", 0)
    inst.burblestarttime = GetTime()
    inst.burbleintensity = inst:DoPeriodicTask(1, function()
        local totalcasttime = TUNING.CRABKING_CAST_TIME -
            ((inst.crab and inst.crab:IsValid()) and math.floor(inst.crab.countgems(inst.crab).yellow / 2) or 0)
        local intensity = math.min(1, (GetTime() - inst.burblestarttime) / totalcasttime)

        inst.SoundEmitter:SetParameter("burble", "intensity", intensity)
    end)
    inst:ListenForEvent("onremove", function()
        if inst.burbletask then
            inst.burbletask:Cancel()
            inst.burbletask = nil
        end
        if inst.burbleintensity then
            inst.burbleintensity:Cancel()
            inst.burbleintensity = nil
        end
        inst.SoundEmitter:KillSound("burble")
    end)

    inst:ListenForEvent("endspell", function()
        endgeyser(inst)
    end)

    inst:DoTaskInTime(TUNING.CRABKING_CAST_TIME + 2, function()
        inst:Remove()
    end)



    return inst
end

-- FREEZE FX

local function onfreeze(inst, target)
    if not target:IsValid() then
        --target killed or removed in combat damage phase
        return
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.components.combat ~= nil and inst.crab and inst.crab:IsValid() then
        target.components.combat:SuggestTarget(inst.crab)
    end

    if target.sg ~= nil and not target.sg:HasStateTag("frozen") and inst.crab and inst.crab:IsValid() then
        target:PushEvent("attacked", { attacker = inst.crab, damage = 0, weapon = inst })
    end

    if target.components.freezable ~= nil then
        target.components.freezable:AddColdness(10,10 + Remap((inst.crab and inst.crab:IsValid() and inst.crab.countgems(inst.crab).blue or 0),0,9,0,10) )
        target.components.freezable:SpawnShatterFX()
    end
end

local function dofreezefz(inst)
    if inst.freezetask then
        inst.freezetask:Cancel()
        inst.freezetask = nil
    end
    local time = 0.1
    inst.freezetask = inst:DoTaskInTime(time,function() inst.freezefx(inst) end)
end

local function freezefx(inst)
    local function spawnfx()
        local MAXRADIUS = inst.crab and inst.crab:IsValid() and getfreezerange(inst.crab) or (TUNING.CRABKING_FREEZE_RANGE * 1.75)
        local x,y,z = inst.Transform:GetWorldPosition()
        local theta = math.random()*2*PI
        local radius = 4+ math.pow(math.random(),0.8)* MAXRADIUS
        local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

        local prefab = "crab_king_icefx"
        local fx = SpawnPrefab(prefab)
        fx.Transform:SetPosition(x+offset.x,y+offset.y,z+offset.z)
    end

    local MAXFX = Remap(( inst.crab and inst.crab:IsValid() and inst.crab.countgems(inst.crab).blue or 0),0, 9,5,15)


    local fx = Remap(inst.components.age:GetAge(),0,CRABKING_CAST_TIME_FREEZES - (math.min((inst.crab and inst.crab:IsValid() and math.floor(inst.crab.countgems(inst.crab).yellow/2) or 0),4)),1,MAXFX)

    for i=1,fx do
        if math.random()<0.2 then
            spawnfx()
        end
    end

    dofreezefz(inst)
end

local FREEZE_CANT_TAGS = {"crab", "shadow", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "INLIMBO"}

local function dofreeze(inst)
    local interval = 0.2
    local pos = Vector3(inst.Transform:GetWorldPosition())
    local range = inst.crab and inst.crab:IsValid() and getfreezerange(inst.crab) or (TUNING.CRABKING_FREEZE_RANGE * 1.75)
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, range, nil, FREEZE_CANT_TAGS)
    for i,v in pairs(ents)do
        if v.components.temperature then
            local rate = (CRABKING_BASE_FREEZE_AMOUNTS + ((inst.crab and inst.crab:IsValid() and inst.crab.countgems(inst.crab).blue or 0) * TUNING.CRABKING_FREEZE_INCRAMENT)) /( (CRABKING_CAST_TIME_FREEZES - (inst.crab and inst.crab:IsValid() and math.floor(inst.crab.countgems(inst.crab).yellow/2) or 0) ) /interval)
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

    local time = 0.2
    inst.lowertemptask = inst:DoTaskInTime(time,function() inst.dofreeze(inst) end)
end

local function endfreeze(inst)
    if inst.freezetask then
        inst.freezetask:Cancel()
        inst.freezetask = nil
    end

    if inst.lowertemptask then
        inst.lowertemptask:Cancel()
        inst.lowertemptask = nil
    end

    local pos = Vector3(inst.Transform:GetWorldPosition())
    local range = inst.crab and inst.crab:IsValid() and getfreezerange(inst.crab) or (TUNING.CRABKING_FREEZE_RANGE * 0.75)
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, range, nil, FREEZE_CANT_TAGS)
    for i,v in pairs(ents)do
        onfreeze(inst, v)
    end
    SpawnPrefab("crabking_ring_fx").Transform:SetPosition(pos.x,pos.y,pos.z)
    inst:DoTaskInTime(1,function() inst:Remove() end)
end

local function freezefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("fx")
    inst:AddTag("crabking_spellgenerator")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("age")

    inst.persists = false

    inst.freezefx = freezefx
    inst.dofreeze = dofreeze
    inst:DoTaskInTime(0,function()
        dofreezefz(inst)
        dofreeze(inst)
    end)

    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/ice_attack")

    inst:ListenForEvent("onremove", function()
        if inst.burbletask then
            inst.burbletask:Cancel()
            inst.burbletask = nil
        end
    end)

    inst:ListenForEvent("endspell", function()
        endfreeze(inst)
    end)

    inst:DoTaskInTime(TUNING.CRABKING_CAST_TIME+2,function()
        endfreeze(inst)
    end)

    return inst
end

local function chipfn(type)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    local phys = inst.entity:AddPhysics()
    phys:SetMass(1)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.FLYERS)
    phys:ClearCollisionMask()
    phys:CollidesWith((TheWorld.has_ocean and COLLISION.GROUND) or COLLISION.WORLD)
    phys:SetCapsule(0.5, 1)

    local s  = 0.7
    inst.Transform:SetScale(s, s, s)

    inst.AnimState:SetBank("rockchip")
    inst.AnimState:SetBuild("crabking_rockchip")
    inst.AnimState:PlayAnimation("rockchip_"..type)

    inst:AddTag("NOCLICK")
    inst:AddTag("fx")

    local down = TheCamera:GetDownVec()
    local offset = (math.random()*30 + 50)
    if math.random() > 0.5 then
        offset = -offset
    end
    local angle = (math.atan2(-down.z, down.x) / DEGREES ) + offset
    inst.Transform:SetRotation(angle)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("hit_water") or inst.AnimState:IsCurrentAnimation("hit_land") then
            inst:Remove()
        end
        if not inst.landed then
            inst.Physics:Stop()
            inst.landed = true
            local pos = Vector3(inst.Transform:GetWorldPosition())
            if not TheWorld.Map:IsVisualGroundAtPoint(pos.x,pos.y,pos.z) and not TheWorld.Map:GetPlatformAtPoint(pos.x,pos.z) then
                inst.AnimState:PlayAnimation("hit_water")
            else
                inst.AnimState:PlayAnimation("hit_land")
            end
        end
    end)

    inst.Physics:SetMotorVel(math.random(8,12), 0, 0)

    inst.persists = false

    return inst
end

return Prefab("crabking2hm", fn, assets, prefabs),
       Prefab("dwx_geyserspawner", geyserfn, nil, geyserprefabs),
       Prefab("dwx_feeze", freezefn, nil, freezeprefabs),
       Prefab("dwx_chip_high", function() return chipfn("high") end, chipassets),
       Prefab("dwx_chip_med",  function() return chipfn("mid") end, chipassets),
       Prefab("dwx_chip_low",  function() return chipfn("low") end,  chipassets)
