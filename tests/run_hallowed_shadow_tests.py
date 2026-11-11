"""Regression for native Halloween initialization before shadow stat scaling."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    pig = z.read("scripts/prefabs/pigman.lua").decode("utf-8-sig")
native_init = pig[pig.index("local function OnInit(inst)"):pig.index("local function ReplacePigToken(inst)")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().helper_source = (ROOT / "content/scripts/shadowhalloween2hm.lua").read_text(encoding="utf-8-sig")
lua.globals().native_init = native_init + "\nreturn OnInit"
lua.execute(r'''
local M = assert(loadstring(helper_source))()
local Init = assert(loadstring(native_init))()
SPECIAL_EVENTS={HALLOWED_NIGHTS=1,YOTP=2}
TUNING={HN_MONSTER_CHANCE=1}
function IsSpecialEventActive(event) return event==SPECIAL_EVENTS.HALLOWED_NIGHTS end
local checks=0
local function check(value,why) checks=checks+1;assert(value,why) end
local function pig(franken,prefab)
    local p={prefab=prefab or "pigman",franken=franken,_pigtokeninitialized=true,
        health=250,damage=30,calls=0,components={inventory={HasAnyEquipment=function()return false end}}}
    function p:HasTag() return false end
    function p:MakeFrankenPig() self.franken=true;self.health=1000;self.damage=100;self.calls=self.calls+1 end
    return p
end
local old=pig()
old.health=150;old.damage=15
Init(old)
check(old.franken and old.health==1000 and old.damage==100,"native deferred initializer reproduces a second form roll/stat reset")
for _,prefab in ipairs({"pigman","pigguard"}) do
    for _,franken in ipairs({false,true}) do
        local child=pig(false,prefab)
        M.Prepare({franken=franken},child)
        check((not not child.franken)==franken,"clone inherits parent's event form")
        check(child._frankeninitialized,"native event roll claimed before deferred initialization")
        child.health=150;child.damage=15
        Init(child)
        check(child.health==150 and child.damage==15,"deferred init preserves final shadow scaling")
        check(child.calls==(franken and 1 or 0),"native form initialized once")
        M.Prepare({franken=franken},child)
        check(child.calls==(franken and 1 or 0),"repeated preparation does not reset form stats")
    end
end
local child={prefab="merm",calls=0,MakeMummyMerm=function(self)self.mummy=true;self.calls=self.calls+1 end}
M.Prepare({mummy=true},child)
check(child.mummy and child.calls==1,"mummy inherited synchronously")
M.Prepare({mummy=true},child)
check(child.calls==1,"mummy conversion is idempotent")
local normal={prefab="merm",MakeMummyMerm=function()error("ordinary merm converted")end}
M.Prepare({},normal)
check(not normal.mummy and not normal._frankeninitialized,"ordinary merm unchanged")
M.Prepare({mummy=true,franken=true},{prefab="other"})
M.Prepare({franken=true},{prefab="pigman"})
check(true,"missing optional native conversion methods tolerated")
print("Halloween shadow initialization: "..checks.." checks passed")
''')
for path in [ROOT / "content/scripts/shadowhalloween2hm.lua", ROOT / "content/shadowworld.lua",
             ROOT / "tests/native/hallowed_population_probe.lua"]:
    lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8-sig"))
print("Changed Lua sources compile under Lua 5.1")
