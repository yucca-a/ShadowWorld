local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)
for _, prefab in ipairs({"beef_bell", "shadow_beef_bell"}) do
    AddPrefabPostInit(prefab, function(inst)
        if TheWorld.ismastersim then
            inst:ListenForEvent("unwrappeditem", function() G.VaultAudit.unwrappedbell = inst end)
        end
    end)
end

function G.VaultAudit.um_compat()
    local owned, checks, cases, done = {}, 0, 0, false
    local function check(ok, message) checks = checks + 1; assert(ok, message) end
    local function spawn(prefab)
        local e = assert(SpawnPrefab(prefab), prefab)
        owned[#owned + 1] = e
        if e.brain then e.brain:Stop() end
        if e.components.health then e.components.health:SetInvincible(true) end
        if e.components.hunger then e.components.hunger:SetRate(0) end
        return e
    end
    local function finish(ok, err)
        if done then return end
        done = true
        for i = #owned, 1, -1 do if owned[i]:IsValid() then owned[i]:Remove() end end
        emit({kind = "um_compat", passed = ok, checks = checks, cases = cases, error = not ok and tostring(err):gsub("'", "") or nil})
    end
    local function safe(fn)
        if done then return end
        local ok, err = pcall(fn)
        if not ok then finish(false, err) end
    end
    local function later(time, fn) TheWorld:DoTaskInTime(time, function() safe(fn) end) end
    local function row(name, extra)
        cases = cases + 1
        emit({kind = "um_compat_case", name = name, detail = extra})
    end
    safe(function()
        local p, w = spawn("wx78"), spawn("wathom")
        p.userid, w.userid = "KU_UM_COMPAT_WX", "KU_UM_COMPAT_WATHOM"
        p.entity:SetCanSleep(false)
        w.entity:SetCanSleep(false)
        local amulet, hat, lab = spawn("yellowamulet"), spawn("nutrientsgoggleshat"), spawn("researchlab3")
        amulet:AddTag("ancient_enhanced2hm")
        check(amulet.ancient_enhance2hm ~= nil, "ancient enhancement available")
        amulet:ancient_enhance2hm()
        p.components.inventory:GiveItem(amulet)
        local heard = {}
        local mod_str_fn = p.components.talker.mod_str_fn
        p.components.talker.mod_str_fn = function(text)
            heard[#heard + 1] = text
            return mod_str_fn and mod_str_fn(text) or text
        end
        local function expectSpeech(needle)
            local text = heard[#heard] or ""
            check(UM_COMPAT_BEFORE and text == "" or not UM_COMPAT_BEFORE and text:find(needle, 1, true),
                "speech expected " .. needle .. ": " .. text)
            check(not text:find("only_used_by_", 1, true), "no placeholder leaked")
            return text
        end
        later(.2, function()
            -- Actual trader path grants shadowmagic + magician and starts wardrobe FX.
            local fuel = spawn("nightmarefuel")
            fuel.components.stackable:SetStackSize(4)
            check(lab.components.trader:AcceptGift(p, fuel), "shadow magic exchange")
            check(p:HasTag("shadowmagic") and p.components.magician ~= nil, "shadow abilities granted")
            p.sg:GoToState("idle")
            check(BufferedAction(p, amulet, ACTIONS.LOOKAT):Do(), "native amulet inspect")
            later(.15, function()
                row("wx78_amulet_after_exchange", expectSpeech("魔光生效"))
                p.components.inventory:Equip(hat)
                later(.15, function()
                    row("wx78_hat_after_exchange", expectSpeech("本季节"))
                    -- Save/load of the character's capability data uses the existing restoration path.
                    local saved = p:GetSaveRecord()
                    local restored = assert(SpawnSaveRecord(saved))
                    owned[#owned + 1] = restored
                    later(.15, function()
                        check(restored:HasTag("shadowmagic") and restored.components.magician ~= nil, "magic restored after load")
                        row("wx78_magic_reload")
                        -- Plain strings and non-placeholder text still reach native Talker.
                        p.components.talker:Say("正常台词 TEST", .1, true)
                        later(.15, function()
                            check(heard[#heard] == "正常台词 TEST", "ordinary speech intact")
                            local attack = w.sg.sg.actionhandlers[ACTIONS.ATTACK].deststate
                            local client = require("stategraphs/SGwilson_client").actionhandlers[ACTIONS.ATTACK].deststate
                            for _, prefab in ipairs({"icestaff", "icestaff2", "icestaff3", "firestaff", "spear", "blowdart_pipe"}) do
                                local weapon = spawn(prefab)
                                w.components.inventory:Equip(weapon)
                                w.sg:GoToState("idle")
                                local action = BufferedAction(w, p, ACTIONS.ATTACK)
                                local state = attack(w, action)
                                local upgraded = prefab == "icestaff2" or prefab == "icestaff3"
                                local leap = prefab ~= "blowdart_pipe" and not (UM_COMPAT_BEFORE and upgraded)
                                check((state == "wathomleap") == leap, "server route " .. prefab .. ": " .. tostring(state))
                                check((client(w, action) == "wathomleap_pre") == (prefab ~= "blowdart_pipe"), "prediction route " .. prefab)
                                if not UM_COMPAT_BEFORE and upgraded then
                                    w:PushBufferedAction(action)
                                    w.sg:GoToState(state)
                                    check(w.sg.currentstate.name == "wathomleap", "real leap entered")
                                    check(w.range2hm, "upgraded staff retains equipment-swap guard")
                                    w.sg:GoToState("idle")
                                    w.range2hm = nil
                                    -- Reject reentry while already attacking, matching UM's base staff rule.
                                    w.sg:AddStateTag("attack")
                                    check(attack(w, action) ~= "wathomleap", "no repeated leap during attack")
                                    w.sg:RemoveStateTag("attack")
                                end
                                w.components.inventory:Unequip(EQUIPSLOTS.HANDS)
                                row("wathom_" .. prefab, state)
                            end
                            local human = spawn("wilson")
                            human.components.inventory:Equip(spawn("icestaff2"))
                            check(attack(human, BufferedAction(human, p, ACTIONS.ATTACK)) ~= "wathomleap", "ordinary character route")
                            if not UM_COMPAT_BETA then row("stable_has_no_silksack"); finish(true); return end
                            local specs, index = {{"beef_bell", false}, {"beef_bell", true}, {"shadow_beef_bell", true}}, 0
                            local nextbell
                            nextbell = function()
                                index = index + 1
                                local spec = specs[index]
                                if not spec then finish(true); return end
                                local bag, cow, bell = spawn("silksack"), spawn("beefalo"), spawn(spec[1])
                                cow.components.domesticatable:DeltaDomestication(1, p)
                                cow.components.domesticatable:SetDomesticated(true)
                                cow.components.domesticatable:DeltaObedience(1)
                                check(bell.components.useabletargeteditem:StartUsingItem(cow, p), "bind bell")
                                cow.components.writeable:Write(p, "Compat " .. index)
                                if spec[1] == "beef_bell" and spec[2] then
                                    check(bell.components.trader:AcceptGift(p, spawn("orangegem")), "upgrade bell")
                                end
                                check(bell:HasTag("nobundling"), "bound bell protected by native tag")
                                local container = bag.components.container
                                local silk, gold = spawn("silk"), spawn("goldnugget")
                                silk.components.stackable:SetStackSize(12)
                                check(container:GiveItem(bell, 1), "bell can be carried")
                                check(container:GiveItem(gold, 2), "ordinary goods in sack")
                                check(container:GiveItem(silk, 9), "silk in sack")
                                local valid = container.widget.buttoninfo.validfn
                                if UM_COMPAT_BEFORE then
                                    check(valid(bag), "old widget allows bell")
                                    check(bag:WrapStuff(p), "old packing accepts bell")
                                    local bundle = container:GetItemInSlot(7)
                                    check(bundle and bundle.components.unwrappable, "old bundle created")
                                    local duplicated = false
                                    for _, record in ipairs(bundle.components.unwrappable.itemdata) do
                                        if record.prefab == bell.prefab and record.data and record.data.beef_record then duplicated = true end
                                    end
                                    check(duplicated, "bundle embeds a second live beefalo record")
                                    row("silksack_old_dupe_" .. index)
                                else
                                    check(valid(bag) and bag:WrapStuff(p), "bound bell and ordinary contents wrap")
                                    check(not bell:IsValid() and not cow:IsValid(), "original bell and cow consumed together")
                                    check(silk.components.stackable:StackSize() == 6, "six silk spent once")
                                    local bundle = container:GetItemInSlot(7)
                                    check(#bundle.components.unwrappable.itemdata == 2, "bell and normal item saved")
                                    bundle.components.unwrappable:Unwrap(p, true)
                                    local restored = G.VaultAudit.unwrappedbell
                                    check(restored and restored:GetBeefalo() and restored:GetBeefalo() ~= cow, "unpack restores one bound cow")
                                    owned[#owned + 1] = restored:GetBeefalo()
                                    owned[#owned + 1] = restored
                                    row("silksack_bell_transferred_" .. index)
                                end
                                -- Each next binding must have a distinct owner inventory.
                                if bell:IsValid() then bell:Remove() end
                                later(.15, nextbell)
                            end
                            later(.15, nextbell)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- Let the original leap timeline actually fire a projectile and spend durability.
function G.VaultAudit.um_staff_casts()
    local owned, checks, index, done = {}, 0, 0, false
    local function finish(ok, err)
        if done then return end
        done = true
        for i = #owned, 1, -1 do if owned[i]:IsValid() then owned[i]:Remove() end end
        emit({kind = "um_staff_casts", passed = ok, checks = checks, error = not ok and tostring(err):gsub("'", "") or nil})
    end
    local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
    local function safe(fn)
        local ok, err = pcall(fn)
        if not ok then finish(false, err) end
    end
    local function later(t, fn) TheWorld:DoTaskInTime(t, function() if not done then safe(fn) end end) end
    local function spawn(name)
        local ent = assert(SpawnPrefab(name))
        owned[#owned + 1] = ent
        if ent.brain then ent.brain:Stop() end
        if ent.components.health then ent.components.health:SetInvincible(true) end
        if ent.components.hunger then ent.components.hunger:SetRate(0) end
        return ent
    end
    local nextstaff
    nextstaff = function()
        index = index + 1
        local prefab = ({"icestaff2", "icestaff3"})[index]
        if not prefab then finish(true); return end
        local w, target, staff = spawn("wathom"), spawn("pigman"), spawn(prefab)
        -- SpawnPrefab test actors have no owner handshake; the stable leap uses
        -- the real playercontroller at its impact/recovery frames.
        if not UM_COMPAT_BETA and not w.components.playercontroller then w:AddComponent("playercontroller") end
        w.entity:SetCanSleep(false)
        target.entity:SetCanSleep(false)
        w.Physics:Teleport(0, 0, 0)
        target.Physics:Teleport(3, 0, 0)
        w.components.adrenaline:SetPercent(.7)
        w.components.inventory:Equip(staff)
        later(.15, function()
            if target.brain then target.brain:Stop() end
            target.components.locomotor:Stop()
            w.sg:GoToState("idle")
            local action = BufferedAction(w, target, ACTIONS.ATTACK)
            local state = w.sg.sg.actionhandlers[ACTIONS.ATTACK].deststate(w, action)
            check(state == "wathomleap", "real action route " .. prefab)
            local uses = staff.components.finiteuses:GetUses()
            w:PushBufferedAction(action)
            w.sg:GoToState(state)
            check(w.sg.currentstate.name == "wathomleap", "real airborne state " .. prefab)
            later(.2, function()
                check(staff.components.finiteuses:GetUses() == uses, "staff waits for leap impact frame")
                later(.7, function()
                    check(staff.components.finiteuses:GetUses() == uses - 1, "exactly one durability use " .. prefab)
                    check(target.components.freezable:IsFrozen() or target.components.freezable.coldness > 0, "projectile freezes target " .. prefab)
                    emit({kind = "um_compat_case", name = "wathom_real_cast_" .. prefab})
                    nextstaff()
                end)
            end)
        end)
    end
    safe(nextstaff)
end
