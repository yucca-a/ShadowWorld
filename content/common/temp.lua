local TEMP_FILE = "mod_config_data/HappyPatchModData"
local function LoadData(filepath)
    local data = nil
    TheSim:GetPersistentString(filepath, function(load_success, str)
        if load_success == true then
            local success, savedata = RunInSandboxSafe(str)
            if success and string.len(str) > 0 then
                data = savedata
            else
                print("[HAPPY PATCH] Could not load " .. filepath)
            end
        else
            print("[HAPPY PATCH] Can not find " .. filepath)
        end
    end)
    return data
end
TUNING.TEMP2HM = LoadData(TEMP_FILE) or {}
TUNING.DATA2HM = TUNING.DATA2HM or {}
function SaveTemp2hm() TheSim:SetPersistentString(TEMP_FILE, DataDumper(TUNING.TEMP2HM)) end
-- 强行开关功能
local isclient = TheNet:GetIsClient() or TUNING.DSA_ONE_PLAYER_MODE or (TheNet:GetServerIsClientHosted() and TheNet:GetIsServerAdmin())
local fastbtn = GetModConfigData("Container Sort") or GetModConfigData("Items collect")
if isclient then
    local configloadtip = TUNING.isCh2hm and "[为爽而虐客户端专属配置已保存,下次进入游戏时生效]" or
                              "[Shadow World Mod Client Config Updated.Enter Game After Will Apply.]"
    local immediatelytip = TUNING.isCh2hm and "[为爽而虐客户端专属配置已保存,该选项可以直接生效]" or
                               "[Shadow World Mod Client Config Updated.It will immediately Apply.]"
    local Say = getmetatable(TheNet).__index["Say"]
    getmetatable(TheNet).__index["Say"] = function(self, chat_string, whisper, ...)
        if chat_string == "显示模组" or chat_string == "show mods" then
            TUNING.TEMP2HM.openmods = true
            SaveTemp2hm()
            chat_string = chat_string .. configloadtip
            whisper = true
        elseif chat_string == "隐藏模组" or chat_string == "hide mods" then
            TUNING.TEMP2HM.openmods = false
            SaveTemp2hm()
            chat_string = chat_string .. configloadtip
            whisper = true
        elseif chat_string == "默认模组" or chat_string == "default mods" then
            TUNING.TEMP2HM.openmods = nil
            SaveTemp2hm()
            chat_string = chat_string .. configloadtip
            whisper = true
        elseif fastbtn and chat_string == "显示整理" or chat_string == "show sort" then
            TUNING.TEMP2HM.opensort = true
            TUNING.DATA2HM.opensort = true
            SaveTemp2hm()
            chat_string = chat_string .. immediatelytip
            whisper = true
        elseif fastbtn and chat_string == "隐藏整理" or chat_string == "hide sort" then
            TUNING.TEMP2HM.opensort = false
            TUNING.DATA2HM.opensort = false
            SaveTemp2hm()
            chat_string = chat_string .. immediatelytip
            whisper = true
        elseif fastbtn and chat_string == "默认整理" or chat_string == "default sort" then
            TUNING.TEMP2HM.opensort = nil
            SaveTemp2hm()
            chat_string = chat_string .. configloadtip
            whisper = true
        end
        return Say(self, chat_string, whisper, ...)
    end
end
-- -- 服务器强制让客户端说话
-- local function myclientsay2hm(chat_string, whisper) TheNet:Say(chat_string, whisper) end
-- AddClientModRPCHandler("MOD_HARDMODE", "clientsay2hm", myclientsay2hm)
-- function ClientSay2hm(sender_list, chat_string, whisper)
--     if chat_string then
--         if TheWorld.ismastersim and TheNet:IsDedicated() then
--             SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "clientsay2hm"), sender_list, chat_string, whisper)
--         else
--             myclientsay2hm(chat_string, whisper)
--         end
--     end
-- end
