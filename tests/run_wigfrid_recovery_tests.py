"""Actual UM song callbacks and guarded replacement, including future-update refusal."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
for edition, uid in (("stable", "2039181790"), ("beta", "3193922031")):
    g[edition + "_source"] = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{uid}/postinit/prefabs/battlesongs.lua").read_text(encoding="utf-8-sig")
for key, name in (("guard_source", "umcompatguard2hm"), ("profiles_source", "umcompatprofiles2hm")):
    g[key] = (ROOT / f"content/scripts/{name}.lua").read_text(encoding="utf-8-sig")
patch = (ROOT / "content/easy_other/um_patch.lua").read_text(encoding="utf-8-sig")
start = patch.index("    -- Reviewed beta songs")
g.repair_source = patch[start:patch.index("    local electrical_type", start)]
lua.execute((ROOT / "tests/wigfrid_recovery_regression.lua").read_text(encoding="utf-8"))
