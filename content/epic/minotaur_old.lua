-- 远古守护者加强，生命值增加6000，碰撞石柱进入晕眩状态或被攻击一定次数后生成爬行梦魇梦魇尖喙暗影触手协助战斗
-- 远古守护者阵亡后会在远古大门的CD时间后重置远古，期间击败远古织影者提前重置远古
TUNING.MINOTAUR_HEALTH = TUNING.MINOTAUR_HEALTH + 6000
local bigshadowtentacleexist = 1
local function SpawnDevilPlant(inst, pos)
    if inst:HasTag("swc2hm") or inst:IsAsleep() then return end
    if not inst.plantsnumber2hm then inst.plantsnumber2hm = #(TUNING.DEVILPLANTS2HM) end
    local homepos = inst.components.knownlocations and inst.components.knownlocations:GetLocation("home")
    local pt = pos or inst.spawnlocation or homepos or inst:GetPosition()
    local theta
    if not pos then
        local angle = inst:GetAngleToPoint(pt)
        if homepos and angle then angle = -angle end
        local iscave = TheWorld:HasTag("cave")
        local newpt
        for i = 1, 15, 1 do
            local radius = math.random(homepos and iscave and 20 or 5, iscave and 36 or 25) + math.random()
            theta = (angle + GetRandomWithVariance(0, 90)) * DEGREES
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            newpt = pt + offset
            if TheWorld.Map:IsPassableAtPoint(newpt.x, 0, newpt.z, false, true) and
                #TheSim:FindEntities(newpt.x, 0, newpt.z, bigshadowtentacleexist > 1 and 0.5 or 1, {"devil_plant2hm"}, {"player"}) <= 0 then
                pt = newpt
                break
            end
            if i == 15 then return end
        end
    elseif #TheSim:FindEntities(pos.x, 0, pos.z, bigshadowtentacleexist > 1 and 0.5 or 1, {"devil_plant2hm"}, {"player"}) > 0 then
        return
    end
    local prefabname = TUNING.DEVILPLANTS2HM[math.random(inst.plantsnumber2hm)]
    local plant = SpawnPrefab(prefabname)
    plant.Transform:SetPosition(pt.x, 0, pt.z)
    if theta then plant.Transform:SetRotation(theta / DEGREES - 180) end
end

local function OnCollisionStun(inst)
    if inst:HasTag("swc2hm") or inst:IsAsleep() then return end
    if not inst.summoncdtask2hm and inst.components.health and not inst.components.health:IsDead() then
        local dangerphase = inst.components.health:GetPercent() < 0.6
        inst.summoncdtask2hm = inst:DoTaskInTime(dangerphase and 8 or 13, function() inst.summoncdtask2hm = nil end)
        inst.attackedindex2hm = math.clamp(inst.attackedindex2hm - (dangerphase and 8 or 15), 0, 15)
        -- 头破血流
        if inst.SpawnBigBloodDrop then
            if dangerphase or math.random() < 0.75 then inst:SpawnBigBloodDrop() end
            -- if math.random() < (dangerphase and 0.75 or 0.5) then inst:SpawnBigBloodDrop() end
            if math.random() < (dangerphase and 0.35 or 0.2) then inst:SpawnBigBloodDrop() end
        end
        -- 头昏脑涨,残血时:0.5,0.75,1,冷却8秒,非残血时:0.3,0.45,0.6,0.75,0.9,冷却13秒
        local chance = dangerphase and 0.2 or 0.15
        for index = 2, dangerphase and 3 or 5 do if math.random() < index * chance then SpawnDevilPlant(inst) end end
    end
end
local function OnAttacked(inst)
    if not inst.attacked2hm then inst.attacked2hm = true end
    if inst:HasTag("swc2hm") or inst:IsAsleep() then return end
    if not inst.refreshcd2hm and inst.summoncdtask2hm and inst.components.health and not inst.components.health:IsDead() and inst.components.health:GetPercent() <
        0.6 then
        inst.summoncdtask2hm:Cancel()
        inst.refreshcd2hm = true
        bigshadowtentacleexist = 3
        inst.summoncdtask2hm = nil
        inst.attackedindex2hm = 0
        -- SpawnMonster2hm(inst.components.combat.target or inst, "crawlingnightmare", nil, nil, true)
        -- SpawnMonster2hm(inst.components.combat.target or inst, "nightmarebeak", nil, nil, true)
        -- SpawnMonster2hm(inst.components.combat.target or inst, "oceanhorror2hm", nil, nil, true)
        -- -- 2025.7.25 melon:增加潜伏暗影
        -- SpawnMonster2hm(inst.components.combat.target or inst, "ruinsnightmare", nil, nil, true)
    end
    inst.attackedindex2hm = inst.attackedindex2hm + 1
    if not inst.summoncdtask2hm and inst.attackedindex2hm >= 15 then OnCollisionStun(inst, true) end
end
local function ondeath(inst)
    if inst:HasTag("swc2hm") then return end
    if TheWorld:HasTag("cave") and TheWorld.components.worldsettingstimer and TheWorld.components.worldsettingstimer:TimerExists("mod_minotaur_resurrect") and
        not TheWorld.components.worldsettingstimer:ActiveTimerExists("mod_minotaur_resurrect") then
        TheWorld.components.worldsettingstimer:StartTimer("mod_minotaur_resurrect", TUNING.ATRIUM_GATE_COOLDOWN)
    end
    bigshadowtentacleexist = 1
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 100, {"devil_plant2hm"}, {"player"})
    if #ents > 0 then for index, ent in ipairs(ents) do ent:DoTaskInTime(math.random(10, 30), ent.KillPlant or ent.Remove) end end
