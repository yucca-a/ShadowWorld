local CollisionMode = GetModConfigData("wall_destroy")
local UpvalueHacker = require("upvaluehacker2hm")
if CollisionMode ~= -1 then
    	-- 移除船摧毁后对船上生物的秒杀伤害
    -- local function newdestroyonboat(self)
	--    if not TheWorld.ismastersim then return end
	--     local IGNORE_WALKABLE_PLATFORM_TAGS_ON_REMOVE = { "ignorewalkableplatforms", "ignorewalkableplatformdrowning", "activeprojectile", "flying", "FX", "DECOR", "INLIMBO", "player" }
	--       function self:DestroyObjectsOnPlatform()
    --       if not TheWorld.ismastersim then return end

    --       local x, y, z = self.inst.Transform:GetWorldPosition()
    --         for i, v in ipairs(TheSim:FindEntities(x, y, z, self.platform_radius, nil, IGNORE_WALKABLE_PLATFORM_TAGS_ON_REMOVE)) do
    --             if v ~= self.inst and v.entity:GetParent() == nil and v.components.amphibiouscreature == nil and v.components.drownable == nil then
    --                 if v.components.inventoryitem ~= nil then
    --                    v.components.inventoryitem:SetLanded(false, true)
    --                 else
    --                    DestroyEntity(v, self.inst, false, true)
    --                 end
    --             end
    --         end
	--     end
    -- end
    local oldDestroyEntity = GLOBAL.DestroyEntity
    GLOBAL.DestroyEntity = function(ent, destroyer, kill_all_creatures, ...)
        if destroyer and destroyer.components and destroyer.components.walkablellatform then kill_all_creatures = false end
        return oldDestroyEntity(ent, destroyer, kill_all_creatures, ...)
    end
	-- AddComponentPostInit("walkableplatform",newdestroyonboat)
	
	-----------------------------------------------------------------------------------
    require("physics")
    local function checknoprotect(inst, other)
        return inst.prefab ~= other.prefab and not other:HasTag("structure") and not other.components.boatphysics and
                   not (inst.components.follower and inst.components.follower.leader and inst.components.follower.leader == other) and
                   not (inst.components.homeseeker and inst.components.homeseeker.home and inst.components.homeseeker.home.prefab == other.prefab)
    end
    local function checkcanworkable(inst, other)
        local workable = other.components.workable
        return workable ~= nil and workable.workable and workable.workleft > 0 and not workable.invincible2hm and workable.action ~= nil and workable.action ~=
                   ACTIONS.NET and not other:HasTag("shadecanopysmall") and (not workable.tough or inst:HasTag("toughworker"))
    end
    local function onothercollide(inst, other)
        if other:IsValid() then
            if other.components.combat and not other:HasTag("epic") then
                -- Use TheWorld as Attacker To Avoid Leif's Battle
                other.components.combat:GetAttacked_Internal(TheWorld, math.max(inst.components.combat.defaultdamage, 10))
            elseif checkcanworkable(inst, other) then
                local left = other.components.workable.workleft
                other.components.workable:WorkedBy_Internal(TheWorld, (inst:HasTag("epic") and 5 or 2))
                if other:IsValid() and other.components.workable and left <= other.components.workable.workleft then
                    other.components.workable.invincible2hm = true
                end
            end
        end
    end
    -- 让自己不被世界碰撞
    local function recoverworldphysics(inst)
        if inst.Physics and inst._disableWorldCollide2hm then
            if inst._disableWorldCollide2hm.testboat then inst.Physics:CollidesWith(COLLISION.BOAT_LIMITS) end
            if inst._disableWorldCollide2hm.testlandocean then inst.Physics:CollidesWith(COLLISION.LAND_OCEAN_LIMITS) end
        end
        inst._disableWorldCollide2hm = nil
    end
    local blacklist = {"alterguardian_phase2", "alterguardian_phase1"}
    local blacklist2 = {"sharkboi", "rocky"}
    local function disableworldcollide(inst)
        local mask = inst.Physics:GetCollisionMask()
        local testboat = (mask % 128) >= 64
        local testlandocean = (mask % 256) >= 128
        inst._disableWorldCollide2hm = {testboat = testboat, testlandocean = testlandocean}
        if testboat then inst.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS)end
        if testlandocean then inst.Physics:ClearCollidesWith(COLLISION.LAND_OCEAN_LIMITS) end
        if table.contains(blacklist,inst.prefab) then
		inst:DoTaskInTime(5, recoverworldphysics)
		else
		inst:DoTaskInTime(30, recoverworldphysics)
		end
    end
    -- 让其他单位不再碰撞
    local function recovesomephysics(inst, group)
        if inst.Physics then inst.Physics:CollidesWith(group) end
        inst._disableCollide2hm = nil
    end
    local function disablesomecollide(inst, group)
        if inst.Physics then inst.Physics:ClearCollidesWith(group) end
        inst:DoTaskInTime(1, recovesomephysics, group)
    end
    -- 卡位期间无敌
    local function invincibleTest(inst, attacker)
        if inst.invincibleCollidetask2hm ~= nil and attacker and (attacker:HasTag("player") or attacker:HasTag("companion") or
            (attacker.components.follower and attacker.components.follower.leader and attacker.components.follower.leader:HasTag("player"))) then
            SpawnPrefab("planar_hit_fx").entity:SetParent(inst.entity)
            return 0
        end
        return 1
    end
    local function cancelinvincibleCollidetask(inst)
        inst.invincibleCollidetask2hm = nil
        if inst.wallGetResist2hm then
            if inst.components.damagetyperesist then inst.components.damagetyperesist.GetResist = inst.wallGetResist2hm end
            inst.wallGetResist2hm = nil
        end
    end
    -- 碰撞检测，不再有速度限制了
    local function OnCollide(inst, other)
        if not POPULATING and inst:IsValid() and (inst.components.combat and inst.components.combat.target or inst:HasTag("epic") or inst:HasTag("pigelite")) and
            other and other:IsValid() and other.GUID and not other.components.locomotor and not other:HasTag("player") then
            local currenttime = GetTime()
            if not inst._startcollisions2hm[other.GUID] then
                for GUID, time in pairs(inst._endcollisions2hm) do
                    if time and currenttime - time > 3 then
                        inst._startcollisions2hm[GUID] = nil
                        inst._endcollisions2hm[GUID] = nil
                    end
                end
                inst._startcollisions2hm[other.GUID] = currenttime
                -- 上个碰撞实体非该实体，1秒内被连续碰撞，该碰撞实体1秒前就被碰撞过
            elseif inst.recentcollisionGUID2hm and inst.recentcollisiontime2hm and (inst.recentcollisionGUID2hm ~= other.GUID or other == TheWorld) and
                currenttime - inst.recentcollisiontime2hm < 1 and currenttime - inst._startcollisions2hm[other.GUID] > 1 then
                if (other.components.combat or checkcanworkable(inst, other)) and checknoprotect(inst, other) then
                    -- 如果该目标可以被摧毁,则尝试破坏目标,同时清除记录,1秒内不重复破坏目标
                    inst:DoTaskInTime(2 * FRAMES, onothercollide, other)
                    inst._startcollisions2hm[other.GUID] = currenttime
                elseif not other._disableCollide2hm and (other.Physics ~= nil or other == TheWorld) and currenttime - inst._startcollisions2hm[other.GUID] >
                    (other == TheWorld and 6 or 3) then
                    -- 被卡住6~3秒后强行突破碰撞
                    if not table.contains(blacklist2, inst.prefab) and (other == TheWorld or other.components.boatphysics or other.Physics:GetCollisionGroup() <= COLLISION.WORLD) then
                        -- 是海陆墙则禁用自己的海陆墙碰撞
                        if not inst._disableWorldCollide2hm then
                            inst._disableWorldCollide2hm = true
                            inst:DoTaskInTime(2 * FRAMES, disableworldcollide)
                        end
                    elseif inst.Physics:GetCollisionGroup() and inst.Physics:GetCollisionGroup() > COLLISION.WORLD then
                        -- 不是海陆墙，则禁用目标的本单位碰撞和自己的本单位碰撞
                        if not other._PhysicsCollisionCb2hm then
                            other._disableCollide2hm = true
                            other:DoTaskInTime(2 * FRAMES, disablesomecollide, inst.Physics:GetCollisionGroup())
                        elseif not inst._disableCollide2hm and other.Physics:GetCollisionGroup() and other.Physics:GetCollisionGroup() > COLLISION.WORLD then
                            inst._disableCollide2hm = true
                            inst:DoTaskInTime(2 * FRAMES, disablesomecollide, other.Physics:GetCollisionGroup())
                        end
                    end
                elseif inst.invincibleCollidetask2hm then
                    inst.invincibleCollidetask2hm:Cancel()
                    inst.invincibleCollidetask2hm = inst:DoTaskInTime(1, cancelinvincibleCollidetask)
                elseif not table.contains(blacklist2, inst.prefab) then
                    -- 被卡住1秒后开始无敌
                    inst.invincibleCollidetask2hm = inst:DoTaskInTime(1, cancelinvincibleCollidetask)
                    if not inst.components.damagetyperesist then inst:AddComponent("damagetyperesist") end
                    local GetResist = inst.components.damagetyperesist.GetResist
                    inst.wallGetResist2hm = GetResist
                    inst.components.damagetyperesist.GetResist = function(self, attacker, ...)
                        return invincibleTest(self.inst, attacker) * GetResist(self, attacker, ...)
                    end
                end
            end
            inst._endcollisions2hm[other.GUID] = currenttime
            inst.recentcollisionGUID2hm = other.GUID
            inst.recentcollisiontime2hm = currenttime
        end
    end
    -- 添加碰撞检测
    local function addCollision(inst)
        if inst.Physics and not inst.components.boatphysics then
            local cb = PhysicsCollisionCallbacks[inst.GUID]
            if inst._PhysicsCollisionCb2hm == nil or cb ~= inst._PhysicsCollisionCb2hm then
                local newcb = cb and function(...)
                    cb(...)
                    OnCollide(...)
                end or OnCollide
                inst._PhysicsCollisionCb2hm = newcb
                inst.Physics:SetCollisionCallback(newcb)
            end
        end
    end
    local cantchangeclllision = {"deer"}
    local function EnableCollision(self)
        if TheWorld.ismastersim and not table.contains(cantchangeclllision, self.inst.prefab) and not self.inst:HasTag("player") and not self.inst.components.boatphysics and not self.inst.components.walkableplatform and
            not self.inst:HasTag("companion") and self.inst.Physics and self.inst.components.locomotor and self.inst.components.combat and self.inst.GUID and
            not self.inst._startcollisions2hm then
            self.inst._startcollisions2hm = {}
            self.inst._endcollisions2hm = {}
            self.inst:DoTaskInTime(0, addCollision)
        end
    end
    AddComponentPostInit("combat", EnableCollision)
    AddComponentPostInit("locomotor", EnableCollision)
    AddPrefabPostInit("alterguardian_phase1", function(inst)
        if not TheWorld.ismastersim then return end
        local EnableRollCollision = inst.EnableRollCollision
        inst.EnableRollCollision = function(inst, ...)
            EnableRollCollision(inst, ...)
            addCollision(inst)
        end
    end)
    local function deerdynamic(inst)
        if not TheWorld.ismastersim then return end
        local ShowAntler = inst.ShowAntler
        inst.ShowAntler = function(inst, ...)
            ShowAntler(inst, ...)
            addCollision(inst)
        end
    end
    AddPrefabPostInit("deer_red", deerdynamic)
    AddPrefabPostInit("deer_blue", deerdynamic)
