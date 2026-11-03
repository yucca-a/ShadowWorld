"""Replay invalid-entity cleanup with native Propagator and actual UM hooks."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().package.loaded.easing = lua.execute(z.read("scripts/easing.lua").decode("latin-1"))
    lua.globals().native_propagator = z.read("scripts/components/propagator.lua").decode("utf-8-sig")
source = (ROOT / "content/common/patch.lua").read_text(encoding="utf-8-sig")
start = source.index('AddComponentPostInit("propagator",')
end = source.index('\n-- 自我堆叠', start)
lua.globals().patch = source[start:end]
for key, mod in [("beta", "3193922031"), ("stable", "2039181790")]:
    lua.globals()[key] = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{mod}/postinit/components/propagator.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/propagator_regression.lua").read_text(encoding="utf-8-sig"))
