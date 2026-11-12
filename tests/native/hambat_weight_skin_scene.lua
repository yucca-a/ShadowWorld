local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row)print("[VAUDIT] "..json.encode(row))end
AddSimPostInit(function()if TheWorld.ismastersim then TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end end)
if not TheNet:IsDedicated()then
 AddSimPostInit(function()
  TheWorld:DoPeriodicTask(1,function()
   if ThePlayer then
    TheCamera:SetDistance(22)
    TheCamera:SetHeadingTarget(90)
    ThePlayer.components.locomotor:Stop()
   end
  end)
 end)
end
AddClientModRPCHandler(modname,"SkinPreview",function()
 local px,py,pz=ThePlayer.Transform:GetWorldPosition()
 local skins={false,"hambat_nautical","hambat_potroast","hambat_spiralcut"}
 for _,actor in ipairs(AllPlayers)do
  if actor~=ThePlayer then
   local x,y,z=actor.Transform:GetWorldPosition()
   local col=math.floor((x-px)/4+2.5+.5)
   local skin=skins[col]
   if skin then
    local symbol=z>pz and "swap_ham_bat_2_50"or"swap_ham_bat_1_00"
    actor.AnimState:OverrideSkinSymbol("swap_object",skin.."_weighted2hm",symbol)
   end
   actor.AnimState:SetLightOverride(.6)
  end
 end
 print("[HAMRENDER] Preview applied")
end)
G.VaultAudit={}
function G.VaultAudit.skin_scene()
 local player=AllPlayers[1]
 assert(player,"rendered client must join first")
 local x,y,z=player.Transform:GetWorldPosition()
 TheWorld:PushEvent("ms_setclocksegs",{day=16,dusk=0,night=0})
 TheWorld:PushEvent("ms_setseason","autumn")
 for _,inst in ipairs(TheSim:FindEntities(x,y,z,18))do
  if inst~=player and not inst:HasTag("CLASSIFIED")and not inst:HasTag("INLIMBO")and not inst:HasTag("player")and inst.persists then inst:Remove()end
 end
 player.components.health:SetInvincible(true)
 player.components.hunger:SetRate(0)
 player:Hide()
 for row,weight in ipairs({1,10})do
  for col,skin in ipairs({false,"hambat_nautical","hambat_potroast","hambat_spiralcut"})do
   local actor=SpawnPrefab("webber")
   actor.entity:SetCanSleep(false)
   actor.Transform:SetPosition(x+(col-2.5)*4,y,z+(row-1.5)*6)
   actor.Transform:SetRotation(0)
   actor.components.health:SetInvincible(true)
   actor.components.hunger:SetRate(0)
   local hat=SpawnPrefab("tophat")
   actor.components.inventory:GiveItem(hat);actor.components.inventory:Equip(hat)
   local item=SpawnPrefab("hambat",skin or nil,nil,player.userid)
   local applied=item:GetSkinBuild()
   item.components.hambat2hm.weight=weight
   actor.components.inventory:GiveItem(item);actor.components.inventory:Equip(item)
   actor.sg:GoToState("idle");actor.AnimState:Show("ARM_carry");actor.AnimState:Hide("ARM_normal")
   emit({kind="skin_actor",row=row,column=col,weight=weight,requested=skin,applied=applied or false,
    weighted=applied and require("hambatweightedskins2hm")[applied]or false,guid=actor.GUID})
  end
 end
 TheWorld:DoTaskInTime(2,function()SendModRPCToClient(CLIENT_MOD_RPC[modname].SkinPreview,player.userid)end)
 emit({kind="skin_scene",players=#AllPlayers})
end
