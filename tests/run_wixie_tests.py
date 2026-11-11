"""Read actual stable/Beta Wixie fear algorithms and native configuration code."""
from pathlib import Path
from zipfile import ZipFile
import sys, subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().combatconfig_source=(ROOT/'content/scripts/combatconfig2hm.lua').read_text(encoding='utf-8-sig')
lua.execute('package.preload["combatconfig2hm"]=assert(loadstring(combatconfig_source))')
for key, file in {"fear_patch": "easy_role/wixie_easy.lua", "role_patch": "role/walter.lua",
                  "access_patch": "common/walter_wixie_slingshot.lua",
                  "config_patch": "scripts/wixieconfig2hm.lua", "modinfo_source": "modinfo.lua"}.items():
    lua.globals()[key] = (ROOT / "content" / file).read_text(encoding="utf-8-sig")
lua.globals().old_role = subprocess.check_output(["git", "show", "4a2b4ad:content/role/walter.lua"], cwd=ROOT).decode("utf-8-sig")
for key, mod in [("beta_fear", "3193922031"), ("stable_fear", "2039181790")]:
    path = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{mod}/scripts/prefabs/wixie.lua")
    source = path.read_text(encoding="utf-8-sig")
    start = source.index("local function GetClaustrophobia(")
    end = source.index("\nend", source.index("local function OnInit(")) + 4
    lua.globals()[key] = source[start:end] + "\nreturn {get=GetClaustrophobia,can=CanGainClaustrophobia,init=OnInit,equip=EquipedCount,unequip=EquipUnequipCount,newstate=OnNewState,panic=ClaustrophobiaPanic}"
    lua.globals()[key + "_path"] = "@" + path.as_posix()
    source = (path.parents[2] / "wixie_postinit/prefabs/slingshot.lua").read_text(encoding="utf-8-sig")
    start = source.index("local function can_cast_fn(")
    end = source.index('\nenv.AddPrefabPostInit("slingshot"', start)
    lua.globals()[key + "_cast"] = source[start:end] + "\nreturn can_cast_fn"
    for graph in ["SGwixie", "SGwixie_client"]:
        source = (path.parents[2] / ("wixie_postinit/stategraphs/" + graph + ".lua")).read_text(encoding="utf-8-sig")
        start = source.index("    local _OldAttack =")
        end = source.index("    local _OldBuild =", start)
        lua.globals()[key + "_" + graph] = "return function(inst)\n" + source[start:end] + "\nend"
common = (ROOT / "content/common/common.lua").read_text(encoding="utf-8-sig")
start = common.index("function RemoveSpeedUpState2hm(")
end = common.index("\nend", common.index("function SpeedUpState2hm(")) + 4
lua.globals().native_speed = common[start:end]
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    for graph in ["SGwilson", "SGwilson_client"]:
        source = z.read("scripts/stategraphs/" + graph + ".lua").decode("utf-8-sig")
        start = source.index("ActionHandler(ACTIONS.ATTACK,") + len("ActionHandler(ACTIONS.ATTACK,")
        end = source.index("ActionHandler(", start)
        lua.globals()[graph + "_attack"] = "return " + source[start:end].strip().removesuffix(",").removesuffix(")")
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.execute('package.loaded["class"] = Class')
    lua.execute(z.read("scripts/stategraph.lua").decode("utf-8-sig"))
    for key, name in [("server_restricted", "equippable"), ("client_restricted", "equippable_replica")]:
        source = z.read(f"scripts/components/{name}.lua").decode("utf-8-sig")
        start = source.index("function Equippable:IsRestricted(")
        end = source.index("\nfunction ", start + 1)
        lua.globals()[key] = "local Equippable={}\n" + source[start:end] + "\nreturn Equippable.IsRestricted"
    source = z.read("scripts/screens/redux/modconfigurationscreen.lua").decode("utf-8-sig")
    start = source.index('Screen._ctor(self, "ModConfigurationScreen")')
    end = source.index("self.started_default", start)
    lua.globals().native_config_ctor = "return function(self, modname, client_config)\n" + source[start:end] + "\nend"
    start = source.index("function ModConfigurationScreen:CollectSettings(")
    lua.globals().native_collect = source[start:source.index("\nend", start) + 4]
lua.execute((ROOT / "tests/wixie_regression.lua").read_text(encoding="utf-8-sig"))
