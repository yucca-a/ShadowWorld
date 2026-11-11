-- Overflow remains in local custody until native item migration takes ownership.
-- Legacy player-carried parcels are accepted when upgrading older saved profiles.
local Adapter=require("shadowvaultitems2hm")
local Courier={}
function Courier.Accept(v,uid,records)
    v.travel_inbox=v.travel_inbox or {};v.travel_receipts=v.travel_receipts or {}
    for id,record in pairs(records or {}) do
        if type(id)=="string" and #id<=1500 and type(record)=="table" and type(record.page)=="string" and
            type(record.payload)=="table" and not v.travel_receipts[id] and not v.travel_inbox[id] then
            v.travel_inbox[id]={userid=uid,page=record.page,payload=deepcopy(record.payload)}
        end
    end
    Courier.Receive(v)
end
function Courier.Receive(v)
    if v.next_courier_retry and GetStaticTime()<v.next_courier_retry then return end
    for id,record in pairs(v.travel_inbox or {}) do
        if not v.rows[id] then
            local escrow=SpawnPrefab("shadowvaulttransfer2hm")
            if not escrow then return end
            v.rows[id]={userid=record.userid,page=record.page,state="delivery",escrow=escrow,portable=true,
                forward=v.delivery_routes and v.delivery_routes[record.userid]}
            local ok=Adapter.Apply(v,id,record.payload)
            if ok then
                v.travel_receipts[id]=record.userid;v.travel_inbox[id]=nil
            else
                escrow:Remove();v.rows[id]=nil
                v.next_courier_retry=GetStaticTime()+2
                -- Keep the serialized record for recovery; a prefab failure
                -- must not delete the parcel or disable character controls.
                return
            end
        end
    end
end
function Courier.Departing(v,uid,destination)
    v.delivery_routes=v.delivery_routes or {};v.delivery_routes[uid]=tostring(destination)
    for _,row in pairs(v.rows) do
        if row.userid==uid then row.forward=tostring(destination) end
    end
end
function Courier.Here(v,uid)
    if v.delivery_routes then v.delivery_routes[uid]=nil end
    for _,row in pairs(v.rows) do if row.userid==uid then row.forward=nil end end
end
function Courier.Forward(v)
    for name,row in pairs(v.rows) do
        if row.state=="delivery" and row.forward then
            local item=row.escrow.components.container.slots[1]
            local present=false
            for _,p in ipairs(AllPlayers) do if p.userid==row.userid then present=true;break end end
            if not item or not item:IsValid() then row.escrow:Remove();v.rows[name]=nil
            elseif not present and Shard_IsWorldAvailable(row.forward) then
                if item and item:IsValid() then
                    local payload=Adapter.Snapshot(v,name)
                    if payload then
                        Shard_CreateTransaction_TransferInventoryItem(row.forward,item,{
                            worldid=v.id,sessionid=v.session,
                            shadowvault_parcel={id="forward:"..v.session..":"..name,userid=row.userid,page=row.page,layout=payload.layout},
                        })
                    end
                end
            end
        end
    end
end
function Courier.Finalize(v,payload)
    local data=payload.data
    local migration=data and data.migrationdata
    local parcel=migration and migration.shadowvault_parcel
    if not parcel then return end
    if type(parcel.id)~="string" or type(parcel.userid)~="string" or type(parcel.page)~="string" or
        type(parcel.layout)~="string" or type(data.item_record)~="table" then return false end
    Courier.Accept(v,parcel.userid,{[parcel.id]={page=parcel.page,payload={
        items={[1]=data.item_record},session=migration.sessionid,layout=parcel.layout}}})
    data.item_record,data.migrationdata=nil,nil
    return true
end
return Courier
