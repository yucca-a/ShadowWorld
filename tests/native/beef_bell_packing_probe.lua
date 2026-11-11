local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)
AddPrefabPostInit("silken_bundle", function(inst)
    if TheWorld.ismastersim then inst:AddComponent("vaultauditmark") end
end)
for _, prefab in ipairs({"beef_bell", "shadow_beef_bell"}) do
    AddPrefabPostInit(prefab, function(inst)
        if TheWorld.ismastersim then inst:ListenForEvent("unwrappeditem", function() G.VaultAudit.unwrapped = inst end) end
    end)
end

local function CountCows(id)
    local count = 0
    for _, ent in pairs(Ents) do
        if ent.prefab == "beefalo" and ent:IsValid() and ent.components.uniqueid.id == id then count = count + 1 end
    end
    return count
end

function G.VaultAudit.bell_packing()
    local checks, cases, owned, done = 0, 0, {}, false
    local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
    local function spawn(prefab)
        local e = assert(SpawnPrefab(prefab), prefab)
        owned[#owned + 1] = e
        if e.brain then e.brain:Stop() end
        if e.components.hunger then e.components.hunger:SetRate(0) end
        return e
    end
    local function finish(ok, err)
        if done then return end
        done = true
        for i = #owned, 1, -1 do if owned[i]:IsValid() then owned[i]:Remove() end end
        emit({kind = "bell_packing", passed = ok, checks = checks, cases = cases, error = not ok and tostring(err):gsub("'", "") or nil})
    end
    local function safe(fn) local ok, err = pcall(fn); if not ok then finish(false, err) end end
    local function later(t, fn) TheWorld:DoTaskInTime(t, function() if not done then safe(fn) end end) end
    safe(function()
        local p = spawn("wilson")
        p.userid = "KU_PACKING"
        p:AddComponent("playeractionpicker")
        p:AddComponent("playercontroller")
        p.entity:SetCanSleep(false)
        p.components.health:SetInvincible(true)
        local specs = {
            {"beef_bell", "mounted"}, {"beef_bell", "live"}, {"shadow_beef_bell", "live"},
            {"beef_bell", "recalled"}, {"shadow_beef_bell", "recalled"},
            {"beef_bell", "dead"}, {"shadow_beef_bell", "dead"},
        }
        local specindex, nextspec = 0
        nextspec = function()
            specindex = specindex + 1
            local spec = specs[specindex]
            if not spec then finish(true); return end
            -- Each case has its own actual owner; native bells allow only one
            -- linked bell per player inventory, including auto-collected items.
            p:Remove()
            p = spawn("wilson")
            p.userid = "KU_PACKING_" .. specindex
            p:AddComponent("playeractionpicker")
            p:AddComponent("playercontroller")
            p.entity:SetCanSleep(false)
            p.components.health:SetInvincible(true)
            local cow, bell, bag = spawn("beefalo"), spawn(spec[1]), spawn("silksack")
            local id, expectedhealth, cooldown
            local function begin()
                local round = 0
                local nextround
                nextround = function()
                    round = round + 1
                    if round > 3 then
                        if spec[2] == "recalled" then
                            bell.components.useabletargeteditem:StopUsingItem()
                            cow = assert(bell:GetBeefalo(), "restored recalled bell can still summon")
                            owned[#owned + 1] = cow
                            check(CountCows(id) == 1, "summoning after packing creates exactly one cow")
                            check(math.abs(cow.components.health.currenthealth - expectedhealth) < 1 and cow.components.rideable.saddle, "summon keeps health and saddle")
                        elseif spec[2] == "dead" and spec[1] == "beef_bell" then
                            local task = bell.relivetask2hm
                            local revive = task.fn
                            task:Cancel()
                            revive(bell)
                            cow = assert(bell:GetBeefalo(), "restored ordinary revival callback still works")
                            owned[#owned + 1] = cow
                            check(not cow.components.health:IsDead() and math.abs(cow.components.health:GetPercent() - .1) < .001, "normal revival retains ten-percent health rule")
                        elseif spec[2] == "dead" then
                            local before = cow
                            bell:ReviveTarget(cow, p)
                            check(bell:GetBeefalo() == before and not cow.components.health:IsDead() and CountCows(id) == 1, "shadow revive reuses one restored corpse")
                        end
                        cases = cases + 1
                        emit({kind = "bell_packing_case", name = spec[1] .. "_" .. spec[2], rounds = 3})
                        if bell:IsValid() then bell:Remove() end
                        if cow:IsValid() then cow:Remove() end
                        later(.1, nextspec)
                        return
                    end
                    local container = bag.components.container
                    local silk = spawn("silk")
                    silk.components.stackable:SetStackSize(12)
                    check(container:GiveItem(bell, 1) and container:GiveItem(silk, 9), "packing slots")
                    check(container.widget.buttoninfo.validfn(bag), "bound/upgrade bell button allowed")
                    local previouscow = bell:GetBeefalo()
                    check(bag:WrapStuff(p), "native sack wraps bell")
                    check(not bell:IsValid(), "source bell consumed")
                    if previouscow then check(not previouscow:IsValid(), "source cow consumed without detached copy") end
                    check(not p.components.rider:IsRiding(), "packing dismounts rider")
                    check(silk.components.stackable:StackSize() == 6, "exact silk cost")
                    container:RemoveItemBySlot(9):Remove()
                    local bundle = container:RemoveItemBySlot(7)
                    p.components.inventory:GiveItem(bundle)
                    local raw = bundle.components.unwrappable.itemdata
                    check(not raw[1].data.beefbellpreview2hm, "real payload has no preview marker")
                    local function expectedpacked() return spec[2] == "dead" and spec[1] == "beef_bell" and cow:IsValid() and 1 or 0 end
                    -- The ordinary dead cow is an old corpse outside the bell; no new corpse is made.
                    check(CountCows(id) == expectedpacked(), "packed cow count")
                    local peeks, peeknext = 0
                    peeknext = function()
                        peeks = peeks + 1
                        if peeks <= 3 then
                            check(bundle.components.unwrappable:PeekInContainer(p), "real read-only peek")
                            check(bundle.components.unwrappable.itemdata == raw, "peek restores authoritative record table")
                            local preview = p.sg.statemem.peekcontainer
                            check(preview and preview.components.container:GetItemInSlot(1).beefbellpreview2hm, "preview bell marked before load")
                            later(.1, function()
                                check(CountCows(id) == expectedpacked(), "preview never spawns a cow")
                                local item = preview.components.container:GetItemInSlot(1)
                                check(not item:GetBeefalo() and not item.relivetask2hm, "preview has no binding or revival task")
                                p.sg:GoToState("idle")
                                later(.1, function()
                                    check(CountCows(id) == expectedpacked(), "closing preview leaves no cow")
                                    peeknext()
                                end)
                            end)
                            return
                        end
                        -- Native record round trip while still packed, before consuming the payload.
                        local saved = bundle:GetSaveRecord()
                        bundle:Remove()
                        bundle = assert(SpawnSaveRecord(saved))
                        owned[#owned + 1] = bundle
                        p.components.inventory:GiveItem(bundle)
                        check(CountCows(id) == expectedpacked(), "loading packed bundle does not restore cow")
                        G.VaultAudit.unwrapped = nil
                        bundle.components.unwrappable:Unwrap(p, true)
                        bell = assert(G.VaultAudit.unwrapped, "native bell restored")
                        owned[#owned + 1] = bell
                        later(.15, function()
                            check(not bell.beefbellpreview2hm, "real unpack is not a preview")
                            if spec[2] == "recalled" then
                                check(not bell:GetBeefalo() and bell.components.persistent2hm.data.beefalotmp, "recalled state preserved")
                                check(CountCows(id) == 0, "recalled cow stays stored")
                            elseif spec[2] == "dead" and spec[1] == "beef_bell" then
                                check(not bell:GetBeefalo() and bell.relivetask2hm, "dead ordinary cow still waits for revival")
                                check(bell.relivetask2hm:NextTime() - GetTime() <= cooldown + .2, "revival delay does not reset")
                            else
                                cow = assert(bell:GetBeefalo(), "bound cow restored")
                                owned[#owned + 1] = cow
                                check(CountCows(id) == 1, "exactly one logical cow after unpack")
                                check(cow.components.follower.leader == bell, "actual follower bound to restored bell")
                                check(cow.components.health:IsDead() == (spec[2] == "dead"), "life/death state preserved")
                                if spec[2] == "dead" then
                                    local remaining = bell.components.rechargeable:GetTimeToCharge()
                                    check(remaining > 60 and remaining < 74, "shadow revival cooldown preserved")
                                end
                                if spec[2] ~= "dead" then
                                    check(math.abs(cow.components.health.currenthealth - expectedhealth) < 1, "health preserved")
                                    check(cow.components.domesticatable:IsDomesticated(), "domestication preserved")
                                    check(cow.components.rideable.saddle ~= nil, "saddle preserved")
                                    check(cow.components.named.name == "Packed cow " .. specindex, "name preserved")
                                end
                            end
                            if specindex == 3 and round == 3 then
                                -- Leave a real packed bell on the ground for normal save + process restart.
                                local restartbundle = spawn("silken_bundle")
                                restartbundle.components.unwrappable:WrapItems({bell}, p)
                                bell:Remove()
                                restartbundle.components.vaultauditmark.token = "bell-pack-restart:" .. tostring(id)
                                -- Keep only this owned test entity across function cleanup.
                                for i, e in ipairs(owned) do if e == restartbundle then table.remove(owned, i); break end end
                                bell = spawn("shadow_beef_bell")
                            end
                            nextround()
                        end)
                    end
                    peeknext()
                end
                nextround()
            end
            later(.15, function()
                id = assert(cow.components.uniqueid.id, "native uniqueid initialized")
                cow.components.domesticatable:DeltaDomestication(1, p)
                cow.components.domesticatable:SetDomesticated(true)
                cow.components.domesticatable:DeltaObedience(1)
                local bound, reason = bell.components.useabletargeteditem:StartUsingItem(cow, p)
                check(bound, "initial binding: " .. tostring(reason))
                cow.components.writeable:Write(p, "Packed cow " .. specindex)
                if spec[1] == "beef_bell" and specindex ~= 1 then
                    check(bell.components.trader:AcceptGift(p, spawn("orangegem")), "orange upgrade")
                end
                cow.components.health:SetPercent(.63)
                cow.components.rideable:SetSaddleable(true)
                cow.components.rideable:SetSaddle(p, spawn("saddle_basic"))
                expectedhealth = cow.components.health.currenthealth
                if specindex == 1 then
                    local failed = spawn("silken_bundle")
                    failed.components.unwrappable:SetOnWrappedFn(function() error("intentional serialization failure") end)
                    check(not pcall(failed.components.unwrappable.WrapItems, failed.components.unwrappable, {bell}, p), "failed packaging propagates error")
                    check(failed.components.unwrappable.itemdata == nil, "failed packaging leaves no duplicate payload")
                    check(bell:IsValid() and bell:GetBeefalo() == cow and cow:IsValid(), "failed packaging preserves original owner and cow")
                end
                if spec[2] == "mounted" then
                    p.components.rider:Mount(cow, true)
                    check(p.components.rider:IsRiding(), "actually riding source cow")
                elseif spec[2] == "recalled" then
                    bell.components.useabletargeteditem:StopUsingItem()
                elseif spec[2] == "dead" then
                    cow.components.health:Kill()
                    if spec[1] == "shadow_beef_bell" then bell.components.rechargeable:Discharge(73) end
                end
                later(.6, function()
                    if spec[2] == "dead" and spec[1] == "beef_bell" then cooldown = bell.relivetask2hm:NextTime() - GetTime() end
                    begin()
                end)
            end)
        end
        later(.15, nextspec)
    end)
end

function G.VaultAudit.bell_packing_restart()
    local checks = 0
    local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
    local ok, err = pcall(function()
        local bundle, id
        for _, ent in pairs(Ents) do
            local mark = ent.components.vaultauditmark
            if mark and mark.token and mark.token:find("bell-pack-restart:", 1, true) == 1 then
                check(not bundle, "only one restart package")
                bundle = ent
                id = tonumber(mark.token:sub(#"bell-pack-restart:" + 1)) or mark.token:sub(#"bell-pack-restart:" + 1)
            end
        end
        check(bundle ~= nil and CountCows(id) == 0, "packed cow remains absent after normal server restart")
        G.VaultAudit.unwrapped = nil
        bundle.components.unwrappable:Unwrap(nil, true)
        local bell = G.VaultAudit.unwrapped
        check(bell and bell:GetBeefalo() and CountCows(id) == 1, "normal restart unpack restores exactly one cow")
    end)
    emit({kind = "bell_packing_restart", passed = ok, checks = checks, error = not ok and tostring(err):gsub("'", "") or nil})
end
