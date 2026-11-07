# 回归测试

## 可选生存模式与难度查询（2026-11-07）

`python tests/run_survival_difficulty_tests.py` 检查完整配置合法值、默认基准、四级阈值、总开关依赖、逆向档位、旧配置迁移、查询私发、控制台入口和制作解锁边界。测试用 Lua 5.1 运行实际模组源码。

`python tests/run_native_survival_difficulty.py --variant default|base|all|um` 在一次性离线原生专服验证默认关闭、仅开模式总开关、开启全部子项、搭配永不妥协测试版。实际运行请选择一个模式名。覆盖真实物品与动作、旧料理数量保留、护甲、影怪伤害、雨天生火／遮雨、冻结、指令注册与私发目标；返回包在测试进程内截取，未模拟真实客户端网络或界面显示。复用本机已有的隔离测试存档，不访问玩家存档。

## 无名称血量变化来源（2026-11-07）

`python tests/run_health_cause_tests.py` 使用游戏原生命名／血量代码，对照本机原版为爽与已归档的淬炼2.8.15.0.7；需本机 `backups/releases/v2.8.15.0.7-content.zip`。108项检查覆盖取名内部拼接空名称、异常返回值、缺方法及三个血量入口，包含正常伤害和死亡原因。

`python tests/run_native_health_cause.py` 在独立完整淬炼＋妥测专服生成真实无名潮湿来源，验证直接取名仍复现原生错误、经过三个血量入口的转换后不崩溃且扣血正确。只操作独立测试目录，不连接玩家世界。结果见[验证记录](../development/validation/health-cause-20261107.txt)。

## 手部装备空手与串位修复（2026-11-06）

`python tests/run_native_equip_slot_tests.py --variant vanilla|patch|full|disabled` 在独立目录和离线原生服务器中运行 39 组场景。四种模式分别是原版行为对照、仅加载补丁、完整淬炼版默认配置、完整淬炼版关闭简单/困难模式总开关。实际运行时选择其中一个模式名，例如 `--variant patch`。

使用本机游戏的真实角色、装备、物品栏和动作实现，覆盖空手开始连续切换 200 次、重复装备、鼠标交换、临时卸下再装备、手动移位、原格占用、满背包、主动卸下、过期装备动作、装备限制、手柄规则、地面物品及容器来源。原版模式的通过表示成功复现原版行为（包括缺陷），不表示原版没有问题。

新增 `equip_input_fixture.lua` 从原版 `Input → FrontEnd → PlayerHud` 输入入口测试键盘快捷键，从 `InvSlot:OnControl → UseItem` 测试鼠标右键。启动器从本机 `scripts.zip` 提取完整原生函数到临时测试模组，记录函数哈希；不在仓库分发游戏源码。绘图、焦点和通知控件用无头测试对象代替，物品和服务端组件是真实实体。

键盘和右键分别遍历全部 15×15 个格位组合，在空手/已装备、满栏/仅两件物品四种状态下测试；另做键盘、右键、键鼠混用各 1500 次连续切换，以及每隔 1 帧/3 帧的 360 次切换。原生客户端请求和服务端 RPC 排队模拟覆盖 5400 个请求及重复投递；不模拟客户端移动预测或真实网络。还覆盖来源格丢失后使用两类输入换装、快捷键按下/松开、连按、制作修饰键和界面拦截。每种模式累计 3315 个有序格位组合、20322 次按下事件。

默认复制 `work/reuse-audit/config/Audit/Master/save` 中已有的一次性测试存档；可用 `--seed` 指定仓库 `work/` 内其他隔离测试存档。不会修改种子或正式存档。输出保存在 `work/native-equip-slot-<模式>-*/`，含原生日志、`result.json` 和 `native-input-manifest.json`。这不等同于物理键鼠、实际客户端画面或第三方模组组合验收。复现结论见 [修复记录](../development/equip-slot-fix-20261106.txt)。

## 主世界托管暗影空间（2026-11-06）

`python tests/run_shadow_vault_tests.py` 执行原生 Lua 5.1 序列化器、保留的持久化事务协议、托管空间组件与客户端容器布局检查。覆盖来源/目标单一物品归属、预留槽位冲突、取消返还、重复完成拒绝、离线请求、原生引用恢复、损坏引用保留、多人目录消息隔离和旧协同存档交接。`run_exchange_modes_tests.py` 现验证托管配置及旧按钮入口；旧协同恢复仍由 `run_fast_exchange_tests.py` 验证。