end

-- 撞到柱子会为自身添加暗影魔法
-- 回血函数
local function showshieldfx(inst)
    local r, g, b, alpha = inst.AnimState:GetMultColour()
    local fx = SpawnPrefab("stalker_shield2hm")
    fx.AnimState:SetScale(-1.36, 1.36, 1.36)
    fx.AnimState:SetMultColour(r, g, b, alpha)
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end

local function shieldfn(inst)
    if inst.components.health and inst.components.health:IsDead() then return end
    inst.components.health:DoDelta(25)
    showshieldfx(inst)
end

-- 击落武器
local function lungemagicfx(inst)
    inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowrock_up")
    local fx = SpawnPrefab("sanity_raise")
    fx.Transform:SetScale(1.25, 1.25, 1.25)
    inst:AddChild(fx)
    if inst.magic_lungetask2hm then return end
    inst:DoTaskInTime(49 * FRAMES, function()
        inst.fx = SpawnPrefab("tophat_shadow_fx")
        inst.fx.entity:SetParent(inst.entity)
        inst.fx.Transform:SetScale(2, 5, 2)
    end)
end

local function droptargetweapon(inst, data)
    if data and data.target and data.target:IsValid() then
        DropPlayerWeapon2hm(inst, data.target)
    end
end

-- 击退波纹
local function checknearplayer(inst)
    local player = FindClosestPlayerToInst(inst, 1, true)
    if player and player:IsValid() and not (player.sg and player.sg:HasStateTag("knockout")) then
        local knocker = inst.src2hm and inst.src2hm:IsValid() and inst.src2hm or inst
        local _strengthmult = 3
        if player:HasTag("wereplayer") then _strengthmult = 7 end
        player:PushEvent("knockback", {
            knocker = knocker,
            radius = _strengthmult,
            strengthmult = (player.components.inventory ~= nil and player.components.inventory:ArmorHasTag("heavyarmor") or player:HasTag("heavybody")) and 0.7 or
                1,
            forcelanded = true
        })
        if TheWorld.has_ocean then
            inst.targets2hm = inst.targets2hm or {}
            local boat = player:GetCurrentPlatform()
            if boat and boat:IsValid() and boat:HasTag("boat") and boat.components.boatphysics and not inst.targets2hm[boat] then
                inst.targets2hm[boat] = true
                local _x, _y, _z = knocker.Transform:GetWorldPosition()
                local x, y, z = boat.Transform:GetWorldPosition()
                local nx, nz = VecUtil_Normalize(_x - x, _z - z)
                boat.components.boatphysics:ApplyRowForce(_x - x, _z - z, 1, 6)
            end
        end
    end
end

local WAKEANIMS = {"idle_loop_1", "idle_loop_2", "idle_loop_3"}
local function dotaunttask(inst)
    local player = FindClosestPlayerToInst(inst, 100, true)
    if player and player:IsValid() then
        local _x, _y, _z = inst.Transform:GetWorldPosition()
        local x, y, z = player.Transform:GetWorldPosition()
        local rotation = inst:GetAngleToPoint(x, y, z)
        local wake = SpawnPrefab("boatwaterfx2hm")
        wake.src2hm = inst
        local theta = rotation * DEGREES
        wake.Transform:SetPosition(_x + 2 * math.cos(theta), 0, _z - math.sin(theta))
        wake.Transform:SetRotation(rotation)
        wake.AnimState:SetMultColour(0, 0, 0, 0.5)
        inst.wakeanimidx2hm = (inst.wakeanimidx2hm + (math.random() > 0.5 and 1 or -1)) % #WAKEANIMS
        wake.AnimState:PlayAnimation(WAKEANIMS[inst.wakeanimidx2hm + 1])
        if wake.components.boattrailmover then
            local nx, nz = VecUtil_Normalize(_x - x, _z - z)
            wake.components.boattrailmover:Setup(nx, nz, 4, 0)
        end
        wake:DoPeriodicTask(FRAMES, checknearplayer)
    end
end

local _magics = {
    "horn",
    "lunge",
    "shield",
    "boatwater",
}

local function hornfn(target, nopillar)
    local time = math.random(8,12)
    if nopillar then time = time / 4 end
    SpawnHorn2hm(target, math.random(2,4), time)
    target.magic_horntask2hm = target:DoTaskInTime(time, function()
        target.magic_horntask2hm = nil
    end)
end

local function shieldpushfn(target)
    local time = math.random(7,11)
    if target.magic_shieldtask2hm then
        target.magic_shieldtask2hm:Cancel()
    elseif not target.magic_shieldtask2hm then
        target.helptask2hm = target:DoPeriodicTask(1, shieldfn, 1)
        target.components.health.externalabsorbmodifiers:SetModifier(target, 0.3, "magic_shield2hm")
    end
    target.magic_shieldtask2hm = target:DoTaskInTime(time, function()
        if target.helptask2hm then 
            target.helptask2hm:Cancel()
            target.helptask2hm = nil
        end
        target.components.health.externalabsorbmodifiers:RemoveModifier(target, "magic_shield2hm")
        target.magic_shieldtask2hm = nil
    end)
end

local function lungepushfn(target)
    local time = math.random(25,35)
    lungemagicfx(target)
    if target.magic_lungetask2hm then
        target.magic_lungetask2hm:Cancel()
    elseif not target.magic_lungetask2hm then
        target:ListenForEvent("onhitother", droptargetweapon)
    end
    target.magic_lungetask2hm = target:DoTaskInTime(time, function()
        target:RemoveEventCallback("onhitother", droptargetweapon)
        if target.fx then target.fx:Remove() end
        target.magic_lungetask2hm = nil
    end)
