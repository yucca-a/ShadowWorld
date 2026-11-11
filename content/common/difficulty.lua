-- /nd is evaluated on the player's shard and returned only to that user.
local Rating = require("difficultyrating2hm")
local function ReadOptions()
    local info = KnownModIndex:GetModInfo(modname)
    if info and info.configuration_options then return info.configuration_options end
    return KnownModIndex:GetModConfigurationOptions_Internal(modname, false)
end
local function Report(player)
    if not TheWorld or not TheWorld.ismastersim or not player or not player:IsValid() or not player.userid then return end
    local now = GetTime()
    if player._difficultyquery2hm and now - player._difficultyquery2hm < 1 then return end
    player._difficultyquery2hm = now
    local result = Rating.Evaluate(GetModConfigData, ReadOptions(), {um = TUNING.DSTU})
    SendModRPCToClient(GetClientModRPC(modname, "difficulty_result"), player.userid,
        result and result.level or nil, result and result.raised or 0,
        result and result.lowered or 0, result and result.disabled or 0, result and result.net or 0)
end
AddModRPCHandler(modname, "difficulty_query", Report)
AddClientModRPCHandler(modname, "difficulty_result", function(level, raised, lowered, disabled, net)
    local result = level and {level = level, raised = raised, lowered = lowered, disabled = disabled, net = net} or nil
    if ChatHistory then ChatHistory:SendCommandResponse(Rating.Format(result, TUNING.isCh2hm)) end
end)
AddUserCommand("nd", {
    prettyname = TUNING.isCh2hm and "查询淬炼难度" or "Tempering difficulty",
    desc = TUNING.isCh2hm and "查询当前难度评定，仅自己可见" or "Privately check the current difficulty rating",
    permission = COMMAND_PERMISSION.USER,
    slash = true, usermenu = false, servermenu = false, vote = false,
    params = {},
    serverfn = function(params, caller) Report(caller) end,
})
if not TheNet:IsDedicated() then
    AddClassPostConstruct("screens/consolescreen", function(screen)
        Rating.InstallConsole(screen, function()
            SendModRPCToServer(GetModRPC(modname, "difficulty_query"))
        end)
    end)
end
