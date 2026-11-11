-- 2025.2.24 YeFeng:时钟险境
local select_clock_peril = GetModConfigData("clock_peril")
local MODE_MAP = {[1] = "shuffle", [2] = "fragment"}
local MODE = MODE_MAP[select_clock_peril] or "shuffle"

local dusk_change = GetModConfigData("dusk_change") -- 2026.2.27 YeFeng:漫漫长夜兼容

-- 原生 sleepingbaguser 的 WakeUpTest 比较 phase 与 GetSleepPhase()。
-- 险境会反复进入黄昏；夜间床铺在黄昏和夜晚都可继续睡，白天仍按原规则唤醒。
-- phase 比 isday 更早更新，因此沿用实际 phase，避免读取切换过程中的旧布尔值。
AddComponentPostInit("sleepingbag", function(self)
    local GetSleepPhase = self.GetSleepPhase
    self.GetSleepPhase = function(self, ...)
        local phase = GetSleepPhase(self, ...)
        if phase == "night" and TheWorld.state.phase == "dusk" then return "dusk" end
        return phase
    end
end)

local Network = require("clock_peril/network")
local Server = require("clock_peril/server")
local Client = require("clock_peril/client")

local ClockPeril = {
    MODE = MODE,
    MOD_NAME = "Clock Peril",
    DUSK_CHANGE = dusk_change, -- 2026.2.27 YeFeng:漫漫长夜兼容
}

function ClockPeril.Log(...)
    print("[Clock Peril 2hm]", ...)
end

ClockPeril.Network = Network
ClockPeril.Server = Server

ClockPeril.Log("Loaded, mode:", MODE)

GLOBAL.CLOCK_PERIL = ClockPeril

-- 分片同步
AddShardModRPCHandler("clock_peril", "sync_schedule", function(shard_id, payload)
    if TheShard:IsMaster() then return end
    if not TheWorld.ismastersim then return end

    ClockPeril.Log("Received schedule sync from master")

    if type(payload) ~= "string" then return end

    local encoded, seg_str = payload:match("^(.+)|(%d+)$")
    if not encoded or #encoded ~= 16 then
        if #payload == 16 then
            encoded = payload
            seg_str = "0"
        else
            return
        end
    end

    local success = Server.ApplyExistingSchedule(encoded)
    if success then
        local seg = tonumber(seg_str) or 0
        Server.SyncTimeProgress(seg)
    end
end)

function ClockPeril.BroadcastScheduleToShards(encoded)
    if not TheShard:IsMaster() then return end
    local seg = Server.GetTimeProgress()
    local payload = encoded .. "|" .. tostring(seg)
    SendModRPCToShard(SHARD_MOD_RPC["clock_peril"]["sync_schedule"], payload)
end

local function OnWorldNetworkPostInit(inst)
    Network.Attach(inst)

    if TheWorld.ismastersim then
        if TheShard:IsMaster() then
            Server.Init()
        else
            Server.InitSlave()
        end
    end
end

AddPrefabPostInit("forest_network", OnWorldNetworkPostInit)
AddPrefabPostInit("cave_network", OnWorldNetworkPostInit)

AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end

    local _orig_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        if _orig_OnSave then _orig_OnSave(inst, data) end
        local save_data = Server.OnSave()
        if save_data then
            data.clock_peril = save_data
        end
    end

    local _orig_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if _orig_OnLoad then _orig_OnLoad(inst, data) end
        if data and data.clock_peril then
            Server.OnLoad(data.clock_peril)
        end
    end
end)

AddClassPostConstruct("widgets/uiclock", Client.HookUIClock)
