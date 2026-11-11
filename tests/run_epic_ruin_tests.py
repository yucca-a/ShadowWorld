"""Test Epic Ruin through DST's entity save and restore path."""
from pathlib import Path
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
scripts = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)
with ZipFile(scripts) as archive:
    lua.execute(archive.read("scripts/class.lua").decode("utf-8-sig"))
    lua.execute(archive.read("scripts/dumper.lua").decode("utf-8-sig"))
    entity = archive.read("scripts/entityscript.lua").decode("utf-8-sig")
    lua.globals().EntityScript = lua.table()
    for name in ("GetPersistData", "SetPersistData"):
        start = entity.index(f"function EntityScript:{name}(")
        lua.execute(entity[start:entity.index("\nend", start) + 4])

lua.globals().Persistent = lua.execute((ROOT / "content/scripts/components/persistent2hm.lua").read_text(encoding="utf-8"))
lua.execute("""
function IsTableEmpty(t) return next(t) == nil end
TUNING = {}
TheWorld = {ismastersim = true, state = {cycles = 10}}
function GetModConfigData() return EpicRuinRate end
function AddPrefabPostInitAny(fn) Initialize = fn end
""")
modinfo = lua.eval("""
function(source)
    local env = setmetatable({locale = "zh"}, {__index = _G})
    setfenv(assert(loadstring(source)), env)()
    for _, option in ipairs(env.configuration_options) do
        if option.name == "epic_ruin" then return option end
    end
end
""")((ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig"))
assert modinfo.default == 0.8
assert {option.data for option in modinfo.options.values()} == {False, 0.6, 0.8, "full", 2}

source = (ROOT / "content/epic/epic_ruin.lua").read_text(encoding="utf-8")
regression = (ROOT / "tests/epic_ruin_regression.lua").read_text(encoding="utf-8")
for rate, remaining, after_one_day in ((1, 3, 5), (modinfo.default, 3, 5), ("full", 1, 3), (None, 3, 5)):
    lua.globals().EpicRuinRate = rate
    lua.globals().ExpectedRemaining = remaining
    lua.globals().ExpectedAfterOneDay = after_one_day
    lua.globals().TheWorld.state.cycles = 10
    lua.execute(source)
    lua.execute(regression)
