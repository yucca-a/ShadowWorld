-- Loaded only in the disposable offline server owned by the Python runner.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
local A, s = {}, {checks = 0}
G.VaultAudit = A
local function emit(row) print("[VAUDIT] " .. json.encode(row)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)
local function check(value, message) s.checks = s.checks + 1; assert(value, message) end
local function near(a, b, message) check(math.abs(a - b) < 1e-7, message .. ": " .. tostring(a) .. " / " .. tostring(b)) end
local function hatheals(owner, message)
    local health, calls = owner.components.health, 0
    local old, before = health.DoDelta, health.currenthealth
    health.DoDelta = function(self, amount, ...)
        if amount == 1 then calls = calls + 1 end
        return old(self, amount, ...)
    end
    owner:PushEvent("attacked", {damage = 0})
    health.DoDelta = old
    check(calls == 1 and health.currenthealth > before, message)
end
local function enhance(prefab)
    local item = SpawnPrefab(prefab)
    check(item.ancient_enhance2hm ~= nil, "real enhancement hook: " .. prefab)
    item:AddTag("ancient_enhanced2hm")
    item.ancient_enhance2hm(item)
    return item
end
local function player(uid)
    local p = SpawnPrefab("wilson"); p.userid = uid
    p.components.hunger:SetRate(0)
    p.components.health:SetPercent(.5)
    return p
end
local stages = {}
stages[1] = function()
    TheWorld:PushEvent("ms_setclocksegs", {day = 0, dusk = 0, night = 16})
    s.a, s.b = player("KU_PERF_A"), player("KU_PERF_B")
    s.hat = enhance("ruinshat")
    s.a.components.inventory:Equip(s.hat)
    hatheals(s.a, "equipped hat heals immediately through existing healing multipliers")
    s.hat.ancient_enhance2hm(s.hat)
    hatheals(s.a, "repeat enhancement does not duplicate listener")
    s.a.components.inventory:Unequip(EQUIPSLOTS.HEAD)
    local hp = s.a.components.health.currenthealth;s.a:PushEvent("attacked", {damage = 0})
    near(s.a.components.health.currenthealth, hp, "unequip detaches immediately")
    s.b.components.inventory:Equip(s.hat)
    check(s.hat._ancient_hat_owner == s.b, "hat follows real owner transfer")
    hatheals(s.b, "new wearer heals")
    s.hat:Remove()
    hp = s.b.components.health.currenthealth;s.b:PushEvent("attacked", {damage = 0})
    near(s.b.components.health.currenthealth, hp, "deleted hat leaves no listener")
    s.m = enhance("yellowamulet")
    s.a.components.inventory:GiveItem(s.m)
end
stages[2] = function()
    check(not TheWorld.state.isday, "night configuration took effect")
    check(s.m._ancient_magi_task ~= nil, "held active amulet ticks")
    check(s.m._ancient_magi_light_owner == s.a, "pocket light follows owner")
    check(s.m.components.fueled.consuming, "pocket amulet consumes fuel")
    local speed = s.a.components.playerspeedmult
    check(speed ~= nil, "native speed component exists")
    s.speedsets = 0;s.speedsetter = speed.SetCappedPredictedSpeedMult
    speed.SetCappedPredictedSpeedMult = function(self, key, value)
        if key == "ancient_magi2hm" then s.speedsets = s.speedsets + 1 end
        return s.speedsetter(self, key, value)
    end
    s.sanityticks = 0;s.sanitydelta = s.a.components.sanity.DoDelta
    s.a.components.sanity.DoDelta = function(self, amount, ...)
        if amount == 1 / 60 then s.sanityticks = s.sanityticks + 1 end
        return s.sanitydelta(self, amount, ...)
    end
end
stages[3] = function()
    check(s.sanityticks >= 2, "native half-second sanity recovery retained")
    check(s.speedsets == 0, "stable ownership does not reset speed every tick")
    s.second = enhance("yellowamulet");s.a.components.inventory:GiveItem(s.second)
end
stages[4] = function()
    check(s.a._ancient_magi_sources2hm[s.second], "second amulet registered")
    s.a.components.inventory:DropItem(s.m, true)
