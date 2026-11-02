-- 2025.2.24 YeFeng:时钟险境 - 网络层

local Network = {}

local NETVAR_NAME = "clock_peril.schedule"
local DIRTY_EVENT = "clock_peril_schedule_dirty"

function Network.Attach(inst)
    inst._clock_peril_schedule = net_string(inst.GUID, NETVAR_NAME, DIRTY_EVENT)

    if TheWorld.ismastersim then
        inst._clock_peril_schedule:set("")
    else
        inst:ListenForEvent(DIRTY_EVENT, function()
            local encoded = inst._clock_peril_schedule:value()
            TheWorld:PushEvent("clock_peril_schedule_updated", encoded)
        end)
    end
end

function Network.SetSchedule(encoded)
    local net = TheWorld and TheWorld.net
    if net and net._clock_peril_schedule then
        net._clock_peril_schedule:set_local(encoded)
        net._clock_peril_schedule:set(encoded)
    end
end

function Network.GetSchedule()
    local net = TheWorld and TheWorld.net
    if net and net._clock_peril_schedule then
        return net._clock_peril_schedule:value()
    end
    return ""
end

Network.DIRTY_EVENT = DIRTY_EVENT

return Network
