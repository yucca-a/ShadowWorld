local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local paused,announcements=false,{}
TheNet={IsServerPaused=function()return paused end,SetServerPaused=function(_,value)paused=value end,
    Announce=function(_,text)announcements[#announcements+1]=text end}
TUNING={isCh2hm=true,DATA2HM={opensort=true},util2hm={}}
local player={IsValid=function()return true end}
local box={prefab="tacklestation2hm",components={container={openlist={[player]=true}}},replica={}}
function box:IsValid()return not self.removed end
function box:HasTag(tag)return tag=="pocketdimension_container"end
local tasks={}
TheWorld={ismastersim=true,components={exchangevariants2hm={ready=true}}}
function TheWorld:DoStaticTaskInTime(delay,fn)
    local task={delay=delay,fn=fn,Cancel=function(self)self.cancelled=true end}
    tasks[#tasks+1]=task;return task
end
local handlers={}
local scope=setmetatable({worldexchangemode="classic",worldexchangecfg=true,
    defaultbtnvalidfn=function()return true end,
    addcontainerbuttonrpc=function(name,fn)handlers[name]=fn end}, {__index=_G})
setfenv(assert(loadstring(callback_source)),scope)()
local button=setfenv(assert(loadstring(button_source)),scope)().pausebtn
check(button.text=="暂停" and button.validfn(box),"original button exists and is valid")
button.fn(box,player)
check(paused and tasks[1].delay==30 and box.cancelpausetask2hm==tasks[1],"host pauses with static 30 second timeout")
button.fn(box,player)
check(not paused and tasks[1].cancelled and not box.cancelpausetask2hm,"second click resumes and cancels timeout")
handlers.pausebtn2hm(player,box)
local timeout=box.cancelpausetask2hm
box.removed=true;timeout.fn()
check(not paused and box.cancelpausetask2hm==nil,"world timer resumes even after box removed")
box.removed=nil
for _,mode in ipairs({"xianyu","hosted","off"})do
    scope.worldexchangemode=mode;handlers.pausebtn2hm(player,box)
    check(not paused and not button.validfn(box),"pause inaccessible outside original mode")
end
scope.worldexchangemode="classic"
box.components.container.openlist[player]=nil;handlers.pausebtn2hm(player,box)
check(not paused,"closed container cannot pause server")
box.components.container.openlist[player]=true
TheWorld.components.exchangevariants2hm.ready=false;handlers.pausebtn2hm(player,box)
check(not paused,"migration cannot pause server")
TheWorld.components.exchangevariants2hm.ready=true
local sent
scope.GetModRPC=function(_,name)return name end
scope.SendModRPCToServer=function(rpc,entity)sent={rpc,entity}end
TheWorld.ismastersim=false;button.fn(box,player)
check(sent[1]=="pausebtn2hm" and sent[2]==box,"remote button routes through existing RPC")
TheWorld.ismastersim=true

-- Existing successful original exchange must also cancel the restored timeout.
local shardhandlers={}
scope.AddShardModRPCHandler=function(_,name,fn)shardhandlers[name]=fn end
scope.TUNING={EXCHANGE_MODE2HM="classic",util2hm={},isCh2hm=true}
scope.TheShard={GetShardId=function()return "1"end}
scope.TheWorld=TheWorld
function TheWorld:GetPocketDimensionContainer()return box end
setfenv(assert(loadstring(classic_source)),scope)()
handlers.pausebtn2hm(player,box)
timeout=box.cancelpausetask2hm
shardhandlers.exchangeconfirmdata2hm("2","1","shadow",nil)
check(not paused and timeout.cancelled and not box.cancelpausetask2hm,"original confirmation resumes and cancels timeout")

local ui=setmetatable({self={bottomrow={}},overflow={inst=box},container=box,widget={},doer=player,
    btnlist={pausebtn=button,exchangebtn={},upgradebtn={},privatespacebtn={}},sharkboiupdate=true,
    isshadowspace=function()return true end,pos1=1,pos2=2,pos3=3,pos4=4,
    supportchangebtnpos=function()end}, {__index=_G})
local backpack=setfenv(assert(loadstring(backpack_source)),ui)
local panel=setfenv(assert(loadstring(panel_source)),ui)
local private=setfenv(assert(loadstring(private_source)),ui)
for _,mode in ipairs({"classic","xianyu","hosted","off"})do
    for _,sort in ipairs({false,true})do
        for _,single in ipairs({false,true})do
            ui.worldexchangemode=mode;ui.worldexchangecfg=mode~="off"
            TUNING.DATA2HM.opensort=sort;TUNING.DSA_ONE_PLAYER_MODE=single
            for _,build in ipairs({backpack,panel})do
                local seen,positions={},{}
                ui.addbutton=function(_,_,_,_,name,_,index,pos)
                    local slot=index or pos
                    check(slot~=nil and not positions[slot],"buttons occupy distinct valid positions")
                    positions[slot]=true;seen[name]=slot
                end
                build()
                local expected=mode=="classic" and not single
                check((seen.pausebutton2hm~=nil)==expected,"pause shown only for original multiplayer")
                if expected then
                    check(seen.pausebutton2hm==(sort and 3 or 2),"pause follows travel")
                    check(seen.upgrade2hm==(sort and 4 or 3),"upgrade shifts after pause")
                end
                -- Private-space button shares the same native panel slots.
                if seen.upgrade2hm then positions[seen.upgrade2hm]=nil end
                private()
                check(seen.privatespacebtn2hm~=nil,"private button retained")
            end
        end
    end
end
print("Classic pause callbacks and button layout: "..n.." checks passed")
