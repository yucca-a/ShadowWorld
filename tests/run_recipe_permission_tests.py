"""Verify actual server/client custom recipe checks keep native deny rules."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
source=(ROOT/'content/tech/prototyperlevel.lua').read_text(encoding='utf-8-sig')
for key,name in [('server_source','newKnowsRecipe'),('client_source','newReplicaKnowsRecipe')]:
 start=source.index('local function '+name+'(')
 end=source.index('\nend',start)+4
 lua.globals()[key]='local TechTree={AVAILABLE_TECH={}}\n'+source[start:end]+'\nreturn '+name
lua.execute(r'''
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
table.contains=function(t,v)for _,x in ipairs(t)do if x==v then return true end end return false end
local server=assert(loadstring(server_source))()
local client=assert(loadstring(client_source))()
local tags,skills={},{}
local inst={components={},HasTag=function(self,tag)return tags[tag]or false end}
inst.components.skilltreeupdater={IsActivated=function(self,skill)return skills[skill]or false end}
local recipe={name='test',level={}}
function GetValidRecipe()return recipe end
local s={inst=inst,recipes={'test'},station_recipes={}}
local c={inst=inst,classified={isfreebuildmode={value=function()return false end},recipes={test={value=function()return true end}},bufferedbuilds={},_bufferedbuildspreview={}}}
for _,fn in ipairs({server,client})do
 local target=fn==server and s or c
 recipe.builder_tag='owner';recipe.no_builder_tag='forbidden';recipe.builder_skill='learned';recipe.no_builder_skill='excluded'
 tags.owner=true;skills.learned=true
 check(fn(target,recipe),'normal owned skill recipe')
 tags.forbidden=true;check(not fn(target,recipe),'deny tag wins over previously learned recipe')
 tags.forbidden=nil;skills.excluded=true;check(not fn(target,recipe),'deny skill wins over learned recipe')
 skills.excluded=nil;skills.learned=nil;check(not fn(target,recipe),'positive skill still required')
 skills.learned=true;tags.owner=nil;check(not fn(target,recipe),'positive tag still required')
 tags.owner=true;inst.components.skilltreeupdater=nil;check(not fn(target,recipe),'missing skill updater denies skill recipe safely')
 recipe.builder_skill=nil;check(fn(target,recipe),'absence of excluded skill is allowed')
 inst.components.skilltreeupdater={IsActivated=function(self,skill)return skills[skill]or false end}
end
print('Recipe permission server/client regressions: '..checks..' passed')
''')