else
    -- 寻找最近的墙
    local function FindClosestWallInRange(inst, range)
        if inst ~= nil and inst:IsValid() then
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, 0, z, range, nil, {"noattack"}, inst:HasTag("eyeplant") and {"wall"} or {"wall", "lureplant"})
            local closestWall = nil
            local rangesq = range * range
            for i, v in ipairs(ents) do
                if v ~= inst and v.entity:IsVisible() and (v:HasTag("noauradamage") or v:HasTag("lureplant")) and not v:HasTag("noattack") then
                    local distsq = v:GetDistanceSqToPoint(x, y, z)
                    if distsq < rangesq then
                        rangesq = distsq
                        closestWall = v
                    end
                end
            end
            return closestWall
        end
    end
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim then return end
        if not inst:HasTag("player") and not inst:HasTag("companion") and inst.components.combat and inst.components.combat.defaultdamage > 0 and
            not inst:HasTag("shadowchesspiece") and not inst:HasTag("shadowcreature") and not inst:HasTag("nightmarecreature") and not inst:HasTag("chess") and
            inst.prefab ~= "archive_centipede" then
            local targetfn = inst.components.combat.targetfn or nilfn
            inst.components.combat:SetRetargetFunction(inst.components.combat.retargetperiod or 3, function(_inst, ...)
                local target, f = targetfn(_inst, ...)
                if target then return target, f end
                if not _inst:HasTag("companion") then return FindClosestWallInRange(_inst, _inst.prefab == "dragonfly" and 60 or 10) end
            end)
        end
    end)
