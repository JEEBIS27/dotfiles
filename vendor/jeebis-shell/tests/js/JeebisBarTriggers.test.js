// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const cp = require('node:child_process'), os = require('node:os');
const root = path.resolve(__dirname, '../..'), m = vm.createContext({});
vm.runInContext(fs.readFileSync(root + '/bars/v2/ruixen.bar/JeebisBarTriggerModel.js', 'utf8'), m);
const config = vm.createContext({}); vm.runInContext(fs.readFileSync(root + '/ShellConfig.js', 'utf8').replace(/^\.pragma library\s*/, ''), config);
for (const mode of ['bar', 'islands']) {
  for (const setting of ['bar', 'islands', 'both', 'none', 'invalid', undefined]) {
    assert.equal(m.enabled({low_battery: setting}, 'low_battery', mode), setting === 'both' || setting === mode);
  }
  assert.equal(m.enabled({}, 'app_open', mode), false);
  assert.equal(m.enabled(null, 'app_open', mode), false);
  assert.equal(m.enabled(config.barTriggerModes, 'toString', mode), false);
}
assert.equal(m.enabled(config.barTriggerModes, 'app_open', 'bar'), true);
assert.equal(m.enabled(config.barTriggerModes, 'app_open', 'islands'), true);
assert.equal(m.enabled(config.barTriggerModes, 'workspace', 'bar'), false);
assert.equal(m.enabled(config.barTriggerModes, 'workspace', 'islands'), true);
for (const [raw, expected] of [['openwindow','app_open'], ['closewindow','app_close'], ['workspace','workspace'], ['workspacev2','workspace'], ['activewindow',''], ['', '']]) assert.equal(m.eventTrigger(raw), expected);
const battery = (percent, charging=false, present=true) => ({percent,charging,present});
assert.equal(m.changed('battery', null, battery(20), 30), '');
assert.equal(m.changed('battery', battery(31), battery(30), 30), 'low_battery');
assert.equal(m.changed('battery', battery(30), battery(29), 30), '');
assert.equal(m.changed('battery', battery(31), battery(30), 20), '');
assert.equal(m.changed('battery', battery(20,true), battery(20,false), 30), 'low_battery');
assert.equal(m.changed('battery', battery(31), battery(20,true), 30), '');
assert.equal(m.changed('battery', battery(31), battery(0,false,false), 30), '');
assert.equal(m.changed('network', null, false), '');
assert.equal(m.changed('network', true, false), 'network_disconnect');
assert.equal(m.changed('network', false, true), 'network_reconnect');
assert.equal(m.changed('network', true, true), '');
const audio=(volume,muted=false,sink=1)=>({volume,muted,sink});
assert.equal(m.changed('audio', null, audio(.2)), '');
assert.equal(m.changed('audio', audio(.2), audio(.3)), 'volume_change');
assert.equal(m.changed('audio', audio(.2), audio(.2,true)), 'volume_change');
assert.equal(m.changed('audio', audio(.2), audio(.2)), '');
assert.equal(m.changed('audio', audio(.2), audio(.3,false,2)), '');
assert.equal(m.changed('agent', null, true), '');
assert.equal(m.changed('agent', false, true), 'agent_limit');
assert.equal(m.changed('agent', true, true), '');
assert.equal(m.changed('agent', true, false), '');
const now=Date.parse('2026-10-28T00:00:00Z'), record=(percent,resetsAt='2026-10-28T01:00:00Z')=>({ready:true,limits:[{percent,resetsAt}]});
assert.equal(m.exhausted(record(.99),now), false);
assert.equal(m.exhausted(record(1),now), true);
assert.equal(m.exhausted(record(1,'2026-10-27T00:00:00Z'),now), false);
assert.equal(m.exhausted({ready:false,limits:[{percent:1}]},now), null);
assert.equal(m.exhausted({},now), null);
// Routing must not replace mode.target; only the existing auto-hide timer is restarted.
const control=fs.readFileSync(root+'/bars/v2/ruixen.bar/JeebisBarVisibility.qml','utf8');
const body=control.slice(control.indexOf('  function triggerEvent('),control.indexOf('  JeebisBarTriggers'));
assert.ok(body.includes('if (!autoHide ||'));
assert.ok(body.includes('Triggers.enabled(ShellConfig.barTriggerModes, name, mode.target)'));
assert.ok(!body.includes('mode =') && !body.includes('selectMode('));
const service=fs.readFileSync(root+'/bars/widgets/ruixen.notch/NotificationService.qml','utf8');
assert.ok(service.includes('if (service.primed && entry.timestamp >= service.startedAt) service.notificationArrived()'));
assert.ok(service.indexOf('service.absorb(batch)') < service.indexOf('service.primed = true'));
console.log('Bar triggers: mode filters, all event transitions, initial baselines, reset windows and unchanged mode passed.');

// A short notification can already be archived before the next 3s sweep.
// Exercise the real sweep command with an empty live directory, not a copy of it.
const command = JSON.parse(service.match(/sweepProc\.command = \["bash", "-c",\s*("(?:[^"\\]|\\.)*")/)[1]);
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'jeebis-notification-trigger-'));
try {
  fs.mkdirSync(fixture+'/history');
  fs.writeFileSync(fixture+'/history/one.json', JSON.stringify({timestamp:1,summary:'one'}));
  fs.writeFileSync(fixture+'/history/two.json', JSON.stringify({timestamp:2,summary:'two'})+'\n');
  let result=cp.spawnSync('bash',['-c',command,'--',fixture,fixture+'/history'],{encoding:'utf8'});
  assert.equal(result.status,0); assert.equal(result.stderr,'');
  assert.equal(result.stdout.trim().split('\n').length,2);
  fs.unlinkSync(fixture+'/history/one.json');fs.unlinkSync(fixture+'/history/two.json');
  result=cp.spawnSync('bash',['-c',command,'--',fixture,fixture+'/history'],{encoding:'utf8'});
  assert.equal(result.status,0);assert.equal(result.stdout,'');assert.equal(result.stderr,'');
} finally { fs.rmSync(fixture,{recursive:true,force:true}); }
console.log('New notifications: archived short toast and empty-directory sweep passed.');

assert.equal(m.enabled({workspace:'notch'},'workspace','islands'),true);
console.log('Legacy notch trigger settings migrate to the islands mode.');
