# IA 存档白天偶发滤镜异常排查

2026-11-11。输入：`D:\Users\Yucca\Downloads\DSTCamp_存档_IA_20261111_110227.zip` 与用户提供的暂停截图。

结论：尚未定位到具体责任模组。夜视状态或显示色表在天亮时未正常恢复，是与反馈相符的重点方向；截图本身不足以确认正在使用 `mole_vision_off_cc.tex`。未改正式存档和玩法代码，未发布工坊更新。

## 存档提供的新证据

- 包含 Master、Caves、Shipwrecked、Hamlet 分片及历史服务端日志，没有 `client_log.txt`，也没有 DayVisionAudit 的客户端输出。
- Master 日志游戏版本为 762172，淬炼为 2.8.15.0.22。当前配置启用 43 个服务端模组。
- Master 的玩家快照 170–174，以及 Caves 的 165，角色均为 WX-78，均安装 `wx78module_nightvision`。最新 Master 玩家快照为 174；世界最新快照为 175，不能把两者当成同一瞬间。
- 最新玩家快照激活 `wx78_circuitry_betabuffs_1`，该技能让原生芯片夜视不改变色表。
- 最新装备为 dreadstonehat、armordreadstone、um_moonfly_lantern、armorslurper、buci_silksack_max；保存时没有戴鼹鼠帽。这不等于异常发生时没有其他装备或临时效果。
- 配置中 `Monster Night Vision=false`、`wathom nightvision=false`、`dusk_change=false`；全能力的 `wx78_recipes=false`；机械飞升的 `night_main=false`；UM 的 `wx78=false`。不能因为其中仍有细项为 true，就认定对应整段功能运行。
- 所检查日志未找到能直接解释该视觉异常的调用栈。11 月 8 日的 IA 伍迪／鱼妹初始化报错与当前白天滤镜反馈没有直接因果证据。

## 源码核对

原生 `scripts/components/playervision.lua`：当夜视仍开启，且 `nonightvisioncc=false`、没有更高优先级自定义表时，白天确实使用 `images/colour_cubes/mole_vision_off_cc.tex`。该组件不通过 OnSave 保存视觉字段，服务端玩家存档不能提供异常时本机来源栈和实际渲染色表。

原生 `scripts/wx78_moduledefs.lua:526` 的 OnNightVisionUpdate：仅在非满月夜晚推入芯片来源，其余时间 Pop；启用上述技能时传入 `nonightvisioncc=true`。单凭“装有光电芯片”无法解释白天残留。

淬炼 `content/common/monster_nightvision.lua`：资格开关关闭时仍安装全角色视觉兼容包装，故不能仅凭开关为 false 完全排除它参与调用链。不过下面的离线检查未复现残留。

额外下载并检查更多物品 6.0.6.1、更好的诅咒物品 26.09.26、Shared Talents 0.3.8、DST Sodium、Performance Pack、DontStarveLuaJit2、The Winterlands 1.4.10 的 Lua 源码，并核对已有全能力、机械飞升、12 格电路槽、IA、UM 源码。下载当前版本不代表拥有反馈现场的完整客户端文件和加载状态。

- 更多物品存在旧的“禁用客户端夜视”包装，但 modtuning 中已显式关闭该功能；不能把磁盘中存在的旧文件当成正在运行的原因。超级鳄梨酱视觉功能也未开启。
- 机械飞升光电扩展受 `night_main` 总开关控制，本存档为 false。
- The Winterlands 会直接发 `ccoverrides`，并包装 `PostProcessor:SetColourCubeData` 转换极地区域配色；因此只看 `playervision.currentcctable` 可能漏掉实际覆盖。当前没有证据证明它造成截图异常。
- IA 会扩展 colourcube 的季节色表；没有发现直接将普通 WX-78 白天固定为鼹鼠色表的代码。

## 本次验证

`work/filter-audit-20261111/check_native_dawn.py` 执行本机游戏包的真实 PlayerVision 和 OnNightVisionUpdate；使用存档夜视相关设置、已点亮的无色表技能，覆盖主机／客户端和有／无淬炼包装。实体、时间及网络用测试桩模拟。

800 个昼夜周期、2408 项断言通过：白天来源栈为空、HasNightVision=false、GetCCTable=nil。另有明确标为人工注入的 legacy ForceNightVision 请求，用于验证未释放请求会产生鼹鼠白天色表这一诊断特征，不是对原存档偶发问题的复现。

未运行该 43 模组组合的图形客户端，没有复现用户截图；以上不能作为完整兼容性或实机画面验收。

## 下一次复现的取证

本地客户端诊断模组 `client_mods/day_vision_audit` 更新为 1.1；运行 `client_mods/tests/run_day_vision_audit_tests.py`，21 项检查通过。记录原方法及调用位置、夜视来源、装备夜视标签、技能与芯片状态、实际 colourcube 调试信息、直接发出的 ccoverrides／ccphasefn／setinpolar 与世界色表覆盖事件。保持原方法返回值，日志错误不阻止原游戏调用。

诊断包：`work/filter-audit-20261111/白天滤镜诊断_1.1.zip`。只需发生问题的玩家安装启用，服务器不需要安装。出现异常后保留当次 `client_log.txt`，再次启动前备份；这是继续定位具体调用者所缺的关键记录。日志不自动上传。

仍有边界：直接调用 PostProcessor 等底层接口的全部行为不会被逐条拦截。若组件状态全部正常而画面仍异常，应结合色表调试信息与客户端模组列表检查渲染层，而不能通过清空所有夜视来冒充定位。