`python tests/run_native_shadow_vault.py --shards 4` 在 `work/native-shadow-vault-*` 创建一次性原生服务器集群，自动选择空闲 LAN 端口。会生成物品、保存、停止测试进程；不会写入正式存档。默认验证初次迁入、取出/存入、丢完成确认、关闭副世界后的主世界访问。

后续场景用 `--seed <上次输出目录>/config/Audit` 复制测试存档：`--scenario reload` 检查读档和原生容器代理开关，`rollback` 在洞穴关闭时回档主世界，`cut` 在双边已保存但未发送 RELEASE 时强停，`recover` 检查其恢复及玩家背包存档，`migrate` 检查旧协同存档迁入，`migrate_cut` 在旧协议交接中强停。旧岛屿/火山存档使用 `--shards 4`，自动加载本机已有的 Island Adventures 与对应多层支持模组。仅使用这些脚本产生的隔离存档作为种子。

原生服务器验证包括两个分片、四个分片、实际 Island Adventures 四层旧协同存档及中断升级恢复。它们不等同于真实客户端画面、鼠标点击、手柄操作或任意第三方模组组合的验收。

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

多分片压力测试随 `run_fast_exchange_tests.py` 执行。它在 2、4、7 个分片上各用三个固定随机种子，合计 720 轮，注入丢包、重复与乱序，同时发起同箱争用、独立交换和共同保存。另有定向用例复现丢失上一轮最终确认后立刻开始下一轮保存。

`run_native_exchange_stress.py` 是 Windows 上的无渲染专服对照。传入尚未建立共同检查点的测试集群目录，内含 `Master/Caves`，四层时另有 `Islands/Volcano`。脚本复制存档到 `work/`，通过游戏真实的服务端按钮处理函数交换满箱并逐轮核对物品。四层需要已安装岛屿冒险与核心。例子使用同一份种子和相同 CPU 亲和性，依次运行两种模式。

```powershell
python tests/run_native_exchange_stress.py <测试集群目录> traditional
python tests/run_native_exchange_stress.py <测试集群目录> coordinated --drop-open
python tests/run_native_exchange_stress.py <双层测试集群目录> coordinated --shards 2 --rounds 25 --recover
python tests/run_native_exchange_stress.py <测试集群目录> coordinated --rounds 13 --shutdown
```

`--drop-open` 人为丢弃一次最终确认并立即发起下一轮保存。`--recover` 在完成压力轮次后强制重启最后一层，检查掉线期间禁止交换、共同回档后的原物品及正常关服。`--shutdown` 同时请求所有分片关服，并丢弃发往一个分片的最终确认，验证每个进程都能自行退出。原生对照使用自动操作的服务端测试角色。

`run_native_exchange_travel.py` 启动真实游戏客户端和隔离专服。默认连续跑三圈，每次抵达都检查目的地、背包里的计数金块和已装备的头盔。岛屿冒险组往返地表、海岛、火山与洞穴，执行模组的跨界道具动画和游戏的原生传送。永恒新界组使用实际生成的深渊洞穴，测试洞穴内的深渊传送，并确认深渊拒绝跨界后，角色可以正常发起下一次允许的跨界。深渊拒绝测试记录实际规则调用，跳过处死测试角色的效果以便核对同一份背包。

```powershell
python tests/run_native_exchange_travel.py islands --port 11011
python tests/run_native_exchange_travel.py islands --port 11011 --unrelated-outage
python tests/run_native_exchange_travel.py newconstant --port 11017
```

可用 `--seed` 指定一次性集群目录来跳过生成。脚本会复制存档到 `work/`，必须使用隔离的测试存档。完整路线结束时会先共同保存。复用输出的 `config/Audit` 作为种子，使用同样的 `--cycles` 加 `--verify-restart`，可验证冷启动后角色、背包和装备仍能恢复。`--unrelated-outage` 停止火山分片，验证箱子交换暂停时，地表角色仍可携带背包和装备通过跨界道具抵达海岛，可搭配 `--quick-worthies` 测试岛屿冒险的快速传送选项。永恒新界核心、深渊的安装路径可通过 `--newconstant-mods` 指定，基础模组从本机工坊目录读取。

## 科技建筑配方预览兼容

