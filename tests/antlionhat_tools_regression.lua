local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
EQUIPSLOTS = {HANDS = "hands"}
TheWorld = {ismastersim = true, has_ocean = true}
TUNING = {MARBLEPILLAR_MINE = 10}
GetTime = function() return 1 end
ShouldItemMimicBeRevealedFor = function() return false end
ACTIONS = {MINE = {id = "MINE"}, CHOP = {id = "CHOP"}}
ACTIONS.MINE.fn = function(act) return NativeToolWork(act, ACTIONS.MINE) end

local function entity(prefab)
    return {prefab = prefab, components = {}, replica = {}, tags = {}, valid = true,
        IsValid = function(self) return self.valid end,
        HasTag = function(self, tag) return self.tags[tag] == true end,
        AddTag = function(self, tag) self.tags[tag] = true end,
        RemoveTag = function(self, tag) self.tags[tag] = nil end,
        PushEvent = function() end, ListenForEvent = function() end,
        GetBufferedAction = EntityScript.GetBufferedAction}
end
local worker, other = entity("wilson"), entity("wilson")
worker:AddTag("player")
other:AddTag("player")
local hand = entity("cane")
local inventory = {GetEquippedItem = function() return hand end}
worker.components.inventory = inventory
local getter = inventory.GetEquippedItem
local prior = {action = ACTIONS.CHOP}
local target, tool = entity("target"), entity("tool")
local seen, uses = 0, 0
tool.OnUsedAsItem = function(self, action, owner, ent)
    uses = uses + 1
    check(owner:GetBufferedAction().invobject == self and ent == target, "native durability sees actual action")
end
local action = {fn = function(act)
    seen = seen + 1
    check(worker:GetBufferedAction() == act, "native action getter sees hat action")
    check(inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == hand, "real hand unchanged")
    check(inventory.GetEquippedItem == getter, "getter unchanged")
    check(other:GetBufferedAction() == nil, "other players unchanged")
    return true, "reason"
end}
worker.bufferedaction = prior
local act = BufferedAction(worker, target, action, tool)
local succeeded = 0
act:AddSuccessAction(function()
    succeeded = succeeded + 1
    check(worker:GetBufferedAction() == act, "success callback has actual action")
end)
local ok, reason = HatDo(act)
check(ok and reason == "reason" and act.reason == reason, "native results preserved")
check(seen == 1 and uses == 1 and succeeded == 1, "native execution and consumption once")
check(worker.bufferedaction == prior, "pending player action restored")
worker.bufferedaction = nil
worker.components.locomotor = {bufferedaction = prior}
HatDo(BufferedAction(worker, target, action, tool))
check(worker.bufferedaction == nil and worker:GetBufferedAction() == prior, "locomotor queue preserved")
worker.components.locomotor = nil
local failact = BufferedAction(worker, target, {fn = function() return false, "FAIL" end}, tool)
ok, reason = HatDo(failact)
check(not ok and reason == "FAIL" and uses == 2, "failed action retains native reason and uses")
check(worker.bufferedaction == nil, "failure restores nil")
target.valid = false
check(not HatDo(BufferedAction(worker, target, action, tool)), "native validation unchanged")
check(worker.bufferedaction == nil, "invalid action cleans up")
target.valid = true
local token = {}
local inner = {fn = function(act)
    check(worker:GetBufferedAction() == act, "nested action exposed")
    error(token)
end}
local outer = {fn = function(act)
    local nestedok, err = pcall(HatDo, BufferedAction(worker, target, inner, tool))
    check(not nestedok and err == token, "nested error propagated")
    check(worker:GetBufferedAction() == act, "nested error restores parent")
    error(token)
end}
worker.bufferedaction = prior
ok, reason = pcall(HatDo, BufferedAction(worker, target, outer, tool))
check(not ok and reason == token and worker.bufferedaction == prior, "error restores pending action")
for _, replacement in ipairs({false, {action = ACTIONS.CHOP}}) do
    local replace = {fn = function() worker.bufferedaction = replacement or nil; return false end}
    HatDo(BufferedAction(worker, target, replace, tool))
    check(worker.bufferedaction == (replacement or nil), "callback cancellation or replacement respected")
end
worker.bufferedaction = nil

-- Existing batch-till flag applies to every wrapped farmtiller, preserving prior values.
ACTIONS.TILL = {id = "TILL"}
local tilltool = entity("pickaxe_lunarplant")
tilltool.components.farmtiller = {oldAction2hm = function() end}
for _, originalflag in ipairs({"nil", false, true}) do
    if originalflag == "nil" then tilltool.oldtill2hm = nil else tilltool.oldtill2hm = originalflag end
    local original = tilltool.oldtill2hm
    local till = {doer = worker, action = ACTIONS.TILL, invobject = tilltool, Do = function()
        check(tilltool.oldtill2hm == true, "head uses existing single-till flag")
        return true
    end}
    check(HatDo(till), "till action returns normally")
    check(tilltool.oldtill2hm == original, "prior till flag restored")
    till.Do = function() error(token) end
    local success, err = pcall(HatDo, till)
    check(not success and err == token and tilltool.oldtill2hm == original, "error restores prior till flag")
end
tilltool.oldtill2hm = nil

