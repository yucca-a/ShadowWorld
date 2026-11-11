"""Summarize the no-forced-save prototype with explicit evidence and limitations."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'development/validation'
sources=[
 'vault-no-forced-save-final-20261106.json',
 'vault-no-forced-save-controls-20261106.json',
 'vault-no-forced-save-interaction-final-20261106.json',
 'vault-no-forced-save-faults-final-20261106.json',
 'vault-no-forced-save-remaining-final-20261106.json',
]
latest={}
for filename in sources:
    for result in json.loads((OUT/filename).read_text(encoding='utf-8')):
        latest[result.get('scenario',result.get('case'))]={'report':filename,**result}
required={'matrix','full_restart','interrupted','complex','shutdown','shutdown_outage','migration',
          'capture_crash','commit_crash','master_restart','secondary_restart','controls','item_migration','history'}
assert required<=latest.keys(),required-latest.keys()
assert all(latest[k]['status'] in ('finished','passed') for k in required)
assert all(c.get('conserved',True) for k in required for c in latest[k]['checks'])
matrix=latest['matrix'];checks={c['name']:c for c in matrix['checks']}
before,after=checks['baseline']['state'],checks['durability_withdraw']['state']
deltas={s:after[s]['saves']-before[s]['saves'] for s in before}
assert all(n==0 for n in deltas.values())
attempts=sum(c.get('attempts',0) for c in matrix['checks'])
files=[
 'content/easy_other/shadowvault.lua','content/easy_other/shadowvaultsnapshot.lua',
 'content/easy_other/worldexchangefast.lua','content/scripts/components/shadowvault2hm.lua',
 'content/scripts/shadowvaultsnapshot2hm.lua','content/scripts/shadowvaultsnapshotcore2hm.lua',
 'content/scripts/shadowvaultconfig2hm.lua','content/scripts/worldexchangeinstant2hm.lua',
]
frozen=Path(matrix['cluster'])/'input'
manifest={p:hashlib.sha256((frozen/Path(p).relative_to('content')).read_bytes()).hexdigest() for p in files}
summary={'status':'historical_before_travel_priority','superseded_by':'vault-travel-priority-20261106.txt',
         'source_manifest_scope':'frozen matrix input; other cases have their own input-manifest.json',
         'native_build':761239,'forced_save_deltas':deltas,
         'race_attempts':attempts,'source_sha256':manifest,
         'cases':{k:{'status':latest[k]['status'],'report':latest[k]['report'],'cluster':latest[k]['cluster']}
                  for k in sorted(required)}}
(OUT/'vault-no-forced-save-20261106-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
lines=[
 '暗影空间：取消逐笔整档保存的原型验证（2026-11-06）',
 '历史报告：保存期间/背包满时阻止跨界、异步动作返回失败等行为已被后续修订。',
 '当前行为与新增实测见 vault-travel-priority-20261106.txt；以下保留当时版本的结果。',
 '状态：本地实现和已列出的回归通过；未发布工坊。不是“完全无通信依赖”的最终方案。',
 '',
 '实现与实际边界',
 '1. 普通存取沿用内存转移、唯一事务和重复回执处理，不再触发 ms_save / c_save / SaveGame。',
 '2. 只有游戏正常自动保存、手动保存或正常退出请求保存时，才建立一致恢复点。',
 '   此时仍调用原生 SaveGame，并额外保存世界与玩家的恢复副本，有额外存档 I/O；不是轻量逐笔仓库日志。',
 '3. 主世界托管每层独立空间；已迁入的洞穴空间在洞穴离线时仍能在主世界实际存取。',
 '   新层原有物品第一次迁入仍需该层在线。副世界远程存取需要主世界连接和回执。',
 '4. 干净离线层保留上次引用，不阻塞主世界启动或保存。存在未保存跨界影响的层失联时，',
 '   新的一致保存可能等待通信恢复，相关跨界/远程存取会拒绝或暂缓，不能保证永远可跨界。',
 '5. 单层崩溃导致跨层状态不一致时，会恢复相关世界到上次一致恢复点；未保存的游戏进度可能回退。',
 '   这不是逐笔即时持久化。数量守恒测试不能证明任意崩溃下最新获得/消耗的物品都不回退。',
 '6. 背包满的待交付物品保留在暂存容器；待交付未清理前可移动、腾位置，但会拒绝本次角色跨界。',
 '',
 '针对角色卡住的修复与验证',
 '原生 SGwilson 的 migrate 状态只在动作失败或实际离开时退出。异步等待仍返回成功会卡在 busy。',
 '现在异步未离开返回失败；取消和超时清理请求，重复 GRANT 不再重复出发或取消已出发角色。',
 '取消消息带确认并重试；迟到 REQUEST 不重建已完成/已取消旅程。短暂断线保留原保存握手阶段。',
 '原生服务器脚本角色实测：等待确认/保存冻结时能退出 migrate/busy，控制器启用并实际走动。',
 f'完全丢弃通信时退出耗时 {latest["shutdown_outage"]["shutdown_seconds"]:.3f} 秒（20 秒兜底+原生关闭时间）。',
 '正常退出、跨界后重启、失联退出后恢复，测试金子均为 17 个。',
 '',
 '原生测试结果',
 f'四层 {attempts} 次争抢请求，重复/丢包/乱序/正常各 3 轮；每轮只有一个成功领取者，归还后总量一致。',
 '普通存取期间，各层真实 SerializeWorldSession 次数：'+str({s:[before[s]['saves'],after[s]['saves']] for s in before}),
 '真实原生存档编号：'+str({s:[before[s]['snapshot'],after[s]['snapshot']] for s in before}),
 '背包满后保存重启/腾空间只交付一次；过期槽位拒绝；10 万字节包裹分块丢失重试；装备属性恢复通过。',
 '正常保存中断、提交消息丢失、主层独立重启、副层独立重启、原生物品跨层传送均恢复到一致数量。',
 '12 轮额外正常保存后的记录统计：'+json.dumps(latest['history'].get('history'),ensure_ascii=False),
 '物资验证完成于原生 DST 761239 的隔离服务器；没有修改正式游戏文件或玩家正式存档。',
 '',
 '证据限制与测试故障',
 '不是完整真人客户端/键鼠测试。玩家跨界测试桥接客户端搬运的档案，调用原生离开和 ResumeExistingUserSession。',
 '未穷尽所有角色、所有第三方特殊传送门（含海难门户）、长时间实服、磁盘/机器级故障。',
 '早期角色测试未唤醒无客户端脚本角色，随后纠正并实际覆盖异步等待分支；失败日志保留。',
 '一次并发测试发生测试集群端口抢占 SOCKET_PORT_ALREADY_IN_USE；随后串行重跑副层重启及控制测试通过。',
 '所有冻结输入与日志留在以下隔离目录；较早测试与当前源码可能存在修复版本差异，应以各 input-manifest.json 为准。',
 '',
]
for name in sorted(required):
    r=latest[name];lines.extend([f'{name}: {r["status"]}',f'  {r["report"]}',f'  {r["cluster"]}'])
(OUT/'vault-no-forced-save-20261106.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'reports':len(required),'attempts':attempts,'save_deltas':deltas},ensure_ascii=False))