运行 `python tests/run_prototyper_preview_tests.py`；可用 `--preview-source` 指定本机“群鸟绘卷”的 `scripts/util/entutil.lua`。测试读取其实际 `ClonePrefab` 方法并执行本模组真实建筑挂钩，40 项断言覆盖客户端预览移除、服务器权限、缺失保存表、正常条目清理、重复事件及临时实体。`--source-ref d340da5` 会在灵子分解器客户端预览移除断言失败，复现本次缺陷。

`tests/native/prototyper_private_space_fixture.lua` 用于独立双层测试世界，名称须为 `ShadowWorld isolated private space test`。它生成科技建筑、模拟玩家与测试物品，验证燃料解锁、帽子升级、私人空间绑定及共同保存回档；会修改测试世界并执行回档，不能导入正式玩家存档。

## 眼球炮塔加强

运行 `python tests/run_eyeturret_tests.py`，可在第一个参数提供游戏 `scripts.zip` 路径。271项检查读取原生 `Projectile:Hit`、`Combat:DoAttack`、`Health:SetVal/DoFireDamage`、材料给予动作收集和给予流程；覆盖默认开关、原版与Wathom配方、五段电击链伤、潮湿／电免疫／独立防御、友军与建筑筛选、升级消耗和保存、孢子云定向免疫、隔离火焰、植物电击点燃拦截、冰盾秒杀及原有双护盾。物品状态专项包含背包右键给予、升级保存、原生部署继承、混合升级、重复材料及失败上下文清理。

`tests/native/eyeturret_fixture.lua` 仅用于名为 `ShadowWorld isolated eyeturret test` 的一次性原生服务器。夹具创建、攻击和删除测试实体，验证原生伤害、升级保存、两类孢子云、冰川座狼冰盾和建筑防火，完成后关闭；关闭加强选项时检查原生属性、配方和物品状态。补充原生玩家 `Inventory:UseItemFromInvTile` 及状态机执行给予、材料堆叠消耗、物品保存、`Deployable:Deploy` 继承及放置后的保存。需要本机永不妥协测试版，不能导入真实存档。该测试没有操作实际客户端窗口或检查画面表现。

## 维希独立配置与幽闭兼容

运行 `python tests/run_wixie_tests.py`，需要本机安装正式版 `2039181790` 与测试版 `3193922031`。372项检查读取实际两版维希幽闭算法、原生配置窗口选项构造和保存代码、本模组变速工具；覆盖两侧任务、恐慌、监听保留、独立开关、角色时间线隔离、原有默认系数、弹丸归属、条件显示、隐藏值保存及界面异常后的方法恢复。

`tests/native/wixie_fixture.lua` 仅用于名称为 `ShadowWorld isolated Wixie test` 的隔离世界，会生成角色、生物和护甲，并在验证后关闭。分别配置 `walter=false,wixie=true,walter_easy=false,um_patch=false,["Wixie No Claustrophobia"]=true`，以及相反角色开关、`um_patch=2`、幽闭移除为false。它检查实际共用状态图的并发隔离、Beta网络幽闭值和开启／关闭后的原生表现，不能用于真实玩家存档。

## 怪物角色夜视与沃托姆

运行 `python tests/run_monster_nightvision_tests.py`：423 项检查执行原生夜视、黑暗伤害与伍迪变身函数，风华（3413376081）完整智能夜视模块，以及永不妥协正式／测试版实际夜视函数和回声界面；覆盖沃托克斯黑名单、动态标签、配置同步、复活、视觉来源共存、风华切换／天亮回调、三种变身的显示与保护，以及原有漫漫长夜规则。需要安装上述三种模组；相关实体、网络和绘图为模拟。`tests/native/monster_nightvision_fixture.lua` 仅用于名为 `ShadowWorld isolated monster vision test` 的一次性世界，会生成角色、修改标签与昼夜、实际变身并自动关闭服务器。详见[实装说明](../development/怪物角色夜视与沃托姆兼容.md)。

正式版地表、测试版地表／洞穴和关闭两项开关共四组原生服务器验证通过；追加风华兼容后，四组均再次通过伍迪三形态真实变身、旧式关闭调用、服务端黑暗保护与还原测试。真实客户端画面尚未人工验收。

芜猴／韦伯／鱼妹专项检查覆盖：共用夜视开关、原有角色强化对微光的限制、各漫漫长夜档位、仅服务端创建微光、风华关闭、幽灵／死亡／复活、洞穴、角色移除及重建。昼夜模拟遵循原生 `worldstate` 先通知 `phase`、后更新布尔标志的顺序。

