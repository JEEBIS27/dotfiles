// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),config=fs.readFileSync(root+'/ShellConfig.js','utf8'),model=vm.createContext({});
vm.runInContext(config.replace(/^\.pragma library\s*/,''),model);
Object.assign(model,{barAnimationPreset:'Linear',barShowAnimationPreset:'OutBounce',barHideAnimationPreset:'InQuart',notchAnimationPreset:'OutBack',notchShowAnimationPreset:'InOutSine',notchHideAnimationPreset:'Linear',hyprlandAnimationPreset:'Linear'});
for(const [group,normal,show,hide] of [['bar','Linear','OutBounce','InQuart'],['notch','OutBack','InOutSine','Linear']]) {
 assert.equal(model.motionPreset(false,group),normal);
 assert.equal(model.motionPreset(false,group,'show'),show);
 assert.equal(model.motionPreset(false,group,'hide'),hide);
}
assert.equal(model.motionPreset(true,'notch'),'InOutSine');
assert.equal(model.motionProgress(.5,false,'bar'),.5);
model.barAnimationPreset='InQuart';assert.equal(model.motionProgress(.5,false,'bar'),.0625);
assert.ok(model.motionProgress(.8,false,'notch')>1);
model.notchHideAnimationPreset='invalid';assert.equal(model.motionPreset(false,'notch','hide'),'InOutSine');
const n=fs.readFileSync(root+'/bars/widgets/ruixen.notch/NotchWindow.qml','utf8');
assert.ok(n.includes('motionGroup: panel.notchRoot.barIslandsMode ? "notch" : "bar"'));
assert.ok(n.includes('motionDirection: panel.notchRoot.barShown ? "show" : "hide"'));
assert.ok(fs.readFileSync(root+'/bars/v2/ruixen.bar/JeebisBarVisibility.qml','utf8').includes('motionGroup: control.unified ? "bar" : "notch"'));
const runner='/usr/lib/qt6/bin/qmltestrunner';
if(fs.existsSync(runner)) {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-motion-selection-'));
 try {
  let c=config;
  for(const [key,value] of Object.entries({barAnimationPreset:'Linear',barShowAnimationPreset:'OutBounce',barHideAnimationPreset:'InQuart',notchAnimationPreset:'OutBack',notchShowAnimationPreset:'InOutSine',notchHideAnimationPreset:'Linear'}))c=c.replace(new RegExp('var '+key+' = "[^"]*";'),'var '+key+' = "'+value+'";');
  fs.writeFileSync(dir+'/ShellConfig.js',c);
  fs.writeFileSync(dir+'/JeebisNumberAnimation.qml',fs.readFileSync(root+'/motion/JeebisNumberAnimation.qml','utf8').replace('../ShellConfig.js','ShellConfig.js'));
  fs.writeFileSync(dir+'/tst_selection.qml',`import QtQuick
import QtTest
TestCase {
 id: testCase; name: "MotionSelection"
 property string group: "bar"
 property bool shown: false
 property real value: shown ? 1 : 0
 Behavior on value { JeebisNumberAnimation {
  id: motion; motionGroup: testCase.group; motionDirection: testCase.shown ? "show" : "hide"; baseDuration: 500
 } }
 function test_directions_and_interruption() {
  for (var i=0,groups=["bar","notch"];i<groups.length;i++) {
   group=groups[i];shown=true;wait(40)
   compare(motion.preset, group==="bar" ? "OutBounce" : "InOutSine")
   compare(motion.easing.type, group==="bar" ? Easing.OutBounce : Easing.InOutSine)
   // Reverse an in-flight animation: departure must immediately use Hide.
   shown=false;wait(10)
   compare(motion.preset, group==="bar" ? "InQuart" : "Linear")
   compare(motion.easing.type, group==="bar" ? Easing.InQuart : Easing.Linear)
   tryCompare(motion,"running",false,2000);compare(value,0)
   shown=true;tryCompare(motion,"running",false,2000);compare(value,1)
   shown=false;tryCompare(motion,"running",false,2000);compare(value,0)
  }
 }
}`);
  const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
  assert.equal(result.status,0,result.stdout+result.stderr);
 } finally {fs.rmSync(dir,{recursive:true,force:true});}
}
console.log('Motion selection: independent groups, show/hide, bounded fallback and live reversal passed.');
