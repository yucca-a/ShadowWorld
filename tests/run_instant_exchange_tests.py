"""Research-only instant exchange tests. Does not enable the prototype in the mod."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    util = archive.read("scripts/util.lua").decode("utf-8-sig")
    start = util.index("function deepcopy(")
    lua.execute(util[start:util.index("\nend", start)+4])
load = lua.eval("function(source, name) return assert(loadstring(source, name))() end")
lua.globals().Base = load((ROOT / "content/scripts/worldexchangeprotocol2hm.lua").read_text(encoding="utf-8"), "durable-protocol")
lua.execute('package.preload["worldexchangeprotocol2hm"] = function() return Base end')
lua.globals().Instant = load((ROOT / "tests/experimental/instant_exchange_protocol.lua").read_text(encoding="utf-8"), "instant-protocol")
lua.globals().Guard = load((ROOT / "tests/experimental/checkpoint_guard.lua").read_text(encoding="utf-8"), "checkpoint-guard")
source = (ROOT / "tests/world_exchange_regression.lua").read_text(encoding="utf-8")
prefix = source[:source.index("\nlocal sim = simulation()")]
factory, initial, equal, checks = lua.execute(prefix + "\nreturn simulation, initial, equal, function() return assertions end")
lua.globals().simulation, lua.globals().initial, lua.globals().equal = factory, initial, equal
lua.execute((ROOT / "tests/experimental/instant_exchange_regression.lua").read_text(encoding="utf-8"))
print("Shared conservation checks:", checks())
lua.globals().Store = load((ROOT / "tests/experimental/snapshot_store.lua").read_text(encoding="utf-8"), "snapshot-store")
lua.execute((ROOT / "tests/experimental/snapshot_store_regression.lua").read_text(encoding="utf-8"))
