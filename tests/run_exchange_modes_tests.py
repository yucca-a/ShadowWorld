"""Exercise real mode gates and upstream exchange RPCs with simulated shards."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
source = lambda path: (ROOT / "content" / path).read_text(encoding="utf-8-sig")
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    lua.execute(archive.read("scripts/dumper.lua").decode("utf-8-sig"))
    util = archive.read("scripts/util.lua").decode("utf-8-sig")
    start = util.index("function RunInSandboxSafe(")
    lua.execute(util[start:util.index("\nend", start) + 4])

collect = source("easy_other/containersort.lua")
start = collect.index("local function defaultbtnvalidfn(")
lua.globals().exchange_source = collect[start:collect.index("-- 容器收集", start)]
lua.globals().mode_source = source("easy_other/worldexchangefast.lua").split("local function engine()", 1)[0]
lua.globals().install_source = source("easy_other/worldexchange.lua").split("AddShardModRPCHandler", 1)[0]
lua.globals().info_source = source("modinfo.lua")
engine = source("scripts/worldexchangeengine2hm.lua")
lua.globals().idle_source = engine[engine.index("function Engine:Idle()"):engine.index("function Engine:Hold(")]
lua.execute((ROOT / "tests/exchange_modes_regression.lua").read_text(encoding="utf-8"))
