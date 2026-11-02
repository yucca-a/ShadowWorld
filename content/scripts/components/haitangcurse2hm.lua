local function on_curse_num(self, curse_num)
    local classified2hm = TUNING.util2hm.GetClassified2hm(self.inst.userid)
    if classified2hm then
        -- print("状态", self.curse_num > 0)
        classified2hm.take_cursed_item_num:set(self.curse_num > 0)
    end
end

local function re_check(self)
    -- print("re_check")
    local held_cursed_item = 0
    if self.inst.components.inventory then
        for _, v in pairs(self.inst.components.inventory.itemslots) do
            if v:HasTag("curse2hm") or v:HasTag("cursed") then
                held_cursed_item = held_cursed_item + 1
            end
        end
        for _, v in pairs(self.inst.components.inventory.equipslots) do
            if v:HasTag("curse2hm") or v:HasTag("cursed") then
                held_cursed_item = held_cursed_item + 1
            end
        end
    end
    self.curse_num = held_cursed_item
    -- print("self.curse_num", self.curse_num)
end

local function OnItemGet(self, data)
    -- print("OnItemGet")
    if data then
        if data.slot and data.item and (data.item:HasTag("curse2hm") or data.item:HasTag("cursed")) then
            self.curse_num = self.curse_num + 1
            -- print("self.curse_num", self.curse_num)
        end
    end
end

local function OnItemEquip(self, data)
    -- print("OnItemEquip")
    if data then
        if data.item and (data.item:HasTag("curse2hm") or data.item:HasTag("cursed")) then
            self.curse_num = self.curse_num + 1
            -- print("self.curse_num", self.curse_num)
        end
    end
end

local function OnItemLose(self, data)
    -- print("OnItemLose")
    if data then
        local item = data.prev_item or data.item
        if item and (item:HasTag("curse2hm") or item:HasTag("cursed")) then
            self.curse_num = self.curse_num - 1
            -- print("self.curse_num", self.curse_num)
        end
    end
end

local function DoInit(self)
    self.inst:WatchWorldState("cycles", function()
        re_check(self)
    end)
    self.OnItemGet = function(inst, data)
        OnItemGet(self, data)
    end
    self.OnItemEquip = function(inst, data)
        OnItemEquip(self, data)
    end
    self.OnItemLose = function(inst, data)
        OnItemLose(self, data)
    end
    self.inst:ListenForEvent("itemget", self.OnItemGet)
    self.inst:ListenForEvent("equip", self.OnItemEquip)
    self.inst:ListenForEvent("itemlose", self.OnItemLose)
    self.inst:ListenForEvent("unequip", self.OnItemLose)
    re_check(self)
end

local function OnRemoveFromEntity(self)
    if self.OnItemGet then
        self.inst:RemoveEventCallback("itemget", self.OnItemGet)
    end
    if self.OnItemEquip then
        self.inst:RemoveEventCallback("equip", self.OnItemEquip)
    end
    if self.OnItemLose then
        self.inst:RemoveEventCallback("itemlose", self.OnItemLose)
        self.inst:RemoveEventCallback("unequip", self.OnItemLose)
    end
end


local haitangcurse2hm = Class(function(self, inst)
    self.inst = inst

    self.curse_num = 0

    self.DoInit = DoInit
    self.OnRemoveFromEntity = OnRemoveFromEntity

    self.inst:DoTaskInTime(0, function()
        self:DoInit()
    end)
end, nil, {
    curse_num = on_curse_num
})

return haitangcurse2hm
