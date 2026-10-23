const fs=require('fs'),vm=require('vm'),base=require('path').join(__dirname, '../../bars/widgets/ruixen.apps/');
let c={};vm.createContext(c);vm.runInContext(fs.readFileSync(base+'WindowOrder.js','utf8'),c);
let clients=[{address:'b',lastIpcObject:{at:[300,0]}},{address:'a',lastIpcObject:{at:[10,100]}},{address:'c',lastIpcObject:{at:[10,300]}}];
if(c.spatial(clients).map(x=>x.address).join()!=='a,c,b')throw Error('spatial order');
if(c.logicalWorkspaceId({id:-98,name:'special:jeebis-floats-31'})!==1)throw Error('float workspace home id');
if(c.logicalWorkspaceId({id:3,name:'3'})!==3)throw Error('ordinary workspace id');
const q=fs.readFileSync(base+'AppGroup.qml','utf8');const reorder=q.slice(q.indexOf('  function updateDisplayedApps()'),q.indexOf('  readonly property int currentWorkspaceId'));
c={switchHeld:false,appItems:[{identity:'a'},{identity:'b'}],displayedApps:[{identity:'b'},{identity:'a'}],arrivalIndex:()=>-1,departureIndex:()=>-1,arrivals:{count:0},departures:{count:0},trackedWorkspaceId:1,currentWorkspaceId:1};vm.createContext(c);vm.runInContext(reorder,c);c.updateDisplayedApps();if(c.displayedApps.map(x=>x.identity).join()!=='a,b')throw Error('reorder');
const departureOrder=q.slice(q.indexOf('  function updateDisplayedApps()'),q.indexOf('  readonly property int currentWorkspaceId'));
c={switchHeld:false,appItems:[{identity:'a'}],displayedApps:[],arrivalIndex:()=>-1,departureIndex:k=>k==='b'||k==='c'?0:-1,arrivals:{count:0},departures:{count:2,get:i=>[{identity:'b',appName:'B',icon:'b',phase:0,transferDirection:0},{identity:'c',appName:'C',icon:'c',phase:0,transferDirection:-1}][i]},trackedWorkspaceId:1,currentWorkspaceId:1};vm.createContext(c);vm.runInContext(departureOrder,c);c.updateDisplayedApps();if(c.displayedApps.map(x=>x.identity).join()!=='c,a,b')throw Error('transfer departure was not moved left before split');
const host=fs.readFileSync(base+'BarWidget.qml','utf8');const methods=host.slice(host.indexOf('  function group('),host.indexOf('  Component.onCompleted'));
let events=[];function group(name,has=true,phase=-1){return {hasDisplayedKey:()=>has,departurePhase:()=>phase,markLayerDeparture:(k,d)=>events.push(name+' adopt '+k+' '+d),queueLayerDeparture:k=>events.push(name+' split '+k),queueLayerArrival:k=>events.push(name+' merge '+k),queueTransferArrival:k=>events.push(name+' transfer-merge '+k),cancelLayerTransfer:k=>events.push(name+' cancel '+k)}}
c={tiledSurface:{group:group('tile')},floatingSurface:{group:group('float')},groupsReady:true,syncingTransfers:false,layerArchive:{},transfers:{},transferRevision:0,transferWorkspace:1,workspaceId:1};c.root=c;vm.createContext(c);vm.runInContext(methods,c);
const window=(floating)=>({address:'1',key:'a',workspaceId:1,floating});
c.syncTransfers([window(false)]);c.syncTransfers([window(true)]);
if(events.join()!=='tile split a'||!c.incomingBlocked('a',true))throw Error('split sequencing');
let rev=c.transferRevision;c.syncTransfers([window(true)]);if(c.transferRevision!==rev)throw Error('poll repeated transfer');
c.splitStarted('a',false);if(events.join()!=='tile split a'||!c.incomingBlocked('a',true))throw Error('destination was not blocked while source split was visible');
c.splitFinished('a',false);if(c.incomingBlocked('a',true)||events.join()!=='tile split a,float transfer-merge a')throw Error('destination did not enter after source removal');
c.syncTransfers([window(false)]);if(!events.includes('float split a'))throw Error('reverse split');c.splitStarted('a',true);if(events.at(-1)!=='float split a'||!c.incomingBlocked('a',false))throw Error('destination was not blocked while float source was visible');c.splitFinished('a',true);if(c.incomingBlocked('a',false)||events.at(-1)!=='tile transfer-merge a')throw Error('reverse arrival direction or sequencing');
events=[];c.syncTransfers([{...window(false),address:'2'}]);c.syncTransfers([{...window(false),address:'2'},window(true)]); // new address is an arrival, not a layer move
if(events.length)throw Error('new window treated as move');
console.log('Spatial order, preserved-delegate reorder, split-before-merge in both directions, stable polling, and new-window cases passed.');

