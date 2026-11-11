-- Only vault-issued items carry this component. Any subsequent use, stacking,
-- ownership change or removal revokes the old recovery claim before refreshing
-- the item's remaining state. No player action waits for journal I/O.
local Issued=Class(function(self,inst)
    self.inst=inst
    local function changed()
        local v=TheWorld and TheWorld.components.shadowvault2hm
        if v and not v.retired and v.journal then v.journal:IssuedChanged(self.id,inst) end
    end
    for _,event in ipairs({"stacksizechange","onputininventory","ondropped","onremove","percentusedchange","perishchange"}) do
        inst:ListenForEvent(event,changed)
    end
end)
function Issued:OnSave()return self.id and {id=self.id,add_component_if_missing=true} end
function Issued:OnLoad(data)self.id=data and data.id end
return Issued
