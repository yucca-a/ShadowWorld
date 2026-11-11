"""Build a portable protected Lua release; maintenance sources remain under ignored work/."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import secrets
import shutil
import zlib

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT / "server_mods/tianxing_guard"
PRIVATE = ROOT / "work/tianxing_guard_private/source"
PROTECTED = ("modmain.lua", "scripts/tianxing_guard.lua", "scripts/tianxing_guard_watch.lua")


def crypt(data, key):
    state = list(range(256))
    j = 0
    for i in range(256):
        j = (j + state[i] + key[i % len(key)]) % 256
        state[i], state[j] = state[j], state[i]
    i = j = 0
    result = bytearray()
    for byte in data:
        i = (i + 1) % 256
        j = (j + state[i]) % 256
        state[i], state[j] = state[j], state[i]
        result.append(byte ^ state[(state[i] + state[j]) % 256])
    return bytes(result)


def protect(source, modmain):
    # Drop only whole-line comments; preserve all Lua tokens and string contents.
    text = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith("--")) + "\n"
    raw = text.encode("utf-8")
    key = secrets.token_bytes(32)
    payload = crypt(raw, key).hex()
    assert crypt(bytes.fromhex(payload), key) == raw
    environment = "GLOBAL" if modmain else "_G"
    # No bit library, external module, bytecode ABI or OS-specific dependency.
    template = '''-- TXG_PROTECTED_1: generated release, keep maintenance sources outside the mod.
local g=__GLOBAL__
local e=g.getfenv(1)
local c,t,n=g.string.char,g.table.concat,g.tonumber
local k={__KEY__}
local h="__PAYLOAD__"
local s={}
for i=0,255 do s[i]=i end
local j=0
for i=0,255 do j=(j+s[i]+k[i%#k+1])%256;s[i],s[j]=s[j],s[i] end
local function x(a,b)
 local v,p=0,1
 while a>0 or b>0 do
  local q,r=a%2,b%2
  if q~=r then v=v+p end
  a,b,p=(a-q)/2,(b-r)/2,p*2
 end
 return v
end
local out,i,a,b={},0,1,0
j=0
for p=1,#h,2 do
 i=(i+1)%256;j=(j+s[i])%256;s[i],s[j]=s[j],s[i]
 local v=x(n(g.string.sub(h,p,p+1),16),s[(s[i]+s[j])%256])
 out[#out+1]=c(v);a=(a+v)%65521;b=(b+a)%65521
end
if #out~=__SIZE__ or b*65536+a~=__CHECK__ then g.error("TXG protected payload corrupted",0) end
local f,err=g.loadstring(t(out),"@tianxing_guard/protected")
if not f then g.error(err,0) end
g.setfenv(f,e)
return f(...)
'''
    return (template.replace("__GLOBAL__", environment)
            .replace("__KEY__", ",".join(str(v) for v in key))
            .replace("__PAYLOAD__", payload)
            .replace("__SIZE__", str(len(raw)))
            .replace("__CHECK__", str(zlib.adler32(raw) & 0xffffffff)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="0.1.1")
    args = parser.parse_args()
    if not PRIVATE.exists():
        if "TXG_PROTECTED_1" in (RELEASE / "modmain.lua").read_text(encoding="utf-8"):
            raise SystemExit("Missing maintenance source; refusing to wrap protected output again")
        shutil.copytree(RELEASE, PRIVATE)
    meta = (PRIVATE / "modinfo.lua").read_text(encoding="utf-8")
    meta = re.sub(r'version = "[^"]+"', f'version = "{args.version}"', meta)
    (RELEASE / "modinfo.lua").write_text(meta, encoding="utf-8")
    manifest = {"version": args.version, "maintenance_source": str(PRIVATE), "files": {}}
    for name in PROTECTED:
        clear = (PRIVATE / name).read_text(encoding="utf-8")
        packed = protect(clear, name == "modmain.lua")
        assert clear not in packed
        (RELEASE / name).write_text(packed, encoding="utf-8")
        manifest["files"][name] = {"source_sha256": hashlib.sha256(clear.encode()).hexdigest(),
                                    "release_sha256": hashlib.sha256(packed.encode()).hexdigest()}
    readme = f'''# 天行卫（服务端防护）{args.version}

在世界的服务器模组列表启用，地上与洞穴均应启用，随后重启世界。玩家无需安装。

拦截目前的异常移动校正与伪造地图投递解控。确认持续异常后，播报玩家名称、行为类型和5至1秒倒计时，共5条；5秒内停止异常请求不踢出，截止后仍继续才踢出，不封号。

“异常持续时自动踢出”默认开启。关闭后仍拦截和播报，但不会踢出。

本版本的核心Lua已做加密封装，模组名称和配置按原版要求保留可读格式。封装只能增加阅读与修改成本，不能保证代码不可还原，也不是通用反作弊。正常观察不单独作为处罚依据；合法装备加速仍由原版处理。

维护源码与构建工具不随模组分发。运行时不下载代码、不连接额外服务、不依赖外部解密库。损坏的载荷会在执行前停止加载。
'''
    (RELEASE / "README.md").write_text(readme, encoding="utf-8")
    path = PRIVATE.parent / "protected-build.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Built {args.version}: 3 protected Lua files; metadata left compatible with native loader.")


if __name__ == "__main__":
    main()
