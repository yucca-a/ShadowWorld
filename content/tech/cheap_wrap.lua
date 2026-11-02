AddRecipePostInit("bundlewrap", function(self)
    for index, ingredient in pairs(self.ingredients) do
        if ingredient.type == "rope" then
            table.remove(self.ingredients, index)
            break
        end
    end
end)

local function CheckPerishableChange(self)
    local used_time = GetTime() - self.wrap_time + self.used_time
    -- print("CheckPerishableChange " .. used_time .. " " .. self.inst.prefab)
    if self.itemdata and self.inst.prefab ~= "bundle" then
        for i, v in ipairs(self.itemdata) do
            if v.data then
                -- print(v.data)
                for component, data in pairs(v.data) do
                    -- print(component, data)
                    if component == "perishable" then
                        -- print("time", data.time, data.time - used_time)
                        data.time = math.max(data.time - used_time, 0)
                    end
                end
            end
        end
    end
end

local function OnSave(self, data)
    data.used_time = GetTime() - self.wrap_time + self.used_time
    -- print("保存时间 " .. data.used_time)
end

local function OnLoad(self, data)
    self.used_time = data.used_time or self.used_time
    self.wrap_time = GetTime()
    -- print("加载时间 " .. self.used_time)
end

AddComponentPostInit("unwrappable", function(self)
    self.wrap_time = GetTime()
    self.used_time = 0
    -- print("制造时间 " .. self.wrap_time)
    local oldUnwrap = self.Unwrap
    function self:Unwrap(doer)
        CheckPerishableChange(self)
        return oldUnwrap(self, doer)
    end
    SetComponentSave(self, OnSave)
    SetComponentLoad(self, OnLoad)
end)