end

local function boatwaterpushfn(pillar_ruins)
    if not pillar_ruins.magic_boatwatertask2hm and pillar_ruins:IsValid() then
        pillar_ruins.magic_boatwatertask2hm = true
        local statrtime = math.random(4,6)
        local time = math.random(6,8)
        pillar_ruins:DoTaskInTime(statrtime, function()
            pillar_ruins.wakeanimidx2hm = 0
            pillar_ruins.taunttask2hm = pillar_ruins:DoPeriodicTask(8 * FRAMES, dotaunttask, 0.25)
            pillar_ruins.magic_boatwatertask2hm = pillar_ruins:DoTaskInTime(time, function()
                if pillar_ruins.taunttask2hm then 
                    pillar_ruins.taunttask2hm:Cancel()
                    pillar_ruins.taunttask2hm = nil
                end
                pillar_ruins.wakeanimidx2hm = nil
                pillar_ruins.magic_boatwatertask2hm = nil
            end)
        end)
    end
end

local function canusepillar(target)
    return target and target:IsValid()
end

local function doshake(inst)
    if inst.notshadowfortarget2hm then
        inst.notshadowfortarget2hm:Cancel()
    end
    inst.notshadowfortarget2hm = inst:DoTaskInTime(20, function() inst.notshadowfortarget2hm = nil end)
    inst.fullshadowmagic2hm = nil
    if inst.task2hm then
        inst.task2hm:Cancel()
    end
    inst.task2hm = inst:DoTaskInTime(math.random(45,60), function() 
        inst.task2hm = nil
        inst.fullshadowmagic2hm = true
    end)
    if not inst.AnimState then return end
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("idle")
end

local function givetargetshadowmagic2hm(inst)
    if inst:HasTag("swc2hm") then return end
    local pillar_ruins = FindClosestEntity(inst, 5, true, {"charge_barrier"})
    if not pillar_ruins then
        if not inst.canmagic2hm then 
            inst.canmagic2hm = {
                horn = true,
                lunge = true,
                boatwater = true,
            }
        end
        local pillar = inst.pillar2hm
        if type(pillar) ~= "table" then return end
        local horn = canusepillar(pillar["horn"]) and pillar["horn"]
        local lunge = canusepillar(pillar["lunge"]) and pillar["lunge"]
        local boatwater = canusepillar(pillar["boatwater"]) and pillar["boatwater"]
        local shield = canusepillar(pillar["shield"]) and pillar["shield"]
        local check = (horn and horn.fullshadowmagic2hm) or (boatwater and boatwater.fullshadowmagic2hm) or (lunge and lunge.fullshadowmagic2hm) or (shield and shield.fullshadowmagic2hm)
        if inst.canmagic2hm["horn"] and not inst.magic_horntask2hm and SpawnHorn2hm and check then
            inst.canmagic2hm["horn"] = false
            doshake(horn)
            inst:DoTaskInTime(40 *FRAMES, hornfn, true)
        elseif inst.canmagic2hm["boatwater"] and check and pillar["boatwater"].prefab == "pillar_ruins" and boatwater and not boatwater.magic_boatwatertask2hm then
            inst.canmagic2hm["boatwater"] = false
            doshake(boatwater)
            boatwater:DoTaskInTime(40 *FRAMES, boatwaterpushfn)
        elseif inst.canmagic2hm["lunge"] and check then
            inst.canmagic2hm["lunge"] = false
            doshake(lunge)
            inst:DoTaskInTime(40 *FRAMES, lungepushfn)
        elseif check then
            inst.canmagic2hm = {
                horn = true,
                lunge = true,
                boatwater = true,
            }
            doshake(shield)
            inst:DoTaskInTime(40 *FRAMES, shieldpushfn)
        end
        return
    end
    if not inst.colding2hm and pillar_ruins and pillar_ruins.canshadowfortarget2hm and not pillar_ruins.notshadowfortarget2hm and inst:IsValid() and inst.components.health and not inst.components.health:IsDead() then
        inst.colding2hm = true
        inst:DoTaskInTime(0.3, function() inst.colding2hm = nil end)
        local target = inst
        if pillar_ruins.canshadowfortarget2hm == "horn" and not target.magic_horntask2hm and SpawnHorn2hm then
            hornfn(target)
        elseif pillar_ruins.prefab == "pillar_ruins" and pillar_ruins.canshadowfortarget2hm == "boatwater" and not pillar_ruins.magic_boatwatertask2hm then
            boatwaterpushfn(pillar_ruins)
        elseif pillar_ruins.canshadowfortarget2hm == "lunge" then
            lungepushfn(target)
        else
            shieldpushfn(target)
        end
    end
    if pillar_ruins and pillar_ruins:IsValid() and pillar_ruins.prefab == "pillar_ruins" then
        pillar_ruins:PushEvent("cancelshadowtask2hm")
    end
end

-- 新界连跳兼容
AddSimPostInit(function()
    AddStategraphPostInit("minotaur",function(sg)
        if sg and sg.states and sg.states.stun2 and sg.states.stun2.onenter then
            local oldfn = sg.states.stun2.onenter
            sg.states.stun2.onenter = function(inst, data, ...)
                oldfn(inst, data, ...)
                if data and data.doleap == false then givetargetshadowmagic2hm(inst) end
            end
        end
    end)
end)

