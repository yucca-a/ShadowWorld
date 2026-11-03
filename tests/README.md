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

以下保留早期研发原型的复现方式；它们本身不属于正式控制器。后续正式接入的验证见下节“快速版实装回归”。

```powershell
python tests/run_instant_exchange_tests.py
python tests/build_instant_probes.py
```

第一条命令只需要 Lupa，不读取游戏脚本压缩包；目前通过 260 项协议／状态模型断言、80 项复用的物品检查和 35 项备份存储检查。测试包含主动证明单层回档不安全的反例，不能把全部测试通过理解为免存档方案已可正式使用。

第二条命令仅在 `work/instant-exchange-probes/` 生成 `speed` 与 `checkpoint` 两套独立试验文件，不安装、不启动游戏。每套文件只能复制到装有当前 `content/` 的一次性测试模组，并在该测试模组末尾导入 `exchange_runtime_diagnostic.lua`。测试服务器名称必须为 `ShadowWorld isolated exchange test`；这一名称检查只是防止误用，不能替代专门的临时存档隔离。

- `speed`：沿用原有三轮测速夹具，但替换为快速协议和始终允许交换的检查点替身。三轮约 0.43 秒的结果只覆盖正常传输，不证明崩溃安全。
- `checkpoint`：会生成模拟玩家，覆盖测试世界状态，并删除明确记录的原始快照文件。第一次启动必须等待**两层**都输出 `READY_FOR_COLD_RESTART`，然后强制结束这两个测试进程，不执行退出保存；第二次启动应在两层看到 `VERIFIED_WORLD_AND_PLAYER`。成功后夹具自行退出。固定试验键会保留在临时存档中，复跑应使用新的隔离存档。

原生恢复试验覆盖的是受控的世界状态和每层一个模拟玩家背包，不覆盖实际联网玩家、迁移、自动协调回档或任意阶段断电。具体发现及尚未完成的接入条件见 [即时交换实验进度](../development/穿越世界即时交换_实验进度.md)。

## 快速版实装回归

```powershell
python tests/run_world_exchange_tests.py $dstScripts
python tests/run_fast_exchange_tests.py $dstScripts
```

当前分别通过 **593**（518＋75）和 **117** 项断言。新增覆盖：连续 20 次穿越零世界保存、各类检查点消息丢失／重复、保存期间排空在途交换、检查点各阶段中断、原生保存先于备份提交的窗口、单层重启、手动共同回档、提交清单损坏、玩家原状态／空记录、迁移归属与旧确认、冻结后的玩家记录不可变、暂停时墙钟推进、双方先后退出、对端离线时退出及退出后的重复保存抑制。日志中的主动恢复失败来自故障注入。

```powershell
python tests/build_fast_exchange_probes.py speed --run-id local_speed
python tests/build_fast_exchange_probes.py crash --run-id local_crash
python tests/build_fast_exchange_probes.py savecrash --run-id local_savecrash
python tests/build_fast_exchange_probes.py exit --run-id local_exit
```

生成文件仅位于 `work/fast-exchange-probes/`，不会安装或启动游戏。复制到**一次性独立测试模组**并在末尾导入 `exchange_runtime_diagnostic.lua`；服务器名称使用 `ShadowWorld isolated exchange test`。必须使用独立存档与端口，绝不能导入玩家世界。

- `speed`：等待真实共同检查点开放后交换三轮，验证每轮世界保存计数不变，输出 `ELAPSED_MS`、`NO_WORLD_SAVE` 和双方 `ROUND_PASS`。
- `crash`：两层都输出 `READY_KILL_CAVES_ONLY` 后，只强制关闭洞穴进程。重启洞穴，保留原地面进程让控制器自行恢复；两层均应输出 `VERIFIED ... crash`。夹具会清空测试箱、生成模拟玩家、修改背包并覆盖原生玩家文件。
- `exit`：第一轮自动请求正常保存退出；使用同一生成文件再次启动，两层均应输出 `VERIFIED ... exit`。
- `savecrash`：在已完成交换后请求共同保存，夹具故意停在洞穴原生保存完成、独立备份尚未提交的位置。看到 `NATIVE_SAVED_WITHOUT_COMMITTED_BACKUP` 后只关闭洞穴再重启，双方应输出 `VERIFIED ... savecrash`，并恢复上一共同检查点。

同一 `run-id` 用于一组准备＋恢复；重做独立测试时换新 ID，以免复用阶段标记或模拟玩家。夹具成功后请求关闭测试服；若一层已关闭导致另一层静态任务暂停，应在核对 `VERIFIED` 后只结束剩余的测试进程。

原生验证结果与未覆盖的真实客户端场景见 [快速版实装说明](../development/穿越世界快速版_实装说明.md)。

