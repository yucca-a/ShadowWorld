"""Summarize frozen native-travel evidence without attributing old tests to new code."""
from pathlib import Path
import difflib
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'development/validation'
SOURCES = [
    'vault-travel-priority-20261106.json',
    'vault-travel-priority-faults-20261106.json',
    'vault-travel-priority-final-20261106.json',
    'vault-travel-priority-forwarding-final-20261106.json',
]
FILES = [
    'content/easy_other/shadowvault.lua',
    'content/easy_other/shadowvaultsnapshot.lua',
    'content/scripts/components/shadowvault2hm.lua',
    'content/scripts/shadowvaultcourier2hm.lua',
    'content/scripts/shadowvaultsnapshot2hm.lua',
    'content/scripts/shadowvaultsnapshotcore2hm.lua',
]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
archived_results=json.loads((OUT / 'vault-travel-priority-forwarding-final-20261106.json').read_text(encoding='utf-8'))
ARCHIVED=Path(archived_results[0]['cluster']) / 'input'
manifest = {name: sha(ARCHIVED / name.removeprefix('content/')) for name in FILES}
latest = {}
for filename in SOURCES:
    for row in json.loads((OUT / filename).read_text(encoding='utf-8')):
        latest[row['case']] = dict(row, report=filename)
required = {'native', 'enabled', 'save', 'full', 'inflight', 'unrelated', 'controls', 'yield_crash'}
assert latest.keys() == required
for row in latest.values():
    assert row['status'] == 'passed', row['case']
    assert row['checks'] and all(c['conserved'] for c in row['checks']), row['case']
    frozen = json.loads((Path(row['cluster']) / 'input-manifest.json').read_text(encoding='utf-8'))
    frozen = {name.replace('\\', '/'): digest for name, digest in frozen.items()}
    row['source_differences_from_archived_core'] = [
        name for name, digest in manifest.items() if frozen.get(name.removeprefix('content/')) != digest
    ]
assert not latest['inflight']['source_differences_from_archived_core'], 'latest forwarding test must match current code'
settled = next(c for c in latest['inflight']['checks'] if c['label'] == 'transaction_settled_after_travel')
assert all(s['pending'] == 0 and not s.get('error') for s in settled['state'].values())
assert settled['state']['Master']['locations']['KU_VA_2_1'] == 17
assert all(s.get('snapshotphase') is None for s in latest['native']['checks'][0]['state'].values())

client_file = 'vault-real-client-travel-20261106.json'
client = json.loads((OUT / client_file).read_text(encoding='utf-8'))
assert client['status'] == 'passed' and client['arrivals'] == list(range(7))
frozen_client = json.loads((Path(client['cluster']) / 'input-manifest.json').read_text(encoding='utf-8'))
frozen_client = {name.replace('\\', '/'): digest for name, digest in frozen_client.items()}
client['source_differences_from_archived_core'] = [
    name for name, digest in manifest.items() if frozen_client.get(name.removeprefix('content/')) != digest
]
timings = {}
for mode in ('native', 'enabled'):
    timings[mode] = {}
    for origin in ('Caves', 'Master'):
        samples = [t['departure_seconds'] for t in latest[mode]['travel'] if t['from'] == origin]
        timings[mode][origin] = dict(samples=samples, median=statistics.median(samples))

baseline = ROOT / 'work/vault-native-travel-baseline-20261106'
changed = {}
for name in FILES:
    old = baseline / name
    before = old.read_text(encoding='utf-8').splitlines() if old.exists() else []
    after = (ARCHIVED / name.removeprefix('content/')).read_text(encoding='utf-8').splitlines()
    diff = list(difflib.unified_diff(before, after))
    changed[name] = {
        'added': sum(l.startswith('+') and not l.startswith('+++') for l in diff),
        'removed': sum(l.startswith('-') and not l.startswith('---') for l in diff),
    }
    assert not any(line.rstrip() != line for line in after), f'trailing whitespace: {name}'

summary = {
    'status': 'historical_before_native_only_migration', 'superseded_by': 'vault-native-only-20261106.txt', 'native_build': 761239,
    'source_sha256': manifest, 'changes_from_turn_baseline': changed,
    'benchmark': timings,
    'benchmark_scope': 'server request-to-departure, includes native fade and probe sampling; not client loading time',
    'cases': {name: {k: row[k] for k in ('status', 'report', 'cluster', 'source_differences_from_archived_core')}
              for name, row in sorted(latest.items())},
    'real_client': dict(client, report=client_file),
}
(OUT / 'vault-travel-priority-20261106-summary.json').write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