local function shadowenterfn(inst)
    inst.num2hm = inst.num2hm or 0
    inst.rgbnum2hm = inst.rgbnum2hm or 10
    
    if inst.rgbnum2hm - inst.num2hm <= 0 then
        -- 完成渐变
        inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowrock_up")
        local fx = SpawnPrefab("sanity_raise")
        fx.Transform:SetScale(1.25, 1.25, 1.25)
        inst:AddChild(fx)
        inst.AnimState:SetMultColour(0, 0, 0, 0.5)
        
        if inst.changetask2hm then
            inst.changetask2hm:Cancel()
            inst.changetask2hm = nil
        end
        
        inst.num2hm = nil
        inst.rgbnum2hm = nil
        inst.canshadowfortarget2hm = inst.finalcanshadowfortarget2hm == "boatwater" and "shield" or inst.finalcanshadowfortarget2hm
        return
    end
    
    -- 计算当前应该达到的颜色（平滑过渡）
    local progress = inst.num2hm / inst.rgbnum2hm
    local rgb = 1 - progress  -- 从1逐渐降到0
    local r, g, b = inst.AnimState:GetMultColour()
    inst.AnimState:SetMultColour(rgb<r and rgb or r, rgb<g and rgb or g, rgb < b and rgb or b, 1)
    inst.num2hm = inst.num2hm + 1
end

local function startSmoothShadowTransition(inst, duration)
    if not inst or not inst.AnimState then return end
    
    local steps = 30  -- 平滑步数
    local interval = duration / steps
    
    inst.num2hm = 0
    inst.rgbnum2hm = steps
    
    if inst.changetask2hm then
        inst.changetask2hm:Cancel()
    end
    inst.changetask2hm = inst:DoPeriodicTask(interval, function()
        shadowenterfn(inst)
    end, interval)
end

local function findnearpillar_ruins(inst)
    if inst:HasTag("swc2hm") then return end
    local x, y, z
    if inst.spawnlocation then
        x = inst.spawnlocation.x
        z = inst.spawnlocation.z
    else
        x, y, z = inst.Transform:GetWorldPosition()
    end
    local ents = TheSim:FindEntities(x, 0, z, 30, {"quake_on_charge"}, {"player"}) -- or we could include a flag to the search?
    local number = 1
    for i, v in pairs(ents) do
        if number > 4 then break end
        if v and v.prefab == "pillar_ruins" then
            if not v.canshadowfortarget2hm then
                v.canshadowfortarget2hm = _magics[number]
                number = number + 1
                if v.AnimState then v.AnimState:SetMultColour(0, 0, 0, 0.5) end
            end
        end
    end
    inst:DoTaskInTime(1, function()
        local ents = TheSim:FindEntities(x, 0, z, 80, {"quake_on_charge"}, {"player"}) -- or we could include a flag to the search?
        for i, v in pairs(ents) do
            if v and v.prefab == "pillar_ruins" and v.canshadowfortarget2hm then
                inst.pillar2hm = inst.pillar2hm or {}
                if #inst.pillar2hm >= 4 then break end
                if v.canshadowfortarget2hm == "horn" and not inst.pillar2hm[v.canshadowfortarget2hm] then
                    inst.pillar2hm[v.canshadowfortarget2hm] = v
                elseif v.canshadowfortarget2hm == "lunge" and not inst.pillar2hm[v.canshadowfortarget2hm] then
                    inst.pillar2hm[v.canshadowfortarget2hm] = v
                elseif v.canshadowfortarget2hm == "shield" and not inst.pillar2hm[v.canshadowfortarget2hm] then
                    inst.pillar2hm[v.canshadowfortarget2hm] = v
                elseif v.canshadowfortarget2hm == "boatwater" and not inst.pillar2hm[v.canshadowfortarget2hm] then
                    inst.pillar2hm[v.canshadowfortarget2hm] = v
                end
                v.task2hm = v:DoTaskInTime(math.random(45,60), function() 
                    v.task2hm = nil
                    v.fullshadowmagic2hm = true
                end)
                v:ListenForEvent("cancelshadowtask2hm", function()
                    if v.task2hm then
                        v.task2hm:Cancel()
                    end
                    v.fullshadowmagic2hm = nil
                    v.task2hm = v:DoTaskInTime(math.random(45,60), function() 
                        v.task2hm = nil
                        v.fullshadowmagic2hm = true
                    end)
                end)
            end
        end
    end)
end

local function pillar_ruinssave(inst, data) data.canshadowfortarget2hm = inst.canshadowfortarget2hm end

local function pillar_ruinsload(inst, data)
    if data and data.canshadowfortarget2hm then
        inst.canshadowfortarget2hm = data.canshadowfortarget2hm
        if inst.AnimState then inst.AnimState:SetMultColour(0, 0, 0, 0.5) end
    end
end

