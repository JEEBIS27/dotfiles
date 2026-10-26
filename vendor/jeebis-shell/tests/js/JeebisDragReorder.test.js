// Jeebis: test the plans and execute generated Lua against a compositor fixture.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),cp=require('node:child_process'),path=require('node:path');
const base=path.join(__dirname,'../../bars/widgets');
function load(file){const c=vm.createContext({});vm.runInContext(fs.readFileSync(file,'utf8'),c);return c}
const apps=load(base+'/ruixen.apps/WindowOrder.js');
const ws=load(base+'/ruixen.workspaces/JeebisWorkspaceOrder.js');
const windows=[{identity:'a',address:'0x1'},{identity:'a',address:'0x2'},{identity:'b',address:'0x3'},{identity:'c',address:'0x4'}];
assert.equal(Array.from(apps.reorderPlan(windows,['a','b','c'],'a','c')).join(), '0x3,0x4,0x1,0x2');
assert.equal(Array.from(apps.reorderPlan(windows,['a','b','c'],'c','a')).join(), '0x4,0x1,0x2,0x3');
assert.equal(apps.reorderPlan(windows,['a','b','c'],'a','a').length,0);
assert.throws(()=>apps.reorderScript([{address:'injected()'}],['injected()'],false));
assert.equal(ws.swapScript(1,1),'');assert.equal(ws.swapScript('1; os.exit()',2),'');
function lua(code,setup,checks){const fixture=`
local a={address='0x1',floating=false,at={x=10,y=20},workspace={id=1},tags={}}
local b={address='0x2',floating=false,at={x=90,y=50},workspace={id=2},tags={}}
local windows={a,b};local focused={id=1};local focusedTarget=nil
hl={get_windows=function()return windows end,get_active_workspace=function()return focused end,dsp={window={},focus=function(x)x.kind='focus';return x end}}
for _,name in ipairs({'move','swap','tag'})do hl.dsp.window[name]=function(x)x.kind=name;return x end end
hl.dispatch=function(x)
 if x.kind=='swap' then x.window.at,x.target.at=x.target.at,x.window.at
 elseif x.kind=='move' then if x.workspace then x.window.destination=x.workspace else x.window.at={x=x.x,y=x.y} end
 elseif x.kind=='tag' then x.window.lastTag=x.tag
 elseif x.kind=='focus' then focusedTarget=x.workspace end
end
${setup}
do
${code}
end
${checks}
`;
const r=cp.spawnSync('lua',['-'],{input:fixture,encoding:'utf8'});assert.equal(r.status,0,r.stderr)}
let pair=[{address:'0x1'},{address:'0x2'}];
lua(apps.reorderScript(pair,['0x2','0x1'],false),'',"assert(a.at.x==90 and b.at.x==10)");
lua(apps.reorderScript(pair,['0x2','0x1'],true),'a.floating=true;b.floating=true',"assert(a.at.x==90 and a.at.y==50 and b.at.x==10 and b.at.y==20)");
lua(ws.swapScript(1,2),'',"assert(a.destination=='2' and b.destination=='1' and focusedTarget=='2')");
lua(ws.swapScript(1,2),"a.workspace={id=-9};a.tags={'jeebis-float-home-31'}", "assert(a.destination=='special:jeebis-floats-32' and a.lastTag=='+jeebis-float-home-32')");
console.log('Drag reorder: grouped insertion, tile/float moves, workspace swap, parked floats and input validation passed.');
