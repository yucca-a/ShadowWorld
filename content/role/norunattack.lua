local extraframes = GetModConfigData("norunattack") or 0
AddStategraphPostInit("wilson", function(sg)
    for _, state in pairs(sg.states) do
        if state.tags.abouttoattack and state.tags.attack and state.ontimeout then
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                local state = inst.sg.currentstate
                onenter(inst, ...)
                if inst.sg.timeout and inst.components.combat and state == inst.sg.currentstate then
                    inst.components.combat:OverrideCooldown(inst.sg.timeout + (extraframes + 2) * FRAMES)
                end
            end
        end
    end
end)
AddStategraphPostInit("wilson_client", function(sg)
    for _, state in pairs(sg.states) do
        if state.tags.abouttoattack and state.tags.attack and state.ontimeout then
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                local state = inst.sg.currentstate
                onenter(inst, ...)
                if inst.sg.timeout and inst.replica and inst.replica.combat and not inst.components.combat and inst.replica.combat.classified and
                    inst.replica.combat.classified.minattackperiod and state == inst.sg.currentstate then
                    inst.replica.combat._laststartattacktime = GetTime() - inst.replica.combat.classified.minattackperiod:value() + inst.sg.timeout +
                                                                   (extraframes + 2) * FRAMES
                end
            end
        end
    end
end)