AddPrefabPostInitAny(function(inst)
    if not inst:HasTag("charge_barrier") or not TheWorld.ismastersim then return end
    -- if inst.prefab == "pillar_ruins" then
    --     if inst.AnimState then inst.AnimState:SetMultColour(0, 0, 0, 0.5) end
    --     inst.canshadowfortarget2hm = true
        -- inst:ListenForEvent("oncollide2hm", givetargetshadowmagic2hm)
    -- else
    if inst.prefab ~= "pillar_ruins" then
        inst:DoTaskInTime(0, function()
            local ent = FindClosestEntity(inst, 20, true, {"quake_on_charge"})
            if not inst.canshadowfortarget2hm and ent and ent.canshadowfortarget2hm then
                inst.finalcanshadowfortarget2hm = ent.canshadowfortarget2hm
                local dist = math.sqrt(inst:GetDistanceSqToInst(ent))
                local time = 20 + (dist ~= nil and math.floor(2 + dist / 2) or 2) / 2
                inst.changetask2hm = inst:DoPeriodicTask(5, startSmoothShadowTransition, 5, time)
                if inst.components.workable then
                    local oldwork = inst.components.workable.onwork
                    inst.components.workable.onwork = function(_inst, ...)
                        if oldwork then oldwork(_inst, ...) end
                        _inst:PushEvent("cancelshadowtask2hm")
                    end
                end
                inst:ListenForEvent("cancelshadowtask2hm", function()
                     if inst.changetask2hm then
                        inst.changetask2hm:Cancel()
                    end 
                end)
            end
        end)
    end
    SetOnLoad(inst, pillar_ruinsload)
    SetOnSave(inst, pillar_ruinssave)
end)

-- 脱战后恢复状态
local function delayonentitysleep(inst)
    inst.sleeptask2hm = nil
    if not inst:HasTag("swc2hm") then bigshadowtentacleexist = 1 end
    if inst.components.health and not inst.components.health:IsDead() then
        if TUNING.DSTU then
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, 0, z)
            if inst.sg then inst.sg:GoToState("idle") end
        elseif inst.attacked2hm then
            inst.attacked2hm = nil
            inst.components.health:DoDelta(inst.components.health.maxhealth * 0.05, nil, nil, true)
        end
    end
end
local function onentitysleep(inst) if not inst.sleeptask2hm then inst.sleeptask2hm = inst:DoTaskInTime(3, delayonentitysleep) end end
local function onentitywake(inst)
    if inst:IsAsleep() then return end
    if inst.components.health and not inst.components.health:IsDead() and not inst:HasTag("swc2hm") then
        bigshadowtentacleexist = inst.refreshcd2hm and 3 or 2
    end
    if inst.sleeptask2hm then
        inst.sleeptask2hm:Cancel()
        inst.sleeptask2hm = nil
    end
end

local function pospersist(inst)
    if inst.components.knownlocations and inst.components.knownlocations.RememberLocation then
        local oldrememberhome = inst.components.knownlocations.RememberLocation
        inst.components.knownlocations.RememberLocation = function(self, name, pos, dont_overwrite, ...)
            dont_overwrite = true
            oldrememberhome(self, name, pos, dont_overwrite, ...)
        end
    end
end
-- local function minotaurOnLoad(inst, data) if data then inst.refreshcd2hm = data.refreshcd2hm end end
-- local function minotaurOnSave(inst, data) data.refreshcd2hm = inst.refreshcd2hm end
local function swc2hmfn(child)
	if child.components.playerprox2hm then
		child.components.playerprox2hm:SetDist(30, 50)
	end
end

AddPrefabPostInit("minotaur", function(inst)
    if not TheWorld.ismastersim then return end
    inst.attackedindex2hm = 0
    inst.chargecount = 0
    pospersist(inst)
    inst.swc2hmfn = swc2hmfn
    inst.shadowcantout2hm = true
    inst:ListenForEvent("blocked", OnAttacked)
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("collision_stun", OnCollisionStun)
    inst:ListenForEvent("collision_stun", givetargetshadowmagic2hm)
    inst:ListenForEvent("death", ondeath)
    inst:ListenForEvent("entitysleep", onentitysleep)
    inst:ListenForEvent("entitywake", onentitywake)
    inst:DoTaskInTime(0, onentitywake)
    inst:DoTaskInTime(0, findnearpillar_ruins)
    -- 2025.10.4 melon:回档后不重复出影怪
    -- SetOnLoad(inst, minotaurOnLoad)
	-- SetOnSave(inst, minotaurOnSave)
end)
-- 石虾会被BOSS破防了
local function onrockyattacked(inst, data)
    if data and data.attacker and data.attacker:IsValid() and data.attacker:HasTag("epic") and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ==
        "shield" and not inst.components.health:IsDead() then inst.sg:GoToState("shield_end") end
end
AddPrefabPostInit("rocky", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", onrockyattacked)
end)

-- 回城时直接释放技能
AddStategraphPostInit("minotaur", function(sg)
    if TUNING.DSTU and sg.states.arena_return_pre and sg.states.arena_return_pre.ontimeout then
        local ontimeout = sg.states.arena_return_pre.ontimeout
        sg.states.arena_return_pre.ontimeout = function(inst, ...)
            ontimeout(inst, ...)
            if not inst:HasTag("swc2hm") and not inst.sg.statemem.minotaurhome2hm then
                inst.sg.statemem.minotaurhome2hm = true
                if inst.components.health and not inst.components.health:IsDead() and inst.attacked2hm then
                    inst.attacked2hm = nil
                    inst.components.health:DoDelta(inst.components.health.maxhealth * 0.1)
                end
                if inst.summoncdtask2hm then
                    inst.summoncdtask2hm = nil
                    local dangerphase = inst.components.health:GetPercent() < 0.6
                    inst.attackedindex2hm = math.clamp(inst.attackedindex2hm - (dangerphase and 8 or 15), 0, 15)
                end
                SpawnDevilPlant(inst, inst:GetPosition())
                OnCollisionStun(inst)
            end
        end
    end
end)

-- 犀牛20天复活
local function ontimer(inst, data) if data and data.name == "mod_minotaur_resurrect" then inst:PushEvent("resetruins") end end
local function onresetruins(inst)
    if inst.components.worldsettingstimer and inst.components.worldsettingstimer:ActiveTimerExists("mod_minotaur_resurrect") then
        inst.components.worldsettingstimer:StopTimer("mod_minotaur_resurrect")
    end
