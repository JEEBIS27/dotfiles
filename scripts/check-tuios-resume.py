#!/usr/bin/env python3
"""Exercise reboot restoration in an isolated real daemon, never the user's server."""
import argparse,json,os,signal,subprocess,tempfile,time,uuid
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--tuios',required=True);p.add_argument('--artifacts',type=Path,required=True)
a=p.parse_args();binary=str(Path(a.tuios).resolve());repo=Path(__file__).resolve().parent.parent
a.artifacts.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tuios-resume-check-') as tmp:
 r=Path(tmp)
 for d in ['home','config/tuios','state/tuios/sessions','runtime','cache','data','bin','project-a','project-b']:(r/d).mkdir(parents=True)
 (r/'runtime').chmod(0o700)
 (r/'config/tuios/config.toml').write_text((repo/'files/tuios/config.toml').read_text().replace('@fish@','/bin/sh'))
 env={k:v for k,v in os.environ.items() if not k.startswith(('TUIOS_','CODEX_'))}
 env.update(HOME=str(r/'home'),XDG_CONFIG_HOME=str(r/'config'),XDG_STATE_HOME=str(r/'state'),XDG_RUNTIME_DIR=str(r/'runtime'),XDG_CACHE_HOME=str(r/'cache'),XDG_DATA_HOME=str(r/'data'),PATH=str(r/'bin')+':'+os.environ['PATH'],TERM='xterm-256color',RESUME_LOG=str(r/'resumes.jsonl'))
 env['TEST_TUIOS_BINARY']=binary
 fake=r/'bin/codex';fake.write_text('''#!/usr/bin/env python3
import json,os,sys,time,subprocess
from pathlib import Path
with open(os.environ['RESUME_LOG'],'a') as f:f.write(json.dumps(dict(argv=sys.argv[1:],cwd=os.getcwd(),pane=os.environ.get('TUIOS_PANE_ID')))+'\\n')
if not sys.argv[1:]:
 payload=dict(hook_event_name='SessionStart',session_id=os.environ['FRESH_ID'],cwd=os.getcwd())
 subprocess.run([os.environ['TEST_TUIOS_BINARY'],'agent-hook','codex','--integration','1'],input=json.dumps(payload),text=True,check=True)
print('CODEX_READY',flush=True)
while True:time.sleep(1)
''');fake.chmod(0o755)
 ids=[str(uuid.uuid4()) for _ in range(6)]
 def pane(i,name,live,cwd,**extra):
  return dict(id=ids[i],title=name,custom_name=name,width=100,height=35,workspace=i+1,pty_id='dead-'+str(i),cwd=str(cwd),agent_harness='codex' if live else '',agent_state='working' if live else '',**extra)
 state=dict(name='restore-check',session_id=str(uuid.uuid4()),start_dir=str(r/'home'),width=100,height=35,current_workspace=1,num_workspaces=9,resurrection_version=1,windows=[
  pane(0,'Codex '+ids[0],True,r/'project-a'),
  pane(1,'Codex '+ids[1],True,r/'project-b',agent_session_id=ids[1],agent_session_harness='codex'),
  pane(2,'Codex '+ids[2],False,r/'project-a',agent_session_id=ids[2],agent_session_harness='codex'),
  pane(3,'Terminal',False,r/'project-b')])
 (r/'state/tuios/sessions/restore-check.json').write_text(json.dumps(state))
 env['FRESH_ID']=ids[5]
 daemon=None;log=None
 def call(*args):
  q=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=15)
  if q.returncode:raise AssertionError((args,q.stdout,q.stderr))
  return q.stdout
 def wait(fn):
  end=time.monotonic()+15
  while time.monotonic()<end:
   if fn():return
   time.sleep(.1)
  raise AssertionError('Timed out; '+(r/'daemon.log').read_text()[-4000:])
 def records():
  f=r/'resumes.jsonl';return [json.loads(s) for s in f.read_text().splitlines()] if f.exists() else []
 def start():
  global daemon,log
  log=(r/'daemon.log').open('a');daemon=subprocess.Popen([binary,'daemon'],env=env,stdout=log,stderr=log)
 def stop():
  global daemon
  if daemon is not None:
   daemon.send_signal(signal.SIGTERM);daemon.wait(timeout=15);daemon=None;log.close()
 try:
  start();wait(lambda:len(records())>=2)
  got=records();assert len(got)==2,got
  assert {(x['argv'][1],x['cwd']) for x in got}=={(ids[0],str(r/'project-a')),(ids[1],str(r/'project-b'))},got
  # This pane has neither a UUID name nor a hook: only argv can supply its ID.
  call('new-window','argv-only','-s','restore-check','--workspace','5','--cwd',str(r/'project-b'),'--','codex','resume',ids[4])
  # A new conversation has no resume argv: its SessionStart must supply the ID.
  call('new-window','hook-only','-s','restore-check','--workspace','6','--cwd',str(r/'project-a'),'--','codex')
  wait(lambda:len(records())>=4)
  def detected():
   agents=json.loads(call('list-agents','-s','restore-check','--json'))['agents']
   return {w.get('agent_session_id') for w in agents}>={ids[0],ids[1],ids[4],ids[5]}
  wait(detected)
  stop()
  saved=json.loads((r/'state/tuios/sessions/restore-check.json').read_text())
  assert all(next(w for w in saved['windows'] if w['id']==i)['agent_session_id']==i for i in ids[:2])
  start();wait(lambda:len(records())>=8)
  assert len(records())==8,records()
  assert {x['argv'][1] for x in records()[4:]}=={ids[0],ids[1],ids[4],ids[5]}
  assert {(x['argv'][1],x['cwd']) for x in records()[4:]}=={(ids[0],str(r/'project-a')),(ids[1],str(r/'project-b')),(ids[4],str(r/'project-b')),(ids[5],str(r/'project-a'))}
  (a.artifacts/'resumes.json').write_text(json.dumps(records(),indent=2))
  (a.artifacts/'saved.json').write_text(json.dumps(saved,indent=2))
  print('PASS: legacy and recorded chats resume at distinct saved CWDs across two daemon starts; exited Codex and plain shell stay shells; argv fallback and new-chat SessionStart both persist IDs')
 finally:
  stop();(a.artifacts/'daemon.log').write_text((r/'daemon.log').read_text())
