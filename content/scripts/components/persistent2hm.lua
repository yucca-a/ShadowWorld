local Component2hm = Class(function(self, inst)
    self.inst = inst
    self.data = {}
end)

function Component2hm:OnSave()
    local refs
    if self.inst.onsave2hm then refs = self.inst.onsave2hm(self.inst, self.data) end
    return self.data, refs
end

function Component2hm:OnLoad(data)
    if data and data.id and TUNING.linkids2hm then TUNING.linkids2hm[data.id] = self.inst end
    if self.data.id and data and not data.id then data.id = self.data.id end
    self.data = data or self.data
    if self.inst.onload2hm then self.inst.onload2hm(self.inst, self.data) end
end

function Component2hm:LoadPostPass(ents, data)
    if self.inst.LoadPostPass2hm then
        self.data = data or self.data
        self.inst.LoadPostPass2hm(self.inst, ents, self.data)
    end
end

function Component2hm:OnRemoveEntity() if self.data.id and TUNING.linkids2hm then TUNING.linkids2hm[self.data.id] = nil end end

return Component2hm
