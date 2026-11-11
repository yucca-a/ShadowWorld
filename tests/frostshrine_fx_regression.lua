local checks, now, created, dedicated = 0, 0, 0, false
local function check(value, message) checks = checks + 1; assert(value, message) end
FRAMES = 1 / 30
GetTime = function() return now end
TheNet = { IsDedicated = function() return dedicated end }
TheWorld = { ismastersim = false }
local function Fake()
    local inst = { GUID = 1, events = {}, tasks = {}, asleep = false }
    inst.AnimState = setmetatable({}, { __index = function(_, name)
        return function(self, ...) self[name .. "_args"] = {...} end
    end })
    inst.Follower = { FollowSymbol = function(self, ...) self.args = {...} end }
    inst.entity = {
        AddTransform = function() end, AddAnimState = function() end,
        AddFollower = function() end, SetParent = function() end,
    }
    function inst:AddTag() end
    function inst:IsAsleep() return self.asleep end
    function inst:Remove() self.removed = true; self:PushEvent("onremove") end
    function inst:ListenForEvent(name, fn) self.events[name] = fn end
    function inst:PushEvent(name) if self.events[name] then self.events[name](self) end end
    function inst:DoPeriodicTask(period, fn)
        local task = { fn = fn, Cancel = function(t) t.cancelled = true end }
        self.tasks[#self.tasks + 1] = task
        return task
    end
    function inst:DoTaskInTime(delay, fn)
        local task = self:DoPeriodicTask(delay, fn); task.once = true; return task
    end
    function inst:Tick(seconds)
        local frames = math.ceil(seconds / FRAMES)
        for _ = 1, frames do
            now = now + FRAMES
            local tasks = {}; for _, task in ipairs(self.tasks) do tasks[#tasks + 1] = task end
            for _, task in ipairs(tasks) do
                if not task.cancelled then
                    task.fn(self)
                    if task.once then task.cancelled = true end
                end
            end
        end
    end
    return inst
end
CreateEntity = function() created = created + 1; return Fake() end
net_bool = function()
    local value = false
    return { value = function() return value end, set = function(_, v) value = v end }
end
net_event = function() return { count = 0, push = function(self) self.count = self.count + 1 end } end
local fx = assert(loadstring(fx_source))()

local client = Fake(); fx.Init(client); client:Tick(.1)
check(created == 0 and client._frostvisualtask == nil, "dormant client does not allocate FX/update task")
client._frostawake:set(true); client:PushEvent("frostshrineawakedirty"); client:Tick(.5)
check(created == 2 and #client._frosteyes == 2, "replicated awake state creates exactly two flames")
check(client._frosteyes[1].Follower.args[2] == "body", "flames follow animated body symbol")
check(client._frosteyes[1].Follower.args[3] < 0 and client._frosteyes[2].Follower.args[3] > 0, "eyes occupy opposite sockets")
check(client._frosteyes[1].AnimState.SetLightOverride_args[1] == 1, "flames stay visible at night")
client:PushEvent("frostshrineawakedirty"); client:PushEvent("frostshrineawakedirty")
check(created == 2, "duplicate dirty events do not duplicate eye entities")
client:PushEvent("frostshrinepulse"); client:Tick(.3)
check(client.AnimState.SetAddColour_args[3] > 0, "use event produces a brief cool flash")
client._frostawake:set(false); client:PushEvent("frostshrineawakedirty"); client:Tick(1.3)
check(client._frosteyes == nil and client._frostvisualtask == nil, "leaving during use finishes pulse then cleans up")
check(client.AnimState.SetAddColour_args[3] == 0, "use flash cannot leave a permanent tint")

client._frostawake:set(true); client:PushEvent("frostshrineawakedirty"); client:Tick(.2)
local eyes = client._frosteyes
client.asleep = true; client.OnEntitySleep(client)
check(eyes[1].removed and eyes[2].removed and client._frostvisualtask == nil, "sleep removes local FX and stops updates")
client.asleep = false; client.OnEntityWake(client); client:Tick(.5)
check(client._frosteyes ~= nil, "streaming back in restores active eyes")
client:Remove()
check(client._frosteyes == nil and client._frostvisualtask == nil, "removal releases all local effects")

local late = Fake(); fx.Init(late); late._frostawake:set(true); late:Tick(.5)
check(late._frosteyes ~= nil, "late join restores awake state even before first dirty event")
late:Remove()

TheWorld.ismastersim = true
local host = Fake(); fx.Init(host); fx.SetActive(host, true); fx.Pulse(host); host:Tick(.3)
check(host._frosteyes ~= nil and host._frostpulse.count == 1, "listen host sees local FX and sends one pulse")
check(host.events.frostshrinepulse == nil, "host does not replay its own network pulse")
host:Remove()

dedicated = true
local before = created
local server = Fake(); fx.Init(server); fx.SetActive(server, true); fx.Pulse(server)
check(server._frostawake:value() and server._frostpulse.count == 1, "dedicated server synchronizes state and use")
check(created == before and #server.tasks == 0, "dedicated server allocates no cosmetic entities or frame tasks")
print("Frost shrine FX lifecycle checks:", checks)
