-- Run only on the disposable cluster created by run_native_exchange_travel.py.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})

local routes = {
    islands = {1, 3, 4, 3, 1, 2},
    newconstant = {1, 2},
}
local suite = GetModConfigData("suite")
local route = assert(routes[suite])
local outage = GetModConfigData("outage")
local verifyRestart = GetModConfigData("verify_restart")
local legs = outage and 1 or #route * GetModConfigData("cycles")
local shard
local function mark(event, value)
    print("[TRAVEL AUDIT] " .. event .. " " .. tostring(value or shard))
end

local function findGold(player)
    return player.components.inventory:FindItem(function(item) return item.prefab == "goldnugget" end)
end

local function findPortal(prefab, destination, requireActive)
    for _, inst in pairs(Ents) do
        local migrator = inst.components.worldmigrator
        if inst.prefab == prefab and migrator and tonumber(migrator.linkedWorld) == destination and
            (not requireActive or migrator:IsActive()) then
            return inst
        end
    end
end

local function depart(player, destination)
    if suite == "islands" and (shard == 1 and destination == 3 or shard == 3 and destination == 1) then
        local portal = assert(SpawnPrefab("seaworthy"))
        portal.persists = false
        portal.Transform:SetPosition(player.Transform:GetWorldPosition())
        local dimension = destination == 3 and CONSTANT_DIMENSIONS.SHIPWRECKED or CONSTANT_DIMENSIONS.FOREST
        local ok, reason = portal.components.worthyportal:StartVoyage(player, dimension)
        assert(ok, tostring(reason) .. " from " .. shard .. " to " .. destination)
        assert(tonumber(portal.components.worldmigrator.linkedWorld) == destination)
        return
    end

    local prefab = destination == 4 and "volcano" or shard == 4 and "volcano_exit" or
        destination == 2 and "cave_entrance_open" or "cave_exit"
    local function activate()
        local portal = assert(findPortal(prefab, destination, true), "missing active " .. prefab .. " to " .. destination)
        player.Physics:Teleport(portal.Transform:GetWorldPosition())
        assert(portal.components.worldmigrator:Activate(player))
    end
    if prefab == "cave_entrance_open" and not findPortal(prefab, destination, true) then
        local closed = assert(findPortal("cave_entrance", destination), "missing closed cave entrance")
        local work = closed.components.workable
        work:WorkedBy(player, work.workleft)
        -- The replacement portal registers and receives its state on a later tick.
        player:DoStaticTaskInTime(1, activate)
    else
        activate()
    end
end

local function testAbyss(world, player)
    local portal
    for _, inst in pairs(Ents) do
        if inst.prefab == "abyss_leak" and #inst.telePos > 0 then portal = inst; break end
    end
    assert(portal, "generated cave lacks an abyss portal with a registered destination")
    local trader = portal.components.trader
    player.Physics:Teleport(portal.Transform:GetWorldPosition())
    local tribute = assert(SpawnPrefab("thulecite"))
    tribute.components.stackable:SetStackSize(3)
    trader:Enable()
    assert(trader:AbleToAccept(tribute, player, 3))
    assert(trader:AcceptGift(player, tribute, 3))
    assert(player.sg.currentstate.name == "abyss_fall")
    player:DoStaticTaskInTime(6, function()
        assert(TheWorld == world and player.sg.currentstate.name ~= "abyss_fall")
        for _, position in ipairs(portal.telePos) do
            if player:GetDistanceSqToPoint(position:Get()) < 36 then mark("ABYSS_PORTAL"); return end
        end
        error("abyss entry did not land at its registered destination")
    end)
end

local function testRejectedAbyssDeparture(world, player)
    local core = world.components.worldexchange2hm.engine.core
    assert(core:CanMigrate(player.userid, "1"))
    local limit, curse = player.components.transformlimit, player.components.abysscurse
    local originalKill, rejected = curse.DoKill, false
    -- Observe the Abyss restriction without killing the inventory test player.
    curse.DoKill = function() rejected = true end
    limit:SetState(true)
    world:PushEvent("ms_playerdespawnandmigrate", {player = player, worldid = "1"})
    limit:SetState(false)
    curse.DoKill = originalKill
    assert(rejected and not player._despawning, "Abyss migration restriction was bypassed")
    assert(not core.outbound[player.userid] and core:CanMigrate(player.userid, "1"),
        "Abyss rejected the request but left the player stuck in departure")
    mark("ABYSS_REJECTION_CLEARED")
end

AddSimPostInit(function()
    local world = TheWorld
    if not (world and world.ismastersim) then return end
    shard = tonumber(TheShard:GetShardId())
    assert(TheNet:GetServerName() == "ShadowWorld isolated travel audit")
    mark("LOADED")
    world:ListenForEvent("ms_playerjoined", function(_, player)
        player:DoStaticTaskInTime(1, function()
            player.components.health:SetInvincible(true)
            local gold = findGold(player)
            if verifyRestart then
                local helmet = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                assert(shard == 1 and gold and gold.components.stackable:StackSize() == legs + 1 and
                    helmet and helmet.prefab == "footballhat", "committed player inventory did not survive restart")
                mark("RESTART_PASS", legs)
                return
            end
            if not gold then
                assert(shard == 1 and not player.migration, "player lost inventory during migration")
                gold = assert(SpawnPrefab("goldnugget"))
                player.components.inventory:GiveItem(gold)
                player.components.inventory:Equip(assert(SpawnPrefab("footballhat")))
            end
            local count = gold.components.stackable:StackSize()
            assert(player.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD).prefab == "footballhat")
            assert(shard == route[(count - 1) % #route + 1], "unexpected destination for travel " .. count)
            mark("ARRIVED", count - 1)
            local needsAbyss = suite == "newconstant" and shard == 2 and count == 2
            if needsAbyss then testAbyss(world, player) end
            if count > legs then
                assert(shard == (outage and 3 or 1))
                if outage then mark("PASS", legs)
                else SaveGame(false, function() mark("PASS", legs) end) end
                return
            end
            local destination = route[count % #route + 1]
            local task, armed
            task = player:DoStaticPeriodicTask(.25, function()
                local service = world.components.worldexchange2hm
                local core = service and service.engine and service.engine.core
                if not core then return end
                if outage then
                    if not armed and core.generation and core:IsReady() and
                        core.io.migrationready(tostring(destination), core.generation) then
                        armed = true
                        mark("DROP_VOLCANO")
                    end
                    if not armed or not core.suspended or Shard_IsWorldAvailable("4") then return end
                    assert(not core:IsReady(), "offline shard must suspend box exchanges")
                end
                if not core:CanMigrate(player.userid, tostring(destination)) then return end
                task:Cancel()
                if needsAbyss then testRejectedAbyssDeparture(world, player) end
                gold.components.stackable:SetStackSize(count + 1)
                mark("DEPARTING", count)
                depart(player, destination)
            end, needsAbyss and 8 or 1)
        end)
    end)
end)
