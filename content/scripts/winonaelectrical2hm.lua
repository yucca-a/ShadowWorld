-- Electrical conversion and bounded overcharging. Charging never changes consumption rates.
local M = {}
local lamps = {lantern = true, minerhat = true, molehat = true}
local weapons = {nightstick = true, bugzapper = true, spear_wathgrithr_lightning = true, spear_wathgrithr_lightning_charged = true}

function M.Storage(inst)
    return inst.components.fueled or inst.components.finiteuses
end

local function Active(inst)
    return inst.electricalconverted2hm or inst.electricalweapon2hm
end

local function Owner(inst)
    return inst._electricaldoer2hm or (inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner())
end

function M.ChargeLimit(inst, battery)
    local owner = Owner(inst)
    local inventory = owner and owner.components.inventory
    local equipped = inventory and inventory:GetEquippedItem(inst.components.equippable.equipslot) == inst
    local generator = battery and (battery.prefab == "winona_battery_low" or battery.prefab == "winona_battery_high")
    return inst.electricalovercharge2hm and generator and owner and owner.prefab == "winona" and equipped and 2 or 1
end

function M.Refresh(inst)
    if not Active(inst) then return end
    local storage = M.Storage(inst)
    local charged = inst.electricalovercharge2hm and storage:GetPercent() > 1 or false
    if inst.overcharged ~= charged then
        inst.overcharged = charged
        inst:PushEvent("overcharged", charged)
    end
    local fueled = inst.components.fueled
    if fueled then
        -- Undo stale UM ground-charging rates; overcharging adds no consumption penalty.
        if fueled.rate < 0 then fueled.rate = 1 end
        fueled.rate_modifiers:SetModifier(inst, 1, "overcharge2hm")
        -- UM's old event listener writes rate=2; retire that old consumption penalty.
        if inst.electricallegacy2hm then fueled.rate = 1 end
    end
    if inst.prefab == "minerhat" and inst._light and inst._light:IsValid() then
        inst._light.Light:SetRadius(charged and 5 or 2.5)
    end
end

