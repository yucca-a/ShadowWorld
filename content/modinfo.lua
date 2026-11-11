version = "2.8.15.0.24"
-- Original authors: 繁花丶海棠 | 胜天一猫 | 小蓝鲸 | leo468
author = "Yucca（维护）"
forumthread = ""
api_version = 10
all_clients_require_mod = true
client_only_mod = false
dst_compatible = true
priority = -11110
icon_atlas = "modicon.xml"
icon = "modicon.tex"
server_filter_tags = {"为爽而虐", "HappyPatch", "暗影世界", "ShadowWorld"}


-- [url=https://pacthforhappy.fandom.com/zh/wiki/%E4%B8%BB%E9%A1%B5]新wiki[/url]

-- 国际化,1为中文,2为英文
local langid = 2
if locale == "zh" or locale == "zhr" or locale == "zht" then langid = 1 end
local function i18n(text, setnil)
    if text == nil or text == "" then return setnil == nil and "" or nil end
    if text[langid] ~= nil and text[langid] ~= "" then return text[langid] end
    if text[2] ~= nil and text[2] ~= "" then return text[2] end
    if text[1] ~= nil and text[1] ~= "" then return text[1] end
    return text
end
-- local version_dev = true
-- EMOJI From emoji_items.lua
name = version_dev and i18n({"󰀩 暗影世界", "Shadow World"}) or
    i18n({"󰀩 为爽而虐/暗影世界", "DST Patch For Happy/Shadow World"})
description = i18n({"当前版本:", "Version"}) .. version ..
    (version_dev and i18n({" 模组为爽而虐的开发版本", " Mod [DST Patch For Happy]'s Dev Version"}) or "") .. "\n" .. i18n({
        [[饥荒联机版的一个困难模式模组,兼容永不妥协和各类模组,难度较高
模组四大主题,随机生物大小/暗影世界/简单模式/困难模式,分别独立开关
模组内置快捷收集整理存放功能
模组内置可选复活按钮(简单模式-角色加强-旺达选项)
模组可选随机季节,内置随机级别岛屿地形(困难模式-天气/科技改动)

交流群：
更新日志见本模组工坊改动记录
模组不定期更新频繁,此时建议订阅客户端模组：无视服务器模组过期

新wiki:https://pacthforhappy.fandom.com/zh/wiki/主页]],
        [[A hard mode mod of DST.Compatible with uncompromising mode.

The mod's idea is that game is more hard to play at first,long term survive and fight with monsters.
In addition, the mod has made appropriate balance changes to the official character/some items/technology building/game settings.

new wiki but in chinese:https://pacthforhappy.fandom.com/zh/wiki/

QQ Group:]]
    })
-- bugtracker_config = {
--     email = "wakhh@qq.com",
--     upload_client_log = true,
--     upload_server_log = true,
--     upload_other_mods_crash_log = true,
--     auto_upload = false,
--     lang = "CHI"
-- }
-- 选项文字交给原生 Spinner 居中，不再通过前后空格模拟对齐。
local disabletext = i18n({"禁用", "Disable"})
local enabletext = i18n({"启用", "Enable"})
local partenabletext = i18n({"部分", "Part"})
local leftparttext = partenabletext
local function forconfoption(conf, i, fillindex, enabledesc, index, newmax, enablehover)
    conf.options[i + fillindex] = {
        description = enabledesc and (enabledesc[i] or enabledesc) or
            (index < 0 and (index == newmax and enabletext or partenabletext) or ("" .. index / 1000)),
        hover = enablehover and enablehover[i] or enablehover,
        data = index / 1000
    }
end
-- 通用选项
-- key索引键,label左侧文本,hover顶部描述,默认值,值最小值,值最大值,值间隔,启用时底部描述,禁用时底部描述,启用时右侧值文本,禁用时右侧值文本,颠倒启用禁用顺序
local function item(key, label, hover, default, min, max, step, enablehover, disablehover, enabledesc, disabledesc,
                    revert)
    -- 这个item函数是用来构建各类选项的特制函数,非常专用化,可以定义新的函数
    -- 用法1：常见二值选项item("key","label","hover")
    -- 用法2：在二值选项后快速增加x个新可选("key","label","hover",true,nil,nil,-x)
    -- 用法3：定义一个多值选项item("key","label","hover",1,1,5,1)
    local conf = {name = key, label = label, hover = hover, options = {}, default = default == nil or default or false}
    if not revert then
        -- revert目前只用于item("Shadow Animals", i18n({"有暗影分身的生物", "Which Creatures Has Shadow"})选项
        conf.options[1] = {description = disabledesc or disabletext, hover = disablehover, data = false}
    end
    if min ~= nil and max ~= nil and step ~= nil then
        -- 用法3： 可禁用可选批量数值的选项,值没有true,可选选项长度动态计算
        -- item("key","label","hover",1,1,1000,1) 或 item("key","label","hover",-1,-1,-5,-1)
        -- 底部描述 enablehover 要么为字符串要么为可选选项长度的字符串数组
        -- 右侧值文本 enabledesc 填写要求同上,不填的话,值小于0视为填写了部分/启用,值大于0则显示数值本身
        local i = 1
        local fillindex = revert and 0 or 1
        local realstep = step > 0 and step or -step
        local newmin = min * 1000
        local newmax = max * 1000
        local newstep = step * 1000
        local realnewmin = newmin < newmax and newmin or newmax
        local realnewmax = newmin < newmax and newmax or newmin
        local realnewstep = newstep > 0 and newstep or -newstep
        local reallength = (realnewmax - realnewmin) / realnewstep
        if reallength < 102 then
            for index = newmin, newmax, newstep do
                forconfoption(conf, i, fillindex, enabledesc, index, newmax, enablehover)
                i = i + 1
            end
        else
            -- 如果可选数值选项超过100多种,则适当压缩部分选择,但不影响可选选项长度
            local startlength = realnewmin / realnewstep
            local diff1 = startlength + 20
            local diff2or5 = startlength + 50
            local diff5 = startlength + 100
            local diff10 = startlength + 200
            local diff20or50 = startlength + 400
            for index = newmin, newmax, newstep do
                local diff = index / realnewstep
                if diff < diff1 or (diff < diff2or5 and (diff % 2 == 0 or diff % 5 == 0)) or (diff < diff5 and diff % 5 == 0) or
                    (diff < diff10 and diff % 10 == 0) or (diff < diff20or50 and (diff % 20 == 0 or diff % 50 == 0)) or (diff % 50 == 0) then
                    forconfoption(conf, i, fillindex, enabledesc, index, newmax, enablehover)
                    i = i + 1
                end
            end
        end
        if revert then conf.options[i + fillindex] = {description = disabledesc or disabletext, hover = disablehover, data = false} end
    elseif min == nil and max == nil and step ~= nil and step < 0 and not revert then
        -- 用法2： 可禁用可启用且有多级可选的选项,该选项和上一选项差不多,但值多一个true
        -- item("key","label","hover",-1,nil,nil,-5)
        -- 多级可选 step step必须小于0,step代表从-1到step起的多级可选,-5则包含true在内有6个可选,可选选项长度为6
        -- 底部描述 enablehover 要么为字符串要么为可选选项长度或2长度的字符串数组,true值选项显示第一个字符串,2长度字符串数组时除true值选项外的选项都会用第二个字符串
        -- 右侧值文本 enabledesc 要么为字符串要么为可选选项长度或更短数组,更短则数组第二个值起需要为数值
        --                      true值选项为第一个字符串,后续选项会自动第二个数值上逐步加1显示,不填则视为填写部分/启用
        conf.options[2] = {
            description = enabledesc and (enabledesc[1] or (enabledesc[2] and enabletext) or enabledesc) or enabletext,
            hover = enablehover and enablehover[1] or enablehover,
            data = true
        }
        local i = 2
        for index = -1, step, -1 do
            -- 连续数字选项值显示(enabledesc[2] + i - 2),仅适用于item("More Skill Points", i18n({"技能点继续增加", "More Skill Points"})选项
            conf.options[i + 1] = {
                description = enabledesc and
                    (enabledesc[i] and ((-step + 1) > #enabledesc and ("" .. enabledesc[i]) or enabledesc[i]) or
                        (enabledesc[2] and ("" .. (enabledesc[2] + i - 2))) or enabledesc) or
                    (index == step and enabletext or partenabletext),
                hover = enablehover and (enablehover[i] or enablehover[2] or enablehover) or index,
                data = index
            }
            i = i + 1
        end
    elseif min == "pairs" and max ~= nil and not revert then
        -- 多级自定义选项,暂未启用
        local i = 2
        for index = 2, #max, 2 do
            conf.options[i] = {
                description = enabledesc and (enabledesc[i] or enabledesc) or max[index - 1],
                hover = enablehover and enablehover[i] or enablehover,
                data = max[index]
            }
            i = i + 1
        end
    else
        -- 用法1：简单的二值选项,用法 item("key","label","hover"),可以很容易改造为上上个多级可选选项
        conf.options[revert and 1 or 2] = {description = enabledesc or enabletext, hover = enablehover, data = true}
        if revert then conf.options[2] = {description = disabledesc or disabletext, hover = disablehover, data = false} end
        -- min,max有值,只用于item("Shadow Prefab Setting", i18n({"暗影分身仇恨玩家", "Shadow Attack Player Actively"})选项
        if min ~= nil then conf.options[revert and 2 or 1].data = min end
        if max ~= nil then conf.options[revert and 1 or 2].data = max end
    end
    return conf
end
-- 用法4:数值不是等步长的自定义档位 itemvalue("key","label","hover",默认值,{说明1,数值1,说明2,数值2,...},禁用hover,禁用说明)
local function itemvalue(key, label, hover, default, list, disablehover, disabledesc)
    local conf = {name = key, label = label, hover = hover, options = {}, default = default == nil or default or false}
    conf.options[1] = {description = disabledesc or disabletext, hover = disablehover, data = false}
    local i = 2
    for index = 1, #list, 2 do
        conf.options[i] = {description = list[index], data = list[index + 1]}
        i = i + 1
    end
    return conf
end
-- 标题选项
local function headeritem(label, hover, disablehover)
    return {name = "", label = label, hover = hover, options = {{description = "", hover = disablehover, data = false}}, default = false}
end
--  空白选项
local function spaceitem() return {name = "", label = "", hover = "", options = {{description = "", data = false}}, default = false} end
configuration_options = {
    item("Language In Game", i18n({"本模组游戏内语言", "Mod Language In Game"}), nil, false, -1, -2, -1, {"简体中文", "English"},
        i18n("自动设定", "Auto Setting"), {"简体中文", "English"},
        i18n({"自动", "Auto"})),
    item("Show Mod Icon In Game", i18n({"游戏内查看模组按钮", "Mods Info Flower Btn"}),
        i18n({"聊天区打字 `显示/隐藏/默认模组` 试试", "try chat input `show/hide/default mods` and enter"})),
    item("Disable Outdate Tip", i18n({"限制模组版本更新提示", "Limit Mods Outdate Tip"}), i18n(
            {"模组的版本更新提示仅在出现和有新玩家时各显示一次", "Limit Mod's Version Tip only show once when init and player join"}), 1, 1,
        2, 1, {i18n({"仅限制本模组更新提示", "Only Disable The Mod's Tip"}), i18n({"限制所有模组更新提示", "Disable All Mod's Tip"})},
        nil,
        enabletext),
    item("player tags limit", i18n({"角色标签限额扩展", "Roles' Tags Limit"}),
        i18n({"角色默认限制拥有63标签，现在为63+N*50", "Roles can have more tags.Default 63,Now is 63+N*50"}), false, 1, 10, 1),
    item("ignore client error", i18n({"强制拦截客户端错误", "Force Ignore Client Error"}),
        i18n({"只拦截客户端游戏内更新游戏API中遇到的错误", "Force Ignore Client Error in game's update API"}), false),
    item("Container Sort", i18n({"容器整理收集按钮", "Containers Buttons"}),
        i18n({"容器整理收集/末影箱穿越/衣柜换装按钮", "Sort and Collect/Shadow Container Exchange Button"}), -3, -1, -6, -1, {
            i18n({"无额外跨整和锁定按钮", "No Extra Multi Sort/Lock Button"}),
            i18n({"额外跨容器整理按钮(同类容器批量整理)", "Extra Multi Sort Button(Same Container Sort Together)"}),
            i18n({"额外锁定道具按钮(与跨整互斥)", "Extra Lock/Unlock Button(No Multi Sort Button)"}),
            i18n({"无额外按钮且禁用收集按钮", "No Extra Button and Disable Collect Button"}),
            i18n({"无额外按钮且禁用整理按钮", "No Extra Button and Disable Sort Button"}),
            i18n({"(无提示文字)额外锁定道具按钮", "(No help message)Extra Lock/Unlock Button"})
        }, nil, enabletext),
    {
        name = "World Exchange",
        label = i18n({"穿越机制", "World Exchange Mode"}),
        hover = i18n({"旧配置统一迁移到为爽原版，旧暗影枢纽物品自动送回各层原生空间；地面与洞穴须同时更新。之后可手动选择咸鱼版或暗影枢纽，各机制分别保留空间。",
            "Legacy settings migrate to Original, returning old Nexus items to their native shard containers. Update all shards together. Later explicit mode selections retain separate storage."}),
        default = "exchange_v1_original",
        options = {
            {description = i18n({"为爽原版（默认）", "Original (default)"}), data = "exchange_v1_original"},
            {description = i18n({"咸鱼版", "Xianyu"}), data = "exchange_v1_xianyu"},
            {description = i18n({"暗影枢纽", "Shadow Nexus"}), data = "exchange_v1_nexus"},
            {description = i18n({"关闭空间切换", "Disable space switching"}), data = "exchange_v1_off"},
        },
    },
    item("Items collect", i18n({"道具快捷收集存放", "Items Collect/Store"}),
        i18n({"Ctrl[Alt]右键道具,制作栏/智能锅收集道具", "Press Ctrl+Mouse Right Store Items;Craft menu Collcect Items"}), -3, -1, -3,
        -1,
        {i18n({"禁用收集", "Disable Collect"}), i18n({"禁用存放", "Disable Store"}), ""}),
    item("enable easy mode", i18n({"󰀜 简单模式总开关", "Enable 󰀜 Easy Mode"})),
    item("enable hard mode", i18n({"󰀕 困难模式总开关", "Enable 󰀕 Hard Mode"}),
        i18n({"可关闭所有难度.不包含Ray的开关,关闭时暗影世界仅宠物;技能点扩展开启时开局15点",
            "Can disable all difficulty except Ray. Only pets have shadows; enabled skill-point expansion starts with 15 points"})),  -- 和暗影世界内容/Shadow World
    --     item("simple chatbot", i18n({"千影小助手", "little QianYing"}), i18n({"召唤小助手来帮你吧", "call bot for help"})),
    --     spaceitem(),
    --     item("Server Paused", i18n({"服务器暂停/继续投票", "Vote for pause / resume"}, i18n({"投票暂停或继续", "Vote for pause / resume"}))),
    item("difficulty_rating", i18n({"难度评级", "Difficulty Rating"}),
        i18n({"按当前生效的模组配置查询难度评级，仅自己可见", "Privately rate the currently active mod settings"}),
        true, nil, nil, nil,
        i18n({"控制台或聊天输入 /nd 查询难度评级，仅自己可见", "Enter /nd in console or chat for a private difficulty rating"}),
        i18n({"关闭难度评级及 /nd 查询", "Disable difficulty ratings and /nd queries"})),
    headeritem(i18n({"贝爷生存", "Bear Grylls Survival"})),
    item("贝爷求生", i18n({"贝爷求生", "Bear Grylls Survival"}),
        i18n({"制作变慢、随机耐久、资源减半、制作不永久解锁科技、猪王不换金；允许磨刀与黑暗，默认关闭",
            "Slower crafting, random durability, halved resources, no permanent crafting unlocks or Pig King gold; sharpening and darkness allowed"}), false, 1, 1, 1,
        i18n({"启用贝爷求生", "Enable Bear Grylls Survival"}), i18n({"禁用贝爷求生", "Bear Grylls Survival"}), enabletext),
    item("种地种树需要书", i18n({"种地种树需要书", "Farming And Planting Needs A Book"}),
        i18n({"没有园艺/造林书籍时无法在农田播种或种植树木,每次消耗1点书耐久", "Cannot plant crops or trees without a gardening/silviculture book; each planting uses 1 book durability"}), false, 1, 1, 1,
        i18n({"启用种地种树需要书", "Enable Farming And Planting Needs A Book"}), i18n({"禁用种地种树需要书", "Farming And Planting Needs A Book"}), enabletext),
    item("做饭需要书", i18n({"做饭需要书", "Cooking Needs A Book"}),
        i18n({"没有可用的烹饪指南时无法在烹饪锅做饭,每次烹饪消耗1点耐久", "Cannot cook without a usable cookbook; each cooking uses 1 durability"}), false, 1, 1, 1,
        i18n({"启用做饭需要书", "Enable Cooking Needs A Book"}), i18n({"禁用做饭需要书", "Cooking Needs A Book"}), enabletext),
    item("材料制造翻倍", i18n({"材料制造翻倍", "Double Craft Materials"}),
        i18n({"制造配方所需材料数量翻倍,生存更艰难", "Recipe materials are doubled, making survival harder"}), false, 1, 1, 1,
        i18n({"启用材料制造翻倍", "Enable Double Craft Materials"}), i18n({"禁用材料制造翻倍", "Double Craft Materials"}), enabletext),
    item("低san采集失败", i18n({"低san采集失败", "Pick Fail At Low Sanity"}),
        i18n({"理智越低采集越容易失败,精神见底时最高50%失败率", "Picking may fail more often at low sanity, up to 50% at zero"}), false, 1, 1, 1,
        i18n({"启用低san采集失败", "Enable Pick Fail At Low Sanity"}), i18n({"禁用低san采集失败", "Pick Fail At Low Sanity"}), enabletext),
    item("捡东西变慢", i18n({"捡东西变慢", "Slow Pickup"}),
        i18n({"捡起/采摘/收获变为慢动作", "Pickup/Pick/Harvest become long actions"}), false, 1, 1, 1,
        i18n({"启用捡东西变慢", "Enable Slow Pickup"}), i18n({"禁用捡东西变慢", "Slow Pickup"}), enabletext),
    headeritem(i18n({"德爷生存", "Ed Stafford Survival"})),
    item("德爷生存", i18n({"德爷生存", "Ed Stafford Survival"}),
        i18n({"德爷极限求生模式总开关，默认关闭；子项仅在总开关开启时生效",
            "Ed Stafford master switch, disabled by default; sub-options require this switch"}), false, 1, 1, 1,
        i18n({"启用德爷生存", "Enable Ed Stafford Survival"}), i18n({"禁用德爷生存", "Ed Stafford Survival"}), enabletext),
    item("料理禁止堆叠", i18n({"料理禁止堆叠", "No Food Stacking"}),
        i18n({"料理不能继续堆叠；已有堆叠保留数量，拆分后每格一份", "Food cannot stack; existing saved stacks keep their count and cannot recombine after splitting"}), false, 1, 1, 1,
        i18n({"启用料理禁止堆叠", "Enable No Food Stacking"}), i18n({"禁用料理禁止堆叠", "No Food Stacking"}), enabletext),
    item("护甲失效", i18n({"护甲失效", "Armor Invalid"}),
        i18n({"护甲不能再抵挡伤害,但被打也不会损失耐久\n开启后暗影生物不能主动伤害你",
            "Armor no longer blocks damage,but loses no durability when hit\nShadow creatures cannot actively harm you while enabled"}), false, 1, 1, 1,
        i18n({"启用护甲失效", "Enable Armor Invalid"}), i18n({"禁用护甲失效", "Armor Invalid"}), enabletext),
    item("难以冻结", i18n({"难以冻结", "Hard To Freeze"}),
        i18n({"冻结有23秒冷却 冻结强度大量减少",
            "Freeze has 23s cooldown,freeze intensity greatly reduced"}), 1, 1, 1, 1,
        i18n({"启用难以冻结", "Enable Hard To Freeze"}), i18n({"禁用难以冻结", "Hard To Freeze"}), enabletext),
    item("下雨禁火", i18n({"下雨禁火", "No Fire In Rain"}),
        i18n({"下雨时无法点燃火焰,火把瞬间熄灭",
            "Cannot light fires in rain,torch goes out instantly"}), 1, 1, 1, 1,
        i18n({"启用下雨禁火", "Enable No Fire In Rain"}), i18n({"禁用下雨禁火", "No Fire In Rain"}), enabletext),
    item("火把传热", i18n({"火把传热", "Torch Heat"}),
        i18n({"点燃的火把/打火机火焰是热源,附近玩家会变暖",
            "Lit torch/lighter flames are heat sources,warms nearby players"}), 1, 1, 1, 1,
        i18n({"启用火把传热", "Enable Torch Heat"}), i18n({"禁用火把传热", "Torch Heat"}), enabletext),
    item("空挥武器", i18n({"空挥武器", "Swing In Place"}),
        i18n({"在使用攻击的时候 玩家不会移动到最远攻击距离\n而是会原地挥刀",
            "When attacking,the player will not move to the max attack range\nbut swing in place"}), false, 1, 1, 1,
        i18n({"启用空挥武器", "Enable Swing In Place"}), i18n({"禁用空挥武器", "Swing In Place"}), enabletext),
    headeritem("Ray"),
    item("Random Sized", i18n({"随机生物大小", "Random biological size"}),
        i18n({"如生活调味料一般改变方方面面", "Change all aspects like seasoning in daily life"}), 1, 1, 1, 1,
        i18n({"启用随机大小", "Enable Random Sized"}), i18n({"禁用随机大小", "Random Sized"}), enabletext),
    item("Random sized beefalo", i18n({"随机生物大小牦牛改动", "Random biological size"}),
        i18n({"对随机生物体型的牦牛数值加成额外调整", "Additional adjustment to the beefalo based on random biological size"}), 1, 1, 1,
        1,
        i18n({"平分体型数值加在各自的特长上", "Distribute the body type stats evenly across their respective strengths"}),
        i18n({"不额外处理数值", "No additional processing of data"}), enabletext),
    item("ban op", i18n({"允许作弊", "not ban op"}),
        i18n({"禁用后，玩家禁止回档，使用控制台等", "Players are prohibited from rollback, using administrator privileges, etc"}), 1, 1,
        1, 1,
        i18n({"启用作弊", "Enable cheating"}), i18n({"禁用作弊", "Disable cheating"}), enabletext),
    item("World ecosystem", i18n({"群系灭绝", "ecosystem extinction"}), i18n({
        "一直无底限的猎杀生物最终会导致生物永久覆灭",
        "The continuous and unrestrained hunting of wildlife will ultimately lead to the permanent extinction of species"
    }), false, 1, 1, 1, i18n({"启用群系灭绝", "Enable World ecosystem"}), i18n({"禁用群系灭绝", "World ecosystem"}), enabletext),
    item("World lose", i18n({"遗忘地图", "lose atlas"}), i18n({
        "玩家需使用月岩守卫标记，否则地图不会解锁。",
        "The player triggers the use of guard markers, otherwise the map will not be unlocked"
    }), false, 1, 1, 1, i18n({"启用遗忘", "Enable World ecosystem"}), i18n({"禁用遗忘", "World ecosystem"}), enabletext),
    item("World Unlock", i18n({"地图解锁", "World Unlock"}),
        i18n({"遗忘地图开启时玩家可以使用特殊手段来解锁地图。", "Players can use special methods to unlock the map"}), false, 1, 1, 1,
        i18n({"启用解锁", "Enable unlocking"}), i18n({"禁用解锁", "Disable unlocking"}), enabletext),
    headeritem(i18n({"󰀩 暗影世界", "󰀩 Shadow World"})),
    headeritem(i18n({"暗影分身改动", "Creatures"})),
    item("Shadow World", i18n({"生物暗影分身数目", "Creatures' Shadow Number"}),
        i18n({"这个世界的生物会生成几个暗影分身", "Creatures will have N shadow in the world"}), 1, 1, 3, 1,
        i18n({"启用暗影世界", "Enable Shadow World"}), i18n({"禁用暗影世界", "Disable Shadow World"})),
    item("Shadow Animals", i18n({"有暗影分身的生物", "Which Creatures Has Shadow"}),
        i18n({"这个世界的哪些生物会生成暗影分身", "Whick creatures will have shadow in the world"}), false, 1, 7, 1, {
            i18n({"除boss外的生物会生成暗影分身", "Creatures except player and boss will have shadow in the world"}),
            i18n({"仅boss会生成暗影分身", "Only boss will have shadow in the world"}),
            i18n({"全部生成但boss残血25%或2500血以下时才生成", "all has but boss low health 25%/2500 will have shadow"}),
            i18n({"全部生成但蜂后和部分困难加强boss半血时生成", "all has but some boss low health 50%/5000 will have shadow"}),
            i18n({"全部生成但boss半血50%或5000血以下时才生成", "all has but boss half health 50%/5000 will have shadow"}),
            i18n({"仅boss残血25%或2500血以下时生成暗影分身", "only boss low health 25%/2500 will have shadow"}),
            i18n({"仅切斯特哈奇阿比盖尔伯尼", "only abigail/bernie/hutch/chester"})
        }, i18n({"除影怪和不可移动生物外大部分生物都会生成暗影分身", "Most creatures will have shadow except shadow/fixed creatures"}), {
            i18n({"非boss", "Notboss"}),
            i18n({"仅boss", "Boss"}),
            i18n({"boss残血", "BossLowHealth"}),
            i18n({"boss特殊", "BossSpecial"}),
            i18n({"boss半血", "BossHalfHealth"}),
            i18n({"仅boss残血", "OnlyBossLowHealth"}),
            i18n({"仅宠物", "OnlyPet"})
        }, i18n({"大部分", "Most"}), true), -- false为大部分,1为非boss,2为仅boss,3为...,最后一个true是revert颠倒顺序
    item("Shadow Num Limit", i18n({"暗影分身总数上限", "Shadow Num Limit"}), i18n(
            {"世界的暗影分身数目上限,BOSS/宠物不算;有但不能生成则减伤", "Per world,except Boss/Pet;If can't then creature reduce takendmg"}),
        12, 5, 30, 1, nil, nil, nil, i18n({"无限", "Unlimit"})),
    item("Shadow Regen Period", i18n({"暗影分身再生时间", "Shadow Rebirth Time"}), -- false为瞬间再生
        i18n({"死亡后多少秒再次生成", "N seconds rebirth after death"}), 480, 60, 960, 60, nil, nil, nil, "1"),
    item("Shadow Help Self", i18n({"生物转移敌人仇恨", "Creatures Transfer Hatred to Shadow"}),
        i18n({"生物会将敌人仇恨转移给暗影分身", "When creatures attacked by enemy,it will transfer hatred to its shadow"}), 1, 1, 4, 1,
        {
            i18n({"只有没有攻击力的生物会转移敌人仇恨给分身", "Creatures No damage"}),
            i18n({"除boss外的生物都会转移仇恨,韦伯沃特很强", "Creatures except player and boss,strong webber and wurt"}),
            i18n({"boss残血25%时才转移敌人仇恨给分身", "all but boss only low health 25% "}),
            i18n({"大部分生物都会转移,韦伯沃特削弱很大", "Most creatures;weak webber and wurt when attack boss"})
        }, nil, {
            i18n({"仅无害", "OnlySafe"}),
            i18n({"非boss", "Notboss"}),
            i18n({"boss残血", "BossLowHealth"}),
            i18n({"大部分", "Most"})
        }, nil),
    item("Shadow Protect Creatures", i18n({"暗影分身保护本体", "Shadow Protect Creatures"}), i18n(
            {"关闭暗影分身独立仇恨;暗影分身有仇恨后仍共享本体仇恨", "Shadow will whether share creatures's target even it has own target"}),
        false),
    item("Shadow Prefab Setting", i18n({"暗影分身仇恨玩家", "Shadow Attack Player Actively"}),
        i18n({"暗影分身主动仇恨没有骨头头盔类防护的玩家", "Shadow will appear and hate player without bone helm near animal"}), true, true,
        false), -- true为和平机制,false为危险机制,实际值与显示信息相反,主要是为了兼容旧版本
    item("Shadow Epic Far Range", i18n({"本体远离驱散距离", "Epic Far Stop Range"}),
        i18n({"远离BOSSx距离后BOSS驱散暗影分身,非BOSS距离50", "Far away Epic x range,shadow disappear;Not epic 50"}), 200, 1000, 100,
        -100, nil,
        nil, nil, i18n({"无限", "Unlimit"})),
    item("Epic Shadow Far Range", i18n({"分身远离回归距离", "Epic Shadow Far Range"}),
        i18n({"远离Boss分身x距离后分身主动回归,非BOSS距离50", "Far away Epic's shadow x range,shadow disappear;Not epic 50"}), false,
        1000,
        100, -100, nil, nil, nil, i18n({"无限", "Unlimit"})),
    item("Shadow Harder Level", i18n({"暗影世界第二周目", "Shadow World Second Mode"}), i18n(
            {"裂隙开启后,脱离加载或丢失仇恨,分身闪到本体周围", "When Enable Rifts,Shadow go back when leave load range or lose target"}),
        false),
    item("shadow_nerf", i18n({"生物暗影分身削弱", "shadow nerf"}), i18n(
        {"设置攻击间隔。削弱影子的血量/体型/攻速/复活时间,部分boss影子2000血/复活更久",
            "set attack_period.weakness Health/Scale/AttackPeriod/SpawnTime of shadow"}), 2, 1, 3, 1),
    spaceitem(),
    headeritem(i18n({"󰀜 简单模式", "󰀜 Easy Mode"})),
    headeritem(i18n({"建筑改动", "Structures"})),
    item("Science Machine Refine Materials", i18n({"科学机器精炼材料", "Science Machine Refine Materials"}),
        i18n({"可以给予成品或材料进行加工,齿轮升级9次", "Give it product or ingredients,gears to level up"})),
    item("Alchemy Engine Redeem Gold Nugget", i18n({"炼金引擎有炼金术", "Alchemy Engine Alchemy"}),
        i18n({"有威尔逊部分炼金术给予炼金;齿轮升级", "Give materials to wilson's Alchemy;gears levelup"}), -1, nil, nil, -1,
        {i18n({"给予肉和玩具等可兑换金块", "Give meat and toy for gold nuggets"}), i18n({"禁用兑换金块", "Disable Redeem GoldNugget"})}),
    item("Shadow Manipulator Break Down Objects", i18n({"灵子分解器分解道具", "Shadow Manipulator Break Down Objects"}),
        i18n({"返还一半素材,小数点部分概率返还,绿宝石升级两次", "Give items returns 50% ingredients;Greengen levelup"})),
    item("Prestihatitator Redeem shadowmagic Tag", i18n({"暗影操控器兑换暗影魔法", "Prestihatitator Redeem shadowmagic Tag"}),
        i18n({
            "给予4噩梦燃料获得暗影魔法和工具标签并让读魔法书理智消耗变为1倍",
            "Give 4 nightmare fuels offers shadow magic/tool tag and consumes normal reading sanity"
        })),
    item("Terra Firma Tamper Redeem Desert Stone", i18n({"土地夯实器兑换沙之石", "Terra Firma Tamper Redeem Desert Stone"}),
        i18n({"给予蛋和玩具等可兑换沙之石;铥矿升级", "Give eggs and toy for desert stones;Thulecite levelup"}), true, nil, nil, -1,
        {" ", i18n({"改为使用懒人传送塔兑换沙之石", "Replace use Lazy Deserter to redeem"})}),
    item("Tackle Receptacle Use Fish Redeem", i18n({"钓具容器选择改动", "Tackle Receptacle Storage Tackle"}), nil, -1, nil, nil,
        -1, {
            i18n({"给予活鱼可兑换海带种子玩具金子触手皮", "Give live fish for kelp seeds toy gold nuggets tentacle spots"}),
            i18n({"禁用兑换但可存放菜肴和钓具箱内道具0.15倍缓鲜", "Disable Redeem but store/0.15 keep pot food and tackle box items"})
        }),
    item("Cartographer's Desk Make Blueprint", i18n({"制图桌制作蓝图", "Cartographer's Desk Make Blueprint"}), i18n({
        "给道具有莎草纸得道具蓝图,给莎草纸复制携带的纸制品",
        "Give item has papyrus get item Blueprint;Give papyrus has paperitem copy paperitem"
    })),
    item("Make Cooking Recipe Card", i18n({"烹饪锅制作食谱卡", "Crock Pot Make Recipe Card"}),
        i18n({"给予莎草纸", "Give papyrus"})),
    item("mannequin swap follower", i18n({"假人额外交换随从", "Mannequin Swap Follower"}),
        i18n({"仅有攻击力的无仇恨的随从", "Only follower has damage and no target"}), true, nil, nil, -1,
        {i18n({"可以放入物品栏的随从放入假人物品栏", "Try Follower Put Into Mannequin's inventory"}), i18n({"不放入", "Not Put Into"})}),
    item("townportal use sandstone activate", i18n({"懒人传送塔保持激活", "Lazy Deserter Activate by Sand Stone"}),
        i18n({"给沙石保持激活;右键其取消激活.在一个塔旁(8石墙距离内)用沙石优先传塔连线自己的方向的塔",
            "Give sandstone active,right click cancel.Use stone near Lazy Deserter(8 distance) to teleport facing Lazy Deserter"}),
        2, 1, 2, 1, {
            i18n({"无标记", "Don't use markers"}),
            i18n({"用彩色标记指示其它塔的方向", "Use colored markers to indicate direciion of other Lazy Deserter"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"无标记", "no mark"}),
            i18n({"标记", "mark"})
        }, i18n({"禁用", "Disable"}), false),
    item("dragonfly furnace stewer", i18n({"龙鳞火炉批量烹饪", "Dragonfly Furnace Multi Cook Pot"}),
        i18n({"四格食材可批量烹饪，添加燃料可加快烹饪。非沃利角色可消耗红宝石制作沃利专属料理。摧毁时木头等量变木炭，树枝及可销毁杂物每两件产出一个灰烬。",
            "Batch cook with four ingredient slots and add fuel to speed up cooking. Other characters can spend red gems to make Warly's dishes. Destroy turns logs into charcoal one for one and yields one ash per two twigs or eligible junk items."})),
    item("Portable Crock Pot Multi", i18n({"便携烹饪锅批量调味", "Portable Crock Pot Multi"})),
    item("mushroom_light", i18n({"蘑菇灯返鲜,更亮", "mushroom_light regain freshness/brighter"})),
    item("meatrack_dry", i18n({"晾肉架可晾晒蔬菜", "meatrack can dry plants"}),
        i18n({"晾好的菜仅有0.25菜/果度,回3%血上限,晾肉架不可燃,可放入冰箱/钓具容器",
            "=0.25 Vegetable/Fruit. Heal 3% maxhealth.non-flammable.Can put in icebox/Tackle Receptacle"})),
    item("eyeturret", i18n({"眼球炮塔加强", "Enhanced Houndius Shootius"}),
        i18n({"仅友方炮塔;配方+2羊角；2000血/每秒回50；200基础电击，额外连锁4目标，每跳衰减20%；龙鳞升级隔离火焰，蘑菇皮免疫孢子云；秒杀妥测冰川座狼；保留双护盾；归零不掉落，休养5天满血恢复；拆解返还升级材料",
            "Friendly turrets only;recipe +2 goat horns;2000 HP,50 HP/s;200 electric base,4 extra chain targets(-20%/hop);scales:contained flames;shroom skin:spore immunity;execute UM glacial hounds;dual shields;revives after 5 days without death loot;deconstruction refunds upgrades"}), true),
    headeritem(i18n({"机制改动", "Settings"})),
    item("Sleep In Tent Even Danger", i18n({"危险入睡/帐篷升级", "Sleep In Tent Even Danger"}),
        i18n({"毛皮铺盖帐篷等可以睡袋升级自愈无视白天等限制", "Use Napsack Upgrade Tent/Fur Roll... then auto repair self"}), true, nil,
        nil, -1, {i18n({"并强制脱离仇恨", "Force attacker lose target"}), i18n({"不强制脱离仇恨", "Not Force"})}),
    item("The tent supports multiple people sharing it",
        i18n({"帐篷可多人共用", "The tent supports multiple people sharing it"}),
        i18n({"帐篷可支持设定的人数共用(优化自 作者:liximi -《多人帐篷》模组)", "The tent can accommodate a predetermined number of people"}),
        -3, nil, nil, -14, {"", ""}, nil, {i18n({"无限", "Unlimit"}), 2}),
    item("Haunt Telltale Heart To Revive", i18n({"作祟告密的心复活", "Haunt Telltale Heart To Revive"}),
        i18n({"作祟容器可以把心作祟出来了", "Even if it's in container"})),
    item("Construction Amulet Repair Equip", i18n({"材料建造修理道具", "Ingredients Repair Equip"}),
        i18n({"部分道具可以材料修理,或需携带建造;", "Use Ingredients Repair Some Items,May take Construction Amulet"}), true, nil, nil,
        -1,
        {"", i18n({"建造护符直接修理道具", "Use Construction Amulet Straight Repair Some Items"})}),
    item("Use Dock kit in Cave", i18n({"洞穴世界使用码头地皮", "Use Dock kit in Cave"}), nil, true, nil, nil, -1,
        {i18n({"码头4天后自毁", "Auto damage,only exist 4 days"}), i18n({"码头不会自毁", "Don't auto damage"})}),
    item("Spider Gland Can Heal Monster Meat", i18n({"净化怪兽肉为肉", "Heal Monster Meat Into Meat"}), i18n(
        {"使用蜘蛛腺体蚊子血袋药膏净化各种怪物食材", "Spider land,mosquito sack,healing salve and so on.Include cooked and dried ones"})),
    item("Use Fire To Cook", i18n({"用任意火焰烹饪", "Use Fire To Cook"}),
        i18n({"火炬,猪人火炬,冰篝火,燃烧的树木等", "Use pig Torch,burning tree and so on to cook"})),
    item("pickup irreplaceable item", i18n({"上线自动捡眼骨", "Auto Pickup Irreplaceable Item"}),
        i18n({"上线时自动捡起眼骨类道具", "Auto Pickup Irreplaceable Item When Connect"})),
    item("Terra Easter egg", i18n({"泰拉箱子彩蛋", "Terra Easter egg"})),
    item("um_patch", i18n({"永不妥协补丁", "Uncompromising Mode Patch"}),
        i18n({"启用永不妥协兼容调整与性能优化；上游实现不匹配时跳过对应优化。", "Enable UM adjustments and performance fixes; unknown upstream implementations are left unchanged."})),
    {
        name = "um_weather_particles2hm",
        label = i18n({"妥协天气粒子密度", "UM weather particle density"}),
        hover = i18n({"永不妥协补丁开启时生效，只调整暴风雪粒子与龙卷风附近雨溅，保留遮挡和天气机制。",
            "With UM Patch enabled, adjust blizzard particles and storm rain effects while preserving overlays and weather gameplay."}),
        options = {
            {description = i18n({"轻量", "Light"}), data = 2},
            {description = i18n({"均衡（默认）", "Balanced (default)"}), data = 4},
            {description = i18n({"妥协原密度", "Original UM density"}), data = 10},
        },
        default = 4,
    },
    item("luck value", i18n({"幸运值机制改动", "Luck value adjustment"}),
        i18n({"幸运值效能削弱,无法达到100概率", "Luck effect diminished, cannot reach 100% probability"})),
    headeritem(i18n({"装备改动", "Equips"})),
    item("Reskin Tool Upgrade", i18n({"清洁扫把连接科技", "Clean Sweeper Connect Prototyper"}),
        i18n({"目前仅支持可升级科技且困难需给过四本燃料", "Hard need Prestihatitator Redeem shadowmagic Tag;Now Support 4 prototyper"})),
    item("Deck Illuminator Equip Head", i18n({"甲板照明灯装备头部", "Deck Illuminator Equip Head"}),
        i18n({"彩蛋设定", "Easter egg settings"}),
        false),
    item("Glass Cutter Leap Attack", i18n({"注能玻璃刀跳跃斩击", "Infused Glass Cutter Leap Attack"}),
        i18n({"注能月亮碎片注能可跳劈,跳劈受益于理智或新鲜", "Need Infused Moon Shard activate.Sanity Effect damage and range"}), true,
        nil, nil, -1,
        {i18n({"玻璃刀击杀影怪回理智但困难模式移除妥协增伤", "Simpe Kill Shadow Get Sanity But Hardmode disable UM Extra Damage"}), " "}),
    item("Nightsword Infused", i18n({"暗夜剑注魔增强", "Nightsword can infuse"}),
        i18n({"伤害增加，攻击召唤影人攻击并附带易伤", "Damage increased, attack summons a shadow figure to attack and inflicts vulnerability"})),
    item("Thulecite Equip Parry", i18n({"铥矿棒格挡敌人攻击", "Thulecite Club Parry Attack"}),
        i18n({"铥矿棒主动格挡攻击;铥矿三件套地下绝缘", "Thulecite Club can Parry attacks;Three Thulecite Equip cave insulation"}), true,
        nil,
        nil, -1, {"", i18n({"每次格挡时都恢复角色碰撞", "When Parry,toggle on role's physics"})}),
    item("Multi Tool Is Almighty Tool", i18n({"多用斧镐更多功能", "Multi Tool Is Almighty Tool"}),
        i18n({"多用斧镐铲锤刮耕地,丢地可叉,配方改动", "dig,hammer,till,shave;drop ground pickup can terraform"})),
    item("Turf-Raiser Helm Plant Tree Cone", i18n({"超级高效刮地皮头盔", "Super Turf-Raiser Helm Tool"}),
        i18n({"范围快速工作种植部署施肥,放沙之石会修理", "Put tools or plant seeds or desert stones into it or equip tools"})),
    item("Shieldofterror Eat Owner", i18n({"恐怖盾牌捕虫", "Shield of Terror As Bug Net"}),
        i18n({"恐怖盾牌眼面具汲取敌人主人回复耐久", "Shield of Terror/Eye Mask Eat Owner/Attacker/Target"})),
    item("Eyebrella Swell Shade", i18n({"眼球伞自愈隔热", "Eyebrella Swell Shade"}),
        i18n({"雨雪天气自愈,装备时不过热则视为水中木庇护,羊奶乳白等修", "Has swell shade,goatmilk.../rain/snow repair"})),
    item("Scalemail Parry Freezable", i18n({"鳞甲抵抗持续冰冻", "Scalemail Parry Freezable"}),
        i18n({"鳞甲抵抗持续冰冻;熔岩虫召唤召回", "Scalemail better and 2/3 chance thaw from frozen"})),
    item("Shadow Thurible Has Light", i18n({"暗影香炉汲影照明", "Shadow Thurible Has Light"}),
        i18n({"吸收附近影怪生命恢复自身和骨头装备耐久", "recover by get health from near shadow creature"})),
    item("Bone Helm No Remove", i18n({"骨头头盔影怪助战", "Bone Helm Shadow Help"}), i18n(
        {"影怪协助战斗(困难模式需暗影魔法),不会损坏,燃料修理", "Summon Shadow creature help(need shadow magic),repair and not bad"})),
    item("Enlightened Crown Benefit From Spore", i18n({"启迪之冠过冬春夏", "Enlightened Crown Benefit From Spores"}), i18n({
        "护目;5孢子时提供热源/冷源/绝缘携带生效;蘑菇帽保暖隔热防水",
        "Goggles;5 Red/Blue/Green has warm/cold heat source/insulated even not equipped"
    }), true, nil, nil, -1, {
        i18n({"每红/蓝/绿孢子提供60保暖/60隔热/20%防水", "Each red/blue/green offers 60 warm/cold or 20% waterproof"}),
        i18n({"额外禁用启迪光照颜色", "extra disable hat light color"})
    }),
    item("upgrade torch", i18n({"辉煌/绝望/亮茄火把", "Upgrade Your Torch"}), i18n(
        {"使用绝望石/纯粹辉煌/亮茄外壳升级你的火把(易伤/重伤)", "Use Brightshade Husk/Pure Brilliance/Dreadstone Upgrade Your Torch"})),
    item("Moongleam Weapon", i18n({"月熠奔雷/月熠晨星", "Elding Spear/Morning Star"}),
        i18n({"月熠进化充能奔雷矛,约束静电和月熠进化晨星锤", "Use Restrained Static/Moongleam Upgrade"})),
    item("hivehat", i18n({"蜂王冠升级为蜂巢", "Bee Queen Crown Change"}),
        i18n({"蜂巢蜂箱友好,给蜜蜂变蜂巢", "Beebox Friendly;Give bees change into Bee Hives"})),
    item("Horizon Expandinator", i18n({"便携式视界扩展器", "More Convenient Horizon Expandinator"}), i18n({
        "视界扩展器可用各种护目镜升级,自助修理机可修理,物品栏内检查可开/关大视野模式",
        "Horizon Expandinator can upgrad with various goggles,can be repaired with Auto-Mat-O-Chanic,check it in inventory enable/disable the maxview mode"})),
    item("scraphat", i18n({"拾荒尖帽受击反伤", "Scraphat Return Attack To Attacker"}), i18n({
        "拾荒尖帽受击反击、可用自助修理机修理、耐久增强",
        "scraphat return attack to attacker,can be repaired with Auto-Mat-O-Chanic,More durable"})),
    item("lunar shadow items", i18n({"月后影后装备增强", "lunar and shadow rift items strengthen"}),
        i18n({"结晶器避茄针,阴郁牛铃可收牛,骑牛离铃约一屏提醒,茄剑带月灵,镰刀特效,虚空头老瓦套迅速叠满",
            "deerclopseyeball avoid lunarthrall_plant, shadow_beef_bell stores beefalo; riding about a screen away reminds you to bring the bell; sword_lunarplant with gestalt, armorwagpunk and voidclothhat quickly stacks up"})),
    item("Celestial Jewel Upgrade Sword Lunarplant", i18n({"天体珠宝升级亮茄剑", "Celestial Jewel Upgrade Sword Lunarplant"}),
        i18n({"攻击200普通+300位面,右键范围300普通+400位面,命中敌人脚下留3秒月火", "Attack 200 physical + 300 planar; RMB AoE 300 physical + 400 planar; hits leave 3s moonfire on the ground"}), true),
    headeritem(i18n({"道具改动", "Props"})),
    item("Tackle Box Can Hold Role's Item", i18n({"钓具箱容纳角色道具", "Tackle box Contains Role's Items"}),
        i18n({"钓具箱打开不掉落,放和保鲜孢子蜘蛛", "Tackle box won't drop when opening,and put/keep spore/spider"})),
    item("boat use shadowheart upgrade", i18n({"暗影心脏升级船只", "Shadow Heart Upgrade Boat"}),
        i18n({"暗影心脏放船上升级船只从而自动船舵,船损返还心脏", "Drop shadow heart on boat make its steering wheel auto"})),
    item("beef_bell use orangegem upgrade", i18n({"橙宝石升级牛铃铛", "Orange Gem Upgrade Beefalo Bell"}), i18n({
        "存档牛数据,死后此数据复活;牛角更新存档;牛毛改名;右键牛铃召唤召回牛;骑牛离铃约一屏提醒",
        "Save data when upgrade,call/recall and auto relive beefalo;horn updates save,wool renames;riding about a screen away reminds you to bring the bell"
    })),
    item("New Hambat 2", i18n({"全新火腿(๑•̀ㅂ•́)و✧", "New Hambat (๑•̀ㅂ•́)و✧"}),
        i18n({"火腿为什么不能吃?我不理解，但是我们火腿棒!很棒 (设置是最大重量)", "taste your hambat and be strong (config for hambat weight)"}), 10,
        5, 10, 1),
    item("quick mast_malbatross", i18n({"飞翼风帆加强", "quick mast_malbatross"}), i18n({"可快速开启", "Can quick open "}),
        false),
    item("elastispacer upgrade", i18n({"弹性空间制造器可升级便携式容器", "Elastispacer Can Upgrade Portablestorage"}), i18n({
        "弹性空间制造器可以升级便携式容器,堆叠无限,防火,配方更简易",
        "Elastispacer can upgrade portablestorage, infinitestacksize, unburnable, simpler recipe"})),
    item("gelblob_storage_kit upgrade", i18n({"恶液存储套件升级容器", "Ooze Storage Kit Upgrade Container"}), i18n({
        "恶液存储套件升级容器使容器永鲜",
        "Right click a container with the Ooze Storage Kit to make it permanently fresh (contents never rot).Upgraded container gets an \"Ooze-\" name prefix,persists across save"})),
    item("boat_bumper_crabking", i18n({"帝王蟹保险杠", "Crab King Bumper"}),
        i18n({"保险杠血量翻倍、缓慢回复损失的生命值、没血时脱落变破损状态，期间可用石头材料修复",
            "doubles health, slowly recovers lost health,falls off and becomes damaged when there is no health, stone materials can be used to repair it"})),
    item("trap_teeth", i18n({"陷阱5秒重置,耐久翻倍", "trap auto reset 5s,use*2"})),
    item("Trap Guaranteed Catch", i18n({"陷阱必中", "Guaranteed Trap Catch"}),
        i18n({"普通陷阱触发后立即捕获有效目标，保留合拢动画；捕获范围、耐久和掉落不变",
            "Ordinary traps catch valid targets immediately on triggering while keeping the closing animation; range, durability and loot are unchanged"}), true),
    item("Minotaurhorn Enchant", i18n({"守卫者角附魔", "Guardian's Horn can enchant"}),
        i18n({"远古守卫者的角可以附魔手杖、懒人杖以及妥协模组的查尔斯滑行杖获得冲锋加速能力",
            "Guardian's Horn be enchanted on Lazy Explorer, Walking Cane, and the Charles_t_horse of UM module to obtain the ability to accelerate the charge"})),
    headeritem(i18n({"生物改动", "Plants"})),
    item("Twiggy Tree Can Pickable", i18n({"多枝树采集树枝", "Twiggy Tree Can Pickable"}),
        i18n({"多枝树长大阶段可采集树枝", "Pick twigs from grown Twiggy trees"})),
    item("Grass Gekko Regrow Grass", i18n({"草根变草蜥蜴再生", "Grass Gekko Regrow Grass"}),
        i18n({"草根变成草蜥蜴后原地再生一个枯萎草根", "New born grass gekko leave root on ground"})),
    item("Weed Product Can Plant", i18n({"杂草产物可以种植", "Weed Product Can Plant"}),
        i18n({"必忘我春秋复苏,和火荨麻犁地草可种植", "Forget-Me-Lots/Fire Nettles/Tillweed are now plantable for weeds"})),
    item("Glommer Eat Near Insects", i18n({"格罗姆会吃昆虫", "Glommer Eat Near Insects"})),
    item("Boulderbough", i18n({"巨石枝削弱", "Boulderbough weaken"})),
    headeritem(i18n({"新物品", "New things"})),
    item("player_tomb", i18n({"哀悼之穴", "tomb of player"}),
        i18n({"为不幸去世的玩家做点什么吧,坟头草什么的,种杂草多产1个", "something would grow from player tomb ? Weed loot 2."})),
    item("sword_vortex2hm", i18n({"涡流刀", "Vortex Sword"}),
        i18n({"每次攻击后可冲刺一次(没有无敌),并将敌人牵引一段距离造成一半伤害", "Can dodge once after attack, pull target move half distance."})),
    headeritem(i18n({"角色改动", "Charaters"})),
    item("role_easy", i18n({"简单模式角色改动总开关", "Switch for Charaters of Easy Mode"})),
    item("More Skill Points", i18n({"技能点继续增加", "More Skill Points"}),
        i18n({"全部经验时可以点满技能;禁用时保留游戏原有技能点规则", "Can activate all skills finally; disabling preserves native skill-point rules"}), -6, nil, nil, -16,
        {"", i18n({"开荒时最多可有部分技能点,选0时永不获得", "New Game Start with x skill points.Never obtain when select 0."})}, nil,
        {enabletext, 0}),
    item("wilson_easy", i18n({"---------------------- 󰀰 威尔逊总开关", "󰀰 Wilson Master Switch"})),
    item("Wilson 1 Science Bonus", i18n({"威尔逊掌握科学机器科技", "Wilson Has 1 Science Bonus"})),
    item("Wilson Tech Bonus", i18n({"威尔逊科技增强", "Wilson Tech Bonus"}),
        i18n({"解锁科技获得增强:科学机器(一本)+25%攻击,炼金引擎(二本)-25%承伤,灵子分解器(魔法一本)+20%移速,暗影操作器(魔法二本)攻击召唤暗影分身",
            "Tech bonus: Science Machine +25% dmg, Alchemy Engine -25% taken, Prestihatitator +20% speed, Shadow Manipulator shadow minions"})),
    item("Wilson Skill Unlock", i18n({"威尔逊技能组解禁", "Wilson Unlock Skill"}),
        i18n({"全角色解锁月亮暗影,伍迪解锁三形态终极", "All Role Effect"})),
    --     item("Wilson More Recipes", i18n({"威尔逊更多炼金配方", "Wilson More Skill Recipes"})),
    item("Wilson Right Dodge", i18n({"威尔逊右键冲刺", "Wilson Right Dodge"}), i18n({"默认1秒CD", "Default 1s cd"}), 1, 0.5, 6,
        0.5),
    item("Wilson Right Self Everything Encyclopedia",
        i18n({"威尔逊右键自身施放万物百科", "Wilson Right Self Everything Encyclopedia"}),
        i18n({"默认30秒CD", "Default 30s cd"}), 30, 10, 240, 10),
    item("ctrl disable right", i18n({"右键动作按Ctrl低优先", "Press Ctrl Right Low priority"}), i18n(
        {"按住Ctrl时,角色原自带右键动作优先,为爽右键动作禁用或低优先", "When Press Ctrl,right action of the mod has lower priority"})),
    item("right self need ctrl", i18n({"右键自身动作需按Ctrl", "Press Ctrl Right Self"}),
        i18n({"按住Ctrl时,才能释放为爽右键自身动作,防止误触", "Unless Press Ctrl,disable right self action of the mod"}), false),
    item("willow_easy", i18n({"------------------------- 󰀈 薇洛总开关", "󰀈 Willow Master Switch"})),
    item("Willow Attack Dry/Burning Enemy", i18n({"薇洛狂热发光增伤", "Willow Attack Dry/Burning Enemy"}),
        i18n({"对潮湿冰冻/干燥/燃烧伤害为1/1.25/1.5且刷新狂热", "1/1.25/1.5x;Burning Frenzy/Bernie Battle Refresh"})),
    --     item("Willow Normal Kill Burning Enemy", i18n({"薇洛击败燃烧敌人正常掉落", "Willow Normal Kill Burning Enemy"}),
    --          i18n({"攻击后30秒内燃烧敌人正常掉落", "Make burning enemy normal drop loot in 30 seconds after attack"})),
    item("Willow Right Self Pyrokinetics Explained", i18n({"薇洛右键自身吸火控火", "Willow Right Self Pyrokinetics Explained"}),
        i18n({"默认3秒CD,薇洛200理智,余烬无限堆叠", "Default 3s cd,willow 200 sanity,Embers Unlimit stackable"}), 3, 3, 30, 3),
    item("Willow Fire Weapon Attack", i18n({"薇洛火焰武器增强效果", "Willow's Fire Weapon"}),
        i18n({"微洛切换火把打火机后仍有火焰,火焰笔火魔杖弹药改动", "Willow use torch/fire staff stronger"})),
    item("willow_improve", i18n({"薇洛优化", "Willow Improve"}),
        i18n({"影火优先打boss本体,牛上装备打火机1格地皮灭火、吸余烬,可控燃烧不烧玩家,过冷掉血降低.",
            "shadow_flame attack boss first,equip light on beefalo put out fire,controlled_burn not hurt player, FreezingHurtRate less"})),
    item("wolfgang_easy", i18n({"-------------------- 󰀙 沃尔夫冈总开关", "󰀙 Wolfgang Master Switch"})),
    item("Wolfgang break Powerup/down", i18n({"沃尔夫冈战斗时打断变身", "Wolfgang break Powerup/down"})),
    item("Wolfgang Strong Battle Speedup", i18n({"沃尔夫冈强壮时战斗加速", "Wolfgang Mighty Battle Speedup"}),
        i18n({"25%,8秒,且脱战饥饿速率降低(妥协模组后者无效)", "25%,8s,and leave battle hunger slow(UM Mod Unless)"})),
    item("Wolfgang Eat Food For Mightiness", i18n({"沃尔夫冈吃食物增加力量值", "Wolfgang Eat Food For Mightiness"}),
        i18n({"默认食物饥饿值的35%", "Default 35% hunger of food"}), 0.35, 0.5, 0.05, -0.05),
    item("Wolfgang Pause Drain When Satiated", i18n({"沃尔夫冈吃饱时不掉力量值", "Wolfgang Pause Drain When Satiated"}),
        i18n({"饥饿值高于100时不掉力量值,妥协模组无效", " Not drop when hunger value is higher than 100,UM Mod Unless"}), 100, 50, 150,
        10),
    item("wendy_easy", i18n({"------------------------- 󰀜 温蒂总开关", "󰀜 Wendy Master Switch"})),
    item("Wendy Low HP Abigail Damage", i18n({"温蒂低血阿比增伤", "Wendy Low HP Abigail Strong"}),
        i18n({"阿比在温蒂受伤的时候更加强壮", "Abigail is stronger when Wendy is hurt"}), false),
    item("Pipspook Give Random Ghostly Elixir", i18n({"帮助小惊吓给予随机药剂", "Pipspook Give Random Ghostly Elixir"}),
        i18n({"最后的玩具给予随机药剂", "only last toy must be rewarded"})),
    item("Abigail Level Protect", i18n({"阿比盖尔等级保护", "Abigail Level Protect"}),
        i18n({"温蒂死亡姐姐不降级但困难模式持续降级;姐姐死亡降1级", "Wendy Death not delevel Abigail but hard slow delevel"})),
    item("Wendy Share Light From Abigail", i18n({"温蒂共享阿比盖尔光源", "Wendy Share Light From Abigail"}), i18n({
        "阿比盖尔放出时共享光源",
        "in>1 share Shield(hard mode consume abigail's grow),when out share light"
    })),
    item("Wendy Share Debuff From Abigail", i18n({"温蒂阿比盖尔药剂优化", "Wendy Abigail Debuff Improve"}), i18n({
        "姐姐药剂同时生效;温蒂己用攻击药(收回>1级时易伤敌人,困难耗经验)/加速药",
        "Abigail can has All Debuff;Wendy use speed/attack(in>1) for self"
    })),
    item("wendy elixir_container", i18n({"温蒂野餐盒加强", "wendy Picnic Casket strengthen"}),
        i18n({"野餐盒可放料理、荣耀花环、蝴蝶翅膀、月蛾翅膀。其中翅膀永鲜,其余1.33倍。",
            "preparedfood,Wraith's Wreath and butterflywings can put in Picnic Casket"}), 1, 1, 2, 1, {
            i18n({"仅温蒂可打开", "only wendy can open"}),
            i18n({"全员可开", "everyone can open"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"仅温蒂可打开", "Wendy can open"}),
            i18n({"全员可开", "Everyone can open"})
        }, i18n({"禁用", "Disable"}), false),
    item("wx78_easy", i18n({"-------------------- 󰀔 WX-78总开关", "󰀔 WX-78 Master Switch"})),
    item("WX-78 Safe Remove Module", i18n({"WX-78拆电路板无损耗", "WX-78 Safe Remove Module"})),
    item("WX-78 Integrated Upgrade Module Level", i18n({"WX-78同种电路板融合升级", "WX-78 Integrated Upgrade Module Level"}),
        i18n({"同一个电路板最多发挥Max格插脚能力,生物数据修理", "The same circuit can have up to max pins,repair with Bio Data"})),
    item("WX-78 Eat Gears InCrease Data", i18n({"WX-78吃齿轮增加三维", "WX-78 Eat Gears Upgrade Self"}),
        i18n({"单个三维各加5点,增加15个;死亡恢复", "Per gear for 5 hunger/sanity/health,max 75.Recovery after death"})),
    item("wx78_module_pack", i18n({"WX-78右键虚拟芯片容器", "WX-78 Module Pack"}),
        i18n({"右键自身打开6格虚拟容器只能存放芯片/扫描仪/生物数据/钳子",
            "Right-click self to open 6-slot virtual container for modules/circuit boards"}), true),
    item("WX-78 Drone Optimization", i18n({"WX-78无人机优化", "WX-78 Drone Optimization"}),
        i18n({"各种无人机范围增加，空投无人机速度加快，破绽放大机可以移动扫描目标", "Increase the range of various drones, the speed of delivery drones, the shadowdrone can move and scan targets"})),
    item("wickerbottom_easy", i18n({"-------------------- 󰀏 薇克巴顿总开关", "󰀏 Wickerbottom Master Switch"})),
    item("Wickerbottom Is Not Insomniac", i18n({"薇克巴顿正常休息", "Wickerbottom Sleep In Tent"}),
        i18n({"可以进帐篷睡觉,但仍免疫外界催眠", "Can sleep into tent but still avoid hypnosis"})),
    item("Wickerbottom No Sanity Dapperness", i18n({"薇克巴顿更难降低理智", "Wickerbottom No Sanity Dapperness"}),
        i18n({"免疫黑暗怪物装备掉理智", "Immune to dark,monster or equipment"})),
    item("Wickerbottom Read Book Less Use", i18n({"薇克巴顿读书消耗更少耐久", "Wickerbottom Read Book Less Use"}),
        i18n({"理智越高,消耗耐久越少,满理智消耗0.35次", "Higher sanity, use less durability, 0.35 times when full sanity"})),
    item("Wickerbottom Use Staff", i18n({"薇克巴顿冰火魔杖施法", "Wickerbottom Red/Blue Staff"}),
        i18n({"冰魔杖造极光,火魔杖造火球", "Use Red/Blue Staff Spell"})),
    item("Wickerbottom Daily Book", i18n({"薇克巴顿右键自身书柜", "Wickerbottom Right Self Bookcase"}),
        i18n({"书柜每日一本免费魔法书,且随种类提高科技", "Every Day get a magic book short exist and update tech with books"})),
    item("Wickerbottom Temperature Book", i18n({"薇克巴顿控温书增强", "Wickerbottom Temperature Book"}),
        i18n({"读控温书后,范围内玩家锁定35度体温并提供100%防水4分钟", "After reading the temperature book, players in range lock body temperature at 35 and get 100% waterproof for 4 minutes"})),
    item("Knowledge is power", i18n({"知识就是力量", "Knowledge is power"}),
        i18n({"薇克巴顿伤害倍率随书籍解锁进度获得", "Wickerbottom more damage as unlocking books"})),
    item("Wickerbottom Repair Book With Papyrus", i18n({"奶奶莎草纸修书", "Wickerbottom/Wurt Repair Book With Papyrus"}),
        i18n({"奶奶可用莎草纸修复书籍,一张纸修复50%耐久", "Wickerbottom can repair books with papyrus, 1 papyrus = 50% durability"})),
    item("Wickerbottom Touch Astral Altar Unlock Celestial", i18n({"奶奶天体科技制作后永久解锁", "Wickerbottom Unlock Celestial After Crafting"}),
        i18n({"奶奶在天体科技下制作过一次物品后永久解锁天体科技,不再需要靠近", "After Wickerbottom crafts once under Celestial tech (altar/moon orb), Celestial tech stays unlocked permanently"})),
    item("woodie_easy", i18n({"------------------------ 󰀎 伍迪总开关", "󰀎 Woodie Master Switch"})),
    item("Woodie Strong Stomach Monster Meat", i18n({"伍迪吃生肉怪兽肉无减益", "Woodie Strong Stomach Monster Meat"})),
    item("Woodie Full Moon Not Become", i18n({"伍迪满月不变身获得随机俗气雕像", "Woodie Full Moon Not Change"}),
        i18n({"伍迪满月不变身获得随机俗气雕像", "Woodie full Moon does not change and get random kitschy idol"})),
    item("Woodie Hunger Wereness", i18n({"伍迪变身值使用饥饿值", "Woodie Hunger Wereness"}),
        i18n({"变身改用饥饿值,变身1.75倍饥饿速率但海狸工作回理智", "Woodie use Hunger as wereness;Beaver Work add sanity"})),
    item("Woodie Right Self Close Transform", i18n({"伍迪右键自身结束变身", "Woodie Right Self Close Transform"})),
    item("Woodie Moose Stronger Charge", i18n({"伍迪鹿人更猛烈地冲撞", "Woodie Moose Stronger Charge"}),
        i18n({"撞碎路途上的一切树木;露西斧正常斧头伤害", "Smash all the trees on the road;Luzy Has Axe Damage"})),
    item("Woodie Moose Random Scale", i18n({"伍迪鹿形态随机缩放", "Woodie Moose Random Scale"}),
        i18n({"鹿形态随机获得0.75到1.5倍体型,攻击力和血量;恢复人形后按当前生命比例还原",
            "Weremoose form gets 0.75 to 1.5 size, damage and max health; returning to human restores human stats by current health percent"})),
    item("wes_easy", i18n({"------------------------ 󰀕 韦斯总开关", "󰀕 Wes Master Switch"})),
    item("Wes Normal Data Attack Work", i18n({"韦斯正常三维攻击伤害工作效率", "Wes Normal Data Attack Work"})),
    item("Wes Right Dodge Collide Balloon", i18n({"韦斯连续右键冲刺", "Wes Right Dodge Double"}),
        i18n({"默认2秒CD", "Default 2s cd"}), 2, 1, 10, 0.5),
    item("Balloon Stackable Per 50 Damage", i18n({"气球伤害50堆叠10", "Balloon Stackable Per 50 Damage"}),
        i18n({"对玩家依旧5点伤害,廉价火药;堆叠气球缠绕敌人", "Still 5 damage for player;max stack size 10;>=5 balloons can slow enermy"})),
    item("Equip Balloon Increase Speed", i18n({"气球装备增加移速和耐久", "Equip Balloon Increase Speed"}),
        i18n({"全种类气球装备有1.1倍移速加成和至少2天耐久", "Each balloon equipment lasts for 2 days with an additional speed of 1.1x"})),
    item("Equip Balloon Summon Tornado", i18n({"气球装备制造旋风", "Equip Balloon Summon Tornado"}),
        i18n({"挨打不伤己会反击旋风;旋风不损坏建筑", "Attacked not hurt and tornado don't destory structure"})),
    item("waxwell_easy", i18n({"-------------------- 󰀖 麦斯威尔总开关", "󰀖 Maxwell Master Switch"})),
    item("Maxwell Normal Health", i18n({"麦斯威尔150生命值", "Maxwell Has 150 Health"}),
        i18n({"麦斯威尔150点生命值", "Maxwell Has 150 Health"})),
    item("Maxwell Eat Petals Get Dark Petals", i18n({"麦斯威尔吃花瓣时获得恶魔花瓣", "Maxwell Eat Petals Get Dark Petals"}), false),
    item("Maxwell Unlock Dark Sword/Armor", i18n({"麦斯威尔解锁暗夜剑暗夜甲", "Maxwell Unlock Night Sword/Armor"})),
    item("Maxwell Right Lunge", i18n({"麦斯威尔右键闪袭", "Maxwell Right Lunge"}),
        i18n({"需要暗影等级不小于4,AOE伤害,6秒CD", "Need Shadow Level >= 4,aoe attack,6s cd"})),
    item("right Lunge need ctrl", i18n({"右键闪袭需要按住Ctrl", "Maxwell Lunge Need Press Ctrl"}),
        i18n({"按住Ctrl时,才能释放为爽右键闪袭动作,防止误触", "Unless Press Ctrl,disable right Lunge action"}), false),
    item("Maxwell Attacked Disappear", i18n({"麦斯威尔受击闪烁", "Maxwell Attacked Disappear"}),
        i18n({"需要暗影等级不小于4,0.5概率躲避此次攻击,4~20秒CD", "Need Shadow Level >= 4,50% chance avoid this attack,4~20s cd"})),
    item("Maxwell Right Self Sleepytime Stories", i18n({"麦斯威尔右键自身施放睡前故事", "Maxwell Right Self Sleepytime Stories"}),
        i18n({"默认30秒CD", "Default 30s cd"}), 30, 10, 120, 10),
    item("wigfrid_easy", i18n({"-------------------- 󰀘 薇格弗德总开关", "󰀘 Wigfrid Master Switch"})),
    item("Wigfrid Inspiration Not Drop", i18n({"薇格弗德激励值脱战不掉落", "Wigfrid Inspiration Not Drop"}),
        i18n({"饥饿值和武器耐久增强", "DURABILITY/FIRE_RESIST Upgrade"})),
    item("Wigfrid can eat any", i18n({"薇格弗德啥都能吃吃肉食溢出获得灵感", "eat any"})),
    item("Wigfrid Ride Right Dodge", i18n({"薇格弗德骑乘时右键冲刺", "Wigfrid Ride Right Dodge"}),
        i18n({"默认1秒CD", "Default 1s cd"}), 1, 0.5,
        6, 0.5),
    item("Wigfrid Right Self Reprise", i18n({"薇格弗德右键自己战士重奏", "Wigfrid Right Self Warrior's Reprise"}),
        i18n({"战士重奏复活队友,后续能力会短暂覆盖", "Warrior's Reprise Revive Player,later option will short override"})),
    item("Rude Interlude Provide Battle Helm", i18n({"粗鲁插曲提供全员头盔耐久", "Rude Interlude Provide Battle Helm"}),
        i18n({"吟唱粗鲁插曲12秒内右键自己重奏触发", "right self in 12s after Sing Rude Interlude"})),
    item("Startling Soliloquy Provide Battle Spear", i18n({"惊心独白提供全员武器耐久", "Startling Soliloquy Provide Battle Spear"}),
        i18n({"吟唱惊心独白12秒内右键自己重奏触发", "right self in 12s after Sing Startling Soliloquy"})),
    item("battlesong_durability_sanitygain",
        i18n({"武器化的颤音/英勇美声颂加强", "battlesong_durability/battlesong_sanitygain change"}),
        i18n({"攻击后短暂加伤/攻击后短暂加速", "add damage/speed after attack"})),
    item("aoespell change", i18n({"矛盾右键动作改进", "Spear/Shield Straight Right"})),
    item("Valkyrie thunder sprints without shaking", i18n({"武神奔雷冲刺无前摇", "Valkyrie thunder sprints without shaking"})),
    item("Charged Elding Spear negative buff", i18n({"充能奔雷冲刺削弱", "Charged Elding Spear negative buff"})),
    item("webber_easy", i18n({"------------------------- 󰀗 韦伯总开关", "󰀗 Webber Master Switch"})),
    item("Webber Eat Meat Lead Wild Spider", i18n({"韦伯吃肉食收买附近蜘蛛", "Webber Eat Meat Lead Wild Spider"}),
        i18n({"饥饿>102消耗3额外收买1直至100饥饿;随从不吃地面食物且跟随灵魂", "Hunger > 105 consumes 6 extra buys 1 to 100 hunger"})),
    item("Webber Eat Switcherdoodle Switch Spider", i18n({"韦伯吃涂鸦升级黑蜘蛛随从", "Webber Eat Switcherdoodle Switch Spider"}),
        i18n({"饥饿>124时消耗25额外升级1直至100饥饿", "Hunger > 124 costs 25 extra upgrade 1 to 100 hunger"})),
    item("Webber Murder Spider Get Switcherdoodle", i18n({"韦伯谋杀非黑蜘蛛时获得涂鸦", "Webber Murder Spider Get Switcher doodle"}),
        i18n({"饥饿>149消耗x饥饿获得1个", "Hunger > 149 consumes x hunger to get one"}), 75, 50, 150, 25),
    item("Webber 200 Sanity", i18n({"韦伯200理智", "Webber 200 Sanity"}),
        i18n({"韦伯理智上限提升为200", "Webber sanity max becomes 200"})),
    item("Webber Right Self Overcoming Arachnophobia",
        i18n({"韦伯右键加强", "Webber Right Self"}),
        i18n({"0关闭;1蛛网恐惧(右键自己读蛛网魔法书,15秒CD);2蜘蛛容器(右键自己打开3×3蜘蛛窝,蜘蛛在内缓慢恢复新鲜度)",
            "0 off;1 spider fear(right self read web book,15s cd);2 spider bag(right self open 3x3 bag, spiders restore freshness)"}),
        1, 0, 2, 1, {
            i18n(""),
            i18n({"蛛网恐惧:右键自己读蛛网魔法书", "Spider fear: right self read web book"}),
            i18n({"蜘蛛容器:右键自己打开3×3蜘蛛窝,只能放各种蜘蛛", "Spider bag: right self open 3x3 bag, only spiders"})
        }, nil, {i18n("禁用"), i18n("启用"), i18n("启用")}),
    item("Webber Uprade SpiderDen SpiderQueen", i18n({"韦伯升级三级蜘蛛巢为女王", "Webber Uprade SpiderDen SpiderQueen"}),
        i18n({"但困难模式蜘蛛巢改为需要给食物升级了", "Hard mode spider den replace give food to upgrade"})),
    --     item("spider_healer", i18n({"护士蜘蛛溢出回血", "Healer Spider Protect Health"}), i18n({
    --         "溢出回血持续生效;但困难模式技能嘲讽限制数目且有生效冷却",
    --         "extra health continue;Hard mode heal taunt/limit num/effect has cd"
    --     })),
    item("Spider Help Work", i18n({"蜘蛛协助工作", "Spider Help Work"})),
    item("Hat Trick", i18n({"帽子戏法", "Hat Trick"}),
        i18n({"戴上帽子  目前 仅限韦伯", "just put on your hat . only for webber now"})),
    item("winona_easy", i18n({"---------------------- 󰀌 薇诺娜总开关", "󰀌 Winona Master Switch"})),
    item("Winona No Hungry Builder", i18n({"薇诺娜制作不再受饥饿值影响", "Winona No Hungry Builder"})),
    item("Winona Toolbox Tools", i18n({"薇诺娜工具箱可存放工具", "Winona Toolbox Stores Tools"}),
        i18n({"薇诺娜可以制作工具箱，并在其中存放斧头、镐、铲子等工具。开启后优先应用淬炼版的存放规则，兼容永不妥协正式版和测试版。",
              "Winona can craft a toolbox that also stores tools such as axes, pickaxes, and shovels. Overrides the tool restriction in both editions of Uncompromising Mode."})),
    item("Winona Generator Ground Charging", i18n({"发电机为地面电器充电", "Generators Charge Dropped Devices"}),
        i18n({"放在运转发电机供电范围内的电器会自动充电，兼容永不妥协转换后的提灯、矿工帽等。",
              "Dropped electrical devices recharge within range of a running generator, including electrically converted equipment from Uncompromising Mode."})),
    item("Winona Electrical Upgrades", i18n({"薇诺娜电气改造与过充", "Winona Electrical Upgrades and Overcharging"}),
        i18n({"电能转换套件可改造提灯、矿工帽和鼹鼠帽，耗能降低25%。薇诺娜装备电气装备触摸发电机，充过100%后解锁该件装备的200%过充和特殊效果；解锁后地面充电也可达200%。过充不增加耗能。兼容永不妥协正式版和测试版，共用一个套件。",
              "Convert lanterns, miner hats and moggles with 25% lower consumption. Winona must equip an item and charge it at a generator past 100% to unlock 200% overcharging, including ground charging. Overcharging adds no consumption penalty. Shares one kit with either UM edition."})),
    item("Winona Hammer Drop All Loot", i18n({"薇诺娜敲掉建筑获得全部材料", "Winona Hammer Drop All Loot"})),
    item("Winona Rotating Weapon Perpetual Attack", i18n({"薇诺娜右键旋转武器", "Winona Right Rotating Weapon"}),
        i18n({"旋转闪避,2秒CD,2.5秒1.5倍伤害和5秒1.33倍加速", "short invincible,2.5s 1.5x damage,5s 1.33x speed,2s CD"})),
    item("Winona Control Chess", i18n({"薇诺娜控制发条看守", "Winona Control Chess"}),
        i18n({"薇诺娜可以令发条随从看守当前位置", "Winona Control Chess Save Current Pos As Spawn Pos"})),
    item("Winona Right Self Hide Structures", i18n({"薇诺娜右键自身折叠建设", "Winona Right Self Hide Structures"}),
        i18n({"默认15秒CD", "Default 15s cd"}), 15, 5, 60, 5),
    item("warly_easy", i18n({"------------------------- 󰀨 沃利总开关", "󰀨 Warly Master Switch"})),
    item("Warly Eat Food Double Health Sanity", i18n({"沃利食物双倍生命理智", "Warly Eat Food 200% Health/Sanity"})),
    item("Warly Food Memory Only Sanity", i18n({"沃利食物惩罚削弱", "Warly Food Memory Only Sanity"}),
        i18n({"沃利重复食物仅理智惩罚;负面减免50%(2*0.5)", "Warly Same Food Only Reduce Sanity;Bad Reduce 50%(2*0.5)"})),
    item("Warly Use Perishable Weapon", i18n({"沃利使用新鲜度武器增伤", "Warly Use Perishable Weapon"}),
        i18n({"新鲜度1.75/1.25/0.75倍伤害", "More fresh more damage,1.75/1.25/0.75x damage"})),
    item("Warly Free Cook Per Day", i18n({"沃利烹饪返还食材", "Warly Cook Not Consume"}), i18n(
        {"沃利每天首次烹饪返还首个食材,困难模式35%概率返还次格", "Warly First Cook don't consume first or second Ingredient Every Day"})),
    item("Warly Food Collect", i18n({"沃利收集食谱增加理智", "Warly Collect Cooking Food"}),
        i18n({"沃利每烹饪出一种新料理加1理智上限", "Per New Cooking Food Add 1 Max Sanity"})),
    item("Warly Right Self Action", i18n({"沃利右键自身动作", "Warly Right Self Action"}),
        i18n({"沃利右键自身动作可选烹饪锅或园艺学", "Warly right self action can be selected as a cooking pot or horticulture"}),
        true, nil, nil, -1, {
            i18n({"沃利右键自身施放园艺学简编版", "Warly Right Self Horticulture Abridged"}),
            i18n({"沃利右键自身打开便携烹饪锅;困难模式不自带锅", "Warly Right Self Open a portable Cookpot"})
        }),
    item("Warly Right Self Horticulture Abridged", i18n({"沃利右键自身动作园艺学简编版CD", "Warly Horticulture Abridged CD"}),
        i18n({"默认240秒CD", "Default 240s cd"}), 120, 10, 240, 10),
    item("walter_easy", i18n({"---------------------- 󰀤 沃尔特总开关", "󰀤 Walter Master Switch"})),
    item("Walter No Damage Lose Sanity", i18n({"沃尔特受伤害时不再损失理智", "Walter No Damage Lose Sanity"}),
        i18n({"理智险境开启时仍受险境掉SAN影响", ""})),
    item("Walter Has Other Pet", i18n({"沃尔特正常领养宠物", "Walter Can Has Pet"}),
        i18n({"四本暗影傀儡需要此项;且妥协沃比吃肉", "So he can normal use shadow magic"})),
    item("Walter Throw Slingshot First Attack", i18n({"沃尔特弹弓攻击优化", "Walter Slingshot Attack Fix"}),
        i18n({"兼容妥协勋章;困难模式沃尔特妥协蓄力连发伤害削弱", "UM/Medal Mod support walter Force Enable Slingshot"}), true, nil, nil,
        -1, {
            i18n({"沃尔特弹弓攻击优化，兼容永不妥协与勋章", "Walter slingshot compatibility with UM and Medal"}),
            i18n({"普通攻击前扔接弹弓,4.5秒内2倍伤害", "Throw Slingshot Before Simple Attack;4.5s 2x damage"})
        }),
    item("Walter Right Dodge Longer", i18n({"沃尔特骑乘时连续右键冲刺", "Walter Ride Right Dodge Double"}),
        i18n({"默认2秒CD", "Default 2s cd"}),
        2, 1, 10, 0.5),
    item("Walter Hide Woby", i18n({"沃尔特ctrl右键自身收回沃比", "Walter Hide Woby"})),
    item("Walter Ride Better", i18n({"骑乘沃比获得保护", "Better Safe Big Woby Mount"}),
        i18n({"沃比帮助闪避敌人攻击有CD;沃尔特摔下时暂时无敌", "Big Woby Protect Walter When Ride"})),
    item("Walter press Ctrl can't Dodge", i18n({"沃尔特按ctrl禁止滑铲", "Walter press Ctrl can't Dodge"}),
        i18n({"骑乘按ctrl+右键冲刺, 开启妥协改动时装备弹弓无法冲刺",
            "Walter press Ctrl can't Dodge, equipment slingshot cannot sprint when weixi and walter(Uncompromising) is enabled"})),
    item("Walter Use Wixie Slingshot", i18n({"沃尔特可使用维希弹弓", "Walter Use Wixie Slingshot"}),
         i18n({"仅在启用永不妥协时显示，默认开启。沃尔特可用原版弹药操作维希专属弹弓，专属弹药由维希制作和使用。",
               "Shown only with Uncompromising Mode enabled. On by default. Walter uses native ammo in Wixie's slingshots. Special ammo is exclusive to Wixie."}), true),
    item("Wixie No Claustrophobia", i18n({"维希：移除幽闭恐惧", "Wixie: No Claustrophobia"}),
        i18n({"独立于沃尔特和永不妥协补丁；兼容正式版及测试版，清除幽闭积累、恐慌与视觉效果",
            "Independent of Walter and UM patch; supports stable/Beta fear, panic and overlay removal"}), true),
    item("wortox_easy", i18n({"-------------------- 󰀀 沃拓克斯总开关", "󰀀 Wortox Master Switch"})),
    item("Wortox Eat Food Normal", i18n({"沃拓克斯吃食物获得75%三维", "Wortox Eat Food 75% H/S/H"})),
    item("Wortox Has No Soul Limit", i18n({"沃拓克斯无限制灵魂", "Wortox Has No Soul Limit"}),
        i18n({"无限堆叠;不再溢出;死亡不掉落灵魂", "Unlimit stackable;No Limit;Don't Drop when death"})),
    item("Wortox Free Blink", i18n({"沃拓克斯单次传送无消耗", "Wortox Free Blink First"})),
    item("Wortox Use Soul Attack", i18n({"沃拓克斯的灵魂飞弹", "Wortox Use Soul Attack"})),
    item("Wortox damage upgrade", i18n({"沃拓克斯三维高时增伤", "Wortox Upgrade Damage"}),
        i18n({"每个高于90%的三维增加0.35伤害(困难模式0.25)", "Per >90% Hunger/Health/Sanity will add 0.35 damage,hard mode 0.25"})),
    item("Wortox Auto Receive Soul", i18n({"沃拓克斯灵魂少时自动获得灵魂", "Wortox Auto Receive Soul"}),
        i18n({"困难模式额外削弱免费排箫冷却", "Hard mode extra increase panflute inspiration time"})),
    item("wormwood_easy", i18n({"-------------------- 󰀇 沃姆伍德总开关", "󰀇 Wormwood Master Switch"})),
    item("Wormwood Eat Food Normal", i18n({"沃姆伍德吃食物获得75%生命", "Wormwood Eat Food 75% Health"})),
    item("Wormwood Right Self To Hide", i18n({"沃姆伍德右键自身隐藏休憩", "Wormwood Right Self To Hide/Rest"})),
    item("Wormwood Regrow Farm Plant", i18n({"沃姆伍德采集农作物再生", "Wormwood Regrow Farm Plant"}),
        i18n({"困难模式需要高级耕作先驱帽", "Hard mode need Premier Gardeneer Hat"})),
    item("Wormwood TendTo Farm Plant Reduce Grow Time",
        i18n({"沃姆伍德生长中安抚植物减少生长时间", "Wormwood TendTo Farm Plant Reduce Grow Time with bloomness"})),
    item("Wormwood Soul Heal Soil", i18n({"沃姆伍德灵魂治愈地裂", "Wormwood Soul Heal Soil"})),
    item("Wormwood Photosynthesis", i18n({"沃姆伍德白天进行光合作用", "Wormwood Photosynthesis in day"})),
    item("Wormwood Eat Rewards Equip", i18n({"沃姆伍德吃食物获得装备", "Wormwood Eat Rewards Equip"}),
        i18n({"概率,苔藓骨头头盔,种子耕作帽,果蔬获得种子,石果蘑菇等...", "Fruits/Veggies give seeds,Seeds Give Gardeneer Hat..."}), 1, 1, 2, 1,
        {
            i18n({"装备不可脱下", "Equipment cannot be removed"}),
            i18n({"装备可取下且具有新鲜度", "Equipment is removable and has freshness"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"启用", "Original backwards"}),
            i18n({"启用", "Towards the back"})
        }),
    item("Wormwood Eat Seeds Debuff", i18n({"沃姆伍德吃杂草能获得buff", "Wormuwood have buff"})),
    item("Wormwood Thorns Generate Spiny Bindweed", i18n({"荆棘陷阱触发时触发刺藤", "citeng"}), i18n({"荆棘陷阱触发时触发刺藤", "citeng"}),
        false),
    item("armor_bramble damage", i18n({"荆棘甲加强", "armor_bramble damage"}),
        i18n({"荆棘甲反伤34点,荆棘甲不反伤牛/鹿/玩家", "armor_bramble spikes 34 damage, not attack beefalo/player/deer"})),
    item("wormwood_eat_fire", i18n({"沃姆伍德吃东西2秒后灭火", "Wormuwood put out self fire after eat 2s"})),
    -- item("Wormwood Right Self Horticulture Abridged", i18n({"植物人右键自身施放园艺学简编版", "Wormwood Right Self Horticulture Abridged"}),-- i18n({"默认240秒CD", "Default 240s cd"}), 120, 10, 240, 10),
    item("wurt_easy", i18n({"------------------------- 󰀐 沃特总开关", "󰀐 Wurt Master Switch"})),
    item("wurt_merm_stronger", i18n({"鱼人堡垒材料增加", "Wurt Merm Stronger"}),
        i18n({"堡垒造价提升:10木板+2触手皮+2长矛+2猪皮", "watchtower cost up:10 boards+2 tentaclespot+2 spear+2 pigskin"}), true),
    item("Wurt Eat Food Lead Wild Merm", i18n({"沃特吃食物收买附近鱼人", "Wurt Eat Food Lead Wild Merm"}),
        i18n({"饥饿>101消耗2额外收买1直至100饥饿", "Hunger > 102 consumes 3 extra buys 1 to 100 hunger"})),
    item("Wurt Eat Food Loyalty Follower", i18n({"沃特吃食物提高鱼人随从忠诚", "Wurt Eat Food Loyalty Follower"}),
        i18n({"饥饿>151消耗2额外延长1直至100饥饿", "Hunger > 152 consumes 3 extra and prolongs 1 to 100 hunger"})),
    item("Mermking Won't Hungry", i18n({"鱼人王不再饥饿", "Mermking Won't Hungry"})),
    --     item("Mermking Multi World Share", i18n({"鱼人王世界共享", "Mermking Multi World Share"})),
    item("Trade Fish with Merm", i18n({"和普通鱼人交易海鱼", "Trade Fish with Merm"}),
        i18n({"每天首次就像鱼人王一样;可给武器", "Once A day like mermking;Give Weapon"})),
    item("Wurt can eat any", i18n({"鱼妹沃特可以吃肉，但收益只有30%", "Wurt can eat meat, but the profit is only 30%"})),
    item("Wurt Can Craft Book Fish", i18n({"鱼妹可制作鱼类之书", "Wurt Can Craft Book Fish"}),
        i18n({"鱼妹可以制作鱼类之书", "Wurt can craft the book of fish"})),
    item("wanda_easy", i18n({"------------------------- 󰀱 旺达总开关", "󰀱 Wanda Master Switch"})),
    item("Wanda Don't Auto Drop Age", i18n({"旺达不再持续衰老", "Wanda Don't Auto Drop Age"}), false),
    item("Ageless Watch Help Temperature", i18n({"不老表恢复温度", "Ageless Watch Temperature Help"})),
    item("wanda strengthen", i18n({"旺达加强", "wanda strengthen"}),
        i18n({"警钟伤害68、81、119，60岁老年，衰老更慢，死亡有骨架", "wanda strengthen"})),
    item("pocketwatch_heal2hm", i18n({"裂开的不老表", "Wanda pocketwatch_heal2hm"}),
        i18n({"瞬间使用，回血、回san、回温、回饥饿上限、无敌0.3秒、短暂发光",
            "Instant use, restore health, restore san, restore temperature, restore hunger limit, invincible for 0.3 seconds, briefly glowing"})),
    item("pocketwatch strengthen", i18n({"钟表加强", "pocketwatch strengthen"}),
        i18n({"不老表回血抵消险境,警钟猫鞭触发夹击,猫鞭吃年龄加伤开局可做,倒走表无敌0.3秒",
            "watch_weapon trigger horn_attack. whip can make start.watch_warp invincible 0.3s"})),
    item("pocketwatch_weapon at start",
        i18n({"警钟开局可做但配方增加1黄宝石", "can make pocketwatch_weapon at start,but requires yellowgem"})),
    item("Wanda Dread Watch", i18n({"恐惧-警告表(暗影心房升级)", "Wanda Dread Clock"}), i18n({
        "附身暗影心房升级警钟,升级后只能用纯粹恐惧加耐久;每次攻击+12%攻速(最多6层),叠满额外34位面伤害和20%攻击距离,3秒未续攻击或挨打清空层数",
        "Upgrade the Alarming Clock with an Infused Shadow Heart. After upgrade only Pure Horror can refuel it; each hit gives +12% attack speed (up to 6 stacks), at full stacks +34 planar damage and +20% attack range; stacks reset after 3s without attacking or when hit"
    })),
    item("wanda Eat Petals Get Dark Petals", i18n({"旺达吃花瓣时获得恶魔花瓣", "wanda Eat Petals Get Dark Petals"})),
    item("Wanda Right Wrapback", i18n({"旺达右键倒走", "Wanda Right Warpback"}), i18n({"无敌0.3秒", "allmiss 0.3s"}), 1, 1, 2,
        1, {
            i18n({"船上会在原地倒走", "warpback to present position on boat"}),
            i18n({"船上会在原地倒走,使用会扣除1年龄,老年0.5", "warpback to present position on boat.Using reduces 1 age (0.5 for old)"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"原版倒走", "Original backwards"}),
            i18n({"往正后方倒走", "Towards the back"})
        }, i18n({"禁用", "Disable"}), false),
    item("Wanda Right Wrapfront", i18n({"旺达右键未来行走", "Wanda Right Warpfront"}), i18n({"娱乐选项", "FOR FUN"}), false, 2,
        20, 1),
    item("right Wrapback need ctrl", i18n({"右键倒走需要按住Ctrl", "Warpback Need Press Ctrl"}),
        i18n({"按住Ctrl时,才能释放为爽右键倒走动作,防止误触", "Unless Press Ctrl,disable right Warpback action"}), false),
    item("Wanda Right Self Backtrek", i18n({"旺达右键自身裂缝表", "Wanda Right Self Rift Watch"})),
    item("Wanda Resurrect Self", i18n({"旺达按钮复活自己", "Wanda Button Resurrect Self"}), i18n(
            {"旺达死亡时世界不重置,右上角按钮复活自己(有CD)", "Wanda death stop world reset,right top button resurrect self(has cooldown)"}),
        true, nil, nil, -1,
        {i18n({"仅旺达有此复活按钮", "Only Wanda Has The Button"}), i18n({"全角色都有此复活按钮", "All Roles Has The Ability"})}),
    item("wonkey_easy", i18n({"------------------------- 󰀂 芜猴总开关", "󰀂 Wonkey Master Switch"})),
    item("Start With Wonkey Disable Transform", i18n({"芜猴开局可选", "Start With Wonkey"}),
        i18n({"诅咒饰品不再导致变身", "Disable accursed trinket transform"})),
    item("Wonkey Run Wait Time", i18n({"芜猴助跑时间缩短", "Wonkey Run Wait Shorter Time"}),
        i18n({"默认步行0.5秒后奔跑,且奔跑无额外饥饿消耗", "Run Wait N Seconds,and run no extra consume hunger"}), 1, 0.5, 5, 0.5),
    item("Wonkey Right Self summon the powder_monkey", i18n({"芜猴右键自身召唤海棠小分队作战", "Wonkey Right Self Action"})),
    item("Wonkey Attack Steal item", i18n({"芜猴攻击偷取物品", "Wonkey Attack Steal item"})),
    item("Wonkey Toss Poop", i18n({"芜猴投掷便便", "Wonkey Toss Poop"})),
    item("Wonkey Remove Curse", i18n({"芜猴吃香蕉消除诅咒饰品", "Wonkey Eat Banana Remove Curse"}),
        i18n({"也可以吃浆果,有概率,被喂养则喂养者消除诅咒饰品", "Aslo Berry;Has Chance;Feed your wonkey teammate to remove your curse"})),
    item("other_role_easy", i18n({"------------------------ 其它角色总开关", "Other Role Master Switch"})),
    item("wathom upgrade", i18n({"󰀕 沃托姆饥饿/伤害/受伤/能量调整", "󰀕 Wathom Damge/Adrenal"}),
        i18n({"饥饿150;仅虚弱7.5秒;护甲不额外受伤;脱战时间翻倍;回档恢复能量",
            "hunger 150;not extra armor;Out of combat time 2x;rollback recover adrenal;weak 7.5s"}), 2, 1, 2, 1, {
            i18n({"激活伤害2x 承伤1.6x", "amped 2x damage, 1.6x taken"}),
            i18n({"激活伤害4x 承伤2.5x", "amped 4x damage, 2.5x taken"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"伤害2x 承伤1.6x", "2x dmg,1.6x taken"}),
            i18n({"伤害4x 承伤2.5x", "4x dmg,2.5x taken"})
        }, i18n({"禁用", "Disable"}), false),
    item("Monster Night Vision", i18n({"怪物角色夜视（独立开关）", "Monster Player Night Vision"}),
        i18n({"韦伯、鱼妹、芜猴及带monster标签的玩家获得稳定夜视（排除沃托克斯）；夜视不依赖模式。开启简单模式和对应角色强化后，前三位夜晚不掉理智",
            "Stable night vision for Webber, Wurt, Wonkey, and monster-tagged players except Wortox, regardless of mode. The first three also avoid night sanity drain with their Easy Mode character perks enabled"})),
    item("wathom nightvision", i18n({"沃托姆夜视优化（独立开关）", "Wathom Stable Night Vision"}),
        i18n({"仅在启用永不妥协正式版或测试版时显示。提供稳定夜视并移除回声黑雾与心跳，开启怪物角色夜视也会生效。",
            "Shown with Uncompromising Mode stable or beta enabled. Steady night vision without sonar fog or heartbeat. Also enabled by Monster Player Night Vision."})),
    item("All Right Dodge", i18n({"全员右键冲刺", "All Right Dodge"}),
        i18n({"娱乐选项;需关闭其他角色的右键动作否则无效;默认1秒CD", "FOR FUN;Default 1s cd"}), false, 0.5, 6, 0.5),
    item("Role Gym", i18n({"全员健身房健身", "All Mighty Gym"}), i18n({" ", " Only Mighty Gym can update mightyness"}), true,
        nil, nil, -1, {
            i18n({"威尔逊维克巴顿韦斯沃姆伍德Winky1.75,其他1.5,沃托姆1.35",
                "Wilson/Wickerbottom/Wes/Wormwood/Winky1.75,other1.5,wathom1.35"}),
            i18n({"全员可制作健身房", "All roles can make Mighty Gym"})
        }),
    item("avoidselfdmg", i18n({"自伤避免", "Avoid Self Attack"}),
        i18n({"玩家对自己的无武器攻击不再有伤害了", "player attack self dmg is 0 unless weapon"})),
    item("All dumbbell heat", i18n({"全员热铃", "dumbbell_heat for all"}),
        i18n({"所有人都可以制作热铃,但是会修改热铃配方.我们觉得使用热铃是懦弱的表现", "everyone can craft dumbbell_heat but modify its recipe"}), false),
    item("enter gift 2", i18n({"新人礼物", "Enter gift"}),
        i18n({"提供更多的首次进入礼物,受其他设置影响.季节礼物", "provide more gift for new player, effect by other config.Season gifts"})),
    spaceitem(),
    headeritem(i18n({"󰀕 困难模式", "󰀕 Hard Mode"})),
    headeritem(i18n({"角色改动", "Charaters"})),
    item("role_nerf", i18n({"困难模式角色改动总开关", "Switch for Charaters of Hard Mode"})),
    item("role_battle", i18n({"生存险境", "Danger Health"}), i18n(
            {
                "掉血配方掉一半黑血;治疗道具溢出时恢复黑血;强心针需血囊",
                "craft munu has half health penalty;Heal Item can heal some penalty"
            }), -1, -1, -2, -1,
        {i18n({"承受伤害+20%,回血-20%", "+20% damage taken, heal-20%"}), i18n({"承受伤害+33%,回血-33%",
            "+33% damage taken, heal -33%"})}),
    item("role_sanity", i18n({"理智险境", "Danger Sanity"}), i18n(
            {"掉血时按比例掉理智,不会掉到血量比下;重复单位增益理智光环取最大", "lose sanity when damaged (From Walter) and overeat"}),
        -2, -1, -2, -1, {
            i18n({"掉血时掉一半理智,吃撑掉一半溢出理智", "lose 0.5x sanity when damaged and overeat"}),
            i18n({"掉血时掉同样理智,吃撑掉一半溢出理智", "lose 1x/0.5x sanity when damaged and overeat"})
        }),
    item("role_hunger", i18n({"饥饿险境", "Danger Hunger"}), i18n({
        "饥饿死亡有饥饿上限惩罚,肉海带种子干/新鲜回血食物/强心针(需蛙腿,效能翻倍)恢复",
        "Hunger Has Penalty.Eat Dried/Fresh Health Food or Booster Shot to Heal"
    })),
    {
        name = "combat", label = i18n({"战斗险境", "Combat Reduce"}), default = 4,
        hover = i18n({"检查拳击袋可开关伤害显示。旧默认1档自动升级为锋芒渐敛；仍可手动选择传统档位。",
            "Inspect a punching bag to toggle damage details. The old default migrates to Tempered Edge; traditional tiers remain selectable."}),
        options = {
            {description = disabletext, data = false},
            {description = i18n({"传统1档", "Traditional 1"}), data = "traditional_1",
                hover = i18n({"使用原版机制，增益伤害全部乘算", "Original multiplicative bonuses"})},
            {description = i18n({"传统2档", "Traditional 2"}), data = 2,
                hover = i18n({"先乘算后加算：小于1.5的倍率乘算，大于等于1.5的倍率加算", "Multiply bonuses below 1.5, then add bonuses of 1.5 or higher"})},
            {description = i18n({"传统3档", "Traditional 3"}), data = 3,
                hover = i18n({"倍率上限2.5倍，多余转为减伤和移速", "Cap at 2.5x; excess grants defense and speed"})},
            {description = i18n({"锋芒渐敛（默认）", "Tempered Edge (default)"}), data = 4,
                hover = i18n({"普通2.5起递减趋近4倍，位面2起递减趋近3.5倍；普通10倍压缩为3.75倍，无溢出生存补偿",
                    "Regular 2.5->4x, planar 2->3.5x; regular 10x becomes 3.75x; no overflow defense/speed"})},
        },
    },
    item("regen_danger", i18n({"恢复险境", "Danger Regen"}), i18n({
        "吃东西缓慢回血,挨打后恢复效果受到折扣",
        "Eating heals slowly over time;recovery is reduced after getting hit"
    }), true),
    item("stand_fight_danger", i18n({"易伤险境", "Danger Vulnerable"}), i18n({
        "开启后常驻20%减伤;被Boss攻击后获得易伤:每次受击+20%受伤,最多+100%,每秒消除10%",
        "Always 20% dmg reduction. When hit by boss, gain vulnerable debuff. Each hit +20% dmg taken(max +100%), decays 10%/sec"
    }), true),
    item("death_danger", i18n({"死亡险境", "Danger Death"}), i18n({
        "Boss附近有玩家死亡恢复1000生命,有生物(怪物/动物)死亡恢复200生命",
        "Boss heals 1000 when player dies nearby, 200 when creature (monster/animal) dies nearby"
    }), true),
    item("pvp_force", i18n({"友伤险境", "Betrayed Friends"}),
        i18n({"玩家无法互相攻击，但道具和随从仍可能误伤", "Players maybe attacked by mates' tools and followers"})),
    item("leader", i18n({"领袖险境", "Leader Limit"}),
        i18n({"玩家最多有x个有血量和攻击力的重复随从;超过则旧随从离开", "Max GroundHealthCombatRepeatFollower Number"}), 10, 8, 40, 1),
    -- item("haitang_curse", i18n({"海棠语险境", "speak like haitang"}), i18n({"诅咒会导致你情不自禁使用海棠语", "curse make you say money words"})),
    item("haitang_curse_2", i18n({"海棠语险境", "speak like haitang"}),
        i18n({"诅咒会导致你炫耀自己的半吊子海棠语", "curse make you say money words"})),
    item("Items collect danger", i18n({"快捷收集存放功能险境", "Items collect/store danger"}),
        i18n({"每次收集或存放物品会扣除0.2饥饿值", "use items collect/store will decrease 0.2 hunger"})),
    item("soul_wild", i18n({"魂游荒野", "Soul Wilderness"}), i18n({
        "灵魂有血怕太阳,作祟可灭火;灵魂死亡则大门/荒野忘却配方地图再生",
        "Soul can stop fires, has Health and will death to regate because sun or haunt"
    })),
    item("death_curse", i18n({"再生之殇", "Body Revive"}),
        i18n({"玩家复活后获得4分钟微光诅咒占位装备)", "Players revive will get a light curse equip for 4 mins"}), true, nil, nil, -1,
        {i18n({"玩家死亡后回档若活着也会诅咒", "Rollback also get"}), i18n({"禁用回档惩罚", "Disable Rollback Curse"})}),
    item("riding_hunger", i18n({"骑乘险境", "Riding Hunger"}),
        i18n({"骑乘受到伤害时扣除伤害*2%的饥饿", "When riding and taking damage, reduce hunger by damage * 2%"})),
    item("recipe_add_material", i18n({"材料险境", "Recipe add Material"}),
        i18n({"从11天开始,制作栏每个材料都有10%的概率+1,每10天重新随机.每个存档固定变化.宝石/重要材料不会变",
            "From day 11,each material has a 10% chance to +1,resetting every 10 days.gems/important material not change"}),
        false, 1, 2, 1, {
            i18n({"11天开始随机+1", "random +1 from day 11"}),
            i18n({"11-20天-1,21-30天+1,以此交替", "take turns as:11-20day -1,21-30day +1"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"随机增加", "Add"}),
            i18n({"随机增减", "Add or Reduce"})
        }, i18n({"禁用", "Disable"}), false),
    -- 2025.2.24 YeFeng:时钟险境,替代旧版clock_rotate,打乱每天日夜交替顺序并真正改变游戏日夜相位
    -- item("clock_rotate", i18n({"时钟欺骗", "Clock Deception"}), i18n({"右上角时钟顺/逆时针旋转1~3格", "The top-right clock rotates 1-3 ticks clockwise/counterclockwise."}), false, 1, 2, 1, {
    --       i18n({"顺/逆时针旋转1~3格", "rotates 1-3 ticks clockwise or counterclockwise."}),
    --       i18n({"每天从上一天逆时针旋转1格", "rotate 1 tick daily, from previous day."})
    --       }, i18n({"禁用", "Disable"}), {
    --       i18n({"部分角度", "Limited Angle"}),
    --       i18n({"全部角度", "Full Angle"})
    --       }, i18n({ "禁用","Disable"}), false),
    item("clock_peril", i18n({"时钟险境", "Clock Peril"}),
        i18n({"打乱每天的日夜交替顺序,真正改变游戏日夜相位", "Randomize the day/dusk/night cycle each day, actually changes game phases"}),
        false, 1, 2, 1, {
            i18n({"整块打乱白天/黄昏/夜晚顺序", "Shuffle day/dusk/night blocks"}),
            i18n({"16段独立随机分配相位", "16 segments randomly assigned"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"整块打乱", "Shuffle"}),
            i18n({"逐段随机", "Fragment"})
        }, i18n({"禁用", "Disable"}), false),
    item("taste", i18n({"口味挑剔", "Taste picky"}), i18n({
        "角色一天内重复吃同一料理san值收益减少且额外扣除san值",
        "Repeatedly eats the same dish in one day, the sanity value benefit decreases and additional sanity value is deducted."
    }), false),
    item("willow", i18n({"薇洛", "Willow"}),
        i18n({"薇洛理智黑化;潮湿伯尼受到额外伤害", "Willow sanity penalty;Wet bernie will take extra damage"})),
    item("wolfgang", i18n({"沃尔夫冈", "Wolfgang"}),
        i18n({"强壮1.75倍饥饿消耗;50力量变正常;妥协无效", "players too less will low dmg;mighty 1.75x hunger"})),
    item("wendy", i18n({"温蒂", "Wendy"}),
        i18n({"阿比盖尔收回无成长,护盾减伤削弱,成长和回血变慢,低温-20怕热50,药水配方变贵",
            "Abigail grow need out,Shield weak,regen/grow slower,is low temp/-20,scare hot/50,elixir recipe expensive"})),
    item("wx-78", i18n({"WX-78", "WX-78"}),
        i18n({"妥协芯片削弱;超载非三维电路增加饥饿消耗", "Hunger rate increase because over-flowing not 3var module"})
    -- ,
    --      true, nil, nil, -1, {
    --      i18n({"启用芯片制作材料难度", "Difficulty of Producing Materials for Chips"}),
    --      i18n({"禁用芯片制作材料难度", "Disabel Difficulty of Producing Materials for Chips"})
    -- }
    ),
    item("wickerbottom", i18n({"薇克巴顿", "Wickerbottom"}),
        i18n({"书籍耐久2次,书柜全员可做,书柜回复变慢", "Books has only 2 durability and bookcase need magicbook to upgrade"}), true, nil,
        nil,
        -1, {
            i18n({"读书地域魔力CD但薇克巴顿无视1天CD", "Book read place has cd and wickerbottom ignore 1 day cd"}),
            i18n({"禁用地域CD", "Disable read place CD"})
        }),
    item("wigfrid", i18n({"薇格弗德", "Wigfrid"}), i18n(
        {"薇格弗德骑牛激励值削弱至原1/3,脱战后歌曲停下", "Wigfrid's ride inspiration reduce to 1/3,song will stop when leave battle"})),
    item("beefalo Dodge", i18n({"骑牛冲刺虚弱", "beefalo Dodge decelerate"}),
        i18n({"骑牛连续冲刺多次后减速，15秒恢复", "After some Dodge on the beefalo, decelerate, then recover in 15 seconds"})),
    item("webber", i18n({"韦伯", "Webber"}), i18n({"谋杀蜘蛛掉理智背叛", "Kill Spider SanityDrop and cause betray"})),
    item("warly", i18n({"沃利", "Warly"})),
    -- item("wx78", i18n({"wx78", "Wx78"})),
    item("walter", i18n({"沃尔特", "Walter"}),
        i18n({"弹弓蓄力时间变久;妥协鞭炮弹沙石弹加速弹削弱", "UM some ammoe weak;UM slingshot slow right attack"})),
    item("wixie", i18n({"维希（Wixie）", "Wixie"}),
        i18n({"维希弹弓蓄力、普攻减速和特殊弹药调整；不受沃尔特开关控制，仅永不妥协启用时显示",
            "Independent Wixie slingshot timing and special-ammo adjustments; shown only with UM enabled"}), true),
    item("maxwell", i18n({"麦斯威尔", "Maxwell"}),
        i18n({"暗影牢笼禁锢怪物的时间缩短", "Shadow Prison imprisons monsters for a shorter time"})),
    item("wortox", i18n({"沃拓克斯", "Wortox"}), i18n({"灵魂回血会消耗同等饥饿", "Soul's heal will consume the same hunger"})),
    item("wormwood", i18n({"沃姆伍德", "Wormwood"}),
        i18n({"再生作物扣饥饿，削弱胡萝卜外套", "Regrow Farm Plant cost hunger,armor_carrotlure cost hunger"})),
    item("wurt", i18n({"沃特", "Wurt"}), i18n({
        "鱼人王需要三叉戟;鱼人堡垒材料增加(10木板+2触手皮+2长矛+2猪皮);鱼人死时小概率变青蛙",
        "Merm king needs trident;mermwatchtower cost more(10 boards+2 tentaclespot+2 spear+2 pigskin);Merm death little chance become frog"
    }), true),
    item("wanda", i18n({"旺达", "Wanda"}), i18n({"不老表蓝宝石;溯源表橙宝石;机会表绿宝石", "Watch need more gem"})),
    item("legion_shield", i18n({"盾牌无伤", "Reduce Legion Shield"}), i18n({
        "棱镜模组盾击动作不再反伤而是短暂提供盾反系数相关的伤害减免",
        "Right Shield action from Legion mod can't do damage but reduce hurt 2s"
    })),
    item("norunattack", i18n({"攻速调整", "Attack Speed"}), i18n({
        "玩家攻速匹配实际动画,打断后摇可行动但不能提早发动攻击",
        "Players' attack use actual anim frames,behind can move but attack earlier"
    }), 0, 0, 20, 1, i18n({"额外增加攻击间隔帧", "add extra attack interval frames?"})),
    item("delay_leave", i18n({"延迟下线", "Delay Leave"}), i18n(
        {
            "延迟下线X秒;期间上线会提示暂时不接受其的连接;请安全区下线",
            "When disconnect,role'll still exist Ns when Connect will block"
        }), false, 5, 60, 5),
    headeritem(i18n({"天气改动", "Weather"})),
    item("weather_change", i18n({"困难模式天气改动总开关", "Switch for Weather of Hard Mode"})),
    item("temperature_change", i18n({"玩家温度", "Player Temperature"}), i18n({
        "玩家保暖隔热削弱;玩家冻伤热伤温度削弱;暖石偏向真实温度",
        "Players have extra thermal insulation;easy to cold or hot;heatrock use real temp"
    }), -1, -1, -2, -1, {"-240,5~65", "-480,10~60"}),
    item("dusk_change", i18n({"漫漫长夜", "Long Night"}), nil, true, nil, nil, -2, {
            i18n({"黄昏的大部分时间变成了黑夜", "Dusk will be shorter"}),
            i18n({"黄昏使用夜间光照，夜视不再安全；官方夜视及简单模式下启用夜视强化的韦伯、鱼妹、芜猴附带微光",
                "Dark dusk; night vision alone is unsafe. Native abilities and enabled Webber, Wurt, and Wonkey vision perks in Easy Mode provide dim light"}),
            i18n({"黄昏使用夜间光照", "dusk no light"})
        }, nil,
        {enabletext, i18n({"经典", "Classical"}), i18n({"经典", "Classical"})}),
    item("moonlight", i18n({"启迪新月", "Full Moon Unlock"}),
        i18n({"天体启迪时月亮正常阴晴圆缺,此外", "MoonStorm Don't lock full Moon,and"}), -4, -1, -6, -1, {
            i18n({"夜间始终有光照", "Night Always Has Light"}),
            i18n({"夜间仅新月时无光照", "Only New Moon Night No Light"}),
            i18n({"夜间新月和凹月时无光照", "New or 1/4 Moon Night No Light"}),
            i18n({"夜间圆月和凸月时有光照", "Full or 3/4 Moon Night Has Light"}),
            i18n({"夜间仅圆月时有光照", "Only Full Moon Night Has Light"}),
            i18n({"夜间始终无光照,这很离谱", "Night Always No Light,Outrageous"})
        }),
    item("sandstorm", i18n({"沙漠风暴", "Sand Storm"}),
        i18n({"秋天春天就会有沙尘暴,提前找蚁狮换图纸,刮地皮头盔更难获得", "Sandstorm/Antlion in autumn/spring"})),
    item("moonisland", i18n({"月岛流星", "Meteor Island"}),
        i18n({"月岛矿区流星雨,月圆有月亮风暴;星象探测仪抵挡月亮风暴", "Moonstorm and Mereors;Astral Detector Parry Moonstorm"}), true,
        nil, nil, -1, {
            i18n({"护目镜现在有种类了不能完全防范住所有风暴", "Goggles Hat now has types for different storm"}),
            i18n({"禁用护目镜种类机制", "Disable Goggles Hat Type"})
        }),
    item("random_seasons", i18n({"混乱之季", "Random Seasons"}),
        i18n({"混乱:至多连续两季节相同,恶劣混乱:较少秋季且可能始终相同", "Random Seasons"}), -3, -1, -5, -1, {
            i18n({"混乱但原版月亮风暴存在时不再混乱", "Random But stop when real moon storm exist"}),
            i18n({"仅原版月亮风暴存在时混乱", "Random Only when real moon storm exist"}),
            i18n({"仅原版月亮风暴存在时恶劣混乱", "Bad Random Only when real moon storm exist"}),
            i18n({"始终混乱且原版月亮风暴存在时恶劣混乱", "Random and bad random when real moon storm exist"}),
            i18n({"始终恶劣混乱", "Random and bad random always"})
        }),
    item("rain_change", i18n({"空气湿度", "Air humidity"}), i18n({
        "春/夏/秋/冬/洞穴湿度倍率;水球雨;潮湿度增加更快",
        "Season S/S/A/W and cave humidity magnification,3~6x moisture rate,waterstreak rain"
    }), -1, -1, -2, -1, {"8/0.5/1/8/4/2", "16/1/2/16/4/4"}),
    item("summer_change", i18n({"夏季风暴", "Summer Heat flow"}),
        i18n({"夏季沙尘暴会不定期来袭且会坠落道具", "Summer will has short sandstorm"})),
    item("winter_change", i18n({"冬季寒光", "Winter Cold Light"}),
        i18n({"用火焰热源驱散冬季黑夜的闪烁极光吧", "use fire/heat source dispell the cold staff"}), true, nil, nil, -1,
        {i18n({"像青蛙雨一样,下雪时概率下雪球雪", "Winter May have Snowball Snow"}), i18n({"禁用雪球雪", "Disable Snowball Snow"})}),
    item("autumn_change", i18n({"秋季复苏", "Autumn recovery"}), i18n({
        "非秋季档案馆插入三颗彩虹宝石时令世界进入秋季;仅1洞穴世界或独行长路不会触发",
        "Enters autumn when iridescent gems inserted non-autumn archives;Single Cave Won't"
    }), -3, -1, -3, -1, {
        i18n({"消耗0颗彩虹宝石", "consume 0 iridescent gem"}),
        i18n({"消耗1颗彩虹宝石", "consume 1 iridescent gem"}),
        i18n({"消耗3颗彩虹宝石并让世界月圆", "consume 3 iridescent gems,and enter fullmoon"})
    }),
    headeritem(i18n({"科技改动", "Prototyper"})),
    item("other_change", i18n({"困难模式科技改动总开关", "Switch for Prototyper of Hard Mode"})),
    --     item("prototyper_change", i18n({"原型科技", "Prototyper"}), i18n({
    --         "科级建筑需要更多材料,科技等级累加制变取最大;万物百科不解锁",
    --         "Science machine needs gears. Prestihatitator green gems, manipulator atrium,weak science level."
    --     }), -1, nil, nil, -1, {i18n({"禁用档案馆更难解密", "Harder Distilled Knowledge"}), i18n({"启用档案馆更难解密", "More science harder"})}),
    item("Harder Prototyper Recipe", i18n({"艰苦原型", "Prototyper"}),
        i18n({"科级建筑需要更多材料", "Science/Prestihatitator/manipulator needs gears/green gems/shadow atrium"})),
    item("Harder Prototyper Level", i18n({"科技求取", "Science"}),
        i18n({"科技等级从累加制变为取最大机制,万物百科不再提供解锁", "Prototyper level change from add to max"})),
    item("Harder Distilled Knowledge", i18n({"档案严密", "Distilled Knowledge"}),
        i18n({"档案馆更难解密,额外两种解密", "Harder Distilled Knowledge.Now has extra two type."})),
    item("sleepingbag", i18n({"野营帐篷", "Sleep Locale"}), i18n(
        {"建筑类睡眠恢复50%下的状态,道具类睡眠恢复45%上的状态", "Sleep in structure can recover until 50%;Sleep by item recover from 45%"})),
    item("moonrockidol", i18n({"暗影之门", "Shadow Door"}), i18n({
        "大门月黑和猴岛门会暗影化需要彩虹宝石净化;月岩雕像现在需要彩虹宝石",
        "Two door will shadow and need shadow heart;Moon rock idol now need iredescent gem"
    }), true, nil, nil, -1, {
        i18n({"伯尼秘典需要黑心;每玩家仅获得一次各角色初始物品", "Only get start inv once of per role"}),
        i18n({"禁用单次初始物品机制", "Disable once Start inv"})
    }),
    item("oceanlife", i18n({"冒险之海", "Secret Ocean"}), i18n({
        "夹夹绞盘6好感兑换;海盗船住猴岛;海盗地图开出更多宝藏或给女王换图纸",
        "Pinchin'Winch need 6 Friendship;More Pirate;Pirate Map give sunkenchest and ..."
    }), true, nil, nil, -1, {
        i18n({"沉底宝藏概率掉落传送魔杖三叉戟启迪之冠等", "Sunken treasure may drop tele staff,trident,enlightened crown..."}),
        i18n({"禁用船上火堆火焰从巨大变大会让船只冒烟", "disable:firepitfire on boat become big from verybig will smolder boat"})
    }),
    item("worldgen", i18n({"复杂地形", "New World"}), i18n({"地表和洞穴世界地形都会有改动", "World Layouts will be change"}), false,
        nil, nil,
        -6, {
            i18n({"随机级别的岛屿冒险化地表地形", "random level islands"}),
            i18n({"0级岛屿冒险,基本无新岛屿", "0 Level islands,should no new islands"}),
            i18n({"1级岛屿冒险,很少岛屿", "1 Level islands,little islands"}),
            i18n({"2级岛屿冒险,有些岛屿", "2 Level islands,has islands"}),
            i18n({"3级岛屿冒险,较多岛屿", "3 Level islands,some islands"}),
            i18n({"4级岛屿冒险,很多岛屿", "4 Level islands,many islands"}),
            i18n({"梦幻机碎群岛(地图会非常非常大)", "dreamly extremely broken islands (makes map huge and huge)"})
        }),
    item("clockwork_guard", i18n({"发条守护", "Clockwork Guard"}), i18n(
        {"在眼骨或月台生成发条", "spawn Clockwork near Eye bone or Moon stone."}), 1, 1, 2, 1, {
        i18n({"开局垃圾堆旁边生成2个发条", "spawn 2 Clockwork Knight near Teetering Junk Pile"}),
        i18n({"月台有1个发条;每一些天后或月圆时再生1个上限3个", "1/3 clockwork spawns near moon stone.Every some days or full moon regen 1"})
    }, i18n({"禁用", "Disable"}), {
        i18n({"垃圾堆", "Junk Pile"}),
        i18n({"月台", "Moon stone"})
    }, i18n({"禁用", "Disable"}), false),
    item("cave_entrance", i18n({"洞梯限行", "Cave entrance"}), i18n({
        "洞口楼梯限行月黑切换;灵魂可出入;洞口伪装但附近有蝙蝠",
        "Entrance/Exit lock unless player ghost;cave entrance hide but near bat"
    }), true, nil, nil, -1, {
        i18n({"2火药炸开洞口;懒人魔杖远古钥匙打开楼梯", "2 Gunpowder Down;Orange staff and Ancient Key up"}),
        i18n("禁用洞口伪装", "Disable hidden cave entrance by bat")
    }),
    item("ancient_statue", i18n({"远古雕像", "Ancient statue"}),
        i18n({"远古雕像镐击时会生成多种事件,最后一下需要斧镐", "Ancient statues generate many event;Final work need Tough"}), true, nil,
        nil, nil,
        i18n({"原版锤击远古科技的效果;敲坏时额外元素反应", "Original hammering effects of ancient pseudoscience;cast spells when broken"})),
    item("ancient_altar", i18n({"远古科技", "Ancient Pseudoscience"}), i18n({
        "是三四本;制作时理智不高会概率锤击,完整锤4次破,破出暗影BOSS;暴动长平静短",
        "Make items chance hammering once, damaging Shadow Chess;Longer nightmare time"
    }), true, nil, nil, -1, {
        i18n({">95%理智且完整远古科技塔必不锤击", "95% sanity when making exclusive items will not trigger"}),
        i18n("禁用暴动平静时间交换", "Disable ruin nightmare time change")
    }),
    item("rocks_change", i18n({"矿物改动", "Mineral rocks"}), i18n({"稿击类石头耐久倍率", "Mines need more strikes for rocks"}), 2,
        1, 16, 0.25),
    item("cheap_wrap", i18n({"廉价包装", "Cheap Wrap"}),
        i18n({"冬季盛宴包装纸效果变差,但是捆绑包装更好用", "giftwrap lose perishable, but better bundle"})),
    headeritem(i18n({"食物改动", "Food"})),
    item("food_change", i18n({"困难模式食物改动总开关", "Switch for Food of Hard Mode"})),
    item("fooddata_change", i18n({"食物改动", "Food"}),
        i18n({"负三维提高,正三维减少,50点以上最低减少", "Negative three status +, positive three status -, safer above 50 points"}), -1,
        -1,
        -3, -1, {"10%~30%", "20%~50%", "33%~66%"}),
    item("cooking_change", i18n({"烹饪改动", "Cooking"}),
        i18n({"烹饪锅需要燃料除非附近龙鳞火炉,火炉咩咩烹饪概率净化", "Cooking Pot now needs to be fueled unless near scaled furnace"}), -1, -1,
        -3, -1, {
            i18n({"容器内火焰背景代表燃料等级", "Flame background in the container represents fuel grade"}),
            i18n({"且全食材各食材度除怪物度和不可食用度外-0.25", "And the degree of all ingredients except grotesque and inedible is-0.25"}),
            i18n({"且5格锅,50%-70%食物仅75%饥饿值,限制不可食用度/装饰度/冰度<=2,和<=3；兼容永不妥协正式版/测试版",
                "And 5 Pot;Food<0.7->0.75hunger;inedible/decoration/frozen<=2,sum<=3. Compatible with UM stable/beta."})  -- 2025.7.9 melon5格锅
        }, i18n({"禁用", "Disable"}), {
            i18n({"燃料", "fuel"}),
            i18n({"-0.25", "-0.25"}),
            i18n({"5格锅", "5-slot Pot"})
        }, i18n({"禁用", "Disable"}), false),
    item("birds_change", i18n({"鸟类改动", "Birds"}), i18n({
        "鸟笼内鸟类会受食物血量影响;被击或喂食受伤会概率诅咒反击",
        "Birds in cages are affected by food blood volume; common birds fight back when they lose blood"
    })),
    item("oceanfish_change", i18n({"鱼类改动", "Oceanfish"}),
        i18n({"海鱼反季仅保鲜,手持挣扎,落地跳海,更难钓;", "Struggle when hold;Drop bottles,gems,accursed trinket;Harder Rod"}), true, nil,
        nil, -1,
        {i18n({"海鱼死亡时掉落瓶中信宝石诅咒饰品", "Shark's jump will knockout enermy"}), i18n({"禁用更难钓鱼", "Disable Hard Rod"})}),
    item("container_live", i18n({"动物箱庭", "Living Box"}), i18n({
        "动物会移动吃掉同容器内的食物,没食物不移动时大鱼会吃临近别种小鱼",
        "Animal move and eat food same container;no food/move fish eat near different type fish"
    }), true, nil, nil, -1, {
        i18n({"每分钟移动1格或吃1食物;1大鱼平均1天吃1小鱼", "Animal will move 1 slot per min for food"}),
        i18n({"吃食物和小鱼无视距离无需移动", "Ignore Slots Range and don't need move"})
    }),
    item("animal_change", i18n({"动物改动", "Animals"}),
        i18n({"主要动物再生时间倍率,非生长时间", "Regeneration time rate of major animals, non-growth time"}), 8, 1, 16, 0.25),
    item("beefalo", i18n({"牦牛改动", "Beefalo"}), i18n(
        {"牦牛顺从平静无仔才能牛铃;牛铃需要橙宝石,喂掉血反击,初有趋势", "Obedience>= 70% can use Beefalo Bell;Bell need orange gem"})),
    item("koalefant", i18n({"大象改动", "Koalefant"}),
        i18n({"脚印间隔距离更远,大象成群出行", "Koalefants has herd group.Harder animals track"})),
    item("Seeds Weed Chance", i18n({"种子改动", "Seeds"}),
        i18n({"箱子可晾干;仅耕地可耕种;长成杂草概率", "Chester Dry Seeds;Limit Farm soil;Seeds Weeds Chance"}), 0.8, 0.5, 0.976, 0.025),
    item("farm_plant_change", i18n({"作物改动", "Farm plants"}), i18n({"作物生长时间倍率", "Growth time rate"}), 2, 1, 16, 0.125),
    item("farm", i18n({"耕地改动", "Farm"}), i18n(
        {"耕地裂缝水土流失夏季破坏耕地,极光/冬季消除", "Farm crack:Lose Water/Soil till cold staff/winter;summer too dry will destory farm"})),
    item("nutrient", i18n({"农肥改动", "Nutrient"}), i18n({
        "每个耕地养分单位各季节有额外养分加成;检查高级耕地帽查看",
        "Per Farm Nutrient Prefabs Has Seasons Extra Nutrient;Inspect Premier Gardeneer Hat"
    }), true, nil, nil, -9, {
        i18n({"默认额外有3/9个季节参考作物的养分加成", "Default Has 3/9 Season Extra Nutrient"}),
        i18n({"额外有x/9个季节参考作物的养分加成", "Has x/9 Season Extra Nutrient"})
    }, nil, {enabletext, 1}),
    item("plant_change", i18n({"植物改动", "Plants"}), i18n({
        "除作物/水中木外,植物生长时间倍率;大理石豆可读书催生",
        "Growth time rate except for crops,oceantree; Marble beans can be spawned by reading book"
    }), 8, 1, 16, 0.25),
    item("action_change", i18n({"互动改动", "Easter egg"}),
        i18n({"采集海带概率有触手,敲骨架概率有幽灵...", "When actions with plants... will ..."})),
    headeritem(i18n({"怪物改动", "Monster"})),
    item("monster_change", i18n({"困难模式怪物改动总开关", "Switch for Monster of Hard Mode"})),
    item("wall_destroy", i18n({"无阻可挡", "Destory Walls"}), nil, true, nil, nil, -1, {
        i18n({"生物有仇恨时可以突破各类障碍了", "Creatures will destroy collision walls when has target"}),
        i18n({"生物主动攻击墙体食人花;宠物不会攻击", "Creatures will attack walls"})
    }),
    item("boss_no_fight", i18n({"反互伤", "Boss No Hostility"}), i18n({"boss之间不会互相有仇恨和造成伤害了;本选项默认关闭,开启与否是服主的选择", "Boss will not hostile or damage each other;this option is OFF by default,enable at host's choice"}), false),
    item("rangesupermonster", i18n({"远程精英怪物", "Super Monster"}), i18n({
        "动物和某些怪物概率有一种远程武器(蓝火)",
        "Animals and monsters now may have range weapon"
    }), 0.075, 0.025, 1, 0.025),
    item("specialsupermonster", i18n({"属性精英怪物", "Super Monster"}), i18n({
        "动物和某些怪物该概率有7种宝石属性(彩虹隐身)",
        "Animals and monsters now may be elemental"
    }), 0.075, 0.025, 1, 0.025),
    item("calmfire", i18n({"战斗镇定", "Battle Calm"}), i18n({"怪物的惊恐AI不会在最近被攻击时生效", "Not panic when attacked recent"})),
    item("nosrctarget", i18n({"无端仇恨", "No Source Target"}), i18n(
        {"危险非随从怪物无仇恨时被无来源攻击会仇恨附近玩家", "Danger Wild Monster no target attacked no src will heat near player"})),
    item("moveattack", i18n({"移动攻击", "Move When Attack"}),
        i18n({"青蛙/蝙蝠/蠕虫/蛞蝓龟/伏特羊;且各有其他增强", "Frogs/Bats/Worm/Slurtle/Volt Goat;And more update"})),
    item("flyingattack", i18n({"空袭攻击", "Flying Attack"}), i18n(
        {"玩家受到飞行单位的攻击仅头部手部护甲可防;果蝇增强", "Only hands/head armor parry flying creatures' attack;Fruitfly Upgrade"})),
    item("bee", i18n({"蜜蜂加强", "Killer Bee"}), i18n({"杀人蜂间歇远程攻击", "Killer bee can range attack some time"})),
    item("fruitfly", i18n({"果蝇加强", "Fruit Fly"}),
        i18n({"果蝇移速变快,捕虫网秒杀;友好果蝇不吸引攻击", "Fruit Fly Fly faster;Friendly safe"})),
    item("warg", i18n({"猎犬加强", "Hounds"}), i18n({"猎犬丘加强", "hound mound update"}), -2, -1, -4, -1, {
        i18n({"常见猎犬迷你化;青年座狼各种猎犬血量调整", "Smaller Hounds,Faster Warg/Walrus"}),
        i18n({"座狼移动中攻击;成年座狼移速攻速嗅觉增加", "Warg will attack when moving"}),
        i18n({"猎犬也会移动中攻击了", "Warg and hounds will attack when moving"}),
        i18n({"猎犬取消迷你化增加血量", "Warg and hounds will attack when moving"})
    }),
    item("walrus", i18n({"海象加强", "Walrus"}), i18n({"海象移速更快血量更高海上行走", "Walrus is stronger and faster,Run On Ocean"}),
        -2, -1,
        -2, -1, {"", i18n({"海象巢双倍海象", "One camp Double Walrus"})}),
    item("chess", i18n({"发条加强", "Clockworks"}), i18n(
            {"发条损坏装置互转,通过月熠闪电带电反击,不免疫电击", "Clockwork<=>Damaged<=>Broken;Gen moonstorm spark to become electric"}), -1,
        nil, nil, -1, {
            i18n({"铥矿装备绝缘;发条装置难锤,薇诺娜爆炸BOSS例外",
                "Thulecite insulate,Broken clockworks toughness unless winona/gunpowder/epic"}),
            i18n({"发条再生时间从10天提高到35天", "Broken->Damaged->Clockwork need time become 35 days from 10days"})
        }),
    item("tentacle", i18n({"触手加强", "Tentacle"}), i18n({
        "触手被攻击后召唤树根,攻击命中则召唤缠绕根须,分别12秒CD",
        "Summons root after being attacked, and if the attack hits, summons binding roots, 12s CD respectively"
    })),
    item("pigman", i18n({"猪人加强", "Pigman"}), i18n({
        "猪人被喂食掉血时仇恨,联动疯猪,可给武器可换金子;噩梦猪人疲惫获得黑雾加速",
        "Pig feed/crazy change,trade weapon/gold;Nightmare Werepig into dark/speedup"
    })),
    item("otter", i18n({"水獭加强", "otter"}),
        i18n({"兄弟加强,攻击附加潮湿,满潮湿后附加击飞", "otter strength, attack with moisture increase, knockback with full moisture"})),
    item("mimicreep", i18n({"拟态蠕虫", "Mimicreep"}), i18n({
        "拟态蠕虫无法复制部分魔杖以及护符装备",
        "Mimicreep cannot replicate some staffs and amulets equipment"
    })),
    item("shark", i18n({"鲨鱼加强", "Shark"}),
        i18n({"鲨鱼飞跃带击退", "Shark leap will knock out target"})),
    item("spider", i18n({"蜘蛛加强", "Spider"}), i18n(
        {"蜘蛛阵亡时巢穴出兵,无蜘蛛时降级召唤白蜘蛛;女王蜘蛛疯狂跳跃", "Spiderden will do more;Spiderqueen‘s spiders jumo"})),
    item("UM Widow", i18n({"寡妇加强", "UM Widow strength"}), i18n(
        {"妥协寡妇加强，触手棒概率开包但奖励减少且概率出活物", "UM Hooded Widow Update and tentacle spike can open packages"})),
    item("lunarthrall_plant", i18n({"亮茄/食人花加强", "Brightshade/Lureplant"}),
        i18n({"可寄生食人花等;亮茄和食人花增强", "Infest Lure Plant...Upgrade Lure Plant"})),
    item("shadowthrall", i18n({"墨荒加强", "Ink Blight"}), i18n({"无阻轮转/弹射法弹/魇食黑雾/熔合三项加强", "Please Test"})),
    item("shadow_rift", i18n({"暗影裂隙", "Shadow Rift"}),
        i18n({"将玩家吸引到裂隙。开启墨荒加强时起效", "Draw players into the Rift. Takes effect when Ink Blight is enabled"}), false),
    item("monkey", i18n({"穴居猴加强", "Splumonkey"}),
        i18n({"穴居猴会主动仇恨携带素食的玩家;暗影猴暗影化", "Actively hate players with vegetarians and become real shadow"})),
    item("krampus", i18n({"坎普斯加强", "Krampus"}), i18n({
        "坎普斯现在携带冰猎犬和火猎犬,存在1分钟后激活逃跑AI,逃跑不会卡住了",
        "Summons 1 hound and 1 firehound and activate runaway AI after 1 minute"
    })),
    item("crawlingshadow", i18n({"爬行恐惧加强", "Crawling Horror"}),
        i18n({"护疗/遁地/死亡禁锢", "Heal Protect/Under Ground/death pillar"}), -2,
        -1, -2, -1,
        {"", i18n({"遇强则强,敌人太快太高伤害会解锁转换能力", "Cave shadow will exchange with it when enermy too strong/fast"})}),
    item("shadowbeak", i18n({"恐怖尖喙加强", "Terrorbeak"}),
        i18n({"冲刺/伪装/死亡陷阱;00坐标清除影怪", "Strike/Change Small/Death Trap;remove shadows in 0,0 pos"}), -2, -1, -2, -1,
        {" ", i18n({"冲刺还会击落武器和头盔", "Strike will drop target's weapon or head"})}),
    item("oceanshadow", i18n({"恐怖利爪加强", "Terrorclaw"}),
        i18n({"近战远程双修,击退波纹,地表海上半血后不再远程", "Terrorclaw use blowdart except half health on ocean"})),
    item("ruinsnightmare", i18n({"潜伏梦魇加强", "Lurking Nightmare"}),
        i18n({"3面夹击,暗影旋角,暗影八角笼", "3 horns, Shadow rotation horn,Shadow octagon cage"}), -2, -1, -2, -1,
        {" ", i18n({"暗影旋角有击飞击退效果以及额外移速加成，拥有双生影怪转化机制",
            "Horn can knockback target and additional speed, a unique exchange 'Transformation-Twin shadows'"})}),
    item("shadowleech", i18n({"寄生暗影加强", "Parasitic Shadeling"}), i18n(
            {"寄生暗影低理智时概率来袭,地表概率减半", "Parasitic Shadeling will come and attack low sanity player;Half chance if not cave"}),
        -2,
        -1, -2, -1, {
            i18n({"仅在其他理智影怪出现时0.025概率出现", "other sanity shadow generate has 0.025 generate chance"}),
            i18n({"初次疯狂时0.1概率出现;彻底疯狂时0.35概率出现",
                "First carzy has 0.1 generate chance;Full Crazy has 0.35 generate chance"})
        }),
    item("shadowthrall_centipede", i18n({"巨荒蜈蚣死亡分裂", "shadowthrall_centipede death to two"})),
    item("leif", i18n({"树精加强", "Treeguard"}), i18n({"森林复苏,树苗突击,群体共生;月亮孢子连环爆炸", "Forest Health,Sapling Attack"})),
    item("deerclops", i18n({"巨鹿加强", "Deerclops"}),
        i18n({"极光冰阵;命运极限-冰封怒雪域;伴随雪球雪天气", "Freeze attacker,low health 1/3 chance has snow ice area"}), true, nil, nil,
        -1, {
            i18n({"队友猪人帮忙解冻;无法客户端解控", "Help frozen teammates thaw; Pig man will help unfreeze"}),
            i18n("禁用巨鹿的雪球雪天气", "Disable Deerclops' Snow Weather")
        }),
    item("antlion", i18n({"蚁狮加强", "Antlion"}), i18n({"燃之沙,颚之刃,地底呼吸,沙暴践踏", "Burning Sand spikes"})),
    item("bearger", i18n({"熊獾改动", "[Bearger]"}), i18n({"妥协装甲熊灌同步普通熊灌", "Lunar Sync UM Simple"})),
    item("dragonfly", i18n({"龙蝇加强", "Dragonfly"}), i18n({"火之弹,极限-不息暴怒炽星火阵", "Fire shoot,Half health enrage"})),
    item("beequeen", i18n({"蜂王加强", "Bee Queen"}),
        i18n({"被蜂王攻击获得沃尔特debuff;蜂王帽:随从伤害+20%;蜂王浆:吃下后随从永久+5伤害", "Hit by Bee Queen gains Walter allergy debuff (bees deal +10); Hivehat: followers +20% dmg; Royal Jelly: followers permanent +5 dmg"})),
    --     item("moosegoose", i18n({"麋鹿鹅加强", "Moose/Goose"}), i18n({"麋鹿鹅幼崽围绕麋鹿鹅化身旋风", "Mosling Help Moose/Goose"})),
    item("malbatross", i18n({"邪天翁加强", "Malbatross"}),
        i18n({"冰霜箭羽;如来神掌;妥协鸟嘴壶可放暖石", "Feather attack;FlyLand Skill;put Thermal Stone into UM Waterfowl Can"})),
    item("klaus", i18n({"克劳斯加强", "Klaus"}), i18n(
        {"魔法鹿AI改动加强,攻击击落物品,连击挥爪",
            "No-Eyed Deer AI change,Attack and shoot down items,Strike repeatedly and wave your claws"})),
    item("crabking", i18n({"帝王蟹加强", "Crabking"}), i18n({"(注: 旧版帝王蟹选项不兼容其他模组的帝王蟹改动)", "(Note: The Previous Crabking option is not compatible with Crabking from other mods.)"}),
        true, nil, nil, -1, {i18n({"再生之炮,守护蟹钳,破冰", "The cannon of regeneration, guard crab claws, break the ice"}),
            i18n({"接弹蟹钳,极限-盾愈钳,深海呼吸,三叉戟联动", "Claws will also crabking itself; it will hide in ocean; Face Trident/Cannonballs"})}
        -- i18n({"禁用", "Disable"}), {
        --     i18n({"新版帝王蟹", "Crabking"}),
        --     i18n({"旧版帝王蟹", "Previous Crabking"})
        -- }
    ),
    item("sharkboi", i18n({"大霜鲨加强", "Frostjaw"}),
        i18n({"鲨影寒袭,寒气波,掠冰之牙,溯冬吐息", "More damage to freeze target, Cold Wave, Frostbite Bite, Breath of Winter"})),
    item("gestalt", i18n({"附体虚影加强", "Gestalt"}), i18n({
        "附体熊灌/巨鹿/座狼攻速更快,每1/3血有更高血量分身则+1分身上限6",
        "Infest 3 Boss When 1/3 health,try exchange higher hp shadow,success add 1 shadow"
    })),
    item("shadowchesspieces", i18n({"暗影棋子加强", "Shadow ChessPieces"}), i18n({
        "影之囚笼,影之陷阱,阈值-影潮,阈值-影之转换,海上行走",
        "Run on ocean, use shadow sneak/prison and summons shadow creatures after death"
    }), true, nil, nil, -1, {
        i18n({"脱离视野不再消失", "Leave View Not Disappear"}),
        i18n({"脱离视野正常消失", "Leave View Normal Disappear"})
    }),
    item("eyeofterror", i18n({"双子魔眼加强", "Eyes of Terror"}), i18n({"血量翻倍,技能CD减半", "Double health, half skill cd"})),
    item("daywalker2", i18n({"拾荒疯猪加强", "Scrappy Werepig"}), i18n({"强击之力,缴械打击,耐用装备"})),
    item("toadstool", i18n({"毒菌蟾蜍加强", "Toadstools"}),
        i18n({"血量减半;双倍爆炸;季节毒雾;遁地回巢", "half health;double sporebomb/sporecloud,season sporecloud"})),
    {
        name = "alterguardian",
        label = i18n({"天体英雄加强", "Celestial Champion"}),
        hover = i18n({"血量攻速移速翻倍,技能CD减半;四季之力,永恒之季;暗影世界三体之力;新版激光更多,攻击时停;禁用血量翻倍,禁用CD减半",
            "Double health/speed, half attack/skill cd; Four Season Ability; ShadowWorld Three Battle; New: more laser, time stop attack; Disable Double Health/cd"}),
        default = -5,
        options = {
            {description = i18n({"禁用", "Disable"}), data = false},
            {description = i18n({"启用", "Enable"}), hover = i18n({"血量攻速移速翻倍,技能CD减半", "Double health/speed, half attack/skill cd"}), data = -1},
            {description = i18n({"启用", "Enable"}), hover = i18n({"四季之力,永恒之季;旧靴子免疫滑倒", "Four Season Ability;Lock season;Bootleg Getaway Avoid slippery"}), data = -2},
            {description = i18n({"启用", "Enable"}), hover = i18n({"暗影世界开启时,三体之力", "ShadowWorld Enable Three Battle"}), data = -3},
            {description = i18n({"启用", "Enable"}), hover = i18n({"激光更多,攻击时停", "More laser, time stop attack"}), data = -5},
            {description = i18n({"启用", "Enable"}), hover = i18n({"禁用血量翻倍,禁用CD减半", "Disable Double Health,disable half skill cd"}), data = -4},
        },
    },
    item("banicetiles", i18n({"禁用天体三阶段冰面能力", "Ban Ice Tiles"}),nil, false),
    item("old_alterguardian", i18n({"怀旧版天体三阶段", "Previous Version Celestial Champion_3"}),
        i18n({"开启后将会使用追击攻击模式的天体三阶段", "After activation, Celestial Champion_3 will use pursuit attack mode"}), false),
    item("alterguardian_phase4", i18n({"天体后裔加强", "Celestial Champion Phase4"}),
        i18n({"天体后裔的影子拥有独立AI,以及技能会实时与本体同步解锁", "Phase4 shadow has independent AI and real-time skill sync"})),
    item("minotaur", i18n({"远古守护者加强", "Ancient Guardian"}),
        i18n({"关闭为完全原版;启用(梦境花园)兼容其他模组;启用(骨刺骨牢)为难度加强,犀牛角可强化远古装备;洞穴无法种植海星陷阱",
            "Disabled is vanilla; Enabled (Dream Garden) compatible; Enabled (spike/cage) hard mode, horn enhances ancient gear; cave cannot deploy anenemy traps"}), 2, 0, 2, 1, {
            i18n(""),
            i18n({"梦境花园,死亡20天后重置远古", "Dream Garden, reset ruins after 20 days"}),
            i18n({"骨刺骨牢释放;犀牛角可以强化远古装备;死亡20天后重置远古", "Spike/bone cage release; horn can enhance ancient gear; reset ruins after 20 days"})
        }, nil, {i18n("禁用"), i18n("启用"), i18n("启用")}),
    item("atriumstalker", i18n({"远古织影者加强", "Ancient Fuelweaver"}),
        i18n({"鬼手需不同玩家或武器轮换击败", "shadow hands need different weapon"}), -1, nil, nil, -2, {
            i18n({"血量攻速移速翻倍,技能CD减半", "Double health/speed, half skill cd"}),
            i18n("为敌人召唤暗影随从和转化敌人暗影分身", "Summon enermy's shadowprotector or friend enermy's shadow"),
            i18n({"禁用血量翻倍,禁用CD减半", "Disable Double Health,disable half skill cd"})
        }),
    {
        name = "epic_armor_5",
        label = i18n({"巨兽装甲", "Epic Armor"}),
        hover = i18n({"旧默认1档自动升级为遇强则坚，传统1～5档仍可手动选择。需要开启困难模式及怪物改动。",
            "The old default migrates to Adaptive Fortitude; traditional tiers 1-5 remain selectable. Requires Hard Mode and Monster Changes."}),
        default = "dynamic",
        options = {
            {description = i18n({"禁用", "Disable"}), data = false},
            {description = i18n({"传统 1 档", "Traditional 1"}), data = "traditional_1"},
            {description = i18n({"传统 2 档", "Traditional 2"}), data = 2},
            {description = i18n({"传统 3 档", "Traditional 3"}), data = 3},
            {description = i18n({"传统 4 档", "Traditional 4"}), data = 4},
            {description = i18n({"传统 5 档", "Traditional 5"}), data = 5},
            {description = i18n({"遇强则坚（默认）", "Adaptive Fortitude (default)"}), data = "dynamic",
                hover = i18n({"单次伤害上限10%最大生命，压力20%起减伤、30%达上限；每秒衰减2%最大生命/额外血量倍率平方根，停手1秒后启用每秒至少400点保底；无固定无敌、回血或陨石。",
                    "Each hit is capped at 10% max health; resistance rises from 20% to 30% pressure. Pressure cools at 2% max health/sec divided by sqrt(extra health multiplier); the 400 HP/sec minimum starts one second after damage. No timed invulnerability, healing or meteors."})},
        },
    },
    itemvalue("epic_ruin", i18n({"巨兽摧毁", "Epic Ruin"}),
        i18n({"按累计巨兽伤害占生命上限的比例乘以摧毁强度，减少战利品数量",
            "Reduces the loot count based on recorded boss damage divided by maximum health, multiplied by the selected strength"}), 0.8, {
            i18n({"关闭", "Disable"}), false,
            i18n({"摧毁强度60%", "Ruin 60%"}), 0.6,
            i18n({"摧毁强度80%（默认）", "Ruin 80% (default)"}), 0.8,
            i18n({"摧毁强度100%", "Ruin 100%"}), "full",
            i18n({"摧毁强度200%", "Ruin 200%"}), 2
        }),
    item("poor_armor", i18n({"劣质装甲", "Poor Armor"}),
        i18n({"普通生物10%概率有劣质装甲，半血触发5秒无敌",
            "Ordinary creatures have a 10% chance of having Poor Armor, half health triggering invincibility for 5 seconds"}),
        false, 1, 3, 1, {
            i18n({"10%", "10%"}),
            i18n({"30%", "30%"}),
            i18n({"50%", "50%"})
        }, i18n({"禁用", "Disable"}), {
            i18n({"10%", "10%"}),
            i18n({"30%", "30%"}),
            i18n({"50%", "50%"})
        }, i18n({"禁用", "Disable"}), false),
    item("pig_boss", i18n({"猪猪boss", "pig_boss"}),
        i18n({"给猪紫宝石让猪变boss,3倍体型,2级装甲,位面抵抗,免疫负面,仅玩家能攻击,掉落彩虹(开启劣质装甲才起效)",
            "give purplegem to pig to boss,planarentity,avoid debuff,only player attack,(enable when open Poor Armor)"}),
        false),
    item("Monster Harder Level", i18n({"怪物猎人第二周目!!!", "Monster World Second Mode!!!"}),
        i18n({"裂隙开启后,危险生物的攻击动画变快;不兼容请反馈", "When Enable Rifts,Monster's attack anim become faster;May Cause Bug"}),
        false, 1.1, 5, 0.1),
    headeritem(i18n({"额外改动", "Extra Chance"})),
    item("extra_change", i18n({"困难模式额外改动总开关", "Switch for Extra of Hard Mode"}), nil, false),
    item("boss_health", i18n({"BOSS血量", "Boss Health"}), i18n({"乘以", "multiply"}), false, 1, 100, 0.1),
    item("boss_speed", i18n({"BOSS移速", "Move Speed"}),
        i18n({"乘以;怪物/额外改动的移速攻速攻频加强同时生效时取较大者", "multiply"}), false, 1, 10, 0.05),
    item("boss_attackanim", i18n({"BOSS攻速!!!", "Attack Speed!!!"}),
        i18n({"乘以;攻击动画更快;不兼容请反馈", "multiply;May Has Bug"}),
        false,
        1, 10, 0.05),
    item("boss_attackspeed", i18n({"BOSS攻频", "Attack Frequency"}), i18n({"乘以;攻击周期更短", "multiply"}), false, 1, 10,
        0.05),
    item("boss_attackrange", i18n({"BOSS攻击距离", "Attack Range"}), i18n({"乘以", "multiply"}), false, 1, 10, 0.05),
    item("boss_damage", i18n({"BOSS造成伤害", "Cause Damage"}), i18n({"乘以", "multiply"}), false, 1, 100, 0.1),
    item("boss_damagetake", i18n({"BOSS受到伤害", "Damage Taken"}), i18n({"乘以", "multiply"}), false, 0, 1, 0.01),
    item("boss_damagetake2", i18n({"BOSS损失血量", "Health Lost"}), i18n({"乘以", "multiply"}), false, 1, 0, -0.01),
    item("boss_maxdamagetake", i18n({"BOSS掉血上限", "Max Health Lost"}), i18n({"设为", "is"}), false, 1000, 1, -1),
    item("boss_healthregen", i18n({"BOSS每秒回血", "Health Regen"}), i18n({" ", "is"}), false, 1, 1000, 1),
    item("boss_notfreezable", i18n({"BOSS免疫冰冻", "Not Freezeable"}), nil, false),
    item("boss_notsleeper", i18n({"BOSS免疫催眠", "Not Sleeper"}), nil, false),
    item("boss_ocean", i18n({"BOSS海上行走", "Run On Ocean"}), nil, false),
    item("boss_notenemyregen", i18n({"BOSS攻击禁止敌疗", "Not Enemy Regen"}),
        i18n({"攻击使敌人10秒内无法回血", "attack enemy will make enemy disable health regen 10s"}), false),
    item("notboss_range", i18n({"非BOSS集合", ">Not Boss Range"}),
        i18n({"哪些生物会获得下面选项的加强", "Which creatures will be enhanced by the following options"}), true, nil, nil, nil,
        i18n({"除玩家和BOSS外的任何危险生物", "All hostile creatures except player and boss"}),
        i18n({"除玩家和BOSS外的任何生物", "All creatures except player and boss"}),
        i18n({"危险生物", "Hostile"}),
        i18n({"全部生物", "All"})),
    item("notboss_health", i18n({"非BOSS血量", "Not Boss Health"}), i18n({"乘以", "multiply"}), false, 1, 100, 0.1),
    item("notboss_speed", i18n({"非BOSS移速", "Move Speed"}),
        i18n({"乘以;怪物/额外改动的移速攻速攻频加强同时生效时取较大者", "multiply"}), false, 1, 10, 0.05),
    item("notboss_attackanim", i18n({"非BOSS攻速!!!", "Attack Speed!!!"}),
        i18n({"乘以;攻击等动画更快;不兼容请反馈", "multiply;May Has Bug"}),
        false, 1, 10, 0.05),
    item("notboss_attackspeed", i18n({"非BOSS攻频", "Attack Frequency"}), i18n({"乘以;攻击周期更短", "multiply"}), false, 1, 10,
        0.05),
    item("notboss_attackrange", i18n({"非BOSS攻击距离", "Attack Range"}), i18n({"乘以", "multiply"}), false, 1, 10, 0.05),
    item("notboss_damage", i18n({"非BOSS造成伤害", "Cause Damage"}), i18n({"乘以", "multiply"}), false, 1, 100, 0.1),
    item("notboss_damagetake", i18n({"非BOSS受到伤害", "Damage Taken"}), i18n({"乘以", "multiply"}), false, 0, 1, 0.01),
    item("notboss_damagetake2", i18n({"非BOSS损失血量", "Health Lost"}), i18n({"乘以", "multiply"}), false, 1, 0, -0.01),
    item("notboss_maxdamagetake", i18n({"非BOSS掉血上限", "Max Health Lost"}), i18n({"设为", "is"}), false, 1000, 1, -1),
    item("notboss_healthregen", i18n({"非BOSS每秒回血", "Health Regen"}), i18n({" ", "is"}), false, 1, 1000, 1),
    item("notboss_ocean", i18n({"非BOSS海上行走", "Run On Ocean"}), nil, false),
    headeritem(i18n({"扩展改动", "Extension Extension"})),
    item("shengwuqishilu", i18n({"怪物启示录", "Monster Apocalypse"}), i18n({
        "除玩家墙建筑船只外的每天增长血量,多少天增长一倍",
        "Monster Except Player/Walls/Boats/Structures Upgrade Health Per day,how long a level"
    }), false, 140, 1400, 10),
    item("shengwuqishilu2", i18n({"伤害成长", "Attack Apocalypse"}),
        i18n({"生物每天增长伤害,多少天增长一倍", "Monster Upgrade Damage Per day,how long a level"}), false, 700, 7000, 50),
    item("shengwuqishilu3", i18n({"护甲成长", "Parry Apocalypse"}), i18n({
        "生物每天增长护甲,多少天增加1000点,减伤1-1000/(1000+护甲),上限95%",
        "Monster Upgrade x armor Per day,reduce damage:1000/(1000+armor)"
    }), false, 1400, 3500, 100)
}

-- Maintained branch based on the original 2.8.14.95 release.
-- Original copyright notices and LICENSE are retained in this package.
name = i18n({"为爽而虐/暗影世界 淬炼之季", "DST Patch For Happy/Shadow World - Season of Tempering"})
description = i18n({"基于《为爽而虐/暗影世界 永恒之季》的独立维护分支，由 Yucca 持续维护与调整。", "An independently maintained branch of 为爽而虐/暗影世界 永恒之季, maintained and refined by Yucca."}) .. "\n\n" .. description
