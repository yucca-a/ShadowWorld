local hoverer2hm = Class(function(self, inst)
    self.inst = inst

    self.hoverStr = net_string(inst.GUID, "hoverer2hm.hoverStr")
    self.hoverStr:set_local("")
end)

return hoverer2hm
