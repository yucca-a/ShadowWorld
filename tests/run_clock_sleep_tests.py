"""Test clock-peril sleeping phases with original DST world state and sleep components."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    read = lambda name: archive.read("scripts/" + name).decode("utf-8-sig")
    lua.execute(read("class.lua"))
    for key, name in (("NativeWorldState", "worldstate"), ("NativeSleepingBag", "sleepingbag"), ("NativeSleepUser", "sleepingbaguser")):
        lua.globals()[key] = lua.execute(read("components/" + name + ".lua"))
source = (ROOT / "content/role/clock_peril.lua").read_text(encoding="utf-8-sig")
start = source.index('AddComponentPostInit("sleepingbag",')
lua.globals().SleepPatch = source[start:source.index("local Network =", start)]
mechanics = (ROOT / "content/easy_other/easy_mechanics.lua").read_text(encoding="utf-8-sig")
start = mechanics.index("        for k,v in pairs(self) do", mechanics.index("local function CreateExSleepingBag"))
lua.globals().CopySleepSettings = lua.execute(
    "return function(self, ex_bag)\n" + mechanics[start:mechanics.index("        --标记", start)] + "\nend"
)
lua.execute((ROOT / "tests/clock_sleep_regression.lua").read_text(encoding="utf-8-sig"))
lua.execute("assert(loadstring(...))", source)
lua.execute("assert(loadstring(...))", mechanics)
print("Clock-peril gameplay source compiles in Lua 5.1")
