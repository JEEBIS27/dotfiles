#!/usr/bin/env python3
"""Verify oldest-first named empty Tab reuse and full-capacity errors with private PTYs."""
import argparse,codecs,fcntl,json,os,pty,select,signal,struct,subprocess,tempfile,termios,time
from pathlib import Path
import pyte
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tuios',required=True);parser.add_argument('--artifacts',type=Path,required=True)
a=parser.parse_args();binary=str(Path(a.tuios).resolve());repo=Path(__file__).resolve().parent.parent
a.artifacts.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tuios-independent-') as temp:
 root=Path(temp)
 for d in ['home','config/tuios','runtime','state','cache','data','bin']:(root/d).mkdir(parents=True)
 (root/'runtime').chmod(0o700)
 (root/'config/tuios/config.toml').write_text((repo/'files/tuios/config.toml').read_text().replace('@fish@','/bin/sh').replace('prefix_toggle_sidebar = ["alt+b"]','prefix_toggle_sidebar = ["alt+b"]\nfocus_sidebar = ["alt+u"]'))
 (root/'config/tuios-codex/tuios').mkdir(parents=True)
 (root/'config/tuios-codex/tuios/config.toml').write_text('include = ["../../tuios/config.toml"]\n[appearance.sidebar]\nenabled = true\nwidth = 16\n')
 (root/'bin/tuios').symlink_to(binary)
 mock=root/'bin/hyprctl';mock.write_text('#!/bin/sh\nprintf \'{"name":"1"}\\n\'\n');mock.chmod(0o755)
 env={k:v for k,v in os.environ.items() if not k.startswith(('TUIOS','TMUX','HERDR','JEEBIS_TUIOS')) and k!='NO_COLOR'}
 env.update(HOME=str(root/'home'),XDG_CONFIG_HOME=str(root/'config'),XDG_RUNTIME_DIR=str(root/'runtime'),XDG_STATE_HOME=str(root/'state'),XDG_CACHE_HOME=str(root/'cache'),XDG_DATA_HOME=str(root/'data'),HYPRLAND_INSTANCE_SIGNATURE='test',SHELL='/bin/sh',TERM='xterm-256color',COLORTERM='truecolor',PATH=f"{root/'bin'}:{repo/'files/desktop/helpers'}:{os.environ['PATH']}")
 clients=[]
 def run(*args):
  p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=15)
  assert p.returncode==0,(args,p.stdout,p.stderr)
  return p.stdout
 def pump(seconds=.2):
  end=time.monotonic()+seconds
  while time.monotonic()<end:
   active=[c for c in clients if c['alive']]
   if not active:time.sleep(.02);continue
   readable,_,_=select.select([c['fd'] for c in active],[],[],.05)
   for c in active:
    if c['fd'] not in readable:continue
    try:data=os.read(c['fd'],65536)
    except OSError:data=b''
    if not data:
     c['alive']=False
     assert c.get('closing'),f"{c['role']} exited unexpectedly"
     continue
    c['raw'].extend(data);c['stream'].feed(c['decode'].decode(data))
    if b'\x1b[6n' in data:os.write(c['fd'],b'\x1b[1;1R')
    if b'\x1b[c' in data:os.write(c['fd'],b'\x1b[?62;4;6;22c')
 def text(c):return '\n'.join(c['screen'].display)
 def wait(fn):
  end=time.monotonic()+12
  while time.monotonic()<end:
   pump()
   if fn():return
  raise AssertionError('\n\n'.join(c['role']+'\n'+text(c) for c in clients))
 def launch(role,*command,profile=False):
  pid,fd=pty.fork()
  if pid==0:
   os.chdir(root)
   os.execvpe(str(repo/'files/desktop/helpers/jeebis-tuios'),['jeebis-tuios',*command],dict(env,JEEBIS_TUIOS_ROLE=role,**({'JEEBIS_TUIOS_CODEX':'1'} if profile else {})))
  fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,1200,800))
  screen=pyte.Screen(120,40)
  c=dict(pid=pid,fd=fd,role=role,alive=True,screen=screen,stream=pyte.Stream(screen),decode=codecs.getincrementaldecoder('utf8')('replace'),raw=bytearray())
  clients.append(c);pump(1.4);return c
 def save(c,name):
  (a.artifacts/(name+'.txt')).write_text(text(c))
 def close(c):
  c['closing']=True;os.write(c['fd'],b'\x1bd')
  end=time.monotonic()+8
  while time.monotonic()<end:
   result=os.waitpid(c['pid'],os.WNOHANG)
   if result[0]:c['reaped']=True;c['alive']=False;return
   pump()
  raise AssertionError('Client did not detach')
 def windows():return json.loads(run('list-windows','-s','desktop-1','--json'))['windows']
 try:
  terminal=launch('desktop')
  os.write(terminal['fd'],b'printf "ORIGINAL_TERMINAL\\n"\r');wait(lambda:'ORIGINAL_TERMINAL' in text(terminal))
  # Two named empty tabs, all other slots holding work. The older empty
  # tab has the higher number, so number ordering cannot pass this check.
  for ws in range(2,10):
   run('call','set-workspace-name',json.dumps(dict(session='desktop-1',workspace=ws,name=f'Old chat {ws}')))
   if ws not in [2,6]:run('new-window',f'work-{ws}','-s','desktop-1','--workspace',str(ws),'--no-focus','--','/bin/sh','-c','sleep 180')
  import hashlib
  lease=root/'runtime/jeebis-tuios/views'/hashlib.sha256(b'\0desktop-1').hexdigest()[:24]
  for ws,stamp in [(2,200),(6,100)]:
   (lease/f'{ws}.json').write_text(json.dumps(dict(role='old-chat',last_used=stamp)))
  before={w['window_id'] for w in windows()}
  second=launch('desktop');os.write(second['fd'],b'printf "SECOND_TERMINAL\\n"\r')
  wait(lambda:'SECOND_TERMINAL' in text(second))
  tabs=json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']
  assert next(t['workspace'] for t in tabs if t['name']=='Terminal 2')==6,tabs
  third=launch('desktop');os.write(third['fd'],b'printf "THIRD_TERMINAL\\n"\r')
  wait(lambda:'THIRD_TERMINAL' in text(third))
  tabs=json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']
  assert next(t['workspace'] for t in tabs if t['name']=='Terminal 3')==2,tabs
  assert len(windows())==9 and before <= {w['window_id'] for w in windows()}
  assert 'SECOND_TERMINAL' not in text(terminal) and 'THIRD_TERMINAL' not in text(second)
  full=launch('desktop');wait(lambda:'Enter' in text(full))
  assert full['alive'] and len(windows())==9
  save(full,'full-tabs-error-stays-visible')
  os.write(full['fd'],b'\r');full['closing']=True
  pump(.5)
  close(second);close(third)
  resumed=launch('desktop')
  wait(lambda:'SECOND_TERMINAL' in text(resumed))
  assert 'THIRD_TERMINAL' not in text(resumed)
  assert len(windows())==9
  save(resumed,'oldest-closed-role-resumed');save(terminal,'original-stays-independent')
  print('PASS: named empty tabs reused oldest-first, existing panes preserved, three independent terminals, oldest closed role resumed, full-tab error remains visible')

 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for c in clients:
   os.close(c['fd'])
   if not c.get('reaped'):
    try:os.waitpid(c['pid'],0)
    except ChildProcessError:pass
