"""Actual UM resurrection callbacks/native timer and local passive soul callback."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/test-python'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
    lua.globals().timer_source = z.read('scripts/components/timer.lua').decode('utf-8-sig')
for key, path in {
    'upstream_source': Path('D:/SteamLibrary/steamapps/workshop/content/322330/3193922031/postinit/components/health.lua'),
    'guard_source': ROOT/'content/scripts/umcompatguard2hm.lua',
    'profiles_source': ROOT/'content/scripts/umcompatprofiles2hm.lua',
    'patch_source': ROOT/'content/scripts/umwortox2hm.lua',
    'local_source': ROOT/'content/easy_role/wortox_easy.lua',
}.items():
    lua.globals()[key] = path.read_text(encoding='utf-8-sig')
lua.execute((ROOT/'tests/wortox_balance_regression.lua').read_text(encoding='utf-8'))