function M.InstallStorage(inst)
    if inst.electricalstorage2hm then return end
    inst.electricalstorage2hm = true
    local replica = inst.replica.inventoryitem
    if replica and replica.classified then replica.classified.electricalowner2hm = inst end
    local fueled = inst.components.fueled
    if fueled then
        local DoDelta, GetPercent, IsFull = fueled.DoDelta, fueled.GetPercent, fueled.IsFull
        function fueled:GetPercent()
            return Active(inst) and (self.maxfuel > 0 and math.clamp(self.currentfuel / self.maxfuel, 0, 2) or 0)
                or GetPercent(self)
        end
        function fueled:IsFull()
            return Active(inst) and self.currentfuel >= self.maxfuel * (inst.electricalovercharge2hm and 2 or 1)
                or not Active(inst) and IsFull(self)
        end
        function fueled:DoDelta(amount, doer)
            if not Active(inst) then return DoDelta(self, amount, doer) end
            local oldsection = self:GetCurrentSection()
            -- Ordinary fuel cannot create overcharge without Winona. Consuming never clamps
            -- a 150% item down to 100%, and charging cannot grow the nominal capacity.
            local cap = self._electricalcap2hm or (amount <= 0 and 2 or math.max(1, self:GetPercent()))
            self.currentfuel = math.clamp(self.currentfuel + amount, 0, self.maxfuel * cap)
            local newsection = self:GetCurrentSection()
            if oldsection ~= newsection then
                if self.sectionfn then self.sectionfn(newsection, oldsection, inst, doer) end
                inst:PushEvent("onfueldsectionchanged", {newsection = newsection, oldsection = oldsection, doer = doer})
                if self.currentfuel <= 0 and self.depleted then self.depleted(inst) end
            end
            inst:PushEvent("percentusedchange", {percent = self:GetPercent()})
            M.Refresh(inst)
        end
        local DoUpdate = fueled.DoUpdate
        function fueled:DoUpdate(dt)
            if Active(inst) and self.rate < 0 then self.rate = 1 end
            return DoUpdate(self, dt)
        end
        fueled.LongUpdate = fueled.DoUpdate
        -- Native OnLoad/InitializeFuelLevel expands maxfuel when loading >100% fuel.
        -- Preserve the original capacity, including on an item whose upgrade loads later.
        local OnLoad = fueled.OnLoad
        function fueled:OnLoad(data, ...)
            if data and data.fuel and Active(inst) then
                local cap = inst.electricalovercharge2hm and 2 or 1
                self._electricalcap2hm = cap
                self:DoDelta(math.clamp(data.fuel, 0, self.maxfuel * cap) - self.currentfuel)
                self._electricalcap2hm = nil
            else
                return OnLoad(self, data, ...)
            end
        end
        local TakeFuelItem = fueled.TakeFuelItem
        function fueled:TakeFuelItem(item, doer)
            if not Active(inst) then return TakeFuelItem(self, item, doer) end
            local fuel_obj = item or doer
            local fuel = fuel_obj and (fuel_obj.components.fuel or fuel_obj.components.fueler)
            if not fuel or not self:CanAcceptFuelItem(fuel_obj) or
                self.cantakefuelitemfn and not self.cantakefuelitemfn(inst, item, doer) then return false end
            -- Fuel items can refill to 100%; first overcharge requires touching a generator.
            local cap = 1
            if self:GetPercent() >= cap then return false end
            local mult = self.multfn and self.multfn(inst, fuel_obj) or 1
            local wetmult = fuel_obj:GetIsWet() and TUNING.WET_FUEL_PENALTY or 1
            local mastery = doer and doer.components.fuelmaster and doer.components.fuelmaster:GetBonusMult(fuel_obj, inst) or 1
            local value = fuel.fuelvalue * self.bonusmult * mult * wetmult * mastery
            self._electricalcap2hm = cap
            self:DoDelta(value, doer)
            self._electricalcap2hm = nil
            fuel:Taken(inst)
            if item then
                if self.ontakefuelitemfn then self.ontakefuelitemfn(inst, item, value, doer) end
                item:Remove()
            end
            if self.ontakefuelfn then self.ontakefuelfn(inst, value) end
            inst:PushEvent("takefuel", {fuelvalue = value})
            return true
        end
    elseif inst.components.finiteuses then
        local uses = inst.components.finiteuses
        local SetUses = uses.SetUses
        function uses:SetUses(value)
            SetUses(self, Active(inst) and math.min(value, self.total * (inst.electricalovercharge2hm and 2 or 1)) or value)
            M.Refresh(inst)
        end
        local Use = uses.Use
        function uses:Use(num)
            return Use(self, Active(inst) and inst.electricalovercharge2hm and (num or 1) * 0.75 or num)
        end
    end
end

local function CalcCharge(inst, battery)
    return math.clamp(M.ChargeLimit(inst, battery) - M.Storage(inst):GetPercent(), 0, 0.33)
end

local function OnBatteryUsed(inst, battery, mult)
    local storage = M.Storage(inst)
    local cap = M.ChargeLimit(inst, battery)
    if not mult or mult <= 0 or storage:GetPercent() >= cap then return false, "CHARGE_FULL" end
    storage._electricalcap2hm = cap
    storage:SetPercent(math.min(cap, storage:GetPercent() + mult))
    storage._electricalcap2hm = nil
    if storage:GetPercent() > 1 and cap == 2 then inst.electricalunlocked2hm = true end
    local fueled = inst.components.fueled
    if fueled and fueled.ontakefuelfn then fueled.ontakefuelfn(inst, 0) end
    M.Refresh(inst)
    SpawnElectricHitSparks(inst, battery, true)
    return true
end

