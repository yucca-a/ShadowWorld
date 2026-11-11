-- Own the enhancement instead of changing another mod's configuration table.
local M = {}

function M.Install(hardmode, AddPrefabPostInit, AddComponentPostInit)
    FUELTYPE.EYE = FUELTYPE.EYE or "EYE"
    local function configure(inst)
        local f=inst.components.fueled
        if hardmode and f then
            local maximum=TUNING.EYEBRELLA_PERISHTIME*(12/9)
            if f.maxfuel~=maximum then
                local percent=f:GetPercent()
                f.maxfuel=maximum
                f:SetPercent(percent)
            end
            f.no_sewing=true;f.fueltype=FUELTYPE.EYE;f.accepting=true
        end
        local insulation=inst.components.insulator
        if insulation then insulation:SetInsulation(math.max(insulation.insulation or 0,TUNING.INSULATION_LARGE))end
    end
    local function refresh(inst)
        inst.refreshstatustask2hm=nil
        if not inst:IsValid()then return end
        configure(inst)
        local f=inst.components.fueled
        if not f then return end
        local equipped=inst.components.equippable and inst.components.equippable:IsEquipped()
        if (TheWorld.state.israining or TheWorld.state.issnowing)and not TheWorld.state.isacidraining then
            f.rate_modifiers:SetModifier(inst,TheWorld.state.issnowing and -3 or -1,"2hm")
            if equipped or not(inst.components.inventoryitem and inst.components.inventoryitem:IsHeld())then
                f:StartConsuming()
            else f:StopConsuming()end
        else
            f.rate_modifiers:RemoveModifier(inst,"2hm")
            if equipped then f:StartConsuming()else f:StopConsuming()end
        end
    end
    local function schedule(inst)
        if not inst.refreshstatustask2hm then inst.refreshstatustask2hm=inst:DoTaskInTime(0,refresh)end
    end
    AddPrefabPostInit("eyebrellahat",function(inst)
        if not TheWorld.ismastersim then return end
        configure(inst)
        for _,key in ipairs({"isacidraining","israining","issnowing"})do inst:WatchWorldState(key,schedule)end
        for _,event in ipairs({"onputininventory","ondropped","equipped","unequipped"})do inst:ListenForEvent(event,schedule)end
        schedule(inst) -- Finalize after other prefab callbacks and load, preserving durability.
    end)
    if hardmode then
        local powers={milkywhites=13,goatmilk=13,butter=14}
        for prefab,power in pairs(powers)do
            AddPrefabPostInit(prefab,function(inst)
                if not TheWorld.ismastersim then return end
                if not inst.components.fuel then
                    inst:AddComponent("fuel")
                    inst.components.fuel.fuelvalue=TUNING.MED_FUEL*power
                    inst.components.fuel.fueltype=FUELTYPE.EYE
                end
            end)
        end
    end
    AddComponentPostInit("sheltered",function(s)
        local set=s.SetSheltered
        function s:SetSheltered(sheltered,level,...)
            level=type(level)=="number"and level or 1
            self.level2hm=level -- Natural tree protection, used by storm projectiles.
            local p=self.inst
            local temperature=p.components.temperature
            local hat=p.components.inventory and p.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
            if self.stoptime==nil and not p:HasTag("playerghost")and temperature and hat and hat:IsValid()
                and hat.prefab=="eyebrellahat"and hat.components.fueled and hat.components.fueled:GetPercent()>0 then
                sheltered=true
                if temperature.current<temperature.overheattemp-4 then level=math.max(level,2)end
            end
            local result=set(self,sheltered,level,...)
            -- Native SetSheltered only announces boolean transitions. A canopy
            -- or hat can change the level while that boolean remains true.
            if temperature and (temperature.sheltered~=self.sheltered or temperature.sheltered_level~=self.sheltered_level)then
                p:PushEvent("sheltered",{sheltered=self.sheltered,level=self.sheltered_level})
            end
            return result
        end
        local function refreshowner()
            s.inst:DoTaskInTime(0,function()
                if s.stoptime==nil then s:OnUpdate(0)end
            end)
        end
        for _,event in ipairs({"equip","unequip","mounted","dismounted"})do s.inst:ListenForEvent(event,refreshowner)end
    end)
end
return M
