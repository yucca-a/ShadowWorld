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

同日速度优化后，穿越世界测试增至 **590 项断言**（协议 518、适配 72），覆盖下一帧唤醒、防重入、合并事件、共享发送额度、确认优先和重复状态抑制。`tests/native/world_exchange_speed_fixture.lua` 是独立专用服务器基准夹具：只在一次性测试世界的测试模组中导入，会清空并填充暗影空间测试箱、连续交换三轮并关闭服务器；不得放入正式存档。它不属于 `content/`，不会随模组发布。

## 即时交换实验

以下是研发原型，**没有启用正式功能，也没有完整的原生检查点控制器**。

```powershell
python tests/run_instant_exchange_tests.py
python tests/build_instant_probes.py
```

第一条命令只需要 Lupa，不读取游戏脚本压缩包；目前通过 260 项协议／状态模型断言、80 项复用的物品检查和 35 项备份存储检查。测试包含主动证明单层回档不安全的反例，不能把全部测试通过理解为免存档方案已可正式使用。

第二条命令仅在 `work/instant-exchange-probes/` 生成 `speed` 与 `checkpoint` 两套独立试验文件，不安装、不启动游戏。每套文件只能复制到装有当前 `content/` 的一次性测试模组，并在该测试模组末尾导入 `exchange_runtime_diagnostic.lua`。测试服务器名称必须为 `ShadowWorld isolated exchange test`；这一名称检查只是防止误用，不能替代专门的临时存档隔离。

- `speed`：沿用原有三轮测速夹具，但替换为快速协议和始终允许交换的检查点替身。三轮约 0.43 秒的结果只覆盖正常传输，不证明崩溃安全。
- `checkpoint`：会生成模拟玩家，覆盖测试世界状态，并删除明确记录的原始快照文件。第一次启动必须等待**两层**都输出 `READY_FOR_COLD_RESTART`，然后强制结束这两个测试进程，不执行退出保存；第二次启动应在两层看到 `VERIFIED_WORLD_AND_PLAYER`。成功后夹具自行退出。固定试验键会保留在临时存档中，复跑应使用新的隔离存档。

原生恢复试验覆盖的是受控的世界状态和每层一个模拟玩家背包，不覆盖实际联网玩家、迁移、自动协调回档或任意阶段断电。具体发现及尚未完成的接入条件见 [即时交换实验进度](../development/穿越世界即时交换_实验进度.md)。
