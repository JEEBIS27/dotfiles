// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),n=root+'/bars/widgets/ruixen.notch/',runner='/usr/lib/qt6/bin/qmltestrunner';
const window=fs.readFileSync(n+'NotchWindow.qml','utf8'),overlay=fs.readFileSync(n+'Overlay.qml','utf8');
assert.ok(window.includes('Translate { y: panel.notchRoot.barIslandsMode ? 0 :'));
assert.ok(window.includes('enabled: !panel.notchRoot.barIslandsMode'));
assert.ok(window.includes('centerX: notchOuter.width / 2'));
assert.ok(overlay.includes('root.barIslandsMode = state.target === "islands"'));
if(!fs.existsSync(runner)){console.log('Notch scale wiring checked; Qt runtime unavailable.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-notch-scale-'));
try {
 fs.copyFileSync(n+'JeebisNotchRevealScale.qml',dir+'/JeebisNotchRevealScale.qml');
 fs.writeFileSync(dir+'/JeebisNumberAnimation.qml',fs.readFileSync(root+'/motion/JeebisNumberAnimation.qml','utf8').replace('../ShellConfig.js','ShellConfig.js'));
 for(const preset of ['Linear','InOutSine','OutBack','OutBounce','InQuart']) {
  fs.writeFileSync(dir+'/ShellConfig.js',fs.readFileSync(root+'/ShellConfig.js','utf8').replace(/var barAnimationPreset = "[^"]+";/,'var barAnimationPreset = "'+preset+'";').replace(/var animationSpeed = [^;]+;/,'var animationSpeed = 1;'));
  fs.writeFileSync(dir+'/tst_scale.qml',`import QtQuick
import QtTest
TestCase {
 id: testCase
 name: "NotchTopAnchor_${preset}"
 width: 400; height: 200; visible: true
 property real maxScale: 0
 property real maxTopError: 0
 Item {
  id: surface
  anchors.horizontalCenter: parent.horizontalCenter
  width: 200; height: 40
  transform: JeebisNotchRevealScale {
   id: reveal
   independent: true; centerX: surface.width/2; progress: 0
   onXScaleChanged: {
    testCase.maxScale=Math.max(testCase.maxScale,xScale)
    var p=surface.mapToItem(testCase,surface.width/2,0)
    testCase.maxTopError=Math.max(testCase.maxTopError,Math.abs(p.y))
   }
  }
 }
 JeebisNumberAnimation { id: motion; target: reveal; property: "progress"; from: 0; to: 1; baseDuration: 300 }
 function checkAnchor() {
  var p=surface.mapToItem(testCase,surface.width/2,0)
  verify(Math.abs(p.y)<0.00001);verify(Math.abs(p.x-width/2)<0.00001)
 }
 function test_scale() {
  for(var i=0,values=[0,.2,.5,1,1.1,1.25,-.2];i<values.length;++i) {
   reveal.progress=values[i];checkAnchor()
   var p=surface.mapToItem(testCase,surface.width/2,surface.height)
   verify(Math.abs(p.y-surface.height*Math.max(0,values[i]))<0.00001)
  }
  surface.width=280;reveal.progress=1.1;checkAnchor()
  reveal.independent=false;reveal.progress=.2;compare(reveal.xScale,1);compare(reveal.yScale,1)
  reveal.independent=true;testCase.maxScale=0;testCase.maxTopError=0
  motion.start();tryCompare(motion,"running",false,2000)
  compare(reveal.progress,1);checkAnchor();verify(maxTopError<0.00001)
  verify(${preset==='OutBack'?'maxScale>1.05':'maxScale<=1'})
  motion.from=1;motion.to=0;motion.start();tryCompare(motion,"running",false,2000)
  compare(reveal.progress,0);compare(reveal.xScale,0);compare(reveal.yScale,0);checkAnchor()
 }
}`);
  const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
  assert.equal(result.status,0,result.stdout+result.stderr);
 }
}finally{fs.rmSync(dir,{recursive:true,force:true});}
console.log('Notch reveal: fixed top/center through all presets, positive overshoot, negative clamp, resize and unified-mode bypass passed.');
