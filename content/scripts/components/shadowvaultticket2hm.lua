-- Only items participating in a deposit receive this component. Native loading
-- adds it on demand; unrelated items do not carry a permanent component.
local Ticket=Class(function(self,inst) self.inst=inst end)
function Ticket:OnSave() return self.id and {id=self.id,add_component_if_missing=true} end
function Ticket:OnLoad(data) self.id=data and data.id end
return Ticket
