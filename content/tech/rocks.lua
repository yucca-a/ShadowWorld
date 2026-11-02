local rocks_change = GetModConfigData("rocks_change")
if rocks_change == true then rocks_change = 2 end
local changeIndex = rocks_change <= 0 and 2 or rocks_change
local SourceModifierList = require("util/sourcemodifierlist")

-- TUNING.MARBLESHRUB_MINE_SMALL = TUNING.MARBLESHRUB_MINE_SMALL * changeIndex -- why are you even mining at this stage?
-- TUNING.MARBLESHRUB_MINE_NORMAL = TUNING.MARBLESHRUB_MINE_NORMAL * changeIndex -- same as MARBLETREE_MINE
-- TUNING.MARBLESHRUB_MINE_TALL = TUNING.MARBLESHRUB_MINE_TALL * changeIndex -- same as MARBLEPILLAR_MINE
-- TUNING.ICE_MINE = TUNING.ICE_MINE * changeIndex
-- TUNING.ROCKS_MINE = TUNING.ROCKS_MINE * changeIndex
-- TUNING.ROCKS_MINE_MED = TUNING.ROCKS_MINE_MED * changeIndex
-- TUNING.ROCKS_MINE_LOW = TUNING.ROCKS_MINE_LOW * changeIndex
-- TUNING.SPILAGMITE_SPAWNER = TUNING.SPILAGMITE_SPAWNER * changeIndex
-- TUNING.SPILAGMITE_ROCK = TUNING.SPILAGMITE_ROCK * changeIndex
-- TUNING.MARBLEPILLAR_MINE = TUNING.MARBLEPILLAR_MINE * changeIndex
-- TUNING.MARBLETREE_MINE = TUNING.MARBLETREE_MINE * changeIndex
-- TUNING.CAVEIN_BOULDER_MINE = TUNING.CAVEIN_BOULDER_MINE * changeIndex
-- TUNING.SEASTACK_MINE = TUNING.SEASTACK_MINE * changeIndex
-- TUNING.SEACOCOON_MINE = TUNING.SEACOCOON_MINE * changeIndex
-- TUNING.SHELL_CLUSTER_MINE = TUNING.SHELL_CLUSTER_MINE * changeIndex
-- TUNING.GARGOYLE_MINE = TUNING.GARGOYLE_MINE * changeIndex
-- TUNING.GARGOYLE_MINE_LOW = TUNING.GARGOYLE_MINE_LOW * changeIndex
-- TUNING.ROCK_FRUIT_MINES = TUNING.ROCK_FRUIT_MINES * changeIndex
-- TUNING.MOONALTAR_ROCKS_MINE = TUNING.MOONALTAR_ROCKS_MINE * changeIndex

-- AddComponentPostInit("workable", function(self)
--     local SetWorkAction = self.SetWorkAction
--     self.SetWorkAction = function(self, action, ...) 
--         if action == ACTIONS.MINE and self.workleft~=1 then
--             self.workleft = self.workleft * 2
--         end
--         return SetWorkAction(self, action, ...) end
--     local SetWorkLeft = self.SetWorkLeft
--     self.SetWorkLeft = function(self, left, ...) return SetWorkAction(self, left, ...) end
-- end)
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.workmultiplier then
        local self = inst.components.workmultiplier
        if not self.actions[ACTIONS.MINE] then self.actions[ACTIONS.MINE] = SourceModifierList(self.inst) end
        self.actions[ACTIONS.MINE]:SetModifier(inst, 1 / changeIndex, "2hm")
    end
end)
