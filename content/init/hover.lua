AddClassPostConstruct("widgets/hoverer",function(self)
    local old_SetString = self.text.SetString
    self.text.SetString = function(text,str)
        local target = TheInput:GetHUDEntityUnderMouse()
        if target ~= nil then
            target = target.widget ~= nil and target.widget.parent ~= nil and target.widget.parent.item
        else
            target = TheInput:GetWorldEntityUnderMouse()
        end
        if target and target.entity ~= nil then
            local newstr
            if target.replica.hoverer2hm then
                newstr = target.replica.hoverer2hm.hoverStr:value()
            end
            if newstr then
                str = str.."\n".. newstr
            end
        end
        return old_SetString(text,str)
    end
end)
