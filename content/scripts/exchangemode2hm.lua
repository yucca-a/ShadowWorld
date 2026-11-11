local Mode={}
function Mode.Normalize(value)
    -- New option values distinguish a deliberate selection from an old save's
    -- default. Every legacy value migrates to the original mechanism once.
    if value=="exchange_v1_off" then return "off" end
    if value=="exchange_v1_xianyu" then return "xianyu" end
    if value=="exchange_v1_nexus" then return "hosted" end
    return "classic"
end
-- Storage receives the already-normalized runtime mode, never a config value.
function Mode.Storage(value)
    return (value=="hosted" or value=="xianyu") and value or "classic"
end
return Mode
