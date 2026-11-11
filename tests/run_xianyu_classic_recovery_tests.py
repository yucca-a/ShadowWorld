"""Recovery ownership, overflow, legacy refs and saved transfer deduplication."""
from pathlib import Path
from zipfile import ZipFile
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
load=lua.eval('function(s,n)return assert(loadstring(s,n))end')
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
 lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
for name in ['exchangemode2hm','shadowvaultconfig2hm','shadowbanktransfer2hm','exchangexianyurecovery2hm','components/shadowbank2hm','components/exchangevariants2hm']:
 lua.globals().module=load((ROOT/'content/scripts'/f'{name}.lua').read_text(encoding='utf-8-sig'),name)
 lua.execute(f'package.preload["{name}"]=module')
lua.execute((ROOT/'tests/xianyu_classic_recovery_regression.lua').read_text(encoding='utf-8'))