end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim or not inst:HasTag("cave") or not inst.components.worldsettingstimer then return inst end
    inst.components.worldsettingstimer:AddTimer("mod_minotaur_resurrect", TUNING.ATRIUM_GATE_COOLDOWN, true)
    inst:ListenForEvent("timerdone", ontimer)
    inst:ListenForEvent("resetruins", onresetruins)
end)

-- 禁用海星
local function cleatstarfishtrap(inst) if inst.components.workable then inst.components.workable:WorkedBy(inst, 1) end end
AddPrefabPostInit("trap_starfish", function(inst)
    if not TheWorld.ismastersim or not TheWorld:HasTag("cave") then return inst end
    inst:DoTaskInTime(0, cleatstarfishtrap)
end)
-- 洞穴不能放置荆棘陷阱(trap_bramble没有workable不能像海星那样挖起,包装deployable:CanDeploy直接拒绝部署,物品保留在背包)
AddPrefabPostInit("trap_bramble", function(inst)
    if not TheWorld.ismastersim or not TheWorld:HasTag("cave") then return inst end
    if inst.components.deployable and inst.components.deployable.CanDeploy then
        local _CanDeploy = inst.components.deployable.CanDeploy
        inst.components.deployable.CanDeploy = function(self, ...)
            return false -- 远古(洞穴)不能放置荆棘陷阱
        end
    end
end)
-- 洞穴不能放置犬牙陷阱(同荆棘陷阱,deployable物品包装CanDeploy拒绝部署,物品保留在背包)
AddPrefabPostInit("trap_teeth", function(inst)
    if not TheWorld.ismastersim or not TheWorld:HasTag("cave") then return inst end
    if inst.components.deployable and inst.components.deployable.CanDeploy then
        inst.components.deployable.CanDeploy = function()
            return false -- 远古(洞穴)不能放置犬牙陷阱
        end
    end
end)
-- 洞穴不能放置煤炭陷阱(同荆棘陷阱,deployable物品包装CanDeploy拒绝部署,物品保留在背包)
AddPrefabPostInit("trap_fumarole", function(inst)
    if not TheWorld.ismastersim or not TheWorld:HasTag("cave") then return inst end
    if inst.components.deployable and inst.components.deployable.CanDeploy then
        inst.components.deployable.CanDeploy = function()
            return false -- 远古(洞穴)不能放置煤炭陷阱
        end
    end
end)

-- 触手协助作战
local function shadowtentacleshouldKeepTarget(inst, target)
    return target ~= nil and target:IsValid() and target.entity:IsVisible() and target.components.health ~= nil and not target.components.health:IsDead() and
               target:IsNear(inst, TUNING.TENTACLE_STOPATTACK_DIST) and (target:HasTag("player") or not (target.sg and target.sg:HasStateTag("hiding")))
end
local function onbigshadowtentacleremove(inst)
    if bigshadowtentacleexist == 1 then return end
    local flower_evil = SpawnPrefab("flower_evil")
    flower_evil.persists = false
    flower_evil.Transform:SetPosition(inst.Transform:GetWorldPosition())
    flower_evil:DoTaskInTime(120, flower_evil.Remove)
end
AddPrefabPostInit("bigshadowtentacle", function(inst)
    if not TheWorld.ismastersim then return end
    if bigshadowtentacleexist ~= 1 then inst.components.combat:SetKeepTargetFunction(shadowtentacleshouldKeepTarget) end
    inst:ListenForEvent("onremove", onbigshadowtentacleremove)
end)
AddStategraphPostInit("bigshadowtentacle", function(sg)
    sg.states.attack_post.events.animover.fn = function(inst, ...)
        if inst.AnimState:AnimDone() then
            inst.existindex2hm = (inst.existindex2hm or 0) + 1
            if inst.existindex2hm >= bigshadowtentacleexist then
                inst:Remove()
            else
                inst.sg:GoToState("arrive")
            end
        end
    end
end)

-- 恶魔植物诱惑采集
local forcepickstate = State {
    name = "forcepick2hm",
    tags = {"doing", "busy", "nodangle", "nopredict"},
    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.components.inventory:Hide()
        inst:PushEvent("ms_closepopups")
        if inst.components.playercontroller ~= nil then
            inst.components.playercontroller:EnableMapControls(false)
            inst.components.playercontroller:Enable(false)
        end

        inst.sg:SetTimeout(math.random() + 1.5)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        if not (inst.weremode and inst.weremode:value() ~= 0) then
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
        end
    end,
    ontimeout = function(inst)
        local tent = SpawnPrefab("bigshadowtentacle")
        tent.Transform:SetPosition(inst.Transform:GetWorldPosition())
        tent:PushEvent("arrive")
        if inst.forcepicktarget2hm and inst.forcepicktarget2hm.components and inst.forcepicktarget2hm.components.pickable then
            inst.forcepicktarget2hm.components.pickable:Pick(inst)
            inst.forcepicktarget2hm = nil
        end
        inst.SoundEmitter:KillSound("make")
        if not (inst.weremode and inst.weremode:value() ~= 0) then inst.AnimState:PlayAnimation("build_pst") end
        inst.sg:GoToState("idle")
    end,
    onexit = function(inst)
        inst.SoundEmitter:KillSound("make")
        inst.components.inventory:Show()
        if inst.components.playercontroller ~= nil then
            inst.components.playercontroller:EnableMapControls(true)
            inst.components.playercontroller:Enable(true)
        end
    end
}
AddStategraphState("wilson", forcepickstate)
local function forcepickdevilplant2hm(inst, target)
    inst.forcepicktarget2hm = target
    if not inst.sg:HasStateTag("dead") then
        inst.sg:GoToState("forcepick2hm")
    end
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst.forcepickdevilplant2hm = forcepickdevilplant2hm
end)

