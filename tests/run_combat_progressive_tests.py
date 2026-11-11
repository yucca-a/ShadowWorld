"""Lua 5.1: real game damage methods/components; engine entities/tasks simulated."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
archive = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)
with ZipFile(archive) as scripts:
    def read(name):
        return scripts.read("scripts/" + name + ".lua").decode("utf-8-sig")
    lua.execute(read("class"))
    lua.execute("native_sources = {}")
    for name in ["util/sourcemodifierlist", "components/spdamageutil", "components/weapon",
                 "components/damagetypebonus", "components/planardamage"]:
        lua.globals().native_sources[name] = read(name)
    combat = read("components/combat")
    lua.globals().native_calc_source = combat[combat.index("function Combat:CalcDamage"):
                                             combat.index("\nlocal function _CalcReflectedDamage")]
    start = combat.index("function Combat:GetAttacked_Internal")
    lua.globals().native_attacked_source = combat[start:combat.index("\nfunction Combat:", start + 1)]
    health = read("components/health")
    lua.globals().health_source = health[health.index("function Health:SetCurrentHealth"):health.index("return Health")]
    config = read("modindex")
    start = config.index("function ModIndex:UpdateConfigurationOptions(")
    lua.globals().native_options_update = "local ModIndex={}\n"+config[start:config.index("\nend",start)+4]+"\nreturn ModIndex.UpdateConfigurationOptions"
    config = read("screens/redux/modconfigurationscreen")
    start = config.index('Screen._ctor(self, "ModConfigurationScreen")')
    lua.globals().native_options_ctor = "return function(self,modname,client_config)\n"+config[start:config.index("self.started_default",start)]+"\nend"

lua.execute("mod_sources = {}")
for name in ["scripts/progressivecombat2hm.lua", "scripts/combatdisplay2hm.lua", "scripts/combatconfig2hm.lua",
             "scripts/components/dynamicarmor2hm.lua", "role/combat.lua", "role/combat_progressive.lua",
             "epic/dynamic_armor.lua", "modinfo.lua"]:
    source = (ROOT / "content" / name).read_text(encoding="utf-8-sig")
    lua.eval("function(s) return assert(loadstring(s)) end")(source)
    lua.globals().mod_sources[name] = source
willow = (ROOT / "content/role/willow.lua").read_text(encoding="utf-8-sig")
lua.globals().willow_flame_wrapper = willow[willow.index("-- 月/影火不吃伤害倍率加成"):
                                          willow.index("-- 2025.9.3", willow.index("-- 月/影火不吃伤害倍率加成"))]
lua.execute((ROOT / "tests/combat_progressive_regression.lua").read_text(encoding="utf-8-sig"))
