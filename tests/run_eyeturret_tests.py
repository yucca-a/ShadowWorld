"""Exercise turret hooks with native projectile, attack, fire and trading code."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
native = {}
with ZipFile(sys.argv[1] if len(sys.argv) > 1 else
             "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    for name in ["combat", "projectile", "health", "trader"]:
        source = z.read(f"scripts/components/{name}.lua").decode("utf-8-sig")
        methods = {"combat": ["DoAttack"], "projectile": ["Hit"],
                   "health": ["SetVal", "DoFireDamage"], "trader": ["AcceptGift", "AbleToAccept", "WantsToAccept"]}[name]
        for method in methods:
            start = source.index(f"function {name.capitalize()}:{method}(")
            native[name + "_" + method] = source[start:source.index("\nend", start) + 4]
lua.globals().native = lua.table_from(native)
lua.globals().turret_source = (ROOT / "content/easy_other/eyeturret2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().fire_source = (ROOT / "content/scripts/prefabs/eyeturret_safefire2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().config_source = (ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/eyeturret_regression.lua").read_text(encoding="utf-8-sig"))