-- Run the real statue patch through native BufferedAction -> DoToolWork -> Workable.
local prefabs, counts = {}, {}
AddPrefabPostInit = function(name, fn) prefabs[name] = fn end
DoRandomRuinMagic2hm = function() counts.magic = counts.magic + 1 end
SpawnMonster2hm = function() counts.monster = counts.monster + 1 end
SpawnSpell2hm = function() counts.gem = counts.gem + 1 end
StalkerSpawnSnares2hm = function() counts.gem = counts.gem + 1 end
CreateMiasma2hm = function() counts.gem = counts.gem + 1 end
SpawnPrefab = function()
    counts.gem = counts.gem + 1
    return {Transform = {SetPosition = function() end}, PushEvent = function() end}
end
assert(loadstring(StatueSource))()
local function upvalue(fn, wanted)
    for i = 1, 20 do
        local name, value = debug.getupvalue(fn, i)
        if name == nil then break end
        if name == wanted then return value end
    end
end
local enhanced = entity("multitool_axe_pickaxe")
enhanced:AddTag("ancient_enhanced2hm")
local plain = entity("multitool_axe_pickaxe")
for _, item in ipairs({enhanced, plain}) do
    item.components.tool = {GetEffectiveness = function() return item == enhanced and 40/3 or 4/3 end,
        CanDoToughWork = function() return true end}
    item.components.equippable = {IsRestricted = function() return false end}
    item.OnUsedAsItem = function(self) self.uses = (self.uses or 0) + 1 end
end
worker.Transform = {GetWorldPosition = function() return 0, 0, 0 end}
local probe = entity("ruins_statue_head")
probe.components.workable = NativeWorkable(probe)
probe.components.workable.onwork = function() end
probe.components.workable.onfinish = function() end
probe.components.timer = {TimerExists = function() return true end}
prefabs[probe.prefab](probe)
local isenhanced = assert(upvalue(probe.components.workable.onwork, "isancientenhancedaxe"))
hand = enhanced
check(isenhanced(probe, worker), "legacy direct work falls back to equipped tool")
for _, pending in ipairs({
    {target = entity("elsewhere"), action = ACTIONS.MINE, invobject = enhanced},
    {target = probe, action = ACTIONS.CHOP, invobject = enhanced},
    {target = probe, action = ACTIONS.MINE},
    {target = probe, action = ACTIONS.MINE, invobject = plain},
}) do
    worker.bufferedaction = pending
    check(not isenhanced(probe, worker), "unrelated or tool-less action cannot borrow hand immunity")
end
worker.bufferedaction = {target = probe, action = ACTIONS.MINE, invobject = enhanced}
enhanced.valid = false
check(not isenhanced(probe, worker), "removed tool cannot grant immunity")
enhanced.valid = true
worker.bufferedaction = nil
local statues = {"ruins_statue_head", "ruins_statue_head_nogem", "ruins_statue_mage", "ruins_statue_mage_nogem"}
for _, name in ipairs(statues) do
    for _, gem in ipairs({false, "redgem", "bluegem", "orangegem", "purplegem", "yellowgem", "greengem"}) do
        for _, mode in ipairs({"hat_enhanced", "manual_enhanced", "hat_plain_held_enhanced", "hat_plain"}) do
            local statue = entity(name)
            statue.gemmed = gem or nil
            statue.components.timer = {TimerExists = function() return false end, StartTimer = function() end}
            local workable = NativeWorkable(statue)
            statue.components.workable = workable
            workable:SetWorkAction(ACTIONS.MINE)
            workable:SetWorkLeft(2)
            workable.onwork = function() end
            local finished = 0
            workable.onfinish = function() finished = finished + 1 end
            prefabs[name](statue)
            counts = {magic = 0, monster = 0, gem = 0}
            local actual = (mode == "hat_plain" or mode == "hat_plain_held_enhanced") and plain or enhanced
            hand = mode == "hat_plain_held_enhanced" and enhanced or (mode == "manual_enhanced" and enhanced or nil)
            local savedhand, savedgetter = hand, inventory.GetEquippedItem
            local before = actual.uses or 0
            local oldrandom = math.random
            math.random = function() return 0 end -- Force every probabilistic punishment.
            local success, err = pcall(function()
                for i = 1, 10 do
                    if not workable:CanBeWorked() then break end
                    local a = BufferedAction(worker, statue, ACTIONS.MINE, actual)
                    if mode == "manual_enhanced" then
                        worker.bufferedaction = a
                        check(a:Do(), "manual native mine succeeds")
                        worker.bufferedaction = nil
                    else
                        check(HatDo(a), "hat native mine succeeds")
                    end
                end
            end)
            math.random = oldrandom
            assert(success, err)
            check(finished == 1, "all four statue variants finish once")
            local immune = actual == enhanced
            check(immune and counts.monster == 0 and counts.magic == 0 or
                not immune and counts.monster > 0 and counts.magic > 0, "actual tool controls immunity")
            check(gem and counts.gem > 0 or not gem and counts.gem == 0, "gem traps unchanged")
            check((actual.uses or 0) - before == (immune and 2 or 3), "efficiency and per-action consumption unchanged")
            check(hand == savedhand and inventory.GetEquippedItem == savedgetter and worker.bufferedaction == nil,
                "equipment query and pending action unchanged")
        end
    end
end
print("Antlion hat tool actions: " .. checks .. " checks passed")