`tests/native/role_nightvision_fixture.lua` 仅用于服务器名为 `ShadowWorld isolated role vision test` 的一次性测试世界。开启简单模式及三人的角色强化，分别测试怪物角色夜视开启时的普通漫漫长夜地表、危险经典地表／洞穴，以及关闭怪物角色夜视的危险经典地表。夹具生成、杀死和移除测试角色，切换昼夜，检查原生光照检测、黑暗伤害启动条件、网络值、理智保留、幽灵视觉与光源清理；洞穴额外关闭／重开实际补光，确认夜视保持时黑暗危险随光源消失／恢复，随后关闭服务器。不能导入正式存档。

角色专项夹具以 `ALL_PASS` 标记成功，危险洞穴额外输出 `LIGHT_SAFETY_CONTROL_PASS`。洞穴的昼夜检查使用原生 `cavephase`，其普通 `phase` 始终为夜晚。

眼球塔兼容新增 `tests/native/newconstant_eyeturret_fixture.lua`，仅用于名为 `ShadowWorld isolated eyeturret compatibility test` 的一次性世界。加载真实永恒新界核心与深渊／Nightmare，关闭随机生物大小以隔离本选项影响；通过真实遗迹刷新器生成两类敌塔，验证属性、保存、共享炮弹与红宝石点燃，真实击杀后确认其仍会正常移除，触发 `resetruins` 后再次检查。测试会生成／删除实体、造成伤害、刷新遗迹并关闭服务器，不能用于玩家存档。

### 眼球塔击毁休养与拆解

`tests/native/eyeturret_recovery_fixture.lua` 仅供名字为 `ShadowWorld isolated eyeturret recovery test` 的一次性独立服务器使用，会生成、击毁、恢复和拆解实体，不能导入玩家存档。搭配完整开发版和永不妥协测试版，关闭独立“随机大小”规则（`Random Sized=false`）以隔离属性断言；分别测试眼球塔加强开启与关闭。通过原生 `ForceKill`、`GetSaveRecord/SpawnSaveRecord`、计时器快进、真实炮弹和 `CASTSPELL` 检验死亡不移除、不掉落、父眼球透明／独立底座保留、恢复满血和升级攻击，以及正常／休养／背包物品落地后的拆解返还。快进只发生在独立测试世界，测试不会等待现实40分钟。无渲染服务器检查动画透明度和底座可见状态，未操作实际客户端验收皮肤画面和鼠标点选。

眼球过渡专项：0.6秒淡出、0.8秒淡入，并验证中间透明度与完成端点、颜色保留、淡入中再次击毁、重复死亡不重播、读档直接恢复状态及拆解时清理任务。原生休养夹具新增 `FADE_OUT_PASS` / `FADE_IN_PASS` 标记；继续验证完整死亡、保存、恢复和拆解流程。


弹弓热修补充实际 `Class`、`State`、`TimeEvent`、`StateGraphInstance:HandleEvents`，覆盖蓄力／普通／特殊射击中 `locomote` 和图级事件；旧版会复现 `stategraph.lua:465` 的缺失 `HandleEvent`。权限测试使用原生服务端与客户端装备限制代码、两版永不妥协蓄力判定，验证开关独立性和出生路径。

`tests/native/wixie_slingshot_hotfix_fixture.lua` 仅用于名为 `ShadowWorld isolated slingshot hotfix test` 的隔离世界，实际生成沃尔特、维希及六种弹弓，执行库存装备、缓冲事件与异步状态更新，完成后关闭测试服；不得导入玩家存档。

`tests/run_propagator_tests.py` 使用游戏原生传热组件和永不妥协正式／测试版的实际包装函数，复现失效实体在 `OnRemoveFromEntity → OnUpdate(0)` 中传入空坐标的崩溃。验证修复后定时任务仍被取消、正常传热和融冰通知仍执行、永不妥协冬季范围在调用后恢复。`tests/native/propagator_cleanup_fixture.lua` 在上述隔离世界中回放移除常青树后的组件清理及完整燃烧延迟回调。

`tests/native/walter_special_shot_fixture.lua` 检查原生铥矿弹弓的动作收集、本机 `OnLeftClick`、远程 `OnRemoteLeftClick`、第二弹药格及实际弹丸生成。能力勋章环境还覆盖童真勋章、落水弹，以及铥矿框架／附身皮筋／果冻手柄。加载永不妥协时同样执行完整射击测试。无图形测试只提供瞄准线数据与视觉取消回调，不代表已完成实际客户端鼠标、画面及本地辅助模组验收；这些检查通过也不能据此认定玩家报告的问题已修复。

