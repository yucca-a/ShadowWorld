local modtip = GetModConfigData("Disable Outdate Tip")
-- 默认遇到模组版本更新后只对该模组进行一次提示,但当新玩家进入游戏后,重新计算提示
local disablemodtips = {}
local prettyname = KnownModIndex:GetModFancyName(modname)
local Networking_ModOutOfDateAnnouncement = GLOBAL.Networking_ModOutOfDateAnnouncement
GLOBAL.Networking_ModOutOfDateAnnouncement = function(mod, ...)
    if disablemodtips[mod] and (modtip == 2 or (modtip == 1 and mod == prettyname)) then return end
    disablemodtips[mod] = true
    return Networking_ModOutOfDateAnnouncement(mod, ...)
end
AddPlayerPostInit(function(inst) disablemodtips = {} end)
