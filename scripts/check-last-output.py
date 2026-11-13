import importlib.util, os, pathlib, subprocess, tempfile
p=pathlib.Path(__file__).resolve().parent.parent / 'files/desktop/helpers/jeebis-last-output.py'
with tempfile.TemporaryDirectory() as d:
 log=pathlib.Path(d)/'output'
 env=dict(os.environ,JEEBIS_OUTPUT_LOG=str(log),JEEBIS_OUTPUT_TOKEN='test')
 start=b'\x1b]777;jeebis;test;start\x07';end=b'\x1b]777;jeebis;test;end\x07'
 for raw,expected in [(b'',b''),('日本語\r\n二行目\r\n'.encode(),'日本語\n二行目\n'.encode()),(b'\x1b[31merror\x1b[0m\r\n',b'error\n'),(b'old\rnew\r\n',b'new\n'),(b'a\r\n\r\n',b'a\n\n'),(b'a\x1b[3Cb\r\n',b'a   b\n')]:
  log.write_bytes(b'prompt'+start+raw+end+b'prompt'+start)
  r=subprocess.run([os.sys.executable,str(p)],env=env,capture_output=True)
  assert r.returncode==0,(r.returncode,r.stderr)
  assert r.stdout==expected,(r.stdout,expected)
 log.write_bytes(start)
 r=subprocess.run([os.sys.executable,str(p)],env=env,capture_output=True)
 assert r.returncode==1
 print('7 extraction cases passed')