// Reversing during a split cancels the stale handoff; only the latest target merges.
events=[];c.layerArchive={};c.transfers={};c.syncTransfers([window(false)]);c.syncTransfers([window(true)]);c.syncTransfers([window(false)]);
c.splitStarted('a',false);c.splitFinished('a',false);if(!c.incomingBlocked('a',false))throw Error('stale completion unblocked latest transfer');
c.splitStarted('a',true);c.splitFinished('a',true);if(c.incomingBlocked('a',false)||events.at(-1)!=='tile transfer-merge a')throw Error('latest move did not complete');
// A remaining source window keeps the source application icon.
events=[];c.layerArchive={};c.transfers={};c.syncTransfers([window(false),{...window(false),address:'2'}]);c.syncTransfers([window(true),{...window(false),address:'2'}]);
if(events.join()!=='float transfer-merge a'||c.incomingBlocked('a',true))throw Error('shared source icon removed or destination lost transfer direction');
console.log('Rapid reversal and multi-window source retention passed.');

// A transiently missing source icon still arrives from the adjacent edge.
events=[];c={tiledSurface:{group:group('tile',false)},floatingSurface:{group:group('float')},groupsReady:true,syncingTransfers:false,layerArchive:{},transfers:{},transferRevision:0,transferWorkspace:1,workspaceId:1};c.root=c;vm.createContext(c);vm.runInContext(methods,c);
c.syncTransfers([window(false)]);c.syncTransfers([window(true)]);
if(events.join()!=='float transfer-merge a')throw Error('missing source icon used generic arrival instead of adjacent transfer');
console.log('Missing-source Float arrival keeps its transfer direction.');

// If the source row already dropped its key but a departure capsule is still
// animating, adopt that capsule and wait for its completion before arrival.
events=[];c={tiledSurface:{group:group('tile',false,1)},floatingSurface:{group:group('float')},groupsReady:true,syncingTransfers:false,layerArchive:{},transfers:{},transferRevision:0,transferWorkspace:1,workspaceId:1};c.root=c;vm.createContext(c);vm.runInContext(methods,c);
c.syncTransfers([window(false)]);c.syncTransfers([window(true)]);
if(events.join()!=='tile adopt a 1'||!c.incomingBlocked('a',true))throw Error('in-flight source departure was not adopted');
c.splitFinished('a',false);
if(events.at(-1)!=='float transfer-merge a'||c.incomingBlocked('a',true))throw Error('adopted departure did not hand off after completion');
console.log('In-flight departure is adopted without a parallel destination capsule.');

const groupSource=fs.readFileSync(base+'AppGroup.qml','utf8');
if(!groupSource.includes('Hyprland.toplevels.values || []')||!groupSource.includes('root.logicalWindow(client)'))throw Error('floating islands do not preserve temporarily parked windows');
if(groupSource.includes('if (root.trackingReady) root.reveal()'))throw Error('window list changes still trigger generic launch reveal');
if(!groupSource.includes('transfer ? (fromLeft ? -width - Style.space(16)'))throw Error('transfer arrivals do not enter from the neighboring edge');
if(!fs.readFileSync(base+'BarWidget.qml','utf8').includes('group(current.floating).queueTransferArrival(key, !previous.floating)'))throw Error('missing-source transfer falls back to a generic arrival');
if(!fs.readFileSync(base+'BarWidget.qml','utf8').includes('source.queueLayerDeparture(key, previous.floating ? -1 : 1)'))throw Error('transfer direction is not passed before departure is queued');
if(!groupSource.includes('function queueLayerDeparture(key, direction)'))throw Error('departure cannot accept an explicit transfer direction');
if(!groupSource.includes('if (previous && Number(previous.workspaceId) > 0)'))throw Error('transient float parking loses cached home workspace');
console.log('Parked-window persistence, no generic relaunch reveal, and adjacent-edge transfer arrival passed.');
