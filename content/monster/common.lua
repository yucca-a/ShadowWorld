-- 攻击击落武器和头部护甲
function DropPlayerWeapon2hm(inst, player)
    if inst and inst:IsValid() and player ~= nil and player:IsValid() and player:HasTag("player") and player.components.inventory ~= nil then
        -- 骨甲正常时免疫脱落
        for slot, equip in pairs(player.components.inventory.equipslots) do
            if equip and equip:IsValid() and equip.prefab == "armorskeleton" then
                if equip.components.cooldown and equip.components.cooldown.onchargedfn and equip.components.cooldown:IsCharged() then
                    return
                else
                    break
                end
            end
        end
        local headitem = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if headitem and headitem:HasTag("curse2hm") then headitem = nil end
        local handsitem = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if handsitem and handsitem:HasTag("curse2hm") then handsitem = nil end
        local item = (not player:HasTag("stronggrip")) and handsitem or headitem
        if item ~= nil and item:IsValid() and item.components.inventoryitem then
            player.components.inventory:DropItem(item, not item.components.inventoryitem.cangoincontainer)
            if item.Physics ~= nil and item.Physics:IsActive() then
                local x, y, z = item.Transform:GetWorldPosition()
                item.Physics:Teleport(x, .1, z)
                x, y, z = inst.Transform:GetWorldPosition()
                local x1, y1, z1 = player.Transform:GetWorldPosition()
                local angle = math.atan2(z1 - z, x1 - x) + (math.random() * 20 - 10) * DEGREES
                local speed = 5 + math.random() * 2
                item.Physics:SetVel(math.cos(angle) * speed, 10, math.sin(angle) * speed)
            end
        end
    end
end

-- 荆棘缠绕
function KillOffSnares(inst)
    local snares = inst.snares
    if snares ~= nil then
        inst.snares = nil
        for _, v in ipairs(snares) do
            if v:IsValid() then
                v.owner = nil
                v:KillOff()
            end
        end
    end
end
local function onsnaredeath(snare)
    local inst = (snare.owner ~= nil and snare.owner:IsValid()) and snare.owner or nil
    if inst ~= nil then KillOffSnares(inst) end
end
local function dosnaredamage(inst, target)
    if target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead() and target.components.combat ~= nil then
        target.components.combat:GetAttacked_Internal(inst, TUNING.WEED_IVY_SNARE_DAMAGE)
        target:PushEvent("snared", {attacker = inst, announce = "ANNOUNCE_SNARED_IVY"})
    end
end
local function SpawnSnare(inst, x, z, r, num, target)
    local count = 0
    local dtheta = PI * 2 / num
    local thetaoffset = math.random() * PI * 2
    local delaytoggle = 0
    local map = TheWorld.Map
    for theta = math.random() * dtheta, PI * 2, dtheta do
        local x1 = x + r * math.cos(theta)
        local z1 = z + r * math.sin(theta)
        if map:IsPassableAtPoint(x1, 0, z1, false, true) and not map:IsPointNearHole(Vector3(x1, 0, z1)) then
            local snare = SpawnPrefab("ivy_snare")
            snare.Transform:SetPosition(x1, 0, z1)
            if inst.prefab == "bigshadowtentacle" then
                snare.AnimState:SetMultColour(0, 0, 0, 0.5)
            else
                snare.AnimState:SetMultColour(180 / 255, 102 / 255, 222 / 255, 1)
            end

            local delay = delaytoggle == 0 and 0 or .2 + delaytoggle * math.random() * .2
            delaytoggle = delaytoggle == 1 and -1 or 1

            snare.owner = inst
            snare.target = target
            snare.target_max_dist = r + 1.0
            snare:RestartSnare(delay)

            table.insert(inst.snares, snare)
            inst:ListenForEvent("death", onsnaredeath, snare)
            count = count + 1
        end
    end
    return count > 0
end
function SpawnDefendIvyPlant(inst, target, issafe, setnum, setradius)
    if target ~= nil and target:IsValid() and not target:HasTag("plantkin") then
        if inst.snares ~= nil and #inst.snares > 0 then
            for _, snare in ipairs(inst.snares) do
                if snare:IsValid() and snare.components.health ~= nil and not snare.components.health:IsDead() then
                    snare.components.health:Kill()
                end
            end
        end
        inst.snares = {}
        local x, y, z = target.Transform:GetWorldPosition()
        local islarge = target:HasTag("largecreature")
        local r = setradius or (target:GetPhysicsRadius(0) + (islarge and 1.4 or .4))
        local num = setnum or (islarge and 12 or 6) + (extranum or 0)
        if SpawnSnare(inst, x, z, r, num, target) and issafe ~= true then inst:DoTaskInTime(0.25, dosnaredamage, target) end
    end
end

-- 生成暗影角围绕自身
function SpawnHorn2hm(target, num, duration, canspeed)
    local prefx = SpawnPrefab("shadow_despawn")
    target:AddChild(prefx)
    target:DoTaskInTime(1, function()
        if target.components.health and target.components.health:IsDead() then return end
        local horn = SpawnPrefab("ruinsnightmare_horn_circular_attack_2hm")
        -- horn.deathrattle2hm = true
        horn.firsthorn2hm = true
        horn.hardmode2hm = true
        horn:SetUp(target, target, num or 3, duration)
        if target.components.locomotor and hardmode and canspeed then
            target.components.locomotor:SetExternalSpeedMultiplier(target, "horn_speedup2hm", 1.5)
        end
    end)
end