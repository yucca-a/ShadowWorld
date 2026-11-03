local ctrldisable = GetModConfigData("ctrl disable right")
local ctrlwrapback = GetModConfigData("right Wrapback need ctrl")
local ctrlLunge = GetModConfigData("right Lunge need ctrl")
local function RightActionNeedCtrl(inst, needctrl)
    return not needctrl or (inst.components.playercontroller ~= nil and
        inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK))
end
local select_beefalo_dodge = GetModConfigData("beefalo Dodge") -- 2025.8.2 melon:骑牛冲刺虚弱
local select_wrapback = GetModConfigData("Wanda Right Wrapback")
select_wrapback = select_wrapback == true and 1 or select_wrapback -- 让原来选true的变为1
local hardmode = TUNING.hardmode2hm
-- local ctrloverrideequip = GetModConfigData("ctrl disable item") or true
-- local handlekeys = GetModConfigData("right action key")

-- 定义每次闪避消耗的饥饿值
local HUNGER_CONSUMPTION_PER_DODGE = 5

-- 闪避冲刺动作
AddAction("DODGE_WALTER", "Dodge", function(act, data)
    if act.pos or act.target then
        local doer = act.doer
		-- 困难模式骑行滑铲积累疲劳值
		if hardmode and select_beefalo_dodge and doer.components.rider and doer.components.rider:IsRiding() then
			local duration = 15
			local intiredstate = 3 
			local inbucked = 6
			if doer.prefab == "walter" then 
				intiredstate = 2
				inbucked = 4
				duration = 20
			end
			doer.pettiredPG = doer.pettiredPG + 1
            -- 2025.9.2 melon:头顶显示剩余滑铲次数
            if doer.components.talker and doer.pettiredPG <= 3 then
                local _times = doer.pettiredPG <= 3 and 3 - doer.pettiredPG or 0
                doer.components.talker:Say((TUNING.isCh2hm and "剩余次数: " or "left times: ") .. tostring(_times), 1, true) -- 显示2秒
            end
			if doer.components.grogginess and doer.pettiredPG > intiredstate then
				doer.components.grogginess:AddGrogginess(10)
			end
			if doer.pettiredPG > inbucked then
				doer:PushEvent("bucked")
			end
			if taskPG ~= nil then
				taskPG:Cancel()
				taskPG = nil
			end
			taskPG = doer:DoTaskInTime(duration, function(doer)
				doer.pettiredPG = 0
				doer.components.grogginess:ResetGrogginess()
                -- 2025.9.2 melon:头顶显示剩余滑铲次数
                if doer.components.talker then
                    doer.components.talker:Say((TUNING.isCh2hm and "剩余次数: " or "left times: ") .. tostring(3), 1, true) -- 显示2秒
                end
			end)
			doer:ListenForEvent("death", function(doer)
				doer.pettiredPG = 0
				if taskPG ~= nil then
					taskPG:Cancel()
					taskPG = nil
				end
			end)
			doer:ListenForEvent("bucked", function(doer)
				doer.pettiredPG = 0
				doer.components.grogginess:ResetGrogginess()
				if taskPG ~= nil then
					taskPG:Cancel()
					taskPG = nil
				end
                -- 2025.9.2 melon:头顶显示剩余滑铲次数
                if doer.components.talker then
                    doer.components.talker:Say((TUNING.isCh2hm and "剩余次数: " or "left times: ") .. tostring(3), 2, true) -- 显示2秒
                end
			end)
		end
        doer.sg:GoToState("dodge2hm", {pos = act.pos or act.target})
        return true
    end
end)
ACTIONS.DODGE_WALTER.distance = math.huge
ACTIONS.DODGE_WALTER.instant = true
ACTIONS.DODGE_WALTER.mount_valid = true
STRINGS.ACTIONS.DODGE_WALTER = {GENERIC = TUNING.isCh2hm and "冲刺" or "Dodge"}
local function cancelmiss(inst)
    inst.cancelmisstask2hm = nil
    if inst.allmiss2hm then inst.allmiss2hm = nil end
end
AddStategraphState("wilson", State {
    name = "dodge2hm",
    tags = {"busy", "evade", "no_stun", "canrotate", "pausepredict", "nopredict", "drowning"},
    onenter = function(inst, data)
        inst.components.locomotor:Stop()
        if inst.components.playercontroller ~= nil then inst.components.playercontroller:RemotePausePrediction() end
        if data and data.pos then
            local pos = data.pos:GetPosition()
            inst.tmpangle2hm = inst:GetAngleToPoint(pos.x, 0, pos.z)
            inst:ForceFacePoint(pos.x, 0, pos.z)
        end
        inst.components.locomotor:EnableGroundSpeedMultiplier(false)
        inst.allmiss2hm = true
        if inst.rightaction2hm_double and inst.rightaction2hm_cooldown then
            if GetTime() - inst.last_rightaction2hm_time > inst.rightaction2hm_cooldown / 2 then
                inst:AddTag("doubledodge2hm")
            else
                inst:RemoveTag("doubledodge2hm")
            end
        end
        local riding = inst.components.rider and inst.components.rider:IsRiding()
        if riding then
            inst.AnimState:PlayAnimation("slingshot_pre")
            inst.AnimState:PushAnimation("slingshot", false)
        else
            inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")
            inst.AnimState:PushAnimation("wortox_portal_jumpin_lag", false)
        end
        inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/hop_out")
        -- 冲刺速度
        local speed = inst.rightaction2hm_range or 20
        if riding then speed = speed * 1.2 end
        inst.Physics:SetMotorVelOverride(speed, 0, 0)
        -- 冲刺时长
        local dodgetime = riding and 0.3 or 0.25
        inst.last_rightaction2hm_time = GetTime() + dodgetime
        inst.rightaction2hm:set(inst.rightaction2hm:value() == false and true or false)
        inst.sg:SetTimeout(dodgetime)
    end,
    ontimeout = function(inst)
        if inst.rightaction2hm_callback then inst.rightaction2hm_callback(inst) end
        if not inst.cancelmisstask2hm then inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss) end
        inst.sg:GoToState("idle")
    end,
    onexit = function(inst)
        inst.components.locomotor:EnableGroundSpeedMultiplier(true)
        inst.Physics:ClearMotorVelOverride()
        inst.components.locomotor:Stop()
        inst.components.locomotor:SetBufferedAction(nil)
        if not inst.cancelmisstask2hm then inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss) end
        if inst.tmpangle2hm then inst.tmpangle2hm = nil end
    end
})
local function ClearCachedServerState(inst) if inst.player_classified ~= nil then inst.player_classified.currentstate:set_local(0) end end
AddStategraphState("wilson_client", State {
    name = "dodge2hm",
    tags = {"busy", "evade", "no_stun", "canrotate", "pausepredict", "nopredict", "drowning"},
    onenter = function(inst, data)
        inst.components.locomotor:Stop()
        inst.components.locomotor:Clear()
        inst:ClearBufferedAction()
        inst.entity:FlattenMovementPrediction()
        inst.entity:SetIsPredictingMovement(false)
        ClearCachedServerState(inst)
        if data and data.pos then
            local pos = data.pos:GetPosition()
            inst:ForceFacePoint(pos.x, 0, pos.z)
        end
        local riding = inst.replica and inst.replica.rider and inst.replica.rider:IsRiding()
        if riding then
            inst.AnimState:PlayAnimation("slingshot_pre")
            inst.AnimState:PushAnimation("slingshot", false)
        else
            inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")
            inst.AnimState:PushAnimation("wortox_portal_jumpin_lag", false)
        end
        local dodgetime = riding and 0.3 or 0.25
        inst.last_rightaction2hm_time = GetTime() + dodgetime
        inst.sg:SetTimeout(2)
    end,
    onupdate = function(inst)
        if inst.sg:ServerStateMatches() then
            if inst.entity:FlattenMovementPrediction() then inst.sg:GoToState("idle", "noanim") end
        elseif inst.bufferedaction == nil then
            inst.sg:GoToState("idle")
        end
    end,
    ontimeout = function(inst)
        inst:ClearBufferedAction()
        inst.sg:GoToState("idle")
    end,
    onexit = function(inst)
        -- inst.entity:SetIsPredictingMovement(true)
    end
})
local function equipaoetargeting(inst)
	local item = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if inst.prefab == "walter" and not (TUNING.DSTU and TUNING.WIXIE_HEALTH) then
		return item ~= nil and (item.components.aoetargeting ~= nil or (item.components.aoecharging ~= nil and inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)))
	elseif inst.prefab == "walter" and (TUNING.DSTU and TUNING.WIXIE_HEALTH) then
		return item ~= nil and (item.components.aoetargeting ~= nil or item.components.spellcaster)
	else
		return item ~= nil and item.components.aoetargeting ~= nil
	end
