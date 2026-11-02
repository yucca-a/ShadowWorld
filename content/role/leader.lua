TUNING.maxfollowernum2hm = GetModConfigData("leader")

local function calculaterepeatfollowers2hm(self)
    if self.followers2hm == nil then return {} end
    local followers = {}
    local prefabfollowers = {}
    local firstfollower = {}
    for _, follower in ipairs(self.followers2hm) do
        if follower and follower:IsValid() and follower.components.health and follower.components.combat and
            (follower.components.combat.defaultdamage > 0 or follower.weaponitems) and not follower:HasTag("swc2hm") then
            if follower:HasTag("spider") or follower:HasTag("merm") or follower:HasTag("chess") then
                -- 蜘蛛鱼人都计入随从数目
                table.insert(followers, follower)
            else
                local prefab = follower.prefab
                if prefabfollowers[prefab] == nil then
                    -- 唯一单位不会计入随从数目上限
                    firstfollower[prefab] = follower
                    prefabfollowers[prefab] = 1
                elseif prefabfollowers[prefab] == 1 then
                    -- 超过1个则都计入
                    table.insert(followers, firstfollower[prefab])
                    table.insert(followers, follower)
                    prefabfollowers[prefab] = 2
                else
                    table.insert(followers, follower)
                end
            end
        end
    end
    return followers
end
local function checkfollowernum(inst, self)
    self.checkfollowerstask = nil
    if self.numfollowers > TUNING.maxfollowernum2hm and self.followers2hm then
        local followers = self:calculaterepeatfollowers2hm()
        if #followers > TUNING.maxfollowernum2hm then
            local extranum = #followers - TUNING.maxfollowernum2hm
            local i = 0
            for _, follower in ipairs(followers) do
                i = i + 1
                self:RemoveFollower(follower)
                if i >= extranum then break end
            end
        end
    end
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.leader then
        inst.components.leader.followers2hm = {}
        inst.components.leader.calculaterepeatfollowers2hm = calculaterepeatfollowers2hm
        local AddFollower = inst.components.leader.AddFollower
        inst.components.leader.AddFollower = function(self, follower, ...)
            AddFollower(self, follower, ...)
            if self.followers and follower and self.followers[follower] and self.followers2hm and not table.contains(self.followers2hm, follower) then
                table.insert(self.followers2hm, follower)
            end
            if not self.checkfollowerstask then self.checkfollowerstask = self.inst:DoTaskInTime(FRAMES, checkfollowernum, self) end
        end
        local RemoveFollower = inst.components.leader.RemoveFollower
        inst.components.leader.RemoveFollower = function(self, follower, ...)
            if follower ~= nil and self.followers and self.followers[follower] and self.followers2hm then
                for i = #self.followers2hm, 1, -1 do
                    if follower == self.followers2hm[i] then
                        table.remove(self.followers2hm, i)
                        break
                    end
                end
            end
            RemoveFollower(self, follower, ...)
        end
    end
end)
