#!/usr/bin/env python3
"""Verify explicit pane/Tab close removes empty Tabs while detach preserves work using private PTYs."""
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
  import hashlib
  lease=root/'runtime/jeebis-tuios/views'/hashlib.sha256(b'\0desktop-1').hexdigest()[:24]
  def tabs():return json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']
  def tab(ws):return next(t for t in tabs() if t['workspace']==ws)
  first=launch('desktop');os.write(first['fd'],b'echo KEEP_WORK\r');wait(lambda:'KEEP_WORK' in text(first))
  first_id=windows()[0]['window_id']
  second=launch('desktop');os.write(second['fd'],b'echo PRESERVE_ON_DETACH\r');wait(lambda:'PRESERVE_ON_DETACH' in text(second))
  ws=next(t['workspace'] for t in tabs() if t['name']=='Terminal 2')
  second_id=next(w['window_id'] for w in windows() if w['workspace']==ws)
  close(second)
  assert tab(ws)['window_count']==1 and tab(ws)['name']=='Terminal 2' and (lease/f'{ws}.json').exists()
  second=launch('desktop');wait(lambda:'PRESERVE_ON_DETACH' in text(second))
  assert any(w['window_id']==second_id for w in windows())
  os.write(second['fd'],b'\x1b\r');wait(lambda:tab(ws)['window_count']==2);pump(.5)
  os.write(second['fd'],b'\x1bw');wait(lambda:tab(ws)['window_count']==1);pump(.5)
  assert tab(ws)['name']=='Terminal 2' and (lease/f'{ws}.json').exists()
  os.write(second['fd'],b'\x1bw')
  wait(lambda:tab(ws)['window_count']==0 and not tab(ws).get('name') and not (lease/f'{ws}.json').exists())
  assert not tab(ws).get('focus_history') and not tab(ws).get('focused_window_id')
  assert any(w['window_id']==first_id for w in windows()) and 'KEEP_WORK' in text(first)
  save(second,'last-pane-close-removes-tab');close(second)
  job=launch('job','/bin/sh');pump(.5)
  jobws=next(t['workspace'] for t in tabs() if t['name']=='job')
  os.write(job['fd'],b'\x1b\r');wait(lambda:tab(jobws)['window_count']==2)
  ids={w['window_id'] for w in windows()}
  os.write(job['fd'],b'\x1bW');pump(.5)
  os.write(job['fd'],b'\x1b');pump(.5)
  assert ids=={w['window_id'] for w in windows()}, 'Cancelled close must preserve everything'
  os.write(job['fd'],b'\x1bW');pump(.5)
  os.write(job['fd'],b'\x1b[B\r')
  wait(lambda:tab(jobws)['window_count']==0 and not tab(jobws).get('name') and not (lease/f'{jobws}.json').exists())
  assert {w['window_id'] for w in windows()}=={first_id}
  save(job,'close-tab-removes-all-own-panes');close(job)
  first['closing']=True
  os.write(first['fd'],b'\x1bw')
  wait(lambda:not windows() and not tab(1).get('name') and not (lease/'1.json').exists())
  wait(lambda:not first['alive'])
  assert all(not t.get('name') for t in tabs())
  print('PASS: detach preserves work; partial close preserves Tab; last-pane and confirmed Tab close remove name/lease; cancelled close preserves work; last Tab exits only its client')

 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for c in clients:
   os.close(c['fd'])
   if not c.get('reaped'):
    try:os.waitpid(c['pid'],0)
    except ChildProcessError:pass
