-- 远古科技塔/铥矿雕像锤击效果
local function PlayerSpawnCritter(player, critter, pos)
    TheWorld:PushEvent("ms_sendlightningstrike", pos)
    SpawnPrefab("collapse_small").Transform:SetPosition(pos:Get())
    local spawn = SpawnPrefab(critter)
    if spawn ~= nil then
        spawn.Transform:SetPosition(pos:Get())
        if spawn.components.combat ~= nil then spawn.components.combat:SetTarget(player) end
    end
end
local function SpawnCritter(critter, pos, player) player:DoTaskInTime(GetRandomWithVariance(1, 0.8), PlayerSpawnCritter, critter, pos) end
local spawns = {
    armormarble = 0.5,
    armor_sanity = 0.5,
    armorsnurtleshell = 0.5,
    resurrectionstatue = 1,
    icestaff = 15,
    firestaff = 15,
    telestaff = 10,
    thulecite = 1,
    orangestaff = 1,
    greenstaff = 1,
    yellowstaff = 1,
    amulet = 3,
    blueamulet = 3,
    purpleamulet = 3,
    orangeamulet = 1,
    greenamulet = 1,
    yellowamulet = 1,
    redgem = 5,
    bluegem = 5,
    orangegem = 3,
    greengem = 3,
    purplegem = 5,
    -- health_plus         = 10,
    -- health_minus        = 10,
    stafflight = 15,
    monkey = 100,
    bat = 100,
    spider_hider = 100,
    spider_spitter = 100,
    trinket = 100,
    gears = 100,
    crawlingnightmare = 110,
    nightmarebeak = 110
}
local actions = {
    tentacle_pillar_arm = {amt = 6, var = 1, sanity = -TUNING.SANITY_TINY, radius = 3},
    monkey = {amt = 3, var = 1},
    bat = {amt = 5},
    trinket = {amt = 4},
    spider_hider = {amt = 2},
    spider_spitter = {amt = 2},
    stafflight = {amt = 1}
}
local function DoRandomThing(inst, pos, count, target)
    count = count or 1
    pos = pos or inst:GetPosition()

    for doit = 1, count do
        local item = weighted_random_choice(spawns)

        local doaction = actions[item]

        local amt = doaction ~= nil and doaction.amt or 1
        local sanity = doaction ~= nil and doaction.sanity or 0
        local health = doaction ~= nil and doaction.health or 0
        local func = doaction ~= nil and doaction.callback or nil
        local radius = doaction ~= nil and doaction.radius or 4

        local player = target

        if doaction ~= nil and doaction.var ~= nil then amt = math.max(0, GetRandomWithVariance(amt, doaction.var)) end

        if amt == 0 and func ~= nil then func(inst, item, doaction) end

        for i = 1, amt do
            local offset = FindWalkableOffset(pos, math.random() * 2 * PI, radius, 8, true, false, NoHoles2hm) -- try to avoid walls
            if offset ~= nil then
                if func ~= nil then
                    func(inst, item, doaction)
                else
                    offset.x = offset.x + pos.x
                    offset.z = offset.z + pos.z
                    if item == "trinket" then
                        local prefab = PickRandomTrinket()
                        if prefab ~= nil then SpawnCritter(prefab, offset, player) end
                    else
                        SpawnCritter(item, offset, player)
                    end
                end
            end
        end
    end
end
function DoRandomRuinMagic2hm(inst, worker)
    local pos = inst:GetPosition()
    DoRandomThing(inst, pos, nil, worker)
end

-- 织影者骨刺
local function SpawnSnare(inst, x, z, r, num, target)
    local vars = {1, 2, 3, 4, 5, 6, 7}
    local used = {}
    local queued = {}
    local count = 0
    local dtheta = PI * 2 / num
    local thetaoffset = math.random() * PI * 2
    local delaytoggle = 0
    local map = TheWorld.Map
    for theta = math.random() * dtheta, PI * 2, dtheta do
        local x1 = x + r * math.cos(theta)
        local z1 = z + r * math.sin(theta)
        if map:IsPassableAtPoint(x1, 0, z1) and not map:IsPointNearHole(Vector3(x1, 0, z1)) then
            local spike = SpawnPrefab("fossilspike")
            spike.Transform:SetPosition(x1, 0, z1)

            local delay = delaytoggle == 0 and 0 or .2 + delaytoggle * math.random() * .2
            delaytoggle = delaytoggle == 1 and -1 or 1

            local duration = GetRandomWithVariance(TUNING.STALKER_SNARE_TIME, TUNING.STALKER_SNARE_TIME_VARIANCE)

            local variation = table.remove(vars, math.random(#vars))
            table.insert(used, variation)
            if #used > 3 then table.insert(queued, table.remove(used, 1)) end
            if #vars <= 0 then
                local swap = vars
                vars = queued
                queued = swap
            end

            spike:RestartSpike(delay, duration, variation)
            count = count + 1
        end
    end
    if count <= 0 then
        return false
    elseif target:IsValid() then
        target:PushEvent("snared", {attacker = inst})
    end
    return true
end
local SNARE_OVERLAP_MIN = 1
local SNARE_OVERLAP_MAX = 3
local SNAREOVERLAP_TAGS = {"fossilspike", "groundspike"}
local function NoSnareOverlap(x, z, r) return #TheSim:FindEntities(x, 0, z, r or SNARE_OVERLAP_MIN, SNAREOVERLAP_TAGS) <= 0 end
function StalkerSpawnSnares2hm(inst, targets)
    if not (inst and inst:IsValid()) then return end
    local count = 0
    local nextpass = {}
    for i, v in ipairs(targets) do
        if inst:IsValid() and v and v:IsValid() and v:IsNear(inst, TUNING.STALKER_SNARE_MAX_RANGE) then
            local x, y, z = v.Transform:GetWorldPosition()
            local islarge = v:HasTag("largecreature")
            local r = v:GetPhysicsRadius(0) + (islarge and 1.5 or .5)
            local num = islarge and 12 or 6
            if NoSnareOverlap(x, z, r + SNARE_OVERLAP_MAX) then
                if SpawnSnare(inst, x, z, r, num, v) then count = count + 1 end
            else
                table.insert(nextpass, {x = x, z = z, r = r, n = num, inst = v})
            end
        end
    end

    if #nextpass > 0 then
        for range = SNARE_OVERLAP_MAX - 1, SNARE_OVERLAP_MIN, -1 do
            local i = 1
            while i <= #nextpass do
                local v = nextpass[i]
                if NoSnareOverlap(v.x, v.z, v.r + range) then
                    if SpawnSnare(inst, v.x, v.z, v.r, v.n, v.inst) then count = count + 1 end
                    table.remove(nextpass, i)
                else
                    i = i + 1
                end
            end
        end
    end
end
