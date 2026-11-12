local settings = require("wx78config2hm").Resolve(GetModConfigData, TUNING)
TUNING.wx78mode2hm = settings.mode
TUNING.wx78easyhard2hm = settings.easyhard
TUNING.wx78hard2hm = settings.hard
if settings.easy and not AddRightSelfAction then modimport("easy_role/rightselfaction.lua") end
if settings.easy and not (TUNING.easymode2hm and GetModConfigData("role_easy")) then
    modimport("easy_role/wx78_easy.lua")
end
if settings.mode == "hard" then modimport("role/wx78.lua") end
if settings.draft then require("wx78draft2hm").Install(env) end

-- Reading old items must not require loading old gameplay enhancements.
TUNING.wx78recoverfusion2hm = settings.mode ~= "legacy" and
    (not settings.easy or not GetModConfigData("WX-78 Integrated Upgrade Module Level"))
TUNING.wx78recoverbox2hm = settings.mode ~= "legacy" and
    (not settings.easy or not GetModConfigData("wx78_module_pack"))
modimport("common/wx78_recovery.lua")
