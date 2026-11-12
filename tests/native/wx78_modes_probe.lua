local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row)print("[VAUDIT] "..json.encode(row))end
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
G.VaultAudit={}
local function saveRecord(p,done)
    TheSim:SetPersistentString("wx78_modes_roundtrip",DataDumper(p:GetSaveRecord(),nil,true),false,done)
end
function G.VaultAudit.wx78_export()
    TheWorld:StartThread(function()
        local p=SpawnPrefab("wx78");p.userid="KU_WX_EXPORT";Sleep(.4)
        local owner=p.components.upgrademoduleowner
        owner:SetChargeLevel(owner:GetMaxChargeLevel())
        local m=SpawnPrefab("wx78module_maxhealth");m.level2hm:set(3)
        owner:PushModule(nil,m)
        local gear=SpawnPrefab("gears");p.components.eater:Eat(gear)
        p.toolbox2hm.components.container:GiveItem(SpawnPrefab("scandata"),1)
        saveRecord(p,function(success)assert(success);emit({kind="wx78_export",passed=true})end)
    end)
end
function G.VaultAudit.wx78_import(back)
    TheSim:GetPersistentString("wx78_modes_roundtrip",function(success,str)
        assert(success)
        local ok,record=RunInSandbox(str);assert(ok)
        local p=SpawnSaveRecord(record);p.userid="KU_WX_IMPORT"
        TheWorld:StartThread(function()
            Sleep(.5)
            local owner=p.components.upgrademoduleowner
            local modules=owner:GetAllModules()
            local count=0
            for _,i in pairs(p.components.inventory.itemslots)do if i.prefab=="wx78module_maxhealth"then count=count+1 end end
            assert(count==2,"actual legacy fusion refund count")
            assert(#modules==1,"actual installed circuit count")
            if not back then
                assert(not modules[1].level2hm)
                assert(not p.toolbox2hm)
                assert(p.components.inventory:FindItem(function(i)return i.prefab=="scandata"end))
                assert(p.components.health.maxhealth==TUNING.WX78_HEALTH+TUNING.WX78_MAXHEALTH_BOOST,"old permanent health remained")
            else
                assert(modules[1].level2hm:value()==1)
                assert(p.toolbox2hm)
            end
            saveRecord(p,function(done)assert(done);emit({kind="wx78_import",passed=true,back=back,refunds=count})end)
        end)
    end)
end
function G.VaultAudit.wx78_modes()
    TheWorld:StartThread(function()
        local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
        local serial=0
        local function player(record)
            local p=record and SpawnSaveRecord(record)or SpawnPrefab("wx78")
            serial=serial+1;p.userid="KU_WX_MODE_"..serial
            p.Transform:SetPosition(x,y,z);p.entity:SetCanSleep(false)
            p.components.hunger:SetRate(0)
            return p
        end
        local function row(name,data)
            data=data or{};data.kind="wx78_case";data.case=name;emit(data)
        end
        local function near(a,b)assert(math.abs(a-b)<.00001,tostring(a).." ~= "..tostring(b))end
        local p=player();Sleep(.4)
        local owner=p.components.upgrademoduleowner
        local board=SpawnPrefab("wx78module_maxhealth")
        assert((board.level2hm~=nil)==(WX_MODE=="legacy"or WX_MODE=="easy"or WX_MODE=="hard"))
        assert((p.wx78draft2hm==true)==(WX_MODE=="draft"))
        row("mode_isolation",{mode=WX_MODE,slots=owner.max_charge,fusion=board.level2hm~=nil})
        if WX_MODE~="draft"and WX_MODE~="off"then
            board:Remove();p:Remove();emit({kind="wx78_modes",passed=true});return
        end
        board:Remove()
        if WX_MODE=="draft"then
            local skills={wx78_circuitry_alphabuffs_1=true,wx78_circuitry_alphabuffs_2=true}
            p.components.skilltreeupdater.IsActivated=function(_,name)return skills[name]or false end
            owner:SetChargeLevel(6)
            for i=1,2 do owner:PushModule(nil,SpawnPrefab("wx78module_maxhealth2"))end
            near(p.wx78draftblock2hm,15)
            near(p.components.combat.externaldamagetakenmultipliers:Get(),1)
            local armor=SpawnPrefab("armorwood");p.components.inventory:Equip(armor)
            local attacker=SpawnPrefab("hound");attacker.Transform:SetPosition(x+5,y,z)
            local expected=85*(1-armor.components.armor:GetAbsorption(attacker,nil))
            local damage,sp=p.components.inventory:ApplyDamage(100,attacker,nil,{planar=10})
            near(damage,expected);near(sp.planar,10)
            local before=p.components.health.currenthealth
            p.components.combat:GetAttacked(attacker,100)
            near(before-p.components.health.currenthealth,expected)
            row("armor_order_and_planar",{damage=damage,planar=sp.planar})
            attacker:Remove();p.components.inventory:Unequip(EQUIPSLOTS.BODY):Remove()
            owner:SetChargeLevel(0);near(p.wx78draftblock2hm,0)
            for _,m in ipairs(owner:PopAllModules())do m:Remove()end
            owner:SetChargeLevel(6)
            owner:PushModule(nil,SpawnPrefab("wx78module_maxsanity1"))
            owner:PushModule(nil,SpawnPrefab("wx78module_maxsanity"))
            near(p.components.sanity.neg_aura_modifiers:Get(),.3)
            near(p.components.sanity.dapperness+p.components.sanity.externalmodifiers:Get(),1/60)
            skills.wx78_circuitry_alphabuffs_2=nil
            p:PushEvent("ondeactivateskill_server",{skill="wx78_circuitry_alphabuffs_2"})
            near(p.components.sanity.neg_aura_modifiers:Get(),.4)
            skills.wx78_circuitry_alphabuffs_1=nil
            p:PushEvent("ondeactivateskill_server",{skill="wx78_circuitry_alphabuffs_1"})
            near(p.components.sanity.neg_aura_modifiers:Get(),.675)
            owner:SetChargeLevel(0)
            near(p.components.sanity.neg_aura_modifiers:Get(),1)
            near(p.components.sanity.externalmodifiers:Get(),0)
            for _,m in ipairs(owner:PopAllModules())do m:Remove()end
            row("sanity_tiers_deactivation")
            local function eat(gain,electric)
                local food=SpawnPrefab("meatballs")
                food.components.edible.hungervalue=gain
                food.components.edible.chargevalue=electric
                assert(p.components.eater:Eat(food))
            end
            p.components.hunger.current=0
            eat(15);near(owner:GetChargeLevel(),0);near(p.wx78nutrition2hm,15)
            local saved=p:GetSaveRecord();local q=player(saved);Sleep(.4)
            near(q.wx78nutrition2hm,15);q:Remove()
            eat(30);near(owner:GetChargeLevel(),1);near(p.wx78nutrition2hm,0)
            p.components.hunger.current=p.components.hunger.max-10
            eat(135);near(owner:GetChargeLevel(),1);near(p.wx78nutrition2hm,10)
            eat(135);near(owner:GetChargeLevel(),1);near(p.wx78nutrition2hm,10)
            p.components.hunger.current=0;eat(45,1)
            near(owner:GetChargeLevel(),2);near(p.wx78nutrition2hm,10)
            owner:SetChargeLevel(6);near(p.wx78nutrition2hm,0)
            p.components.hunger.current=0;eat(45);near(p.wx78nutrition2hm,0)
            owner:SetChargeLevel(0);p.components.hunger:SetMax(200);p.components.hunger.current=0;eat(135)
            near(owner:GetChargeLevel(),3);near(p.wx78nutrition2hm,0)
            row("food_actual_gain_overflow_electric_save")
            skills.wx78_circuitry_alphabuffs_1=true;skills.wx78_circuitry_alphabuffs_2=true
            local body=SpawnPrefab("wx78_possessedbody")
            p.components.leader:AddFollower(body)
            local bodyaura=body.components.sanity.neg_aura_modifiers:Get()
            local bo=body.components.upgrademoduleowner;bo:SetChargeLevel(6)
            for _,name in ipairs({"maxhealth2","maxhealth","maxsanity","maxsanity1"})do
                bo:PushModule(nil,SpawnPrefab("wx78module_"..name))
            end
            near(body.wx78draftblock2hm,10.5)
            near(body.components.sanity.neg_aura_modifiers:Get(),.3*bodyaura)
            skills.wx78_circuitry_alphabuffs_2=nil
            p:PushEvent("ondeactivateskill_server",{skill="wx78_circuitry_alphabuffs_2"})
            near(body.components.sanity.neg_aura_modifiers:Get(),.4*bodyaura)
            near(body.wx78draftblock2hm,7)
            bo:SetOverrideFullCharge(false);bo:SetChargeLevel(0);near(body.wx78draftblock2hm,0)
            body:Remove()
            row("possessed_body_follows_leader_skills")
        end
        -- A real saved fused circuit becomes one installed circuit plus refunds.
        local item=SpawnPrefab("wx78module_maxhealth")
        item.components.finiteuses:SetPercent(.6)
        local rec=item:GetSaveRecord();item:Remove();rec.data=rec.data or{};rec.data.level=3
        local fused=SpawnSaveRecord(rec)
        local pending=fused:GetSaveRecord()
        assert(pending.data.wx78refund2hm==2,"preload save lost pending circuit refunds")
        p.components.upgrademoduleowner:PushModule(nil,fused)
        Sleep(.4)
        local count=0
        for _,i in pairs(p.components.inventory.itemslots)do
            if i.prefab=="wx78module_maxhealth"then count=count+1;near(i.components.finiteuses:GetPercent(),.6)end
        end
        assert(count==2,"fusion refund count "..count)
        local saved=p:GetSaveRecord();local q=player(saved);Sleep(.4)
        local count2=0
        for _,i in pairs(q.components.inventory.itemslots)do if i.prefab=="wx78module_maxhealth"then count2=count2+1 end end
        assert(count2==2,"repeat refund after reload")
        row("fusion_refund_and_reload",{refunds=count2})
        q:Remove()
        -- Restore a persistent virtual box using the actual container serializer.
        local box=SpawnPrefab("wx78_toolbox")
        box.components.container:GiveItem(SpawnPrefab("scandata"),1)
        local boxdata=box:GetPersistData();box:Remove()
        saved=p:GetSaveRecord();saved.data.persistent2hm=saved.data.persistent2hm or{}
        saved.data.persistent2hm.wx78_toolbox=boxdata
        q=player(saved);Sleep(.5)
        assert(q.components.inventory:FindItem(function(i)return i.prefab=="scandata"end),"missing box item")
        assert(not q.components.persistent2hm.data.wx78_toolbox)
        local second=player(q:GetSaveRecord());Sleep(.5)
        local n=0
        for _,i in pairs(second.components.inventory.itemslots)do if i.prefab=="scandata"then n=n+1 end end
        assert(n==1,"duplicated box items")
        row("virtual_box_recovery_and_reload",{items=n})
        second:Remove();q:Remove();p:Remove()
        local crowded=player()
        crowded.components.upgrademoduleowner:SetChargeLevel(6)
        for i=1,7 do crowded.components.upgrademoduleowner:PushModule(nil,SpawnPrefab("wx78module_maxhealth"))end
        local record=crowded:GetSaveRecord();crowded:Remove()
        local trimmed=player(record);Sleep(.4)
        assert(#trimmed.components.upgrademoduleowner:GetAllModules()==6)
        local refunds=0
        for _,i in pairs(trimmed.components.inventory.itemslots)do if i.prefab=="wx78module_maxhealth"then refunds=refunds+1 end end
        assert(refunds==1,"oversized circuit bar lost items")
        row("oversized_bar_refund",{installed=6,refunds=refunds})
        trimmed:Remove()
        local scanner=SpawnPrefab("wx78_scanner")
        local scannerrecord=scanner:GetSaveRecord();scanner:Remove()
        local base=player();local savedbase=base:GetSaveRecord();base:Remove()
        savedbase.data.wx78_scanner_save2hm=scannerrecord
        local restored=player(savedbase)
        assert(restored:GetSaveRecord().data.wx78_scanner_save2hm,"preload save lost scanner")
        Sleep(.4)
        local scanners=0
        for follower in pairs(restored.components.leader.followers)do if follower.prefab=="wx78_scanner"then scanners=scanners+1 end end
        assert(scanners==1,"missing legacy scanner")
        assert(not restored.wx78recoveryscanner2hm)
        row("legacy_scanner_recovery",{scanners=scanners})
        restored:Remove()
        emit({kind="wx78_modes",passed=true})
    end)
end
