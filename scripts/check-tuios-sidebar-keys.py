#!/usr/bin/env python3
"""Verify Alt+B sidebar focus/visibility and Alt+Shift+B visibility-only toggles with private PTYs."""
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
 (root/'config/tuios/config.toml').write_text((repo/'files/tuios/config.toml').read_text().replace('@fish@','/bin/sh'))
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
  (root/'TREE.txt').touch()
  first=launch('desktop');first_id=windows()[0]['window_id']
  peer=launch('desktop');peer_id=next(w['window_id'] for w in windows() if w['window_id']!=first_id)
  os.write(first['fd'],b'\x1b\r');wait(lambda:len(windows())==3);pump(.5)
  target=next(w['window_id'] for w in windows() if w['window_id'] not in [first_id,peer_id])
  def capture(id):return run('capture-pane','-s','desktop-1','-w',id,'--trim')
  def marker(client,id,value):
   os.write(client['fd'],f"printf '\\n{value}\\n'\r".encode())
   wait(lambda:'\n'+value+'\n' in capture(id))
  marker(first,target,'ORIGINAL_INPUT_TARGET')
  os.write(first['fd'],b'\x1bB');wait(lambda:'TREE.txt' in text(first))
  marker(first,target,'PEEK_OPEN_STILL_TYPES_HERE')
  assert 'TREE.txt' not in text(peer)
  os.write(first['fd'],b'\x1bB');pump(.4)
  marker(first,target,'PEEK_HIDDEN_STILL_TYPES_HERE')
  os.write(first['fd'],b'\x1bb');wait(lambda:'TREE.txt' in text(first))
  os.write(first['fd'],b'jj');pump(.3)
  marker(peer,peer_id,'PEER_FOCUS_UNCHANGED')
  os.write(first['fd'],b'\x1bb');pump(.4)
  assert 'TREE.txt' not in text(first)
  marker(first,target,'FOCUS_RETURNED_AFTER_CLOSE')
  # A visible peek becomes keyboard-focused with Alt+B, rather than closing.
  os.write(first['fd'],b'\x1bB');wait(lambda:'TREE.txt' in text(first))
  os.write(first['fd'],b'\x1bb');pump(.3)
  os.write(first['fd'],b'j');pump(.3)
  # Shift toggles preserve sidebar ownership too, including across hiding it.
  os.write(first['fd'],b'\x1bB');pump(.3)
  os.write(first['fd'],b'j');pump(.3)
  os.write(first['fd'],b'\x1bB');wait(lambda:'TREE.txt' in text(first))
  os.write(first['fd'],b'j');pump(.3)
  os.write(first['fd'],b'\x1bb');pump(.3)
  marker(first,target,'FOCUS_RETURNED_AFTER_SHIFT_TOGGLES')
  os.write(first['fd'],b'\x1bb');wait(lambda:'TREE.txt' in text(first))
  os.write(first['fd'],b'\x1b');pump(.4)
  marker(first,target,'ESC_RETURNS_WITH_SIDEBAR_VISIBLE')
  assert 'TREE.txt' in text(first)
  os.write(first['fd'],b'\x1bb');pump(.3)
  os.write(first['fd'],b'\x1bb');pump(.3)
  assert 'TREE.txt' not in text(first)
  doctor=json.loads(run('keybinds','doctor','--json'))
  assert not any(b['key']=='alt+u' for b in doctor['terminal_mode_swallowed'])
  assert not doctor.get('key_problems') and not doctor.get('collisions'),doctor
  save(first,'sidebar-toggles-return-to-split-pane');save(peer,'peer-keeps-own-focus')
  print('PASS: Alt+B opens/focuses and closes/restores; Alt+Shift+B preserves pane/sidebar focus; visible sidebar can gain focus; Esc restores pane; Alt+U unbound; peer stays independent')

 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for c in clients:
   os.close(c['fd'])
   if not c.get('reaped'):
    try:os.waitpid(c['pid'],0)
    except ChildProcessError:pass
