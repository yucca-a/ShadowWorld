local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require('json')
local function emit(row)print('[VAUDIT] '..json.encode(row))end
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind='ready'})end)end)
G.VaultAudit={}
function G.VaultAudit.moonstorm_goggles()
    local p=SpawnPrefab('wilson');p.userid='KU_MOON_GOGGLES_TEST'
    p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
    local inv=p.components.inventory;inv:Open()
    local hat,tool,moon=SpawnPrefab('antlionhat'),SpawnPrefab('axe'),SpawnPrefab('moonstorm_goggleshat')
    local c=hat.components.container
    local storm=STORM_TYPES.NONE
    local watcher,vision=p.components.stormwatcher,p.components.playervision
    watcher.GetCurrentStorm=function()return storm end
    p:StopUpdatingComponent(watcher)
    local function setstorm(s)
        storm=s;watcher.currentstorm=s;watcher.stormlevel=s==STORM_TYPES.MOONSTORM and 1 or 0
        p.components.moonstormwatcher:UpdateMoonstormLevel()
    end
    local rows,checks={},0
    local function check(ok,why)checks=checks+1;assert(ok,why)end
    local function case(name,fn)
        local ok,err=xpcall(fn,tostring);rows[#rows+1]={name=name,passed=ok,error=not ok and err or nil}
    end
    p:StartThread(function()
        case('prepare_real_helm_tool',function()
            check(c~=nil and hat:HasTag('goggles')and not hat:HasTag('moonstormgoggles'),'real helm has ordinary goggles and container')
            check(c:GiveItem(tool,1),'put real tool into helm');inv:Equip(hat)
            hat.components.autoterraformer:StopTerraforming()
        end)
        Sleep(.25)
        case('outside_protection',function()check(vision:HasGoggleVision(),'ordinary goggles work outside')end)
        setstorm(STORM_TYPES.MOONSTORM)
        Sleep(.25)
        case('enter_storm_keep_helm',function()
            check(inv:GetEquippedItem(EQUIPSLOTS.HEAD)==hat,'head remains equipped after delayed storm callback')
            check(c:GetItemInSlot(1)==tool and tool:IsValid(),'tool remains in the original helm')
            check(not vision:HasGoggleVision(),'ordinary goggles protection disabled')
            check(p.components.locomotor:GetExternalSpeedMultiplier(p,'moonstorm')==TUNING.MOONSTORM_SPEED_MOD,'native moonstorm slowing applies')
        end)
        case('take_tool_while_wearing_in_storm',function()
            c:Open(p);check(c:IsOpenedBy(p),'helm container can be opened in storm')
            c:MoveItemFromAllOfSlot(1,p,p)
            check(c:GetItemInSlot(1)==nil and tool.components.inventoryitem.owner==p,'native quick take retrieves real tool into inventory')
            check(inv:GetEquippedItem(EQUIPSLOTS.HEAD)==hat,'retrieving tool keeps helm equipped')
            inv:RemoveItem(tool,true);check(c:GiveItem(tool,1),'tool can return to helm')
            inv:Unequip(EQUIPSLOTS.HEAD);inv:Equip(hat);hat.components.autoterraformer:StopTerraforming()
        end)
        Sleep(.25)
        case('equip_ordinary_inside_storm',function()
            check(inv:GetEquippedItem(EQUIPSLOTS.HEAD)==hat and c:GetItemInSlot(1)==tool,'ordinary helm can be equipped inside storm with contents')
            check(not vision:HasGoggleVision(),'re-equipping does not grant moon protection')
            inv:Unequip(EQUIPSLOTS.HEAD);inv:Equip(moon)
        end)
        Sleep(.25)
        case('dedicated_moon_goggles',function()
            check(inv:GetEquippedItem(EQUIPSLOTS.HEAD)==moon and vision:HasGoggleVision(),'moon goggles remain effective')
            check((p.components.locomotor:GetExternalSpeedMultiplier(p,'moonstorm')or 1)==1,'native moon goggles remove slowing')
            inv:Unequip(EQUIPSLOTS.HEAD);inv:Equip(hat);hat.components.autoterraformer:StopTerraforming()
        end)
        Sleep(.25)
        setstorm(STORM_TYPES.NONE)
        case('leave_storm_restore',function()
            check(inv:GetEquippedItem(EQUIPSLOTS.HEAD)==hat and vision:HasGoggleVision(),'ordinary helm protection restored without re-equipping on exit')
            check(c:GetItemInSlot(1)==tool,'tool identity and slot preserved across storm and equipment changes')
        end)
        local passed=true;for _,r in ipairs(rows)do passed=passed and r.passed end
        for _,item in ipairs({p,hat,moon,tool})do if item:IsValid()then item:Remove()end end
        emit({kind='moonstorm_goggles',passed=passed,checks=checks,cases=rows,
            limitation='Real entities and native callbacks; storm state is injected on this test player, not a generated storm area.'})
    end)
end
