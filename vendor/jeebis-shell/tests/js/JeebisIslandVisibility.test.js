// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),runner='/usr/lib/qt6/bin/qmltestrunner';
if(!fs.existsSync(runner)){console.log('Island Qt runtime skipped: qmltestrunner unavailable.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-island-test-'));
try {
 fs.writeFileSync(dir+'/ShellConfig.js',fs.readFileSync(root+'/ShellConfig.js','utf8').replace(/var barActivityShowDuration = [^;]+;/,'var barActivityShowDuration = 100;').replace(/var barSlideDuration = [^;]+;/,'var barSlideDuration = 20;'));
 fs.writeFileSync(dir+'/JeebisNumberAnimation.qml',fs.readFileSync(root+'/motion/JeebisNumberAnimation.qml','utf8').replace('../ShellConfig.js','ShellConfig.js'));
 fs.writeFileSync(dir+'/JeebisIslandVisibility.qml',fs.readFileSync(root+'/bars/v2/ruixen.bar/JeebisIslandVisibility.qml','utf8').replace('../../../motion','.').replace('../../../ShellConfig.js','ShellConfig.js'));
 fs.writeFileSync(dir+'/tst_island.qml',`import QtQuick
import QtTest
TestCase {
 name: "IndependentIslandVisibility"
 JeebisIslandVisibility { id: left; behavior: "auto" }
 JeebisIslandVisibility { id: right; behavior: "auto" }
 JeebisIslandVisibility { id: notch; behavior: "always" }
 function test_independent_timers_and_holds() {
  compare(left.shown,false);compare(right.shown,false);compare(notch.shown,true)
  left.reveal();compare(left.shown,true);compare(right.shown,false)
  tryCompare(left,"activity",false,2000);compare(left.shown,false)
  right.reveal();left.reveal();left.reset()
  compare(left.shown,false);compare(right.shown,true);compare(notch.shown,true)
  left.held=true;compare(left.shown,true);right.reset();compare(right.shown,false)
  left.held=false;compare(left.shown,true)
  tryCompare(left,"shown",false,2000)
  left.behavior="off";left.held=true;left.reveal();compare(left.shown,false);compare(left.activity,false)
  notch.behavior="off";compare(notch.shown,false)
 }
}`);
 const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
 assert.equal(result.status,0,result.stdout+result.stderr);
}finally{fs.rmSync(dir,{recursive:true,force:true});}
console.log('Island Qt runtime: independent expiry/reset, hover bridge, fixed notch and fully hidden passed.');
