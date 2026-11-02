local function onhoverStr(self, value)
    self.inst.replica.hoverer2hm.hoverStr:set(value)
end

local hoverer2hm = Class(function(self, inst)
    self.inst = inst

    self.hoverFunc = nil
end, nil, {
    hoverStr = onhoverStr,
})

return hoverer2hm
