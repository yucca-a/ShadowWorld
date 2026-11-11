function A.health_cause()
    local source=CreateEntity()
    source.prefab="unnamed_health_source_audit2hm"
    source.always_wet_prefix=true
    local direct,errorname=pcall(source.GetDisplayName,source)
    local rows={}
    for _,method in ipairs({"DoDelta","SetPercent","SetVal"})do
        local victim=SpawnPrefab("pigman")
        local h=victim.components.health
        h:SetInvincible(false)
        local maximum=h.maxhealth
        local eventcause
        victim:ListenForEvent("healthdelta",function(_,data)eventcause=data.cause end)
        if method=="DoDelta"then h:DoDelta(-maximum*.25,false,source)
        elseif method=="SetPercent"then h:SetPercent(.75,false,source)
        else h:SetVal(maximum*.75,source)end
        rows[#rows+1]={method=method,maximum=maximum,current=h.currenthealth,cause=eventcause}
        victim:Remove()
    end
    source:Remove()
    -- The engine JSON encoder escapes apostrophes as \\' (not valid JSON).
    -- Emit the diagnostic class without the quoted local-variable name.
    emit({kind="health_cause",native_name_crashed=not direct,
        native_error=tostring(errorname):match("attempt to concatenate")or "other",rows=rows})
end