end
if CollisionMode ~= -1 then
    require "behaviours/chaseandattack" 
    -----------------优化熊獾对海上敌人寻敌的机制------------------
    AddBrainPostInit("beargerbrain",function(self)
		if self.bt.root.children and self.bt.root.children[1] then 
            if self.bt.root.children[1].children and self.bt.root.children[1].children[2] then
                if self.bt.root.children[1].children[2].children and self.bt.root.children[1].children[2].children[3] and self.bt.root.children[1].children[2].children[3].name =="ChaseAndAttack" then
                    self.bt.root.children[1].children[2].children[3] = ChaseAndAttack(self.inst, TUNING.BEARGER_MAX_CHASE_TIME, 60, nil, nil, true, nil)
                end
            end
        end		    
	end)
	------------------优化巨鹿对海上敌人寻敌的机制------------------------
	AddBrainPostInit("deerclopsbrain",function(self)
		if self.bt.root.children and self.bt.root.children[4] and self.bt.root.children[4].name == "ChaseAndAttack" then
            self.bt.root.children[4] = ChaseAndAttack(self.inst, 20, 32, nil, nil, nil, nil)
		end
	end)
end
----------------------------------------------------------------------------------------
AddPrefabPostInit("oceantree_pillar", function(inst)
    if not TheWorld.ismastersim or not inst.components.workable then return end
    inst.components.workable:SetRequiresToughWork(true)
end)

AddComponentPostInit("drownable", function(self)
    if not TheWorld.ismastersim then return end
    local oldIsOverWater = self.IsOverWater
    self.IsOverWater = function(self)
        if self.inst._disableWorldCollide2hm then return false end
        return oldIsOverWater(self)
    end

    local oldIsOverVoid = self.IsOverVoid
    self.IsOverVoid = function(self)
        if self.inst._disableWorldCollide2hm then return false end
        return oldIsOverVoid(self)
    end
end)