end

local function GetPointSpecialActions_DODGE(inst, pos, useitem, right)
	if inst.prefab == "walter" then
        local mount
		if inst.replica.rider then
			mount = inst.replica.rider:GetMount()
		end
		if right and not equipaoetargeting(inst) and (GetTime() - inst.last_rightaction2hm_time > inst.rightaction2hm_cooldown or inst:HasTag("doubledodge2hm")) and mount and not mount:HasTag("woby") and
		(inst.rightaction2hm_both or (inst.rightaction2hm_beefalo and inst.replica.rider and inst.replica.rider:IsRiding()) or (not inst.rightaction2hm_beefalo and not (inst.replica.rider and inst.replica.rider:IsRiding()))) 
		then return {ACTIONS.DODGE_WALTER} end
		return {}
	else
		if right and not equipaoetargeting(inst) and (GetTime() - inst.last_rightaction2hm_time > inst.rightaction2hm_cooldown or inst:HasTag("doubledodge2hm")) and
		(inst.rightaction2hm_both or (inst.rightaction2hm_beefalo and inst.replica.rider and inst.replica.rider:IsRiding()) or (not inst.rightaction2hm_beefalo and not (inst.replica.rider and inst.replica.rider:IsRiding()))) 
		then return {ACTIONS.DODGE_WALTER} end
		return {}
	end
end
local function OnSetOwner_DODGE(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.rightaction2hm = GetPointSpecialActions_DODGE
        if not inst.components.playeractionpicker.pointspecialactionsfn then
            inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions_DODGE
        else
            local old = inst.components.playeractionpicker.pointspecialactionsfn
            inst.components.playeractionpicker.pointspecialactionsfn = function(...)
                if ctrldisable then
                    return (inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) and old(...)) or
                           GetPointSpecialActions_DODGE(...)
                end
                local actions = GetPointSpecialActions_DODGE(...)
                return #actions > 0 and actions or old(...)
            end
        end
        if inst.prefab == "walter" and TUNING.DSTU and inst.components.playeractionpicker.rightclickoverride and not inst.rightaction2hm_beefalo then
            local old = inst.components.playeractionpicker.rightclickoverride
            inst.components.playeractionpicker.rightclickoverride = function(...)
                local actions, usedefault = old(...)
                if ctrldisable and actions and #actions == 1 and actions[1] and actions[1].action and ACTIONS.WOBY_COMMAND and actions[1].action ==
                    ACTIONS.WOBY_COMMAND and not (inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)) then
                    return {}, true
                end
                return actions, usedefault
            end
        end
        if inst.prefab == "woodie" and GetModConfigData("All Right Dodge") then
            inst.woodiepointspecialactionsfn2hm = inst.components.playeractionpicker.pointspecialactionsfn
        end
    end
end
local function delayOnSetOwner_DODGE(inst) inst:DoTaskInTime(0, OnSetOwner_DODGE) end
function AddDodgeAbility(inst)
	inst.pettiredPG = 0
    inst.rightaction2hm = net_bool(inst.GUID, "player.rightaction2hm", "rightaction2hmdirty")
    inst:ListenForEvent("rightaction2hmdirty", function() inst.last_rightaction2hm_time = GetTime() + 0.25 end)
    inst:ListenForEvent("setowner", delayOnSetOwner_DODGE)
    inst.rightaction2hm_cooldown = 2
    inst.last_rightaction2hm_time = GetTime() - inst.rightaction2hm_cooldown
end

-- 闪避蓄力动作
AddAction("ROTATE_WINONA2HM", "Rotate", function(act, data)
    act.doer.sg:GoToState("rotate_weapon2hm")
    return true
end)
ACTIONS.ROTATE_WINONA2HM.distance = math.huge
ACTIONS.ROTATE_WINONA2HM.instant = true
ACTIONS.ROTATE_WINONA2HM.do_not_locomote = true
STRINGS.ACTIONS.ROTATE_WINONA2HM = {GENERIC = TUNING.isCh2hm and "盈能" or "Rotate"}
local function addrotatetag(inst) inst:AddTag("rotate_weapon2hm") end
local function endrotatebuff(inst)
    if inst:HasTag("rotate_weapon2hm") then inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "rotate_weapon2hm") end
end
local function speedupfx(inst)
    if inst.sg and (inst.sg:HasStateTag("moving") or inst.sg:HasStateTag("runing")) then
        SpawnPrefab("ground_chunks_breaking").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end
local function endrotatespeeduptask(inst)
    inst.rotatespeedup2hmtask = nil
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "rotatespeedup2hm")
    if inst.rotatespeedupfx2hmtask then
        inst.rotatespeedupfx2hmtask:Cancel()
        inst.rotatespeedupfx2hmtask = nil
    end
    inst.components.hunger.burnratemodifiers:RemoveModifier(inst, "rotate_weapon2hm")
