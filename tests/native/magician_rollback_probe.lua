-- Actual hat conversion, shadow-magic trade, open proxies, disk sessions and world rollback.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
local A = {players = {}}
G.VaultAudit = A
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
local specs = {
    {"wilson", "inventory"}, {"wilson", "equip"},
    {"waxwell", "inventory"}, {"waxwell", "equip"},
    {"wilson", "ground"}, {"waxwell", "ground"},
    {"wilson", "inventory", true}, {"waxwell", "inventory", true},
    {"wilson", "full"}, {"wilson", "closed"},
}
local function uid(i) return "KU_MagicRollback_" .. i end
local function token(i) return "magic_rollback_" .. i end
local function player(role, i)
    local p = SpawnPrefab(role)
    p.userid = uid(i)
    local x, y, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
    p.Transform:SetPosition(x + i * 4, y, z)
    p.components.health:SetInvincible(true)
    p.components.hunger:SetRate(0)
    p.components.inventory:Open()
    p.persists = false -- Player sessions, never duplicate players as world entities.
    return p
end
AddSimPostInit(function()
    TheWorld:DoTaskInTime(2, function() emit({kind = "ready"}) end)
end)
function A.prepare()
    local lab = SpawnPrefab("researchlab3")
    for i, spec in ipairs(specs) do
        local p = player(spec[1], i)
        A.players[i] = p
        if not p.components.magician then
            local fuel = SpawnPrefab("nightmarefuel")
            fuel.components.stackable:SetStackSize(4)
            p.components.inventory:GiveItem(fuel)
            assert(lab.components.trader:AcceptGift(p, fuel, 4), "shadow magic trade accepted")
            assert(p.components.magician and p:HasTag("shadowmagic"), "native grant installed")
        end
        local hat = SpawnPrefab("tophat")
        hat:ConvertToMagician()
        hat.components.persistent2hm.data.rollback_token = token(i)
        hat.components.fueled:SetPercent(.43)
        if spec[3] then
            assert(hat.components.repairable2hm.customrepair(hat, 1, p, SpawnPrefab("shadowheart_infused")), "hat upgraded")
        end
        if spec[2] == "ground" then hat.Transform:SetPosition(p.Transform:GetWorldPosition())
        elseif spec[2] == "equip" then p.components.inventory:Equip(hat)
        else p.components.inventory:GiveItem(hat, 1) end
        if spec[2] ~= "closed" then
            assert(p.components.magician:StartUsingTool(hat), "hat starts using")
            assert(p.components.magician.item == hat and not hat.persists and hat:IsInLimbo(), "native open custody")
            if spec[2] == "full" then
                for slot = 1, p.components.inventory.maxslots do
                    if not p.components.inventory.itemslots[slot] then p.components.inventory:GiveItem(SpawnPrefab("axe"), slot) end
                end
            end
        end
    end
    lab:Remove()
    TheWorld:DoTaskInTime(.5, function()
        local opened = 0
        for _, p in ipairs(A.players) do
            local item = p.components.magician and p.components.magician.item
            if item then
                assert(item.container and item.container.components.container_proxy:IsOpenedBy(p), "actual hat space is open")
                opened = opened + 1
            end
        end
        emit({kind = "prepared", players = #A.players, open = opened})
    end)
end
function A.save()
    for _, p in ipairs(A.players) do SerializeUserSession(p) end
    SaveGame(false, function() emit({kind = "saved", snapshot = TheNet:GetCurrentSnapshot()}) end)
end
function A.close()
    for _, p in ipairs(A.players) do
        if p.components.magician then p.components.magician:StopUsing() end
    end
    emit({kind = "closed"})
end
local function session(i, cb)
    local path = assert(TheNet:GetUserSessionFile(TheWorld.meta.session_identifier, uid(i)), "native session exists")
    TheNet:DeserializeUserSession(path, function(ok, raw)
        assert(ok and raw, "native session readable")
        local parsed, record = RunInSandboxSafe(raw)
        assert(parsed and record.data, "native session decodes")
        cb(record, path)
    end)
end
function A.sessions()
    local rows, remaining = {}, #specs
    for i in ipairs(specs) do
        session(i, function(record, path)
            rows[i] = {index = i, path = path, has_magician = record.data.magician ~= nil,
                saved_hat = record.data.magician and record.data.magician.item and record.data.magician.item.prefab == "tophat" or false}
            remaining = remaining - 1
            if remaining == 0 then emit({kind = "sessions", rows = rows}) end
        end)
    end
end
function A.restore()
    local rows, remaining = {}, #specs
    for i, spec in ipairs(specs) do
        session(i, function(record, path)
            local p = player(spec[1], i)
            A.players[i] = p
            p:SetPersistData(record.data)
            TheWorld:DoTaskInTime(.5, function()
                local hats, hat = 0
                for _, inst in pairs(Ents) do
                    if inst.prefab == "tophat" and inst.components.persistent2hm and
                        inst.components.persistent2hm.data.rollback_token == token(i) then
                        hats = hats + 1; hat = inst
                    end
                end
                local closed = spec[2] == "closed"
                local saved = closed and record.data.inventory.items[1] or record.data.magician and record.data.magician.item
                rows[i] = {index = i, role = spec[1], origin = spec[2], opened = not closed,
                    hats = hats, saved_hat = saved and saved.prefab == "tophat" or false,
                    valid_hat = hat and hat:IsValid() or false,
                    available = hat and (hat.components.inventoryitem:GetGrandOwner() == p or not hat:IsInLimbo()) or false,
                    fuel = hat and hat.components.fueled:GetPercent(), upgraded = hat and hat:HasTag("magicianupgraded2hm") or false,
                    expected_upgrade = spec[3] or false, using = p:HasTag("usingmagiciantool"),
                    magician = p.components.magician ~= nil,
                    tool_user = hat and hat.components.magiciantool.user ~= nil or false, path = path}
                remaining = remaining - 1
                if remaining == 0 then emit({kind = "restored", rows = rows}) end
            end)
        end)
    end
end
function A.reopen()
    local opened = 0
    for i, spec in ipairs(specs) do
        if spec[2] ~= "closed" then
            local p, hat = A.players[i]
            for _, inst in pairs(Ents) do
                if inst.prefab == "tophat" and inst.components.persistent2hm and
                    inst.components.persistent2hm.data.rollback_token == token(i) then hat = inst; break end
            end
            assert(p.components.magician, "granted magician ability restored")
            assert(hat and p.components.magician:StartUsingTool(hat), "restored hat reopens")
            assert(hat.container.components.container_proxy:IsOpenedBy(p), "restored hat opens actual space")
            opened = opened + 1
        end
    end
    emit({kind = "reopened", open = opened})
end
