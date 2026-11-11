"""Run size loot behavior against native LootDropper and native loot definitions."""
from pathlib import Path
import re
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().LootDropper = lua.execute(z.read("scripts/components/lootdropper.lua").decode("utf-8-sig"))
    actions = z.read("scripts/actions.lua").decode("utf-8-sig")
    start = actions.index("ACTIONS.MURDER.fn = function(act)")
    lua.globals().murder_source = actions[start:actions.index("\nACTIONS.HEAL.strfn", start)]
    beefalo = z.read("scripts/prefabs/beefalo.lua").decode("utf-8-sig")
    table = re.search(r"SetSharedLootTable\(\s*'beefalo'\s*,[\s\S]*?\}\s*\)", beefalo)
    assert table
    lua.execute(table.group())
    elephant = z.read("scripts/prefabs/koalefant.lua").decode("utf-8-sig")
    for season in ("summer", "winter", "fire"):
        match = re.search(r"local loot_" + season + r"\s*=\s*(\{[^\n]+\})", elephant)
        assert match
        lua.globals()["elephant_" + season] = lua.eval(match.group(1))
source = (ROOT / "content/ray/suijishengwuapi.lua").read_text(encoding="utf-8-sig")
lua.eval("function(s) return assert(loadstring(s)) end")(source)
start = source.index("-- Only ordinary meat portions")
end = source.index("-- 提取判断是否随机缩放", start)
lua.globals().size_source = "local beefalochange=false\n" + source[start:end] + "\nreturn {Apply=qianghua, Save=saveandload, Install=InstallTrapIdentity}"
lua.execute((ROOT / "tests/random_size_loot_regression.lua").read_text(encoding="utf-8"))
lua.execute((ROOT / "tests/random_size_capture_regression.lua").read_text(encoding="utf-8"))
