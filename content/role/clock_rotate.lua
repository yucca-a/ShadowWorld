-------------------------------------------------------------------------------------
-------------------------[[2025.6.23 melon:时钟险境]]---------------------------------
-- 右上角时钟每天逆时针旋转一格，但实际时间不变
-- 可选:顺或逆旋转1~3格  第3天逆2格，第4天逆3格，第5天顺3格，第6天逆2格
-- 根据天数计算随机数，因此某一天的改变是固定的
-------------------------------------------------------------------------------------
local select_clock = GetModConfigData("clock_rotate")
select_clock = select_clock == true and 1 or select_clock -- 1:循环顺时针/逆时针旋转1~3格  2:每天逆时针1格
--------------------------------------------------------------------------------------
--[[ Constants ]]
local NUM_SEGS = 16
local DAY_COLOUR = Vector3(254 / 255, 212 / 255, 86 / 255)
local DUSK_COLOUR = Vector3(165 / 255, 91 / 255, 82 / 255)
local CAVE_DAY_COLOUR = Vector3(174 / 255, 195 / 255, 108 / 255)
local CAVE_DUSK_COLOUR = Vector3(113 / 255, 127 / 255, 108 / 255)
local DARKEN_PERCENT = .75
-------------------------------------------------------------------------------------
AddClassPostConstruct("widgets/uiclock", function(self)
    -- 新函数  由OnClockSegsChanged修改而来
    self.clockrotate2hm = function(self, data)
        -- 根据传入的 day/dusk/night 分段数：动态调整每个分段的颜色，交替变暗（DARKEN_PERCENT）以增强区分度。
        local day = data.day or self._daysegs2hm or 0 
        local dusk = data.dusk or self._dusksegs2hm or 0
        local night = data.night or self._nightsegs2hm or 0
        if day + dusk + night ~= NUM_SEGS then return end
        -- assert(day + dusk + night == NUM_SEGS, "invalid number of time segs") -- 改为上面的if
        -------------------------------
        local cycles = TheWorld and TheWorld.state.cycles or self._cycles or 0
        -- 计算旋转几格，一共16(NUM_SEGS)格，每天逆时针旋转1格  seg分段
        -- 选择1时，从-3到3循环  +3让第一天不旋转 6 - ((cycles + 3) % 7 - 3)   6-表示反向转
        local rotate_seg = select_clock == 1 and (3 - (cycles + 3) % 7) % NUM_SEGS or cycles % NUM_SEGS
        -- print("#####seg ", rotate_seg)
        -------------------------
        -- 设置self._segs的颜色
        local dark = rotate_seg % 2 == 0 -- 原本是true,%2可以让深浅位置固定
        local cur = rotate_seg + 1 -- 当前格子
        local color = self._cave and CAVE_DAY_COLOUR or DAY_COLOUR -- 白天
        local real_color
        for i = 1, day do -- 设置白天部分
            real_color = dark and color * DARKEN_PERCENT or color
            -- print("#####day, cur: ", cur, " dark: ", dark)
            self._segs[cur]:Show()
            self._segs[cur]:SetTint(real_color.x, real_color.y, real_color.z, 1)
            cur = cur + 1 > NUM_SEGS and 1 or cur + 1 -- 超过就变1
            dark = not dark -- 颜色一深一浅
        end
        color = self._cave and CAVE_DUSK_COLOUR or DUSK_COLOUR --黄昏
        for i = 1, dusk do -- 设置黄昏部分
            real_color = dark and color * DARKEN_PERCENT or color
            -- print("#####dusk, cur: ", cur, " dark: ", dark)
            self._segs[cur]:Show()
            self._segs[cur]:SetTint(real_color.x, real_color.y, real_color.z, 1)
            cur = cur + 1 > NUM_SEGS and 1 or cur + 1
            dark = not dark
        end
        for i = 1, night do -- 设置黑夜部分
            -- print("#####night, cur: ", cur, " dark: ", dark)
            self._segs[cur]:Hide() -- 隐藏了就是黑夜颜色
            cur = cur + 1 > NUM_SEGS and 1 or cur + 1
        end
        -- 原本代码有 self._daysegs = day
        self._daysegs2hm = day   -- 白天长度
        self._dusksegs2hm = dusk   -- 黄昏
        self._nightsegs2hm = night   -- 黑夜
    end
    -----------------------------------------
    local _OnClockSegsChanged = self.OnClockSegsChanged
    self.OnClockSegsChanged = function(self, data)
        _OnClockSegsChanged(self, data) -- 原来的
        self.clockrotate2hm(self, data) -- 改之后的
    end
    -- 执行OnCyclesChanged时执行一次clockrotate2hm  因为每天都要更新
    local _OnCyclesChanged = self.OnCyclesChanged
    self.OnCyclesChanged = function(self, cycles)
        _OnCyclesChanged(self, cycles) -- 原来的
        self.clockrotate2hm(self, {}) -- 触发 空的时候使用self._daysegs2hm
    end
end)