-- 传送魔杖不能卡BUG
AddPrefabPostInit("telestaff", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.spellcaster and inst.components.spellcaster.spell then
        local spell = inst.components.spellcaster.spell
        inst.components.spellcaster.spell = function(inst, target, pos, caster, ...)
            if caster and caster:IsValid() and TheWorld:HasTag("cave") then
                TheWorld:PushEvent("ms_miniquake", {rad = 3, num = 5, duration = 1.5, target = caster})
            end
            if target and target:IsValid() and not target:HasTag("player") and target.components.combat then
                target.components.combat:SuggestTarget(caster)
            end
            return spell(inst, target, pos, caster, ...)
        end
    end
end)
-- 远古宝箱限制收益,只能拿特定数目的道具
local function sayminotaurchesttext(inst, itemlimit2hm)
	inst.sayminotaurchesttexttask2hm = nil
	if inst.components.talker then
	local desc = itemlimit2hm and
				((TUNING.isCh2hm and "你可以从这个箱子里拿走" or "You can get ") .. itemlimit2hm ..
					(TUNING.isCh2hm and "个道具" or " items form the chest.")) or
				(TUNING.isCh2hm and "箱子的道具拿走限制已经解除了" or "The chest's items limit now stop.")
	inst.components.talker:Say(desc, nil, true)
	end
end
local function minotaurchestonopen(inst, data)
	if inst.itemlimit2hm and inst.components.inspectable and data and data.doer and data.doer:IsValid() and data.doer:HasTag("player") and
	data.doer.components.talker then
	local desc, text_filter_context, original_author = inst.components.inspectable:GetDescription(data.doer)
	desc = (TUNING.isCh2hm and "你可以从这个箱子里拿走" or "You can get ") .. inst.itemlimit2hm ..
		   (TUNING.isCh2hm and "个道具" or " items form the chest.")
	if desc ~= nil then data.doer.components.talker:Say(desc, nil, true, nil, nil, nil, text_filter_context, original_author) end
	end
end
local minotaurchestinit
local function minotaurchestprocess(inst, limit, recordslots)
	if inst.itemlimit2hm ~= nil or not inst.components.container then return end
	inst.itemlimit2hm = limit
	if limit == nil then
	--远古地形给5个奖励，非远古只给2个
	local x, y, z = inst.Transform:GetWorldPosition()
	local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, 0, z, "Nightmare")
		if node ~= nil then
			inst.itemlimit2hm = 5
		else
			inst.itemlimit2hm = 2
		end
	end
	inst.limitfn2hm = function(item)
		if inst.recorditems2hm and inst.recorditems2hm[item] then
			inst.itemlimit2hm = inst.itemlimit2hm - 1
			inst.recorditems2hm[item] = nil
			if item:IsValid() then
				inst:RemoveEventCallback("onremove", inst.limitfn2hm, item)
				inst:RemoveEventCallback("ondropped", inst.limitfn2hm, item)
				inst:RemoveEventCallback("onputininventory", inst.limitfn2hm, item)
				inst:RemoveEventCallback("stacksizechange", inst.limitfn2hm, item)
			end
			if inst.itemlimit2hm <= 0 then
				inst.itemlimit2hm = nil
			for v, value in pairs(inst.recorditems2hm) do
			if v and v:IsValid() and value then
				inst:RemoveEventCallback("onremove", inst.limitfn2hm, v)
				inst:RemoveEventCallback("ondropped", inst.limitfn2hm, v)
				inst:RemoveEventCallback("onputininventory", inst.limitfn2hm, v)
				inst:RemoveEventCallback("stacksizechange", inst.limitfn2hm, v)
				v:DoTaskInTime(0, v.Remove)
			end
			end
			inst.limitfn2hm = nil
			inst.recorditems2hm = nil
			inst:RemoveEventCallback("onopen", minotaurchestonopen)
			SpawnPrefab("collapse_big").Transform:SetPosition(inst.Transform:GetWorldPosition())
			if TheNet:IsServerPaused() then TheNet:SetServerPaused(false) end
			end
			if inst.components.container and inst.components.container:IsOpen() then
			local player = FindClosestPlayerToInst(inst, 10, true)
			if player then
				if player.sayminotaurchesttexttask2hm then
					player.sayminotaurchesttexttask2hm:Cancel()
					player.sayminotaurchesttexttask2hm = nil
				end
				if not (inst.components.workable and inst.components.workable.workleft <= 0) then
					player.sayminotaurchesttexttask2hm = player:DoTaskInTime(0, sayminotaurchesttext, inst.itemlimit2hm)
				end
			end
			end
		end
	end
	local total = 0
	inst.recorditems2hm = {}
	for i = 1, inst.components.container.numslots do
	local v = inst.components.container.slots[i]
		if (recordslots == nil or table.contains(recordslots, i)) and v ~= nil and v:IsValid() and v.components.inventoryitem then
			inst.recorditems2hm[v] = true
			inst:ListenForEvent("onremove", inst.limitfn2hm, v)
			inst:ListenForEvent("ondropped", inst.limitfn2hm, v)
			inst:ListenForEvent("onputininventory", inst.limitfn2hm, v)
			inst:ListenForEvent("stacksizechange", inst.limitfn2hm, v)
			total = total + 1
		end
	end
	if total == 0 or total <= inst.itemlimit2hm then
	inst.itemlimit2hm = nil
	for v, value in pairs(inst.recorditems2hm) do
		if v and v:IsValid() and value then
			inst:RemoveEventCallback("onremove", inst.limitfn2hm, v)
			inst:RemoveEventCallback("ondropped", inst.limitfn2hm, v)
			inst:RemoveEventCallback("onputininventory", inst.limitfn2hm, v)
			inst:RemoveEventCallback("stacksizechange", inst.limitfn2hm, v)
		end
	end
	inst.recorditems2hm = nil
	inst.limitfn2hm = nil
	return
	end
	inst:ListenForEvent("onopen", minotaurchestonopen)
