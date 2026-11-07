#!/usr/bin/env python3
"""Verify aborted cold starts cannot strand the launcher lock, then open two private terminals."""
import argparse,fcntl,json,os,pty,select,signal,struct,subprocess,tempfile,termios,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--tuios',required=True);p.add_argument('--launcher',type=Path);p.add_argument('--artifacts',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parent.parent
binary=str(Path(a.tuios).resolve());launcher=str(a.launcher or repo/'files/desktop/helpers/jeebis-tuios');a.artifacts.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tuios-startup-check-') as temp:
 r=Path(temp)
 for d in ['home','config/tuios','runtime','state','cache','data','bin']:(r/d).mkdir(parents=True)
 (r/'runtime').chmod(0o700)
 (r/'config/tuios/config.toml').write_text((repo/'files/tuios/config.toml').read_text().replace('@fish@','/bin/sh'))
 flag=r/'fail-new';flag.touch()
 mock=r/'bin/tuios';mock.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nf=Path('+repr(str(flag))+')\nif sys.argv[1:2]==["new"] and f.exists():f.unlink();sys.exit(7)\nos.execv('+repr(binary)+',["tuios",*sys.argv[1:]])\n');mock.chmod(0o755)
 env={k:v for k,v in os.environ.items() if not k.startswith(('TUIOS','TMUX','HERDR','JEEBIS_TUIOS','CODEX_','HYPRLAND_'))}
 env.update(HOME=str(r/'home'),XDG_CONFIG_HOME=str(r/'config'),XDG_RUNTIME_DIR=str(r/'runtime'),XDG_STATE_HOME=str(r/'state'),XDG_CACHE_HOME=str(r/'cache'),XDG_DATA_HOME=str(r/'data'),PATH=str(r/'bin')+':'+str(repo/'files/desktop/helpers')+':'+os.environ['PATH'],TERM='xterm-256color',SHELL='/bin/sh')
 clients=[]
 def call(*args):
  q=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=12)
  assert q.returncode==0,(args,q.stdout,q.stderr)
  return q.stdout
 def windows():
  q=subprocess.run([binary,'list-windows','-s','main','--json'],env=env,capture_output=True,text=True,timeout=12)
  if q.returncode and 'session main not found' in q.stdout:return []
  assert q.returncode==0,(q.stdout,q.stderr)
  return json.loads(q.stdout)['windows']
 def pump():
  ready,_,_=select.select([c['fd'] for c in clients],[],[],.1)
  for c in clients:
   if c['fd'] not in ready:continue
   try:data=os.read(c['fd'],65536)
   except OSError:data=b''
   c['raw'].extend(data)
   if b'\x1b[6n' in data:os.write(c['fd'],b'\x1b[1;1R')
   if b'\x1b[c' in data:os.write(c['fd'],b'\x1b[?62;4;6;22c')
 def launch():
  pid,fd=pty.fork()
  if pid==0:os.chdir(r);os.execve(launcher,[launcher],env)
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,1000,600));clients.append(dict(pid=pid,fd=fd,raw=bytearray()))
 def wait(fn):
  end=time.monotonic()+12
  while time.monotonic()<end:
   pump()
   if fn():return
  raise AssertionError('Timed out waiting for terminal startup')
 try:
  # A real cold-started daemon survives an injected failure creating the session.
  aborted=subprocess.run([launcher],env=env,cwd=r,capture_output=True,timeout=15)
  assert aborted.returncode==7,aborted
  lock=r/'runtime/jeebis-tuios/launch.lock'
  with lock.open('a') as f:
   try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
   except BlockingIOError:raise AssertionError('Cold-start daemon inherited launch.lock after the launcher failed')
   fcntl.flock(f,fcntl.LOCK_UN)
  launch();wait(lambda:len(windows())==1 and len(clients[0]['raw'])>100)
  os.write(clients[0]['fd'],b'echo FIRST_TERMINAL_READY\r')
  wait(lambda:b'FIRST_TERMINAL_READY' in clients[0]['raw'])
  launch();wait(lambda:len(windows())==2 and len(clients[1]['raw'])>100)
  os.write(clients[1]['fd'],b'echo SECOND_TERMINAL_READY\r')
  wait(lambda:b'SECOND_TERMINAL_READY' in clients[1]['raw'])
  panes=windows();assert len({w['workspace'] for w in panes})==2
  (a.artifacts/'windows.json').write_text(json.dumps(panes,indent=2))
  print('PASS: failed cold start releases launch lock; two subsequent terminals draw prompts and accept input in independent Tabs')
 finally:
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
   try:os.kill(c['pid'],signal.SIGTERM)
   except ProcessLookupError:pass
   os.close(c['fd'])
   try:os.waitpid(c['pid'],0)
   except ChildProcessError:pass
