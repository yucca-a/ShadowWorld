"""Use installed Lua 5.1 oldager/eater/health and real watch/mod callbacks; no game launch."""
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

with ZipFile(archive) as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    for name in ["oldager", "eater"]:
        lua.globals()[name + "_source"] = z.read("scripts/components/" + name + ".lua").decode("utf-8-sig")
    health = z.read("scripts/components/health.lua").decode("utf-8-sig")
    lua.globals().health_source = between(health, "function Health:DoDelta(", "function Health:TransferComponent")
    watch = z.read("scripts/prefabs/pocketwatch.lua").decode("utf-8-sig")
    lua.globals().watch_source = between(watch, "local function Heal_DoCastSpell", "local MOUNTED_CAST_TAGS") + "\nreturn Heal_DoCastSpell"

lua.globals().regen_source = (ROOT / "content/role/regen.lua").read_text(encoding="utf-8-sig")
lua.globals().old_regen_source = (ROOT / "backups/wanda-regen-20261102/content/role/regen.lua").read_text(encoding="utf-8-sig")
role = (ROOT / "content/role/health.lua").read_text(encoding="utf-8-sig")
lua.globals().role_source = role[:role.index("-- 药膏")]
easy = (ROOT / "content/easy_role/wanda_easy.lua").read_text(encoding="utf-8-sig")
lua.globals().stop_source = between(easy, '-- 旺达不再持续衰老', '-- 旺达不老表回温')
strength = easy[easy.index('-- 2025.5.3 melon:旺达加强'):]
lua.globals().strength_source = between(strength, '    AddPrefabPostInit("wanda", function(inst)', '    -- 用原版的伤害计算覆盖妥协')
cracked = (ROOT / "content/scripts/prefabs/pocketwatch_heal2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().cracked_source = between(cracked, 'local function cancelmiss', 'local function healfn') + '\nreturn use2hm'
for name in ['content/role/regen.lua', 'content/easy_role/wanda_easy.lua']:
    lua.eval('function(s) return assert(loadstring(s)) end')((ROOT / name).read_text(encoding='utf-8-sig'))
lua.execute((ROOT / "tests/wanda_regen_regression.lua").read_text(encoding="utf-8-sig"))
