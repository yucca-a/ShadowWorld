"""Summarize native-only migration tests and retain exact frozen-source provenance."""
from pathlib import Path
import hashlib,json,statistics

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'development/validation'
FILES=[
    'content/easy_other/shadowvaultsnapshot.lua',
    'content/scripts/components/shadowvault2hm.lua',
    'content/scripts/shadowvaultcourier2hm.lua',
    'content/scripts/shadowvaultmovement2hm.lua',
    'content/scripts/shadowvaultsnapshot2hm.lua',
    'content/scripts/shadowvaultsnapshotcore2hm.lua',
    'content/scripts/shadowvaulttransport2hm.lua',
]
manifest={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in FILES}
def differences(cluster):
    old=json.loads((Path(cluster)/'input-manifest.json').read_text(encoding='utf-8'))
    old={k.replace('\\','/'):v for k,v in old.items()}
    return [p for p,v in manifest.items() if old.get(p.removeprefix('content/'))!=v]
latest={}
for name in ['vault-native-only-main-20261106.json','vault-native-only-final-20261106.json',
             'vault-native-only-recovery-final-20261106.json','vault-native-only-four-final-20261106.json']:
    for row in json.loads((OUT/name).read_text(encoding='utf-8')):
        assert row['status']=='passed'
        assert row['checks'] and all(c['conserved'] for c in row['checks'])
        assert all(t['departure_seconds']<2 for t in row['travel'])
        latest[row['case']]=dict(row,report=name,source_differences_from_current=differences(row['cluster']))
