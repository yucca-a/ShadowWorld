-- [临时装备] --
-- 处理临时装备，添加新鲜度，禁止被用于制作，禁止被拆解/通过作祟拆解（见common）

local tempequip2hm = Class(function(self, inst)
    self.inst = inst
    self.perishtime = TUNING.TOTAL_DAY_TIME * 20
    self.remainingtime2hm = TUNING.TOTAL_DAY_TIME * 20
    self.onperishreplacement = "spoiled_food"
    self.inst:AddTag("nocrafting")
end, nil, {})

local function InventoryPerish2hm(inst)
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
end

function tempequip2hm:BecomePerishable()
    local inst = self.inst
    if not inst.components.perishable then
        inst:AddTag("show_spoilage")
        inst:AddComponent("perishable")
    end
    inst.components.perishable.perishtime = self.perishtime
    inst.components.perishable.perishremainingtime = self.remainingtime2hm
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = self.onperishreplacement
    inst.components.perishable:SetOnPerishFn(InventoryPerish2hm)
end

return tempequip2hm
