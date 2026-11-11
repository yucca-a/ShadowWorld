-- Persist only vault state before releasing protocol messages. This protocol
-- never asks the world or a player's migration to wait for a remote response.
local Base=require("worldexchangeprotocol2hm")
local Durable={}
function Durable.new(io,saved,journal)
    local wrapped={};for k,v in pairs(io) do wrapped[k]=v end
    local outbound={}
    wrapped.send=function(peer,m) m.v=4;outbound[#outbound+1]={peer,m} end
    wrapped.checkpoint=function() end -- every changed phase is journalled below
    local self=Base.new(wrapped,saved)
    self.mode="journal";self.inbound={};self.waitingoffers={}
    local receive,tick,start,save=self.Receive,self.Tick,self.Start,self.Save
    function self:Save()
        local data=save(self);data.version=4;data.mode="journal";return data
    end
    local persist
    local function fast()return journal.v and journal.v.native and journal.v.native.shared end
    persist=function()
        local messages=outbound;outbound={}
        local marker=self:Marker()
        journal:Flush(function(ok)
            if not ok then self:Fail("journal_write_failed");return end
            if not self.durable then self:OnSaved(marker) end
            for _,packet in ipairs(messages) do io.send(packet[1],packet[2]) end
            if fast() and not journal.busy and not journal.staging then
                if #self.inbound>0 or not self.active and #self.waitingoffers>0 then self:Tick()
                elseif self.active and io.now()>=self.retry then
                    -- Do not add a periodic world-update wait between already
                    -- durable phases. Every outgoing message still follows its
                    -- journal acknowledgement, including this fast path.
                    tick(self)
                    if #outbound>0 then persist()end
                end
            end
        end)
    end
    function self:Start(name,peer,uid)
        if not journal.ready or journal.busy or journal.staging or journal.error then return false,"busy" end
        local ok,why=start(self,name,peer,uid)
        if ok then persist() end
        return ok,why
    end
    function self:Receive(peer,m)
        if journal.error or type(m)~="table" or m.v~=4 then return end
        if fast() and journal.v.master and self.active and m.kind=="PREPARE" and m.id~=self.active.id then
            for _,offer in ipairs(self.waitingoffers)do if offer[1]==peer and offer[2].id==m.id then return end end
            if #self.waitingoffers<32 then self.waitingoffers[#self.waitingoffers+1]={peer,deepcopy(m)}end
            return
        end
        if not journal.ready or journal.busy or journal.staging then
            if #self.inbound<64 then self.inbound[#self.inbound+1]={peer,deepcopy(m)} end
            return
        end
        local decoded=deepcopy(m);decoded.v=1
        receive(self,peer,decoded)
        if fast() and self.active and io.now()>=self.retry then tick(self)end
        persist()
    end
    function self:Tick()
        if not journal.ready or journal.busy or journal.staging or journal.error then return end
        if not self.active and #self.waitingoffers>0 then
            local offer=table.remove(self.waitingoffers,1)
            local previous=journal.v.receiving_peer
            journal.v.receiving_peer=offer[1];self:Receive(offer[1],offer[2]);journal.v.receiving_peer=previous
            return
        end
        if #self.inbound>0 then
            local packet=table.remove(self.inbound,1)
            -- Lock() checks the authenticated view's origin while accepting.
            local previous=journal.v.receiving_peer
            journal.v.receiving_peer=packet[1];self:Receive(packet[1],packet[2]);journal.v.receiving_peer=previous
            return
        end
        if not self.active or io.now()<self.retry then return end
        tick(self);persist()
    end
    return self
end
return Durable
