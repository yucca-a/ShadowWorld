local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end
PLAYER_CAMERA_SEE_DISTANCE = 40
TheWorld = {ismastersim = true}
TUNING = {isCh2hm = true}
local attach
AddPlayerPostInit = function(fn) attach = fn end
assert(loadstring(ReminderSource))()
local function entity(prefab, x)
    local inst = {prefab = prefab, x = x or 0, valid = true, components = {}, listeners = {}, tasks = {}, initial = {}}
    function inst:IsValid() return self.valid end
    function inst:GetDistanceSqToInst(other) return (self.x - other.x)^2 end
    function inst:ListenForEvent(name, fn) self.listeners[name] = fn end
    function inst:PushEvent(name) if self.listeners[name] then self.listeners[name](self) end end
    function inst:DoPeriodicTask(period, fn)
        local task = {period = period, fn = fn, cancelled = false, Cancel = function(self) self.cancelled = true end}
        self.tasks[#self.tasks + 1] = task
        return task
    end
    function inst:DoTaskInTime(_, fn) self.initial[#self.initial + 1] = fn end
    return inst
end
local function own(item, owner)
    item.components.inventoryitem = item.components.inventoryitem or {GetGrandOwner = InventoryItem.GetGrandOwner}
    item.components.inventoryitem.owner = owner
end
local function setup(prefab)
    local player, mount, bell = entity("wilson"), entity("beefalo"), entity(prefab)
    local messages = {}
    local riding = false
    player.components.talker = {Say = function(_, message) messages[#messages + 1] = message end}
    player.components.rider = {IsRiding = function() return riding end, GetMount = function() return mount end}
    mount.components.follower = {leader = bell, itemowner = player}
    -- Native GetLeader() would return itemowner here; the implementation must use the raw bell link.
    mount.components.follower.GetLeader = function(self) return self.itemowner or self.leader end
    bell.GetBeefalo = function() return mount end
    own(bell, nil)
    attach(player)
    local function ride(value)
        riding = value
        player:PushEvent(value and "mounted" or "dismounted")
    end
    local function poll()
        for _, task in ipairs(player.tasks) do if not task.cancelled then task.fn(player) end end
    end
    return player, mount, bell, messages, ride, poll
end
for _, prefab in ipairs({"beef_bell", "shadow_beef_bell"}) do
    local player, mount, bell, messages, ride, poll = setup(prefab)
    check(#player.tasks == 0, "no continuous task while walking")
    ride(true)
    check(#player.tasks == 1 and player.tasks[1].period == 1, "mounted check runs once per second")
    player:PushEvent("mounted")
    check(#player.tasks == 1, "duplicate mount event does not duplicate task")
    player.x = 39.99; poll()
    check(#messages == 0, "inside range is quiet")
    player.x = 40; poll()
    check(#messages == 1 and messages[1]:find("忘带牛铃", 1, true), "40-unit boundary reminds")
    for i = 1, 10 do player.x = 40 + i; poll() end
    check(#messages == 1, "no repeated reminders while away")
    player.x = 39; poll(); player.x = 41; poll()
    check(#messages == 1, "edge oscillation does not spam")
    player.x = 20; poll(); player.x = 40; poll()
    check(#messages == 2, "returning nearby rearms next departure")
    own(bell, player); player.x = 100; poll()
    check(#messages == 2, "carried bell is quiet")
    local pack, box = entity("backpack", -999), entity("treasurechest", -999)
    own(pack, player); own(box, pack); own(bell, box); poll()
    check(#messages == 2, "nested carried container is quiet despite stale item transforms")
    own(box, nil); box.x = 100; poll()
    check(#messages == 2, "nearby ground container uses its own position")
    box.x = 0; poll()
    check(#messages == 3, "bell left in far ground container reminds")
    local other = entity("wendy", 100)
    own(bell, other); poll()
    check(#messages == 3, "nearby carrier rearms without false warning")
    other.x = 0; poll()
    check(#messages == 4, "far other-player carrier is not treated as own inventory")
    ride(false)
    check(player.tasks[1].cancelled, "dismount stops periodic check")
    poll(); check(#messages == 4, "walking does not remind")
    ride(true)
    check(#messages == 5 and #player.tasks == 2, "new ride gets one fresh warning")
    mount.components.follower.leader = nil; poll()
    check(#messages == 5, "unbound animal is quiet")
    mount.components.follower.leader = bell; bell.valid = false; poll()
    check(#messages == 5, "removed bell is quiet")
    bell.valid = true
    bell.GetBeefalo = function() return entity("other_beefalo") end
    poll(); check(#messages == 5, "mismatched bell is ignored")
    bell.GetBeefalo = function() return mount end
    player.components.talker = nil; poll()
    player.components.talker = {Say = function(_, text) messages[#messages + 1] = text end}
    poll(); check(#messages == 6, "missing talker does not consume warning")
    player:PushEvent("onremove")
    check(player.tasks[2].cancelled, "removal cancels reminder task")
end
do
    local player, mount, bell, messages, ride, poll = setup("beef_bell")
    mount.prefab = "warg"; ride(true)
    check(#player.tasks == 0 and #messages == 0, "other mount types are ignored")
end
do
    local player, mount, bell, messages, ride, poll = setup("shadow_beef_bell")
    ride(true); player.x = 100
    TUNING.isCh2hm = false; poll(); TUNING.isCh2hm = true
    check(messages[1]:find("beefalo bell", 1, true), "English reminder")
    player.components.rider.IsRiding = function() return false end
    poll(); check(player.tasks[1].cancelled, "lost riding state stops task without event")
end
do
    TheWorld.ismastersim = false
    local player = entity("wilson")
    attach(player)
    check(next(player.listeners) == nil and #player.initial == 0, "clients do not run reminder tasks")
    TheWorld.ismastersim = true
end
do
    local player, mount, bell, messages, ride = setup("beef_bell")
    -- Simulate restored riding before the deferred initialization callback.
    player.components.rider.IsRiding = function() return true end
    player.x = 100
    player.initial[1]()
    check(#messages == 1 and #player.tasks == 1, "restored riding is monitored")
end
print("Beef bell reminder: " .. checks .. " checks passed")
