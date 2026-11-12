"""Native drain callbacks and Weapon:OnAttack, plus the actual reward filters."""
from pathlib import Path
from zipfile import ZipFile
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
g=lua.globals()
def between(s,a,b):return s[s.index(a):s.index(b,s.index(a))]
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")as z:
    read=lambda n:z.read('scripts/'+n+'.lua').decode('utf-8-sig').replace('\r\r\n','\n')
    g.bat_source=between(read('prefabs/batbat'),'local function onattack','local function fn')+'return onattack'
    g.axe_source=between(read('prefabs/shadow_battleaxe'),'local function DoLifeSteal','local function OnAttack')+'return DoLifeSteal'
    g.weapon_source=between(read('components/weapon'),'function Weapon:OnAttack','function Weapon:LaunchProjectile')
    g.life_source=between(read('componentutil'),'function IsLifeDrainable','--------------------------------------------------------------------------')
    constants=read('componentutil')
    g.tags_source=re.search(r'NON_LIFEFORM_TARGET_TAGS\s*=\s*\{[^}]+\}',constants).group()
for key,name in [('benefits_source','scripts/combatbenefits2hm.lua'),('patch_source','common/combat_rewards.lua'),('guard_source','scripts/umcompatguard2hm.lua')]:
    g[key]=(ROOT/'content'/name).read_text(encoding='utf-8-sig')
s=(ROOT/'content/easy_other/easy_equipments.lua').read_text(encoding='utf-8-sig')
g.victim_source=between(s,'    local nocreaturetags =','    local function endeatattackertask')+'return IsValidVictim'
s=(ROOT/'content/easy_other/lunar_shadow_items.lua').read_text(encoding='utf-8-sig')
g.extra_source=between(s,'local function SBAOnAttack','local function addhorn')+'return SBAOnAttack'
g.wathom_sources=lua.table_from([between(Path('D:/SteamLibrary/steamapps/workshop/content/322330/'+uid+'/scripts/prefabs/wathom.lua').read_text(encoding='utf-8-sig'),'local function OnAttackOther','local function OnHealthDelta')+'return OnAttackOther' for uid in ['2039181790','3193922031']])
lua.execute((ROOT/'tests/combat_rewards_regression.lua').read_text(encoding='utf-8-sig'))
