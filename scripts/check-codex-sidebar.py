#!/usr/bin/env python3
"""Exercise Codex sidebar activation and Tab routing with a fake Codex in private PTYs."""
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
  import sqlite3,re,textwrap
  module=(repo/'modules/app-files.nix').read_text()
  profile_text=module.split('"tuios-codex/tuios/config.toml".text = '+chr(39)*2+'\n',1)[1].split('\n    '+chr(39)*2+';',1)[0]
  (root/'config/tuios-codex/tuios/config.toml').write_text(textwrap.dedent(profile_text))
  metadata=root/'home/.codex';metadata.mkdir()
  db=sqlite3.connect(metadata/'state_5.sqlite')
  db.executescript('CREATE TABLE projects(id TEXT,name TEXT,position INT); CREATE TABLE project_roots(project_id TEXT,path TEXT,position INT); CREATE TABLE threads(id TEXT,title TEXT,name TEXT,cwd TEXT,project_id TEXT,is_pinned INT,updated_at INT,archived INT,thread_source TEXT);')
  db.execute('insert into projects values(?,?,?)',('p','Project from GUI',0))
  db.execute('insert into threads values(?,?,?,?,?,?,?,?,?)',('11111111-1111-4111-8111-111111111111','Chat sidebar fixture',None,str(root),'p',1,1,0,'user'));db.commit();db.close()
  agents_file=root/'agents.json';agents_file.write_text(json.dumps({'agents':[]}))
  shim=root/'bin/tuios';shim.unlink()
  shim.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nif sys.argv[1:2]==["list-agents"]: print(Path('+repr(str(root/'agents.json'))+').read_text())\nelse: os.execv('+repr(binary)+', ["tuios",*sys.argv[1:]])\n');shim.chmod(0o755)
  (root/'TREE.txt').write_text('fixture')
  fake=root/'bin/codex';fake.write_text('#!/bin/sh\nprintf \'FAKE_CODEX:%s\\n\' "$*"\nexec /bin/sh\n');fake.chmod(0o755)
  normal=launch('desktop');os.write(normal['fd'],b'\x1bB')
  wait(lambda:'TREE.txt' in text(normal))
  sidebar_state=root/'state/tuios/sidebar.json';sidebar_state.parent.mkdir(exist_ok=True)
  sidebar_state.write_text(json.dumps({'collapsed':True}))
  codex=launch('codex','codex',profile=True)
  wait(lambda:'Project from GUI' in text(codex) and 'Chat sidebar fixture' in text(codex))
  os.write(codex['fd'],b'echo ORIGINAL_CODEX_MARKER\r');wait(lambda:'ORIGINAL_CODEX_MARKER' in text(codex))
  assert 'TREE.txt' not in text(codex)
  assert 'Chat sidebar fixture' not in text(normal)
  os.write(codex['fd'],b'\x1bb');pump(.4)
  assert any(cell.bg=='9fc5ff' and cell.fg=='101521' for row in codex['screen'].buffer.values() for cell in row.values()), 'Missing high-contrast selection colours'
  os.write(codex['fd'],b'\r');pump(.4)
  assert 'Chat sidebar fixture' not in text(codex),text(codex)
  os.write(codex['fd'],b'\r');wait(lambda:'Chat sidebar fixture' in text(codex))
  assert '●' not in text(codex)
  agents_file.write_text(json.dumps({'agents':[dict(harness_id='codex',foreground='codex',agent_session_id='11111111-1111-4111-8111-111111111111',state='working')]}))
  wait(lambda:'●' in text(codex))
  os.write(codex['fd'],b'\x1b[B');pump(.4)
  assert any(cell.data=='●' and cell.fg=='164a88' and cell.bg=='9fc5ff' for row in codex['screen'].buffer.values() for cell in row.values()), 'State dot must remain distinct on selected row'
  selected=next(i for i,row in enumerate(codex['screen'].display) if '●' in row[:28])
  cells=codex['screen'].buffer[selected]
  assert all(cells[x].bg=='9fc5ff' for x in range(27)), 'Selection background must cover badge, chat name and trailing spaces'
  assert all(cells[x].fg=='101521' for x in range(5,25)), 'Selected chat name must retain the selection foreground after the badge'
  before=len(windows())
  os.write(codex['fd'],b'\r')
  wait(lambda:'FAKE_CODEX:resume 11111111' in text(codex))
  assert len(windows())==before+1,windows()
  save(codex,'chat-resumed')
  os.write(codex['fd'],b'\x1bb');pump(.3)
  os.write(codex['fd'],b'\r');pump(.5)
  assert len(windows())==before+1,windows()
  os.write(codex['fd'],b'\x1bN')
  wait(lambda:len(windows())==before+2)
  wait(lambda:'FAKE_CODEX:' in text(codex) and 'FAKE_CODEX:resume' not in text(codex))
  pump(1)  # The daemon creates the PTY before the client subscribes to it.
  os.write(codex['fd'],b'echo NEW_CODEX_MARKER\r');wait(lambda:'NEW_CODEX_MARKER' in text(codex))
  save(codex,'new-codex-tab')
  other=launch('yazi','/bin/sh')
  os.write(other['fd'],b'echo OTHER_TAB_MARKER\r');wait(lambda:'OTHER_TAB_MARKER' in text(other))
  count=len(windows())
  for key in [b'\x1b[9;3u',b'\x1b[9;4u',b'\x1b[6;3~',b'\x1b[5;3~']:
   os.write(codex['fd'],key);pump(.5)
   assert 'OTHER_TAB_MARKER' not in text(codex),text(codex)
   assert 'FAKE_CODEX:' in text(codex),text(codex)
  os.write(codex['fd'],b'\x1b[<0;5;2M\x1b[<0;5;2m');pump(.4)
  assert 'Chat sidebar fixture' not in text(codex),text(codex)
  os.write(codex['fd'],b'\x1b[<0;5;2M\x1b[<0;5;2m');wait(lambda:'Chat sidebar fixture' in text(codex))
  os.write(codex['fd'],b'\x1b[<0;5;3M\x1b[<0;5;3m')
  wait(lambda:'FAKE_CODEX:resume 11111111' in text(codex))
  assert len(windows())==count,windows()
  save(codex,'mouse-resume-existing')
  agents_file.write_text(json.dumps({'agents':[]}))
  wait(lambda:'●' not in text(codex))
  previous={w['window_id'] for w in windows()}
  os.write(codex['fd'],b'\x1bb<');pump(.3)
  os.write(codex['fd'],b'\x1b');pump(.3)
  os.write(codex['fd'],b'\x1bB');pump(.3)
  close(codex)
  reopened=launch('codex','codex',profile=True)
  wait(lambda:'Project from GUI' in text(reopened) and 'FAKE_CODEX:' in text(reopened))
  current={w['window_id'] for w in windows()}
  assert previous < current and len(current)==len(previous)+1, windows()
  tabs=json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']
  assert any(t.get('name','').startswith('Terminal-Codex') for t in tabs),tabs
  for _ in range(4):
   os.write(reopened['fd'],b'\x1b[6;3~');pump(.4)
   assert 'ORIGINAL_CODEX_MARKER' not in text(reopened), 'Retired terminal included in Codex navigation'
  save(reopened,'codex-reopened-with-sidebar')
  print('PASS: active-only coloured Agent dots, high-contrast selection, sidebar expanded on startup/reopen, exited Codex shell preserved and fresh Codex started; chat operations and Codex Tab navigation')

 finally:
  for i,c in enumerate(clients):
   (a.artifacts/f'client-{i}.ansi').write_bytes(c['raw'])
   save(c,f'client-{i}-final')
  subprocess.run([binary,'kill-server'],env=env,capture_output=True,timeout=15)
  for c in clients:
   os.close(c['fd'])
   try:os.waitpid(c['pid'],0)
   except ChildProcessError:pass
