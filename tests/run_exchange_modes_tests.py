"""Current Shadow Nexus names, legacy settings, installation and native-flow gates."""
from pathlib import Path
from zipfile import ZipFile
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
loader=lua.eval('function(s,n)return assert(loadstring(s,n))end')
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
    util=z.read('scripts/util.lua').decode('utf-8-sig');a=util.index('function deepcopy(');lua.execute(util[a:util.index('\nend',a)+4])
for name,path in {'info_source':'modinfo.lua','entry_source':'easy_other/shadowvault.lua','player_source':'easy_other/shadowvaultplayer.lua','main_source':'modmain.lua','legacy_source':'scripts/components/worldexchange2hm.lua'}.items():
    text=(ROOT/'content'/path).read_text(encoding='utf-8-sig');loader(text,path);lua.globals()[name]=text
lua.globals().Config=loader((ROOT/'content/scripts/shadowvaultconfig2hm.lua').read_text(encoding='utf-8'),'config')()
lua.execute((ROOT/'tests/exchange_modes_regression.lua').read_text(encoding='utf-8'))
# Resolve live module/import references, keeping retired sources out of content.
import re
retired={'worldexchangeengine2hm','worldexchangecheckpoint2hm','worldexchangeinstant2hm','worldexchangemaps2hm','shadowvaultsnapshot2hm','shadowvaultsnapshotcore2hm','shadowvaultmovement2hm'}
for path in (ROOT/'content').rglob('*.lua'):
    s=path.read_text(encoding='utf-8-sig')
    for name in re.findall(r'require\(["\']([^"\']+)["\']\)',s):
        assert name not in retired,(path,name)
    assert 'modimport("easy_other/worldexchange' not in s,path
print('Live runtime dependency scan: no retired coordinator imports')
