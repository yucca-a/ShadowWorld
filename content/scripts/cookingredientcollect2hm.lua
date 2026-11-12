-- Bind the existing collection RPC to ingredient images, preserving native
-- hover/left-click behavior. Specs are replaced whenever a pooled icon is reused.
local M = {}
local aliases = {smallmeat_cooked="cookedsmallmeat", monstermeat_cooked="cookedmonstermeat", meat_cooked="cookedmeat"}

function M.Bind(image, spec, collect, owner, chinese)
    if not image then return end
    image.cookcollectdown2hm = nil
    image.cookcollectspec2hm = spec
    if not spec then return end
    local hint = chinese and "右键：从附近容器收集到背包" or "Right-click: collect from nearby containers"
    local tip = image:GetTooltip() or ""
    if not string.find(tip, hint, 1, true) then image:SetTooltip(tip..(tip~="" and "\n" or "")..hint) end
    if image.cookcollectbound2hm then return end
    image.cookcollectbound2hm = true
    local control, lose = image.OnControl, image.OnLoseFocus
    image.OnLoseFocus = function(self, ...)
        self.cookcollectdown2hm = nil
        if lose then return lose(self, ...) end
    end
    image.OnControl = function(self, key, down, ...)
        if key==CONTROL_SECONDARY and self.focus and self.cookcollectspec2hm and self:IsVisible() then
            if down then
                self.cookcollectdown2hm = true
            elseif self.cookcollectdown2hm then
                self.cookcollectdown2hm = nil
                local s = self.cookcollectspec2hm
                collect(owner(), s.istag and s.key or aliases[s.key] or s.key, s.istag, nil, true)
            end
            return true
        end
        return control(self, key, down, ...)
    end
end

function M.Install(api, collect)
    if api.TheNet and api.TheNet:IsDedicated() then return end
    local function Bind(img, key, istag, enabled, owner)
        M.Bind(img, enabled and key and {key=key, istag=istag} or nil, collect,
            owner or function() return ThePlayer end, TUNING.isCh2hm)
    end
    if api.isModuleAvailable("craftpot/cp_foodpopup") then
        api.AddClassPostConstruct("craftpot/cp_foodpopup", function(popup)
            local set = popup.SetEntry
            popup.SetEntry = function(self, ...)
                local result = set(self, ...)
                for _, wrap in pairs(self.wraps) do
                    for i, icon in ipairs(wrap.icons) do
                        Bind(icon.img, icon.tag or icon.members and icon.members[1], icon.tag~=nil,
                            wrap.is_min and i<=wrap.used, function() return self.owner end)
                    end
                end
                return result
            end
        end)
    end
    if not api.isModuleAvailable("ui/recipe_popup_req_section") then return end
    local req = require("ui/recipe_popup_req_section")
    if req.cookcollect2hm then return end
    req.cookcollect2hm = true
    local create, update, expand = req.Create, req.UpdateEntries, req.ShowExpand
    req.Create = function(popup, name, ...)
        local section = create(popup, name, ...)
        section.cookcollectminimum2hm = name=="min"
        return section
    end
    req.UpdateEntries = function(section, requirements, ...)
        local result = update(section, requirements, ...)
        for _, slot in ipairs(section.pool) do
            Bind(slot.img, nil)
            Bind(slot.hover, nil)
        end
        local index = 1
        for _, r in ipairs(requirements or {}) do
            local group = r.type=="group"
            local collapsed = group and #r.members>=8
            local members = group and r.members or {r}
            for i, m in ipairs(members) do
                if not collapsed or i==1 then
                    local slot = section.pool[index]
                    if slot then
                        Bind(collapsed and slot.hover or slot.img, m.key, m.is_tag, section.cookcollectminimum2hm)
                    end
                    index = index+1
                end
            end
            if group and not collapsed and r.display_amount then index = index+1 end
        end
        return result
    end
    req.ShowExpand = function(section, members, ...)
        local result = expand(section, members, ...)
        for i, cell in ipairs(section.expand.icons) do
            local m = members[i]
            Bind(cell.img, m and m.key, m and m.is_tag, m and section.cookcollectminimum2hm)
        end
        return result
    end
    if api.isModuleAvailable("ui/recipe_popup_craft_section") then
        local craft = require("ui/recipe_popup_craft_section")
        local config = require("config/config_manager")
        local updatecraft = craft.Update
        craft.Update = function(popup, section, recipe, ...)
            local get, combos = popup._get_craftable_fn
            if get then popup._get_craftable_fn = function(...)
                combos = get(...)
                return combos
            end end
            local ok, result = pcall(updatecraft, popup, section, recipe, ...)
            popup._get_craftable_fn = get
            if not ok then error(result, 0) end
            -- Read the same combinations used by the native renderer. Only bind
            -- rendered slots; hidden pooled entries must lose their old target.
            for _, slot in ipairs(section.slot_pool) do Bind(slot.img, nil) end
            local limit = config.GetMaxRenderCombos()
            for ci, combo in ipairs(combos or {}) do
                if limit>0 and ci>limit then break end
                local n = #combo.ingredients
                for si, ingredient in ipairs(combo.ingredients) do
                    local slot = section.slot_pool[(ci-1)*n+si]
                    if slot and slot:IsVisible() then
                        Bind(slot.img, type(ingredient)=="table" and ingredient.prefab or ingredient, false, true)
                    end
                end
            end
            return result
        end
    end
end

return M