lines = [
    '暗影空间：跨界体验调整与验证（2026-11-06）',
    '历史报告：角色等待确认及 20 秒取消机制已移除；当前行为见 vault-native-only-20261106.txt。',
    '状态：本地改动及下列验证完成，未发布工坊。原生游戏版本 761239。',
    '',
    '这次改变了什么',
    '1. 保存协调处于排空、冻结或准备阶段时，不再直接拒绝角色跨界。',
    '   尚未提交的恢复点让出执行，跨界完成后重试原本已经提出的正常保存请求。',
    '   若已进入不可撤销的元数据提交阶段，则自动等提交完成，不把普通保存当作传送失败。',
    '2. 背包满的已确认待交付物品随原生玩家迁移档案搬运；档案序列化后才清理来源暂存。',
    '   目的地仍满就继续暂存，腾出空间后交付；去重回执防止重复读取档案再次生成物品。',
    '3. 尚未完成的存取留在原世界完成，再通过游戏原生物品跨层事务转交到玩家所在层。',
    '   恢复物品失败时保留序列化原件供重试，不删除原件，也不禁止玩家操作。',
    '4. 异步等待保持原生动作成功结果，下一静态帧退出尚未实际出发的 migrate/busy 状态。',
    '   玩家仍能移动；移离入口、入口失效或取消航行后不会执行迟到的跨界。',
    '5. 普通存取和角色跨界不请求 c_save / ms_save / SaveGame。原生跨界本来就会保存玩家档案。',
    '   与已经开始的正常保存相撞时，废弃的恢复点可能产生一次无效写入，随后重做正常保存；',
    '   这不是“每次穿越整档保存”，也不代表正常存档协调完全没有额外 I/O。',
    '',
    '验证结果',
    '原生开关对照：关闭空间机制/启用机制分别执行 6 次服务端角色跨界。',
    '按出发方向统计的请求至离开秒数（含原生淡出与探针采样；不代表客户端完整加载耗时）：',
    json.dumps(timings, ensure_ascii=False),
    '洞穴出发中位数增加约 0.10 秒；每方向仅 3 个样本，不用于保证所有服务器性能。',
    '实际游戏客户端：6 次跨界、7 次到达，逐次核对背包 17 个金子及控制器启用状态。',
    '实际客户端采用隔离运行目录与自动加入/选角，使用真实客户端原生跨服连接和玩家档案搬运。',
    '背包满：携带暂存来回跨界、保存重启、腾出空间后只交付一次，物品总量均为 17。',
    '存取进行中：只丢存取协议消息，跨界后恢复通信，17 个金子进入目的地玩家背包；',
    '最后复测来源和目的地 pending 都为 0，正常保存重启后仍为 17。',
    '保存相撞：冻结期间成功跨界，恢复通信并保存重启后数量一致。',
    '保存让出后崩溃：未提交新恢复点即强停所有层，重启恢复到一致数量 17。',
    '四层：Layer4 离线期间，Caves → Master → Layer3 均正常离开，物品数量一致。',
    '完全丢模组确认：实际原生缓冲动作没有虚假失败回调，角色退出 busy 且实际走动；',
    '20 秒后清理本次请求标记，恢复通信后物品总量仍为 17。',
    '本轮 Lua 回归：518 协议、86 适配、65 暂存、1025 快照、5 保存让出、16 跨界、9 面板、2 原生布局检查通过。',
    '上述 1025 包含 1000 次普通存取循环断言，不代表 1025 种故障。既有快速交换/回档回归也通过。',
    '',
    '发现并修复的问题',
    '早期跨界后延迟转交已正确交付，但来源容器保留了被原生事务移除的失效实体引用，pending=1。',
    '现已识别并清理该空记录，避免后续残留；为此增加单元检查及目的地背包/两端 pending 的原生断言。',
    '旧 inflight 报告保留原始事实；以 forwarding-final 报告作为收尾清理的最终证据。',
    '',
    '保留的边界',
    '目标世界离线不能让角色真正进入该世界，这是原生限制；在主世界访问已托管的离线层空间不受此限制。',
    '模组仍需要一次跨界确认。游戏连接仍在但模组确认完全丢失时，20 秒后取消本次请求，等待中可移动。',
    '因此正常路径已接近原版，不能宣称所有故障状态与原版完全相同或完全摆脱世界通信。',
    '崩溃恢复仍以最近共同提交的恢复点为准，未保存的游戏进度可能回退，不能保证最后一笔永久保留。',
    '大量暂存转交的去重回执会随存档累积；长时间实服、所有第三方门户、客户端键鼠画面未全部验收。',
    '正常退出沿用上一轮 20 秒兜底，通信故障时可能等到兜底才退出；本轮没有重新测这一项。',
    '不能用这些有限测试证明任意硬件、进程或第三方模组故障下绝不刷物/吞物。',
    '',
    '输入与证据',
    '各测试使用冻结的 input 内容；input-manifest.json 和日志保留在对应集群目录。',
    '测试在连续修复过程中执行，不能把较早用例说成对最后每一行代码都重跑过。',
    'summary.json 列出每个用例与该次归档的 6 个核心文件的差异；最终延迟转交复测与该次归档核心文件一致。',
    '该次归档核心 SHA-256、相对本轮开始时的改动统计也在 summary.json。',
    '',
]
for name, row in sorted(latest.items()):
    lines += [f'{name}: {row["status"]}', f'  {row["report"]}', f'  {row["cluster"]}']
lines += ['real_client: passed', f'  {client_file}', f'  {client["cluster"]}', '',
          '复现入口（原生测试需本机游戏和已有隔离种子）：',
          'work/python-3.12.8/python.exe tests/run_shadow_vault_tests.py',
          'work/python-3.12.8/python.exe tests/run_vault_travel_priority.py --case native enabled save full inflight unrelated controls yield_crash',
          'work/python-3.12.8/python.exe tests/run_vault_client_travel.py',
          '原生测试串行执行，避免固定端口争用。测试脚本只用于一次性隔离集群，不导入正式存档。']
(OUT / 'vault-travel-priority-20261106.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(json.dumps({'cases': len(latest), 'real_client_crossings': 6, 'benchmark': timings,
                  'core_changes': changed}, ensure_ascii=False))
