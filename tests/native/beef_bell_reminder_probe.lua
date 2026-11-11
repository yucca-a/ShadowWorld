-- Disposable server: actual bell binding, riding, container ownership and periodic task.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

function G.VaultAudit.bell_reminder()
    local checks, rows, owned, done = 0, 0, {}, false
    local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
    local function finish(ok, err)
        if done then return end
        done = true
        for _, ent in ipairs(owned) do
            if ent:IsValid() and ent.components.rider then
                ent.components.rider:ActualDismount()
                ent.sg:GoToState("idle")
            end
        end
        for i = #owned, 1, -1 do if owned[i]:IsValid() then owned[i]:Remove() end end
        emit({kind = "bell_reminder", passed = ok, checks = checks, cases = rows,
            error = not ok and tostring(err):gsub("'", "") or nil})
    end
    local function safe(fn)
        if done then return end
        local ok, err = pcall(fn)
        if not ok then finish(false, err) end
    end
    local function later(delay, fn) TheWorld:DoTaskInTime(delay, function() safe(fn) end) end
    local function spawn(name)
        local ent = assert(SpawnPrefab(name), name)
        owned[#owned + 1] = ent
        return ent
    end
    local function timer(p)
        for _, fn in ipairs(p.event_listening.mounted[p]) do
            local task, callback
            for i = 1, 30 do
                local name, value = debug.getupvalue(fn, i)
                if name == nil then break end
                if name == "task" then task = value elseif name == "check" then callback = value end
            end
            if callback then return task, callback end
        end
    end
    local specs, index = {{"beef_bell", false}, {"beef_bell", true}, {"shadow_beef_bell", true}}, 0
    local nextcase
    nextcase = function()
        index = index + 1
        local spec = specs[index]
        if not spec then finish(true); return end
        local p, cow, bell = spawn("wilson"), spawn("beefalo"), spawn(spec[1])
        p.userid = "KU_BELL_REMINDER_" .. index
        p.entity:SetCanSleep(false)
        p.components.health:SetInvincible(true)
        p.components.hunger:SetRate(0)
        cow.components.domesticatable:DeltaDomestication(1, p)
        cow.components.domesticatable:SetDomesticated(true)
        cow.components.domesticatable:DeltaObedience(1)
        cow.components.health:SetInvincible(true)
        if cow.brain then cow.brain:Stop() end
        later(0.1, function()
            local x, y, z = p.Transform:GetWorldPosition()
            cow.Physics:Teleport(x, y, z)
            bell.Physics:Teleport(x, y, z)
            local bound, reason = bell.components.useabletargeteditem:StartUsingItem(cow, p)
            check(bound, "native binding: " .. tostring(reason) .. " domestication=" .. cow.components.domesticatable.domestication)
            -- Complete the native naming step; cancelling an unnamed binding unlinks the cow.
            cow.components.writeable:Write(p, "Reminder " .. index)
            check(cow.components.writeable:IsWritten(), "native naming completed")
            check(bell:GetBeefalo() == cow and cow.components.follower.leader == bell, "native binding identities")
            if spec[1] == "beef_bell" and spec[2] then
                check(bell.components.trader:AcceptGift(p, spawn("orangegem")), "orange gem accepted")
                check(bell:HasTag("bell_upgrade2hm"), "ordinary upgraded")
            end
            if spec[1] == "shadow_beef_bell" then check(bell:HasTag("minotaurhorn2hm"), "shadow upgraded") end
            cow.components.rideable:SetSaddleable(true)
            cow.components.rideable:SetSaddle(p, spawn("saddle_basic"))
            local messages = 0
            local say = p.components.talker.Say
            p.components.talker.Say = function(self, text, ...)
                if text:find("忘带牛铃", 1, true) or text:find("beefalo bell", 1, true) then messages = messages + 1 end
                return say(self, text, ...)
            end
            p.components.rider:Mount(cow, true)
            check(p.components.rider:IsRiding(), "actual mounted")
            local task, tick = timer(p)
            check(task and task.fn == tick, "actual reminder timer installed")
            local function move(ent, distance)
                local px, py, pz = p.Transform:GetWorldPosition()
                if ent.Physics then ent.Physics:Teleport(px + distance, py, pz)
                else ent.Transform:SetPosition(px + distance, py, pz) end
            end
            move(bell, 39); tick(); check(messages == 0, "near bell silent")
            move(bell, 41); tick(); check(messages == 1, "far bell warns")
            tick(); move(bell, 39); tick(); move(bell, 41); tick()
            check(messages == 1, "boundary and repeat silent")
            move(bell, 19); tick(); move(bell, 41); tick()
            check(messages == 2, "return close resets warning")
            p.components.inventory:GiveItem(bell)
            tick(); check(messages == 2 and bell.components.inventoryitem:GetGrandOwner() == p, "carried bell silent")
            bell.components.inventoryitem:RemoveFromOwner(true)
            local pack = spawn("backpack")
            p.components.inventory:Equip(pack)
            check(pack.components.container:GiveItem(bell), "backpack accepts bell")
            tick(); check(messages == 2 and bell.components.inventoryitem:GetGrandOwner() == p, "equipped backpack silent")
            check(cow.components.follower:GetLeader() == p, "native GetLeader resolves holder rather than bell")
            bell.components.inventoryitem:RemoveFromOwner(true)
            local chest = spawn("treasurechest")
            check(chest.components.container:GiveItem(bell), "chest accepts bell")
            check(bell.components.inventoryitem:GetGrandOwner() == chest, "native chest ownership")
            move(chest, 41); tick(); check(messages == 3, "ground chest uses owner position")
            move(chest, 19); tick()
            bell.components.inventoryitem:RemoveFromOwner(true)
            move(bell, 19); tick()
            move(bell, 60)
            local before = messages
            local ticks = 0
            task.fn = function(...) ticks = ticks + 1; return tick(...) end
            later(1.2, function()
                check(messages == before + 1, "actual periodic tick warns: messages=" .. messages .. " before=" .. before ..
                    " riding=" .. tostring(p.components.rider:IsRiding()) .. " distance=" .. p:GetDistanceSqToInst(bell) ..
                    " owner=" .. tostring(bell.components.inventoryitem:GetGrandOwner()) .. " ticks=" .. ticks ..
                    " bound=" .. tostring(bell:GetBeefalo() == cow) .. " leader=" .. tostring(cow.components.follower.leader == bell) ..
                    " task=" .. tostring(timer(p) == task) .. " valid=" .. tostring(bell:IsValid()))
                p.components.rider:ActualDismount()
                check(timer(p) == nil, "actual dismount cancels timer")
                p.components.rider:Mount(cow, true)
                check(messages == before + 2, "remount checks immediately")
                p.components.rider:ActualDismount()
                rows = rows + 1
                emit({kind = "bell_reminder_case", prefab = spec[1], upgraded = spec[2], checks = checks})
                nextcase()
            end)
        end)
    end
    safe(nextcase)
end
