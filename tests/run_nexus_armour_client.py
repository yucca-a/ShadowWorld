from pathlib import Path
import sys

source=Path("tests/run_vault_client_travel.py").resolve()
runner=source.read_text(encoding="utf-8")
runner=runner.replace("c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')",
 "c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')\nimport re\nini=c.cluster/'cluster.ini'\nini.write_text(re.sub(r'master_port = \\d+','master_port = 18194',ini.read_text()))")
rounds=int(sys.argv[1]) if len(sys.argv)>1 else 6
report=sys.argv[2] if len(sys.argv)>2 else "work/nexus-armour-client.json"
start=runner.index("    fixture=c.runtime")
end=runner.index("    runtime=c.out",start)
runner=runner[:start]+'''    probe=c.runtime/'mods/NexusPlayAudit'
    probe.mkdir()
    (probe/'modinfo.lua').write_text('name="Nexus Play Audit"\\ndescription="Disposable"\\nauthor="Local"\\nversion="1"\\napi_version=10\\ndst_compatible=true\\nall_clients_require_mod=true\\npriority=-99998\\n')
    script=Path('tests/native/nexus_armour_fixture.lua').read_text(encoding='utf-8-sig').replace('__ROUNDS__',str(rounds))
    script+='\\n'+Path('tests/native/nexus_armour_client.lua').read_text(encoding='utf-8-sig')
    (probe/'modmain.lua').write_text('local G=GLOBAL\\nG.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})\\n'+script,encoding='utf-8')
    for name in c.names:
        overrides=c.cluster/name/'modoverrides.lua'
        overrides.write_text(overrides.read_text().replace('return {','return {NexusPlayAudit={enabled=true},',1)
            .replace('["World Exchange"]="hosted",','').replace('["Container Sort"]=-3','["Container Sort"]=-3,["Tackle Receptacle Use Fish Redeem"]=-1'))
'''+runner[end:]
start=runner.index("    deadline=time.monotonic()")
end=runner.index("except Exception:",start)
runner=runner[:start]+'''    deadline=time.monotonic()+140*rounds
    seen=set()
    while time.monotonic()<deadline:
        rows=[]
        for n in c.names:
            c.events(n)
            raw=c.logs[n].read_text(encoding='utf-8',errors='replace')
            for line in raw.splitlines():
                if '[NEXUS PLAY] SERVER PASS ' in line:
                    rows.append(int(line.split('[NEXUS PLAY] SERVER PASS ',1)[1].strip()))
        for step in sorted(set(rows)-seen):print('NEXUS PLAY PASS',step,flush=True);seen.add(step)
        raw=log.read_text(encoding='utf-8',errors='replace')
        if 'LUA ERROR' in raw or '[NEXUS PLAY] timed out' in raw:raise RuntimeError('client error: '+str(log)+'\\n'+raw[-6500:])
        if len(seen)==rounds:
            clients=[int(line.split('[NEXUS PLAY] CLIENT PASS ',1)[1].strip()) for line in raw.splitlines() if '[NEXUS PLAY] CLIENT PASS ' in line]
            assert clients==list(range(1,rounds+1)),clients
            result.update(status='passed',rounds=clients,client_log=str(log));break
        if client.poll() is not None:raise RuntimeError('client exited: '+str(client.returncode))
        time.sleep(.5)
    else:raise TimeoutError('real client did not finish interaction rounds; '+str(log))
'''+runner[end:]
sys.argv=[str(source),'--report',report]
globals()['__file__']=str(source)
exec(compile(runner,str(source),'exec'))
