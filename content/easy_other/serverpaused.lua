local UserCommands = require("usercommands")
local VoteUtil = require("voteutil")

AddUserCommand("serverpaused2hm", {
    permission = COMMAND_PERMISSION.USER,
    slah = true,
    usermenu = false,
    servermenu = true,
    menusort = 1,
    params = {},
    paramsoptional = {},
    vote = true,
    votetimeout = 30,
    voteminstartage = 0,
    voteminpasscount = 1,
    votecountvisible = true,
    voteallownotvoted = true,
    voteoptions = nil, --default to { "Yes", "No" }
    votecanstartfn = VoteUtil.DefaultCanStartVote,
    voteresultfn = VoteUtil.YesNoMajorityVote,
    serverfn = function(params, caller)
        print("serverfn")
        --NOTE: must support nil caller for voting
        if caller ~= nil then
            --Wasn't a vote so we should send out an announcement manually
            --NOTE: the vote rollback announcement is customized and still
            --      makes sense even when it wasn't a vote, (run by admin)
            local command = UserCommands.GetCommandFromName("serverpaused2hm")
            TheNet:AnnounceVoteResult(command.hash, nil, true)
        end
        -- TheWorld:DoTaskInTime(5, function(world)
        --     if world.ismastersim then
        --         TheNet:SendWorldRollbackRequestToServer(params.numsaves ~= nil and tonumber(params.numsaves) or nil)
        --     end
        -- end)
        SetServerPaused()
    end,
})