local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local now=100;local oldclock=GetStaticTime;GetStaticTime=function()return now end
local sent={}
GetModRPC=function()return {}end
SendModRPCToServer=function(_,action,page,slot,token,session,item,amount)
    sent[#sent+1]={action=action,page=page,slot=slot,token=token,session=session,item=item,amount=amount}
end
local function cell()
    return {Hide=function(self)self.hidden=true end,Show=function(self)self.hidden=false end,
        Enable=function(self)self.enabled=true end,Disable=function(self)self.enabled=false end,
        SetTooltip=function(self,text)self.tooltip=text end,
        icon={Hide=function()end,Show=function()end,SetTexture=function()end,SetSize=function()end},
        stack={SetString=function(self,text)self.text=text end,SetSize=function()end}}
end
GetInventoryItemAtlas=function()return "images/inventoryimages.xml" end
local held={replica={stackable={StackSize=function()return 5 end}}}
local active
local p=setmetatable({owner={replica={inventory={GetActiveItem=function()return active end}}},cells={},offset=0}, {__index=VaultPanel})
p.title={SetString=function()end};p.status={SetString=function(self,text)self.text=text end}
for i=1,12 do p.cells[i]=cell()end
p.data={page="2",session="opening1",slots=12,registry={["2"]={name="Caves"}},ready=true,
    items={["1"]={prefab="goldnugget",name="Gold",count=17,token="gold_v1"}},emptytoken="empty_v1"}
p:SetStatus({mode="ready"})
p:ClickSlot(1)
check(#sent==1 and sent[1].token=="gold_v1" and sent[1].session=="opening1" and sent[1].action=="withdraw","click carries the displayed item identity and opening")
check(sent[1].amount=="cursor","left click withdraws to an empty cursor")
p:ClickSlot(1);check(#sent==1,"local click burst suppressed")
now=101;active=held;p:ClickSlot(2)
check(#sent==2 and sent[2].token=="empty_v1" and sent[2].action=="deposit","empty-slot deposit carries its master epoch")
check(sent[2].item==held and sent[2].amount==5,"deposit binds the cursor entity and displayed stack count")
p:SetStatus({mode="delivery",name="Gold",count=17,page="2",page_name="Caves"})
check(not p.cells[1].enabled and not p.cells[2].enabled and p.state.count==17,"pending delivery disables further transfers")
now=102;p:ClickSlot(1);check(#sent==2,"blocked button cannot send another transfer even if called directly")
p:SetStatus({mode="done"});check(p.cells[1].enabled,"completion restores controls")
p.data.pending={["1"]=true};p:Render()
check(not p.cells[1].enabled and p.cells[2].enabled,"master-reserved cell remains disabled independently of player status")
p.data.pending={};p:SetStatus({mode="stale"})
check(p.cells[1].enabled,"stale view permits a new choice instead of permanently locking panel")
p.data.registry["1"]={name="Master"}
p.data.registry.tackle_2={name="Caves"}
p:ChangePage(1)
check(sent[3].action=="page" and sent[3].page=="1","the travel button only cycles through pages of the same container")
now=103;active=nil;p:ClickSlot(1,true)
check(sent[4].action=="takehalf" and sent[4].amount=="cursor","the stack modifier takes half of an occupied slot")
now=104;active=held;p:ClickSlot(1,true)
check(sent[5].action=="placeone" and sent[5].token=="gold_v1","the stack modifier adds one to an occupied slot")
now=105;p:ClickSlot(2,true)
check(sent[6].action=="placeone" and sent[6].token=="empty_v1","the stack modifier places one into an empty slot")
now=106;p:ClickSlot(1)
check(sent[7].action=="place" and sent[7].item==held,"a held stack can merge or swap using the authoritative slot token")
GetStaticTime=oldclock
print("Vault panel behavior: "..checks.." checks passed (Lua widget logic)")
