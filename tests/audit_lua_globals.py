"""Compile every shipped Lua file and inventory actual SETGLOBAL bytecodes."""
from pathlib import Path
import sys, json, struct
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(encoding=None,unpack_returned_tuples=True)
compilelua=lua.eval(b'function(s,n) local f,e=loadstring(s,n);if not f then return nil,e end;return string.dump(f) end')

class Chunk:
    def __init__(self,b):
        self.b=b;self.p=12;self.endian='<' if b[6] else '>';self.sz=b[8];self.num=b[10];self.writes=[]
    def read(self,n):
        value=self.b[self.p:self.p+n];self.p+=n;return value
    def integer(self):return struct.unpack(self.endian+'I',self.read(4))[0]
    def string(self):
        n=int.from_bytes(self.read(self.sz),'little' if self.endian=='<' else 'big')
        return self.read(n)[:-1].decode('utf-8',errors='replace') if n else ''
    def function(self):
        self.string();start=self.integer();self.integer();self.read(4)
        code=[self.integer() for _ in range(self.integer())]
        constants=[]
        for _ in range(self.integer()):
            tag=self.read(1)[0]
            if tag==0:constants.append(None)
            elif tag==1:constants.append(self.read(1)[0])
            elif tag==3:constants.append(self.read(self.num))
            elif tag==4:constants.append(self.string())
            else:raise ValueError(tag)
        for _ in range(self.integer()):self.function()
        lines=[self.integer() for _ in range(self.integer())]
        for _ in range(self.integer()):self.string();self.integer();self.integer()
        for _ in range(self.integer()):self.string()
        for pc,op in enumerate(code):
            if op&63==7:self.writes.append({'line':lines[pc] if lines else start,'name':constants[op>>14]})

report={'files':0,'syntax_errors':[],'global_writes':{}}
for p in sorted((ROOT/'content').rglob('*.lua')):
    name=p.relative_to(ROOT/'content').as_posix();report['files']+=1
    result=compilelua(p.read_text(encoding='utf-8-sig').encode(),('@'+name).encode())
    if isinstance(result,tuple):report['syntax_errors'].append({'file':name,'error':result[1].decode()});continue
    chunk=Chunk(result);chunk.function();assert chunk.p==len(result)
    if chunk.writes:report['global_writes'][name]=sorted(chunk.writes,key=lambda row:row['line'])
path=ROOT/'work/lua-global-audit.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Compiled',report['files'],'Lua files; syntax errors:',len(report['syntax_errors']))
for name,rows in report['global_writes'].items():
    if name.startswith('scripts/'):
        print(name,', '.join(str(r['line'])+':'+r['name'] for r in rows))
raise SystemExit(bool(report['syntax_errors']))
