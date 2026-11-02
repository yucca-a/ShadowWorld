local globalData = {}

local NodeBase = Class(function(self, name, route, time)
    self.name = name or "NodeBase"
    self.list = {}
    self.route = {}
    self.dirty = true
    self.time = time or 30
    if route then
        for _, v in pairs(route) do
            self:AddRoute(v[1], v[2])
        end
    end
end)

function NodeBase:Try(data)
    return true
end

function NodeBase:AddRoute(key, node)
    self.route[key] = node
    self.list[#self.list + 1] = key
    self.dirty = true
end

function NodeBase:GetAllRoutes()
    if not self.dirty then
        return self.allRoutes
    end
    self.dirty = false
    local str = {}
    for i, key in pairs(self.list) do
        table.insert(str, string.format("%d: %s", i, STRINGS.NAMES.BOT2HM[string.upper(key)]))
    end
    self.allRoutes = STRINGS.NAMES.BOT2HM.CODECANUSE .. table.concat(str, "|")
    return self.allRoutes
end

function NodeBase:EnterWords(data)
end

function NodeBase:ExitWords(data)
end

function NodeBase:Enter(data)
    data.timer = data.time
end

function NodeBase:OnUpdate(dt, data)
    data.timer = data.timer - dt
end

function NodeBase:IsEnd(data)
    return data.timer <= 0
end

function NodeBase:Exit(data)
end

function NodeBase:TryWord(key, data, data2)
    local rt = self.route[key]
    if rt:Try(data) then
        return rt
    end
end

function NodeBase:GetWords(key, data, data2)
    local rt = self.route[key]
    if rt then
        if type(rt) == "table" then
            return self["TryWord"](self, key, data, data2)
        elseif type(rt) == "string" then
            return self[rt](self, key, data, data2)
        elseif type(rt) == "function" then
            return rt(self, key, data, data2)
        end
    end
end

local ActionNode = Class(NodeBase, function(self, action)
    NodeBase._ctor(self, "ActionNode", nil, 0)
    self.action = action
end)

function ActionNode:Enter(data)
    if self.action then
        self.action()
    end
end

local StartNode = Class(NodeBase, function(self, route)
	NodeBase._ctor(self, "StartNode", route)
end)

function StartNode:EnterWords(data)
    return STRINGS.NAMES.BOT2HM.IMHERE
end

local SoloNode = Class(NodeBase, function(self, name, route)
    NodeBase._ctor(self, name or "SoloNode", route)
end)

function SoloNode:Try(data)
    return self._base:Try(data) and not globalData.soloUserId
end

function SoloNode:Enter(data)
    self._base:Enter(data)
    globalData.soloUserId = data.userid
end

function SoloNode:Exit(data)
    self._base:Exit(data)
    globalData.soloUserId = nil
end

local VoteNode = Class(SoloNode, function(self, name, route, agreeRate, agreeNode)
    SoloNode._ctor(self, name or "VoteNode", route)
    self.time = 120
    self:AddRoute("vote_agree", "Vote")
    self:AddRoute("vote_negative", "Vote")
    self.agreeRate = agreeRate
    self.agreeNode = agreeNode
end)

function VoteNode:Enter(data)
    self._base:Enter(data)
    globalData.voteList = {}
    globalData.voteCount = {}
    globalData.voteCount.rateNum = 0
    globalData.voteCount.agree_count = 0
    globalData.voteCount.negative_count = 0
    self:Vote("vote_agree", data, data)
end

function VoteNode:Exit(data)
    self._base:Exit(data)
    globalData.voteList = nil
    globalData.voteCount = nil
end

function VoteNode:EnterWords(data)
    return self:GetVoteStr()
end

function VoteNode:ExitWords(data)
    if globalData.voteCount.agree_count > globalData.voteCount.rateNum then
        return STRINGS.NAMES.BOT2HM.VOTE_PASSED
    else
        return STRINGS.NAMES.BOT2HM.VOTE_FAILED
    end
end

function VoteNode:GetVoteStr()
    return subfmt(STRINGS.NAMES.BOT2HM.VOTE_TXT, {
        agree = globalData.voteCount.agree_count,
        total = #AllPlayers
    })
end

function VoteNode:CheckVote()
    local rateNum = math.floor(#AllPlayers * self.agreeRate)
    local agree_count, negative_count = 0, 0
    for _, ent in pairs(AllPlayers) do
        if globalData.voteList[ent.userid] == "vote_agree" then
            agree_count = agree_count + 1
        elseif globalData.voteList[ent.userid] == "vote_negative" then
            negative_count = negative_count + 1
        end
    end
    globalData.voteCount.rateNum = rateNum
    globalData.voteCount.agree_count = agree_count
    globalData.voteCount.negative_count = negative_count
end

function VoteNode:GetVoteResult(data)
    if globalData.voteCount.agree_count > globalData.voteCount.rateNum then
        return self.agreeNode
    else
        if globalData.voteCount.rateNum - globalData.voteCount.negative_count <= globalData.voteCount.rateNum then
            data.timer = 0
        end
    end
end

function VoteNode:Vote(key, data, data2)
    if not globalData.voteList[data2.userid] then
        globalData.voteList[data2.userid] = key
        self:CheckVote()
        return self:GetVoteResult(data), self:GetVoteStr()
    end
end

local PauseNode = Class(VoteNode, function(self)
    VoteNode._ctor(self, "PauseNode", nil, 0.5, ActionNode(function() TheNet:SetServerPaused(true) end))
end)

function PauseNode:Try(data)
    return self._base:Try(data) and not TheNet:IsServerPaused()
end

local ResumeNode = Class(VoteNode, function(self)
    VoteNode._ctor(self, "ResumeNode", nil, 0.5, ActionNode(function() TheNet:SetServerPaused(false) end))
end)

function PauseNode:Try(data)
    return self._base:Try(data) and TheNet:IsServerPaused()
end

local default = StartNode({
    {"try_pause", PauseNode()},
    {"try_resume", ResumeNode()},
})

local RoleNode = Class(function(self, usedid)
    self.userid = usedid
    self.data = {usedid = usedid}
    self.node = nil
end)

return {
    globalData = globalData,
    default = default,
    RoleNode = RoleNode,
}