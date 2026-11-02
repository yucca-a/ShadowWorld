-- 2026.8.7:沃托姆夜视优化 - 客户端强制(微光+永久夜视,游戏机制方案)
-- 背景:旧方案在服务器端覆盖不妥协内部变量(inst.IsInLight=true / inst.updatewathomvisiontask=1),
--   2026.8 不妥协测试版(workshop-3193922031)改了 CheckLight,把 updatewathomvisiontask 当 task 调用
--   :Cancel(),数字占位 1 导致服务器崩溃(attempt to index a number value)。
-- 新方案:不再碰不妥协任何内部变量,用游戏机制绕过:
--   1) 服务器给 wathom 打 "wathom_nv_2hm" 标签 + 常驻微光实体(强度1.2,GetLightAtPoint>0.9)
--      → 不妥协 CheckLight(新旧版)永远判定"有光"→ 不触发它自己的夜视/滤镜,也碰不到
--        updatewathomvisiontask 的取消分支,天然防崩溃防闪烁。
--   2) 本文件(客户端):看到标签后,把 playervision 的 ForceNightVision/SetCustomCCTable 替换为空操作,
--      不妥协每2秒的"关夜视"调用全部失效;视觉用保存的原方法直接强制 春天滤镜+永久夜视。
-- 信号为何用标签:实体标签随网络复制,比 RPC 可靠(无需处理注册方向/丢失),比客户端读配置可靠
--   (non-client 配置在客户端读默认 false,2026.8.6 已验证)。
-- 加载范围:纯专用服务器进程无渲染逻辑,提前 return;其余(客户端/房主)都会执行。
local daycc = "images/colour_cubes/spring_day_cc.tex" -- 原版春天滤镜
local keep_on_day_cubes = {
    day = daycc,
    dusk = "images/colour_cubes/spring_dusk_cc.tex",
    night = daycc,
    full_moon = daycc,
}

-- 完全吞掉 + 主动应用:
--   SetCustomCCTable/ForceNightVision 替换为空操作 → 永不妥协 CheckLight 每0.3秒/2秒的开关调用全部无效果
--   保存原方法到 __wathom_apply2hm,由我们主动强制 春天滤镜+永久夜视(就绪后可重复调用)
local function patch_wathom_vision(comp)
    if not comp or comp.__wathom_nightvision_patched2hm then return end
    comp.__wathom_nightvision_patched2hm = true -- 防重复包装(不妥协/其他模组重复调用)
    local _SetCustomCCTable = comp.SetCustomCCTable
    local _ForceNightVision = comp.ForceNightVision
    comp.SetCustomCCTable = function(self, cctable, blend)
        return -- 完全吞掉:不妥协/任何人的滤镜调用都不生效,防止刷新闪烁
    end
    comp.ForceNightVision = function(self, force)
        return -- 完全吞掉:夜视开关只由我们控制
    end
    comp.__wathom_apply2hm = function()
        _SetCustomCCTable(comp, keep_on_day_cubes) -- 原方法:春天滤镜
        _ForceNightVision(comp, true) -- 原方法:永久夜视
    end
    comp.__wathom_apply2hm() -- 立即应用
end

-- 暴露给服务器端(wathom_easy.lua):房主(客户端托管)场景下,服务器实体即渲染实体,
-- 服务器端可直接调用本包装函数,不依赖标签同步时序,视觉立即生效。
TUNING.wathom_nv_patch2hm = patch_wathom_vision

-- 强制一次 + 就绪重试:标签可能未同步、playervision 组件可能延迟就绪。
-- 每0.5秒轮询:等标签出现→包装→应用;同时本地移除 WathomInDark 兜底屏蔽不妥协的黑雾/心跳。
local function force_vision(inst)
    if not inst or not inst:IsValid() then return end
    if inst._wathom_nv_loop2hm then return end -- 已有循环,防重复
    inst._wathom_nv_loop2hm = true
    local retry = 0
    local task
    task = inst:DoPeriodicTask(0.5, function(i)
        if not i or not i:IsValid() then
            if task then task:Cancel() end
            return
        end
        retry = retry + 1
        if not i:HasTag("wathom_nv_2hm") then
            -- 服务器未开启夜视优化 / 标签尚未同步:继续等待(20秒兜底)
            if retry >= 40 then
                if task then task:Cancel() end
            end
            return
        end
        -- 兜底屏蔽黑雾/心跳:服务器每0.3秒重新添加WathomInDark,客户端本地移除不反向影响服务器
        i:RemoveTag("WathomInDark")
        local p = i.components.playervision
        if p then patch_wathom_vision(p) end
        local ready = p and p.__wathom_apply2hm and p.inst and p.inst.replica and p.inst.replica.playervision
        if ready then
            p.__wathom_apply2hm() -- 就绪后主动应用一次并停止
            if task then task:Cancel() end
        elseif retry >= 40 then
            if task then task:Cancel() end -- 20秒兜底强制停止
        end
    end)
end

if TheNet:IsDedicated() then return end -- 纯专用服务器无渲染,以下仅客户端/房主执行

--组件级:playervision 组件添加时立即包装(客户端实体组件就绪就能拦截 CheckLight)
AddComponentPostInit("playervision", function(comp, inst)
    if inst and inst.prefab == "wathom" and inst:HasTag("wathom_nv_2hm") then
        patch_wathom_vision(comp)
    end
end)

--实体级:客户端 wathom 实体生成时立即强制 + 延迟兜底(组件/标签可能延迟同步)
AddPrefabPostInit("wathom", function(inst)
    force_vision(inst)
    inst:DoTaskInTime(0.5, function()
        if not inst:IsValid() then return end
        force_vision(inst)
    end)
end)

--地玩家兜底:进世界后立即强制
AddSimPostInit(function()
    if ThePlayer and ThePlayer.prefab == "wathom" and ThePlayer:HasTag("wathom_nv_2hm") then
        force_vision(ThePlayer)
    end
end)