`tests/native/walter_charge_fixture.lua` 仅用于上述隔离弹弓世界，验证真实废料框架及其升级版的蓄力、松键发射、取消与卸下清理，安装猪皮皮筋和黏糊手柄以避免附身皮筋随机节省弹药干扰消耗断言。启用永不妥协后，还通过远程右键动作检查沃尔特（开关开启时）与维希的原始／犬牙／玛蒂尔达弹弓，提供等同于鼠标坐标 RPC 的瞄准数据并验证实际施法及弹药消耗。`run_wixie_tests.py` 另覆盖服务器／预测客户端的状态分流、预测状态匹配、继承方法，以及两版永不妥协的装备和普通攻击权限。

## 暗影空间跨界与暂存转交

2.8.15.0.5 已发布的原生容器重构使用各模组注册的真实容器 prefab，通过原生 `container_proxy`、物品格与容器 RPC 存取。该版仅切换所属世界时交接整页；同层玩家可共享，同一页不能在不同层同时修改。`shadow_vault_native_regression.lua` 覆盖空间类型隔离、原生单例注册保护、过期所属世界消息、私人帽子切换，以及妥协启动清理保留合法独立页。旧存取协议和日志保留用于升级恢复，旧手绘面板不再加载。下文的旧故障测试属于恢复协议历史覆盖，不代表本次进行了突然崩溃或断网实测。

2026-11-07 后续本地改动允许暗影／钓具空间跨层同时打开。主世界保管真实物品，远端使用相同原生 prefab 的非持久显示容器，存取经独立日志逐项确认。原生界面、物品格和预测交互继续使用；显示副本禁止参与制作，材料需要先取出。云青松等特殊容器保留整页交接以继续使用模组原有容量／升级管理。`shadow_vault_shared_regression.lua` 覆盖稳定物品实体、更新耐久／打包数据、排队时的格子标识、会话隔离、计数与交换编码及重复视图限频；`shadow_vault_shared_hooks_regression.lua` 验证显示副本及嵌套容器不能通过普通 RPC 被取走。

`python tests/run_nexus_shared_native.py` 使用隔离四层游戏专服，验证同时打开、争抢同一叠物品、洞穴先取、指定数量取出／逐个放入、不同格并行及正常保存重启。`python tests/run_nexus_shared_client.py 4 work/nexus-shared-client.json` 驱动隔离真实客户端往返，验证原生格位、礼盒图标及内容、拆叠合堆交换、快捷存取、耐久及附身帽私人空间。需要本机 DST 和现有测试种子，客户端用例串行运行。`run_nexus_armour_client.py` 在同样客户端中增加真实巨兽微光及消退验证；动态减伤数学回归仍由 `run_dynamic_armor_tests.py` 执行。结果见[共享空间验证记录](../development/validation/nexus-shared-20261107.txt)，未公开发布。

随后合入咸鱼动态减伤调参。合并时 `run_dynamic_armor_tests.py` 为 176 项，覆盖 20% 起点／30% 上限、每秒 400 点保底和较高血量时的比例衰减、跨阈值拆分不变性、旧存档、长时间更新与阶段继承；战斗险境联动为 109 项。`run_nexus_armour_client.py 1 work/xianyu-dynamic-armour-client.json` 通过实际巨鹿生命组件验证连续三次扣血与 400 点保底，再检查客户端微光和清除。完整状态见[合并验证记录](../development/validation/xianyu-dynamic-armor-20261107.txt)。

2026-11-07 后续修复：`run_dynamic_armor_tests.py` 为 190 项，新增停手 1 秒后启用 400 点保底、受击期间继续比例衰减、缓冲保存／读取／长时间更新和零伤害不续期。`run_combat_progressive_tests.py` 为 129 项，验证普通 10 倍放宽到 3.75 倍、实际报告显示 W=1.5，以及旧默认 1 档迁移、全新配置采用 4／dynamic，显式传统 1 档使用独立标记且仍运行旧算法。`run_wixie_tests.py` 为 705 项，另使用原生配置界面构造和收集函数验证手动选择三轮保存／重新打开后保留。