end
stages[5] = function()
    check(not s.m._ancient_magi_task, "ground amulet at night has no periodic task")
    check(not s.m._ancient_magi_light, "drop removes pocket light")
    check(s.a._ancient_magi_sources2hm[s.second] and not s.a._ancient_magi_sources2hm[s.m], "other amulet retains speed source")
    s.a.components.inventory:DropItem(s.second, true)
    TheWorld:PushEvent("ms_setclocksegs", {day = 16, dusk = 0, night = 0})
    s.m.components.fueled:SetPercent(.5)
    s.solarfuel = s.m.components.fueled.currentfuel
end
stages[6] = function()
    check(TheWorld.state.isday, "day configuration took effect")
    check(s.m._ancient_magi_task ~= nil, "day starts ground recharge")
    check(s.m.components.fueled.currentfuel > s.solarfuel, "ground fuel actually recharges")
    check(not s.m.components.fueled.consuming, "ground fuel does not burn")
    check(not s.a._ancient_magi_sources2hm, "last pocket amulet removes speed")
    s.m.components.fueled:SetPercent(1)
end
stages[7] = function()
    check(not s.m._ancient_magi_task, "full ground amulet stops ticking")
    s.chest = SpawnPrefab("treasurechest")
    s.chest.components.container:GiveItem(s.m)
    s.m.components.fueled:SetPercent(.5)
    s.chestfuel = s.m.components.fueled.currentfuel
end
stages[8] = function()
    check(s.m.components.fueled.currentfuel > s.chestfuel, "chest recharge retained")
    TheWorld:PushEvent("ms_setclocksegs", {day = 0, dusk = 0, night = 16})
end
stages[9] = function()
    check(not s.m._ancient_magi_task, "night stops idle chest task")
    local item = s.chest.components.container:RemoveItemBySlot(s.chest.components.container:GetItemSlot(s.m))
    s.a.components.inventory:GiveItem(item)
end
stages[10] = function()
    check(s.m._ancient_magi_light_owner == s.a, "taking idle chest amulet activates it")
    s.a.components.inventory:Equip(s.m)
end
stages[11] = function()
    check(not s.m._ancient_magi_task and not s.m._ancient_magi_light, "equipped amulet uses native effects")
    check(s.m.components.fueled.consuming, "native equipped consumption retained")
    local item = s.a.components.inventory:Unequip(EQUIPSLOTS.BODY)
    if not item then item = s.m.components.inventoryitem:RemoveFromOwner(true) end
    s.a.components.inventory:GiveItem(item)
end
stages[12] = function()
    check(s.m._ancient_magi_task and s.m.components.fueled.consuming, "pocket consumption resumes after unequip")
    s.m._ancient_magi_on2hm = false
    s.m:PushEvent("onputininventory", s.a)
    s.bag = SpawnPrefab("backpack")
    s.a.components.inventory:Equip(s.bag)
    check(s.bag.components.inventoryitem.owner == s.a, "native backpack is worn")
    s.m.components.inventoryitem:RemoveFromOwner(true)
    s.bag.components.container:GiveItem(s.m)
end
stages[13] = function()
    check(not s.m._ancient_magi_task, "disabled nested amulet stays idle at night")
    s.m.components.inspectable:GetDescription(s.a) -- Uses the actual toggle wrapper.
end
stages[14] = function()
    check(s.m._ancient_magi_light_owner == s.a, "inspect restarts nested amulet")
    s.a.components.inventory:DropItem(s.bag, true)
end
stages[15] = function()
    check(not s.m._ancient_magi_task and not s.m._ancient_magi_light, "dropping parent backpack stops pocket effects")
    s.m._ancient_magi_on2hm = false
    s.savedamulet = SpawnSaveRecord(s.m:GetSaveRecord())
    s.a.components.inventory:GiveItem(s.savedamulet)
    s.boss = SpawnPrefab("bearger");s.boss.entity:SetCanSleep(false)
    s.rabbit = SpawnPrefab("rabbit")