end
local function minotaurchestOnLoad(inst, data)
	if data and data.itemlimit2hm then inst:DoTaskInTime(0, minotaurchestprocess, data.itemlimit2hm, data.recordslots2hm) end
end
local function minotaurchestOnSave(inst, data)
	data.itemlimit2hm = inst.itemlimit2hm
	if inst.itemlimit2hm and inst.recorditems2hm then
		data.recordslots2hm = {}
		for i = 1, inst.components.container.numslots do
			local v = inst.components.container.slots[i]
			if v and inst.recorditems2hm[v] then table.insert(data.recordslots2hm, i) end
		end
	end
end
AddPrefabPostInit("minotaurchest", function(inst)
	if not TheWorld.ismastersim then return end
	SetOnLoad(inst, minotaurchestOnLoad)
	SetOnSave(inst, minotaurchestOnSave)
	if minotaurchestinit then inst:DoTaskInTime(0, minotaurchestprocess) end
end)
AddPrefabPostInit("minotaurchestspawner", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.task and inst.task.fn then
        local fn = inst.task.fn
        inst.task.fn = function(...)
         minotaurchestinit = true
            fn(...)
            minotaurchestinit = nil
        end
    end
end)

-- 陷坑和华丽箱子重置后不再生成高级宝石
local function savedata(inst, data)
    if inst.worldstart2hm then data.worldstart2hm = inst.worldstart2hm end
end

local function loaddata(inst, data)
    if data and data.worldstart2hm then inst.worldstart2hm = data.worldstart2hm end
end

local canthavegems = {
    "greengem",
    "yellowgem",
    "orangegem",
}

local cave_hole_loot =
{
    purplegem = 0.4,
    thulecite = 1.0,
    thulecite_pieces = 1.0,
    nightmare_timepiece = 0.1,
}

AddPrefabPostInit("cave_hole", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.objectspawner and inst.components.objectspawner.SpawnObject then
        local oldSpawnObject = inst.components.objectspawner.SpawnObject
        inst.components.objectspawner.SpawnObject = function(self, obj, ...)
            if self.inst.worldstart2hm and obj and table.contains(canthavegems,obj) then
                obj = weighted_random_choice(cave_hole_loot) or "thulecite_pieces"
            end
            return oldSpawnObject(self, obj, ...)
        end
    end
    inst:DoTaskInTime(1, function() if not inst.worldstart2hm then inst.worldstart2hm = true end end)
    SetOnLoad(inst, savedata)
	SetOnSave(inst, loaddata)
end)

if ModManager:GetMod("workshop-3191348907") or ModManager:GetMod("workshop-3645180511") then return end
AddPrefabPostInit("pandoraschest", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(1, function() if not inst.worldstart2hm then inst.worldstart2hm = true end end)
    SetOnLoad(inst, savedata)
	SetOnSave(inst, loaddata)
end)

local chestfunctions = require("scenarios/chestfunctions")
if chestfunctions and chestfunctions.AddChestItems then
    local items =
	{
		{
			--Body Items
			item = {"armorwood", "footballhat"},
			chance = 0.2,
			initfn = function(item) item.components.armor:SetCondition(math.random(item.components.armor.maxcondition * 0.33, item.components.armor.maxcondition * 0.8)) end,
		},
		{
			--Weapon Items
			item = {"spear"},
			chance = 0.2,
			initfn = function(item) item.components.finiteuses:SetUses(math.random(item.components.finiteuses.total * 0.33, item.components.finiteuses.total * 0.8)) end,
		},
		{
			item = "nightmarefuel",
			count = math.random(1, 3),
			chance = 0.2,
		},
		{
			item = {"redgem", "bluegem", "purplegem"},
			count = math.random(1,2),
			chance = 0.15,
		},
		{
			item = "thulecite_pieces",
			count = math.random(2, 4),
			chance = 0.2,
		},
		{
			item = "thulecite",
			count = math.random(1, 3),
			chance = 0.1,
		},
		{
			--Weapon Items
			item = {"batbat"},
			chance = 0.05,
			initfn = function(item) if item.components.finiteuses ~= nil then item.components.finiteuses:SetUses(math.random(item.components.finiteuses.total * 0.3, item.components.finiteuses.total * 0.5)) end end,
		},
		{
			--Weapon Items
			item = {"firestaff", "icestaff", "multitool_axe_pickaxe"},
			chance = 0.05,
			initfn = function(item) item.components.finiteuses:SetUses(math.random(item.components.finiteuses.total * 0.3, item.components.finiteuses.total * 0.5)) end,
		},
	}

    local oldAddChestItems = chestfunctions.AddChestItems
    chestfunctions.AddChestItems = function(chest, loot, ...)
        if chest and chest.worldstart2hm then
            loot = items 
        end
        return oldAddChestItems(chest, loot, ...)
    end
end