end
local state_rotate_weapon2hm = State {
    name = "rotate_weapon2hm",
    tags = {"attack", "busy", "drowning"},
    onenter = function(inst)
        inst.allmiss2hm = true
        inst.AnimState:PlayAnimation("lunge_pre")
        inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tornado", "rotatespeedup2hm")
    end,
    events = {
        EventHandler("animover", function(inst)
            if TheWorld.ismastersim then
                -- 冷却2秒
                inst:RemoveTag("rotate_weapon2hm")
                inst:DoTaskInTime(2, addrotatetag)
                -- 获得持续2.5秒的伤害BUFF
                inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1.25, "rotate_weapon2hm")
                inst:DoTaskInTime(2.5, endrotatebuff)
                -- 获得持续5秒的33%加速
                if not inst.rotatespeedup2hmtask then
                    inst.rotatespeedup2hmtask = inst:DoTaskInTime(5, endrotatespeeduptask)
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "rotatespeedup2hm", 1.25)
                    inst.components.hunger.burnratemodifiers:SetModifier(inst, 1.75, "rotate_weapon2hm")
                    inst.rotatespeedupfx2hmtask = inst:DoPeriodicTask(0.25, speedupfx)
                elseif inst.rotatespeedup2hmtask then
                    inst.rotatespeedup2hmtask:Cancel()
                    inst.rotatespeedup2hmtask = inst:DoTaskInTime(5, endrotatespeeduptask)
                end
            end
            if not inst.cancelmisstask2hm then inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss) end
            inst.sg:GoToState("idle")
        end)
    },
    onexit = function(inst)
        if not inst.cancelmisstask2hm then inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss) end
        inst.SoundEmitter:KillSound("rotatespeedup2hm")
    end
}
AddStategraphState("wilson", state_rotate_weapon2hm)
AddStategraphState("wilson_client", state_rotate_weapon2hm)
local function GetPointSpecialActions_Rotate(inst, pos, useitem, right)
    if right and not equipaoetargeting(inst) and inst:HasTag("rotate_weapon2hm") then
        local has_weapon = false
        local inventory = inst.replica.inventory
        local tool = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        local rider = inst.replica.rider
        if tool ~= nil and not (rider and rider:IsRiding()) then return {ACTIONS.ROTATE_WINONA2HM} end
    end
    return {}
end
local function OnSetOwner_Rotate(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.rightaction2hm = GetPointSpecialActions_Rotate
        if not inst.components.playeractionpicker.pointspecialactionsfn then
            inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions_Rotate
        else
            local old = inst.components.playeractionpicker.pointspecialactionsfn
            inst.components.playeractionpicker.pointspecialactionsfn = function(...)
                if ctrldisable and inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) then
                    local oldactions = old(...)
                    return #oldactions > 0 and oldactions or GetPointSpecialActions_Rotate(...)
                end
                local actions = GetPointSpecialActions_Rotate(...)
                return #actions > 0 and actions or old(...)
            end
        end
    end
end
local function delayOnSetOwner_Rotate(inst) inst:DoTaskInTime(0, OnSetOwner_Rotate) end
function AddRotateAbility(inst)
    inst.rightaction2hm = net_bool(inst.GUID, "player.rightaction2hm", "rightaction2hmdirty")
    inst:AddTag("rotate_weapon2hm")
    inst:ListenForEvent("setowner", delayOnSetOwner_Rotate)
end

-- 未来行走动作
AddAction("WARPFRONT_WANDA", "Wrapfront", function(act, data)
    act.doer.last_rightaction2hm_time = GetTime()
    act.doer.rightaction2hm:set(act.doer.rightaction2hm:value() == false and true or false)
    act.doer.sg:GoToState(TheNet:GetIsClient() and "pocketwatch_warpfront_pre" or "warpfront_pre2hm")
    return true
end)
ACTIONS.WARPFRONT_WANDA.instant = true
STRINGS.ACTIONS.WARPFRONT_WANDA = {GENERIC = TUNING.isCh2hm and "未来行走" or "Warpfront"}
local state_warpfront_pre2hm = State {
    name = "warpfront_pre2hm",
    tags = {"busy"},
    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("pocketwatch_warp_pre")
        local buffaction = inst:GetBufferedAction()
        if buffaction ~= nil then
            inst.AnimState:OverrideSymbol("watchprop", "pocketwatch_warp", "watchprop")
            inst.sg.statemem.castfxcolour = nil
        end
    end,
    timeline = {TimeEvent(1 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/warp") end)},
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                local self = inst.components.positionalwarp
                if not self then
                    inst.sg:GoToState("idle")
                    return
                end
                inst.sg.statemem.portaljumping = true
                local x, y, z = inst.Transform:GetWorldPosition()
                local history_rollback_dist = self.history_rollback_dist
                local maxdist = 0
                local cur = self.history_cur
                for i = 1, history_rollback_dist do
                    if cur == self.history_back then break end
                    maxdist = maxdist + 1
                    cur = (cur - 1) % self.history_max
                end
                if maxdist > 0 then
                    for i = history_rollback_dist, 1, -1 do
                        self.history_rollback_dist = i
                        local tx, ty, tz = self:GetHistoryPosition(false)
                        if tx == nil then break end
                        local dest_x = x + (x - tx) * (i > maxdist and i / maxdist or 1)
                        local dest_y = y + (y - ty) * (i > maxdist and i / maxdist or 1)
                        local dest_z = z + (z - tz) * (i > maxdist and i / maxdist or 1)
                        if TheWorld.Map:IsPassableAtPoint(dest_x, dest_y, dest_z) then
                            inst.sg.statemem.warpback = {
                                dest_x = dest_x,
                                dest_y = dest_y,
                                dest_z = dest_z,
                                frontdata2hm = {x = x, y = y, z = z, dist = i, maxdist = maxdist}
                            }
                            self.history_rollback_dist = history_rollback_dist
                            inst.sg:GoToState("pocketwatch_warpback", inst.sg.statemem)
                            return
                        end
                    end
                end
                self.history_rollback_dist = history_rollback_dist
                inst.sg.statemem.warpback = {dest_x = x, dest_y = y, dest_z = z}
                inst.sg:GoToState("pocketwatch_warpback", inst.sg.statemem)
            end
        end)
    },
    onexit = function(inst) if not inst.sg.statemem.portaljumping then inst.AnimState:ClearOverrideSymbol("watchprop") end end
}
AddStategraphState("wilson", state_warpfront_pre2hm)
AddStategraphPostInit("wilson", function(sg)
    local onenter = sg.states.pocketwatch_warpback_pst.onenter
    sg.states.pocketwatch_warpback_pst.onenter = function(inst, data, ...)
        if data and data.warpback_data and data.warpback_data.frontdata2hm then inst.sg.statemem.frontdata2hm = data.warpback_data.frontdata2hm end
        onenter(inst, data, ...)
        if inst.sg.statemem.frontdata2hm then inst.sg.statemem.frontdata2hm = nil end
    end
end)
local function GetPointSpecialActions_WARPFRONT(inst, pos, useitem, right)
    if not RightActionNeedCtrl(inst, ctrlwrapback) then return {} end
    if right and not equipaoetargeting(inst) and GetTime() - inst.last_rightaction2hm_time > inst.rightaction2hm_cooldown and not inst:GetCurrentPlatform() and
        not (inst.replica.rider and inst.replica.rider:IsRiding()) then return {ACTIONS.WARPFRONT_WANDA} end
    return {}
end
local function OnSetOwner_WARPFRONT(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.rightaction2hm = GetPointSpecialActions_WARPFRONT
        if not inst.components.playeractionpicker.pointspecialactionsfn then
            inst.components.playeractionpicker.pointspecialactionsfn = ctrlwrapback and function(...)
                return inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) and
                           GetPointSpecialActions_WARPFRONT(...) or {}
            end or GetPointSpecialActions_WARPFRONT
        else
            local old = inst.components.playeractionpicker.pointspecialactionsfn
            inst.components.playeractionpicker.pointspecialactionsfn = function(...)
                local pressctrl = inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)
                if ctrlwrapback then return pressctrl and GetPointSpecialActions_WARPFRONT(...) or old(...) end
                if ctrldisable and pressctrl then
                    local oldactions = old(...)
                    return #oldactions > 0 and oldactions or GetPointSpecialActions_WARPFRONT(...)
                end
                local actions = GetPointSpecialActions_WARPFRONT(...)
                return #actions > 0 and actions or old(...)
            end
        end
    end
