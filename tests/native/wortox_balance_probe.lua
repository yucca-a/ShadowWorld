local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row)print("[VAUDIT] "..json.encode(row))end
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
G.VaultAudit={}
function G.VaultAudit.wortox_balance()
    TheWorld:StartThread(function()
        local CD="wortox_reviver_cooldown2hm"
        local enabled=BALANCE_EDITION=="beta"and BALANCE_OVERHAUL
        local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
        local serial=0
        local function spawnplayer(record)
            local p=record and SpawnSaveRecord(record)or SpawnPrefab("wortox")
            serial=serial+1;p.userid="KU_WORTOX_BALANCE_"..serial
            p.Transform:SetPosition(x,y,z);p.entity:SetCanSleep(false)
            p.components.hunger:SetRate(0)
            return p
        end
        local function give(p,prefab)
            local item=SpawnPrefab(prefab or "wortox_reviver")
            p.components.inventory:GiveItem(item)
            return item
        end
        local function hit(p)
            p.components.health:DoDelta(-10000,false,"wortox_balance_probe",true,nil,true)
        end
        local function row(name,p,more)
            local r=more or{};r.kind="wortox_balance_case";r.case=name
            r.health=p.components.health.currenthealth
            r.cooldown=p.components.timer:GetTimeLeft(CD)or false
            emit(r)
        end
        local p=spawnplayer()
        local a=give(p)
        hit(p);Sleep(.3)
        row("first_rescue",p,{consumed=not a:IsValid()})
        if BALANCE_EDITION=="beta"then
            assert(not p.components.health:IsDead()and not a:IsValid())
            assert(p.components.timer:TimerExists(CD)==enabled)
            give(p)
            local saved=p:GetSaveRecord()
            local q=spawnplayer(saved)
            local second=q.components.inventory:FindItem(function(i)return i.prefab=="wortox_reviver"end)
            hit(q)
            row("saved_cooldown_blocks_second_heart",q,{heart_valid=second:IsValid()})
            assert(q.components.health:IsDead()==enabled)
            if enabled then assert(second:IsValid())end
            q:Remove()
            local ally=SpawnPrefab("wilson")
            ally.userid="KU_WORTOX_BALANCE_ALLY";ally.components.hunger:SetRate(0)
            ally.Transform:SetPosition(x,y,z)
            give(ally);hit(ally);Sleep(.3)
            row("heart_on_another_character",ally)
            assert(ally.components.timer:TimerExists(CD)==enabled)
            ally:Remove()
            if enabled then
                local amuletuser=spawnplayer(saved)
                local amulet=give(amuletuser,"amulet")
                amuletuser.components.inventory:Equip(amulet)
                hit(amuletuser)
                row("amulet_during_heart_cooldown",amuletuser)
                assert(not amuletuser.components.health:IsDead())
                assert(amuletuser.components.timer:TimerExists(CD))
                amuletuser:Remove()
                local left=p.components.timer:GetTimeLeft(CD)
                assert(left>118 and left<=120)
                local started=GetTime()
                if BALANCE_REAL_TIME then
                    Sleep(left-.1)
                    local chooser=require("umcompatguard2hm").Find(p.components.health.SetVal,"HasPocketResurrection").value
                    assert(chooser(p.components.health)==nil)
                    Sleep(.3)
                else
                    p.components.timer:SetTimeLeft(CD,.1);Sleep(.3)
                end
                assert(not p.components.timer:TimerExists(CD))
                local elapsed=GetTime()-started
                local fresh=p.components.inventory:FindItem(function(i)return i.prefab=="wortox_reviver"end)
                hit(p);Sleep(.1)
                row("heart_after_cooldown",p,{elapsed=elapsed,elapsed_since_trigger=120-left+elapsed,
                    consumed=not fresh:IsValid(),real_time=BALANCE_REAL_TIME})
                assert(not p.components.health:IsDead()and not fresh:IsValid())
                assert(p.components.timer:GetTimeLeft(CD)>119)
            end
        else
            assert(p.components.health:IsDead()and a:IsValid())
            assert(not p.components.timer:TimerExists(CD))
        end
        p:Remove()

        local healthy=spawnplayer()
        local grant,period
        for task in pairs(healthy.pendingtasks or{})do
            local info=debug.getinfo(task.fn,"S")
            if info.source:find("easy_role/wortox_easy.lua",1,true)and(task.period==120 or task.period==240)then grant=task.fn;period=task.period end
        end
        assert(grant,"native passive soul task not found")
        local function count()
            local n=0
            for _,item in ipairs(healthy.components.inventory:FindItems(function(i)return i.prefab=="wortox_soul"end))do
                n=n+item.components.stackable:StackSize()
            end
            return n
        end
        local function stats(h,s,f)
            healthy.components.health:SetPercent(h)
            healthy.components.sanity:SetPercent(s)
            healthy.components.hunger:SetPercent(f)
        end
        stats(.75,.75,.75)
        local before=count();grant(healthy)
        row("healthy_passive_soul",healthy,{souls=count()-before,period=period})
        assert(count()-before==1)
        for _,values in ipairs({{.74,.9,.9},{.9,.74,.9},{.9,.9,.74}})do
            stats(unpack(values));before=count();grant(healthy);assert(count()==before)
        end
        stats(.9,.9,.9)
        -- GiveItem may merge and remove the supplied entity; set the stack first.
        local soul=SpawnPrefab("wortox_soul")
        soul.components.stackable:SetStackSize(10)
        healthy.components.inventory:GiveItem(soul)
        before=count();grant(healthy)
        row("soul_cap",healthy,{before=before,after=count()})
        assert(count()==before)
        healthy:Remove()
        emit({kind="wortox_balance",passed=true,edition=BALANCE_EDITION,overhaul=BALANCE_OVERHAUL})
    end)
end