end
stages[16] = function()
    check(s.savedamulet:HasTag("ancient_enhanced2hm") and s.savedamulet._ancient_magi_on2hm == false, "native save restores enhancement and toggle")
    check(not s.savedamulet._ancient_magi_task, "disabled restored amulet remains idle")
    local armor = s.boss.components.dynamicarmor2hm
    check(armor ~= nil, "native boss has dynamic armor")
    armor:RecordDamage(s.boss.components.health.maxhealth * .1)
    check(not armor.task, "native subthreshold armor has no FX task")
    armor:OnLoad({pressure = .25, cooling = 1})
    check(armor.task and armor.fx, "native visible armor creates FX")
    local saved = armor:OnSave();armor:OnLoad(saved)
    near(armor.pressure, saved.pressure, "native armor save data round trip")
    check(not s.rabbit._epicruinwatching2hm, "native untouched creature has no decay listener")
    s.rabbit.components.health:SetVal(s.rabbit.components.health.currenthealth - 1, "test", s.boss)
    check(s.rabbit._epicruinwatching2hm, "native boss damage starts decay listener")
    local restored = SpawnSaveRecord(s.rabbit:GetSaveRecord())
    s.restored = restored
    check(restored.components.persistent2hm.data.epicruin2hm.totalEpicDamage > 0, "native creature record survives reload")
    local record = s.rabbit.components.persistent2hm.data.epicruin2hm
    record.lastDecayDay = TheWorld.state.cycles - 10
    s.rabbit.components.lootdropper:GenerateLoot()
    check(not s.rabbit._epicruinwatching2hm and record.totalEpicDamage == 0, "native expired record unregisters watcher")
    s.rabbit.components.health:SetVal(s.rabbit.components.health.currenthealth - 1, "test", s.boss)
    check(s.rabbit._epicruinwatching2hm, "later native hit registers again")
    local hat = enhance("ruinshat")
    s.savedhat = SpawnSaveRecord(hat:GetSaveRecord());hat:Remove()
    s.b.components.inventory:Equip(s.savedhat)
    s.m.components.inventoryitem:RemoveFromOwner(true)
    s.a.components.inventory:GiveItem(s.m)
    s.m._ancient_magi_on2hm = true
    s.m.components.fueled:SetPercent(0)
end
stages[17] = function()
    check(s.restored._epicruinwatching2hm, "native loaded record registers after deferred initialization")
    check(s.savedhat._ancient_hat_owner == s.b, "native saved hat restores equipped listener")
    hatheals(s.b, "native saved hat heals only once")
    check(not s.m:IsValid(), "native pocket depletion still removes the amulet")
    check(not s.m._ancient_magi_task and not s.m._ancient_magi_light, "depleted amulet stops effects and task")
    check(not s.a._ancient_magi_sources2hm, "empty amulet removes speed")
    s.m = enhance("yellowamulet")
    s.m._ancient_magi_on2hm = false
    s.a.components.inventory:GiveItem(s.m)
    s.m.components.fueled:SetPercent(.5)
end
stages[18] = function()
    check(not s.m._ancient_magi_task, "disabled pocket amulet remains idle")
    local before = s.m.components.fueled.currentfuel
    check(s.m.components.fueled:TakeFuelItem(SpawnPrefab("nightmarefuel"), s.a), "native refuel action succeeds")
    check(s.m.components.fueled.currentfuel > before, "native refuel adds durability")
    s.m.components.inspectable:GetDescription(s.a)
end
stages[19] = function()
    check(s.m._ancient_magi_task and s.m._ancient_magi_light_owner == s.a, "refueled amulet restarts after inspection")
    check(s.m.components.fueled.consuming, "refueled pocket amulet consumes fuel")
    -- Equip and unequip within one frame, before the coalesced refresh runs.
    s.a.components.inventory:Equip(s.m)
    s.a.components.inventory:GiveItem(s.a.components.inventory:Unequip(EQUIPSLOTS.BODY))
end
stages[20] = function()
    check(s.m.components.fueled.consuming, "same-frame equip and unequip resumes pocket consumption")
    s.removedlight = s.m._ancient_magi_light
    s.m:Remove()
    check(not s.a._ancient_magi_sources2hm, "deleted pocket amulet leaves no speed source")
    check(not s.removedlight:IsValid(), "deleted pocket amulet removes attached light")
    check(not s.m._ancient_magi_task and not s.m._ancient_magi_refresh_task, "deleted amulet cancels owned tasks")
    s.savedamulet:Remove();s.savedhat:Remove();s.second:Remove();s.boss:Remove();s.rabbit:Remove();s.restored:Remove()
    s.bag:Remove();s.chest:Remove();s.a:Remove();s.b:Remove()
end
function A.step(index)
    TheWorld:DoTaskInTime((index == 3 or index == 6 or index == 8) and 1.2 or .3, function()
        local ok, err = xpcall(stages[index], debug.traceback)
        emit({kind = "performance_phase1", phase = index, passed = ok, checks = s.checks, error = not ok and tostring(err) or nil})
    end)
end