end
-- 穿梭到未来添加新的N个坐标
local function positionalwarpaddfuturepos(self, frontdata2hm)
    if not frontdata2hm then return end
    local x = frontdata2hm.x
    local y = frontdata2hm.y
    local z = frontdata2hm.z
    local dist = frontdata2hm.dist
    local maxdist = frontdata2hm.maxdist
    if not (x and y and z and dist and maxdist) then return end
    local history_rollback_dist = self.history_rollback_dist
    local history_x = {}
    local history_y = {}
    local history_z = {}
    for i = 1, dist do
        self.history_rollback_dist = i
        local tx, ty, tz = self:GetHistoryPosition(false)
        if tx == nil then break end
        history_x[i] = x + (x - tx) * (i > maxdist and i / maxdist or 1)
        history_y[i] = y + (y - ty) * (i > maxdist and i / maxdist or 1)
        history_z[i] = z + (z - tz) * (i > maxdist and i / maxdist or 1)
    end
    for i = 1, dist do
        if history_x[i] == nil then break end
        self.history_cur = (self.history_cur + 1) % self.history_max
        if self.history_cur == self.history_back then self.history_back = (self.history_back + 1) % self.history_max end
        self.history_x[self.history_cur + 1] = history_x[i]
        self.history_y[self.history_cur + 1] = history_y[i]
        self.history_z[self.history_cur + 1] = history_z[i]
    end
    self.history_rollback_dist = history_rollback_dist
    self:UpdateMarker()
end
local function OnWarpBack(inst, data)
    if inst.components.positionalwarp ~= nil then
        if data ~= nil and data.reset_warp then
            inst.components.positionalwarp:Reset()
        else
            inst.components.positionalwarp:GetHistoryPosition(true)
        end
    end
end
function AddWrapFrontAbility(inst)
    inst.rightaction2hm = net_bool(inst.GUID, "player.rightaction2hm", "rightaction2hmdirty")
    inst:ListenForEvent("rightaction2hmdirty", function() inst.last_rightaction2hm_time = GetTime() end)
    inst:ListenForEvent("setowner", OnSetOwner_WARPFRONT)
    inst.rightaction2hm_cooldown = 2
    inst.last_rightaction2hm_time = GetTime() - inst.rightaction2hm_cooldown
    if not TheWorld.ismastersim then return end
    local self = inst.components.positionalwarp
    if not self then
        self = inst:AddComponent("positionalwarp")
        inst:DoTaskInTime(0, function() self:SetMarker("pocketwatch_warp_marker") end)
        self:SetWarpBackDist(TUNING.WANDA_WARP_DIST_OLD)
        inst:ListenForEvent("onwarpback", OnWarpBack)
    end
    local oldEnableMarker = self.EnableMarker
    self.EnableMarker = function(self, enable) oldEnableMarker(self, true) end
    self:EnableMarker(true)
    local GetHistoryPosition = self.GetHistoryPosition
    self.GetHistoryPosition = function(self, rewind, ...)
        if rewind and self.inst.sg and self.inst.sg.statemem and self.inst.sg.statemem.frontdata2hm then
            positionalwarpaddfuturepos(self, self.inst.sg.statemem.frontdata2hm)
            return
        end
        return GetHistoryPosition(self, rewind, ...)
    end
end

