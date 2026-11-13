#!/usr/bin/env python3
"""Exercise real rendering/publication with isolated HOME and mocked desktop IPC."""
import configparser
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
if not (REPO / 'packages/desktop/desktopctl.py').exists():
    raise RuntimeError('Could not locate the repository root from this script path')
with tempfile.TemporaryDirectory(prefix='jeebis-theme-test-') as folder:
    root=Path(folder); bin=root/'bin'; bin.mkdir()
    runner=bin/'mock'
    runner.write_text('''#!/usr/bin/env python3
import os,sys,json,pathlib,shutil
p=pathlib.Path(os.environ['HOME']);name=pathlib.Path(sys.argv[0]).name;a=sys.argv[1:]
with (p/'calls').open('a') as f:f.write(json.dumps([name,*a])+'\\n')
if name=='omarchy':
 current=p/'.local/state/omarchy/current';current.mkdir(parents=True,exist_ok=True)
 if a[:2]==['theme','set']:
  theme=current/'theme';theme.mkdir(exist_ok=True)
  shutil.copy(pathlib.Path(os.environ['THEMES'])/(a[2]+'.toml'),theme/'colors.toml')
  (current/'theme.name').write_text(a[2])
 if a[:3]==['theme','bg','set']:
  (current/'background').unlink(missing_ok=True);(current/'background').symlink_to(a[3])
''');runner.chmod(0o755)
    for name in ['omarchy','omarchy-shell','quickshell','hyprctl','bat']:(bin/name).symlink_to(runner)
    resolver=bin/'jeebis-theme-colors';resolver.write_text('#!/bin/sh\nexec bash '+str(REPO/'packages/desktop/theme-colors.sh')+' "$@"\n');resolver.chmod(0o755)
    templates=REPO/'files/desktop/templates'
    for backend in ['omarchy','nixos']:
        home=root/backend;home.mkdir();public=home/'public';public.mkdir()
        env=os.environ|{'HOME':str(home),'XDG_STATE_HOME':str(home/'.local/state'),
            'XDG_CONFIG_HOME':str(home/'.config'),'PATH':str(bin)+':'+os.environ['PATH'],
            'THEMES':str(REPO/'files/desktop/themes'),'PYTHONDONTWRITEBYTECODE':'1'}
        presets=json.loads((REPO/'files/desktop/presets.json').read_text())
        presets[0]['lockWallpaper']='kanagawa.jpg'
        cfg={'backend':backend,'themes':env['THEMES'],'backgrounds':str(REPO/'files/desktop/backgrounds'),
            'presets':presets,'templates':str(templates),'renderer':str(REPO/'packages/desktop/render-theme.sh'),
            'runtime':'/unused','loginAssets':str(public) if backend=='nixos' else None}
        config=home/'config.json';config.write_text(json.dumps(cfg))
        def run(*args, success=True):
            result=subprocess.run(['python3',str(REPO/'packages/desktop/desktopctl.py'),'--config',str(config),*args],env=env,text=True,capture_output=True)
            assert (result.returncode==0)==success,(args,result.stdout,result.stderr)
            return result
        for preset in presets:
            run('theme','set',preset['name'])
            current=home/'.local/state/jeebis-theme/current'
            data=json.loads((current/'preset.json').read_text());assert data['name']==preset['name']
            lock=REPO/'files/desktop/backgrounds'/preset['lockWallpaper']
            assert (current/'lock-wallpaper').read_bytes()==lock.read_bytes()
            css=(current/'gtk.css').read_text();assert '{{' not in css and '@define-color' in css
            qt=configparser.ConfigParser();qt.read(current/'qt.colors')
            assert len(qt['ColorScheme']['active_colors'].split(','))==22
            assert all(len(x.strip())==9 for x in qt['ColorScheme']['active_colors'].split(','))
            if backend=='nixos':
                assert (public/'current/lock-wallpaper').read_bytes()==lock.read_bytes()
                sddm=configparser.ConfigParser();sddm.read(public/'current/sddm.conf')
                assert sddm['General']['Background']=='Backgrounds/jeebis'
                assert sddm['General']['BackgroundColor'] in css
        run('theme','set','tokyonight')
        current=home/'.local/state/jeebis-theme/current'
        before=(current/'lock-wallpaper').read_bytes()
        run('wallpaper','set',str(REPO/'files/desktop/backgrounds/catppuccin.png'))
        assert (current/'lock-wallpaper').read_bytes()==before,'home-only change altered lock wallpaper'
        # Missing or animated lock image must fail before any desktop side effects.
        calls=(home/'calls').read_text()
        cfg['presets'][0]['lockWallpaper']='missing.png';config.write_text(json.dumps(cfg))
        run('theme','set','tokyonight',success=False)
        assert (home/'calls').read_text()==calls
        cfg['presets'][0]['lockWallpaper']='kanagawa.jpg'
        video=home/'movie.mp4';video.write_bytes(b'fixture; IPC playback is mocked')
        cfg['presets'][0]['wallpaper']=str(video);config.write_text(json.dumps(cfg))
        run('theme','set','tokyonight')
        assert 'playVideo' in (home/'calls').read_text()
        assert (current/'lock-wallpaper').read_bytes()==before
        gif=home/'animation.gif';gif.write_bytes(b'fixture')
        cfg['presets'][0]['wallpaper']=str(gif);config.write_text(json.dumps(cfg));run('theme','set','tokyonight')
        assert 'playGif' in (home/'calls').read_text()
        run('theme','refresh')
        assert (current/'lock-wallpaper').read_bytes()==before
        assert len(list((current.parent).glob('.appearance-*')))<=2
        print(backend+': 3 palettes, independent home/lock, public login assets, fail-before-change, video/GIF routing, refresh: PASS')
