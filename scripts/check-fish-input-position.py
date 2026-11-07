#!/usr/bin/env python3
"""Verify managed Fish input/cursor alignment and fzf cancellation after the listing prompt."""
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
  fish='/home/jeebis/.nix-profile/bin/fish'
  import shutil
  fishdir=root/'config/fish';fishdir.mkdir()
  (root/'home/.config').symlink_to(root/'config')
  live=Path('/home/jeebis/.config/fish')
  for f in live.glob('jeebis-*.fish'):(fishdir/f.name).symlink_to(f.resolve())
  (fishdir/'config.fish').write_text((live/'config.fish').read_text().replace('/home/jeebis/.config/fish',str(fishdir)))
  (fishdir/'conf.d').mkdir()
  for f in (live/'conf.d').glob('plugin*.fish'):
   if 'ssh-agent' not in f.name and 'done.' not in f.name:(fishdir/'conf.d'/f.name).symlink_to(f.resolve())
  (fishdir/'jeebis-prompt.fish').unlink()
  (fishdir/'jeebis-prompt.fish').symlink_to(repo/'files/fish/prompt.fish')
  (root/'picker-one').touch();(root/'picker-two').touch()
  c=launch('shell-test',fish,'-i','-C',"set -g fish_greeting; set -g fish_autosuggestion_enabled 0; function fish_title; end")
  pump(1)
  os.write(c['fd'],b'ls\r');pump(1)
  empty=(c['screen'].cursor.x,c['screen'].cursor.y)
  save(c,'empty-after-ls')
  os.write(c['fd'],b'ls ');pump(.7)
  typed=(c['screen'].cursor.x,c['screen'].cursor.y)
  line=c['screen'].display[typed[1]]
  print('empty',empty,'typed',typed,'line',repr(line.rstrip()))
  assert typed[0]==empty[0]+3,(empty,typed,line)
  assert '❯ ls ' in line and '❯  ls' not in line,line
  save(c,'typed-after-ls')
  os.write(c['fd'],b'\t');pump(1.5)
  save(c,'fzf-open')
  os.write(c['fd'],b'\x1b');pump(1)
  line=c['screen'].display[c['screen'].cursor.y]
  print('restored',repr(line.rstrip()))
  assert '❯ ls ' in line and 'lls' not in line and '❯  ls' not in line,line
  assert c['screen'].cursor.x==typed[0]
  save(c,'fzf-cancelled')
  print('PASS: listing prompt, typed text and cursor align; Tab/fzf/Esc restores a single ls')


 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for c in clients:
   os.close(c['fd'])
   if not c.get('reaped'):
    try:os.waitpid(c['pid'],0)
    except ChildProcessError:pass
