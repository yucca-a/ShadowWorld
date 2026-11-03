"""Exercise turret hooks with native combat and the upstream repair action/component."""
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
    for name in ["combat", "projectile", "health", "spellcaster"]:
        source = z.read(f"scripts/components/{name}.lua").decode("utf-8-sig")
        methods = {"combat": ["DoAttack"], "projectile": ["Hit"],
                   "health": ["SetVal", "DoFireDamage"],
                   "spellcaster": ["CanCast"]}[name]
        for method in methods:
            classname = "SpellCaster" if name == "spellcaster" else name.capitalize()
            start = source.index(f"function {classname}:{method}(")
            native[name + "_" + method] = source[start:source.index("\nend", start) + 4]
    lua.globals().timer_source = z.read("scripts/components/timer.lua").decode("utf-8-sig")
common = (ROOT / "content/common/common.lua").read_text(encoding="utf-8-sig")
lua.globals().common_actions_source = common[common.index('TUNING.USEITEMFNS2HM = {}'):common.index('STRINGS.ACTIONS.REPAIR2HM = {}')]
lua.globals().repair_source = (ROOT / "content/scripts/components/repairable2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().native = lua.table_from(native)
lua.globals().turret_source = (ROOT / "content/easy_other/eyeturret2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().fire_source = (ROOT / "content/scripts/prefabs/eyeturret_safefire2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().config_source = (ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/eyeturret_regression.lua").read_text(encoding="utf-8-sig"))
