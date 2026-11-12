local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row) print("[VAUDIT] "..json.encode(row)) end
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
G.VaultAudit={}
function G.VaultAudit.combat_rewards()
    local rows={}
    local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
    local function spawn(name)
        local inst=SpawnPrefab(name)
        inst.Transform:SetPosition(x,y,z)
        inst.entity:SetCanSleep(false)
        inst:StopBrain()
        return inst
    end
    local function equip(player,name)
        local item=spawn(name)
        player.components.inventory:GiveItem(item)
        player.components.inventory:Equip(item)
        return item
    end
    local function attack(player,target,weapon)
        player.components.combat.laststartattacktime=-1000
        player.components.combat:DoAttack(target,weapon,nil,nil,nil,10)
    end
    local function record(row)rows[#rows+1]=row;row.kind="combat_reward_case";emit(row)end
    TheWorld:StartThread(function()
        if WITH_WATHOM then
            local player=spawn("wathom")
            player.userid="KU_COMBAT_REWARDS_WATHOM"
            player:AddComponent("playercontroller")
            player.components.hunger:SetRate(0)
            local cow,bell=spawn("beefalo"),spawn("beef_bell")
            cow.components.domesticatable:DeltaDomestication(1,player)
            cow.components.domesticatable:SetDomesticated(true)
            cow.components.domesticatable:DeltaObedience(1)
            Sleep(.2)
            assert(bell.components.useabletargeteditem:StartUsingItem(cow,player))
            cow.components.writeable:Write(player,"Combat reward test")
            assert(bell:GetBeefalo()==cow and cow.components.follower:GetLeader()==bell)
            player.components.inventory:GiveItem(bell)
            for _, weaponname in ipairs({"batbat","shadow_battleaxe","spear"})do
                local weapon=equip(player,weaponname)
                Sleep(.1)
                if weaponname=="shadow_battleaxe"then weapon._lifesteal=3 end
                player.components.health:SetCurrentHealth(player.components.health.maxhealth*.5)
                player.components.sanity:SetPercent(.7)
                player.components.adrenaline:SetPercent(.3)
                local hp,san=player.components.health.currenthealth,player.components.sanity.current
                local cowhp,amp=cow.components.health.currenthealth,player.components.adrenaline:GetPercent()
                local uses=weapon.components.finiteuses and weapon.components.finiteuses:GetUses()
                attack(player,cow,weapon)
                record({case="protected_cow_"..weaponname,healing=player.components.health.currenthealth-hp,
                    sanity=player.components.sanity.current-san,damage=cowhp-cow.components.health.currenthealth,
                    adrenaline=player.components.adrenaline:GetPercent()-amp,
                    wear=uses and uses-weapon.components.finiteuses:GetUses()or nil})
                if weaponname=="shadow_battleaxe"then
                    player.components.health:SetCurrentHealth(hp)
                    local repeatedhp=cow.components.health.currenthealth
                    for i=1,5 do attack(player,cow,weapon) end
                    record({case="protected_cow_stacked_axe",healing=player.components.health.currenthealth-hp,
                        damage=repeatedhp-cow.components.health.currenthealth,
                        adrenaline=player.components.adrenaline:GetPercent()-amp,buffed=cow._sba_buff2hm==true})
                end
                if weaponname=="shadow_battleaxe"then
                    local cowhp=cow.components.health.currenthealth
                    Sleep(1.2)
                    record({case="protected_cow_axe_dot",healing=0,damage=cowhp-cow.components.health.currenthealth,adrenaline=0})
                end
                local enemy=spawn("pigman")
                player.components.health:SetCurrentHealth(hp)
                local enemyhp=enemy.components.health.currenthealth
                attack(player,enemy,weapon)
                record({case="enemy_"..weaponname,healing=player.components.health.currenthealth-hp,damage=enemyhp-enemy.components.health.currenthealth})
                enemy:Remove()
            end
            local spear=equip(player,"spear")
            Sleep(.1)
            for _,target in ipairs({cow,spawn("pigman")})do
                player.Transform:SetPosition(x,y,z)
                target.Transform:SetPosition(x+1,y,z)
                player.components.adrenaline:SetPercent(.3)
                if player.adrenalresume then player.adrenalresume:Cancel();player.adrenalresume=nil end
                player.adrenalpause=false
                local gain,hits=0,0
                local onamp=function(_,data)gain=gain+math.max(0,data.newpercent-data.oldpercent)end
                local onattack=function()hits=hits+1 end
                player:ListenForEvent("adrenalinedelta",onamp)
                player:ListenForEvent("onattackother",onattack)
                local hp=target.components.health.currenthealth
                player.bufferedaction=BufferedAction(player,target,ACTIONS.ATTACK,spear)
                player.sg:GoToState("wathomleap")
                Sleep(1.2)
                record({case=target==cow and "protected_cow_leap"or"enemy_leap",healing=0,
                    damage=hp-target.components.health.currenthealth,adrenaline=gain,hits=hits,
                    paused=player.adrenalpause or false})
                player:RemoveEventCallback("adrenalinedelta",onamp)
                player:RemoveEventCallback("onattackother",onattack)
            end
        end
        local singer=spawn("wathgrithr")
        singer.components.hunger:SetRate(0)
        local inspiration=singer.components.singinginspiration
        inspiration:SetPercent(.95)
        for _, name in ipairs({"battlesong_healthgain","battlesong_sanitygain"})do
            local song=spawn(name)
            inspiration:AddSong(song.songdata,false,song)
            singer:AddDebuff(song.songdata.NAME,song.songdata.NAME)
        end
        local spear=equip(singer,"spear")
        local deck=spawn("deck_of_cards")
        local enemy=spawn("pigman")
        Sleep(.2)
        for _,target in ipairs({deck,enemy})do
            for _,stored in ipairs({false,true})do
                singer.components.health:SetCurrentHealth(singer.components.health.maxhealth*.5)
                singer.components.sanity:SetPercent(.5)
                singer.components.combat:SetTarget(stored and enemy or nil)
                local hp,san=singer.components.health.currenthealth,singer.components.sanity.current
                attack(singer,target,spear)
                record({case="songs_"..target.prefab.."_"..tostring(stored),healing=singer.components.health.currenthealth-hp,
                    sanity=singer.components.sanity.current-san,shuffles=deck._hit_recently_count})
            end
        end
        local player=spawn("wilson")
        player.components.hunger:SetRate(0)
        local shield=equip(player,"shieldofterror")
        shield.components.armor:SetPercent(.8)
        local card=spawn("playing_card")
        local canfeed=shield.components.eater:CanEat(deck)or shield.components.eater:CanEat(card)or false
        for _,target in ipairs({deck,spawn("pigman")})do
            local condition=shield.components.armor.condition
            local targethp=target.components.health.currenthealth
            for i=1,6 do attack(player,target,shield);Sleep(.4)end
            record({case="shield_"..target.prefab,condition=shield.components.armor.condition-condition,
                targetdamage=targethp-target.components.health.currenthealth,valid=target:IsValid(),canfeed=canfeed,
                bites=shield._hitcount2hm or 0})
        end
        emit({kind="combat_rewards",passed=true,cases=#rows})
    end)
end
