#!/usr/bin/env python3
"""Exercise simultaneous desktop windows against an isolated TUIOS daemon."""
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
  terminal=launch('desktop')
  os.write(terminal['fd'],b'printf "TERMINAL_ONE_MARKER\\n"\r')
  wait(lambda:'TERMINAL_ONE_MARKER' in text(terminal));save(terminal,'01-terminal-before-codex')
  codex=launch('codex','/bin/sh','-c','printf "CODEX_MARKER\\n"; sleep 180')
  wait(lambda:'CODEX_MARKER' in text(codex))
  pump(1)
  assert 'TERMINAL_ONE_MARKER' in text(terminal) and 'CODEX_MARKER' not in text(terminal)
  save(terminal,'02-terminal-after-codex');save(codex,'02-codex')
  terminal2=launch('desktop')
  os.write(terminal2['fd'],b'printf "TERMINAL_TWO_MARKER\\n"\r')
  wait(lambda:'TERMINAL_TWO_MARKER' in text(terminal2));pump(1)
  assert 'TERMINAL_ONE_MARKER' in text(terminal) and 'TERMINAL_TWO_MARKER' not in text(terminal)
  assert 'CODEX_MARKER' in text(codex) and 'TERMINAL_TWO_MARKER' not in text(codex)
  tabinfo=json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']
  duplicate=next(w for w in tabinfo if w['name']=='Terminal 2')
  duplicate_id=next(w['window_id'] for w in windows() if w['workspace']==duplicate['workspace'])
  assert len({w['tty'] for w in windows()})==len(windows())
  assert len(json.loads(run('list-sessions','--json')))==1
  save(terminal2,'03-terminal-two')
  close(terminal2)
  resumed=launch('desktop')
  wait(lambda:'TERMINAL_TWO_MARKER' in text(resumed))
  assert next(w['window_id'] for w in windows() if w['workspace']==duplicate['workspace'])==duplicate_id
  assert len(windows())==3
  assert 'TERMINAL_ONE_MARKER' in text(terminal) and 'CODEX_MARKER' in text(codex)
  save(resumed,'04-resumed-terminal-two')
  # Sidebar visibility is a viewer preference, not shared session state.
  def marker_column(client,marker):
   return next(row.index(marker) for row in client['screen'].display if marker in row and 'printf' not in row)
  os.write(terminal['fd'],b'\x1bB');pump(1)
  os.write(resumed['fd'],b'printf "SIDEBAR_PEER_UPDATE\\n"\r');pump(1)
  assert marker_column(terminal,'TERMINAL_ONE_MARKER')>0
  assert marker_column(resumed,'TERMINAL_TWO_MARKER')==0
  assert marker_column(codex,'CODEX_MARKER')==0
  def check_pty_size(client,label,rows,cols):
   os.write(client['fd'],f"printf '{label}:'; stty size\r".encode())
   wait(lambda:f'{label}:{rows} {cols}' in text(client))
  check_pty_size(terminal,'SIDEBAR_PTY',40,104)
  check_pty_size(resumed,'FULL_WIDTH_PEER',40,120)
  pump(1)
  assert not any('· · ·' in row for row in resumed['screen'].display)
  save(terminal,'sidebar-open-here');save(resumed,'sidebar-hidden-peer')
  # A new client keeps the launch profile's default even if a peer has it open.
  fresh=launch('desktop')
  os.write(fresh['fd'],b'printf "FRESH_VIEW_MARKER\\n"\r')
  wait(lambda:'FRESH_VIEW_MARKER' in text(fresh))
  assert marker_column(fresh,'FRESH_VIEW_MARKER')==0
  close(fresh)
  expanded=marker_column(terminal,'TERMINAL_ONE_MARKER')
  os.write(terminal['fd'],b'\x1bb<');pump(.5)
  os.write(terminal['fd'],b'\x1b');pump(.5)
  os.write(resumed['fd'],b'printf "COLLAPSE_PEER_UPDATE\\n"\r');pump(1)
  assert 0<marker_column(terminal,'TERMINAL_ONE_MARKER')<expanded
  assert marker_column(resumed,'TERMINAL_TWO_MARKER')==0
  os.write(terminal['fd'],b'\x1bb>');pump(.5)
  os.write(terminal['fd'],b'\x1b');pump(.5)
  os.write(terminal['fd'],b'\x1bB');pump(1)
  os.write(resumed['fd'],b'\x1bB');pump(1)
  os.write(terminal['fd'],b'printf "REVERSE_PEER_UPDATE\\n"\r');pump(1)
  assert marker_column(terminal,'TERMINAL_ONE_MARKER')==0
  assert marker_column(resumed,'TERMINAL_TWO_MARKER')>0
  os.write(resumed['fd'],b'\x1bB');pump(1)
  # The Codex launch profile keeps its enabled rail, beside hidden normal rails.
  profile=launch('codex',profile=True)
  os.write(profile['fd'],b'printf "CODEX_PROFILE_MARKER\\n"\r')
  wait(lambda:'CODEX_PROFILE_MARKER' in text(profile))
  assert marker_column(profile,'CODEX_PROFILE_MARKER')>0
  assert marker_column(terminal,'TERMINAL_ONE_MARKER')==0
  assert marker_column(resumed,'TERMINAL_TWO_MARKER')==0
  save(profile,'codex-profile-sidebar');close(profile);pump(1)
  # Showing a scratch view in one client must survive another client's input.
  os.write(terminal['fd'],b'\x1bt');pump(1.5)
  os.write(terminal['fd'],b'printf "LOCAL_SCRATCH_MARKER\\n"\r')
  wait(lambda:'LOCAL_SCRATCH_MARKER' in text(terminal))
  os.write(resumed['fd'],b'printf "SCRATCH_PEER_UPDATE\\n"\r');pump(1)
  assert 'LOCAL_SCRATCH_MARKER' in text(terminal)
  assert 'LOCAL_SCRATCH_MARKER' not in text(resumed)
  os.write(terminal['fd'],b'\x1bt');pump(1)
  os.write(terminal['fd'],b'printf "RETURNED_FROM_SCRATCH\\n"\r')
  wait(lambda:'RETURNED_FROM_SCRATCH' in text(terminal))
  # A half-width shell beside a full-width shell must not resize both PTYs
  # on every focus/input change. This used to alternate 80x30 and 120x40.
  fcntl.ioctl(terminal['fd'],termios.TIOCSWINSZ,struct.pack('HHHH',30,80,800,600))
  terminal['screen'].resize(30,80)
  pump(2)
  dimensions=[]
  for i in range(6):
   client=terminal if i%2==0 else resumed
   marker=f'RESIZE_STABLE_{i:02d}'
   os.write(client['fd'],f'printf "{marker}\\n"\r'.encode())
   wait(lambda client=client,marker=marker:marker in text(client))
   pump(1.1) # Cross the latest-client policy's one-second ownership lease.
   info=json.loads(run('session-info','-s','desktop-1','--json'))
   dimensions.append((info['session_width'],info['session_height']))
  assert dimensions==[(80,30)]*6,dimensions
  check_pty_size(terminal,'NARROW_PTY',30,80)
  check_pty_size(resumed,'WIDE_PTY',40,120)
  assert not any('· · ·' in row for row in resumed['screen'].display)
  for client,parity in [(terminal,0),(resumed,1)]:
   # The wide client's right-hand padding is outside the shared pane area.
   rows=[row[:80].strip() for row in client['screen'].display[:30]]
   for n in range(parity,6,2):
    marker=f'RESIZE_STABLE_{n:02d}'
    assert rows.count(marker)==1,(marker,rows)
  assert 'CODEX_MARKER' in text(codex)
  save(terminal,'05-stable-narrow');save(resumed,'05-stable-wide')
  print('PASS: independent views/sidebar/scratch, separate PTYs, closed Tab reuse; alternating input at different window sizes keeps each Tab at its own full viewport width')
 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  for c in clients:
   os.close(c['fd'])
   if not c.get('reaped'):
    try:os.waitpid(c['pid'],0)
    except ChildProcessError:pass
