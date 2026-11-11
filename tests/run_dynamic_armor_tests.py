"""Lua 5.1 regression using installed health/explosive/explosiveresist code.

Engine, combat dispatch and rendering are simulated; the mod integration and its
component are loaded unchanged. No player world or game installation is modified.
"""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

archive = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)
lua = LuaRuntime(unpack_returned_tuples=True)


def between(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]


with ZipFile(archive) as scripts:
    lua.execute(scripts.read("scripts/class.lua").decode("utf-8-sig"))
    health = scripts.read("scripts/components/health.lua").decode("utf-8-sig")
    lua.globals().health_source = (
        between(health, "function Health:OnLoad", "local FIRE_TIMEOUT")
        + between(health, "function Health:SetCurrentHealth", "return Health")
    )
    for name in ["explosive", "explosiveresist"]:
        lua.globals()[name + "_source"] = scripts.read("scripts/components/" + name + ".lua").decode("utf-8-sig")
    for phase in [1, 2]:
        source = scripts.read(f"scripts/prefabs/alterguardian_phase{phase}.lua").decode("utf-8-sig")
        lua.globals()[f"phase{phase}_source"] = between(source, "local function OnPhaseTransition", "\nend") + "\nend\nreturn OnPhaseTransition"

for field, path in {
    "component_source": "content/scripts/components/dynamicarmor2hm.lua",
    "integration_source": "content/epic/dynamic_armor.lua",
    "config_source": "content/modinfo.lua",
    "legacy_source": "content/epic/epic_armor.lua",
    "modeconfig_source": "content/scripts/combatconfig2hm.lua",
}.items():
    source = (ROOT / path).read_text(encoding="utf-8-sig")
    lua.eval("function(s) return assert(loadstring(s)) end")(source)
    lua.globals()[field] = source
main = (ROOT / "content/modmain.lua").read_text(encoding="utf-8-sig")
lua.eval("function(s) return assert(loadstring(s)) end")(main)
lua.globals().routing_source = between(main, '        local epic_armor_mode =', 'if GetModConfigData("epic_ruin")')
lua.execute((ROOT / "tests/dynamic_armor_regression.lua").read_text(encoding="utf-8-sig"))
