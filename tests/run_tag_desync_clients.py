"""Sequential independent offline clients on an owned native dedicated server."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,sys,time,traceback,zipfile,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,GAME
sys.stdout.reconfigure(encoding='utf-8')
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,default=ROOT/'content')
p.add_argument('--clients',type=int,default=3)
p.add_argument('--legion',action='store_true')
p.add_argument('--tagmod',action='store_true')
p.add_argument('--um',action='store_true')
p.add_argument('--newconstant',action='store_true')
p.add_argument('--crosspatch',action='store_true')
p.add_argument('--extra-mod',action='append',default=[],help='Additional installed or researched workshop ID')
p.add_argument('--characters',default='wilson,wilson,wilson')
p.add_argument('--internal-tags',type=int,default=0)
p.add_argument('--trace-netvars',action='store_true')
p.add_argument('--pressure-tags',type=int,default=0)
p.add_argument('--reconnect-third',action='store_true')
p.add_argument('--calm-world',action='store_true',help='Disable shadow and elite creature variants for isolation')
a=p.parse_args()
a.characters=','.join('wathgrithr'if name=='wigfrid'else name for name in a.characters.split(','))
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',a.source.resolve())
children=[];logs=[];client_commands=[]
report={'cluster':str(c.out),'options':vars(a)|{'source':str(a.source)},'status':'running'}
def rows(log):
    raw=log.read_text(encoding='utf-8',errors='replace') if log.exists()else''
    data=[]
    for line in raw.splitlines():
        if '[TAG AUDIT] 'in line:
            try:data.append(json.loads(line.split('[TAG AUDIT] ',1)[1]))
            except ValueError:pass
    return raw,data
try:
    if a.trace_netvars:
        trace=c.runtime/'mods/TagNetTrace';trace.mkdir()
        (trace/'modinfo.lua').write_text('name="Tag Net Trace"\ndescription="Disposable constructor observer"\nversion="1"\nauthor="Local"\napi_version=10\ndst_compatible=true\nall_clients_require_mod=true\npriority=1000001\n')
        (trace/'modmain.lua').write_text('''local G=GLOBAL
G.TAG_NET_TRACE={}
for _,kind in G.ipairs({"net_bool","net_byte","net_smallbyte","net_tinybyte","net_shortint","net_ushortint","net_uint","net_int","net_float","net_string","net_hash","net_entity","net_bytearray","net_uintarray"})do
 local original=G.rawget(G,kind)
 if original then G[kind]=function(guid,name,...)
  local list=G.TAG_NET_TRACE[guid]or{};G.TAG_NET_TRACE[guid]=list
  local info=G.debug.getinfo(2,"Sl")
  list[#list+1]={kind=kind,name=name,source=info.source,line=info.currentline}
  return original(guid,name,...)
 end end
end
''')
    probe=c.runtime/'mods/TagClientAudit';probe.mkdir()
    (probe/'modinfo.lua').write_text('name="Tag Client Audit"\ndescription="Disposable network diagnostics"\nversion="1"\nauthor="Local"\napi_version=10\ndst_compatible=true\nall_clients_require_mod=true\npriority=-11110.5\n')
    # Development folder aliases are required by this installation's native
    # Workshop file resolver. Preserve the neutralizer's production-ID detection
    # before it flushes deferred callbacks; do not edit any external source.
    adapter='''local names={happypatch="ShadowWorld",newcs_base="newcs_base",newcs_core="newcs_core",newcs_shadow="newcs_abyss"}
local function adapt(mod)
 if mod and mod.modname=="workshop-3801390351" and mod.COMPAT and not mod.TAG_AUDIT_ALIASES then
  mod.TAG_AUDIT_ALIASES=true
  local C=mod.COMPAT;local original=C.get_env
  C.get_env=function(key)
   local found=original(key);if found then return found end
   for _,candidate in GLOBAL.ipairs(GLOBAL.ModManager.mods)do
    if candidate.modname==names[key]then return candidate end
   end
  end
  for key in GLOBAL.pairs(names)do C.present[key]=C.get_env(key)~=nil end
  C.present.newcs=C.present.newcs_base or C.present.newcs_core or C.present.newcs_shadow
  print("[TAG AUDIT ALIASES] neutralizer recognized local development folders")
 end
end
local manager=GLOBAL.ModManager
local initialize=manager.InitializeModMain
manager.InitializeModMain=function(self,modname,modenv,mainfile,...)
 local result=initialize(self,modname,modenv,mainfile,...)
 if mainfile=="modmain.lua"then adapt(modenv)end
 return result
end
for _,mod in GLOBAL.ipairs(manager.mods)do adapt(mod)end
'''
    (probe/'modmain.lua').write_text(adapter+'local EXPECTED_CLIENTS='+str(a.clients)+'\nlocal PRESSURE_TAGS='+str(a.pressure_tags)+'\n'+(ROOT/'tests/native/tag_clients_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
    # Replace only the server-ready helper, keeping the network probe separate.
    (c.runtime/'mods/VaultAudit/modmain.lua').write_text('AddSimPostInit(function()GLOBAL.TheWorld:DoTaskInTime(1,function()print(\'[VAUDIT] {"kind":"ready"}\')end)end)')
    ids=[]
    if a.legion:ids.append('1392778117')
    if a.tagmod:ids.append('3564271209')
    if a.um:ids.append('3193922031')
    if a.newconstant:ids+=['3191348907','3645179905','3645181516']
    if a.crosspatch:ids.append('3801390351')
    ids+=a.extra_mod
    ids=list(dict.fromkeys(ids))
    aliases={'3191348907':'newcs_base','3645179905':'newcs_core','3645181516':'newcs_abyss'}
    for uid in ids:
        src=ROOT/'work/newconstant-research/steamcmd/steamapps/workshop/content/322330'/uid
        if not src.exists():src=Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid
        _winapi.CreateJunction(str(src),str(c.runtime/'mods'/aliases.get(uid,'workshop-'+uid)))
    options={'player tags limit':a.internal_tags or False}
    if a.calm_world:
        options.update({'Shadow World':False,'rangesupermonster':False,'specialsupermonster':False})
    cfg=','.join('['+json.dumps(k)+']='+str(v).lower() for k,v in options.items())
    mods=', '.join('['+json.dumps(aliases.get(uid,'workshop-'+uid))+']={enabled=true}'for uid in ids)
    (c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},TagClientAudit={enabled=true},'+('TagNetTrace={enabled=true},'if a.trace_netvars else'')+'ShadowWorld={enabled=true,configuration_options={'+cfg+'}}'+(','+mods if mods else'')+'}',encoding='utf-8')
    c.start()
    actual=re.findall(r'\bServerPort:\s*(\d+)',c.logs['Master'].read_text(encoding='utf-8',errors='replace'))
    port=int(actual[-1])if actual else c.ports[0]
    for index in range(1,a.clients+1):
        runtime=c.out/f'client-runtime-{index}'
        shutil.copytree(GAME/'bin64',runtime/'bin64');(runtime/'bin64/steam_appid.txt').write_text('322330')
        # Owned offline diagnostic copies only. The retail debug-random flag
        # does not change this installation's Steam-derived offline identity;
        # identical identities disconnect each other. Distinguish the offline
        # ID prefixes in the three copies, retaining native network peers and
        # all simulation/replication code. Never edit the installed executable.
        binary=runtime/'bin64/dontstarve_steam_x64.exe'
        original=binary.read_bytes();needle=b'OU_\0KU_\0'
        assert original.count(needle)==1,'Expected offline identity literal changed'
        prefix=['FU_','OU_','KU_'][index-1]
        replacement=prefix.encode()+b'\0KU_\0'
        modified=original.replace(needle,replacement,1);binary.write_bytes(modified)
        report.setdefault('offline_identity_copies',[]).append({'index':index,'prefix':prefix,
            'offset':original.index(needle),'original_sha256':hashlib.sha256(original).hexdigest(),
            'test_sha256':hashlib.sha256(modified).hexdigest()})
        _winapi.CreateJunction(str(c.runtime/'mods'),str(runtime/'mods'))
        data=runtime/'data';bundles=data/'databundles';bundles.mkdir(parents=True)
        for src in (GAME/'data').iterdir():
            if src.is_file():shutil.copyfile(src,data/src.name)
            elif src.name!='databundles':_winapi.CreateJunction(str(src),str(data/src.name))
        for src in (GAME/'data/databundles').iterdir():
            if src.name!='scripts.zip':(bundles/src.name).hardlink_to(src)
        boot='''
    if not TheNet:IsDedicated() then
        rawset(_G,"TAG_CLIENT_INDEX",__INDEX__)
        Profile:SetWarnModsEnabled(false)
        DoLoadingPortal=function(cb)cb()end
        if IsInFrontEnd() and Settings.last_reset_action==nil then
            scheduler:ExecuteInTime(5,function()c_connect("127.0.0.1",__PORT__)end)
        end
        local task;task=scheduler:ExecutePeriodic(.5,function()
            local s=TheFrontEnd:GetActiveScreen()
            if s and s.name=="LobbyScreen" and s.cb then task:Cancel();s.cb("__CHAR__","__CHAR___none","","","","")end
        end)
    end
'''.replace('__INDEX__',str(index)).replace('__PORT__',str(port)).replace('__CHAR__',a.characters.split(',')[index-1]).replace('GLOBAL.TAG_CLIENT_INDEX','TAG_CLIENT_INDEX')
        with zipfile.ZipFile(GAME/'data/databundles/scripts.zip')as src,zipfile.ZipFile(bundles/'scripts.zip','w',zipfile.ZIP_DEFLATED,compresslevel=1)as dst:
            for entry in src.infolist():
                raw=src.read(entry)
                if entry.filename=='scripts/mainfunctions.lua':raw=raw.replace(b'    CheckControllers()',boot.encode()+b'    CheckControllers()',1)
                dst.writestr(entry.filename,raw)
        log=c.out/f'client-{index}.log';logs.append(log)
        startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
        with log.open('wb')as out:
            command=[str(runtime/'bin64/dontstarve_steam_x64.exe'),'-persistent_storage_root',str(c.out),'-conf_dir',f'client-{index}','-skipintromovie','-console','-offline','-windowed','-debug_random_data']
            client_commands.append((command,runtime/'bin64'))
            child=subprocess.Popen(command,cwd=runtime/'bin64',stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
        children.append(child)
        deadline=time.monotonic()+210
        while time.monotonic()<deadline:
            raw,events=rows(log);c.events('Master')
            if 'LUA ERROR'in raw or 'SERVER_MODS_WORKSHOP_VERSION_MISMATCH'in raw:raise RuntimeError('client error '+str(log)+'\n'+raw[-6000:])
            ready=next((r for r in events if r.get('kind')=='client_ready'),None)
            if ready:print('CLIENT READY',index,ready['userid'],flush=True);break
            if child.poll()is not None:raise RuntimeError('client exited '+str(log))
            time.sleep(.5)
        else:raise TimeoutError('client connect '+str(log))
    deadline=time.monotonic()+100
    while time.monotonic()<deadline:
        c.events('Master')
        if all(any(r.get('kind')=='client_finished'for r in rows(log)[1])for log in logs):break
        for log in logs:
            raw,_=rows(log)
            if 'LUA ERROR'in raw:raise RuntimeError('client error '+str(log)+'\n'+raw[-6000:])
        time.sleep(.5)
    else:raise TimeoutError('clients did not finish snapshots')
    if a.reconnect_third:
        assert a.clients==3
        children[2].terminate();children[2].wait(15)
        time.sleep(2)
        log=c.out/'client-3-reconnect.log';logs.append(log)
        command,cwd=client_commands[2]
        with log.open('wb')as out:
            child=subprocess.Popen(command,cwd=cwd,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
        children.append(child)
        deadline=time.monotonic()+240
        while time.monotonic()<deadline:
            c.events('Master')
            complete=True
            for i,log in enumerate(logs):
                raw,events=rows(log)
                if 'LUA ERROR'in raw:raise RuntimeError('client reconnect error '+str(log)+'\n'+raw[-6000:])
                expected=2 if i<2 else 1
                if sum(r.get('kind')=='client_finished'for r in events)<expected:complete=False
            if complete:break
            if child.poll()is not None:raise RuntimeError('reconnecting client exited')
            time.sleep(.5)
        else:raise TimeoutError('reconnection did not finish')
    report['clients']=[{'log':str(log),'events':rows(log)[1]}for log in logs]
    report['status']='completed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    for child in children:
        if child.poll()is None:child.terminate()
        child.wait(15)
    c.stop();out=c.out/'tag-clients-result.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(out,flush=True)
raise SystemExit(0 if report['status']=='completed'else 1)
