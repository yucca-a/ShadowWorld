"""Live three-mode selection, native original exchange and migration regressions."""
from pathlib import Path
from zipfile import ZipFile
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
load=lua.eval('function(s,n)return assert(loadstring(s,n))end')
for p in (ROOT/'content').rglob('*.lua'):load(p.read_text(encoding='utf-8-sig'),str(p))
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
 lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
 lua.execute(z.read('scripts/dumper.lua').decode('utf-8-sig'))
 util=z.read('scripts/util.lua').decode('utf-8-sig')
 for name in ['deepcopy','RunInSandboxSafe']:
  start=util.index('function '+name+'(');lua.execute(util[start:util.index('\nend',start)+4])
for name in ['exchangemode2hm','shadowvaultconfig2hm','rpcguard2hm','exchangeoriginalmigration2hm','components/exchangevariants2hm']:
 lua.globals().module=load((ROOT/'content/scripts'/f'{name}.lua').read_text(encoding='utf-8'),name)
 lua.execute(f'package.preload["{name}"]=module')
lua.globals().classic_source=(ROOT/'content/easy_other/exchangeclassic2hm.lua').read_text(encoding='utf-8')
lua.execute((ROOT/'tests/exchange_variants_regression.lua').read_text(encoding='utf-8'))
print('All content Lua 5.1 syntax checks passed')
