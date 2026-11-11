local enabled = TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData("winona_easy") and
                    GetModConfigData("Winona Toolbox Tools")
local containers = require("containers")
local params = containers.params.winona_toolbox
local has_um_toolbox = params ~= nil

if not has_um_toolbox then
    -- 两版永不妥协先加载。独立使用时注册同名实体，方便已有工具箱随存档切换。
    table.insert(PrefabFiles, "winona_toolbox2hm")
    STRINGS.NAMES.WINONA_TOOLBOX = TUNING.isCh2hm and "薇诺娜的工具箱" or "Winona's Toolbox"
    STRINGS.RECIPE_DESC.WINONA_TOOLBOX = TUNING.isCh2hm and "把干活的家伙都收在一起。" or "Keep your work gear in one place."

    local toolbox_items = {
        sewing_tape = true, winona_recipescanner = true, winona_telebrella = true, inspectacleshat = true,
        roseglasseshat = true, winona_remote = true, wagpunk_bits = true, wagpunkbits_kit = true,
        transistor = true, nitre = true, alterguardianhatshard = true, purebrilliance = true, winona_storage_robot = true,
    }
    local toolbox_tags = {"toolbox_item", "gem", "portableitem", "NIGHTMARE_fuel"}
    params = {
        widget = containers.params.shadowchester.widget,
        type = "chest",
        itemtestfn = function(_, item)
            return toolbox_items[item.prefab] or item:HasOneOfTags(toolbox_tags)
        end,
    }
    containers.params.winona_toolbox = params
end

-- 容器组件与客户端副本都从这张表读取规则，保留永不妥协原有可放入的物品。
local OldItemTest = params.itemtestfn
params.itemtestfn = function(container, item, slot)
    return item ~= nil and ((enabled or container.loadingtools2hm) and item:HasTag("tool") or
        OldItemTest(container, item, slot))
end

if not enabled then
    AddPrefabPostInit("winona_toolbox", function(inst)
        local container = inst.components.container
        if not container then return end
        local OnLoad = container.OnLoad
        container.OnLoad = function(self, ...)
            -- 原版读档也会检查存放规则，允许已存好的工具原位恢复。
            self.loadingtools2hm = true
            OnLoad(self, ...)
            self.loadingtools2hm = nil
        end
    end)
elseif not AllRecipes.winona_toolbox then
    AddRecipe2("winona_toolbox", {Ingredient("boards", 2), Ingredient("goldnugget", 4), Ingredient("sewing_tape", 2)},
        TECH.NONE, {builder_tag = "handyperson", image = not has_um_toolbox and "tacklecontainer.tex" or nil},
        {"CONTAINERS", "CHARACTER"})
end
