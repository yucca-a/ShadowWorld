"""Reproduce nameless-source crashes with installed native naming/health code."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/test-python'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    health = z.read('scripts/components/health.lua').decode('utf-8-sig')
    lua.globals().health_source = health[health.index('function Health:SetCurrentHealth'):health.index('return Health')]
    entity = z.read('scripts/entityscript.lua').decode('utf-8-sig')
    lua.globals().naming_source = entity[entity.index('function EntityScript:GetBasicDisplayName'):entity.index('--Can NOT be used on clients', entity.index('function EntityScript:GetDisplayName'))]
    lua.globals().adjective_source = z.read('scripts/dlcsupport_strings.lua').decode('utf-8-sig')
with ZipFile(ROOT / 'backups/releases/v2.8.15.0.7-content.zip') as z:
    lua.globals().published_source = z.read('common/bugfix.lua').decode('utf-8-sig')
lua.globals().upstream_source = Path('D:/SteamLibrary/steamapps/workshop/content/322330/2886753796/common/bugfix.lua').read_text(encoding='utf-8-sig')
lua.globals().fixed_source = (ROOT / 'content/common/bugfix.lua').read_text(encoding='utf-8-sig')
lua.execute((ROOT / 'tests/health_cause_regression.lua').read_text(encoding='utf-8-sig'))
