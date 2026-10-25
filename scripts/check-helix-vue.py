import json,subprocess,threading,queue,time,pathlib
import argparse, tomllib, shutil, sys
parser=argparse.ArgumentParser(description="Probe Vue TypeScript diagnostics/completion using the generated Helix config")
parser.add_argument("fixture", type=pathlib.Path, help="Dedicated temporary Vue project with vue and typescript installed")
parser.add_argument("--languages", type=pathlib.Path, required=True)
args=parser.parse_args()
root=args.fixture.resolve(); uri=(root/'App.vue').as_uri()
assert (root/'node_modules/vue/package.json').is_file(), "Install Vue in the temporary fixture first"
source='<script setup lang="ts">\nconst count: number = "wrong"\nconst message = "hello"\nmessage.\n</script>\n<template><p>{{ count }}</p></template>\n'
(root/'App.vue').write_text(source)
(root/'tsconfig.json').write_text(json.dumps({'compilerOptions':{'strict':True,'target':'ESNext','module':'ESNext','moduleResolution':'Bundler','allowJs':True},'include':['**/*.vue']}))
config=tomllib.loads(args.languages.read_text())["language-server"]["vtsls"]["config"]
p=subprocess.Popen([shutil.which('vtsls') or 'vtsls','--stdio'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,cwd=root)

def send(x):
 b=json.dumps({'jsonrpc':'2.0',**x}).encode(); p.stdin.write(f'Content-Length: {len(b)}\r\n\r\n'.encode()+b);p.stdin.flush()
q=queue.Queue()
def read():
 while True:
  h={}
  while True:
   line=p.stdout.readline()
   if not line:return
   if line==b'\r\n':break
   k,v=line.decode().split(':',1);h[k.lower()]=v.strip()
  q.put(json.loads(p.stdout.read(int(h['content-length']))))
threading.Thread(target=read,daemon=True).start()
send({'id':1,'method':'initialize','params':{'processId':None,'rootUri':root.as_uri(),'capabilities':{'workspace':{'configuration':True},'textDocument':{'publishDiagnostics':{'relatedInformation':True},'completion':{'completionItem':{'snippetSupport':True}}}},'workspaceFolders':[{'uri':root.as_uri(),'name':'probe'}]}})
deadline=time.time()+55; initialized=False; diagnostics=[]; completion=None; opened=False; changed=False; start=time.time()
try:
 while time.time()<deadline:
  if initialized and not opened and time.time()-start>4:
   send({'method':'textDocument/didOpen','params':{'textDocument':{'uri':uri,'languageId':'vue','version':1,'text':source}}});opened=True;send({'id':2,'method':'textDocument/completion','params':{'textDocument':{'uri':uri},'position':{'line':3,'character':8},'context':{'triggerKind':1}}})
  if opened and not changed and time.time()-start>8:
   send({'method':'textDocument/didChange','params':{'textDocument':{'uri':uri,'version':2},'contentChanges':[{'text':source+'\n'}]}});changed=True
  try:m=q.get(timeout=0.3)
  except queue.Empty:continue
  if 'method' in m and 'id' in m:
   if m['method']=='workspace/configuration':
    vals=[]
    for it in m['params']['items']:
     val=config
     for part in filter(None,it.get('section','').split('.')):
      val=val.get(part,{}) if isinstance(val,dict) else {}
     vals.append(val)
    send({'id':m['id'],'result':vals})
   else:send({'id':m['id'],'result':None})
  elif m.get('id')==1:
   send({'method':'initialized','params':{}});send({'method':'workspace/didChangeConfiguration','params':{'settings':config}})
   initialized=True
  elif m.get('method')=='textDocument/publishDiagnostics':
   diagnostics+=m['params']['diagnostics']
   if True:
    send({'id':2,'method':'textDocument/completion','params':{'textDocument':{'uri':uri},'position':{'line':3,'character':8},'context':{'triggerKind':1}}})
  elif m.get('id')==2:
   completion=m.get('result')
  if completion and any(d.get('code')==2322 for d in diagnostics):break
 labels={item['label'] for item in (completion or {}).get('items', [])}
 assert any(d.get('code')==2322 for d in diagnostics), f"Type error 2322 missing: {diagnostics}"
 assert 'toUpperCase' in labels, f"String completion missing: {labels}"
 print(f"PASS: Vue type error 2322 and {len(labels)} string completions through standard LSP")
finally:p.terminate();p.wait(timeout=5)
