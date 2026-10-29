// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
function scan(dir){for(const file of fs.readdirSync(dir,{withFileTypes:true})){
 const full=path.join(dir,file.name);
 if(file.isDirectory()){if(!['tests','.git','motion'].includes(file.name))scan(full);continue;}
 if(!file.name.endsWith('.qml'))continue;
 const text=fs.readFileSync(full,'utf8');
 assert.ok(!/(?<![\w.])(?:NumberAnimation|ColorAnimation|PropertyAnimation|RotationAnimation|RotationAnimator)\s*(?:on\s+\w+\s*)?\{/.test(text),full+' bypasses shared motion');
 if(/Motion\.Jeebis/.test(text))assert.ok(/import "[^"\n]*motion" as Motion/.test(text),full+' has no shared motion import');
}}
scan(root);console.log('Shared motion coverage: all shell-owned Qt animations use the common components.');
