function A.balance_setup()
    local p=A.player(1)
    p.components.playervision:ForceNightVision(true)
    p.Transform:SetPosition(TheWorld.components.playerspawner:GetAnySpawnPoint())
    p.components.temperature:SetTemperature(40)
    local hat=SpawnPrefab("eyebrellahat")
    p.components.inventory:Equip(hat)
    A.balancehat=hat
    p:StopUpdatingComponent(p.components.sheltered)
    p:DoTaskInTime(.3,function()
        local f=hat.components.fueled
        emit({kind="balance_setup",maxfuel=f.maxfuel,fueltype=f.fueltype,no_sewing=f.no_sewing,
            insulation=hat.components.insulator and hat.components.insulator.insulation,
            hard=TUNING.hardmode2hm,um=UM_CONFIG and UM_CONFIG.EYEBRELLAREWORK})
    end)
end
function A.shade_step(label,natural,level,temp,mounted)
    local p=A.player(1);local s=p.components.sheltered
    p.components.temperature:SetTemperature(temp)
    s.mounted=mounted
    s:SetSheltered(natural,level)
    p:DoTaskInTime(.35,function()
        s:SetSheltered(natural,level)
        emit({kind="shade_step",label=label,level=s.sheltered_level,sheltered=s.sheltered,
            temperaturelevel=p.components.temperature.sheltered_level,
            temperature_sheltered=p.components.temperature.sheltered,mounted=s.mounted})
    end)
end
function A.armor_burst(prefab)
    local p=A.player(1);local b=SpawnPrefab(prefab)
    b:StopBrain();b.entity:SetCanSleep(false)
    b.Transform:SetPosition(p.Transform:GetWorldPosition())
    b:DoTaskInTime(.3,function()
        local h=b.components.health;h:SetInvincible(false)
        local armor=b.components.dynamicarmor2hm
        local rows={}
        for i=1,5 do
            local before=h.currenthealth
            h:DoDelta(-h.maxhealth,false,"audit",false,p)
            rows[i]={loss=before-h.currenthealth,pressure=armor and armor.pressure}
        end
        emit({kind="armor_burst",prefab=prefab,maximum=h.maxhealth,rows=rows,
            component=armor~=nil,eligible=armor and armor:IsEligible(),fx=armor and armor.fx~=nil})
        b:Remove()
    end)
end
function A.combat_values()
    local p=A.player(1)
    local weapon=SpawnPrefab("spear");weapon.components.weapon:SetDamage(100)
    local target=SpawnPrefab("bearger");target:StopBrain()
    local combat=p.components.combat;local previous=combat.damagemultiplier
    local values={}
    for _,mult in ipairs({1,2.5,3,4,5,10})do
        combat.damagemultiplier=mult
        local damage=combat:CalcDamage(target,weapon)
        values[tostring(mult)]=damage/100
    end
    combat.damagemultiplier=previous
    weapon:Remove();target:Remove()
    emit({kind="combat_values",values=values})
end
function A.actual_mount(mount)
    local p=A.player(1)
    local s=p.components.sheltered
    p.components.temperature:SetTemperature(40)
    p:StartUpdatingComponent(s)
    if mount then
        local beef=SpawnPrefab("beefalo");beef:StopBrain()
        beef.components.domesticatable:DeltaDomestication(1)
        beef.components.domesticatable:DeltaObedience(1)
        beef.Transform:SetPosition(p.Transform:GetWorldPosition())
        beef.components.rideable:SetSaddle(nil,SpawnPrefab("saddle_basic"))
        A.balancebeef=beef
        p.components.rider:Mount(beef,true)
    else p.components.rider:ActualDismount()end
    p:DoTaskInTime(1,function()
        emit({kind="actual_mount",mounted=p.components.rider:IsRiding(),level=s.sheltered_level,
            temperaturelevel=p.components.temperature.sheltered_level,sheltered=p.components.temperature.sheltered})
    end)
