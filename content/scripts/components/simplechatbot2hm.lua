local util = require("simplechatbot2hm_util")

local Simplechatbot2hm = Class(function(self, inst)
    self.inst = inst

    self.roleList = {}

    inst:StartUpdatingComponent(self)
end)

function Simplechatbot2hm:OnRemoveFromEntity()
    self.inst:StopUpdatingComponent(self)
end

function Simplechatbot2hm:OnUpdate(dt)
    for _, rn in pairs(self.roleList) do
        if rn.node then
            rn.node:OnUpdate(dt, rn.data)
            if rn.node:IsEnd(rn.data) then
                self:DoAnnounce(rn.userid, rn.node:ExitWords(rn.data))
                rn.node:Exit(rn.data)
                rn.node = nil
            end
        end
    end
end

function Simplechatbot2hm:DoAnnounce(userid, words)
end

function Simplechatbot2hm:GetWords(userid, words)
    local rn = self.roleList[userid]
    if not rn then
        rn = util.RoleNode(userid)
        self.roleList[userid] = rn
    end
    if not util.globalData.soloUserId then
        if words == STRINGS.NAMES.BOT2HM.ACTIVEWORD then
            if not rn.node then
                rn.node = util.default
                rn.node:Enter(rn.data)
                self:DoAnnounce(userid, rn.node:EnterWords(rn.data))
            end
        elseif words == STRINGS.NAMES.BOT2HM.HELP then
            if rn.node then
                self:DoAnnounce(userid, rn.node:GetAllRoutes())
            end
        else
            if rn.node then
                local nextNode, word = rn.node:GetWords(words, rn.data)
                self:DoAnnounce(userid, word)
                if nextNode then
                    self:DoAnnounce(userid, rn.node:ExitWords(rn.data))
                    rn.node:Exit(rn.data)
                    nextNode:Enter(rn.data)
                    self:DoAnnounce(userid, nextNode:EnterWords(rn.data))
                    rn.node = nextNode
                end
            end
        end
    else
        local soloRN = self.roleList[util.globalData.soloUserId]
        local nextNode, word = soloRN.node:GetWords(words, soloRN.data, rn.data)
        self:DoAnnounce(userid, word)
        if nextNode then
            self:DoAnnounce(userid, soloRN.node:ExitWords(soloRN.data))
            soloRN.node:Exit(soloRN.data)
            nextNode:Enter(soloRN.data)
            self:DoAnnounce(userid, nextNode:EnterWords(soloRN.data))
            soloRN.node = nextNode
        end
    end
end

return Simplechatbot2hm