-- 倒走动作 -[[
-- AddAction("WARPBACK_WANDA", "Wrapback", function(act, data)
--     act.doer.last_rightaction2hm_time = GetTime()
--     act.doer.rightaction2hm:set(act.doer.rightaction2hm:value() == false and true or false)
--     act.doer.sg:GoToState(TheNet:GetIsClient() and "pocketwatch_warpback_pre" or "warpback_pre2hm")
--     return true
-- end)
-- ACTIONS.WARPBACK_WANDA.instant = true
-- STRINGS.ACTIONS.WARPBACK_WANDA = {GENERIC = TUNING.isCh2hm and "倒走" or "Warpback"}
-- local state_warpback_pre2hm = State {
--     name = "warpback_pre2hm",
--     tags = {"busy"},
--     onenter = function(inst)
--         inst.components.locomotor:Stop()
--         inst.AnimState:PlayAnimation("pocketwatch_warp_pre")
--         local buffaction = inst:GetBufferedAction()
--         if buffaction ~= nil then
--             inst.AnimState:OverrideSymbol("watchprop", "pocketwatch_warp", "watchprop")
--             inst.sg.statemem.castfxcolour = nil
--         end
--     end,
--     timeline = {TimeEvent(1 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/warp") end)},
--     events = {
--         EventHandler("animover", function(inst)
--             if inst.AnimState:AnimDone() then
--                 local tx, ty, tz = inst.components.positionalwarp:GetHistoryPosition(false)
--                 if tx ~= nil then
--                     inst.sg.statemem.portaljumping = true
--                     inst.sg.statemem.warpback = {dest_x = tx, dest_y = ty, dest_z = tz}
--                     inst.sg:GoToState("pocketwatch_warpback", inst.sg.statemem) -- 'warpback' is set by the action function
--                 else
--                     inst.sg:GoToState("idle")
--                     inst:DoTaskInTime(15 * FRAMES, function(inst)
--                         -- if the player starts moving right away then we can skip this
--                         if inst.sg == nil or inst.sg:HasStateTag("idle") then
--                             inst.components.talker:Say(STRINGS.CHARACTERS.WANDA.ACTIONFAIL.CAST_POCKETWATCH.WARP_NO_POINTS_LEFT)
--                         end
--                     end)
--                 end
--             end
--         end)
--     },
--     onexit = function(inst) if not inst.sg.statemem.portaljumping then inst.AnimState:ClearOverrideSymbol("watchprop") end end
-- }
-- AddStategraphState("wilson", state_warpback_pre2hm) -]]
----------------------------------------------------------------------------------------
-- 2025.5.3 melon: 修改旺达右键倒走
local hardmode_wanda = hardmode and GetModConfigData("wanda")
AddAction("WARPBACK_WANDA", "Wrapback", function(act, data)
    act.doer.last_rightaction2hm_time = GetTime()
    act.doer.rightaction2hm:set(act.doer.rightaction2hm:value() == false and true or false)
    -- act.doer.sg:GoToState(TheNet:GetIsClient() and "pocketwatch_warpback_pre" or "warpback_pre2hm")
    act.doer.sg:GoToState(TheNet:GetIsClient() and "warpback_pre2hm" or "warpback_pre2hm")
    return true
end)
ACTIONS.WARPBACK_WANDA.instant = true
STRINGS.ACTIONS.WARPBACK_WANDA = {GENERIC = TUNING.isCh2hm and "倒走" or "Warpback"}
local state_warpback_pre2hm = State {
    name = "warpback_pre2hm",
    tags = {"busy"},
    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("pocketwatch_warp_pre")
        local buffaction = inst:GetBufferedAction()
        if buffaction ~= nil then
            inst.AnimState:OverrideSymbol("watchprop", "pocketwatch_warp", "watchprop")
            inst.sg.statemem.castfxcolour = nil
        end
    end,
    timeline = {TimeEvent(1 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/warp") end)},
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                local px, py, pz = inst.Transform:GetWorldPosition()
                local tx, ty, tz = inst.components.positionalwarp:GetHistoryPosition(false)
                if select_wrapback == 2 then -- 往正后方倒走
                    if hardmode_wanda then -- 2025.9.21 melon:可关闭旺达困难而关闭
                        inst.components.health:DoDelta(inst.age_state == "old" and -1.25 or -2.5, true, "pocketwatch_heal") -- 2025.8.2 melon:扣1.5年龄  老年扣0.5
                    end
                    SpawnPrefab("shadow_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
                    local dist2hm = inst.age_state == "old" and TUNING.WANDA_WARP_DIST_OLD
                            or inst.age_state == "normal" and TUNING.WANDA_WARP_DIST_NORMAL
                            or TUNING.WANDA_WARP_DIST_YOUNG
                    dist2hm = dist2hm + 4 -- 调整倒走距离
                    -- 转270度是正后  90是正前方  为什么转180度不是正后方
                    local theta = ((inst.Transform:GetRotation() + 270) % 360) * DEGREES
                    -- 倒走点是大陆
                    if IsLandTile(TheWorld.Map:GetTileAtPoint(px + dist2hm * math.sin(theta), py, pz + dist2hm * math.cos(theta))) then
                        inst.Transform:SetPosition(px + dist2hm * math.sin(theta), py, pz + dist2hm * math.cos(theta))-- 瞬移
                    end
                    inst.sg:GoToState("idle")
                elseif select_wrapback == 1 and tx ~= nil then  -- 原来的倒走
                    if not IsLandTile(TheWorld.Map:GetTileAtPoint(tx, ty, tz)) then -- 倒走点不在陆地改为原地倒走
                        tx, ty, tz = px, py, pz
                    end
                    inst.sg.statemem.portaljumping = true
                    inst.sg.statemem.warpback = {dest_x = tx, dest_y = ty, dest_z = tz}
                    inst.sg:GoToState("pocketwatch_warpback", inst.sg.statemem) -- 'warpback' is set by the action function
                else
                    inst.sg:GoToState("idle")
                    inst:DoTaskInTime(15 * FRAMES, function(inst)
                        -- if the player starts moving right away then we can skip this
                        if inst.sg == nil or inst.sg:HasStateTag("idle") then
                            inst.components.talker:Say(STRINGS.CHARACTERS.WANDA.ACTIONFAIL.CAST_POCKETWATCH.WARP_NO_POINTS_LEFT)
                        end
                    end)
                end
            else
                inst.sg:GoToState("idle")
            end
        end)
    },
    onexit = function(inst) if not inst.sg.statemem.portaljumping then inst.AnimState:ClearOverrideSymbol("watchprop") end end
}
AddStategraphState("wilson", state_warpback_pre2hm)
-------------------------------------------------------------
-- 特殊,倒走动作在某种情况下升级
local function GetPointSpecialActions_WARPBACK(inst, pos, useitem, right)
    if not RightActionNeedCtrl(inst, ctrlwrapback) then return {} end
    if right and not equipaoetargeting(inst) and GetTime() - inst.last_rightaction2hm_time > inst.rightaction2hm_cooldown and-- not inst:GetCurrentPlatform() and--2025.5.3 melon:去除在平台上的判断(船上也能倒走了)
        not (inst.replica.rider and inst.replica.rider:IsRiding()) then return {ACTIONS.WARPBACK_WANDA} end
    return {}
end
local function OnSetOwner_WARPBACK(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.rightaction2hm = GetPointSpecialActions_WARPBACK
        if not inst.components.playeractionpicker.pointspecialactionsfn then
            inst.components.playeractionpicker.pointspecialactionsfn = ctrlwrapback and function(...)
                return inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) and
                           GetPointSpecialActions_WARPBACK(...) or {}
            end or GetPointSpecialActions_WARPBACK
        else
            local old = inst.components.playeractionpicker.pointspecialactionsfn
            inst.components.playeractionpicker.pointspecialactionsfn = function(...)
                local pressctrl = inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)
                if ctrlwrapback then return pressctrl and GetPointSpecialActions_WARPBACK(...) or old(...) end
                if ctrldisable and pressctrl then
                    local oldactions = old(...)
                    return #oldactions > 0 and oldactions or GetPointSpecialActions_WARPBACK(...)
                end
                local actions = GetPointSpecialActions_WARPBACK(...)
                return #actions > 0 and actions or old(...)
            end
        end
    end
end
function AddWrapAbility(inst)
    inst.rightaction2hm = net_bool(inst.GUID, "player.rightaction2hm", "rightaction2hmdirty")
    inst:ListenForEvent("rightaction2hmdirty", function() inst.last_rightaction2hm_time = GetTime() end)
    inst:ListenForEvent("setowner", OnSetOwner_WARPBACK)
    inst.rightaction2hm_cooldown = 2
    inst.last_rightaction2hm_time = GetTime() - inst.rightaction2hm_cooldown
    if not TheWorld.ismastersim then return end
    if not inst.components.positionalwarp then
        inst:AddComponent("positionalwarp")
        inst:DoTaskInTime(0, function() inst.components.positionalwarp:SetMarker("pocketwatch_warp_marker") end)
        inst.components.positionalwarp:SetWarpBackDist(TUNING.WANDA_WARP_DIST_OLD)
        inst:ListenForEvent("onwarpback", OnWarpBack)
    end
    local oldEnableMarker = inst.components.positionalwarp.EnableMarker
    inst.components.positionalwarp.EnableMarker = function(self, enable) oldEnableMarker(self, true) end
    inst.components.positionalwarp:EnableMarker(true)
end

-- 暗影冲刺动作,该动作需要处理标签
AddAction("Lunge_WAXWELL2HM", "lunge", function(act, data)
    if TheNet:GetIsClient() then
        act.doer.sg:GoToState("combat_lunge_start")
    else
        act.doer.sg:GoToState("lunge_pre2hm", {targetpos = act.pos or (act.target and Vector3(act.target.Transform:GetWorldPosition()))})
    end
    return true
end)
ACTIONS.Lunge_WAXWELL2HM.distance = math.huge
ACTIONS.Lunge_WAXWELL2HM.instant = true
-- The native prediction state only recognizes native lunge state names.
-- Preserve its animation/timeout handling, but also accept our server states.
AddStategraphPostInit("wilson_client", function(sg)
    local state = sg.states.combat_lunge_start
    if state then
        state.server_states = state.server_states or {}
        for _, name in ipairs({"lunge_pre2hm", "lunge_loop2hm"}) do
            state.server_states[hash(name)] = true
        end
    end
end)
STRINGS.ACTIONS.Lunge_WAXWELL2HM = {GENERIC = TUNING.isCh2hm and "暗袭" or "Lunge"}
local function endlungecd(inst)
    inst.shadowlungecdtask2hm = nil
    if inst.shadowlungeendfn2hm then
        inst:shadowlungeendfn2hm()
    else
        inst:AddTag("shadowlunge2hm")
    end
end
local state_lunge_pre = State {
    name = "lunge_pre2hm",
    tags = {"attack", "busy", "evade", "no_stun", "pausepredict", "nopredict", "drowning", "busy", "aoe", "doing", "nointerrupt", "nomorph"},
    onenter = function(inst, data)
        local targetpos = data and data.targetpos and data.targetpos:GetPosition()
        if not targetpos then
            inst.sg:GoToState("idle")
            return
        end
        inst.components.locomotor:Stop()
        inst:ForceFacePoint(targetpos)
        local radius = math.max((inst.shadowlevel2hm or 4) * 4, 8)
        local firstradius = inst:GetDistanceSqToPoint(targetpos)
        if firstradius <= 16 then
            local theta = inst.Transform:GetRotation() * DEGREES
            local pos = inst:GetPosition()
            for i = 4, radius, 1 do
                local offset = Vector3(i * math.cos(theta), 0, -i * math.sin(theta))
                local targetpos = pos + offset
                if not TheWorld.Map:IsOceanAtPoint(targetpos.x, 0, targetpos.z, false) then
                    inst.sg.statemem.targetpos = targetpos
                    break
                end
            end
        elseif firstradius >= radius * radius then
            local theta = inst.Transform:GetRotation() * DEGREES
            local pos = inst:GetPosition()
            for i = radius, 4, -1 do
                local offset = Vector3(i * math.cos(theta), 0, -i * math.sin(theta))
                local targetpos = pos + offset
                if not TheWorld.Map:IsOceanAtPoint(targetpos.x, 0, targetpos.z, false) then
                    inst.sg.statemem.targetpos = targetpos
                    break
                end
            end
        else
            inst.sg.statemem.targetpos = targetpos
        end
        if not inst.sg.statemem.targetpos then
            inst.sg:GoToState("idle")
            return
        end
        inst.sg.statemem.use = inst:GetDistanceSqToPoint(inst.sg.statemem.targetpos) / (radius * radius)
        inst.allmiss2hm = true
        if not inst.cancelmisstask2hm then inst.cancelmisstask2hm = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.1, cancelmiss) end
        inst:RemoveTag("shadowlunge2hm")
        inst.shadowlungecdtask2hm = inst:DoTaskInTime(8, endlungecd)
        inst.AnimState:PlayAnimation("lunge_pre")
        inst.sg.statemem.weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end,
    timeline = {TimeEvent(4 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/twirl", nil, nil, true) end)},
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("lunge_loop2hm", {weapon = inst.sg.statemem.weapon, use = inst.sg.statemem.use, targetpos = inst.sg.statemem.targetpos})
            end
        end)
    },
    onexit = function(inst)
        if inst.cancelmisstask2hm then inst.cancelmisstask2hm:Cancel() end
        inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss)
    end
}
local function onlungehit(inst, doer, target)
    local fx = SpawnPrefab(math.random() < .5 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
    local x, y, z = target.Transform:GetWorldPosition()
    fx.Transform:SetPosition(x, y + 1.5, z)
    fx.Transform:SetRotation(doer.Transform:GetRotation())
end
local TOSS_MUSTTAGS = {"_inventoryitem"}
local TOSS_CANTTAGS = {"locomotor", "INLIMBO"}
function AOEWeapon_Lunge_DoLunge(self, doer, startingpos, targetpos)
    if not startingpos or not targetpos or not doer or not doer.components.combat then return false end
    if self.onprelungefn ~= nil then self.onprelungefn(self.inst, doer, startingpos, targetpos) end
    -- Hitting -----------------------------------------------------------------
    local doer_combat = doer.components.combat
    doer_combat:EnableAreaDamage(false)
    local weapon = self.inst.components.weapon
    local attackwear = 0
    if weapon then
        attackwear = weapon.attackwear
        if attackwear ~= 0 then weapon.attackwear = 0 end
    end
    local p1 = {x = startingpos.x, y = startingpos.z}
    local p2 = {x = targetpos.x, y = targetpos.z}
    local dx, dy = p2.x - p1.x, p2.y - p1.y
    local dist = dx * dx + dy * dy
    local toskip = {}
    local pv = {}
    local r, cx, cy
    if dist > 0 then
        dist = math.sqrt(dist)
        r = (dist + doer_combat.hitrange * 0.5 + self.physicspadding) * 0.5 + 0.15
        dx, dy = dx / dist, dy / dist
        cx, cy = p1.x + dx * r, p1.y + dy * r
        doer_combat.ignorehitrange = true
        local c_hit_targets = TheSim:FindEntities(cx, 0, cy, r, nil, self.notags, self.combinedtags)
        for _, hit_target in ipairs(c_hit_targets) do
            toskip[hit_target] = true
            if hit_target ~= doer and hit_target:IsValid() and not hit_target:IsInLimbo() and
                not (hit_target.components.health and hit_target.components.health:IsDead()) then
                pv.x, pv._, pv.y = hit_target.Transform:GetWorldPosition()
                local vrange = self.siderange + hit_target:GetPhysicsRadius(0.5) + 0.15
                if DistPointToSegmentXYSq(pv, p1, p2) < vrange * vrange then self:OnHit(doer, hit_target) end
            end
        end
        doer_combat.ignorehitrange = false
    end
    local angle = (doer.Transform:GetRotation() + 90) * DEGREES
    local p3 = {x = p2.x + doer_combat.hitrange * math.sin(angle), y = p2.y + doer_combat.hitrange * math.cos(angle)}
    local p2_hit_targets = TheSim:FindEntities(p2.x, 0, p2.y, doer_combat.hitrange + self.physicspadding, nil, self.notags, self.combinedtags)
    for _, hit_target in ipairs(p2_hit_targets) do
        if not toskip[hit_target] and hit_target:IsValid() and not hit_target:IsInLimbo() and
            not (hit_target.components.health and hit_target.components.health:IsDead()) then
            pv.x, pv._, pv.y = hit_target.Transform:GetWorldPosition()
            local vradius = hit_target:GetPhysicsRadius(0.5)
            local vrange = doer_combat.hitrange + vradius
            if distsq(pv.x, pv.y, p2.x, p2.y) < vrange * vrange then
                vrange = self.siderange + vradius
                if DistPointToSegmentXYSq(pv, p2, p3) < vrange * vrange then self:OnHit(doer, hit_target) end
            end
        end
    end
    doer_combat:EnableAreaDamage(true)
    if weapon then if attackwear ~= 0 then weapon.attackwear = attackwear end end
    -- Tossing -----------------------------------------------------------------
    toskip = {}
    local srcpos = Vector3()
    if dist > 0 then
        local c_toss_targets = TheSim:FindEntities(cx, 0, cy, r, TOSS_MUSTTAGS, TOSS_CANTTAGS)
        for _, toss_target in ipairs(c_toss_targets) do
            toskip[toss_target] = true
            pv.x, pv._, pv.y = toss_target.Transform:GetWorldPosition()
            local lensq = DistPointToSegmentXYSq(pv, p1, p2)
            local vrangesq = self.siderange + toss_target:GetPhysicsRadius(0.5)
            vrangesq = vrangesq * vrangesq
            if lensq < vrangesq and pv._ < 0.2 then
                local dxv, dyv = pv.x - p1.x, pv.y - p1.y
                local proj = math.sqrt(dxv * dxv + dyv * dyv - lensq)
                srcpos.x = p1.x + dx * proj
                srcpos.z = p1.y + dy * proj
                if lensq <= 0 then
                    proj = (math.random(2) - 1.5) * .1
                    srcpos.x = srcpos.x + dy * proj
                    srcpos.z = srcpos.z + dx * proj
                end
                self:OnToss(doer, toss_target, srcpos, 1 - lensq / vrangesq, math.sqrt(lensq))
            end
        end
    end
    local p2_toss_targets = TheSim:FindEntities(p2.x, 0, p2.y, doer_combat.hitrange + self.physicspadding, TOSS_MUSTTAGS, TOSS_CANTTAGS)
    for _, toss_target in ipairs(p2_toss_targets) do
        if not toskip[toss_target] then
            pv.x, pv._, pv.y = toss_target.Transform:GetWorldPosition()
            local lensq = distsq(pv.x, pv.y, p2.x, p2.y)
            local vradius = toss_target:GetPhysicsRadius(0)
            local vrangesq = doer_combat.hitrange + vradius
            if lensq < vrangesq * vrangesq and pv._ < 0.2 then
                vrangesq = self.siderange + vradius
                vrangesq = vrangesq * vrangesq
                if DistPointToSegmentXYSq(pv, p2, p3) < vrangesq then
                    local dxv, dyv = pv.x - p2.x, pv.y - p2.y
                    local proj = math.sqrt(dxv * dxv + dyv * dyv - lensq)
                    srcpos.x = p1.x + dx * proj
                    srcpos.z = p1.y + dy * proj
                    if lensq <= 0 then
                        proj = (math.random(2) - 1.5) * 0.1
                        srcpos.x = srcpos.x + dy * proj
                        srcpos.z = srcpos.z + dx * proj
                    end
                    self:OnToss(doer, toss_target, srcpos, 1.5 - lensq / vrangesq, math.sqrt(lensq))
                end
            end
        end
    end
    -- FX trail ----------------------------------------------------------------
    if self.fxprefab and (self.fxspacing or 0) > 0 then
        if dist <= 0 then
            local fx = SpawnPrefab(self.fxprefab)
            fx.Transform:SetPosition(p2.x, 0, p2.y)
        else
            dist = math.floor(dist / self.fxspacing)
            dx = dx * self.fxspacing
            dy = dy * self.fxspacing
            local flip = math.random() < 0.5
            for i = 0, dist do
                if i == 0 then
                    p2.x = p2.x - dx * 0.25
                    p2.y = p2.y - dy * 0.25
                elseif i == 1 then
                    p2.x = p2.x - dx * 0.75
                    p2.y = p2.y - dy * 0.75
                else
                    p2.x = p2.x - dx
                    p2.y = p2.y - dy
                end
                local fx = SpawnPrefab(self.fxprefab)
                fx.Transform:SetPosition(p2.x, 0, p2.y)
                local k = (dist > 0 and math.max(0, 1 - i / dist)) or 0
                k = 1 - k * k
                if fx.FastForward then fx:FastForward(0.4 * k) end
                if fx.SetMotion then
                    k = 1 + k * 2
                    fx:SetMotion(k * dx, 0, k * dy)
                end
                if flip and fx.AnimState then fx.AnimState:SetScale(-1, 1) end
                flip = not flip
            end
        end
    end
    if self.onlungedfn ~= nil then self.onlungedfn(self.inst, doer, startingpos, targetpos) end
    return true
end
local function itemcomponent(item) return item and item:IsValid() and (item.components.finiteuses or item.components.fueled or item.components.armor) end
local state_lunge_loop = State {
    name = "lunge_loop2hm",
    tags = {"attack", "busy", "noattack", "temp_invincible"},
    onenter = function(inst, data)
        inst.AnimState:PlayAnimation("lunge_pst") -- NOTE: this anim NOT a loop yo
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_shadow_med_sharp")
        local pos = inst:GetPosition()
        if pos.x ~= data.targetpos.x or pos.z ~= data.targetpos.z then inst:ForceFacePoint(data.targetpos:Get()) end
        local weapon = data and data.weapon
        local component = itemcomponent(weapon) or itemcomponent(inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)) or
                              itemcomponent(inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY))
        if component and component.SetPercent then
            component:SetPercent(component:GetPercent() - 0.05 * (data and data.use or 1))
            if weapon and weapon:IsValid() then
                if not weapon.components.aoeweapon_lunge then
                    if not weapon.components.weapon then
                        weapon:AddComponent("weapon")
                        weapon.components.weapon:SetDamage(10)
                    end
                    weapon:AddComponent("aoeweapon_lunge")
                    if weapon.components.aoeweapon_lunge.SetWorkActions then
                        weapon.components.aoeweapon_lunge:SetWorkActions()
                        weapon.components.aoeweapon_lunge.tags = {"_combat"}
                        weapon.components.aoeweapon_lunge:SetOnHitFn(onlungehit)
                        if weapon:HasTag("shadow_item") then
                            if weapon.components.planardamage and inst.components.damagetypebonus then
                                weapon.components.aoeweapon_lunge:SetTrailFX("willow_shadow_flame", 1.5)
                                inst.components.damagetypebonus:AddBonus("_health", weapon, TUNING.SHADOWWAXWELL_SHADOWSTRIKE_DAMAGE_MULT, "_shadowstrike2hm")
                            else
                                weapon.components.aoeweapon_lunge:SetTrailFX("cane_ancient_fx", 1)
                                inst.components.combat.externaldamagemultipliers:SetModifier(weapon, TUNING.SHADOWWAXWELL_SHADOWSTRIKE_DAMAGE_MULT,
                                                                                             "shadowstrike2hm")
                            end
                        end
                        AOEWeapon_Lunge_DoLunge(weapon.components.aoeweapon_lunge, inst, pos, data.targetpos)
                        if weapon:IsValid() then
                            inst.components.combat.externaldamagemultipliers:RemoveModifier(weapon, "shadowstrike2hm")
                            if inst.components.damagetypebonus then
                                inst.components.damagetypebonus:RemoveBonus("_health", weapon, "_shadowstrike2hm")
                            end
                        end
                    end
                    if weapon:IsValid() then weapon:RemoveComponent("aoeweapon_lunge") end
                end
            end
            inst.Physics:Teleport(data.targetpos.x, 0, data.targetpos.z)
        end
        if inst.cancelmisstask2hm then inst.cancelmisstask2hm:Cancel() end
        inst.cancelmisstask2hm = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.1, cancelmiss)
    end,
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                if inst.cancelmisstask2hm then inst.cancelmisstask2hm:Cancel() end
                inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss)
                inst.sg:GoToState("idle")
            end
        end)
    },
    onexit = function(inst)
        if inst.cancelmisstask2hm then inst.cancelmisstask2hm:Cancel() end
        inst.cancelmisstask2hm = inst:DoTaskInTime(0.1, cancelmiss)
    end
}
AddStategraphState("wilson", state_lunge_pre)
AddStategraphState("wilson", state_lunge_loop)
local function GetPointSpecialActions_Lunge(inst, pos, useitem, right)
    if not RightActionNeedCtrl(inst, ctrlLunge) then return {} end
    if right and not equipaoetargeting(inst) and inst:HasTag("shadowlunge2hm") and not inst:GetCurrentPlatform() then
        local has_weapon = false
        local inventory = inst.replica.inventory
        local tool = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        if tool ~= nil then
            local inventoryitem = tool.replica.inventoryitem
            has_weapon = inventoryitem ~= nil and inventoryitem:IsWeapon() and not tool:HasTag("rangedweapon") and not tool:HasTag("projectile")
        end
        local rider = inst.replica.rider
        if has_weapon and not (rider and rider:IsRiding()) and not TheWorld.Map:IsOceanAtPoint(pos.x, pos.y, pos.z, false) then
            return {ACTIONS.Lunge_WAXWELL2HM}
        end
    end
    return {}
