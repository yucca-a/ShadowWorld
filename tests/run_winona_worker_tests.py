"""Use actual beta closures/native modifier components to test future-update guards."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
upstream = Path("D:/SteamLibrary/steamapps/workshop/content/322330/3193922031/init/init_character_changes/winona.lua").read_text(encoding="utf-8-sig")
g.worker_source = upstream[:upstream.index("local function onrepaired")]
for key, file in {"guard_source": "umcompatguard2hm", "profiles_source": "umcompatprofiles2hm", "repair_source": "umwinonaworker2hm", "builder_source": "winonabuilder2hm"}.items():
    g[key] = (ROOT / f"content/scripts/{file}.lua").read_text(encoding="utf-8-sig")
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    for key, file in {"class_source": "class", "modifier_source": "util/sourcemodifierlist", "work_source": "components/workmultiplier", "efficient_source": "components/efficientuser"}.items():
        g[key] = z.read(f"scripts/{file}.lua").decode("utf-8-sig")
lua.execute((ROOT / "tests/winona_worker_regression.lua").read_text(encoding="utf-8-sig"))
