"""Run actual station hooks, including the foreign client's preview clone flow."""
from pathlib import Path
from zipfile import ZipFile
import argparse,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-ref')
parser.add_argument('--preview-source', default="D:/SteamLibrary/steamapps/workshop/content/322330/3161117403/scripts/util/entutil.lua")
args=parser.parse_args()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path = str(ROOT/'content/scripts/?.lua').replace('\\','/') + ';' + lua.globals().package.path
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read('scripts/dumper.lua').decode('utf-8-sig'))
source=(subprocess.check_output(['git','show',f'{args.source_ref}:content/easy_other/easy_structures.lua'],cwd=ROOT).decode('utf-8-sig') if args.source_ref else (ROOT/'content/easy_other/easy_structures.lua').read_text(encoding='utf-8-sig'))
lua.globals().structure_source=source
lua.eval('function(s)return assert(loadstring(s))end')((ROOT/'tests/native/prototyper_private_space_fixture.lua').read_text(encoding='utf-8'))
# This is the exact method responsible for the reported removal call. Keep its
# native ordering: ismastersim is restored only AFTER the preview is removed.
foreign=Path(args.preview_source).read_text(encoding='utf-8-sig')
start=foreign.index('function EntUtil:ClonePrefab(')
lua.globals().clone_source=foreign[start:foreign.index('\nend',start)+4]
lua.execute((ROOT/'tests/prototyper_preview_regression.lua').read_text(encoding='utf-8'))
