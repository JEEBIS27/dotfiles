const fs=require('fs'),vm=require('vm'),base=require('path').join(__dirname, '../../bars/widgets/ruixen.apps/');
let c={};vm.createContext(c);vm.runInContext(fs.readFileSync(base+'WindowOrder.js','utf8'),c);
let clients=[{address:'b',lastIpcObject:{at:[300,0]}},{address:'a',lastIpcObject:{at:[10,100]}},{address:'c',lastIpcObject:{at:[10,300]}}];
if(c.spatial(clients).map(x=>x.address).join()!=='a,c,b')throw Error('spatial order');
if(c.logicalWorkspaceId({id:-98,name:'special:jeebis-floats-31'})!==1)throw Error('float workspace home id');
if(c.logicalWorkspaceId({id:3,name:'3'})!==3)throw Error('ordinary workspace id');
const q=fs.readFileSync(base+'AppGroup.qml','utf8');const reorder=q.slice(q.indexOf('  function updateDisplayedApps()'),q.indexOf('  readonly property int currentWorkspaceId'));
c={switchHeld:false,appItems:[{identity:'a'},{identity:'b'}],displayedApps:[{identity:'b'},{identity:'a'}],arrivalIndex:()=>-1,departureIndex:()=>-1,arrivals:{count:0},departures:{count:0},trackedWorkspaceId:1,currentWorkspaceId:1};vm.createContext(c);vm.runInContext(reorder,c);c.updateDisplayedApps();if(c.displayedApps.map(x=>x.identity).join()!=='a,b')throw Error('reorder');
console.log('Spatial order, logical workspace and preserved-delegate reorder passed.');
const assert = require('node:assert/strict');
const host = fs.readFileSync(base+'BarWidget.qml','utf8');
const methods = host.slice(host.indexOf('  function group('), host.indexOf('  Component.onCompleted: groupsReady'));
function fixture() {
  const rows=[];
  const model={get count(){return rows.length},get:i=>rows[i],append:r=>rows.push(r),set:(i,r)=>rows[i]=r,remove:i=>rows.splice(i,1),clear:()=>rows.splice(0)};
  function member(x) {return {appMetadataCache:{a:{icon:'test'}},renderedIconX:()=>0,mapToItem:()=>({x}),reveal(){},cancelLayerTransfer(){}}}
  let ctx={tiledSurface:{group:member(10)},floatingSurface:{group:member(100)},groupsReady:true,syncingTransfers:false,layerArchive:{},transfers:{},transferRevision:0,transferWorkspace:1,workspaceId:1,transferSerial:0,transferVisuals:model,transferRepeater:{itemAt:()=>({x:55})},ShellConfig:{appTransfer:{settledMs:1000}}};
  ctx.root=ctx;vm.createContext(ctx);vm.runInContext(methods,ctx);return {ctx,rows};
}
const w=(floating,address='1')=>({address,key:'a',workspaceId:1,floating});
let {ctx,rows}=fixture();
ctx.syncTransfers([w(false)]);ctx.syncTransfers([w(true)]);
assert.equal(rows.length,1);assert.equal(rows[0].startX,10);assert.equal(ctx.iconInFlight('a',true),true);assert.equal(ctx.iconInFlight('a',false),true); // stale source row is suppressed too
let serial=rows[0].serial;ctx.syncTransfers([w(true)]);assert.equal(rows[0].serial,serial);
ctx.finishTransfer('a',serial);assert.equal(rows.length,0);assert.equal(ctx.iconInFlight('a',true),false);
ctx.syncTransfers([w(false)]);assert.equal(rows[0].startX,100);assert.equal(rows[0].toFloating,false);
serial=rows[0].serial;ctx.syncTransfers([w(true)]);assert.equal(rows.length,1);assert.equal(rows[0].startX,55);
ctx.finishTransfer('a',serial);assert.equal(rows.length,1); // stale flight must not finish its replacement
ctx.finishTransfer('a',rows[0].serial);assert.equal(rows.length,0);
({ctx,rows}=fixture());ctx.syncTransfers([w(false),w(false,'2')]);ctx.syncTransfers([w(true),w(false,'2')]);
assert.equal(rows.length,1);assert.equal(ctx.iconInFlight('a',false),false);assert.equal(ctx.iconInFlight('a',true),true);
ctx.syncTransfers([w(false,'2')]);assert.equal(rows.length,0); // closed during flight
({ctx,rows}=fixture());ctx.syncTransfers([w(false),w(true,'2')]);ctx.syncTransfers([w(true),w(true,'2')]);
assert.equal(rows.length,1);assert.equal(ctx.iconInFlight('a',true),false); // existing destination remains visible
({ctx,rows}=fixture());ctx.syncTransfers([w(false)]);ctx.syncTransfers([w(true)]);ctx.workspaceId=2;ctx.syncTransfers([w(true)]);assert.equal(rows.length,0);
({ctx,rows}=fixture());ctx.syncTransfers([w(false)]);ctx.syncTransfers([w(false),w(true,'2')]);assert.equal(rows.length,0); // actual launch
assert.ok(!host.includes('queueTransferArrival'));assert.ok(!host.includes('queueLayerDeparture'));
assert.ok(q.includes('root.logicalWindow(client)'));assert.ok(q.includes('if (previous && Number(previous.workspaceId) > 0)'));
console.log('Dedicated transfer: both directions, single proxy, reversal, stale completion, shared apps, close and workspace cancellation passed.');
