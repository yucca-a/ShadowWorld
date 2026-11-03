"""Production fast protocol, async checkpoint journal and recovery fault tests."""
from pathlib import Path
from zipfile import ZipFile
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
load = lua.eval("function(s,n) return assert(loadstring(s,n))() end")
for path in ["content/easy_other/worldexchangefast.lua", "content/easy_other/worldexchange.lua", "content/scripts/components/worldexchange2hm.lua"]:
    lua.eval("function(s,n) return assert(loadstring(s,n)) end")((ROOT / path).read_text(encoding="utf-8"), path)
scripts = sys.argv[1] if len(sys.argv) > 1 else "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
with ZipFile(scripts) as z:
    lua.execute(z.read("scripts/dumper.lua").decode("utf-8-sig"))
    util = z.read("scripts/util.lua").decode("utf-8-sig")
    start = util.index("function RunInSandboxSafe(")
    lua.execute(util[start:util.index("\nend", start)+4])
for name in ["worldexchangeprotocol2hm", "worldexchangestore2hm", "worldexchangeinstant2hm", "worldexchangecheckpoint2hm", "worldexchangeengine2hm"]:
    module = load((ROOT / "content/scripts" / (name + ".lua")).read_text(encoding="utf-8"), name)
    lua.globals()[name] = module
    lua.execute(f'package.preload["{name}"] = function() return {name} end')
lua.execute((ROOT / "tests/fast_exchange_regression.lua").read_text(encoding="utf-8"))