2026-11-03 回档启动修复增加 `fast_rollback_regression.lua`，随 `run_fast_exchange_tests.py` 运行，另通过 **29 项**检查：安装前原生回档、归档读回失败、玩家归属清理、时间线握手隔离、提交后中断恢复、废弃编号跳转及旧版无跳转记录的兼容、原生快照与元数据恢复顺序、暂停时专用 RPC 通道和写入排空。

`tests/native/world_exchange_rollback_fixture.lua` 仅用于**完整隔离的玩家存档副本**，服务器名必须为 `ShadowWorld isolated rollback copy`。保留原有模组、选项和分片 ID；在测试模组末尾导入夹具。它先验证安装前回档恢复到旧天数，再覆盖测试箱、交换、共同保存，并依次调用原生 `c_rollback(1)`、`c_rollback(1)`、`c_rollback(2)`、`c_rollback(4)`。每轮验证共同检查点、箱内数量及交换期间零世界保存，全部通过后输出 `ALL_ROLLBACKS_PASS` 并关闭。它会修改副本和箱内物品，不能导入正式存档。固定阶段键不可复用到另一轮测试。

回档控制恢复优化后，协议／适配检查为 **518＋77**，快速协议／检查点为 **126**，回档专项为 **39**，合计 **760**。新增提前通知的来源、目标及重复校验、并行恢复的一致性、写入排空和控制锁释放检查。原生夹具输出 `CONTROLS_READY_MS`，统计加载后控制门控等待；首次冷启动应剔除，后四次对应回档。相同存档副本与模组配置的旧／新版对照结果见[控制恢复优化记录](../development/穿越世界回档控制恢复_优化记录.md)。

## 科技建筑配方预览兼容

运行 `python tests/run_prototyper_preview_tests.py`；可用 `--preview-source` 指定本机“群鸟绘卷”的 `scripts/util/entutil.lua`。测试读取其实际 `ClonePrefab` 方法并执行本模组真实建筑挂钩，40 项断言覆盖客户端预览移除、服务器权限、缺失保存表、正常条目清理、重复事件及临时实体。`--source-ref d340da5` 会在灵子分解器客户端预览移除断言失败，复现本次缺陷。

`tests/native/prototyper_private_space_fixture.lua` 用于独立双层测试世界，名称须为 `ShadowWorld isolated private space test`。它生成科技建筑、模拟玩家与测试物品，验证燃料解锁、帽子升级、私人空间绑定及共同保存回档；会修改测试世界并执行回档，不能导入正式玩家存档。

## 眼球炮塔加强

运行 `python tests/run_eyeturret_tests.py`，可在第一个参数提供游戏 `scripts.zip` 路径。115项检查读取原生 `Projectile:Hit`、`Combat:DoAttack`、`Health:SetVal/DoFireDamage`、材料给予动作收集和给予流程；覆盖默认开关、原版与Wathom配方、五段电击链伤、潮湿／电免疫／独立防御、友军与建筑筛选、升级消耗和保存、孢子云定向免疫、隔离火焰、植物电击点燃拦截、冰盾秒杀及原有双护盾。物品状态专项包含背包右键给予、升级保存、原生部署继承、混合升级、重复材料及失败上下文清理。

`tests/native/eyeturret_fixture.lua` 仅用于名为 `ShadowWorld isolated eyeturret test` 的一次性原生服务器。夹具创建、攻击和删除测试实体，验证原生伤害、升级保存、两类孢子云、冰川座狼冰盾和建筑防火，完成后关闭；关闭加强选项时检查原生属性、配方和物品状态。补充原生玩家 `Inventory:UseItemFromInvTile` 及状态机执行给予、材料堆叠消耗、物品保存、`Deployable:Deploy` 继承及放置后的保存。需要本机永不妥协测试版，不能导入真实存档。该测试没有操作实际客户端窗口或检查画面表现。

## 维希独立配置与幽闭兼容

运行 `python tests/run_wixie_tests.py`，需要本机安装正式版 `2039181790` 与测试版 `3193922031`。268项检查读取实际两版维希幽闭算法、原生配置窗口选项构造和保存代码、本模组变速工具；覆盖两侧任务、恐慌、监听保留、独立开关、角色时间线隔离、原有默认系数、弹丸归属、条件显示、隐藏值保存及界面异常后的方法恢复。

`tests/native/wixie_fixture.lua` 仅用于名称为 `ShadowWorld isolated Wixie test` 的隔离世界，会生成角色、生物和护甲，并在验证后关闭。分别配置 `walter=false,wixie=true,walter_easy=false,um_patch=false,["Wixie No Claustrophobia"]=true`，以及相反角色开关、`um_patch=2`、幽闭移除为false。它检查实际共用状态图的并发隔离、Beta网络幽闭值和开启／关闭后的原生表现，不能用于真实玩家存档。
