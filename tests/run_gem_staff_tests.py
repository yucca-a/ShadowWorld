"""Exercise the installed native green-staff closures and Gem Core callback."""
from pathlib import Path
from zipfile import ZipFile
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    staff = z.read('scripts/prefabs/staff_common.lua').decode('utf-8-sig')
lua.globals().staff_source = 'local fns={}\n'+staff[staff.index('------- green'):staff.index('------- yellow')]+ '\nreturn {fns=fns,DESTSOUNDSMAP=DESTSOUNDSMAP}'
gem = Path('D:/SteamLibrary/steamapps/workshop/content/322330/1378549454/gemscripts/gemdictionary/loot.lua').read_text(encoding='utf-8-sig')
lua.globals().gem_source = gem[gem.index('-- GREENSTAFF --'):gem.index('-- GREENSTAFF END --')]
with ZipFile(ROOT/'backups/releases/v2.8.15.0.8-content.zip') as z:
    lua.globals().old_helper = z.read('scripts/upvaluehacker2hm.lua').decode('utf-8-sig')
lua.globals().new_helper = (ROOT/'content/scripts/upvaluehacker2hm.lua').read_text(encoding='utf-8-sig')
lua.globals().compat_source = (ROOT/'content/scripts/gemstaffcompat2hm.lua').read_text(encoding='utf-8-sig')
lua.execute((ROOT/'tests/gem_staff_regression.lua').read_text(encoding='utf-8-sig'))
