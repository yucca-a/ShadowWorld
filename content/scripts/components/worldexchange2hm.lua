-- Read-only compatibility record for retired coordinated exchanges.
-- No protocol, network transport, timers, save/rollback hooks or player gates.
local Legacy=Class(function(self,inst)self.inst=inst end)
function Legacy:OnLoad(data)
    if data and data.active then self.saved=deepcopy(data) end
end
function Legacy:OnSave()return self.saved end
function Legacy:LoadPostPass()
    local active=self.saved and self.saved.active
    local container=active and self.inst:GetPocketDimensionContainer(active.name)
    if container and container.components.container then container.components.container:EnableReadOnlyContainer(true) end
end
return Legacy
