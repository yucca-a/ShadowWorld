"""Exercise the game's require loader against old and current workshop indices."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
sys.path.insert(0, str(ROOT / "tests"))
from lupa.lua51 import LuaRuntime, LuaError
from update_mod_manifest import audit, decode, path_hash

sys.stdout.reconfigure(encoding="utf-8")
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    main = z.read("scripts/main.lua").decode("utf-8-sig")
loader_source = main[main.index("local manifest_paths = {}"):main.index("table.insert(package.loaders, 2, loadfn)")]
loader_source += "table.insert(package.loaders, 2, loadfn)"
bootstrap = (ROOT / "content/modmain.lua").read_text(encoding="utf-8-sig").split('-- 本模组需要的一些设定的通用补充', 1)[0]
with ZipFile(ROOT / "backups/merges/20261110-104808/workshop-2.8.15.0.18.zip") as z:
    old_index = set(decode(z.read("mod.manifest")))

modules = ["shadowhalloween2hm", "bootlegnonslip2hm", "exchangexianyurecovery2hm"]
sources = {f"scripts/{name}.lua": (ROOT / f"content/scripts/{name}.lua").read_text(encoding="utf-8-sig") for name in modules}
checks = 0


def check(value, message):
    global checks
    checks += 1
    assert value, message


def runtime(index, available=None, manager=True):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    lua.execute(r'''
GLOBAL=_G
modname="workshop-3832182265"
MODS_ROOT="../mods/"
function IsWorkshopMod(name)return name~=nil and name:sub(1,9)=="workshop-"end
package.path="../mods/workshop-3832182265\\scripts\\?.lua;scripts\\?.lua"
RequiredFilesForReload={}
TheSim={GetFileModificationTime=function()return 0 end}
''')
    index = set(index) if index is not None else None
    available = dict(sources) if available is None else available
    compile_source = lua.eval("function(source,name)return assert(loadstring(source,name))end")

    def load(filename, manifest=None, relative=None):
        if not filename.startswith("../mods/workshop-3832182265/"):
            return None
        if manifest is not None and index is not None and path_hash(relative) not in index:
            return None
        path = filename.removeprefix("../mods/workshop-3832182265/")
        return compile_source(available[path], filename) if path in available else None

    def register(_self, name, path):
        assert name == "workshop-3832182265"
        if index is not None:
            index.add(path_hash(path))

    g.kleiloadlua = load
    if manager:
        g.ManifestManager = lua.table_from({"AddFileToModManifest": register})
    lua.execute(loader_source)
    return lua, index


def require(lua, module):
    # Evaluate inside Lua so failure uses the game's normal require error path.
    return lua.eval("function(name)return require(name)end")(module)


lua, index = runtime(old_index)
for name in modules:
    try:
        require(lua, name)
    except LuaError as error:
        check(f"module '{name}' not found" in str(error), "old index reproduces module-not-found startup failure")
    else:
        raise AssertionError("Old workshop index unexpectedly resolved new module")
lua.execute(bootstrap)
for name in modules:
    check(require(lua, name) is not None, "registered module loads with native require loader")
    check(lua.globals().RequiredFilesForReload[f"../mods/workshop-3832182265/scripts/{name}.lua"] is not None,
          "native reload bookkeeping preserved")
before = set(index)
lua.execute(bootstrap)
check(index == before, "bootstrap registration is idempotent")
lua.execute('local M=require("shadowhalloween2hm");local c={prefab="pigman"};M.Prepare({},c);assert(c._frankeninitialized)')
check(True, "loaded Halloween helper retains its actual behavior")

fresh = set(decode((ROOT / "content/mod.manifest").read_bytes()))
lua, _ = runtime(fresh)
for name in modules:
    check(require(lua, name) is not None, "current checked-in manifest resolves module without repair")

lua, _ = runtime(None, manager=False)
lua.execute(bootstrap)
for name in modules:
    check(require(lua, name) is not None, "non-manifest/local loading remains supported")

lua, _ = runtime(None)
lua.execute('modname="ShadowWorld";ManifestManager.AddFileToModManifest=function()error("local mod index modified")end')
lua.execute(bootstrap)
check(True, "local mods with a manifest manager do not create a partial workshop index")

lua, _ = runtime(old_index, {path: source for path, source in sources.items() if "shadowhalloween" not in path})
lua.execute(bootstrap)
try:
    require(lua, "shadowhalloween2hm")
except LuaError:
    check(True, "genuinely missing file remains an error rather than silently disabling fixes")
else:
    raise AssertionError("Missing physical module silently accepted")

check(audit(ROOT / "content") == sum(p.is_file() for p in (ROOT / "content").rglob("*")),
      "all current package paths are indexed")
print(f"Native require / manifest regressions: {checks} checks passed")
