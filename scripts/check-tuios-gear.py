#!/usr/bin/env python3
"""Legacy command name: test gear removal, role workspace attach and native picker.

Uses only a private daemon and writes repeatable screen artifacts. Requires pyte.
"""
import argparse,codecs,fcntl,json,os,pty,select,struct,subprocess,tempfile,termios,time
from pathlib import Path
import pyte
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--tuios',required=True)
p.add_argument('--artifacts',type=Path,required=True)
a=p.parse_args(); binary=str(Path(a.tuios).resolve()); repo=Path(__file__).resolve().parent.parent
a.artifacts.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tuios-interface-') as temp:
 root=Path(temp)
 for d in ['home','config/tuios','runtime','state','data','cache']:(root/d).mkdir(parents=True)
 (root/'runtime').chmod(0o700)
 config=(repo/'files/tuios/config.toml').read_text().replace('@fish@','/bin/sh')
 (root/'config/tuios/config.toml').write_text(config)
 env={k:v for k,v in os.environ.items() if not k.startswith(('TUIOS','TMUX','HERDR','HYPRLAND')) and k!='NO_COLOR'}
 env.update(HOME=str(root/'home'),XDG_CONFIG_HOME=str(root/'config'),XDG_RUNTIME_DIR=str(root/'runtime'),XDG_STATE_HOME=str(root/'state'),XDG_DATA_HOME=str(root/'data'),XDG_CACHE_HOME=str(root/'cache'),SHELL='/bin/sh',TERM='xterm-256color',COLORTERM='truecolor')
 def run(*args):
  result=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=15)
  assert result.returncode==0,(args,result.stdout,result.stderr)
  return result.stdout
 for name in ['ui-check','switch-target','delete-target']:run('new',name,'--detach')
 run('call','set-workspace-name',json.dumps({'session':'ui-check','workspace':2,'name':'Yazi'}))
 run('new-window','Codex','-s','ui-check','--workspace','3','--no-focus','--','/bin/sh','-c','sleep 120')
 (root/'project-alpha').mkdir()
 run('new-window','Yazi','-s','ui-check','--workspace','2','--no-focus','--cwd',str(root/'project-alpha'),'--','/bin/sh','-c','printf role-two; sleep 120')
 pid,fd=pty.fork()
 if pid==0:os.execvpe(binary,[binary,'attach','ui-check','--workspace','2','--terminal-mode'],env)
 fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,1200,800))
 screen=pyte.Screen(120,40);stream=pyte.Stream(screen);decode=codecs.getincrementaldecoder('utf8')('replace');raw=bytearray()
 def pump(seconds=.2):
  end=time.monotonic()+seconds
  while time.monotonic()<end:
   if select.select([fd],[],[],min(.05,max(0,end-time.monotonic())))[0]:
    data=os.read(fd,65536);assert data,'UI unexpectedly exited'
    raw.extend(data);stream.feed(decode.decode(data))
    if b'\x1b[6n' in data:os.write(fd,b'\x1b[1;1R')
    if b'\x1b[c' in data:os.write(fd,b'\x1b[?62;4;6;22c')
 def text():return '\n'.join(screen.display)
 def wait(fn):
  end=time.monotonic()+10
  while time.monotonic()<end:
   pump()
   if fn():return
  raise AssertionError(text())
 def keys(data):os.write(fd,data);pump(.4)
 def save(name):(a.artifacts/(name+'.txt')).write_text(text())
 def sessions():return json.loads(run('list-sessions','--json'))
 try:
  wait(lambda:json.loads(run('list-windows','-s','ui-check','--json'))['current_workspace']==2)
  wait(lambda:'role-two' in text())
  assert '\uf013' not in text(),'Gear still rendered'
  save('01-role-workspace-no-gear')
  # Workspace navigation must move between role workspaces, not panes.
  for key, expected in [(b'\x1b[9;3u',3),(b'\x1b[9;4u',2),(b'\x1b[5;3~',1),(b'\x1b[6;3~',2)]:
   keys(key)
   wait(lambda:json.loads(run('list-windows','-s','ui-check','--json'))['current_workspace']==expected)
  keys(b'\x1bs')
  wait(lambda:'Tabs' in text() and 'Yazi' in text() and 'Directory:' in text() and 'Panes:' in text())
  save('02-workspace-picker')
  keys(b'Yazi')
  wait(lambda:'Yazi' in text() and 'current' in text() and '1 pane' in text())
  save('02-workspace-filter-by-name')
  keys(b'\x15project-alpha')
  wait(lambda:'current' in text() and '1 pane' in text())
  save('02-workspace-filter-by-directory')
  keys(b'\x1b')
  keys(b'\x1bS');keys(b'switch-target');wait(lambda:'Workspaces' in text());save('02-native-search')
  keys(b'\r')
  wait(lambda:any(s['name']=='switch-target' and s['attached'] for s in sessions()))
  keys(b'\x1bS');keys(b'delete-target');keys(b'\x1b[3~')
  wait(lambda:'delete-target' in text() and 'Delete workspace?' in text())
  save('03-delete-confirmation')
  keys(b'n')
  assert any(s['name']=='delete-target' for s in sessions())
  keys(b'\x1b[3~');keys(b'y')
  wait(lambda:not any(s['name']=='delete-target' for s in sessions()))
  save('04-after-delete')
  keys(b'\x1b')
  keys(b'\x1b/')
  wait(lambda:'Tabs' in text())
  assert 'Sessions' not in text()
  save('05-help-terminology')
  print('PASS: gear absent; attach workspace 2; Alt+Tab/PgUp/PgDn workspace navigation; Alt+S workspace picker; Alt+Shift+S search/Enter switch; Delete confirmation/cancel/delete')
 finally:
  (a.artifacts/'terminal.ansi').write_bytes(raw)
  subprocess.run([binary,'kill-server'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
  os.close(fd);os.waitpid(pid,0)
