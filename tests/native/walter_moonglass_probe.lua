local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local A={owned={},checks=0}
G.VaultAudit=A
local round="slingshotammo_moonglass_walter2hm"
local sharp="slingshotammo_moonglass"
local function emit(row)print("[VAUDIT] "..json.encode(row))end
local function check(ok,name,detail)
    A.checks=A.checks+1
    assert(ok,name..": "..tostring(detail))
end
local function spawn(name)
    local inst=assert(SpawnPrefab(name),name)
    A.owned[#A.owned+1]=inst
    return inst
end
local function activate(actor,skill)
    local updater=actor.components.skilltreeupdater
    local old=updater.skilltree.skip_validation
    updater.skilltree.skip_validation=true -- Fixture supplies skills, not XP progression.
    updater:ActivateSkill(skill,nil,true)
    updater.skilltree.skip_validation=old
    check(updater:IsActivated(skill),"native_skill_"..skill)
end
local function count(actor,name)
    local n=0
    for _,item in ipairs(actor.components.inventory:FindItems(function(item)return item.prefab==name end))do
        n=n+(item.components.stackable and item.components.stackable:StackSize()or 1)
    end
    return n
end
for _,name in ipairs({round,sharp})do
    AddPrefabPostInit(name,function(inst)
        if not TheWorld.ismastersim then return end
        local save,load=inst.OnSave,inst.OnLoad
        inst.OnSave=function(inst,data,...)
            if inst.moonammo_fixture2hm then data.moonammo_fixture2hm=inst.moonammo_fixture2hm end
            if save then return save(inst,data,...)end
        end
        inst.OnLoad=function(inst,data,...)
            if data and data.moonammo_fixture2hm then inst.moonammo_fixture2hm=data.moonammo_fixture2hm end
            if load then return load(inst,data,...)end
        end
    end)
end
AddPrefabPostInit(round.."_proj",function(inst)
    inst.entity:SetCanSleep(false)
    A.projectile=inst
    A.shots=(A.shots or 0)+1
end)
AddPrefabPostInit(round.."_proj_secondary",function(inst)
    inst.entity:SetCanSleep(false)
    A.secondary=inst;A.secondaryshots=(A.secondaryshots or 0)+1
end)
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
function A.run()
    local done=false
    local function finish(ok,err)
        if done then return end;done=true
        for i=#A.owned,1,-1 do
            local inst=A.owned[i]
            if inst:IsValid()and not inst.moonammo_fixture2hm then inst:Remove()end
        end
        emit({kind="moonammo",passed=ok,checks=A.checks,shots=A.shots or 0,
            access=MOONAMMO_ACCESS,error=not ok and tostring(err):gsub("'","")or nil})
    end
    local function safe(fn)local ok,err=pcall(fn);if not ok then finish(false,err)end end
    safe(function()
        local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
        local walter,wixie=spawn("walter"),spawn("wixie")
        walter.userid="KU_MOONAMMO_WALTER";wixie.userid="KU_MOONAMMO_WIXIE"
        for i,actor in ipairs({walter,wixie})do
            actor.Transform:SetPosition(x+(i-1)*2,0,z)
            actor.entity:SetCanSleep(false)
            actor.components.health:SetInvincible(true)
            actor.sg:GoToState("idle")
        end
        local recipe=assert(AllRecipes[round])
        check(recipe.builder_tag=="walter_moonglass2hm","walter_only_recipe_tag")
        check(recipe.builder_skill=="walter_ammo_shattershots","native_skill_requirement")
        check(recipe.numtogive==20 and recipe.ingredients[1].amount==1,"native_recipe_cost_count")
        check(recipe.atlas=="images/inventoryimages3.xml"and recipe.image==sharp..".tex","native_recipe_icon")
        walter.components.builder:UnlockRecipe(round)
        wixie.components.builder:UnlockRecipe(round)
        wixie.components.builder:UnlockRecipe(sharp)
        walter.components.builder:UnlockRecipe(sharp)
        check(not walter.components.builder:KnowsRecipe(round),"skill_lock_before_learning")
        activate(walter,"walter_ammo_shattershots")
        check(walter.components.builder:KnowsRecipe(round),"walter_can_craft_round")
        check(not wixie.components.builder:KnowsRecipe(round),"wixie_cannot_craft_walter_round")
        check(wixie.components.builder:KnowsRecipe(sharp),"wixie_keeps_spiked_recipe")
        check(not walter.components.builder:KnowsRecipe(sharp),"walter_does_not_gain_wixie_recipe")
        local material=spawn("moonglass");material.components.stackable:SetStackSize(4)
        walter.components.inventory:GiveItem(material)
        local before=count(walter,round)
        check(walter.components.builder:DoBuild(round),"native_round_crafting")
        check(count(walter,round)-before==20,"craft_yields_twenty")
        activate(walter,"walter_ammo_efficiency")
        before=count(walter,round)
        check(walter.components.builder:DoBuild(round),"native_efficient_crafting")
        check(count(walter,round)-before==30,"efficiency_yields_thirty")
        local item=walter.components.inventory:FindItem(function(item)return item.prefab==round end)
        check(item.AnimState:GetBuild()=="slingshotammo","native_round_world_build",item.AnimState:GetBuild())
        check(item.REQUIRED_SKILL=="walter_ammo_shattershots","native_ammo_skill_metadata")
        check(item.components.inventoryitem.atlasname=="images/inventoryimages3.xml","native_inventory_atlas")
        check(item.components.inventoryitem.imagename==sharp,"native_inventory_image")
        local shard=spawn(sharp)
        check(shard.AnimState:GetBuild()=="wixieammo","sharp_world_build_preserved",shard.AnimState:GetBuild())
        check(shard.prefab~=item.prefab,"distinct_prefab_identity")
        shard.components.stackable:SetStackSize(11);shard.moonammo_fixture2hm="sharp"
        shard.Transform:SetPosition(x+12,0,z)
        local saved=spawn(round);saved.components.stackable:SetStackSize(7);saved.moonammo_fixture2hm="round"
        saved.Transform:SetPosition(x+10,0,z)
        for _,source in ipairs({saved,shard})do
            local copy=spawnSaveRecord and spawnSaveRecord(source:GetSaveRecord())or G.SpawnSaveRecord(source:GetSaveRecord())
            check(copy and copy.prefab==source.prefab,"saved_identity_"..source.prefab)
            check(copy.components.stackable:StackSize()==source.components.stackable:StackSize(),"saved_stack_"..source.prefab)
            copy:Remove()
        end
        local weapon=spawn("slingshot")
        walter.components.inventory:GiveItem(weapon)
        check(BufferedAction(walter,nil,ACTIONS.EQUIP,weapon):Do(),"native_slingshot_equipped")
        local loaded=item.components.stackable:Get(3)
        check(weapon.components.container:CanTakeItemInSlot(loaded,1),"round_ammo_allowed")
        weapon.components.container:GiveItem(loaded,1)
        check(weapon.components.weapon.projectile==round.."_proj","new_round_projectile_selected")
        check(not weapon.components.container:CanTakeItemInSlot(shard,1),"spiked_ammo_still_restricted")
        local target=spawn("pigman");target.entity:SetCanSleep(false);target:StopBrain()
        target.Transform:SetPosition(x+7,0,z);target.components.health:SetMaxHealth(1000)
        local hitdamage=0
        target:ListenForEvent("attacked",function(inst,data)
            if data.attacker==walter then hitdamage=hitdamage+(data.damageresolved or data.damage or 0)end
        end)
        local action=BufferedAction(walter,target,ACTIONS.ATTACK)
        local state=walter.sg.sg.actionhandlers[ACTIONS.ATTACK].deststate(walter,action)
        check(state=="slingshot_shoot","native_attack_route",state)
        walter.bufferedaction=action;walter.sg:GoToState(state)
        TheWorld:DoTaskInTime(3,function()safe(function()
            check((A.shots or 0)>0,"native_projectile_spawned")
            check(loaded:IsValid()and loaded.components.stackable:StackSize()==2,"one_round_consumed")
            -- UM applies delayed pig/Halloween health multipliers after spawn;
            -- a pre-init absolute-health snapshot can rise despite a real hit.
            check(hitdamage>0,"native_round_hits",hitdamage)
            if not MOONAMMO_ACCESS then finish(true);return end
            local gun=spawn("slingshot_gnasher")
            walter.sg:GoToState("idle")
            local previous=walter.components.inventory:Unequip(EQUIPSLOTS.HANDS)
            if previous then previous:Remove()end
            walter.components.inventory:GiveItem(gun)
            check(BufferedAction(walter,nil,ACTIONS.EQUIP,gun):Do(),"wixie_weapon_permission_still_works")
            local spare=walter.components.inventory:FindItem(function(item)return item.prefab==round end)
            local bullets=spare.components.stackable:Get(3)
            check(gun.components.container:CanTakeItemInSlot(bullets,1),"native_round_loads_in_permitted_wixie_weapon")
            gun.components.container:GiveItem(bullets,1)
            check(gun.components.weapon.projectile==round.."_proj","wixie_weapon_keeps_round_projectile")
            local guard=require("umcompatguard2hm")
            local launch=assert(guard.Find(G.Prefabs.slingshot_gnasher.fn,"LaunchSpit")).value
            gun.powerlevel=2
            hitdamage=0
            launch(gun,walter,target)
            check(A.secondary and A.secondary.components.weapon.damage==A.secondary.ammo_def.damage*2,"secondary_damage_uses_um_power")
            TheWorld:DoTaskInTime(2,function()safe(function()
                check((A.secondaryshots or 0)>0 and hitdamage>0,"actual_um_secondary_round_hits",hitdamage)
                finish(true)
            end)end)
        end)end)
    end)
end
function A.reload()
    local ok,err=pcall(function()
        local found={}
        for _,inst in pairs(Ents)do
            if inst.moonammo_fixture2hm then found[inst.moonammo_fixture2hm]=inst end
        end
        check(found.round and found.round.prefab==round,"cold_round_identity")
        check(found.round.components.stackable:StackSize()==7,"cold_round_stack")
        check(found.round.AnimState:GetBuild()=="slingshotammo","cold_round_build")
        check(found.sharp and found.sharp.prefab==sharp,"cold_sharp_identity")
        check(found.sharp.components.stackable:StackSize()==11,"cold_sharp_stack")
        check(found.sharp.AnimState:GetBuild()=="wixieammo","cold_sharp_build")
    end)
    emit({kind="moonammo_reload",passed=ok,checks=A.checks,error=not ok and tostring(err):gsub("'","")or nil})
end