assert set(latest)=={'blackhole','full','inflight','save','crash','source_restart','four'}
assert not latest['four']['source_differences_from_current']
client_name='vault-native-only-real-client-20261106.json'
client=json.loads((OUT/client_name).read_text(encoding='utf-8'))
assert client['status']=='passed' and client['blackhole'] and client['arrivals']==list(range(7))
client['source_differences_from_current']=differences(client['cluster'])
client['report']=client_name
timings=[t['departure_seconds'] for t in latest['blackhole']['travel']]
native=next(r for r in json.loads((OUT/'vault-travel-priority-20261106.json').read_text(encoding='utf-8')) if r['case']=='native')
assert native['status']=='passed'
off=[t['departure_seconds'] for t in native['travel']]
saves={n:s['saves'] for n,s in latest['blackhole']['checks'][0]['state'].items()}
assert all(n==1 for n in saves.values()),'only the one baseline save occurred across all six trips'
summary={
    'status':'tested_locally_not_published','native_build':761239,'source_sha256':manifest,
    'character_permission_rpc':False,'character_ack_timeout':False,
    'native_blackhole_departure_seconds':timings,'native_blackhole_median_seconds':statistics.median(timings),
    'historical_disabled_comparison_seconds':off,'historical_disabled_comparison_cluster':native['cluster'],
    'world_saves_after_baseline_and_six_blackhole_trips':saves,
    'cases':{k:{f:r[f] for f in ['status','report','cluster','source_differences_from_current']} for k,r in sorted(latest.items())},
    'real_client':client,
}
(OUT/'vault-native-only-20261106-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=[
    '暗影空间：原生角色跨界、后台物资交接（2026-11-06）',
    '状态：本地实现及下列测试通过，未发布工坊。原生 DST 761239。',
    '',
    '行为改变',
    '1. 删除角色跨界前的 REQUEST / GRANT / DENY 流程及 20 秒取消期限。',
    '   不再重写 worldmigrator.Activate 或拦住 ms_playerdespawnandmigrate。',
    '   仅监听目的地，并给原生玩家档案附加本地迁移记录；原生序列化立即执行，不等远端或本地登记回调。',
    '   角色传送动作、淡出、控制器、移除及 StartMigration 均由原生流程处理。',
    '   仓库连接状态也不再设置原生 SetSecondaryLoading；目标层是否能进入仍由游戏决定。',
    '2. 满背包暂存不再随玩家档案搬运。物品保留在原层暂存容器，随后交给原生物品迁移事务。',
    '   未完成存取先在原端完成，再按玩家离开时记录的去向转交；玩家继续跨界也不必等它。',
    '   旧版玩家档案里的暂存包裹仍能接收，重复包裹与恢复失败原件仍保留相应防护。',
    '3. 原生物品迁移也不再等待模组许可；由原生事务负责接收、重试和完成确认。',
    '4. 存取和角色跨界本身不触发 c_save / ms_save / SaveGame。',
    '   原生本来就需要的玩家档案序列化保留；第一次身份登记属于后台元数据写入，不是整档保存。',
    '',
    '防刷吞校验放在哪里',
    '每个来源进程与目的地形成连续编号流。到达端记录连续前缀与乱序缺口，重复到达不增加计数。',
    '只有普通游戏保存发生时，才对比各层恢复副本中的出发与到达记录。缺出发、缺到达或存在缺口的组合不提交。',
    '这样“来源保存于跨界前、目的地保存于跨界后”的副本组合不会被当成有效恢复点。',
    '不一致时丢弃本轮准备结果，保留原本的保存请求，待迁移记录变化后再捕获；不因等不到到达而反复整档写盘。',
    '角色跨界不等这个校验。模组通信故障可能推迟存取完成和新的一致恢复点，而不是取消角色跨界。',
    '正常完成的编号流压缩成计数器，乱序缺口消除后删除；按进程启动/目的地保留，不按每次角色跨界无限追加回执。',
    '',
    '原生服务器与客户端验证',
    '两层所有仓库传输消息丢失：连续 6 次角色跨界成功，17 个测试金子守恒，恢复通信保存重启后仍为 17。',
    '请求至原生离开耗时（秒，含原生淡出及测试探针采样）：'+str(timings),
    '较早关闭机制的原生对照（同样 6 次，不代表重新跑了旧源码）：'+str(off),
    '两者均约 0.53～0.57 秒；小样本不能推导所有服务器总加载耗时或性能。',
    '这 6 次跨界期间，各层只有初始化测试用的 1 次基准保存，没有新增世界保存：'+str(saves),
    '满背包：模组断信下跨界并通过原生后台转交，满包再返回、保存重启、腾位置，最终只交付一次。',
    '存取未完成：只屏蔽存取协议，先原生跨界，再恢复通信；17 个金子到达目的地玩家，双方 pending=0，重启仍为 17。',
    '保存相撞：来源冻结、主层已准备时仍可跨界；旧组合校验不一致后重做正常保存，重启数量一致。',
    '故障恢复：断信跨界后整服强停、来源层单独强停，均恢复到一致数量 17。',
    '四层：Layer4 离线且其他层模组消息全丢，Caves → Layer3 → Master → Caves 均成功；其余层先保存，再让 Layer4 重连并保存重启，数量一致。',
    '真实游戏客户端：模组断信期间 6 次原生跨界，7 次到达检查逐一核对金子 17 及控制器启用，最后恢复通信完成保存。',
    '真实客户端使用隔离目录、自动加入/选角；迁移连接与档案搬运走真实客户端，不使用脚本角色的迁移桥接。',
    '',
    'Lua 与模型验证',
    '518 协议、86 适配、65 暂存、1567 原生迁移守恒、1025 快照、5 废弃重试、4 后台保存、2 恢复身份、2 保存断连竞态、6 原生写档、9 面板及 2 布局检查通过。',
    '迁移守恒模型额外运行 600 步四层出发/乱序到达/重复/不同时间捕获，独立按物品身份核对每个允许提交的组合恰有一份。',
    '这些是断言数，不是同样数量的独立故障场景；1025 快照检查包含 1000 次普通存取循环。',
    '',
    '恢复代价与尚未证明的边界',
    '没有事前通知后，不能再把“没有收到 Dirty 消息”当成某层未参与物品迁移的证据。',
    '因此发现已知分片换了进程时（包括关闭后重新开启），会保守恢复共同存档；即使先前认为该层干净，也可能触发相关层重启和进度回退。',
    '按主层同一次恢复决定重启的分片携带一次性身份凭据，避免相互反复触发重启；凭据在这次启动读取时持久清除。',
    '仍以最近提交的一致恢复点为准，未保存的获得、消耗与游戏进度可能回退。此方案不是逐笔持久化，也不是脱离原生网络的离线角色穿越。',
    '后台存取长期断信、玩家原生迁移未完成时，新的一致恢复点可能推迟；正常退出仍有先前的 20 秒兜底，这不是角色跨界超时。',
    '本轮没有穷尽第三方门户、长时间实服、机器/磁盘故障、恢复期间持续跨界的全部时序，也没有人工键鼠/画面验收。',
    '有限测试支持已列出的数量守恒结论，不能据此承诺任意故障下绝不丢最新进度、绝不出现第三方兼容问题。',
    '',
    '证据和复现',
    '每轮原生测试冻结 input 并保存 input-manifest.json。summary.json 记录当前核心哈希和各用例的版本差异。',
    '测试期间新增了等待记录变化再重做保存、一次性恢复身份等修订；较早通过项不冒充对最后每一行代码重新测试。',
    '四层补测第一次复现保存等待超时：断开通知晚于保存参与者选定。现已在断开时废弃未提交尝试，再按在线层重试。',
    '失败原始记录保留在 vault-native-only-four-attempt1-20261106.json 及其集群日志；最终复测见 four-final。',
]
for name,row in sorted(latest.items()):lines.extend([name+': '+row['status'],'  '+row['report'],'  '+row['cluster']])
lines.extend(['real_client: passed','  '+client_name,'  '+client['cluster'],'',
    'work/python-3.12.8/python.exe tests/run_shadow_vault_tests.py',
    'work/python-3.12.8/python.exe tests/run_vault_native_only.py --case blackhole full inflight save crash source_restart four',
    'work/python-3.12.8/python.exe tests/run_vault_client_travel.py --blackhole',
    '原生测试需本机游戏与现有隔离种子，串行运行避免端口冲突；不能导入正式玩家存档。'])
(OUT/'vault-native-only-20261106.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'cases':len(latest),'client_crossings':6,'native_blackhole_seconds':timings,'baseline_save_counts':saves}))
