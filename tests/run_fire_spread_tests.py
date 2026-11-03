"""Compare actual native heat/smolder/ignite code with upstream/current hooks.

Only the entity registry, scheduler and visual effects are simulated. No new
production fire algorithm is used. Also exercises the installed UM beta hooks.
"""
from pathlib import Path
from zipfile import ZipFile
import subprocess
import sys
import re

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
scripts = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")
with ZipFile(scripts) as archive:
    lua.execute(archive.read("scripts/class.lua").decode("utf-8-sig", errors="replace"))
    for name in ["easing", "util/sourcemodifierlist"]:
        lua.globals().module_source = archive.read("scripts/" + name + ".lua").decode("utf-8-sig", errors="replace")
        lua.execute(f'package.preload["{name}"] = assert(loadstring(module_source))')
    lua.execute('package.preload["prefabs/willow_ember_common"] = function() return {} end')
    lua.globals().propagator_source = archive.read("scripts/components/propagator.lua").decode("utf-8-sig", errors="replace")
    lua.globals().burnable_source = archive.read("scripts/components/burnable.lua").decode("utf-8-sig", errors="replace")
    standard = archive.read("scripts/standardcomponents.lua").decode("utf-8-sig", errors="replace")
    for name in ["DefaultIgniteFn", "MakeSmallPropagator", "MakeMediumPropagator", "MakeLargePropagator"]:
        start = standard.index("function " + name + "(")
        lua.execute(standard[start:standard.index("\nend", start) + 4])
    lua.globals().campfire_source = archive.read("scripts/prefabs/campfire.lua").decode("utf-8-sig", errors="replace")
    tuning = archive.read("scripts/tuning.lua").decode("utf-8-sig", errors="replace")
    seg_time = re.search(r'local seg_time\s*=\s*([^\r\n]+)', tuning).group(1)
    values = []
    for key in ["SPRING_FIRE_RANGE_MOD", "MIN_SMOLDER_TIME", "MAX_SMOLDER_TIME"]:
        value = re.search(r'^\s*' + key + r'\s*=\s*([^,\r\n]+)', tuning, re.M).group(1)
        values.append(key + '=' + value)
    lua.execute('native_fire_tuning = (function() local seg_time=' + seg_time + '\nreturn {' + ','.join(values) + '} end)()')

def upstream(path):
    return subprocess.check_output(["git", "show", "upstream-v2.8.14.95:content/" + path], cwd=ROOT).decode("utf-8-sig", errors="replace")

def source(path):
    return (ROOT / "content" / path).read_text(encoding="utf-8-sig")

def propagation_hook(text):
    start = text.index('AddComponentPostInit("propagator"')
    return text[start:text.index("\nend)", start) + 5]

lua.globals().baseline_patch = propagation_hook(upstream("common/patch.lua"))
lua.globals().current_patch = propagation_hook(source("common/patch.lua"))
lua.globals().baseline_willow = upstream("easy_role/willow_easy.lua")
lua.globals().current_willow = source("easy_role/willow_easy.lua")
lua.globals().turret_source = source("easy_other/eyeturret2hm.lua")
um = Path("D:/SteamLibrary/steamapps/workshop/content/322330/3193922031")
lua.globals().um_propagator = (um / "postinit/components/propagator.lua").read_text(encoding="utf-8-sig")
lua.globals().um_burnable = (um / "postinit/components/burnable.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/fire_spread_regression.lua").read_text(encoding="utf-8-sig"))
