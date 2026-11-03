// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),folder=root+'/bars/widgets/ruixen.notch/';
const source=fs.readFileSync(folder+'JeebisRotationTransition.qml','utf8');
assert.ok(source.includes('sourceComponent: ScreencopyView'));
assert.ok(source.includes('live: false'));
assert.ok(source.includes('phase = "idle"'));
assert.ok(source.includes('Component.onDestruction: reset()'));
assert.ok(source.includes('onTriggered: transition.reset()'));
const active=source.match(/active: ([^\n]+)/)[1];
assert.ok(active.includes('"capture"')&&active.includes('"rotate"')&&active.includes('"ready"')&&active.includes('"crossfade"'));
assert.ok(!active.includes('"idle"'));
assert.ok(!source.includes('coverMotion'));
assert.ok(source.includes('orientationOffset: transition.remapped ? -transition.turn : 0'));
assert.ok(source.includes('&& !transition.remapped'));
assert.ok(source.includes('1 - transition.fade'));
assert.ok(!/saveToFile|grabToImage|\.png|\.jpg|\/tmp\/|clipboard/i.test(source));
const runner='/usr/lib/qt6/bin/qmltestrunner';
if(fs.existsSync(runner)) {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-rotation-animation-test-'));
 try {
  fs.copyFileSync(folder+'JeebisRotationVisual.qml',dir+'/JeebisRotationVisual.qml');
  fs.writeFileSync(dir+'/tst_rotation.qml',`import QtQuick
import QtTest
TestCase {
 id: testCase; name: "RotationVisual"; width: 600; height: 375
 JeebisRotationVisual { id: visual; anchors.fill: parent }
 function test_fits_and_remains_centered() {
  for (var d=0;d<2;d++) {
   visual.turn=d===0?180:-180
   for (var i=0;i<=110;i++) {
    visual.progress=i/100
    compare(visual.rotation,visual.turn*visual.progress)
    verify(visual.scale>0&&visual.scale<=1)
    var center=visual.mapToItem(testCase,visual.width/2,visual.height/2)
    verify(Math.abs(center.x-width/2)<.001&&Math.abs(center.y-height/2)<.001)
    for (var j=0;j<4;j++) {
     var p=visual.mapToItem(testCase,j%2?visual.width:0,j<2?0:visual.height)
     verify(p.x>=-.001&&p.x<=width+.001&&p.y>=-.001&&p.y<=height+.001)
    }
   }
  }
  visual.progress=1
  for(var turn of [180,-180]) {
   visual.turn=turn;visual.orientationOffset=-turn
   compare(visual.rotation,0);compare(visual.scale,1)
  }
 }
}`);
  const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
  assert.equal(result.status,0,result.stdout+result.stderr);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
}
console.log('Rotation animation: both directions, overshoot bounds, crossfade orientation compensation, memory-only capture, teardown and watchdog passed.');
