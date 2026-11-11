-- Only loaded by run_native_antlionhat_tools.py in its copied, disposable world.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
local A = {}
G.VaultAudit = A
local function emit(row) print("[VAUDIT] " .. json.encode(row)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

function A.antlionhat_tools()
    local player = SpawnPrefab("wilson")
    player.userid = "KU_ANTLIONHAT_TOOLS_AUDIT"
    player.components.health:SetInvincible(true)
    player.components.hunger:SetRate(0)
    local hat, enhanced, plain, cane = SpawnPrefab("antlionhat"), SpawnPrefab("multitool_axe_pickaxe"),
        SpawnPrefab("multitool_axe_pickaxe"), SpawnPrefab("cane")
    enhanced:AddTag("ancient_enhanced2hm")
    assert(enhanced.ancient_enhance2hm, "native ancient enhancement is installed")
    enhanced.ancient_enhance2hm(enhanced)
    local inventory, container = player.components.inventory, hat.components.container
    inventory:Equip(hat)
    -- Avoid autonomous updates; tests call the real public DoTerraform explicitly.
    hat.components.autoterraformer:StopTerraforming()
    TheWorld:DoTaskInTime(0.2, function()
        local rows, checks = {}, 0
        local function check(value, message)
            checks = checks + 1
            assert(value, message)
        end
        local modenv, original, current
        local oldrandom = math.random
        local success, err = xpcall(function()
            check(enhanced.components.tool:GetEffectiveness(ACTIONS.MINE) == TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY * 10,
                "real upgrade mining efficiency")
            -- Find land and keep only work targets created by this fixture in the scan radius.
            local px, pz
            for x = -80, 80, 8 do
                for z = -80, 80, 8 do
                    if TheWorld.Map:IsPassableAtPoint(x, 0, z) and not TheWorld.Map:IsOceanAtPoint(x, 0, z) then px, pz = x, z; break end
                end
                if px then break end
            end
            assert(px, "disposable world has test land")
            player.Transform:SetPosition(px, 0, pz)
            for _, ent in ipairs(TheSim:FindEntities(px, 0, pz, 12)) do
                if ent ~= player and ent.components.workable then ent:Remove() end
            end
            local getter = inventory.GetEquippedItem
            local names = {"ruins_statue_head", "ruins_statue_head_nogem", "ruins_statue_mage", "ruins_statue_mage_nogem"}
            local modes = {"manual_enhanced", "manual_plain", "hat_enhanced_empty", "hat_enhanced_cane", "hat_plain_empty",
                "hat_hand_plain_slot_enhanced", "hat_hand_enhanced_slot_plain"}
            for _, name in ipairs(names) do
                for _, gemmed in ipairs({false, true}) do
                    local reference = {}
                    for _, mode in ipairs(modes) do
                        local held = inventory:Unequip(EQUIPSLOTS.HANDS)
                        if held then held.components.inventoryitem:RemoveFromOwner(true) end
                        container:RemoveItemBySlot(1)
                        local manual = mode:find("manual", 1, true) ~= nil
                        local handitem, slotitem, actual
                        if mode == "hat_enhanced_empty" then slotitem, actual = enhanced, enhanced
                        elseif mode == "hat_enhanced_cane" then handitem, slotitem, actual = cane, enhanced, enhanced
                        elseif mode == "hat_plain_empty" then slotitem, actual = plain, plain
                        elseif mode == "hat_hand_plain_slot_enhanced" then handitem, slotitem, actual = plain, enhanced, plain
                        elseif mode == "hat_hand_enhanced_slot_plain" then handitem, slotitem, actual = enhanced, plain, enhanced
                        elseif mode == "manual_enhanced" then handitem, actual = enhanced, enhanced
                        else handitem, actual = plain, plain end
                        if handitem then inventory:Equip(handitem) end
                        if slotitem then container:GiveItem(slotitem, 1) end
                        enhanced.components.finiteuses:SetUses(enhanced.components.finiteuses.total)
                        plain.components.finiteuses:SetUses(plain.components.finiteuses.total)
                        local statue = SpawnPrefab(name)
                        current = statue
                        statue.Transform:SetPosition(px + 1, 0, pz)
                        statue.gemmed = gemmed and "redgem" or nil
                        local workable = statue.components.workable
                        workable:SetRequiresToughWork(false)
                        workable:SetWorkLeft(2)
                        if not modenv then
                            modenv = getfenv(workable.onwork)
                            original = {monster = modenv.SpawnMonster2hm, magic = modenv.DoRandomRuinMagic2hm, spell = modenv.SpawnSpell2hm}
                        end
                        local monster, magic, spell, works, finished, changes = 0, 0, 0, 0, 0, 0
                        modenv.SpawnMonster2hm = function() monster = monster + 1 end
                        modenv.DoRandomRuinMagic2hm = function() magic = magic + 1 end
                        modenv.SpawnSpell2hm = function() spell = spell + 1 end
                        local onwork, onfinish = workable.onwork, workable.onfinish
                        workable.onwork = function(inst, worker, ...)
                            works = works + 1
                            local act = worker:GetBufferedAction()
                            check(act and act.invobject == actual and act.target == inst and act.action == ACTIONS.MINE,
                                "native action exposes actual tool, target and action")
                            check(inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == handitem, "hand stays real during callback")
                            return onwork(inst, worker, ...)
                        end
                        workable.onfinish = function(inst, worker, ...)
                            finished = finished + 1
                            return onfinish(inst, worker, ...)
                        end
                        local function changed() changes = changes + 1 end
                        player:ListenForEvent("equip", changed)
                        player:ListenForEvent("unequip", changed)
                        hat:ListenForEvent("itemget", changed)
                        hat:ListenForEvent("itemlose", changed)
                        local before = actual.components.finiteuses:GetUses()
                        local pending = BufferedAction(player, nil, ACTIONS.LOOKAT)
                        player.bufferedaction = pending
                        -- Force punishment chances while preserving valid integer random calls in base prefabs.
                        math.random = function(a, b) if b then return a elseif a then return 1 else return 0 end end
                        if manual then
                            for i = 1, 10 do
                                if not statue:IsValid() or not workable:CanBeWorked() then break end
                                player.bufferedaction = BufferedAction(player, statue, ACTIONS.MINE, actual)
                                check(player:PerformBufferedAction(), "native manual mining succeeds")
                            end
                            player.bufferedaction = pending
                        else
                            local x, y = TheWorld.Map:GetTileXYAtPoint(px, 0, pz)
                            hat.components.autoterraformer:DoTerraform(px, 0, pz, x, y)
                        end
                        math.random = oldrandom
                        player:RemoveEventCallback("equip", changed)
                        player:RemoveEventCallback("unequip", changed)
                        hat:RemoveEventCallback("itemget", changed)
                        hat:RemoveEventCallback("itemlose", changed)
                        local immune = actual == enhanced
                        check(finished == 1, "statue finishes exactly once")
                        check(immune and monster == 0 and magic == 0 or not immune and monster > 0 and magic > 0,
                            "immunity follows actual tool, not stored or held decoys")
                        check(gemmed and spell > 0 or not gemmed and spell == 0, "gem traps stay enabled")
                        if manual then reference[actual] = works end
                        check(works == reference[actual], "hat work count matches native manual mining: " .. works)
                        check(before - actual.components.finiteuses:GetUses() == works * actual.components.finiteuses.consumption[ACTIONS.MINE],
                            "native tool durability consumed normally")
                        check(inventory.GetEquippedItem == getter and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == handitem,
                            "equipment getter and hand unchanged")
                        check(container:GetItemInSlot(1) == slotitem and changes == 0, "no item movement or equip events")
                        check(player.bufferedaction == pending, "pending player action restored")
                        player.bufferedaction = nil
                        rows[#rows + 1] = {prefab = name, gemmed = gemmed, mode = mode, works = works,
                            monster = monster, magic = magic, spell = spell}
                        local row = rows[#rows]
                        row.kind = "antlionhat_case"
                        emit(row)
                        if statue:IsValid() then statue:Remove() end
                        current = nil
                    end
                end
            end
        end, tostring)
        math.random = oldrandom
        if original then
            modenv.SpawnMonster2hm, modenv.DoRandomRuinMagic2hm, modenv.SpawnSpell2hm = original.monster, original.magic, original.spell
        end
        if current and current:IsValid() then current:Remove() end
        for _, ent in ipairs({enhanced, plain, cane, hat, player}) do if ent:IsValid() then ent:Remove() end end
        emit({kind = "antlionhat_tools", passed = success, checks = checks, cases = #rows,
            error = not success and tostring(err):gsub("'", "") or nil})
    end)
end
