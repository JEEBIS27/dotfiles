// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),runner='/usr/lib/qt6/bin/qmltestrunner';
if(!fs.existsSync(runner)){console.log('Rolling clock Qt tests skipped: qmltestrunner unavailable.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-rolling-clock-'));
try {
 fs.writeFileSync(dir+'/ShellConfig.js',fs.readFileSync(root+'/ShellConfig.js','utf8'));
 fs.writeFileSync(dir+'/JeebisNumberAnimation.qml',fs.readFileSync(root+'/motion/JeebisNumberAnimation.qml','utf8').replace('../ShellConfig.js','ShellConfig.js'));
 for(const name of ['JeebisRollingDigit.qml','JeebisRollingClock.qml']) fs.writeFileSync(dir+'/'+name,fs.readFileSync(root+'/bars/widgets/ruixen.notch/'+name,'utf8').replace('../../../motion','.'));
 fs.writeFileSync(dir+'/tst_clock.qml',`import QtQuick
import QtTest
TestCase {
 name: "RollingClock"
 width: 220; height: 80
 visible: true
 when: windowShown
 Rectangle { anchors.fill: parent; color: "#202127" }
 JeebisRollingClock { id: clock; x: 20; y: 20; width: 65; height: 24; text: "12:34"; baseDuration: 120 }
 function cells() {
  var result=[];var children=clock.children[0].children
  for(var i=0;i<children.length;++i) if(typeof children[i].index === "number") result.push(children[i])
  return result.sort(function(a,b){return a.index-b.index})
 }
 function settleAll() { var c=cells();for(var i=0;i<c.length;++i) tryCompare(c[i],"rolling",false,2000) }
 function test_clock() {
  var c=cells();compare(c.length,5)
  for(var i=0;i<c.length;++i) {compare(c[i].rolling,false);compare(c[i].current,"12:34".charAt(i))}
  var width=clock.implicitWidth
  clock.text="12:35"
  for(var i=0;i<4;++i) compare(c[i].rolling,false)
  compare(c[4].rolling,true);settleAll();compare(c[4].progress,1);compare(c[4].current,"5")
  clock.text="12:59";settleAll();clock.text="13:00"
  compare(c[0].rolling,false);compare(c[1].rolling,true);compare(c[2].rolling,false);compare(c[3].rolling,true);compare(c[4].rolling,true)
  // A newer value must replace the pending target without stale completion.
  clock.text="14:02";settleAll()
  for(var i=0;i<c.length;++i) compare(c[i].current,"14:02".charAt(i))
  clock.text="23:59";settleAll();clock.text="00:00"
  for(var i=0;i<c.length;++i) compare(c[i].rolling,i!==2)
  settleAll();compare(clock.implicitWidth,width)
  clock.animateChanges=false;clock.text="08:47"
  for(var i=0;i<c.length;++i) {compare(c[i].rolling,false);compare(c[i].current,"08:47".charAt(i));compare(c[i].progress,1)}
  clock.animateChanges=true;clock.text="08:48";compare(c[4].rolling,true)
  clock.animateChanges=false;compare(c[4].rolling,false);compare(c[4].current,"8");compare(c[4].progress,1)
  clock.width=18;verify(clock.children[0].scale>0 && clock.children[0].scale<1)
  clock.color="#aabbcc";compare(c[0].color.toString(),"#aabbcc")
  clock.width=180;clock.height=44;clock.font.pixelSize=32;clock.animateChanges=true;clock.baseDuration=1500
  clock.text="09:59";settleAll();clock.text="10:00";wait(150)
  grabImage(clock).save("/tmp/jeebis-clock-rolling-preview.png")
  settleAll();grabImage(clock).save("/tmp/jeebis-clock-rest-preview.png")
 }
}`);
 const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
 assert.equal(result.status,0,result.stdout+result.stderr);
}finally{fs.rmSync(dir,{recursive:true,force:true});}
console.log('Rolling clock: changed digits, static colon, hour/day rollover, rapid retarget, disabled/hidden updates, width and theme passed.');