end
function A.hat_weather()
    local hat=A.balancehat;local f=hat.components.fueled
    f:SetPercent(.5)
    local rain,acid=TheWorld.state.israining,TheWorld.state.isacidraining
    TheWorld.state.israining=true;TheWorld.state.isacidraining=false
    local before=f.currentfuel
    hat:PushEvent("equipped")
    hat:DoTaskInTime(2,function()
        local healed=f.currentfuel>before
        TheWorld.state.isacidraining=true;hat:PushEvent("equipped")
        local acidbefore=f.currentfuel
        hat:DoTaskInTime(2,function()
            local acidhealed=f.currentfuel>acidbefore
            TheWorld.state.israining=rain;TheWorld.state.isacidraining=acid
            hat:PushEvent("equipped")
            local milk=SpawnPrefab("goatmilk")
            local accepts=f:CanAcceptFuelItem(milk)
            local repairbefore=f.currentfuel
            local taken=f:TakeFuelItem(milk,A.player(1))
            local repaired=taken and f.currentfuel>repairbefore
            if milk:IsValid()then milk:Remove()end
            emit({kind="hat_weather",healed=healed,acidhealed=acidhealed,accepts_milk=accepts,repaired=repaired})
        end)
    end)
end
function A.armor_sustained()
    local p=A.player(1);local b=SpawnPrefab("bearger")
    b:StopBrain();b.entity:SetCanSleep(false)
    b.Transform:SetPosition(p.Transform:GetWorldPosition())
    local h=b.components.health
    local rows={};local iteration=0;local peak=0;local total=0
    local task
    task=b:DoPeriodicTask(.5,function()
        iteration=iteration+1
        local before=h.currenthealth
        h:DoDelta(-200,false,"audit",false,p)
        local a=b.components.dynamicarmor2hm
        local loss=before-h.currenthealth
        local resistance=a and a:GetResistance()or 0
        total=total+loss;peak=math.max(peak,resistance)
        -- Keep the event below the engine's log line limit.
        if iteration<=10 or iteration%10==0 then
            rows[#rows+1]={hit=iteration,loss=loss,pressure=a and a.pressure,
                resistance=resistance,hp=h.currenthealth}
        end
        if h:IsDead()or iteration>=50 then
            task:Cancel()
            emit({kind="armor_sustained",maximum=h.maxhealth,rows=rows,peak=peak,
                hits=iteration,total=total,remaining=h.currenthealth})
            b:Remove()
        end
    end,.3)
end

function A.hat_save_load()
    local p=A.player(1);local hat=A.balancehat;local f=hat.components.fueled
    f:SetPercent(.37)
    local before=f.currentfuel
    local data=hat:GetSaveRecord()
    hat:Remove()
    local restored=SpawnSaveRecord(data)
    A.balancehat=restored
    p.components.inventory:Equip(restored)
    restored:DoTaskInTime(.3,function()
        emit({kind="hat_save_load",before=before,after=restored.components.fueled.currentfuel,
            maximum=restored.components.fueled.maxfuel,fueltype=restored.components.fueled.fueltype})
    end)
end

function A.shade_lifecycle()
    local p=A.player(1);local s=p.components.sheltered
    local hat=p.components.inventory:Unequip(EQUIPSLOTS.HEAD)
    if hat then p.components.inventory:GiveItem(hat)end
    p:StopUpdatingComponent(s)
    s:SetSheltered(false,1)
    s:SetSheltered(false,1)
    local bare=p.components.temperature.sheltered
    s.mounted=true
    s:Stop() -- Native Stop supplies no level; this must also work while mounted.
    local stopped=not s.sheltered and not p.components.temperature.sheltered
    s:Start();s.mounted=false
    p.components.inventory:Equip(A.balancehat)
    p.components.temperature:SetTemperature(40)
    p:DoTaskInTime(1,function()
        emit({kind="shade_lifecycle",bare=bare,stopped=stopped,level=s.sheltered_level,
            temperaturelevel=p.components.temperature.sheltered_level,
            sheltered=p.components.temperature.sheltered})
    end)
end
