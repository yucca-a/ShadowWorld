from pathlib import Path
import sys, json, traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
c=Cluster('hosted',1,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
with (c.runtime/'mods/VaultAudit/modmain.lua').open('a',encoding='utf-8') as f:
    f.write('\n'+(ROOT/'tests/native/backpack_lock_probe.lua').read_text(encoding='utf-8'))
result={'cluster':str(c.out)}
try:
    c.start()
    result['probe']=c.call('Master','VaultAudit.backpack_lock()','backpack_lock')
except Exception:
    result['error']=traceback.format_exc()
finally:
    c.stop()
    target=ROOT/('work/backpack-lock-'+(sys.argv[1] if len(sys.argv)>1 else 'baseline')+'.json')
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True))