`python tests/run_combat_shade_native.py --edition none|stable|beta --label validated` 使用现有本机游戏和已安装妥协，在独立、冻结输入的单层专服中验证三种环境；串行运行，不连接或修改玩家世界。包含三种真实 Boss 的连续扣血、熊獾 50 次间隔攻击、原生 CalcDamage、真实骑牛／下牛、眼球伞乳制品修复资格、雨水回复／酸雨限制与原生物品保存读取。树荫等级切换通过原生 Sheltered 输入复现，不代表实际客户端走位或画面验收。结果保存在 `work/combat-shade-<edition>-validated.json`。

`--um-eyebrella` 在启动时开启妥协自身眼球伞改动；`--legacy-defaults` 用旧 `combat=1,epic_armor_5=1` 配置启动，验证实际运行时仍加载新机制。两种设置可分别配合不同 `--label` 保留报告；最新夹具还实际消耗羊奶检验眼球伞修复。

`run_shadow_vault_tests.py` 覆盖后台暂存转交、重复和乱序到达记录、恢复失败保留原件及混合时点存档的物品守恒。`run_vault_native_only.py --case native enabled blackhole full inflight save crash source_restart four` 使用真实 DST 专服隔离副本，验证完全丢模组消息时原生跨界、满背包反复跨界、未完成存取、保存相撞、崩溃重启与四层通信故障。脚本角色使用迁移档案桥接，不能代替真实客户端验证。

`run_vault_client_travel.py --blackhole` 另外启动隔离的真实游戏客户端，自动加入和选角，在丢弃模组消息期间完成 6 次原生客户端跨界。每次抵达核对 17 个金子和控制器启用状态；不包含人工键鼠或所有第三方门户验收。以上原生测试需要本机游戏及现有隔离种子，应串行执行以避免端口冲突。

`summarize_vault_native_only.py` 汇总冻结输入、用例报告、当前核心文件哈希及版本差异，见[原生跨界与后台转交报告](../development/validation/vault-native-only-20261106.txt)。`run_vault_travel_priority.py`、`summarize_vault_travel.py` 及更早的 no-save 报告属于历史版本；其中“等确认、20 秒后取消跨界”的行为已经移除。


2026-11-07 空间锁定回归：`run_weapon_infusion_view_tests.py` 验证注能显示更新不移动或删除物品（44 项）；`run_vault_journal_tests.py` 附加 `shadow_vault_capture_recovery.lua`（20 项）。`run_vault_archive_recovery.py --archive <tar.gz> --verify` 在只读输入包的独立双层副本中复现／恢复旧交易，并保存重启两轮。`run_vault_item_compatibility.py` 使用本机妥协测试版、棱镜和能力勋章，检查异常物品提前拒绝、真实物品跨层往返、礼盒内模组物品、耐久及安全自动重试。两种原生入口须串行运行，避免启动前空闲端口选择发生竞争。详见 `development/validation/vault-capture-recovery-20261107.txt`。
2026-11-07 崩溃入口排查：`audit_lua_globals.py` 编译全部源码并清点 SETGLOBAL；`run_gem_staff_tests.py` 使用本机原生绿杖和 Gem Core 回调检验包装／不透明替换；`run_crash_audit_tests.py` 检验参数边界、字面搜索、火炉空产出保留、多人计时器、风暴节点与延迟实体检查。`run_native_gem_staff.py --smoke --mods ...` 在隔离专服中检查实体、RPC、火炉和正常保存；`--wrap-green` 添加构造函数包装，空的 `--mods` 表示只开淬炼。原生入口串行运行。详见 `development/validation/crash-audit-20261107.txt`。


2026-11-07 三档穿越与强制默认迁移：`run_exchange_variants_tests.py` 编译当前全部 Lua 并执行 48 项专项检查；`run_exchange_variants_native.py` 在隔离双层原生专服中检查原版双向交换、咸鱼拆叠存取、三档库存与配置的保存重启。

`run_vault_zip_recovery.py --archive <zip> --legacy-fixture --migration` 用反馈包的只读隔离副本检查旧默认自动迁移及重启；不带 `--migration` 时显式选第三档，继续测试枢纽原有恢复。`run_exchange_migrated_roundtrip.py --seed <isolated cluster>` 检查迁移后再选枢纽不会重复导入旧日志，切回原版后库存一致。`summarize_exchange_variants.py` 汇总冻结输入报告；详细范围见 `development/validation/exchange-variants-20261107.txt`。
