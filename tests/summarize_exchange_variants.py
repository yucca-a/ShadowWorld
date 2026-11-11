"""Summarize frozen native runs without publishing player inventories or IDs."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
paths={
 'archive_migration':'work/vault-hardened-hosted-kn8nxbu4/archive-zip-report.json',
 'three_modes':'work/vault-hardened-hosted-ayn2aqj7/three-mode-native-report.json',
 'retired_journal':'work/vault-hardened-hosted-yj2u3v50/migrated-mode-roundtrip.json',
}
data={k:read(p)for k,p in paths.items()}
assert all(r['status']=='passed'for r in data.values())
archive=Path('D:/Users/Yucca/Downloads/----A萌新----妥测+为爽+棱镜+新界_688天_2026-11-07-08-09.zip')
assert hashlib.sha256(archive.read_bytes()).hexdigest()==data['archive_migration']['archive_sha256'],'original feedback archive changed'
baseline=read('work/vault-hardened-hosted-fi7p7wun/archive-zip-report.json')
retained={}
for shard,rows in baseline['inventories'].items():
 count=0;stacks=0
 for family,old in rows.items():
  new=data['archive_migration']['migrated'][shard]['inventory'][family]['items']or{}
  items={s:{k:i[k]for k in ('prefab','count','pet')if k in i}for s,i in new.items()}
  assert items==(old['items']or{}),(shard,family)
  count+=sum(i['count']for i in items.values());stacks+=len(items)
 retained[shard]={'containers':len(rows),'occupied_slots':stacks,'item_count':count}
core=['easy_other/exchangemodes2hm.lua','easy_other/exchangeclassic2hm.lua','easy_other/shadowbank2hm.lua',
 'easy_other/shadowvault.lua','scripts/exchangemode2hm.lua','scripts/exchangeoriginalmigration2hm.lua',
 'scripts/components/exchangevariants2hm.lua','scripts/components/shadowbank2hm.lua',
 'scripts/components/shadowvault2hm.lua','scripts/shadowvaultjournal2hm.lua','scripts/shadowvaultnative2hm.lua',
 'scripts/shadowvaultproxy2hm.lua','scripts/shadowvaultconfig2hm.lua','scripts/shadowbankview2hm.lua','scripts/shadowbanktransfer2hm.lua']
manifest=read('work/vault-hardened-hosted-ayn2aqj7/input-manifest.json')
manifest={p.replace('\\','/'):h for p,h in manifest.items()}
hashes={p:hashlib.sha256((ROOT/'content'/p).read_bytes()).hexdigest()for p in core}
assert all(manifest[p]==h for p,h in hashes.items()),'Core source changed after final three-mode test'
report={'status':'passed','publication':'local only; version unchanged at 2.8.15.0.8',
 'configuration':{'default':'exchange_v1_original','legacy_values':'classic','choices':['classic','xianyu','hosted'],
 'explicit_choice_persists':True,'old_nexus_items':'automatically returned to native home-shard containers before opening'},
 'reports':paths,'unit_checks':48,'lua_files_compiled':len(list((ROOT/'content').rglob('*.lua'))),
 'native_checks':[r['name']for r in data['three_modes']['checks']],
 'retained_inventory_comparison':retained,'archive_sha256':data['archive_migration']['archive_sha256'],
 'missing_original_mods':data['archive_migration']['missing_mods'],'core_sha256':hashes,
 'limits':['Dedicated-engine tests with simulated players, not client visual QA.',
 'Six original archive mods are unavailable locally; existing private offline-container mod is a substitute fixture.',
 'Archive auto-migration run predates the final offline-receipt proof helper; its helper is covered by Lua regression, and final mode-cycle/retired-journal runs use current core.',
 'Unresolved transactions, missing prefabs, and absent ownership evidence retain original records; they are not cleared to force migration.']}
out=ROOT/'development/validation/exchange-variants-20261107.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
summary='''三档穿越与旧档迁移，本地待发布（2026-11-07）

配置：一档为爽原版（默认），二档咸鱼版，三档暗影枢纽。
使用新的配置值区分显式选择与旧默认；所有旧配置值统一运行原版，之后手选二／三档可正常保存。
旧枢纽先恢复独立日志，再通过已有持久交接把真实物品送回所属层原生容器；原生世界保存完成后开放。
旧日志保留为升级前恢复依据，后续手动使用枢纽启用独立新日志，避免重新导入已迁出的物品。
手动切换新三档时，各自库存独立保留。咸鱼档忠实接入 test.zip 的双帽子空间与远端交互，未扩展成全容器原生 UI。

验证：
- 全部 Lua 5.1 编译、三档专项 48 项及既有枢纽日志／存取／入口回归通过。
- 真实双层专服：原版双向交换；咸鱼远端拆半取出与放回；三档保存重启；原版和枢纽有物品的往返；咸鱼第二空间保留。
- 688 天反馈存档隔离副本：旧配置自动迁移、双层保存重启、暗影／钓具／云青松打开。
- 对照先前 .8 恢复实测：地面 13、洞穴 9 个原有离线私人／云青松容器逐格物品与牛铃关联一致。
- 迁移后再切枢纽：两层新空间均为空，无旧日志重复导入；切回原版后逐格库存与迁移后存档一致。

边界：以上为专服引擎与模拟角色实测，未做客户端画面验收。反馈档有 6 个原模组本机未安装；离线私人容器使用现有同类实现作夹具，不能代表完全相同的原模组环境。
自动迁移不会通过删除未决交易、未知模组物品或不明归属记录来解锁；这些情况仍需原模组／对应世界恢复后继续处理。
旧档实测冻结输入早于最后的离线领取凭据核验；该辅助逻辑由专项回归覆盖，最终三档与迁移后日志隔离实测使用当前核心。

未修改版本号，未发布工坊。原始反馈包未修改；详细报告、输入哈希与范围见同名 JSON。
'''
out.with_suffix('.txt').write_text(summary,encoding='utf-8')
print(out)
