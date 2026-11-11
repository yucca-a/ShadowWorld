"""Disposable Gem Core/staff compatibility check; installed workshop files are read-only."""
from pathlib import Path
import sys, json, _winapi, traceback, argparse
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding='utf-8')
parser = argparse.ArgumentParser()
parser.add_argument('--label', default='fixed')
parser.add_argument('--wrap-green', action='store_true')
parser.add_argument('--mods', nargs='*', default=['1378549454', '3193922031', '3750536829'])
parser.add_argument('--smoke', action='store_true')
args = parser.parse_args()
c = Cluster('hosted', 1, ROOT/'work/native-shadow-vault-2j510173/config/Audit', ROOT/'content')
for uid in args.mods:
    _winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid), str(c.runtime/'mods'/('workshop-'+uid)))
p = c.cluster/'Master/modoverrides.lua'
config = p.read_text()
p.write_text(config[:-1] + ''.join(',["workshop-'+uid+'"]={enabled=true,configuration_options={}}' for uid in args.mods) + '}')
probe = ROOT/'tests/native/gem_staff_probe.lua'
if probe.exists():
    with (c.runtime/'mods/VaultAudit/modmain.lua').open('a', encoding='utf-8') as f:
        if args.wrap_green:
            f.write('\nlocal staff_common = require("prefabs/staff_common")\nlocal prior_green = staff_common.fns.green\nstaff_common.fns.green = function(...) return prior_green(...) end\n')
        f.write('\n'+probe.read_text(encoding='utf-8'))
        if args.smoke:
            f.write('\n'+(ROOT/'tests/native/crash_audit_probe.lua').read_text(encoding='utf-8'))
report = {'cluster': str(c.out), 'mods': args.mods, 'label': args.label}
try:
    c.start()
    if probe.exists() and '1378549454' in args.mods:
        report['result'] = c.call('Master', 'VaultAudit.gem_staff()', 'gem_staff')
        assert report['result']['passed'], report['result']
        assert report['result']['private_helper'] and report['result']['compat'], report['result']
    if args.smoke:
        report['smoke'] = c.call('Master', 'VaultAudit.crash_audit()', 'crash_audit')
        assert report['smoke']['passed'], report['smoke']
        c.saveall()
    report['status'] = 'passed'
except Exception:
    report.update(status='failed', error=traceback.format_exc())
    print(report['error'])
finally:
    c.stop()
    path = ROOT/('work/gem-staff-'+args.label+'.json')
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(path)
raise SystemExit(0 if report['status']=='passed' else 1)
