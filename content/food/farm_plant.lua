local farm_plant_change = GetModConfigData("farm_plant_change")

local changeIndex = (farm_plant_change == -1 or farm_plant_change == true) and 1.5 or farm_plant_change

-- 种田时间削弱
local stages = {"seed", "sprout", "small", "med", "regrow"}
local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS
for _, data in pairs(PLANT_DEFS) do
    local growtime = data.grow_time
    if not growtime.pro2hm then
        growtime.pro2hm = true
        for _, stage in ipairs(stages) do
            if growtime[stage] and growtime[stage][1] and growtime[stage][2] then
                growtime[stage][1] = growtime[stage][1] * changeIndex
                growtime[stage][2] = growtime[stage][2] * changeIndex
            end
        end
    end
end
-- 棱镜削弱
if CONFIGS_LEGION then
    AddComponentPostInit("perennialcrop", function(self)
        local oldGetGrowTime = self.GetGrowTime
        self.GetGrowTime = function(self, ...)
            local time = oldGetGrowTime(self, ...)
            return time and time * changeIndex
        end
    end)
end
