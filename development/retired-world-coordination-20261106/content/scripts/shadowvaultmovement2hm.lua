-- Observe native transfers without asking another shard for permission.
-- Each boot/destination stream uses a contiguous sequence. Snapshot validation
-- compares the exact received prefix, not merely totals (out-of-order arrivals
-- must never mask a different missing transfer). Completed traffic costs one
-- counter per stream rather than one permanent receipt per player journey.
local Movement={}
function Movement.Empty() return {outgoing={},incoming={},revision=0} end
function Movement.Send(state,source,destination,boot)
    local key=source.."/"..boot.."/"..destination
    local row=state.outgoing[key] or {source=source,destination=destination,count=0}
    state.outgoing[key]=row;row.count=row.count+1
    state.revision=(state.revision or 0)+1
    return {stream=key,source=source,destination=destination,sequence=row.count}
end
function Movement.Token(m) return m.stream.."/"..m.sequence end
function Movement.Receive(state,id,m)
    if type(m)~="table" or type(m.stream)~="string" or #m.stream>300 or
        type(m.source)~="string" or m.destination~=id or type(m.sequence)~="number" or
        m.sequence<1 or m.sequence%1~=0 then return false end
    local row=state.incoming[m.stream]
    if not row then
        row={source=m.source,destination=id,count=0,extra={}};state.incoming[m.stream]=row
    end
    if row.source~=m.source or row.destination~=id then return false end
    if m.sequence<=row.count or row.extra[tostring(m.sequence)] then return false end
    state.revision=(state.revision or 0)+1
    row.extra[tostring(m.sequence)]=true
    while row.extra[tostring(row.count+1)] do
        row.extra[tostring(row.count+1)]=nil;row.count=row.count+1
    end
    return true
end
function Movement.Coherent(images)
    local sent,received={},{}
    for owner,image in pairs(images) do
        if type(image)~="table" or type(image.outgoing)~="table" or type(image.incoming)~="table" then return false end
        for key,row in pairs(image.outgoing) do
            if type(row)~="table" or row.source~=owner or type(row.count)~="number" or sent[key] then return false end
            sent[key]=row
        end
        for key,row in pairs(image.incoming) do
            if type(row)~="table" or row.destination~=owner or type(row.count)~="number" or
                type(row.extra)~="table" or next(row.extra) or received[key] then return false end
            received[key]=row
        end
    end
    for key,row in pairs(sent) do
        local other=received[key]
        if not other or row.count~=other.count or row.source~=other.source or row.destination~=other.destination then return false end
    end
    for key in pairs(received) do if not sent[key] then return false end end
    return true
end
return Movement