end
local function OnSetOwner_Lunge(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.rightaction2hm = GetPointSpecialActions_Lunge
        if not inst.components.playeractionpicker.pointspecialactionsfn then
            inst.components.playeractionpicker.pointspecialactionsfn = ctrlLunge and function(...)
                return inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) and
                           GetPointSpecialActions_Lunge(...) or {}
            end or GetPointSpecialActions_Lunge
        else
            local old = inst.components.playeractionpicker.pointspecialactionsfn
            inst.components.playeractionpicker.pointspecialactionsfn = function(...)
                local pressctrl = inst.components.playercontroller and inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)
                if ctrlLunge then return pressctrl and GetPointSpecialActions_Lunge(...) or old(...) end
                if ctrldisable and pressctrl then
                    local oldactions = old(...)
                    return #oldactions > 0 and oldactions or GetPointSpecialActions_Lunge(...)
                end
                local actions = GetPointSpecialActions_Lunge(...)
                return #actions > 0 and actions or old(...)
            end
        end
    end
end
local function delayOnSetOwner_Lunge(inst) inst:DoTaskInTime(0, OnSetOwner_Lunge) end
function AddLungeAbility(inst)
    inst.rightaction2hm = net_bool(inst.GUID, "player.rightaction2hm", "rightaction2hmdirty")
    inst:ListenForEvent("setowner", delayOnSetOwner_Lunge)
