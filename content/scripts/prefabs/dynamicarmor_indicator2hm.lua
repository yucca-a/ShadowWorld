-- Invisible network carrier. ColourAdder composes this gentle body tint with
-- native hit/mouse highlights and other effects; it never replaces a skin.
local function Clear(inst)
    local target=inst._painted
    if target and target:IsValid() and target.components.colouradder then
        target.components.colouradder:PopColour(inst)
    end
    inst._painted=nil
end

local function Paint(inst)
    local target=inst._target:value()
    if target~=inst._painted then Clear(inst) end
    if not target or not target:IsValid() or not target.AnimState then return end
    if not target.components.colouradder then target:AddComponent("colouradder") end
    inst._painted=target
    local goal=inst._strength:value()/255
    inst._shown=(inst._shown or 0)+(goal-(inst._shown or 0))*.25
    -- Continuous, low-intensity red feedback: no animation, bloom, light or sound.
    local red=.16*inst._shown
    target.components.colouradder:PushColour(inst,red,red*.08,red*.04,0)
end

local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists=false
    inst._target=net_entity(inst.GUID,"dynamicarmor_indicator2hm.target")
    inst._strength=net_byte(inst.GUID,"dynamicarmor_indicator2hm.strength")
    inst.entity:SetPristine()
    if not TheNet:IsDedicated() then
        inst:DoPeriodicTask(FRAMES*2,Paint)
        inst.OnRemoveEntity=Clear
    end
    if not TheWorld.ismastersim then return inst end
    function inst:SetTarget(target) self._target:set(target) end
    function inst:SetResistance(value) self._strength:set(math.floor(math.clamp(value,0,1)*255+.5)) end
    return inst
end

return Prefab("dynamicarmor_indicator2hm",fn)
