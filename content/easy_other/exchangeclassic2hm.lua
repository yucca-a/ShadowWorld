-- Original Workshop 2886753796, v2.8.14.112: native container exchange protocol.
-- Original authors and license are retained in ARCHIVE_SOURCE.txt / LICENSE.
-- 末影箱穿越
local function exchangedestroydata(inst)
    if inst.components.container then
        local container = inst.components.container
        for i = 1, container.numslots do
            local item = container.slots[i]
            if item ~= nil and item:IsValid() then item:PushEvent("player_despawn") end
        end
        container:DestroyContents()
    end
end
local function exchangesenddata(inst, rpcname, world_id, name, confirm)
    if inst.components.container and world_id and name then
        local rpc = GetShardModRPC("MOD_HARDMODE", rpcname)
        if confirm then
            SendModRPCToShard(rpc, nil, world_id, name)
        else
            local containerdata = inst.components.container:OnSave()
            containerdata.time2hm = os.time()
            inst.exchangetmpdata2hm = containerdata
            exchangedestroydata(inst)
            SendModRPCToShard(rpc, nil, world_id, name, DataDumper(containerdata, nil, true))
        end
    end
end
local function exchangeapplydata(inst, containerdata)
    if inst.components.container and type(containerdata)=="table" then
        exchangedestroydata(inst)
        inst.components.container:OnLoad(containerdata)
    end
end
local function exchangetaskend(inst)
    if inst:HasTag("exchangeloading2hm") then inst:RemoveTag("exchangeloading2hm") end
    if inst.containersendtask2hm then inst.containersendtask2hm = nil end
    if inst.containerreceivetask2hm then inst.containerreceivetask2hm = nil end
    if inst.exchangeconfirmtask2hm then inst.exchangeconfirmtask2hm = nil end
    if inst.sendcontainerproxyplayer2hm then
        local player = inst.sendcontainerproxyplayer2hm
        if player and player:IsValid() and player.components.talker then
            player.components.talker:Say((TUNING.isCh2hm and ("穿越世界超时中止(可暂停穿越=25秒)") or
                ("Exchange timeout invalid~(Pause game then exchange wait 25s)")))
        end
        inst.sendcontainerproxyplayer2hm = nil
    end
    if inst.sendcontainerproxydata2hm then inst.sendcontainerproxydata2hm = nil end
    if inst.exchangetmpdata2hm then
        exchangeapplydata(inst, inst.exchangetmpdata2hm)
        inst.exchangetmpdata2hm = nil
    end
end
-- 另一世界的确认请求被确认
AddShardModRPCHandler("MOD_HARDMODE", "exchangeconfirm2hm", function(shard_id, world_id, name)
    local variants=TheWorld and TheWorld.components.exchangevariants2hm
    if TUNING.EXCHANGE_MODE2HM == "classic" and (not variants or variants.ready) and type(name)=="string" and TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) and tostring(TheShard:GetShardId()) == tostring(world_id) then
        local container = TheWorld:GetPocketDimensionContainer(name)
        if container and container:IsValid() and container.components.container and container.exchangetmpdata2hm and not container.containersendtask2hm and
            not container.exchangeconfirmtask2hm and container.containerreceivetask2hm and container.sendcontainerproxydata2hm then
            container.exchangetmpdata2hm = nil
            container.containerreceivetask2hm:Cancel()
            container.containerreceivetask2hm = nil
            exchangeapplydata(container, container.sendcontainerproxydata2hm)
            container.sendcontainerproxydata2hm = nil
            if container:HasTag("exchangeloading2hm") then container:RemoveTag("exchangeloading2hm") end
        end
    end
