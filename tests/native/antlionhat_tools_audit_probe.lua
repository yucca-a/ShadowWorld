-- Reproduce existing compatibility gaps. Passing means reproduction, not repair.
local VERIFY_FIXED = false -- The launcher selects fixed expectations with --fixes.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(row) print("[VAUDIT] " .. json.encode(row)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

function G.VaultAudit.antlionhat_tools()
    local checks, cases, owned = 0, 0, {}
    local function check(value, message) checks = checks + 1; assert(value, message) end
    local function spawn(name)
        local ent = assert(SpawnPrefab(name), name)
        owned[#owned + 1] = ent
        return ent
    end
    local function row(data)
        data.kind = "antlionhat_case"
        cases = cases + 1
        emit(data)
    end
    local success, err = xpcall(function()
        local px, pz
        for x = -80, 80, 8 do
            for z = -80, 80, 8 do
                if TheWorld.Map:IsPassableAtPoint(x, 0, z) and not TheWorld.Map:IsOceanAtPoint(x, 0, z) then px, pz = x, z; break end
            end
            if px then break end
        end
        assert(px, "test land")
        local function clear()
            for _, ent in ipairs(TheSim:FindEntities(px, 0, pz, 12)) do
                if ent.components.workable or ent:HasTag("smallcreature") or ent:HasTag("bird") or ent:HasTag("canbebottled") then ent:Remove() end
            end
        end
        local function setup(character)
            clear()
            local player, hat = spawn(character), spawn("antlionhat")
            player.userid = "KU_HAT_AUDIT_" .. cases
            player.Transform:SetPosition(px, 0, pz)
            player.components.health:SetInvincible(true)
            player.components.hunger:SetRate(0)
            player.components.inventory:Equip(hat)
            hat.components.autoterraformer:StopTerraforming()
            return player, hat
        end
        local function mineorchop(player, hat, target, actual, manual)
            local work = target.components.workable
            local original = work.onwork
            local works = 0
            work.onwork = function(inst, worker, ...)
                works = works + 1
                return original(inst, worker, ...)
            end
            if manual then
                player.bufferedaction = BufferedAction(player, target, work.action, actual)
                check(player:PerformBufferedAction(), "manual work succeeds")
            else
                local x, y = TheWorld.Map:GetTileXYAtPoint(px, 0, pz)
                hat.components.autoterraformer:DoTerraform(px, 0, pz, x, y)
            end
            check(works > 0, "real work callback reached")
            return works
        end
        -- Woodie's native axe possession reads actual equipped hands, not invobject.
        for _, manual in ipairs({true, false}) do
            local player, hat = setup("woodie")
            local inv = player.components.inventory
            for _, item in ipairs(inv:FindItems(function(v) return v.prefab == "lucy" end)) do item:Remove() end
            local axe, tree = spawn("axe"), spawn("evergreen")
            tree.Transform:SetPosition(px + 1, 0, pz)
            tree.components.workable:SetWorkLeft(10000)
            if manual then inv:Equip(axe) else hat.components.container:GiveItem(axe, 1) end
            local works = mineorchop(player, hat, tree, axe, manual)
            local hand = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
            local lucy = hand and hand.prefab == "lucy" or false
            check(lucy == manual, "reproduce missed axe possession in hat")
            row({issue = "woodie_possession", manual = manual, works = works, lucy = lucy})
            if hand and hand.prefab == "lucy" then owned[#owned + 1] = hand end
            player:Remove(); hat:Remove()
        end
        -- Dark axe's working listener is attached only while equipped.
        for _, manual in ipairs({true, false}) do
            local player, hat = setup("woodie")
            local axe, tree = spawn("shadow_battleaxe"), spawn("evergreen")
            tree.Transform:SetPosition(px + 1, 0, pz)
            tree.components.workable:SetWorkLeft(10000)
            if manual then player.components.inventory:Equip(axe) else hat.components.container:GiveItem(axe, 1) end
            player.components.sanity:SetPercent(1)
            local before = player.components.sanity.current
            local works = mineorchop(player, hat, tree, axe, manual)
            local loss = before - player.components.sanity.current
            check(VERIFY_FIXED and loss == works * TUNING.SANITY_MED or not VERIFY_FIXED and
                (manual and loss > 0 or not manual and loss == 0), "dark axe sanity follows actual chopping")
            row({issue = "darkaxe_sanity", manual = manual, works = works, loss = loss})
            player:Remove(); hat:Remove()
        end
        -- Conversely, an unused held dark axe reacts to work done by the hat's pickaxe.
        for _, dark in ipairs({false, true}) do
            local player, hat = setup("woodie")
            local held, pick, rock = spawn(dark and "shadow_battleaxe" or "cane"), spawn("pickaxe"), spawn("rock1")
            player.components.inventory:Equip(held)
            hat.components.container:GiveItem(pick, 1)
            rock.Transform:SetPosition(px + 1, 0, pz)
            rock.components.workable:SetWorkLeft(10000)
            player.components.sanity:SetPercent(1)
            local before = player.components.sanity.current
            local works = mineorchop(player, hat, rock, pick, false)
            local loss = before - player.components.sanity.current
            check(VERIFY_FIXED and loss == 0 or not VERIFY_FIXED and (dark and loss > 0 or not dark and loss == 0),
                "unused held tool does not apply a cost")
            row({issue = "held_darkaxe_mining", held = held.prefab, works = works, loss = loss})
            player:Remove(); hat:Remove()
        end
        local function autotrap(hat)
            local task = assert(hat.autotraptask2hm, "head's real auto capture task started")
            task.fn(hat)
            if hat.autotraptask2hm then hat.autotraptask2hm:Cancel(); hat.autotraptask2hm = nil end
        end
        -- Compare a loot-only creature (frog) and an inventory creature (spider).
        for _, prefab in ipairs({"frog", "spider"}) do
            for _, manual in ipairs({true, false}) do
                local player, hat = setup("wilson")
                local trap, victim = spawn("trap"), spawn(prefab)
                trap.Transform:SetPosition(px, 0, pz)
                victim.Transform:SetPosition(px + 1, 0, pz)
                local trapped, harvests = 0, 0
                victim:ListenForEvent("ontrapped", function() trapped = trapped + 1 end)
                trap:ListenForEvent("harvesttrap", function() harvests = harvests + 1 end)
                local before = {}
                for guid in pairs(Ents) do before[guid] = true end
                if manual then
                    trap.components.trap.target = victim
                    trap.components.trap:DoSpring()
                    trap.components.trap:Harvest(player)
                else
                    hat.components.container:GiveItem(trap, 1)
                    autotrap(hat)
                end
                local alive, loot = 0, 0
                for guid, item in pairs(Ents) do
                    if not before[guid] and item:IsValid() then
                        owned[#owned + 1] = item
                        if item.prefab == prefab and item.components.inventoryitem == nil then alive = alive + 1 end
                    end
                end
                for _, item in ipairs(player.components.inventory:FindItems(function(v)
                    return v.prefab == "froglegs" or v.prefab == "monstermeat" or v.prefab == "silk" or v.prefab == "spidergland"
                end)) do loot = loot + 1 end
                local captured = #player.components.inventory:FindItems(function(v) return v.prefab == prefab end)
                row({issue = "trap_loot", prefab = prefab, manual = manual, trapped = trapped, harvests = harvests,
                    loot = loot, alive = alive, captured = captured})
                check((manual or VERIFY_FIXED) and not victim:IsValid() or not manual and not VERIFY_FIXED and
                    (prefab == "frog" and not victim:IsValid() or prefab == "spider" and captured == 1), "capture follows entity type")
                check((manual or VERIFY_FIXED) and trapped > 0 and harvests > 0 and alive == 0 or
                    not manual and not VERIFY_FIXED and trapped == 0 and harvests == 0 and loot == 0 and
                        (prefab == "frog" and alive == 1 or prefab == "spider" and captured == 1),
                    "frog respawns; inventory spider is captured but trap hooks are bypassed")
                player:Remove(); hat:Remove()
            end
        end
        -- Bottle outcome matches vanilla today, but the bottler callback is bypassed.
        for _, manual in ipairs({true, false}) do
            local player, hat = setup("wilson")
            local bottle, blob = spawn("messagebottleempty"), spawn("gelblob_small_fx")
            blob.Transform:SetPosition(px + 1, 0, pz)
            local callbacks = 0
            local original = bottle.components.bottler.onbottlefn
            bottle.components.bottler.onbottlefn = function(...)
                callbacks = callbacks + 1
                return original(...)
            end
            if manual then
                player.components.inventory:GiveItem(bottle)
                check(BufferedAction(player, blob, ACTIONS.BOTTLE, bottle):Do(), "native bottle succeeds")
            else
                hat.components.container:GiveItem(bottle, 1)
                autotrap(hat)
            end
            check(not blob:IsValid(), "blob collected")
            check(player.components.inventory:FindItem(function(v) return v.prefab == "gelblob_bottle" end), "correct bottled product")
            check(callbacks == ((manual or VERIFY_FIXED) and 1 or 0), "native bottler callback is used")
            row({issue = "bottler_callback", manual = manual, callbacks = callbacks})
            player:Remove(); hat:Remove()
        end
        -- Brightshade's copied area-tilling handler has the same bypass flag as the multitool,
        -- but the hat sets it only for multitool_axe_pickaxe. Compare actual soil and wear.
        for _, prefab in ipairs({"farm_hoe", "multitool_axe_pickaxe", "pickaxe_lunarplant"}) do
            local player, hat = setup("wilson")
            local item = spawn(prefab)
            check(item.components.farmtiller ~= nil, "tilling tool enhancement installed")
            local x, y = TheWorld.Map:GetTileXYAtPoint(px, 0, pz)
            TheWorld.Map:SetTile(x, y, WORLD_TILES.FARMING_SOIL)
            local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(px, 0, pz)
            player.Transform:SetPosition(cx, 0, cz)
            for _, ent in ipairs(TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)) do
                if ent:HasTag("soil") then ent:Remove() end
            end
            hat.components.container:GiveItem(item, 1)
            local beforehat = hat.components.finiteuses:GetUses()
            local beforetool = item.components.finiteuses:GetUses()
            hat.components.autoterraformer:DoTerraform(cx, 0, cz, x, y)
            local soil = 0
            for _, ent in ipairs(TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)) do
                if ent:HasTag("soil") then soil = soil + 1; owned[#owned + 1] = ent end
            end
            row({issue = "till_accounting", prefab = prefab, soil = soil,
                hat_uses = beforehat - hat.components.finiteuses:GetUses(),
                tool_uses = beforetool - item.components.finiteuses:GetUses()})
            check(soil > 0, "real tilling executed")
            if VERIFY_FIXED then
                check(beforetool - item.components.finiteuses:GetUses() == soil * item.components.finiteuses.consumption[ACTIONS.TILL],
                    "tilling consumes only native per-action uses")
                check(item.oldtill2hm == nil, "temporary till flag restored")
            end
            player:Remove(); hat:Remove()
        end
        if VERIFY_FIXED then
            -- Native Harvest must charge the last trap use only once and still deliver loot.
            for _, lasthead in ipairs({false, true}) do
                local player, hat = setup("wilson")
                local trap, spare, victim = spawn("trap"), spawn("trap"), spawn("frog")
                player.components.inventory:GiveItem(spare)
                hat.components.container:GiveItem(trap, 1)
                trap.components.finiteuses:SetUses(1)
                if lasthead then hat.components.finiteuses:SetUses(1) end
                victim.Transform:SetPosition(px + 1, 0, pz)
                local beforehat = hat.components.finiteuses:GetUses()
                local spareuses = spare.components.finiteuses:GetUses()
                autotrap(hat)
                check(not trap:IsValid() and not victim:IsValid(), "last trap use consumed and frog captured")
                check(player.components.inventory:FindItem(function(v) return v.prefab == "froglegs" end), "last use still delivers native loot")
                check(spare:IsValid() and spare.components.finiteuses:GetUses() == spareuses, "replacement not charged")
                check(lasthead and not hat:IsValid() or not lasthead and
                    hat.components.container:GetItemInSlot(1) == spare and beforehat - hat.components.finiteuses:GetUses() == 1,
                    "head wear and replacement remain correct on final uses")
                row({issue = "trap_last_use", lasthead = lasthead})
                player:Remove(); if hat:IsValid() then hat:Remove() end
            end
            do
                local player, hat = setup("wilson")
                local trap, bird = spawn("birdtrap"), spawn("crow")
                bird.Transform:SetPosition(px + 1, 0, pz)
                bird.sg:GoToState("idle")
                bird.components.health:SetPercent(0.4)
                local expected = bird.components.health:GetPercent()
                hat.components.container:GiveItem(trap, 1)
                local before = trap.components.finiteuses:GetUses()
                autotrap(hat)
                local captured = player.components.inventory:FindItem(function(v) return v.prefab == "crow" end)
                if captured then owned[#owned + 1] = captured end
                row({issue = "birdtrap_data", captured = captured ~= nil, original_valid = bird:IsValid(),
                    healthpercent = captured and captured.components.health:GetPercent() or nil})
                check(captured and captured ~= bird and not bird:IsValid(), "bird uses native trap reconstruction")
                check(math.abs(captured.components.health:GetPercent() - expected) < 1e-6, "for-happy bird trap data preserved")
                check(before - trap.components.finiteuses:GetUses() == 1 and trap.components.trap.task == nil and
                    not trap.components.trap:IsSprung(), "held birdtrap consumed once and not armed")
                player:Remove(); hat:Remove()
            end
            for _, reason in ipairs({"swc2hm", "untrappable", "rejected"}) do
                local player, hat = setup("wilson")
                local trap, victim = spawn("trap"), spawn("frog")
                victim.Transform:SetPosition(px + 1, 0, pz)
                if reason == "swc2hm" then victim:AddTag("swc2hm")
                elseif reason == "untrappable" then victim.components.lootdropper.trappable = false
                else trap.components.trap.DoSpring = function() end end
                hat.components.container:GiveItem(trap, 1)
                local before, beforehat = trap.components.finiteuses:GetUses(), hat.components.finiteuses:GetUses()
                autotrap(hat)
                check(victim:IsValid() and trap.components.finiteuses:GetUses() == before and
                    hat.components.finiteuses:GetUses() == beforehat, "rejected capture consumes nothing")
                check(trap.components.trap.target == nil, "failed capture leaves no stale target")
                row({issue = "trap_excluded", reason = reason})
                player:Remove(); hat:Remove()
            end
            do
                local player, hat = setup("wilson")
                local trap, victim = spawn("trap"), spawn("frog")
                hat.components.container:GiveItem(trap, 1)
                trap.components.trap.target = victim
                trap.components.trap:DoSpring()
                check(not victim:IsValid(), "prepare pending native catch")
                local before = trap.components.finiteuses:GetUses()
                autotrap(hat) -- No other live target is nearby.
                check(player.components.inventory:FindItem(function(v) return v.prefab == "froglegs" end), "pending catch delivered without overwriting it")
                check(before - trap.components.finiteuses:GetUses() == 1 and trap.components.trap.task == nil,
                    "pending catch settled once and held trap stopped")
                row({issue = "trap_pending"})
                player:Remove(); hat:Remove()
            end
            for _, mode in ipairs({"stack", "refill", "rejected", "lasthead"}) do
                local player, hat = setup("wilson")
                local bottle, blob = spawn("messagebottleempty"), spawn("gelblob_small_fx")
                blob.Transform:SetPosition(px + 1, 0, pz)
                local spare
                if mode == "stack" then bottle.components.stackable:SetStackSize(3)
                elseif mode == "refill" then
                    spare = spawn("messagebottleempty")
                    spare.components.stackable:SetStackSize(2)
                    player.components.inventory:GiveItem(spare)
                elseif mode == "lasthead" then hat.components.finiteuses:SetUses(1) end
                local original, calls = bottle.components.bottler.onbottlefn, 0
                bottle.components.bottler.onbottlefn = function(inst, target, doer)
                    calls = calls + 1
                    check(doer:GetBufferedAction().invobject == inst, "bottler sees native current action")
                    if mode == "rejected" then return false end
                    return original(inst, target, doer)
                end
                hat.components.container:GiveItem(bottle, 1)
                local beforehat = hat.components.finiteuses:GetUses()
                autotrap(hat)
                check(calls == 1, "one bottler callback per attempt")
                local product = player.components.inventory:FindItem(function(v) return v.prefab == "gelblob_bottle" end)
                check(mode == "rejected" and blob:IsValid() and not product and bottle:IsValid() and
                    hat.components.finiteuses:GetUses() == beforehat or mode ~= "rejected" and not blob:IsValid() and product,
                    "native success or rejection controls product and wear")
                if mode == "stack" then
                    check(hat.components.container:GetItemInSlot(1) == bottle and bottle.components.stackable:StackSize() == 2,
                        "only one bottle removed from stack")
                elseif mode == "refill" then
                    check(not bottle:IsValid() and hat.components.container:GetItemInSlot(1) == spare and spare.components.stackable:StackSize() == 2,
                        "last bottle replenishes from inventory without consuming spare")
                elseif mode == "lasthead" then check(not hat:IsValid(), "head's last use breaks safely") end
                row({issue = "bottle_edges", mode = mode, callbacks = calls})
                player:Remove(); if hat:IsValid() then hat:Remove() end
            end
            do
                local player, hat = setup("woodie")
                local axe, kit, tree = spawn("shadow_battleaxe"), spawn("voidcloth_kit"), spawn("evergreen")
                tree.Transform:SetPosition(px + 1, 0, pz)
                tree.components.workable:SetWorkLeft(10000)
                hat.components.container:GiveItem(axe, 1)
                axe.components.finiteuses:Use(axe.components.finiteuses:GetUses())
                check(axe:HasTag("broken") and axe.components.tool == nil, "native axe break removes tool component")
                check(axe.components.forgerepairable:Repair(player, kit), "native kit repairs axe")
                check(axe.components.tool and not axe:HasTag("broken"), "repair rebuilt native tool")
                player.components.sanity:SetPercent(1)
                local before = player.components.sanity.current
                local works = mineorchop(player, hat, tree, axe, false)
                check(before - player.components.sanity.current == works * TUNING.SANITY_MED, "repaired axe keeps actual-work cost")
                row({issue = "darkaxe_repaired", works = works})
                player:Remove(); hat:Remove()
            end
        end
    end, tostring)
    for _, ent in ipairs(owned) do if ent:IsValid() then ent:Remove() end end
    emit({kind = "antlionhat_tools", passed = success, checks = checks, cases = cases,
        error = not success and tostring(err):gsub("'", "") or nil})
end
