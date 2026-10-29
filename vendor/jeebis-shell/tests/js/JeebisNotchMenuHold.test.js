// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),notch=root+'/bars/widgets/ruixen.notch/';
const status=fs.readFileSync(notch+'NotchStatus.qml','utf8'),overlay=fs.readFileSync(notch+'Overlay.qml','utf8'),window=fs.readFileSync(notch+'NotchWindow.qml','utf8');
const lifecycle=status.slice(status.indexOf('  property string activeMenu:'),status.indexOf('  readonly property int unreadCount:'));
const counter=overlay.slice(overlay.indexOf('  function setBarNotchMenuOpen('),overlay.indexOf('  property bool lastNotchHold:'));
const hold=overlay.match(/var held = ([^\n]+)/)[1];
assert.ok(window.includes('onMenuHoldChanged: function(held) { panel.notchRoot.setBarNotchMenuOpen(held) }'));
const runner='/usr/lib/qt6/bin/qmltestrunner';if(!fs.existsSync(runner)){console.log('Menu lifecycle source checked; Qt runtime skipped.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jeebis-menu-hold-'));
try {
 fs.writeFileSync(dir+'/ShellConfig.js',fs.readFileSync(root+'/ShellConfig.js','utf8'));
 fs.writeFileSync(dir+'/JeebisNumberAnimation.qml',fs.readFileSync(root+'/motion/JeebisNumberAnimation.qml','utf8').replace('../ShellConfig.js','ShellConfig.js'));
 fs.writeFileSync(dir+'/JeebisIslandVisibility.qml',fs.readFileSync(root+'/bars/v2/ruixen.bar/JeebisIslandVisibility.qml','utf8').replace('../../../motion','.').replace('../../../ShellConfig.js','ShellConfig.js'));
 fs.writeFileSync(dir+'/tst_menu.qml',`import QtQuick
import QtTest
TestCase {
 id: testCase
 name: "NotchMenuHold"
 visible: true; width: 100; height: 100
 Item {
  id: owner
  property int barNotchHoverCount: 0
  property int barNotchMenuCount: 0
  property bool pinnedOpen: false
  property bool launcherOpen: false
  readonly property bool held: ${hold}
  function syncBarNotchHold() {}
  ${counter}
 }
 JeebisIslandVisibility { id: notch; behavior: "auto"; held: owner.held }
 Component {
  id: statusComponent
  Item {
   property string hoverTarget: ""
   ${lifecycle}
   onMenuHoldChanged: function(held) { owner.setBarNotchMenuOpen(held) }
  }
 }
 function test_open_switch_close_and_destroy() {
  var a=createTemporaryObject(statusComponent,testCase),b=createTemporaryObject(statusComponent,testCase)
  owner.barNotchHoverCount=1;a.activeMenu="wifi";compare(owner.barNotchMenuCount,1)
  owner.barNotchHoverCount=0
  wait(2500);compare(owner.held,true);compare(notch.shown,true)
  a.activeMenu="audio";compare(owner.barNotchMenuCount,1)
  b.activeMenu="battery";compare(owner.barNotchMenuCount,2)
  a.activeMenu="";compare(owner.barNotchMenuCount,1);compare(owner.held,true)
  b.activeMenu="";compare(owner.barNotchMenuCount,0)
  tryCompare(notch,"shown",false,1500)
  a.activeMenu="notifications";compare(owner.barNotchMenuCount,1)
  a.visible=false;compare(owner.barNotchMenuCount,0)
  b.activeMenu="battery";compare(owner.barNotchMenuCount,1)
  b.destroy();tryCompare(owner,"barNotchMenuCount",0,1000)
  a.destroy();wait(0);compare(owner.barNotchMenuCount,0)
 }
}`);
 const result=cp.spawnSync(runner,['-input',dir],{encoding:'utf8',env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'}});
 assert.equal(result.status,0,result.stdout+result.stderr);
}finally{fs.rmSync(dir,{recursive:true,force:true});}
console.log('Notch menu: holds beyond auto-hide, no double hold on switch, multi-window close/hide/destruction release passed.');