end

-- 扩展动作使用范围
AddComponentPostInit("playeractionpicker", function(self)
    local DoGetMouseActions = self.DoGetMouseActions
    self.DoGetMouseActions = function(self, position, target, spellbook, ...)
        if not (self.inst.replica and self.inst.replica.inventory) then return end
        local ok, leftaction, rightaction = pcall(DoGetMouseActions, self, position, target, spellbook, ...)
        if not ok then
            -- 兼容 Uncompromising Mode 的 magmatiles/GetRightClickActions：
            -- 其右键路径可能传入带 inventoryitem 组件但没有 replica.inventoryitem 的实体，
            -- 核心 componentactions.lua 会因此索引 nil。这里只拦截这一种已知错误，
            -- 其它真正的 Lua 错误继续抛出，避免掩盖问题。
            if type(leftaction) == "string" and leftaction:find("inventoryitem", 1, true) then
                if not self._happy_patch_inventoryitem_warned2hm then
                    self._happy_patch_inventoryitem_warned2hm = true
                    print("[HappyPatch] suppressed inventoryitem action-picker crash: " .. tostring(leftaction))
                end
                return nil, nil
            end
            error(leftaction, 0)
        end
        local ctrlpressed = self.inst.components.playercontroller ~= nil and
            self.inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK)
        if (rightaction == nil or (ctrlwrapback and ctrlpressed)) and self.rightaction2hm and not TheInput:GetHUDEntityUnderMouse() then
            -- 获取自定义右键动作列表
            local custom_actions = self.rightaction2hm(self.inst,
                position or TheInput:GetWorldPosition() or (target and target:GetPosition()), nil, true)

            -- 2025.11.25 YeFeng:【修复】确保所有动作都有有效的 priority 值,防止与其他模组冲突导致排序崩溃
            -- YeFeng: 修复与热带冒险等模组的兼容性问题
            if custom_actions and type(custom_actions) == "table" then
                for i, action in pairs(custom_actions) do
                    if action and action.priority == nil then
                        action.priority = 0 -- 设置默认优先级为0
                    end
                end
            end
            -- 只有确实拿到自定义动作时才覆盖原右键动作。
            -- 这样不按 Ctrl 时保留妥协滑行手杖的右键滑行；
            -- 按 Ctrl 时强制用旺达倒走覆盖滑行。
            if custom_actions and type(custom_actions) == "table" and #custom_actions > 0 then
                rightaction = self:SortActionList(custom_actions)[1]
                if position and rightaction then
                    if not rightaction.pos then
                        rightaction.pos = DynamicPosition(position)
                        rightaction.pos.local_pt = Vector3(position:Get())
                    elseif rightaction.pos and rightaction.pos.local_pt then
                        rightaction.pos.local_pt = Vector3(position:Get())
                    end
                end
            end
        end
        return leftaction, rightaction
    end
