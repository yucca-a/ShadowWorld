"""Vault custody regressions, using the native Lua 5.1 serializer and protocol."""
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(ROOT/"tests/run_world_exchange_tests.py"))
lua,loader=base["lua"],base["loader"]
for path in (ROOT/"content").rglob("*shadowvault*.lua"):
    loader(path.read_text(encoding="utf-8-sig"),str(path))
lua.execute('package.preload["components/worldexchange2hm"]=function()return WorldExchange end; package.preload["json"]=function()return {encode=function()return "{}" end} end')
for name in ("exchangemode2hm","components/exchangevariants2hm","worldexchangestore2hm","worldexchangeinstant2hm","shadowvaultmovement2hm","shadowvaultsnapshotcore2hm","shadowvaultsnapshot2hm","shadowvaultcourier2hm",
             "shadowvaultnative2hm","shadowvaultshared2hm","shadowvaultconfig2hm","shadowvaultproxy2hm","shadowvaultio2hm","shadowvaulttransport2hm","shadowvaultdurable2hm","shadowvaultjournal2hm","components/shadowvault2hm"):
    path=ROOT/"content/scripts"/(name+".lua")
    if not path.exists():path=ROOT/"development/retired-world-coordination-20261106/content/scripts"/(name+".lua")
    fn=loader(path.read_text(encoding="utf-8"),name)
    lua.globals().module_loader=fn
    lua.execute('package.preload["'+name+'"]=module_loader')
lua.execute('''package.preload["prefabs/pocketdimensioncontainer_defs"]=function()return {POCKETDIMENSIONCONTAINER_DEFS={
{name="shadow",prefab="shadowvaultpage2hm"},{name="tacklestation2hm",prefab="shadowvaulttacklepage2hm"}}}end''')
lua.execute((ROOT/"tests/shadow_vault_regression.lua").read_text(encoding="utf-8"))
lua.execute((ROOT/"tests/shadow_vault_movement_regression.lua").read_text(encoding="utf-8"))
lua.execute((ROOT/"tests/shadow_vault_snapshot_regression.lua").read_text(encoding="utf-8"))
lua.execute((ROOT/"tests/shadow_vault_travel_regression.lua").read_text(encoding="utf-8"))
with ZipFile(base["scripts"]) as archive:
    native=archive.read("scripts/containers.lua").decode("utf-8-sig")
    start=native.index("params.shadowchester =")
    end=native.index("--[[ rabbitkinghorn ]]",start)
    setup=native[native.index("function containers.widgetsetup("):native.index("\nend",native.index("function containers.widgetsetup("))+4]
    lua.execute('Vector3=function(x,y,z)return {x=x,y=y,z=z}end; nativecontainers={params={}}')
    lua.execute('local containers=nativecontainers;local params=containers.params\n'+setup+'\n'+native[start:end])
    lua.execute('package.preload["containers"]=function()return nativecontainers end; package.loaded["containers"]=nil')
    entry=(ROOT/"content/easy_other/shadowvault.lua").read_text(encoding="utf-8")
    lua.execute(entry[:entry.index("TUNING.SHADOWVAULT_ENABLED2HM")])
    lua.globals().NativeContainerReplica=loader(archive.read("scripts/components/container_replica.lua").decode("utf-8-sig"),"native container replica")()
lua.execute('''
TheWorld={ismastersim=false}
net_bool=function()return {}end
local replica=NativeContainerReplica({GUID=900,prefab="shadowvaultpage2hm"})
assert(replica:GetNumSlots()==12 and replica.widget.animbank=="ui_portal_shadow_3x4","client page must resolve the native shadow layout")
local hidden=NativeContainerReplica({GUID=901,prefab="shadowvaulttransfer2hm"})
assert(hidden:GetNumSlots()==1,"hidden escrow replica has the same capacity as its server container")
print("Native client container layout: 2 checks passed")
''')

lua.execute((ROOT/"tests/shadow_vault_native_regression.lua").read_text(encoding="utf-8"))
lua.execute((ROOT/"tests/shadow_vault_shared_regression.lua").read_text(encoding="utf-8"))
lua.globals().SHARED_HOOK_SOURCE=str(ROOT/"content/easy_other/shadowvaultshared.lua")
lua.execute((ROOT/"tests/shadow_vault_shared_hooks_regression.lua").read_text(encoding="utf-8"))
