-- Crafting availability may include open chests. Collection needs the amount
-- actually carried, recomputed at click time rather than cached by the widget.
local function Needed(owner, prefab, quantity, batches, fallback)
    local inventory = owner and owner.replica and owner.replica.inventory
    local builder = owner and owner.replica and owner.replica.builder
    local required = quantity * (batches or 1)
    if builder then required = RoundBiasedUp(required * builder:IngredientMod()) end
    local carried = fallback or 0
    if inventory then
        local _, count = inventory:Has(prefab, required, false)
        carried = count or 0
    end
    local missing = math.max(0, math.ceil(required - carried))
    -- Only an explicit click with enough carried material requests a stack.
    return missing > 0 and missing or false
end
return Needed
