"""Shared desktop actions. Only the host adapters know distribution commands."""
import argparse,base64,fcntl,json,os,re,shlex,shutil,subprocess,sys,tempfile,time
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--config',required=True)
parser.add_argument('--plan',action='store_true',help='show the first external command without executing it')
parser.add_argument('action');parser.add_argument('args',nargs=argparse.REMAINDER)
opt=parser.parse_args();cfg=json.loads(Path(opt.config).read_text());args=opt.args
HOME=Path.home();STATE=Path(os.environ.get('XDG_STATE_HOME',HOME/'.local/state'))

def call(argv,**kwargs):
 argv=[str(x) for x in argv]
 if opt.plan:
  print(json.dumps({'backend':cfg['backend'],'argv':argv},ensure_ascii=False));raise SystemExit(0)
 return subprocess.run(argv,check=True,**kwargs)
def command(name):return cfg.get('commands',{}).get(name,name)
def shell_ipc(target,method,*values):
 if target=='shell' and method in ['toggle','summon'] and len(values)==1:values=(*values,'{}')
 if cfg['backend']=='omarchy':return call(['omarchy-shell',target,method,*values])
 result=call([command('quickshell'),'ipc','-n','-p',cfg['runtime']+'/shell','call','--',target,method,*values],text=True,stdout=subprocess.PIPE)
 output=result.stdout.strip()
 if output.startswith(('Target not found.','Function not found.','Too few arguments','Too many arguments','Not ready to accept queries')):raise ValueError(output)
 if output:print(output)
 return result
def launch(argv):return call([command('uwsm-app'),'--',*argv])
def focus_or_launch(pattern, argv):
 if opt.plan:return call(['hyprctl','-j','clients'])
 result=call([command('hyprctl'),'-j','clients'],text=True,stdout=subprocess.PIPE)
 for window in json.loads(result.stdout):
  if any(re.search(pattern,str(window.get(key,'')),re.I) for key in ['class','title']):
   target='address:'+window['address']
   return call([command('hyprctl'),'dispatch','hl.dsp.focus({window='+json.dumps(target)+'})'])
 return call(argv)
def tui(a):
 app_id='org.omarchy.'+Path(a[0]).name if a else 'org.omarchy.terminal'
 if a and a[0].startswith('--app-id='):app_id=a.pop(0).split('=',1)[1]
 return launch([command('terminal'),'--app-id='+app_id,'--',*a])
def menu(name='root'):
 if cfg['backend']=='omarchy':return call(['omarchy-menu','toggle',name])
 return shell_ipc('shell','toggle','omarchy.menu',json.dumps({'menu':name}))
def current_directory():
 return STATE/('omarchy/current' if cfg['backend']=='omarchy' else 'jeebis-desktop/current')
def stop_wallpaper_media():
 if opt.plan or not (STATE/'ruixen/wallpaper-media').exists():return
 try:shell_ipc('ruixen.wallpaper','stop',str(int(time.time()*1000)))
 except subprocess.CalledProcessError:pass

def wallpaper(action,values):
 current=current_directory()
 if action=='pick':
  folders=[Path(cfg['backgrounds']),HOME/'Pictures/ruixen-wallpapers']
  paths=sorted({str(p.resolve()) for folder in folders if folder.is_dir() for p in folder.iterdir() if p.is_file() and p.suffix.lower() in ['.jpg','.jpeg','.png','.webp','.bmp'] and '\n' not in str(p)})
  if not paths:return
  result=call([command('fuzzel'),'--dmenu','--prompt','Wallpaper: '],input='\n'.join(paths)+'\n',text=True,stdout=subprocess.PIPE)
  if result.stdout.strip():print(result.stdout.strip())
  return
 if action!='set' or len(values)!=1:raise ValueError('wallpaper set requires one image path')
 path=Path(values[0]).expanduser().resolve()
 if not path.is_file():raise ValueError('wallpaper file does not exist')
 if cfg['backend']=='omarchy':return call(['omarchy','theme','bg','set',str(path)])
 if opt.plan:return shell_ipc('background','set',str(path))
 current.mkdir(parents=True,exist_ok=True)
 temporary=current/'.background';temporary.unlink(missing_ok=True);temporary.symlink_to(path);temporary.replace(current/'background')
 return shell_ipc('background','set',str(path))

