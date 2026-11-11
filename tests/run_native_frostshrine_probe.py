"""Smoke-check selected art in a copied mod and disposable native test world."""
from pathlib import Path
import _winapi, json, shutil, subprocess, time

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
OUT = ROOT/'work/frost-station-effects'/('native-check-'+time.strftime('%Y%m%d-%H%M%S'))
OUT.mkdir(exist_ok=False)
runtime = OUT/'runtime'
(runtime/'bin64').mkdir(parents=True)
for source in (GAME/'bin64').iterdir():
    if source.is_file(): shutil.copy2(source, runtime/'bin64'/source.name)
_winapi.CreateJunction(str(GAME/'data'), str(runtime/'data'))
mod = runtime/'mods/FrostArtProbe'
shutil.copytree(ROOT/'content', mod)
shutil.copy2(ROOT/'tests/native/frostshrine_effects_probe.lua', mod/'native_probe.lua')
with (mod/'modmain.lua').open('a', encoding='utf-8') as f:
    f.write('\nmodimport("native_probe.lua")\n')
cluster = OUT/'config/FrostArt'
master = cluster/'Master'
shutil.copytree(ROOT/'work/reuse-audit/config/Audit/Master/save', master/'save')
(cluster/'cluster.ini').write_text('''[GAMEPLAY]
game_mode = survival
max_players = 1
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld disposable frost art check
offline_cluster = true
lan_only_cluster = true
[MISC]
console_enabled = true
[SHARD]
shard_enabled = false
''', encoding='utf-8')
(master/'server.ini').write_text('''[NETWORK]
server_port = 11172
[SHARD]
is_master = true
name = Master
id = 1
[STEAM]
master_server_port = 28973
authentication_port = 9703
''', encoding='utf-8')
(master/'modoverrides.lua').write_text('return {FrostArtProbe={enabled=true,configuration_options={}}}', encoding='utf-8')
logpath = OUT/'native.log'
with logpath.open('wb') as log:
    p = subprocess.Popen([str(runtime/'bin64/dontstarve_dedicated_server_nullrenderer_x64.exe'),
        '-persistent_storage_root', str(OUT), '-conf_dir', 'config', '-cluster', 'FrostArt',
        '-shard', 'Master', '-port', '11172'], cwd=runtime/'bin64',
        stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
    print('Started disposable native art check PID', p.pid, flush=True)
    (OUT/'process.json').write_text(json.dumps({'pid':p.pid}), encoding='utf-8')
    try:
        p.wait(timeout=150)
    except subprocess.TimeoutExpired:
        print('Timeout; stopping only this disposable child process', flush=True)
    finally:
        if p.poll() is None: p.terminate(); p.wait(timeout=15)
logtext = logpath.read_text(encoding='utf-8', errors='replace')
lines = [line for line in logtext.splitlines() if '[FROST_ART_PROBE]' in line or 'LUA ERROR' in line or 'Could not find' in line or 'Could not load' in line]
result = {'pass':'[FROST_ART_PROBE] PASS:' in logtext and '[FROST_ART_PROBE] FAIL:' not in logtext,
          'exit_code':p.returncode, 'log':str(logpath), 'checks':lines,
          'limitation':'Nullrenderer native smoke test; not a client visual screenshot.'}
(OUT/'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2), flush=True)
raise SystemExit(0 if result['pass'] else 1)
