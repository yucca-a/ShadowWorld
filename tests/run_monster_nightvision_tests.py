"""Execute native playervision and both installed UM vision/HUD implementations."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile(sys.argv[1] if len(sys.argv) > 1 else
             "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().vision_source = z.read("scripts/components/playervision.lua").decode("utf-8-sig")
    lua.globals().grue_source = z.read("scripts/components/grue.lua").decode("utf-8-sig")
    native = z.read("scripts/simutil.lua").decode("utf-8-sig")
    start = native.index("local function _CanEntitySeeInDark(")
    end = native.index("\nlocal function _CanEntitySeeInStorm", start)
    lua.globals().see_source = native[start:end]
    wortox = z.read("scripts/prefabs/wortox.lua").decode("utf-8-sig")
    assert 'inst:AddTag("monster")' in wortox and 'inst:RemoveTag("monster")' in wortox
    woodie = z.read("scripts/prefabs/woodie.lua").decode("utf-8-sig")
    start = woodie.index("local BEAVERVISION_COLOURCUBES =")
    end = woodie.index("\nend", woodie.index("local function IsWereMode(")) + 4
    prefix = woodie[start:end]
    start = woodie.index("local function SetWereVision(")
    end = woodie.index("\nend", start) + 4
    lua.globals().were_vision_source = prefix + "\n" + woodie[start:end] + "\nreturn SetWereVision"
for version, mod in [("stable", "2039181790"), ("beta", "3193922031")]:
    root = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{mod}/scripts")
    path = root / "prefabs/wathom.lua"
    source = path.read_text(encoding="utf-8-sig")
    start = source.index("local function CheckLight(")
    end = source.index("\nend", start) + 4
    lua.globals()[version + "_check"] = (
        'local NIGHTVISION_CCS = {test = {night = "um_sonar"}}\n' + source[start:end] + "\nreturn CheckLight"
    )
    lua.globals()[version + "_path"] = "@" + path.as_posix()
    lua.globals()[version + "_widget"] = (root / "widgets/wathom_sonar.lua").read_text(encoding="utf-8-sig")
lua.globals().patch_source = (ROOT / "content/common/monster_nightvision.lua").read_text(encoding="utf-8-sig")
lua.globals().config_source = (ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig")
lua.globals().dusk_source = (ROOT / "content/weather/dusk.lua").read_text(encoding="utf-8-sig")
lua.globals().fenghua_source = Path(
    "D:/SteamLibrary/steamapps/workshop/content/322330/3413376081/modtable/13.lua"
).read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/monster_nightvision_regression.lua").read_text(encoding="utf-8-sig"))