end)
-- 所在世界的穿越请求被确认,更新数据,且确认对方的确认请求
AddShardModRPCHandler("MOD_HARDMODE", "exchangeconfirmdata2hm", function(shard_id, world_id, name, containerdata)
    local variants=TheWorld and TheWorld.components.exchangevariants2hm
    if TUNING.EXCHANGE_MODE2HM == "classic" and (not variants or variants.ready) and type(name)=="string" and TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) and tostring(TheShard:GetShardId()) == tostring(world_id) then
        if TheNet:IsServerPaused() then
            TheNet:SetServerPaused(false) 
            TheNet:Announce(TUNING.isCh2hm and "服务器已停止暂停" or "The server has stopped pausing") 
        end
        local container = TheWorld:GetPocketDimensionContainer(name)
        if container and container.cancelpausetask2hm then
            container.cancelpausetask2hm:Cancel()
            container.cancelpausetask2hm = nil
        end
        if container and container:IsValid() and container.components.container and container.exchangetmpdata2hm and container.containersendtask2hm and
            not container.containerreceivetask2hm and not container.exchangeconfirmtask2hm and container.sendcontainerproxyplayer2hm and type(containerdata)=="string" then
            local success, data = RunInSandboxSafe(containerdata)
            if success and type(data)=="table" and require("rpcguard2hm").IsFinite(data.time2hm) and os.time() - data.time2hm < 400 then
                container:DoStaticTaskInTime(FRAMES * 1.5, exchangesenddata, "exchangeconfirm2hm", shard_id, name, true)
                container.exchangetmpdata2hm = nil
                container.containersendtask2hm:Cancel()
                container.containersendtask2hm = nil
                container.exchangeconfirmtask2hm = container:DoTaskInTime(0.25, exchangetaskend)
                exchangeapplydata(container, data)
                local player = container.sendcontainerproxyplayer2hm
                if player and player:IsValid() and player.components.talker then
                    player.components.talker:Say((TUNING.isCh2hm and ("成功穿越世界" .. shard_id .. "啦") or
                        ("SUCCESS to exchange with world " .. shard_id .. "~")))
                end
                container.sendcontainerproxyplayer2hm = nil
            end
        end
    end
end)
-- 另一世界收到穿越请求,确认请求
AddShardModRPCHandler("MOD_HARDMODE", "exchangesenddata2hm", function(shard_id, world_id, name, containerdata)
    local variants=TheWorld and TheWorld.components.exchangevariants2hm
    if TUNING.EXCHANGE_MODE2HM == "classic" and (not variants or variants.ready) and type(name)=="string" and TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) and tostring(TheShard:GetShardId()) == tostring(world_id) then
        local container = TheWorld:GetPocketDimensionContainer(name)
        if container and container:IsValid() and container.components.container and container.virtchest == nil and not container.containersendtask2hm and
            not container.containerreceivetask2hm and not container.exchangeconfirmtask2hm and type(containerdata)=="string" then
            local success, data = RunInSandboxSafe(containerdata)
            if success and type(data)=="table" and require("rpcguard2hm").IsFinite(data.time2hm) and os.time() - data.time2hm < 350 then
                if not container:HasTag("exchangeloading2hm") then container:AddTag("exchangeloading2hm") end
                container.containerreceivetask2hm = container:DoTaskInTime(3, exchangetaskend)
                container.sendcontainerproxydata2hm = data
                container:DoStaticTaskInTime(FRAMES * 1.5, exchangesenddata, "exchangeconfirmdata2hm", shard_id, name)
            end
        end
    end
end)
local function findcontainerproxyname(inst)
    if TheWorld.PocketDimensionContainers then
        for name, container in pairs(TheWorld.PocketDimensionContainers) do if container == inst then return name end end
    end
end
local function findanotherworldid(inst)
    if ShardList then
        local shardids = {}
        for world_id, v in pairs(ShardList) do
            if TheShard and world_id ~= TheShard:GetShardId() and Shard_IsWorldAvailable(world_id) then
                table.insert(
                    shardids, world_id)
            end
        end
        local total = #shardids
        if total == 1 then
            return shardids[1]
        elseif total > 1 then
            inst.lastexchangeidx2hm = (inst.lastexchangeidx2hm or 0) + 1
            if inst.lastexchangeidx2hm > total then inst.lastexchangeidx2hm = 1 end
            return shardids[inst.lastexchangeidx2hm]
        end
    end
end
-- 所在世界进行穿越请求
local function exchangefn(player, inst)
    if TheWorld.ismastersim and inst.components.container and not inst.containersendtask2hm and not inst.containerreceivetask2hm and
        not inst.exchangeconfirmtask2hm and inst.virtchest == nil and player then
        local name = findcontainerproxyname(inst)
        local world_id = findanotherworldid(inst)
        -- SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_prototyper_update"), nil, true)
        if world_id and name then
            inst.sendcontainerproxyplayer2hm = player
            inst.containersendtask2hm = inst:DoTaskInTime(1.5, exchangetaskend)
            if not inst:HasTag("exchangeloading2hm") then inst:AddTag("exchangeloading2hm") end
            exchangesenddata(inst, "exchangesenddata2hm", world_id, name)
        elseif player and player:IsValid() and player.components.talker then
            player.components.talker:Say((TUNING.isCh2hm and "找不到世界和容器穿越哎" or "Can't find another world's container to exchange."))
        end
    end
end

TUNING.util2hm.ClassicExchange2hm = exchangefn
