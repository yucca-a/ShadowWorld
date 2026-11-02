"""Fault tests for the actual exchange protocol and Lua 5.1 syntax checks."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
loader = lua.eval("function(s, name) return assert(loadstring(s, name)) end")
for path in ["scripts/worldexchangeprotocol2hm.lua", "scripts/components/worldexchange2hm.lua",
             "easy_other/worldexchange.lua", "easy_other/containersort.lua", "modmain.lua"]:
    loader((ROOT / "content" / path).read_text(encoding="utf-8-sig"), path)
lua.globals().Protocol = loader((ROOT / "content/scripts/worldexchangeprotocol2hm.lua").read_text(encoding="utf-8"), "protocol")()
lua.execute((ROOT / "tests/world_exchange_regression.lua").read_text(encoding="utf-8"))

# Run the actual engine adapter with native serialization/class support. Only
# entities, persistence I/O and RPC delivery are simulated in this second suite.
scripts = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")
with ZipFile(scripts) as archive:
    lua.execute(archive.read("scripts/class.lua").decode("utf-8-sig"))
    lua.execute(archive.read("scripts/dumper.lua").decode("utf-8-sig"))
    util = archive.read("scripts/util.lua").decode("utf-8-sig")
    start = util.index("function RunInSandboxSafe(")
    lua.execute(util[start:util.index("\nend", start) + 4])
lua.execute('package.preload["worldexchangeprotocol2hm"] = function() return Protocol end')
lua.globals().WorldExchange = loader((ROOT / "content/scripts/components/worldexchange2hm.lua").read_text(encoding="utf-8"), "adapter")()
lua.globals().integration_source = (ROOT / "content/easy_other/worldexchange.lua").read_text(encoding="utf-8")
lua.execute((ROOT / "tests/world_exchange_adapter_regression.lua").read_text(encoding="utf-8"))
