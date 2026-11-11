AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated electrical test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoTaskInTime(2, function()
        local encode = require("json").encode
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local singer = SpawnPrefab("wathgrithr")
        singer.userid = "KU_WIGRECOVERY"
        singer.entity:SetCanSleep(false)
        singer.Transform:SetPosition(x,0,z)
        local updater = singer.components.skilltreeupdater
        updater:SetSkipValidation(true)
        local definitions = require("prefabs/skilltree_defs").SKILLTREE_DEFS.wathgrithr
        local activated = 0
        for name, def in pairs(definitions) do
            if not def.lock_open and not name:find("shadow",1,true) then
                updater:ActivateSkill(name,nil,true)
                activated = activated + 1
            end
        end
        updater:SetSkipValidation(false)
        local songs = {}
        local inspiration = singer.components.singinginspiration
        inspiration:SetPercent(.95)
        for _, name in ipairs({"battlesong_healthgain","battlesong_sanitygain"}) do
            local item = SpawnPrefab(name)
            inspiration:AddSong(item.songdata,false,item)
            singer:AddDebuff(item.songdata.NAME,item.songdata.NAME)
            songs[#songs+1] = item.songdata.NAME
        end
        local weapon = SpawnPrefab("spear_wathgrithr")
        singer.components.inventory:GiveItem(weapon)
        singer.components.inventory:Equip(weapon)
        singer.components.hunger:SetPercent(.5)
        singer.components.combat:SetAttackPeriod(0)
        local hitcount = 0
        singer:ListenForEvent("onattackother",function() hitcount=hitcount+1 end)
        print("[ELECTRICAL] WIG_SETUP",encode({skills=activated,lunar=singer:HasTag("player_lunar_aligned"),
            battleborn_health=singer.components.battleborn.health_enabled,
            battleborn_sanity=singer.components.battleborn.sanity_enabled,
            health_song=singer.components.debuffable:HasDebuff(songs[1]),sanity_song=singer.components.debuffable:HasDebuff(songs[2])}))
        local passive = SpawnPrefab("rabbit")
        passive.Transform:SetPosition(x+2,0,z)
        local targets = {}
        for _, name in ipairs({"antlion","bearger"}) do
            local target = SpawnPrefab(name)
            target.Transform:SetPosition(x+1,0,z)
            target.entity:SetCanSleep(false)
            if target.StartCombat then target:StartCombat(singer) end
            if target.StopBrain then target:StopBrain() end
            if target.sg then target.sg:GoToState("idle") end
            assert(target.components.health and target.components.combat,name.." must be in combat mode")
            target.components.health:SetMaxHealth(1000000)
            target.components.combat:SetTarget(nil)
            targets[#targets+1] = target
        end
        local function attack(target,stored,label)
            singer.components.health:SetCurrentHealth(singer.components.health.maxhealth*.5)
            singer.components.sanity:SetPercent(.5)
            singer.components.combat:SetTarget(stored)
            singer.components.combat.laststartattacktime = -1000
            local hp,san,hits = singer.components.health.currenthealth,singer.components.sanity.current,hitcount
            local enemyhp = target.components.health.currenthealth
            singer.components.combat:DoAttack(target,weapon,nil,nil,nil,10)
            print("[ELECTRICAL] WIG_CASE",encode({label=label,target=target.prefab,stored=stored and stored.prefab or "nil",
                defaultdamage=target.components.combat.defaultdamage,health=singer.components.health.currenthealth-hp,
                sanity=singer.components.sanity.current-san,hits=hitcount-hits,damage=enemyhp-target.components.health.currenthealth,
                health_song=singer.components.debuffable:HasDebuff(songs[1]),sanity_song=singer.components.debuffable:HasDebuff(songs[2])}))
        end
        for _,target in ipairs(targets) do
            attack(target,target,"matching_target")
            attack(target,nil,"no_stored_target")
            attack(target,passive,"stale_passive_target")
        end
        local bag = SpawnPrefab("punchingbag")
        if bag then
            bag.Transform:SetPosition(x+2,0,z)
            attack(targets[2],targets[2],"near_punchingbag")
            bag:Remove()
        end
        print("[ELECTRICAL] ALL_PASS audit recorded")
        c_shutdown(false)
    end)
end)
