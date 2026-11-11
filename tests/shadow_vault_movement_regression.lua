local M=require("shadowvaultmovement2hm")
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local a,b=M.Empty(),M.Empty()
local first=M.Send(a,"1","2","boot")
local second=M.Send(a,"1","2","boot")
M.Receive(b,"2",second)
check(not M.Coherent({["1"]=a,["2"]=b}),"out-of-order arrival cannot mask a missing transfer")
M.Receive(b,"2",first)
check(M.Coherent({["1"]=a,["2"]=b}),"complete contiguous native stream forms a coherent recovery cut")
check(not M.Receive(b,"2",first) and M.Coherent({["1"]=a,["2"]=b}),"duplicate arrival cannot increase the count")
check(not M.Receive(b,"3",first),"a record for another destination is rejected")
local before=deepcopy(a)
local third=M.Send(a,"1","2","boot");M.Receive(b,"2",third)
check(not M.Coherent({["1"]=before,["2"]=b}),"old source plus new destination cannot commit a duplicate inventory")
check(not M.Coherent({["1"]=a,["2"]=M.Empty()}),"new source plus old destination cannot commit lost inventory")
check(not M.Coherent({["1"]=a}),"offline destination cannot be silently omitted")
local back=M.Send(b,"2","1","return");M.Receive(a,"1",back)
check(M.Coherent({["1"]=a,["2"]=b}),"bidirectional traffic preserves exact per-stream causality")
for n=1,1000 do M.Receive(b,"2",M.Send(a,"1","2","boot")) end
check(M.Coherent({["1"]=a,["2"]=b}) and not next(b.incoming[first.stream].extra),"completed traffic compacts to a counter")
local count=0;for _ in pairs(a.outgoing) do count=count+1 end
check(count==1,"1000 crossings do not create 1000 permanent movement receipts")
-- Independent inventory oracle: captures may occur on different sides of a
-- native departure/arrival, including reordered delivery and duplicate packets.
local nodes,images,wire={},{},{}
for n=1,4 do
    local id=tostring(n);nodes[id]={movements=M.Empty(),items={[n]=true}}
    images[id]=deepcopy(nodes[id])
end
local seed,accepted=73,0
local function random(n)seed=(seed*48271)%2147483647;return seed%n+1 end
local function capture(id)images[id]=deepcopy(nodes[id])end
local function receive(index)
    local packet=table.remove(wire,index);local node=nodes[packet.to]
    if M.Receive(node.movements,packet.to,packet.move) then node.items[packet.item]=true end
    M.Receive(node.movements,packet.to,packet.move) -- repeated acknowledgement/payload
end
for step=1,600 do
    local id=tostring(random(4));local node=nodes[id]
    if random(3)==1 then
        local item=next(node.items);local target=tostring(random(4))
        if item and target~=id then
            node.items[item]=nil
            wire[#wire+1]={to=target,item=item,move=M.Send(node.movements,id,target,"run"..id)}
        end
    elseif #wire>0 then receive(random(#wire)) end
    capture(tostring(random(4)))
    if step%30==0 then
        while #wire>0 do receive(random(#wire)) end
        for n=1,4 do capture(tostring(n)) end
    end
    local vector={};for peer,image in pairs(images) do vector[peer]=image.movements end
    if M.Coherent(vector) then
        accepted=accepted+1
        local totals={}
        for _,image in pairs(images) do for item in pairs(image.items) do totals[item]=(totals[item] or 0)+1 end end
        for item=1,4 do check(totals[item]==1,"every accepted mixed-time snapshot has exactly one copy of each inventory item") end
    end
end
check(accepted>=20,"stress simulation checks both quiescent and mixed-time cuts")
print("Native movement conservation: "..checks.." checks passed")