end)
-- AddComponentPostInit("playercontroller", function(self)
--     local IsAOETargeting = self.IsAOETargeting
--     self.IsAOETargeting = function (self,...)
--         return IsAOETargeting(self,...) and not (ctrloverrideequip and self.inst.rightaction2hm and self:IsControlPressed(CONTROL_FORCE_STACK))
--     end
-- end)
-- local GetRightClickActions = self.GetRightClickActions
-- self.GetRightClickActions = function(self, position, target, spellbook, ...)
--     local rightactions = GetRightClickActions(self, position, target, spellbook, ...)
--     if rightactions and rightactions[1] and self.rightaction2hm and ctrloverrideequip and rightactions[1].target and rightactions[1].invobject ==
--         (self.inst.replica.inventory and self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)) and rightactions[1].invobject ~=
--         rightactions[1].target and self.inst.components.playercontroller and self.inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) then
--         local newrightaction = self:SortActionList(self.rightaction2hm(self.inst,
--                                                                        position or TheInput:GetWorldPosition() or (target and target:GetPosition()), nil,
--                                                                        true))[1]
--         if position and newrightaction then
--             if not newrightaction.pos then
--                 newrightaction.pos = DynamicPosition(pos)
--                 newrightaction.pos.local_pt = Vector3(position:Get())
--             elseif newrightaction.pos and newrightaction.pos.local_pt then
--                 newrightaction.pos.local_pt = Vector3(position:Get())
--             end
--             rightactions = {newrightaction}
--         end
--     end
--     return rightactions
-- end

-- if TheNet:GetIsClient() then
--     local function IsDefaultScreen()
--         local active_screen = TheFrontEnd:GetActiveScreen()
--         local screenname = active_screen and active_screen.name or ""
--         return screenname:find("HUD") ~= nil and ThePlayer ~= nil and not ThePlayer.HUD:IsChatInputScreenOpen() and not ThePlayer.HUD.writeablescreen and
--                    not (ThePlayer.HUD.controls and ThePlayer.HUD.controls.craftingmenu and ThePlayer.HUD.controls.craftingmenu.craftingmenu and
--                        ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box and ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box.textbox and
--                        ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box.textbox.editing)
--     end
--     TheInput:AddKeyHandler(function(_, down)
--         if down and handlekeys and ((handlekeys == true and TheInput:IsKeyDown(KEY_SPACE) and TheInput:IsKeyDown(CONTROL_FORCE_STACK)) or TheInput:IsKeyDown(handlekeys)) and
--             ThePlayer and ThePlayer:IsValid() and ThePlayer.rightaction2hm and IsDefaultScreen() and ThePlayer.sg and ThePlayer.sg:HasStateTag("idle") then
--              end
--     end)
-- end
