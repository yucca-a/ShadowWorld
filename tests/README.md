# 回归测试

这些测试通过 Python 的 Lupa Lua 5.1 运行模组代码，并从本机正版游戏的 `data/databundles/scripts.zip` 读取所需原生 Lua 实现。实体和引擎行为有模拟部分，不能替代多人联机或游戏内完整验证。

依赖：Python、`lupa==2.8`。可使用虚拟环境，或在仓库根目录安装到已忽略的本地目录：

```powershell
python -m pip install --target work/test-python lupa==2.8
```

各入口均支持将游戏脚本压缩包路径作为第一个参数：

```powershell
$dstScripts = "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
python tests/run_dynamic_armor_tests.py $dstScripts
python tests/run_combat_progressive_tests.py $dstScripts
python tests/run_skilltree_tests.py $dstScripts
python tests/run_wanda_regen_tests.py $dstScripts
python tests/run_frostjaw_tests.py $dstScripts
python tests/run_mod_viewer_tests.py $dstScripts
python tests/run_world_exchange_tests.py $dstScripts
```

请按实际游戏安装位置修改路径。游戏更新可能使原生源码发生变化，此时需要重新检查测试提取位置与实际行为。游戏的 `scripts.zip` 和测试依赖不随仓库上传。

在 2.8.14.96 开发验证中，前五组分别通过 118、105、138、144、590 项断言，共 **1095 项**。战斗险境与动态装甲还完成过隔离专用服务器验证。2.8.14.96.1 仅修改名称、简介和版本号；本次建仓核验版本文件完整性，未重复运行玩法测试。

2026-11-03 新增模组查看器回归测试，**58 项断言通过**：覆盖离线 HUD/选人界面、当前世界配置、在线配置优先级、数据缺失、显示/隐藏偏好及专用服务器隔离。读取游戏原生配置查询与界面选项解析代码，网络和绘图使用模拟对象；实际离线存档的图标显示仍需游戏内验收。通过 `--source-ref v2.8.14.96.1` 可对旧版运行同一测试，旧版会在离线界面加载断言失败。

2026-11-03 新增穿越世界回归测试，**574 项断言通过**（事务协议 515、引擎适配 59）。覆盖延迟、丢包、重复/乱序消息、双方同时点击、断线重连、不同阶段重启、旧消息重放、分包限额、保存回调、容器锁与恢复失败。适配层使用本机原生 Class、DataDumper、RunInSandboxSafe；实体和网络仍由测试桩模拟。输出中三条 `WorldExchange2hm` 错误来自主动注入的恢复失败，属于预期测试。

另已运行独立地面/洞穴专用服务器，验证正常整箱交换，以及两个存档阶段强制结束进程后的恢复；恢复时同时注入 2 秒消息延迟和一次最终确认丢失。详细结果及限制见 [穿越世界实装说明](../development/穿越世界事务机制_实装说明.md)。正式玩家世界未用于这些自动测试，容器按钮的真实玩家交互还需本地验收。
