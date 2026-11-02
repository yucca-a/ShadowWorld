local AOE_RANGE2HM = 8

AddComponentPostInit("farmplanttendable", function(comp)
    local _TendTo = comp.TendTo
    comp.TendTo = function(self, doer, ...)
        local ok = _TendTo(self, doer, ...)
        if ok and TheWorld.ismastersim and doer ~= nil and doer:HasTag("friendlyfruitfly") then
            local x, y, z = self.inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, 0, z, AOE_RANGE2HM, {"tendable_farmplant"})
            for i = 1, #ents do
                local v = ents[i]
                if v ~= self.inst and v.components.farmplanttendable ~= nil then
                    _TendTo(v.components.farmplanttendable, doer)
                end
            end
        end
        return ok
    end
end)
