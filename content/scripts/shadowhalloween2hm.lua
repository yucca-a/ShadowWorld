local M = {}

-- Apply the native event form before Shadow World copies/scales combat stats.
-- A clone follows its parent's form instead of rolling a second event creature.
function M.Prepare(parent, child)
    if parent.mummy and child.MakeMummyMerm and not child.mummy then
        child:MakeMummyMerm()
    end
    if child.prefab == "pigman" or child.prefab == "pigguard" then
        -- The stock zero-delay pig initializer otherwise rolls after onspawnchild,
        -- replacing the shadow's brain/stategraph and resetting its health/damage.
        child._frankeninitialized = true
        if parent.franken and child.MakeFrankenPig and not child.franken then
            child:MakeFrankenPig()
        end
    end
end

return M
