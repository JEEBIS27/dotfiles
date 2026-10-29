// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const m=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../../bars/v2/ruixen.bar/JeebisBarVisibilityModel.js'),'utf8'),m);
const plain=x=>JSON.parse(JSON.stringify(x));
function mode(target,behavior,reserve=false){return {target,behavior,reserve}}
for(const target of ['bar','islands']) {
  const auto=mode(target,'auto'),overlay=mode(target,'always'),fixed=mode(target,'always',true),off=mode(target,'off');
  assert.deepEqual(plain(m.next(auto,target,false)),overlay);
  assert.deepEqual(plain(m.next(overlay,target,false)),auto);
  assert.deepEqual(plain(m.next(fixed,target,false)),auto);
  assert.deepEqual(plain(m.next(fixed,target,true)),off);
  for(const previous of [off,auto,overlay]) assert.deepEqual(plain(m.next(previous,target,true)),fixed);
  for(const held of [false,true])for(const activity of [false,true])for(const bridge of [false,true]) {
    assert.equal(m.shown(off,held,activity,bridge),false);
    assert.equal(m.shown(fixed,held,activity,bridge),true);
    assert.equal(m.shown(overlay,held,activity,bridge),true);
    assert.equal(m.shown(auto,held,activity,bridge),held||activity||bridge);
  }
}
assert.deepEqual(plain(m.next(mode('islands','always',true),'bar',true)),mode('bar','always',true));
assert.deepEqual(plain(m.next(mode('bar','off'),'islands',false)),mode('islands','auto'));
assert.deepEqual(plain(m.normalize({target:'invalid',behavior:'off',reserve:true})),mode('bar','off'));
for(const e of ['openwindow','closewindow','workspace','workspacev2'])assert.equal(m.isActivity(e),true);
for(const e of ['activewindow','movewindow','floating','',undefined])assert.equal(m.isActivity(e),false);
console.log('Bar visibility: both targets, overlay/fixed toggles, complete off, hover/activity and cross-mode transitions passed.');

assert.deepEqual(plain(m.normalize({target:'notch',behavior:'auto'})),mode('islands','auto'));
assert.deepEqual(plain(m.revealSections('bar',true,'left')),['left','notch','right']);
assert.deepEqual(plain(m.revealSections('islands',false,'right')),['left','notch','right']);
for(const section of ['left','notch','right']) assert.deepEqual(plain(m.revealSections('islands',true,section)),[section]);
const geometry={left:{x:5,width:120},notch:{x:450,width:300},right:{x:950,width:240}};
assert.equal(m.sectionAt(geometry,50),'left');assert.equal(m.sectionAt(geometry,600),'notch');assert.equal(m.sectionAt(geometry,1100),'right');assert.equal(m.sectionAt(geometry,300),'');
console.log('Island visibility: legacy migration, independent triggers, unified mode and section hit testing passed.');

assert.equal(m.sectionBehavior(mode('islands','always'),'notch'),'always');
assert.equal(m.sectionBehavior(mode('islands','always'),'left'),'auto');
assert.equal(m.sectionBehavior(mode('islands','always',true),'right'),'auto');
for(const section of ['left','notch','right']) {
  assert.equal(m.sectionBehavior(mode('bar','always'),section),'always');
  assert.equal(m.sectionBehavior(mode('islands','off'),section),'off');
}
console.log('Island always mode: fixed notch, auto-hide sides, and complete off passed.');
