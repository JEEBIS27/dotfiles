#!/usr/bin/env python3
import tempfile,subprocess,json,sys,os
from pathlib import Path
r=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
 p=Path(d); helper=p/'helper.py'
 helper.write_text('import os,sys,json\ndef main():\n print(json.dumps({"config":json.loads(sys.argv[-1]), "state":os.environ.get("XDG_STATE_HOME")}))\n return 0\n')
 command=[sys.executable,str(r/'packages/desktop/rotation-watch.py'),str(helper)]
 session=json.loads(subprocess.check_output(command+['session',str(r/'vendor/jeebis-shell/ShellConfig.js')],text=True))
 assert session['config']['animation'] is True
 assert session['config']['delayMs']==1000
 greeter=json.loads(subprocess.check_output(command+['greeter'],env=dict(os.environ,XDG_RUNTIME_DIR=d),text=True))
 assert greeter['config']['animation'] is False and greeter['config']['automatic'] is True
 assert greeter['state']==str(p/'jeebis-greeter')
 print('Rotation wrapper: ShellConfig preserved; greeter state isolated; greeter capture disabled.')
