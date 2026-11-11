local Core=require("shadowvaultsnapshotcore2hm")
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function cluster(size,drop)
    local c={nodes={},wire={},now=0,saves=0,drop=drop,online={}}
    for n=1,size do
        local id=tostring(n);local base="base"..id
        local store={state={cuts={[base]={id=base,serial=1,committed=true,refs={[id]={session="s"..id,id=base}}}},current=base,nextserial=1}}
        function store:Update(change,cb) local s=deepcopy(self.state);change(s);self.state=s;cb(true) end
        local node={id=id,store=store,boot="boot"..id,captures=0};c.nodes[id]=node;c.online[id]=true
        local io={id=id,session="s"..id,master=id=="1",masterid="1",boot=node.boot,
            now=function()return c.now end,
            connected=function(peer,boot)return c.online[peer] and c.nodes[peer].boot==boot end,
            idle=function()return not node.busy end,
            movement_revision=function()return node.movements and node.movements.revision or 0 end,
            fail=function(why)node.error=why end,
            restart=function(target)node.restart=target end,
            send=function(peer,m)c.wire[#c.wire+1]={from=id,to=peer,m=deepcopy(m)}end,
            capture=function(cut,cb)
                c.saves=c.saves+1;node.captures=node.captures+1
                node.store.state.cuts[cut.id]=deepcopy(cut);node.store.state.nextserial=cut.serial
                node.store.state.cuts[cut.id].movements=deepcopy(node.movements)
                if node.failcapture then cb(false,"injected_write_error") else cb(true) end
            end}
        node.io=io;node.core=Core.new(io,store,base)
    end
    function c:connect(id)
        local a,b=self.nodes["1"],self.nodes[id]
        a.core:Connected(id,{session="s"..id,boot=b.boot})
        b.core:Connected("1",{session="s1",boot=a.boot})
    end
    function c:steps(n)
        for _=1,n do
            self.now=self.now+.1
            for id,node in pairs(self.nodes) do if self.online[id] then node.core:Tick() end end
            local wire=self.wire;self.wire={}
            for _,p in ipairs(wire) do
                if self.online[p.to] and not (self.drop and self.drop(p)) then self.nodes[p.to].core:Receive(p.from,p.m) end
            end
        end
    end
    for n=2,size do c:connect(tostring(n)) end
    c:steps(60)
    return c
end
local c=cluster(4)
for id,n in pairs(c.nodes) do check(n.core.phase=="ready","four worlds join without requesting any save: "..id) end
check(c.saves==0,"handshake and initialization never invoke world capture")
local master=c.nodes["1"].core
for _=1,1000 do
    check(master:CanExchange("2"),"runtime transactions allowed between saves")
    master:Dirty("2")
end
c:steps(100)
check(c.saves==0,"1000 runtime accesses do not request a world save")
local completed=0;master:Request(function()completed=completed+1 end)
c:steps(100)
check(c.saves==4 and completed==1,"one explicit save captures each participating world once")
local shared=master.loaded
for id,n in pairs(c.nodes) do check(n.core.loaded==shared and n.core.phase=="ready","same saved transaction history: "..id) end
c.online["2"]=false;master:Disconnected("2")
master:Request();c:steps(100)
check(c.saves==7 and master.phase=="ready","offline clean world does not block normal save")
check(master.refs["2"].id==shared,"offline world's last verified image remains referenced")
c.online["2"]=true;c:connect("2");c:steps(60)
check(c.nodes["2"].core:CanExchange("1"),"offline world rejoins a newer master without loading other absent worlds")
master:Dirty("2");c.nodes["2"].boot="newboot";c:connect("2")
check(c.nodes["1"].restart==master.loaded,"lost unsaved participant forces recovery before accepting its old inventory")

local d=cluster(2,function(p)return p.m.op=="COMMIT"end)
d.nodes["1"].core:Request();d:steps(100)
local root=d.nodes["1"].core
check(root.phase=="ready" and d.nodes["2"].core.phase=="prepared","lost commit leaves durable receiver image awaiting decision")
check(d.nodes["2"].store.state.current=="base2","prepared native save is not mistaken for a committed image")
d.drop=nil;d:steps(100)
check(d.nodes["2"].core.loaded==root.loaded,"lost commit retry completes without another world capture")
check(d.saves==2,"commit retries only send metadata")
local committed=d.nodes["1"].core.committed
d.nodes["2"].core:Receive("1",{vault=3,kind="SNAPSHOT",op="FREEZE",id=committed.id,serial=committed.serial,
    generation=committed.generation,participants=committed.participants,refs=committed.refs})
d:steps(30)
check(d.nodes["2"].core.phase=="ready" and d.saves==2,"delayed freeze cannot reopen a completed save")

local e=cluster(2,function(p)return p.m.op=="PREPARED"end)
e.nodes["1"].core:Request();e:steps(100)
check(e.nodes["1"].store.state.current=="base1","master cannot commit with missing peer preparation evidence")
check(e.nodes["1"].core.phase=="prepared","uncommitted native image remains recoverable from its parent")
e.nodes["1"].core:Disconnected("2");e.nodes["2"].core:Disconnected("1")
e.drop=nil;e:connect("2");e:steps(100)
check(e.nodes["1"].core.phase=="ready" and e.nodes["2"].core.phase=="ready","same-boot reconnect resumes the interrupted save phase")
local peerphase=e.nodes["2"].core.phase
e.nodes["2"].core:Disconnected("3")
check(e.nodes["2"].core.phase==peerphase,"another secondary going offline cannot change this shard's readiness")
local f=cluster(2);f.nodes["2"].failcapture=true
f.nodes["1"].core:Request();f:steps(100)
check(f.nodes["2"].error=="injected_write_error" and f.nodes["1"].store.state.current=="base1","failed persistence cannot become a committed recovery point")
print("Vault normal-save snapshots: "..checks.." checks passed")
local g=cluster(4,function(p)return p.m.op=="CAPTURE"end)
local root=g.nodes["1"].core
root:Request();g:steps(100)
local abandoned=deepcopy(root.pending)
check(root.phase=="prepared" and g.nodes["2"].core.phase=="frozen","save is waiting for peers before travel")
g.nodes["1"].io.travelidle=function()return false end
check(root:YieldForTravel() and root.phase=="ready","native travel can yield a prepared but uncommitted save")
g.drop=function(p)return p.to=="4"end;g.online["4"]=false;g:steps(30)
check(root.phase=="ready" and g.nodes["2"].core.phase=="ready" and g.nodes["3"].core.phase=="ready",
    "an unrelated lost shard cannot hold the active travel endpoints frozen")
g.nodes["2"].core:Receive("1",{vault=3,kind="SNAPSHOT",op="FREEZE",id=abandoned.id,serial=abandoned.serial,
    generation=abandoned.generation,participants=abandoned.participants,refs=abandoned.refs})
check(g.nodes["2"].core.phase=="ready","late freeze for an abandoned attempt cannot block travel again")
g.drop=nil;g.online["4"]=true;g:steps(30);g.nodes["1"].io.travelidle=function()return true end;g:steps(100)
check(root.phase=="ready" and root.loaded~=abandoned.id and root.store.state.cuts[abandoned.id].committed~=true,
    "save retries with a new identity after travel; abandoned image is never committed")
print("Vault travel-priority saves: 5 checks passed")
local M=require("shadowvaultmovement2hm")
local h=cluster(2)
local sender,receiver=h.nodes["2"],h.nodes["1"]
sender.movements=M.Empty();receiver.movements=M.Empty()
local move=M.Send(sender.movements,"2","1","native")
receiver.core:Request();h:steps(50)
check(receiver.store.state.current=="base1","missing arrival never commits an inconsistent save")
local writes=h.saves;h:steps(100)
check(h.saves==writes,"missing native arrival cannot cause repeated whole-world writes")
M.Receive(receiver.movements,"1",move);h:steps(100)
check(receiver.core.phase=="ready" and receiver.store.state.current~="base1","background save retries after native arrival without a player grant")
local current=receiver.core.loaded
h.nodes["2"].boot="restarted_after_lost_mod_notifications";h:connect("2")
check(receiver.restart==current,"native movements require recovery even when a restarted peer sent no Dirty RPC")
print("Native-only travel snapshot safety: 4 checks passed")
local j=cluster(2);local root=j.nodes["1"].core
root:Connected("2",{session="s2",boot="coordinated_recovery",recovery_parent=root.io.boot,recovery_cut=root.refs["2"].id})
check(not j.nodes["1"].restart,"a peer recovering under this master's current boot cannot trigger a restart cascade")
root:Connected("2",{session="s2",boot="later_unplanned_restart"})
check(j.nodes["1"].restart==root.loaded,"recovery exemption applies only to the one proven aligned boot")
print("Recovery boot identity: 2 checks passed")
local k=cluster(4,function(p)return p.from=="4" and p.m.op=="DRAINED"end)
local root=k.nodes["1"].core;local old=root.refs["4"].id
root:Request();k:steps(30)
check(root.pending and root.phase=="frozen","capture can race native disconnect notification")
k.online["4"]=false;root:Disconnected("4");k.drop=nil;k:steps(100)
check(root.phase=="ready" and root.refs["4"].id==old and root.loaded~=old,
    "late disconnect retries the save while retaining the offline shard's older reference")
print("Save/disconnect race: 2 checks passed")