def theme(action,values):
 presets={item['name']:item for item in cfg['presets']};themes=Path(cfg['themes'])
 current=current_directory()
 namefile=current/'theme.name';initializing=action=='init'
 if initializing:
  if (current/'theme/colors.toml').exists():return
  action='set';values=['tokyonight']
 if action=='catalog':
  for item in cfg['presets']:
   print('\x1f'.join([item['name'],item['name'].title(),str(Path(cfg['backgrounds'])/item['wallpaper']),'custom']))
  return
 if action=='list':print('\n'.join(presets));return
 if action=='current':print(namefile.read_text().strip() if namefile.exists() else 'tokyonight');return
 if action=='show':
  name=values[0] if values else (namefile.read_text().strip() if namefile.exists() else 'tokyonight')
  if name not in presets:raise ValueError('unknown preset: '+name)
  preset=presets[name]
  print(json.dumps({'name':name,'palette':str(themes/(preset['palette']+'.toml')),'wallpaper':str(Path(cfg['backgrounds'])/preset['wallpaper'])},ensure_ascii=False,indent=2));return
 if action in ['menu','pick']:
  names='\n'.join(presets)+'\n'
  r=call([command('fuzzel'),'--dmenu','--prompt','Theme: '],input=names,text=True,stdout=subprocess.PIPE)
  if not r.stdout.strip():return
  if action=='pick':print(r.stdout.strip());return
  return theme('set',[r.stdout.strip()])
 if action=='cycle':
  def next_preset():
   names=list(presets);previous=namefile.read_text().strip() if namefile.exists() else names[0]
   if previous=='tokyo-night':previous='tokyonight'
   return names[(names.index(previous)+1)%len(names)] if previous in names else names[0]
  if opt.plan:return theme('set',[next_preset()])
  current.mkdir(parents=True,exist_ok=True)
  with (current/'preset-cycle.lock').open('w') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX)
   return theme('set',[next_preset()])
 if action!='set' or len(values)!=1 or values[0] not in presets:raise ValueError('theme set requires one known preset')
 preset=presets[values[0]]
 if not re.fullmatch('[a-zA-Z0-9_-]+',preset['palette']) or Path(preset['wallpaper']).name!=preset['wallpaper']:raise ValueError('invalid preset path')
 source=themes/(preset['palette']+'.toml');wallpaper=Path(cfg['backgrounds'])/preset['wallpaper']
 if not source.is_file() or not wallpaper.is_file():raise ValueError('preset palette or wallpaper is missing')
 if not initializing:stop_wallpaper_media()
 if cfg['backend']=='omarchy':
  call(['omarchy','theme','set',values[0]])
  return call(['omarchy','theme','bg','set',str(wallpaper)])
 if opt.plan:return call(['render-theme',str(source),str(current/'theme'),str(wallpaper)])
 current.mkdir(parents=True,exist_ok=True)
 with (current/'theme.lock').open('w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  staging=Path(tempfile.mkdtemp(prefix='.theme-',dir=current));shutil.copy2(source,staging/'colors.toml')
  try:
   call(['bash',cfg['renderer'],cfg['templates'],str(staging)])
   target=current/'theme';old=current/'.old-theme'
   if old.exists():shutil.rmtree(old)
   if target.exists():target.rename(old)
   try:staging.rename(target)
   except BaseException:
    if old.exists():old.rename(target)
    raise
   temp=current/'.theme.name';temp.write_text(values[0]+'\n');temp.replace(namefile)
   backgrounds=[wallpaper]
   old_background=str((current/'background').resolve()) if (current/'background').exists() else ''
   if backgrounds:
    temporary=current/'.background';temporary.unlink(missing_ok=True);temporary.symlink_to(backgrounds[0]);temporary.replace(current/'background')
   if old.exists():shutil.rmtree(old)
  finally:
   if staging.exists():shutil.rmtree(staging)
 rio_dir=Path(os.environ.get('XDG_CONFIG_HOME',HOME/'.config'))/'rio'
 if rio_dir.is_dir():os.utime(rio_dir,None)
 if cfg.get('helixReload'):call([cfg['helixReload']])
 if initializing:return
 call([command('hyprctl'),'reload'])
 try:call([command('bat'),'cache','--build'],stdout=subprocess.DEVNULL)
 except subprocess.CalledProcessError:pass
 colors=base64.b64encode((current/'theme/colors.toml').read_bytes()).decode()
 style=base64.b64encode((current/'theme/shell.toml').read_bytes()).decode()
 if backgrounds:return shell_ipc('background','themeTransition',old_background,str(backgrounds[0]),str(backgrounds[0]),colors,style)
 return shell_ipc('shell','applyTheme',colors,style)

def native_legacy(name,a):
 # Compatibility is confined to this adapter; shared plugin IDs remain stable.
 helper=Path(cfg['runtime'])/'bin'/name
 if helper.is_file():return call([str(helper),*a])
 if name=='omarchy-shell':return shell_ipc(*(a[1:] if a and a[0]=='-q' else a))
 if name=='omarchy-menu':return menu(a[-1] if a else 'root')
 if name=='omarchy-theme-set':return theme('set',a)
 if name=='omarchy-theme-switcher':return theme('pick',[])
 if name=='omarchy-theme-bg-set':return wallpaper('set',a)
 if name=='omarchy-theme-bg-switcher':return wallpaper('pick',[])
 if name=='omarchy-launch-browser':return call([command('xdg-open'),*a]) if a else launch([command('browser')])
 if name in ['omarchy-launch-webapp','omarchy-launch-webapp-sole']:return call([command('xdg-open'),a[-1]])
 if name in ['omarchy-launch-tui','omarchy-launch-floating-terminal-with-presentation']:return tui(a)
 if name=='omarchy-launch-editor':return launch([command('terminal'),'--',command('editor'),*a])
 if name=='omarchy-launch-or-focus':return focus_or_launch(a[0],['bash','-c',a[1]] if len(a)>1 else ['uwsm-app','--',a[0]])
 if name=='omarchy-launch-or-focus-tui':
  app_id=a[0].split('=',1)[1] if a[0].startswith('--app-id=') else 'org.omarchy.'+Path(a[0]).name
  return focus_or_launch(re.escape(app_id),['jeebis-desktop','legacy','omarchy-launch-tui',*a])
 if name=='omarchy-launch-or-focus-webapp':return focus_or_launch(a[0],['xdg-open',a[1]])
 if name=='omarchy-osd':return shell_ipc('osd','show',*a)
 if name in ['omarchy-system-lock','omarchy-launch-screensaver']:return shell_ipc('lock','lock')
 if name in ['omarchy-system-reboot','omarchy-system-shutdown']:return call([command('systemctl'),'reboot' if name.endswith('reboot') else 'poweroff'])
 if name=='omarchy-system-logout':return call([command('uwsm'),'stop'])
 if name=='omarchy-system-wake':return call([command('brightnessctl'),'--restore'])
 if name=='omarchy-hyprland-session-locked':return shell_ipc('lock','status')
 if name.startswith('omarchy-audio-'):
  source='@DEFAULT_AUDIO_SOURCE@' if 'input' in name else '@DEFAULT_AUDIO_SINK@';mode=a[0] if a else 'toggle'
  return call([command('wpctl'),'set-volume',source,'5%+' if mode in ['raise','up'] else '5%-']) if 'volume' in name else call([command('wpctl'),'set-mute',source,'toggle'])
 if name.startswith('omarchy-brightness-'):
  extra=['--device','*::kbd_backlight'] if name.endswith('keyboard') else []
  return call([command('brightnessctl'),*extra,'set',{'raise':'+5%','lower':'5%-','off':'0','on':'50%'}.get(a[0] if a else 'raise','+5%')])
 if name=='omarchy-capture-screenshot':return screenshot(a)
 if name=='omarchy-notification-send':return call([command('notify-send'),*a])
 if name in ['omarchy-cmd-present','omarchy-cmd-missing']:raise SystemExit(0 if bool(shutil.which(a[0]))==(name.endswith('present')) else 1)
 if name=='omarchy-cmd-terminal-cwd':
  r=call([command('hyprctl'),'-j','activewindow'],text=True,stdout=subprocess.PIPE);pid=json.loads(r.stdout).get('pid');p=Path('/proc')/str(pid)/'cwd';print(str(p.resolve()) if p.exists() else str(HOME));return
 if name=='omarchy-toggle-nightlight':return call([command('systemctl'),'--user','restart','hyprsunset.service'])
 if name.startswith('omarchy-launch-'):
  app=name.removeprefix('omarchy-launch-');return launch([app,*a])
 if name in ['omarchy-menu-keybindings']:
  return launch([command('terminal'),'--',command('editor'),str(HOME/'Git/home-manager/docs/desktop-architecture.md')])
 if name=='omarchy-menu-timezone':return call([command('terminal'),'--','timedatectl','list-timezones'])
 if name in ['omarchy-powerprofiles-list']:return call([command('powerprofilesctl'),'list'])
 if name=='omarchy-powerprofiles-set':return call([command('powerprofilesctl'),'set',*a])
 raise ValueError('No native adapter for '+name+'; this distro operation is not part of the shared desktop')

def screenshot(a):
 if cfg['backend']=='omarchy':return call(['omarchy-capture-screenshot',*a])
 if opt.plan:return call([command('grim'),'-g','<interactive region>','<Pictures/Screenshots/file.png>'])
 region=call([command('slurp')],text=True,stdout=subprocess.PIPE).stdout.strip()
 if not region:return
 folder=HOME/'Pictures/Screenshots';folder.mkdir(parents=True,exist_ok=True);p=folder/time.strftime('%Y-%m-%d_%H-%M-%S.png')
 call([command('grim'),'-g',region,str(p)])
 with p.open('rb') as stream:call([command('wl-copy'),'--type','image/png'],stdin=stream)
 call([command('notify-send'),'Screenshot saved',str(p)])

def main():
 action=opt.action
 if action=='backend':print(cfg['backend']);return
 if action=='launch':return launch(args)
 if action=='capture':return screenshot(args)
 if action=='theme':return theme(args[0] if args else 'menu',args[1:])
 if action=='wallpaper':return wallpaper(args[0] if args else 'pick',args[1:])
 if action=='shell':
  if args==['restart']:
   return call(['omarchy','restart','shell']) if cfg['backend']=='omarchy' else call([command('systemctl'),'--user','--no-block','restart','jeebis-desktop.service'])
  return shell_ipc(*args)
 if action in ['menu','pick']:return menu(args[0] if args else 'root')
 if action=='notify':return call([command('notify-send'),*args])
 if action=='legacy':
  if cfg['backend']=='omarchy' and args[0] not in ['omarchy-launch-tui','omarchy-launch-floating-terminal-with-presentation','omarchy-launch-editor','omarchy-launch-or-focus-tui']:return call(args)
  return native_legacy(args[0],args[1:])
 if action=='browser':return call(['omarchy-launch-browser',*args]) if cfg['backend']=='omarchy' else (call([command('xdg-open'),*args]) if args else launch([command('browser')]))
 if action=='terminal':return launch([command('terminal'),*args])
 if action=='overview':return shell_ipc('shell','toggle' if not args else args[0],'ruixen.launcher','{}')
 raise ValueError('Unknown desktop action: '+action)
def main_browser(a):return call(['omarchy-launch-webapp',*a]) if cfg['backend']=='omarchy' else call([command('xdg-open'),*a])
try:main()
except (ValueError,IndexError,FileNotFoundError,subprocess.CalledProcessError) as e:
 print('jeebis-desktop: '+str(e),file=sys.stderr);raise SystemExit(2)
