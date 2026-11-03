"""Real installed DST trap component, prefab, stategraph and finite uses."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    lua.execute(archive.read("scripts/class.lua").decode("utf-8-sig"))
    lua.execute('package.loaded["class"] = true')
    lua.execute(archive.read("scripts/stategraph.lua").decode("utf-8-sig"))
    lua.execute("EntityScript = {}")
    entity = archive.read("scripts/entityscript.lua").decode("utf-8-sig")
    for name in ["PushEvent_Internal", "PushEvent"]:
        start = entity.index("function EntityScript:" + name + "(")
        lua.execute(entity[start:entity.index("\nend", start) + 4])
    for key, name in {"native_trap": "components/trap", "native_graph": "stategraphs/SGtrap",
                      "native_prefab": "prefabs/trap", "native_uses": "components/finiteuses"}.items():
        lua.globals()[key] = archive.read("scripts/" + name + ".lua").decode("utf-8-sig")
    util = archive.read("scripts/simutil.lua").decode("utf-8-sig")
    start = util.index("function FindEntity(")
    lua.execute(util[start:util.index("\nend", start) + 4])

items = (ROOT / "content/easy_other/easy_items.lua").read_text(encoding="utf-8-sig")
lua.globals().patch_source = items[items.index("-- 普通陷阱必中："):items.index("-- 瓶中信配方:")]
shadow = (ROOT / "content/shadowworld.lua").read_text(encoding="utf-8-sig")
lua.globals().shadow_source = shadow[shadow.index('-- 分身免疫陷阱和捕鸟陷阱'):shadow.index('-- 无眼鹿不掉落宝石')]
lua.globals().info_source = (ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/trap_regression.lua").read_text(encoding="utf-8"))