function M.InstallBatteryUser(inst)
    if not inst.components.batteryuser then inst:AddComponent("batteryuser") end
    local batteryuser = inst.components.batteryuser
    batteryuser:SetChargeMultFn(CalcCharge)
    batteryuser:SetOnBatteryUsedFn(OnBatteryUsed)
    batteryuser:SetAllowPartialCharge(true)
end

function M.Convert(inst)
    inst.upgraded = true
    inst.electricalconverted2hm = true
    inst:AddTag("electricaltool")
    if inst.electricalovercharge2hm then inst:AddTag("electricalovercharge2hm") end
    local fueled = inst.components.fueled
    fueled.fueltype = FUELTYPE.BATTERYPOWER
    fueled.rate_modifiers:SetModifier(inst, 0.75, "electricalefficiency")
    if inst.electricallegacy2hm then fueled.rate = 1 end
    inst.components.upgradeable.upgradetype = nil
    local name = string.upper(inst.prefab) .. "_ELECTRICAL"
    inst:SetPrefabNameOverride(name)
    if not inst.components.named then inst:AddComponent("named") end
    inst.components.named:SetName(STRINGS.NAMES[name])
    M.InstallBatteryUser(inst)
    M.Refresh(inst)
end

local function Disconnect(inst)
    inst.components.powerload:SetLoad(0)
    inst.components.circuitnode:Disconnect()
end

local function Connect(inst)
    if not inst:IsInLimbo() and not inst.components.inventoryitem:IsHeld() then
        inst.components.circuitnode:ConnectTo("engineeringbattery")
    end
end

function M.InstallGround(inst, enabled)
    if inst.electricalground2hm then return end
    inst.electricalground2hm = true
    -- Retire UM's negative-rate charger even if the ground charging option is disabled.
    if inst._powertask then inst._powertask:Cancel(); inst._powertask = nil end
    inst._oldrate = nil
    local fueled = inst.components.fueled
    if fueled and inst.AddBatteryPower then
        fueled:SetUpdateFn(nil)
        if fueled.rate < 0 then fueled.rate = 1 end
    end
    if not enabled and not inst.components.circuitnode then return end
    if not inst.components.circuitnode then
        inst:AddComponent("circuitnode")
        inst.components.circuitnode:SetRange(TUNING.WINONA_BATTERY_RANGE)
        inst.components.circuitnode.connectsacrossplatforms = false
        inst:AddComponent("powerload")
    end
    inst:AddTag("engineeringbatterypowered")
    inst.components.powerload:SetLoad(0)
    inst.AddBatteryPower = function(inst)
        if inst:IsInLimbo() or inst.components.inventoryitem:IsHeld() then return end
        local storage = M.Storage(inst)
        local percent = storage:GetPercent()
        local cap = inst.electricalovercharge2hm and inst.electricalunlocked2hm and 2 or 1
        local now = GetTime()
        if enabled and percent < cap and (not inst.nextgroundcharge2hm or now >= inst.nextgroundcharge2hm) then
            inst.nextgroundcharge2hm = now + 0.5 - FRAMES
            storage._electricalcap2hm = cap
            storage:SetPercent(math.min(cap, percent + 0.01))
            storage._electricalcap2hm = nil
            percent = storage:GetPercent()
        end
        local load = enabled and percent < cap and TUNING.WINONA_TELEBRELLA_POWER_LOAD_CHARGING or 0
        if inst.components.powerload:GetLoad() ~= load then
            inst.components.powerload:SetLoad(load)
            inst.components.circuitnode:ForEachNode(function(_, generator) generator:PushEvent("engineeringcircuitchanged") end)
        end
    end
    inst:ListenForEvent("on_landed", Connect)
    inst:ListenForEvent("on_no_longer_landed", Disconnect)
    inst:ListenForEvent("onputininventory", Disconnect)
    inst:DoTaskInTime(0, Connect)
end

function M.IsLamp(name) return lamps[name] end
function M.IsWeapon(name) return weapons[name] end
return M
